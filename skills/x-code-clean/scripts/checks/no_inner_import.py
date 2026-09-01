"""Checker: report imports that are not at module top level.

Rule: every ``import`` / ``from ... import`` must sit at module top level —
never inside a function, class, if/for/while, try, or other block.

Legitimate inner imports are downgraded, never hidden: a structural
signal attaches an exemption flag and the finding becomes an exemption
candidate — still reported, no hoist proposed; the user decides (same
contract as the dead-code checker):

- ``typing-only``: inside a module-level ``if TYPE_CHECKING:`` block
- ``optional-dep``: inside ``try`` with an ImportError handler that falls
  back without raising (probing for an optional dependency)
- ``lazy-activation``: an ImportError handler that raises an actionable
  error, or a lazy-contract keyword in the module/enclosing docstring
  (keyword heuristic — the agent reads the actual contract)
- ``test-local``: test file (``tests/``, ``test_*.py``, ``conftest.py``),
  or the import alias appears as a patch target string in the same file
- ``circular-guard``: hoisting would close a cycle — the in-repo target
  module transitively module-level-imports the current module (the graph
  is read from the working tree; external targets cannot be proven and
  are left to the agent)
- ``heavy-deferral``: a heavy third-party package imported inside a CLI
  entry (``main``/``cli`` function, ``__main__.py``, or the
  ``if __name__ == "__main__"`` guard) to keep startup fast

Unflagged findings are violations. Signals are structural and
conservative; judgment stays with the agent and the user (GUIDE.md).
"""

import ast
import os
import subprocess

CHECKER_ID = "no-inner-import"
DESCRIPTION = "imports at module top level only (legit inner imports flagged, never hidden)"

_TEST_MARKERS = ("/tests/", "/test_", "_test.py", "/conftest.py")

# Heavy third-party families whose import cost justifies deferral into a
# CLI entry. Extend here when a family is missing.
_HEAVY_DEPS = frozenset({
    "torch", "transformers", "triton", "tensorflow", "keras", "jax",
    "flax", "vllm", "deepspeed", "accelerate", "megatron", "flash_attn",
    "xformers", "onnxruntime", "diffusers", "peft", "datasets",
})

# Docstring keywords that declare a lazy/optional import contract. Kept
# tight on purpose — a hit only downgrades to an exemption candidate.
_LAZY_KEYWORDS = (
    "lazy", "on demand", "on-demand", "optional dep", "deferred import",
    "not require",
)

_ENTRY_FUNCS = frozenset({"main", "cli"})

_FLAG_ORDER = (
    "typing-only", "optional-dep", "lazy-activation", "circular-guard",
    "heavy-deferral", "test-local",
)

_GRAPH_CACHE = {}


def _parent_chain(node):
    chain = []
    parent = getattr(node, "_code_cleanup_parent", None)
    while parent is not None:
        chain.append(parent)
        parent = getattr(parent, "_code_cleanup_parent", None)
    return chain


def _describe(parents):
    # parents is outermost-last; the nearest enclosing construct is the
    # most useful label for the user.
    for p in parents:
        if isinstance(p, ast.Module):
            continue
        if isinstance(p, (ast.FunctionDef, ast.AsyncFunctionDef)):
            return f"FunctionDef '{p.name}'"
        if isinstance(p, ast.ClassDef):
            return f"ClassDef '{p.name}'"
        return type(p).__name__
    return None


def _is_type_checking(test):
    return (isinstance(test, ast.Name) and test.id == "TYPE_CHECKING") or (
        isinstance(test, ast.Attribute) and test.attr == "TYPE_CHECKING")


def _is_main_guard(test):
    return (isinstance(test, ast.Compare)
            and isinstance(test.left, ast.Name) and test.left.id == "__name__"
            and any(isinstance(c, ast.Constant) and c.value == "__main__"
                    for c in test.comparators))


def _catches_importerror(handler):
    t = handler.type
    if t is None:
        return True  # bare except catches ImportError too
    elts = t.elts if isinstance(t, ast.Tuple) else [t]
    return any(isinstance(e, ast.Name)
               and e.id in ("ImportError", "ModuleNotFoundError") for e in elts)


def _raises(handler):
    return any(isinstance(n, ast.Raise) for n in ast.walk(handler))


def _repo_root(path):
    try:
        out = subprocess.run(
            ["git", "-C", os.path.dirname(os.path.abspath(path)),
             "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=False,
        ).stdout.strip()
        if out:
            return out
    except OSError:
        pass
    return os.path.dirname(os.path.abspath(path))


def _repo_py_files(root):
    out = subprocess.run(
        ["git", "-C", root, "ls-files", "*.py"],
        capture_output=True, text=True, check=False,
    ).stdout
    if out:
        return [os.path.join(root, f) for f in out.splitlines()]
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
        found += [os.path.join(dirpath, f) for f in filenames if f.endswith(".py")]
    return found


def _file_module(apath, root):
    rel = os.path.relpath(apath, root)
    parts = rel[:-3].split(os.sep) if rel.endswith(".py") else rel.split(os.sep)
    if parts and parts[-1] == "__init__":
        parts = parts[:-1]
    return ".".join(parts)


def _package_of(apath, root):
    mod = _file_module(apath, root)
    if os.path.basename(apath) == "__init__.py":
        return mod
    return mod.rsplit(".", 1)[0] if "." in mod else ""


def _dotted_targets(node, pkg):
    """Absolute (or pkg-relative) dotted modules an import statement binds."""
    if isinstance(node, ast.Import):
        return [a.name for a in node.names]
    level = node.level or 0
    base = pkg or ""
    for _ in range(level - 1):
        base = base.rsplit(".", 1)[0] if "." in base else ""
    parts = ([base] if level else []) + ([node.module] if node.module else [])
    mod = ".".join(p for p in parts if p)
    targets = [mod] if mod else []
    if node.module:  # `from a import b` may bind submodule a.b
        targets += [f"{mod}.{a.name}" for a in node.names]
    elif base:  # `from . import b`
        targets += [f"{base}.{a.name}" for a in node.names]
    return [t for t in targets if t]


def _dotted_to_file(root, dotted):
    rel = dotted.replace(".", os.sep)
    for cand in (os.path.join(root, rel + ".py"),
                 os.path.join(root, rel, "__init__.py")):
        if os.path.isfile(cand):
            return os.path.abspath(cand)
    return None


def _module_graph(root):
    """Module-level import edges between repo files: {file: set(files)}."""
    if root in _GRAPH_CACHE:
        return _GRAPH_CACHE[root]
    graph = {}
    root = os.path.abspath(root)
    for pyfile in _repo_py_files(root):
        apath = os.path.abspath(pyfile)
        try:
            tree = ast.parse(open(pyfile, encoding="utf-8").read())
        except (OSError, SyntaxError, UnicodeDecodeError):
            continue
        pkg = _package_of(apath, root)
        edges = set()
        for stmt in tree.body:  # module top level only — hoisting scope
            if isinstance(stmt, (ast.Import, ast.ImportFrom)):
                for dotted in _dotted_targets(stmt, pkg):
                    target = _dotted_to_file(root, dotted)
                    if target and target != apath:
                        edges.add(target)
        graph[apath] = edges
    _GRAPH_CACHE[root] = graph
    return graph


def _reaches(graph, start, goal):
    seen, stack = set(), [start]
    while stack:
        for nxt in graph.get(stack.pop(), ()):
            if nxt == goal:
                return True
            if nxt not in seen:
                seen.add(nxt)
                stack.append(nxt)
    return False


def _exemption_flags(node, parents, tree, apath, root):
    flags = set()

    # typing-only / entry guard: module-level if-blocks on the chain.
    for p in parents:
        if isinstance(p, ast.If) and isinstance(
                getattr(p, "_code_cleanup_parent", None), ast.Module):
            if _is_type_checking(p.test):
                flags.add("typing-only")

    # optional-dep / lazy-activation: nearest enclosing try that catches
    # ImportError — raising an actionable error activates lazily, a
    # silent fallback probes for an optional dependency.
    for p in parents:
        if isinstance(p, ast.Try):
            handlers = [h for h in p.handlers if _catches_importerror(h)]
            if handlers:
                flags.add("lazy-activation" if any(_raises(h) for h in handlers)
                          else "optional-dep")
                break

    # lazy-activation: lazy-contract keyword in the module or enclosing
    # docstring (heuristic — downgrades only, the agent verifies).
    docs = [ast.get_docstring(tree)]
    docs += [ast.get_docstring(p) for p in parents
             if isinstance(p, (ast.FunctionDef, ast.AsyncFunctionDef,
                               ast.ClassDef))]
    blob = "\n".join(d for d in docs if d).lower()
    if any(k in blob for k in _LAZY_KEYWORDS):
        flags.add("lazy-activation")

    # test-local: test files, or the alias is a patch target in-file.
    if any(m in apath.replace(os.sep, "/") for m in _TEST_MARKERS):
        flags.add("test-local")
    else:
        strings = [n.value for n in ast.walk(tree)
                   if isinstance(n, ast.Constant) and isinstance(n.value, str)]
        for alias in node.names:
            binding = alias.asname
            if binding is None:
                binding = (alias.name.split(".")[0]
                           if isinstance(node, ast.Import) else alias.name)
            if binding and any(f"{binding}." in s for s in strings):
                flags.add("test-local")

    # heavy-deferral: heavy third-party inside a CLI entry.
    roots = ({a.name.split(".")[0] for a in node.names}
             if isinstance(node, ast.Import)
             else {node.module.split(".")[0]} if node.module else set())
    nearest_func = next(
        (p for p in parents
         if isinstance(p, (ast.FunctionDef, ast.AsyncFunctionDef))), None)
    entry_ctx = (
        os.path.basename(apath) == "__main__.py"
        or (nearest_func is not None and nearest_func.name in _ENTRY_FUNCS)
        or any(isinstance(p, ast.If) and _is_main_guard(p.test)
               and isinstance(getattr(p, "_code_cleanup_parent", None),
                              ast.Module)
               for p in parents)
    )
    if roots & _HEAVY_DEPS and entry_ctx:
        flags.add("heavy-deferral")

    # circular-guard: hoisting would close an in-repo import cycle.
    pkg = _package_of(apath, root)
    graph = _module_graph(root)
    for dotted in _dotted_targets(node, pkg):
        target = _dotted_to_file(root, dotted)
        if target and target != apath and _reaches(graph, target, apath):
            flags.add("circular-guard")
            break

    return [f for f in _FLAG_ORDER if f in flags]


def run(path, src):
    """Return a list of finding dicts for ``src``."""
    try:
        tree = ast.parse(src)
    except SyntaxError as e:
        return [
            {
                "file": path,
                "line": getattr(e, "lineno", 0),
                "text": "",
                "parent": "SyntaxError",
                "message": f"cannot parse: {e.msg}",
            }
        ]

    # Attach parent pointers.
    for node in ast.walk(tree):
        for child in ast.iter_child_nodes(node):
            child._code_cleanup_parent = node

    apath = os.path.abspath(path)
    root = None
    findings = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.Import, ast.ImportFrom)):
            continue
        parents = _parent_chain(node)
        parent_desc = _describe(parents)
        if parent_desc is None:
            continue
        if root is None:
            root = _repo_root(apath)
        names = ", ".join(
            alias.asname or alias.name for alias in node.names
        )
        flags = _exemption_flags(node, parents, tree, apath, root)
        if flags:
            message = (f"import '{names}' inside {parent_desc}; "
                       f"exemption candidate (flags: {', '.join(flags)}); "
                       "do not hoist without verifying")
        else:
            message = (f"import '{names}' inside {parent_desc}; "
                       "move to module top level")
        findings.append(
            {
                "file": path,
                "line": node.lineno,
                "column": node.col_offset,
                "text": ast.unparse(node),
                "parent": parent_desc,
                "flags": flags,
                "message": message,
            }
        )
    return findings

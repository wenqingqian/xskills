"""Checker: report module-level definitions never referenced in the repo.

Rule: a module-level function, class, or constant defined in a scope file
but never referenced anywhere else in the repository's Python code is a
dead-code candidate.

Candidates come only from the scope files; the reference search always
covers every tracked ``*.py`` in the repository (working tree), because
"use" is a repo-level property.  References are name-based (``ast.Name``
loads, attribute accesses, import aliases), so a same-named symbol in an
unrelated module can mask a dead definition — findings are candidates for
the agent to verify, never verdicts.

Exemptions are reported as flags, not hidden (checkers only find; the user
decides):

- ``exported``: listed in the module's ``__all__``
- ``decorated``: carries decorators (registration-style decorators such as
  pytest fixtures or CLI commands consume the function invisibly)
- ``entry-point``: named ``main``
- ``test-only``: referenced only from test files
- ``dynamic-ref``: no static reference, but the exact name appears in a
  string literal somewhere (getattr / registry lookups)
"""

import ast
import os
import subprocess

CHECKER_ID = "dead-code"
DESCRIPTION = "module-level defs (functions/classes/constants) never referenced in the repo"

_INDEX_CACHE = {}

_TEST_MARKERS = ("/tests/", "/test_", "_test.py", "/conftest.py")


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


def _build_index(root):
    """Scan every repo .py once: (name, file, line) refs + string literals."""
    if root in _INDEX_CACHE:
        return _INDEX_CACHE[root]
    refs, strings, exported = [], set(), {}
    for pyfile in _repo_py_files(root):
        try:
            tree = ast.parse(open(pyfile, encoding="utf-8").read())
        except (OSError, SyntaxError, UnicodeDecodeError):
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load):
                refs.append((node.id, pyfile, node.lineno))
            elif isinstance(node, ast.Attribute):
                refs.append((node.attr, pyfile, node.lineno))
            elif isinstance(node, (ast.Import, ast.ImportFrom)):
                for a in node.names:
                    refs.append(((a.asname or a.name).split(".")[0], pyfile, node.lineno))
            elif isinstance(node, ast.Constant) and isinstance(node.value, str):
                strings.add(node.value)
        names = set()
        for node in tree.body:
            if (isinstance(node, ast.Assign)
                    and any(isinstance(t, ast.Name) and t.id == "__all__" for t in node.targets)
                    and isinstance(node.value, (ast.List, ast.Tuple))):
                names |= {e.value for e in node.value.elts
                          if isinstance(e, ast.Constant) and isinstance(e.value, str)}
        exported[os.path.abspath(pyfile)] = names
    _INDEX_CACHE[root] = (refs, strings, exported)
    return _INDEX_CACHE[root]


def _definitions(tree):
    """Module-level candidate definitions in a scope file's AST."""
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            yield ("function", node.name, node, bool(node.decorator_list))
        elif isinstance(node, ast.ClassDef):
            yield ("class", node.name, node, bool(node.decorator_list))
        elif isinstance(node, ast.Assign) and len(node.targets) == 1 \
                and isinstance(node.targets[0], ast.Name):
            yield ("constant", node.targets[0].id, node, False)
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            yield ("constant", node.target.id, node, False)


def _is_dunder(name):
    return name.startswith("__") and name.endswith("__")


def run(path, src):
    """Return dead-code candidate findings for the scope file ``src``."""
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return []  # the parse failure is reported by other checkers
    refs, strings, exported = _build_index(_repo_root(path))
    apath = os.path.abspath(path)
    findings = []
    for kind, name, node, decorated in _definitions(tree):
        if _is_dunder(name) or name == "__all__":
            continue
        own = (node.lineno, node.end_lineno or node.lineno)
        hard = [(f, ln) for n, f, ln in refs
                if n == name and not (f == apath and own[0] <= ln <= own[1])]
        flags = []
        if name in exported.get(apath, ()):
            flags.append("exported")
        if decorated:
            flags.append("decorated")
        if kind == "function" and name == "main":
            flags.append("entry-point")
        if hard and all(any(m in f for m in _TEST_MARKERS) for f, _ in hard):
            flags.append("test-only")
        if not hard:
            if name in strings:
                flags.append("dynamic-ref")
            text = ast.get_source_segment(src, node) or name
            findings.append({
                "file": path,
                "line": node.lineno,
                "column": node.col_offset,
                "text": text.splitlines()[0],
                "kind": kind,
                "flags": flags,
                "message": f"{kind} '{name}' is defined but never referenced"
                           f" in the repo (flags: {', '.join(flags) or 'none'})",
            })
    return findings

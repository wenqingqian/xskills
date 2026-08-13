"""Checker: report imports that are not at module top level.

Rule: every `import` / `from ... import` must sit at module top level —
never inside a function, class, if/for/while, try, or other block.

The finding's ``parent`` field names the enclosing construct (e.g.
``FunctionDef 'foo'``, ``If``, ``Try``) so the user can tell a real
violation from a deliberate pattern (e.g. ``if TYPE_CHECKING:``).
"""

import ast

CHECKER_ID = "no-inner-import"
DESCRIPTION = "imports must be at module top level (no inner imports)"


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

    findings = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.Import, ast.ImportFrom)):
            continue
        parents = _parent_chain(node)
        parent_desc = _describe(parents)
        if parent_desc is not None:
            names = ", ".join(
                alias.asname or alias.name for alias in node.names
            )
            findings.append(
                {
                    "file": path,
                    "line": node.lineno,
                    "column": node.col_offset,
                    "text": ast.unparse(node),
                    "parent": parent_desc,
                    "message": f"import '{names}' inside {parent_desc}; move to module top level",
                }
            )
    return findings

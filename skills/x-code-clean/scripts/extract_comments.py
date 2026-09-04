#!/usr/bin/env python3
"""Extract comment candidates from source files for a code-cleanup review.

Two modes:

  --range <start>..<end>        Git mode: comments on lines added/modified by
                                the commit range.  Tokenizes the *end* commit's
                                snapshot (`git show <end>:<file>`) so line
                                numbers match the diff hunks; the working tree
                                is never read in this mode (uncommitted changes
                                to these files are ignored).
  --files <f1> [<f2> ...]       File mode: all comments in the given files
                                (working-tree content).

Output is JSON: [{"file", "line", "line_end", "kind", "text"}, ...]
kind is one of full_comment / inline_comment / docstring / desc_string
(docstring and desc_string only reported for Python; desc_string is a plain
string literal bound to a documentation-carrying name, e.g. help=/description=).

Language coverage:
  - Python: exact via tokenize (docstrings and whitelisted descriptive
    strings are grouped).
  - Everything else: per-extension comment-marker heuristics (line markers
    like # // --, block pairs like /* */) with a block-comment state machine.
    Heuristics cannot tell a marker inside a string literal from a real
    comment, and multi-line block comments are reported as one item.

Caveats (by design — this is a *candidate* list, the review reads the real
files anyway): see above; git mode only reports comments on lines the range
actually touched; files created inside the range are reported whole
(use --files to limit).
"""

import argparse
import io
import json
import re
import subprocess
import sys
import tokenize

# Extension -> (line markers, block pairs).  A line marker also starts a
# comment mid-line (inline_comment); block pairs are (start, end) strings.
LANG_COMMENT_STYLES = {
    ".py": ("__python__", None),
    ".c": (["//"], [("/*", "*/")]),
    ".h": (["//"], [("/*", "*/")]),
    ".cpp": (["//"], [("/*", "*/")]),
    ".cc": (["//"], [("/*", "*/")]),
    ".cxx": (["//"], [("/*", "*/")]),
    ".hpp": (["//"], [("/*", "*/")]),
    ".cu": (["//"], [("/*", "*/")]),
    ".cuh": (["//"], [("/*", "*/")]),
    ".js": (["//"], [("/*", "*/")]),
    ".jsx": (["//"], [("/*", "*/")]),
    ".ts": (["//"], [("/*", "*/")]),
    ".tsx": (["//"], [("/*", "*/")]),
    ".go": (["//"], [("/*", "*/")]),
    ".rs": (["//"], [("/*", "*/")]),
    ".java": (["//"], [("/*", "*/")]),
    ".sh": (["#"], None),
    ".bash": (["#"], None),
    ".zsh": (["#"], None),
    ".yaml": (["#"], None),
    ".yml": (["#"], None),
    ".toml": (["#"], None),
    ".ini": (["#", ";"], None),
    ".cfg": (["#"], None),
    ".conf": (["#"], None),
    ".cmake": (["#"], None),
    ".mk": (["#"], None),
    ".dockerfile": (["#"], None),
    ".rb": (["#"], None),
    ".lua": (["--"], None),
    ".sql": (["--"], [("/*", "*/")]),
    ".tex": (["%"], None),
}

FALLBACK_STYLE = (["#", "//"], [("/*", "*/")])

# Assignment-target names (lowercase compare) whose plain string value is
# user-facing documentation — the string twin of a comment.  Extend here,
# not in the classifier.
DESC_STRING_PARAMS = frozenset({
    "help", "description", "doc", "__doc__", "epilog", "usage", "title",
    "comment", "note", "notes", "summary", "about",
})


def extract_from_python(src, added_lines=None):
    items = []
    lines = src.splitlines()
    try:
        toks = list(tokenize.generate_tokens(io.StringIO(src).readline))
    except (tokenize.TokenError, IndentationError):
        return items
    # Lookback state for `NAME = STRING` (kwarg or assignment).  Only a
    # plain '=' sets after_eq — '==' and ':=' are distinct OP tokens, so
    # comparisons and walrus never match.
    last_name = None
    after_eq = False
    for tok in toks:
        if tok.type == tokenize.COMMENT:
            line = tok.start[0]
            if added_lines is not None and line not in added_lines:
                continue
            prefix = lines[line - 1][: tok.start[1]].strip() if line - 1 < len(lines) else ""
            kind = "inline_comment" if prefix else "full_comment"
            items.append({"line": line, "line_end": line, "kind": kind, "text": tok.string})
            # A comment sitting between `=` and the string must not reset
            # the lookback (e.g. `help=  # note\n    "text"`).
            continue
        if tok.type in (tokenize.NL, tokenize.NEWLINE, tokenize.INDENT, tokenize.DEDENT):
            continue
        if tok.type == tokenize.STRING:
            start, end = tok.start[0], tok.end[0]
            report = added_lines is None or any(l in added_lines for l in range(start, end + 1))
            appended = False
            if report and tok.string.strip().startswith(('"""', "'''")):
                line_text = lines[start - 1] if start - 1 < len(lines) else ""
                if line_text[: tok.start[1]].strip() == "":
                    items.append(
                        {"line": start, "line_end": end, "kind": "docstring", "text": tok.string}
                    )
                    appended = True
            if not appended and report:
                # desc_string: plain literal (no f/b/r prefix — interpolated
                # or non-text values are functional, not prose) bound to a
                # whitelisted documentation name.
                if (
                    after_eq
                    and last_name is not None
                    and last_name.lower() in DESC_STRING_PARAMS
                    and tok.string[:1] in ("'", '"')
                ):
                    items.append(
                        {"line": start, "line_end": end, "kind": "desc_string", "text": tok.string}
                    )
        if tok.type == tokenize.NAME:
            last_name = tok.string
            after_eq = False
        elif tok.type == tokenize.OP:
            after_eq = tok.string == "="
        else:
            last_name = None
            after_eq = False
    items.sort(key=lambda x: x["line"])
    return items


def extract_from_heuristic(src, line_markers, block_pairs, added_lines=None):
    """Line-marker + block-comment extraction for non-Python languages."""
    items = []
    lines = src.splitlines()
    in_block = None
    block_start = None
    block_text = []
    n = len(lines)
    for idx in range(n):
        lineno = idx + 1
        line = lines[idx]
        if added_lines is not None and lineno not in added_lines:
            # Still track block state on skipped lines so later lines parse
            # correctly; only the *reporting* is filtered.
            if in_block:
                end_marker = in_block[1]
                if end_marker in line:
                    in_block = None
                    block_start = None
                    block_text = []
            continue
        if in_block:
            end_marker = in_block[1]
            block_text.append(line)
            if end_marker in line:
                items.append(
                    {
                        "line": block_start,
                        "line_end": lineno,
                        "kind": "full_comment",
                        "text": "\n".join(block_text),
                    }
                )
                in_block = None
                block_start = None
                block_text = []
            continue
        stripped = line.lstrip()
        if block_pairs:
            matched_block = False
            for start_marker, end_marker in block_pairs:
                if start_marker in stripped:
                    matched_block = True
                    if end_marker in line:
                        # Single-line block comment: /* ... */.
                        items.append(
                            {
                                "line": lineno,
                                "line_end": lineno,
                                "kind": "full_comment",
                                "text": line,
                            }
                        )
                    else:
                        in_block = (start_marker, end_marker)
                        block_start = lineno
                        block_text = [line]
                    break
            if matched_block:
                continue
        for marker in line_markers:
            pos = line.find(marker)
            if pos == -1:
                continue
            # shebang lines are not comments (e.g. #!/usr/bin/env bash)
            if marker == "#" and pos == 0 and line.startswith("#!"):
                continue
            prefix = line[:pos].strip()
            items.append(
                {
                    "line": lineno,
                    "line_end": lineno,
                    "kind": "inline_comment" if prefix else "full_comment",
                    "text": line[pos:],
                }
            )
            break
    if in_block:
        items.append(
            {
                "line": block_start,
                "line_end": n,
                "kind": "full_comment",
                "text": "\n".join(block_text),
            }
        )
    items.sort(key=lambda x: x["line"])
    return items


def extract_from_source(path, src, added_lines=None):
    style = LANG_COMMENT_STYLES.get(
        path[path.rfind("."):].lower() if "." in path else "", None
    )
    if style is None:
        style = FALLBACK_STYLE
    if style[0] == "__python__":
        return extract_from_python(src, added_lines)
    return extract_from_heuristic(src, style[0], style[1], added_lines)


def _git(args, quiet=False):
    out = subprocess.run(args, capture_output=True, text=True, check=False).stdout
    return out


def _added_lines_for_file(rng, path):
    """Parse `git diff <rng> -- <path>` into the set of added line numbers."""
    out = _git(["git", "diff", rng, "--", path])
    added = set()
    cur = None
    for line in out.splitlines():
        m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
        if m:
            cur = int(m.group(1)) - 1
            continue
        if cur is None:
            continue
        if line.startswith("+"):
            cur += 1
            added.add(cur)
        elif line.startswith("-"):
            continue
        else:
            cur += 1
    return added


# Extensions unlikely to carry reviewable comments; always skipped in git mode.
BINARY_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico", ".bmp",
    ".pdf", ".zip", ".gz", ".tar", ".bz2", ".xz", ".7z", ".zst",
    ".bin", ".o", ".a", ".so", ".dll", ".exe", ".pt", ".pth", ".ckpt",
    ".safetensors", ".npy", ".npz", ".h5", ".tfrecord", ".db", ".sqlite",
    ".woff", ".woff2", ".ttf", ".eot", ".mp4", ".mp3", ".wav",
}


def _git_mode_files(rng, files):
    if files:
        return files
    out = _git(["git", "diff", rng, "--name-only", "--diff-filter=ACM"])
    result = []
    for f in out.splitlines():
        base = f.split("/")[-1]
        if "." in base:
            if base[base.rfind("."):].lower() in BINARY_EXTENSIONS:
                continue
        elif base not in ("Makefile", "makefile", "Dockerfile", "dockerfile", "CMakeLists"):
            continue
        result.append(f)
    return result


def _range_end(rng):
    """Return the commit the range's '+' line numbers refer to."""
    return rng.split("..")[-1] if ".." in rng else "HEAD"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--range", help="git commit range, e.g. abc123..HEAD")
    ap.add_argument("--files", nargs="+", help="files to scan")
    args = ap.parse_args()

    if not args.range and not args.files:
        ap.error("provide --range or --files")

    out = []
    if args.range:
        end = _range_end(args.range)
        for path in _git_mode_files(args.range, args.files):
            src = _git(["git", "show", f"{end}:{path}"])
            if not src:
                continue
            added = _added_lines_for_file(args.range, path)
            for item in extract_from_source(path, src, added_lines=added):
                item["file"] = path
                out.append(item)
    else:
        for path in args.files:
            try:
                src = open(path, encoding="utf-8").read()
            except (OSError, UnicodeDecodeError) as e:
                print(f"skip {path}: {e}", file=sys.stderr)
                continue
            for item in extract_from_source(path, src):
                item["file"] = path
                out.append(item)

    print(json.dumps(out, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()

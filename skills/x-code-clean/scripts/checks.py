#!/usr/bin/env python3
"""Run all code-cleanup checkers over files or a git commit range.

Usage:
  python3 scripts/checks.py --files a.py b.py
  python3 scripts/checks.py --range abc123..HEAD

Every checker registered in scripts/checks/ runs on every invocation —
the skill decides the scope, never which checkers run.  Output is JSON:
  [{"checker", "file", "line", "column", "text", "message", ...}, ...]

Git mode reads the *end* commit's snapshot (`git show <end>:<file>`), so
line numbers match the diff; per-file sources are never read from the
working tree in that mode (repo-wide checkers may still consult it).
Scope is every non-binary text file (null-byte sniff); checkers declaring
``PYTHON_ONLY = True`` run on ``.py`` files only.
"""

import argparse
import json
import re
import subprocess
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

from checks import CHECKERS  # noqa: E402
from changed_lines import BINARY_EXTENSIONS  # noqa: E402

SNIFF_BYTES = 8192


def _git(args):
    return subprocess.run(args, capture_output=True, text=True, check=False).stdout


def _range_end(rng):
    return rng.split("..")[-1] if ".." in rng else "HEAD"


def _added_lines_for_file(rng, path):
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


def _is_text(src):
    """Null byte in the first 8 KB marks binary — secrets scanning wants
    every non-binary text file, so the sniff, not an extension list, decides."""
    return b"\0" not in src.encode("utf-8", "replace")[:SNIFF_BYTES]


def _git_mode_files(rng):
    out = _git(["git", "diff", rng, "--name-only", "--diff-filter=ACM"])
    files = []
    for f in out.splitlines():
        base = f.split("/")[-1]
        if "." in base and base[base.rfind("."):].lower() in BINARY_EXTENSIONS:
            continue
        files.append(f)
    return files


def _applicable(path):
    """Checker IDs that apply to this path (PYTHON_ONLY checkers skip the rest)."""
    return [cid for cid in CHECKERS
            if not getattr(CHECKERS[cid], "PYTHON_ONLY", False) or path.endswith(".py")]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--range", help="git commit range, e.g. abc123..HEAD")
    ap.add_argument("--files", nargs="+", help="files to scan")
    args = ap.parse_args()

    if not args.range and not args.files:
        ap.error("provide --range or --files")

    findings = []
    if args.range:
        end = _range_end(args.range)
        for path in _git_mode_files(args.range):
            src = _git(["git", "show", f"{end}:{path}"])
            if not src or not _is_text(src):
                continue
            added = _added_lines_for_file(args.range, path)
            for cid in _applicable(path):
                for finding in CHECKERS[cid].run(path, src):
                    if finding.get("line") in added or not added:
                        findings.append({"checker": cid, **finding})
    else:
        for path in args.files:
            try:
                src = open(path, encoding="utf-8").read()
            except (OSError, UnicodeDecodeError) as e:
                print(f"skip {path}: {e}", file=sys.stderr)
                continue
            if not _is_text(src):
                continue
            for cid in _applicable(path):
                for finding in CHECKERS[cid].run(path, src):
                    findings.append({"checker": cid, **finding})

    print(json.dumps(findings, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()

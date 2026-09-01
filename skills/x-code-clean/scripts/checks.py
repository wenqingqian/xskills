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
"""

import argparse
import json
import re
import subprocess
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

from checks import CHECKERS  # noqa: E402


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


def _git_mode_files(rng):
    out = _git(["git", "diff", rng, "--name-only", "--diff-filter=ACM"])
    return [f for f in out.splitlines() if f.endswith(".py")]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--range", help="git commit range, e.g. abc123..HEAD")
    ap.add_argument("--files", nargs="+", help="files to scan")
    args = ap.parse_args()

    if not args.range and not args.files:
        ap.error("provide --range or --files")
    ids = list(CHECKERS)

    findings = []
    if args.range:
        end = _range_end(args.range)
        for path in _git_mode_files(args.range):
            src = _git(["git", "show", f"{end}:{path}"])
            if not src:
                continue
            added = _added_lines_for_file(args.range, path)
            for cid in ids:
                for finding in CHECKERS[cid].run(path, src):
                    if finding.get("line") in added or not added:
                        findings.append({"checker": cid, **finding})
    else:
        for path in args.files:
            try:
                src = open(path, encoding="utf-8").read()
            except OSError as e:
                print(f"skip {path}: {e}", file=sys.stderr)
                continue
            for cid in ids:
                for finding in CHECKERS[cid].run(path, src):
                    findings.append({"checker": cid, **finding})

    print(json.dumps(findings, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()

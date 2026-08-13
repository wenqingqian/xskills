#!/usr/bin/env python3
"""Run code-cleanup checkers over files or a git commit range.

Usage:
  python3 scripts/checks.py --check no-inner-import --files a.py b.py
  python3 scripts/checks.py --check no-inner-import --range abc123..HEAD
  python3 scripts/checks.py --all --files ...

Checkers live in scripts/checks/ and register themselves in the registry
(see scripts/checks/__init__.py).  Output is JSON:
  [{"file", "line", "column", "text", "message", ...}, ...]

Git mode reads the *end* commit's snapshot (`git show <end>:<file>`), so
line numbers match the diff; the working tree is never read in that mode.
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
    ap.add_argument("--check", nargs="+", help="checker ids to run")
    ap.add_argument("--all", action="store_true", help="run every registered checker")
    ap.add_argument("--list", action="store_true", help="list registered checkers and exit")
    ap.add_argument("--range", help="git commit range, e.g. abc123..HEAD")
    ap.add_argument("--files", nargs="+", help="files to scan")
    # Map "--<checker-id>" (e.g. --no-inner-import) onto --check <id> so a
    # checker can be selected directly, without knowing the --check flag.
    argv = []
    for a in sys.argv[1:]:
        if a.startswith("--") and a[2:] in CHECKERS:
            argv += ["--check", a[2:]]
        else:
            argv.append(a)
    args = ap.parse_args(argv)

    if args.list:
        for cid, mod in sorted(CHECKERS.items()):
            desc = getattr(mod, "DESCRIPTION", "")
            print(f"{cid}: {desc}")
        return

    if args.all:
        ids = list(CHECKERS)
    else:
        ids = args.check or []
    for cid in ids:
        if cid not in CHECKERS:
            ap.error(f"unknown checker '{cid}'; use --list to see available checkers")
    if not ids:
        ap.error("provide --check <ids> or --all")
    if not args.range and not args.files:
        ap.error("provide --range or --files")

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

#!/usr/bin/env python3
"""Compute added-line sets for comment-review scoping (no comment parsing).

Usage:
  changed_lines.py --range <start>..<end>   Lines added by the commit range,
                                            numbered in <end>'s snapshot.
  changed_lines.py                          Uncommitted changes vs HEAD:
                                            tracked modifications plus
                                            untracked files.

Output JSON:
  {"files": {path: [line, ...]}, "whole": [path, ...]}
  - "files": added line numbers per modified file — review only these lines
  - "whole": files created in the range / untracked files — review entire

Range mode assumes the working tree matches <end>; line numbers refer to
that snapshot, not to a drifted working tree.

Text detection: known binary extensions are excluded outright; anything
else passes a null-byte sniff of its first 8 KB (from the end commit's
blob in range mode, the working tree otherwise).
"""

import argparse
import json
import re
import subprocess
import sys

# Extensions unlikely to carry reviewable text; always skipped.
BINARY_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico", ".bmp",
    ".pdf", ".zip", ".gz", ".tar", ".bz2", ".xz", ".7z", ".zst",
    ".bin", ".o", ".a", ".so", ".dll", ".exe", ".pt", ".pth", ".ckpt",
    ".safetensors", ".npy", ".npz", ".h5", ".tfrecord", ".db", ".sqlite",
    ".woff", ".woff2", ".ttf", ".eot", ".mp4", ".mp3", ".wav",
}

SNIFF_BYTES = 8192


def _git(args):
    return subprocess.run(args, capture_output=True, text=True, check=False)


def _git_out(args):
    """Run git and return stdout; a git failure is a hard error — an
    invalid range must fail loudly, not yield an empty result."""
    r = subprocess.run(args, capture_output=True, text=True, check=False)
    if r.returncode != 0:
        sys.exit(f"changed_lines.py: git {' '.join(args)} failed: "
                 f"{r.stderr.strip()}")
    return r.stdout


def _is_binary(path, ref=None):
    """Null byte in the first 8 KB — from `ref:path` when ref is given,
    else from the working tree."""
    if ref:
        out = _git_out(["git", "show", f"{ref}:{path}"]).encode("utf-8", "replace")
    else:
        try:
            with open(path, "rb") as f:
                out = f.read(SNIFF_BYTES)
        except OSError:
            return True
    return b"\0" in out[:SNIFF_BYTES]


def _looks_binary_ext(path):
    base = path.split("/")[-1]
    return "." in base and base[base.rfind("."):].lower() in BINARY_EXTENSIONS


def _added_lines(diff_text):
    """Parse a `git diff` into the set of added line numbers (new side)."""
    added = set()
    cur = None
    for line in diff_text.splitlines():
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
    return sorted(added)


def scan(diff_range=None):
    files = {}
    whole = []
    if diff_range:
        ref = diff_range.split("..")[-1] if ".." in diff_range else "HEAD"
        modified = _git_out(["git", "diff", diff_range, "--name-only",
                             "--diff-filter=M"]).split()
        created = _git_out(["git", "diff", diff_range, "--name-only",
                            "--diff-filter=A"]).split()
    else:
        ref = None
        probe = _git(["git", "rev-parse", "--verify", "HEAD"])
        if probe.returncode == 0:
            modified = _git_out(["git", "diff", "HEAD", "--name-only",
                                 "--diff-filter=M"]).split()
            created = _git_out(["git", "diff", "HEAD", "--name-only",
                                "--diff-filter=A"]).split()
        else:
            # Empty repository: everything is untracked.
            modified = []
            created = []
        created += _git_out(["git", "ls-files", "--others",
                             "--exclude-standard"]).split()

    for path in modified:
        if _looks_binary_ext(path):
            continue
        if _is_binary(path, ref):
            continue
        rng = diff_range if diff_range else "HEAD"
        lines = _added_lines(_git_out(["git", "diff", rng, "--", path]))
        if lines:
            files[path] = lines
    for path in created:
        if _looks_binary_ext(path):
            continue
        if _is_binary(path, ref):
            continue
        whole.append(path)
    whole.sort()
    return {"files": files, "whole": whole}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--range", help="git commit range, e.g. abc123..HEAD; "
                    "omit for uncommitted changes")
    args = ap.parse_args()
    print(json.dumps(scan(args.range), ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()

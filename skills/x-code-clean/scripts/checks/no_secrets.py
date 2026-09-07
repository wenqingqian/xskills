"""Checker: report secret-looking values in comments, strings, and text.

Rule: a line carrying a credential-shaped value — IP address, cloud/API
token, private key material, a ``password=/token:`` style assignment with a
literal-looking value — is a finding.  In comments and documentation text
the remedy is deleting the whole line (a line that carried a secret is not
trusted to keep); hits on code lines are reported as flags for the user to
decide, since removing them can change behavior.

This checker is the hard half of a dual pass: high-precision regexes with a
low false-positive budget.  It deliberately does NOT try to catch
unstructured secrets — internal hostnames, IPv6 short forms, usernames,
topology descriptions — that is the subagent soft pass's job (GUIDE.md).
Generic long-hex blobs are also out of scope on purpose: git SHAs and
checksums make the false-positive cost higher than the recall gain.

Exemptions are reported as flags, never hidden (checkers only find; the
user decides):

- ``loopback``: 127.0.0.0/8, 0.0.0.0, ::1
- ``doc-range``: RFC 5737 IPv4 documentation ranges (192.0.2.0/24,
  198.51.100.0/24, 203.0.113.0/24), RFC 3849 IPv6 (2001:db8::/32),
  broadcast 255.255.255.255

Runs on every non-binary text file, not just Python.
"""

import re

CHECKER_ID = "no-secrets"
DESCRIPTION = ("secret-looking values (IPs, tokens, credentials) in text; "
               "whole-line delete for comment hits")
PYTHON_ONLY = False

_IPV4 = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
_IPV6 = re.compile(r"\b(?:[0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}\b")

_TOKEN_PATTERNS = (
    ("aws-key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("github-token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b")),
    ("slack-token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("google-key", re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b")),
    ("api-key", re.compile(r"\bsk-[A-Za-z0-9_\-]{20,}\b")),
    ("private-key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("bearer-token", re.compile(r"\b[Bb]earer\s+[A-Za-z0-9._\-]{20,}\b")),
)

# `password=hunter12` / "token: 9f86d081..." in text.  The value must look
# literal: a quoted string of 8+ chars, or an unquoted run of 8+ chars with
# at least one digit — placeholders, env lookups, and prose stay out.
_ASSIGN = re.compile(
    r"\b(password|passwd|pwd|secret|token|api[_-]?key|access[_-]?key|"
    r"auth[_-]?token)\b\s*[:=]\s*(\S+)", re.IGNORECASE)

_ASSIGN_VALUE_SKIP = re.compile(
    r"^[$<{(<]|^\*|^x+$|^n/a$", re.IGNORECASE)
_ASSIGN_VALUE_WORDS = frozenset({
    "none", "null", "nil", "true", "false", "yes", "no", "redacted",
    "placeholder", "os.environ", "getenv", "environ", "len", "str",
})
_ASSIGN_PREFIX_SKIP = ("os.environ", "getenv", "environ.get", "getattr",
                       "your_", "<redacted>", "***")

_LOOPBACK = re.compile(r"^127\.|^0\.0\.0\.0$")
_DOC_V4 = re.compile(r"^192\.0\.2\.|^198\.51\.100\.|^203\.0\.113\.|^255\.255\.255\.255$")


def _ipv4_finding_flags(value):
    """Return flags for an IPv4-shaped token, or None if not IP-like.

    Shape-only detection cannot tell a version string (2.6.32.5) from an
    address — those stay findings (over-reporting is the safe direction
    for a secrets check; the agent verifies before reporting).
    """
    octets = value.split(".")
    if any(not o.isdigit() or int(o) > 255 for o in octets):
        return None  # an octet >255 is impossible for an address
    flags = []
    if _LOOPBACK.match(value):
        flags.append("loopback")
    if _DOC_V4.match(value):
        flags.append("doc-range")
    return flags


def run(path, src):
    findings = []
    for lineno, line in enumerate(src.splitlines(), start=1):
        kinds, flags = [], []
        for m in _IPV4.finditer(line):
            ip_flags = _ipv4_finding_flags(m.group(0))
            if ip_flags is None:
                continue
            if "ipv4" not in kinds:
                kinds.append("ipv4")
            flags.extend(f for f in ip_flags if f not in flags)
        for m in _IPV6.finditer(line):
            low = m.group(0).lower()
            if "ipv6" not in kinds:
                kinds.append("ipv6")
            if low.startswith("2001:db8") and "doc-range" not in flags:
                flags.append("doc-range")
        for kind, pat in _TOKEN_PATTERNS:
            if pat.search(line) and kind not in kinds:
                kinds.append(kind)
        for m in _ASSIGN.finditer(line):
            value = m.group(2).strip("'\"").rstrip(".,;)")
            if len(value) < 8:
                continue
            if _ASSIGN_VALUE_SKIP.match(value):
                continue
            if value.lower() in _ASSIGN_VALUE_WORDS:
                continue
            if any(value.startswith(p) for p in _ASSIGN_PREFIX_SKIP):
                continue
            if not (re.search(r"\d", value) or len(value) >= 16):
                continue
            if "credential-assignment" not in kinds:
                kinds.append("credential-assignment")
        if not kinds:
            continue
        text = line.strip()
        findings.append({
            "file": path,
            "line": lineno,
            "column": 0,
            "text": text,
            "kinds": kinds,
            "flags": flags,
            "message": (f"possible secret(s): {', '.join(kinds)}"
                        f" (flags: {', '.join(flags) or 'none'})"
                        " — comment hits delete the whole line"),
        })
    return findings

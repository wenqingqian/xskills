"""Checker registry for the code-cleanup skill.

Add a new checker by dropping a module in this package that defines
``CHECKER_ID`` and ``run(path, src) -> list[dict]``, then registering it
below.  The CLI (``scripts/checks.py``) and the SKILL.md workflow pick it
up automatically; nothing else needs to change.

Finding dict fields (all checkers should emit at least): file, line,
text, message — plus any checker-specific fields (e.g. ``parent``).
"""

from . import no_inner_import

CHECKERS = {
    no_inner_import.CHECKER_ID: no_inner_import,
}

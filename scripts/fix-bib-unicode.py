#!/usr/bin/env python3
"""Replace non-LaTeX characters in LaTeX source files with LaTeX equivalents.

Works on any LaTeX-related file (.tex, .bib, .bst, .cls, .sty, etc.).

Handles two kinds of input:
  1. Literal \\UTF{xxxx} / \\CID{xxx} escape strings (from some export tools)
  2. Raw Unicode characters (from copy-paste or web downloads)

Exit codes:
  0 — no changes needed
  1 — file(s) were modified (caller should re-stage)
"""

import re
import sys

# ── Mapping tables ──────────────────────────────────────────────

# \UTF{xxxx} string escapes  →  LaTeX
UTF_MAP = {
    "00E0": r"{\`a}",   # à
    "00E1": r"{\'a}",   # á
    "00E4": r'{\"a}',   # ä
    "00C4": r'{\"A}',   # Ä
    "00E8": r"{\`e}",   # è
    "00E9": r"{\'e}",   # é
    "00ED": r"{\'i}",   # í
    "00F1": r"{\~n}",   # ñ
    "00F6": r'{\"o}',   # ö
    "00D6": r'{\"O}',   # Ö
    "00FC": r'{\"u}',   # ü
    "00DC": r'{\"U}',   # Ü
    "00DF": r"{\ss}",   # ß
    "00A0": " ",         # non-breaking space
    "2013": "--",        # en-dash
    "2014": "---",       # em-dash
    "201C": "``",        # left double quote
    "201D": "''",        # right double quote
    "201E": r"\glqq{}",  # German opening quote „
}

CID_MAP = {
    "122": r"\grqq{}",   # German closing quote "
}

# Raw Unicode codepoints  →  LaTeX
UNICODE_MAP = {
    "\u00e0": r"{\`a}",
    "\u00e1": r"{\'a}",
    "\u00e4": r'{\"a}',
    "\u00c4": r'{\"A}',
    "\u00e8": r"{\`e}",
    "\u00e9": r"{\'e}",
    "\u00ed": r"{\'i}",
    "\u00f1": r"{\~n}",
    "\u00f6": r'{\"o}',
    "\u00d6": r'{\"O}',
    "\u00fc": r'{\"u}',
    "\u00dc": r'{\"U}',
    "\u00df": r"{\ss}",
    "\u00a0": " ",
    "\u2013": "--",
    "\u2014": "---",
    "\u201c": "``",
    "\u201d": "''",
    "\u201e": r"\glqq{}",
    "\u03c6": r"$\varphi$",
}

# ── Processing ──────────────────────────────────────────────────

def fix_content(content: str) -> tuple[str, bool]:
    """Return (fixed_content, was_changed)."""
    original = content

    # Pass 1: \UTF{xxxx}
    def replace_utf(m):
        code = m.group(1).upper()
        return UTF_MAP.get(code, m.group(0))

    content = re.sub(r"\\UTF\{([0-9A-Fa-f]+)\}", replace_utf, content)

    # Pass 2: \CID{xxx}
    def replace_cid(m):
        code = m.group(1)
        return CID_MAP.get(code, m.group(0))

    content = re.sub(r"\\CID\{([0-9]+)\}", replace_cid, content)

    # Pass 3: raw Unicode
    for char, latex in UNICODE_MAP.items():
        content = content.replace(char, latex)

    return content, content != original


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} FILE [FILE ...]", file=sys.stderr)
        sys.exit(2)

    any_changed = False
    for path in sys.argv[1:]:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        fixed, changed = fix_content(content)
        if changed:
            with open(path, "w", encoding="utf-8") as f:
                f.write(fixed)
            print(f"  fixed: {path}")
            any_changed = True

    sys.exit(1 if any_changed else 0)


if __name__ == "__main__":
    main()

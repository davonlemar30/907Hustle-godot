#!/usr/bin/env python3
"""Fail if any shipped string uses a character the theme fonts do not carry.

This bug class is invisible in the editor. On macOS the editor quietly borrows a
system font for any glyph Anton / Barlow Condensed / Share Tech Mono lack, so a
missing character looks perfect locally and renders as a tofu box in the web
export, which has no system font to borrow. Screenshots of the editor will never
show it; only the browser will.

So the check reads the fonts' own cmap tables and refuses anything outside them.
Comments are ignored -- they never reach a Label. Anything that does reach one
must either be a covered character or stop being text (an SVG in a TextureRect,
which is how the arrows, warning and meter dots on these screens are drawn).

    scripts/check_glyph_coverage.py            # report and exit non-zero on a gap
    scripts/check_glyph_coverage.py --list     # also list every non-ASCII in use

Requires fonttools and brotli (pip install fonttools brotli).
"""

from __future__ import annotations

import sys
import unicodedata
from pathlib import Path

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / "assets" / "fonts"
SCAN_DIRS = ("ui", "autoload", "systems")
SCAN_EXTS = (".tscn", ".gd", ".tres")


def covered() -> set[int]:
    """Codepoints present in *every* theme font.

    Intersection, not union: a string can be styled with any of the type
    variations, so a character is only safe if all of them can draw it.
    """
    fonts = sorted(FONT_DIR.glob("*.woff2"))
    if not fonts:
        sys.exit(f"no fonts found under {FONT_DIR}")
    sets = []
    for path in fonts:
        cmap: set[int] = set()
        for table in TTFont(path)["cmap"].tables:
            cmap |= set(table.cmap)
        sets.append(cmap)
    return set.intersection(*sets)


def is_comment(path: Path, line: str, chars: str) -> bool:
    """True when every non-ASCII character on the line sits in a GDScript comment."""
    if path.suffix != ".gd":
        return False
    if line.lstrip().startswith("#"):
        return True
    hash_at = line.find("#")
    if hash_at == -1 or any(line.index(c) < hash_at for c in set(chars)):
        return False
    before = line[:hash_at]
    return before.count('"') % 2 == 0 and before.count("'") % 2 == 0


def main() -> int:
    ok = covered()
    gaps: dict[str, list[str]] = {}
    seen: dict[str, list[str]] = {}

    for name in SCAN_DIRS:
        for path in sorted((ROOT / name).rglob("*")):
            if path.suffix not in SCAN_EXTS:
                continue
            rel = path.relative_to(ROOT)
            for num, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                chars = "".join(c for c in line if ord(c) > 127)
                if not chars or is_comment(path, line, chars):
                    continue
                for char in dict.fromkeys(chars):
                    bucket = seen if ord(char) in ok else gaps
                    bucket.setdefault(char, []).append(f"{rel}:{num}")

    if "--list" in sys.argv:
        for char, hits in sorted(seen.items(), key=lambda kv: ord(kv[0])):
            print(f"  ok  U+{ord(char):04X} {char}  {unicodedata.name(char, '?')} ({len(hits)})")

    if not gaps:
        print(f"glyph coverage ok - every shipped character is in all {len(list(FONT_DIR.glob('*.woff2')))} theme fonts")
        return 0

    print("Characters no theme font can draw. These render as tofu boxes in the")
    print("web export even though the editor shows them correctly:\n")
    for char, hits in sorted(gaps.items(), key=lambda kv: ord(kv[0])):
        print(f"  U+{ord(char):04X} {char}  {unicodedata.name(char, '?')}")
        for hit in hits:
            print(f"      {hit}")
    print("\nUse an SVG from assets/icons/ in a TextureRect instead.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

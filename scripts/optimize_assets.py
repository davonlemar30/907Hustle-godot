#!/usr/bin/env python3
"""Shrink oversized raster assets to WebP at phone-appropriate resolutions.

907Hustle renders at 375x812 logical points. Source art ships at 1254px+ square,
which is 3-8x more pixels than any device will ever sample. This script caps each
asset by *width* (the constraining axis on a portrait phone) and re-encodes to
WebP, which Godot 4 imports natively.

Re-runnable and idempotent: drop new PNGs into assets/ and run it again. Files
already converted are left alone unless they still exceed their width cap.

    scripts/optimize_assets.py --dry-run     # report only, touch nothing
    scripts/optimize_assets.py               # convert, rewrite refs, drop sources
    scripts/optimize_assets.py --keep-source # convert but leave the PNGs on disk

Requires cwebp (brew install webp).
"""

from __future__ import annotations

import argparse
import fnmatch
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"

# (glob, max_width_px, quality, lossless). First match wins.
# Width is the cap because a 375pt-wide portrait viewport constrains horizontally;
# 750 = 2x the viewport, the most any mainstream phone will resolve.
# (glob, max_width_px, quality, lossless). First match wins.
# Width is the cap because a 375pt-wide portrait viewport constrains horizontally.
# 750 = 2x that viewport, and nothing can ever render wider than the screen, so it
# is the honest ceiling for any full-width art. Only icons, which are never drawn
# above ~52pt, get a tighter cap.
RULES: list[tuple[str, int, int, bool]] = [
    ("assets/icons/logolaucher*",    512, 90, False),  # launcher icon, needs headroom
    ("assets/icons/*",               128,  0, True),   # nav/HUD icons: flat art, lossless wins
    ("assets/textures/logo*",        750, 88, False),  # wordmarks: sharp edges, alpha
    ("assets/textures/grungelogo*",  750, 88, False),
    ("assets/textures/tex-*",        750, 82, False),  # grain/noise/vignette overlays
]
DEFAULT_RULE = (750, 85, False)

# Extensions we re-encode. SVG (vector) and woff2 (already compressed) are skipped.
SOURCE_EXTS = {".png", ".jpg", ".jpeg"}
# Files to scan when rewriting res:// references after a rename.
REF_GLOBS = ("*.tscn", "*.tres", "*.gd", "*.godot", "*.cfg")


def die(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def image_size(path: Path) -> tuple[int, int] | None:
    """Width/height without a third-party imaging library."""
    data = path.read_bytes()[:64]
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = struct.unpack(">II", data[16:24])
        return w, h
    if data[:2] == b"\xff\xd8":  # JPEG: walk the segment headers
        with path.open("rb") as fh:
            fh.read(2)
            while True:
                b = fh.read(1)
                while b and b != b"\xff":
                    b = fh.read(1)
                marker = fh.read(1)
                while marker == b"\xff":
                    marker = fh.read(1)
                if not marker:
                    return None
                if marker[0] in range(0xC0, 0xCF) and marker[0] not in (0xC4, 0xC8, 0xCC):
                    fh.read(3)
                    h, w = struct.unpack(">HH", fh.read(4))
                    return w, h
                seg = fh.read(2)
                if len(seg) < 2:
                    return None
                fh.seek(struct.unpack(">H", seg)[0] - 2, 1)
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        out = subprocess.run(["webpinfo", str(path)], capture_output=True, text=True)
        w = re.search(r"Width:\s*(\d+)", out.stdout)
        h = re.search(r"Height:\s*(\d+)", out.stdout)
        if w and h:
            return int(w.group(1)), int(h.group(1))
    return None


def rule_for(rel: str) -> tuple[int, int, bool]:
    for pattern, width, quality, lossless in RULES:
        if fnmatch.fnmatch(rel, pattern):
            return width, quality, lossless
    return DEFAULT_RULE


def encode(src: Path, dst: Path, cap: int, quality: int, lossless: bool, width: int) -> None:
    cmd = ["cwebp", "-quiet", "-m", "6", "-metadata", "none"]
    cmd += ["-lossless", "-z", "9"] if lossless else ["-q", str(quality)]
    if width > cap:
        cmd += ["-resize", str(cap), "0"]  # 0 = derive height, preserve aspect
    cmd += [str(src), "-o", str(dst)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0 or not dst.exists():
        die(f"cwebp failed on {src}: {result.stderr.strip()}")


def rewrite_refs(renames: dict[str, str], dry_run: bool) -> int:
    """Point res:// paths at the new .webp files.

    Godot keys ext_resources by uid first and path second. A renamed file gets a
    fresh uid on next import, so the recorded uid goes stale -- strip it and let
    the editor regenerate it from the path.
    """
    touched = 0
    for pattern in REF_GLOBS:
        for path in ROOT.rglob(pattern):
            if ".godot" in path.parts or "addons" in path.parts:
                continue
            try:
                original = path.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            text = original
            for old, new in renames.items():
                if old not in text:
                    continue
                lines = text.split("\n")
                for i, line in enumerate(lines):
                    if old in line:
                        line = line.replace(old, new)
                        lines[i] = re.sub(r'\suid="uid://[^"]*"', "", line)
                text = "\n".join(lines)
            if text != original:
                touched += 1
                if not dry_run:
                    path.write_text(text, encoding="utf-8")
                print(f"    refs  {path.relative_to(ROOT)}")
    return touched


# Godot re-encodes every texture on import, so shrinking the source file alone
# does not shrink the shipped .pck. A lossless import inflates 2.5MB of WebP back
# into 12MB of .ctex. These params are what actually control download size.
IMPORT_PARAMS = {
    "compress/mode": "1",            # 1 = Lossy (WebP). 0 = Lossless, the default.
    "compress/lossy_quality": "0.9",  # high, because the source is already lossy
    "detect_3d/compress_to": "0",     # this is a 2D project; never silently switch to VRAM
}

# Assets a lossless RULE claims keep a lossless import too. Lossy WebP rings around
# hard edges, which on an icon's alpha channel shows up as a halo when the nav bar
# tints it. Icons are a couple of KB either way, so there is nothing to win here.
LOSSLESS_IMPORT_PARAMS = dict(IMPORT_PARAMS, **{"compress/mode": "0"})


def enforce_import_settings(dry_run: bool) -> int:
    """Pin texture import params on generated .import files.

    Godot writes these with defaults on first import and then honours whatever is
    in the file, so committing them is how the setting sticks. SVGs are left
    lossless -- they rasterise to small textures and lossy blurs their edges --
    and so is any WebP whose rule asked for lossless, for the same reason.
    """
    changed = 0
    for imp in sorted(ASSETS.rglob("*.webp.import")):
        source = imp.relative_to(ROOT).as_posix().removesuffix(".import")
        _, _, lossless = rule_for(source)
        params = LOSSLESS_IMPORT_PARAMS if lossless else IMPORT_PARAMS
        text = original = imp.read_text(encoding="utf-8")
        for key, value in params.items():
            pattern = rf"^{re.escape(key)}=.*$"
            if re.search(pattern, text, flags=re.M):
                text = re.sub(pattern, f"{key}={value}", text, flags=re.M)
        if text != original:
            changed += 1
            print(f"  imp {imp.relative_to(ROOT)}")
            if not dry_run:
                imp.write_text(text, encoding="utf-8")
    return changed


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="report what would change, write nothing")
    ap.add_argument("--keep-source", action="store_true", help="leave original files on disk")
    args = ap.parse_args()

    if not shutil.which("cwebp"):
        die("cwebp not found. Install it with:  brew install webp")
    if not ASSETS.is_dir():
        die(f"no assets directory at {ASSETS}")

    before = after = 0
    converted = shrunk = skipped = 0
    renames: dict[str, str] = {}

    for src in sorted(ASSETS.rglob("*")):
        if not src.is_file() or src.suffix.lower() not in SOURCE_EXTS | {".webp"}:
            continue
        rel = src.relative_to(ROOT).as_posix()
        cap, quality, lossless = rule_for(rel)
        size = image_size(src)
        if size is None:
            print(f"  ??  {rel} (unreadable header, skipped)")
            continue
        width, height = size
        src_bytes = src.stat().st_size

        already_webp = src.suffix.lower() == ".webp"
        if already_webp and width <= cap:
            skipped += 1
            continue  # already converted and within budget

        dst = src.with_suffix(".webp")
        tmp = dst.with_suffix(".webp.tmp") if already_webp else dst

        new_dims = f"{cap}x{round(height * cap / width)}" if width > cap else f"{width}x{height}"
        if args.dry_run:
            print(f"  ->  {rel}  {width}x{height} -> {new_dims}  ({src_bytes // 1024}KB -> ?)")
            before += src_bytes
            converted += 1
            continue

        encode(src, tmp, cap, quality, lossless, width)
        if already_webp:
            tmp.replace(dst)
        dst_bytes = dst.stat().st_size
        before += src_bytes
        after += dst_bytes
        pct = 100 - (100 * dst_bytes // src_bytes)
        print(f"  ok  {rel}  {width}x{height} -> {new_dims}  {src_bytes // 1024}KB -> {dst_bytes // 1024}KB  (-{pct}%)")

        if already_webp:
            shrunk += 1
        else:
            converted += 1
            renames[f"res://{rel}"] = f"res://{dst.relative_to(ROOT).as_posix()}"
            if not args.keep_source:
                src.unlink()
                # The stale .import points at a file that no longer exists; Godot
                # writes a fresh one for the .webp on next scan.
                stale = src.with_name(src.name + ".import")
                if stale.exists():
                    stale.unlink()

    if renames and not args.dry_run:
        print("\n  rewriting res:// references")
        rewrite_refs(renames, args.dry_run)

    print("\n  pinning texture import settings")
    repinned = enforce_import_settings(args.dry_run)
    if not repinned:
        print("    (all already pinned)")

    print()
    if args.dry_run:
        print(f"dry run: {converted} file(s) would be processed, {before // 1024}KB of input")
        print("re-run without --dry-run to apply")
    else:
        saved = before - after
        print(f"converted {converted}, re-shrank {shrunk}, skipped {skipped} (already optimal)")
        if before:
            print(f"{before // 1024}KB -> {after // 1024}KB  (saved {saved // 1024}KB, -{100 * saved // before}%)")
        print("\nnext: open the project in Godot so it re-imports and regenerates uids,")
        print("      then save the scenes to bake the new uids into .tscn files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

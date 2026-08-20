#!/usr/bin/env python3
"""Turn flat two-tone icon art into a white glyph on transparency.

The nav bar tints its icons at runtime with `self_modulate` on a TextureRect.
That only works if the texture is a *mask*: white pixels carrying the shape in
their alpha channel, so multiplying by the tint colour yields the tint. Art that
ships as black-on-white (or white-on-black, or dark-on-transparent) renders as a
solid square, or as an invisible near-black smudge, on the dark nav bar.

This script derives the alpha channel from the art's own luminance, forces every
pixel to opaque white RGB, and rescales the glyph so it occupies the same share
of the canvas as the hand-authored SVG icons in assets/icons/nav (~80%). The
source art is flat two-tone with antialiased edges, so luminance *is* the
coverage mask -- the conversion is exact, not a chroma-key approximation.

Background detection is automatic, from the four corners:

    transparent corners -> keep existing alpha, just repaint RGB white
    light corners       -> dark ink is the glyph, alpha = 255 - luminance
    dark corners        -> light ink is the glyph, alpha = luminance

Levels are stretched to the art's own min/max, which matters for source files
whose ink barely separates from its background (icon-hustl is a 28/255 glyph on
a 0/255 field -- visually a black square until it is normalised).

    scripts/icon_to_mask.py in.webp out.webp
    scripts/icon_to_mask.py --fill 0.8 in.webp out.webp
    scripts/icon_to_mask.py --dry-run in.webp    # report what it would do

Requires cwebp and dwebp (brew install webp).
"""

from __future__ import annotations

import argparse
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

# Share of the canvas the glyph's longest axis should span. The SVG nav icons
# draw into a 24x24 viewBox with roughly 2-3 units of padding, so ~0.8.
DEFAULT_FILL = 0.80
CANVAS = 128

# A corner brighter than this is a light background; darker is a dark one.
CORNER_MIDPOINT = 128
# Alpha at or below this counts as transparent when sniffing the corners.
CORNER_ALPHA_FLOOR = 8


def die(msg: str) -> None:
    sys.exit("icon_to_mask: " + msg)


def decode(src: Path) -> tuple[int, int, bytearray]:
    """Decode any cwebp-readable image to a flat RGBA bytearray."""
    with tempfile.TemporaryDirectory() as tmp:
        pam = Path(tmp) / "decoded.pam"
        if src.suffix.lower() == ".webp":
            cmd = ["dwebp", "-quiet", str(src), "-pam", "-o", str(pam)]
        else:
            # Round-trip through cwebp so PNG/TIFF inputs work too.
            web = Path(tmp) / "in.webp"
            subprocess.run(
                ["cwebp", "-quiet", "-lossless", "-exact", str(src), "-o", str(web)],
                check=True,
            )
            cmd = ["dwebp", "-quiet", str(web), "-pam", "-o", str(pam)]
        subprocess.run(cmd, check=True)
        return read_pam(pam)


def read_pam(path: Path) -> tuple[int, int, bytearray]:
    with open(path, "rb") as f:
        if f.readline().strip() != b"P7":
            die("%s is not a PAM file" % path)
        hdr = {}
        while True:
            line = f.readline().strip()
            if line == b"ENDHDR":
                break
            if b" " in line:
                key, val = line.split(b" ", 1)
                hdr[key.decode()] = val.decode()
        w, h, depth = int(hdr["WIDTH"]), int(hdr["HEIGHT"]), int(hdr["DEPTH"])
        data = f.read()

    if depth == 4:
        return w, h, bytearray(data)
    if depth == 3:  # dwebp drops alpha for images that have none
        out = bytearray(w * h * 4)
        for p in range(w * h):
            out[p * 4 : p * 4 + 3] = data[p * 3 : p * 3 + 3]
            out[p * 4 + 3] = 255
        return w, h, out
    die("unsupported PAM depth %d" % depth)


def write_png(path: Path, w: int, h: int, rgba: bytearray) -> None:
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # filter type 0
        raw += rgba[y * w * 4 : (y + 1) * w * 4]

    def chunk(tag: bytes, payload: bytes) -> bytes:
        body = tag + payload
        return (
            struct.pack(">I", len(payload))
            + body
            + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
        )

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def luminance(r: int, g: int, b: int) -> int:
    return (r * 299 + g * 587 + b * 114) // 1000


def sniff_background(w: int, h: int, rgba: bytearray) -> str:
    """Classify the source as 'alpha', 'light' or 'dark' from its corners."""
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    alphas, lums = [], []
    for x, y in corners:
        i = (y * w + x) * 4
        alphas.append(rgba[i + 3])
        lums.append(luminance(rgba[i], rgba[i + 1], rgba[i + 2]))

    if all(a <= CORNER_ALPHA_FLOOR for a in alphas):
        return "alpha"
    mid = sum(lums) / len(lums)
    return "light" if mid > CORNER_MIDPOINT else "dark"


def build_mask(w: int, h: int, rgba: bytearray, mode: str) -> list[int]:
    """Derive a 0-255 coverage value per pixel."""
    if mode == "alpha":
        return [rgba[i * 4 + 3] for i in range(w * h)]

    lums = [luminance(rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2]) for i in range(w * h)]
    lo, hi = min(lums), max(lums)
    if hi == lo:
        die("source is a single flat colour -- nothing to key out")
    span = hi - lo

    if mode == "light":  # dark ink on a light field
        return [255 - (l - lo) * 255 // span for l in lums]
    return [(l - lo) * 255 // span for l in lums]  # light ink on a dark field


def ink_bbox(w: int, h: int, mask: list[int], threshold: int = 8):
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        row = y * w
        for x in range(w):
            if mask[row + x] > threshold:
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                if y < miny:
                    miny = y
                if y > maxy:
                    maxy = y
    if maxx < 0:
        die("mask is empty -- background detection probably picked the wrong side")
    return minx, miny, maxx, maxy


def resample(mask: list[int], w: int, h: int, box, size: int, fill: float) -> list[int]:
    """Bilinearly fit the glyph's bounding box into a `size` canvas at `fill`."""
    minx, miny, maxx, maxy = box
    iw, ih = maxx - minx + 1, maxy - miny + 1
    scale = (size * fill) / max(iw, ih)
    dw, dh = max(1, round(iw * scale)), max(1, round(ih * scale))
    ox, oy = (size - dw) // 2, (size - dh) // 2

    out = [0] * (size * size)
    for dy in range(dh):
        # Map destination centre back into the source bounding box.
        sy = miny + (dy + 0.5) * ih / dh - 0.5
        y0 = max(miny, min(maxy, int(sy // 1)))
        y1 = min(maxy, y0 + 1)
        fy = sy - y0
        for dx in range(dw):
            sx = minx + (dx + 0.5) * iw / dw - 0.5
            x0 = max(minx, min(maxx, int(sx // 1)))
            x1 = min(maxx, x0 + 1)
            fx = sx - x0
            a = mask[y0 * w + x0]
            b = mask[y0 * w + x1]
            c = mask[y1 * w + x0]
            d = mask[y1 * w + x1]
            top = a + (b - a) * fx
            bot = c + (d - c) * fx
            out[(oy + dy) * size + ox + dx] = int(round(top + (bot - top) * fy))
    return out


def convert(src: Path, dst: Path, size: int, fill: float, dry_run: bool) -> None:
    w, h, rgba = decode(src)
    mode = sniff_background(w, h, rgba)
    mask = build_mask(w, h, rgba, mode)
    box = ink_bbox(w, h, mask)
    minx, miny, maxx, maxy = box

    print(
        "%s: %dx%d, background=%s, ink %dx%d at (%d,%d)"
        % (src.name, w, h, mode, maxx - minx + 1, maxy - miny + 1, minx, miny)
    )
    if dry_run:
        return

    mask = resample(mask, w, h, box, size, fill)

    # White everywhere, including under transparent pixels: linear filtering and
    # mipmaps sample RGB regardless of alpha, so a dark backing colour would
    # bleed a grey halo around the glyph at nav-bar size.
    out = bytearray(b"\xff" * (size * size * 4))
    for p, a in enumerate(mask):
        out[p * 4 + 3] = max(0, min(255, a))

    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "mask.png"
        write_png(png, size, size, out)
        dst.parent.mkdir(parents=True, exist_ok=True)
        # -exact keeps the white RGB under transparent pixels; without it cwebp
        # is free to rewrite invisible pixels to whatever compresses best.
        subprocess.run(
            ["cwebp", "-quiet", "-lossless", "-exact", str(png), "-o", str(dst)],
            check=True,
        )
    print("  -> %s (%d bytes)" % (dst, dst.stat().st_size))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path, nargs="?")
    ap.add_argument("--size", type=int, default=CANVAS)
    ap.add_argument(
        "--fill",
        type=float,
        default=DEFAULT_FILL,
        help="share of the canvas the glyph should span (default %.2f)" % DEFAULT_FILL,
    )
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not args.src.exists():
        die("no such file: %s" % args.src)
    if not args.dry_run and args.dst is None:
        ap.error("dst is required unless --dry-run")

    convert(args.src, args.dst, args.size, args.fill, args.dry_run)


if __name__ == "__main__":
    main()

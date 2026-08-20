#!/usr/bin/env python3
"""Generate a Hustle-surface screen that shares the game chrome.

Every game screen carries the same top bar, HUD, bottom nav, HOME FAB and
atmosphere layer. Re-authoring ~600 lines of that per surface would guarantee
they drift apart, so a new surface is derived from an existing screen instead:
keep the chrome verbatim, drop the content nodes, and leave a Title plus one
empty `Body` VBox for the script to fill.

Content stays in code because these lists are state-shaped -- how many stickup
targets are visible depends on where the player is standing, and how many
Shark notes are open depends on what they funded.

    scripts/make_surface_screen.py stickup "STICKUP" "Fast money. Loud money."
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "ui" / "screens" / "hustle.tscn"
CONTENT = "Shell/Scroll/Pad/Content"


def build(name: str, heading: str, subtitle: str, backdrop: str) -> str:
    src = SOURCE.read_text(encoding="utf-8")
    out, skipping = [], False
    for ln in src.split("\n"):
        if ln.startswith("[node "):
            m = re.search(r'parent="([^"]*)"', ln)
            parent = m.group(1) if m else ""
            skipping = parent == CONTENT or parent.startswith(CONTENT + "/")
        if not skipping:
            out.append(ln)
    s = "\n".join(out)

    s = s.replace('[node name="Hustle" type="Control"]', f'[node name="{name.title()}" type="Control"]')
    s = s.replace('path="res://ui/screens/hustle.gd" id="scr"', f'path="res://ui/screens/{name}.gd" id="scr"')
    s = s.replace('path="res://assets/textures/bg-hustle.webp" id="bg_hustle"',
                  f'path="res://assets/textures/{backdrop}" id="bg_hustle"')

    header = f'''[node name="Title" type="VBoxContainer" parent="{CONTENT}"]
layout_mode = 2
theme_override_constants/separation = 2

[node name="H" type="Label" parent="{CONTENT}/Title"]
layout_mode = 2
theme_type_variation = &"Brand"
theme_override_font_sizes/font_size = 26
text = "{heading}"

[node name="Sub" type="Label" parent="{CONTENT}/Title"]
layout_mode = 2
theme_type_variation = &"Muted"
theme_override_font_sizes/font_size = 12
text = "{subtitle}"

[node name="Gap" type="Control" parent="{CONTENT}"]
custom_minimum_size = Vector2(0, 12)
layout_mode = 2
mouse_filter = 2

[node name="Body" type="VBoxContainer" parent="{CONTENT}"]
layout_mode = 2
theme_override_constants/separation = 10

'''
    anchor = s.index('[node name="NavBar" type="PanelContainer" parent="Shell"]')
    return s[:anchor] + header + s[anchor:]


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    name, heading, subtitle = sys.argv[1], sys.argv[2], sys.argv[3]
    backdrop = sys.argv[4] if len(sys.argv) > 4 else "bg-street.webp"
    path = ROOT / "ui" / "screens" / f"{name}.tscn"
    path.write_text(build(name, heading, subtitle, backdrop), encoding="utf-8")
    print(f"  wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

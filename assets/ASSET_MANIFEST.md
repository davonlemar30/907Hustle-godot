# 907Hustle — Godot Asset Manifest

> **Corrected 2026-08-23 (Batch 18 PR 5) — two things below were wrong, found
> in a documentation audit rather than by anyone hitting the drift in
> practice.**
>
> 1. **The nav-icon list two sections down documents tabs that do not
>    exist.** It lists `icon-market.svg`, `icon-crew.svg`, `icon-travel.svg`
>    and `icon-people.svg` as the bottom tab bar. The actual, canonical nav
>    (`HANDOFF.md`'s "Bottom nav — CANONICAL" section, sourced from web
>    `ui.jsx:197`) is `street / hustle / home / phone / more`, using
>    `icon-street.webp`, `icon-hustle.webp`, `icon-home.svg`,
>    `icon-phone.webp` and `icon-menu.svg`. The four wrongly-listed SVGs are
>    real files that still exist in `assets/icons/nav/` — they were drawn for
>    an earlier, since-abandoned nav plan and were never deleted, so the
>    folder now holds both sets. Do not wire them; they are not the nav.
> 2. **Four of the delivery folders below are empty on disk** —
>    `portraits/`, `photos/atmosphere/`, `photos/locations/`, `logo/` — and
>    the art this manifest describes for each of them shipped somewhere
>    else instead: character/location art is in `assets/img/`, and the brand
>    logo and Home's atmosphere backdrop are in `assets/textures/`
>    (`grungelogo1trans.webp`, `bg-hustle.webp`). The pipeline this manifest
>    describes (drop into the named folder, Godot auto-imports) was
>    superseded at some point by delivering finished, already-wired assets
>    directly into the folder a scene actually reads from — nobody updated
>    this file to say so.
>
> The plan below is left as originally written rather than rewritten, since
> it is a useful record of the original intent even where delivery diverged
> from it. Check `assets/img/`, `assets/icons/nav/` and `assets/textures/`
> directly for what is actually shipped, or `HANDOFF.md`'s Design System
> section for the current, correct reference.

Drop generated assets into the folders below using the exact filenames.
Godot auto-imports on focus/scan; then I wire them into the scenes.

## Global rules (important for clean import + theming)

- **Icons → SVG, monochrome WHITE (#ffffff) on transparent, 24×24 viewBox, FILLED silhouette** (matches the mockup's flat style). Keep them one solid color — Godot tints them per-state via `modulate` (grey when idle, red `#ff4a3d` when active, amber/green/etc. in the HUD). One file serves every color state; do **not** bake colors in.
- **Portraits → PNG, 512×512**, head-and-shoulders, consistent framing, dark or transparent background. I crop them to circles in-engine.
- **Photos → WebP (or PNG), 1280×720 (16:9)**, dark / night / snowy Anchorage mood to match. Home banner crops to a ~375×150 strip, so keep the subject centered-ish.
- **Naming → lowercase, hyphenated**, prefixed by folder (`icon-`, `portrait-`, `photo-`). No spaces.

---

> ✅ **ALL 36 ICONS DONE** — authored as monochrome SVGs, imported, and the
> 5 nav icons are wired + verified in home.tscn. `coke` & `cocaine` share
> `icon-coke.svg`. The lists below are the reference for what exists.

## icons/nav/  (5) — bottom tab bar
- icon-home.svg   (house)
- icon-market.svg (bar chart / trending)
- icon-crew.svg   (three people)
- icon-travel.svg (map pin)
- icon-people.svg (contacts / two figures)

## icons/hud/  (6) — top stat strip
- icon-heat.svg    (flame)
- icon-health.svg  (pulse / heartbeat line)
- icon-debt.svg    (coins / dollar)
- icon-cargo.svg   (crate / box)
- icon-respect.svg (crown)
- icon-crewpower.svg (raised fist or people)

## icons/products/  (7) — market rows & trade screens
- icon-weed.svg    (leaf)
- icon-meth.svg    (crystal shard)
- icon-pills.svg   (capsule)
- icon-coke.svg    (baggie / powder)
- icon-molly.svg   (pill)
- icon-shrooms.svg (mushroom)
- icon-lean.svg    (foam cup)

## icons/ui/  (~18) — functional / inline
- icon-target.svg     (reticle — Tonight's Operation)
- icon-arrow-up.svg   (market up)
- icon-arrow-down.svg (market down)
- icon-external.svg   (up-right arrow — "LIVE UPDATE")
- icon-chat.svg       (speech bubble)
- icon-walkie.svg     (walkie-talkie — Eli report)
- icon-clock.svg      (activity feed)
- icon-eye.svg        (lay low / night watch)
- icon-bus.svg        (travel / bus pass)
- icon-cash.svg       (dollar — sold)
- icon-plus.svg
- icon-minus.svg
- icon-back.svg       (chevron left)
- icon-menu.svg       (hamburger)
- icon-lock.svg
- icon-warning.svg    (alert triangle)
- icon-check.svg
- icon-gear.svg       (settings)

## portraits/  — NPCs (**1024×1024** masters, head centered, ~12% headroom)
**Pull each character's ClickUp bio before generating.** Generate Yalonda + Juan
first (they set the visual bible), then batch the rest. Priority order:
- portrait-yalonda.png  (Yalonda Hernandez — LOCKED concept in PROMPT_GUIDE.md)
- portrait-juan.png     (Juan Hernandez, 18, her son)
- portrait-goodie.png
- portrait-tasha.png
- portrait-malik.png
- portrait-eli.png      (Eli Ward)
- portrait-pherris.png
- portrait-tone.png
- portrait-deshawn.png
- portrait-curtis.png
- portrait-cal.png / portrait-nia.png
  Secondary, as their screens arrive: renata, boone, mina, selam, biniam, etc.

## photos/atmosphere/  — gameplay backgrounds, **9:16**
- bg-spenard-home.webp  ← the tall night-street shot you're dropping in now
  (fine to drop as street.png in assets/img/ — I'll relocate/rename it).
  Full-bleed behind the Home shell; also center-crops to the banner.

## photos/locations/  — area headers (Travel screen), **16:9**
Primary travel areas (confirmed in game data):
- location-spenard.webp
- location-downtown.webp
- location-industrial.webp   (Industrial Service Roads — docks, chain-link,
  loading bays, truck yards, snow berms)
  (Midtown / U-Med / Mountain View are minor ambient refs — skip until they
  get real screens.)

## logo/  (optional but big fidelity win)
- logo-907hustle.svg (or .png, ~1024px wide, transparent) — distressed wordmark
  to replace the plain font brand in the header / title screen.
- icon-app.png (512×512) — game/app icon.

## textures/  (optional polish — overlays)
- tex-snow.png     (seamless, transparent — falling snow particle sprite)
- tex-grain.png    (subtle noise overlay)
- tex-vignette.png (radial darkening)

---

### Minimum set to make the NEXT build (Market screen) look complete
`icons/nav/*` (5) + `icons/hud/*` (6) + `icons/products/*` (7) + a couple of
`icons/ui` arrows. Portraits/photos can trail in per-screen.

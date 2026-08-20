# 907Hustle — Godot

A ground-up **Godot 4.7.2** rebuild of *907Hustle: One Good Run* — a mobile-first
(375×812, portrait) street-sim set in Anchorage's Spenard district. This repo is the
UI/UX layer; the shipping **web build (React, v1.35) is the behavioral canon** for all
game data and logic.

> Living build notes with the full detail live in [`HANDOFF.md`](HANDOFF.md).

## Status

Static, canon-populated screens with the state spine now in place. **No game logic
yet** — screens read a fixed mid-game snapshot; the reducer port is a later phase.

| Screen | File | Notes |
| --- | --- | --- |
| Home | `ui/screens/home.tscn` | HUD, hero photo, Tonight's Operation, market/turf, people, feed |
| Market | `ui/screens/market.tscn` | 8 products, canon per-district pricing, buy/sell (the "Street Market") |
| Hustle | `ui/screens/hustle.tscn` | income hub — 6 surfaces, Today's Take, Curtis pressure |
| Street | `ui/screens/street.tscn` | exploration hub — districts, venues, people (fully `GameState`-driven) |

All four screens read their shared chrome (day/cash/HUD) from `GameState` via
`ui/screens/screen_base.gd`. Street (districts/venues) and Market (product rows +
prices) also drive their content from it. Remaining baked content (Home's snapshot/
turf, Hustle's surfaces) gets bound as `GameState` grows.

**Nav:** `STREET · HUSTLE · HOME · PHONE · MORE` with a raised red center HOME button.
Not yet built: Phone, More, Crew/Territory, Travel detail, and the Hustle sub-screens
(Jobs, 907List, Boost, Stickup, Shark).

## Project layout

```
autoload/game_state.gd     # GameState singleton — the run's state spine
ui/screens/*.tscn|.gd      # one scene per screen (Street is script-driven)
ui/components/atmosphere.tscn   # reusable screen-space FX layer, instanced everywhere
ui/theme/hustle_theme.tres      # palette, fonts, SVG 9-slice skins, type variations
ui/theme/atmosphere.gdshader    # material + film grain + vignette
assets/                    # icons (SVG), fonts, skins, photos, textures, logos
addons/godot_ai/           # committed MCP bridge (works on any clone)
```

## Architecture

- **`GameState` autoload** is the single source of truth for the run (stats, districts,
  venues, contacts). Screens read from it in `_ready()` rather than hardcoding values —
  when it later mutates via the reducer port, every reader updates for free.
- **Reusable atmosphere** (`atmosphere.tscn`) is a `CanvasLayer` each screen instances;
  one screen-space shader does a `tex-card` material pass + animated film grain + a soft
  vignette. Intensity is a set of shader uniforms.
- **Theme-driven UI** — colors, fonts, card/button skins, and type scale live in
  `hustle_theme.tres`; a change there restyles every screen.

## Running it

Open the project in Godot 4.7.2 and run any screen (`F6`), or set the main scene in
Project Settings. Target viewport is 375×812 portrait, mobile renderer. The
`godot_ai` MCP bridge is committed but optional for a plain run.

## Roadmap (abridged)

0. **UI scaffold** ✅ — screens, nav, atmosphere, theme
1. **IA completion** — remaining screens + Hustle sub-screens (static)
2. **State spine** — `GameState` exists; shared chrome retrofitted ✅; per-screen content binding next
3. **Reducer port + RNG parity** — translate `game-core.js` actions to GDScript
4. **Save/load parity** · 5. **Behavioral test harness vs the JS oracle** · 6. **Cutover**

Full roadmap and design-decision log live in the project's ClickUp master doc.

## Contributing

Feature branches per screen/system, opened as PRs against `main`. Pull game data/logic
from the web build (`src/data/*`, `game-core.js`) — **never guess canon**.

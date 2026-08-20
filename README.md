# 907Hustle — Godot

A ground-up **Godot 4.7.2** rebuild of *907Hustle: One Good Run* — a mobile-first
(375×812, portrait) street-sim set in Anchorage's Spenard district. This repo is the
UI/UX layer; the shipping **web build (React, v1.35) is the behavioral canon** for all
game data and logic.

> Living build notes with the full detail live in [`HANDOFF.md`](HANDOFF.md).

## Status

Playable demo with survival pressure: the game opens on a title screen, NEW RUN
leads through name entry into a fresh Day 1, and every screen responds. Time
passes, prices shift, travel costs a fare and a slot, jobs pay clean money on a
schedule, stickups pay fast money and raise Heat, 907List rewards reading a
listing, Boost trades odds for stock, Shark notes run on a due-day clock, and rent and the phone bill arrive whether or not you earned anything.
Crew cost wages every night, corners pay out while you sleep, and missing enough
rent ends the run.

| Screen | File | Notes |
| --- | --- | --- |
| Title | `ui/screens/title.tscn` | NEW RUN / CONTINUE RUN; standalone, no chrome |
| Name Entry | `ui/screens/name_entry.tscn` | street name + canon Day 1 preview |

Beyond the opening, screens still read a largely fixed mid-game snapshot; the
reducer port is a later phase.

| Screen | File | Notes |
| --- | --- | --- |
| Home | `ui/screens/home.tscn` | HUD, hero photo, Tonight's Operation, market/turf, people, feed |
| Market | `ui/screens/market.tscn` | 8 products, canon per-district pricing, buy/sell (the "Street Market") |
| Hustle | `ui/screens/hustle.tscn` | income hub — 6 surfaces, Today's Take, Curtis pressure |
| Street | `ui/screens/street.tscn` | exploration hub — districts, venues, people (fully `GameState`-driven) |

**All four screens are fully `GameState`-driven** — chrome plus content: Street
(districts/venues), Market (product rows/prices), Home (operation, snapshot, turf +
mini-map, feed, messages), and Hustle (Today's Take, income surfaces, Curtis). One
`notify_changed()` re-renders the visible screen (Phase 2 / State Spine complete for
existing screens).

**Nav:** `STREET · HUSTLE · HOME · PHONE · MORE` with a raised red center HOME button.
Each cell is a real Button routed through the `ScreenManager` autoload. Phone and More
are disabled until those screens exist.

Not yet built: Phone, More, Crew/Territory, Travel detail, and the Hustle sub-screens
(Jobs, 907List, Boost, Stickup, Shark).

## Project layout

```
autoload/game_state.gd     # GameState singleton — the run's state spine
autoload/screen_manager.gd # the only thing that swaps top-level screens; also toasts
systems/*.gd               # economy, time, travel, jobs, obligations — the only writers of GameState
ui/components/toast.tscn   # brief non-blocking feedback, one instance under /root
ui/screens/*.tscn|.gd      # one scene per screen (Street is script-driven)
ui/components/atmosphere.tscn   # reusable screen-space FX layer, instanced everywhere
ui/theme/hustle_theme.tres      # palette, fonts, SVG 9-slice skins, type variations
ui/theme/atmosphere.gdshader    # material + film grain + vignette
assets/                    # icons (SVG), fonts, skins, photos, textures, logos
addons/godot_ai/           # committed MCP bridge (works on any clone)
```

## Architecture

- **`GameState` autoload** is the single source of truth for the run (stats, districts,
  venues, contacts, products, turf, operation, feed, messages). It exposes a
  `state_changed` signal; screens connect `refresh()` to it, so one `notify_changed()`
  re-renders everything (the web-reducer pattern) — no per-field wiring.
- **`screen_base.gd`** fills the shared chrome and calls a `_bind_content()` hook each
  screen overrides. Home, Market, Street, and Hustle are all fully `GameState`-driven.
- **Action layer (Phase 3):** UI never mutates state directly — it calls
  `GameManager.dispatch(action, payload)`, which routes to a system in `systems/`
  (economy, time). Systems mutate `GameState`; GameManager fires one `notify_changed()`
  or an `action_failed`. All randomness routes through **`RngManager`** (FNV-1a
  `string_hash`, golden-verified against the JS oracle) — no `randf()`/`randi()` elsewhere.
- **Reusable atmosphere** (`atmosphere.tscn`) is a `CanvasLayer` each screen instances;
  one screen-space shader does a `tex-card` material pass + animated film grain + a soft
  vignette. Intensity is a set of shader uniforms.
- **Theme-driven UI** — colors, fonts, card/button skins, and type scale live in
  `hustle_theme.tres`; a change there restyles every screen.

## Running it

Open the project in Godot 4.7.2 and run any screen (`F6`), or set the main scene in
Project Settings. Target viewport is 375×812 portrait using the **Compatibility**
renderer (`gl_compatibility`), which is also what the web export requires. The
`godot_ai` MCP bridge is committed but optional for a plain run.

### On a phone

Every push to `main` builds a web export and publishes it to GitHub Pages:

**https://davonlemar30.github.io/907Hustle-godot/**

Open it in a mobile browser — roughly a 13MB download, cached after the first load.
Pull requests build the export too but do not publish, so a broken export gets caught
before it reaches the live URL.

The build runs with thread support off (Godot's default), which avoids
`SharedArrayBuffer` and therefore the COOP/COEP response headers GitHub Pages cannot
send. The `godot_ai` addon is stripped during the build — it is editor tooling, and its
autoload dials a local WebSocket that does not exist in a browser.

## Assets

Source art is capped at **750px wide** and stored as WebP. 750 is 2x the 375pt
viewport, and nothing renders wider than the screen, so it is the ceiling for
full-width art; nav icons cap at 128px lossless.

```bash
scripts/optimize_assets.py --dry-run   # report only
scripts/optimize_assets.py             # convert, rewrite refs, pin import settings
```

Drop new art into `assets/` and re-run it — files already within budget are skipped.
The script also pins `compress/mode=1` on texture `.import` files: Godot re-encodes
textures on import, and the default lossless mode re-inflates the shipped `.pck`
several times over regardless of how small the source file is.

## Roadmap (abridged)

0. **UI scaffold** ✅ — screens, nav, atmosphere, theme
1. **IA completion** — remaining screens + Hustle sub-screens (static)
2. **State spine** ✅ — `GameState` + reactive `state_changed`; all existing screens fully data-driven
3. **Reducer port + RNG parity** — 🚧 3a done (seeded RNG w/ golden parity, GameManager
   dispatch, economy buy/sell/evolve, time ticks, Market live); 3b–3d next (Jobs, 907List,
   Stick/Boost/Shark, Crew, Territory, Events)
4. **Save/load parity** · 5. **Behavioral test harness vs the JS oracle** · 6. **Cutover**

Web deploy to GitHub Pages is live (see [On a phone](#on-a-phone)) and runs independently
of the phase order.

Full roadmap and design-decision log live in the project's ClickUp master doc.

## Contributing

Feature branches per screen/system, opened as PRs against `main`. Pull game data/logic
from the web build (`src/data/*`, `game-core.js`) — **never guess canon**.

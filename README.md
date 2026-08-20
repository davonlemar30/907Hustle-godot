# 907Hustle — Godot

A ground-up **Godot 4.7.2** rebuild of *907Hustle: One Good Run* — a mobile-first
(375×812, portrait) street-sim set in Anchorage's Spenard district. The shipping
**web build (React, v1.35) is the behavioral canon** for all game data and logic.

**Play it: https://davonlemar30.github.io/907Hustle-godot/** — rebuilt on every merge
to `main`. Roughly a 13MB first load, cached after.

> Living build notes with the full detail live in [`HANDOFF.md`](HANDOFF.md).

## Status

A playable run with real pressure. You start with a name and $100, and the clock
does not stop.

The run opens on a title screen. NEW RUN leads through name entry into a fresh Day 1
in Spenard. From there: work a legitimate job or one of five criminal surfaces, move
between three districts, hire crew and pay their wages, take corners and post soldiers
on them — while rent, the phone bill and Curtis's attention all advance on their own
schedule. Miss enough rent and you are evicted, which ends the run.

Every number comes from the web build. Where a written brief and the oracle disagreed,
the oracle won; those divergences are listed in `HANDOFF.md`.

### What works

| Loop | Where |
| --- | --- |
| Start a run, name your character | Title → Name Entry |
| Buy and sell product at district prices | Market |
| Travel between districts ($5 fare, one slot) | Street |
| Work shifts for banded pay, get fired for ghosting | Hustle → Jobs |
| Flip listings whose true value is hidden by your tier | Hustle → 907List |
| Lift stock from rooms that may be watching | Hustle → Boost |
| Rob marks for fast money and real Heat | Hustle → Stickup |
| Lend at interest and decide what a default costs | Hustle → Shark |
| Hire crew, pay wages, watch loyalty | Street → People → Crew |
| Claim corners, post soldiers, collect nightly | Home → Turf |
| See what each character knows and makes of it | Home → People |
| Rent, phone bill, eviction | automatic, on day-cross |
| Pick up where you left off | automatic autosave · title → CONTINUE RUN |

### Not built yet

Phone and More screens (their nav cells are disabled), venue interiors, combat
encounters, equipment, attributes, and the behavioral parity harness.

## Project layout

```
autoload/
  game_state.gd       # the run's state spine + reactive `state_changed`
  game_manager.gd     # dispatch(action) → systems; one notify_changed per success
  rng_manager.gd      # FNV-1a string_hash, golden-verified against the JS oracle
  screen_manager.gd   # the only thing that swaps screens; also toasts
  exposure.gd         # observation ledgers, NPC lenses, channels, disposition bands
  curtis.gd           # rival awareness phases, watchers, quiet-streak decay
  save_system.gd      # versioned autosave on every state change; title save preview

systems/              # the ONLY writers of GameState
  economy.gd          # buy / sell / seeded price evolution
  time_system.gd      # time slots + day-cross
  travel.gd           # district change: fare + a slot
  jobs.gd             # apply / work / quit + attendance
  obligations.gd      # rent + phone bill, settled nightly
  stickup.gd          # armed robbery, tiers, the two-a-day cap
  shark.gd            # lending, terms, defaults
  nine07list.gd       # the flip board and its tiers
  boost.gd            # lifting, the technique ladder, the fence
  crew.gd             # roster, loyalty, the nightly wage clock
  territory.gd        # corners, soldiers, passive income

ui/screens/*.tscn|.gd # one scene per screen; screen_base.gd holds shared chrome
ui/components/        # atmosphere.tscn (grain/vignette), toast.tscn
ui/theme/             # hustle_theme.tres, atmosphere.gdshader

scripts/
  optimize_assets.py       # 750px cap + WebP + import pinning; re-runnable
  icon_to_mask.py          # alpha-masks flat icon art for self_modulate tinting
  check_glyph_coverage.py  # CI gate: fails the build on a glyph no font carries
  make_surface_screen.py   # derives a new surface screen from hustle.tscn's chrome
```

## Architecture

- **`GameState`** is the single source of truth for the run. It exposes a
  `state_changed` signal; screens connect `refresh()` to it, so one
  `notify_changed()` re-renders everything — the web-reducer pattern, with no
  per-field wiring.
- **UI never mutates state.** It calls `GameManager.dispatch(action, payload)`, which
  routes to a system in `systems/`. Systems mutate `GameState`; `GameManager` fires one
  `notify_changed()` or an `action_failed`.
- **`screen_base.gd`** fills the shared chrome (top bar + HUD), wires the bottom nav
  once in `_ready()`, and calls a `_bind_content()` hook each screen overrides. Title,
  Name Entry and Game Over are standalone — no chrome, so they do not extend it.
- **All randomness routes through `RngManager`**, keyed by a seed plus a per-decision
  context string. No `randf()`/`randi()` anywhere else. Canon uses two hash
  normalisations (`/2^32` and `%10000/10000`) and both exist — pick by what canon does
  at that call site, not by preference.
- **Day-cross is the heartbeat.** `time_system` emits `day_crossed`; jobs, obligations,
  crew, territory, shark, curtis and exposure all settle against it. Settlement is
  scoped to the day that *ended*, so a bill due on day 7 is payable during day 7.
- **Theme-driven UI** — colors, fonts, skins and type scale live in
  `hustle_theme.tres`; a change there restyles every screen.

## Running it

Open the project in Godot 4.7.2 and run (`F5`). Target viewport is 375×812 portrait
using the **Compatibility** renderer (`gl_compatibility`), which is also what the web
export requires. The `godot_ai` MCP bridge is committed but optional for a plain run.

### On a phone

Every push to `main` builds a web export and publishes it to GitHub Pages at the URL
above. Pull requests build the export too but do not publish, so a broken export gets
caught before it reaches the live URL.

The build runs with thread support off (Godot's default), which avoids
`SharedArrayBuffer` and therefore the COOP/COEP response headers GitHub Pages cannot
send. `html/experimental_virtual_keyboard` is **on** — that is Godot's own hidden-input
workaround and it is what makes the name field usable on a phone. The `godot_ai` addon
is stripped during the build; its autoload dials a local WebSocket that does not exist
in a browser.

## Assets

Source art is capped at **750px wide** and stored as WebP. 750 is 2x the 375pt
viewport, and nothing renders wider than the screen; nav icons cap at 128px lossless.

```bash
scripts/optimize_assets.py --dry-run   # report only
scripts/optimize_assets.py             # convert, rewrite refs, pin import settings
```

Drop new art into `assets/` and re-run it — files already within budget are skipped.
The script also pins texture `.import` settings: Godot re-encodes textures on import,
and the default lossless mode re-inflates the shipped `.pck` several times over
regardless of how small the source file is.

## Roadmap

| Phase | Status |
| --- | --- |
| 1. UI scaffold — screens, nav, atmosphere, theme | ✅ |
| 2. State spine — `GameState` + reactive refresh | ✅ |
| 3a. Reducer foundation + RNG parity | ✅ |
| 3b. Interactive screens, travel, toasts, mobile keyboard | ✅ |
| 3c. Jobs, obligations, game over | ✅ |
| 3d. 907List, Boost, Stickup, Shark | ✅ |
| 3e. Crew, territory | ✅ |
| 3f. Exposure, Curtis awareness | ✅ |
| 4. Save / load — versioned autosave, CONTINUE RUN | ✅ |
| **5. Behavioral parity harness vs the JS oracle** | **next** |
| 6. Cutover | — |

Full roadmap and the design-decision log live in the project's ClickUp master doc.

## Contributing

Feature branches per screen/system, opened as PRs against `main`. Pull game data and
logic from the web build (`src/data/*`, `game-core.js`) — **never guess canon**, and
when a brief disagrees with the oracle, the oracle wins and the divergence goes in the
PR body.

**Documentation ships with the PR.** A `HANDOFF.md` entry and the relevant ClickUp doc
section are part of the change, not a follow-up. A PR that introduces a new system
carries its doc update in the same commit range.

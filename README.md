# 907Hustle — Godot

A **Godot 4.7.2** production build of *907Hustle: One Good Run* — a mobile-first
(375×812, portrait) street-sim set in Anchorage's Spenard district. Approved
ClickUp specifications and the current Godot architecture are authoritative.
The frozen React v1.35 build is historical parity reference material only.

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

Existing ported formulas retain oracle-backed parity where that remains the approved
Godot decision. Newer approved Godot/ClickUp decisions take precedence over historical
web behavior; named divergences are listed in `HANDOFF.md`.

### What works

| Loop | Where |
| --- | --- |
| Start a run, name your character | Title → Name Entry |
| Buy and sell product at district prices | Market |
| Travel between districts ($5 fare, one slot) | Street |
| Work shifts for banded pay, get fired for ghosting | Hustle → Jobs |
| Flip listings whose true value is hidden by your tier | Hustle → 907List |
| Lose a listing to someone else the moment you pass on it | automatic, once a day's board is spent |
| Get better at reading value, and watch the odds move | automatic, on a clean flip |
| Lift stock from rooms that may be watching | Hustle → Boost |
| Rob marks for fast money and real Heat | Hustle → Stickup |
| Have it go clean, messy, wrong, or badly wrong | automatic, on any risky action |
| Lend at interest and decide what a default costs | Hustle → Shark |
| Hire crew, pay wages, watch loyalty, move them up the ranks | Street → People → Crew |
| Give Pherris the day to work the board, and get the money back at night | automatic, once she is Trusted enough |
| Claim corners, post soldiers, collect nightly | Home → Turf |
| See what each character knows and makes of it | Home → People |
| Rent, phone bill, eviction | automatic, on day-cross |
| Read texts, pay bills, hear word around town | Phone |
| Reach everything else, and read the rules | More · More → Help |
| See what the block calls you, and why | More → Character |
| Patch yourself up, or go quiet for a night | More → Recovery |
| Texts arrive; miss the bill and the line dies holding them | Phone → Texts |
| Pick up where you left off | automatic autosave · title → CONTINUE RUN |

### Not built yet

Arrest/jail, venue interiors, combat encounters, and equipment. The consequence
encounter engine is the next real gap: canon routes a blown boost and a hard
collection into it, and it is what would let those two surfaces reach the tiers
that already exist for them.

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
  economy.gd          # buy / sell + canon market walk (per-area, nightly)
  time_system.gd      # time slots + day-cross
  travel.gd           # district change: fare + a slot
  jobs.gd             # apply / work / quit + attendance
  obligations.gd      # rent + phone bill, settled nightly
  phone.gd            # the inbox, the held inbox, and the line coming back
  attributes.gd       # combat / charisma / intelligence, and how they grow
  outcome_resolver.gd # the four tiers, advantage, and what the block learns
  recovery.gd         # first aid, the clinic ladder, and laying low
  stickup.gd          # armed robbery, tiers, the two-a-day cap
  shark.gd            # lending, terms, defaults
  nine07list.gd       # the flip board and its tiers
  boost.gd            # lifting, the technique ladder, the fence
  crew.gd             # roster, loyalty, ranks, the nightly wage clock
  crew_operations.gd  # delegation lifecycle — discovery, assignment, settlement
  list_adapter.gd     # Pherris running the board: what she buys, and why she stops
  requirements.gd     # pure eligibility evaluator — structured blockers, no state
  territory.gd        # corners, soldiers, passive income

ui/screens/*.tscn|.gd # one scene per screen; screen_base.gd holds shared chrome
ui/components/        # atmosphere.tscn (grain/vignette), toast.tscn
ui/theme/             # hustle_theme.tres, atmosphere.gdshader

scripts/
  optimize_assets.py       # 750px cap + WebP + import pinning; re-runnable
  icon_to_mask.py          # alpha-masks flat icon art for self_modulate tinting
  check_glyph_coverage.py  # CI gate: fails the build on a glyph no font carries
  make_surface_screen.py   # derives a new surface screen from hustle.tscn's chrome
  parity/gen_fixtures.mjs  # records oracle truth into tests/parity/fixtures/

tests/parity/         # CI gate: replays recorded oracle fixtures through the
                      # Godot port headless; also runs the save round-trip
  fixtures/outcome_resolver/   # Build 5e: whole actions resolving, not primitives
  fixtures/requirements/       # FS-001.5: the eligibility evaluator, every type
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
- **The UI owns no gameplay rules.** Everything the 907List and Crew screens show
  about a delegated operation is read from `operation_summary()`, the adapter's
  `preview()`, and canonical blocker codes. The preview is not a second opinion:
  `preview()` and `select()` run the same `plan()`, so what the player is shown
  is what happens.
- **Delegation costs her day, not yours.** A crew member running an operation
  buys in the morning and settles at night through the same value and
  consequence path a personal sale uses — the money and the Exposure footprint
  are identical. What does *not* transfer is the player's own experience of the
  trade: no slot, no Intelligence, no progress toward Broker standing. Without
  that line a crew member would be strictly better than doing the work yourself.
- **The day ends before the clock moves.** `day_ending(ended_day)` fires while
  the clock still reads the day that is finishing; `day_crossed` fires after the
  increment. Canon's `confirmDayEnd` has the same shape, and its comment on
  `applyAttendance(state, oldDay)` gives the reason the ending day is a
  parameter rather than a read: a listener should not depend on which side of
  the increment it sits.
- **Day-cross is the heartbeat.** `time_system` emits `day_crossed`; jobs, obligations,
  crew, territory, shark, curtis and exposure all settle against it. Settlement is
  scoped to the day that *ended*, so a bill due on day 7 is payable during day 7.
- **Eligibility is data, not `if` statements.** `requirements.gd` takes a list of
  semantic requirement records and a facts dictionary and returns a structured
  blocker — `{ok, blocker_code, blocker_copy_key, current, required}` — stopping
  at the first failure, so the order of the list is the authored priority of the
  reasons. It reads nothing but its own parameters: no GameState, no autoloads.
- **Curtis hears through a filter, not a firehose.** Only violence, defiance and
  growth clear his network ear; a `financial` row reaches him on volume alone,
  at $200. That is why a big 907List day gets his attention and a $40 space
  heater never does — and why removing the filter quietly over-credits him.
- **Outcomes are tiered, not binary.** A risky action resolves into clean /
  messy / failure / catastrophic. The attribute reads that pool with tabletop
  advantage — a second look at 3, catastrophe immunity at 6 — rather than a
  bonus to a number the player cannot see. The tier then decides the Exposure
  footprint, which is the point: doing crime well does not make you invisible,
  it makes you quiet.
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
| 5. Behavioral parity harness vs the JS oracle | ✅ core — RNG primitives, the canon market walk, and the save round-trip enforced in CI (2399 checks); fixtures grow with each system |
| 5b. Phone + More screens | ✅ Phone (substrate + screen), More, Help — every nav cell has a screen |
| 5c. Attributes | ✅ substrate + Character screen — three surfaces unpinned, growth live, Street Identity derived |
| 5d. Recovery | ✅ treatment ladder + Lay Low — all six More rows ship |
| 5e. Tiered outcomes | ✅ shared resolver + Stickup/Jobs/907List converted; parity 2399 → 6628 checks |
| FS-001.2. 907List ownership | ✅ same-day opportunity consumption, Curtis volume filter, save v6; parity → 6702 checks |
| FS-001.5. Crew extensibility | ✅ rank labels, rank-curve clamp, shared requirement evaluator; parity → 7121 checks |
| FS-001.6. Crew operations | ✅ day-ending lifecycle + delegation substrate, save v7; parity → 7211 checks |
| FS-001.7. Run the Board | ✅ Pherris buys and settles on her own day; parity → 7308 checks |
| FS-001.8. Player experience | ✅ the delegation slice is playable from the existing screens; parity → 7400 checks |
| 6. Cutover | — |

Full roadmap and the design-decision log live in the project's ClickUp master doc.

## Contributing

Feature branches per screen/system, opened as PRs against `main`. Follow approved
ClickUp specifications, current Godot design decisions, and reproducible Godot tests.
The frozen web build (`src/data/*`, `game-core.js`) may explain migration history or
legacy formulas, but it does not override a newer approved Godot decision.

**Documentation ships with the PR.** A `HANDOFF.md` entry and the relevant ClickUp doc
section are part of the change, not a follow-up. A PR that introduces a new system
carries its doc update in the same commit range.

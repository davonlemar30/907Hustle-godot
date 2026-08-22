# 907Hustle — Godot

A **Godot 4.7.2** production build of *907Hustle: One Good Run* — a mobile-first
(375×812, portrait) street-sim set in Anchorage's Spenard district. Approved
ClickUp specifications and the current Godot architecture are authoritative.
The frozen React v1.35 build is historical parity reference material only.

**Play it: https://davonlemar30.github.io/907Hustle-godot/** — rebuilt on every merge
to `main`. Roughly a 13MB first load, cached after.

> Living build notes with the full detail live in [`HANDOFF.md`](HANDOFF.md).

## Version

**Current: `0.1.0`** — shown bottom-right on the title screen, and stamped into
the deployed page's `<title>` by the web-export workflow.

`MAJOR.MINOR.PATCH`, and each part means one thing here:

| Part | Increments when |
| --- | --- |
| **MAJOR** | Save compatibility breaks, or the shape of a run changes. `0` until the game is feature-complete. |
| **MINOR** | A feature milestone ships — new surfaces, new systems, a playtest pass. |
| **PATCH** | Bug fixes and tuning against an unchanged feature set. |

The number is declared in exactly one place, `autoload/version.gd`, and read
from there by everything that displays it. Nothing else contains a version
literal: the title screen reads `Version.display()`, the export workflow greps
the constant out of the file, and the parity suite asserts both the value and
its shape. A version written down twice is a version that disagrees with itself
the first time somebody bumps one copy.

## Status

A playable run with real pressure. You start with a name and $100, and the clock
does not stop.

The run opens on a title screen. NEW RUN leads through name entry into a fresh Day 1
in Spenard. From there: work a legitimate job or one of five criminal surfaces, move
between three districts, hire crew and pay their wages, take corners and post soldiers
on them — while rent, the phone bill and Curtis's attention all advance on their own
schedule. Miss enough rent and you are evicted, which ends the run.

Crime answers back. A blown lift holds the screen until you decide how to play it;
a bad enough answer ends in a booking, where you trade cash against calendar time
while rent and wages keep settling without you. The block remembers: work the same
hustle in the same district often enough and the odds there get worse, until you
change districts, change hustles, or slow down. And the people you rob can send
somebody after you two days later, in the part of town you did it in — though the
block starts talking about them first, if you are standing where they are.

A new run shows only what it has earned. The Market snapshot, Turf & Crew, the Crew
panel, Jobs and the two districts past Spenard all start locked — greyed, with one
line saying what opens them — and Tonight's Operation, the text card and the activity
feed are not on the screen at all until there is something in them. The gates are
authored in one table (`autoload/surface_visibility.gd`), evaluated by the shared
requirements engine, and enforced on the ROUTE as well as the button, so there is one
answer to "may the player go here" no matter who asked. Nothing about an unlock is
stored: every verdict is derived from the run's own facts, which is why unlocks
survive a save without a migration.

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
| Get caught mid-lift and choose how to play it | automatic, on a blown Boost |
| Get booked, and trade cash against calendar time | automatic, when an answer goes badly enough |
| Watch a district start recognising your routine, and cool off when you stop | Boost · Stickup · Market — LOCAL ATTENTION |
| Have the people you robbed find you days later | automatic, in the district you did it in |
| Hear the block warn you they are coming, and hear it stop when you leave | Activity feed · Phone |
| Pay a formal bill in street money and draw attention for it | automatic, on rent · phone · bail |
| Lend at interest and decide what a default costs | Hustle → Shark |
| Hire crew, pay wages, watch loyalty, move them up the ranks | Street → People → Crew |
| Give Pherris the day to work the board, and get the money back at night | automatic, once she is Trusted enough |
| Hear from her when she can do it, what she took, and how the night went | Phone · Activity feed · Home · Hustle |
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

Venue interiors, tactical combat, equipment, and court/trial/prison simulation.

**The consequence-encounter engine is complete.** FS-003 closed with FS-003.12:
a blown lift or a bad robbery now runs all the way from the action, through a
blocking encounter you cannot navigate away from, into an arrest, a bail
decision, time served while the world keeps moving, and — days later, in the
same part of town — the people you robbed finding you.

**FS-001 Crew Operations is closed.** FS-001.10 was its exit gate: the migration
chain walks v5 to current, a night replayed from a save lands identically, one
dispatch is one refresh, and a thirty-day economy simulation says what delegation
is worth. Delegation beyond Pherris and the 907List board was never in the
milestone; what shipped is the whole vertical slice, end to end.

The milestone still ahead is **FS-002 Territory Warfare**.

### What FS-003 delivered

| Slice | What shipped |
| --- | --- |
| .1 · .2 | Behaviour freeze, then the night as a declared sequence rather than signal-connection order |
| .3 · .4 | `WalletSystem` and `HeatSystem` as the sole writers, with automated writer audits; save v8 |
| .5 · .6 | One blocking chain with exactly-once receipts and a queue; pure odds projection |
| .7 | Failed Boost → Caught: contested take, Fight/Run/Talk/Yield, persistent store bans |
| .8 | `ArrestSystem` — severity, bail, priors, processing time, booking, release |
| .9 | District Pressure and Financial Pressure lifecycle; district Heat scaling live |
| .10 | Retaliation scheduling and the `retaliation_street_crew` encounter |
| .11 | Consequence UX, Local Attention, and the hidden-information audit |
| .12 | Integration gate: TI-003 §23 scenarios, migration matrix, 30-day RNG non-drift, long-run simulations |
| .13 | Balance pass: Pressure recovery, arrest cooldown, Financial Pressure activation, ambient retaliation signals; save v9 |

### What FS-003.13 tuned

The consequence loop worked and read as monotone. `.13` moved constants, not
mechanics — the simulation harness gained two profiles first, so the moves could
be measured rather than argued about.

| Constant | Where | Was | Now |
| --- | --- | --- | --- |
| `PRESSURE_QUIET_RECOVERY` | `data/consequence_rules.gd` | 1.0 | 1.5 |
| `PRESSURE_QUIET_GRACE_DAYS` | `data/consequence_rules.gd` | 1 | 0 |
| `PRESSURE_ACCELERATED_RECOVERY` | `data/consequence_rules.gd` | — | 2.0 while HOT |
| `STICK_FAILURE_ARREST_HEAT` | `data/consequence_rules.gd` | 10 / 8 / 6 | 12 / 10 / 8 |
| `ARREST_COOLDOWN_DAYS` | `data/consequence_rules.gd` | — | 2 |
| `FINANCIAL_PRESSURE_FREE_DIRTY` | `systems/wallet.gd` | $400 | $200 |
| `FINANCIAL_PRESSURE_PER_DOLLAR` | `systems/wallet.gd` | 0.01 | 0.015 |
| `FINANCIAL_PRESSURE_FOLD_AT` | `data/consequence_rules.gd` | 6 | 4 |
| `RETALIATION_AMBIENT_LINES` | `data/consequence_rules.gd` | — | five authored lines |

Two behavioural additions ride with them, both signals rather than mechanics:

- **The post-arrest cooldown.** For two days after a booking commits, no arrest
  gate fires — the same precinct does not pick you up on the way out of its own
  parking lot. It is stamped on `arrest_record.cooldown_until_day` and applied
  by Boost and Stickup *after* their own authored gates, so the gates keep their
  meaning and the cooldown can only ever turn a yes into a no.
- **Ambient retaliation warnings.** While a threat is queued in the district you
  are standing in, the activity feed carries one line a day — *"Same car passed
  the lot twice."* It stops when you leave, when the threat surfaces, or when it
  expires. The first time a run ever avoids a threat into expiry, the Phone
  carries a one-time callback. Neither ever names a day, a count, or the actor:
  PX-003 §8 keeps the window hidden, and the parity suite audits the copy for it.

`day_lifecycle.gd` gained a third `DAY_START_ORDER` step, `retaliation_ambient`,
appended after `surface_delayed`. Nothing above it moved. Save schema is **v9**:
one additive field, `consequence_flags`, for the consequence layer's run-level
one-shot flags. The arrest cooldown needed no field of its own — it rides inside
`arrest_record`, which v8 already persisted whole.

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
  version.gd          # the build version, declared once and read everywhere
  surface_visibility.gd # the access layer: which surfaces are earned, and which exist

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
  day_lifecycle.gd    # the night sequence, in declared order rather than by accident
  wallet.gd           # the only writer of cash; clean/dirty provenance
  heat.gd             # the only writer of heat; district x family scaling, relief
  consequence_engine.gd # one blocking chain, receipts, the delayed queue, Pressure
  arrest.gd           # severity, bail, priors, processing time, the record
  retaliation.gd      # the delayed answer: schedule, ambient warnings, street crew
  list_adapter.gd     # Pherris running the board: what she buys, and why she stops
  requirements.gd     # pure eligibility evaluator — structured blockers, no state
                      # (the ONE gate language: progression gates author records
                      #  for it, they do not bring their own condition engine)
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
  Thirty simulated days say it holds: sixty delegated cycles produced zero
  flips, zero Intelligence and zero tier progress, against an identical solo run.
- **Delegation talks back through channels that already exist.** Discovery, the
  morning acknowledgement, the nightly report and the loyalty complaint go out
  through `phone.push_message()` and `GameState.activity_log` — there is no
  notification system and no tutorial layer. Which template fires is decided by
  the result, never authored per outcome, and the one-shot flags live inside
  `crew_operation_state` so none of them costs a schema bump.
- **The night runs in a declared order.** `day_lifecycle.gd` owns the whole
  transition — settle against the ending day, move the clock, walk the market,
  start the new one — as a list a test reads, not as five `day_crossed.connect()`
  calls whose order is a side effect of construction. Reordering a phase is now
  a deliberate edit that breaks an ordering test.
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
| 5. Behavioral parity harness vs the JS oracle | ✅ core — RNG primitives, the canon market walk, and the save round-trip enforced in CI (11,110 checks at v0.1.0, floor enforced at 11,000); fixtures grow with each system |
| 5b. Phone + More screens | ✅ Phone (substrate + screen), More, Help — every nav cell has a screen |
| 5c. Attributes | ✅ substrate + Character screen — three surfaces unpinned, growth live, Street Identity derived |
| 5d. Recovery | ✅ treatment ladder + Lay Low — all six More rows ship |
| 5e. Tiered outcomes | ✅ shared resolver + Stickup/Jobs/907List converted; parity 2399 → 6628 checks |
| FS-001.2. 907List ownership | ✅ same-day opportunity consumption, Curtis volume filter, save v6; parity → 6702 checks |
| FS-001.5. Crew extensibility | ✅ rank labels, rank-curve clamp, shared requirement evaluator; parity → 7121 checks |
| FS-001.6. Crew operations | ✅ day-ending lifecycle + delegation substrate, save v7; parity → 7211 checks |
| FS-001.7. Run the Board | ✅ Pherris buys and settles on her own day; parity → 7308 checks |
| FS-001.8. Player experience | ✅ the delegation slice is playable from the existing screens; parity → 7400 checks |
| FS-001.9. Narrative continuity | ✅ discovery, assignment, settlement and loyalty callbacks through Phone + feed; Home/Hustle contextual surfaces; parity → 10499 checks |
| FS-001.10. Integration gate | ✅ v5→current migration chain, replay from a save, one-refresh contract, 30-day economy simulation, 375×812 UI regression; **FS-001 closed**; parity → 10609 checks |
| FS-003.1. Consequence freeze | ✅ consequence-adjacent behavior pinned as regression fixtures; parity → 7665 checks |
| FS-003.2. DayLifecycle seam | ✅ night settlement is a declared sequence, not signal-connection order; parity → 7726 checks |
| FS-003.3. Wallet + Heat owners | ✅ every runtime Cash/Heat write routes through one owner, with automated writer audits; parity → 7889 checks |
| FS-003.4. Consequence state | ✅ TI-003 §5 state persisted, save v8, v7 aggregate Cash migrates to Clean; parity → 8036 checks |
| FS-003.5. ConsequenceEngine core | ✅ one blocking chain with receipts, stage machine, queue arbitration and a blocking scene navigation cannot bypass; parity → 8267 checks |
| FS-003.6. Odds projection | ✅ pure `success_probability` / `tier_probabilities`, proved against the resolver over 4000 keys per cell; parity → 8785 checks |
| FS-003.7. Failed Boost → Caught | ✅ first end-to-end encounter: contested take, Fight/Run/Talk/Yield, bans, arrest handoff, source time settles once; parity → 9100 checks |
| FS-003.8. Arrest + Booking | ✅ one owner for severity, bail, priors, processing time and the record; both source gates feed it; parity → 9440 checks |
| FS-003.9. Pressure lifecycle | ✅ District Pressure bands/bleed/recovery, Financial Pressure decay and ≥6 Heat fold, district Heat scaling live; parity → 9637 checks |
| FS-003.10. Retaliation | ✅ the delayed path: schedule, dedupe, Day +2/+5 window, district presence, arrest suppression, Dirty-only loss; parity → 9905 checks |
| FS-003.11. Consequence UX | ✅ qualitative odds, arrest warnings, exact deltas, return routes, Local Attention on Boost/Stickup/Market; parity → 10044 checks |
| FS-003.12. Integration gate | ✅ TI-003 §23 scenarios, save migration matrix, 30-day market non-drift, seeded long-run simulations; parity → 10211 checks |
| FS-003.13. Balance pass | ✅ Pressure recovery, arrest gates + cooldown, Financial Pressure activation, PX-003 §8 ambient signals, save v9; parity → 10611 checks |
| **v0.1.0. Playtest polish** | ✅ build versioning, the surface-visibility access layer (progression gates + feature flags), the seeded-key composition audit, the HOT escape lever, the Phone tap-target fix and the canonical location rename, save v10; parity → 11,110 checks, floor at 11,000 |
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

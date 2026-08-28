# 907Hustle — Godot

A **Godot 4.7.2** production build of *907Hustle: One Good Run* — a mobile-first
(375×812, portrait) street-sim set in Anchorage's Spenard district. Approved
ClickUp specifications and the current Godot architecture are authoritative.
The frozen React v1.35 build is historical parity reference material only.

**Play it: https://davonlemar30.github.io/907Hustle-godot/** — rebuilt on every merge
to `main`. Roughly a 13MB first load, cached after.

> Living build notes with the full detail live in [`HANDOFF.md`](HANDOFF.md).

## Version

**Current: `0.1.2`** — shown bottom-right on the title screen, and stamped into
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

## What's new in 0.1.2 — "She Said Get a Job"

*Five PRs, one release. Full technical detail in [`CHANGELOG.md`](CHANGELOG.md)
and [`docs/BUILD_LOG.md`](docs/BUILD_LOG.md); this is the short version.*

**A new opening.** Yalonda introduces the run now instead of a standalone
title-screen slideshow — you meet her in scene, same beats, less clicking.

**The home screen keeps its secrets a little longer.** Turf and Crew don't
show up greyed-out on day one anymore — they stay off the board entirely
until you've earned them, same as Market and Boost already did.

**Finding something now feels like finding something.** A new job, a Lift
target, or the Street Market turning up on a walk gets an actual card, not a
toast that scrolls past before you read it.

**Your crew texts you now.** Word gets around. Recruit Pherris and some
mornings she'll text the best market route before you've checked yourself.
Recruit Eli and he'll tell you which side of town is quiet today. Nobody on
your crew ever burns you — and most days, nobody has anything worth
texting about. That silence is on purpose.

**Getting caught is a scene now, not a coin flip.** Tier 2-3 stickups — the
till, the register, the dice game, Goodie's stash — play out as staged rooms:
bank what you've got and go, or push for more. And Boost's caught state has
real outs: talk your way clear, buy off the store (once, ever, per store), or
just hand back what you took and walk — no clean roll, but no charge either.

**Some nights are fat nights.** Every so often Tone hears about a room
that's flush that same night. Hit the window he names and the take doubles,
sometimes better. Miss it and it's just a normal night.

**Up next:** Stickup and the Lift are two versions of "take something that
isn't yours." The next build starts folding them into one ladder — SCORES —
petty theft up through organized crew work, one progression instead of two.

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

A new run shows only what it has earned, and Day 1 is nearly bare on purpose. Turf &
Crew, the Crew panel, Jobs and the two districts past Spenard start LOCKED — greyed,
with one line saying what opens them. Everything else is simply not there: the Market
snapshot until a first flip, Tonight's Operation and the text card and the activity
feed until they have something in them, and five of the Hustle hub's six income rows
until the run has earned them. Walking the block turns up the corner you buy from on
the first walk and the doors worth trying on the third; days passing bring the board,
the desperation and the man who lends. Jobs keeps the only padlock on that screen,
because it is the one on-ramp the player is meant to know about and go looking for.

The gates are authored in one table (`autoload/surface_visibility.gd`), evaluated by
the shared requirements engine, and enforced on the ROUTE as well as the button — all
seven gated surfaces, so a deep link, a menu row and a hub row cannot disagree about
whether you may go somewhere. Nothing about an unlock is stored: every verdict is
derived from the run's own facts, which is why unlocks survive a save without a
migration.

And the game says when a door opens. A hidden surface has no padlock to watch, so the
run is told once, in the feed, the moment one arrives — detected by diffing what was
open before an action against what is open after it, inside the action that caused it.
There is no "already told them" flag anywhere, which is what keeps loading a save from
announcing a ladder the player climbed a fortnight ago.

And the route is findable. Buying in one district to sell in another is the only
strategy in the game that clears the day job, and until now nothing on any screen could
show you a price in a district you were not standing in — the Market row's "SELL SHIP
CREEK +$11" was authored text, true on the day it was written and stale every night
after. It reads the real board now, and Word Around Town carries what people say things
are going for elsewhere. Both need the phone bill paid, which is the first thing in the
build that $75 has ever bought.

Crime is now priced. The courier route — buy cheap in one district, carry, sell dear in
another — used to move hundreds of units for exactly zero Heat and land at nearly four
times the day job's net worth, against a design position that says smart crime should
approach the job and never beat it. A sale writes Heat now, scaled by what it was worth
and by which district it happened in; a corner that has watched you all week pays less
for the next handoff; and a trip taken holding can be stopped, with the bag being what
you lose. The route still pays — that is the point of it — but it pays for itself.

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
| Lift stock from rooms that may be watching — once you have clocked them | Hustle → Boost |
| Notice a room worth trying, and put it on your own map | Home → LOOK FOR A DEAL |
| Rob marks for fast money and real Heat | Hustle → Stickup |
| Play a staged room on the till, the register, the dice game, or Goodie's stash — bank what you've got or push for more | automatic, on a tier 2-3 stickup |
| Have it go clean, messy, wrong, or badly wrong | automatic, on any risky action |
| Get caught mid-lift and choose how to play it — talk your way clear, buy off the store, or hand back what you took | automatic, on a blown Boost |
| Get booked, and trade cash against calendar time | automatic, when an answer goes badly enough |
| Hear from Pherris and Eli when they have something worth texting about, and hear nothing most days | Phone |
| Catch a fat-night window from Tone and double the take if you hit it in time | automatic, on a rare stickup tip |
| Watch a district start recognising your routine, and cool off when you stop | Boost · Stickup · Market — LOCAL ATTENTION |
| Carry Heat and have it cost you: a night with lights behind you, and money gone | automatic, above WATCHED |
| Cool off by having a day nobody has to hear about | automatic, on any day that generates no Heat |
| Have the people you robbed find you days later | automatic, in the district you did it in |
| Hear the block warn you they are coming, and hear it stop when you leave | Activity feed · Phone |
| Pay a formal bill in street money and draw attention for it | automatic, on rent · phone · bail |
| Lend at interest and decide what a default costs | Hustle → Shark |
| Hire crew, pay wages, watch loyalty, move them up the ranks | Street → People → Crew |
| Give Pherris the day to work the board, and get the money back at night | automatic, once she is Trusted enough |
| Hear from her when she can do it, what she took, and how the night went | Phone · Activity feed · Home · Hustle |
| Give Eli the day to cover the bag, and get stopped less carrying it | automatic, once he trusts you |
| Give Deshawn the day to work a corner, and watch its Pressure come down | automatic, once he trusts you |
| Take a smaller wound because Tone was standing there | automatic, once he is on the crew |
| Train Combat at the gym, and carry three days running into the next check | Street → Spenard Gym |
| Find out the Night Owl counter is short evenings, and pay a bill in cash | Street → Night Owl |
| Claim corners, post soldiers, collect nightly | Home → Turf |
| See what each character knows and makes of it | Home → People |
| Rent, phone bill, eviction | automatic, on day-cross |
| Go out looking for work, for a deal, or just to read the block | Home → the three wander buttons |
| Be told what the walk actually turned up, rather than that you walked | automatic, on any wander |
| Send Eli out or go quiet, without waiting for an operation to exist | Home → WHAT ELSE |
| Be told, once, when a new way of earning opens up | Activity feed, on the action that opened it |
| Be told where you woke up, what is owed, and what to do first | the opening, once per run |
| Put a soldier on a corner and collect from it every night | Home → Turf |
| Learn what a corner is hot for, and whether anyone has started watching you | Home → SEE WHO IS OUT |
| Turn up work nobody told you about by walking the block | automatic, on a wander |
| Get stopped on foot and decide what to do about it | automatic, above WATCHED |
| Read texts, pay bills, hear word around town | Phone |
| Reach everything else, and read the rules | More · More → Help |
| See what the block calls you, and why | More → Character |
| Patch yourself up, or go quiet for a night | More → Recovery |
| Texts arrive; miss the bill and the line dies holding them | Phone → Texts |
| Pick up where you left off | automatic autosave · title → CONTINUE RUN |

### Not built yet

Tactical combat, equipment, gambling, and court/trial/prison simulation.

Two of the four Spenard venues have interiors as of batch 7 — the **Spenard
Gym** and the **Night Owl**. The other two are deliberately still cards. **The
Nile** needs a gambling system that does not exist: what is in the build for it
is the resolution half only, three callerless outcome shapes with no economy,
stakes, opponents or screen under them, and its NPC is not on the Exposure
roster. A **Home** interior would duplicate the Home nav tab wholesale, and its
one distinctive obligation — rent — is already payable from the Phone.

**The economy is measured, asserted within corridors, and the instrument is now
trustworthy.** A leaked test catalogue had been corrupting every economy figure
since batch 3; batch 9 closed it and re-measured. Against a day job at 100%,
the 907List flipper reads 358% and the trade-plus-job hybrid 732%, while Boost
sits at 13% and Stickup at 2%.

**"Wandering reads 288% — the strongest clean path" was true for one batch and
is retracted here rather than left standing.** It was measured before Territory
had ever been played by a profile in this table (batch 17) and before Territory
had a recurring cost (Batch 18 PR 4, D-1). With both: Territory reads **409%**
of the day job — six corners, staffed, paying every night and costing
$20/soldier/night to keep staffed — and is the actual strongest clean path.
Wandering itself reads 287%, close to its old number and still real, just no
longer the ceiling. Every percentage in this section is now asserted within a
floor/ceiling corridor (`ECON_CORRIDORS` in `tests/parity/parity_runner.gd`),
not a bare `print()` — see `HANDOFF.md`'s orientation table for the full
current figures. The weak surfaces (Stickup, Boost) are filed as design
findings with the evidence in `docs/DECISIONS.md`, not tuned in flight.

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

Batches 6a and 6b then spent that slice. 6a moved the delegation COPY out of the
coordinator and into the adapters, so a second operation costs no edit to shared
code and no save-schema bump. 6b added the second and third: Eli covering the
bag on the carry roll, Deshawn taking Pressure off a corner. Tone, who had been
on the roster since the port began without changing a single number, now absorbs
damage at both sites that deal it. Three of the four crew members the game has
always shown you now do something.

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
  screen_manager.gd   # the only thing that swaps screens; also toasts + the
                      # flow-sheet queue (discovery cards, the Yalonda intro)
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
  confrontation_loop.gd # the multi-round chassis shared by every KIND_CONFRONTATION
                      # chain: verb burning, round log, the tip-payload seam
  tips.gd             # Word of Mouth: the day-start tip generator (Pherris'
                      # route push, Eli's corridor read, Tone's fat-night window)
  arrest.gd           # severity, bail, priors, processing time, the record
  retaliation.gd      # the delayed answer: schedule, ambient warnings, street crew
  list_adapter.gd     # Pherris running the board: what she buys, and why she stops
  runner_adapter.gd   # Eli covering the bag: which exits nobody watches
  fixer_adapter.gd    # Deshawn working a corner: Pressure off every family on it
  requirements.gd     # pure eligibility evaluator — structured blockers, no state
                      # (the ONE gate language: progression gates author records
                      #  for it, they do not bring their own condition engine)
  territory.gd        # corners, soldiers, passive income
  venues.gd           # the two Spenard interiors: gym sessions, the counter
  wander.gd           # going out and looking: the ramp, the draw, the encounter

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
tests/save_validation/# CI gate: adversarial nested-save shapes through the real
                      # load-time validator; load-only, never writes a save
tests/territory/      # CI gate: FS-002's own suite. Seconds, not the parity
                      # runner's ten minutes, which is why it is separate
  territory_asserts.gd         # the shared helper every FS-002 slice reuses,
                               # incl. the market-RNG non-drift assertion;
                               # confrontation and tips reuse it too
tests/confrontation/  # CI gate: the confrontation loop's own suite (tier
                      # boundaries, verb burning, the guaranteed out, BRIBE,
                      # HAND IT BACK), on the shared territory asserts
tests/tips/           # CI gate: Word of Mouth's own suite (seeded determinism,
                      # the budget ramp, each generator's gating, a fat-night
                      # payload consumed by a driven room), same shared harness
tests/smoke/          # CI gate: every screen instantiates WITH its script
                      # attached, and refreshes without raising
```

```
data/                  # authored tables the systems above read; no state, no autoloads
  consequence_rules.gd # odds, bands, Pressure constants, arrest gates
  confrontation_scripts.gd # every authored room/scene script, incl. the Lift's
                      # caught-loop beats + bribe rows, and TIP_MODIFIERS
  tip_events.gd       # Word of Mouth's budget ramp numbers (base/per-miss/cap)
  wander_events.gd    # the discovery ramp + card pool Wander draws from
  territory_definitions.gd # the authored board: corners, adjacency, capacity
```

### The six gates

All six run in CI on every push and pull request, and all six are green on
`main`. The `--script` form does **not** exit in this project; use the scene.

```bash
godot --headless --path . --scene tests/parity/parity_runner.tscn
godot --headless --path . --scene tests/save_validation/save_validation_runner.tscn
godot --headless --path . --scene tests/territory/territory_runner.tscn
godot --headless --path . --scene tests/confrontation/confrontation_runner.tscn
godot --headless --path . --scene tests/tips/tips_runner.tscn
godot --headless --path . --scene tests/smoke/screen_smoke.tscn
scripts/check_glyph_coverage.py
```

Each harness prints its own `<name>: PASS` line and CI greps for it, because a
Godot run that dies part-way still exits 0. CI additionally fails any run whose
log carries `SCRIPT ERROR` or `Invalid access`: a PASS line only says the checks
that RAN all passed, and `screen_smoke.gd` calls `refresh()` while ignoring
every error it raises.

Current counts: parity 12,533 · save-validation 151 · territory 169 ·
confrontation 212 · tips 93 · smoke 23/23 screens.

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
- **A multi-round confrontation is a fifth `ConsequenceEngine` chain kind, not
  a second engine.** `confrontation_loop.gd` is the chassis every source
  adapter shares — round bookkeeping, verb burning, the round log, and the
  tip-payload read (`tip_modifiers_for`) — so a stickup room and the Lift's
  caught loop cannot drift on the rules that make the loop one machine. Round
  state persists inside the chain's own `decision` block rather than
  replaying from round one on reload, a deliberate divergence from the
  original build brief: a reload has to show the decision the player was
  actually looking at, snapshotted odds included.
- **A day-start generator is a declared step, not a signal listener.**
  `day_lifecycle.gd`'s `DAY_START_ORDER` is a literal array a test reads back;
  adding Word of Mouth's tip generator meant appending `"tips"` to that array
  and one `match` arm, the same shape every other day-start step already
  used. Nothing subscribes to `day_crossed` on its own to decide when it runs.
- **A tip is a claim about state the simulation already tracks, never a
  second roll wearing a name.** Two of Word of Mouth's three generators
  (Pherris' route, Eli's corridor) are pure reads with no side effect at all;
  only Tone's fat-night window writes a payload, and it writes to a seam
  (`ConfrontationLoop.tip_modifiers_for`) the confrontation loop was already
  reading defensively before Word of Mouth existed — the field arrived as
  data, not as a new read path.

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
| 5. Behavioral parity harness vs the JS oracle | ✅ core — RNG primitives, the canon market walk, and the save round-trip enforced in CI (**12,499 checks** after batch 17, floor enforced at 12,489). Save-validation and screen-smoke are CI gates too as of batch 12; the smoke gate also proves each screen's script actually attached, as of batch 15 |
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
| Batch 1. Hardening | ✅ crew/shark settle against the ending day (canon), every persisted Exposure/Curtis mutator behind the dispatch guard, standing guarantees for the 907List board fill and the crew-capacity accessor; parity → 11,147 checks |
| Batch 2. The settlement contract | ✅ the four audited day-cross ordering dependencies documented in `time_system.gd` and asserted (one of them had silently inverted); three playtest findings verified as not reproducing and pinned so they cannot start; parity → 11,177 checks |
| Batch 3. The risk term | ✅ the economy instrument (five profiles × four seeds, measuring the trading path against the day job for the first time) and the risk term it made possible — a sale writes Heat, a watched corner pays less, and a trip taken holding can be stopped. The pure courier route goes **384% → 90%** of the day job. Parity → 11,248 checks |
| Batch 4. The stickup ladder | ✅ `stick_tier` was written exactly once in the whole repo (`= 1`, at reset) and `stick_rep` was counted and read by nothing, so four of nine authored stickup targets — including both biggest paydays — were unreachable for a run's whole life. Rep now climbs the ladder. The criminal surfaces are also measured against the day job for the first time. Parity → 11,273 checks |
| Batch 5. The route, made visible | ✅ the one profitable strategy in the game had no surface anywhere that could see it. The Market row's route line is live off the real board instead of an authored string, Word Around Town carries what product is going for elsewhere, and both go dark when the phone bill goes unpaid — the first thing the $75 has ever bought. Parity → 11,311 checks |
| Batch 6a. The operation substrate | ✅ every delegation string was a const on the coordinator, which is why there could only ever be one operation. Copy is adapter-supplied now, with a `params` passthrough so an operation can be given a target. Plus three honesty defects in batch 5's route line. Parity → 11,330 checks |
| Batch 6b. Tone, Eli, Deshawn | ✅ three crew members who had been on the roster since the port began without changing a single number now each do one thing. Tone absorbs damage at both sites that deal it; Eli covers the carry; Deshawn takes Pressure off a corner. The callback flags were global, so only the first operation discovered would ever have spoken. Parity → 11,402 checks |
| Batch 7. Venue interiors | ✅ two of four Spenard venues open, chosen by what they front: the Gym reaches a nine-source growth table that had exactly one caller, the Night Owl reaches a job that was in the data with nothing able to discover it. `effectiveAttribute` and the gym streak ported. The Nile needs a gambling system; Home would duplicate the nav tab. Save v11; parity → 11,493 checks |
| Batch 8. Heat gets teeth | ✅ Heat was a one-way ratchet with nothing on either end — no decay, nothing at the ceiling, and getting arrested was the cheapest sink in the game. Four bands, a quiet-day decay, a nightly street stop above WATCHED, Lay Low capped once a day, and a propagation bug where crossing Heat 12 stopped the household hearing at all. Save v12; parity → 11,576 checks |
| Batch 9. Balance pass | ✅ **the economy instrument had been lying since batch 3** — a batch-1 check leaked a one-item 907List catalogue and `reset_to_new_game` restored none of the ten authored tables, so `flipper` read 4% when it is really 358%. Class closed. Stickup measured as under-powered on its own terms (a crew-backed profile makes no difference) and filed. Parity → 11,622 checks |
| Batch 10. Wander | ✅ Home's `MOVE PRODUCT` button was canon's `explore_spenard` — Wander — priced correctly and wired to `advance_time` plus "Time passes." The ramped discovery, the card registry, a fourth consequence chain kind, and two jobs nothing in the build could ever find. Save v13; parity → 11,723 checks |
| Batch 11. Wander follow-ups | ✅ an adversarial read found five shipped defects: four of five encounter choices rendered an empty description, the ramp and its validator disagreed, the toast talked over the encounter, a wander was the one way around the block nobody waiting could use, and which job you found was array order. Parity → 11,761 checks |
| Batch 12. Wander, measured | ✅ a slot-costing action had shipped unmeasured. A wandering worker reads **307%** of the day job on zero Heat and zero arrests. The first probe read 129% and was wrong — it found both jobs and kept clocking in at the car wash. The other two test harnesses became CI gates. Parity → 11,780 checks |
| Batch 13. Wander becomes a choice | ✅ 89.5 walks a run, 7 of 11 cards ungated flavour, and no decision anywhere in it. Three intents, a per-day effort falloff, and READ — five readers surfacing state the build tracks and had no window onto. Save v14; parity → 11,887 checks |
| Batch 14. The visibility pass, and Boost's second axis | ✅ the build showed everything at once and explained none of it. The Hustle hub opened with six income rows on Day 1; five now arrive on two earned axes (walks and days) and Jobs keeps the only padlock. The Home Market Snapshot went LOCKED → HIDDEN — a padlock over real product names and prices reads as a bug, not a promise. Wander says what it found instead of "You take a walk." POST ELI and LAY LOW came off the operation card the gate system hides for the whole of a fresh run. And Boost got a DISCOVERY axis: a room has to be clocked on a DEAL walk before it is liftable, which is the first thing that ever put a target BACK on that board. Measured: the profile that earns its board absorbs **7.5 permanent bans and still ends with rooms open**, against 3.5 bans and an empty screen for the one handed twelve targets on day one. Save v15; parity → 12,249 checks |
| Batch 15. The doors, and the news | ✅ an adversarial read of batch 14 and two defects older than it. **The More menu's Crew row never rendered** — `apply_surface_gate(…, _menu_row(…))` gated a card nobody had parented, so from v0.1.0 the row existed only in the comment arguing for it. **Two doors, two answers**: batch 14 gated five Hustle rows at the button and left the routes open, and `More → Finances` IS the Shark screen and opened on Day 1. **The clear-and-rebuild did not clear** — `queue_free()` is deferred, so a second refresh in one frame stacked every row (4 → 8 → 16), which had been quietly inflating this suite and was the only thing keeping one phone check green. And five surfaces arrived **silently**, so the announcer now says once, in the feed, when a door opens — detected by diffing a snapshot across the dispatch that caused it, which needs no persisted flag, no manifest entry and no migration. Plus the opening: one screen between naming yourself and the first morning, reading the rent and the date off GameState. Schema unchanged; parity → 12,441 checks |
| Batch 16. The door to work | ✅ **the Jobs screen was unreachable on a fresh run.** `menu.jobs` gated on `job_contacts`, which rose in exactly one way — recruiting Deshawn ($100 against a starting $100, then $50/day, with $150 rent on day 7). So "Meet someone who hires" asked the player to go broke to read it, while the run *starts* knowing five places that hire and `apply_job` works when called. Batch 10 had built a second path to work — walking the block until somebody mentions the freight yard — and the gate never learned about it, so you could be told about a job and not be let through the door to apply. A job you find yourself now counts. **Nothing caught it because no profile played the game**: every one dispatches actions directly, and a dispatch does not pass a surface gate, which is how the table came to call `worker_wanders` the strongest clean path at 287% for a path a real run could not take. The new `newcomer` profile plays only what the ladder has opened — measured with the fix at **458%** and without it at **262% with zero shifts in thirty days**, running the Heat ceiling and two arrests because crime was the only thing left open. Schema unchanged; parity → 12,467 checks |
| Batch 17. The corner, measured | ✅ Territory shipped in Phase 3e — six corners, soldiers, nightly income, nightly heat, and two districts gated behind holding one — and **no profile in the economy table had ever claimed a corner.** Every balance number this project has published, including "the strongest clean path in the build", was measured against a game with its territory system switched off. Played properly it reads **636% of the day job**: six corners, $2,660 in, **$9,081 out**, zero arrests. The reason it outruns everything is that it is the only earner in the build that **costs no slot** — neither `recruit_soldier` nor `claim_block` advances time, so it competes for money and never for the four hours a day everything else fights over. Reported, not tuned. Also pins the five-step chain that opens the map (soldier → idle soldier → corner → `held_blocks` → district), which nothing asserted at any step, and whose middle link — a claim is refused without a free soldier however rich you are — sent this batch's first probe to the wrong conclusion. Schema unchanged; parity → 12,499 checks |
| Batch 18 PR 0. The ground under the war | ✅ five live defects fixed (an unknown territory id silently killed nightly settlement; the parity suite could delete a developer's save; soldiers could exceed capacity; a screen wrote GameState outside dispatch; Territory's heat scaling relied on a dictionary-miss accident) plus the CI gates that protect everything after: the parity PASS grep it was missing, timeouts on every job, and a crash gate on `SCRIPT ERROR`/`Invalid access`. Parity → 12,499 checks (unchanged — behaviour-preserving) |
| Batch 18 PR 1. FS-002.1 | ✅ `tests/territory/` stood up as FS-002's own harness — seconds, not the parity runner's ~2 minutes — and closed a coverage gap: `post_soldier`/`pull_soldier` had never been dispatched anywhere, `block_income()` was asserted nowhere, and the diminishing-returns constant appeared in zero checks. 121 checks, new suite |
| Batch 18 PR 2. FS-002.2 | ✅ D-5: the shipped settlement order (`crew → territory → shark → jobs → obligations`) wins over a documented contract that had said the reverse for four batches with no test behind it. The bigger find: the stated REASON for crew-before-territory was false in four places — territory income does not read crew power at all; the real dependency is Deshawn's heat multiplier. Parity → 12,500 checks |
| Batch 18 PR 3. FS-002.3 | ✅ the one-way door: `held_blocks`/`spenard_blocks` retired for `territory_nodes`/`territory_fronts` off a new `data/territory_definitions.gd`. Save v15 → **v16**. D-6: a migrated holding is never confiscated, even where the new board calls it Curtis-secure. Found and fixed two real bugs chasing this down — a test-fixture object-aliasing bug in the migration chain, and a forward-referenced const that hung the parity suite for over an hour. Parity → 12,505 checks |
| Batch 18 PR 4. Territory's operating cost, D-1 | ✅ the only player-visible change in Build 18: a $20/soldier/night upkeep, charged on the full roster whether posted or idle. `settler` moves **636% → 409%** of the day job — 636% was the bug, not a floor worth defending. Every economy profile is now asserted within a floor/ceiling corridor instead of a bare `print()`. Parity → 12,524 checks |
| The Rooms — confrontation loop | ✅ tier 2-3 stickup targets play out as authored multi-round rooms (bank-or-push, TAKE AND GO, the exit fork) on a new fifth `ConsequenceEngine` chain kind, `confrontation`. New CI gate `tests/confrontation/`. Parity → 12,530 checks |
| **0.1.2. She Said Get a Job** | ✅ five PRs: Turf & Crew hide until earned; discovery gets a real card instead of a toast; Yalonda replaces the opening screen; the Lift's caught loop gets BRIBE and a same-day HAND IT BACK follow-up; Word of Mouth slice 1 (Pherris' route push, Eli's corridor read, Tone's fat-night window) on a new seeded day-start tip generator. Save v16 → v19. New CI gate `tests/tips/`. Parity → **12,533 checks**, floor `MIN_CHECKS := 12533` |
| 6. Cutover | — |

Full roadmap and the design-decision log live in the project's ClickUp master doc.
Standing rulings that have already been made are also recorded in
`docs/DECISIONS.md`, which is the faster read when the question is "has this
already been decided" rather than "what's the plan."

**The repo owns what the code does; ClickUp owns what we intend to build and
why. Where they disagree about shipped behaviour, the repo wins.** (Batch 18's
own studio pass found eleven cases of ClickUp or `HANDOFF.md` narrative
disagreeing with shipped code — five serious enough to call lying rather than
merely stale — which is the reason this rule is written down rather than
assumed.)

## Contributing

Feature branches per screen/system, opened as PRs against `main`. Follow approved
ClickUp specifications, current Godot design decisions, and reproducible Godot tests.
The frozen web build (`src/data/*`, `game-core.js`) may explain migration history or
legacy formulas, but it does not override a newer approved Godot decision.

**Documentation ships with the PR.** A `HANDOFF.md` entry and the relevant ClickUp doc
section are part of the change, not a follow-up. A PR that introduces a new system
carries its doc update in the same commit range.

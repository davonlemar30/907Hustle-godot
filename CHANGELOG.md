# Changelog

The game ships to a public URL on every merge to `main`
(https://davonlemar30.github.io/907Hustle-godot/) and had no release notes
until this file, added in Batch 18 PR 5 (`86bbjxtmr`).

Format loosely follows [Keep a Changelog](https://keepachangelog.com/); this
project does not cut version tags per merge, so entries are grouped by batch
instead of by version number. `autoload/version.gd` carries the one build
version string (currently `0.1.2`); it moves on its own schedule (MAJOR/MINOR/
PATCH per that file's own header), not once per entry here.

**This file starts at Batch 18, not at the beginning of the project.**
Backfilling every batch since Phase 3b in this format would duplicate
`docs/BUILD_LOG.md`'s narrative history in a second, thinner format — the
narrative entries there already say what changed and why, in more depth than
a changelog line can. This file is upkeep from here forward, not a rewrite of
what came before. For full history, see `docs/BUILD_LOG.md` (newest-first,
append-only) and `docs/DECISIONS.md` (standing rulings).

## 0.1.2 — She Said Get a Job (2026-08-28)

*Draft — this entry was written from the build's own record of what shipped,
not from an established patch-note voice sample, and is worth a pass before
it goes out under that voice.*

#### THE OPENING

Yalonda replaces the old title-screen opening. You meet her in the scene now
instead of clicking through a separate intro screen first — same beats,
delivered where the run actually starts.

#### THE HOME SCREEN

Turf and Crew don't show up greyed-out on day one anymore. They stay off the
board entirely until you've earned them, the same way Market and Boost
already did — and the game tells you the moment that changes instead of
leaving you to notice on your own.

#### DISCOVERY FEELS LIKE SOMETHING

Wander into a new job, a Lift target, or the Street Market for the first time
and it's not just a toast anymore — you get an actual card for it.

#### YOUR CREW TEXTS YOU

Word gets around now. Recruit Pherris and some mornings she'll text you the
best market route before you've even checked. Recruit Eli and he'll tell you
which side of town is quiet today — the safest road to carry through.
Nobody's crew ever burns you, and most days nobody has anything worth
texting about — silence is the point as much as the tips are.

#### GETTING CAUGHT IS A SCENE NOW

Tier 2-3 stickups — the Chevron till, the Holiday register, the dice game
behind the rec center, Goodie's stash — are staged rooms now, not one roll.
Bank what you've got and go, or push for more; a slipped stage forks into
running for it clean or running for it messy, and heat scales with how much
of the take you actually walked out with. Tier-1 marks are still one roll,
exactly as before, and WALK at the door still costs nothing.

Getting caught lifting has real outs now too: talk your way clear, settle up
with the store you got caught in (once a store, once a run), or just hand
back what you took and walk — no clean roll, but no charge either.

#### THE FAT NIGHT

Every so often Tone hears about a room that's flush — a specific target, a
specific window that same night. Hit it while the window's open and the take
doubles, sometimes better. Miss the window and it's just a normal night
again.

#### Next up

Stickup and the Lift are two versions of the same idea — "take something
that isn't yours" — and the next build starts folding them into one ladder,
SCORES: petty theft up through organized crew work, one progression instead
of two.

#### Added

- **Word of Mouth, slice 1** (`systems/tips.gd`): a day-start tip generator —
  Pherris' route push, Eli's corridor read, Tone's fat-night window — on a
  seeded drought ramp (roughly 40% of days carry nothing). New save fields
  `tip_effects`/`tip_misses` (schema v18 → v19). New gate suite
  `tests/tips/` (93 checks) in CI beside the other four.
- **The Lift's caught loop**: BRIBE (buy off a store, once per store per
  run) and HAND IT BACK (surrender the goods, no roll, no charge) as real
  outs from a caught chain, alongside the existing talk-your-way-clear path.
  New save field `boost_bribes_used` (schema v17 → v18).
- **Tier 2-3 stickups are multi-round rooms.** The take is split across
  authored stages, TAKE AND GO banks what you have and leaves, a slipped
  stage forks into DROP IT AND RUN versus RUN WITH IT, and leaving early is
  quieter — heat scales with the fraction you actually walked out with.
- **New gate suites** `tests/confrontation/` (212 checks) and `tests/tips/`
  (93 checks) in CI beside the other three.

#### Changed

- The consequence scene renders loop chains with a stage counter, a #LEFT
  chip, the banked amount, the current beat as the situation line, and a
  short SO FAR log.
- Three parity sections that drove tier 2-3 stickup dispatches now drive the
  rooms; their contracts (the arrest gate against pre-source Heat, the
  cooldown, retaliation scheduling by outcome) are unchanged.

### 0.1.0 Playtest Pass (2026-08-27)

Three UX PRs addressing findings from the first 0.1.0 playtest session.

#### Fixed

- **Opening screen beat cards overlapping** (PR #78): each beat card was a
  `PanelContainer` with two sibling Labels, but PanelContainer only lays out a
  single managed child. Inserted a VBoxContainer between each card and its
  labels. Added a staggered entrance animation (fade + slide, `create_tween()`).
- **Hustle screen permanently showing $312 "Today's Take"** (PR #79): the
  `todays_take` and `income_sources` fields were scaffold data no system ever
  wrote to. Replaced with `todays_earnings` Dictionary, a `record_earning()`
  helper called by all seven income systems after their wallet credit, and a
  `todays_take()` derived total. Resets at DAY_START alongside `heat_gain_today`.
  Persisted for mid-day save/reload (additive, no schema bump).
- **Market buy/sell hardcoded to quantity 1** (PR #80): the economy system
  already validated and executed any quantity; only the UI never asked "how
  many?" Now tapping BUY or SELL opens a bottom sheet with a live quantity
  stepper (capped at supply/cash/cargo for buy, holdings for sell), running
  total, and a CONFIRM button. Dispatch stays the sole authority.

#### Added

- `GameState.record_earning(source, amount)` — bookkeeping method for day-scoped
  income tracking. Called by jobs, economy (market sells), stickup, boost, shark,
  territory, and nine07list.
- `GameState.todays_take()` — derived total of today's earnings.
- Staggered tween entrance on the Opening screen (head, sub, beat cards, button).
- `ui/components/modal_sheet.gd` — reusable bottom-sheet overlay component
  (scrim, sliding/scaling card, swipe-down handle, `dismissed` signal,
  self-freeing). No Market-specific knowledge; designed for reuse by the
  encounter popup PR.

#### Gates

Parity 12,524 → **12,526** checks, 0 failures (floor raised; +2 from existing
round-trip loops walking one more PERSIST_FIELDS entry). Territory 169/0.
Save validation 114/0. Screen smoke 24/24.

## Batch 18 — the ground under the war, and Territory's missing cost

Five PRs. FS-002 slices .1–.3 (Territory's canonical state and save v16), a
live-defect pass, Territory's first operating cost, and the documentation
split this file is part of.

### Added

- Nightly soldier upkeep for Territory: $20/soldier/night, charged on the full
  roster whether posted or idle (D-1, `86bbjxtfa`, PR 4).
- Economy corridor assertions: every profile in the 30-day economy measurement
  now has a floor/ceiling asserted in CI, not a bare `print()` (`86bbjxth6`,
  PR 4).
- `data/territory_definitions.gd` — the canonical Territory board, replacing
  `GameState.spenard_blocks` (PR 3).
- `tests/territory/` — FS-002's own test harness, seconds rather than the
  parity runner's ~2 minutes (`86bbjxtjb`, PR 1).
- The first `save_validator.gd` arm for Territory state — the root-cause fix
  for an unknown territory node id silently killing nightly settlement
  (`86bbjxtab`, PR 3).
- `systems/run_start.gd` — routes starting a new run through
  `GameManager.dispatch()` for the first time; a new run now autosaves on
  creation (PR 0).
- CI: a crash gate failing any harness run whose log carries `SCRIPT ERROR` or
  `Invalid access`; `timeout-minutes` on every job; the parity job's own
  `PASS` grep, which it had been missing (`86bbjxthk`, PR 0).
- `docs/DECISIONS.md`, `docs/BUILD_LOG.md`, `docs/DESIGN.md`, this file — the
  documentation split (`86bbjxtmr`, PR 5).

### Changed

- **Save schema v15 → v16.** `held_blocks` (keyed off `spenard_blocks` display
  rows) becomes `territory_nodes` (keyed off canonical ids) plus
  `territory_fronts`, a Curtis-relationship ledger. Migration preserves every
  soldier and never confiscates a holding, even one the new board calls
  Curtis-secure (D-6).
- The day-cross settlement ordering contract in `HANDOFF.md` — documented
  wrong for four batches — now matches shipped `SETTLE_ORDER`. The stated
  REASON for the ordering (crew settles before Territory "because territory
  income is computed off crew power") was also false; corrected to name the
  real dependency, Deshawn's heat multiplier (D-5).
- `settler` economy profile: **636% → 409%** of the day job, reflecting
  Territory's new operating cost. 636% is preserved in `docs/BUILD_LOG.md`'s
  batch-17 entry as the finding that motivated D-1, not as a target.
- `HANDOFF.md`: split from 7,440 lines into a ~730-line living-reference file
  plus `docs/BUILD_LOG.md` (history) and `docs/DECISIONS.md` (rulings).

### Fixed

- An unknown territory node id no longer kills nightly settlement outright;
  `territory.gd` and `turf.gd` degrade gracefully and the new save-validator
  arm drops unrecognised ids on load (`86bbjxtab`).
- The parity suite could delete a developer's save file when it was unreadable
  (not merely absent) — the two cases are now distinguished (`86bbjxtaw`).
- Soldier count could permanently exceed capacity after abandoning a corner
  that had raised it; the excess now walks (`86bbjxtb6`).
- `name_entry.gd` wrote `GameState` directly, bypassing the dispatch-ownership
  guard on the largest single write in the build (`86bbjxtbm`).
- Territory's nightly heat gain passed an empty family string to the heat
  multiplier by accident of a dictionary miss rather than by a named rule;
  named explicitly as `HeatSystem.FAMILY_NONE` (`86bbjxtbm`).
- Five documentation findings classified "lying" rather than merely stale:
  the day-cross ordering contract (see above), README's retracted-but-still-
  present "wandering reads 288%" claim, `ASSET_MANIFEST.md`'s nav-icon list
  and delivery paths, and `SABOTAGE.md`'s stale check count and schema-version
  ceiling (`86bbjxtmr`).
- A self-referential off-by-one in `tests/territory/territory_asserts.gd`'s
  own check-floor mechanism, found while wiring PR 4's corridor checks.

### Known gaps, recorded rather than fixed

- **D-2 (the ending) is open, not answered.** No ending mechanic exists;
  nothing in Batch 18 forecloses one. See `docs/DECISIONS.md`.
- Two live defects were escalated as design rulings rather than fixed:
  Boost's tier-3 Run failure arrest (transcribes the approved spec exactly)
  and Pherris's rank-2 wage exceeding her delegated return (any fix is a
  tune). See `docs/DECISIONS.md`, "Escalations open as of Batch 18 PR 0."

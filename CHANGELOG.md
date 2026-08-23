# Changelog

The game ships to a public URL on every merge to `main`
(https://davonlemar30.github.io/907Hustle-godot/) and had no release notes
until this file, added in Batch 18 PR 5 (`86bbjxtmr`).

Format loosely follows [Keep a Changelog](https://keepachangelog.com/); this
project does not cut version tags per merge, so entries are grouped by batch
instead of by version number. `autoload/version.gd` carries the one build
version string (currently `0.1.0`); it moves on its own schedule (MAJOR/MINOR/
PATCH per that file's own header), not once per entry here.

**This file starts at Batch 18, not at the beginning of the project.**
Backfilling every batch since Phase 3b in this format would duplicate
`docs/BUILD_LOG.md`'s narrative history in a second, thinner format — the
narrative entries there already say what changed and why, in more depth than
a changelog line can. This file is upkeep from here forward, not a rewrite of
what came before. For full history, see `docs/BUILD_LOG.md` (newest-first,
append-only) and `docs/DECISIONS.md` (standing rulings).

## Unreleased

Nothing since Batch 18 PR 4.

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

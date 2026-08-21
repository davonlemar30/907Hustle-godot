# Godot Hardening Pass 01

Review branch: `codex/godot-hardening-pass-01`

Base: `main` at `c5e88af2a9cfd834efd6fbb654b797ecf9b60c16` (merged PR #35)

Review date: 2026-08-21

## Baseline

- Godot 4.7.2 headless import/resource parse: pass.
- Main scene headless startup: pass.
- Behavioral parity before changes: 6,628 checks, 0 failures.
- Glyph coverage: pass across all five theme fonts.
- `git diff --check`: pass.
- Local web export was not run because this machine had no 4.7.2 export
  templates; the draft PR's existing `build` job is the export gate.

The review brief named `0c80aff` as its starting snapshot. Current `main` had
advanced to `c5e88af`, adding PR #35's tiered outcome resolver and expanding the
fixture suite from 2,399 to 6,628 checks. The newer repository state was used.

## System Map

`GameManager` owns action routing. Economy, Travel, Jobs, Obligations, Phone,
Stickup, Shark, 907List, Boost, Crew, Territory, Attributes, Recovery, and the
Outcome Resolver write `GameState`. `TimeSystem` advances the clock and emits
`day_crossed`; Jobs, Obligations, Stickup, Shark, Crew, Territory, Exposure, and
Curtis settle in connection order. `SaveSystem` observes the one
`state_changed` notification emitted after a successful dispatch. Screens read
state and dispatch intent; `ScreenManager` alone changes scenes.

Gameplay randomness is split deliberately: keyed hashes for replay-stable
decisions and one persisted xorshift cursor for order-sensitive market walks.

## Findings

### P1 — Omitted legacy save fields inherited live-session values

- File/system: `autoload/save_system.gd`, save/load.
- Evidence: `_apply()` skipped every absent field. Its existing migration test
  explicitly reset `GameState` first because otherwise the current inbox leaked
  into a v2 load. The same affected v1 markets/RNG and every later additive
  field.
- Reproduction: dirty phone/attribute/Recovery fields, load a v2 payload that
  omits them, and observe the dirty values remain; dirty markets, load v1, and
  observe the wrong board/cursor remain.
- Resolution: build from a fresh `GameState` instance on every load, overlay
  fields present in the payload, then reconstruct pre-v2 markets from run seed.

### P1 — The only save was truncated before a write completed

- File/system: `autoload/save_system.gd`, autosave durability.
- Evidence: `FileAccess.open(SAVE_PATH, WRITE)` truncates the final file before
  `store_string()` completes. Process interruption or a failed browser-backed
  flush could leave no valid run.
- Resolution: write and flush `SAVE_TEMP_PATH`, then atomically rename it over
  the final path. A failed write leaves the prior save intact.

### P2 — Presentation mutated the Recovery persistence latch

- File/system: `ui/screens/more.gd`, state ownership/save ordering.
- Evidence: `_recovery_available()` assigned `recovery_introduced` while the
  screen rendered. `SaveSystem` is connected before screen instances, so the
  action's autosave had already captured state when the UI performed the write.
- Resolution: More now calls a pure `GameState.recovery_available()` selector.
  The action layer reconciles the latch before `state_changed`; loading does the
  same for legacy injured/high-Heat runs.

### P2 — Exposure queries created persistent state

- File/system: `autoload/exposure.gd`, read/write ownership.
- Evidence: `ledger_of()`, `disposition()`, and `everyone()` all reached a helper
  that inserted an empty array for missing NPCs. Opening Character/People or
  checking Recovery's doctor gate could mutate the persisted ledger without an
  action or notification.
- Resolution: reads return an empty non-persisted array; only
  `record_observation()` uses the creating write accessor.

### P2 — Malformed top-level saves could enter coercion paths

- File/system: `autoload/save_system.gd`, validation.
- Evidence: version and required fields were converted before their input types
  were validated.
- Resolution: invalid version, day, cash, and street-name types fail closed
  before any state is applied. Deeper per-system shape validation remains a
  follow-up.

## Changes Made

- Isolated every load from the current singleton's mutable values.
- Added atomic save replacement.
- Centralized the Recovery availability invariant in `GameState` and restored
  presentation-only behavior in More.
- Split Exposure's read and write ledger accessors.
- Corrected README/HANDOFF authority language: Godot + approved ClickUp decisions
  are current authority; the frozen web build is historical reference.

No gameplay formulas, balance values, RNG keys, stream draws, save fields, or
save-version numbers changed.

## Refactors

Each refactor protects one invariant:

- load result = declared defaults overlaid by the selected save, never live
  session residue;
- persistent latches settle before notification/autosave;
- queries do not create gameplay state;
- the previous valid save survives an incomplete replacement.

## Performance

No performance change was warranted. Production gameplay/UI scripts contain no
`_process()` or `_physics_process()` loops. The fresh default-state node is
allocated only during an explicit load, not on actions or frames.

## Tests Added

Thirteen regression checks were added, taking parity from 6,628 to 6,641:

- Recovery latch is set before notification, saved, and retained after the live
  trigger clears.
- Atomic save replacement leaves no temporary file after success.
- v2 phone, attributes, progress, and Recovery defaults defeat contaminated live
  state.
- v1 markets and RNG cursor rebuild deterministically and reject a live sentinel.
- malformed version and required-field types are refused.
- Exposure reads leave an empty ledger dictionary unchanged.

## Save Safety

Schema remains v5. Existing v1-v5 payloads remain readable. The migration chain
is unchanged; only default application is corrected. Current saves retain every
persisted field exactly, verified by the existing deep round-trip. Atomic replace
reduces interruption risk without changing the payload format.

Nested dictionaries and arrays still rely on consuming systems for detailed
shape assumptions. Add per-version structural validation before accepting
external/imported or user-edited saves.

## Determinism

No RNG implementation, key, call count, iteration order, or cursor ownership was
changed. The final 6,641-check suite passes with zero failures, including market
walk parity, outcome fixtures, save/reload replay, and explicit market-cursor
isolation.

## Claude Branch Overlap

No Claude branch was available in either local checkout or GitHub; GitHub exposed
only `main`, and there were no open PRs. Therefore no owned Claude files could be
identified. The review changes are limited to state/save plumbing, one Exposure
accessor, one UI selector, tests, and documentation.

Before merge, re-check any newly pushed Claude branch against:

- `autoload/game_manager.gd`
- `autoload/game_state.gd`
- `autoload/save_system.gd`
- `autoload/exposure.gd`
- `tests/parity/parity_runner.gd`
- `ui/screens/more.gd`

## Technical Debt / Follow-ups

- P2: Name Entry still assigns `street_name` directly and calls
  `reset_to_new_game()` outside dispatch. Move run creation behind one atomic
  action when the opening flow next changes.
- P2: Day-cross ordering is implicit in signal connection/autoload order. An
  explicit settlement pipeline would make future dependencies and autosave timing
  easier to prove.
- P2: Add nested save-shape validation for markets, ledgers, queue entries, loans,
  crew records, and phone messages.
- P4: `GameState` still combines large static content tables with mutable run
  state. Separate data resources when doing so serves an active feature, not as a
  cosmetic move.

## Gate

**APPROVE WITH FOLLOW-UPS**

The current Godot baseline is healthy and the verified save/state defects are
contained. Development can continue with the documented structural debt.

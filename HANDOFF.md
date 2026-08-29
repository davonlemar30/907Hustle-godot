# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-08-29. Living doc — update as screens land._

> **Floors are the RUNNER CONSTANTS, not this table.** This row set drifted
> once already (parity read 12,751 here against `MIN_CHECKS := 12763` in the
> file) because a close-out added checks and did not come back. Every suite row
> below now names the file its floor lives in. When they disagree, the constant
> is right.

> **This file is one of four.** `HANDOFF.md` (here) carries current, living
> reference — orientation, design system, canon tables, working notes, and the
> last few batches. `docs/BUILD_LOG.md` carries everything older, newest-first,
> append-only. `docs/DECISIONS.md` is the ADR — every standing ruling (`D-`
> numbers, the Build 5e divergences, open escalations), the one place a ruling
> gets recorded once rather than repeated at every reading. `docs/DESIGN.md` is
> the one-page answer to "what is this game and why."
>
> **The repo owns what the code does; ClickUp owns what we intend to build and
> why. Where they disagree about shipped behaviour, the repo wins.**

## What this is
907Hustle ("One Good Run") is a mobile-first (375×812), dark-theme street sim
being rebuilt from a React web app into **Godot 4.7.2** Control-node scenes,
driven through the **Godot AI MCP** (dlight plugin; server at
`http://127.0.0.1:8000/mcp`, configured in `~/.claude.json`).

- **Godot project:** `/Users/damusthadon/Documents/907HustleGodot/907-hustle-godot/`
- **GitHub:** https://github.com/davonlemar30/907Hustle-godot (PUBLIC, branch `main`)
- **Web source (historical parity reference, read-only):** `/Users/damusthadon/Documents/907HustleGame/907Hustle-game/` — useful for migration history and legacy formulas, but newer approved ClickUp/Godot decisions win.

## Where the build stands

One place to orient before reading anything else below.

| | |
| --- | --- |
| Build version | `0.6.0` — Squared Up: the street gets in your face, and it does not take the screen to do it (`autoload/version.gd`) |
| Save schema | **v25**, UNCHANGED by 0.6.0 — and that is the headline, not a footnote. The overlay is derived from the live chain (kind + stage) and never persisted; the verb roles, the room's beats, the observation rows and both corner triggers are all authored data or reads of fields the game already kept. `corner_stiff`'s once-per-district-per-day bound is derived from `add_market_pressure`'s own day-stamped counter rather than given a field. "Derive before you persist" paid for a whole build |
| Parity | **13,276 checks, 0 failures**, floor `MIN_CHECKS := 13276` (`tests/parity/parity_runner.gd`). **The number in this row was stale from 0.5.0 through to this build's PR F** — it read 12,751 while the runner read 12,763, because the 0.5.0 close-out added 12 checks and did not update this table. Reconciled here, and the lesson recorded: read the constant, never this row. 0.6.0's own movement: the route ladder asserted in both directions everywhere it used to be asserted in one (+54), the room's coverage rewritten from a re-rolled verb to per-beat (+19), and the eight-card roster's generic every-card-every-road arm (+436) |
| Territory suite | **170 checks, 0 failures**, floor `MIN_CHECKS := 170` (`tests/territory/territory_runner.gd`) — unchanged in 0.6.0 |
| Confrontation suite | **1,248 checks, 0 failures**, floor `MIN_CHECKS := 1248` (`tests/confrontation/confrontation_runner.gd`) — up from 251. Most of that is two STRUCTURAL sweeps added in PR B that iterate the card registry rather than driving one example each, so PR C's eight new cards brought ~500 checks with them without a line of new test code. That was the point: 0.5.0 shipped two of four cards with no guaranteed out on a chassis whose stated rule is one guaranteed out per round, and "an author remembered" is exactly the enforcement that failed |
| Tips suite | **93 checks, 0 failures**, floor `MIN_CHECKS := 93` (`tests/tips/tips_runner.gd`) — unchanged in 0.6.0 |
| Dre suite | **404 checks, 0 failures**, floor `MIN_CHECKS := 404` (`tests/dre/dre_runner.gd`) — unchanged in 0.6.0 |
| Save validation | **247 checks, 0 failures** (`tests/save_validation/`, no `MIN_CHECKS` — it asserts per-arm). +12 in 0.6.0 for SQ-D4's mid-round reload arm: a decision-stage chain reloads with its round, bank, burned verbs and snapshotted odds intact, and with NOTHING about the sheet persisted |
| Screen smoke | 23/23 screens instantiate **with their scripts attached**, **1101/1101 touch checks**, and — new in 0.6.0 — **67/67 component checks**. `ModalSheet` had shipped for two builds with nothing asserting it could be constructed at all; the suite now builds it, `encounter_sheet.gd` and `health_bar.gd` against a REAL live chain (not a stub summary) and runs the same TOUCH-D5 scroll-transparency walk over the result. That gap caught a real parse error inside a minute during PR A |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` |
| Screens | 23, unchanged in 0.6.0 — and this is the build where that stops being the whole story. Decision and result stages render through `ui/components/encounter_sheet.gd` into a `ModalSheet` over whatever screen the player was on; only booking and release still reach `consequence.tscn` |
| Systems | **37** registered in `GameManager` (0.6.0 PR D added `corner`) |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Wander encounter pool | **12 cards**, up from 4 (0.6.0 PR C). Three police (on-foot stop, vehicle search, warrant check), two addicts, seven general street. Every one declares all three SQ-D6 roles, and the suite asserts it |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **0.6.0** — six PRs off `BUILD_SQUARED_UP_PROMPT.md`: the encounter overlay (SQ-D1..D5, `#120`), the verb triad and the missing outs (SQ-D6..D9, `#121`), the street roster (POOL-D1, `#122`), the corner (SQ-D10, `#123`), the 907List meetup (SQ-D10, `#124`), and integration/close-out (2026-08-29) |

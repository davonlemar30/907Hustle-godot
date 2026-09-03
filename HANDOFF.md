# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-09-03. Living doc — update as screens land._

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
| Build version | `0.7.0` — Blow by Blow: the hit lands, the words fit, the street shows up (`autoload/version.gd`) |
| Save schema | **v25**, UNCHANGED by 0.6.0 and by 0.7.0. Interim results ride the persisted chain's own result block and the loop's note to itself (`loop.pending`); the validator's coercion leaves both alone. "Derive before you persist" paid for a second whole build |
| Parity | **13,346 checks, 0 failures**, floor `MIN_CHECKS := 13346` (`tests/parity/parity_runner.gd`). **The floor had never been raised to 13,281** — the constant read 12,836 at 0.6.0's close-out while this row and the changelog both said 13,281; a fresh run counted 13,281 and 0.7.0 PR A set the constant to it. Read the constant, never this row — and this time the constant was the one that was wrong |
| Territory suite | **170 checks, 0 failures**, floor `MIN_CHECKS := 170` (`tests/territory/territory_runner.gd`) — unchanged in 0.6.0 |
| Confrontation suite | **2,994 checks, 0 failures**, floor `MIN_CHECKS := 2994` (`tests/confrontation/confrontation_runner.gd`) — up from 1,266. Every road of every card and script rendered to the sheet and asserted free of the boost fallback (PR A), the interim result end to end with a driven walk holding every beat and exit to its authored number (PR B), the priced road blocked, paid dirty-first and receipted (PR D) |
| Tips suite | **93 checks, 0 failures**, floor `MIN_CHECKS := 93` (`tests/tips/tips_runner.gd`) — unchanged in 0.6.0 |
| Dre suite | **404 checks, 0 failures**, floor `MIN_CHECKS := 404` (`tests/dre/dre_runner.gd`) — unchanged in 0.6.0 |
| Save validation | **247 checks, 0 failures** (`tests/save_validation/`, no `MIN_CHECKS` — it asserts per-arm). +12 in 0.6.0 for SQ-D4's mid-round reload arm: a decision-stage chain reloads with its round, bank, burned verbs and snapshotted odds intact, and with NOTHING about the sheet persisted |
| Screen smoke | 23/23 screens instantiate **with their scripts attached**, **1101/1101 touch checks**, **54/54 component checks**, and — new in 0.7.0 — **88/88 panel checks**: every authored street card's decision sheet built against the real chain it opens, laid out, and read — the card's resting top leaves at least 35% of the viewport uncovered and every authored road's button sits inside the visible scroll rect. That arm caught a scrollbar-induced wrap the headless build could not see until the live rect read did |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` |
| Screens | 23, unchanged in 0.6.0 — and this is the build where that stops being the whole story. Decision and result stages render through `ui/components/encounter_sheet.gd` into a `ModalSheet` over whatever screen the player was on; only booking and release still reach `consequence.tscn` |
| Systems | **37** registered in `GameManager` (0.6.0 PR D added `corner`) |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Wander encounter pool | **12 cards**, up from 4 (0.6.0 PR C). Three police (on-foot stop, vehicle search, warrant check), two addicts, seven general street. Every one declares all three SQ-D6 roles, and the suite asserts it |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **0.7.0** — five PRs off `BUILD_BLOW_BY_BLOW_PROMPT.md`: the words fit (BB-D1/D2/D5/D7, `#127`), the hit lands (BB-D3/D4, `#128`), the panel (BB-D6, `#129`), the street shows up (BB-D8/D9), and the close-out (2026-09-03) |

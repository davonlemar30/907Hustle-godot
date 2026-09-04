# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-09-03 (0.9.0). Living doc — update as screens land._

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
| Build version | `0.9.0` — The Block Remembers: the screen holds, the city gets a fourth district, and the crew has ideas (`autoload/version.gd`) |
| Save schema | **v28**. 0.9.0 bumped once, additive: `job_applications` (BR-D2). v26 `hustles_discovered` and v27 `phone_reply_history` from 0.8.0. |
| Parity | **13,782 checks, 0 failures**, floor `MIN_CHECKS := 13782` (`tests/parity/parity_runner.gd`). Set from a fresh run at every 0.9.0 PR. |
| Territory suite | **170 checks, 0 failures**, floor `MIN_CHECKS := 170` (`tests/territory/territory_runner.gd`) — unchanged in 0.6.0 |
| Confrontation suite | **3,614 checks, 0 failures**, floor `MIN_CHECKS := 3614` (`tests/confrontation/confrontation_runner.gd`) — up from 3,445 in 0.9.0: the fence-line room, the block's roads, the answer rooms. |
| Tips suite | **93 checks, 0 failures**, floor `MIN_CHECKS := 93` (`tests/tips/tips_runner.gd`) — unchanged in 0.6.0 |
| Dre suite | **427 checks, 0 failures**, floor `MIN_CHECKS := 427` (`tests/dre/dre_runner.gd`) — up from 404 in 0.8.0 for the phone exchange, the ghost and the crew loyalty point (WS-D3). |
| Save validation | **261 checks, 0 failures** (`tests/save_validation/`, floor `MIN_CHECKS := 261`). +4 in 0.9.0 for v28 `job_applications`. |
| Screen smoke | Every screen instantiated **at the phone's width (375)** over the longest lines the game writes: all touch checks, 54/54 component checks, **98/98 panel checks** (the triad fits the glance at 375; a fourth authored road may sit a drag away), and **2,788/2,788 width checks** — no visible control outside the viewport (BR-D1, the stretch bug's regression test). |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` |
| Screens | 23, unchanged in 0.6.0 — and this is the build where that stops being the whole story. Decision and result stages render through `ui/components/encounter_sheet.gd` into a `ModalSheet` over whatever screen the player was on; only booking and release still reach `consequence.tscn` |
| Systems | **39** registered in `GameManager` (0.9.0 PR 5 added `scout_adapter` and `enforcer_adapter`) |
| Discovery axes | **3** — `jobs_discovered`, `boost_targets_discovered`, `hustles_discovered`. Districts: Downtown at one corner, Ship Creek at two, **Mountain View at day seven or by the bus-shelter card** (0.9.0). |
| Wander encounter pool | **45 cards** (0.9.0): 0.8.0's 40 plus Mountain View's four and the Spenard card that names it. Every non-fight road whose tier hurts on a civilian card answers back in a generated room (BR-D1). |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **0.9.0** — six PRs off `907Hustle_Build_Prompt_v3.md`, stacked: the screen holds (BR-D1/D2, `#139`), clock in move up (BR-D3, `#140`), your corners their corners (BR-D4, `#141`), Mountain View (BR-D5, `#142`), they have their own ideas (BR-D6), the close-out. Before that: 0.8.0 The World Speaks (`#133`–`#138`). See `docs/BLOCK_REMEMBERS_REVIEW.md` for the eight-question assessment. |

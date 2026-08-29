# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-08-29. Living doc — update as screens land._

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
| Build version | `0.5.0` — The Street Answers Back: you can't walk it for free anymore (`autoload/version.gd`) |
| Save schema | **v25** (PR A, `wander_quiet_streak`) — the doorstep's own thresholds (PR D) deliberately added no field: every one derives from a `due_day` or warning counter the game already tracked |
| Parity | **12,751 checks, 0 failures**, floor `MIN_CHECKS := 12751` — gained the interruption gate (STR-D1/D2), the four-script roster and its room (STR-D3/D5), the travel checkpoint (STR-D4), and the doorstep's three obligations and shared enforcement room (DOOR-D1/D2); net movement from 0.4.0's 12637 also reflects a seeded-key fix that shifted a rigged shakedown-room test off a "messy" roll onto a "failure" roll, dropping one conditional check (D-23) |
| Territory suite | **170 checks, 0 failures** — a CI gate as of Batch 18 PR 1 (`tests/territory/`), FS-002's own harness, seconds rather than the parity runner's ~10 minutes; unchanged in 0.5.0 |
| Confrontation suite | **251 checks, 0 failures** — a CI gate as of the rooms build (`tests/confrontation/`), the loop's own harness on the shared territory asserts; unchanged in 0.5.0 |
| Tips suite | **93 checks, 0 failures** — a CI gate as of 0.1.2 PR E (`tests/tips/`), Word of Mouth's own harness on the shared territory asserts; unchanged in 0.5.0 |
| Dre suite | **404 checks, 0 failures**, unchanged in 0.5.0 — a CI gate since Dre Lending PR A (`tests/dre/`); PR D relocated the player-default ultimatum's own trigger out of `dre_lender.gd` and into `doorstep.gd`'s day-start hook, and every existing ultimatum test needed no change beyond that, since they drive through the real day-cross dispatch the hook rides same as everything else |
| Save validation | **235 checks, 0 failures** — a CI gate as of batch 12; covers nested save shapes through v25 and asserts that catalogue validation releases its temporary GameState Node (`#104`) |
| Screen smoke | 23/23 screens instantiate **with their scripts attached** — a CI gate as of batch 12, script-attachment added in batch 15; `opening.tscn` retired in 0.1.2 PR C (Yalonda replaces it). **1101/1101 touch checks**, unchanged in 0.5.0 — the new street/checkpoint/doorstep content all renders through the existing `consequence.tscn` screen rather than a new one |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` — the ↗/♛ tofu findings from an earlier audit were already fixed in a prior batch, confirmed by direct search |
| Screens | 23 (`opening.tscn` retired in 0.1.2 PR C) — unchanged in 0.5.0, every new consequence kind (the roster's room, the checkpoint, the doorstep's rooms) renders through the existing `consequence.tscn` |
| Systems | **36** registered in `GameManager` (0.5.0 PR D added `doorstep`; corrected from a stale 35 here) |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) — the first recurring cost Territory has ever had |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **0.5.0** — five PRs off `BUILD_STREET_ANSWERS_PROMPT.md`: the interruption gate (STR-D1/D2, `#114`), the street encounter roster and its room (STR-D3/D5, `#115`), the travel checkpoint (STR-D4, `#116`), the doorstep and its shared enforcement room (DOOR-D1/D2, `#117`), and integration/close-out (2026-08-29) |

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
| Build version | `0.4.0` — Repeat Business: Dre's book becomes standing work (`autoload/version.gd`) |
| Save schema | **v24**, unchanged — the repeatable-contract catalogue and the Score contract are all data inside the already-persisted opportunity substrate; nothing in 0.4.0 adds a field |
| Parity | **12,637 checks, 0 failures**, floor `MIN_CHECKS := 12637` — gained the Score contract's substrate coverage (SCR-D1..D3), the version-stamp golden values, and `_check_pressure_family_caps` proving Boost/Stick's new daily Pressure caps truncate and reset correctly (PRESS-D1) |
| Territory suite | **170 checks, 0 failures** — a CI gate as of Batch 18 PR 1 (`tests/territory/`), FS-002's own harness, seconds rather than the parity runner's ~10 minutes |
| Confrontation suite | **251 checks, 0 failures** — a CI gate as of the rooms build (`tests/confrontation/`), the loop's own harness on the shared territory asserts; unchanged in 0.4.0 |
| Tips suite | **93 checks, 0 failures** — a CI gate as of 0.1.2 PR E (`tests/tips/`), Word of Mouth's own harness on the shared territory asserts |
| Dre suite | **404 checks, 0 failures** (was 331) — a CI gate since Dre Lending PR A (`tests/dre/`), seconds rather than parity's ~10 minutes; 0.4.0 added the Score-chain arm (PR A), the repeatable generator's cap/cadence/determinism/expiry coverage (PR B, REP-D1..D5), and the three-more-templates catalogue coverage including the generator's new retry-loop arm (PR C, CAT-D1..D4) |
| Save validation | **235 checks, 0 failures** — a CI gate as of batch 12; covers nested save shapes through v24 and asserts that catalogue validation releases its temporary GameState Node (`#104`) |
| Screen smoke | 23/23 screens instantiate **with their scripts attached** — a CI gate as of batch 12, script-attachment added in batch 15; `opening.tscn` retired in 0.1.2 PR C (Yalonda replaces it). **1101/1101 touch checks** (up from 1093 — PR D's title-screen `Content` restructuring added scrollable structure the walk now covers), every `ScrollContainer` on every screen walked for a stuck `MOUSE_FILTER_STOP` Control or a `pressed`-wired `BaseButton` |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` — the ↗/♛ tofu findings from an earlier audit were already fixed in a prior batch, confirmed by direct search |
| Screens | 23 (`opening.tscn` retired in 0.1.2 PR C) |
| Systems | **35** registered in `GameManager` (Dre Lending arc added `dre`, `opportunities`, `dre_collector` — PR A/C/D respectively; corrected from a stale 34 here — no PR in 0.2.1 through 0.3.0 added a `register_system` call, so the miscount predates both) |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) — the first recurring cost Territory has ever had |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **0.4.0** — five PRs off `BUILD_REPEAT_BUSINESS_PROMPT.md`: one Score through the substrate (SCR-D1..D3, `#109`), the repeatable-contract generator (REP-D1..D5, `#110`), the three-template catalogue (CAT-D1..D4, `#111`), Boost/Stick District Pressure caps plus standing-income pricing (PRESS-D1/D2, `#112`), and integration/close-out (2026-08-29) |

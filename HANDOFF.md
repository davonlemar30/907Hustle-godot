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
| Build version | `0.3.0` — Answer For It: the cops talk to you now (`autoload/version.gd`) |
| Save schema | **v24**, unchanged — the stickup-caught chain kind is data inside the already-persisted `active_consequence`; nothing in 0.3.0 adds a field |
| Parity | **12,618 checks, 0 failures**, floor `MIN_CHECKS := 12618` — gained the stickup-caught decision's coverage (ENC-D1..D9), the `everyday_criminal` economy profile and Heat's own property assertion (HEAT-D1/D2), and the rep-scaled daily-cap coverage (STK-D1). (Re-verified by a fresh full run against `main` after `#104` merged; that PR's own doc update had undercounted this at 12,591) |
| Territory suite | **170 checks, 0 failures** — a CI gate as of Batch 18 PR 1 (`tests/territory/`), FS-002's own harness, seconds rather than the parity runner's ~10 minutes |
| Confrontation suite | **251 checks, 0 failures** — a CI gate as of the rooms build (`tests/confrontation/`), the loop's own harness on the shared territory asserts; gained the stickup-caught decision's own check block plus one from the new stickup target's automatic coverage in the existing target-iteration loop. (`#104`'s doc update had this at 250) |
| Tips suite | **93 checks, 0 failures** — a CI gate as of 0.1.2 PR E (`tests/tips/`), Word of Mouth's own harness on the shared territory asserts |
| Dre suite | **331 checks, 0 failures** — a CI gate since Dre Lending PR A (`tests/dre/`), seconds rather than parity's ~10 minutes; PR E adds the full-arc integration drive (Juan through Junior Lender), the gate-opens-only-through-the-arc and locked-borrowers-refuse checks, and bond-term parity |
| Save validation | **235 checks, 0 failures** — a CI gate as of batch 12; covers nested save shapes through v24 and asserts that catalogue validation releases its temporary GameState Node (`#104`) |
| Screen smoke | 23/23 screens instantiate **with their scripts attached** — a CI gate as of batch 12, script-attachment added in batch 15; `opening.tscn` retired in 0.1.2 PR C (Yalonda replaces it). **1101/1101 touch checks** (up from 1093 — PR D's title-screen `Content` restructuring added scrollable structure the walk now covers), every `ScrollContainer` on every screen walked for a stuck `MOUSE_FILTER_STOP` Control or a `pressed`-wired `BaseButton` |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` — the ↗/♛ tofu findings from an earlier audit were already fixed in a prior batch, confirmed by direct search |
| Screens | 23 (`opening.tscn` retired in 0.1.2 PR C) |
| Systems | **35** registered in `GameManager` (Dre Lending arc added `dre`, `opportunities`, `dre_collector` — PR A/C/D respectively; corrected from a stale 34 here — no PR in 0.2.1 through 0.3.0 added a `register_system` call, so the miscount predates both) |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) — the first recurring cost Territory has ever had |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **0.3.0** — four PRs off `BUILD_ANSWER_FOR_IT_PROMPT.md`: the stickup caught decision (ENC-D1..D9), Heat active decay (HEAT-D1/D2), stickup viability (STK-D1), and phone/title polish (2026-08-29); plus a concurrent `#104` (Node-leak fix in save validation, system-lookup perf hardening) |

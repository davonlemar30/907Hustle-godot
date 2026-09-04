# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-09-03 (0.8.0). Living doc — update as screens land._

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
| Build version | `0.8.0` — The World Speaks: the city reveals itself, and everybody in it has a voice (`autoload/version.gd`) |
| Save schema | **v27**. 0.8.0 bumped twice, both additive: v26 `hustles_discovered` (WS-D1, derived for v25 saves from the gates they had open) and v27 `phone_reply_history` (WS-D3, empty for every earlier save). Unchanged by 0.6.0 and 0.7.0 at v25. |
| Parity | **13,556 checks, 0 failures**, floor `MIN_CHECKS := 13556` (`tests/parity/parity_runner.gd`). Set from a fresh run at every 0.8.0 PR. |
| Territory suite | **170 checks, 0 failures**, floor `MIN_CHECKS := 170` (`tests/territory/territory_runner.gd`) — unchanged in 0.6.0 |
| Confrontation suite | **3,445 checks, 0 failures**, floor `MIN_CHECKS := 3445` (`tests/confrontation/confrontation_runner.gd`) — up from 2,994 in 0.8.0: every road on every card and script swept for a universal verb and a non-empty line under it (WS-D2), the meeting cards, the five priced roads. |
| Tips suite | **93 checks, 0 failures**, floor `MIN_CHECKS := 93` (`tests/tips/tips_runner.gd`) — unchanged in 0.6.0 |
| Dre suite | **427 checks, 0 failures**, floor `MIN_CHECKS := 427` (`tests/dre/dre_runner.gd`) — up from 404 in 0.8.0 for the phone exchange, the ghost and the crew loyalty point (WS-D3). |
| Save validation | **257 checks, 0 failures** (`tests/save_validation/`, floor `MIN_CHECKS := 257`). +6 in 0.8.0 for v26 `hustles_discovered` and v27 `phone_reply_history`. |
| Screen smoke | 23/23 screens instantiate with their scripts attached, all touch checks, 54/54 component checks, and **96/96 panel checks** (0.8.0: every authored street card, meeting card and phase card measured on the sheet). |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` |
| Screens | 23, unchanged in 0.6.0 — and this is the build where that stops being the whole story. Decision and result stages render through `ui/components/encounter_sheet.gd` into a `ModalSheet` over whatever screen the player was on; only booking and release still reach `consequence.tscn` |
| Systems | **37** registered in `GameManager` (0.6.0 PR D added `corner`) |
| Discovery axes | **3** — `jobs_discovered` (WORK walks; the run starts knowing only `wash_go`), `boost_targets_discovered` (DEAL walks), and `hustles_discovered` (0.8.0 WS-D1: `market`, `boost`, `stickup`, `list`, each latched by an authored moment). |
| Wander encounter pool | **40 cards** (0.8.0): 13 encounters, 16 ambients, 4 meetings (Goodie, the rack, the broke afternoon, the witness), 5 reads, 2 opportunities. `day_min`/`day_max` key the encounters and ambients to Week Zero, Getting Known, Reputation and Weight; the mistaken-identity filler was cut. Every encounter declares the SQ-D6 roles and every road reads as one of seven verbs. |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **0.8.0** — five PRs off `907Hustle_Build_Prompt_v2.md`, stacked: the city reveals itself (WS-D1, `#134`), every card earns its slot (WS-D2, `#135`), the player speaks (WS-D3, `#136`), the managers have names (WS-D4, `#137`), the writing pass and close-out (WS-D5, with PR `#107` folded in). Before that: 0.7.0 Blow by Blow (`#127`–`#131`, `#133`). See `docs/WORLD_SPEAKS_REVIEW.md` for the six-question assessment. |

# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-09-06 (1.3.0). Living doc — update as screens land._

> **Floors are the RUNNER CONSTANTS, not this table.** This row set drifted
> once already (parity read 12,751 here against `MIN_CHECKS := 12763` in the
> file) because a close-out added checks and did not come back. It then drifted
> much worse: this table sat at 0.9.0 through the whole 1.0.0–1.3.0 run and was
> four builds stale when a session finally checked. Every suite row below names
> the file its floor lives in. When they disagree, the constant is right — and
> when the constant and a fresh run disagree, the run is right.
>
> **Every number in the table below was verified by a fresh headless run on
> 2026-09-06**, not copied forward. Re-verify the same way rather than trusting
> this line.

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
| Build version | `1.3.0` — Tighten It Up: the 1.2.0 playtest, answered (`autoload/version.gd`) |
| Save schema | **v34**. Six bumps across 1.0.0–1.3.0, every one additive: v29 `rent_arrears_day` (OG-D1), v30 `weapon`/`vehicle`/`trunk` (OG-D3), v31 `game_over_kind`/`leaving`/`run_earnings` (OG-D4), v32 `hot_goods` (OG-D5), v33 `curtis_dismantled`/`curtis_dismantle_hold` (HS-D3), v34 `market_nudges` (TU-D4). Migration arms are documented by version in `autoload/save_system.gd`'s `SAVE_VERSION` header. |
| Parity | **14,482 checks, 0 failures**, floor `MIN_CHECKS := 14482` (`tests/parity/parity_runner.gd`). Set from a fresh run at every PR. |
| Territory suite | **170 checks, 0 failures**, floor `MIN_CHECKS := 170` (`tests/territory/territory_runner.gd`) — unchanged since 0.6.0. Note this suite did **not** move through 1.0.0–1.3.0 even though `systems/territory.gd` gained fronts, the hold, and the dismantle gate; those landed covered by parity and confrontation instead. Territory work is the thinnest-covered surface in the build. |
| Confrontation suite | **4,429 checks, 0 failures**, floor `MIN_CHECKS := 4429` (`tests/confrontation/confrontation_runner.gd`) — up from 3,614 at 0.9.0 across the 1.x run. |
| Tips suite | **93 checks, 0 failures**, floor `MIN_CHECKS := 93` (`tests/tips/tips_runner.gd`) — unchanged since 0.6.0 |
| Dre suite | **427 checks, 0 failures**, floor `MIN_CHECKS := 427` (`tests/dre/dre_runner.gd`) — unchanged since 0.8.0 |
| Save validation | **284 checks, 0 failures** (`tests/save_validation/save_validation_runner.gd`). **This runner has no `MIN_CHECKS` constant** — the "floor `MIN_CHECKS := 261`" this table used to claim never existed in the file. The count is asserted by the CI step, not by a floor. |
| Screen smoke | Every screen instantiated **at the phone's width (375)** over the longest lines the game writes: **1,137/1,137 touch checks**, **2,764/2,764 width checks** (no visible control outside the viewport — BR-D1, the stretch bug's regression test), **52/52 component checks**, **133/133 panel checks**. `MIN_UNCOVERED := 0.35` in `tests/smoke/screen_smoke.gd` is a card-legibility ratio, not a check-count floor. |
| Glyph coverage | ok — `scripts/check_glyph_coverage.py --list`: every shipped character is in all 5 theme fonts, across `ui`, `autoload`, `systems`, `data` |
| Screens | 23 `.tscn` under `ui/screens/`. Decision and result stages render through `ui/components/encounter_sheet.gd` into a `ModalSheet` over whatever screen the player was on; only booking and release still reach `consequence.tscn` |
| Systems | **41** registered in `GameManager` (`grep -c '^\tregister_system(' autoload/game_manager.gd`). 0.9.0's 39 plus the 1.x additions. |
| Districts | **4**, `TERRITORY_DEFS.DISTRICT_ORDER`: `north_star_lot` (Spenard), `downtown`, `airport_industrial` (Ship Creek), `mountain_view`. Discovery axes remain **3** — `jobs_discovered`, `boost_targets_discovered`, `hustles_discovered`. |
| Territory board | **17 nodes** across the four districts (`data/territory_definitions.gd` `NODES`). Operating cost **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1). Soldier income diminishes at `SOLDIER_INCOME_DIMINISH` per additional head on a block. Fronts (HS-D1), `hold_it_down` (HS-D2) and the dismantle gate (HS-D3) all landed in 1.2.0. |
| Crew | **4 recruitable**: Eli "Shortcut" Ward (RUNNER), Deshawn (FIXER/RECRUITER), Pherris Dickens (CONNECTOR), Anton "Tone" Bell (ENFORCER/LOOKOUT); `CREW_CAPACITY := 2` behind `crew_capacity()`. Six delegated operations in `systems/crew_operations.gd` `OPERATION_CAPABILITY`. **Rank ceiling is tier 3**: `CREW_TIER_REQUIREMENTS` defines only tiers 2 and 3, so `at_top_rank()` is true at TRUSTED, while `RANK_LABELS` authors **six** with `MAX_CREW_RANK := 6` — labels 4–6 are shipped strings nothing can reach, and **`autoload/save_validator.gd:162` clamps every loaded tier to 1..3**, so a higher rank cannot survive a load until that line moves. `TIER_WAGES` has three entries per member and no Eli row (`crew_wage_for()` clamps to the curve). `GameState.CREW_CAPABILITIES` authors three rows against six operations — `scout_district`, `put_it_down` and `hold_it_down` have none; Tone's curve sits in `enforcer_adapter.RELIEF_BY_RANK`; `hold_it_down` reads rank nowhere — a one-home hygiene drift with **no runtime effect** (`crew_has_capability()` has no caller outside parity). `crew_records[*].proofs` is read by `requirements.gd` and written by nothing. No requirement row anywhere uses `crew_rank_min`. |
| Player kit | `weapon` is one slot — `hands`/`knife`/`piece`, table in `GameState.WEAPONS` (fight bonus, heat, room line); `vehicle` is `""` or `beater`; `trunk` is the beater's overnight stash. OG-D3, v30. Acquisition is two authored wander cards (`knife_buy`, `piece_buy`) — there is no shop, no loadout, and no crew or soldier equipment. |
| Wander encounter pool | **56 cards** (`data/wander_events.gd` `CARDS`) — 0.9.0's 45 plus the 1.x run's additions, including TU-D4's five rewritten roads. |
| Rulings | Latest recorded is **D-31** (Tighten It Up). **D-32 is the next free number — re-verify against `docs/DECISIONS.md` before claiming it.** |
| Design authority (ClickUp) | Three approved documents govern the organized-crime work and are **not** restated in this repo: **DD-001 Organizational Progression / Crew as Capability** (`2kyd583p-6674`, page `2kyd583p-22394`), **FS-001 Revision 2** (page `2kyd583p-22414` — the six-rank crew spine, proof gates, and "Tier 1–3 wages unchanged" are already ruled there), and **DD-002 Territory Warfare & Rival Dismantling** (page `2kyd583p-22574`). The 2026-09-05 **Godfather II Crew & Territory Expansion — Integration Readiness Report** (`2kyd583p-4054`, page `2kyd583p-23414`) is the initiative's brief and ClickUp `ORG-000` (`86bbvjgk2`) its umbrella task. The design pass, the claim-by-claim corrections to that report, the dependency graph and the phased plan live in `docs/ORGANIZED_CRIME_ECONOMY_DESIGN_PLAN.md` (2026-09-06). |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **1.3.0** — five PRs off the 1.2.0 playtest, stacked: the day has edges (TU-D1, `#166`), earn it on the street (TU-D2, `#167`), the phone in your hand (TU-D3, `#168`), say what is happening (TU-D4, `#169`), clock in move up + the close-out (TU-D5, `#170`). Before that: 1.2.0 His Side of the Board (D-30), 1.1.0 Somebody Shows You Around (D-29), 1.0.0 One Good Run (D-28). Assessments: `docs/ONE_GOOD_RUN_REVIEW.md`, `docs/BLOCK_REMEMBERS_REVIEW.md`, `docs/WORLD_SPEAKS_REVIEW.md`, `docs/VISION_REVIEW.md`. |

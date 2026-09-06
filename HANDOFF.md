# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-09-06 (1.4.0). Living doc — update as screens land._

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
| Build version | `1.4.0` — Room to Move Up: one home, rank four, the standing brief (`autoload/version.gd`) |
| Save schema | **v34** — unchanged by 1.4.0 (proofs and the standing brief ride `crew_records` / `crew_assignments`, which already persist whole; the validator's tier clamp moved without a bump). Six bumps across 1.0.0–1.3.0, every one additive: v29 `rent_arrears_day` (OG-D1), v30 `weapon`/`vehicle`/`trunk` (OG-D3), v31 `game_over_kind`/`leaving`/`run_earnings` (OG-D4), v32 `hot_goods` (OG-D5), v33 `curtis_dismantled`/`curtis_dismantle_hold` (HS-D3), v34 `market_nudges` (TU-D4). Migration arms are documented by version in `autoload/save_system.gd`'s `SAVE_VERSION` header. |
| Parity | **14,618 checks, 0 failures**, floor `MIN_CHECKS := 14618` (`tests/parity/parity_runner.gd`). Set from a fresh run at every PR. |
| Territory suite | **206 checks, 0 failures**, floor `MIN_CHECKS := 206` (`tests/territory/territory_runner.gd`) — moved in 1.4.0 for the first time since 0.6.0, with its first arms for HS-D2's hold and BR-D6's put-it-down at every rank. Fronts, probes, recovery and the dismantle gate are still covered in parity, not here; territory remains the thinnest-covered surface and every slice that touches it should move this floor. |
| Confrontation suite | **4,429 checks, 0 failures**, floor `MIN_CHECKS := 4429` (`tests/confrontation/confrontation_runner.gd`) — up from 3,614 at 0.9.0 across the 1.x run. |
| Tips suite | **93 checks, 0 failures**, floor `MIN_CHECKS := 93` (`tests/tips/tips_runner.gd`) — unchanged since 0.6.0 |
| Dre suite | **427 checks, 0 failures**, floor `MIN_CHECKS := 427` (`tests/dre/dre_runner.gd`) — unchanged since 0.8.0 |
| Save validation | **299 checks, 0 failures** (`tests/save_validation/save_validation_runner.gd`). **This runner has no `MIN_CHECKS` constant** — the "floor `MIN_CHECKS := 261`" this table used to claim never existed in the file. The count is asserted by the CI step, not by a floor. |
| Screen smoke | Every screen instantiated **at the phone's width (375)** over the longest lines the game writes: **1,160/1,160 touch checks**, **2,834/2,834 width checks** (no visible control outside the viewport — BR-D1, the stretch bug's regression test), **52/52 component checks**, **133/133 panel checks**. `MIN_UNCOVERED := 0.35` in `tests/smoke/screen_smoke.gd` is a card-legibility ratio, not a check-count floor. |
| Glyph coverage | ok — `scripts/check_glyph_coverage.py --list`: every shipped character is in all 5 theme fonts, across `ui`, `autoload`, `systems`, `data` |
| Screens | 23 `.tscn` under `ui/screens/`. Decision and result stages render through `ui/components/encounter_sheet.gd` into a `ModalSheet` over whatever screen the player was on; only booking and release still reach `consequence.tscn` |
| Systems | **41** registered in `GameManager` (`grep -c '^\tregister_system(' autoload/game_manager.gd`). 0.9.0's 39 plus the 1.x additions. |
| Districts | **4**, `TERRITORY_DEFS.DISTRICT_ORDER`: `north_star_lot` (Spenard), `downtown`, `airport_industrial` (Ship Creek), `mountain_view`. Discovery axes remain **3** — `jobs_discovered`, `boost_targets_discovered`, `hustles_discovered`. |
| Territory board | **17 nodes** across the four districts (`data/territory_definitions.gd` `NODES`). Operating cost **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1). Soldier income diminishes at `SOLDIER_INCOME_DIMINISH` per additional head on a block. Fronts (HS-D1), `hold_it_down` (HS-D2) and the dismantle gate (HS-D3) all landed in 1.2.0. |
| Crew | **4 recruitable**: Eli "Shortcut" Ward (RUNNER), Deshawn (FIXER/RECRUITER), Pherris Dickens (CONNECTOR), Anton "Tone" Bell (ENFORCER/LOOKOUT); `CREW_CAPACITY := 2` behind `crew_capacity()`. Six delegated operations in `systems/crew_operations.gd` `OPERATION_CAPABILITY`, every one with a row in `GameState.CREW_CAPABILITIES` (RM-D2). **Rank ceiling is tier 4** (1.4.0): `CREW_TIER_REQUIREMENTS` is a requirement list per tier for 2, 3 and 4; tier 4 adds a role-specific `proof_counter_min` row from `PROMOTION_PROOFS`; `at_top_rank()` is true at SPECIALIST LEAD and the Crew screen hides PROMOTE there. Labels 5–6 (`RANK_LABELS`, `MAX_CREW_RANK := 6`) are authored with no entry — absent by design until their scope (district command) exists. The validator clamps tier to `MAX_CREW_RANK` (RM-D1). `crew_records[*].proofs` is written by every adapter's `settle()` on a night of real work (RM-D3) and read by `proof_counter_min`. `TIER_WAGES` has four entries per member, Eli included. A rank-4 member can hold a **standing brief** (`crew_assignments[*].brief`, RM-D7..D9): the `crew_briefs` day-start step renews it, gated by `crew_rank_min 4` — the type's first use. |
| Player kit | `weapon` is one slot — `hands`/`knife`/`piece`, table in `GameState.WEAPONS` (fight bonus, heat, room line); `vehicle` is `""` or `beater`; `trunk` is the beater's overnight stash. OG-D3, v30. Acquisition is two authored wander cards (`knife_buy`, `piece_buy`) — there is no shop, no loadout, and no crew or soldier equipment. |
| Wander encounter pool | **56 cards** (`data/wander_events.gd` `CARDS`) — 0.9.0's 45 plus the 1.x run's additions, including TU-D4's five rewritten roads. |
| Rulings | Latest recorded is **D-32** (Room to Move Up, RM-D1..D9). **D-33 is the next free number — re-verify against `docs/DECISIONS.md` before claiming it.** |
| Design authority (ClickUp) | Three approved documents govern the organized-crime work and are **not** restated in this repo: **DD-001 Organizational Progression / Crew as Capability** (`2kyd583p-6674`, page `2kyd583p-22394`), **FS-001 Revision 2** (page `2kyd583p-22414` — the six-rank crew spine, proof gates, and "Tier 1–3 wages unchanged" are already ruled there), and **DD-002 Territory Warfare & Rival Dismantling** (page `2kyd583p-22574`). The 2026-09-05 **Godfather II Crew & Territory Expansion — Integration Readiness Report** (`2kyd583p-4054`, page `2kyd583p-23414`) is the initiative's brief and ClickUp `ORG-000` (`86bbvjgk2`) its umbrella task. The design pass, the claim-by-claim corrections to that report, the dependency graph and the phased plan live in `docs/ORGANIZED_CRIME_ECONOMY_DESIGN_PLAN.md` (2026-09-06). |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Android artifact | `.github/workflows/android-apk.yml` uploads `android-debug-apk` (arm64, debug-signed) on every push to `main` and on `workflow_dispatch`. Additive to the Web pipeline — `web-deploy.yml` and `export_presets.cfg`'s `preset.0` are untouched. On-device checklist: `docs/ANDROID_SMOKE.md` |
| Latest PRs | **1.4.0** — three PRs plus the close-out off the organized-crime design plan: one home for rank (RM-D1..D3, `#171`), move up (RM-D4..D6, `#172`), the standing brief (RM-D7..D9, `#173`), the close-out. Before that: **1.3.0** — five PRs off the 1.2.0 playtest, stacked: the day has edges (TU-D1, `#166`), earn it on the street (TU-D2, `#167`), the phone in your hand (TU-D3, `#168`), say what is happening (TU-D4, `#169`), clock in move up + the close-out (TU-D5, `#170`). Before that: 1.2.0 His Side of the Board (D-30), 1.1.0 Somebody Shows You Around (D-29), 1.0.0 One Good Run (D-28). Assessments: `docs/ONE_GOOD_RUN_REVIEW.md`, `docs/BLOCK_REMEMBERS_REVIEW.md`, `docs/WORLD_SPEAKS_REVIEW.md`, `docs/VISION_REVIEW.md`. |

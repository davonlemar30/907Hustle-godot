# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-08-28. Living doc — update as screens land._

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
| Build version | `0.1.2` — "She Said Get a Job" (`autoload/version.gd`) |
| Save schema | **v19** (0.1.2 PR E, Word of Mouth) — migration ladder walks v1 → v19. `boost_bribes_used` (v18, the Lift's BRIBE), `tip_effects`/`tip_misses` (v19, Word of Mouth's payloads + drought counter) |
| Parity | **12,533 checks, 0 failures**, floor `MIN_CHECKS := 12533` — `DAY_START_ORDER` trace gained `DAY_START:tips`; five sections that drove tier 2-3 stickups drive the rooms (confrontation loop) |
| Territory suite | **169 checks, 0 failures** — a CI gate as of Batch 18 PR 1 (`tests/territory/`), FS-002's own harness, seconds rather than the parity runner's ~2 minutes |
| Confrontation suite | **212 checks, 0 failures** — a CI gate as of the rooms build (`tests/confrontation/`), the loop's own harness on the shared territory asserts; grew through 0.1.2 PR D (the Lift's caught loop) and the HAND IT BACK follow-up |
| Tips suite | **93 checks, 0 failures** — a CI gate as of 0.1.2 PR E (`tests/tips/`), Word of Mouth's own harness on the shared territory asserts |
| Save validation | **151 checks, 0 failures** — a CI gate as of batch 12; gained `_test_v18_boost_bribes_used` and `_test_v19_tips` in 0.1.2 |
| Screen smoke | 23/23 screens instantiate **with their scripts attached** — a CI gate as of batch 12, script-attachment added in batch 15; `opening.tscn` retired in 0.1.2 PR C (Yalonda replaces it) |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` |
| Screens | 23 (`opening.tscn` retired in 0.1.2 PR C) |
| Systems | 31 registered in `GameManager` (0.1.2 PR E added `tips`) |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) — the first recurring cost Territory has ever had |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Latest PRs | **0.1.2** — five PRs off `BUILD_0.1.2_PROMPT.md`: hide Turf/Crew, the discovery card, Yalonda's opening, the Lift's BRIBE (+ a same-day HAND IT BACK follow-up), Word of Mouth slice 1 (2026-08-28) |

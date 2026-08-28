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
| Build version | `0.2.0` — Dre Lending & Loan-Shark Progression (`autoload/version.gd`) |
| Save schema | **v24** — migration ladder walks v1 → v24. `dre_account` + siblings (v20), `dre_intro_offered` (v21), v22 adds **no fields** (trims `phone_inbox`/`phone_held_inbox` to `PHONE_INBOX_MAX`, drops terminal shark notes, sheds the consequence layer's settled state), v23 adds `opportunity_offers`/`active_opportunities`/`opportunity_history`/`opportunity_next_instance_id` (Street Opportunity substrate, PR C — GameState declared these one version early, so v23 is the first bump that actually reads/writes them), v24 adds `dre_pending_penance` (PR D, restitution follow-up). PR E (0.2.0) adds **no fields** — `shark_borrowers`' new `access_tier_min`/`introduction_key` metadata lives in the authored catalogue, reset fresh every run, never persisted |
| Parity | **12,578 checks, 0 failures**, floor `MIN_CHECKS := 12578` — gained the `leveraged_lender` economy profile, the structural no-risk-free-Dre-carry check, and the shark bond-term parity update (PR E) |
| Territory suite | **170 checks, 0 failures** — a CI gate as of Batch 18 PR 1 (`tests/territory/`), FS-002's own harness, seconds rather than the parity runner's ~10 minutes |
| Confrontation suite | **212 checks, 0 failures** — a CI gate as of the rooms build (`tests/confrontation/`), the loop's own harness on the shared territory asserts; grew through 0.1.2 PR D (the Lift's caught loop) and the HAND IT BACK follow-up |
| Tips suite | **93 checks, 0 failures** — a CI gate as of 0.1.2 PR E (`tests/tips/`), Word of Mouth's own harness on the shared territory asserts |
| Dre suite | **331 checks, 0 failures** — a CI gate since Dre Lending PR A (`tests/dre/`), seconds rather than parity's ~10 minutes; PR E adds the full-arc integration drive (Juan through Junior Lender), the gate-opens-only-through-the-arc and locked-borrowers-refuse checks, and bond-term parity |
| Save validation | **229 checks, 0 failures** — a CI gate as of batch 12; gained `_test_v18_boost_bribes_used` and `_test_v19_tips` in 0.1.2, and the Dre arms through v24 (`_test_v20`..`_test_v24`, one per schema bump above) |
| Screen smoke | 23/23 screens instantiate **with their scripts attached** — a CI gate as of batch 12, script-attachment added in batch 15; `opening.tscn` retired in 0.1.2 PR C (Yalonda replaces it). **1093/1093 touch checks** as of `fix/touch-scroll-transparency` (TOUCH-D5): every `ScrollContainer` on every screen is walked for a stuck `MOUSE_FILTER_STOP` Control or a `pressed`-wired `BaseButton` |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` |
| Screens | 23 (`opening.tscn` retired in 0.1.2 PR C) |
| Systems | 34 registered in `GameManager` (Dre Lending arc added `dre`, `opportunities`, `dre_collector` — PR A/C/D respectively) |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) — the first recurring cost Territory has ever had |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |
| Latest PRs | **0.2.0** — five PRs off `BUILD_DRE_LENDING_PROMPT.md`: structured debt to Dre, introduction and earned access, the opportunity substrate + First Money, A Reminder (collection contract), and the Book earned through a sponsored loan (2026-08-28) |

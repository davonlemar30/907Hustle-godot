# Design

One page. What the run is, what the day is for, what each surface is for
economically, the standing balance positions, and what is deliberately absent.
Created in Batch 18 PR 5 (`86bbjxtmr`) because the game has shipped to a public
URL on every merge since batch 12 and never had one page that answered "what is
this."

For HOW a specific system works, read that system's own file header — every
`systems/*.gd` and `data/*.gd` file carries one, and they are the actual source
of truth. This page is the one level up: why those systems exist and what they
are for, together.

## What the run is

907Hustle ("One Good Run") is a street-life simulation: one character, one
city (Spenard, opening onto Downtown and Ship Creek as the run earns them),
and a clock that does not stop. There is no combat screen, no inventory grid,
no skill tree — every decision is "what do I do with today," repeated until
the run ends.

There is currently no ending (`D-2`, `docs/DECISIONS.md`, open). A run plays
out and the player stops when they stop; nothing in the game says "the story
is over." That is a known, escalated gap, not an oversight — see D-2 for why
this build did not close it.

## What the four hours are for

A day is four time slots — `MORNING`, `AFTERNOON`, `EVENING`, `NIGHT`
(`systems/time_system.gd::SLOTS`) — and almost everything the player can DO
costs exactly one. That is the whole shape of the design: the game is a
scheduling problem before it is anything else. Four slots means four choices,
and every surface below is competing for the same four choices, not for the
player's money or their risk tolerance directly — those are downstream of
which four things got picked.

A few things do NOT cost a slot, and each is a deliberate exception:

- **Territory's nightly settlement** (income, heat, and — as of Batch 18 PR 4 —
  soldier upkeep) happens automatically at day-cross. This is what makes
  Territory categorically different from every other earner: it is the one
  thing in the game that pays (and now costs) without the player spending a
  slot on it, ever, once it is set up. See "the standing balance positions"
  below for what that is worth and what it costs to be worth it.
- **Paying rent, the phone bill, or crew wages** are cash transactions, not
  time transactions — the slot cost was spent earning the money, not spending
  it.
- **Night itself** (`advance_time` crossing past `NIGHT`) runs the whole
  settlement lifecycle (`systems/day_lifecycle.gd`) — crew wages, Territory,
  Shark, Jobs, Obligations, then the rollover and day-start phases — as one
  atomic step the player did not have to spend a slot to trigger; it is the
  consequence of having spent all four.

## What each surface is for, economically

Every surface below is a way to spend a slot. This is what each one is FOR —
the role it plays in the economy, not how it works mechanically.

- **Jobs** (`systems/jobs.gd`) — the floor. A legal shift, modest and reliable,
  with no risk and no ceiling. It is the baseline every other surface is
  measured against (`legal_worker` = 100% by definition; see D-4,
  `docs/DECISIONS.md`).
- **The Market** (`systems/economy.gd`, buy/sell) — the trading path. Margin
  on product price swings, with Heat as the cost of moving volume. Rewards
  reading the market over time, not a single big play.
- **907List** (`systems/nine07list.gd`) — the flip board. Faster-turnover
  trading with tiers and a delegation option (Pherris can run cycles without
  spending the player's own slot — see `systems/list_adapter.gd`).
  Delegation's own economics are a live, escalated finding (Pherris's wage at
  rank 2, `docs/DECISIONS.md`, "Escalations").
- **Boost** (`systems/boost.gd`) — lifting, with a permanent-ban risk per
  target and a technique ladder that raises the ceiling and the risk together.
  Structurally capped by `CAUGHT_EFFECTS talk/messy` (D-4, `docs/DECISIONS.md`)
  — the binding constraint on the surface, filed rather than fixed because it
  is transcribed from the oracle.
- **Stickup** (`systems/stickup.gd`) — armed robbery. The highest nominal
  take-per-attempt and, measured, the worst return in the game: roughly 4.6hp
  of expected damage against an $11 take, solo (D-4, `docs/DECISIONS.md`). A
  crew member (Tone) does not fix it. Filed for design, not taken.
- **Territory** (`systems/territory.gd`) — the only earner with no time cost.
  Buy a corner, staff it, and it pays every night whether or not the player
  ever returns — and, as of D-1, costs $20/soldier/night to keep staffed
  whether or not those soldiers are earning anything. The one surface that
  turns "have I built something" into an ongoing question rather than a
  one-time payoff.
- **Crew** (`systems/crew.gd`) — not a slot-spender itself; a multiplier on
  everything else. Recruiting and paying crew is how Territory's heat gets
  damped (Deshawn), Tone absorbs Stick damage, and Eli/Pherris/Deshawn run
  delegated operations. Crew wages are a standing cost with a loyalty
  consequence for going unpaid — the one recurring cost in the build that
  predates D-1's Territory upkeep.
- **Wander** (`systems/wander.gd`) — the discovery axis. Spends a slot to find
  things (jobs, Boost targets) rather than to earn directly; its value is
  measured relative to a job the player already has (`worker_wanders` vs.
  `wanderer` — see the orientation table in `HANDOFF.md`).
- **Recovery** (`systems/recovery.gd`) — the health floor. Not an earner;
  what keeps Stickup and Boost's damage from ending a run outright.
- **The Shark** (`systems/shark.gd`) — credit. A lever for a player who is
  cash-short of a Territory claim or a 907List buy-in, at the cost of a due
  date and a collection consequence for missing it.

## The standing balance positions

Recorded here so they do not have to be re-derived from the economy table
every time someone asks "is this game balanced."

- **Smart crime approaches the job and never beats it — except Territory.**
  Every measured criminal surface (Stickup, Boost, Boost's finder variant)
  reads well under the day job's 100% baseline. Territory is the deliberate
  exception, and it is deliberate because it is not really "crime" in the
  same sense — it is capital investment, paid for once and defended forever,
  and D-1 exists specifically to give that investment a maintenance cost
  instead of a purely one-way payoff.
- **The clean paths (Jobs, trading, Territory) dominate the violent ones
  (Stickup) by a wide margin, and that is read as correct, not as a gap to
  close.** Stickup's weakness was sw­ept with every lever available — removing
  injuries, free first aid, removing arrests, a rank-3 crew bodyguard — and
  none of it closes the gap (D-4, `docs/DECISIONS.md`). This build's answer is
  to file that rather than tune Stickup's numbers, because "report, do not
  tune" applies to a surface reading weak the same as it applies to one
  reading strong.
- **`legal_worker` is the anchor, and it is deliberately the LAZY anchor,**
  not the optimal one — it does not seek the best available shift. The gap
  between it and a profile that does (`best_job_worker`, 111%) is the
  instrument's own honesty check on itself: eleven points is a small, known,
  accepted amount of anchor drift (D-4), not a hidden thumb on the scale.
- **Territory is the one surface whose numbers moved between builds and the
  move was itself the fix.** `settler` at 636% was Territory with no
  recurring cost; 409% is Territory taxed the way every other earner already
  was. The 636% number is preserved in `docs/BUILD_LOG.md`'s batch-17 entry as
  the finding that led here, not as a target.

## What is deliberately absent

- **An ending.** D-2, open. Nothing in the current state shape forecloses one.
- **Contested takeovers, Curtis pressure on Territory, soldier attrition,
  police raids on staffed corners, block manager assignment.** All named as
  "not ported" in `territory.gd`'s own header since the system shipped in
  Phase 3e. `starting_owner` (FS-002.3) seeds the DATA a future takeover
  mechanic needs without building the mechanic itself — see D-6,
  `docs/DECISIONS.md`.
- **A debt/consequence system for Territory's own upkeep.** D-1's upkeep is a
  best-effort immediate deduction (pay what the wallet holds, no debt) rather
  than a due-date-and-penalty system like rent, the phone bill, or crew wages.
  A deliberate scope decision recorded in D-1, not an oversight — a future
  ruling can build a real consequence on top without this choice foreclosing
  it.
- **A win condition, a difficulty curve, seed/character selection.** The run
  is one character, one seed per playthrough, and success is read entirely off
  the economy measurement in `HANDOFF.md`'s orientation table — there is no
  in-game scoring or completion state.

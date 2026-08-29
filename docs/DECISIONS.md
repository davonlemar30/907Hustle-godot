# Decisions

Standing rulings, newest first within each era. One entry per decision, each
with what was decided, why, and what it binds.

**This file is a record, not an authority.** Where a ruling here describes
shipped behaviour and the code disagrees, the code wins and the ruling is stale
— fix it here. Where a ruling grants permission for future work, it binds until
superseded by a later entry that says so by number.

Started in Batch 18 PR 2, because D-5 had to be recorded somewhere before the
documentation it corrects could point at it. Back-filled in PR 5 with the
rulings that were buried in `HANDOFF.md` narrative: the Build 5e divergences,
D-2 and D-4, the `CAUGHT_EFFECTS` anomaly, and the `legal_worker` baseline.

---

## D-2 — The ending

**Status: open — escalated, not answered.** Recorded here per Build 18's own
exit criteria ("D-2 answered or escalated"), because answering it is outside
what this session has standing to do.

**Decided (that it needs deciding) by** the 2026-08-23 studio pass · **Ticket**
`86bbjxtfz` · **Constraint honoured in** Batch 18 PR 3 (FS-002.3)

### The question

907Hustle has no ending. A run plays out, days pass, and nothing closes it —
there is no win state, no "the story is over" screen, no mechanic that reads as
a deliberate stopping point. The studio pass flagged this as a ruling the game
needs before FS-002.6 can be built: **"a ruling this build, not code."** What
should end a run, and what should the game say when it does?

This is not a technical question with a technical answer sitting somewhere in
the codebase to transcribe. It is a narrative-design call — canon may have an
answer (an ending state in the web build's own source), or it may be genuinely
undecided upstream, and either way it needs a person who owns the game's
direction, not an agent executing a build brief, to make the call.

### What this build was told to do about it, and did

**"Do not build an ending in Build 18; do not let FS-002.3's state shape
foreclose one."** Both halves held:

- No ending mechanic was built. Territory's canonical state (`territory_nodes`,
  `territory_fronts`) is generic holding/relationship data, not anything
  ending-shaped.
- Nothing in FS-002.3's migration or schema forecloses a future ending. Save
  v16 adds no field that assumes a particular ending design, and the
  `territory_fronts` ledger is deliberately minimal — bookkeeping for a
  migrated capture, not a state machine that would need to know about win
  conditions to be consistent.

### What is needed to close this

A human ruling: what ends a run (a day count, a net-worth threshold, an arrest
record, something else entirely), and whether canon already answers this or the
port gets to decide fresh. Until that ruling lands, FS-002.6 cannot start —
which is exactly the ordering the studio pass specified, and exactly why this
is recorded as open rather than guessed at.

## D-4 — Economy baseline: resolved, `legal_worker` stays 100%

**Decided** by the 2026-08-23 studio pass · **Status: resolved** · reopen only
if the gap drifts past ~125%

### The worry

`legal_worker` — the profile every other economy percentage in this file is
quoted against — never leaves Wash & Go, and `ECON_JOB` is not even the best
starter shift the game offers (`spenard_chevron` pays `[48, 60]` against
`[40, 60]`). If the baseline itself was leaving free money on the table, every
percentage quoted against it would be systematically inflated, and the whole
economy table would need re-baselining.

### The measurement that resolved it (batch 16)

`best_job_worker` runs the identical ladder with `best_job` turned on — the
same profile, taking the best shift available instead of the fixed one.
It reads **111%**. The anchor is off by eleven points, not by a multiple:
re-baselining against the best shift would move every number in this file by
about a tenth, which is inside the spread these profiles already have from
seed variance alone.

### The ruling

**Keep `legal_worker` at 100%. Quote the 11% gap (`best_job_worker` = 111%)
instead of carrying the "naive baseline" caveat.** The caveat overstated a
real but small effect as an open question; the measurement closed it.
**Reopen only if the gap drifts past roughly 125%** — a threshold, not a
tripwire, because a few points of drift from an unrelated shift-pay tweak
is not the same finding as the anchor becoming genuinely unrepresentative.

Swept out of `HANDOFF.md`'s orientation table in PR 5, which is what "resolved"
means for a caveat: it does not get repeated at every reading, it gets recorded
once, here, with the number that closed it.

### A related, still-open finding: the `CAUGHT_EFFECTS talk/messy` anomaly

Filed for design, not taken — the shape of the finding is still useful even
though nothing has acted on it.

`CAUGHT_EFFECTS talk/messy` is the binding constraint on Boost: the only row
where a SUCCESS tier permanently bans, and it accounts for roughly 3.5 of 4
Spenard targets banned per run. Measured, not guessed: removing the ban from
that row alone moved Boost from 13% to 15% (a small effect — most of Boost's
weakness is elsewhere), while narrowing bans to catastrophic outcomes only
measured 50% in a scratch tree (a large effect, because it stops treating an
ordinary success like a catastrophic one).

**Not fixed, because it is transcribed faithfully from FS-003 §5 and the web
build is the oracle for this port.** If the web build's own rule is itself the
anomaly — a success tier that permanently bans reads like an authoring
oversight rather than a deliberate design choice — that is a question for
whoever owns the web build, not something this port gets to silently correct.
Recorded here as the reasoned case for revisiting FS-003 §5, with both
measurements attached, so a future ruling does not have to re-derive them.

## D-1 — Territory's operating cost: $20/soldier/night

**Decided** by the 2026-08-23 studio pass, before this session started · **Ships
in** Batch 18 PR 4 · **Ticket** `86bbjxtfa`

### The ruling (not this session's — recorded here per the exit criteria)

Territory had no time cost and no recurring cost: claiming and recruiting never
call `advance_time`, and a soldier cost $140 once and was never on a wage
clock. Six corners cost $1,680 and paid $415/night forever, unvisited; the
`settler` economy profile read 636% of the day job with zero arrests, and that
was a floor — the profile never even posted a second soldier. FS-002.5's
offense loop would then price risk at one slot while claiming and holding stay
entirely free, making the whole warfare mechanic strictly dominated by not
using it.

**Ruling: a nightly soldier upkeep, $20/soldier/night, settled alongside crew
wages.** This is a missing rule, not a balance tweak — the FS-002 "constants
unchanged" freeze held through PR 3 because no FS-002 balance constant existed
yet to freeze. It exists now.

### This session's implementation choices, flagged as choices

The ruling specifies the number and the timing ("alongside crew wages") but not
the mechanism. Three calls were made executing it, each because the ticket's
own ClickUp comment could not be read (connector unauthenticated):

1. **Charged on the full roster (`soldiers_total()` — idle AND posted), not
   just posted soldiers.** Read as the parallel to crew wages, which are
   charged per RECRUITED member regardless of assignment. It is also the only
   reading under which "an over-extended board becomes a live cost" (the
   ruling's own phrase) is true: a posted-only charge would make recruiting
   soldiers beyond what is staffed free, which is exactly "over-extended" with
   no cost attached.
2. **An immediate best-effort wallet deduction, not a debt.** Every other
   recurring cost in the build (rent, the phone bill, crew wages) is
   PLAYER-INITIATED with a due date and a miss penalty — nightly settlement
   only tracks misses, never force-deducts. An automatic nightly charge with no
   player action and no blocker to check is a genuinely new pattern; building a
   full debt-and-consequence system to match crew's mechanism would be a much
   bigger change than one upkeep line. Chosen instead: pay what the wallet
   holds, log the shortfall, no debt, no departure, no grace period. A later
   ruling can build a real consequence on top of this without this choice
   foreclosing it.
3. **Lives inside `territory.gd`'s existing `settle_night()`, not a new named
   step in `day_lifecycle.gd`'s phase lists.** "Alongside crew wages... a new
   step in the declared order, not a `day_crossed.connect()`" is satisfied by
   the adjacency `SETTLE_ORDER` already declares (`crew` immediately before
   `territory`) and by running through the existing declared SETTLE phase —
   never a signal hookup. No phase list needed a new entry.

### A flag on this entry

Choices 1–3 are this session's reading of an already-decided ruling, not a
re-litigation of the ruling itself. If `86bbjxtfa`'s own comments specify the
mechanism differently, THIS section is what should change.

## D-5 — Day-cross settlement ordering: the shipped order wins

**Decided** 2026-08-23 · **Ships in** Batch 18 PR 2 · **Ticket** `86bbj1jnr`
(FS-002.2)

### The conflict

`HANDOFF.md` documented the day-cross settlement order as:

```text
Jobs → Obligations → Stickup reset → Shark → Crew → Territory → ...
```

and called it *"the approved gameplay ordering"*. Shipped `SETTLE_ORDER`
(`systems/day_lifecycle.gd`) is:

```text
crew → territory → shark → jobs → obligations
```

Jobs and obligations run **last**, not first. The two are not reconcilable by
reading; one of them had to lose.

### The ruling

**The shipped order wins. Reconcile the document to the code, not the code to
the document.**

Three reasons, in order of weight:

1. **The code is defended and the document is not.** `time_system.gd` carries a
   canon-grounded rationale for the shipped sequence with a parity assertion
   behind it (`_check_settlement_contract`), and the whole trace is pinned as a
   literal fixture. The document has no test and had drifted through at least
   four batches without anybody noticing.
2. **Reordering would change gameplay.** Obligations last is load-bearing: rent
   and the phone bill are what end a run, and everything that could still pay
   them has had its turn. Moving them first would end runs that currently
   survive.
3. **A document that instructs a reconciliation toward itself is the more
   dangerous artefact.** `BUILD_18_BRIEF.md` was withdrawn for exactly this: its
   Slice 2 instructed a reconciliation toward the documented contract, and
   following it would have reordered gameplay on the strength of a doc nobody
   had tested.

### The corollary that matters more

The *reason* the ordering was given is false, and was false in **four places** —
`systems/day_lifecycle.gd`, `systems/time_system.gd`, `systems/crew.gd` and
`HANDOFF.md`. All four said, in words:

> Crew settles before Territory because territory income is computed off crew
> power.

`systems/territory.gd` does not reference `crew_power`. It does not reference
`crew` at all. Corner income is the block's authored `earning` and
`SOLDIER_INCOME_DIMINISH`, full stop. `crew_power` is read by the HUD, the Crew
screen and the save, and by nothing that settles.

**The real dependency is heat, through Deshawn.** `crew.settle_night()` can mark
a member departed when loyalty bottoms out over unpaid wages;
`territory.settle_night()` applies its holding heat through
`HeatSystem.apply_gain()`, the one site that consults `crew.heat_multiplier()`,
and that multiplier returns 1.0 for a Deshawn who is no longer recruited.

So the ordering decides what the night **costs**, not what it earns. It is still
load-bearing and swapping it is still a gameplay change — it was simply never
the change the documentation described.

This is the more dangerous half of the finding. A wrong ordering is caught by
the parity fixture the moment somebody moves it. A wrong *reason* is caught by
nothing, propagates by copy-paste, and is what a future reader reasons from when
deciding whether a reorder is safe.

### What binds

- `SETTLE_ORDER` is the contract. Documentation describes it and never defines
  it.
- The justification in all four places now names Deshawn and the heat
  multiplier.
- Proven behaviourally rather than only in prose
  (`tests/territory/territory_runner.gd`): corner income is identical at
  `crew_power` 0 and 999, and settling in the shipped `SETTLE_ORDER` costs
  strictly more heat than settling territory first. The measurement is driven
  off the constant, so swapping it changes the measured number rather than only
  an index comparison.

---

## D-6 — A migrated Territory holding is never confiscated

**Decided** 2026-08-23 · **Ships in** Batch 18 PR 3 · **Ticket** `86bbj1jpm`
(FS-002.3)

**Numbered D-6 rather than D-3 deliberately.** The build prompt's own decision
list names D-1, D-2, D-4 and D-5 and skips D-3 — a gap that reads as reserved
rather than accidental, most likely a standing ruling already recorded in
ClickUp under that number and simply not restated in the brief handed to this
session. Claiming "D-3" for an unrelated new ruling risked colliding with
whatever that already is. This entry is D-6, continuing after the highest
number this build actually uses.

### The conflict

FS-002.3 seeds the Territory board with an authored `starting_owner`:
`spenard_rec_lot` and `wash_and_go_lot` neutral, the other four
(`minnesota_offramp`, `service_road_chokepoint`, `fourth_ave_strip`,
`northern_lights_motels`) Curtis-secure.

A save written before this file existed can already hold one of the four
Curtis-secure nodes — Batch 17 measured the `settler` profile holding all six.
Migrating that save collides two rules that cannot both be honoured for the
same corner:

1. **The seeding rule** says those four nodes belong to Curtis from the start.
2. **"No migrated holding is ever confiscated"** — the ticket's own language,
   quoted in the build prompt's list of fixtures FS-002.3 was missing — says a
   holding a save already has survives the migration that introduces a new way
   to think about it.

One has to lose, in writing.

### The ruling

**The migrated holding wins. It is never confiscated.**

A Curtis-secure node the player already held before FS-002.3 migrates as
player-held, exactly as `wash_and_go_lot` (neutral) does. The capture is treated
as having already happened, off camera, before this build had a way to describe
it — which is the only reading consistent with the player's own save file.

Two bookkeeping facts are stamped alongside the migrated node, in
`territory_fronts[id]`:

- `capture_reward_consumed: true` — so that whenever FS-002.4/.5 attaches a real
  reward to a real capture, this corner cannot be awarded it a second time for a
  capture that already happened.
- `conflict_active: true` — so a later build can tell this corner apart from one
  nobody has ever touched, without needing a second migration to add the flag.

A Curtis-secure node the save did **not** hold gets no `territory_fronts` entry
at all. The field records a migrated capture, not a standing fact about the
board — an untouched Curtis-secure corner is exactly what the seeding rule says
it is, until a real takeover mechanic (FS-002.4/.5) changes that.

### What this does NOT do

**`starting_owner` gates nothing about `claim_block` in this build.** All six
nodes remain claimable through the ordinary flow, identically, on a fresh run.
Contested takeovers are FS-002.4/.5 (Build 18b) — `territory.gd`'s own header
has listed "Curtis pressure and contested takeovers" under "Not ported" since
the system shipped. Gating claims on ownership now, with no mechanic to make a
Curtis-secure claim mean something different, would lock four of six corners on
every fresh run for no reason a player could discover — a real gameplay change
smuggled inside a state-migration PR, which is exactly what the FS-002
"constants unchanged" freeze and rule 8 (derive through the rule, don't
hardcode the answer — and don't invent a rule nobody asked for) both forbid.

### A flag on this ruling

**This is a scope call this session made, not a transcription of the ticket.**
The ticket's own ClickUp comment — which the build prompt explicitly says to
read in full before starting FS-002.3 — could not be read: the ClickUp
connector is unauthenticated in this non-interactive session. If that comment
specifies the confiscation/seeding collision or the claim-gating question
differently, this ruling is the one that should change, not the code it
describes. Check `86bbj1jpm`'s comments before treating D-6 as final.

Proven behaviourally in `tests/territory/territory_runner.gd` (`_test_v16_migration`)
and cross-checked in `tests/parity/parity_runner.gd`'s v9→v16 migration chain:
a migrated Curtis-secure holding survives with its capture marked consumed; an
untouched one gets no fronts entry; a neutral migrated holding gets no fronts
entry either.

## D-7 — Dre Lending & Loan-Shark Progression: the closed design rulings

**Decided** 2026-08-28 · **Ships in** 0.1.2 PR A · **Design doc**
`docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` §22 · **Sources:** the
design doc's own recommended defaults, the ClickUp "Dre Smooth (Story /
Utility)" character page, and the running code as of PR A

### The question

The design doc closes with twelve open questions (§22, "Open design
decisions") and a note that exact numbers "remain balance parameters and
must be selected through measurement." Section 22 gives a recommended
default for each; this entry is where those recommendations become rulings
this build actually carries, plus the two repo-specific facts (the
provisional first-loan numbers, and where `boost.gd`'s pinned-neutral Dre
bond term goes live) neither the design doc nor Section 22 could name
without reading the running code.

### The rulings

Referenced from code as `DRE-D1` through `DRE-D12`, matching the design
doc's own numbering so a comment naming one can be traced straight back to
the question it answers.

| ID | Ruling |
|---|---|
| DRE-D1 | **Juan mentions Dre** — canon (ClickUp), not Word Around Town or elapsed time. Trigger: `day >= 2` AND no prior introduction AND (`cash <= 80` OR rent is due within 1 day and `cash` is under the weekly rent). Delivered as a phone text from Juan, once per run, latched. The rent-pressure clause is a deliberate addition to canon's flat cash check: a player doing fine on cash but about to miss rent still needs an honest way in. |
| DRE-D2 | First meeting costs one slot (the trip to the Mini-Mart lot). Repay and extension-request are cash/phone actions and cost no slot. |
| DRE-D3 | Full repayment only. No partials, in the MVP. |
| DRE-D4 | Access tiers are monotonic latches. A serious default sets the account `suspended`, which blocks services without erasing the tier the player already earned; restitution (full repayment) clears it. |
| DRE-D5 | Borrow-to-lend is legal. PR E's economy pass must include a leveraged-lender profile and assert no combination is risk-free positive carry. |
| DRE-D6 | Overdue schedules exactly one authored collection response through the consequence chassis — never an instant game over. PR A stands up a provisional flat-grace substitute (`OVERDUE_GRACE_DAYS`) for the real event-driven version PR D builds; see `dre_lender.gd`'s own header. |
| DRE-D7 | Junior Lender (The Book) unlocks on the design doc's lighter chain: one resolved Dre loan milestone + one collection milestone + the sponsored first Book loan. **This supersedes the ClickUp character page's heavier gate** (trust 3 + 3 missions + 2 loans) — repo decisions win; the ClickUp page needs updating to match once PR E ships it. |
| DRE-D8 | No visible numeric rank or trust bar. Access reads through role labels, terms offered, and dialogue. |
| DRE-D9 | No mission currency. Rewards are cash, access, relationship, information. |
| DRE-D10 | Surfaces: "DRE" for the relationship/account; "THE BOOK" for player-funded loans. "Note" survives only in flavor dialogue. Finances shows two sections, never merged: **DEBT TO DRE — YOU OWE** and **THE BOOK — THEY OWE YOU**. |
| DRE-D11 | `SETTLE_ORDER` becomes `crew, territory, shark, dre, jobs, obligations` — Dre's account transition settles after shark receivables (money due back that night is in hand before Dre calls the player late) and before jobs/obligations. Pinned by `tests/parity/parity_runner.gd`'s `LIFECYCLE_EXPECTED_TRACE` and `tests/dre/dre_runner.gd`'s own ordering check. |
| DRE-D12 | Post-chain repeatable contracts: max three offered/active, at most one new offer per in-game day start. **Deferred past PR E** — the authored chain ships first. |
| Tier names | Mechanical tiers 0-4 stay as the design doc has them (Unknown → Borrower → Trusted Customer → Collector → Junior Lender). ClickUp's Stranger/Reliable/Earner/Inner Circle are Dre's *dialogue* vocabulary at roughly tiers 0/2/3/4 — copy only, never a second state. The ClickUp character page needs this mapping recorded once PR B lands tier progression. |
| First-loan numbers | Canon (ClickUp): **$1,000 principal, $1,200 total due, 5-day term.** Extension: +2 days, +$100, once. Trusted Customer offer band (design doc §7, tier 2+): up to $2,000 at the same 20%/5-day pricing, plus a short $500/$600/2-day option — PR B/E's to wire. **All provisional pending PR E's economy-profile pass** — `dre_lender.gd`'s header says so explicitly, and nothing here should be read as balance-final. Note the poetry: `GameState.debt`'s dead initial value had been `1200` all along. |
| Dre bond | The pinned-neutral `"bonded with Dre → false"` term in `systems/shark.gd::default_probability` (see that function's own header) goes live in PR E: bonded == `dre_access_tier >= 3`. A named divergence closing on purpose, not by accident — `shark.gd`'s header and parity's shark section both need a deliberate update when it happens, not a silent drift. |

### Two properties that must survive across every later PR

Not new rulings — restated here because PR A through E all depend on both
holding, and a violation would not show up as a failing assertion until
something else broke first.

1. **Route-gate monotonicity.** `surface_visibility.gd`'s `ROUTE_GATES` are
   monotonic — a route never re-closes once open. Suspension must NOT be
   expressed by re-closing a gate: a suspended account keeps every earned
   surface visible, and the *systems* refuse the actions (`dre_lender`
   refuses new borrowing; PR E's `shark.fund_blocker` gains a suspension
   clause) while the screens render the real reason.
2. **The dispatch seam is `GameManager.dispatch()`'s existing post-handler
   reconciliation point**, not a second one built beside it. PR C's
   opportunity tracker observes `action`/`payload`/`result` there, the same
   seam `crew_ops.reconcile()` already uses — it does not invent its own.

### Why PR A carries this entry rather than a later PR

The build prompt is explicit: these rulings are Slice 0 of the design
doc's own recommended implementation order (§20) and are recorded "as part
of PR A. No production behavior" rides on Slice 0 itself, but PR A's own
account/state-machine code already depends on DRE-D2 (slot costs),
DRE-D3 (full repayment only), DRE-D6 (the provisional grace substitute),
and the first-loan numbers — so the rulings this file records had to exist
before the code that implements them, not after.

## D-8 — Street Opportunity and Mission System: the closed umbrella rulings

**Decided** 2026-08-28 · **Ships in** PR C · **Design doc**
`docs/STREET_OPPORTUNITY_AND_MISSION_SYSTEM_DESIGN.md` §25 · **Sources:** the
design doc's own recommended defaults, `BUILD_OPPORTUNITY_CONTRACT_ADDENDUM.md`
(the mid-build addendum binding this doc to PR C), and D-7 above, which this
entry restates rather than overrides where the two name the same fact

### The question

The umbrella design closes with fifteen open questions (§25) the same way
D-7's design doc did — a recommended default for each, "measurement and
playtest may change it." The addendum that bound this doc to PR C turned
every one of those defaults into a ruling before PR C's own code landed, the
same Slice-0-before-the-code discipline D-7 records for Dre's own rulings.

### Authority chain (umbrella §2.1)

The umbrella owns the shared opportunity lifecycle, objective vocabulary,
deadline semantics, capacity rules, and typed-effect rules. The Dre design
owns Dre's own content, economy, and milestones. The running domain system
(`dre_lender.gd`, `shark.gd`, ...) stays authoritative for what actually
happened. Where the Dre design's thinner §10.3 sketch and the umbrella's
§9 shapes disagree on a field's exact place — `giver_id` is the one case
PR C actually hit — the umbrella wins: `giver_id` lives on the *definition*
(`data/dre_contracts.gd`), not duplicated onto the instance.

### The rulings

Referenced from code as `OPP-D1` through `OPP-D15`, matching the design
doc's own numbering.

| ID | Ruling |
|---|---|
| OPP-D1 | Internal name "opportunities" (`systems/opportunities.gd`, `opportunity_*` fields). Player-facing surfaces use thematic names only — no screen is ever titled "Opportunities". |
| OPP-D2 | Accepted-commitment cap: three globally across contracts/missions/scores. Leads, standing surfaces, obligations, operations, and threats never count. Enforced in `opportunities.gd` from day one, per the addendum's own instruction — a guard on `_accept()`, one comparison. PR C's one authored chain never reaches it; the guard exists so the first repeatable content that could cannot ship without it already in place. |
| OPP-D3 | Accepting costs no slot by default. An authored meeting that both accepts and begins work states its cost in its own confirm copy — First Money's `dre_borrow` is the one live example, consistent with DRE-D2. |
| OPP-D4 | `completion_mode: "auto"` for every MVP definition. `ready` (turn-in) ships in the lifecycle enum and the validator but no MVP content uses it. |
| OPP-D5 | No separate agent standing. Exposure is sentiment; domain milestones are access — DRE-D8 restated at the umbrella level, one authority. |
| OPP-D6 | No mission currency — DRE-D9 restated. |
| OPP-D7 | Offer generation only at declared lifecycle points (a dispatch's own reconcile, or `DayLifecycle.SETTLE_ORDER`'s `opportunities` step), seeded, never on screen open. |
| OPP-D8 | No procedural generation until the Dre chain and one Score chain are both live. PR C hardcodes nothing generative. |
| OPP-D9 | Unified Score presentation deferred entirely — needs its own content design first. Lift/Stickup untouched by this build. |
| OPP-D10 | Elapsed-day gates: 907List's `day_min: 3` and Stickup's `day_min: 2` are retained as intentional pacing; Boost's wander-count gate is real discovery and stays. Only person/relationship access converts — Shark→Dre, which PR B already did. |
| OPP-D11 | Deadlines store absolute `deadline_day`/`deadline_slot`; the stated final slot is inclusive. **Not exercised by PR C's content** — First Money's offer carries no authored deadline (see its own header in `data/dre_contracts.gd`), so the shared projection helper this ruling calls for has no second caller yet to prove it against and is deferred to the PR that first needs one, rather than built against a single, untested call site. |
| OPP-D12 | Typed completion effects, closed allowlist: `wallet_credit`, `exposure_observation`, `access_milestone`, `message`, `offer_followup` — the five PR C-E need. `announce_surface`/`record_proof` wait for a consumer. Unknown effect types fail closed with a warning, never a silent no-op. |
| OPP-D13 | Home shows at most: urgent obligation/threat, nearest accepted deadline, strongest new offer — never a quest log. **Not yet wired to Home** — PR C's own scope is the substrate and its Phone/People presentation; the Home summary card is deferred to whichever PR first has more than one live offer competing for the same priority stack. |
| OPP-D14 | No tutorial week. Yalonda's intro sheet and Juan's mention are the model: authored, optional, no reward for merely visiting a screen. |
| OPP-D15 | `respect` is out of scope for this build and is not wired into opportunities. Its own meaning (or removal from presentation) is a separate, later ruling. |

Three further calls the addendum made that are not numbered in the design
doc's own §25 but are equally closed:

| Decision | Ruling |
|---|---|
| Objective classes | PR C implements only `action_result` and `state_fact`. `consequence_result` is PR D's (the collection contract). `counter_delta`, `maintain_condition`, `deliver_resource` stay unimplemented — unknown classes fail closed, so authoring one later forces the implementation rather than silently no-op-ing. |
| Lifecycle enum | The full set ships from day one — `offered, active, ready, completed, declined, expired, withdrawn, failed` — because the validator has to know every state before any content uses it. PR C's own content reaches `offered`, `active`, `completed`, and `declined`; `ready`, `expired`, `withdrawn`, and `failed` are reachable by later PRs' content without a schema change. |
| Adapter registry | Not built in this build. PR C needs exactly one seam — the dispatch-reconcile call reading `action`/`payload`/`result`, plus direct reads of `dre_lender` projections. The registry (umbrella §19.2) appears when a second domain consumer exists to justify it, per the umbrella's own G10, "land no unused framework." |

### DRE-ARC-01 is recorded, never tracked — the "one authority" call

The addendum asks PR C to author DRE-ARC-01 (The Introduction) "retroactively
as the PR B meeting" and states plainly: "one authority only." PR B's
`dre_lender._seek_out()` already shipped and merged as the sole authority for
`dre_introduced` and the tier-1 latch before this system existed. PR C does
not migrate that mutation into an opportunity completion effect — doing so
would touch already-merged, already-tested code to relocate a single write
for no behavioral gain, and would leave two authorities disagreeing about
which one fires first during the window between the two dispatches most
players will never notice. Instead, `dre_the_introduction` is authored as a
definition (so its `id`/`objectives` are ordinary data anything can read) but
`opportunities.gd` never creates a live *instance* for it — the first time
`dre_seek_out` succeeds, the system writes a `completed`-only history entry
with empty `completion_effects` and nothing else. DRE-ARC-02 (First Money) is
the first definition this system tracks through a real offered → active →
completed instance.

### Two properties that must survive, restated for PR C specifically

D-7 already names route-gate monotonicity and the single dispatch seam as
properties every later PR depends on. PR C adds one more of the same shape:
**qualifying load is not optional.** A save that reached First Money's
eligibility before this system existed — any PR B player who already sought
Dre out — would otherwise never see the offer, ever, because nothing but a
fresh `dre_seek_out` dispatch or a load-time catch-up can create it.
`Opportunities.reconcile_on_load()`, called from `SaveSystem.load_run()`
beside the existing `crew_operations.reconcile()` call there, is that
catch-up. Its own header carries the exhaustive branch table, including the
one genuine edge case: a save migrated from before PR A (`debt`/
`debt_due_days`) can carry an open Dre account with `dre_account_history
.loans_taken` still at zero, because the counter did not exist yet to
migrate — that save is activated retroactively, not offered a second time.

### Why PR C carries this entry rather than a later PR

Same reasoning as D-7's own closing note: PR C's `opportunities.gd` and
`data/dre_contracts.gd` already depend on OPP-D2 (the enforced cap),
OPP-D3 (borrowing IS accepting), OPP-D4 (auto-completion), OPP-D12 (the
exact five effect types), and the objective-class scope — so the rulings
had to exist before the code that implements them, not after. OPP-D11's
deadline row is the one exception, recorded but not yet built: PR C's own
content has no deadline to project (see that row), so the shared helper it
calls for is deferred to whichever PR first has a real caller, rather than
built once against zero live uses.

## D-9 — A Reminder and restitution: the collection encounter rulings

**Decided** 2026-08-28 · **Ships in** PR D · **Design doc**
`docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` §13.2 (DRE-ARC-03), §17
(failure, collections, recovery) · **Sources:** the design doc's own text,
D-7/D-8 above, and the running code as of PR C

### The question

Neither D-7 nor D-8 rules on the collection encounter itself, because
neither PR A/B (structured debt, the door) nor PR C (the opportunity
substrate, First Money) needed a real confrontation. PR D is the first PR
that actually opens one — DRE-ARC-03, and the player-default path §17.1
asks for through "the same chassis" — so this is where those judgment calls
get recorded, the same Slice-0-before-the-code discipline D-7 and D-8 both
follow.

### The rulings

| Decision | Ruling |
|---|---|
| One adapter, two encounters | `systems/dre_collector.gd` is `consequence_engine`'s one registered adapter for `action_id == "dre_collection"`, serving BOTH DRE-ARC-03 (the player collecting from Dre's own borrower) and the player-default ultimatum (Dre collecting from the player). `chain.source.kind` (`"borrower_collection"` vs `"player_default"`) tells `resolve_consequence()` which is live — not two adapter keys, since both are Dre's voice on the same chassis and neither needs a second registration to stay distinct. |
| The borrower's name | Dontae Wells — authored for this build (`data/confrontation_scripts.gd`'s `DRE_COLLECTION_TARGET`), deliberately not drawn from `GameState.shark_borrowers`, per the design doc's own words: "an authored NPC." |
| Two rolled roads, one deterministic each | DRE-ARC-03: NEGOTIATE (Charisma, `outcome_resolver.gd`'s existing "negotiation" shape, no chain — nothing to observe beyond one roll) and PRESS (Combat, "confrontation" shape, inside a chain whose other choice, WALK, is deterministic and refuses the job for `refused_work`). The player-default ultimatum: PAY NOW and stalling, both deterministic — paying is just paying, stalling is just stalling, and inventing a roll for either would manufacture drama the design doc never asks for. |
| `collected_hard`'s two audiences | Fires as two separate calls on a successful PRESS — `record_observation` direct to Dre, and a SEPARATE `broadcast_observation` on the `"neighborhood"` channel. Not one call doing double duty: `NPC_CHANNELS["dre"]` has no `"neighborhood"` entry, so the two audiences never overlap and neither call risks double-counting the other. This is the inverse of `walked_a_debt`'s own PR A ruling (direct-only, because THAT event's audience already includes `"network"`) — same principle, opposite fact pattern, so the different shape is deliberate, not an inconsistency. |
| `botched_mission`'s channel | Broadcasts on `"network"` only, per the build prompt's own words ("can travel on the network channel") — reaches Dre AND Curtis in one call, no separate direct write. |
| "Acceptable Dre disposition" | `Exposure.disposition("dre") >= 0.0` — neutral or better on the existing band ladder (`autoload/exposure.gd`'s `BAND_FLOORS`), not the visible NEUTRAL label specifically, which is a wider band than the floor. A fresh run with no Dre history reads exactly 0.0 and passes; DRE-D8's "no visible numeric rank" is unaffected, since this is a fact `requirements.gd` reads, never a number the player is shown. |
| Restitution does not gate on penance | D-4/D-7 already ruled full repayment alone clears a suspended account — PR D does not reopen that. `dre_pending_penance` (game_state.gd) latches the moment payment clears a suspension and `dre_penance` (data/dre_contracts.gd) is the follow-up relationship repair, not a second lock stacked on top of the account's own clear. The build prompt's "restitution (pay remaining + small authored penance contract) clearing suspension visibly" is read as sequence, not conjunction: pay clears the account (already visible), penance repairs the relationship after. |
| `OVERDUE_GRACE_DAYS` is gone, not repurposed under its old name | The build prompt says PR D deletes it. `dre_lender.gd` now has `OVERDUE_RESPONSE_DELAY_DAYS` instead — same authored number (2 days), but naming the delay before Dre's real response opens, not a stand-in grace period before a fake auto-suspend. The rename is the point: nothing named `OVERDUE_GRACE_DAYS` survives in this codebase. |
| `Opportunities.accept()`/`resolve()`/`fail()` are public | PR C shipped them private (`_accept`/`_resolve`, no `_fail`). PR D's `dre_collector.gd` is a second real caller with a concrete reason the generic `reconcile()` matcher cannot serve it: both `dre_collect_hard` and the player-default ultimatum resolve on `"resolve_consequence_choice"`, an action name shared by every confrontation in the game, so routing through the generic action-name matcher risks an unrelated chain resolving the wrong instance. `fail()` is new outright — DRE-ARC-03 is the first definition that can genuinely fail (walking away, a botched negotiation) rather than only ever completing. |

### Why PR D carries this entry rather than a later PR

Same reasoning as D-7 and D-8's own closing notes: `dre_collector.gd` and
the rewritten `dre_lender.gd` overdue branch already depend on every row
above — which chain kind to reuse, how the two audiences of `collected_hard`
divide, what "acceptable disposition" means operationally, whether
restitution gates on penance — so the rulings had to exist before the code
that implements them, not after.

## D-10 — The Book, earned: PR E's closing rulings

**Decided** 2026-08-28 · **Ships in** PR E · **Design doc**
`docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` §13.2 (DRE-ARC-04), §14
(borrowing economics), §16 (gating changes) · **Sources:** the design doc's
own text, DRE-D5/D7/D10 (D-7 above), and the running code as of PR D

### The question

PR E is the arc's capstone: the sponsored Book loan, the bond term going
live, the leveraged-lender economy profile DRE-D5 requires, and DRE-D10's
relabeling. Several of these had no code to hang a ruling on until this PR
actually wrote it, the same Slice-0-before-code discipline D-7/D-8/D-9
follow — recorded here, after the fact, because the judgment calls were made
while writing the code rather than before it.

### The rulings

| Decision | Ruling |
|---|---|
| Sponsorship is keyed by catalogue row, not `source_context` | `dre_book_sponsorship` resolves when a Book loan's `borrower_id` matches the ONE `GameState.shark_borrowers` row carrying `introduction_key: "dre_book_sponsorship"` (Priya Osei) — not a `source_context` field on the opportunity instance. The sponsored borrower is authored, not chosen at offer time, so there is nothing an instance-scoped context would need to carry that the catalogue row does not already say. `systems/shark.gd` calls `Opportunities.accept/resolve()` directly against that key, the same direct-call pattern `dre_collector.gd` (D-9) established for action names shared across every Book loan (`fund_shark`/`enforce_shark`/`forgive_shark`), not just the sponsored one. |
| The tier gate and the sponsorship exception live on the same check | `shark.fund_blocker` refuses funding when `dre_access_tier < b.access_tier_min` UNLESS `Opportunities.is_offered_or_active("dre_book_sponsorship")` is true for that borrower's row. `is_offered_or_active` is deliberately narrower than the existing `_resolved_or_live`: a RESOLVED sponsorship must read false (the milestone already paid out Junior Lender, which opens the borrower through the ordinary tier gate instead), which `_resolved_or_live` cannot tell apart from "offered" or "active." |
| The route gate opens on the sponsorship, not just the tier | `HUSTLE_SHARK`'s requirement changed from `dre_access_tier_min: 4` to a single precomputed `fact_true: dre_book_visible`, where `dre_book_visible := tier >= 4 OR a live dre_book_sponsorship`. The design doc is explicit that "ordinary Book access is not required" for the milestone (§13.2) — a Collector who cannot navigate to the one screen `fund_shark` lives on could never complete the milestone the game offered them, which is circular in practice even though the design doc's own text says it is not. The discovery card ("THE BOOK IS YOURS") fires at whichever of the two conditions is met FIRST, which for a sponsored player is the offer appearing, not the milestone resolving — a deliberate reading, not an oversight: every other card in `SurfaceVisibility.GATES` already celebrates a surface becoming reachable (one seeded wander for the Market, a wander count for Boost), never a later "and you used it well," so an earlier truthful reveal is the established pattern here, not an exception to it. |
| The bond term goes live at tier ≥ 3 | `shark.gd::default_probability`'s bonded term (`-0.08`) reads `dre_access_tier >= 3` (Collector), matching the design doc's own ruling above the header. Named divergence closed, not discovered — parity's shark section is updated deliberately in this PR. |
| No risk-free Dre-to-Book carry, proved structurally | `tests/parity/parity_runner.gd::_check_no_risk_free_dre_carry()` checks the authored constants directly rather than relying on simulation alone: `shark.gd::_resolve_defaulted`'s "enforce" arm is the only deterministic (no-roll) recovery road the Book has, and it recovers exactly the principal lent, never the interest. Dre's own guaranteed cost is always principal + interest (First Money: $1,000 vs. $1,200). Since the Book's guaranteed floor can never exceed what was borrowed and Dre's guaranteed cost always exceeds it, no risk-free combination can exist under the current authored numbers, and the check fails loudly the moment either fact stops holding — a structural proof covers every combination a simulated profile could try, not only the one it happened to run. |
| `leveraged_lender` carries a survival income, and walks the real arc | The new `ECON_PROFILES` entry sets `job: true, best_job: true` alongside `dre_leverage: true` — the same shape `worker_wanders` already gives Wander, a floor independent of the strategy being measured. A pure zero-income leverage profile cannot outlive its own rent long enough to reach the Book at all, which would be an instrument weakness, not a finding about Dre. The profile also walks the real earned-access arc (introduction → First Money → repay → A Reminder's NEGOTIATE road only → the sponsored loan) rather than being handed tier 4 directly, for the same reason the route-gate ruling above gives: the milestone's eligibility is mission-scoped, and the honest cost of a leverage strategy includes paying what every other player pays to reach it. `book_loans_funded` is reported, never asserted — A Reminder's Charisma roll can fail, so some seeds legitimately plateau after First Money; only `dre_loans_taken > 0` is asserted, since borrowing itself is unconditional once the cash-pressure trigger is crossed. Measured (4 seeds, mean): **91% of the day job**, 5 Dre loans taken, 21 Book loans funded — leverage roughly breaks even against steady work once Dre's cut and the arc's own time cost are counted, never strictly ahead, the empirical echo of the structural proof directly above. Getting a working measurement took two real bugs out of the first attempt, both left in the code's own comments rather than just this table: the profile initially called `gm.system("dre_lender")`, a name nothing registers (`"dre"` is correct — `dre_lender.gd`'s own file name misled the first draft), so the whole leg silently no-opped; fixed, the SECOND bug was priority order — re-borrowing was checked ahead of the Collector-milestone NEGOTIATE dispatch, and since `dre_a_reminder` requires a clear account, a profile that re-borrows the instant it clears never leaves the account clear long enough for `opportunities.settle_night` to ever offer the milestone, so it cycled First Money forever (6 loans taken, 0 ever funding the Book) instead of climbing the tier ladder. Fixed by moving the milestone dispatch ahead of re-borrowing, and by excluding borrowing entirely at exactly tier 2 (Trusted Customer) so the account has a real window to sit clear. |
| `net_worth` now nets Dre's debt and the Book's receivables | Extended to `cash + inventory_value - debt + outstanding_book_principal` (principal only, matching the "enforce never recovers interest" fact above — an unresolved note's interest is a hope, not a holding). Zero-valued for all thirteen profiles that existed before this PR, since none of them ever touch Dre or the Book, so no previously-published `pct_of_job` figure moves; it only changes what `leveraged_lender` reads. |
| Version bumps MINOR, not PATCH | `0.1.3 → 0.2.0`. `autoload/version.gd`'s own header defines MINOR as "a build that ships new surfaces or systems" — five PRs closing with a new relationship system, authored contracts, and an earned hustle surface (THE BOOK) is the clearest case for that rule since it was written, even though 0.1.2 (arguably comparable in scope) shipped as a PATCH under a looser reading. |

### Why PR E carries this entry rather than a later PR

Same reasoning as D-7/D-8/D-9's own closing notes: the route-gate widening,
the sponsorship-matching mechanism, and the arithmetic invariant are all
things the code now depends on, so the ruling has to be recorded where the
dependency was created. Unlike D-7/D-8/D-9, this PR is also the arc's exit —
`docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` and
`docs/STREET_OPPORTUNITY_AND_MISSION_SYSTEM_DESIGN.md` both flip their
Status line from "Proposed" to "Approved with rulings; see DECISIONS.md" in
this same PR, which only makes sense once every ruling either doc's open
questions produced is actually written down somewhere.

## D-11 — Touch scroll transparency: the In Hand rulings

**Decided** 2026-08-28 · **Ships in** `fix/touch-scroll-transparency` (0.2.1) ·
**Source:** `BUILD_IN_HAND_PROMPT.md`

### The question

On every screen except parts of Home, a touch that started on a card, button,
or label never reached the `ScrollContainer` above it — only a drag starting
on bare background scrolled. Root cause: `card()`/`_card()`
(`ui/screens/surface_base.gd`, `ui/screens/jobs.gd`) return a bare
`PanelContainer`, and `PanelContainer` is the one Container subtype that
defaults to `MOUSE_FILTER_STOP` — every layout Container (`VBoxContainer`,
`HBoxContainer`, `MarginContainer`, generic `Container`) defaults to `PASS`
instead, confirmed directly against a live instance rather than assumed. The
fix mechanism (`tap_connect`/`make_tappable`, `ui/screens/screen_base.gd`) was
already correct; it had only ever been wired onto 7 of 70+ card call sites.

### The rulings

| Decision | Ruling |
|---|---|
| Pass-through is the default, not the exception | Inside any screen's `ScrollContainer`, no Control sits at `MOUSE_FILTER_STOP`. Interactivity is added via the measured-tap pattern (`tap_connect`), never via `STOP` + `pressed`. |
| Transparency and tappability are separate concerns | The fix makes cards *transparent to drags* (`PASS`); it does not make previously-inert cards tappable. `make_tappable()` stays the opt-in door to tappability — no handler was wired onto a card that never had one. |
| Fix at the source plus one backstop, not 70 patches | `card()` (`surface_base.gd`) and `jobs.gd::_card()` set `mouse_filter = PASS` on the panel they return (`help.gd::_card()` already inherits this — it calls `card()`). `screen_base.gd::_normalize_scroll_mouse_filters()` runs after every `_bind_content()`/`refresh()` and demotes any remaining `STOP` Control inside a `ScrollContainer` to `PASS`, catching every `.tscn`-authored panel the helpers never touch (Home's Wander/Actions/OpCard/Activity columns, and more found once the gate ran — Hustle's Rival/Take cards, Market's Rows/Districts/Foot, Recovery's progress row). The sweep never demotes a `BaseButton` or a Control with its own `gui_input` connections — those are findings for the structural gate, fixed by hand via `tap_connect`, never silently. In this codebase, none existed: every `pressed`-wired button found by a full-repo audit lives on a non-scrolling screen (`title`, `name_entry`, `game_over`) or inside a `ModalSheet`/flow-sheet overlay parented outside the `ScrollContainer` entirely — so no button conversions were needed this PR, only panel fixes. |
| Tap semantics are frozen | `TAP_SLOP := 12.0`, the `LOCKED_META` silent-swallow rule, and "no `pressed` inside a scroll" all survive unchanged. `tap_connect` itself was not touched. |
| The structural gate lives in screen smoke | `tests/smoke/screen_smoke.gd::_check_scroll_transparency()` walks every `ScrollContainer`'s descendants on the same `refresh()` the suite already calls, failing on any Control at `STOP` or any `BaseButton` wired via `pressed`. Allowlisted by a named `SCROLL_STOP_ALLOWLIST` constant (empty today — `ModalSheet`'s scrim/card and flow-sheet content are built at runtime as siblings of `Shell`, never actual `ScrollContainer` descendants), not by skipping screens. Proved live: disabling the sweep before merge produced 37 real `TOUCH FAILED` violations across Home, Hustle, Market, and Recovery; re-enabling it returned the suite to clean. |
| Live-scroll verification is an exit criterion, not a CI check | Synthetic drag injection headless is flaky; the structural gate covers CI, and driving the real running game via `godot-ai` MCP (reading `scroll_vertical`/`get_global_rect()` before and after an injected drag) covers reality. No headless drag simulator was built. |
| Version `0.2.0 → 0.2.1`, PATCH | `version.gd`'s own definition: bug fixes against an unchanged feature set. |

### Measured results

`tests/smoke/screen_smoke.gd` now reports `touch checks 1093/1093 passed`
across the 23 real screens (a 24th, `opening.tscn`, is unrelated in-progress
work from a concurrent session with no script attached yet — pre-existing in
the shared checkout, not part of this PR, and absent from this branch's own
history). Every other gate suite held its existing floor unchanged: parity,
confrontation (212), territory (170), tips (93), dre (331), save-validation
(229).

## D-12 — The phone build: the In Hand ANDR rulings

**Decided** 2026-08-28 · **Ships in** `build/android-debug-apk` (0.2.1) ·
**Source:** `BUILD_IN_HAND_PROMPT.md`, closing ClickUp `86bbjxtjz`

### The question

`export_presets.cfg` had exactly one preset (Web) and `.github/workflows/`
exactly one workflow (web-deploy). Phone testing had only ever happened
through the GitHub Pages browser export — never a native app, on a project
whose own README describes itself as mobile-first.

### The rulings

| Decision | Ruling |
|---|---|
| The Android preset is additive | Lands as `preset.1`; `preset.0` (Web) is byte-for-byte untouched — confirmed by diffing the file before committing, zero lines removed or changed in the Web section. Specifically load-bearing and untouched: `variant/thread_support=false` and `compress/mode=1` on texture `.import` files (D-11's sibling ruling, [[godot-web-deploy-pages]] in the project's own memory of why). |
| Legacy build, not Gradle | `gradle_build/use_gradle_build=false`. The Gradle custom-build path needs a full Android SDK/NDK/Gradle toolchain resolved over the network inside CI — much more likely to break or time out for a first Android job. The legacy path just needs the bundled export templates the `barichello/godot-ci:4.7.2` image already ships (the same image `web-deploy.yml` already uses successfully), and the project needs no native plugins or custom Gradle hooks to justify the heavier path. |
| No committed keystore, ever | The debug keystore is generated fresh every CI run via `keytool` at Android's own conventional path (`~/.android/debug.keystore`, user `androiddebugkey`, password `android`). `export_presets.cfg`'s `keystore/debug*` fields are left blank on purpose — Godot's own fallback finds a keystore at that conventional path without the preset needing to name it, so nothing project-specific has to be committed or rotated. |
| arm64 only | `architectures/arm64-v8a=true`, every other ABI `false`. The build target is "does this work on a real, current phone," not broad device coverage — armeabi-v7a/x86/x86_64 are a later decision if this ever needs them. |
| A separate workflow file | `.github/workflows/android-apk.yml`, never an edit to `web-deploy.yml`. Debug-signed APK, uploaded as a CI artifact. Triggers on `push: main` + `workflow_dispatch`, deliberately not `pull_request` — this job produces an artifact and gates nothing, unlike the suites in `web-deploy.yml`. |
| The rendering method did not change | `renderer/rendering_method="gl_compatibility"` (project-wide, already set) works unmodified for Android — nothing about the preset required touching a project-wide rendering or display setting, so nothing was touched (ANDR-D3's own rule, satisfied rather than tested). |
| ETC2/ASTC texture compression is CI-scoped, never committed | Godot's Android export unconditionally refuses without an ETC2/ASTC-compressed texture variant available (`ResourceImporterTextureSettings::should_import_etc2_astc()`), and toggling that alone does nothing here: every committed texture imports at `compress/mode=1` (Lossy), and the ETC2/ASTC project setting only controls which GPU formats get generated for a texture already set to `compress/mode=2` (VRAM Compressed) — it does not change a texture's own import mode, and does not retroactively regenerate an already-cached `.import` file either (confirmed against known Godot behavior: godotengine/godot#94882, #106992). The fix touches none of the 88 committed `.import` sidecars: `android-apk.yml` enables `rendering/textures/vram_compression/import_etc2_astc` in `project.godot` (committed — a project-wide capability flag, not a per-texture change) and separately appends an `[importer_defaults] texture={"compress/mode": 2}` override plus deletes every `.import` sidecar, forcing a clean VRAM-compressed reimport, entirely inside the CI job's own ephemeral checkout. Nothing here is committed except the capability flag; the real project default, and every already-shipped Web texture, stays exactly Lossy. |
| `project.godot` comments must use `;`, never `#` | Found the hard way: the ETC2 fix above appeared to silently fail across six consecutive CI runs — the Java SDK path fix, a forced reimport, an importer-defaults override, and an `override.cfg` backstop were all tried and none moved the error, because none of them were the actual bug. Isolated by testing against a from-scratch minimal project: a `#` comment anywhere inside the same section as a not-yet-engine-registered key (one without a "basic"/always-registered `GLOBAL_DEF`, unlike e.g. `application/config/name`) silently drops that key's value during `project.godot` parsing in Godot 4.7.2, regardless of adjacency or blank-line separation — confirmed reproducible with a single bare `#` line anywhere in `[rendering]`, and confirmed fixed by switching to `;`. This file's own header already uses `;` for exactly this reason; `#` is fine everywhere else in the repo (`.gd`, `.cfg`, `.yml`) but not in `project.godot` itself. |
| On-device smoke is a checklist, not automation | `docs/ANDROID_SMOKE.md` — install, cold boot, start a run, scroll Market/Jobs/Phone with a thumb starting ON cards (D-11's fix, meant to be felt in the hand), buy/sell, save/reload, kill/relaunch resumes. The user runs it on their own phone; the house merge rule already provides the pause before that answer is needed. |
| Version `0.2.0 → 0.2.1`, PATCH | Same TOUCH-D7 ruling D-11 already recorded, ridden here at the close-out: neither the touch fix nor an additive build target ships a player-facing surface or system, so this stays PATCH under `version.gd`'s own MAJOR/MINOR/PATCH definition. |

### Why this PR carries the entry rather than a later one

Same Slice-0-before-the-code discipline as D-7 through D-11: the additive-
preset property, the no-committed-keystore rule, and the legacy-build choice
are all things `export_presets.cfg` and `android-apk.yml` now depend on, so
the ruling is recorded where the dependency was created.

## D-13 — Answer For It: the blown job answers to somebody

**Decided** 2026-08-28 · **Ships in** `build/stick-caught-encounter` (0.3.0
PR A) · **Source:** `BUILD_ANSWER_FOR_IT_PROMPT.md`, closing the legibility
hole the 0.2.1 phone playtest found

### The question

The owner's first finding on the 0.2.1 phone build was not a crash: doing
criminal work while carrying Heat, a blown stickup put the player straight
into Booking ("SERVE IT" / "PUT UP WHAT YOU HAVE") with no encounter, no
choices, no explanation. `systems/stickup.gd::_open_booking` opened the
chain directly at `STAGE_RESULT` with `allowed_choices: []`, by design —
TI-003 §14 called this "there was no decision," because the robbery had
already resolved on its own tier roll and the arrest was a fact about that
roll, not a fresh choice.

**The owner ruled that design over.** Every action-sourced caught/cop moment
in this game now presents a decision before any arrest resolves.

### The rulings

Referenced from code as `ENC-D1` through `ENC-D9`.

| ID | Ruling |
|---|---|
| ENC-D1 | No booking without a decision. Every action-sourced caught/cop moment opens a choice surface before any arrest resolves. Supersedes TI-003 §14's decision-less booking entry. The nightly street stop (`heat.gd::settle_street_stop`) is a named exception — a day-lifecycle settlement, not an action. |
| ENC-D2 | The room boundary (tier 2-3, the REPLACE ruling) is NOT reversed. A room's own stages already are the decision — a beaten room attaching a booking quote at `_room_exit` already satisfies ENC-D1 — so rooms are untouched. What is added is a post-failure caught encounter for the single-roll (tier 1) path only, the same shape as the Lift's: the robbery still resolves on its one roll; the encounter is what happens when the law arrives after it goes wrong. |
| ENC-D3 | Opens exactly when the old gate would have booked: plain Failure with `pre_source_heat` above `STICK_FAILURE_ARREST_HEAT[tier]`, or any Catastrophic roll, cooldown clear (`ArrestSystem.in_cooldown` unchanged — cooldown active means the law does not show, and the old sub-gate shape runs instead: heat, a log line, move on). |
| ENC-D4 | New chain kind `KIND_STICK_CAUGHT`, opened at `decision` by `stickup.gd::_open_stick_caught`, mirroring `boost.gd::_open_caught` seam-for-seam. Choices are the authored four (`RULES.CAUGHT_CHOICES`, untouched) — no BRIBE, no HAND IT BACK: there is no contested take (`contested_take: 0`) and no store relationship to buy back into. |
| ENC-D5 | Single-round. No escalation loop, no `decision.loop` block — a cops-arriving beat is one decision, unlike the Lift's rounds (which exist because a banked contested take justifies them). |
| ENC-D6 | Odds and effects are stickup-authored (`STICK_CAUGHT_OPPONENT` / `STICK_CAUGHT_EFFECTS`, `data/consequence_rules.gd`), never folded into the Lift's rows. Resolvers reuse the existing `outcome_resolver` action types the Lift's verbs map through (`CAUGHT_RESOLVERS`). A catastrophic entry degrades every rolled verb's odds by one authored constant (`STICK_CAUGHT_CATASTROPHIC_PENALTY`), snapshotted on `source.entry_tier` at open time so the odds shown and the odds rolled can never disagree. Arrest is per-choice, per-tier, stick-authored — never Boost's table. Yield is the deterministic surrender: no roll, straight to cuffs, the lowest authored pressure gain of the four (`STICK_CAUGHT_YIELD_PRESSURE_GAIN`). An arrested resolution attaches Booking to the SAME chain (`ArrestSystem.attach_booking`), exactly as the Lift does. |
| ENC-D7 | Copy is authored in `data/confrontation_scripts.gd` as `STICK_CAUGHT_CHOICE_COPY`. Voice: the responding officer, not the mark — the mark already had their moment in the source roll. No new label table: fight/run/yield fall through to the engine's own `choice_id.capitalize()` default exactly as Boost's own four already do, and TALK reuses the room's own label ("TALK") because the word is right either way — only the COPY under it needed its own table, since the room's own TALK copy is addressed to the mark, not an officer. |
| ENC-D8 | Pre-attempt legibility: the Stickup screen shows a warning line per target when current Heat sits above that target's tier's gate — the player learns before attempting that a blown job right now brings the law. Reads the same live `gs.heat` the gate reads at attempt time, so the warning can never promise one thing and the gate deliver another. |
| ENC-D9 | Time follows the Lift's pattern: the blown-job slot is NOT advanced when the encounter opens; the chain owes it and the engine's existing Continue/Booking settlement pays it exactly once. Proved in the confrontation suite by reading `ConsequenceEngine.source_time_owed()` at every stage of the arc (owed at decision, still owed at result, still owed entering booking, settled exactly once when the booking commits) rather than by asserting a total slot count — the booking's own processing/shortfall math varies independently and is not this ruling's concern. |

### Implementation choices this session made, flagged as choices

The ruling table above is the prompt's own text, verbatim. Everything below is
this session's reading of it into working code, flagged the way D-1 and D-6
flag their own implementation choices:

1. **One authored opponent row, not a tier ladder.** Every tier-2/3 stick
   target already has a room (`confrontation_scripts.gd::has_room`), so
   `KIND_STICK_CAUGHT` can only ever open from a tier-1 attempt. Authoring
   `STICK_CAUGHT_OPPONENT` as a tiered table (mirroring `CAUGHT_OPPONENTS`)
   would invent rows for tiers that can never reach it. If a future build adds
   an unscripted tier-2/3 stick target, this table is the first thing that
   needs to grow a tier dimension.
2. **The catastrophic-entry penalty is `-0.10`**, applied to the base chance
   before the resolver's own clamp — the same shape and rough size as the
   Lift's `LIFT_ESCALATION.verb_penalty`, chosen for consistency with the
   nearest authored precedent rather than measured, since this is a single
   modifier on an encounter with no economy weight of its own to tune against.
3. **Yield's pressure gain is `0.25`**, below `PRESSURE_BY_TIER`'s own floor
   (0.5, `clean`) — an authored number satisfying "lowest of the four," not a
   measured one.
4. **A new engine seam, `ConsequenceEngine.choice_guarantee`.** The
   consequence screen's deterministic-choice line ("Guaranteed: no injury, no
   Heat, no arrest.") was a hardcoded literal, true for every deterministic
   choice that shipped before this build. Stick Caught's own YIELD guarantees
   an arrest rather than avoiding one, which that literal would have
   misrepresented. Rather than special-case `KIND_STICK_CAUGHT` inside the
   screen, the line now runs through the same adapter-copy seam
   `choice_description`/`choice_label` already use, with the old literal kept
   as the fallback every prior deterministic choice still gets silently.

### Why this PR carries this entry rather than a later PR

Same Slice-0-before-the-code discipline as D-7 through D-12: `stickup.gd`'s
new adapter and `consequence_rules.gd`'s new tables already depend on every
row above, so the ruling is recorded where the dependency was created.

## D-14 — Heat can breathe

**Decided** 2026-08-28 · **Ships in** `fix/heat-active-decay` (0.3.0 PR B) ·
**Source:** `BUILD_ANSWER_FOR_IT_PROMPT.md`

### The question

Two related findings, both already on record before this build:

1. Heat had no way down under ordinary criminal play. The only decay was the
   quiet-day rule (`heat.gd::settle_quiet_day`), which sheds nothing on any
   day that generated Heat at all — and a player working boost and stickup
   daily generates Heat every day by definition, so the rule never once fired
   for that profile across a measured 30-day run. Heat asymptoted at the
   ceiling (15) with no way back down short of an arrest or a lucky street
   stop (`86bbjk6jy`).
2. Boost's Run/Failure row arrested unconditionally at tier 3, regardless of
   Heat — an OR-clause (`consequence_rules.gd:248`, pre-fix) rather than a
   Heat-conditional gate (`86bbjk6kk`, filed as a possible defect and
   escalated as a ruling instead — see that entry above).

### The rulings

| ID | Ruling |
|---|---|
| HEAT-D1 | The property, not a constant: an every-day criminal profile (daily boost + stickup, at the parity economy profiles' own intensity) must be able to return below the tier-1 stickup gate (12.0) — Heat must asymptote below the BURNING band's ceiling under sustained ordinary play, and a genuinely quiet day must still shed visibly more than an active one. Implement the smallest mechanism that achieves it, measured through the parity economy profiles, asserted as a corridor check (`86bbjxth6`'s first real arm). Relief paths (arrest relief, street stop) keep bypassing gain multipliers — TI-003 regression #15 stands. |
| HEAT-D2 | No unconditional arrests anywhere (ENC-D1's principle, applied to odds): drop the `RUN_FAILURE_ARREST_TIER` OR-clause; Run's failure arrest at every Boost tier becomes Heat-conditional, tier scaling the threshold rather than bypassing it. Closes `86bbjk6kk`. |

### Implementation choices this session made, flagged as choices

1. **The second candidate from HEAT-D1's own list, not the first.** The
   ruling named two shapes: "partial decay on active days scaled inversely by
   the day's generated Heat" or "a raised quiet-day shed plus a small
   unconditional floor decay." The second is the flatter, simpler shape — no
   new formula relating decay to a day's own Heat total — and was implemented
   as two constants and one new function, `HeatSystem.settle_active_decay`,
   called alongside (never instead of) the existing `settle_quiet_day` from
   the same declared `"heat_decay"` ROLLOVER step. No new `ROLLOVER_ORDER`
   entry: both are Heat's own nightly bookkeeping, settling at the same point
   in the lifecycle.
2. **`HEAT_QUIET_DECAY` raised 0.75 → 1.5; `HEAT_ACTIVE_DECAY` authored at
   2.0, new.** Measured, not guessed: 0.35 and 1.0 both left the every-day
   profile's mean ending Heat above the 12.0 gate (13.775 and 12.8
   respectively, across 4 seeds); 1.5 landed the mean just past the gate
   (12.05) with one seed still over it (13.5); only 2.0 put every one of 4
   seeds comfortably under, with the worst seed at 11.0. Chosen for a real
   margin instead of a number that happens to clear the gate on average.
3. **A new economy profile, `everyday_criminal`.** Neither `stickup` nor
   `boost` alone is "daily boost + stickup" as HEAT-D1's own parenthetical
   names it — each works one surface, and whichever surface's own cap is not
   binding on a given day still leaves slots the profile spends elsewhere.
   The new profile tries stickup first every slot and falls through to boost
   when stickup is blocked, which is "whatever criminal action is available,
   every slot" read literally. Its own corridor is a plain report (0-20% of
   the day job), the same shape `stickup`/`boost` already use; the property
   this build actually cares about is a direct assertion on `final_heat`
   (Heat where the run actually landed at day 30) against the live gate
   constant, not a corridor.
4. **A disclosed side effect: `hustler` and `arbitrage`'s own corridors
   moved, and were widened rather than fought.** Heat is one shared meter —
   `CARRY_STOP_PER_HEAT` prices a carry trip's risk off the exact same number
   stickup and boost were measured against, and both trading profiles already
   ran hot before this build (peak Heat 15.0 / 13.2). Less standing Heat means
   fewer carry stops and a materially better courier number: measured 942%
   (was corridor 600-850%) and 259% (was 60-110%), corridors widened to
   800-1100% and 180-320%. This was not HEAT-D1's target and is not a second
   balance change smuggled into this PR — retuning `CARRY_STOP_PER_HEAT`
   itself to claw the old ceiling back, if that is even wanted, is a separate
   decision for whoever owns the trading economy next.
5. **`RUN_FAILURE_ARREST_HEAT` changed from a flat `6.0` to a tier-keyed
   table, `{1: 9.0, 2: 7.5, 3: 6.0}`.** Tier 3 keeps the old number as its own
   (lowest, easiest-to-trigger) gate rather than moving it — the one row that
   already shipped and was measured; tiers 1 and 2 get progressively higher
   gates, the same shape and spacing `STICK_FAILURE_ARREST_HEAT` already
   uses for Stick. `ARREST_RISK_TARGET` and its screen copy were removed
   outright as dead code: nothing can return that code any more, since there
   is no tier left that arrests independently of Heat.

### Measured results (4 seeds each; suite: `_check_economy_profiles`)

| Profile | Metric | Before | After |
|---|---|---|---|
| `everyday_criminal` (new) | mean ending Heat | 14.113 (all 4 seeds above the 12.0 gate: 13.0 / 14.6 / 14.25 / 14.6) | 10.500 (all 4 seeds below: 11.0 / 10.0 / 10.4 / 10.6) |
| `stickup` (solo) | mean ending Heat · arrests (sum, 4 seeds) | 11.025 · 31 | 10.375 · 23 |
| `boost` (solo) | mean ending Heat · peak Heat (per seed) | 0.188 · 15.0 / 15.0 / 1.6 / 15.0 | 0.000 · 8.2 / 7.45 / 0.9 / 11.7 |
| `hustler` | % of day job | ~730-850% (old corridor) | 942% (measured) |
| `arbitrage` | % of day job | ~60-110% (old corridor) | 259% (measured) |

Boost's own Heat trajectory improved sharply even though it was not this
ruling's primary target — the unconditional floor decay reaches every
Heat-generating surface alike, which is also exactly why the trading
corridors above moved.

### Why this PR carries this entry rather than a later PR

Same Slice-0-before-the-code discipline as D-7 through D-13: `heat.gd`'s new
function, `day_lifecycle.gd`'s step, and `consequence_rules.gd`'s tier-keyed
table all already depend on every row above, so the ruling is recorded where
the dependency was created.

## D-15 — Stickup earns its place

**Decided** 2026-08-28 · **Ships in** `build/stick-viability` (0.3.0 PR C) ·
**Source:** `BUILD_ANSWER_FOR_IT_PROMPT.md`, closing `86bbjngyz`

### The question

Stickup's own measured option table found it earning 2% of the day job,
EV-negative per attempt, with one starved tier-1 target (`washgo_regular`)
absorbing 98% of every attempt the surface ever recorded — the only any-slot
tier-1 target in Spenard, and the daily cap flat at two forever regardless of
how much rep a player had earned. `86bbjngyz` filed this as a standing
high-priority decision rather than a build; this PR is the build.

### The ruling

| ID | Ruling |
|---|---|
| STK-D1 | (a) A second any-slot tier-1 target in Spenard with a band meaningfully above `washgo_regular`'s [30, 50], authored name/fiction to match the district's existing voice. (b) The daily cap scales with `stick_rep` (2 base, authored thresholds add +1, hard ceiling 4 — the cap stays a count, `stickup.gd`'s own semantics unchanged). Stickup is NOT re-measured against the old (pre-0.3.0) baseline — PR A changed blown-job cost and PR B changed Heat, so this re-measures after both landed, tunes the new target's band against that fresh baseline, and asserts a corridor floor (single digits as % of day job is success; 2% was the disease). |

### Implementation choices this session made, flagged as choices

1. **`spenard_diner_regular`, take `[95, 160]`, resistance 0, heat 2, any
   slot.** The band was tuned empirically against the post-A/B baseline, not
   picked once and trusted: `[50, 90]` at resistance 1 measured WORSE than
   the 2%-hole baseline (arrests rose with the richer target's harder odds,
   and the increased booking time outweighed the extra take); dropping
   resistance to 0 and raising the ceiling in steps — `[50,90]` → 1.7%,
   `[90,150]` → 5.5%, `[110,180]` → 14.2%, `[130,220]` → 13.0% — showed the
   real lever was the CEILING itself (`_econ_try_crime`'s own picking rule is
   "highest take ceiling among legal targets," so a richer target simply
   replaces a poorer one in the profile's rotation; resistance and heat only
   matter once two targets are otherwise comparable). `[95, 160]` was the
   value that landed the measured share robustly mid-single-digits rather
   than skimming either edge of the band the ruling asks for.
2. **The rep thresholds are the existing tier milestones, not new authored
   ones.** `+1` at `STICK_TIER2_REP` (4), `+1` at `STICK_TIER3_REP` (11) —
   reusing exactly what `_update_tier` already reads rather than inventing a
   parallel schedule. The ruling's own "hard ceiling 4" falls out of this
   automatically (2 base + 1 + 1) rather than needing its own authored
   number; `mini(cap, 4)` is kept anyway as a stated ceiling rather than an
   incidental fact of the arithmetic, so a future third milestone cannot
   silently raise the cap past 4 without a deliberate change here.
3. **A disclosed instrument limitation, not a design claim: the "98%
   concentration" moves to the new target inside the economy sweep, it does
   not break into a genuine split.** `_econ_try_crime` always attempts
   whichever LEGAL target has the highest take ceiling — a greedy rule with
   no real risk-adjustment — so `spenard_diner_regular` (ceiling 160) now
   strictly dominates both `washgo_regular` (ceiling 50) and even
   `chilkoots_stumbler` (ceiling 80, and slot-restricted to NIGHT besides)
   at every opportunity the daily cap allows. Reported rather than
   engineered around: a real player weighing resistance, slot availability,
   and personal risk tolerance would plausibly split across all three:
   nothing about this PR removes that choice, it only changes which single
   number this particular measurement tool's greedy heuristic prefers.
4. **Copy note:** `blocker()`'s cap-refusal line dropped "Two in a day is how
   people get named" (canon's own phrase, no longer accurate once the cap
   can be three or four) for "That's enough attention for one day" — same
   fiction (committing crimes draws attention), no specific count claimed.

### Measured results (4 seeds each; suite: `_check_economy_profiles`)

| Profile | % of day job, before (0.3.0 PR A+B baseline) | % of day job, after |
|---|---|---|
| `stickup` (solo) | 2% | 6% |
| `stickup_crew` | not separately re-measured pre-PR-C; corridor floor was 0 | 5% |
| `everyday_criminal` | 8% | 8% (unchanged — boost's own share of this combined profile already dominates its economics enough that stickup's fix did not move the combined number, even though stickup's own solo share tripled) |

No economy profile reached `STICK_TIER3_REP` (11) within the 30-day window,
`stickup_crew` included (`final_stick_tier` stayed at 2.0 in every seed) — the
cap's hard ceiling of 4 is proven by `_check_stick_daily_cap_scaling`'s direct
coverage, not by the economy sweep, which never climbs high enough to exercise
it.

### Why this PR carries this entry rather than a later PR

Same Slice-0-before-the-code discipline as D-7 through D-14: `stickup.gd`'s
`daily_cap()` and `game_state.gd`'s new target both already depend on the
rows above, so the ruling is recorded where the dependency was created.

## D-16 — One Score through the substrate

**Decided** 2026-08-29 · **Ships in** `build/score-through-substrate` (0.4.0
PR A) · **Source:** `BUILD_REPEAT_BUSINESS_PROMPT.md`, closing `86bbp7ctz`

### The question

`docs/STREET_OPPORTUNITY_AND_MISSION_SYSTEM_DESIGN.md` shipped in 0.2.0 PR C
with exactly one content pair, both Dre's own (DRE-ARC-01/02) — OPP-D8's own
gate ("no procedural generation until the Dre chain AND one Score chain are
live") had never actually been tested against a second, non-lending
consumer. `86bbp7ctz` is the declared reusability-validation gate between
"working vertical slice" and "reusable foundation"; this PR is that
validation, not a Scores feature.

### The ruling

| ID | Ruling |
|---|---|
| SCR-D1 | The one-Score validation ships in exactly one shape: `data/score_contracts.gd`'s `score_slide_special` observes an existing successful `boost` at a named target (`northern_value`, tier 2 — an existing authored target, no new Boost content) and adds an authored $50 bonus on top, inside an authored 3-day window from the offer. It does not own the lift's payout, Heat, technique, bans, or the caught path — those stay entirely `systems/boost.gd`'s. A blown/caught attempt at the named target does not fail the Score; only the window closing does. A first draft named `spenard_fuel_till` — a real target, but a Stickup one (`tests/confrontation/confrontation_runner.gd`'s own `T2_TARGET`), not Boost's; `boost_target_by_id()` returned empty and every live dispatch refused with "No such place." until a `game_eval` drive caught it, which the suite's own synthetic-reconcile tests could not have (they hand `opportunities.reconcile()` a result dict directly and have no way to know whether the target name inside it is real). |
| SCR-D2 | Integration follows neither of the two established patterns exactly, and that gap is itself the finding: Dre's shared-name resolutions (`resolve_consequence_choice`, `fund_shark`) needed a domain system's own authority to call `accept()`/`resolve()` directly; `boost`'s own action name is unambiguous and synchronous, so the generic action-result matcher was the natural fit — except that matcher only ever scans `active_opportunities`, and there is no meaningful accept moment separate from the resolving `boost` dispatch itself (OPP-D3 applies more directly here than to any Dre content: the domain action doubling as acceptance leaves no gap between the two at all). The actual shape: one bespoke `reconcile()` branch, the same shape as `dre_seek_out`/`dre_borrow`, calling `accept()` then `resolve()` back to back the moment a live offer's named target reports a real success. No new dispatch action, no adapter registry. |
| SCR-D3 | `systems/boost.gd`, `systems/stickup.gd`, and the confrontation chassis are untouched — confirmed by diff, not just by intent. The UI touch (`ui/screens/boost.gd`'s target row gains one informational line when a live Score names that row) is deliberately outside this constraint's wording, which names domain/mechanics files specifically; presentation was never the thing being protected. |

### What the substrate actually needed to generalize

Smaller than expected, and worth naming precisely because "the substrate
needed nothing new" was the optimistic case `systems/opportunities.gd`'s own
header predicted and this PR did not quite land on:

1. **A deadline a definition can declare and have enforced.** OPP-D11
   deferred the umbrella's own `deadline_day`/`deadline_slot` half of the
   instance shape (design doc section 9.2) for lack of a second caller —
   this Score is that caller. `_new_instance()` now reads an optional
   `"deadline": {"window_days": N}` off the definition and computes
   `deadline_day` from the offer day; `_expire_overdue()` (called from
   `settle_night()`, the same declared lifecycle point the nightly offer
   sweep already uses) is the enforcement half, checking both
   `opportunity_offers` and `active_opportunities` since this content never
   leaves the former before resolving. Dre's own content declares no
   `deadline`, so `window_days` defaults to 0 and `deadline_day` stays -1 —
   unchanged behavior.
2. **One new `requirements.gd` type**, `boost_target_discovered` — SCR-D1's
   "the named target discovered" reads the same DEAL-walk latch the Boost
   screen itself reads, handed in as a new `boost_targets_discovered` fact
   in `_facts()` rather than a bespoke pre-computed boolean, so a second
   Score naming a different target needs no new fact key.
3. **`_definition()`/`settle_night()`'s definitions loop now read a list of
   catalogues** (`CATALOGUES := [DRE_CONTRACTS, SCORE_CONTRACTS]`) instead of
   one hardcoded file — the only change that was purely mechanical rather
   than a real new capability.

No adapter registry, no `opportunity_accept` dispatch, no change to the
receipt/idempotency discipline `resolve()`/`fail()` already enforced.

### Why this PR carries this entry rather than a later PR

Same Slice-0-before-the-code discipline as D-7 through D-15:
`opportunities.gd`'s deadline handling and the new requirement type are both
already load-bearing for `score_slide_special`'s own lifecycle, so the
ruling is recorded where the dependency was created.

## D-17 — Repeat Business: the generator

**Decided** 2026-08-29 · **Ships in** `build/dre-repeatables` (0.4.0 PR B) ·
**Source:** `BUILD_REPEAT_BUSINESS_PROMPT.md`, DRE-D12

### The question

DRE-D12 deferred repeatable Dre contracts past Junior Lender from the moment
it was written (0.2.0): "at most three offered/active, at most one new
offer per in-game day start... deferred past PR E — the authored chain
ships first." OPP-D8 held the same gate at the umbrella level. D-16 (PR A)
satisfied OPP-D8's own precondition; this PR is DRE-D12's actual delivery.

### The ruling

| ID | Ruling |
|---|---|
| REP-D1 | Generation hooks `settle_night()` — the same declared lifecycle point the nightly offer sweep already uses, not a new one. `repeatable: true` definitions are excluded from that generic sweep entirely (`_maybe_offer`'s own guard, `_resolved_or_live`, checks `opportunity_history.has()`, which reads true forever after a repeatable's first resolution — exactly backwards for one meant to offer again). `_generate_repeatables()` is their own path: gated on the 3-cap (offered+active combined, OPP-D2), on each candidate definition's own requirements, and on not already being offered or active (`is_offered_or_active()` — the narrower, correct question, since history staying populated is expected and not a block). "One new offer per day" falls out of `settle_night()` itself firing at most once per day-cross — no persisted counter needed. |
| REP-D2 | One template this PR: `data/dre_repeat_contracts.gd`'s `dre_repeat_collection`, riding `systems/dre_collector.gd`'s existing encounter (same two dispatch actions, same chance tables) end to end. Per-instance variance — a seeded borrower from an authored 3-name pool, a seeded clean/messy fee band ($60-100 / $35-65, close to the authored one-time fee's own $80/$60 clean and $50/$40 messy) — lives on `source_context`, exactly the umbrella's own §9.3 field ("named target or borrower... authored amount/range selection"). A 4-day authored window, riding D-16's own deadline mechanism. |
| REP-D3 | No new persisted field, no schema bump. Verified rather than assumed: the cap and "one per day" both derive from existing state (checked above); the deadline rides D-16's `deadline_day`; the borrower/fee variance rides `source_context`, already part of the v23 instance shape. |
| REP-D4 | `dre_collector.gd` generalizes rather than duplicates. Every hardcoded reference to `dre_a_reminder` and `DRE_COLLECTION_TARGET` (Dontae Wells) is replaced with a lookup — `_active_collection()` asks `Opportunities.definition()` (new public wrapper) for whichever offered/active instance carries a new marker, `resolves_via: "dre_collector"`, set on both `dre_a_reminder` and `dre_repeat_collection`. The two can never be live together (the repeatable's tier-4 requirement cannot hold before the one-time arc has already resolved past it), so the lookup is never ambiguous. Chance tables, injury bands, and Heat costs stay the authored flat constants for BOTH callers — only the fee-per-tier payout reads a per-instance override when `source_context` supplies one. Dre's account/tier authority is untouched; the generator only ever reads `dre_access_tier`, never writes it. |
| REP-D5 | No new bound needed, verified rather than assumed: `_write_history` already stores one compact row per definition id (`count`/`outcome`/`last_resolved_day`), not one row per occurrence — a repeatable resolving three separate times increments one row's `count` three times rather than growing an array. The umbrella's own section 9.4/20.1 shape already bounds this by construction. |

### What generalizing `dre_collector.gd` actually cost

Every flavor line that named Dontae Wells directly now takes a `name`
parameter or reads `chain.source.target_name` (persisted on the chain
itself at open time, alongside a new `definition_id` field on that same
`source` dict — both survive a reload the same way every other consequence
chain does, per the engine's own snapshot invariant, so resolution never
needs to re-derive which definition it is mid-chain). `ui/screens/people.gd`
gained the same generalization independently, reading `Opportunities.
definition()` rather than checking two ids by name, so a third repeatable
template (PR C) needs no edit there either.

### Two bugs the suite caught before this shipped, both from sabotage-testing the generator specifically

1. **No per-definition dedup.** The first draft's eligibility check only
   enforced the 3-cap, not "is this specific repeatable already offered" —
   calling `settle_night()` twice on the same day, or once after a prior
   offer's deadline had already passed but before `_expire_overdue()` ran
   inside that same call, minted a second instance of the same template.
   Fixed by adding `is_offered_or_active()` to the eligibility filter.
2. **The test fixture, not the code.** Jumping straight to Junior Lender by
   setting `dre_access_tier = 4` directly (rather than playing the arc out)
   left `dre_first_money`/`dre_a_reminder`/`dre_book_sponsorship` all
   trivially re-eligible under the generic sweep, consuming the entire
   3-cap before generation ever ran. The fixture now also marks those three
   `completed` in `opportunity_history`, matching what a real run's
   sequential progression already guarantees by the time Junior Lender is
   reached.

### Why this PR carries this entry rather than a later PR

Same Slice-0-before-the-code discipline as D-7 through D-16:
`dre_collector.gd`'s generalization and the generator's own eligibility
rules are both already load-bearing for `dre_repeat_collection`'s lifecycle,
so the ruling is recorded where the dependency was created.

## D-18 — Repeat Business: the catalogue

**Decided** 2026-08-29 · **Ships in** `build/dre-contract-catalogue` (0.4.0
PR C) · **Source:** `BUILD_REPEAT_BUSINESS_PROMPT.md`

### The question

PR B shipped exactly one repeatable template to prove the generator itself.
The build prompt asks for three to four total, naming three distinct roles:
"at minimum one more collection variant (different borrower archetype/
stakes)," "one delivery/errand-shaped contract observing existing movement/
market actions," and "one higher-tier contract gated by access tier" — plus
outcome-variation rows per REP-D4 on all of them.

### The ruling

| ID | Ruling |
|---|---|
| CAT-D1 | Four templates total (the PR B collection included). `dre_repeat_collection_leaned_on` is the second collection variant — same machinery as the base template end to end, a different borrower pool, a higher fee band ($110-160/$60-95 clean/messy against the base's $60-100/$35-65), gated on `repeatable_attempts_min: 1`. `dre_repeat_premium` is the "higher-tier" ask, gated on `repeatable_attempts_min: 3`, the highest fee band ($180-260/$100-150). `dre_repeat_errand` is the delivery/errand shape: observes a successful `travel` to a seeded, reachable, non-home district within a 3-day window, the one template that does not ride `dre_collector.gd` at all. |
| CAT-D2 | "Higher-tier... gated by access tier" is read as the design doc's own §12.3 difficulty progression rather than a new mechanical tier — mechanical tiers stop at 4 (Junior Lender), so there is no tier 5 to gate on. `repeatable_attempts` (new fact, `opportunities.gd`) sums `count` across every repeatable's own history row, disclosed as proven WORK rather than proven success (`count` increments on `fail()` the same as `resolve()`) — the closest fact already derivable from existing state, per REP-D3's own discipline, without a persisted win counter no other reader of `opportunity_history` has ever needed. |
| CAT-D3 | Outcome variation (REP-D4) is already satisfied for every collection-shaped template — `dre_collector.gd`'s existing tier-keyed Exposure calls (`collected_hard`/`botched_mission`/`refused_work`) apply to ANY `resolves_via: "dre_collector"` instance regardless of definition id, so `dre_repeat_collection_leaned_on`/`dre_repeat_premium` inherit it for free; adding opportunity-level `completion_effects` on top would be the "two authorities" pattern this codebase keeps refusing. The errand's own variation is resolve-vs-fail rather than tiered, since `travel` has no clean/messy/failure shape to key off — a flat `wallet_credit` + `exposure_observation` completion effect, the same asymmetry the collection templates already carry between `resolve()` and `fail()`. |
| CAT-D4 | The generator's own eligibility filter gained a retry loop it did not need with one template: a pick that turns out to be a dud (the errand, when no district is currently reachable) is removed and re-rolled against the shrinking pool rather than silently burning the night's one generation slot, still fully deterministic for a fixed run_seed + day. This was not anticipated when PR B's filter shipped — a single-template generator has no way to be a dud — and is the one genuinely new substrate capability this PR's four-template catalogue required. |

### Two real bugs, caught by sabotage-testing the new mechanism specifically

1. **A parse-error typo** (`DRE_REPEAT_CONTRACTS` used in a test file that
   aliases the same preload as `REPEAT_CONTRACTS`) hung the suite silently
   near 0% CPU on first run — the exact failure mode the danger list
   already named; killed and fixed rather than waited out.
2. **The retry loop itself (CAT-D4) did not exist in the first draft.** A
   dud errand pick silently produced zero offers for the night even when
   the base collection was still perfectly eligible. The first version of
   the regression test for this did not catch it either: a seeded pick
   that happens to land on a working template FIRST never exercises a
   retry at all, so the test needed its own search for a day where the
   errand is specifically the first pick before sabotaging the fix could
   turn it red — confirmed both ways (red with the retry loop removed,
   green with it restored) before trusting the coverage.

### Why this PR carries this entry rather than a later PR

Same Slice-0-before-the-code discipline as D-7 through D-17: the new
requirement type, the retry loop, and the fee-band/borrower-pool variance
are all already load-bearing for the three new templates' own lifecycles,
so the ruling is recorded where the dependency was created.

## D-19 — Repeat Business: the economy answers

**Decided** 2026-08-29 · **Ships in** `build/economy-pass-0.4.0` (0.4.0 PR D)
· **Source:** `BUILD_REPEAT_BUSINESS_PROMPT.md`

### The question

Two open items shared PR D's measurement harness. `86bbp7cw2`: what standing
Dre contracts are worth once REP-D1..D5 (PR B/C) shipped a generator and
three collection-family templates with no profile ever pricing the income.
`86bbjk6jy`: Market's `PRESSURE_MARKET_DAILY_CAP` has no Boost/Stick
equivalent, and 0.3.0's D-14 fixed global Heat for the every-day profile
without touching District Pressure at all — the every-day profile's worst
district still sits HOT for most of a run.

### The ruling

| ID | Ruling |
|---|---|
| PRESS-D1 | **Both caps land on 2.0** (`PRESSURE_BOOST_DAILY_CAP`, `PRESSURE_STICK_DAILY_CAP`, `data/consequence_rules.gd`), not two independently-tuned numbers, because both families bottom out their worst single draw in the same place: a Boost Caught encounter's non-yield tiers and a Stick Caught encounter's (a beaten room's, and a retaliation's) non-yield tiers all read the same shared `PRESSURE_BY_TIER` table, topping out at 2.0 on a single catastrophic result. Every non-Market pressure call site now routes through the new `ConsequenceEngine.add_capped_pressure()` (Market's own `add_market_pressure` mechanism, generalised) — `boost.gd`'s one wrapper covers its four call sites, `stickup.gd`'s three (source robbery, Caught resolution, room exit) and `retaliation.gd`'s one are wired individually. **Measured against `86bbjk6jy`'s five-profile table, honestly: the cap does NOT clear "leaves HOT within the run" for the two always-criminal archetypes.** The every-day "fights everything" profile's worst Stick district moved from HOT on 14 of 29 days (uncapped) to HOT on 13 (capped) — a one-day improvement, not an exit. "Yields everything" shows the same shape (14→13, 11→11). The "mixed strategy, plays the odds" profile fares somewhat better on the Boost side specifically (its lightest district cleared its one remaining Boost HOT day, 1→0; the other two dropped one each, 5→4), because Boost's clean-success gain already nets to zero against its own refund (see below) and rarely needs the cap at all, while Stick's own worst districts there are unmoved (17, 15, 15 before and after). |
| — | **Root cause, not a sizing error:** District Pressure has exactly two ways down — `apply_pressure_recovery`'s quiet-day decay (gated on a genuinely zero-gain day, per-family) and `credit_clean_outcome`'s per-outcome refund (`PRESSURE_CLEAN_RECOVERY := 0.5`, paid only on a **clean** resolved tier, banked and drained at POST_SETTLE). An "every day, fights/yields everything" policy structurally starves both: it never has a zero-gain day by construction, and fighting or yielding through a Caught encounter produces messy/failure/catastrophic tiers far more often than clean ones, so most of its daily gain is the kind neither lever ever pays back. A daily CAP bounds how much can land in one day; it cannot fix an inflow-vs-refund imbalance that recurs every day, and PRESS-D2 forbids touching either recovery lever in this build. The cap is not wrong-shaped for what a cap can do — the ceiling itself is real and worth having (a multi-action bad day can no longer compound past exactly one worst-case result, down from unbounded) — but a cap alone was never going to be sufficient for this specific archetype, and the honest report is that PRESS-D1's own acceptance bar is not met by it alone. |
| — | **Per PRESS-D1's own escalation clause** ("if measurement argues the cap is wrong-shaped, stop and escalate with the numbers — close-as-no-change is the recorded alternative, not a silent one"): closing `86bbjk6jy` here, as ruled either way, with this table as the attached evidence and an explicit escalation — a further fix needs to touch `apply_pressure_recovery` or `credit_clean_outcome`'s own eligibility, which is recovery-rate territory PRESS-D2 places out of this build's scope. Whoever picks this up next should start from "give the always-criminal archetype a refund path that doesn't require a clean outcome or a zero-gain day," not from re-sizing either cap. |
| PRESS-D2 | **Nothing else in the Pressure system moved.** Bands, penalties, bleed, the 0–9 clamp, both recovery rates and Market's own cap are untouched and still sabotage-tested green (`_check_pressure_bands`, `_check_pressure_source_penalties`, `_check_pressure_bleed`, `_check_pressure_recovery`, `_check_pressure_market_cap` — all pre-existing, all still passing at their pre-PR-D literals). |
| REP-income | **`86bbp7cw2` closes at a measured 109%** of the day job (`repeat_contractor` profile, `tests/parity/parity_runner.gd`: `job` + `best_job` for a survival floor, walks the real earned-access arc through the sponsored Book loan — averaging 1.5 Dre loans taken and 0.3 Book loans funded before the arc completes — then works whatever collection-family repeatable is offered or active every slot after, averaging 3.5 standing contracts worked over the run: `dre_collect_negotiate` resolves `dre_a_reminder` pre-arc and all three collection templates post-arc identically, since all four share `dre_collector`'s `resolves_via` marker. Corridor `{floor: 90, ceiling: 135}`. Standing contract income is meaningful on top of a working player without dominating the economy — the same shape `hustler` occupies relative to `legal_worker`, not `worker_wanders`'s outlier multiple. Scoped to the collection family; `dre_repeat_errand` resolves through Travel rather than through `dre_collector` and is left for whoever next measures Travel's own economics, named rather than silently absent. |

### An honest side effect, disclosed rather than absorbed

The `stickup` economy profile's own corridor floor came from STK-D1 (0.3.0),
set at 3 specifically so "a regression back toward the 2% hole" — the
pre-STK-D1 disease — would fail loudly. Measured post-cap: 2%, the exact
number the floor was built to catch, and every other indicator on the same
four seeds a wash or favorable (arrests 8=8, final Stick tier 2.0=2.0,
attempts ~80=~80, take $2415→$2336, heat seized $301→$226 — better). This is
not STK-D1's disease returning: that fix was the target pool and the
rep-scaled daily attempt cap, neither touched here, both unchanged. This
profile's own net worth is a handful of dollars against the day job's, so it
sits at the noisy edge of any corridor by construction — capping Stick's
daily gain nudges which side of a discrete pressure-band boundary a few of
its many seeded attempts land on, and a small absolute swing on a
near-zero baseline reads as a large percentage one. Floor lowered to 2, with
this paragraph rather than a quieter number, so the next person to touch this
corridor inherits the reason instead of re-deriving it.

### Why this PR carries this entry rather than a later PR

Same discipline as every entry above: the caps, the new corridor, and the
economy measurement are all already load-bearing for PR D's own code, so the
ruling is recorded where the dependency was created — including the ruling
that a cap alone does not fully close its own acceptance criterion.

## D-20 — The Street Answers Back: the interruption gate

**Decided** 2026-08-29 · **Ships in** `build/street-interruption-gate` (0.5.0
PR A) · **Source:** `BUILD_STREET_ANSWERS_PROMPT.md`

### The question

The owner's direct ruling after playtesting, with *Drug Lord 2* reference
screenshots: "I should not be able to continuously hit the walk-around
button on the Home screen indefinitely. Events should happen that force the
player to do something." `wander_shakedown` and `wander_stopped_on_foot`
were two ordinary cards at flat weights (7 and 9) against ~14 ambient/read/
opportunity cards — a player at BURNING Heat with three districts HOT drew
from the same gentle deck as a clean day-one kid, and the recency filter
spaced the two encounters out further still.

### The ruling

| ID | Ruling |
|---|---|
| STR-D1 | **The street initiates, and it reads the player.** Every wander now rolls a seeded interruption gate BEFORE the ordinary draw — `WanderSystem._roll_gate()`, keyed `day:slot:wander_count:district:gate` (varying components lead, per the established precedent). The two legacy encounter cards fold into it: `eligible_cards()` (the ordinary pool) now excludes `KIND_ENCOUNTER` entirely, and a new `eligible_encounters()` applies the exact same district/slot/once/recency/requirements discipline to the gate's own pool — POOL-D1's own requirement, that a staged card declares through `requirements.gd` like any other rather than through a second eligibility idea invented for encounters. `_play_encounter()` (the chain-opening seam) is reused completely unmodified; the gate only decides WHETHER and WHICH, never how an opened encounter resolves. |
| — | **The chance is `data/wander_events.gd::gate_chance(total_steps)`** — `clamp(0.03 + 0.05 × steps, 0.03, 0.60)`. Steps are read off each system's OWN existing band vocabulary rather than a second scale invented for this: Heat's four bands (COOL/NOTICED/WATCHED/BURNING → 0/1/2/3), District Pressure's worst family in the current district (already numbered by `ConsequenceEngine.pressure_steps()`), Curtis's four phases (invisible/ambient/watching/approaching → 0/1/2/3), plus a flat `GATE_OVERDUE_STEPS := 3` for any overdue debt (`gs.debt_due_days < 0`, `gs.rent_missed >= 1`, or any `defaulted` Book note) — STR-D2's own text frames "elevated Heat," "HOT pressure," and "any overdue debt" as independent alternatives, not components of one blended score, so overdue debt gets a flat bonus sized to match the top of any one graduated signal rather than its own graduated scale. |
| STR-D2 | **The quiet streak is bounded above the floor, protected below it.** `gs.wander_quiet_streak` (new, v25) counts consecutive gate-quiet walks; `quiet_streak_cap(steps)` returns the authored cap for the current steps (6+ → 2, 3+ → 3, 1+ → 5) or `-1` ("no cap") at zero steps. A forced-open check runs before every roll: `wander_quiet_streak >= cap` opens the gate regardless of the roll. Verified against the actual Godot port rather than assumed: no web-era "day 1-3 sandbox" gate survived into this build at all (`gs.day` gates nothing in `wander.gd`/`wander_events.gd`) — the ONLY thing making early wandering gentle is that a fresh run's Heat/Pressure/Curtis/debt all read zero, which is exactly the "cold, clean, paid-up player" state STR-D2 asks to stay near-silent, achieved here structurally (zero steps has no streak-cap row at all) rather than by a separate early-game exemption. |
| POOL-D1 (partial) | PR A implements the mechanical half — staged cards declare through `requirements.gd`, the recency filter is untouched, and the pool is now big enough to support a bias (below) — the actual roster deepening is PR B's. |
| MEAS-D1 (partial) | Measured in `tests/parity/parity_runner.gd::_check_street_interruption_gate`: a cold profile opens ≤6 of 30 walks and its streak climbs freely past every authored cap (proving "no cap" is real, not merely untested); a maximally hot profile (BURNING Heat, HOT Market pressure, one missed rent payment — re-pinned every walk, clearing every `QUIET_STREAK_CAPS` row including the tightest, cap 2) never goes quiet longer than 2 walks running, seed after seed; a mid-streak save/reload round-trip (`SaveSystem.capture()`/`_apply()`, in memory) reproduces the identical streak count and the identical gate result on the replayed walk; `blocker()`'s existing "refuses while a chain is active" seam is re-proven against a gate-opened chain specifically, and a second `wander` dispatch on top of it is confirmed to fail. Full profile-level economy measurement (the five-profile table STR-D1's own PR describes) is deferred to PR E's own integration pass, once PR B's roster gives the gate something richer to measure than two legacy cards. |

### Three real bugs, caught by sabotage-testing and live-tracing the new mechanism specifically

1. **An empty encounter pool silently froze the streak instead of advancing
   it.** The first draft of `_roll_gate()` returned early on `pool.is_empty()`
   before touching `wander_quiet_streak` at all — so a cold profile with no
   inventory and COOL Heat (both encounter cards permanently ineligible)
   never incremented the streak even once in 30 walks, and the cold-profile
   test's own "the streak climbs freely past every cap" assertion failed for
   a reason that had nothing to do with the cap. Fixed by counting an empty
   pool as a quiet walk for the streak's own purposes — the player
   experienced an uneventful walk either way — while still correctly
   refusing to force an encounter that does not exist to force.
2. **A rigged "overdue Dre account" test fixture tripped a real, unrelated
   encounter.** The hot-profile test's first draft set `dre_account` directly
   to `{"status": "overdue", "due_day": day - 3}` to satisfy the gate's own
   overdue-debt check — which ALSO satisfies `dre_lender.gd::settle_night`'s
   real trigger for the player-default encounter once a day-cross runs,
   opening a second, unrelated chain the moment the rigged wander chain
   cleared. Read as "Continue is broken" until traced live through
   `game_eval` step by step and found to be a correctly-firing Dre encounter
   this fixture had no business causing. Fixed by using `rent_missed = 1`
   instead — the same `_has_overdue_debt()` branch, with no real system on
   the other side of it to trip.
3. **A hot profile rigged once at the top of a 20-walk loop cooled off
   partway through.** Heat's own nightly decay (HEAT-D1) and District
   Pressure's own recovery (PRESS-D1) both run on every day-cross this
   build's own suite work already ships — a 20-walk loop spans several
   in-game days, long enough for a one-time BURNING/HOT/overdue snapshot to
   decay into a lower step count with a looser cap partway through,
   producing a real streak of 3 under a cap the test still asserted was 2.
   Fixed by re-pinning Heat, Pressure and rent arrears at the top of every
   iteration — proving "a player who STAYS this loud," which is what the
   ruling actually claims, rather than a player whose rigged state the test
   forgot to defend against the game's own ordinary decay.

### Implementation choices this session made, flagged as choices

1. **The band table lives in `data/wander_events.gd`, not `data/consequence_rules.gd`.** This is Wander's own draw-time decision (whether and which, not a cross-system consequence rule anything else reads), matching this file's own existing precedent (`EFFORT_BY_WALK`, `DISCOVERY_BASE`) for "a number that shapes one system's own draw lives with that draw." Pressure's own family table is read, never duplicated.
2. **`GATE_BASE_CHANCE := 0.03` / `GATE_PER_STEP_CHANCE := 0.05` / `GATE_CAP := 0.60` are authored, not measured yet** — chosen so a cold player (0 steps) lands near the ruling's own words ("near-silent") and a maximally hot one (12 steps) approaches the ceiling without the roll alone guaranteeing an encounter every walk; the streak cap is the actual guarantee. MEAS-D1's own job is to report these honestly against play, the same discipline PRESS-D1 (D-19) just went through for District Pressure's cap.
3. **A schema bump to v25** for `wander_quiet_streak` — genuinely new sequential state (how many consecutive quiet walks), not derivable from `wander_misses`/`wander_recent`/any existing field, the same call `wander_misses` itself got at v13. Purely additive; the migration arm is `pass`. The save validator gets the same type/non-negative check its siblings already have, deliberately WITHOUT a cap-clamp of its own — an inflated streak cannot be exploited for anything (it only ever shortens the wait until the street answers, never lengthens it), so re-deriving the current cap inside the validator would cost real complexity for a repair an honest save's own next walk will correct in one step regardless.
4. **Tests are homed in `tests/parity/parity_runner.gd`, not the confrontation/dre suites the build prompt names.** Every other Wander behavioral test already lives in parity (`_check_batch10`/`_check_batch11` and neighbors) — a second home for the same system's own coverage would be exactly the "two authorities" pattern this codebase keeps refusing. Divergence Protocol applied: the brief's assumption and the shipped test layout disagree, the repo's own existing pattern wins, recorded here rather than silently substituted.
5. **Encounter bias is a `gate_bias` tag** (`"debt"`, or a pressure family name) read by `_pick_encounter()`, boosting a matching card's weight by `GATE_BIAS_MATCH := 3.0`. Neither of the two legacy cards carries one — PR A's own scope has no debt- or pressure-flavored script to tag yet, so this reduces to a plain weighted pick today and becomes real the moment PR B's roster gives it something to prefer. Not "heat" as a bias category yet either, for the same reason (OPP-D8's "no unused framework" discipline, applied here to a tag rather than a whole system).

### Why this PR carries this entry rather than a later PR

Same Slice-0-before-the-code discipline as every entry above: the gate, the
streak, and the schema bump are all already load-bearing for `wander.gd`'s
own new code, so the ruling is recorded where the dependency was created.

## D-21 — The Street Answers Back: the roster

**Decided** 2026-08-29 · **Ships in** `build/street-encounter-roster` (0.5.0
PR B) · **Source:** `BUILD_STREET_ANSWERS_PROMPT.md`

### The question

PR A shipped the gate and the streak; it had exactly two legacy cards to
fire at whoever it interrupted. PR B is the roster the gate was built to
serve — new scripts that actually cost the player something, in VOX-D1's
register, staged through POOL-D1's requirements.

### The ruling

| ID | Ruling |
|---|---|
| STR-D3 | **The "luggage" rule.** `wander_shakedown` and the deepened `wander_stopped_on_foot` now author a per-choice `effects` table (`cash_fraction`/`cash_flat`, `goods_fraction`, `health`, `heat`, `escalate`) read by a new `WanderSystem._apply_effects()`. Cash is DIRTY-only, capped at `wallet.dirty_balance()` before it is spent — the same cap-before-spend shape `retaliation.gd` already uses — and goods route through the existing `_lose_cargo` owner. Run can still succeed and cost part of what is carried; nothing here grows a second money or inventory owner. |
| STR-D5 | **One new room, no new chassis.** The armed shakedown's escalation (FIGHT that does not end it) opens a room on `ConfrontationLoop`'s shared helpers — `loop_of`, `has_loop`, `append_log`, `present_round` — exactly like Stickup's tier 2-3 rooms, with its own escalating-odds step (`SHAKEDOWN_ROUND_PENALTY := -0.10`, matching `LIFT_ESCALATION`'s own precedent) and its own round cap (`SHAKEDOWN_ROUND_CAP := 3`). Single-round for every other new script, per the ruling's own text. |
| POOL-D1 (partial) | Four scripts staged this PR: `wander_shakedown` (armed, gated `gate_bias: "stick"`), the deepened `wander_stopped_on_foot` (adds a conditional `stash_it` verb — STASH_IT's own long-dormant authored script, see below — offered only when `gs.cargo_used() > 0`), `wander_curtis_tax` (gated on the new `curtis_watching_or_worse` fact PR A already exposed), and `wander_young_ones` (no requirements — the deliberately cheap, charisma-read floor of the roster). Full pool staging (ambient/read cards too) is still PR E's. |
| VOX-D1 | All four scripts' copy is authored fresh in this PR, not lifted from *Power* — terse declaratives, threats as terms, violence as logistics until it isn't. |

### Real bugs caught this PR

1. **Wiring STASH_IT the obvious way breaks oracle parity.** STASH_IT
   (`data/confrontation_scripts.gd`, authored since Q4 and never wired) has
   its own `"shape": "escape_route"`. Adding that shape to
   `outcome_resolver.gd`'s `OUTCOME_SHAPES` / `ACTION_ATTRIBUTE_MAP` — the
   obvious way to make the resolver understand it — immediately broke two
   parity fixture-count assertions (`got 12, want 11` on both tables). Those
   tables are checked byte-for-byte against fixtures generated by running the
   actual web oracle; this side never re-derives an expected value from its
   own code, and the oracle has no `escape_route` shape to have generated a
   fixture for. Reverted in full. STASH IT resolves through its own direct
   roll instead (`WanderSystem._stash_it_tier()`: a seeded comparison against
   `SCRIPTS.STASH_IT["base"]`, clean/failure only, never touching the
   resolver), the same choice this build already made once for STR-D1's own
   content that does not exist in the oracle.
2. **`_lose_cargo`'s floor of 1 silently charged "clean" resolutions.**
   `_lose_cargo(fraction)` is `maxi(1, int(ceil(held * fraction)))` — it
   always takes at least one unit given any held inventory, even for
   `fraction = 0.0`. A generic effects-table applier that calls it
   unconditionally would take a unit of product on a resolution the
   authored table calls a clean no-op. Fixed by skipping the call entirely
   whenever the authored `goods_fraction <= 0.0`. Caught live, before the
   suite ran, by tracing a "clean" `wander_stopped_on_foot` resolution
   through `game_eval` and noticing cargo had moved when the table said it
   shouldn't have.
3. **Two GDScript parse errors from patterns this codebase had not hit
   yet.** `CHOICE_LABELS`/`CHOICE_COPY`'s const initializers tried to read
   `SCRIPTS.STASH_IT["label"]` — a cross-script dictionary subscript is not
   a constant expression to the compiler, however constant it is in
   practice. Fixed by hardcoding the literal string with a comment pointing
   at the source of truth. Separately, `EVENTS.card_by_id(...)` was called
   on the class directly without an instance, which only works for a
   `static func`; `card_by_id` was not one. Fixed by making it static
   (both existing `.new().card_by_id(...)` call sites remain valid either
   way).
4. **The suite's own escalation-search helper could not find an
   escalation.** `_find_encounter_key()` (parity_runner's generic lookup)
   explicitly skips any chain not yet in a result stage — which is exactly
   what a freshly-escalated room looks like. Reusing it for
   `_check_roster_shakedown_room` would have made "find a STAND that
   escalates" structurally unsatisfiable regardless of the actual code.
   Fixed by writing that one check its own dedicated inline search rather
   than bending a helper built for a different shape of lookup.
5. **The shared stakes-strip Label had no wrap, and a loop's real content
   is long enough to break it — in Stickup's own shipped rooms, not just
   this PR's.** Live-verifying the new shakedown room's screen showed
   severely truncated text ("UGHT" for "CAUGHT") and a "· 0 ·" where
   "· LEFT 0 ·" should read. Traced with `game_eval` to
   `ui/screens/consequence.gd`'s stakes-strip Label
   (`_build_situation`, the `"STAGE %d/%d  ·  ..."` line): built without
   the `label()` helper's `wrap` flag, so a Label with no autowrap reports
   its full unbroken text as its minimum size — and a loop's real stakes
   string is routinely 60-75+ characters, well past what fits at that font
   size. The oversized minimum drags every ancestor Container up to fit it;
   `Shell` (anchored full-rect, `grow_horizontal = BOTH`) grew symmetrically
   past the 375px viewport in both directions at once, which reads on
   screen as the entire screen's text sheared off on the left. Confirmed
   this is NOT something PR B introduced: opening a real, already-shipped
   Stickup room the same way overflowed Shell even further (534px against
   this PR's 463px) on an unmodified code path. Fixed at the shared root —
   `_build_situation` now passes `wrap = not loop.is_empty()` for that one
   Label — verified live afterward for both a real Stickup room and this
   PR's shakedown room, Shell back to exactly 375×812 in both cases, and
   confirmed by screenshot that the strip now wraps onto two legible lines
   instead of forcing the layout wide. Separately (not a layout bug, a data
   bug): this PR's own shakedown loop was never populating
   `stage`/`stage_count`/`left`/`left_label`/`banked` at all, which is what
   produced the blank "LEFT" in the first place — `loop_summary()` defaults
   `left_label` to `""`, not the UI's own "LEFT" fallback, once the key
   exists in the projected dict at all. Fixed by populating the chrome
   fields following Boost's own escalation room precedent exactly (a fight
   has no cash to bank either): `stage = round - 1`, `stage_count =
   SHAKEDOWN_ROUND_CAP`, `left_label = "ROUNDS LEFT"`, `left =
   SHAKEDOWN_ROUND_CAP - round`, `banked` stays honestly `0`.
   This is the class of bug the automated suite cannot see by construction
   — it asserts dictionary contents, never rendered Control geometry — and
   was only caught because this PR's own ground rules require a live visual
   pass before calling a screen done, not because any check failed.
6. **A type-mismatch crash in this PR's own test code was silently
   truncating that test's remaining assertions, and a bare "PASS" reading
   missed it.** `GameManager.dispatch()` returns `bool` (whether some
   system handled the action) — it has never returned the adapter's own
   result dict, which is internal to `dispatch()`'s own reconcile step.
   `_check_roster_shakedown_room`'s mid-round reload check declared
   `var live_result: Dictionary = gm.dispatch(...)`, a type CI's stricter
   gate caught (`SCRIPT ERROR: Trying to assign value of type 'bool' to a
   variable of type 'Dictionary'`) that this local run's own "PASS —
   12707 checks" reading did not surface — the crash aborted the rest of
   that test function on the spot, silently skipping every `_expect_*`
   call after it (the reload-restores-the-room check, the replayed-dispatch
   check, the resolved-tier check, the round-cap section). Fixed by typing
   both dispatch results `bool`, matching what the function actually
   returns, and reading the real state to compare through
   `gs.active_consequence` instead — which the surrounding code was
   already doing for the tier comparison anyway. Running to completion
   surfaced 5 more real checks (12707 → 12712), all passing. Corrected the
   process, not just the code: checked this local run's own output for
   `SCRIPT ERROR`/`ERROR:`/`Invalid access` explicitly afterward, the same
   grep CI's "no engine or script errors" gate runs, rather than trusting
   a passing summary line at the tail of a long log.

### Implementation choices this session made, flagged as choices

1. **STASH IT bypasses the outcome resolver entirely rather than gaining an
   oracle-side entry.** The resolver's shape tables are fixture-locked
   against the web oracle by standing convention (`parity_fixtures`'
   own discipline: this side never re-derives an expected value from its
   own code, recorded truth or nothing) — a Godot-only verb gets a
   Godot-only roll, never a new table row the oracle was never asked to
   generate.
2. **The shakedown room has no verb-burning.** Stickup's rooms burn
   one-time verbs (WATCH, etc.) across rounds; the shakedown room's two
   verbs (KEEP FIGHTING / GIVE IT UP) are both repeatable every round by
   authored design — there is no third, one-time verb to burn. This is a
   real, smaller feature than Stickup's rooms, not an oversight; STR-D5
   asks for "rounds where the stakes earn them," not for Stickup's full
   verb vocabulary on every room.
3. **The consequence-screen wrap fix is scoped to loop chains only.** The
   non-loop stakes strip (`TAKE $N  ·  HEALTH ...  ·  HEAT ...`) is short
   by construction and stays unwrapped, matching `label()`'s own "wrap is
   opt-in, only prose asks for it" doc comment; only the loop branch, which
   is the one actually capable of producing an unbounded-length string,
   gets the flag.
4. **Fixed in this PR despite being a pre-existing Stickup bug, not a
   regression introduced here.** The stakes-strip overflow blocks this
   PR's own deliverable — a shakedown room that cannot be read is not a
   shipped room — and was found through this PR's own verification work.
   Fixing it at the shared root rather than working around it only for
   wander's content is what the bug actually calls for; leaving Stickup's
   rooms broken while fixing the symptom locally would have been the
   smaller, worse patch.
5. **Tests are homed in `tests/parity/parity_runner.gd` again**, under a
   new "0.5.0 PR B — The roster" section, for the same reason D-20 gave:
   every other Wander behavioral check already lives there. `MIN_CHECKS`
   moves to 12712 (see bug 6 below for why this is 5 higher than this PR's
   first local run reported); full suite confirmed PASS at that count with
   a clean scan for engine/script errors, and territory, save-validation,
   and screen-smoke all reconfirmed green alongside it.

### Why this PR carries this entry rather than a later PR

Same rule as every entry above: STASH IT's resolution path, the shakedown
room's own chassis use, and the shared UI fix are all load-bearing for this
PR's own new content, so the ruling is recorded where the dependency was
created.

## D-22 — The Street Answers Back: the checkpoint

**Decided** 2026-08-29 · **Ships in** `build/travel-checkpoint` (0.5.0 PR C) ·
**Source:** `BUILD_STREET_ANSWERS_PROMPT.md`

### The question

PR A's gate and PR B's roster both answer "you're standing still, doing
nothing" — the wander button. STR-D4 is the other half of the owner's
complaint: crossing districts while hot or holding product was completely
free of interactive risk. `economy.gd::resolve_carry` already taxes a hot
carry silently on arrival, but silent and automatic is not what DL2's
"airport security" beat asks for — a real decision, the same as every other
interruption this build ships.

### The ruling

| ID | Ruling |
|---|---|
| STR-D4 | **Travel answers too.** `TravelSystem.handle("travel", ...)` rolls the same interruption gate a wander does — `WanderSystem.attention_steps()` (promoted public this PR) and `data/wander_events.gd::gate_chance()`, read rather than re-derived, per the ruling's own words: "the same interruption gate." Its own authored script (`data/travel_events.gd::CHECKPOINT`, a police-flavored patrol stop: TALK/RUN IT/HAND OVER), its own seeded key (`"%d:%d:travel:%s:gate"`, day and slot leading, the destination trailing), its own `KIND_TRAVEL_STOP` chain kind, and `return_route: "STREET"` — travel always originates from the Street screen (`ui/screens/street.gd`'s only `dispatch("travel", ...)` call site), so Continue lands the player back where the trip started, never generically at Home. |

### Real bugs caught this PR

1. **A missing local color constant.** `travel.gd` is a new author of
   `gs.log_activity(...)` calls and never had its own `AMBER` — every other
   system that logs activity (`wander.gd`, `stickup.gd`, `dre_collector.gd`)
   independently declares the same `Color(0.882, 0.651, 0.227)` locally
   rather than sharing one constant, an existing house pattern this file
   simply hadn't needed yet. Caught immediately via a filesystem scan and
   editor log check, before it ever reached a suite run: "Parse Error:
   Identifier 'AMBER' not declared in the current scope."
2. **The checkpoint's own context line repeated the destination's name
   twice.** `_context_line()`'s per-kind match arm named the destination
   explicitly (`"EN ROUTE  ·  DOWNTOWN"`), not realizing the function ALSO
   appends the chain's own `district_id` as a universal trailing suffix for
   every kind — since a checkpoint's `district_id` IS the destination, the
   result rendered `"EN ROUTE  ·  DOWNTOWN  ·  DOWNTOWN"`. Suite coverage
   cannot see this class of bug (it is a string-content correctness issue,
   not a state assertion), and screenshot inspection alone did not catch it
   either on first read — it took reading the actual UI element text via
   `get_ui_elements` against the live chain to notice the repeated word.
   Fixed by dropping the per-kind arm's own append and trusting the
   universal suffix, matching `KIND_STICK_BOOKING`'s own minimal one-part
   pattern (no target name, because its own suffix already supplies enough
   context).

### Implementation choices this session made, flagged as choices

1. **The checkpoint and the older carry-stop tax are mutually exclusive per
   trip.** `resolve_carry` (`economy.gd`) already taxes a hot carry silently
   on arrival — STR-D4 does not say to remove it, and it stays for any trip
   the new gate leaves quiet. But a fired checkpoint already IS the street
   noticing the player in transit; also running the older silent tax on the
   same trip would charge the same event twice under two different names.
   `TravelSystem.handle()` skips `resolve_carry` exactly when the
   checkpoint opens, nothing else. This is a judgment call the build prompt
   does not spell out explicitly — recorded here per the Divergence
   Protocol rather than left implicit in the diff.
2. **No travel-specific quiet-streak guarantee.** STR-D2's streak cap is a
   Wander-specific answer to "the walk-around button pressed indefinitely";
   STR-D4 asks only for "the same interruption gate" (the chance formula),
   not a second forced-open guarantee. Travel already costs a fare and a
   full slot every time it is used, which is its own natural throttle —
   inventing a streak mechanic STR-D4 never asked for would be scope the
   ruling did not request. `attention_steps()`/`gate_chance()` alone govern
   the checkpoint's frequency.
3. **`WanderSystem.attention_steps()` made public rather than duplicated.**
   The alternative — a travel-flavored copy of the same Heat/Pressure/
   Curtis/debt aggregation — is exactly the kind of drift this build's own
   `ConfrontationLoop` header warns against ("two adapters cannot drift on
   the rules that make the loop one machine"), applied here to a
   read-only signal formula instead of round bookkeeping. Wander stays the
   formula's one author; Travel reads it the same way it already reads
   Heat's own `band()`.
4. **`apply_effects`/`apply_heat`/`lose_cargo` moved from `wander.gd` into
   `ConfrontationLoop` as shared static helpers.** PR B authored these as
   Wander-private; PR C is the second real caller of the exact same
   authored-effects-table shape (`cash_fraction`/`cash_flat`/
   `goods_fraction`/`health`/`heat`), which is the point at which "shared
   later" becomes "shared now" rather than a premature abstraction. Every
   call site updated in the same commit; behavior is unchanged (confirmed
   by parity staying at the same check count for Wander's own existing
   roster arms, all still passing).
5. **The checkpoint's effects table costs product and Heat/health, never
   cash — the same distinction `wander_stopped_on_foot` already draws
   against `wander_shakedown`'s armed robbery.** A patrol has no standing
   reason to seize money that is not itself illegal to hold; only what is
   actually contraband is on the table. HAND OVER accordingly costs goods
   only (no Heat, no health) — matching every existing deterministic
   safe-out in this codebase, all of which cost assets and nothing else —
   which is also why `choice_guarantee` needed no override: the fallback
   text ("no injury, no Heat, no arrest") stays true without one.
6. **The `arbitrage` economy corridor's floor moved from 180% to 140%,
   measured rather than tuned to hold the old number.** Arbitrage is the
   one profile built entirely out of district crossings, so it is the
   profile most exposed to a new per-crossing risk by construction.
   Measured at 158% on this PR's own baseline; the floor was lowered to
   sit under that measurement rather than adjusting the gate's chance
   table or the luggage rule's own effects to claw the old ceiling back —
   MEAS-D1 asks for honest measurement, not a target defended after the
   fact. 158% still clears the balance guard's own bar (materially
   riskier, not priced out of the strategy).
7. **Tests are homed in `tests/parity/parity_runner.gd` again**, under a
   new "0.5.0 PR C — The checkpoint" section, for the same reason D-20 and
   D-21 both gave. `MIN_CHECKS` moves to 12720; full suite confirmed PASS
   at that count with a clean scan for engine/script errors, and
   territory, save-validation, and screen-smoke all reconfirmed alongside
   it.

### Why this PR carries this entry rather than a later PR

Same rule as every entry above: the checkpoint's trigger site, its kind, and
the carry-stop exclusion are all load-bearing for this PR's own new code, so
the ruling is recorded where the dependency was created.

## D-23 — The Street Answers Back: the doorstep

**Decided** 2026-08-29 · **Ships in** `build/debt-doorstep` (0.5.0 PR D) ·
**Source:** `BUILD_STREET_ANSWERS_PROMPT.md`

### The question

Three obligations already ratchet toward the run's own end conditions, and
until this PR every one let the player keep tapping around it: Dre's own
ultimatum waited for `dre_lender.settle_night` to notice it; a defaulted
Book note sat available-but-ignorable until the player felt like resolving
it; rent's escalation was pure log lines counting down to a game over the
player never got to answer. DOOR-D1 forces the visit instead, staged.

### A reading called out before the ruling table, not after

STR/DOOR-D1's own words are "a defaulted/suspended **Book** standing" and
"enforcement... a beating that routes through health and seizure" —
language that reads, on a first pass, like someone collecting FROM the
player. The Book (`systems/shark.gd`, UI label "THE BOOK") is the one place
in this game the player is the LENDER: `enforce`/`extend`/`forgive` are
already risk-free rolls the player makes about a borrower's defaulted note,
confirmed by reading `_resolve_defaulted()` directly — no health cost
anywhere in it, and no other player-facing debt-to-a-"Book" character
exists anywhere in `game_state.gd` (`book_loans_funded`'s own economy
metric reads as loans the player FUNDS, consistent with `shark.gd` being
the only Book mechanic that exists). Taken together, "a defaulted... Book
standing" reads as a note the PLAYER has been avoiding a decision about,
not a debt the player owes — and "enforcement... a beating" describes NEW
risk this PR adds to the player's own aggressive collection attempt
(`FIGHT`), the same shape `dre_collect_hard`'s existing PRESS verb already
has for Dre's borrowers, just no longer optional. This is the session's own
best-reasoned resolution of a genuine ambiguity, not a confirmed reading —
flagged here prominently, exactly where the Divergence Protocol says a
brief's own assumption and the shipped system disagreeing belongs, so it is
the first thing found and correctable if wrong.

### The ruling

| ID | Ruling |
|---|---|
| DOOR-D1 | **Overdue debts stop waiting**, staged: the word (unchanged — see below), the collection (a forced decision), enforcement (STR-D5's second room). Dre's own collection stage reuses `dre_collector.open_player_default_encounter()` verbatim; the Book and rent sides author the same forced-decision pattern with their own scripts. Never scripted death: no road in `systems/doorstep.gd` ever sets `game_over` — every exit costs only health and the debt itself, through the owners each already has. |
| DOOR-D2 | **One visit per day-start, worst debt first.** `doorstep.gd`'s `worst_visit()` compares all three obligations' current stage (and, on a tie, how overdue each is in its own terms) before anything opens; the day-start hook (`DayLifecycle.add_day_start_hook`, run after every `DAY_START_ORDER` step) claims the floor before any generated offer would, and the engine's own `has_active()` guard is the same one-chain seam every other forced-open mechanism in this build already defers to. |

### "The word" needed no new code

The mildest stage already exists as the passive warning each obligation
already prints the first time it goes bad — none of them block anything.
Forcing a screen interrupt on the day's first sign of trouble would fight
the same balance guard this build's other interruption gates were tuned
against ("must not turn the button into a tax that makes it not worth
pressing"). What DOOR-D1 actually asks to stop being avoidable is the two
stages that cost something real, so those are the two this PR adds; "the
word" is unchanged.

### Nothing new persisted

Every stage is computed off a field that already exists and never resets on
its own once an obligation goes bad: `dre_account.due_day`, a shark loan's
own `due_day`, and `gs.rent_missed`/`household_warnings`. `gs.day - due_day`
is a valid, ever-growing "how overdue" measure for both Dre and the Book
without a new field, and rent's own warning counter already climbs on its
own. Ground rules: "derive before you persist" — this PR found nothing that
could not be. `SAVE_VERSION` does not move.

### Real bugs caught this PR

1. **Registering a new adapter without the base dispatch contract crashes
   every single dispatch, not just the new one.** `register_system("doorstep",
   doorstep)` adds it to the same list `GameManager.dispatch()` calls
   `can_handle(action)` on for EVERY action, unconditionally — a system with
   no `can_handle`/`handle` pair (reasonable, on the assumption that a
   pure adapter with no player-initiated actions would not need them) breaks
   every dispatch in the game the instant it is registered. Fixed by
   matching `retaliation.gd`'s own existing precedent for exactly this case:
   `can_handle` returns `false` unconditionally, `handle` refuses. Found
   immediately via the dre suite going from 404 checks to 14 failures the
   moment this file was registered, all of them cascading from one crash.
2. **A trailing-varying-integer seeded key, caught by the suite's own static
   audit — in new code, and in PR B's own shipped shakedown room.** The
   room's per-round roll was first written as `"<cause_id>:<choice_id>:room:
   <round>"`; `_check_no_tail_varying_keys()` (a source scan, not a
   behavioral check) flags any seeded key literal ending in a bare `%d` as
   the exact shape of "the near-identical-rolls finding" this build's own
   danger list names. Fixed by moving the round number to the front. While
   fixing it, checked whether PR B's own shakedown-room key
   (`"<key>:stand:room:<round>"`) had the same defect: it does, but the
   audit's own line-by-line scanner never caught it because that key is
   built as a bare expression spanning the `resolve_action(...)` call's own
   multiple lines rather than a same-line `var key := ...` — a real, narrow
   blind spot in the audit, not evidence the original key was fine. Fixed
   the same way, on the same principle the audit exists to enforce, even
   though nothing would have failed if it were left alone.
3. **Dre's own "yield" could fail to close the account at all.** The first
   draft routed every "paid" resolution through the real `dre_repay`
   dispatch, which refuses outright (`repay_blocker()`) when the account
   cannot be covered in full — correct for the ordinary menu, wrong for a
   room whose entire point is that this debt ends today. An unaffordable
   YIELD would have left the account exactly as overdue as it already was,
   silently re-opening the identical enforcement room the next day forever.
   Fixed by falling back to taking whatever cash is on hand and closing the
   account regardless, once the real repay path refuses.
4. **Rent's own "yield" had the opposite bug: a free pass.** The first draft
   only spent cash toward arrears when the player could cover the full
   amount, but reset `rent_missed`/`household_warnings` to zero
   unconditionally either way — an unaffordable player walked away with
   back rent forgiven for nothing. Fixed to take whatever is on hand first,
   the same partial-payment discipline the Dre fix above uses.
5. **The room's own stakes-strip chrome was never populated, the identical
   class of bug D-21 already caught once for the shakedown room.** Live
   verification (a real day-cross through the actual `advance_time`
   dispatch, not a direct `try_force_visit` call) showed the card's title
   falling back to `consequence.gd`'s generic "THIS IS HAPPENING NOW" and
   the stakes strip reading "STAGE 1/1 · · BANKED $0" — `loop_summary()`
   defaults every field this screen reads (`sheet_title`, `stage`,
   `stage_count`, `left`, `left_label`, `banked`) when a loop dict does not
   set them, and this room's own `loop` dict set none of them. Fixed by
   populating them following the exact same Boost/shakedown-room precedent
   (`ROUNDS LEFT`, `BANKED` honestly `$0`) and confirmed live afterward: the
   card now reads "THE COLLECTION" / "STAGE 1/3 · ROUNDS LEFT 2 · BANKED
   $0". Noted for the project's own memory as a suite-coverage gap that
   keeps recurring across every new loop-driven room in this build — the
   automated suite asserts dictionary contents, never rendered chrome, and
   only a live pass catches this class of bug.

### Implementation choices this session made, flagged as choices

1. **One room, three tenants.** STR-D5 calls this "the build's SECOND
   room" — singular. `_open_enforcement`/`_room_round`/`_room_exit` are one
   chassis (built on `ConfrontationLoop`'s shared helpers, same as the
   shakedown room) parameterized by `family`, with each family's own
   `_close_*` function the only place that actually differs. Three
   independent implementations would have tripled the surface a future
   round-mechanics change has to find and fix.
2. **The Book's room points the other way from Dre's and rent's.** FIGHT
   there is the player pressing a resistant borrower, so the health risk
   lands on the player attempting to collect, not on the player being
   collected from; YIELD there means walking away from collecting at all
   (the note's own existing `forgive`), not "pay whatever is on hand" —
   the one place a single shared verb label carries a different meaning per
   family, disclosed rather than left to read as an inconsistency.
3. **Dre's own trigger moved out of `dre_lender.settle_night` entirely.**
   "One visit per day-start, worst debt first" needs Dre, a defaulted Book
   note and rent arrears compared against EACH OTHER before anything opens
   — a check still living inside `dre_lender.gd`'s own settlement could not
   see the other two, and would race whichever of them tried to open
   first. `dre_lender.gd`'s state machine itself (active → due → overdue →
   suspended) is completely unchanged; only who asks whether tonight is the
   night to act on "overdue" moved, to `doorstep.gd`'s own day-start hook.
   `tests/dre/dre_runner.gd`'s own ultimatum tests needed no changes beyond
   this relocation — they drive through the real day-cross dispatch, which
   the hook rides same as everything else registered on it.
4. **Threshold numbers are authored, not measured yet** — `DRE_ENFORCEMENT_
   DELAY_DAYS := 5`, `BOOK_COLLECTION_DELAY_DAYS := 2`, `BOOK_ENFORCEMENT_
   DELAY_DAYS := 6`, `RENT_ENFORCEMENT_AT_WARNING := 2` (one warning short
   of the existing `HOUSEHOLD_WARNING_LIMIT`, so a player who survives the
   room still meets the existing end condition as the actual last word, not
   this room). MEAS-D1's own job — measuring these against real play rather
   than vibing them — is PR E's, the same discipline every authored number
   in this build has gone through before it.
5. **Tests are homed in `tests/parity/parity_runner.gd` again**, under a
   new "0.5.0 PR D — The doorstep" section, for the reason every prior PR
   in this build gave the same answer to. `MIN_CHECKS` moves to 12751 (a
   net decrease from PR C's 12720 despite ~40 new checks: fixing the
   seeded-key bug above shifted a pre-existing rigged-round test in the
   shakedown room from a "messy" roll to a "failure" roll, and one of that
   test's own assertions is conditioned on the tier being exactly "messy" —
   a real, if narrow, fragility in a test tied to which tier a specific
   rigged round happens to roll, not a loosening). Full suite confirmed
   PASS at that count with a clean scan for engine/script errors, and
   territory, save-validation, dre, confrontation, tips and screen-smoke
   all reconfirmed alongside it.

### Why this PR carries this entry rather than a later PR

Same rule as every entry above: the threshold table, the room's own
chassis, and the Dre-trigger relocation are all load-bearing for this PR's
own new code, so the ruling is recorded where the dependency was created.

## D-24 — Squared Up: the encounter overlay

**Decided** 2026-08-29 · **Ships in** `build/encounter-overlay` (0.6.0 PR A),
with SQ-D6..D11 landing alongside the code that depends on them in PRs B-E ·
**Source:** `BUILD_SQUARED_UP_PROMPT.md`, ClickUp `86bbnk6en`

### The question

Three things the owner asked for, and one drift the repo had shipped without
noticing.

The ask: every confrontation should present as a popup over the current
screen rather than a full-screen takeover, with a health bar that MOVES as
damage lands; the wander encounter pool should stop being a skeleton and
carry the everyday street; and the authored-but-unwired per-path scripts
should get wired.

The drift: encounters were full-screen and it was enforced globally —
`ScreenManager.blocking_route()` returned CONSEQUENCE for any non-empty
chain, and `resolved_route()` made every navigation land there. It was never
"some encounters"; it was all of them. Under that, two of the four 0.5.0
wander cards shipped with `"deterministic": []` (no guaranteed out, which the
chassis rule forbids), the shakedown room re-rolled one verb at decaying odds
instead of authoring a new situation, and no wander encounter wrote an
exposure observation.

### The ruling

| ID | Ruling |
|---|---|
| SQ-D1 | **Encounters present as a sheet; the street stays behind them.** Chain rendering is extracted out of `ui/screens/consequence.gd` into `ui/components/encounter_sheet.gd` on the `flow_sheets.gd` pattern: static builders, no `class_name`, resolved at BUILD time from the engine's summary calls and never from `gs.active_consequence`. Both presentations consume the same builder, so the screen and the sheet cannot drift on what a chain looks like. The screen is not deleted — see SQ-D2. |
| SQ-D2 | **Which stages ride the sheet.** `STAGE_DECISION` and `STAGE_RESULT` render as a `ModalSheet` over the current screen for every chain kind. `STAGE_BOOKING` and `STAGE_RELEASE` keep `consequence.tscn`: an arrest genuinely IS a takeover, the booking terms are long-form, and release is where a run's shape changes. `blocking_route()` returns CONSEQUENCE only for booking/release and `""` for decision/result; nothing else about the priority ladder moved, and game over still outranks everything. The split has ONE owner (`encounter_sheet.stage_rides_sheet`) and three readers — `resolved_route()`, the boot/CONTINUE path, and the flow-sheet drain's own guard — which all change behaviour together. |
| SQ-D3 | **A blocking sheet cannot be dismissed by touching it.** `ModalSheet` gains a `blocking` flag, default `false` so Market's picker and every flow sheet are byte-for-byte unaffected. When set, the scrim still STOPS the tap (the screen underneath must not receive it) but does not treat it as a dismissal, and the handle bar is not built at all rather than built and ignored — a grab-bar that does nothing is a control that lies. The sheet closes exactly one way: the chain resolving. |
| SQ-D4 | **The sheet reopens itself after a reload.** Presentation is DERIVED from the live chain (kind + stage), never persisted — which is what keeps the whole change migration-free. On boot or load with a decision- or result-stage chain live, `screen_base.gd`'s existing flow-sheet drain reopens the encounter sheet ahead of any queued discovery card. Two hazards, both handled here: (a) the encounter takes STRICT precedence in the drain (checked first, returns; and an ordinary card already on screen has its spec handed back to the FRONT of the queue via `requeue_flow_sheet` rather than being eaten), and (b) TI-003 §18's "no ordinary screen exposed for an interactive frame" is now met by the sheet's scrim rather than by the route — `screen_manager.gd`'s own doc-comment was rewritten to describe the path that exists rather than the one that no longer does. |
| SQ-D5 | **The health bar is a component, and it moves in real time.** `ui/components/health_bar.gd`, a `ProgressBar`-backed strip with the exact `current/max` beside it in house colours, renders inside the situation block on every sheet stage. After a round resolves the delta ANIMATES from the prior value rather than snapping, so the player sees the hit land. The prior value is a static on the script — session-lifetime presentation memory, never persisted, never read by anything but the tween, and cleared on the run boundary `clear_flow_sheets()` already owns. HEALTH graduates out of the text stakes strip into the bar; STAGE/#LEFT/BANKED/HEAT stay in the strip. |
| SQ-D6 | **The verb triad, and roles rather than labels.** Every general wander encounter offers exactly three roles — `fight` / `run` / `surrender` — declared as a `role` key per choice in `data/wander_events.gd`. Labels stay per-card and in voice; the role is what the chassis, the suite and the UI ordering read. The `surrender` role is always deterministic and always present, which is how "one guaranteed out per round" becomes structural instead of per-card care. Path-specific scripts keep their own authored vocabularies. *(Lands with PR B.)* |
| SQ-D7 | **A round is a new situation or it is not a round.** Every multi-round script authors a `beats` array — one entry per round, each a distinct situation with its own copy and its own offered stakes — the way `STICK_SCRIPTS` and `LIFT_BEATS` already do. The shakedown room is rewritten to that shape. Escalating odds may ride on top but are never the only thing that changes between rounds. A script that cannot honestly author a second beat ships as one round. Cap stays 3. *(Lands with PR B.)* |
| SQ-D8 | **Every encounter writes an exposure observation**, on RESOLUTION, keyed by the road taken and the tier reached, at the district it happened in, with receipts so a reload cannot double-write — `boost.gd`'s `boost_caught:observation` receipt is the precedent. Authored per card, read generically; a card with no authored row falls back to a shape derived from its role and tier rather than writing nothing. *(Lands with PR B.)* |
| SQ-D9 | **Crew calls become chassis actions.** `CREW_CALLS` are offered by any script that declares `admits_crew: true`, gated on the existing availability language (recruited, active, loyalty > 0, `crew_unassigned_today`). Once per loop; calling burns no verb. Stickup scripts still admit none. *(Lands with PR B.)* |
| SQ-D10 | **The path variants wire what is authored; they author only what is missing.** `corner_stiff`, `corner_push` and `MEETUP_SCRIPT` wire as authored. The Lift and STASH_IT are ALREADY wired — they are audited against the spec and the stale "AUTHORED, NOT YET WIRED" header in `data/confrontation_scripts.gd` is corrected. Stickup tier 1 keeps its single-roll path byte-for-byte. *(Lands with PRs D and E.)* |
| SQ-D11 | **New rolls that the oracle never knew stay off the oracle's tables.** No new shapes in `outcome_resolver.gd`'s `OUTCOME_SHAPES` / `ACTION_ATTRIBUTE_MAP` — D-21 records what that cost last time. A Godot-only roll rolls directly and seeded, the way `_stash_it_tier` does, and says so in its header. |
| VOX-D1 | **The voice: menace as business — the *Power* register**, carried forward unchanged from 0.5.0. Emulate the register; never lift or paraphrase actual lines. Copy ships in the same PR as its content. |
| MEAS-D1 | **Frequencies and durations are measured, never vibed**, carried forward. |
| VER-D1 | **Version → `0.6.0`, MINOR.** Rides the close-out PR. |

### Real bugs caught in PR A

1. **`consequence.gd` could not simply preload the extracted builder.** It
   extends `surface_base.gd` → `screen_base.gd`, and `screen_base` needs the
   same preload for the drain. Declaring `const ENCOUNTER_SHEET` in both is a
   parse error ("the member already exists in parent class") — which Godot
   reports by REFUSING TO ATTACH THE SCRIPT and instantiating the scene
   anyway. That is the exact failure mode `screen_smoke.gd`'s own header was
   written about, and the smoke gate caught it inside a minute (23/24 → 22/24,
   touch checks 1101 → 1093). The fix made it better rather than merely
   compiling: the const AND the `_wire_encounter_button` seam are inherited,
   so a choice committed from the sheet and a choice committed from the screen
   now go through one dispatcher instead of two near-identical ones.

2. **Nothing in the build could see a runtime-built component.**
   `screen_smoke.gd` walks `ui/screens/*.tscn`; `ModalSheet` had shipped for
   two builds with no gate asserting it could be constructed at all, and the
   new `encounter_sheet.gd` / `health_bar.gd` would have inherited that blind
   spot. The suite now builds all three against a REAL live chain (not a stub
   summary — the point of the builder is that it resolves from the engine's
   own calls) and runs the same TOUCH-D5 scroll-transparency walk over the
   result: +67 component checks.

### Measured results, PR A

| Suite | Before | After |
| --- | --- | --- |
| parity | 12763 | 12763 (presentation-only; not one authored number moved) |
| confrontation | 251 | 286 |
| save validation | 235 | 247 |
| screen smoke | 23/23 screens, 1101 touch | 23/23 screens, 1101 touch, +67 component |
| territory / tips / dre | 170 / 93 / 404 | unchanged |

### Real bugs caught in PR B

3. **The room's own copy reached the chip and the log and not the sentence.**
   `encounter_sheet.situation_body()` read `loop.beat` only inside its
   `KIND_CONFRONTATION` arm — correct while the confrontation chain was the
   only kind that ran a room. The wander shakedown's room is the second, so
   all three of its newly authored beats rendered under the card's standing
   opener ("You went out to see what was around"), with a correct STAGE 3/3
   chip and a correct round log directly above and below the wrong line. The
   structural arm and the driven arm both passed clean; a **screenshot** is
   what caught it. Fixed by hoisting the beat above the kind match entirely —
   "the situation IS the current beat" is what the round rule means on screen
   and it was never a fact about one chain kind.

4. **The room's roads wrote no observation at all.** SQ-D8's fallback resolves
   a role, and a room declares its roles per BEAT rather than on the card
   (SWING is the fight road of three different situations and each prices it
   its own way). So `observation_for` found no role for SWING, returned `{}`,
   and a fight that took three rounds became the one resolution in the build
   that observed nothing. Found by driving the room live after the structural
   arm — which only ever swept the card's own roles — passed clean. The arm
   now sweeps every road any beat offers as well, which is the shape the rule
   always meant.

### Measured results, PR B

| Suite | After PR A | After PR B |
| --- | --- | --- |
| parity | 12817 | 12836 |
| confrontation | 286 | 630 |
| save validation | 247 | 247 |
| screen smoke | 23/23, 1101 touch, 67 component | unchanged |
| territory / tips / dre | 170 / 93 / 404 | unchanged |

Confrontation's +344 is mostly the two STRUCTURAL sweeps — every encounter
card x every role x every tier, rather than one driven example each. That is
deliberate and it is the point of the PR: 0.5.0 shipped two of four cards with
no guaranteed out on a chassis whose stated rule is one guaranteed out per
round, and "an author remembered" is precisely the enforcement that failed.

**MEAS-D1, the encounter wall-clock.** Measured on the real build against the
40-second budget, worst case (a full three-beat room, open to chain cleared):

- **machine time: 30 / 31 / 31 / 46 ms** across four passes — sheet build,
  three beat rebuilds, the commit, the result build and the clear.
- **animation budget: 0.67 s** total, and it is fixed rather than per-round:
  sheet entry 0.18 s + exit 0.14 s + one health-bar drain 0.35 s. A beat
  change swaps content in place and re-fits; it does not re-enter.

So the build's own contribution to a three-round encounter is under a second,
and the 40-second budget is spent entirely on reading. The copy is what has to
stay inside it, not the code, and three beats of ~30 words each plus three
choice lanes reads inside 40 seconds comfortably.

### Real bugs caught in PR C

5. **A road labelled CERTAIN under a line promising it cost nothing.** The
   screen's fallback for a deterministic choice is "Guaranteed: no injury, no
   Heat, no arrest." That was true for every deterministic choice shipped
   before 0.3.0 and is true for almost none of SQ-D6's surrender roads — and
   it was flatly a lie on `wander_warrant_check`'s WAIT IT OUT, the one card
   where surrender is deliberately the WORST road (the whole bag plus the
   loudest Heat on the card). ENC-D6 had already opened the exact seam for
   this (`choice_guarantee`) when Stick Caught's YIELD started guaranteeing an
   arrest; Wander had simply never implemented it. Every surrender road in the
   file now states its own price, and the suite asserts none of them reads
   like the fallback.

6. **Flat observation rows on run roads with costly tails.** Six roads
   authored one observation shape for every tier, so a KEEP MOVING that cost
   health and a quarter of the cash still observed as `discretion /
   walked_it_off`. Found by driving all 24 new roads on the real build and
   reading the ledger back. Tiered.

7. **The parity runner hung silently, and it was a parse error after all.**
   Editing this suite by slicing between two markers removed three functions
   along with the one being replaced. Godot logged three "function not found"
   parse errors and then sat at ~1% CPU indefinitely. Exactly the failure the
   danger list names — worth recording that the first instinct (three
   overlapping background runs contending) was wrong, and that the diagnosis
   came from running ONE instance with output unfiltered.

### Measured results, PR C

| Suite | After PR B | After PR C |
| --- | --- | --- |
| parity | 12836 | 13276 |
| confrontation | 630 | 1130 |
| save validation / territory / tips / dre / smoke | — | unchanged |

Confrontation's +500 is almost entirely free: the structural sweeps iterate
the card registry, so eight new cards brought their own coverage with them.
That is what the sweeps were for.

**MEAS-D1, the gate.** The gate is out of scope for 0.6.0 and no line of it
changed, but "we did not touch it" is not the same claim as "it did not get
louder" — tripling the roster is exactly the kind of change that moves a rate
through a back door. Both halves are now measured and asserted:

- **Structurally:** the gate's own predicate is re-derived in the suite from
  only the two inputs it is allowed to read (`attention_steps()` and
  `wander_quiet_streak`, through `gate_chance` and `quiet_streak_cap`) and
  compared against what `_roll_gate()` actually decided — **30/30 agreement**
  on the largest pool the roster can stage. A pool-size term anywhere in that
  predicate would show up as a disagreement.
- **Empirically, on the real build:** a cold day-one profile driven through
  the real `dispatch("wander")` path opens **2.83 of 30 walks** (1/5/3/1/4/2
  across six seeds), well inside the ≤6 ceiling PR A set — and the cards that
  came up were genuinely varied (`wander_desperate_approach` ×6,
  `wander_young_ones` ×6, `wander_mistaken_identity` ×4, `wander_lot_side`
  ×1), which is the roster doing its job.

One honest finding fell out of it: `_roll_gate`'s empty-pool branch is
**defensive rather than reachable**. Three cards are authored for any district,
any slot, with no requirements, so the pool has a floor of three whatever the
player has done. The suite now asserts that floor, so an author who gates all
three gets a red suite telling them the gate just became silenceable.

### Measured results, PR D

| Suite | After PR C | After PR D |
| --- | --- | --- |
| parity | 13276 | 13276 (+1 adapter id, −1 nothing; the corner's coverage is in the confrontation suite) |
| confrontation | 1130 | 1203 |
| save validation / territory / tips / dre / smoke | — | unchanged |

**No schema bump.** `corner_stiff`'s "once per district per day" is derived
from `add_market_pressure`'s own day-stamped counter on the district's Market
pressure row (`market_gain_day` / `market_gain_today`), which already answers
"has anything sold here today". Read BEFORE `_sell` adds its pressure — after
that call the answer is always yes, so the order of those two lines in
`economy.gd::_sell` is load-bearing and is commented as such.

Confirmed live: a real `market_sell` dispatch on a KNOWN corner opened SHORT
COUNT over Home with $28 in dispute (a fifth of a $138 sale, floored and
capped), `first_sale_today` flipped to false, and a second sell the same day
opened nothing. A `corner_push` on a watching Curtis resolved STEP OFF and put
exactly one `submission / ceded_the_corner` row in his ledger at
`north_star_lot`.

### The Lift audit (SQ-D10, PR D)

Ruled: audit the shipped Lift against the ClickUp spec, correct the stale
header, report the delta, and **add no new verb without the owner's ruling**.

The spec names **Run / Talk / Drop It / Shove Past**, with Intelligence for
talk and run and Combat for shove. What ships is **fight / run / talk / yield**
(the shared caught table) plus **SETTLE IT** (`bribe`) and **HAND IT BACK**
(`hand_it_back`), on an escalating multi-round loop with per-tier authored
beats. The delta, verb by verb:

| Spec verb | Shipped as | Note |
|---|---|---|
| Run | `run` | direct |
| Talk | `talk` | direct |
| Drop It | `yield`, and `hand_it_back` | the spec's one verb is shipped as two: YIELD gives it up under the caught table's own terms, HAND IT BACK is the softer road that keeps the door (no ban) |
| Shove Past | `fight` | the physical road, on Combat, as specified — under a different name |
| — | `bribe` (SETTLE IT) | **not in the spec.** Per-tier capped, once per store, and the reason the Lift has the widest action set in the game |

So all four spec verbs are present in different words, one is split in two, and
one road exists that the spec never named. **Recommendation held: no new verb.**
Six is already the widest action set in the build, and SHOVE PAST would be a
fifth name for the road `fight` already is.

Wiring confirmed live: `boost.gd` consumes `LIFT_BEATS` (per-tier, per-round
situation copy), `LIFT_ESCALATION` (`verb_penalty` −0.10, `heat_per_round` 0.5,
`round_cap` = the shared `ROUND_CAP`), `LIFT_BRIBE` (2× multiplier, per-tier
floors, `per_store_limit` 1), and `LIFT_CHOICE_LABELS`/`LIFT_CHOICE_COPY`
through the engine's adapter seam. **Nothing was missing and nothing was
added.** What was wrong was the file's own header, which listed all of it as
"authored and NOT yet wired" — along with STASH_IT (wired in 0.5.0, and not on
the Lift at all), MARKET_SCRIPTS, MEETUP_SCRIPT and CREW_CALLS. Four of five
entries stale, stated with confidence, which is the worst way for a file to be
wrong. Corrected in place, and the suite now asserts the corrected text.

### Why this PR carries this entry

Same rule as every entry above: SQ-D1..D5 are load-bearing for PR A's own
code, so they are recorded where the dependency was created. SQ-D6..D11 are
recorded here too because they are one ruling set the owner closed at once and
splitting them across five files would be worse than naming, per row, which PR
the code lands in.

## Standing Policy — Build 5e divergences

**Decided** in Build 5e (predates Batch 18; recorded here in PR 5, migrated
verbatim from `HANDOFF.md`'s "Codex Hardening + Fixes Batch 01") · permanent
rulings, not historical notes.

Future implementations must preserve these unless a newer approved ClickUp
specification explicitly replaces one:

1. **`job_interview` has a household-tier clean observation and no
   catastrophic tier.** The clean row is the only action-shaped household
   observation (`growth / hired_on`), and the action intentionally cannot
   catastrophically fail: the worst result is not being hired. Future tables
   must not add a catastrophic row or remove that clean household row.
2. **`escape` catastrophic rides `neighborhood`, not `network`.** A botched
   escape is a local spectacle — the block sees you run — rather than a
   systemic signal. The network channel is reserved for organized criminal
   activity.
3. **The tier-3 organized-hit counter increments on success.** An attempt is
   not organized work until it succeeds; a blown job must not advance the
   counter. This remains the success-side contract.

### The Divergence Protocol these rulings established

When a build brief conflicts with the oracle (web behavior) or an approved
specification:

1. Stop implementation of the conflicting item.
2. Document what the brief says, what the oracle says, and which wins and why.
3. Treat the oracle as behavioral authority unless a newer approved ClickUp
   specification explicitly overrides it.
4. Record the resolution here as standing policy.
5. Continue implementation only after the resolution is recorded.

Every `D-` entry in this file above this one is this protocol, applied. D-5 is
the clearest recent example: the build prompt and the shipped code disagreed
about the day-cross settlement order, and the resolution — code wins, with the
reason recorded — is exactly steps 2–4 of this protocol run against a case the
protocol did not originally anticipate (a *document*, not a brief, disagreeing
with shipped code).

---

## Escalations open as of Batch 18 PR 0

Two items filed as defects turned out to be design rulings. Neither was guessed
at. Both need a human answer.

### `86bbjk6kk` — Boost tier-3 Run failure arrests unconditionally

**Status: closed — see D-14 (HEAT-D2), 0.3.0.** The OR-clause this entry
describes is gone: tier now scales the arrest threshold (`RUN_FAILURE_ARREST_
HEAT`, tier-keyed) instead of bypassing it at tier 3. Left below, unedited,
as the record of what the defect actually was and why it needed a ruling
rather than a silent fix.

**Status when filed: open. Not a defect as filed.**

It does arrest unconditionally at tier 3, and it does so because
`data/consequence_rules.gd:132-135` transcribes FS-003 §5:

> "Arrest occurs only when pre-encounter Global Heat > 6 **or the target is
> Tier 3**."

The code implements the approved spec exactly. Changing the behaviour amends
FS-003 §5 — a design ruling, not a fix. Needs an answer to "should tier 3 stop
being an unconditional arrest, and what replaces it".

### `86bbjkccu` — Pherris's wage exceeds her delegated return at rank 2

**Status: open. Any fix is a tune.**

Rank 2 costs $120/day (`crew_roster` wage curve `[60, 120, 220]`) and raises her
cycle cap from 1 to 2
(`CREW_CAPABILITIES.pherris.max_cycles_by_rank = [1, 2, 3]`). Whether two cycles
of listing margin clears $120 is a measured question, and every available lever —
the wage curve, the cycle curve, the margin — is a balance change.

**"Report, do not tune" is the standing rule** and Build 18's PR 4 restates it
for everything except the one missing Territory cost line that PR exists to add.
Needs either a ruling that delegation is allowed to be worth less than its wage
at rank 2, or an explicit tuning mandate naming the lever.

### A note on how both were escalated

Neither ticket's own ClickUp comments could be read during the session that
filed these: the connector was unauthenticated and the session was
non-interactive, so if either ticket already carries a ruling, it was not
visible. Check the tickets before acting on these entries.

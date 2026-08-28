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
| On-device smoke is a checklist, not automation | `docs/ANDROID_SMOKE.md` — install, cold boot, start a run, scroll Market/Jobs/Phone with a thumb starting ON cards (D-11's fix, meant to be felt in the hand), buy/sell, save/reload, kill/relaunch resumes. The user runs it on their own phone; the house merge rule already provides the pause before that answer is needed. |
| Version `0.2.0 → 0.2.1`, PATCH | Same TOUCH-D7 ruling D-11 already recorded, ridden here at the close-out: neither the touch fix nor an additive build target ships a player-facing surface or system, so this stays PATCH under `version.gd`'s own MAJOR/MINOR/PATCH definition. |

### Why this PR carries the entry rather than a later one

Same Slice-0-before-the-code discipline as D-7 through D-11: the additive-
preset property, the no-committed-keystore rule, and the legacy-build choice
are all things `export_presets.cfg` and `android-apk.yml` now depend on, so
the ruling is recorded where the dependency was created.

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

**Status: open. Not a defect as filed.**

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

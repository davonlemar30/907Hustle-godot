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

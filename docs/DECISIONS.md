# Decisions

Standing rulings, newest first. One entry per decision, each with what was
decided, why, and what it binds.

**This file is a record, not an authority.** Where a ruling here describes
shipped behaviour and the code disagrees, the code wins and the ruling is stale
— fix it here. Where a ruling grants permission for future work, it binds until
superseded by a later entry that says so by number.

Started in Batch 18 PR 2, because D-5 had to be recorded somewhere before the
documentation it corrects could point at it. PR 5 back-fills the rulings
currently buried in `HANDOFF.md` narrative: the Build 5e divergences, D-1
through D-4, the `CAUGHT_EFFECTS` anomaly and the `legal_worker` baseline.

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

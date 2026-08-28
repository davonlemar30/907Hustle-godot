# Street Opportunity and Mission System — System Design

**Status:** Proposed umbrella design for evaluation; not yet an implementation
authority  
**Audience:** 907Hustle design, engineering, content, balance review, and ClickUp
Brain  
**Scope:** How opportunities are discovered, compared, accepted, resolved,
remembered, and used to advance relationships and hustle access across the game  
**First concrete consumer:**
`docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md`  
**Out of scope:** Replacing the existing hustle systems, imposing a fixed run
length, copying Torn's MMO resource bars, or turning every player action into a
quest objective

---

## 1. Executive summary

907Hustle already contains many functioning economic and consequence systems.
The missing game-wide layer is not another hustle. It is a consistent answer to:

> How does the player hear about something worth doing, understand why it
> matters now, commit to it, see the consequences, and discover what changed
> afterward?

The **Street Opportunity and Mission System** supplies that answer.

Its repeatable player loop is:

```text
DISCOVER
→ COMPARE
→ COMMIT
→ EXECUTE THROUGH AN EXISTING SYSTEM
→ RESOLVE RISK AND CONSEQUENCES
→ SETTLE REWARD, REPUTATION, AND ACCESS
→ SURFACE THE NEXT MEANINGFUL CHOICE
```

The design combines two external inspirations with 907Hustle's existing
identity:

- **Drug Lord 2 contributes the decision engine:** visible opportunities,
  limited capital/capacity, location and timing choices, risk mitigation,
  consequences, and a changed next decision.
- **Torn contributes the goal layer:** named mission givers, introductory
  chains, limited contracts, milestone promotions, and jobs that develop into
  careers.
- **907Hustle contributes the world model:** four-part days, Exposure, personal
  memory, district conditions, Heat, Curtis, crew, territory, and consequences
  that travel through the neighborhood.

The system does **not** absorb Jobs, Market, 907List, Lift, Stickup, Shark,
Wander, Crew Operations, or Territory. Those systems remain authoritative for
their own rules. Opportunities point into them, observe their authoritative
results, and connect those results to relationships and future access.

The Dre lending design is sufficient as a vertical content specification. This
document is still necessary because it prevents every future NPC and hustle from
inventing a different mission state machine, objective language, deadline rule,
and reward pipeline.

---

## 2. Why the Dre system design is not the whole game-wide rule

The Dre design specifies:

- borrowing from Dre;
- repayment, extension, default, and restitution;
- Dre's authored contracts;
- progression into the existing Loan Book;
- one concrete mission chain;
- one domain's UI, balance, and save requirements.

It deliberately leaves its opportunity substrate reusable. Without this
umbrella design, later work could still diverge:

- Dre contracts might use `active_opportunities` while Scores invent
  `active_missions`.
- Jobs might detect objectives from the activity log while Crew uses proofs.
- One agent might settle rewards through Wallet while another directly edits
  cash.
- One deadline might expire at the start of Night while another expires after
  Night with the same copy.
- Home, Phone, Word Around Town, and Hustle could each show a different answer
  to whether an offer is live.

This design establishes the shared contract. Domain designs such as Dre then
author content and rules inside it.

### 2.1 Design authority between documents

When this document and a domain design are evaluated together:

- this document owns the shared opportunity lifecycle, objective vocabulary,
  deadline semantics, capacity rules, typed completion effects, settlement
  order, and cross-surface presentation contract;
- the domain design owns its fiction, eligibility, economy, relationship
  milestones, domain-specific failure states, and balance values;
- the existing runtime domain system remains authoritative for the action that
  actually occurred and its base consequences;
- if a domain needs an exception to the shared contract, that exception must be
  named and approved rather than implemented implicitly.

For Dre specifically, this document determines how a Dre offer becomes an
accepted and resolved opportunity. The Dre design determines loan terms, debt
behavior, trust progression, contract content, and when the player earns access
to the Loan Book.

---

## 3. Current-state assessment

### 3.1 Strong foundations already present

The current build already has:

- one action boundary through `GameManager.dispatch()`;
- semantic eligibility through `Requirements`;
- visibility and route guarding through `SurfaceVisibility`;
- deterministic action outcomes through `OutcomeResolver`;
- multi-step confrontation and delayed fallout through `ConsequenceEngine`;
- personal and propagated reputation through `Exposure`;
- district-specific criminal attention through District Pressure;
- an explicit four-slot day and ordered night lifecycle;
- Phone texts, contacts, bills, logs, and Word Around Town;
- Wander discovery, ambient reads, opportunities, and encounters;
- an announcer that reports newly opened surfaces;
- save validation, migrations, receipts, and regression suites;
- real domain systems for Jobs, Market, 907List, Lift/Boost, Stickup, Shark,
  Crew, Crew Operations, Territory, Recovery, and travel.

### 3.2 Existing opportunity-like behavior is fragmented

Several systems already produce parts of the desired experience:

- Wander discovers jobs, places, market access, cash, intel, and encounters.
- Phone renders ambient market intelligence and contains dormant support for
  actionable messages.
- Home surfaces Wander results, standing actions, tonight's operation, and an
  activity feed.
- Crew Operations uses semantic requirements and persistent proofs.
- SurfaceVisibility announces newly opened systems.
- Consequence chains already preserve source, target, district, choices, and
  return routes.

What is missing is one shared lifecycle for an authored or generated
opportunity that can survive save/load, accept or decline, track an objective,
settle exactly once, and produce a follow-up.

### 3.3 Current pacing gates are not all narrative access

Some Hustle surfaces currently open because a day or Wander count threshold was
reached. Those gates can serve temporary pacing, but they do not automatically
express why a named person trusts the player or why a specific opportunity
exists.

This design does not require removing every elapsed-progress gate. It requires
relationship-, introduction-, and target-specific access to use authored facts
instead of elapsed time as a substitute.

### 3.4 The player can receive consequences without a clear next pull

The underlying simulation often changes correctly, but the player-facing answer
to "what did that make possible?" is inconsistent. Closing the loop requires
both settlement and a readable forward consequence.

---

## 4. Design goals

### G1. Establish one player-visible decision spine

Every major opportunity should help the player understand:

- why it is available;
- why it matters now;
- what it will consume;
- what is known about payoff and risk;
- what preparation is possible;
- what changed after resolution.

### G2. Preserve systemic freedom

Missions and contracts create short-term intention. They do not become the only
profitable or meaningful way to play.

### G3. Reuse existing mechanics

If a contract requests a Lift, Lift resolves it. If it requests employment,
Jobs resolves the interview and shift. If it requests a market trade, Economy
moves inventory and cash. The opportunity layer never contains parallel copies
of those rules.

### G4. Give characters thematic work

Named people should offer work that reflects who they are, what they know, and
how they read the player. Different agents are content channels over the same
technical lifecycle.

### G5. Separate access from sentiment

Exposure expresses what a person currently thinks. Milestone facts express what
the player has permanently learned, completed, or been allowed to access.
Temporary blocks express current conditions without erasing history.

### G6. Make information actionable

Intel should alter a decision. A market lead changes where or when the player
trades. A target lead creates a Score. A warning changes preparation. Flavor
that creates no actionable difference stays ambient and does not become a
persisted offer.

### G7. Respect the four-part day

Deadlines, travel, meetings, recovery, contracts, jobs, and Scores compete for
the same time. The system adds no second Energy or Nerve economy.

### G8. Limit cognitive load

The player should have a small number of meaningful live commitments, not a
page of chores. Persistent surfaces remain available without occupying mission
slots.

### G9. Support authored arcs and repeatable play

The same lifecycle must support a finite milestone mission and a repeatable
contract without pretending they are identical content.

### G10. Land no unused framework

The minimal opportunity substrate ships with Dre's first real chain or another
approved live consumer. It does not land several builds before content can use
it.

---

## 5. Non-goals

This system will not:

- replace the Hustle hub with a quest log;
- make accepting missions mandatory for ordinary Jobs, Market, or 907List play;
- add visible agent XP bars;
- add mission credits, Energy, Nerve, or Happiness;
- grant rewards for merely opening a screen;
- track objectives by matching activity-log strings;
- introduce real-time offer refreshes;
- create a fixed tutorial week or fixed run duration;
- expose hidden raw Exposure or District Pressure scores;
- define the detailed economy of every hustle;
- create bespoke minigames inside mission definitions;
- allow data files to execute arbitrary mutations;
- create a procedural contract generator before one authored chain works.

---

## 6. Opportunity taxonomy

Not everything worth doing is a mission. The taxonomy is a design boundary.

| Type | Meaning | Persisted lifecycle? | Acceptance required? | Example |
|---|---|---:|---:|---|
| **Standing surface** | A system the player has access to repeatedly. | Access fact only | No | Jobs, Market, 907List, The Book |
| **Lead** | Actionable information pointing toward a condition or opportunity. | Only while still actionable | Usually no | A favorable route, named target, workplace rumor |
| **Score** | A target-specific, risky criminal opportunity executed through an existing hustle method. | Yes | Usually yes | Lift a named vehicle; rob a named target |
| **Contract** | Limited work offered by a named character, normally repeatable or semi-random. | Yes | Yes | Dre collection; Mina delivery |
| **Mission** | Authored milestone content that changes access, relationship, or story state. | Yes | Yes or explicit start | Dre's first loan chain; first crew introduction |
| **Job career** | Ongoing employment with interviews, shifts, ranks, and perks. | Career state, not mission state | Apply/interview | Chevron or Wash & Go employment |
| **Operation** | Work assigned to crew using existing Crew Operations rules. | Existing operation state | Assignment required | Send Pherris to 907List |
| **Obligation** | A cost or promise the player must address. | Yes | Already incurred | Rent, Debt to Dre, wages |
| **Threat** | Reactive danger requiring a decision. | Existing consequence state | No | Retaliation, collection, arrest pressure |
| **Ambient event** | Character or world texture without a durable actionable promise. | No beyond existing observations | No | A rumor with no current target |

### 6.1 Taxonomy rules

- Standing surfaces never consume an active-contract slot.
- A Lead expires when its underlying fact stops being useful; it does not fail.
- A Contract can be declined before acceptance; accepted work may fail.
- A Mission has authored follow-up and milestone meaning.
- Obligations and Threats may appear beside opportunities in UI because they
  compete for time, but they are not mislabeled as rewards.
- Ambient events remain lightweight. Persistence is a cost paid only when the
  player can act on the information later.

---

## 7. The shared opportunity loop

### 7.1 Discover

An opportunity enters play through an authoritative source:

- a named NPC message or meeting;
- Word Around Town;
- Wander;
- a workplace interaction or promotion;
- a crew member;
- a district or territory condition;
- a prior outcome or consequence;
- an existing market or listing projection.

Discovery records **how the player knows**, not merely that a UI row should be
visible.

### 7.2 Compare

Before commitment, show the information the player is entitled to know:

- source/giver;
- location;
- deadline or live window;
- slot cost;
- cash/inventory/capacity requirement;
- expected payoff as exact amount, range, or qualitative promise as authored;
- risk band and known consequences;
- preparation options;
- relationship stakes;
- blocker reason, if the opportunity is known but temporarily unavailable.

The projection must come from the owning systems. Opportunity data cannot carry
a second payout or risk formula.

### 7.3 Commit

Acceptance normally costs no slot. Acceptance is a promise, not the work.

Exceptions require explicit authorship—for example, a meeting that begins and
accepts a mission may itself consume a slot. Copy must state the cost before the
action.

### 7.4 Execute

The player uses an existing domain action:

- apply or work through Jobs;
- buy/sell through Economy;
- complete a 907List transaction;
- attempt Lift/Boost or Stickup;
- Wander, travel, recover, meet, delegate, fund, or collect through their
  existing owners.

### 7.5 Resolve

The domain returns its authoritative result. Risky or delayed paths may open or
complete a consequence chain. The opportunity does not settle early merely
because the attempt began.

### 7.6 React

On resolution:

- the base system settles its normal money, inventory, Heat, Health, pressure,
  and other domain effects;
- Exposure records authored observations;
- the opportunity applies only its explicit, typed bonus or milestone effects;
- accepted work becomes completed, failed, or ready for turn-in exactly once;
- follow-up eligibility is reconciled;
- the player receives a concise explanation of what changed.

### 7.7 Advance

The next choice may change because:

- an agent offers harder work;
- a new Score appears;
- a workplace perk unlocks intel;
- a crew introduction becomes available;
- a district opens;
- a threat or obligation now competes for time;
- the same action is less attractive because pressure increased.

If resolution produces only a reward toast and the next decision is identical,
the mission layer has not tied the game together.

---

## 8. Opportunity lifecycle

```mermaid
stateDiagram-v2
    [*] --> Hidden
    Hidden --> Offered: Discovery and requirements pass
    Offered --> Active: Accept
    Offered --> Declined: Decline
    Offered --> Expired: Offer window closes
    Offered --> Withdrawn: Source invalidates offer
    Active --> Ready: Objective satisfied; return required
    Active --> Completed: Objective satisfied; auto-settle
    Active --> Failed: Failure condition resolves
    Active --> Expired: Accepted deadline closes
    Ready --> Completed: Turn in / final conversation
    Declined --> [*]
    Expired --> [*]
    Withdrawn --> [*]
    Failed --> [*]
    Completed --> [*]
```

### 8.1 State meanings

- **Hidden:** definition exists but the player has neither discovered nor been
  offered it.
- **Offered:** visible and actionable; acceptance has not occurred.
- **Active:** the player accepted and the objective can advance.
- **Ready:** objective is satisfied but authored turn-in or final conversation
  remains.
- **Completed:** all completion effects settled and receipt claimed.
- **Declined:** player explicitly rejected an unaccepted offer.
- **Expired:** the authored window ended.
- **Withdrawn:** the source became invalid before acceptance, such as a target
  disappearing for a reason outside the player.
- **Failed:** accepted work reached an authored failure condition.

### 8.2 Completion policy

Use automatic completion when the authoritative result is the entire promise.
Use `Ready` only when returning to the giver creates a meaningful choice,
relationship scene, payment, or reveal. Do not add turn-in clicks as ritual.

### 8.3 Decline versus failure

- Declining before acceptance is not failure.
- Allowing an offer to expire is not automatically betrayal.
- Accepting and then abandoning work may trigger `refused_work`,
  `botched_mission`, or a domain-specific observation.
- Definitions author these differences; the engine preserves the states.

---

## 9. Shared state model

Exact names are proposals. Runtime state must remain minimal and derived facts
must not be persisted.

```gdscript
var opportunity_offers: Array = []
var active_opportunities: Array = []
var opportunity_history: Dictionary = {}
var opportunity_next_instance_id: int = 1
```

### 9.1 Definition shape

Definitions are immutable authored data.

```gdscript
{
    "id": "dre_first_money",
    "kind": "mission",
    "giver_id": "dre",
    "family": "dre_credit",
    "source_adapter": "dre",
    "repeatable": false,
    "requirements": [],
    "offer_window": {},
    "deadline": {},
    "objectives": [],
    "completion_mode": "auto",
    "completion_effects": [],
    "failure_effects": [],
    "followups": [],
    "presentation": {},
}
```

### 9.2 Instance shape

Instances store only run-specific information.

```gdscript
{
    "instance_id": 12,
    "definition_id": "dre_first_money",
    "state": "active",
    "source_context": {},
    "offered_day": 8,
    "offered_slot": 1,
    "accepted_day": 8,
    "accepted_slot": 1,
    "deadline_day": 10,
    "deadline_slot": 3,
    "objective_progress": {},
    "resolved_result": {},
    "receipt_id": "opportunity:12:complete",
}
```

### 9.3 Source context

The instance pins only information that must remain stable:

- named target or borrower;
- district;
- authored amount/range selection;
- source/giver;
- accepted approach restrictions;
- deterministic RNG key;
- return route where required.

Live projections such as current Heat, relationship, wallet balance, or district
pressure are read from their owners unless the design explicitly says the offer
locked them at acceptance.

### 9.4 History

History stores compact facts needed for:

- one-time missions;
- repeat limits;
- follow-up requirements;
- content variety;
- record/character presentation;
- save-stable milestones.

Do not retain full resolved instance payloads forever when a definition ID,
outcome key, count, and last-resolved day answer every future question.

---

## 10. Objectives

### 10.1 Principle

Objectives observe authoritative gameplay results. They do not infer play from
navigation, UI labels, or activity copy.

### 10.2 Supported objective classes

The first version should implement only classes needed by live content.

| Class | Reads | Example |
|---|---|---|
| `action_result` | Successful dispatch action, payload, and returned result | Get hired; complete a specific Lift outcome |
| `state_fact` | Canonical GameState/system projection | Hold one job; account is clear; target is discovered |
| `counter_delta` | Authoritative counter change after acceptance | Complete one clean 907List flip |
| `consequence_result` | Claimed consequence receipt/outcome | Resolve a collection through negotiation |
| `maintain_condition` | State at resolution/deadline | Keep Heat below an authored band |
| `deliver_resource` | Explicit turn-in through owning inventory/wallet system | Bring a named item or amount |

Unknown objective classes fail closed.

### 10.3 Objective composition

A definition may require:

- **all** objectives;
- **any one** of several authored approaches;
- an ordered sequence for milestone missions;
- one main objective plus optional constraints.

Avoid a fully general expression language. Use semantic records evaluated by a
small, tested table.

### 10.4 Multi-path objectives

Where the fantasy permits, author the desired result rather than one mandatory
button.

Examples:

- "Have $150 of clean money by tomorrow" may allow Jobs or approved trading if
  the wallet can authoritatively distinguish the source.
- "Resolve the collection" may allow payment, negotiation, or enforcement,
  with different outcomes.
- "Learn whether the target is safe" may allow a workplace contact, Wander, or
  a crew operation if each produces the same semantic proof.

Some Scores should remain method-specific. Flexibility is authored, not assumed.

### 10.5 No log-string objectives

`activity_log` is presentation. Copy edits, localization, and multiple messages
per action make it unsuitable as a rules API. Objectives use results, facts,
counters, or receipts.

---

## 11. Completion effects and rewards

### 11.1 Base outcome versus opportunity effect

The underlying action owns its normal result:

- Job wages belong to Jobs/Wallet.
- Trade profit belongs to Economy/Wallet.
- Lift and Stickup payout, Heat, Pressure, and damage belong to those systems.
- Loan repayment belongs to Shark.
- Territory income belongs to Territory.

The opportunity may add an authored bonus, relationship observation, access
milestone, message, or follow-up—but it must not repeat the base settlement.

### 11.2 Typed effects

Definitions may use a small allowlist of semantic completion effects:

- `wallet_credit` through Wallet with source and cash class;
- `exposure_observation` through Exposure;
- `access_milestone` through the owning progression system;
- `message` through Phone;
- `announce_surface` through reconciled access/Announcer, never direct UI state;
- `record_proof` through the owning proof ledger;
- `offer_followup` through Opportunities;
- future inventory grants only after an inventory owner exists.

Unknown effects fail closed. Data definitions cannot name arbitrary methods or
mutate GameState fields directly.

### 11.3 Reward rules

- No generic mission currency in the first version.
- Mission bonuses should not make the underlying action irrelevant.
- Access, information, relationships, and opportunities are valid rewards.
- Milestone missions may pay little or no cash when access is the payoff.
- Repeatable contract rewards must be measured against the opportunity cost of
  the consumed slot and the risk of failure.
- Every reward claims an idempotent receipt before mutation.

---

## 12. Agents, relationships, and progression

### 12.1 Agent model

An agent is a named content source, not a separate gameplay engine. An agent
definition provides:

- character ID and presentation;
- thematic opportunity families;
- authored milestones;
- offer-pool rules;
- Exposure requirements and observations;
- access milestones owned by the relevant domain;
- decline/failure policy;
- cadence and maximum live offers.

### 12.2 Exposure versus access

- Exposure disposition influences whether an offer is plausible, how it is
  worded, and which variants appear.
- Access milestones record introductions, completed arcs, and permissions.
- A small relationship shift must not erase learned systems.
- Serious conditions may temporarily block an agent with a visible reason.

### 12.3 Difficulty progression

Borrow Torn's useful structure without copying a visible standing grind:

```text
ordinary work at current access
→ authored milestone becomes eligible
→ complete milestone
→ higher-difficulty offers enter the pool
```

Difficulty tiers should change situation and consequence, not only multiply
cash and enemy numbers.

### 12.4 Candidate agent identities

This design does not authorize content, but existing characters naturally point
to distinct channels:

- **Dre:** credit, vetting, collections, the Loan Book.
- **Mina:** night work, discretion, recovery, deliveries, people seeking quiet
  help.
- **Yalonda:** legitimate introductions, household obligations, stability.
- **Juan:** trade, market access, supplier or warehouse opportunities.
- **Crew members:** operations that prove trust and capability.
- **Curtis:** primarily antagonist/threat source rather than a conventional
  mission giver.

Each needs a separate content design before implementation. The shared engine
does not invent their voice or arc.

---

## 13. Scores

### 13.1 Role

Scores are the target-specific criminal opportunity family. They are where the
Drug Lord 2 decision engine and Torn-style contract wrapper meet most directly.

A Score answers:

- who or what is the target;
- where and when it is available;
- what methods are possible;
- what preparation can change;
- what payout is believed;
- what risk is known;
- who offered or revealed it;
- what happens to future opportunities after resolution.

### 13.2 Existing systems remain separate resolvers

The unified Score layer may present Lift and Stickup opportunities together,
but it does not merge their underlying engines.

- Lift/Boost owns stores/targets, technique, bans, fencing, caught outcomes,
  and its Pressure family.
- Stickup owns robbery targets, tiers, payout, damage, retaliation, and its
  Pressure family.
- The shared confrontation chassis resolves supported trouble.
- Score state owns discovery, commitment, source/giver, deadline, optional
  constraints, and follow-up.

### 13.3 Score lifecycle

```text
Lead reveals target
→ Score card becomes offered
→ player compares method, payoff, risk, district, and preparation
→ player accepts or acts while live
→ selected hustle system resolves attempt
→ consequence completes if opened
→ Score settles completed/failed
→ source, neighborhood, and next tier react
```

### 13.4 Score preview

Show:

- target and district;
- live window/deadline;
- one-slot or multi-step cost as authored;
- payout band or qualitative promise from the owning system;
- risk band, not hidden raw Pressure score;
- known Heat/Health/inventory exposure;
- eligible crew/preparation;
- source/giver and relationship stake;
- method-specific blockers.

### 13.5 Score ladder

Progression should come from completed milestones and demonstrated capability,
not a generic Respect number that increases for every crime.

Possible proof categories include:

- completed target tier;
- clean versus messy resolution;
- returned value;
- relationship-specific trust;
- district access;
- crew capability;
- accepted consequences.

The exact ladder requires a separate Scores content/economy design. This
document defines how it plugs into opportunities.

---

## 14. Market, 907List, and Drug Lord 2-style intel

### 14.1 Markets are systems, not mission boards

The Market and 907List should remain systemic, repeatable economic surfaces.
Their ordinary transactions do not need acceptance records or mission bonuses.

### 14.2 Leads make market information actionable

A price or listing becomes a Lead when the player learns something that can
change a near-term decision:

- a product is unusually favorable elsewhere;
- a named buyer wants an item;
- a workplace contact reveals supply;
- a district event changes availability;
- a 907List seller or buyer creates a temporary opportunity.

The Lead stores the stable source/window and reads the live market projection.
If the market changes, the Lead updates or expires according to its authored
promise; it cannot display a stale copied price as current truth.

### 14.3 No artificial trade missions by default

Avoid generic "buy three items" or "visit the Market" missions. Use market
contracts only when a person, deadline, relationship, or delivery condition
creates a distinct decision.

### 14.4 Information tools

Drug Lord 2's world prices and price history work because they help compare
capital allocation. 907Hustle should preserve that function through:

- current district prices;
- Word Around Town routes;
- discovered external prices;
- workplace/crew intel;
- market history or trend presentation only if the player can act on it.

Intel is a strategic input, not collectible lore.

---

## 15. Jobs and Torn-style career progression

### 15.1 Jobs remain an ongoing career system

A Job is not a long mission. It owns:

- discovery and application;
- interview resolution;
- active employment;
- shifts and approaches;
- attendance and firing;
- job XP/rank;
- pay and workplace consequences.

### 15.2 Missions may introduce Jobs

An introduction mission may:

- tell the player where work exists;
- provide a vouch or interview context;
- ask the player to hold a job or reach a named rank;
- create a workplace opportunity after promotion.

It may not auto-hire the player or replace the real interview unless the
authored result explicitly routes through Jobs.

### 15.3 Career improvement needed

The existing job ladder currently communicates generic numeric ranks and pay
scaling. Torn's strongest applicable lesson is that promotion should change
capability.

Future job content should add:

- job-specific rank names;
- one meaningful perk or opportunity at selected ranks;
- workplace characters or contacts;
- real effects for `SOCIALIZE` and `LEARN THE JOB`;
- job-derived Leads or introductions that feed other systems.

This may be a separate Job Career design. It uses the Street Opportunity System
for offers and contacts but keeps shift economics in Jobs.

### 15.4 No job-points currency by default

Rank perks should initially unlock automatically or through an authored choice.
A new spendable job currency is not justified until the existing rank choices
need one.

---

## 16. Word Around Town, Wander, Phone, and discovery

### 16.1 Source roles

- **Wander:** spend a slot to find people, places, intel, opportunities, or
  trouble without choosing exactly which one.
- **Word Around Town:** present actionable ambient intelligence already earned
  by location, relationships, Phone access, or prior observation.
- **Phone:** deliver named offers, messages, obligations, accepted contract
  updates, and contacts.
- **Home:** summarize urgent and newly meaningful choices.

These are complementary. They should not each generate independent copies of
the same opportunity.

### 16.2 One opportunity, many views

An opportunity instance has one ID and one state. Wander may discover it, Phone
may carry the giver's message, Home may summarize it, and a Score screen may
show its details. All four views read the same instance.

### 16.3 Discovery facts

Store facts about what happened:

- met a person;
- heard about a target;
- discovered a place;
- received an offer;
- learned a market route;
- completed a milestone.

Do not store derived duplicates such as `score_button_unlocked` when the target
discovery and access milestone already determine it.

### 16.4 Offer generation

- Generated offers use deterministic seeded selection.
- Opening Phone/Home never creates or rerolls offers.
- Offer cadence is authored per source/agent.
- Generation occurs at a declared lifecycle point after prior outcomes and
  Exposure settle.
- Requirements fail closed before an offer enters the visible pool.
- Variety memory prevents immediate repeats where content supports alternatives.
- Named milestone missions cannot be displaced by random contracts.

---

## 17. Time, deadlines, and capacity

### 17.1 In-game time only

All windows use the game's day and slot. No offer depends on wall-clock time.

### 17.2 Deadline representation

Store absolute `deadline_day` and `deadline_slot` on an instance when the offer
locks a window. Definitions describe how to calculate that point.

### 17.3 Inclusive rule

If copy says "by Night," the player may complete the action during Night unless
the offer explicitly says "before Night." Expiration occurs when advancing past
the stated final slot.

The UI must use the same deadline projection as the engine:

- GOOD THIS AFTERNOON;
- GOOD THROUGH NIGHT;
- DUE TOMORROW;
- EXPIRES AFTER THIS PART OF DAY.

### 17.4 Active commitment limit

Recommended MVP limit:

- maximum **three accepted Contracts/Missions/Scores** at once globally;
- Leads, standing surfaces, obligations, operations, and threats do not consume
  this limit;
- milestone definitions may reserve or bypass a slot only through an explicit
  design ruling.

Three is a starting recommendation, not an MMO imitation. It is small enough
to preserve readable choice within a four-slot day and large enough to permit
competing commitments. Measurement and playtest may change it.

### 17.5 Acceptance and slot cost

- Reviewing and normally accepting an offer costs no slot.
- The actual meeting/action costs what its domain already charges.
- If accepting is itself the meeting, the confirmation must state that it will
  advance time.
- Resolving an event choice does not charge a second slot unless the owning
  consequence explicitly authors a new action.

---

## 18. UI and information architecture

### 18.1 Home — what matters now

Home should not become a mission page. It should show at most a compact
priority stack:

1. urgent obligation or threat;
2. nearest accepted deadline;
3. strongest new offer or actionable result;
4. standing actions already supported by the current design.

Every card answers "what changed" or "what requires a decision."

### 18.2 Phone — people and promises

Phone owns:

- named offer messages;
- accept/decline where live;
- active contract updates;
- contact-specific work;
- bills and obligations;
- Word Around Town.

An actionable text carries an opportunity instance ID. Buttons dispatch against
that instance and disappear or change when its state changes.

### 18.3 Hustle hub — standing methods

Hustle remains the catalogue of repeatable income methods:

- Jobs;
- 907List;
- Market;
- Lift/Boost or unified Scores entry as approved;
- Stickup or unified Scores entry as approved;
- The Book after Dre progression.

It should communicate access and current domain status, not list every active
contract.

### 18.4 Score/Opportunity detail

A dedicated detail surface may show accepted and offered Scores/Contracts, but
it should be organized around decisions, not checklist completion percentages.

Recommended sections:

- **NOW:** accepted work and deadlines;
- **ON OFFER:** limited commitments available;
- **LEADS:** actionable intel not requiring acceptance;
- **DONE:** recent meaningful outcomes, compact and capped.

### 18.5 Result presentation

After resolution, show a concise receipt:

- what happened;
- base payout/loss from the owning system;
- opportunity bonus or milestone;
- known Heat/Health/inventory effects;
- relationship/access change in player-facing language;
- next available action.

Do not expose hidden raw scores merely because the opportunity engine can read
their bands.

### 18.6 Locked versus hidden

Use the existing rule:

- **Hidden:** the player does not know the person, place, target, or feature.
- **Locked:** the player knows it exists and has an actionable path to qualify.
- **Temporarily blocked:** previously available, currently unusable for a
  reversible reason.
- **Available:** can act now.

An opportunity-specific blocker must agree across Home, Phone, detail views,
Hustle, and deep routes.

---

## 19. Architecture and ownership

### 19.1 Proposed shared owner

`systems/opportunities.gd` owns:

- offer/active/resolved instance state;
- accept, decline, and turn-in actions;
- deadline state transitions;
- objective reconciliation;
- completion/failure receipts;
- typed opportunity effects;
- follow-up eligibility;
- read-only projections for UI.

It does not own domain actions or their normal consequences.

### 19.2 Domain adapters

Where an opportunity needs domain-specific projections or semantic proofs, the
owner registers a runtime adapter. Adapters are not saved.

Possible adapter contract:

```text
preview(instance) -> Dictionary
objective_facts(instance) -> Dictionary
validate_commitment(instance) -> structured verdict
result_matches(instance, action, payload, result) -> Dictionary
```

Only add methods required by live content. Do not establish a broad interface
on speculation.

### 19.3 Post-action reconciliation

`GameManager.dispatch()` already receives a detailed result dictionary from the
domain handler. Opportunities require a deterministic reconciliation point:

```text
domain handler succeeds
→ opportunity observer reads action/payload/result and live state
→ objective/completion effects settle
→ crew/access invariants reconcile
→ announcer compares gates
→ one notify_changed/autosave
```

Requirements:

- still inside dispatch ownership;
- no nested dispatch;
- exactly once;
- declared observer order;
- action failures do not advance objectives;
- unfavorable but real outcomes can advance/fail objectives when the domain
  returns `ok: true` with a result tier;
- automatic lifecycle outcomes receive a separate declared reconciliation
  point.

### 19.4 Requirements

Opportunity definitions use the existing semantic Requirement evaluator. Add a
new requirement type only when:

- the fact already has one authoritative owner;
- at least one live definition needs it;
- current/required values can be returned for blocker copy;
- unknown or malformed values fail closed.

Potential live types include:

- `opportunity_completed`;
- `opportunity_active`;
- `agent_introduced`;
- domain-specific access tier minimum;
- named target discovered;
- accepted-capacity available.

### 19.5 Typed effects

The opportunity effect resolver is an allowlist over existing mutation owners.
It cannot contain a generic `set_field` or arbitrary method name.

### 19.6 Read-only UI

Every UI action dispatches. Rendering and opening screens never mutate,
generate, accept, expire, complete, or claim an opportunity.

---

## 20. Determinism, save, and lifecycle

- Definitions are immutable data; instances persist run-specific choices.
- Instance IDs are monotonic within the run.
- Generated selections use seeded keys containing stable source, day/slot, and
  instance identity as authored.
- Reopening a view cannot reroll target, reward, risk, or deadline.
- Objective progress survives save/load exactly.
- Completion, failure, and rewards claim receipts before mutation.
- Expiration happens at a declared time transition, not during rendering.
- Follow-up generation occurs after relevant outcomes and Exposure settle.
- SaveValidator validates known states, definition IDs, objective shapes,
  deadlines, receipts, and compact history.
- Unknown definitions in an older/newer save fail safely: preserve enough state
  for repair or withdraw with explicit audit logging; never pay an unknown
  reward.
- Runtime source adapters are rebuilt on boot and never serialized.

### 20.1 Save growth

Cap or compact:

- resolved instance history;
- repeated generated offers;
- declined/expired routine contracts;
- presentation messages already represented elsewhere.

One-time milestone outcomes remain as compact proof facts.

---

## 21. Analytics and balance instrumentation

This is a single-player game, but deterministic simulation and local test
profiles should answer design questions.

Track or instrument:

- offers generated, seen, accepted, declined, expired, withdrawn;
- active opportunity count by day;
- completion/failure by family, tier, and approach;
- slots between discovery, acceptance, attempt, and resolution;
- reward and loss separated into base-domain versus opportunity bonus;
- relationship/access milestones reached;
- opportunities abandoned because of blockers;
- percentage of play spent on accepted work versus free systemic play;
- whether missions crowd out Jobs, Market, 907List, recovery, or travel;
- outcome diversity and immediate-repeat rates;
- time from new run to first informed choice among at least two viable actions.

### 21.1 Balance guardrails

- Mission bonuses do not dominate base earnings.
- Repeatable contracts do not make unrestricted systemic play irrational.
- A player can ignore agents and still maintain a viable run.
- A mission path should create meaningful opportunity cost in the four-slot day.
- Higher difficulty adds consequence and preparation demands, not merely higher
  numbers.
- Generated offers cannot bypass domain discovery or access rules.
- Declining optional work must not create a universal downward spiral.

Measure first. Tune in a separate authorized change.

---

## 22. Acceptance criteria

### 22.1 Shared lifecycle

- One authored opportunity can be offered, accepted, advanced, completed or
  failed, and followed up without UI mutation.
- Offered, active, ready, completed, declined, expired, withdrawn, and failed
  are distinct where authored.
- Completion/reward settles exactly once across save/load.
- Deadlines use one inclusive rule and the same copy projection everywhere.
- Opening Home/Phone/detail never generates or advances state.

### 22.2 Domain authority

- Job objectives use real Jobs results.
- Market objectives use real Economy transactions/provenance.
- Score objectives use real Lift/Stickup/consequence results.
- Dre objectives use real lender/Shark states.
- Crew objectives use real operation proofs/results.
- No opportunity duplicates payout, Heat, Health, Pressure, inventory, or
  attendance logic.

### 22.3 Discovery and presentation

- One opportunity instance can be discovered in Wander, messaged on Phone,
  summarized on Home, and detailed elsewhere without duplicated state.
- Hidden/locked/temporarily blocked/available agree across all routes.
- Every accepted opportunity shows source, goal, deadline, slot cost, known
  requirements, and known stakes.
- Every resolution explains what changed and exposes the next actionable choice
  where one exists.

### 22.4 Relationships and access

- Exposure influences authored offers without becoming a duplicate access bar.
- Milestone access persists through ordinary disposition changes.
- Temporary block has a visible reversible condition.
- Decline, expiry, accepted failure, and completion can produce distinct
  observations.

### 22.5 Cognitive load

- Standing systems and Leads do not consume active-contract capacity.
- Global accepted commitment limit is enforced consistently.
- Home shows a compact priority set, not every possible objective.
- Routine completed history is capped/compacted.

### 22.6 Regression and validation

- Save validation covers every lifecycle state and unknown-definition repair.
- Screen smoke covers zero, offered, active, ready, blocked, completed, failed,
  and expired states.
- Behavioral tests cover deadline boundaries and idempotent rewards.
- Existing Jobs, Market, List, Lift, Stickup, Shark, Crew, Territory,
  confrontation, and lifecycle suites remain green.
- Economy profiles separate base-domain value from opportunity bonuses.

---

## 23. Recommended implementation slices

### Slice 0 — Approve the shared contract

Resolve Section 25 decisions and record approved rulings. Reconcile existing
ClickUp tasks that already propose mission/tip/Score persistence.

### Slice 1 — First live lifecycle with Dre

Implement only the offer/accept/objective/complete behavior required by the
first approved Dre milestone from the Dre system design.

Include:

- persisted instance;
- authoritative objective observation;
- one deadline if the content needs it;
- one typed relationship/access effect;
- Phone/Home projection;
- save/idempotency tests.

Do not add procedural generation.

**Exit:** the shared substrate has one complete player-visible consumer.

### Slice 2 — Shared presentation and limits

- Add consistent offer/active/ready projections.
- Enforce accepted commitment capacity.
- Ensure one instance appears consistently across Phone, Home, and detail.
- Add decline/expiry if live content needs them.

### Slice 3 — Unified Score consumer

- Define Score opportunity metadata.
- Connect Word Around Town/Wander discovery to one Lift and one Stickup target.
- Let existing systems resolve them.
- Add source relationship/follow-up.

**Exit:** two different criminal systems use the same opportunity lifecycle
without sharing their domain rules.

### Slice 4 — Job introduction and promotion opportunity

- Route one real job introduction/offer through the shared layer.
- Implement one real workplace approach effect or rank perk.
- Keep Jobs authoritative for interview, shift, pay, and attendance.

### Slice 5 — Repeatable agent contracts

- Add deterministic offer pools, cadence, variety memory, and capacity.
- Begin with one proven agent/domain.
- Measure checklist pressure and reward crowd-out.

### Slice 6 — Crew, territory, and market Leads

Add each only when its content design proves that the opportunity creates a
meaningful new decision rather than restating a standing surface.

---

## 24. Suggested ClickUp structure

### Epic

**Close the Street Opportunity Loop**

### Proposed tasks

1. **OPP-001 — Approve opportunity taxonomy, lifecycle, and terminology**
2. **OPP-002 — Persisted instance state and save validation**
3. **OPP-003 — Authoritative post-action/lifecycle objective reconciliation**
4. **OPP-004 — Typed completion effects and idempotent receipts**
5. **OPP-005 — Requirements and accepted-capacity gates**
6. **OPP-006 — Phone/Home/detail projections from one instance**
7. **OPP-007 — Dre first milestone as the live vertical slice**
8. **OPP-008 — Word Around Town lead-to-Score bridge**
9. **OPP-009 — Unified Score metadata for one Lift and one Stickup**
10. **OPP-010 — Job introduction and first meaningful rank/workplace perk**
11. **OPP-011 — Repeatable agent offer cadence and variety memory**
12. **OPP-012 — Economy, cognitive-load, and progression measurement report**

The Dre epic remains its domain implementation. OPP tasks own only the shared
contract and should not duplicate Dre's lender, debt, collection, or Loan Book
tasks.

---

## 25. Open design decisions

| ID | Decision | Recommended default |
|---|---|---|
| OPP-D1 | Player-facing umbrella name | Use "Opportunities" internally; use thematic UI names such as Scores, Work, Favors, Calls, and Leads. |
| OPP-D2 | Maximum accepted commitments | Three globally for Contracts/Missions/Scores; standing surfaces and Leads excluded. |
| OPP-D3 | Does acceptance cost a slot? | No by default; only an authored meeting/action advances time. |
| OPP-D4 | Manual mission turn-in | Only when returning creates meaningful dialogue, payment, or choice. Otherwise auto-complete. |
| OPP-D5 | Separate agent standing | No. Use Exposure for sentiment and domain milestones for access. |
| OPP-D6 | Mission currency | None. Use cash, access, information, relationship, and opportunity rewards. |
| OPP-D7 | Offer cadence | Authored per agent/source at in-game lifecycle points; never wall-clock. |
| OPP-D8 | Generic procedural generation | Defer until one Dre chain and one Score chain work. |
| OPP-D9 | Unified Scores presentation | Yes as an opportunity view; keep Lift and Stickup as separate resolving systems. |
| OPP-D10 | Elapsed-day surface gates | Retain only where time itself is the intended fact; replace person/target access with introductions and milestones. |
| OPP-D11 | Deadline semantics | Store absolute day/slot; stated final slot is inclusive. |
| OPP-D12 | Opportunity reward effects | Small typed allowlist; no arbitrary field mutation or callback names in data. |
| OPP-D13 | Home scope | Compact priority stack, not a full quest log. |
| OPP-D14 | Tutorial missions | Optional authored introductions; no fixed tutorial week and no rewards for merely visiting screens. |
| OPP-D15 | Respect stat | Do not make it generic mission XP. Resolve separately: give it an authored meaning or remove it from presentation. |

---

## 26. Risks and mitigations

### Risk: The framework becomes larger than the content

**Mitigation:** Implement only objective/effect types required by Dre's first
live chain. Expand through real consumers.

### Risk: The game becomes a checklist

**Mitigation:** Limit accepted commitments, keep standing systems viable, use
few situational objectives, and make Home a priority summary.

### Risk: Missions duplicate economy and consequences

**Mitigation:** Base systems settle base outcomes. Opportunity effects are typed,
small, audited, and idempotent.

### Risk: Multiple views disagree

**Mitigation:** One persisted instance and one projection API feed Wander,
Phone, Home, Hustle/detail, and deep routes.

### Risk: Agent progression becomes another XP ladder

**Mitigation:** Exposure provides sentiment; authored milestones provide access;
no visible numeric standing.

### Risk: Generated work feels generic

**Mitigation:** Prove authored character chains first. Generated templates stay
inside each agent's voice, systems, and consequences.

### Risk: Deadlines feel unfair

**Mitigation:** Exact day/slot projection, inclusive rules, deterministic expiry,
and visible time cost before commitment.

### Risk: Existing systemic play becomes inferior

**Mitigation:** Measure bonus crowd-out and preserve viable no-contract profiles.

### Risk: Discovery becomes another hidden gate

**Mitigation:** Breadcrumbs, actionable blocker copy, and sources that explain
how the player knows or what they can do next.

### Risk: Legacy ClickUp tasks build competing substrates

**Mitigation:** Brain review should identify duplicate Word of Mouth, mission,
Score, job-offer, and progression tasks before implementation begins.

---

## 27. Questions for ClickUp Brain evaluation

ClickUp Brain should review this document together with the Dre system design
and current backlog, then answer:

1. Which open ClickUp tasks already describe mission, contract, Word of Mouth,
   tip, Score, job-offer, or progression state?
2. Which tasks should become consumers of this shared system, and which propose
   competing infrastructure that should be superseded?
3. Does the taxonomy correctly keep standing systems, Leads, Scores, Contracts,
   Missions, Jobs, Operations, Obligations, Threats, and ambient events distinct?
4. Is the proposed opportunity lifecycle minimal enough for the first Dre
   consumer?
5. Which objective and typed-effect classes are actually required by the first
   two approved content slices?
6. Does post-action reconciliation fit the current GameManager single-refresh,
   mutation-ownership, autosave, and announcer contracts?
7. Which automatic lifecycle outcomes need explicit opportunity reconciliation?
8. Are any proposed facts duplicates of GameState, Exposure, Requirements,
   consequence receipts, Crew proofs, or existing counters?
9. Can the unified Score presentation support Lift and Stickup without merging
   or weakening their domain mechanics?
10. Does the three-commitment recommendation fit a four-slot day, or should the
    first playtest use a different cap?
11. Which current elapsed-day gates represent intentional pacing, and which are
    temporary substitutes for discovery or relationship?
12. Where could mission bonuses crowd out Jobs, Market, 907List, recovery,
    travel, or free-form Scores?
13. What is the smallest dependency-ordered ClickUp plan that ships one closed
    Dre loop and one closed Score loop without unused substrate?
14. Which acceptance criteria or failure states are missing before the design
    becomes implementation-ready?

---

## 28. Final design tests

The shared system succeeds when a player can describe both of these experiences:

> I heard about something worth doing, understood what it would cost me, chose
> it over other work, handled what went wrong, and the city gave me a different
> decision afterward.

and:

> I ignored the offer and still played a viable run through the systems I had
> already earned.

It fails if:

- every feature becomes a mission;
- missions are only bonus cash attached to ordinary clicks;
- the player cannot tell why an opportunity appeared;
- accepting work does not affect later relationships or access;
- Home becomes a wall of objectives;
- Lift, Stickup, Jobs, Market, or The Book reimplement their rules inside
  mission data;
- another surface unlocks only because an arbitrary day arrived when the real
  fiction is meeting a person, learning a target, or proving capability.

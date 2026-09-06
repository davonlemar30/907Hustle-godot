# Organized Crime Economy & Territory Expansion — Systems Design & Build Plan

_Design pass only. No gameplay code. Written 2026-09-06 by Claude Fable 5.1
(`claude-fable-5-1`) against `main` at `e2e1b0e` — build `1.3.0`, save schema
v34, last recorded ruling D-31. Every suite number below comes from a fresh
headless run on 2026-09-06; every code claim names the file it was read from._

_This document replaces, in full, a draft written on 2026-09-05 by a session
that was accidentally run on a different model. Nothing from that draft was
carried forward without being re-verified against the code; §4 records what was
kept, corrected, and discarded, and why._

---

## 0. What this document is, and what it answers to

The ClickUp umbrella **ORG-000 — Organized Crime Economy & Territory
Expansion** (`86bbvjgk2`) asks for one deliverable before implementation: the
real dependency graph and a pipeline-safe break-up of nine workstreams. Its
brief is the **Godfather II Crew & Territory Expansion — Integration Readiness
Report** (doc `2kyd583p-4054`, page `2kyd583p-23414`). This document is that
deliverable. It also discharges the required outputs of **ORG-001** (`86bbvjgng`,
Design Debt, status `identified`): rank ladder, authority matrix, migration
map, promotion rules, unlock matrix, relationship to Loyalty/Reputation, UX
implications, regression notes.

### Authority chain, in order

1. **The live repo owns what the code does.** Where any document disagrees
   with the code about shipped behaviour, the code wins and the document is
   stale. §2 records every disagreement found, and §11 lists them as a
   drift register.
2. **Approved pipeline documents own intent.** Three are load-bearing and none
   is restated in the repo:
   - **DD-001 — Organizational Progression / Crew as Capability**
     (`2kyd583p-22394`): greenlit direction, locked rules, non-goals.
   - **FS-001 Revision 2 — Long-Run Crew Progression Spine**
     (`2kyd583p-22414`): the **six-rank spine is already ruled**, with
     loyalty/tenure floors, role proof, organizational footing, "no generic
     Crew XP", "existing Tier 1–3 wages remain active", and "Tier 4+ wages
     rise but never geometric doubling". This is the single most important
     document for the rank work, and the readiness report does not cite it.
   - **DD-002 — Territory Warfare & Rival Dismantling** (`2kyd583p-22574`):
     locked direction rules and non-goals (no RTS, no second currency, no
     capture-every-icon map, one rival before many).
   FS-002 / TI-002 (the territory pipeline) were **reconciled against the game
   as built by D-30**; where TI-002's control-step model differs from what
   shipped (fronts, probes, hold, dismantle), D-30 and the code win.
3. **The readiness report owns the initiative's shape, not current state.**
   It was written without reading the 1.x code. §3 re-assesses it claim by
   claim.
4. **`docs/DECISIONS.md` owns standing rulings.** Latest recorded is D-31;
   **D-32 is the next free number** (verified: zero occurrences in the file).

### What this document does NOT do

It does not authorize implementation, and it does not manufacture owner
rulings. Every `ORG-A#` below is a proposed architecture ruling; every
`ORG-Q#` is an open owner question. The numbering is this document's own and
does **not** continue the prior draft's `ORG-P` / `ORG-R` / `ORG-Q` series,
which are retired (§4).

---

## 1. Working-tree forensics (2026-09-06)

`git status` on `main` (`e2e1b0e`, up to date with `origin/main`): one modified
tracked file, `HANDOFF.md` (mtime 2026-09-05 19:58); one untracked file
relevant to this initiative, `docs/ORGANIZED_CRIME_ECONOMY_DESIGN_PLAN.md`
(created 2026-09-05 20:14, never committed, no git history). The eleven other
untracked `BUILD_*.md` / `FABLE_*.md` files at the repo root are dated
2026-08-23 through 2026-09-03 and are the deliberately-untracked build prompts
this repo has always kept there; they predate the prior session and are not
its work. No stash, no stray branch, no gameplay file modified. The prior
session's claim that it changed no gameplay code and wrote nothing to ClickUp
is consistent with the evidence (no ClickUp comment exists on any ORG task).

One stale process was found: a headless parity runner started Fri 2026-09-04
23:31 (PID 65747) still alive after a day, idle. Parity hangs silently on a
parse error; this one is from a previous session and was left alone. It did
not affect this pass's runs.

---

## 2. Current-state audit (verified 2026-09-06)

### 2.1 Suite floors — fresh headless runs

| Suite | Fresh run | Floor constant | Agrees |
| --- | --- | --- | --- |
| Parity | 14,482 checks, 0 failures | `MIN_CHECKS := 14482` (`tests/parity/parity_runner.gd:22400`) | yes |
| Confrontation | 4,429 checks, 0 failures | `MIN_CHECKS := 4429` (`tests/confrontation/confrontation_runner.gd:80`) | yes |
| Territory | 170 checks, 0 failures | `MIN_CHECKS := 170` (`tests/territory/territory_runner.gd:54`) | yes |
| Dre | 427 checks, 0 failures | `MIN_CHECKS := 427` (`tests/dre/dre_runner.gd:65`) | yes |
| Tips | 93 checks, 0 failures | `MIN_CHECKS := 93` (`tests/tips/tips_runner.gd:20`) | yes |
| Save validation | 284 checks, 0 failures | **no `MIN_CHECKS` constant in the file** | n/a |
| Screen smoke | touch 1,137/1,137 · width 2,764/2,764 · component 52/52 · panel 133/133 | `MIN_UNCOVERED := 0.35` is a legibility ratio, not a count floor | n/a |

All seven logs were grepped for `ERROR:` / `SCRIPT ERROR` / `Invalid access`:
zero hits. Version `1.3.0` (`autoload/version.gd`), `SAVE_VERSION := 34`
(`autoload/save_system.gd:208`), **41** systems registered in `GameManager`,
**17** territory nodes across **4** districts (`data/territory_definitions.gd`),
**56** wander cards (`data/wander_events.gd` `CARDS`), **23** screens.

### 2.2 What exists, by system

**Crew (`systems/crew.gd`, `autoload/game_state.gd:1195–1430`).** Four
recruitable members (Eli RUNNER, Deshawn FIXER/RECRUITER, Pherris CONNECTOR,
Tone ENFORCER/LOOKOUT); `CREW_CAPACITY := 2` behind `crew_capacity()`;
recruiting gated on street rank Known (OG-D2); wage clock with two nights'
grace, loyalty 0–10 starting at 5, departure at 0. `crew_records[id]` carries
`recruited, status (active|departed), loyalty, tier, wage_due,
wage_missed_since, recruited_day, proofs`.

**Crew rank.** `RANK_LABELS` authors six (RECRUIT, PROVEN, TRUSTED, SPECIALIST
LEAD, LIEUTENANT, INNER CIRCLE), `MAX_CREW_RANK := 6`. `CREW_TIER_REQUIREMENTS`
defines **only** `2: {loyalty 7, days 5}` and `3: {loyalty 9, days 12}`, so
`at_top_rank()` is true at 3 and the Crew screen hides PROMOTE there (the
locked "hidden, not disabled" rule). `TIER_WAGES` has three entries for
Deshawn/Tone/Pherris and **no Eli row** (he keeps `wage: 45` at every tier);
`crew_wage_for()` clamps the index to the curve, so a hypothetical rank 4 pays
the rank-3 wage. Effect curves (`TONE_DEFENSE_MULTIPLIER`,
`DESHAWN_HEAT_REDUCTION`) clamp **up** through `curve_value_for_rank`.
**`autoload/save_validator.gd:162` clamps every loaded crew tier to `1..3`** —
a rank-4 record would be repaired down to 3 on the next load. Parity pins
"rank 3 is the top of the authored ladder" in three checks
(`parity_runner.gd:2439–2448`).

**Capabilities.** `GameState.CREW_CAPABILITIES` authors three rows
(`pherris/907list_run_board`, `eli/run_the_bag`, `deshawn/smooth_it_over`);
`crew_operations.gd::OPERATION_CAPABILITY` names six operations. The three
newer ones (`scout_district`, `put_it_down`, `hold_it_down`) have no capability
row. **Runtime impact: none.** `crew_has_capability()` has no caller outside
the parity fixture; `crew_capability_value()` is called by the list, runner and
fixer adapters (which have rows) and by `operation_summary()` for
`max_cycles_by_rank` (falls back to 0 for the others, which is also what Eli's
and Deshawn's rows return). Tone's `put_it_down` reads rank through an
adapter-local `RELIEF_BY_RANK` (`systems/enforcer_adapter.gd:12`);
`hold_it_down` and `scout_district` read rank nowhere. So there are two homes
for one kind of fact. It is a hygiene defect, not a bug, and it is fixed in
Phase 0 because rank-4 scope needs one home.

**Delegation (`systems/crew_operations.gd`).** Six operations, discovery
one-way, morning assignment behind `planning_window_open`, exclusive per
person per day (`crew_unassigned_today`), settled at `day_ending`, adapters
per domain, BR-D6 proposals. `DISCOVERY_REQUIREMENTS` and
`ASSIGNMENT_REQUIREMENTS` gate on `crew_active`, `crew_loyalty_min`,
`payroll_not_delinquent`, `crew_unassigned_today`, `planning_window_open` — and
on **who the person is**, by `crew_id`. **No row anywhere uses
`crew_rank_min`**, although `systems/requirements.gd` evaluates it. Rank moves
numbers (cycles, relief fractions) and confers no scope. That is correct for
ranks 1–3 as FS-001 specified them; it is the gap ranks 4–6 exist to fill.

**Proofs.** `crew_records[id].proofs` ships as `{}` on recruit,
`crew.crew_proofs()` reads it, `requirements.gd` evaluates `proof_flag` and
`proof_counter_min` against it, and **nothing writes a proof**. The vocabulary
exists with no producer.

**Street rank (`data/rank.gd`, OG-D2, TU-D2).** Derived from the observation
ledgers, never persisted; six tiers NOBODY → BOSS at floors 0/3/8/15/25/40;
rows folded by key across ledgers, presence capped. `gs.respect` is gone (zero
references in `game_state.gd`). It gates recruiting (Known), corners (Player),
the board, and the door (Boss) through `rank_min` requirements and
SurfaceVisibility facts.

**Player kit (OG-D3, v30).** `weapon ∈ {hands, knife, piece}`; `WEAPONS` table
with `fight_bonus` 0/0.10/0.22, `heat` 0/0.5/2.5, a room `line`. Read by:
`wander.gd` card facts (`unarmed`, `no_piece`), FIGHT-road odds (`:1692`),
room odds (`:1868`), heat on the draw (`:1465`), `WEAPON_BEAT_LINES` (SA-D2),
`territory.gd:397` contest chance, the Character screen and the Phone
inventory page; repaired by the validator. **Not read by** `stickup.gd`
(header pins `weaponBonus → 0`, "no equipment system"), `boost.gd`,
`corner.gd`, `doorstep.gd`, `retaliation.gd`, `arrest.gd`, or the
confrontation loop. **A booking does not seize it**: `arrest.gd:339–352`
takes product and `hot_goods` only. Booking severity is keyed by family and
tier (`consequence_rules.gd:417–431`); there is no armed row. Acquisition is
two authored wander meetings (`wander_meet_the_knife`, $120, day 6+;
`wander_meet_the_piece`, $600, day 14+) using the card `grants` mechanism.
`vehicle ∈ {"", beater}`, `BEATER_PRICE := 1400`, `trunk` holds product only,
cargo derived on reconcile. No armor, no loadout, no stash beyond the trunk,
no crew or soldier equipment, no confiscation, no evidence.

**Territory (`systems/territory.gd`, `data/territory_definitions.gd`).**
Four districts (`DISTRICT_ORDER`), 17 nodes with `kind` (corner/venue/lot),
`starting_owner` (neutral/curtis), and Ship Creek's `supply_discount` — the one
shipped "holding grants a capability" precedent. Soldiers are a count
(`soldiers_idle` + per-node `soldiers`), capacity `2 + 2/block`, income
`earning × 0.85^i`, nightly heat per held block, `$20/soldier/night` upkeep
(D-1). Curtis blocks are taken through the confrontation loop
(`contest_chance`, pinned in parity); nightly probes at three pinned rates
plus `PROBE_HELD_DOWN`; fronts (HS-D1) pay half and run hotter until three
quiet nights; `hold_it_down` (Tone, a district, a night) and `stand_watch`
(the player, a block, a slot) read at probe time; recovery every fourth night
on the weakest taken block (HS-D3); a district is dismantled after two settles
with every Curtis-start block held and uncontested, and then never probed or
recovered, corners paying `DISMANTLED_INCOME` 1.25. Turf reads all of it in
words (HS-D4). **Drift:** D-28 says a won contest leaves "retaliation queued";
`_take_from_curtis` (`territory.gd:468`) opens a front and posts a soldier and
queues nothing. TI-002's control steps (−2..+2), graph, capability nodes,
Fortify and pressure cases were **not built** as written; D-30 chose the
front/probe/hold model instead. That is the shipped, tested model and this
plan extends it.

**Rival.** `autoload/curtis.gd` keeps awareness (phases with ratcheting
floors), watchers, quiet-streak decay; his THREAT lens in Exposure is
separate; district `rival` ints (`game_state.gd:120–160`) are separate again;
`starting_owner` flags name his blocks. He has **no roster, no named people, no
assets, no income the player can read**. Canon character pages name pressure
points (his girlfriend, Makell as a flip risk) that nothing in the build
carries.

**Businesses.** None as actors. `systems/venues.gd` builds two interiors (the
Gym, the Night Owl). Downtown's "venues" are territory nodes with higher
earning, not owners with allegiance. Job managers (Lani, Marcus, Mina, Sonny,
Denise, Ray, Big Mike) are named employers on the Jobs side and are the
nearest thing to business owners the build has.

**Money, exposure, consequence.** `systems/wallet.gd` keeps
`cash == dirty_cash + clean_cash` with two spend policies and Financial
Pressure; no laundering. Exposure has **five** lenses (Yalonda, Juan, Mina,
Curtis, Dre) and five band floors; `record_observation` will create a ledger
for any id (the dismantle line writes to `goodie`, who has no lens — harmless,
worth knowing). `systems/opportunities.gd` is the offered/accepted/settled
substrate with one reconcile seam in `GameManager.dispatch()`.
`systems/consequence_engine.gd` + `retaliation.gd` are the chain chassis;
`arrest.gd` computes severity, bail, slots, seizure. Crew status is
`active|departed` only: **no availability model** (injured, held, recovering)
exists for named crew; `systems/recovery.gd` is the player's health only.

**Surfaces.** Turf (per-district tabs, words not numbers), Crew (roster, wage
ledger, operations, PROMOTE hidden at the top), People (ledger evidence for
the five lensed NPCs; `NAMES`/`ROLES` tables hard-coded in `people.gd`), Phone
(hub, contacts, threads, bills, inventory — TU-D3). No screen renders a
weapon beyond the kit line.

### 2.3 Test coverage of the surfaces this initiative lands on

`tests/territory/territory_runner.gd` (170 checks) covers FS-002.3-era
behaviour only: claim, abandon, post/pull, capacity, income curve, heat,
Deshawn, save round-trip, v16 migration, upkeep. **Fronts, probes, hold,
recovery, dismantling and the contest are covered in parity**
(`dismantle` 15 mentions, `probe_chance` 11, `hold_it_down` 6,
`curtis_recovers` 6, `stand_watch` 5, `contest_chance` 3), not in the territory
suite. Crew rank has three parity checks and no save-validation check beyond
"tier defaults to 1". This initiative must move the territory and
save-validation suites, not only parity.

---

## 3. The readiness report, claim by claim

Classification key: **exists/reusable** · **extend** · **migrate** ·
**partial** · **missing shared infrastructure** · **new feature** ·
**stale premise**.

| Report claim | Verdict | Evidence |
| --- | --- | --- |
| §2 "Player-held nodes, Curtis start ownership, contested fronts, contested income/Heat, probes, soldiers, personal defense, Tone defense, recovery, district dismantling" | **exists/reusable** | all in `territory.gd`; see §2.2 |
| §2 "Crew progression capable of expanding what a person can be trusted to handle" | **partial** | ranks 1–3 only; 4–6 are labels; validator clamps to 3; no proof producer |
| §2 "Reputation/standing systems", ORG-000 "Respect" | **stale premise** | `gs.respect` deleted in 1.0.0 (OG-D2); the standing system is `data/rank.gd` |
| §3 "no generalized weapon ownership/loadout system" | **extend** (one slot exists and is tuned) | `WEAPONS`, seven read sites; stickup's `weaponBonus` pinned 0 is a pre-cut seam |
| §3 the weapons ticket as "existing ruling" | **stale premise** | `86bbptgp1` is **`shipped`** (2026-09-04) though its "design pass first" never happened; its owner question (opponent stat blocks) was never ruled — re-raised as ORG-Q1 |
| §3 "police/search/arrest consequences for carrying" | **new feature** | `arrest.gd` never reads `weapon`; booking seizes product and hot goods only |
| §3 armor, utility, long gun, named-crew loadout, soldier equipment | **new feature** | nothing exists |
| §4 acquisition channels, scarcity, cleanliness | **partial** | two meeting cards; `hot_goods` already carries `{kind, name, value, heat, from, day}` provenance; `opportunities.gd` is the offer substrate |
| §5 "ranking needs a dedicated restructure" | **stale premise → completion** | the four concepts are already separate in code; FS-001 Rev 2 already rules the six-rank spine; what is missing is reachability, proof producers, one home, and scope |
| §5 player rank determines authority, recruitment ceiling, scope | **missing shared infrastructure, by design** | no player organizational number exists; ORG-A1 rules it stays derived (facts + requirement sets), not a fourth ladder |
| §6 businesses, protection, extortion | **new feature** | none exist; `SETTLE_ORDER` has no businesses step |
| §7 strategic infrastructure | **partial** | `supply_discount` on Ship Creek lots is the shipped precedent; nothing else |
| §8 rival organization structure | **new feature** | Curtis is awareness + flags + cycles; no people or assets |
| §9 dismantling aftermath | **partial** | the end-state exists per district; nothing before or after it |
| §10.A storage/armory | **partial** | trunk (product only); no home stash |
| §10.C availability (injured/arrested/unavailable) | **missing shared infrastructure** | crew status is active/departed only; this is a hidden prerequisite for any equipment that can be lost |
| §10.D soldiers stay aggregate | **exists/reusable** | already a count; keep it (ORG-A5) |
| §10.E upkeep | **exists/reusable** | wages, soldier upkeep, rent, phone |
| §10.F intelligence/discovery | **partial** | three one-way latches, `crew_operation_state.discovered`, `scout_district` returns a district read, `tips.gd` is idle capacity |
| §10.G Turf/Crew/People/Phone as the surfaces | **exists/reusable** | with one caveat: People is hard-coded to five NPCs |
| §11 "Organizational Rank Restructure must be designed first" | **stale premise** | rank blocks lieutenants, equipment permissions and absorption; it does **not** block businesses or sourcing |
| §12 sequence Rank → Weapons → Dealers → Crew equipment → Businesses → Infra → Rivals → Aftermath → Scaling | **partially wrong** | see §7: Phase 0 repair precedes rank; equipment and businesses are parallel; crew capacity (infrastructure) precedes lieutenants |
| §13 "territory/crew work can continue meanwhile" | **exists/reusable** | true, and the parallelism is real |

---

## 4. The prior draft, assessed

The 2026-09-05 draft was read in full, treated as untrusted, and checked
line by line against the code. Disposition:

**Kept after independent verification.** The suite table and the state
numbers (all re-run and re-counted here); the observation that `weapon`,
`proofs`, `requirements.gd`'s vocabulary, the dirty/clean split, the
opportunities substrate, per-district dismantling and the contested-front
economy already exist; the finding that no requirement row uses
`crew_rank_min`; the finding that HANDOFF.md was four builds stale; the
principle that soldiers stay aggregate and businesses are a second axis over
the same board; the `hot_goods` provenance reuse; the idea that a rival
person removes a specific effect the player can already feel.

**Corrected.**
- It called the capability drift "load-bearing" and made it the reason Phase 0
  exists. `crew_has_capability` has no runtime caller; the drift is hygiene.
  Phase 0 still exists, but for the reason it missed: **the validator clamp**
  (`save_validator.gd:162`), which makes every rank-4+ save repair itself back
  to 3 and is the actual blocker.
- It proposed a **non-additive** `weapon → loadout` migration and raised a
  ruling for it. Unnecessary: `weapon` is not retired by adding siblings; the
  repo's "retired truth" rule is about facts that stop being canonical.
  Additive `armor` and `stash` fields keep every reader and the validator
  untouched (§6.2, ORG-A6). The ruling is withdrawn.
- It claimed three **owner rulings** (ORG-R1/R2/R3) as given on 2026-09-05.
  There is no record of them in ClickUp (no comments on any ORG task) and
  this session cannot see the prior conversation. They are **not** treated
  as rulings here. Two of them are moot: FS-001 Revision 2 already rules
  wages at 4+ (its R2) and ranks 1–3 unchanged (its Q8). The player-authority
  question (its R1) is ORG-Q7 below, with a recommendation that is compatible
  with what the draft described.
- It stated crew rank curves and effects were "already separate from street
  rank" as if that closed ORG-001's migration question. It does — but the
  migration map ORG-001 asks for is the validator, the wage curves, the
  parity pins, and the Crew screen's top-rank hiding, none of which it listed.

**Discarded.** Its slice labels and PR shapes; its Command Capacity ladder as
a named authored ladder (ORG-A1 keeps authority derived without a ladder to
read); its statement that the territory suite "did not move" as a standing
obligation phrased around the prior draft's own rule set; its §9 "deliberately
not decided" list (replaced by §12).

---

## 5. Architecture principles, pressure-tested, and the rulings proposed

Each principle from the brief was tested against the code. Agreements are
short; disagreements say why.

| Principle | Verdict |
| --- | --- |
| One canonical owner per fact | **Agree.** It is already the repo's own rule (`territory_definitions.gd` header). Phase 0 applies it to rank curves. |
| Reuse existing systems | **Agree.** Every slice below names the seam it extends. |
| Every gate uses shared requirement infrastructure | **Agree, with one precision.** `requirements.gd` reads facts only; a new gate is a new fact key in the caller's `_facts()` plus a row, never a new evaluator. Per-person capability ownership (`crew_id` in a row) is authored data, not a gate, and stays as it is. |
| Rank primarily confers scope | **Agree.** Ranks 1–3 already confer curve steps and that is shipped and stays; 4–6 confer a new thing the person may do (ORG-A2). |
| Soldiers stay aggregate | **Agree.** The open BLOCK_REMEMBERS review note ("fold soldiers into unnamed crew") is answered the other way here: a per-district readiness word, never per-head records (ORG-A5). |
| Businesses coexist with territory | **Agree.** A business hangs off a node or district and carries allegiance separately from who holds the ground (ORG-A7). |
| Rival people have systemic functions | **Agree.** A name with no effect is a Wikipedia entry (ORG-A8). |
| Turf/Crew/People/Phone stay primary | **Agree, with a hidden cost:** People is a fixed five-row screen; rival people need a data-driven "known people" section, which is a real UI slice, not free. |
| No RTS, no second territory game, no conquest currency | **Agree.** DD-002 non-goals; nothing below adds a map, a unit, or a currency. |
| No Spenard-only architecture | **Agree; mostly already true.** Districts, rival ints, dismantling and probes are per district. The remaining Spenard literals are Curtis's watcher texture and the `curtis_*` field names; new fields in this initiative are keyed by `rival_id` from day one (ORG-A9), the old names are not migrated speculatively. |
| **Where this plan disagrees with the brief** | The readiness report's "rank restructure first" and its strictly linear order. Rank is a completion, not a restructure; equipment and businesses are parallel; and **crew capacity** (`CREW_CAPACITY := 2`) is a prerequisite the report never names — two crew slots cannot hold two specialists and a lieutenant, so multi-district command depends on infrastructure that raises capacity (FS-001 Rev 2: capacity grows through property/base). |

### Proposed architecture rulings

**ORG-A1 — Four ladders, and the player has no fourth number.**

| Ladder | Answers | Lives in | Kind |
| --- | --- | --- | --- |
| Street rank | how the city reads you | `data/rank.gd` | derived from ledgers, never persisted |
| Crew rank (organizational) | how much this person has proven they can carry | `crew_records[id].tier` 1–6 | conferred by the player, with proof |
| Loyalty | can I rely on them right now | `crew_records[id].loyalty` 0–10 | the wage clock |
| Skill / specialisation | what they are good at | roster `role`, `power`, capability rows | authored |

The player's **organizational authority is derived, and is not a ladder**: it
is the organization itself — crew held and at what rank, districts held,
businesses paying, lieutenants standing — read through requirement sets on
facts that already exist (`crew_count_min`, `rank_min`, `district_discovered`,
new `held_in`/`lieutenants_min`/`businesses_min` facts). No persisted player
rank, no new labels (the street rank label already names the player), no
Organization XP. Rationale: OG-D2 rejected a persisted rank once, FS-001 Rev 2
forbids an organization currency, and a third visible ladder is one more thing
a phone screen has to explain. The street rank never gates command; crew rank
never gates how the world reads you.

**ORG-A2 — A rung is a new thing its holder may do.** Ranks 1–3 keep exactly
what they have (FS-001 Rev 2, "retain current pacing"). Every rung above 3 is
justified by scope: 4 works on a **standing brief**, 5 **holds a district**, 6
**acts on judgment**. Effect curves (`TONE_DEFENSE_MULTIPLIER`,
`DESHAWN_HEAT_REDUCTION`, relief fractions, cycles) clamp up at their rank-3
values and do not grow past 3 — FS-001 Rev 2: "pure stat inflation is
insufficient", and its explicit warning not to turn Pherris's four-listing
board into six cycles.

**ORG-A3 — Every new gate is a requirement row.** Promotion, standing briefs,
district command, equipment permission, business actions and defection all
evaluate through `systems/requirements.gd` and return its structured blocker,
so a surface can say "Needs LIEUTENANT, has TRUSTED" or "Needs five boards run,
has two" without bespoke `if`s. `CREW_TIER_REQUIREMENTS` itself becomes a
requirement list per tier (with tiers 2 and 3 expressed as the same
`crew_loyalty_min` + `crew_tenure_days_min` rows they are today, so behaviour
is byte-identical). First consumer of the long-idle `crew_rank_min` type.

**ORG-A4 — Proof is written where the work settles.** Each adapter's `settle()`
increments `crew_records[id].proofs[<operation_id>]` when the night reports
real work (not the "nothing to do" outcome). One counter per operation, keyed
by operation id, no per-role naming to invent. Rank-4 proof for a member is a
`proof_counter_min` row on their own operation. No schema bump: `proofs`
already round-trips inside `crew_records` (the precedent `crew_proofs()`
documents).

**ORG-A5 — Soldiers stay a count, with one word per district.** Named crew
carry identity, loyalty, rank, kit. Soldiers stay `soldiers_idle` and per-node
counts, plus one readiness word per district (UNARMED / ARMED) bought from the
armory as an allocation. Never per-soldier records.

**ORG-A6 — Items are additive to the kit, fungible by type, owned by the
organization.** `weapon` stays the player's carry slot. `armor` joins it as a
sibling string. `armory` is one `item_id → count` dictionary (the
organization's stores, starting as the home stash). A named crew member's kit
is `crew_records[id].kit = {weapon, armor}` (nested, no bump). An item is in
exactly one place — carried, in the armory, on a crew member, or allocated to
a district's soldiers — and moves by assignment, never by copy. Provenance
rides `hot_goods` as it does today: a taken weapon is a hot item until it is
fenced or **kept** (moved into the armory at a heat cost).

**ORG-A7 — A business is a second axis on the same board.** Authored against a
territory node or district; carries `allegiance ∈ {none, player, rival}`,
`pressure`, and an owner who is an Exposure ledger. Holding the ground never
implies the business pays. No new geography, no second map.

**ORG-A8 — Every rival person is a function.** Authored data plus a state
(`active | pressured | held | flipped | gone`), each binding to **one number
the player can already feel** (a district's probe rate, `RECOVERY_EVERY`, his
supply, the police read, the tax card). Removing the person removes the
effect, and Turf says so in words. No autonomous rival AI (DD-002 non-goal).

**ORG-A9 — Rivals are instances from the first line of new data.** New fields
are keyed by `rival_id`; `data/rival_definitions.gd` holds Curtis as the first
entry. The shipped `curtis_*` fields and `starting_owner: "curtis"` are **not**
migrated until a second rival exists (DD-002: one rival who can lose before
many who cannot), and a note in the definitions file says so.

---

## 6. The system design

### 6.1 Organizational rank & authority

**The spine is FS-001 Revision 2's, adopted as ruled**, with the scope each
rung confers made concrete against the code:

| Rank | Label | Promotion gate (FS-001 Rev 2 floors) | Scope conferred | Reuses |
| --- | --- | --- | --- | --- |
| 1 | RECRUIT | recruited | one operation, one day, claimed each morning | shipped |
| 2 | PROVEN | loyalty 7, 5 days | curve step | shipped |
| 3 | TRUSTED | loyalty 9, 12 days | curve step; leads their first delegated operation | shipped |
| 4 | SPECIALIST LEAD | loyalty 8+, ~20–25 days, **Role Proof I** (their own operation's counter) | **standing brief**: their operation renews each morning without the player re-claiming it, until ended, suspended by the assignment gate, or the night reports nothing to do | `crew_assignments` day-keying, `ASSIGNMENT_REQUIREMENTS`, BR-D6 texts |
| 5 | LIEUTENANT | loyalty 9+, ~35–45 days, Role Proof II, **footing**: a block held outside the district they started in | **holds a district** on a standing basis: probes there read `PROBE_HELD_DOWN` every night they stand, soldiers there are theirs to supervise (readiness allocation), one district per lieutenant | generalises `held_down_district()` from one day to a brief; a map, not a string |
| 6 | INNER CIRCLE | loyalty 9+, ~55–70 days, Role Proof III, footing: blocks in two districts | **acts on judgment**: chooses which of their operations to run each morning inside the brief; the rank that can **receive** an absorbed rival (§6.8) | `day_start_ideas` / `accept_idea` |

The day floors are FS-001's pacing floors, "not automatic timers" — proof is
the gate that bites. Wages at 4–6 rise per person and role, authored not
multiplied, never geometric; ranks 1–3 pay exactly what they pay in 1.3.0
(both FS-001 Rev 2 rules, so neither is an owner question). Eli gets a fourth
entry and keeps his flat $45 at 1–3.

**Player authority** per ORG-A1. The readiness report's list maps to facts:
recruitment ceiling → `crew_capacity()` raised by infrastructure (§6.6);
subordinate leaders → count of rank-5 members; district scope → lieutenants
held; extortion scale → businesses paying; absorption → a rank-6 member to
receive them. Turf and Crew already read these; nothing new to persist.

**Promotion with proof** per ORG-A3/A4. `promote_blocker()` evaluates the
tier's requirement list and returns the evaluator's blocker; the Crew screen
prints the `current`/`required` pair in words ("Needs five boards run, has
two") on the existing PROMOTE button. Rank-up keeps its feed line and gains a
text in the member's voice.

**Demotion.** Not needed for ranks 4–6 to ship: a loyalty fall below the
assignment gate already suspends every scope (brief, district) because every
scope is assigned through `ASSIGNMENT_REQUIREMENTS`. Whether rank itself ever
falls is ORG-Q8; the recommendation is that it falls only through authored
organizational consequences (flip, betrayal), never through ordinary loyalty
decline, and that no player "demote" verb ships until one of those producers
exists.

**Absorbed rivals** arrive at the rank their old role earns (that role is the
proof) with loyalty **below** `CREW_LOYALTY_START`; because every operation
gates on `crew_loyalty_min`, a rank-5 defector with loyalty 3 can be held and
paid but not used until earned. No new mechanism.

### 6.2 Weapons, armor, equipment, items

**Verdict: extension, additive.** The one-slot weapon layer is tuned, tested and
read in seven places; nothing about it is replaced.

- **Catalogue.** `WEAPONS` grows into `ITEMS` (one table, a `slot` field:
  `weapon | armor | utility`), with the three weapon rows keeping their exact
  values. `weapon_def()` keeps its signature.
- **Armor.** `armor: String` (`"none" | "vest"`), reducing damage **received**
  in the same lane Tone's `absorbed_damage()` occupies and composed with it,
  not stacked as a second divisor. Carries heat when found on you.
- **Storage.** `armory: Dictionary` (item_id → count) — the home stash and the
  organization's stores in one; a stash property (§6.6) adds a location that a
  checkpoint cannot reach, the way the trunk already is exempt.
- **Where the weapon plugs in, all pre-cut:** `stickup.gd`'s pinned
  `weaponBonus` (firearm 0.12 / other 0.06 in canon), `arrest.gd` severity
  (an ARMED row), booking seizure (weapon joins product and hot goods), the
  checkpoint's STASH IT road (a weapon in the trunk is not on you),
  `consequence_rules.gd` injury bands for armor.
- **Downside, so nothing is a permanent buff:** price, heat on the draw
  (shipped), what a stop finds, worse booking while armed, loss at booking
  (ORG-Q2), loss with a departed crew member unless recovered (ORG-A6).
- **Long gun** deferred: it is the item that most needs ORG-Q1 answered and the
  least needed to prove the model.

**Schema:** one additive bump (`armor`, `armory`), the four-touch discipline.
No migration of `weapon`.

### 6.3 Acquisition & the black market

**No shop button.** A source is a relationship with availability. The
substrate is `systems/opportunities.gd` (offered / accepted / settled, catalogue
preloads, one reconcile seam), which already knows how to put an offer in
front of the player and settle it.

| Channel | Gate | Character |
| --- | --- | --- |
| Street meeting | day + `unarmed` / `no_piece` (shipped cards) | the introduction |
| The dealer (a named source per item class: the Chevron knife man; Dre's cousin for the piece — both already canon) | street rank + a relationship band | reliable, dear, remembers you |
| Fence (907List) | broker tier | cheap, hot, history attached |
| Contact sourcing (Dre) | disposition band | occasional, favour-priced |
| Crew-connected | a member's rank + capability | the gun connection made personal |
| Taken | a rival loss, a stickup drop, a boost | free, hottest, no receipt |

**One truth, two surfaces.** The two shipped meeting cards stay exactly as
authored and become the **first meeting** with the source; afterwards the
source is reachable as a Phone contact whose offers are opportunities. No
migration, no third truth. **Scarcity** is a per-source, per-day seeded
availability read (the market's restock precedent), so "I know a guy" is an
advantage and "he has nothing this week" is a problem. **Legitimate retail**
is not modelled: a knife from a store is not a story this game tells.

### 6.4 Crew equipment & soldier readiness

- **Named crew:** `kit` per member, assigned from the armory, recoverable,
  gated on rank through `crew_rank_min` (an equipment permission is exactly
  the kind of scope a rung confers). A kit changes what the member's operation
  reads: Tone's `absorbed_damage`, contest odds when he leads, the enforcer's
  heat cost; Eli's stop chance; nothing for Pherris and Deshawn beyond safety.
- **Soldiers:** one readiness word per district (ORG-A5), bought as an
  allocation from the armory, degraded by losses on probes, feeding
  `probe_chance` (a lower defended rate) and what a lost block costs.
- **The hidden prerequisite is the availability model.** Without
  `laid_up` / `held` statuses for named crew, kit can never be lost, and kit
  that cannot be lost is a permanent bonus (readiness report §3's own rule).
  The hooks exist: `status` on the record, `crew_active` in every gate (which
  reads `status == "active"` and so suspends every scope for free), `recovery.gd`
  for the cadence, `arrest.gd` for the cause.
- **Allocation is the decision:** stores are finite, the player is one of the
  people who can carry, arming a district is money that did not go to a corner
  (DD-002 pillar 4, satisfied by scarcity, not a slider).

### 6.5 Extortion, protection & businesses

**Data.** `data/business_definitions.gd`: `{id, district, node_id?, name,
kind, owner_id, take, capability?}`. Runtime `businesses[id] = {allegiance,
pressure, since_day}`; the owner is an Exposure ledger with a default
CIVILIAN lens (one authored row each — Exposure's authoring cost for a new
character is "pick an archetype and override a few weights", by design).

**Routes to influence, never one verb:**

| Route | Reuses | Costs |
| --- | --- | --- |
| Pressure | a `consequence_engine` chain kind through the confrontation rooms | heat, the owner's ledger, pressure +1 |
| Protection | a real threat must exist (probes in that district) | a promise: a probe that lands on a protected block costs the arrangement |
| Relationship | the owner's disposition band | time, being seen |
| Buy in | wallet, **clean** money | money and a paper trail |
| Take from the rival | the district's rival state | retaliation |

**Payment** settles nightly as **dirty** cash through a new `businesses`
system in `SETTLE_ORDER` (a registered system with the base
`can_handle`/`handle` pair), which is what makes laundering (§6.6) a want.
**Failure and overpressure:** at pressure 3 an owner closes (nothing for N
nights), calls the police (Heat + District Pressure), goes to the rival
(allegiance flips against you), or resists in a room. **Geography ≠
allegiance:** a Downtown venue node keeps its `earning` as the door; the
business behind it is a separate row (ORG-Q3 asks the owner to confirm this
does not double-pay).

### 6.6 Strategic infrastructure

**Rule: a holding grants one named capability that changes one existing
seam. Never a flat percentage, never a set bonus** (DD-002: discard "named set
bonuses"). The GF2 "break the ring" moment is kept differently — a rival's
capability *is* a business or a person he holds (§6.7), and taking it removes
the effect.

| Holding | Capability | Seam |
| --- | --- | --- |
| Laundering front (laundromat, car wash) | converts dirty to clean at a rate and a risk | `wallet.gd` buckets + Financial Pressure |
| Gun connection | **unlocks** a §6.3 channel; never defines a new one | opportunities catalogue |
| Safehouse / stash property | `crew_capacity()` +1; an armory location a checkpoint cannot reach | `crew_capacity()`, the trunk's exemption |
| Warehouse | carry more; product enters cheaper | `cargo_max`, `supply_discount` (shipped precedent) |
| Mechanic | the beater turns over on cold mornings | `beater_dead_today` |
| Motel | recover without spending a slot | `recovery.gd` |
| Bar / club | buyers, tips | `market_nudges` (v34), `tips.gd` budget |
| Supply route | a cut on a district crossing | `travel.gd` |

**The safehouse is the one that unblocks the initiative:** crew capacity 2 is
the readiness report's unnamed prerequisite for lieutenants (§5).

### 6.7 Rival organizations

`data/rival_definitions.gd` — Curtis as the first instance: `people`
(four to six authored, each `{id, name, role, district, function, state}`),
`assets` (businesses with `allegiance: rival`), `presence` (the district `rival`
ints already shipped). Functions in the grammar the code has:

| Person (example) | Function | Number it owns |
| --- | --- | --- |
| the one who runs the probes | `probe_rate` in a district | `PROBE_*` multiplier there |
| the one who brings people back | `recovery` | `RECOVERY_EVERY` / `RECOVERY_CHANCE` |
| the one who moves supply | `supply` | his Ship Creek staging lot's value; the tax card's frequency |
| the one who pays the police | `police` | the district's police read on stops |
| the collector | `tax` | `wander_curtis_tax` weight |

**Ways to remove a person** reuse verbs the game has: get them booked (a tip
through a contact — costs standing with Curtis when it reaches him), flip
them (their own ledger, STREET archetype), drive them out (a room at their
asset), buy them (clean money), recruit them (defection → a crew slot, which
is why capacity matters). **Discovery** is a fourth one-way latch
(`rival_people_known`), fed by `scout_district` (already returns a district's
rival read), by People (a ledger row is how you learn a name), by Phone tips,
and by `tips.gd`, which is an intel generator sitting mostly idle. **The
fourth axis stays separate:** awareness is how hard his people look;
structure is who they are (`curtis.gd`'s own header separates the first three
on purpose).

### 6.8 Dismantling, surrender & absorption

**Before the end-state**, per district and derived: HOLDING (his blocks and
people intact) → PRESSED (a block or a person gone) → FRACTURING (recovery
suppressed, a business flipped) → OUT (the shipped `curtis_dismantled`). Each
state changes behaviour, not a number: a fracturing district probes less and
recovers slower (DD-002 pillar 3: "feel the rival losing power before the game
declares him finished").

**After**, so that deleting a rival does not delete the content:
- **Defection.** A named person becomes recruitable at their rank with low
  loyalty (§6.1) — the highest-value outcome because it reuses the roster,
  and the one that needs a crew slot.
- **Absorption of soldiers** into the aggregate (payroll follows).
- **Absorption of businesses** with the owner's ledger and resentment intact.
- **Inherited problems**: a dismantled district's police read rises
  (District Pressure); a flipped business carries its heat.
- **The vacuum** is content only with somebody to fill it — a second rival is
  the last thing built, not the first (ORG-Q5).

### 6.9 Multi-district command

A rank-5 lieutenant holding a district is the whole mechanism: `hold_it_down`
generalised from one night to a standing brief, `held_down_district()` from a
string to a map, probes already reading it. **Player attention is the cap**:
districts supervised ≤ lieutenants held ≤ crew capacity; an unsupervised
district is probed at the undefended rate, which is the consequence already
in the code. Turf's district card reads it in words (HS-D4). No new screen.

---

## 7. Dependency graph

```
P0  Foundation repair: validator clamp → MAX_CREW_RANK; capability table total
    (one home); proof producers at settlement; tests on the thin suites   [no ruling]
 │
 ├─→ P1  Rank 4 reachable (requirement lists per tier, proof I, wages at 4,
 │       standing briefs, crew_rank_min's first use)                        [defaults pre-answered]
 │     │
 │     ├─→ P2  Crew availability model (laid_up / held; crew_active suspends
 │     │       every scope for free)                                         [ORG-Q6]
 │     │     │
 │     │     ├─→ P3  Item model: ITEMS, armor, armory, weapon reads extended
 │     │     │       to stickup / arrest / seizure / checkpoint (v35)         [ORG-Q1, ORG-Q2]
 │     │     │     └─→ P4  Sources: dealers as opportunities, introductions
 │     │     │            from the shipped cards, scarcity
 │     │     │            └─→ P5  Crew kit + soldier readiness
 │     │     │
 │     │     └─→ P10 Lieutenants / district command (rank 5) — also needs P7
 │     │
 │     └─→ P9  Aftermath: defection at rank, absorption, inherited problems
 │            (needs P8, and a crew slot from P7)                              [ORG-Q5]
 │
 └─→ P6  Businesses: definitions, allegiance, pressure, protection, nightly
         settlement step, owner ledgers                                       [ORG-Q3]
       └─→ P7  Infrastructure capabilities (laundering, gun connection → P4,
              **safehouse → crew capacity**, warehouse, motel, bar)
              └─→ P8  Rival personnel, functions, discovery latch, People rows
```

**Critical path:** P0 → P1, then two genuinely parallel branches — equipment
(P2 → P3 → P4 → P5) and business (P6 → P7). P8 needs P6 (assets) and P0
(scout). P9 needs P8 and a crew slot (P7). P10 needs P1, P2 and P7.

**Hidden prerequisites the readiness report missed:**
1. The validator clamp (`save_validator.gd:162`) — no rank above 3 survives a
   load.
2. `CREW_CAPACITY := 2` — lieutenants at scale need property first.
3. The availability model — before any kit can be lost.
4. People's hard-coded roster — rival people need a data-driven section.
5. `SETTLE_ORDER` has no businesses step; a new registered system needs the
   base handler pair.
6. Parity pins "rank 3 is the top" — the test moves before the rank does.
7. The territory suite does not cover HS-D1..D3 — this initiative lands there.
8. `curtis_*` persisted names — new data keyed by `rival_id`, old names left.

**Schema map:** P1 none (nested keys, precedent `proofs`); P2 none (a status
string already persisted); P3 v35 additive (`armor`, `armory`); P4 none
(opportunities are persisted instances); P5 none (nested `kit`, per-district
readiness in a persisted dict — one bump if a new top-level dict is preferred);
P6 v36 additive (`businesses`); P7 none; P8 v37 additive (`rival_people_known`,
per-person state); P9 none; P10 none (a brief on `crew_assignments`).

---

## 8. Phased build plan

Slices are sized the way 0.2.0 → 1.3.0 shipped: one ruling family per build,
a fixed PR order, each PR green and merged before the next, floors set from a
fresh run at every PR, additive bumps only. Every slice below carries the same
fields; later slices are lighter on numbers because they are specified against
phases that have not happened.

### P0 — "One home" (foundation repair)

- **Player-facing purpose.** None visible. The ladder stops lying about
  itself and a promotion can be earned by work.
- **Technical purpose.** Make ranks 4–6 *representable*; make rank curves live
  in one place; give the proof vocabulary a producer.
- **Prerequisites.** None. The only slice with none.
- **Reused.** `curve_value_for_rank`, `crew_capability_value`, every adapter's
  `settle()`, `crew_proofs()`.
- **Extended.** `save_validator.gd` (`clampi(tier, 1, MAX_CREW_RANK)`);
  `GameState.CREW_CAPABILITIES` (+3 rows: `eli/scout_district`,
  `tone/put_it_down` carrying `relief_by_rank [3.0, 4.0, 5.0]`,
  `tone/hold_it_down`); `enforcer_adapter.gd` reads the curve through the
  table; five adapters write `proofs[<operation_id>]`.
- **New shared infrastructure.** None; this slice removes a second home.
- **Owner rulings.** None. Defects.
- **Save/schema.** None. **Migration risk:** low; moving a curve must produce
  byte-identical values (asserted).
- **Economy impact.** None.
- **UI.** None required (the Crew screen may read a counter as a word later).
- **Tests that must move.** Save validation: tier 4 survives, 9 clamps to 6.
  Parity: `fs001` capability fixture stays green (`eli/territory_operations`
  and `deshawn/network_operations` remain burned ids); one arm proves
  `RELIEF_BY_RANK` through the table equals the old constants; proof counters
  increment at settlement and read through `proof_counter_min`. Territory:
  first arms for `hold_it_down` and `put_it_down` at each rank (the suite has
  never covered HS-D2).
- **Acceptance.** A rank-6 record round-trips; every shipped effect value is
  unchanged; every operation has a capability row; at least one proof per
  member increments on a driven run.
- **Non-goals.** Anything reading rank for scope.
- **Deferred.** Everything below.

### P1 — "Room to move up" (rank 4, standing briefs)

- **Player-facing purpose.** A trusted crew member who has done the work can
  be made SPECIALIST LEAD, and then you stop assigning them every morning.
- **Technical purpose.** Requirement lists per tier; `crew_rank_min` in use;
  a standing brief on `crew_assignments`; wages at 4.
- **Prerequisites.** P0.
- **Reused.** `requirements.gd`, `ASSIGNMENT_REQUIREMENTS`, `_assign`,
  BR-D6 texts, `economy-metrics` in parity for wage measurement.
- **Extended.** `CREW_TIER_REQUIREMENTS` → lists (2/3 byte-identical, 4 with
  `crew_loyalty_min 8`, `crew_tenure_days_min 20`, and a per-member
  `proof_counter_min` on their primary operation); `TIER_WAGES` fourth entries
  (Eli `[45, 45, 45, x]`); `promote_blocker` through the evaluator; a
  `DAY_START_ORDER` step that renews briefs; Crew screen STANDING chip and END
  BRIEF; the settlement text cadence for a standing operation (feed nightly,
  phone only on change — TU-D3's uncluttered phone is a standing rule).
- **New shared infrastructure.** The brief shape
  `{operation_id, params, spend_limit, since_day}`.
- **Owner rulings.** None blocking; four defaults pre-answered in the build
  prompt (rank-4 scope = brief; wage bounds; proof thresholds; 5–6 stay hidden).
- **Save/schema.** None (nested key on a persisted dictionary; precedent
  `proofs`, callback flags). The validator's `crew_assignments` arm, if any,
  must leave unknown keys alone — verify.
- **Migration risk.** Medium: `curve_value_for_rank` clamps up, so every
  three-entry curve silently pays rank 4 the rank-3 value — audit all of them;
  wages are the one curve that must *not* clamp.
- **Economy impact.** Recurring: a rank-4 wage. Measured on driven runs and
  reported, per 86bbjkccu's standing "report, do not tune other levers".
- **UI.** Crew (PROMOTE blocker in words; STANDING; END BRIEF); Phone (rank-up
  text; brief texts on change only).
- **Tests that must move.** Parity: the three "rank 3 is the top" checks move
  to 4; a rank-4 promotion arm; a brief that renews, suspends on a loyalty fall,
  resumes, ends; wage curves at every rank. Smoke: Crew at 375 with a rank-4
  member and a brief. Save validation: a brief round-trips.
- **Acceptance.** Rank 4 reachable by all four through their own work; ranks
  1–3 pay and behave exactly as 1.3.0; a brief runs three mornings unattended
  and stops when the gate says so.
- **Non-goals.** Ranks 5–6 (hidden, not signposted, until their scope exists);
  demotion; kit.

### P2 — Availability

- **Purpose.** A named crew member can be laid up or held, and everything
  they were doing stops.
- **Prerequisites.** P1 (a brief is the first thing worth suspending).
- **Reused.** `status`, `crew_active` in every gate, `recovery.gd` cadence,
  `arrest.gd` causes, `retaliation.gd` for the how.
- **Extended.** `status ∈ {active, laid_up, held, departed}` + `until_day`;
  producers: a lost probe with Tone holding, a failed put-it-down, a booking
  reached through a crew call.
- **Rulings.** ORG-Q6 (no death; recommended).
- **Schema.** None. **Tests.** Parity, territory, save validation (status
  values). **Acceptance.** A held member's brief suspends and resumes.

### P3 — The item model

Additive v35 (`armor`, `armory`), `ITEMS` with `slot`, weapon read by stickup
(un-pin `weaponBonus`), arrest severity ARMED row, booking seizes the weapon
(ORG-Q2), checkpoint STASH IT covers the trunk, armor composed with
`absorbed_damage`. Confrontation suite (4,429) is the guard. Blocked by ORG-Q1
for armor, ORG-Q2 for seizure; the catalogue and armory are not blocked.

### P4 — Sources

Dealers as opportunity definitions with seeded availability; the two cards as
introductions; a Phone contact per source. No schema. Needs P3.

### P5 — Crew kit and soldier readiness

`kit` per member (rank-gated), per-district readiness word, probe rates read
it, losses degrade it. Needs P2, P3, P4.

### P6 — Businesses

Definitions, runtime rows (v36), owner ledgers, four routes, a `businesses`
settle step, overpressure outcomes, Turf rows under the district. Parallel to
P3. Blocked by ORG-Q3 on the venue-node question only.

### P7 — Infrastructure

Capabilities as one-seam effects; **safehouse raises `crew_capacity()`**;
laundering through the wallet; gun connection unlocks a P4 channel. Needs P6.

### P8 — Rival personnel

`rival_definitions.gd`, functions bound to shipped numbers, states, a fourth
discovery latch (v37), People's known-people rows, `scout_district` feeds it.
Needs P6 (assets), P0.

### P9 — Aftermath

Defection at rank with low loyalty (needs a slot from P7), absorption, the
per-district operational word before OUT, inherited police attention. Second
rival deferred (ORG-Q5).

### P10 — District command

Rank 5 as a standing hold, `held_down_district()` → map, attention cap in
words, rank 6 as judgment. Needs P1, P2, P7.

**Standing obligations for every slice:** the suite that covers the surface
moves (territory and save validation, not only parity); no new screens; every
gate is a requirement row; additive bumps only, one per build; floors from a
fresh run at every PR; copy in the Power register.

---

## 9. Owner questions (the true remaining set)

Questions the prior draft carried that are **answered by authority and
removed**: Eli's curve at 1–3 (FS-001 Rev 2: Tier 1–3 wages unchanged);
wages at 4+ (FS-001 Rev 2: rise, per person, never geometric); whether a
non-additive weapon migration is acceptable (withdrawn — none is proposed).

**ORG-Q1 — Do opponents get stat blocks, or stay odds+damage rows?**
*Plain English:* when armor and a long gun exist, does the other side get
hit points and a count, or stay authored rows of odds and injury bands?
*Options:* (a) stay rows — armor reduces damage received, weapons move odds,
the multi-round room already gives fights duration; (b) stat blocks — a new
resolver shape. *Consequences:* (a) keeps D-13 universality, the 4,429-check
suite and every authored room; (b) is a combat engine (`86bbptgp1`'s
"no new combat engine" constraint, SQ-D11). *Recommendation:* **(a)**. *Raised
by the owner on `86bbptgp1` 2026-08-29, never ruled.* **Blocks:** P3's armor,
P5's soldier readiness numbers.

**ORG-Q2 — Does a booking take the weapon, and is being armed a worse
booking?** *Plain:* TU-D4 made jail "take what is on you" for product and hot
goods; the piece stays in the coat today. *Options:* (a) yes, seized, and an
ARMED severity row (more bail, more slots); (b) seized, same severity; (c) not
seized. *Consequences:* (a) makes the piece a real liability and is what the
weapons ticket asked for; it also changes a 1.0.0 balance the owner tuned
(`piece` at $600 and 2.5 heat). *Recommendation:* **(a)**. **Blocks:** P3.

**ORG-Q3 — Venue nodes and businesses: does a Downtown venue node keep its
`earning` when a business is authored behind it?** *Options:* (a) yes, the
node earns as the door, the business pays separately for protection; (b) the
business replaces the node's earning. *Consequences:* (a) is additive and
keeps 0.9.0's tuning; (b) is a migration of Downtown's economy.
*Recommendation:* **(a)**. **Blocks:** P6.

**ORG-Q4 — Which comes first after P1: equipment (P2–P5) or businesses
(P6–P7)?** They are parallel. Equipment is the readiness report's stated
priority; businesses are the larger missing *gameplay* layer, need no ruling
beyond Q3, and unblock crew capacity. *Recommendation:* **businesses first**
(P6 → P7), because the safehouse is on the critical path to lieutenants and
because a business is content the player meets on day one of a build, where a
vest is not. **Blocks:** the 1.5.0 prompt only.

**ORG-Q5 — Does a second rival organization exist in this initiative?**
DD-002 defers multiple factions; the vacuum needs somebody to fill it.
*Recommendation:* **deferred past P9**; Curtis stays the instance, data keyed by
`rival_id` from now. **Blocks:** P9's vacuum content only.

**ORG-Q6 — Can a named crew member die?** Readiness report §11 lists
permadeath as "if desired". *Options:* (a) no — laid up, held, departed;
(b) yes. *Consequences:* (b) deletes authored content and four-person roster
math. *Recommendation:* **(a)**. **Blocks:** P2's status set.

**ORG-Q7 — Does the player get a visible organizational title distinct from
street rank?** *Recommendation:* **no** (ORG-A1); the street rank label is the
player's name in the city, and the organization is read on Turf and Crew.
The prior session's "Command Capacity" description, if it was an owner
ruling, is compatible with ORG-A1 as long as no persisted number and no third
label ships; please confirm which. **Blocks:** nothing now; P10's Turf copy.

**ORG-Q8 — Can crew rank ever fall?** *Options:* (a) never; (b) only through
authored consequences (flip, betrayal); (c) also by the player's choice.
*Recommendation:* **(b)**, with no player verb until a producer exists.
**Blocks:** P9.

**ORG-Q9 — Is the safehouse (crew capacity +1) allowed to precede
lieutenants?** *Plain:* rank 5 needs a third crew slot to mean anything.
*Recommendation:* **yes**, P7 before P10. **Blocks:** the order of 1.6.0+.

---

## 10. Recommended next build — 1.4.0 "Room to Move Up"

**P0 + P1**, four PRs, ruling family **D-32**, version **1.4.0** (MINOR: a
new reachable rank and standing briefs are new player-facing behaviour).
Prompt: `BUILD_ROOM_TO_MOVE_UP_PROMPT.md` at the repo root, with its owner
addendum `BUILD_ROOM_TO_MOVE_UP_ADDENDUM.md`. Schema does not move; the
validator does. The territory and save-validation floors move for the first
time since 0.6.0 / 1.3.0.

**Owner rulings, 2026-09-06 (approved in chat, recorded as D-32 with PR 1):**
all five pre-answered defaults approved; promotion proofs approved as
role-specific evidence that a person has demonstrated the responsibility of
their position, required in addition to loyalty and tenure, **never a generic
XP system**; the listed thresholds are **starting targets**, to be tuned
through playtesting so each member needs roughly comparable effort and
meaningful experience relative to how often their operation can be run. With
that, 1.4.0 moved from proposed to in progress the same day.

Why this and not equipment: it is the only slice with no prerequisite, it
fixes a defect (the clamp) that would silently eat any later rank work, it
touches the thinnest-covered surfaces with the suites that cover them, and
every later phase cites its requirement-list shape.

---

## 11. Documentation drift register

| Where | Says | Truth | Action |
| --- | --- | --- | --- |
| `HANDOFF.md` (committed) | 0.9.0 numbers | 1.3.0 | amended in the working tree by the prior session; every number re-verified here; Crew row corrected (see §4) |
| `systems/crew.gd` header | "all four are recruitable from Day 1" | `recruit_blocker` gates on Known (OG-D2) | fix in 1.4.0 PR 1 |
| `data/territory_definitions.gd` header | "the connector is unauthenticated" | it is authenticated | fix in 1.4.0 PR 1 |
| `docs/DECISIONS.md` D-28 | contest win leaves "retaliation queued" | `_take_from_curtis` queues nothing | one-line correction in 1.4.0 close-out |
| ClickUp ORG-000 description | "Existing Heat, Exposure, **Respect**…" | Respect deleted in 1.0.0; the system is Rank | corrected 2026-09-06 (this pass) |
| ClickUp `86bbptgp1` | `shipped` | its design pass never happened; ORG-002 calls it canonical | comment left; status left to the owner |
| ClickUp "Current Godot Build State" (`2kyd583p-21514`) | 1.2.0, parity 14,263 | 1.3.0, 14,482 | ClickUp Brain sync page; not edited here |
| FS-002 / TI-002 | Respect rewards, control steps −2..+2, Fortify | D-30 reconciled to fronts/probes/hold | historical; cited as intent only |

---

## 12. What this plan deliberately does not decide

Any number above rank 4 (wages at 5–6, item prices, extortion takes,
readiness costs); the item catalogue's contents beyond the three shipped rows
and a vest; the names of Curtis's people and which district each stands in;
which district gets businesses first; the second rival; the exact proof
thresholds (bounded in the build prompt, measured by the implementer); and
anything about a Nile gambling floor, which is a build of its own.

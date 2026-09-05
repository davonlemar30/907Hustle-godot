extends RefCounted
## The Wander card registry — what is out there when you go and look.
##
## `SCRIPTS` is read for exactly one authored row: `STASH_IT` (0.5.0 PR B),
## Q4's own action for a police stop while carrying product — authored
## there, never wired to a caller until now. Referencing it rather than
## re-authoring its label/copy is the same "one owner" discipline this file
## already applies to Pressure's own bands elsewhere in the codebase.
const SCRIPTS := preload("res://data/confrontation_scripts.gd")
##
## ## What Wander is, from the oracle
##
## The web build's changelog (v1.3, PR #59) has it exactly:
##
##     Explore Spenard restructured into category menu (Jobs, Wander, Contacts)
##     Seeded job discovery system: Wash & Go (guaranteed first wander), Night
##     Owl, Delivery, Ship Creek Freight with ramped probability (30% base, +10%
##     per miss, cap 70%, one discovery per wander)
##     Narrative breadcrumbs on missed discovery rolls
##
## and the design decision beside it:
##
##     Flat probability rejected in favor of ramped rolls with breadcrumbs to
##     prevent long droughts while keeping neighborhoods explorable indefinitely
##
## A later build promoted Wander out of its submenu to the Explore Spenard root
## when Contacts moved to the Phone. Separately the web build carries a
## STORY_REGISTRY of 60 event cards with `isEligible()` / `getWeight()` gating.
##
## ## What this file is
##
## The registry half. `systems/wander.gd` owns the ramp and the draw; this owns
## the cards and nothing else — it is pure data with no state handle, the same
## shape `data/consequence_rules.gd` has.
##
## ## The card record
##
## Every card carries the same keys, so a reader never has to ask which kind it
## is holding before it can look at it:
##
##   id            unique, stable, and written into the save as "seen"
##   kind          one of the four below
##   weight        relative draw weight within the eligible pool
##   districts     [] means anywhere; otherwise district ids
##   slots         [] means any time; otherwise indices into TimeSystem.SLOTS
##   requirements  requirement records, evaluated by `systems/requirements.gd`
##   once          true if seeing it once is the whole of it
##   line          what the activity feed says
##
## plus a payload keyed by kind. **`requirements` is the ONLY gate language.**
## There is deliberately no second eligibility engine anywhere in this build —
## `systems/requirements.gd` fails closed on a type it does not know, so a typo
## in a card record hides that card rather than shipping it ungated.
##
## ## The four kinds
##
## AMBIENT      something happened. A line in the feed, sometimes a text. No
##              choice, no cost, no roll. This is the Curtis-watcher shape
##              generalised past Curtis.
## DISCOVERY    you found something that is now on your map. Handled by the
##              RAMP rather than by weight — see `WanderSystem`.
## OPPORTUNITY  something is on the table. It lands immediately and in your
##              favour: found money, a name, a price somebody let slip.
## ENCOUNTER    somebody is in front of you. Opens a real blocking chain through
##              the consequence engine with authored choices and shown odds —
##              the same machinery a blown lift uses, and deliberately the same,
##              because the web build made that call too ("reusing EncounterModal
##              — no new UI shell").
##
## ## The verb triad (SQ-D6, 0.6.0)
##
## Every ENCOUNTER card offers all three ROLES. A role is the structural
## position a choice occupies; the LABEL is what that position says in this
## card's voice, and the two are deliberately not the same thing:
##
##   fight      the CONTESTED road. The one the player chooses to take a roll
##              on, that can go well or badly on their own answer. On a corner
##              that is fists (STAND THERE, SWING); at a cruiser window it is
##              your mouth (TALK TO THEM). The role names the position, not
##              the act — that is the whole point of having roles at all.
##   run        the AVOIDING road, also rolled. Keep moving, do not engage,
##              get past it. It works until it does not.
##   surrender  the GUARANTEED out. Always deterministic, always present, and
##              it always costs something real — cash, cargo, or standing.
##
## `surrender` being a declared role rather than a per-card habit is how "one
## guaranteed out per round" stops depending on an author remembering. The
## suite asserts every card declares all three and that its `surrender` road is
## in `deterministic` — see `tests/confrontation/confrontation_runner.gd`.
##
## Extra roads beyond the triad are allowed and carry no role: `stash_it` on
## the police stop is one action added under its own condition, not a fourth
## structural position. Path-specific scripts (the Lift, the corner, the
## meetup, Stickup's rooms) keep their own authored vocabularies entirely —
## the triad is the general street's rule, not the whole game's.

const ROLE_FIGHT := "fight"
const ROLE_RUN := "run"
const ROLE_SURRENDER := "surrender"
const ROLES: Array[String] = [ROLE_FIGHT, ROLE_RUN, ROLE_SURRENDER]

## BB-D8 (0.7.0): the fourth road, where money is the point. Optional per
## card -- the triad above is the rule, this is a road a card MAY add -- and
## never the guaranteed out: it is deterministic (a price is not a roll) but
## it is blocked when the wallet cannot cover it, which a guaranteed out never
## is. Drug Lord 2 makes bribe a standing verb; here it is a verb the
## situation earns, on four cards, at a stated price.
const ROLE_PAY := "pay"
const OPTIONAL_ROLES: Array[String] = [ROLE_PAY]

## ## Observations (SQ-D8, 0.6.0)
##
## Every encounter writes one, on RESOLUTION, keyed by the road taken and the
## tier reached, at the district it happened in. A card may author its own row
## (`observation: {npc, type, event}` on the encounter payload, optionally
## per-role under `observations`); a card that authors none falls back to
## `OBSERVATION_FALLBACK` below rather than writing nothing, which is what
## makes the rule hold for cards nobody has written yet.
##
## Curtis is the fallback listener because his is the build's one THREAT lens
## and the only one that reads the street directly — defiance, submission,
## violence and territory are all his vocabulary. A card whose observation
## genuinely belongs to somebody else says so in its own row.
const OBSERVATION_NPC := "curtis"

## Role x tier -> the shape written when a card authors nothing. Tiers are the
## resolver's four plus `deterministic`; `surrender` only ever reaches the last
## one, because a deterministic road is never rolled.
const OBSERVATION_FALLBACK := {
	ROLE_FIGHT: {
		"clean": {"type": "defiance", "event": "held_the_block"},
		"messy": {"type": "violence", "event": "street_fight"},
		"failure": {"type": "violence", "event": "street_fight"},
		"catastrophic": {"type": "violence", "event": "street_fight"},
	},
	ROLE_RUN: {
		"clean": {"type": "discretion", "event": "walked_it_off"},
		"messy": {"type": "discretion", "event": "walked_it_off"},
		"failure": {"type": "heat_exposure", "event": "caught_in_the_open"},
		"catastrophic": {"type": "heat_exposure", "event": "caught_in_the_open"},
	},
	ROLE_SURRENDER: {
		"deterministic": {"type": "submission", "event": "gave_it_up"},
		"clean": {"type": "submission", "event": "gave_it_up"},
		"messy": {"type": "submission", "event": "gave_it_up"},
		"failure": {"type": "submission", "event": "gave_it_up"},
		"catastrophic": {"type": "submission", "event": "gave_it_up"},
	},
	ROLE_PAY: {
		"deterministic": {"type": "financial", "event": "paid_to_be_left_alone"},
	},
}

## The authored row for one (card, choice, tier), or the fallback shape.
## `roles` is the card's own choice_id -> role map; a choice with no role (the
## conditional extras) resolves through the role its card names for it in
## `observations`, and writes nothing only if the card names neither.
static func observation_for(card: Dictionary, choice_id: String, tier: String) -> Dictionary:
	var encounter: Dictionary = card.get("encounter", {})
	var authored: Dictionary = encounter.get("observations", {})
	if authored.has(choice_id):
		var per_choice: Dictionary = authored[choice_id]
		# A row may be flat (one shape for every tier) or keyed by tier.
		if per_choice.has(tier):
			return (per_choice[tier] as Dictionary).duplicate()
		if per_choice.has("type"):
			return per_choice.duplicate()
		return {}
	var role := role_of(card, choice_id)
	if role.is_empty():
		return {}
	var by_tier: Dictionary = OBSERVATION_FALLBACK.get(role, {})
	var row: Variant = by_tier.get(tier)
	return (row as Dictionary).duplicate() if row is Dictionary else {}

## The role one choice fills on this card, at the door OR inside its room.
##
## A room's verbs are declared per BEAT rather than on the card — SWING is the
## fight road of three different situations and each one prices it its own way
## — so a lookup that only read the card's own `roles` would find nothing for
## every road the room offers, and the observation for a fight that took three
## rounds would be the one road in the build that wrote nothing. Beats are
## searched after the card so a card-level declaration always wins.
static func role_of(card: Dictionary, choice_id: String) -> String:
	var encounter: Dictionary = card.get("encounter", {})
	var at_the_door := str((encounter.get("roles", {}) as Dictionary).get(choice_id, ""))
	if not at_the_door.is_empty():
		return at_the_door
	for beat in ((encounter.get("room", {}) as Dictionary).get("beats", []) as Array):
		var role := str(((beat as Dictionary).get("roles", {}) as Dictionary)
			.get(choice_id, ""))
		if not role.is_empty():
			return role
	return ""

## Which crew calls a card admits (SQ-D9). Declared per card as
## `admits_crew: true` on the encounter payload; the calls themselves and their
## availability rules live in `data/confrontation_scripts.gd::CREW_CALLS`.
static func admits_crew(card: Dictionary) -> bool:
	return bool((card.get("encounter", {}) as Dictionary).get("admits_crew", false))

## Every role this card declares, choice_id -> role.
static func roles_of(card: Dictionary) -> Dictionary:
	return (card.get("encounter", {}) as Dictionary).get("roles", {})

## The one choice id filling `role` on this card, or "" if it declares none.
static func choice_for_role(card: Dictionary, role: String) -> String:
	for choice_id in roles_of(card).keys():
		if str(roles_of(card)[choice_id]) == role:
			return str(choice_id)
	return ""

## The three intents (batch 13).
##
## Wander shipped as one button, and the measurement said what that made it:
## 89.5 walks over 31 days, three a day every day, 11 cards of which 7 were
## ungated flavour, and a correct play of "press it with every spare slot". It
## paid 307% of the day job and contained no decision at all.
##
## An intent is the decision. The pool does not change — the WEIGHTING does, and
## so does what a find can be. Same slot, same draw, three different questions:
##
##   WORK  who is hiring, and who knows somebody
##   DEAL  what is worth buying, lifting or moving
##   READ  what is going on around here — the one that is not about getting
##         something, but about knowing something
##
## READ exists because the build hides an enormous amount from the player and
## has no surface that tells them: which families a corner is hot for, whether
## Curtis's people have started looking, what a product is fetching in a
## district they are not standing in. Walking the block is how a person finds
## that out, and it gives Wander a job that does not run out — discovery does,
## after two finds, usually in week one.
const INTENT_WORK := "work"
const INTENT_DEAL := "deal"
const INTENT_READ := "read"
const INTENTS: Array[String] = [INTENT_WORK, INTENT_DEAL, INTENT_READ]

## What each button says, and the line under it.
const INTENT_COPY := {
	INTENT_WORK: {"label": "LOOK FOR WORK",
		"line": "Ask around. Somebody is always short a shift."},
	INTENT_DEAL: {"label": "LOOK FOR A DEAL",
		"line": "See what is moving, and what is loose."},
	INTENT_READ: {"label": "SEE WHO IS OUT",
		"line": "Stand around long enough to read the block."},
}

## How much a card's weight is multiplied when it matches the intent, and when
## it does not. A non-match is damped rather than excluded: an intent should
## steer the walk, not put blinkers on it — you can still get jumped while you
## are out looking for work.
const INTENT_MATCH := 4.0
const INTENT_MISS := 0.4

# --- the day's third walk is not the first (batch 13) -------------------------
#
# The other half of what the measurement found. Three walks a day were worth
# exactly as much as each other, which is why the optimal play was to take all
# of them. An hour on the block is worth something; the third hour on the same
# block on the same day is worth much less, and the arithmetic should say so.
#
# Applied to the discovery roll and to what an opportunity pays. Never to
# whether a card is drawn at all — a walk still always produces something, which
# is the oracle's breadcrumb rule and the reason a wander is never a dead slot.
const EFFORT_BY_WALK: Array[float] = [1.0, 0.6, 0.25]
const EFFORT_FLOOR := 0.1

## What this walk is worth, given how many have already happened today.
static func effort_for(walks_today: int) -> float:
	if walks_today < 0:
		return 1.0
	if walks_today < EFFORT_BY_WALK.size():
		return EFFORT_BY_WALK[walks_today]
	return EFFORT_FLOOR

const KIND_AMBIENT := "ambient"
const KIND_OPPORTUNITY := "opportunity"
const KIND_ENCOUNTER := "encounter"
## WS-D1 (0.8.0): the city reveals itself. A MEETING is an encounter-shaped
## card (same `encounter` block, same chain, same roads) with one extra fact:
## playing it DISCOVERS a hustle. Meetings do not compete with the pool or
## with the gate -- an eligible one is the walk, first, because the whole
## point is that the world shows you the thing on the day it is ready to.
## Once each, and gated on the hustle still being unknown.
const KIND_MEETING := "meeting"
## A card whose whole payload is telling you something true. See INTENT_READ.
const KIND_READ := "read"

const SPENARD := "north_star_lot"
const DOWNTOWN := "downtown"
const SHIP_CREEK := "airport_industrial"
const MOUNTAIN_VIEW := "mountain_view"

## Slot indices, matching `TimeSystem.SLOTS`. Named so a card reads as a time of
## day rather than as an integer somebody has to go and look up.
const MORNING := 0
const AFTERNOON := 1
const EVENING := 2
const NIGHT := 3

# --- the ramp ----------------------------------------------------------------
#
# Straight from the oracle. Every number here is the web build's, and the
# comment above says where they came from.

const DISCOVERY_BASE := 0.30
const DISCOVERY_PER_MISS := 0.10
const DISCOVERY_CAP := 0.70

## How many misses it takes to reach the cap, derived rather than written down
## so the two can never disagree.
##
## The live path and the save validator BOTH need this number and shipped with
## only the validator holding it: `wander_misses` climbed without bound in play
## while the validator clamped it on load, so an honest save at five misses
## silently changed value and reported a repair it had not earned. One owner
## now, read by both.
static func miss_ceiling() -> int:
	return int(ceil((DISCOVERY_CAP - DISCOVERY_BASE) / DISCOVERY_PER_MISS))

## What a wander can put on your map, in the order it is offered.
##
## Jobs first and deliberately: `juan_warehouse` and `ship_creek` have been in
## `gs.jobs` since the port began — priced, slotted, and the two best-paying
## shifts in the game at $70-95 and $110-140 against the starters' $40-60 — with
## NOTHING in the codebase able to add them to `jobs_discovered`. Batch 7 made
## the Night Owl findable by putting it behind its own counter. These two had no
## door at all, and this is the one the web build built for them.
## WS-D1 (0.8.0): every job but the one Yalonda vouches for is found by
## walking, one at a time. The ramp picks which, seeded.
const DISCOVERY_JOBS: Array[String] = ["spenard_chevron", "rebel_convenience",
	"northern_value", "day_labor", "juan_warehouse", "ship_creek"]

## Breadcrumbs, by how many times you have come back empty.
##
## The oracle's "narrative breadcrumbs on missed discovery rolls", and the
## reason they escalate rather than repeat: the ramp is real, and a player who
## can feel it getting warmer will keep looking. Told a number they would be
## doing arithmetic; told the same line four times they would stop reading it.
const BREADCRUMBS: Array[String] = [
	"Nothing doing. A man outside the laundromat nods like he half knows you.",
	"Nothing again — but the dock gate on the far side of the lot was open, and it usually is not.",
	"Somebody at the bus shelter is talking about who is hiring. They stop when you get close.",
	"Third time out. The same face keeps turning up, and this time it looks back.",
]

# --- STR-D1/D2: the interruption gate (0.5.0 PR A) --------------------------
#
# The owner's ruling, verbatim: "I should not be able to continuously hit the
# walk-around button on the Home screen indefinitely. Events should happen
# that force the player to do something." Before this, `wander_shakedown`
# and `wander_stopped_on_foot` were two ordinary cards in the pool above,
# competing against ~14 ambient/read/opportunity cards at flat weights that
# read nothing about the player — a player at BURNING Heat with three
# districts HOT drew from the same gentle deck as a clean day-one kid. This
# is the table that replaces "flat weight" with "reads the player."
#
# Owned here rather than in `data/consequence_rules.gd`: this gate is
# Wander's own draw-time decision (WHETHER a walk gets interrupted at all),
# not a cross-system consequence rule anything else reads — `EFFORT_BY_WALK`
# and `DISCOVERY_BASE` above are this file's own precedent for "a number that
# shapes one system's own draw lives with that draw," and Pressure's family
# table stays exactly what it is, a fact this gate READS rather than owns.
#
# The four inputs are each banded 0-3 by their OWNING system's own existing
# vocabulary — Heat's four bands, Pressure's four bands (already numbered by
# `ConsequenceEngine.pressure_steps()`), Curtis's four phases — plus a flat
# bonus for any overdue debt, since STR-D2 names "any overdue debt" as its
# own threshold condition rather than a graduated one. `systems/wander.gd`
# does the reading; this is only the arithmetic once the steps are counted.
#
# Base and cap are new, authored numbers, not measured yet — MEAS-D1's own
# job is to measure them against the five-profile table and report honestly,
# the same discipline PRESS-D1 just went through for District Pressure's own
# cap. Chosen for a cold player (0 steps, every signal quiet) to land near
# the floor — "near-silent," STR-D2's own words — and a maximally hot one (a
# BURNING/HOT/approaching player also carrying overdue debt, 3+3+3+3 = 12
# steps) to approach the ceiling without guaranteeing an encounter on every
# single walk; the guarantee is the streak cap below, not this roll.
## BB-D9 (0.7.0): 0.03 -> 0.10. At three percent a clean day-one player met
## the street on 2.83 of 30 walks (0.6.0's own measurement), and a walk costs
## one of four daily slots -- a player who walked twice a day saw the best
## system in the game once every five days. The hot profile's guarantees
## (`QUIET_STREAK_CAPS` below) are untouched.
const GATE_BASE_CHANCE := 0.10
const GATE_PER_STEP_CHANCE := 0.05
const GATE_CAP := 0.60
## Flat step bonus for "any overdue debt" — sized to match the top of any one
## graduated signal's own 0-3 scale, so a debt problem alone reads as
## seriously as being at BURNING Heat or a HOT district, per STR-D2's own
## framing of the three conditions as equally weighted alternatives.
const GATE_OVERDUE_STEPS := 3

## The quiet-streak cap, by total attention steps — STR-D2's "the Nth walk
## forces the gate open," N authored per band, small. Checked highest
## threshold first. Zero steps (the cold, clean, paid-up player) matches no
## row at all, which is what "no cap" means here: `wander.gd` reads an empty
## match as "let the streak run," so early-game wandering keeps its current
## gentleness exactly as STR-D2 asks.
##
## The lowest row fires the moment ANY single signal leaves its own floor
## (one step is reachable from Heat's NOTICED band alone, Pressure's KNOWN
## band alone, or Curtis's AMBIENT phase alone) — "elevated Heat band" in the
## ruling's own text is not "BURNING specifically," so the cap has to start
## working before a player is already at the top of every scale at once.
const QUIET_STREAK_CAPS: Array[Dictionary] = [
	{"min_steps": 6, "cap": 2},
	{"min_steps": 3, "cap": 3},
	{"min_steps": 1, "cap": 5},
	# BB-D9: the cold row. A clean player used to have NO cap at all -- the
	# streak could climb forever -- and now cannot walk more than eight quiet
	# walks running. Last, because rows are matched top-down and this one
	# matches everybody.
	{"min_steps": 0, "cap": 8},
]

## BB-D9: a run's first encounter is forced open no later than this walk,
## when the pool has anything in it. The first day should show the player
## what a walk can cost; four walks is one day.
const FIRST_ENCOUNTER_BY_WALK := 4

## The chance this walk's gate opens, given the total attention steps
## `wander.gd` has already counted. Clamped at the authored floor and
## ceiling — never truly zero (every walk rolls, per STR-D1), never a
## guarantee (the streak cap is what guarantees, not this number).
static func gate_chance(total_steps: int) -> float:
	return gate_chance_from(GATE_BASE_CHANCE, total_steps)

## The same curve from a caller's own floor. BB-D9 raised the WANDER floor;
## the checkpoint (`data/travel_events.gd`) keeps the old one, because a
## district crossing is not a walk -- arbitrage is built entirely out of
## crossings and a tripled checkpoint rate cut it from 158% of the day job
## to 47% on parity's own sweep. The per-step climb and the ceiling are
## shared; only the floor is the caller's.
static func gate_chance_from(base: float, total_steps: int) -> float:
	return clampf(base + GATE_PER_STEP_CHANCE * float(maxi(0, total_steps)),
		base, GATE_CAP)

## The streak cap for this many steps, or -1 for "no cap" (steps at or below
## every authored row's floor). -1 rather than 0 so a caller can never
## mistake "uncapped" for "the very next walk forces it."
static func quiet_streak_cap(total_steps: int) -> int:
	for row in QUIET_STREAK_CAPS:
		if total_steps >= int((row as Dictionary)["min_steps"]):
			return int((row as Dictionary)["cap"])
	return -1

## How much an encounter card's weight is boosted when its own `gate_bias` tag
## (a pressure family name, or the literal `"debt"`) matches what actually
## caused the gate to open this walk — PR A item 2's "a debt-driven opening
## prefers the debt-flavored script, a pressure-driven one prefers the
## recognition scripts." A card with no tag, or a tag that does not match
## today's cause, draws at its own authored weight, unboosted — this is a
## thumb on the scale, not a filter; the untagged legacy cards below are
## still fully eligible every time the gate opens.
const GATE_BIAS_MATCH := 3.0

# --- the cards ---------------------------------------------------------------

const CARDS: Array[Dictionary] = [
	# --- ambient: the block, and being in it ---------------------------------
	{
		"id": "spenard_cold_snap", "kind": KIND_AMBIENT, "weight": 10,
		"intents": [INTENT_READ],
		"districts": [SPENARD], "slots": [], "requirements": [], "once": false,
		"line": "Cold enough that the snow squeaks. Nobody is out who does not have to be.",
	},
	{
		"id": "spenard_lot_kids", "kind": KIND_AMBIENT, "weight": 8,
		"intents": [INTENT_READ],
		"districts": [SPENARD], "slots": [AFTERNOON, EVENING], "requirements": [], "once": false,
		"line": "Kids cutting through the lot with a sled and no coats. One of them says your name and keeps running.",
	},
	{
		"id": "downtown_shift_change", "kind": KIND_AMBIENT, "weight": 10,
		"intents": [INTENT_WORK, INTENT_READ],
		"districts": [DOWNTOWN], "slots": [AFTERNOON, EVENING], "requirements": [], "once": false,
		"line": "Fourth Avenue at shift change. Everybody walking somewhere, nobody looking up.",
	},
	{
		"id": "ship_creek_yards", "kind": KIND_AMBIENT, "weight": 10,
		"intents": [INTENT_WORK, INTENT_READ],
		"districts": [SHIP_CREEK], "slots": [], "requirements": [], "once": false,
		"line": "Diesel and salt off the yards. A container door bangs somewhere behind the fence.",
	},
	{
		"id": "wander_carrying_heavy", "kind": KIND_AMBIENT, "weight": 14,
		"intents": [INTENT_DEAL],
		"districts": [], "slots": [], "once": false,
		# Only when there is something to be careful with. `collection_non_empty`
		# is an existing requirement type; this needed no new gate.
		"requirements": [{"type": "collection_non_empty", "collection": "inventory"}],
		"line": "You take the long way round with the bag. It is heavier when you are thinking about it.",
	},
	{
		"id": "wander_pocket_heavy", "kind": KIND_AMBIENT, "weight": 8,
		"intents": [INTENT_DEAL],
		"districts": [], "slots": [], "once": false,
		# `86bbjnh0x`: `carrying_dirty` is minted in `WanderSystem.facts()`
		# (`gs.dirty_cash > 0`) and no card gated on it -- a dead fact. Same
		# family as `wander_carrying_heavy` (product), one door down: cash
		# on hand is its own kind of visible, and the street-stop precedent
		# already treats dirty money as street-visible for exactly this
		# reason (STR-D3).
		"requirements": [{"type": "fact_true", "fact": "carrying_dirty"}],
		"line": "You keep a hand near the pocket without meaning to. That much cash has a way of announcing itself.",
	},
	{
		"id": "wander_every_car", "kind": KIND_AMBIENT, "weight": 8,
		"intents": [INTENT_READ],
		"districts": [], "slots": [], "once": false,
		# `86bbjnh0x`: `heat_burning` is minted in `WanderSystem.facts()`
		# (Heat's own worst band) and no card gated on it -- a dead fact.
		# BURNING already forces the interruption gate's own ceiling
		# (STR-D1); this is the ambient beat for the walks it doesn't.
		"requirements": [{"type": "fact_true", "fact": "heat_burning"}],
		"line": "Every car that slows down might be nothing. You stopped believing that a while ago.",
	},

	# --- ambient: people you actually know -----------------------------------
	{
		"id": "wander_yalonda_porch", "kind": KIND_AMBIENT, "weight": 9,
		"intents": [INTENT_READ],
		"districts": [SPENARD], "slots": [MORNING, AFTERNOON], "requirements": [], "once": false,
		"line": "Yalonda is out on the step with a coffee. She asks if you are eating. You say yes.",
		"observation": {"npc": "yalonda", "type": "presence", "event": "seen_around",
			"source": "household"},
	},
	{
		"id": "wander_juan_truck", "kind": KIND_AMBIENT, "weight": 9,
		"intents": [INTENT_WORK, INTENT_READ],
		"districts": [SPENARD], "slots": [MORNING, AFTERNOON, EVENING], "requirements": [], "once": false,
		"line": "Juan has the hood up on the truck again. He does not need help and says so twice.",
		"observation": {"npc": "juan", "type": "presence", "event": "seen_around",
			"source": "neighborhood"},
	},

	# --- opportunity: small, immediate, in your favour ------------------------
	{
		"id": "wander_found_cash", "kind": KIND_OPPORTUNITY, "weight": 6,
		"intents": [INTENT_DEAL],
		"districts": [], "slots": [], "requirements": [],
		# `86bbjnh0x`: the `once` key was read by `eligible_cards()`/
		# `eligible_encounters()` and set by nothing -- a dead branch. This is
		# the one card whose own fiction actually asks for it: a specific
		# lucky find at a specific pump island reads as a one-time thing, not
		# a spot that keeps paying out for the rest of the run.
		"once": true,
		"line": "Folded bills in the slush by the pump island. Nobody is coming back for it.",
		"grant": {"cash": [8, 25], "clean": false},
	},
	{
		"id": "wander_price_overheard", "kind": KIND_OPPORTUNITY, "weight": 8,
		"intents": [INTENT_DEAL],
		"districts": [], "slots": [], "once": false,
		# Only worth anything to somebody who can act on it: the phone is what
		# carries a price you are not standing in front of (batch 5).
		"requirements": [{"type": "fact_true", "fact": "phone_active"}],
		"line": "Two guys at the counter talking numbers, loud, like nobody else is in the room.",
		"grant": {"intel": true},
	},

	# --- read: what an hour on the block tells you ---------------------------
	#
	# These are the reason READ exists. Each one reports live state the build
	# already tracks and has NO surface for, through the read API that owns it.
	# Nothing here mutates; a report is a report.
	{
		"id": "read_the_corner", "kind": KIND_READ, "weight": 14,
		"intents": [INTENT_READ],
		"districts": [], "slots": [], "requirements": [], "once": false,
		"line": "You give it an hour and watch who watches back.",
		"read": "pressure",
	},
	{
		"id": "read_the_heat", "kind": KIND_READ, "weight": 10,
		"intents": [INTENT_READ],
		"districts": [], "slots": [], "once": false,
		"requirements": [{"type": "fact_true", "fact": "heat_noticed"}],
		"line": "You count how many times somebody looks twice.",
		"read": "heat",
	},
	{
		"id": "read_the_watchers", "kind": KIND_READ, "weight": 12,
		"intents": [INTENT_READ],
		"districts": [SPENARD], "slots": [], "once": false,
		"requirements": [{"type": "fact_true", "fact": "curtis_visible"}],
		"line": "The same car has been parked wrong for two days.",
		"read": "curtis",
	},
	{
		"id": "read_the_board", "kind": KIND_READ, "weight": 12,
		"intents": [INTENT_READ, INTENT_DEAL],
		"districts": [], "slots": [], "once": false,
		"requirements": [{"type": "fact_true", "fact": "phone_active"}],
		"line": "Two people at the counter talking numbers, and neither of them quietly.",
		"read": "prices",
	},
	{
		"id": "read_the_crew", "kind": KIND_READ, "weight": 10,
		"intents": [INTENT_READ],
		"districts": [], "slots": [], "once": false,
		"requirements": [{"type": "crew_count_min", "min": 1}],
		"line": "You run into one of yours, and they have things to say.",
		"read": "crew",
	},

	# --- encounter: somebody is in front of you -------------------------------
	#
	# These open a real blocking chain. Odds are shown before the player commits,
	# because the build's rule is that a risk they cannot see is not a decision.
	#
	# STR-D3 (0.5.0 PR B), the "luggage" rule: every encounter's own `effects`
	# table below is authored per choice, per tier, and read generically by
	# `WanderSystem.resolve_consequence()` rather than the one hardcoded
	# tier→outcome match this file shipped with through PR A — that match
	# could not tell a mugging from a charisma test, and STR-D3 asks each
	# script to put its own stakes on the table. `cash_fraction` reads DIRTY
	# only, through the same Wallet seam the street-stop precedent already
	# uses (clean, documented money is not street-visible); `goods_fraction`
	# is `_lose_cargo`'s own fraction argument, unchanged. `escalate: true`
	# on a (choice, tier) pair means this roll does not resolve on its own —
	# it opens the room (`_open_shakedown_room`) instead of applying an
	# effect at all, so an escalating row's own health/cash/goods fields are
	# left at zero: the room's own effects are what actually lands.
	{
		"id": "wander_shakedown", "kind": KIND_ENCOUNTER, "weight": 7,
		"intents": [INTENT_DEAL], "gate_bias": "stick",
		"districts": [], "slots": [EVENING, NIGHT], "once": false,
		"requirements": [{"type": "day_min", "min": 4}, {"type": "collection_non_empty", "collection": "inventory"}],
		"line": "Two guys peel off the wall and box you in. One wants your bag. The other is watching for cops.",
		"encounter": {
			"definition_id": "wander_shakedown",
			"opponent": "Two off the wall",
			"shape": "confrontation",
			"choices": ["stand", "walk", "pay_them", "hand_over"],
			# SQ-D6. This card already offered all three positions; the roles
			# make that structural instead of coincidental. BB-D8 adds the
			# fourth at the door only -- once the room opens there is no
			# price on it.
			"roles": {"stand": ROLE_FIGHT, "walk": ROLE_RUN,
				"pay_them": ROLE_PAY, "hand_over": ROLE_SURRENDER},
			# SQ-D9: two of them on a corner is exactly the situation Tone's
			# own terms describe -- he is told when something has already
			# started, not aimed at something you are starting.
			"admits_crew": true,
			"deterministic": ["pay_them", "hand_over"],
			"base": {"stand": 0.45, "walk": 0.60},
			"observations": {
				"pay_them": {"type": "financial", "event": "paid_to_be_left_alone"},
			},
			# STAND is the fight verb (STR-D5): clean settles it on the spot —
			# they decide you are not worth it — anything else is the fight not
			# ending here, so it escalates into the room instead of resolving.
			# WALK is the run, priced exactly as DL2's own reference: "you lose
			# them in the streets — BUT all your money and drugs were in your
			# luggage." Clean gets away with everything; every other tier costs
			# a rising share of what was in hand, because losing them and
			# losing the bag are two different rolls in real life and one roll
			# here.
			"effects": {
				"stand": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"escalate": true},
					"failure": {"escalate": true},
					"catastrophic": {"escalate": true},
				},
				"walk": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.25, "goods_fraction": 0.25},
					"failure": {"health": 3, "cash_fraction": 0.5, "goods_fraction": 0.5},
					"catastrophic": {"health": 8, "cash_fraction": 1.0, "goods_fraction": 1.0},
				},
				"hand_over": {
					"deterministic": {"health": 0, "cash_fraction": 1.0, "goods_fraction": 1.0},
				},
				# BB-D8: a flat price, from either bucket, and nothing else.
				"pay_them": {
					"deterministic": {"health": 0, "cash_flat": 60, "goods_fraction": 0.0},
				},
			},
			# --- SQ-D7: the room, as three authored beats ---------------------
			#
			# 0.5.0 shipped this room as ONE verb re-rolled at `base - 0.10 x
			# round` with generic per-round log copy. That is a re-roll at worse
			# odds, not a new situation, and it is exactly what the chassis's
			# round rule forbids -- `data/confrontation_scripts.gd`'s own header
			# has said so since the loop was written ("a script whose stages
			# read the same is a script with too many stages").
			#
			# Three beats, each a different fight: they close the distance, then
			# somebody else joins, then the door is behind you. Each authors its
			# own situation, its own offered roads, its own numbers and its own
			# exit table. Odds still worsen across the room -- that is honest,
			# a fight you are still in after two rounds IS going worse -- but
			# the decay rides on top of a beat that changed, rather than being
			# the only thing that changed.
			#
			# `banked` is health taken so far and carried to whichever exit ends
			# it, unchanged from 0.5.0. `left` is bodies, not rounds: beat two
			# adds one, which is what "somebody else joins" costs.
			"room": {
				"cap": 3,
				"left_label": "IN YOUR WAY",
				"beats": [
					{
						"beat": "They close the distance before you have finished deciding. One of them is already inside arm's reach and the other has stopped talking.",
						"log": "It does not end there. The first one steps in.",
						"left": 2,
						"choices": ["swing", "break_for_it", "give_it_up"],
						"roles": {"swing": ROLE_FIGHT, "break_for_it": ROLE_RUN,
							"give_it_up": ROLE_SURRENDER},
						"deterministic": ["give_it_up"],
						"base": {"swing": 0.52, "break_for_it": 0.55},
						"banked": 3,
						"effects": {
							"swing": {
								"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
								"messy": {"escalate": true},
								"failure": {"escalate": true},
								"catastrophic": {"health": 12, "cash_fraction": 1.0, "goods_fraction": 1.0},
							},
							"break_for_it": {
								"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
								"messy": {"health": 2, "cash_fraction": 0.25, "goods_fraction": 0.25},
								"failure": {"escalate": true},
								"catastrophic": {"health": 10, "cash_fraction": 1.0, "goods_fraction": 1.0},
							},
							"give_it_up": {
								"deterministic": {"health": 0, "cash_fraction": 1.0, "goods_fraction": 1.0},
							},
						},
					},
					{
						"beat": "A third one comes off the wall behind you, unhurried, and now the two in front of you are not in a hurry either. Nobody here needs this to be quick.",
						"log": "Somebody else joins. That is three.",
						"left": 3,
						"choices": ["swing", "break_for_it", "give_it_up"],
						"roles": {"swing": ROLE_FIGHT, "break_for_it": ROLE_RUN,
							"give_it_up": ROLE_SURRENDER},
						"deterministic": ["give_it_up"],
						# Three of them: swinging is worse, and running is worse
						# than swinging because somebody is behind you now.
						"base": {"swing": 0.38, "break_for_it": 0.30},
						"banked": 4,
						"effects": {
							"swing": {
								"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
								"messy": {"escalate": true},
								"failure": {"escalate": true},
								"catastrophic": {"health": 14, "cash_fraction": 1.0, "goods_fraction": 1.0},
							},
							"break_for_it": {
								"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
								"messy": {"health": 4, "cash_fraction": 0.5, "goods_fraction": 0.5},
								"failure": {"escalate": true},
								"catastrophic": {"health": 12, "cash_fraction": 1.0, "goods_fraction": 1.0},
							},
							"give_it_up": {
								"deterministic": {"health": 0, "cash_fraction": 1.0, "goods_fraction": 1.0},
							},
						},
					},
					{
						"beat": "You have your back against a door that does not open from this side. There is no third round after this one and everybody standing here knows it.",
						"log": "The door is behind you. This is the last of it.",
						"left": 3,
						# The last beat drops the run: there is nowhere to run TO,
						# and offering a road that the situation has already closed
						# is the kind of lie the round rule exists to stop. The
						# guaranteed out stays, which is the rule that matters.
						"choices": ["swing", "give_it_up"],
						"roles": {"swing": ROLE_FIGHT, "give_it_up": ROLE_SURRENDER},
						"deterministic": ["give_it_up"],
						"base": {"swing": 0.44},
						"banked": 0,
						"effects": {
							"swing": {
								"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
								# Nothing escalates out of the last beat: `messy`
								# and `failure` are terminal here, priced between
								# a clean win and the catastrophe.
								"messy": {"health": 5, "cash_fraction": 0.25, "goods_fraction": 0.25},
								"failure": {"health": 9, "cash_fraction": 0.5, "goods_fraction": 0.5},
								"catastrophic": {"health": 15, "cash_fraction": 1.0, "goods_fraction": 1.0},
							},
							"give_it_up": {
								"deterministic": {"health": 0, "cash_fraction": 1.0, "goods_fraction": 1.0},
							},
						},
					},
				],
			},
		},
	},
	{
		"id": "wander_stopped_on_foot", "kind": KIND_ENCOUNTER, "weight": 9,
		"answers_back": false,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		# Only when you are already carrying enough attention to be worth
		# stopping. Reuses batch 8's WATCHED floor rather than inventing a
		# second idea of "hot".
		"requirements": [{"type": "fact_true", "fact": "heat_watched"}],
		"line": "A cruiser slows to your walking pace and stays there for half a block.",
		"encounter": {
			"definition_id": "wander_stopped_on_foot",
			"opponent": "The cruiser",
			"shape": "negotiation",
			# STASH IT (0.5.0 PR B) reactivates `SCRIPTS.STASH_IT`, authored in
			# Q4 and never wired to a caller — its own header already says what
			# it is: "one action added to the existing police-stop script when
			# inventory > 0". `WanderSystem` offers it exactly under that
			# condition rather than baking it into `choices` unconditionally, so
			# an empty-handed stop still reads as the two-choice encounter it
			# always was. The WATCHED floor this card already gates on is
			# untouched by any of this — carrying product only ever ADDS a
			# third road, never changes what makes the stop happen at all.
			#
			# SQ-D6, the missing out. This card shipped in 0.5.0 with
			# `"deterministic": []` -- two rolled roads and no guaranteed one,
			# which breaks the chassis rule outright. HANDS OUT is that road:
			# you end it on their terms. It is deterministic, it costs, and it
			# is not free -- a stop that ends with your product in an evidence
			# bag is still a stop that ended.
			#
			# No crew call here (SQ-D9): Tone standing next to you does not end
			# a police stop, it adds a second person in cuffs.
			# BB-D8: the one police card that takes money, because this is the
			# one cop who is alone with you. It costs Heat as well as cash -- a
			# cop who takes money remembers who paid.
			"choices": ["talk", "keep_walking", "slip_him_something", "hands_out"],
			"roles": {"talk": ROLE_FIGHT, "keep_walking": ROLE_RUN,
				"slip_him_something": ROLE_PAY, "hands_out": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["slip_him_something", "hands_out"],
			"base": {"talk": 0.62, "keep_walking": 0.48},
			# A police stop is not a corner beef, and the roles' generic
			# fallback would write `violence` for a road that is entirely
			# verbal. Authored per road instead.
			"observations": {
				"talk": {"type": "heat_exposure", "event": "stopped_and_questioned"},
				"keep_walking": {
					"clean": {"type": "discretion", "event": "walked_past_a_stop"},
					"messy": {"type": "discretion", "event": "walked_past_a_stop"},
					"failure": {"type": "heat_exposure", "event": "searched_on_the_street"},
					"catastrophic": {"type": "heat_exposure", "event": "searched_on_the_street"},
				},
				"hands_out": {"type": "submission", "event": "searched_on_the_street"},
				"slip_him_something": {"type": "heat_exposure", "event": "bribed_a_cop"},
				"stash_it": {
					"clean": {"type": "discretion", "event": "carried_clean_through"},
					"failure": {"type": "heat_exposure", "event": "searched_on_the_street"},
				},
			},
			"effects": {
				# HANDS OUT: the search happens and it finds what is on you.
				# Cheaper than a failed KEEP WALKING because nothing escalated,
				# and it takes no health at all -- nobody hit anybody.
				"hands_out": {
					"deterministic": {"health": 0, "cash_fraction": 0.0,
						"goods_fraction": 1.0, "heat": 0.5},
				},
				"slip_him_something": {
					"deterministic": {"health": 0, "cash_flat": 80, "goods_fraction": 0.0,
						"heat": 1.0},
				},
				"talk": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.25},
					"catastrophic": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.5},
				},
				"keep_walking": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.5},
					"catastrophic": {"health": 12, "cash_fraction": 0.0, "goods_fraction": 1.0},
				},
				# Two keys only — `WanderSystem._stash_it_tier()` rolls a
				# direct success/failure the same shape STASH_IT's own
				# authored row always was, never a four-tier resolver split,
				# so "messy"/"catastrophic" would be dead rows here. Success
				# hides the product from THIS stop's own search entirely —
				# the stop still happened, but nothing carried was ever on
				# the table. Failure mirrors KEEP_WALKING's own worst-case
				# cost exactly, plus the authored +0.5 Heat STASH_IT's own
				# header prices for getting watched doing it.
				"stash_it": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 12, "cash_fraction": 0.0, "goods_fraction": 1.0,
						"heat": 0.5},
				},
			},
		},
	},

	# --- STR-D1 PR B: two new encounters, the roster deepening -----------------

	{
		"id": "wander_curtis_tax", "kind": KIND_ENCOUNTER, "weight": 6,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		# Curtis-side, gated on his own awareness climbing past ambient —
		# reuses the phase read `facts()` already exposes for `heat_watched`'s
		# own neighbour rather than inventing a second awareness scale.
		"requirements": [{"type": "fact_true", "fact": "curtis_watching_or_worse"}],
		"line": "Somebody who works the block for Curtis falls in beside you. He wants a cut of what you made here, and he has a number.",
		"encounter": {
			"definition_id": "wander_curtis_tax",
			"opponent": "Curtis's man",
			"shape": "negotiation",
			# SQ-D6. PAY IT was already the guaranteed out; PUSH BACK was
			# already the contested road. What this card never had was the
			# third position -- the answer that is neither paying nor arguing.
			# KEEP YOUR PACE is it: you do not stop, you do not answer, and you
			# find out whether that was allowed.
			"choices": ["push_back", "keep_pace", "pay_it"],
			"roles": {"push_back": ROLE_FIGHT, "keep_pace": ROLE_RUN,
				"pay_it": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["pay_it"],
			"base": {"push_back": 0.42, "keep_pace": 0.50},
			# Curtis's own ledger, both directions, the same shape
			# `corner_push` authors in `confrontation_scripts.gd`.
			"observations": {
				"push_back": {
					"clean": {"type": "defiance", "event": "refused_the_tax"},
					"messy": {"type": "defiance", "event": "refused_the_tax"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				"keep_pace": {
					"clean": {"type": "defiance", "event": "walked_past_the_tax"},
					"messy": {"type": "defiance", "event": "walked_past_the_tax"},
					"failure": {"type": "submission", "event": "paid_the_tax"},
					"catastrophic": {"type": "submission", "event": "paid_the_tax"},
				},
				"pay_it": {"type": "submission", "event": "paid_the_tax"},
			},
			"effects": {
				# Walking past costs nothing when it works, and costs the toll
				# plus interest when it does not -- the price of having made
				# him ask twice.
				"keep_pace": {
					"clean": {"health": 0, "cash_flat": 0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_flat": 40, "goods_fraction": 0.0},
					"failure": {"health": 2, "cash_flat": 60, "goods_fraction": 0.0},
					"catastrophic": {"health": 6, "cash_flat": 80, "goods_fraction": 0.0},
				},
				# The known price. A flat toll rather than a percentage — the
				# number is what buys the corner's patience, not a cut of
				# anything specific being carried.
				"pay_it": {
					"deterministic": {"health": 0, "cash_flat": 40, "goods_fraction": 0.0},
				},
				"push_back": {
					"clean": {"health": 0, "cash_flat": 0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_flat": 40, "goods_fraction": 0.0},
					"failure": {"health": 5, "cash_flat": 60, "goods_fraction": 0.0},
					"catastrophic": {"health": 10, "cash_flat": 80, "goods_fraction": 0.25},
				},
			},
		},
	},
	{
		"id": "wander_young_ones", "kind": KIND_ENCOUNTER, "weight": 8,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		"requirements": [{"type": "day_max", "max": 4}],
		"line": "Three of them on the wall outside the Rebel, none of them older than nineteen, and all three watching the new face walk past like it is the only thing happening on the block. It is.",
		"encounter": {
			"definition_id": "wander_young_ones",
			"opponent": "The three on the wall",
			"shape": "negotiation",
			# The low-stakes test the roster's own floor names: the cheap
			# answer is composure, and composure is genuinely cheap — a clean
			# HOLD STEADY costs nothing at all. STARE BACK is the higher
			# variance answer for a player who wants respect out of it instead
			# of just an uneventful walk; nothing here can cost more than a
			# bruise, because sizing somebody up is not yet a fight.
			#
			# SQ-D6, the second missing out. This card also shipped with
			# `"deterministic": []`. CROSS THE STREET is the deterministic
			# walk-past: nothing physical happens and nothing is taken, and it
			# still costs -- you have shown them the block is theirs, and
			# Curtis's ledger keeps that.
			"choices": ["stare_back", "hold_steady", "cross_the_street"],
			"roles": {"stare_back": ROLE_FIGHT, "hold_steady": ROLE_RUN,
				"cross_the_street": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["cross_the_street"],
			"base": {"hold_steady": 0.70, "stare_back": 0.50},
			"observations": {
				"stare_back": {
					"clean": {"type": "defiance", "event": "held_the_block"},
					"messy": {"type": "defiance", "event": "held_the_block"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				"hold_steady": {
					"clean": {"type": "discretion", "event": "walked_it_off"},
					"messy": {"type": "discretion", "event": "walked_it_off"},
					"failure": {"type": "discretion", "event": "walked_it_off"},
					# The only bruise this card can leave, and it is one.
					"catastrophic": {"type": "violence", "event": "caught_from_behind"},
				},
				"cross_the_street": {"type": "submission", "event": "ceded_the_corner"},
			},
			"effects": {
				# Costs nothing a meter reads. What it costs is in the ledger.
				"cross_the_street": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
				"hold_steady": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 2, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
				"stare_back": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 2, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 6, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
	# --- 0.6.0 PR C: the everyday street (POOL-D1, SQ-D6..D8, VOX-D1) --------
	#
	# 0.5.0 left the encounter pool a skeleton: four cards, of which two were
	# Curtis-shaped and one needed WATCHED Heat to fire at all. What was
	# missing is the ordinary -- the stops that happen to people who are not
	# doing anything in particular, the addicts who are not a plot, and the
	# blocks that decide you are the wrong person to be standing on them.
	#
	# Eight cards below, in three families the owner named:
	#
	#   POLICE      the vehicle search and the warrant check. The on-foot
	#               stop already ships (`wander_stopped_on_foot`) and is NOT
	#               duplicated -- it is the first of the three.
	#   ADDICTS     the desperate approach and the lot-side confrontation.
	#               The hard case for VOX-D1: desperation is not comedy and
	#               not pity, and the register holds.
	#   GENERAL     wrong place wrong time, mistaken identity, the beef the
	#               block picks, and the one that is somebody else's problem
	#               until you answer it.
	#
	# **Arrest, and the seam left obvious.** Wander has never booked one --
	# `resolve_consequence`'s own header says why: "somebody on a corner is
	# not a crime the player committed", and the two chains that DO reach
	# custody both open off an action the player chose to take. The police
	# cards are the first plausible exception and it is the owner's ruling to
	# make. Until it is made they ship as ruled-as-specified: **seizure and
	# Heat are the worst road, no custody**, and `arrest_risks` stays empty on
	# every one of them. The seam is `open_chain`'s own `arrest_risks` block,
	# which every other chain kind already fills; a card that gains custody
	# fills it and changes nothing else.

	{
		"id": "wander_vehicle_search", "kind": KIND_ENCOUNTER, "weight": 7,
		"answers_back": false,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		# Somewhere else to be, and enough attention to be worth pulling over
		# on the way. Both gates read state the build already keeps.
		"requirements": [
			{"type": "fact_true", "fact": "on_the_road"},
			{"type": "fact_true", "fact": "heat_noticed"},
		],
		"line": "The car behind you has been behind you for three turns, and now the lights come on.",
		"encounter": {
			"definition_id": "wander_vehicle_search",
			"opponent": "The traffic stop",
			"shape": "negotiation",
			"choices": ["ask_why", "roll_slow", "open_it_up"],
			"roles": {"ask_why": ROLE_FIGHT, "roll_slow": ROLE_RUN,
				"open_it_up": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["open_it_up"],
			"base": {"ask_why": 0.55, "roll_slow": 0.40},
			"observations": {
				"ask_why": {
					"clean": {"type": "discretion", "event": "talked_through_a_stop"},
					"messy": {"type": "discretion", "event": "talked_through_a_stop"},
					"failure": {"type": "heat_exposure", "event": "vehicle_searched"},
					"catastrophic": {"type": "heat_exposure", "event": "vehicle_searched"},
				},
				"roll_slow": {
					"clean": {"type": "discretion", "event": "talked_through_a_stop"},
					"messy": {"type": "heat_exposure", "event": "vehicle_searched"},
					"failure": {"type": "heat_exposure", "event": "vehicle_searched"},
					"catastrophic": {"type": "heat_exposure", "event": "vehicle_searched"},
				},
				"open_it_up": {"type": "submission", "event": "vehicle_searched"},
			},
			"effects": {
				# A car search finds cargo, not cash -- a wallet is not
				# probable cause and the luggage rule has never taken clean
				# money. The worst road is the whole trunk plus the Heat of
				# having been the reason somebody called it in.
				"ask_why": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 0.5},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.5,
						"heat": 1.0},
					"catastrophic": {"health": 0, "cash_fraction": 0.0,
						"goods_fraction": 1.0, "heat": 2.0},
				},
				"roll_slow": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.25,
						"heat": 1.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.5,
						"heat": 1.5},
					"catastrophic": {"health": 0, "cash_fraction": 0.0,
						"goods_fraction": 1.0, "heat": 2.5},
				},
				"open_it_up": {
					"deterministic": {"health": 0, "cash_fraction": 0.0,
						"goods_fraction": 1.0, "heat": 0.5},
				},
			},
		},
	},
	{
		"id": "wander_warrant_check", "kind": KIND_ENCOUNTER, "weight": 6,
		"answers_back": false,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		# The one card in the roster that requires a history. A warrant check
		# on somebody who has never been booked is not a warrant check.
		"requirements": [{"type": "fact_true", "fact": "has_priors"}],
		"line": "He takes your name back to the cruiser and stays there a long time. He is running it.",
		"encounter": {
			"definition_id": "wander_warrant_check",
			"opponent": "The name check",
			"shape": "negotiation",
			# THE ONE CARD WHERE SURRENDER IS THE WORST ROAD, and the odds say
			# so before the player commits: WAIT IT OUT is deterministic and
			# its authored guarantee is the whole cargo plus the most Heat any
			# road here carries. The chassis rule is that a guaranteed out
			# EXISTS, never that it is cheap -- Stick Caught's own YIELD books
			# you on purpose (ENC-D6) and is the precedent. What the player is
			# owed is that the price is visible first, and a deterministic
			# road states its price rather than showing a band.
			"choices": ["give_a_name", "walk_now", "wait_it_out"],
			"roles": {"give_a_name": ROLE_FIGHT, "walk_now": ROLE_RUN,
				"wait_it_out": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["wait_it_out"],
			"base": {"give_a_name": 0.48, "walk_now": 0.34},
			"observations": {
				"give_a_name": {
					"clean": {"type": "honesty", "event": "name_came_back_clean"},
					"messy": {"type": "heat_exposure", "event": "run_for_warrants"},
					"failure": {"type": "heat_exposure", "event": "run_for_warrants"},
					"catastrophic": {"type": "heat_exposure", "event": "run_for_warrants"},
				},
				"walk_now": {
					"clean": {"type": "discretion", "event": "left_before_it_landed"},
					"messy": {"type": "heat_exposure", "event": "run_for_warrants"},
					"failure": {"type": "heat_exposure", "event": "run_for_warrants"},
					"catastrophic": {"type": "heat_exposure", "event": "run_for_warrants"},
				},
				"wait_it_out": {"type": "submission", "event": "run_for_warrants"},
			},
			"effects": {
				"give_a_name": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 1.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.5,
						"heat": 2.0},
					"catastrophic": {"health": 0, "cash_fraction": 0.0,
						"goods_fraction": 1.0, "heat": 3.0},
				},
				# Walking away from a name that is already in a computer is
				# the fastest road out and the one that costs most when it
				# does not work.
				"walk_now": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 2, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 1.5},
					"failure": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.5,
						"heat": 3.0},
					"catastrophic": {"health": 8, "cash_fraction": 0.0,
						"goods_fraction": 1.0, "heat": 4.0},
				},
				# The deliberate inversion. Nobody is hurt and nothing is
				# argued; you stand there while a computer decides, and it
				# decides the expensive way.
				"wait_it_out": {
					"deterministic": {"health": 0, "cash_fraction": 0.0,
						"goods_fraction": 1.0, "heat": 3.5},
				},
			},
		},
	},

	# --- OG-D3 (1.0.0 PR 3): the kit -------------------------------------------
	#
	# Weapons are bought off people, not from a menu. A knife from a man at
	# the Chevron a week in; a piece from Dre's cousin, later, once the run
	# is a player. Each is a meeting card with a PAY road that grants it.

	# --- TU-D4 (1.3.0): more of the street, said plainly ------------------------
	{
		"id": "wander_bench_tax", "kind": KIND_ENCOUNTER, "weight": 8,
		"intents": [], "gate_bias": "",
		"districts": [SPENARD], "slots": [EVENING, NIGHT], "once": false,
		"requirements": [{"type": "day_min", "min": 2}],
		"line": "A man at the bus shelter says the bench is his and sitting on it costs ten dollars. His friend behind him has not said anything yet.",
		"encounter": {
			"definition_id": "wander_bench_tax",
			"opponent": "The man who owns the bench",
			"shape": "negotiation",
			"choices": ["bench_stand", "bench_laugh", "bench_pay"],
			"roles": {"bench_stand": ROLE_FIGHT, "bench_laugh": ROLE_RUN, "bench_pay": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["bench_pay"],
			"base": {"bench_stand": 0.55, "bench_laugh": 0.60},
			"observations": {
				"bench_stand": {
					"clean": {"type": "defiance", "event": "kept_the_bench"},
					"messy": {"type": "violence", "event": "street_fight"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				"bench_laugh": {
					"clean": {"type": "discretion", "event": "laughed_it_off"},
					"messy": {"type": "discretion", "event": "laughed_it_off"},
					"failure": {"type": "violence", "event": "caught_from_behind"},
					"catastrophic": {"type": "violence", "event": "caught_from_behind"},
				},
				"bench_pay": {"type": "financial", "event": "paid_the_bench_tax"},
			},
			"effects": {
				"bench_stand": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 8, "cash_fraction": 0.1, "goods_fraction": 0.0},
					"catastrophic": {"health": 14, "cash_fraction": 0.3, "goods_fraction": 0.0},
				},
				"bench_laugh": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 3, "cash_fraction": 0.1, "goods_fraction": 0.0},
					"catastrophic": {"health": 7, "cash_fraction": 0.25, "goods_fraction": 0.0},
				},
				"bench_pay": {"deterministic": {"health": 0, "cash_flat": 10, "goods_fraction": 0.0}},
			},
		},
	},
	{
		"id": "wander_kid_lookout", "kind": KIND_ENCOUNTER, "weight": 7,
		"intents": [INTENT_DEAL], "gate_bias": "",
		"districts": [SPENARD, MOUNTAIN_VIEW], "slots": [AFTERNOON, EVENING], "once": false,
		"requirements": [{"type": "day_min", "min": 3}, {"type": "fact_true", "fact": "market_discovered"}],
		"line": "A kid, twelve maybe, offers to watch the corner for you for five dollars. He is already watching it, and he has already counted your pockets.",
		"encounter": {
			"definition_id": "wander_kid_lookout",
			"opponent": "The kid on the corner",
			"shape": "negotiation",
			"choices": ["kid_send_home", "kid_walk", "kid_pay"],
			"roles": {"kid_send_home": ROLE_FIGHT, "kid_walk": ROLE_RUN, "kid_pay": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["kid_pay"],
			"base": {"kid_send_home": 0.60, "kid_walk": 0.70},
			"observations": {
				"kid_send_home": {
					"clean": {"type": "honesty", "event": "sent_a_kid_home"},
					"messy": {"type": "honesty", "event": "sent_a_kid_home"},
					"failure": {"type": "presence", "event": "argued_with_a_kid"},
					"catastrophic": {"type": "presence", "event": "argued_with_a_kid"},
				},
				"kid_walk": {
					"clean": {"type": "discretion", "event": "kept_walking"},
					"messy": {"type": "discretion", "event": "kept_walking"},
					"failure": {"type": "presence", "event": "the_kid_followed"},
					"catastrophic": {"type": "presence", "event": "the_kid_followed"},
				},
				"kid_pay": {"type": "growth", "event": "hired_a_lookout"},
			},
			"effects": {
				"kid_send_home": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 0.5},
					"catastrophic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 1.0},
				},
				"kid_walk": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 0.5},
					"catastrophic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.1, "heat": 0.5},
				},
				"kid_pay": {"deterministic": {"health": 0, "cash_flat": 5, "goods_fraction": 0.0}},
			},
		},
	},
	{
		"id": "wander_lost_wallet", "kind": KIND_ENCOUNTER, "weight": 6,
		"intents": [INTENT_READ, INTENT_DEAL], "gate_bias": "",
		"districts": [SPENARD], "slots": [MORNING, AFTERNOON], "once": false,
		"requirements": [{"type": "day_min", "min": 2}],
		"line": "A wallet in the slush by the pumps: eighty dollars, a bus pass, and the ID of a woman you have seen at the Wash & Go. Nobody saw you pick it up.",
		"encounter": {
			"definition_id": "wander_lost_wallet",
			"opponent": "A wallet in the slush",
			"shape": "negotiation",
			"choices": ["wallet_ask", "wallet_keep", "wallet_return"],
			"roles": {"wallet_ask": ROLE_FIGHT, "wallet_keep": ROLE_RUN, "wallet_return": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["wallet_return"],
			"base": {"wallet_ask": 0.60, "wallet_keep": 0.70},
			"observations": {
				"wallet_ask": {
					"clean": {"type": "honesty", "event": "found_the_owner"},
					"messy": {"type": "honesty", "event": "found_the_owner"},
					"failure": {"type": "presence", "event": "asked_around_with_a_wallet"},
					"catastrophic": {"type": "betrayal", "event": "asked_around_with_a_wallet"},
				},
				"wallet_keep": {
					"clean": {"type": "discretion", "event": "kept_the_wallet"},
					"messy": {"type": "discretion", "event": "kept_the_wallet"},
					"failure": {"type": "betrayal", "event": "seen_keeping_a_wallet"},
					"catastrophic": {"type": "betrayal", "event": "seen_keeping_a_wallet"},
				},
				"wallet_return": {"type": "honesty", "event": "returned_the_wallet"},
			},
			"effects": {
				"wallet_ask": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 0.5},
				},
				"wallet_keep": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 0.5},
				},
				"wallet_return": {"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0}},
			},
			"grants": {
				"wallet_ask": {"clean": {"cash": 20}, "messy": {"cash": 20}},
				"wallet_keep": {"clean": {"cash": 80}, "messy": {"cash": 80}, "failure": {"cash": 80}},
			},
		},
	},
	{
		"id": "wander_plow_night", "kind": KIND_AMBIENT, "weight": 7,
		"intents": [INTENT_READ],
		"districts": [SPENARD], "slots": [NIGHT], "once": false,
		"requirements": [],
		"line": "The plow comes through at two and buries every car on the street side, Juan's truck included. He is out there with a shovel, not talking.",
		"observation": {"npc": "juan", "type": "presence", "event": "seen_around", "source": "household"},
	},
	{
		"id": "wander_no_lights", "kind": KIND_AMBIENT, "weight": 8,
		"intents": [INTENT_READ],
		"districts": [DOWNTOWN], "slots": [EVENING, NIGHT], "once": false,
		"requirements": [{"type": "fact_true", "fact": "heat_noticed"}],
		"line": "Two cruisers pass with no lights and no hurry. They are not looking for anyone. They are letting you see them not looking.",
		"observation": {"npc": "dre", "type": "discretion", "event": "seen_around", "source": "neighborhood"},
	},
	# --- SA-D3 (1.1.0): the Vales, at the counter ------------------------------
	#
	# Once, in the evening, once Mina reads you warm: a man with her last
	# name at her counter, and her whole face gone still. What you do about
	# it is the first thing her family learns about you. FIGHT is a mark on
	# her ledger she reads at minus four; TALK is discretion she reads at
	# plus four; COMPLY is watching from the end of the counter.
	{
		"id": "wander_vale_at_the_counter", "kind": KIND_ENCOUNTER, "weight": 9,
		"intents": [INTENT_READ], "gate_bias": "",
		"districts": [SPENARD], "slots": [EVENING], "once": true,
		"requirements": [{"type": "fact_true", "fact": "mina_warm"}],
		"line": "A man in a Carhartt is at the Night Owl counter with his voice low and Mina's whole face gone still. He says her last name like it is his. It is.",
		"encounter": {
			"definition_id": "wander_vale_at_the_counter",
			"opponent": "Mina's cousin",
			"shape": "negotiation",
			"choices": ["vale_step_in", "vale_talk", "vale_stay"],
			"roles": {"vale_step_in": ROLE_FIGHT, "vale_talk": ROLE_RUN, "vale_stay": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["vale_stay"],
			"base": {"vale_step_in": 0.45, "vale_talk": 0.60},
			"observations": {
				"vale_step_in": {"type": "violence", "event": "swung_on_minas_cousin"},
				"vale_talk": {
					"clean": {"type": "discretion", "event": "talked_the_cousin_down"},
					"messy": {"type": "discretion", "event": "talked_the_cousin_down"},
					"failure": {"type": "presence", "event": "made_it_worse_at_the_counter"},
					"catastrophic": {"type": "presence", "event": "made_it_worse_at_the_counter"},
				},
				"vale_stay": {"type": "submission", "event": "stayed_out_of_it"},
			},
			"effects": {
				"vale_step_in": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 8, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 14, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 1.0},
				},
				"vale_talk": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 3, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 6, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
				"vale_stay": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
	# --- SA-D2 (1.1.0): the beater on the street ------------------------------
	#
	# Three cards that only exist once there is a car. Two are ambient -- the
	# plate being read, Juan with the cables -- and one is an encounter with a
	# trunk to lose. `has_vehicle` is the gate on all three, and the traffic
	# stop above reads `on_the_road` as "or you have a car" now.
	{
		"id": "wander_plates_read", "kind": KIND_AMBIENT, "weight": 7,
		"intents": [INTENT_READ],
		"districts": [], "slots": [], "once": false,
		"requirements": [{"type": "fact_true", "fact": "has_vehicle"},
			{"type": "fact_true", "fact": "curtis_visible"}],
		"line": "A kid on a bike rides a slow circle around the Corolla, reading the plate out loud to somebody on speaker.",
		"observation": {"npc": "curtis", "type": "growth", "event": "plates_read",
			"source": "neighborhood"},
	},
	{
		"id": "wander_juan_jumps_it", "kind": KIND_AMBIENT, "weight": 6,
		"intents": [INTENT_WORK, INTENT_READ],
		"districts": [SPENARD], "slots": [MORNING], "once": false,
		"requirements": [{"type": "fact_true", "fact": "has_vehicle"}],
		"line": "Fourteen below and the Corolla is thinking about it. Juan is already walking over with the cables. He does not say anything about the car.",
		"observation": {"npc": "juan", "type": "presence", "event": "jumped_the_car",
			"source": "household"},
	},
	{
		"id": "wander_beater_breakin", "kind": KIND_ENCOUNTER, "weight": 8,
		# Answers back: a thief who does not scare is a thief who comes over,
		# and BR-D1's fistfight is what that is.
		"intents": [], "gate_bias": "",
		"districts": [SPENARD, DOWNTOWN], "slots": [EVENING, NIGHT], "once": false,
		"requirements": [{"type": "fact_true", "fact": "has_vehicle"}],
		"line": "The Corolla's back window is a hole with the glass on the seat, and somebody is still leaning into the trunk.",
		"encounter": {
			"definition_id": "wander_beater_breakin",
			"opponent": "Whoever is in your trunk",
			"shape": "negotiation",
			"choices": ["run_up", "shout", "let_it_go"],
			"roles": {"run_up": ROLE_FIGHT, "shout": ROLE_RUN, "let_it_go": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["let_it_go"],
			"base": {"run_up": 0.50, "shout": 0.58},
			"observations": {
				"run_up": {"type": "violence", "event": "ran_up_on_a_thief"},
				"shout": {
					"clean": {"type": "presence", "event": "shouted_off_the_lot"},
					"messy": {"type": "presence", "event": "shouted_off_the_lot"},
					"failure": {"type": "presence", "event": "watched_the_trunk_go"},
					"catastrophic": {"type": "presence", "event": "watched_the_trunk_go"},
				},
				"let_it_go": {"type": "submission", "event": "let_the_trunk_go"},
			},
			"effects": {
				# What is in the trunk is what is at risk; the wallet and the
				# bag on your back are not in the car.
				"run_up": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 3, "cash_fraction": 0.0, "goods_fraction": 0.0, "trunk_fraction": 0.5},
					"failure": {"health": 6, "cash_fraction": 0.0, "goods_fraction": 0.0, "trunk_fraction": 1.0},
					"catastrophic": {"health": 12, "cash_fraction": 0.0, "goods_fraction": 0.0, "trunk_fraction": 1.0, "heat": 0.5},
				},
				"shout": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "trunk_fraction": 0.5},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "trunk_fraction": 1.0},
					"catastrophic": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0, "trunk_fraction": 1.0},
				},
				"let_it_go": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "trunk_fraction": 1.0},
				},
			},
		},
	},
	{
		"id": "wander_meet_the_knife", "kind": KIND_MEETING, "weight": 7,
		"intents": [], "gate_bias": "",
		"districts": [SPENARD], "slots": [2, 3], "once": true,
		"requirements": [{"type": "day_min", "min": 6}, {"type": "fact_true", "fact": "unarmed"}],
		"line": "A man by the Chevron ice machine with a folding knife in his palm, showing it the way you would show a phone. \"Hundred twenty. Nobody's on it.\"",
		"encounter": {
			"definition_id": "wander_meet_the_knife",
			"opponent": "The man at the ice machine",
			"shape": "negotiation",
			"choices": ["knife_buy", "knife_pass"],
			"roles": {"knife_buy": ROLE_PAY, "knife_pass": ROLE_RUN},
			"admits_crew": false,
			"deterministic": ["knife_buy", "knife_pass"],
			"base": {},
			"observations": {},
			"effects": {
				"knife_buy": {"deterministic": {"health": 0, "cash_flat": 120, "goods_fraction": 0.0}},
				"knife_pass": {"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0}},
			},
		},
		"grants": {"knife_buy": {"deterministic": {"weapon": "knife"}}},
	},
	{
		"id": "wander_meet_the_piece", "kind": KIND_MEETING, "weight": 6,
		"intents": [], "gate_bias": "",
		"districts": [SPENARD], "slots": [3], "once": true,
		"requirements": [{"type": "day_min", "min": 14}, {"type": "fact_true", "fact": "no_piece"},
			{"type": "rank_min", "rank": "player"}],
		"line": "Dre's cousin, who you have seen but never been introduced to, sits down next to you at the Night Owl and puts a gym bag between his feet. \"Six hundred. Dre said you were somebody now. Are you?\"",
		"encounter": {
			"definition_id": "wander_meet_the_piece",
			"opponent": "Dre's cousin",
			"shape": "negotiation",
			"choices": ["piece_buy", "piece_pass"],
			"roles": {"piece_buy": ROLE_PAY, "piece_pass": ROLE_RUN},
			"admits_crew": false,
			"deterministic": ["piece_buy", "piece_pass"],
			"base": {},
			"observations": {},
			"effects": {
				"piece_buy": {"deterministic": {"health": 0, "cash_flat": 600, "goods_fraction": 0.0}},
				"piece_pass": {"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0}},
			},
		},
		"grants": {"piece_buy": {"deterministic": {"weapon": "piece"}}},
	},

	# --- BR-D5 (0.9.0 PR 4): Mountain View ---------------------------------------
	#
	# The community district. Ambients that say what the block is; one
	# encounter that says what it wants from you, which is a name; and a
	# Spenard card that opens it early through somebody who lives there.

	{
		"id": "mv_word_of_the_block", "kind": KIND_AMBIENT, "weight": 6,
		"intents": [], "gate_bias": "",
		"districts": [SPENARD], "slots": [], "once": true,
		# Days four to six: after that the block opens on its own.
		"requirements": [{"type": "day_min", "min": 4}, {"type": "day_max", "max": 6}],
		"discovers_district": MOUNTAIN_VIEW,
		"line": "Two Samoan brothers at the bus shelter, going home to Mountain View. One of them says pills go for real money over there because of the base, and the other one tells him to stop talking to strangers. They both laugh. Now you know where it is.",
	},
	{
		"id": "mv_the_courts", "kind": KIND_AMBIENT, "weight": 9,
		"intents": [], "gate_bias": "",
		"districts": [MOUNTAIN_VIEW], "slots": [], "once": false,
		"requirements": [],
		"line": "The courts behind Clark at dusk. A full-court game in three languages, and everybody on the fence knows everybody on the floor. They look at you exactly once. That once is the whole message.",
	},
	{
		"id": "mv_juba_market", "kind": KIND_AMBIENT, "weight": 8,
		"intents": [], "gate_bias": "",
		"districts": [MOUNTAIN_VIEW], "slots": [], "once": false,
		"requirements": [],
		"line": "Juba Market. Ahmed behind the counter greets four people by name before he gets to you. He does not get to you. He watches you pick a drink, and that is the whole transaction, and it is fair.",
	},
	{
		"id": "mv_church_lot", "kind": KIND_AMBIENT, "weight": 7,
		"intents": [], "gate_bias": "",
		"districts": [MOUNTAIN_VIEW], "slots": [2, 3], "once": false,
		"requirements": [],
		"line": "A Samoan church letting out on a Wednesday night. Two hundred people, more food than that, and an uncle in a lavalava who asks whose family you're with. You don't have an answer he likes. He feeds you anyway.",
	},
	{
		"id": "mv_who_are_you", "kind": KIND_ENCOUNTER, "weight": 9,
		"intents": [], "gate_bias": "",
		"districts": [MOUNTAIN_VIEW], "slots": [], "once": false,
		"requirements": [],
		"line": "Three men outside the barbershop on Mountain View Drive. The one with the name on the door, Reggie, asks who you're with. It is a real question, and the block is waiting on the answer.",
		"encounter": {
			"definition_id": "mv_who_are_you",
			"opponent": "Reggie, and the block",
			"shape": "negotiation",
			"choices": ["say_your_name", "keep_walking_mv", "come_correct"],
			"roles": {"say_your_name": ROLE_FIGHT, "keep_walking_mv": ROLE_RUN,
				"come_correct": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["come_correct"],
			"base": {"say_your_name": 0.55, "keep_walking_mv": 0.5},
			# Nobody swings here. The cost of the wrong answer is the block:
			# pressure, and the product you were carrying walking off with a
			# kid who was told to take it.
			"observations": {},
			"effects": {
				"say_your_name": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 1.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.5, "heat": 2.0},
					"catastrophic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 1.0, "heat": 3.0},
				},
				"keep_walking_mv": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 1.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.5, "heat": 2.5},
					"catastrophic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 1.0, "heat": 3.5},
				},
				"come_correct": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.25, "heat": 0.0},
				},
			},
		},
	},

	# --- hostile addicts ------------------------------------------------------
	#
	# VOX-D1's hard case, and the register holds: these are not comedy and they
	# are not pity. A person who needs something in the next ten minutes is
	# unpredictable in a specific way -- they are not calculating, which is
	# what makes them dangerous to somebody who is.

	{
		"id": "wander_desperate_approach", "kind": KIND_ENCOUNTER, "weight": 9,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		# No requirement at all: this is the roster's floor, the thing that
		# happens to anybody standing anywhere. Weighted highest of the eight
		# for the same reason.
		"requirements": [],
		"line": "A man with shaking hands walks up asking for twenty dollars, and he is not going to take no. He is between you and the sidewalk.",
		"encounter": {
			"definition_id": "wander_desperate_approach",
			"opponent": "The one who will not stop talking",
			"shape": "negotiation",
			"choices": ["shut_it_down", "keep_moving_past", "give_him_something"],
			"roles": {"shut_it_down": ROLE_FIGHT, "keep_moving_past": ROLE_RUN,
				"give_him_something": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["give_him_something"],
			# Unpredictable, and the numbers say it: the flat odds are decent
			# on both rolled roads and the catastrophic tails are heavy. He is
			# not calculating, so neither road is a plan.
			"base": {"shut_it_down": 0.58, "keep_moving_past": 0.62},
			"observations": {
				"shut_it_down": {
					"clean": {"type": "defiance", "event": "held_the_block"},
					"messy": {"type": "violence", "event": "street_fight"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				# Per-tier, not flat: a run road whose failure tiers cost real
				# health and cash cannot observe as "walked it off" on those
				# tiers. Found by driving all 24 roads on the real build —
				# every flat row on a road with a costly tail was wrong the
				# same way.
				"keep_moving_past": {
					"clean": {"type": "discretion", "event": "walked_it_off"},
					"messy": {"type": "discretion", "event": "walked_it_off"},
					"failure": {"type": "violence", "event": "caught_from_behind"},
					"catastrophic": {"type": "violence", "event": "caught_from_behind"},
				},
				"give_him_something": {"type": "financial", "event": "paid_to_be_left_alone"},
			},
			"effects": {
				"shut_it_down": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 3, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 7, "cash_fraction": 0.0, "goods_fraction": 0.0},
					# DOOR-D1, carried forward: no scripted death. The worst
					# road hurts and takes; the run ends only through the
					# existing end conditions.
					"catastrophic": {"health": 16, "cash_fraction": 0.25,
						"goods_fraction": 0.0},
				},
				"keep_moving_past": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 2, "cash_fraction": 0.25, "goods_fraction": 0.0},
					"catastrophic": {"health": 9, "cash_fraction": 0.5, "goods_fraction": 0.25},
				},
				# A flat, small, known price. The cheapest guaranteed out in
				# the roster, and it should be -- what he wants is small.
				"give_him_something": {
					"deterministic": {"health": 0, "cash_flat": 20, "goods_fraction": 0.0},
				},
			},
		},
	},
	{
		"id": "wander_lot_side", "kind": KIND_ENCOUNTER, "weight": 7,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [EVENING, NIGHT], "once": false,
		"requirements": [{"type": "day_min", "min": 4}],
		"line": "Two men arguing under the one working light on the Chevron lot, loud enough to carry, about money one of them says he never borrowed. You have to walk past them to get anywhere.",
		"encounter": {
			"definition_id": "wander_lot_side",
			"opponent": "The argument on the lot",
			"shape": "confrontation",
			# The card the brief asks for by name: FIGHT is CHEAP IN ODDS and
			# EXPENSIVE IN HEAT. Winning is easy -- they are not in any state
			# to stop you -- and a fight on a lit lot at night is the loudest
			# thing in this file. The trade is legible before the player
			# commits, because the odds band says STRONG and nothing hides
			# that heat is what it costs.
			"choices": ["put_them_down", "go_around", "pay_them_off", "hands_up"],
			"roles": {"put_them_down": ROLE_FIGHT, "go_around": ROLE_RUN,
				"pay_them_off": ROLE_PAY, "hands_up": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["pay_them_off", "hands_up"],
			"base": {"put_them_down": 0.78, "go_around": 0.60},
			"observations": {
				"put_them_down": {"type": "violence", "event": "beat_somebody_in_public"},
				"go_around": {
					"clean": {"type": "discretion", "event": "walked_it_off"},
					"messy": {"type": "discretion", "event": "walked_it_off"},
					"failure": {"type": "violence", "event": "caught_from_behind"},
					"catastrophic": {"type": "violence", "event": "caught_from_behind"},
				},
				"hands_up": {"type": "submission", "event": "gave_it_up"},
				"pay_them_off": {"type": "financial", "event": "paid_to_be_left_alone"},
			},
			"effects": {
				# BB-D8: the cheapest price in the roster, because what they
				# want is to be paid for not caring about you.
				"pay_them_off": {
					"deterministic": {"health": 0, "cash_flat": 30, "goods_fraction": 0.0},
				},
				# Every tier of the fight road carries Heat, including the
				# clean one. That is the point: you did not lose, you were
				# seen.
				"put_them_down": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 2.0},
					"messy": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 2.5},
					"failure": {"health": 9, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 3.0},
					"catastrophic": {"health": 14, "cash_fraction": 0.25,
						"goods_fraction": 0.25, "heat": 3.5},
				},
				"go_around": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 3, "cash_fraction": 0.25, "goods_fraction": 0.0},
					"catastrophic": {"health": 8, "cash_fraction": 0.5, "goods_fraction": 0.5},
				},
				"hands_up": {
					"deterministic": {"health": 0, "cash_fraction": 0.5, "goods_fraction": 0.5},
				},
			},
		},
	},

	# --- general street -------------------------------------------------------

	{
		"id": "wander_wrong_place", "kind": KIND_ENCOUNTER, "weight": 8,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [EVENING, NIGHT], "once": false,
		"requirements": [{"type": "day_min", "min": 4}],
		"line": "Something happened in this lot ten minutes ago: glass on the ground, a door still open, and two people who now know your name, deciding whether you are a witness or a problem.",
		"encounter": {
			"definition_id": "wander_wrong_place",
			"opponent": "The two who were here first",
			"shape": "negotiation",
			"choices": ["say_your_piece", "keep_it_moving", "back_out"],
			"roles": {"say_your_piece": ROLE_FIGHT, "keep_it_moving": ROLE_RUN,
				"back_out": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["back_out"],
			"base": {"say_your_piece": 0.56, "keep_it_moving": 0.58},
			"observations": {
				"say_your_piece": {
					"clean": {"type": "honesty", "event": "cleared_it_up"},
					"messy": {"type": "honesty", "event": "cleared_it_up"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				"keep_it_moving": {
					"clean": {"type": "discretion", "event": "walked_it_off"},
					"messy": {"type": "discretion", "event": "walked_it_off"},
					"failure": {"type": "violence", "event": "caught_from_behind"},
					"catastrophic": {"type": "violence", "event": "caught_from_behind"},
				},
				"back_out": {"type": "submission", "event": "gave_it_up"},
			},
			"effects": {
				"say_your_piece": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 2, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 6, "cash_fraction": 0.25, "goods_fraction": 0.0},
					"catastrophic": {"health": 11, "cash_fraction": 0.5, "goods_fraction": 0.25},
				},
				"keep_it_moving": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 4, "cash_fraction": 0.25, "goods_fraction": 0.25},
					"catastrophic": {"health": 10, "cash_fraction": 0.5, "goods_fraction": 0.5},
				},
				# Backing out of somewhere you had no business being costs the
				# walk and nothing else. The block keeps it anyway.
				"back_out": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
	{
		"id": "wander_territorial_beef", "kind": KIND_ENCOUNTER, "weight": 7,
		"intents": [INTENT_DEAL], "gate_bias": "stick",
		"districts": [], "slots": [], "once": false,
		# The block has to already be paying attention for this to make sense.
		# Reads the engine's own MARKET band for the district underfoot, which
		# is the same read `SEE WHO IS OUT` renders -- not a second scale.
		"requirements": [{"type": "day_min", "min": 8}, {"type": "fact_true", "fact": "market_pressure_visible"}],
		"line": "Two of Curtis's people block the sidewalk. This corner is theirs, they say, and so is whatever you made on it.",
		"encounter": {
			"definition_id": "wander_territorial_beef",
			"opponent": "The ones who work this block",
			"shape": "confrontation",
			"choices": ["it_is_my_block", "not_today", "settle_it_here", "off_the_block"],
			"roles": {"it_is_my_block": ROLE_FIGHT, "not_today": ROLE_RUN,
				"settle_it_here": ROLE_PAY, "off_the_block": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["settle_it_here", "off_the_block"],
			"base": {"it_is_my_block": 0.46, "not_today": 0.54},
			"observations": {
				"it_is_my_block": {
					"clean": {"type": "territory", "event": "held_the_block"},
					"messy": {"type": "territory", "event": "held_the_block"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				"not_today": {
					"clean": {"type": "discretion", "event": "walked_it_off"},
					"messy": {"type": "discretion", "event": "walked_it_off"},
					"failure": {"type": "territory", "event": "run_off_the_block"},
					"catastrophic": {"type": "territory", "event": "run_off_the_block"},
				},
				"off_the_block": {"type": "submission", "event": "ceded_the_corner"},
				# A tax paid is a tax Curtis's ledger reads the same way it
				# reads his own man being paid: the block is theirs, you
				# agreed, and you kept working.
				"settle_it_here": {"type": "submission", "event": "paid_the_tax"},
			},
			"effects": {
				# BB-D8: a cut for the block, and you keep what you brought.
				"settle_it_here": {
					"deterministic": {"health": 0, "cash_flat": 50, "goods_fraction": 0.0},
				},
				"it_is_my_block": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 1.0},
					"messy": {"health": 5, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 1.5},
					"failure": {"health": 10, "cash_fraction": 0.25, "goods_fraction": 0.5,
						"heat": 1.5},
					"catastrophic": {"health": 15, "cash_fraction": 0.5, "goods_fraction": 1.0,
						"heat": 2.0},
				},
				"not_today": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.25},
					"failure": {"health": 4, "cash_fraction": 0.25, "goods_fraction": 0.5},
					"catastrophic": {"health": 9, "cash_fraction": 0.5, "goods_fraction": 1.0},
				},
				# The whole point of the card: the cheap answer is agreeing
				# not to work here, and what it costs is what you are holding.
				"off_the_block": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.5},
				},
			},
		},
	},
	{
		"id": "wander_somebody_elses_problem", "kind": KIND_ENCOUNTER, "weight": 6,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		"requirements": [{"type": "day_min", "min": 20}, {"type": "fact_true", "fact": "curtis_visible"}],
		"line": "Half a block up, three men are stomping somebody on the ground. One of them has looked at you twice, and the second look was a question.",
		"encounter": {
			"definition_id": "wander_somebody_elses_problem",
			"opponent": "The two up the block",
			"shape": "confrontation",
			"choices": ["step_in", "cross_over", "look_away"],
			"roles": {"step_in": ROLE_FIGHT, "cross_over": ROLE_RUN,
				"look_away": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["look_away"],
			"base": {"step_in": 0.44, "cross_over": 0.66},
			"observations": {
				"step_in": {
					"clean": {"type": "loyalty", "event": "stepped_in_for_somebody"},
					"messy": {"type": "loyalty", "event": "stepped_in_for_somebody"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				"cross_over": {
					"clean": {"type": "discretion", "event": "walked_it_off"},
					"messy": {"type": "discretion", "event": "walked_it_off"},
					"failure": {"type": "violence", "event": "caught_from_behind"},
					"catastrophic": {"type": "violence", "event": "caught_from_behind"},
				},
				# Watching and doing nothing is a thing the block also sees.
				"look_away": {"type": "submission", "event": "watched_it_happen"},
			},
			"effects": {
				"step_in": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 6, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 11, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 17, "cash_fraction": 0.25, "goods_fraction": 0.25},
				},
				"cross_over": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 2, "cash_fraction": 0.0, "goods_fraction": 0.25},
					"catastrophic": {"health": 6, "cash_fraction": 0.25, "goods_fraction": 0.5},
				},
				"look_away": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
	# --- WS-D2 (0.8.0): the roster answers three questions -------------------
	#
	# Who is this? Why are they in front of me? Why should I care? Every card
	# below is keyed to WHEN in a run it makes sense, through `day_min` /
	# `day_max` and the facts the run already keeps:
	#
	#   Week Zero    days 1-4    arriving, cold, nobody knows you
	#   Getting Known days 4-10  you are doing something; people notice
	#   Reputation   days 10-20  the city knows your name; favors and warnings
	#   Weight       days 20+    you are a factor; probes and traps

	# Week Zero, ambient: orientation. Low stakes, high atmosphere.
	{
		"id": "wz_bus_shelter", "kind": KIND_AMBIENT, "weight": 14,
		"intents": [INTENT_READ], "gate_bias": "",
		"districts": [SPENARD], "slots": [MORNING, AFTERNOON], "once": true,
		"requirements": [{"type": "day_max", "max": 4}],
		"line": "The bus shelter on Spenard Road has a schedule nobody has updated since the snow came. An old man in a fur hat tells you the 7 runs when it runs, and that you are standing on the wrong side for downtown.",
	},
	{
		"id": "wz_the_chevron_sign", "kind": KIND_AMBIENT, "weight": 12,
		"intents": [INTENT_READ], "gate_bias": "",
		"districts": [SPENARD], "slots": [EVENING, NIGHT], "once": true,
		"requirements": [{"type": "day_max", "max": 4}],
		"line": "Four in the afternoon and the sun is already gone. The Chevron sign is the brightest thing for three blocks, and everybody on the block is orbiting it the way moths would if Anchorage had moths.",
	},
	{
		"id": "wz_overheard", "kind": KIND_AMBIENT, "weight": 10,
		"intents": [INTENT_READ, INTENT_DEAL], "gate_bias": "",
		"districts": [SPENARD], "slots": [], "once": true,
		"requirements": [{"type": "day_max", "max": 4}],
		"line": "Two women outside the laundromat, talking about somebody named Curtis the way people talk about weather. You do not know who that is yet. You will.",
	},

	# Getting Known, ambient: people start noticing.
	{
		"id": "gk_new_guy", "kind": KIND_AMBIENT, "weight": 10,
		"intents": [INTENT_WORK, INTENT_READ], "gate_bias": "",
		"districts": [SPENARD], "slots": [], "once": true,
		"requirements": [{"type": "day_min", "min": 4}, {"type": "day_max", "max": 12},
			{"type": "job_contacts_min", "min": 1}],
		"line": "A regular at the Chevron counter looks up from his scratch tickets. \"You the new one?\" He does not wait for an answer. He already had one.",
	},
	{
		"id": "gk_goodies_spot", "kind": KIND_AMBIENT, "weight": 10,
		"intents": [INTENT_DEAL, INTENT_READ], "gate_bias": "",
		"districts": [SPENARD], "slots": [EVENING, NIGHT], "once": true,
		"requirements": [{"type": "day_min", "min": 4}, {"type": "day_max", "max": 14},
			{"type": "fact_true", "fact": "market_discovered"}],
		"line": "Somebody at the Night Owl counter, not looking at you, says they have seen you around Goodie's spot. Just that. Then they go back to their coffee.",
		"observation": {"npc": "mina", "type": "presence", "event": "seen_around",
			"source": "witnessed"},
	},

	# Reputation: the city knows your name, and it wants things.
	{
		"id": "rep_a_favor", "kind": KIND_ENCOUNTER, "weight": 8,
		"intents": [INTENT_DEAL, INTENT_READ], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		"requirements": [{"type": "day_min", "min": 10}],
		"line": "A man you have seen twice and never spoken to says your name like he has said it before. He has a gym bag. He needs it held for an hour, and he is asking you because you are the one who is always around.",
		"encounter": {
			"definition_id": "rep_a_favor",
			"opponent": "The man with the gym bag",
			"shape": "negotiation",
			"choices": ["favor_ask", "favor_decline", "favor_hold"],
			"roles": {"favor_ask": ROLE_FIGHT, "favor_decline": ROLE_RUN,
				"favor_hold": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["favor_hold"],
			"base": {"favor_ask": 0.55, "favor_decline": 0.70},
			"observations": {
				"favor_ask": {
					"clean": {"type": "honesty", "event": "asked_the_right_question"},
					"messy": {"type": "honesty", "event": "asked_the_right_question"},
					"failure": {"type": "defiance", "event": "refused_a_favor"},
					"catastrophic": {"type": "defiance", "event": "refused_a_favor"},
				},
				"favor_decline": {
					"clean": {"type": "discretion", "event": "walked_it_off"},
					"messy": {"type": "discretion", "event": "walked_it_off"},
					"failure": {"type": "defiance", "event": "refused_a_favor"},
					"catastrophic": {"type": "defiance", "event": "refused_a_favor"},
				},
				"favor_hold": {"type": "loyalty", "event": "held_the_bag"},
			},
			"grants": {"favor_ask": {"clean": {"cash": 40}, "messy": {"cash": 25}},
				"favor_hold": {"deterministic": {"cash": 30}}},
			"effects": {
				"favor_ask": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 0.5},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 3, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
				"favor_decline": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
				"favor_hold": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 1.0},
				},
			},
		},
	},
	{
		"id": "rep_a_warning", "kind": KIND_AMBIENT, "weight": 9,
		"intents": [INTENT_READ], "gate_bias": "",
		"districts": [], "slots": [], "once": true,
		"requirements": [{"type": "day_min", "min": 10}, {"type": "fact_true", "fact": "curtis_visible"}],
		"line": "Juan's cousin, who has never said ten words to you, stops you outside the building. \"People are saying your name in places you are not.\" He does not say which people. He does not have to.",
		"observation": {"npc": "juan", "type": "presence", "event": "seen_around",
			"source": "household"},
	},

	# Weight: you are a factor. Encounters are political.
	{
		"id": "wt_curtis_probe", "kind": KIND_ENCOUNTER, "weight": 9,
		"intents": [INTENT_DEAL, INTENT_READ], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		"requirements": [{"type": "day_min", "min": 20},
			{"type": "fact_true", "fact": "curtis_watching_or_worse"}],
		"line": "Two of Curtis's people, not the ones who collect. These two ask questions -- where you were Tuesday, who you buy from, whether you know a man named Dre -- and every question is one they already know the answer to.",
		"encounter": {
			"definition_id": "wt_curtis_probe",
			"opponent": "Curtis's two",
			"shape": "negotiation",
			"choices": ["probe_answer", "probe_walk", "probe_pay", "probe_fold"],
			"roles": {"probe_answer": ROLE_FIGHT, "probe_walk": ROLE_RUN,
				"probe_pay": ROLE_PAY, "probe_fold": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["probe_pay", "probe_fold"],
			"base": {"probe_answer": 0.50, "probe_walk": 0.45},
			"observations": {
				"probe_answer": {
					"clean": {"type": "defiance", "event": "gave_curtis_nothing"},
					"messy": {"type": "defiance", "event": "gave_curtis_nothing"},
					"failure": {"type": "honesty", "event": "gave_curtis_a_name"},
					"catastrophic": {"type": "honesty", "event": "gave_curtis_a_name"},
				},
				"probe_walk": {
					"clean": {"type": "defiance", "event": "walked_past_the_tax"},
					"messy": {"type": "defiance", "event": "walked_past_the_tax"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				"probe_pay": {"type": "submission", "event": "paid_the_tax"},
				"probe_fold": {"type": "submission", "event": "gave_curtis_a_name"},
			},
			"effects": {
				"probe_answer": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "heat": 0.5},
					"failure": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 9, "cash_fraction": 0.25, "goods_fraction": 0.0},
				},
				"probe_walk": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 3, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 8, "cash_fraction": 0.25, "goods_fraction": 0.25},
					"catastrophic": {"health": 14, "cash_fraction": 0.5, "goods_fraction": 0.5},
				},
				"probe_pay": {
					"deterministic": {"health": 0, "cash_flat": 100, "goods_fraction": 0.0},
				},
				"probe_fold": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
	{
		"id": "wt_protection", "kind": KIND_AMBIENT, "weight": 8,
		"intents": [INTENT_READ, INTENT_DEAL], "gate_bias": "",
		"districts": [], "slots": [MORNING, AFTERNOON], "once": true,
		"requirements": [{"type": "day_min", "min": 20}, {"type": "crew_count_min", "min": 1}],
		"line": "The woman who runs the laundromat waits until nobody else is in it. She has heard you have people. She wants to know what it would cost for those people to be on her side of the street. She says it like a price, because it is one.",
		"observation": {"npc": "curtis", "type": "growth", "event": "asked_for_protection",
			"source": "neighborhood"},
	},

	# --- WS-D1 (0.8.0): the meetings -- the city reveals itself --------------
	#
	# Nothing criminal is on the board on day one. Each path arrives through
	# one of these: an authored moment, in the register, that DISCOVERS the
	# hustle the moment it opens (you now know the thing exists; how you
	# handle it is the road). Once each. `observations` are authored empty on
	# purpose: none of these is Curtis's business yet, and the role fallback
	# would write to his ledger otherwise.

	{
		"id": "wander_meet_goodie", "kind": KIND_MEETING, "weight": 1,
		"intents": [], "gate_bias": "",
		"districts": [SPENARD], "slots": [], "once": true,
		"requirements": [{"type": "day_min", "min": 2},
			{"type": "hustle_undiscovered", "hustle": "market"}],
		"discovers": "market",
		"line": "A man in a Carhartt has been watching the corner like it owes him money, and watching you longer. He is walking over now.",
		"encounter": {
			"definition_id": "wander_meet_goodie",
			"opponent": "Goodie",
			"shape": "negotiation",
			"choices": ["goodie_talk", "goodie_buy", "goodie_pass"],
			"roles": {"goodie_talk": ROLE_FIGHT, "goodie_pass": ROLE_RUN,
				"goodie_buy": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["goodie_buy", "goodie_pass"],
			"base": {"goodie_talk": 0.66},
			"observations": {"goodie_talk": {}, "goodie_buy": {}, "goodie_pass": {}},
			"grants": {"goodie_buy": {"deterministic": {"weed": 2}}},
			"effects": {
				"goodie_talk": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 0.5},
				},
				"goodie_buy": {
					"deterministic": {"health": 0, "cash_flat": 20, "goods_fraction": 0.0},
				},
				"goodie_pass": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
	{
		"id": "wander_first_lift", "kind": KIND_MEETING, "weight": 1,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [MORNING, AFTERNOON], "once": true,
		"requirements": [{"type": "day_min", "min": 3},
			{"type": "hustle_undiscovered", "hustle": "boost"}],
		"discovers": "boost",
		"discovers_target": "northern_value",
		"line": "Northern Value, mid-afternoon. One kid on the floor, the guard on his phone by the doors, and a rack of jackets nobody has counted since Christmas.",
		"encounter": {
			"definition_id": "wander_first_lift",
			"opponent": "The floor at Northern Value",
			"shape": "escape",
			"choices": ["lift_take", "lift_leave"],
			"roles": {"lift_take": ROLE_FIGHT, "lift_leave": ROLE_RUN},
			"admits_crew": false,
			"deterministic": ["lift_leave"],
			"base": {"lift_take": 0.60},
			"observations": {"lift_take": {}, "lift_leave": {}},
			"grants": {"lift_take": {"clean": {"cash": 45}, "messy": {"cash": 30}}},
			"effects": {
				"lift_take": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 0.5},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 1.0},
					"catastrophic": {"health": 4, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 2.0},
				},
				"lift_leave": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
	{
		"id": "wander_first_stickup_broke", "kind": KIND_MEETING, "weight": 1,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": true,
		"requirements": [{"type": "day_min", "min": 5},
			{"type": "fact_true", "fact": "broke"},
			{"type": "hustle_undiscovered", "hustle": "stickup"}],
		"discovers": "stickup",
		"line": "Under thirty dollars to your name and a week of rent standing behind it. The man coming out of the Chevron is counting a fold of cash like the street is his living room.",
		"encounter": {
			"definition_id": "wander_first_stickup_broke",
			"opponent": "The man with the fold",
			"shape": "confrontation",
			"choices": ["stick_take", "stick_pass"],
			"roles": {"stick_take": ROLE_FIGHT, "stick_pass": ROLE_RUN},
			"admits_crew": false,
			"deterministic": ["stick_pass"],
			"base": {"stick_take": 0.45},
			"observations": {"stick_take": {}, "stick_pass": {}},
			"grants": {"stick_take": {"clean": {"cash": 60}, "messy": {"cash": 40}}},
			"effects": {
				"stick_take": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 1.5},
					"messy": {"health": 3, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 2.0},
					"failure": {"health": 6, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 1.0},
					"catastrophic": {"health": 12, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 2.5},
				},
				"stick_pass": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
	{
		"id": "wander_first_stickup_witness", "kind": KIND_MEETING, "weight": 1,
		"intents": [], "gate_bias": "",
		"districts": [SPENARD], "slots": [EVENING, NIGHT], "once": true,
		"requirements": [{"type": "day_min", "min": 5},
			{"type": "hustle_undiscovered", "hustle": "stickup"}],
		"discovers": "stickup",
		"line": "Half a block up, a kid in a grey hoodie walks up on a man at the ATM. It takes eleven seconds, and the kid does not run afterward.",
		"encounter": {
			"definition_id": "wander_first_stickup_witness",
			"opponent": "The kid at the ATM",
			"shape": "negotiation",
			"choices": ["witness_ask", "witness_pass"],
			"roles": {"witness_ask": ROLE_FIGHT, "witness_pass": ROLE_RUN},
			"admits_crew": false,
			"deterministic": ["witness_pass"],
			"base": {"witness_ask": 0.55},
			"observations": {"witness_ask": {}, "witness_pass": {}},
			"effects": {
				"witness_ask": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0,
						"heat": 0.5},
					"catastrophic": {"health": 5, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
				"witness_pass": {
					"deterministic": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
				},
			},
		},
	},
]

## Player-facing copy for the encounter choices, in the two shapes the screen
## needs: the button, and the line under it.
##
## WS-D2 (0.8.0): the button is one of seven universal verbs -- FIGHT, RUN,
## TALK, PAY, SURRENDER, BLUFF, COMPLY -- plus the two crew calls, which are
## names. The old labels were phrases in each card's voice (STAND THERE, HANDS
## OUT, KEEP YOUR PACE), and the playtest verdict was that a player should
## never have to read a button to know what it does. The situation lives in
## the line UNDER the button now (`CHOICE_COPY`), and the story lives in the
## result. The ROLE is still what the chassis reads; the verb is what the
## thumb reads.
##
## Both are reached through the engine's adapter seam. Before that seam existed
## Wander shipped with FOUR of its five choices rendering an EMPTY description
## and the fifth inheriting Boost's — `talk` read "Hand it back and try to keep
## this from turning physical", which is nothing you can do to a cruiser. The
## engine's own table is Boost's vocabulary (fight / run / talk / yield) and was
## never going to cover a different chain's.
const CHOICE_LABELS := {
	# OG-D3: the kit.
	"knife_buy": "PAY", "knife_pass": "RUN", "piece_buy": "PAY", "piece_pass": "RUN",
	# BR-D5: Mountain View.
	"say_your_name": "TALK", "keep_walking_mv": "RUN", "come_correct": "COMPLY",
	"stand": "FIGHT",
	"walk": "RUN",
	"hand_over": "SURRENDER",
	"talk": "TALK",
	"keep_walking": "RUN",
	# SQ-D6's two missing surrender roads, and the run road Curtis's man never
	# had. Labels stay in each card's own voice -- the ROLE is the thing the
	# chassis reads, and it is not any of these strings.
	"hands_out": "COMPLY",
	"keep_pace": "RUN",
	"cross_the_street": "SURRENDER",
	# Duplicated from SCRIPTS.STASH_IT's own "label" rather than read off it:
	# GDScript's const initializer must be a compile-time-foldable expression,
	# and a cross-script dictionary subscript is not one. The value this
	# duplicates is asserted equal to the source in the suite, so the two
	# cannot drift silently.
	"stash_it": "BLUFF",
	"pay_it": "PAY",
	"push_back": "TALK",
	"hold_steady": "RUN",
	"stare_back": "BLUFF",
	# The shakedown room's verbs. SQ-D7 replaced 0.5.0's single KEEP FIGHTING
	# (which re-rolled STAND at decaying odds) with the triad, offered fresh
	# against each authored beat: SWING is the fight, BREAK FOR IT is the run
	# where the beat still has one, GIVE IT UP is the guaranteed out mid-fight
	# — the same shape HAND OVER already is at the door.
	"swing": "FIGHT",
	"break_for_it": "RUN",
	"give_it_up": "SURRENDER",
	# SQ-D9's chassis actions. Copy is `CREW_CALLS`' own; the labels are here
	# because this is where the wander adapter looks its buttons up.
	"call_tone": "CALL TONE",
	"let_deshawn_talk": "LET DESHAWN TALK",
	# --- 0.6.0 PR C: the roster's own vocabulary -------------------------------
	# Twenty-four labels, three per card, and not one of them is the word
	# "fight", "run" or "surrender". That is SQ-D6 working: the role is the
	# structural position and the label is what this particular situation
	# actually offers you.
	# TU-D4: the bench, the kid, the wallet.
	"bench_stand": "FIGHT",
	"bench_laugh": "BLUFF",
	"bench_pay": "PAY",
	"kid_send_home": "TALK",
	"kid_walk": "RUN",
	"kid_pay": "PAY",
	"wallet_ask": "TALK",
	"wallet_keep": "RUN",
	"wallet_return": "COMPLY",
	# SA-D3: the Vales.
	"vale_step_in": "FIGHT",
	"vale_talk": "TALK",
	"vale_stay": "COMPLY",
	# SA-D2: the break-in.
	"run_up": "FIGHT",
	"shout": "BLUFF",
	"let_it_go": "SURRENDER",
	"ask_why": "TALK",
	"roll_slow": "BLUFF",
	"open_it_up": "COMPLY",
	"give_a_name": "BLUFF",
	"walk_now": "RUN",
	"wait_it_out": "COMPLY",
	"shut_it_down": "TALK",
	"keep_moving_past": "RUN",
	"give_him_something": "PAY",
	"put_them_down": "FIGHT",
	"go_around": "RUN",
	"hands_up": "SURRENDER",
	"say_your_piece": "TALK",
	"keep_it_moving": "RUN",
	"back_out": "SURRENDER",
	"it_is_my_block": "FIGHT",
	"not_today": "RUN",
	"off_the_block": "SURRENDER",
	"step_in": "FIGHT",
	"cross_over": "RUN",
	"look_away": "SURRENDER",
	# BB-D8: the four priced roads.
	# WS-D1: the meetings, in the universal verbs (WS-D2 standardises the rest).
	# WS-D2: the favor and the probe.
	"favor_ask": "TALK",
	"favor_decline": "RUN",
	"favor_hold": "COMPLY",
	"probe_answer": "BLUFF",
	"probe_walk": "RUN",
	"probe_pay": "PAY",
	"probe_fold": "SURRENDER",
	"goodie_talk": "TALK",
	"goodie_buy": "PAY",
	"goodie_pass": "RUN",
	"lift_take": "BLUFF",
	"lift_leave": "RUN",
	"stick_take": "FIGHT",
	"stick_pass": "RUN",
	"witness_ask": "TALK",
	"witness_pass": "RUN",
	"pay_them": "PAY",
	"slip_him_something": "PAY",
	"pay_them_off": "PAY",
	"settle_it_here": "PAY",
}

const CHOICE_COPY := {
	"knife_buy": "A hundred and twenty. A knife in the coat from here on.",
	"knife_pass": "Keep your hands in your pockets.",
	"piece_buy": "Six hundred. Say you are somebody, and carry what that costs.",
	"piece_pass": "Tell him you're good. Let Dre hear that too.",
	# BR-D5: Mountain View.
	"say_your_name": "Say your name, and whose. Let the block decide what it's worth.",
	"keep_walking_mv": "It wasn't a question you have to answer. Yet.",
	"come_correct": "Tell him you're nobody yet. Pay the tax. Get invited back.",
	"stand": "Do not move. Let them decide what the bag is worth.",
	"walk": "Keep the bag, keep your pace, around the corner.",
	"hand_over": "Hand it over and walk away whole.",
	"talk": "Answer what he asks and nothing he did not. It is a conversation until he decides it is not.",
	"keep_walking": "Do not stop, do not run. Let the cruiser decide.",
	# Same duplication, same reason — see CHOICE_LABELS's own note above.
	"stash_it": "Product goes off you before he is out of the car.",
	"pay_it": "Forty dollars. He stops walking beside you.",
	"push_back": "The corner has no name on it either. Say so.",
	"hold_steady": "Same pace, eyes forward. Give them nothing to react to.",
	"stare_back": "Hold their eyes across the street until one of them looks away. That is the bet.",
	"hands_out": "Hands where he can see them. It ends.",
	"keep_pace": "Same speed, same direction, no answer. Find out whether that is allowed.",
	"cross_the_street": "Give them the block. Costs nothing you can count, and they will remember it.",
	"swing": "Hit first and keep hitting. This stopped being a conversation.",
	"break_for_it": "One gap, one chance. Take it before it closes.",
	"give_it_up": "Open your hands and say the word. Whatever you are holding stops being worth this.",
	"call_tone": "He ends it by standing there. Costs a favor.",
	"let_deshawn_talk": "His voice, not yours. Everybody walks.",
	# VOX-D1: short declaratives, terms rather than threats, and the addict
	# lines carry no comedy and no pity.
	"bench_stand": "Sit down anyway, and let him decide what that costs him.",
	"bench_laugh": "Laugh, and keep walking like that settled it.",
	"bench_pay": "Ten dollars. It is his bench.",
	"kid_send_home": "Tell him to go home, like somebody who means it.",
	"kid_walk": "Keep walking. He is twelve.",
	"kid_pay": "Five dollars. He is already watching it.",
	"wallet_ask": "Ask around the Wash & Go. Somebody will know her, and they will know you asked.",
	"wallet_keep": "Pocket the cash. Drop the rest in the trash by the pumps.",
	"wallet_return": "Take it to the Wash & Go. Lani will know her.",
	"vale_step_in": "Get between them. He is bigger than you and she did not ask.",
	"vale_talk": "Sit down next to him like you belong there and ask about the drive up.",
	"vale_stay": "Stay at the end of the counter. Watch. Be somebody she can look at.",
	"run_up": "Cross the lot fast. He has a screwdriver and a decision to make.",
	"shout": "From where you stand, loud enough for the building. Most of them run.",
	"let_it_go": "Stand there. Let him have the trunk. Keep the car.",
	"ask_why": "Make him say the reason out loud, politely. Sometimes there is not one.",
	"roll_slow": "Two inches of window and every answer already ready.",
	"open_it_up": "Trunk, doors, all of it. It ends when they are finished.",
	"give_a_name": "A name close enough to be boring. Boring gets waved through.",
	"walk_now": "Away from the car before the computer finishes. Every second is worse odds.",
	"wait_it_out": "Stand there and let the name come back. It will come back.",
	"shut_it_down": "End the conversation in the voice that means once. He will not end it himself.",
	"keep_moving_past": "Do not slow down and do not answer. He loses interest or he does not.",
	"give_him_something": "Twenty dollars is cheaper than the next ten minutes of him.",
	"put_them_down": "Both of them, before they agree about you. Everybody on this lot will see it.",
	"go_around": "The long way round the lot, eyes down.",
	"hands_up": "Whatever is on you is theirs. Nobody swings.",
	"say_your_piece": "Tell them what you did and did not see. Hope it lands.",
	"keep_it_moving": "You were never here. Walk like it.",
	"back_out": "The way you came, at the speed you came. Nothing lost but the walk.",
	"it_is_my_block": "You have been working it. Argue it with your hands.",
	"not_today": "Not today. Leave them the corner.",
	"off_the_block": "Agree not to work here. Leave half as the agreement.",
	"step_in": "Step in. Nobody else on this lot is going to.",
	"cross_over": "Other side of the street, same pace, eyes forward.",
	"look_away": "Keep walking and let it happen. Somebody will remember that you saw.",
	# BB-D8. A price is a price; the copy says what it buys.
	# WS-D1: the meetings. The line under the verb carries the situation.
	"favor_ask": "Ask what is in the bag before you touch it. The answer is the whole favor.",
	"favor_decline": "You do not hold bags. Say it once and keep walking.",
	"favor_hold": "Take the bag, stand where he says, and be somebody's for an hour.",
	"probe_answer": "Something true and useless. A story to check.",
	"probe_walk": "Do not answer. Walk. See if they can stop you yet.",
	"probe_pay": "A hundred dollars and the questions stop for today.",
	"probe_fold": "Give them a name. Not yours. Somebody's problem now.",
	"goodie_talk": "Ask him what he has and what it costs. He has already decided whether to answer.",
	"goodie_buy": "Twenty dollars for two. He remembers a customer longer than a question.",
	"goodie_pass": "Eyes forward. He will still be there tomorrow, and so will the corner.",
	"lift_take": "Two jackets under your own, and walk out like you paid. The guard is still on his phone.",
	"lift_leave": "Not today. But you saw how loose it was, and you will not unsee it.",
	"stick_take": "Walk up on him before he looks up. Whatever is in that fold is rent.",
	"stick_pass": "Let him count. You saw how easy it would have been; that is the part that stays.",
	"witness_ask": "Catch the kid at the corner and ask him how. He will either tell you or size you up.",
	"witness_pass": "Keep walking. You saw the whole thing, and eleven seconds is a number you now know.",
	"pay_them": "Sixty dollars buys the corner's patience. Cheaper than the bag, if you have it.",
	"slip_him_something": "Eighty dollars folded small. He takes it or he takes you in.",
	"pay_them_off": "Thirty dollars and the argument goes back to being theirs.",
	"settle_it_here": "A cut for the block, and you keep working it. Curtis's people will hear you paid.",
}

## The line under a DETERMINISTIC road, stating its guaranteed price.
##
## Reached through the engine's `choice_guarantee` adapter seam, which exists
## for exactly this: the screen's own fallback ("Guaranteed: no injury, no
## Heat, no arrest") was true for every deterministic choice that shipped
## before 0.3.0, and ENC-D6 opened the seam the day Stick Caught's YIELD
## guaranteed an ARREST instead.
##
## Every surrender road in this file needs it, because SQ-D6 makes the
## guaranteed out structural rather than cheap: HANDS OUT ends a search by
## letting it find what is on you, OFF THE BLOCK leaves half your cargo where
## you were standing, and WAIT IT OUT — the warrant check, the one card where
## surrender is genuinely the WORST road — costs the whole bag and the loudest
## Heat on the card. A player is owed that price BEFORE they commit, and
## "CERTAIN" beside an odds band is not a price.
const CHOICE_GUARANTEE := {
	"let_it_go": "Guaranteed: nobody swings. The trunk is his.",
	"vale_stay": "Guaranteed: nobody swings. She saw you not leave.",
	"bench_pay": "Guaranteed: ten dollars, and the bench.",
	"kid_pay": "Guaranteed: five dollars, and a lookout.",
	"wallet_return": "Guaranteed: nothing in your pocket, and a name that knows.",
	"knife_buy": "Guaranteed: $120, and the knife is yours.",
	"knife_pass": "Guaranteed: nothing changes hands.",
	"piece_buy": "Guaranteed: $600, and the piece is yours. Heat rides with it from here.",
	"piece_pass": "Guaranteed: nothing changes hands.",
	# BR-D5: Mountain View.
	"come_correct": "Guaranteed: nobody touches you. A quarter of what you carry, and an invitation.",
	"hand_over": "Guaranteed: you walk away whole. Everything you are carrying is theirs.",
	"hands_out": "Guaranteed: nobody is hurt. The search happens, and it finds what is on you.",
	"cross_the_street": "Guaranteed: nothing happens to you. The block will remember that it did not.",
	"pay_it": "Guaranteed: $40, and the corner has no further questions today.",
	"give_it_up": "Guaranteed: the fight stops here. Whatever is still in your hands is not.",
	"open_it_up": "Guaranteed: no argument and no injury. Whatever is in the car is theirs.",
	# The inversion, stated plainly. It is the only road on this card that
	# takes everything AND carries the most Heat, and it is the certain one.
	"wait_it_out": "Guaranteed: nobody lays a hand on you. They take everything you are carrying, and your name goes in a computer twice.",
	"give_him_something": "Guaranteed: $20, and he goes and asks somebody else.",
	"hands_up": "Guaranteed: nobody swings. Half of what is on you leaves with them.",
	"back_out": "Guaranteed: nothing lost but the walk back.",
	"off_the_block": "Guaranteed: no injury. Half of what you brought stays on this corner.",
	"look_away": "Guaranteed: nothing happens to you at all. Somebody will remember that you saw.",
	"call_tone": "Guaranteed: it ends. It costs a favor you will want back later.",
	"let_deshawn_talk": "Guaranteed: everybody walks, and you keep what you were carrying.",
	# BB-D8: a flat price from either pocket, stated whole.
	# WS-D1: the meetings' guaranteed roads.
	"favor_hold": "Guaranteed: $30 for the hour, and whatever is in the bag was in your hands. Heat comes with it.",
	"probe_pay": "Guaranteed: $100, no hands on you, and Curtis knows you pay when asked.",
	"probe_fold": "Guaranteed: nobody touches you. You gave Curtis a name, and the block will hear whose.",
	"goodie_buy": "Guaranteed: $20, two units of product, and Goodie knows your face as a customer.",
	"goodie_pass": "Guaranteed: nothing changes hands. You know where the corner is now.",
	"lift_leave": "Guaranteed: nothing taken, nothing risked. You know what a loose rack looks like now.",
	"stick_pass": "Guaranteed: nothing happens. You know how it would have gone.",
	"witness_pass": "Guaranteed: nothing happens to you. You know how fast it is now.",
	"pay_them": "Guaranteed: $60, and they let you keep walking with the rest.",
	"slip_him_something": "Guaranteed: $80, no search, and a cop who knows your face and your price.",
	"pay_them_off": "Guaranteed: $30. Nobody swings, and you keep what is on you.",
	"settle_it_here": "Guaranteed: $50, and you keep what you brought.",
}

## What happened, in the card's own voice -- BB-D1 (0.7.0).
##
## Until this table existed a street encounter's result fell through to the
## sheet's boost-caught copy: a three-round fistfight over nothing ended on
## "The take is gone and the room remembers your face." Every road of every
## card now says what it did, and the confrontation suite renders all of them
## and refuses the boost fallback on any of them.
##
## Shape: card -> choice -> tier -> [HEADLINE, body]. `"*"` under a choice is
## that road's default for any tier not authored by name. A card's `"room"`
## block is the same shape for the roads offered INSIDE its room, which are
## different situations from the roads at the door and read that way. Tiers
## that escalate into the room have no entry here, because nothing has
## resolved yet -- the room writes its own ending.
##
## VOX-D1 holds: short declaratives, terms rather than threats, the addicts
## without comedy or pity. A headline is what happened; the body is what it
## means. Neither ever prints a number -- WHAT IT COST is rendered under them,
## exact and signed, by the sheet.
const RESULT_COPY := {
	"wander_shakedown": {
		"stand": {
			"clean": ["THEY THINK BETTER OF IT", "You do not move and you do not raise your voice. The one doing the talking runs out of things to say, and they go find an easier evening."],
			# BB-D4: the door's own round, when it does not end there.
			"escalate": ["IT DOES NOT END THERE", "They do not scatter. This is a fight now, and the first one is already stepping in."],
		},
		"walk": {
			"clean": ["YOU KEEP WALKING", "You do not speed up. By the time they decide, you are somebody else's problem on somebody else's block."],
			"messy": ["THEY GET A HAND ON THE BAG", "You are clear of them before it turns into anything, but not before one of them got a hand in. Part of what you were carrying stayed on the corner."],
			"failure": ["THEY CATCH YOU AT THE CORNER", "The gap you were counting on was never there. They take what they can reach and let you keep walking, which was their idea of generous."],
			"catastrophic": ["IT GOES THE WAY THEY PLANNED", "You were carrying, and now they are. They went through your pockets the way you would go through a drawer."],
		},
		"hand_over": {
			"deterministic": ["YOU HAND IT OVER", "Nobody has to touch you. Whatever was in your pockets and on your back goes with them, and the corner goes back to being a corner."],
		},
		"pay_them": {
			"deterministic": ["YOU PAY THEM", "Sixty dollars changes hands and the corner loses interest. They did not want a fight. They wanted to be paid for not having one."],
		},
		"room": {
			"swing": {
				"escalate": ["HE STAYS UP", "You landed it and he took it. There are more of them than there were a second ago, and you are still in it."],
				"clean": ["THE FIRST ONE GOES DOWN", "He was closer than he should have been and now he is on the ground. The others look at him and decide the arithmetic changed."],
				"messy": ["NOBODY WINS OUTRIGHT", "It stops because everybody is tired of it. You leave with less than you came with and more than they wanted you to keep."],
				"failure": ["THEY WEAR YOU DOWN", "Two of them is one too many. You stayed on your feet, which is the whole of the good news."],
				"catastrophic": ["IT ENDS ON THE GROUND", "You do not remember the last one landing. When you can stand, your pockets are already empty and the street is quiet."],
				"*": ["NOBODY WINS OUTRIGHT", "It stops because everybody is tired of it. You leave with less than you came with and more than they wanted you to keep."],
			},
			"break_for_it": {
				"escalate": ["NO GAP", "You went for it and it closed. Somebody has a hand on you, and you are still in it."],
				"clean": ["YOU FIND THE GAP", "One of them turned his head. It was enough."],
				"messy": ["YOU GET CLEAR, MOSTLY", "Somebody got a fistful of your jacket on the way past. What was in it is theirs now."],
				"failure": ["THEY CLOSE THE GAP", "You were a step slow and they were not. It is a fight again, and it is worse than it was."],
				"catastrophic": ["THEY CLOSE IT", "You run into the third one. Everything you had is gone before you hit the ground."],
				"*": ["NOBODY WINS OUTRIGHT", "It stops because everybody is tired of it. You leave with less than you came with and more than they wanted you to keep."],
			},
			"give_it_up": {
				"deterministic": ["YOU GIVE IT UP", "You stop, open your hands, and say the one word that ends a fight on this block. They take it all and take their time."],
			},
		},
	},
	"wander_stopped_on_foot": {
		"talk": {
			"clean": ["HE LETS YOU GO", "You answer the questions he asks and none of the ones he did not. He runs out of reasons before you run out of answers."],
			"messy": ["HE LETS YOU GO, EVENTUALLY", "It takes longer than it should, and he writes something down. You keep everything but the ten minutes."],
			"failure": ["HE FINDS A REASON", "The conversation was never the point. He pats you down like he was always going to, and part of what you carried goes into a bag with a number on it."],
			"catastrophic": ["IT GOES INTO EVIDENCE", "Wrong answer, wrong tone, wrong block. He puts you against the car and takes his time about the rest."],
		},
		"keep_walking": {
			"clean": ["HE DRIVES ON", "The cruiser stays with you for another half block and then it is somewhere else. You never looked at it."],
			"messy": ["HE MAKES YOU STOP", "He gets out. You get put against the fence hard enough to mean it, and then he loses interest."],
			"failure": ["HE SEARCHES YOU ANYWAY", "Not stopping was an answer, and he did not like it. Half of what you were carrying is his now."],
			"catastrophic": ["WRONG ANSWER", "He gets out fast and puts you on the ground. Everything on you is theirs, and so is the rest of your afternoon."],
		},
		"hands_out": {
			"deterministic": ["THE SEARCH FINDS WHAT IS THERE", "You keep your hands where he can see them and let him find what he finds. It ends on his terms, and it ends."],
		},
		"slip_him_something": {
			"deterministic": ["HE TAKES IT", "It goes into his pocket without a look. The search does not happen. He will remember exactly who paid, and what for."],
		},
		"stash_it": {
			"clean": ["NOTHING ON YOU", "By the time his hand reaches your pocket there is nothing in it. He knows there was. He cannot prove it."],
			"failure": ["HE WATCHED YOU DO IT", "Fast hands, but not faster than his eyes. He takes what you tried to drop and remembers your face for the trying."],
		},
	},
	"wander_curtis_tax": {
		"push_back": {
			"clean": ["HE LETS IT GO, FOR NOW", "He hears the answer and does not argue with it. That is not the same as agreeing. Curtis will hear how you said it."],
			"messy": ["YOU PAY ANYWAY", "You said your piece, and it cost exactly what it would have cost to say nothing. He took the money and the attitude both."],
			"failure": ["HE MAKES HIS POINT", "It got physical in the time it takes to say no. You paid, plus the interest for making him ask twice."],
			"catastrophic": ["CURTIS'S ANSWER", "He does not hit you like somebody who is angry. He hits you like somebody sending a message, and then goes through your pockets for the postage."],
		},
		"keep_pace": {
			"clean": ["HE FALLS AWAY", "Same speed, same direction, no answer. Half a block later he is not beside you anymore."],
			"messy": ["HE STOPS YOU", "Not answering was allowed for exactly half a block. He takes the toll off you at the corner."],
			"failure": ["IT COSTS YOU EXTRA", "He decided your silence was expensive. You paid the toll and something for the walk."],
			"catastrophic": ["HE MAKES SURE YOU REMEMBER", "He does not raise his voice. When it is over you have paid more than he first asked, and you understand why he only asks once."],
		},
		"pay_it": {
			"deterministic": ["YOU PAY THE TOLL", "The money changes hands like it was always going to. He nods like a cashier. Curtis knows the corner is still his."],
		},
	},
	"wander_young_ones": {
		"stare_back": {
			"clean": ["THEY LOOK AWAY FIRST", "One of them finds something interesting on his phone. The other one follows. The block noticed who blinked."],
			"messy": ["THEY REMEMBER YOU", "It ends with a word from the older one and a shove that was meant to be a joke. You are on their list now, and their list is short."],
			"failure": ["THEY CROSS OVER", "You made it a thing, and now it is a thing. A few punches on a cold street, thrown by people with nothing better to do."],
			"catastrophic": ["ALL OF THEM AT ONCE", "They were waiting for a reason. You gave them one, and it took three of them to accept it."],
		},
		"hold_steady": {
			"clean": ["THEY LOSE INTEREST", "You keep your pace and your face. They were looking for a reaction and did not get one."],
			"messy": ["THEY LET YOU PASS", "One of them says something as you go by. You do not turn around, and that turns out to be correct."],
			"failure": ["ONE OF THEM FOLLOWS", "He walks behind you for a block saying your name, or a name. Nothing happens. You do not feel like nothing happened."],
			"catastrophic": ["FROM BEHIND", "You held it together right up until the one you did not see. One punch, no words, and they are gone."],
		},
		"cross_the_street": {
			"deterministic": ["YOU CROSS THE STREET", "Nothing happens to you. They watch it not happen, and they know what it means, and so does the block."],
		},
	},
	"wander_bench_tax": {
		"bench_stand": {
			"clean": ["HE FINDS ANOTHER BENCH", "You sit. He looks at his friend, his friend looks at the road, and the bench is a bench again."],
			"messy": ["ONE SWING EACH", "He swings first and you swing better. His friend does not get involved. You keep the bench and a fat lip."],
			"failure": ["THE FRIEND GETS INVOLVED", "It was two on one the whole time. You come off the bench the hard way, and some of what was in your pocket stays on it."],
			"catastrophic": ["THE SHELTER", "They put you into the glass of the shelter and go through your pockets while you are still deciding to get up."],
		},
		"bench_laugh": {
			"clean": ["HE LAUGHS TOO", "You laugh and keep walking, and he laughs, because it was a bit, and now it is over."],
			"messy": ["HE DOES NOT LAUGH", "He does not think it is funny. He says so, loud, to the whole stop. You are past him before it becomes more than that."],
			"failure": ["FROM BEHIND", "You laughed and turned your back, which was the mistake. He catches you three steps on."],
			"catastrophic": ["THE FRIEND WAS FASTER", "The friend was faster than he looked. You are on the ground by the schedule nobody updated, and your pockets are lighter."],
		},
		"bench_pay": {
			"deterministic": ["TEN DOLLARS", "You pay the bench tax. He takes it like rent. His friend never said a word."],
		},
	},
	"wander_kid_lookout": {
		"kid_send_home": {
			"clean": ["HE GOES", "You tell him to go home, and something in how you say it works. He goes. He looks back once."],
			"messy": ["HE GOES, SLOWLY", "He argues, then goes, then stands at the end of the block watching anyway. Free, this time."],
			"failure": ["HE TELLS THE BLOCK", "He tells everybody in earshot what you told him, louder than you said it. Now the block knows there is a corner to watch."],
			"catastrophic": ["HIS BROTHER", "His brother is seventeen and was across the street. Nothing happens, except that you are known now, by the wrong family."],
		},
		"kid_walk": {
			"clean": ["HE LOSES INTEREST", "You keep walking. He picks somebody else to watch."],
			"messy": ["HE FOLLOWS", "He follows for a block, narrating. Then he gets bored."],
			"failure": ["HE FOLLOWS ALL THE WAY", "He follows you to the corner and stands there watching the transaction like a customer."],
			"catastrophic": ["HE GOES THROUGH YOUR BAG", "Somewhere in the following, a hand went in your bag. He is twelve, and he is gone."],
		},
		"kid_pay": {
			"deterministic": ["FIVE DOLLARS", "You pay him. He watches the corner like it is his job, because now it is."],
		},
	},
	"wander_lost_wallet": {
		"wallet_ask": {
			"clean": ["SHE WAS AT THE COUNTER", "Lani knows her, and she is three people back in line. She gives you twenty for the trouble and says your name to the room."],
			"messy": ["LANI PASSES IT ON", "Lani takes it and says she will get it to her. Twenty dollars comes back to you a day later in an envelope with no note."],
			"failure": ["THE WRONG PERSON HEARS", "You ask the wrong person, who wants to know why you are asking. The wallet goes back to Lani. The story goes around."],
			"catastrophic": ["NOW YOU ARE THE STORY", "By the time it reaches her, the story is that you had it all afternoon. She thanks you like somebody who does not believe you."],
		},
		"wallet_keep": {
			"clean": ["NOBODY SAW", "The cash goes in your pocket and the rest goes in the trash by the pumps. Nobody saw. She will look for it anyway."],
			"messy": ["SOMEBODY MIGHT HAVE", "A car at the pumps pulls out as you straighten up. Eighty dollars, and a driver who may have seen where it came from."],
			"failure": ["THE ATTENDANT SAW", "The attendant watched the whole thing through the glass. He does not say anything. He does not have to; it is his block."],
			"catastrophic": ["SHE SAW", "She was coming back for it. She watches you put it in your pocket from thirty feet away, and she knows your face from the Wash & Go."],
		},
		"wallet_return": {
			"deterministic": ["LANI KNOWS HER", "You leave it with Lani, who knows exactly who she is. Nothing in your pocket. Somebody at the Wash & Go knows what you did."],
		},
	},
	"wander_vale_at_the_counter": {
		"vale_step_in": {
			"clean": ["HE BACKS OFF", "You are between them before you decided to be. He looks at you a long time, and then at her, and leaves. She does not thank you. She does not have to."],
			"messy": ["ONE EACH", "He puts you into the cooler door and you put him into the floor. Mina says both your names in the voice that ends things."],
			"failure": ["HE IS BIGGER", "He is bigger than you and has done this more. You are on the floor and he is still talking to her, softer now, which is worse."],
			"catastrophic": ["THE COUNTER GOES OVER", "It ends with the register on the floor and a customer on the phone. He leaves. So does she, out the back, and she does not look at you on the way."],
		},
		"vale_talk": {
			"clean": ["THE DRIVE UP", "You sit down next to him and ask about the roads. He talks about the roads. Whatever he came to say, he says it to you instead, and it is not the thing he came to say."],
			"messy": ["HE KNOWS WHAT YOU ARE DOING", "He answers you, slowly, and then goes back to her. But softer, and shorter, and then he leaves. She wipes the same spot of counter for a while."],
			"failure": ["WRONG THING TO SAY", "You say the wrong thing about the family and he stands up to say so. It is over fast. She does not look at either of you."],
			"catastrophic": ["HE TAKES IT OUT ON YOU", "Whatever he could not say to her, he says with his hands. Out front, in the cold, with the door propped so she can hear."],
		},
		"vale_stay": {
			"deterministic": ["YOU STAYED", "You stay at the end of the counter and drink the coffee. He leaves when he is done. She does not say anything about it, then or later, but she saw you not leave."],
		},
	},
	"wander_beater_breakin": {
		"run_up": {
			"clean": ["HE DROPS IT", "He sees you coming and drops what he had. The window is still a hole, but the trunk is yours."],
			"messy": ["HE SWINGS", "The screwdriver catches your arm on the way past. He goes with half of what was under the spare."],
			"failure": ["HE WAS NOT ALONE", "Somebody in the car across the lot gets out. The trunk goes, and so does a little of you."],
			"catastrophic": ["THE LOT", "Two of them, and a tire iron. The trunk is empty, the window is gone, and somebody called it in."],
		},
		"shout": {
			"clean": ["HE RUNS", "One shout and the whole lot hears it. He is over the fence before he has closed the trunk."],
			"messy": ["HE GRABS WHAT HE CAN", "He runs, but not with empty hands. Half of it goes with him."],
			"failure": ["HE DOES NOT CARE", "He looks up, looks back down, and finishes. You watched the trunk go."],
			"catastrophic": ["HE COMES OVER", "He was not scared, and now he is annoyed. The trunk is empty and your lip is split."],
		},
		"let_it_go": {
			"deterministic": ["YOU LET HIM", "He takes what he came for and leaves the keys in the ignition, which is a kind of manners."],
		},
	},
	"wander_vehicle_search": {
		"ask_why": {
			"clean": ["HE HAS NO REASON", "You ask him to say it out loud, politely. He cannot, and he knows you know it. Plates come back clean and so do you."],
			"messy": ["HE WRITES IT DOWN", "He finds a taillight to talk about. The stop ends with paper, and your name in a system it was not in this morning."],
			"failure": ["HE SEARCHES THE CAR", "The question annoyed him into probable cause. Part of what was in the trunk is now in his."],
			"catastrophic": ["THE WHOLE TRUNK", "You made him prove it and he proved it. He calls a second car so the two of them can take their time."],
		},
		"roll_slow": {
			"clean": ["HE WAVES YOU ON", "Two inches of window, license ready, nothing to see. He was already looking for somebody else."],
			"messy": ["HE TAKES A LOOK", "Two inches was not enough. He leans in, sees something, and takes the smallest part of it to make a point."],
			"failure": ["OUT OF THE CAR", "The slow window told him something. So did the trunk."],
			"catastrophic": ["THEY TAKE IT APART", "The car gets pulled onto the shoulder and emptied onto it. Everything you carried is theirs, and your plate is on a list."],
		},
		"open_it_up": {
			"deterministic": ["YOU LET THEM LOOK", "Trunk, doors, all of it. They take what they find and let you keep the car."],
		},
	},
	"wander_warrant_check": {
		"give_a_name": {
			"clean": ["THE NAME COMES BACK CLEAN", "Close enough to be boring. Boring got waved through."],
			"messy": ["IT TAKES A WHILE", "The name comes back, but not before he has looked at you for a long time. He lets you go with a warning that was not about the name."],
			"failure": ["THE NAME DOES NOT HOLD", "The computer had a different opinion. He takes what you are carrying and does not explain which name it was for."],
			"catastrophic": ["TWO NAMES IN THE SYSTEM", "Yours and the one you gave. He empties your pockets into an evidence bag and puts both names on it."],
		},
		"walk_now": {
			"clean": ["GONE BEFORE IT LANDS", "Half a block, around a corner, and he is still in the car reading. Whatever it said, it said it to nobody."],
			"messy": ["HE CATCHES UP", "He puts a hand on your shoulder hard enough to count. You keep what you have. Your name goes in twice."],
			"failure": ["HE DOES NOT LET YOU", "Walking away from a name that is already on a screen goes the way it goes. Half of what you carried stays with him."],
			"catastrophic": ["ON THE HOOD", "You did not get ten feet. He puts you on the hood and takes everything, and the report will say you ran."],
		},
		"wait_it_out": {
			"deterministic": ["IT COMES BACK", "You stand there while a computer decides. It decides the expensive way. Nobody lays a hand on you; they do not have to."],
		},
	},
	"wander_desperate_approach": {
		"shut_it_down": {
			"clean": ["HE HEARS YOU", "You say it once, in the voice that means once. He goes to find somebody softer."],
			"messy": ["HE HITS YOU FIRST", "One wild swing, the kind that lands by accident. Then he is gone, still talking."],
			"failure": ["HE DOES NOT STOP", "He is not calculating, which is the problem. It takes more than you wanted to give to make him leave."],
			"catastrophic": ["HE HAD SOMETHING IN HIS HAND", "You did not see it until it was in you. He takes what he can grab and runs, and you sit down on the curb for a while."],
		},
		"keep_moving_past": {
			"clean": ["HE LOSES INTEREST", "You do not slow down and you do not answer. He is talking to your back and then to nobody."],
			"messy": ["HE FOLLOWS YOU A BLOCK", "A whole block of it. Then he sees somebody he knows, and you were never here."],
			"failure": ["HE GRABS YOU", "A hand on your arm and then your pocket. Not much, taken fast, by somebody who needed it more."],
			"catastrophic": ["FROM BEHIND", "You should have turned around. He hits you with everything he has, which is not much, and takes what he can carry."],
		},
		"give_him_something": {
			"deterministic": ["HE TAKES IT", "Twenty dollars and he is somebody else's problem. He does not say thank you. He does not say anything you have not already heard."],
		},
	},
	"wander_lot_side": {
		"put_them_down": {
			"clean": ["BOTH OF THEM, FAST", "Neither of them was in any state to stop you. Everybody on the lot saw it, and the lot is lit."],
			"messy": ["YOU WIN UGLY", "It took longer than it should have and one of them got a hand up. The lot saw all of it."],
			"failure": ["THEY TURN ON YOU", "Whatever they were arguing about, they agree about you. Two on one under a streetlight, and the light is not on your side."],
			"catastrophic": ["THE LOT WAS WATCHING", "You went down under a light with an audience. They take what they want and leave you for whoever comes next."],
		},
		"go_around": {
			"clean": ["THE LONG WAY", "Well lit, nobody's business but yours. They never look up."],
			"messy": ["ONE OF THEM LOOKS UP", "He watches you go the long way and says something to the other one. Nothing follows you but the feeling."],
			"failure": ["ONE OF THEM FOLLOWS", "The argument ends and you are the next thing. A shove, a hand in your pocket, and he is back to the argument."],
			"catastrophic": ["BOTH OF THEM", "They stopped arguing when they saw you. You were the thing they could agree on."],
		},
		"hands_up": {
			"deterministic": ["HANDS UP", "Nobody swings. Half of what is on you leaves with the two of them, and the argument resumes without you."],
		},
		"pay_them_off": {
			"deterministic": ["YOU PAY THEM OFF", "Thirty dollars, split however they split it. They go back to arguing and you go around."],
		},
	},
	"wander_wrong_place": {
		"say_your_piece": {
			"clean": ["THEY BELIEVE YOU", "You tell them what you saw, which was nothing, and it comes out sounding true. They go back to whatever it was."],
			"messy": ["THEY DECIDE YOU ARE NOBODY", "One of them shoves you toward the street to see if you argue. You do not. That was the right answer."],
			"failure": ["THEY DO NOT BELIEVE YOU", "A witness is a problem, and you look like one. They solve it with their hands and take something for the trouble."],
			"catastrophic": ["YOU SAW TOO MUCH", "Whatever happened here, you are now part of it. They make sure you will not describe it well."],
		},
		"keep_it_moving": {
			"clean": ["YOU WERE NEVER HERE", "Eyes forward, same pace. By the time somebody says something, you are past the corner."],
			"messy": ["SOMEBODY SAYS YOUR NAME", "Or a name. You do not turn around. You will not be sure for a week whether it was yours."],
			"failure": ["THEY CATCH YOU", "Walking away looked like knowing something. They take a piece of what you have and all of your certainty about the block."],
			"catastrophic": ["FROM BEHIND", "You were never here, and they make sure you will remember that. What was on you is theirs."],
		},
		"back_out": {
			"deterministic": ["YOU BACK OUT", "The way you came, at the speed you came. Nothing lost but the walk, and the block writes it down."],
		},
	},
	"wander_territorial_beef": {
		"it_is_my_block": {
			"clean": ["THE BLOCK IS YOURS", "You do not move, and they see something in that. They go, and the corner is quieter than it was."],
			"messy": ["YOU HOLD IT, BARELY", "It took blood to make the point. The corner is yours tonight. Tomorrow is a separate conversation."],
			"failure": ["THEY RUN YOU OFF", "The argument was you working here. They win it the old way and take a cut of the evidence."],
			"catastrophic": ["THE BLOCK TAKES ITS CUT", "They leave you on the corner you said was yours, with your pockets turned out, so the block can see who was right."],
		},
		"not_today": {
			"clean": ["NOT TODAY", "You do not argue and you do not run. There will be another block, and they let you go find it."],
			"messy": ["THEY TAKE A SAMPLE", "You leave, but not with everything. They keep a little of what you were selling, so the block knows it was theirs."],
			"failure": ["THEY WALK YOU OFF", "Run off a corner in front of the corner, with half of what you brought staying behind. The block keeps the score."],
			"catastrophic": ["THEY MAKE AN EXAMPLE", "They do not just want you gone. They want it remembered."],
		},
		"off_the_block": {
			"deterministic": ["OFF THE BLOCK", "You agree not to work here and leave half of what you brought as the agreement. The block saw who moved."],
		},
		"settle_it_here": {
			"deterministic": ["YOU SETTLE IT", "Fifty dollars and the block lets you work. It is a tax now, and they will remember that you paid it."],
		},
	},
	"wander_somebody_elses_problem": {
		"step_in": {
			"clean": ["YOU END IT", "They did not expect a third person, and they did not expect that one. Somebody you do not know gets to walk away, and remembers who let him."],
			"messy": ["YOU END IT, BLEEDING", "It stops. You are not sure who won and neither are they. The one on the ground got up while nobody was looking."],
			"failure": ["IT WAS NOT YOUR PROBLEM", "You made it yours and they made it your body. The one you stepped in for is long gone."],
			"catastrophic": ["TWO FOR THE PRICE OF ONE", "They finish what they were doing and then finish you, and go through your pockets while they are down there."],
		},
		"cross_over": {
			"clean": ["OTHER SIDE OF THE STREET", "Same pace, eyes forward. Whatever that was, it was on the other side."],
			"messy": ["ONE OF THEM WATCHES YOU GO", "He looks up long enough to make sure you saw him look. Nothing else happens. That was the message."],
			"failure": ["HE COMES ACROSS", "One of them decides you saw too much from over there. A shove, a hand, a piece of what you were carrying."],
			"catastrophic": ["THEY BOTH COME ACROSS", "Crossing the street was not far enough. What they were doing up the block, they do to you."],
		},
		"look_away": {
			"deterministic": ["YOU LOOK AWAY", "Nothing happens to you at all. Somebody up the block is going to remember that you saw and did not."],
		},
	},
}

## WS-D2: the favor and the probe, same shape.
const PHASE_RESULT_COPY := {
	"rep_a_favor": {
		"favor_ask": {
			"clean": ["HE TELLS YOU", "Cash, he says, and it is. You hold it for an hour by the Chevron and he tips you out of it when he comes back. You are somebody who can be asked now."],
			"messy": ["HE TELLS YOU MOST OF IT", "He says clothes. It is heavier than clothes. You hold it anyway, and he pays anyway, and now you both know something about each other."],
			"failure": ["HE DOES NOT LIKE THE QUESTION", "Asking what is in it was answering no. He takes the bag somewhere else, and takes your name with him."],
			"catastrophic": ["WRONG THING TO ASK", "He decides you are the kind who asks. He makes sure you remember not to, and takes his bag with him."],
		},
		"favor_decline": {
			"clean": ["YOU DO NOT HOLD BAGS", "He nods like he expected it and finds somebody who does. No harm. No favor owed either way."],
			"messy": ["HE ASKS AGAIN", "You say no twice. The second no costs you a look you will get again someday."],
			"failure": ["HE REMEMBERS THAT", "Saying no to a man who knows your name is a thing the man does with your name afterward."],
			"catastrophic": ["HE TAKES IT PERSONALLY", "He decides your no was about him. It gets brief and physical, and it will not be the last time you see him."],
		},
		"favor_hold": {
			"deterministic": ["YOU HOLD THE BAG", "An hour by the Chevron with somebody else's problem in your hand. He comes back, pays, and says nothing about what was in it. Neither do you."],
		},
	},
	"wt_curtis_probe": {
		"probe_answer": {
			"clean": ["THEY GET A STORY", "Every answer true, none of them useful. They leave with a Tuesday that checks out and nothing Curtis can use. That is the whole game, and you played it."],
			"messy": ["THEY GET MOST OF A STORY", "One answer came out too fast. They noticed. Curtis will hear that you talk, and that you are careful, and he will weigh those against each other."],
			"failure": ["THEY GET A NAME", "You gave them something real to make the rest sound real. It was Dre's. That is going to be a conversation."],
			"catastrophic": ["THEY GET EVERYTHING", "You ran out of story before they ran out of questions. Curtis knows who you buy from, where you keep it, and what your Tuesdays look like."],
		},
		"probe_walk": {
			"clean": ["THEY LET YOU WALK", "Not yet, one of them says to the other, and they do not follow. Curtis hears that you do not stop for his people. He files it."],
			"messy": ["THEY WALK WITH YOU", "Half a block of it, one on either side, asking the questions anyway. You gave nothing, and it cost you a shoulder."],
			"failure": ["THEY STOP YOU", "It turns out they were allowed to. Not badly, and not for long, but Curtis's people put hands on you and the block saw it."],
			"catastrophic": ["THEY MAKE THEIR POINT", "Curtis's people do not hit you like they are angry. When it is over you have answered everything, and paid for making them ask."],
		},
		"probe_pay": {
			"deterministic": ["YOU PAY FOR QUIET", "A hundred dollars and the questions stop. Curtis now knows the exact price of your afternoon, and that you will pay it."],
		},
		"probe_fold": {
			"deterministic": ["YOU GIVE THEM A NAME", "It was not yours. They leave satisfied, and somewhere on the block a man you have met twice just became Curtis's problem instead of you."],
		},
	},
}

## WS-D1: the meetings' own endings, same shape as the cards above.
const MEETING_RESULT_COPY := {
	"wander_meet_goodie": {
		"goodie_talk": {
			"clean": ["HE GIVES YOU A PRICE", "He tells you what he has like he is reading a menu, and what it costs like you already agreed. You know the corner now, and the corner knows you."],
			"messy": ["HE GIVES YOU HALF AN ANSWER", "Enough to know he is the one to ask, and not enough to think you are owed anything. It is a start."],
			"failure": ["HE DOES NOT ANSWER", "He looks at you for a long moment and goes back to watching the corner. You still know where it is. He knows you asked."],
			"catastrophic": ["WRONG QUESTION, WRONG VOLUME", "You said it loud enough for the block to hear, and the block includes a cruiser two lights down. He walks. So should you."],
		},
		"goodie_buy": {
			"deterministic": ["YOU BUY IN", "Twenty dollars, two in a fold of foil, no conversation. He nods like a cashier. That nod is the whole relationship, for now."],
		},
		"goodie_pass": {
			"deterministic": ["YOU KEEP WALKING", "He does not stop watching. You have seen where the corner is and who runs it, and that is a thing you cannot give back."],
		},
	},
	"wander_first_lift": {
		"lift_take": {
			"clean": ["OUT THE DOOR", "Two jackets under your own and nobody looked up. You sell them behind the Chevron before the guard finishes his call."],
			"messy": ["OUT THE DOOR, BARELY", "The kid on the floor saw something and decided it was not his problem. One jacket sells. The other you leave in a dumpster because your hands would not stop."],
			"failure": ["THE GUARD LOOKS UP", "He takes the jackets back at the door and takes your face with them. Nobody calls anybody. Nobody has to."],
			"catastrophic": ["THE GUARD PUTS YOU DOWN", "He was not on his phone. Everybody in the parking lot watches you get walked out, and one of them is a cop's brother-in-law."],
		},
		"lift_leave": {
			"deterministic": ["YOU LEAVE IT", "You walk out with what you came in with and a piece of information you did not have: how loose a rack can be, and how bored a guard."],
		},
	},
	"wander_first_stickup_broke": {
		"stick_take": {
			"clean": ["THE FOLD IS YOURS", "You were on him before he looked up, and the fold was in your hand before he understood the question. Rent, the bad way."],
			"messy": ["YOU GET MOST OF IT", "He held on longer than his money was worth. You leave with the fold and a cut lip, and he leaves with your description."],
			"failure": ["HE IS NOT WHO YOU THOUGHT", "He was counting cash outside a gas station because nobody had ever taken it from him. You find out why."],
			"catastrophic": ["ALL THE WAY DOWN", "He puts you on the ground in front of the pumps and keeps his money. Somebody films it. That is Spenard now."],
		},
		"stick_pass": {
			"deterministic": ["YOU LET HIM COUNT", "He folds the money into his jacket and drives off. You stand there under thirty dollars, and you know exactly how it would have gone."],
		},
	},
	"wander_first_stickup_witness": {
		"witness_ask": {
			"clean": ["HE TELLS YOU", "He is nineteen and proud of it. Where they stand, when they look down, how long you have. He tells you like it is a recipe."],
			"messy": ["HE SIZES YOU UP FIRST", "He wants to know who is asking before he answers, and then answers anyway, in fewer words. You got the shape of it."],
			"failure": ["HE DOES NOT LIKE THE QUESTION", "Asking how it is done is a way of saying you saw it done. He tells you to forget both, and means it."],
			"catastrophic": ["HE THINKS YOU ARE A PROBLEM", "You asked the wrong kid the wrong thing. He makes sure you will not describe him well, and you will not."],
		},
		"witness_pass": {
			"deterministic": ["ELEVEN SECONDS", "You keep walking. The man at the ATM is still standing there deciding whether to call anybody. You know how fast it is now, and how nobody ran."],
		},
	},
}

## The two chassis actions read the same on every card: a call is a call.
const CREW_RESULT_COPY := {
	"call_tone": ["TONE ENDS IT", "He does not say much. He does not need to. They look at him and decide the evening is over."],
	"let_deshawn_talk": ["DESHAWN TALKS", "His voice, not yours. By the time he is done everybody has somewhere better to be, and you still have what you came with."],
}

## The one lookup, so the adapter and the suite read the table the same way.
## Returns `[headline, body]` or `[]` when nothing is authored for the road.
static func result_copy(card_id: String, choice_id: String, tier: String,
		in_room: bool) -> Array:
	if CREW_RESULT_COPY.has(choice_id):
		return CREW_RESULT_COPY[choice_id]
	var card_table: Dictionary = RESULT_COPY.get(card_id,
		MEETING_RESULT_COPY.get(card_id, PHASE_RESULT_COPY.get(card_id,
			MV_RESULT_COPY.get(card_id, KIT_RESULT_COPY.get(card_id, {})))))
	var table: Dictionary = card_table.get("room", {}) if in_room else card_table
	var road: Dictionary = table.get(choice_id, {})
	if road.has(tier):
		return road[tier]
	if road.has("*"):
		return road["*"]
	return []

## BB-D8: the price of a card's PAY road at the door, or 0 for a card without
## one. Read off the authored `cash_flat`, so the table is the one owner.
static func pay_price(card: Dictionary, choice_id: String) -> int:
	if role_of(card, choice_id) != ROLE_PAY:
		return 0
	var effects: Dictionary = (card.get("encounter", {}) as Dictionary).get("effects", {})
	return int(((effects.get(choice_id, {}) as Dictionary).get("deterministic", {}) as Dictionary)
		.get("cash_flat", 0))

# --- BR-D1 (0.9.0): he swung first ---------------------------------------------
#
# "If he chooses to hit us why can't we fight back until he runs away, dies,
# or gives up?" A non-fight road whose rolled tier hurts is somebody
# initiating violence, and the encounter used to end there with the damage
# landed and nothing to do about it. Now it answers back: the hit lands, the
# result says so, and the next round offers the card's own FIGHT road (and
# its RUN and its SURRENDER) in a room generated from the card. Two beats,
# then a stalemate. A clean FIGHT exit sends him off and leaves what fell
# out of his pockets -- a few dollars, not a wage: the first cut paid $25/$35
# and lifted two job-plus profiles 8-12% past their corridors, because a
# street fight you win must not out-earn a shift.
#
# Police cards opt out (`answers_back: false`): a cop's hands on you is not
# a fight the game lets you win, and their FIGHT-role road is TALK anyway.
# A card with an authored room opens that room instead of a generated one.

## BR-D5: the block's own result copy. `PHASE_RESULT_COPY` shape.
const MV_RESULT_COPY := {
	"mv_who_are_you": {
		"say_your_name": {
			"clean": ["HE NODS", "You say your name and who put you up in Spenard. Reggie nods once. Somebody inside the shop laughs, not at you. You are known on the block now, which is worth more than anything you were carrying."],
			"messy": ["HE LETS IT GO", "He hears the name and does not love it. \"Spenard.\" Like it is a diagnosis. He lets you pass. The block heard it too."],
			"failure": ["WRONG ANSWER", "The name means nothing here and you can see it mean nothing. A kid you did not notice walks off with half of what you had, and nobody outside the barbershop saw a thing."],
			"catastrophic": ["THE BLOCK DECIDES", "Reggie does not move. Three other people do. Everything you were carrying leaves in three directions, and the whole street watches it go without watching."],
		},
		"keep_walking_mv": {
			"clean": ["YOU WALK", "You keep walking and nobody follows. The question is still open, and it will be open next time."],
			"messy": ["NOTICED", "You walk and they let you, and the barbershop's whole window turns to watch you go. That is not nothing on this block."],
			"failure": ["CUT OFF", "A kid on a bike cuts you off at the corner, polite as anything, and leaves with half of what you had. Reggie never moved."],
			"catastrophic": ["THE BLOCK CLOSES", "You walk into a wall of cousins. Everything you were carrying is gone before you are back on the Drive, and every door on it is closed to you tonight."],
		},
		"come_correct": {
			"deterministic": ["YOU COME CORRECT", "You tell him you are nobody yet and you are not here to be somebody at his expense. He takes a little off the top -- \"tax\" -- and tells you to come see him before you sell anything on his Drive again. That is an invitation."],
		},
	},
}

## OG-D3: what buying or passing on a weapon reads.
const KIT_RESULT_COPY := {
	"wander_meet_the_knife": {
		"knife_buy": {"deterministic": ["IT'S YOURS", "He folds it, hands it over handle first, and does not tell you his name. The coat is heavier now, and so are you."]},
		"knife_pass": {"deterministic": ["NOT TODAY", "You keep your hands in your pockets. He shrugs. \"It'll be here.\""]},
	},
	"wander_meet_the_piece": {
		"piece_buy": {"deterministic": ["SOMEBODY NOW", "The bag goes under your stool and the money goes into his. \"Don't be stupid with it.\" Everybody in the Night Owl saw the bag change feet."]},
		"piece_pass": {"deterministic": ["NOT LIKE THAT", "You tell him you're good. He looks at you for a while and decides to believe it. Dre will hear that too."]},
	},
}

const ANSWER_LINES := {
	"wander_desperate_approach": {
		"open": "He swings before the sentence is finished. It catches you high on the cheek, and now he is not talking at all.",
		"beat": "He is off balance from the first one and swinging again, wild, crying a little. He is not going to stop on his own.",
		"beat2": "He is bleeding from the mouth and still coming. Whatever he needed, he needs it more now.",
		"won": "He goes down and stays down long enough to think about it, then gets up and runs. There is money on the ground that was in his hand.",
		"ran": "You get a step on him and he does not chase. He is yelling something you do not stop to hear.",
	},
	"wander_lot_side": {
		"open": "She comes off the car door with something in her hand and it catches your shoulder. Not a knife. Not nothing, either.",
		"beat": "She is between you and the sidewalk now, and she is faster than she looks.",
		"beat2": "She drops whatever it was and comes with her hands. There is nothing left in her but this.",
		"won": "She backs off the lot, swearing, and does not come back. There is a fold of bills on the asphalt where she was standing.",
		"ran": "You put the row of cars between you and her and she loses interest before you reach the street.",
	},
	"wander_wrong_place": {
		"open": "Somebody you did not see puts a hand on the back of your neck and the ground comes up. Then there are two of them.",
		"beat": "You are up. The one who hit you is already reaching again; the other one is watching the street.",
		"beat2": "The second one steps in. It is two on one now and they know it.",
		"won": "The first one goes down and the second one decides. They walk, and one of them leaves a phone and a roll behind.",
		"ran": "You break for the lights and they do not follow past the corner. Wrong place. You know that now.",
	},
	"wander_territorial_beef": {
		"open": "He does not argue. He hits you, once, hard, to say the block has already decided.",
		"beat": "He is squared up and waiting. He wants you to swing, so everybody watching sees who started it.",
		"beat2": "He comes again, and this time he has his boys' attention. This is the whole block now.",
		"won": "He goes down in front of his own people, and that is worse for him than the hit. He leaves what was in his pocket.",
		"ran": "You walk off his block backwards. He lets you. That is its own message.",
	},
	"wander_somebody_elses_problem": {
		"open": "It was not your problem until his elbow found your face. Now it is.",
		"beat": "He has turned all the way around. Whoever he was fighting is gone; you are what is left.",
		"beat2": "He is not tired. He is one of those people who is never tired.",
		"won": "He backs off with his hands up and leaves faster than he came, and whatever fell out of his jacket stays.",
		"ran": "You get out of range. He finds somebody else to be angry at.",
	},
	"wander_young_ones": {
		"open": "One of them, the smallest, hits you in the ear from behind. The other two laugh.",
		"beat": "They are kids. They are also three, and they have done this before.",
		"beat2": "The big one stops laughing and steps in. That was the one who mattered.",
		"won": "The big one goes down and the other two are gone before he lands. He leaves a phone. He leaves his shoes.",
		"ran": "They chase you half a block and quit, still laughing.",
	},
	"wander_curtis_tax": {
		"open": "The one who was smiling stops smiling and puts you into the fence. \"That is the courtesy version.\"",
		"beat": "He lets you up. He is waiting to see what you do with it, and so is the one behind him.",
		"beat2": "He comes again, slower, meaning it. This is what Curtis's people are for.",
		"won": "He goes down and the other one does not step in, which tells you something about Curtis's people. He leaves the fold he was collecting.",
		"ran": "You get off the block. He does not chase. Curtis will hear about it either way.",
	},
	"rep_a_favor": {
		"open": "He does not take no. His hand is on your collar and the bag is on the ground between you.",
		"beat": "He is bigger than you and knows it, and he has one hand free.",
		"beat2": "He is not letting go of you or the bag. One of those is going to give.",
		"won": "He lets go of everything. The bag, your collar, and a roll that was in his coat, and he is gone.",
		"ran": "You slip the collar and leave him with his bag. He shouts. You keep going.",
	},
	"wt_curtis_probe": {
		"open": "The question was a formality. The first one hits you while the second one keeps asking it.",
		"beat": "They are professionals. They are not angry. That is the problem with them.",
		"beat2": "The second one puts his phone away. Whatever he was going to report, he is going to report this instead.",
		"won": "One of them goes down and the other one helps him up and they leave, unhurried. They leave the envelope.",
		"ran": "You put a door between you and them. They do not try it. They already know where you live.",
	},
	"_": {
		"open": "He swings first. Now it is a fight.",
		"beat": "He is still coming. He is not going to stop on his own.",
		"beat2": "He is hurt and still coming. Whatever this is about, it is about more than you.",
		"won": "He goes down, gets up, and runs. He leaves what fell out of his pockets.",
		"ran": "You get clear. He does not follow.",
	},
}

## BR-D1: what the sheet says at each stage of an answer room, when the card
## has no room copy of its own. `[headline, body]`, by the tier the round
## ended in, or "escalate" for the interim result.
const ANSWER_RESULT_COPY := {
	"escalate": ["HE SWUNG FIRST", "It landed. You are still standing, and now it is a fight -- yours to finish or to leave."],
	"clean": ["HE IS DONE", "It breaks your way. He runs, and he leaves what was in his hand."],
	"messy": ["YOU GET OUT OF IT", "Not clean, and not for free. But you are walking and he is not chasing."],
	"failure": ["IT DOES NOT BREAK YOUR WAY", "You gave it what you had. It was not enough."],
	"catastrophic": ["IT GOES BADLY", "All the way through. You are on the ground and your pockets are lighter."],
	"deterministic": ["YOU GIVE IT UP", "Hands up, mid-fight. He takes what he came for and goes."],
}

static func answers_back(card: Dictionary) -> bool:
	return str(card.get("kind", "")) == KIND_ENCOUNTER \
		and bool(card.get("answers_back", true))

static func answer_lines(card_id: String) -> Dictionary:
	return ANSWER_LINES.get(card_id, ANSWER_LINES["_"])

## The road of `role` on a card, or "".
static func road_of_role(card: Dictionary, role: String) -> String:
	var roles: Dictionary = (card.get("encounter", {}) as Dictionary).get("roles", {})
	for choice_id in roles.keys():
		if str(roles[choice_id]) == role:
			return str(choice_id)
	return ""

## A two-beat room built from the card's own roads, for a card that has no
## authored room. FIGHT is always on the table; RUN on the first beat; the
## card's SURRENDER road is the guaranteed out on both.
## The roads of an answer room are the fistfight's own -- SWING, BREAK FOR
## IT, GIVE IT UP -- not the door's. A door whose FIGHT road read TALK (the
## talker, a negotiation) is a fistfight now, and the verb has to say so.
const ANSWER_CHOICE_COPY := {
	"swing": "He started it. Finish it.",
	"break_for_it": "Get clear before it gets worse.",
	"give_it_up": "Hands up. He takes what he takes.",
}

static func answer_room(card: Dictionary) -> Dictionary:
	var card_fight := road_of_role(card, ROLE_FIGHT)
	var card_run := road_of_role(card, ROLE_RUN)
	if card_fight.is_empty():
		return {}
	var fight := "swing"
	var run := "break_for_it"
	var out := "give_it_up"
	var encounter: Dictionary = card.get("encounter", {})
	var base: Dictionary = encounter.get("base", {})
	var lines := answer_lines(str(card.get("id", "")))
	var fight_base: float = clampf(float(base.get(card_fight, 0.5)) + 0.05, 0.2, 0.9)
	var run_base: float = clampf(float(base.get(card_run, 0.5)), 0.2, 0.9)
	var roles: Dictionary = {fight: ROLE_FIGHT, run: ROLE_RUN, out: ROLE_SURRENDER}
	var deterministic: Array = [out]
	var give_up := {"deterministic": {"health": 0, "cash_fraction": 0.5, "goods_fraction": 0.5}}
	var first_choices: Array = [fight]
	if not run.is_empty():
		first_choices.append(run)
	if not out.is_empty():
		first_choices.append(out)
	var first_effects := {
		fight: {
			"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "grant_cash": 10},
			"messy": {"escalate": true},
			"failure": {"escalate": true},
			"catastrophic": {"health": 9, "cash_fraction": 0.5, "goods_fraction": 0.25},
		},
	}
	if not run.is_empty():
		first_effects[run] = {
			"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
			"messy": {"health": 2, "cash_fraction": 0.0, "goods_fraction": 0.0},
			"failure": {"escalate": true},
			"catastrophic": {"health": 7, "cash_fraction": 0.5, "goods_fraction": 0.25},
		}
	if not out.is_empty():
		first_effects[out] = give_up
	var second_choices: Array = [fight]
	if not out.is_empty():
		second_choices.append(out)
	var second_effects := {
		fight: {
			"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0, "grant_cash": 15},
			"messy": {"health": 3, "cash_fraction": 0.0, "goods_fraction": 0.0},
			"failure": {"health": 6, "cash_fraction": 0.25, "goods_fraction": 0.0},
			"catastrophic": {"health": 11, "cash_fraction": 0.5, "goods_fraction": 0.5},
		},
	}
	if not out.is_empty():
		second_effects[out] = give_up
	return {
		"answer": true,
		"cap": 2,
		"left_label": "STILL COMING",
		"open_line": str(lines.get("open", "")),
		"won_line": str(lines.get("won", "")),
		"ran_line": str(lines.get("ran", "")),
		"stalemate": {"line": "You both stop. Nobody won it, and everybody watching knows that.",
			"effects": {"health": 3, "cash_fraction": 0.0, "goods_fraction": 0.0}},
		"beats": [
			{
				"beat": str(lines.get("beat", "")),
				"log": "He came at you. You are still standing.",
				"left": 1,
				"choices": first_choices,
				"roles": roles,
				"deterministic": deterministic,
				"base": {fight: fight_base, run: run_base} if not run.is_empty() else {fight: fight_base},
				"banked": 2,
				"effects": first_effects,
			},
			{
				"beat": str(lines.get("beat2", "")),
				"log": "He is hurt and still coming.",
				"left": 1,
				"choices": second_choices,
				"roles": roles,
				"deterministic": deterministic,
				"base": {fight: clampf(fight_base + 0.1, 0.2, 0.95)},
				"banked": 3,
				"effects": second_effects,
			},
		],
	}

static func card_by_id(card_id: String) -> Dictionary:
	for card in CARDS:
		if str(card["id"]) == card_id:
			return card
	return {}

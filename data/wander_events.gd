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
## A card whose whole payload is telling you something true. See INTENT_READ.
const KIND_READ := "read"

const SPENARD := "north_star_lot"
const DOWNTOWN := "downtown"
const SHIP_CREEK := "airport_industrial"

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
const DISCOVERY_JOBS: Array[String] = ["juan_warehouse", "ship_creek"]

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
const GATE_BASE_CHANCE := 0.03
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
]

## The chance this walk's gate opens, given the total attention steps
## `wander.gd` has already counted. Clamped at the authored floor and
## ceiling — never truly zero (every walk rolls, per STR-D1), never a
## guarantee (the streak cap is what guarantees, not this number).
static func gate_chance(total_steps: int) -> float:
	return clampf(GATE_BASE_CHANCE + GATE_PER_STEP_CHANCE * float(maxi(0, total_steps)),
		GATE_BASE_CHANCE, GATE_CAP)

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
		"requirements": [{"type": "collection_non_empty", "collection": "inventory"}],
		"line": "Two of them peel off the wall as you pass, and one is already talking.",
		"encounter": {
			"definition_id": "wander_shakedown",
			"opponent": "Two off the wall",
			"shape": "confrontation",
			"choices": ["stand", "walk", "hand_over"],
			# SQ-D6. This card already offered all three positions; the roles
			# make that structural instead of coincidental.
			"roles": {"stand": ROLE_FIGHT, "walk": ROLE_RUN,
				"hand_over": ROLE_SURRENDER},
			# SQ-D9: two of them on a corner is exactly the situation Tone's
			# own terms describe -- he is told when something has already
			# started, not aimed at something you are starting.
			"admits_crew": true,
			"deterministic": ["hand_over"],
			"base": {"stand": 0.45, "walk": 0.60},
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
			"choices": ["talk", "keep_walking", "hands_out"],
			"roles": {"talk": ROLE_FIGHT, "keep_walking": ROLE_RUN,
				"hands_out": ROLE_SURRENDER},
			"admits_crew": false,
			"deterministic": ["hands_out"],
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
		"line": "Somebody who works the block for Curtis falls in beside you. He already has a number in mind.",
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
		"requirements": [],
		"line": "A couple of them post up across the street, not hiding that they are watching. They want to see what you do.",
		"encounter": {
			"definition_id": "wander_young_ones",
			"opponent": "The kids across the street",
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
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		# The one card in the roster that requires a history. A warrant check
		# on somebody who has never been booked is not a warrant check.
		"requirements": [{"type": "fact_true", "fact": "has_priors"}],
		"line": "He takes your name to the car and does not come straight back.",
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
		"line": "He was talking before he got to you and has not stopped since. His hands will not stay still.",
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
		"requirements": [],
		"line": "Two of them are already arguing about something that has nothing to do with you, on the side of the lot you have to walk past.",
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
			"choices": ["put_them_down", "go_around", "hands_up"],
			"roles": {"put_them_down": ROLE_FIGHT, "go_around": ROLE_RUN,
				"hands_up": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["hands_up"],
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
			},
			"effects": {
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
		"requirements": [],
		"line": "Something already happened here. You did not see it, and the people who did are looking at you.",
		"encounter": {
			"definition_id": "wander_wrong_place",
			"opponent": "Whoever was already here",
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
		"id": "wander_mistaken_identity", "kind": KIND_ENCOUNTER, "weight": 8,
		"intents": [], "gate_bias": "",
		"districts": [], "slots": [], "once": false,
		"requirements": [],
		"line": "He says your name. It is not your name, and he is very sure about it.",
		"encounter": {
			"definition_id": "wander_mistaken_identity",
			"opponent": "The man who is sure",
			"shape": "negotiation",
			"choices": ["set_him_straight", "let_him_talk", "be_who_he_wants"],
			"roles": {"set_him_straight": ROLE_FIGHT, "let_him_talk": ROLE_RUN,
				"be_who_he_wants": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["be_who_he_wants"],
			"base": {"set_him_straight": 0.60, "let_him_talk": 0.52},
			"observations": {
				"set_him_straight": {
					"clean": {"type": "honesty", "event": "cleared_it_up"},
					"messy": {"type": "honesty", "event": "cleared_it_up"},
					"failure": {"type": "violence", "event": "street_fight"},
					"catastrophic": {"type": "violence", "event": "street_fight"},
				},
				"let_him_talk": {
					"clean": {"type": "discretion", "event": "walked_it_off"},
					"messy": {"type": "discretion", "event": "walked_it_off"},
					"failure": {"type": "honesty", "event": "wore_somebody_elses_name"},
					"catastrophic": {"type": "honesty", "event": "wore_somebody_elses_name"},
				},
				# Answering to a name that is not yours is a lie the street
				# can check later, and it is the road that carries the debt.
				"be_who_he_wants": {"type": "honesty", "event": "wore_somebody_elses_name"},
			},
			"effects": {
				"set_him_straight": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 2, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"failure": {"health": 6, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"catastrophic": {"health": 12, "cash_fraction": 0.25, "goods_fraction": 0.0},
				},
				"let_him_talk": {
					"clean": {"health": 0, "cash_fraction": 0.0, "goods_fraction": 0.0},
					"messy": {"health": 0, "cash_fraction": 0.25, "goods_fraction": 0.0},
					"failure": {"health": 3, "cash_fraction": 0.5, "goods_fraction": 0.0},
					"catastrophic": {"health": 8, "cash_fraction": 1.0, "goods_fraction": 0.25},
				},
				# Whatever the other man owed, you just agreed to.
				"be_who_he_wants": {
					"deterministic": {"health": 0, "cash_flat": 60, "goods_fraction": 0.0},
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
		"requirements": [{"type": "fact_true", "fact": "market_pressure_visible"}],
		"line": "They know what you have been doing on this block, and they have decided it is their block.",
		"encounter": {
			"definition_id": "wander_territorial_beef",
			"opponent": "The ones who work this block",
			"shape": "confrontation",
			"choices": ["it_is_my_block", "not_today", "off_the_block"],
			"roles": {"it_is_my_block": ROLE_FIGHT, "not_today": ROLE_RUN,
				"off_the_block": ROLE_SURRENDER},
			"admits_crew": true,
			"deterministic": ["off_the_block"],
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
			},
			"effects": {
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
		"requirements": [{"type": "fact_true", "fact": "curtis_visible"}],
		"line": "Somebody is getting worked over half a block up, and one of them has already looked at you twice.",
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
]

## Player-facing copy for the encounter choices, in the two shapes the screen
## needs: the button, and the line under it.
##
## Both are reached through the engine's adapter seam. Before that seam existed
## Wander shipped with FOUR of its five choices rendering an EMPTY description
## and the fifth inheriting Boost's — `talk` read "Hand it back and try to keep
## this from turning physical", which is nothing you can do to a cruiser. The
## engine's own table is Boost's vocabulary (fight / run / talk / yield) and was
## never going to cover a different chain's.
const CHOICE_LABELS := {
	"stand": "STAND THERE",
	"walk": "KEEP MOVING",
	"hand_over": "GIVE IT UP",
	"talk": "TALK TO THEM",
	"keep_walking": "DO NOT STOP",
	# SQ-D6's two missing surrender roads, and the run road Curtis's man never
	# had. Labels stay in each card's own voice -- the ROLE is the thing the
	# chassis reads, and it is not any of these strings.
	"hands_out": "HANDS OUT",
	"keep_pace": "KEEP YOUR PACE",
	"cross_the_street": "CROSS THE STREET",
	# Duplicated from SCRIPTS.STASH_IT's own "label" rather than read off it:
	# GDScript's const initializer must be a compile-time-foldable expression,
	# and a cross-script dictionary subscript is not one. The value this
	# duplicates is asserted equal to the source in the suite, so the two
	# cannot drift silently.
	"stash_it": "STASH IT",
	"pay_it": "PAY IT",
	"push_back": "PUSH BACK",
	"hold_steady": "HOLD STEADY",
	"stare_back": "STARE BACK",
	# The shakedown room's verbs. SQ-D7 replaced 0.5.0's single KEEP FIGHTING
	# (which re-rolled STAND at decaying odds) with the triad, offered fresh
	# against each authored beat: SWING is the fight, BREAK FOR IT is the run
	# where the beat still has one, GIVE IT UP is the guaranteed out mid-fight
	# — the same shape HAND OVER already is at the door.
	"swing": "SWING",
	"break_for_it": "BREAK FOR IT",
	"give_it_up": "GIVE IT UP",
	# SQ-D9's chassis actions. Copy is `CREW_CALLS`' own; the labels are here
	# because this is where the wander adapter looks its buttons up.
	"call_tone": "CALL TONE",
	"let_deshawn_talk": "LET DESHAWN TALK",
	# --- 0.6.0 PR C: the roster's own vocabulary -------------------------------
	# Twenty-four labels, three per card, and not one of them is the word
	# "fight", "run" or "surrender". That is SQ-D6 working: the role is the
	# structural position and the label is what this particular situation
	# actually offers you.
	"ask_why": "ASK WHY",
	"roll_slow": "ROLL IT DOWN SLOW",
	"open_it_up": "OPEN IT UP",
	"give_a_name": "GIVE HIM A NAME",
	"walk_now": "WALK NOW",
	"wait_it_out": "WAIT IT OUT",
	"shut_it_down": "SHUT IT DOWN",
	"keep_moving_past": "KEEP MOVING",
	"give_him_something": "GIVE HIM SOMETHING",
	"put_them_down": "PUT THEM DOWN",
	"go_around": "GO AROUND",
	"hands_up": "HANDS UP",
	"say_your_piece": "SAY YOUR PIECE",
	"keep_it_moving": "KEEP IT MOVING",
	"back_out": "BACK OUT",
	"set_him_straight": "SET HIM STRAIGHT",
	"let_him_talk": "LET HIM TALK",
	"be_who_he_wants": "BE WHO HE WANTS",
	"it_is_my_block": "IT IS MY BLOCK",
	"not_today": "NOT TODAY",
	"off_the_block": "OFF THE BLOCK",
	"step_in": "STEP IN",
	"cross_over": "CROSS OVER",
	"look_away": "LOOK AWAY",
}

const CHOICE_COPY := {
	"stand": "Make them decide how much they want it. Costs blood if they do.",
	"walk": "Keep the bag and keep going. It works until it does not.",
	"hand_over": "Hand it over and walk away whole. You lose what you are carrying.",
	"talk": "Answer what they ask and nothing else. Charisma, not speed.",
	"keep_walking": "Do not stop and do not run. Either one is an answer.",
	# Same duplication, same reason — see CHOICE_LABELS's own note above.
	"stash_it": "Product goes somewhere that is not on you. Fast hands, faster story.",
	"pay_it": "The toll on a corner you do not own. Cheap, considering.",
	"push_back": "Tell him the corner does not have your name on it either.",
	"hold_steady": "Do not blink first. That is the whole test.",
	"stare_back": "Make them remember whose block this is too.",
	"hands_out": "Hands where they can see them. It ends on their terms, and it ends.",
	"keep_pace": "Same speed, same direction, no answer. See if that is allowed.",
	"cross_the_street": "Give them the block. It costs nothing you can count.",
	"swing": "Hit first and keep hitting. This is not a conversation any more.",
	"break_for_it": "One gap, one chance. Take it before it closes.",
	"give_it_up": "Whatever you are holding stops being worth this.",
	"call_tone": "He ends it by standing there. Costs a favor.",
	"let_deshawn_talk": "His voice, not yours. Everybody walks.",
	# VOX-D1: short declaratives, terms rather than threats, and the addict
	# lines carry no comedy and no pity.
	"ask_why": "Make him say the reason out loud. Sometimes there is not one.",
	"roll_slow": "Two inches of window and every answer already ready.",
	"open_it_up": "Trunk, doors, all of it. It ends when they are finished.",
	"give_a_name": "A name that is close enough to be boring. Boring gets waved through.",
	"walk_now": "Before the computer finishes. Every second is worse odds.",
	"wait_it_out": "Stand there and let it come back. It will come back.",
	"shut_it_down": "End the conversation. He will not end it himself.",
	"keep_moving_past": "Do not slow down and do not answer. He loses interest or he does not.",
	"give_him_something": "Twenty dollars is cheaper than the next ten minutes.",
	"put_them_down": "Neither of them is in any state to stop you. Everybody on this lot will see it.",
	"go_around": "Long way, well lit, nobody's business but yours.",
	"hands_up": "Whatever is on you is theirs. Nobody swings.",
	"say_your_piece": "Tell them what you did and did not see. Hope it lands.",
	"keep_it_moving": "You were never here. Act like it.",
	"back_out": "The way you came, at the speed you came. Nothing lost but the walk.",
	"set_him_straight": "Tell him whose name it is. He is going to argue.",
	"let_him_talk": "Let him finish and find out what the other man owes.",
	"be_who_he_wants": "Answer to it. Whatever that man owed, you just agreed to.",
	"it_is_my_block": "You have been working it. That is the argument.",
	"not_today": "Not the day for it. There will be another block.",
	"off_the_block": "Agree not to work here. Leave what you brought.",
	"step_in": "It is not your problem until you make it yours.",
	"cross_over": "Other side of the street, same pace, eyes forward.",
	"look_away": "Somebody is going to remember that you saw.",
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
	"be_who_he_wants": "Guaranteed: $60. Whatever that other man owed is yours now.",
	"off_the_block": "Guaranteed: no injury. Half of what you brought stays on this corner.",
	"look_away": "Guaranteed: nothing happens to you at all. Somebody will remember that you saw.",
	"call_tone": "Guaranteed: it ends. It costs a favor you will want back later.",
	"let_deshawn_talk": "Guaranteed: everybody walks, and you keep what you were carrying.",
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
	"wander_mistaken_identity": {
		"set_him_straight": {
			"clean": ["HE SEES IT", "Something in your face finally does not match. He apologizes the way a man apologizes to someone he almost hit."],
			"messy": ["HE HALF BELIEVES YOU", "He backs off with a shove and a look. He is not sure. He is going to keep not being sure."],
			"failure": ["HE DOES NOT BUY IT", "Whoever you are, you are the one in front of him. The other man's beating finds a home."],
			"catastrophic": ["THE OTHER MAN'S DEBT", "You paid it in full, in the currency he came to collect. He goes through your pockets for the interest."],
		},
		"let_him_talk": {
			"clean": ["HE TALKS HIMSELF OUT OF IT", "You let him finish. Somewhere in the middle he says a detail that does not fit, and he hears it too."],
			"messy": ["HE TAKES A DEPOSIT", "He is not sure enough to hurt you and not unsure enough to leave. He takes some money on account."],
			"failure": ["HE COLLECTS", "The other man owed him. Now you do, and he takes it in cash while you are still deciding what to say."],
			"catastrophic": ["HE COLLECTS ALL OF IT", "Whatever the other man owed, you had it on you, and now you do not. He hits you once on the way out, for the other man."],
		},
		"be_who_he_wants": {
			"deterministic": ["YOU ANSWER TO IT", "You take a name that is not yours and pay the debt that came with it. He will remember the face he collected from."],
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
	var card_table: Dictionary = RESULT_COPY.get(card_id, {})
	var table: Dictionary = card_table.get("room", {}) if in_room else card_table
	var road: Dictionary = table.get(choice_id, {})
	if road.has(tier):
		return road[tier]
	if road.has("*"):
		return road["*"]
	return []

static func card_by_id(card_id: String) -> Dictionary:
	for card in CARDS:
		if str(card["id"]) == card_id:
			return card
	return {}

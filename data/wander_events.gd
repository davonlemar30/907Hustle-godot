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
				"hold_steady": {"type": "discretion", "event": "walked_it_off"},
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
}

static func card_by_id(card_id: String) -> Dictionary:
	for card in CARDS:
		if str(card["id"]) == card_id:
			return card
	return {}

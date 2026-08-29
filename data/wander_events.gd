extends RefCounted
## The Wander card registry — what is out there when you go and look.
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
		"districts": [], "slots": [], "requirements": [], "once": false,
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
	{
		"id": "wander_shakedown", "kind": KIND_ENCOUNTER, "weight": 7,
		"intents": [INTENT_DEAL],
		"districts": [], "slots": [EVENING, NIGHT], "once": false,
		"requirements": [{"type": "collection_non_empty", "collection": "inventory"}],
		"line": "Two of them peel off the wall as you pass, and one is already talking.",
		"encounter": {
			"definition_id": "wander_shakedown",
			"opponent": "Two off the wall",
			"shape": "confrontation",
			"choices": ["stand", "walk", "hand_over"],
			"deterministic": ["hand_over"],
			"base": {"stand": 0.45, "walk": 0.60},
		},
	},
	{
		"id": "wander_stopped_on_foot", "kind": KIND_ENCOUNTER, "weight": 9,
		"intents": [],
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
			"choices": ["talk", "keep_walking"],
			"deterministic": [],
			"base": {"talk": 0.62, "keep_walking": 0.48},
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
}

const CHOICE_COPY := {
	"stand": "Make them decide how much they want it. Costs blood if they do.",
	"walk": "Keep the bag and keep going. It works until it does not.",
	"hand_over": "Hand it over and walk away whole. You lose what you are carrying.",
	"talk": "Answer what they ask and nothing else. Charisma, not speed.",
	"keep_walking": "Do not stop and do not run. Either one is an answer.",
}

func card_by_id(card_id: String) -> Dictionary:
	for card in CARDS:
		if str(card["id"]) == card_id:
			return card
	return {}

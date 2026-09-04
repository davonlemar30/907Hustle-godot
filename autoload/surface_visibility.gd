extends Node
## SurfaceVisibility — the access layer. One answer to "may the player see this,
## and may they use it", for every surface that can be gated.
##
## Authored against the Lightweight Design Pass (Progression Gate Architecture).
## The path it prescribes, and the one this file completes:
##
##   GameState / owning systems
##     -> progression facts adapter   (`facts()`, below)
##     -> requirements evaluator      (`systems/requirements.gd`, unchanged)
##     -> access registry             (`GATES`, below)
##     -> UI + ScreenManager          (`is_unlocked` / `is_visible` / `verdict`)
##
## ## There is no second eligibility engine here
##
## That is the first architectural invariant of the design pass, and it is the
## reason this file is as short as it is. It owns no condition logic: a gate is
## a list of SEMANTIC REQUIREMENT RECORDS, and `Requirements.evaluate_requirements`
## decides them — the same evaluator, with the same fail-closed behaviour and the
## same authored blocker ordering, that Named Crew Operations already uses.
##
## ## Two modes, one verdict
##
##   LOCKED  the player knows it exists and has not earned it. Rendered at 40%
##           with a padlock and one line of hint text; a tap does nothing.
##   HIDDEN  there is nothing there. The node leaves the layout entirely.
##
## The mode is PRESENTATION METADATA. It changes how a failed gate looks, never
## whether it passes — so a surface can move from hidden to locked without any
## screen learning a new condition, which is exactly what batch 14 did to the
## Market Snapshot in one line.
##
## v0.1.0 drew the line as "progression is LOCKED, population is HIDDEN".
## Batch 14 moved it, and the amended rule is worth stating because it is not
## the obvious one: LOCKED is for a surface the player is MEANT TO KNOW ABOUT
## and has not earned. A padlock is a promise, and a promise is only worth
## making about a thing the player can go and do something about.
##
## Jobs is the case that still earns it — "meet someone who hires" is an
## instruction, and Jobs is the authored on-ramp. The Hustle ladder's other five
## rows are not: six padlocks on a fresh run is the same wall of unusable
## surface with an apology written on it, and none of the hints would have been
## actionable. The Market Snapshot failed the rule the other way — it was a
## padlock over a card of real product names and real prices, which reads as a
## broken feature rather than a coming one.
##
## So: a lock teaches that something is coming and how to reach it. Everything
## else — an empty feed, a card with nothing to say, a surface the block has not
## shown you yet — is HIDDEN.
##
## ## Nothing derived is stored
##
## Every answer is computed from live GameState on the call. There is no
## `unlocked` boolean anywhere, which is what makes "unlocks survive save/load"
## true by construction rather than by a migration: the facts persist, the
## verdicts do not. The facts that ARE persisted — `districts_unlocked`,
## `job_contacts`, and `boost_targets_discovered` since batch 14 — are one-way
## discovery latches owned by GameState, not copies of a condition that could
## contradict it. The distinction is worth keeping sharp: a latch records
## something that HAPPENED, and a verdict is an opinion about what that means.
## Only the first kind belongs in a save file.
##
## ## Read-only, always
##
## This service never mutates GameState and never dispatches. UI reads it; it
## reads GameState. That is the whole of its relationship with the rest of the
## build.

const REQUIREMENTS := preload("res://systems/requirements.gd")

## Presentation modes. `mode` on a gate takes one of these.
const MODE_LOCKED := "locked"
const MODE_HIDDEN := "hidden"

## Access states, the design pass's four. `temporarily_blocked` is declared and
## unused this build: no current gate reads a condition that can go false again
## (both persisted facts are latches). It stays in the vocabulary so the first
## gate that needs it does not have to invent the concept.
const STATE_AVAILABLE := "available"
const STATE_LOCKED := "locked"
const STATE_HIDDEN := "hidden"
const STATE_TEMPORARILY_BLOCKED := "temporarily_blocked"

# --- surface ids -----------------------------------------------------------
#
# Namespaced by where the player meets them, per the design pass. Constants
# rather than bare strings so a typo is a parse error in the screen that made
# it, not a gate that silently answers "unknown surface".

const HOME_MARKET_SNAPSHOT := "home.market_snapshot"
const HOME_TURF_CREW := "home.turf_crew"
const HOME_TONIGHTS_OPERATION := "home.tonights_operation"
const HOME_ACTIONS := "home.actions"
const HOME_TEXT_MESSAGES := "home.text_messages"
const HOME_ACTIVITY_FEED := "home.activity_feed"
const MENU_CREW := "menu.crew"
const MENU_JOBS := "menu.jobs"
## The Hustle hub's six income rows. Jobs already had a gate; batch 14 gives the
## other five one each, so the hub opens a surface at a time instead of handing
## a Day 1 player six doors and no reason to pick any of them.
const HUSTLE_MARKET := "hustle.market"
const HUSTLE_LIST := "hustle.list"
const HUSTLE_BOOST := "hustle.boost"
const HUSTLE_STICKUP := "hustle.stickup"
const HUSTLE_SHARK := "hustle.shark"
const STREET_DOWNTOWN := "street.downtown"
const STREET_SHIP_CREEK := "street.ship_creek"
const STREET_MOUNTAIN_VIEW := "street.mountain_view"

## The access registry: what each surface requires, and how a failure looks.
##
## This is CONFIGURATION, not a system. Every entry is
##
##   {mode, requirements, hint}
##
## `requirements` is handed to the evaluator verbatim and its ORDER is the
## authored blocker priority — the evaluator stops at the first failure, so the
## player is shown the same reason every time for the same state. `hint` is the
## one line rendered under a locked surface; the access layer does not
## manufacture copy beyond it, and a hidden surface has none because nobody sees
## a hidden surface.
##
## Jasmine's design pass authored the triggers. Two are written against district
## IDs rather than the pass's shorthand ("downtown"/"industrial"/"spenard"):
## `north_star_lot` and `airport_industrial` are the ids GameState, the market,
## the pressure ledger and the save already use, and a second vocabulary of
## friendly names would be one rename away from gating nothing at all.
const GATES := {
	# --- progression gates: LOCKED --------------------------------------
	MENU_CREW: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "crew_count_min", "min": 1}],
		"hint": "Recruit your first crew member",
	},
	# WS-D1 (0.8.0): the door opens on KNOWING a place that hires, and a
	# fresh run knows one -- the Wash & Go Yalonda vouches for. It used to
	# need a contact, and the playtest defect was a run that knew five places
	# and could reach none of them. The lock stays authored so a save that
	# somehow knows nothing still reads the hint.
	MENU_JOBS: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "collection_non_empty", "collection": "jobs_known"}],
		"hint": "Find work on the block, or meet someone who hires",
		"announce": "Somebody will vouch for you now. There is work on the board.",
		"card_title": "WORK IS ON THE BOARD",
	},
	STREET_DOWNTOWN: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "district_discovered", "district_id": "downtown"}],
		"hint": "Hold a corner before the city opens up",
		"announce": "Downtown is worth the bus fare now. Different prices, different people.",
		"card_title": "DOWNTOWN UNLOCKED",
		"card_icon": "res://assets/icons/nav/icon-street.webp",
	},
	STREET_SHIP_CREEK: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "district_discovered",
			"district_id": "airport_industrial"}],
		"hint": "Hold two corners before the port is worth the trip",
		"announce": "Ship Creek is on the map. The yards run all night out there.",
		"card_title": "SHIP CREEK UNLOCKED",
		"card_icon": "res://assets/icons/nav/icon-street.webp",
	},
	STREET_MOUNTAIN_VIEW: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "district_discovered", "district_id": "mountain_view"}],
		"hint": "Get established in Spenard before the block will have you",
		"announce": "Mountain View is on the map. Forty languages, one set of eyes, and pills that pay.",
		"card_title": "MOUNTAIN VIEW UNLOCKED",
		"card_icon": "res://assets/icons/nav/icon-street.webp",
	},

	# --- population / feature flags: HIDDEN -----------------------------
	#
	# The Market Snapshot moved here in batch 14, from LOCKED. A padlock is a
	# promise that something is coming, and playtest read this one as a bug
	# instead: three greyed rows of product names with prices under them, on a
	# card headed by a number, on Day 1, before the player has traded once. The
	# lock said "earn this" and the content said "here is your portfolio", and
	# the content won. There is nothing to snapshot until there has been a flip,
	# so until then there is no card — which is the HIDDEN argument exactly.
	HOME_MARKET_SNAPSHOT: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "list_flips_min", "min": 1}],
		"hint": "",
	},
	HOME_TONIGHTS_OPERATION: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "fact_true", "fact": "operation_card_live"}],
		"hint": "",
	},
	# The two standing actions, batch 14. They lived on the operation card until
	# now, which meant they inherited its visibility — and its visibility is
	# "there is an operation out, or rent is close, or a shift is workable".
	# None of those is true on a fresh run, so POST ELI and LAY LOW were
	# UNREACHABLE from Home for exactly as long as the operation card was
	# hidden, which is the part of the run a player most needs a door out of.
	#
	# Their own card, on their own condition. Still HIDDEN rather than LOCKED:
	# neither is a progression reward the player is meant to see coming, and a
	# padlock reading "recruit Eli first" on a screen that has not introduced
	# Eli is a promise about a stranger.
	HOME_ACTIONS: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "collection_non_empty", "collection": "home_actions"}],
		"hint": "",
	},
	HOME_TEXT_MESSAGES: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "collection_non_empty", "collection": "phone_messages"}],
		"hint": "",
	},
	HOME_ACTIVITY_FEED: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "collection_non_empty", "collection": "activity_log"}],
		"hint": "",
	},

	# 0.1.2 playtest: a padlocked Turf & Crew card on Day 1 promised territory
	# and a roster the player cannot act on yet -- recruiting crew is the gate,
	# not a countdown to it, so this follows Market Snapshot's HIDDEN argument
	# rather than staying LOCKED.
	HOME_TURF_CREW: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "crew_count_min", "min": 1}],
		"hint": "",
	},

	# --- the Hustle ladder: HIDDEN --------------------------------------
	#
	# Every income surface in the build was on the Hustle screen on Day 1, and
	# playtest is unambiguous about what that produced: six rows, no order, and
	# a first hour spent reading rather than doing. The hub is the game's widest
	# screen and it was also its flattest.
	#
	# HIDDEN rather than LOCKED, and that is the one decision worth arguing.
	# Jobs keeps its lock because Jobs is the authored on-ramp — the player is
	# meant to know work exists and go and find somebody who hires. The other
	# five are not promises, they are things the block has not shown you yet,
	# and six padlocks on a fresh run is the same wall of unusable surface with
	# an apology written on it. So the rows leave the layout and arrive one at a
	# time, each on a fact the player can feel themselves producing.
	#
	# Two axes on purpose. WALKS gate the two surfaces you find by being out —
	# the corner you buy from, and the doors you notice are unlatched. DAYS gate
	# the three that arrive because time passed and word got around: the board,
	# the desperation, and the man who lends. Neither axis is a substitute for
	# the other, which is what keeps a player who only walks and a player who
	# only sits from converging on the same screen.
	# fact_true rather than its WALKS-axis sibling's wander_count_min: Market
	# used to open on the FIRST wander of every run, deterministically, which
	# playtest read as scripted rather than found. `market_discovered` is a
	# seeded event WanderSystem can fire on any walk (not just the first) —
	# the requirement type had to change because the fact behind it is no
	# longer a count, it is a coin WanderSystem flips.
	HUSTLE_MARKET: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "fact_true", "fact": "market_discovered"}],
		"hint": "",
		"announce": "You know where the corner is now. Street Market is on the board.",
		"card_title": "STREET MARKET UNLOCKED",
		"card_icon": "res://assets/icons/nav/icon-market.svg",
	},
	# WS-D1 (0.8.0): the three rows below stopped being clocks. A day count
	# and a walk count opened every criminal surface in the first three days
	# whether or not the city had shown the player anything, and the playtest
	# read exactly that -- "everything unlocks at once". Each row now opens on
	# a DISCOVERY the run has actually made (`hustles_discovered`): the first
	# loose rack, a desperate afternoon or a kid at an ATM, somebody who
	# trusts you mentioning the board. The moments themselves are authored in
	# `data/wander_events.gd` (the meeting cards) and `systems/wander.gd`.
	HUSTLE_LIST: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "hustle_discovered", "hustle": "list"}],
		"hint": "",
		"announce": "Somebody trusted you with the board. 907List is on it.",
		"card_title": "907LIST UNLOCKED",
	},
	HUSTLE_BOOST: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "hustle_discovered", "hustle": "boost"}],
		"hint": "",
		"announce": "You saw how loose a rack can be. Boost is on the board.",
		"card_title": "BOOST UNLOCKED",
	},
	HUSTLE_STICKUP: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "hustle_discovered", "hustle": "stickup"}],
		"hint": "",
		"announce": "You know how fast it happens now. Stickup is on the board, for what that is worth.",
		"card_title": "STICKUP UNLOCKED",
	},
	HUSTLE_SHARK: {
		"mode": MODE_HIDDEN,
		# Replaces the elapsed-day gate (design doc: "time passing does not
		# explain why Dre trusts the player with his borrower network").
		# Junior Lender, OR the one PR E exception a live `dre_book_
		# sponsorship` opens early — `dre_book_visible` folds both into one
		# fact (see its own comment above). Deliberately not combined with
		# `dre_account_clear`; see `requirements.gd`'s header on why a route
		# gate never reads a field that moves backward.
		"requirements": [{"type": "fact_true", "fact": "dre_book_visible"}],
		"hint": "",
		# PR E re-copy, Dre's own voice (DRE-ARC-04) — the old day-5
		# placeholder ("You know who lends now...") never shipped where a
		# player could see it.
		#
		# Fires the moment `dre_book_visible` flips, which is now the
		# sponsorship offer for a Collector on that road, not only true
		# tier-4 completion — deliberate, not an early-fire bug. Every other
		# card in this table already celebrates a SURFACE becoming reachable
		# (a discovery), not a mastery milestone: `HUSTLE_MARKET` fires on
		# one seeded wander, `HUSTLE_BOOST` on a wander count, neither on
		# some later "and you used it well." A player who sees this the
		# moment Priya's offer lands is seeing an honest, earlier truth —
		# the screen really is reachable now, four locked strangers and one
		# name he vouched for — not a lie the milestone has to catch up to.
		"announce": "Your name's in the Book now. That's not nothing.",
		"card_title": "THE BOOK IS YOURS",
	},
}

## Which surface guards which route, so route entry and the visible button
## cannot disagree (design pass, Improvement 2). Read by ScreenManager.
##
## Keyed by scene path because that is what `go_to` is handed — a nav cell, a
## deep link and a debug jump all arrive as a path, and all three get the same
## answer.
## Batch 15 completes the table. Batch 14 gated five Hustle rows and stopped at
## the button, which is precisely the half-measure this map exists to prevent:
## `More -> Finances` is a second door onto the Shark screen and it opened on a
## fresh run while the Hustle row hid until day 5. Two entrances, two answers.
##
## Every gate on this ladder is MONOTONIC — days and walks only ever go up — so
## a route cannot be refused after the player has already been through it. That
## matters for one caller in particular: `consequence.gd` sends the player back
## to where a chain started, and a gate that could re-close would strand them on
## a screen with no navigation. The consequence screen falls back to Home now
## rather than relying on that property holding forever, but the property is real
## and is the reason adding these five is safe today.
const ROUTE_GATES := {
	"res://ui/screens/crew.tscn": MENU_CREW,
	"res://ui/screens/jobs.tscn": MENU_JOBS,
	"res://ui/screens/market.tscn": HUSTLE_MARKET,
	"res://ui/screens/nine07list.tscn": HUSTLE_LIST,
	"res://ui/screens/boost.tscn": HUSTLE_BOOST,
	"res://ui/screens/stickup.tscn": HUSTLE_STICKUP,
	"res://ui/screens/shark.tscn": HUSTLE_SHARK,
}

var gs: Node

func _ready() -> void:
	gs = get_node("/root/GameState")

# --- the progression facts adapter -----------------------------------------

## Canonical GameState, translated once into the semantic facts the evaluator
## reads. The one seam between "what the run holds" and "what a gate asks".
##
## Public because it is the shared adapter the design pass asks for: any future
## caller that needs to evaluate a requirement against the run gets its facts
## here rather than reaching into GameState and inventing its own idea of what
## "has crew" means. Read-only — it allocates a Dictionary and touches nothing.
##
## `crew_operations.gd::_facts()` is the older, narrower version of this seam and
## still serves delegation; folding the two together is a follow-up, not a
## v0.1.0 change, because that file's facts are load-bearing for FS-001 parity.
func facts() -> Dictionary:
	if gs == null:
		return {}
	return {
		"current_day": gs.day,
		"time_slots_today": gs.time_slots_today,
		"crew_count": gs.recruited_crew().size(),
		"districts_unlocked": gs.districts_unlocked,
		"list_flips": gs.list_flips,
		"job_contacts": gs.job_contacts,
		# Walks taken this RUN. The Hustle ladder's effort axis — see GATES.
		"wander_count": gs.wander_count,
		# Boost targets the player has actually clocked. No gate reads it yet;
		# it is minted here because the discovery latch it reports is the same
		# shape as `districts_unlocked` and belongs in the one adapter rather
		# than being reached for out of GameState by whoever needs it first.
		"boost_targets_discovered": gs.boost_targets_discovered.size(),
		# The Market discovery latch (PR 4). A named boolean rather than a
		# population, for `fact_true` — HUSTLE_MARKET's own gate.
		"market_discovered": bool(gs.market_discovered),
		# WS-D1 (0.8.0): the hustle latches, for `hustle_discovered`.
		"hustles_discovered": gs.hustles_discovered,
		# WS-D1: doors onto work -- places that hire the run has heard of
		# (Yalonda's Wash & Go on day one, then one at a time by walking)
		# PLUS the people who connect you to it. Either kind opens the Jobs
		# door; a contact still counts the way it did before the reveal.
		"jobs_known": gs.jobs_discovered.size() + int(gs.job_contacts),
		# Populations. Named for the surface that reads them, not the field
		# that backs them, so a rename on GameState is one line here.
		#
		# `phone_messages` counts everything the Home phone card exists to
		# report, which is a message waiting -- live OR held behind a dead line
		# -- and the dead line itself. A cut-off phone is a bill with a deadline
		# on it, not an empty inbox, and hiding the card would take away the one
		# place on Home that says so. The count is defined here, once, rather
		# than as an `or` inside the screen.
		"phone_messages": gs.phone_inbox.size() + gs.phone_held_inbox.size() \
			+ (0 if gs.phone_active else 1),
		"activity_log": gs.activity_log.size(),
		# Dre Lending & Loan-Shark Progression, PR B. `dre_access_tier` gates
		# `HUSTLE_SHARK` (design doc §16); `dre_account_status` backs
		# `dre_account_clear` for non-route checks that are allowed to move
		# backward, unlike a route gate — see `requirements.gd`'s own header
		# on why the two are never combined on the same gate.
		"dre_access_tier": gs.dre_access_tier,
		"dre_account_status": str(gs.dre_account.get("status", "clear")),
		# PR E (DRE-ARC-04): the milestone itself IS the borrower's temporary
		# eligibility — design doc §13.2, "ordinary Book access is not
		# required, so the gate is not circular." A Collector with Priya's
		# sponsorship live has to be able to reach the Shark screen to fund
		# her; the ordinary tier-4 latch alone would strand them on a route
		# that refuses the one action their own offer requires. Folded into
		# one precomputed OR here rather than a new requirement type, because
		# `Requirements.evaluate_requirements` ANDs its list and cannot
		# express the OR itself — see `fact_true`'s own header on why this is
		# the escape hatch for exactly that shape, the same move
		# `operation_card_live` already makes two rows up.
		"dre_book_visible": int(gs.dre_access_tier) >= 4 or _dre_book_sponsored(),
		"operation_card_live": not str(operation_card_reason()).is_empty(),
		# A population rather than a boolean, because the SCREEN needs the list
		# and the gate needs its size — and deriving them separately is how a
		# card ends up visible with nothing on it.
		"home_actions": home_actions().size(),
	}

# --- DRE-ARC-04's route exception -------------------------------------------

## True while `dre_book_sponsorship` (data/dre_contracts.gd) is offered or
## active — see the `dre_book_visible` fact above for why this exists.
## Monotonicity caveat, named rather than hidden: this can only run
## true-to-false if the offer is DECLINED before it resolves (resolving
## always raises the tier to 4 in the same call that clears the offer — see
## `Opportunities.resolve()` — so that road never dips). Nothing in this
## build's UI currently offers a decline door for this specific definition
## (no People card exists for it — funding IS the acceptance, same as First
## Money), so the flip side is unreachable today. A future PR that adds one
## must re-examine this the moment it does.
func _dre_book_sponsored() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null:
		return false
	var opportunities: Object = manager.system("opportunities")
	return opportunities != null and opportunities.is_offered_or_active("dre_book_sponsorship")

# --- Home's operation card -------------------------------------------------

## What the card is carrying, or "" when it is carrying nothing.
##
##   "operation"  a named crew operation is out today
##   "rent"       rent lands inside two days and the money is not there
##   "shift"      the player is employed and the shift is workable now
##
## Jasmine's table gates this surface on `crew_operation_state.active_today`,
## and that is the first branch here. The other two exist because the card is
## not only the delegation readout: it is also the only place on Home that
## carries a DEADLINE. Hiding it on a fresh run is right — what stands there
## otherwise is authored scaffold about a probe on Minnesota Off-Ramp that
## nothing in the run ever wrote. Hiding it on the morning rent is due would
## take away the warning that decides whether the run ends.
##
## So the condition is "does this card have something real to say", and it lives
## HERE rather than in the screen for the reason the design pass gives: the
## visible state and the content have to come from one verdict, or a screen ends
## up hiding a card it is simultaneously filling.
##
## `home.gd` reads the reason back to choose copy. It does not re-derive it.
func operation_card_reason() -> String:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null or gs == null:
		return ""
	var ops: Object = manager.system("crew_operations")
	if ops != null:
		for operation_id in ops.operation_ids():
			var summary: Dictionary = ops.operation_summary(str(operation_id))
			if not bool(summary.get("discovered", false)):
				continue
			if bool(summary.get("active_today", false)) \
					or summary.get("last_night") is Dictionary:
				return "operation"
	var obligations: Object = manager.system("obligations")
	if obligations != null and gs.cash < gs.WEEKLY_RENT \
			and int(obligations.days_until_rent()) <= 2:
		return "rent"
	if not str(gs.active_job_id).is_empty():
		var jobs: Object = manager.system("jobs")
		if jobs != null and str(jobs.shift_blocker()).is_empty():
			return "shift"
	return ""

# --- what has just arrived -------------------------------------------------

## Every surface worth telling the player about when it opens, and the line.
##
## The list is not authored separately — it is the gates that carry an
## `announce` key, so "is this worth announcing" sits beside "what does this
## require" and neither can be edited without the other being visible.
##
## Only PROGRESSION gates carry one. A population gate opens because something
## arrived (a text, a feed row, an operation) and the thing that arrived is its
## own announcement; a line saying "you have a text" beside the text is noise.
## An earned surface is the opposite case: nothing else on the screen says that
## a door opened, and after batch 14 five of them open with no padlock to watch.
func announceable() -> Dictionary:
	var out: Dictionary = {}
	for surface_id in GATES:
		var line := str((GATES[surface_id] as Dictionary).get("announce", ""))
		if not line.is_empty():
			out[str(surface_id)] = line
	return out

## Which announceable surfaces are open right now.
##
## A plain snapshot, so a caller can take one before an action and one after and
## diff them. **That is deliberately how "what just opened" is answered, rather
## than by a persisted `announced` set.** This file's founding rule is that
## nothing derived is stored — a stored flag is a second opinion about a
## condition, and it is the one thing that can contradict the run. A transition
## is only meaningful inside the action that caused it, which is exactly where
## the diff is taken.
##
## It also gets loading right for free. A load is not a dispatch, so no snapshot
## is taken across it and a run reloaded on day 20 is told nothing — which is
## correct, because nothing opened.
func unlocked_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for surface_id in announceable():
		out[str(surface_id)] = is_unlocked(str(surface_id))
	return out

## Copy for a discovery card, or {} for a surface with nothing to celebrate
## (unregistered, or registered with no `announce`).
##
## `line` IS the `announce` sentence, not a second line written for the
## card -- one author, so the card a player sees and the activity-feed row
## for the same unlock can never disagree with each other.
func card_for(surface_id: String) -> Dictionary:
	var gate: Variant = GATES.get(surface_id)
	if not (gate is Dictionary):
		return {}
	var rule: Dictionary = gate
	var line := str(rule.get("announce", ""))
	if line.is_empty():
		return {}
	return {
		"title": str(rule.get("card_title", "")),
		"line": line,
		"icon": str(rule.get("card_icon", "")),
	}

# --- Home's standing actions -----------------------------------------------

## Which of Home's two standing actions have a door right now, in render order.
##
##   "post_eli"  Eli has offered the bag, so there is somebody to send
##   "lay_low"   Recovery is relevant, so there is a reason to go quiet
##
## The IDs are the screen's render list AND the gate's population, from one
## derivation. That is the same rule `operation_card_reason()` is written to —
## the visible state and the content come from one verdict, or a screen ends up
## hiding a card it is simultaneously filling — applied to a card whose contents
## VARY rather than one that is simply on or off.
##
## Availability, not eligibility. `post_eli` asks whether Eli has offered, not
## whether he can be assigned this minute: a button that disappears because it
## is Tuesday afternoon teaches nothing, and both handlers already refuse with a
## reason the player can act on. The card is about what EXISTS.
func home_actions() -> Array:
	var out: Array = []
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null or gs == null:
		return out
	var ops: Object = manager.system("crew_operations")
	if ops != null and bool(ops.is_discovered("run_the_bag")):
		out.append("post_eli")
	if bool(gs.recovery_available()):
		out.append("lay_low")
	return out

# --- the verdict -----------------------------------------------------------

## The full answer for one surface, in the design pass's contract shape:
##
##   {feature_id, state, mode, ok, blocker_code, blocker_copy_key,
##    current, required, hint}
##
## An UNREGISTERED surface id comes back available. That is the one place this
## file opens rather than closes, and it is deliberate: the registry exists to
## restrict surfaces somebody has decided to restrict, and a screen asking about
## an id nobody registered is asking about a surface with no gate. Failing closed
## there would make every unregistered surface in the build disappear at once.
## A registered gate with a TYPO IN ITS REQUIREMENT still fails closed, because
## the evaluator decides that, and the evaluator does not guess.
func verdict(surface_id: String) -> Dictionary:
	var gate: Variant = GATES.get(surface_id)
	if not (gate is Dictionary):
		return {
			"feature_id": surface_id,
			"state": STATE_AVAILABLE,
			"mode": MODE_LOCKED,
			"ok": true,
			"blocker_code": null,
			"blocker_copy_key": null,
			"current": null,
			"required": null,
			"hint": "",
		}
	var rule: Dictionary = gate
	var evaluated: Dictionary = REQUIREMENTS.new().evaluate_requirements(
		rule.get("requirements", []), facts())
	var passed: bool = bool(evaluated["ok"])
	var mode: String = str(rule.get("mode", MODE_LOCKED))
	var state: String = STATE_AVAILABLE
	if not passed:
		state = STATE_HIDDEN if mode == MODE_HIDDEN else STATE_LOCKED
	return {
		"feature_id": surface_id,
		"state": state,
		"mode": mode,
		"ok": passed,
		"blocker_code": evaluated["blocker_code"],
		"blocker_copy_key": evaluated["blocker_copy_key"],
		"current": evaluated["current"],
		"required": evaluated["required"],
		"hint": str(rule.get("hint", "")) if not passed else "",
	}

## Has the player earned this surface? The progression-gate question.
##
## A HIDDEN surface that has not been populated reports false here too — both
## modes share one verdict, which is what stops a screen showing a hidden
## surface as merely locked, or routing into one it is not rendering.
func is_unlocked(surface_id: String) -> bool:
	return bool(verdict(surface_id)["ok"])

## Should this surface be in the layout at all?
##
## False ONLY for a hidden surface that has not met its condition. A locked
## surface is visible — being visible while unusable is the entire point of
## LOCKED, and a screen that hid it would be teaching the player nothing.
func is_visible(surface_id: String) -> bool:
	var answer: Dictionary = verdict(surface_id)
	return bool(answer["ok"]) or str(answer["mode"]) != MODE_HIDDEN

## One line explaining a locked surface, or "" when there is nothing to say.
func hint_for(surface_id: String) -> String:
	return str(verdict(surface_id)["hint"])

## May the player enter this route? The same verdict the button reads, asked of
## the destination rather than the control — so an alternate entry point, a deep
## link, or a screen rendered before a state change all get the same answer.
##
## A route with no registered gate is open, for the reason `verdict` documents.
func route_allowed(scene_path: String) -> bool:
	var surface_id: Variant = ROUTE_GATES.get(scene_path)
	return true if surface_id == null else is_unlocked(str(surface_id))

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
## screen learning a new condition. Progression gates are LOCKED (a lock teaches
## that something is coming); population and feature-flag checks are HIDDEN (an
## empty feed teaches nothing, and a padlock on it would be a lie about
## progression).
##
## ## Nothing derived is stored
##
## Every answer is computed from live GameState on the call. There is no
## `unlocked` boolean anywhere, which is what makes "unlocks survive save/load"
## true by construction rather than by a migration: the facts persist, the
## verdicts do not. The two facts that ARE persisted — `districts_unlocked` and
## `job_contacts` — are one-way discovery latches owned by GameState, not copies
## of a condition that could contradict it.
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
const HOME_TEXT_MESSAGES := "home.text_messages"
const HOME_ACTIVITY_FEED := "home.activity_feed"
const MENU_CREW := "menu.crew"
const MENU_JOBS := "menu.jobs"
const STREET_DOWNTOWN := "street.downtown"
const STREET_SHIP_CREEK := "street.ship_creek"

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
	HOME_MARKET_SNAPSHOT: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "list_flips_min", "min": 1}],
		"hint": "Complete your first flip to unlock",
	},
	HOME_TURF_CREW: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "crew_count_min", "min": 1}],
		"hint": "Recruit your first crew member",
	},
	MENU_CREW: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "crew_count_min", "min": 1}],
		"hint": "Recruit your first crew member",
	},
	MENU_JOBS: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "job_contacts_min", "min": 1}],
		"hint": "Meet someone who hires",
	},
	STREET_DOWNTOWN: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "district_discovered", "district_id": "downtown"}],
		"hint": "Hold a corner before the city opens up",
	},
	STREET_SHIP_CREEK: {
		"mode": MODE_LOCKED,
		"requirements": [{"type": "district_discovered",
			"district_id": "airport_industrial"}],
		"hint": "Hold two corners before the port is worth the trip",
	},

	# --- population / feature flags: HIDDEN -----------------------------
	HOME_TONIGHTS_OPERATION: {
		"mode": MODE_HIDDEN,
		"requirements": [{"type": "fact_true", "fact": "operation_card_live"}],
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
}

## Which surface guards which route, so route entry and the visible button
## cannot disagree (design pass, Improvement 2). Read by ScreenManager.
##
## Keyed by scene path because that is what `go_to` is handed — a nav cell, a
## deep link and a debug jump all arrive as a path, and all three get the same
## answer.
const ROUTE_GATES := {
	"res://ui/screens/crew.tscn": MENU_CREW,
	"res://ui/screens/jobs.tscn": MENU_JOBS,
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
		"operation_card_live": not str(operation_card_reason()).is_empty(),
	}

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

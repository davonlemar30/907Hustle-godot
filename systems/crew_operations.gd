extends RefCounted
## Crew Operations — the lifecycle a delegated job runs through.
##
## FS-001.6. **Substrate only.** Discovery unlocks, eligibility is evaluated,
## a crew member's day is claimed in the morning, and the claim settles at
## night — but no operation has a domain adapter yet, so a settled assignment
## carries a null result. FS-001.7 (Pherris, "Run the Board") plugs an adapter
## into this file without modifying it.
##
## ## What this file knows and what it refuses to know
##
## It knows: which operations exist, whether they have been discovered, whether
## one can be assigned right now and why not, who is booked today, and when to
## hand a pending assignment to whoever owns its domain.
##
## It does NOT know: what running the board means, what it buys, what it costs,
## or how it decides to stop. Every one of those is adapter business. The moment
## a `if operation_id == "907list_run_board"` appears here, the substrate has
## stopped being one.
##
## ## Discovery is one-way, and that is a design decision
##
## `907list_run_board` becomes discoverable at Broker tier with Pherris active
## and loyal. Let her loyalty slip afterwards and the operation stays
## discovered — you learned she can do this. What you lose is the ability to
## ASSIGN it, which is a separate requirement list evaluated separately.
##
## Two lists rather than one because they answer different questions:
## "is this a thing you know about" and "can it happen this morning". Collapsing
## them would make forgetting a capability the punishment for a bad week.
##
## ## The planning window
##
## An assignment is a morning decision. Canon's shape for delegation is that you
## point somebody at a job before the day starts moving, not halfway through it,
## so `planning_window_open` gates on `time_slots_today == 0`.
##
## Worth knowing what does NOT close it: a personal 907List buy costs no slot
## and never dispatches `advance_time`, so browsing the board in the morning
## leaves the window open. Anything that advances the clock shuts it.
##
## ## Settlement rides `day_ending`, never a dispatch
##
## Settlement is not something the player does, so it is not an action. It hangs
## off `day_ending`, which fires while the clock still reads the day being
## settled — the adapter therefore sees the state its assignment was made
## against, without subtracting one from anything.

const AMBER := Color(0.882, 0.651, 0.227)

## What has to be true for an operation to become KNOWN. Evaluated continuously
## through `reconcile()`; once satisfied the result is latched.
const DISCOVERY_REQUIREMENTS := {
	"907list_run_board": [
		{"type": "hustle_tier_min", "hustle_id": "list", "min": 3},
		{"type": "crew_active", "crew_id": "pherris"},
		{"type": "crew_loyalty_min", "crew_id": "pherris", "min": 6},
	],
}

## What has to be true to CLAIM somebody's day for it, this morning.
##
## Order is the authored priority of the reasons: the evaluator short-circuits,
## so the player is told the most fundamental thing that is wrong first. "She is
## not on the crew" outranks "you already used her today", which outranks "it is
## the afternoon".
const ASSIGNMENT_REQUIREMENTS := {
	"907list_run_board": [
		{"type": "crew_active", "crew_id": "pherris"},
		{"type": "crew_loyalty_min", "crew_id": "pherris", "min": 6},
		{"type": "payroll_not_delinquent", "crew_id": "pherris"},
		{"type": "crew_unassigned_today", "crew_id": "pherris"},
		{"type": "planning_window_open"},
	],
}

## Which crew member each operation belongs to. A capability is a person's, not
## a slot's — so this is derived from the capability table rather than a second
## place to keep the same fact.
const OPERATION_CAPABILITY := {
	"907list_run_board": {"crew_id": "pherris", "capability_id": "907list_run_board"},
}

var gs: Node
var gm: Node
var requirements: RefCounted

func setup(game_state: Node, manager: Node, requirement_system: RefCounted) -> void:
	gs = game_state
	gm = manager
	requirements = requirement_system
	gs.day_ending.connect(_on_day_ending)

func can_handle(action: String) -> bool:
	return action == "assign_crew_operation"

func handle(action: String, payload: Dictionary) -> Dictionary:
	if action != "assign_crew_operation":
		return {"ok": false, "reason": "Unknown crew operation action."}
	return _assign(str(payload.get("crew_id", "")), str(payload.get("operation_id", "")))

# --- facts -----------------------------------------------------------------

## The one place live state is translated into the evaluator's input.
##
## **This is the seam FS-001.5 proved is dangerous.** The evaluator is oracle-
## exact and reads what it is handed; every representation this build uses that
## canon does not — `wage_missed_since` of -1 where canon writes null, an absent
## `crew_assignments` entry where canon might write null — meets canon's
## semantics HERE or nowhere. Fixtures recorded from the oracle cannot see this
## function, so it carries its own checks.
func _facts() -> Dictionary:
	var crew: Dictionary = {}
	for person in gs.crew_roster:
		var id := str(person["id"])
		var record: Dictionary = gs.crew_record(id)
		if record.is_empty():
			continue
		crew[id] = record
	return {
		"crew": crew,
		"current_day": gs.day,
		"time_slots_today": gs.time_slots_today,
		"wage_grace_days": gs.CREW_WAGE_GRACE_DAYS,
		"hustle_tiers": {
			"list": gs.list_tier,
			"stick": gs.stick_tier,
			"boost": gs.boost_tier,
		},
		# Only TODAY's live claims are facts. A stale entry is not an
		# assignment, and handing the evaluator one would block a crew member
		# forever on the strength of a booking they already finished.
		"assignments": _live_assignments(),
	}

func _live_assignments() -> Dictionary:
	var out: Dictionary = {}
	for crew_id in gs.crew_assignments.keys():
		var entry: Variant = gs.crew_assignments[crew_id]
		if entry is Dictionary and int((entry as Dictionary).get("day", -1)) == gs.day:
			out[str(crew_id)] = entry
	return out

# --- discovery -------------------------------------------------------------

func discovered() -> Array:
	var known: Variant = gs.crew_operation_state.get("discovered", [])
	return known if known is Array else []

func is_discovered(operation_id: String) -> bool:
	return operation_id in discovered()

## Latch any operation whose discovery requirements are now satisfied.
##
## Called from GameManager after every successful dispatch and once after a
## load, so an operation unlocks the moment the state that reveals it exists —
## not on the next action that happens to look.
##
## **Writes state directly and dispatches nothing.** A nested dispatch here
## would fire a second notify_changed() inside the first one's stack, and the
## reactive contract is one refresh per action.
func reconcile() -> void:
	if gs.game_over:
		return
	var facts: Dictionary = _facts()
	for operation_id in DISCOVERY_REQUIREMENTS.keys():
		if is_discovered(str(operation_id)):
			continue
		var verdict: Dictionary = requirements.evaluate_requirements(
			DISCOVERY_REQUIREMENTS[operation_id], facts)
		if bool(verdict["ok"]):
			_mark_discovered(str(operation_id))

func _mark_discovered(operation_id: String) -> void:
	if not (gs.crew_operation_state.get("discovered") is Array):
		gs.crew_operation_state["discovered"] = []
	if operation_id in gs.crew_operation_state["discovered"]:
		return
	gs.crew_operation_state["discovered"].append(operation_id)
	gs.log_activity(
		"Pherris mentions she could work the board herself, if you asked.", AMBER)

# --- eligibility -----------------------------------------------------------

## The first reason this cannot be assigned right now, or null if it can.
## Discovery is checked first: an operation you do not know about is not
## blocked, it does not exist.
func assignment_blocker(operation_id: String) -> Variant:
	if not ASSIGNMENT_REQUIREMENTS.has(operation_id):
		return {
			"ok": false, "blocker_code": "unknown_operation",
			"blocker_copy_key": "operations.unknown_operation",
			"current": operation_id, "required": "known_operation",
		}
	if not is_discovered(operation_id):
		return {
			"ok": false, "blocker_code": "operation_undiscovered",
			"blocker_copy_key": "operations.operation_undiscovered",
			"current": false, "required": true,
		}
	var verdict: Dictionary = requirements.evaluate_requirements(
		ASSIGNMENT_REQUIREMENTS[operation_id], _facts())
	return null if bool(verdict["ok"]) else verdict

# --- assignment ------------------------------------------------------------

func assignment_for(crew_id: String) -> Dictionary:
	var entry: Variant = gs.crew_assignments.get(crew_id)
	if not (entry is Dictionary):
		return {}
	# A booking from a previous day is history, not a claim on today.
	return entry if int((entry as Dictionary).get("day", -1)) == gs.day else {}

func _assign(crew_id: String, operation_id: String) -> Dictionary:
	if gs.game_over:
		return {"ok": false, "reason": "The run is over."}
	var expected: Dictionary = OPERATION_CAPABILITY.get(operation_id, {})
	if expected.is_empty():
		return {"ok": false, "reason": "No such operation."}
	# The operation belongs to a person. Asking somebody else to run it is not a
	# blocker to explain, it is a category error.
	if crew_id != str(expected["crew_id"]):
		return {"ok": false, "reason": "That is not their work."}
	var blocker: Variant = assignment_blocker(operation_id)
	if blocker != null:
		return {"ok": false, "reason": _blocker_copy(blocker),
			"blocker": blocker}
	gs.crew_assignments[crew_id] = {
		"day": gs.day,
		"operation_id": operation_id,
		"settled": false,
		"result": null,
	}
	gs.log_activity("Pherris takes the day to work the board.", AMBER)
	return {"ok": true, "crew_id": crew_id, "operation_id": operation_id}

## Player-facing wording for a structured blocker. Deliberately small: the
## evaluator's `blocker_copy_key` is the real translation seam, and this is the
## fallback until a copy table exists to translate against.
func _blocker_copy(blocker: Variant) -> String:
	match str((blocker as Dictionary).get("blocker_code", "")):
		"operation_undiscovered": return "You have not thought to ask."
		"unknown_operation": return "No such operation."
		"crew_active": return "They are not on the crew."
		"crew_loyalty_min": return "They are not sure enough of you yet."
		"payroll_not_delinquent": return "Pay them what you owe first."
		"crew_unassigned_today": return "They already have the day."
		"planning_window_open": return "That is a morning decision."
	return "Not today."

# --- settlement ------------------------------------------------------------

## Night. Hand every live, unsettled claim to whoever owns its domain.
##
## `ended_day` arrives as a parameter and the clock still reads it, so an
## adapter sees exactly the state its assignment was made against. Nothing here
## subtracts one from anything.
##
## With no adapter registered, a pending assignment settles to a null result
## rather than staying pending forever — a claim on a day that has ended is
## finished by definition, and leaving it open would block the crew member
## tomorrow through `crew_unassigned_today`.
func _on_day_ending(ended_day: int) -> void:
	for crew_id in gs.crew_assignments.keys():
		var entry: Variant = gs.crew_assignments[crew_id]
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		if int(assignment.get("day", -1)) != ended_day:
			continue
		if bool(assignment.get("settled", false)):
			continue
		assignment["settled"] = true
		assignment["result"] = _settle(str(crew_id), assignment, ended_day)

## The adapter hand-off. Returns whatever the adapter reports, or null when
## nothing owns this operation yet.
##
## An adapter is any object with `settle(crew_id, assignment, ended_day)`.
## FS-001.7 registers one; until then this is the whole of the domain layer.
func _settle(crew_id: String, assignment: Dictionary, ended_day: int) -> Variant:
	var adapter: Variant = _adapter_for(str(assignment.get("operation_id", "")))
	if adapter == null:
		return null
	return adapter.settle(crew_id, assignment, ended_day)

func _adapter_for(operation_id: String) -> Variant:
	var adapters: Variant = gs.crew_operation_state.get("adapters", {})
	if not (adapters is Dictionary):
		return null
	var adapter: Variant = (adapters as Dictionary).get(operation_id)
	# A stored adapter must actually be able to settle. A save cannot carry an
	# object, so anything found here that does not answer is stale data.
	if adapter != null and adapter is Object and (adapter as Object).has_method("settle"):
		return adapter
	return null

# --- reads -----------------------------------------------------------------

## Everything a screen needs about one operation, in one call. FS-001.8 is the
## caller; nothing renders it yet.
func operation_summary(operation_id: String) -> Dictionary:
	var expected: Dictionary = OPERATION_CAPABILITY.get(operation_id, {})
	var crew_id: String = str(expected.get("crew_id", ""))
	var known: bool = is_discovered(operation_id)
	var blocker: Variant = assignment_blocker(operation_id) if known else null
	var assignment: Dictionary = assignment_for(crew_id) if not crew_id.is_empty() else {}
	var assigned_here: bool = str(assignment.get("operation_id", "")) == operation_id

	# The cap the capability curve allows at their current rank. Read through
	# the same helper the wage curve uses, so an unauthored rank clamps to the
	# top authored value rather than falling back to nothing.
	var rank: int = int(gs.crew_record(crew_id).get("tier", 1)) if not crew_id.is_empty() else 0
	var requested_cap: int = 0
	if not crew_id.is_empty():
		requested_cap = int(gs.crew_capability_value(
			crew_id, str(expected.get("capability_id", "")), "max_cycles_by_rank", rank, 0))

	return {
		"operation_id": operation_id,
		"crew_id": crew_id,
		"discovered": known,
		"available": known and blocker == null,
		"blocker": blocker,
		"assigned_today": assigned_here,
		"assignment_settled": assigned_here and bool(assignment.get("settled", false)),
		"assignment_result": assignment.get("result") if assigned_here else null,
		"requested_cap": requested_cap,
		# Both stay null until an adapter has an opinion. Declared now so the
		# shape a screen reads does not change when FS-001.7 lands.
		"spend_limit": null,
		"stop_reason": null,
	}

## Every operation this build knows how to run, discovered or not.
func operation_ids() -> Array:
	return OPERATION_CAPABILITY.keys()

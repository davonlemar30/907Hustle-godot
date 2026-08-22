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

# --- FS-001.9: the callbacks --------------------------------------------------
#
# Delegation worked before this and said almost nothing. The player could learn
# that Pherris runs the board only by opening the 907List screen and reading a
# panel; they found out how her day went by noticing the cash total had moved.
#
# What follows is CONTINUITY, not a tutorial and not a notification system. Every
# line goes out through a channel that already exists — `phone.push_message()`
# for anything she says to you, `gs.log_activity()` for anything the day records
# — and every number in every line is read off the assignment that produced it.
# There is no authored "good day" text: which template fires is decided by the
# settlement result, and the figures inside it come from the same Dictionary the
# 907List screen renders.
#
# ## The one-shot flags
#
# Three facts have to survive a reload or they become spam: that she has offered
# once, that she has complained about her loyalty once, and — the one that is not
# a latch — whether that complaint is still standing. They live inside
# `crew_operation_state`, which is already in PERSIST_FIELDS, so none of them
# costs a schema bump.
#
# `discovery_notified` is checked SEPARATELY from the `discovered` list rather
# than folded into `_mark_discovered`. A save written before FS-001.9 can already
# carry a discovered operation and has never seen the text; keying the message on
# its own flag means that run gets the offer once, on its next reconcile, instead
# of never.

## Who the delegation texts come from, when the adapter does not say.
##
## GENERALISED in batch 6a. Every string in this block used to be the only thing
## an operation could say, which was fine while there was one operation and is
## the reason there could only ever be one. The coordinator now asks the ADAPTER
## for its copy and falls back to these, so a second operation is a second
## adapter rather than an `if operation_id ==` in a file whose own header
## forbids exactly that.
##
## The fallbacks stay Pherris's because `list_adapter` is the one adapter that
## predates the seam; its own strings moved into it and these are what any
## adapter that declines to speak inherits.
const CALLBACK_FROM := "Pherris"

## The offer, once she is capable of it. PX/FS-001.9's authored copy.
const DISCOVERY_TEXT := "I been watching how you move product on that list. " \
	+ "Let me run your board tomorrow morning. I know what sells."

## The one blocker that gets a text rather than a panel line. Routine refusals —
## it is the afternoon, she already has the day — are already answered where the
## player asked, and texting about them would be nagging about a button.
const LOYALTY_WARNING_TEXT := "I'm not feeling like running errands right now. " \
	+ "You know what I need."

## The loyalty the warning arms and disarms around. Read from the assignment
## requirement rather than restated, so the text cannot drift from the gate that
## produced it — see `_loyalty_gate()`.
const LOYALTY_REQUIREMENT_TYPE := "crew_loyalty_min"

## What has to be true for an operation to become KNOWN. Evaluated continuously
## through `reconcile()`; once satisfied the result is latched.
const DISCOVERY_REQUIREMENTS := {
	"907list_run_board": [
		{"type": "hustle_tier_min", "hustle_id": "list", "min": 3},
		{"type": "crew_active", "crew_id": "pherris"},
		{"type": "crew_loyalty_min", "crew_id": "pherris", "min": 6},
	],
	# Eli and Deshawn are gated on the RELATIONSHIP rather than on a hustle
	# tier, and the difference is the offer each is making. Pherris offers to
	# run a board she has watched you get good at, so her gate is your Broker
	# tier. These two are offering to do their own job for you, and the only
	# question is whether they trust you enough to spend a day on it.
	#
	# A loyalty of 5 is one above the recruiting floor, so neither offer arrives
	# on the morning you hire them.
	"run_the_bag": [
		{"type": "crew_active", "crew_id": "eli"},
		{"type": "crew_loyalty_min", "crew_id": "eli", "min": 5},
	],
	"smooth_it_over": [
		{"type": "crew_active", "crew_id": "deshawn"},
		{"type": "crew_loyalty_min", "crew_id": "deshawn", "min": 5},
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
	# Same five rows in the same authored order, because the order IS the
	# priority of the reasons and it does not change with the person: "he is not
	# on the crew" outranks "you already used him today", which outranks "it is
	# the afternoon".
	"run_the_bag": [
		{"type": "crew_active", "crew_id": "eli"},
		{"type": "crew_loyalty_min", "crew_id": "eli", "min": 5},
		{"type": "payroll_not_delinquent", "crew_id": "eli"},
		{"type": "crew_unassigned_today", "crew_id": "eli"},
		{"type": "planning_window_open"},
	],
	"smooth_it_over": [
		{"type": "crew_active", "crew_id": "deshawn"},
		{"type": "crew_loyalty_min", "crew_id": "deshawn", "min": 5},
		{"type": "payroll_not_delinquent", "crew_id": "deshawn"},
		{"type": "crew_unassigned_today", "crew_id": "deshawn"},
		{"type": "planning_window_open"},
	],
}

## Which crew member each operation belongs to. A capability is a person's, not
## a slot's — so this is derived from the capability table rather than a second
## place to keep the same fact.
const OPERATION_CAPABILITY := {
	"907list_run_board": {"crew_id": "pherris", "capability_id": "907list_run_board"},
	"run_the_bag": {"crew_id": "eli", "capability_id": "run_the_bag"},
	"smooth_it_over": {"crew_id": "deshawn", "capability_id": "smooth_it_over"},
}

var gs: Node
var gm: Node
var requirements: RefCounted

## operation_id -> adapter object. **Runtime wiring, not run state.**
##
## FS-001.6 kept these under `crew_operation_state.adapters`, which was wrong in
## a way that only shows up after a load: that dictionary is persisted, so
## `_apply()` replaces it with the saved copy — and a saved copy can never
## contain an object. The adapter silently vanished on every CONTINUE RUN.
##
## Living here instead, they are re-registered by GameManager on boot and a load
## cannot clear them. The persisted `adapters` key stays in `crew_operation_state`
## so no schema bump is needed; it is vestigial and nothing reads it.
var _adapters: Dictionary = {}

func setup(game_state: Node, manager: Node, requirement_system: RefCounted) -> void:
	gs = game_state
	gm = manager
	requirements = requirement_system
	gs.day_ending.connect(_on_day_ending)

## Wire a domain adapter to an operation. Any object with
## `select(crew_id, assignment)` and `settle(crew_id, assignment, ended_day)`.
func register_adapter(operation_id: String, adapter: Object) -> void:
	_adapters[operation_id] = adapter

func can_handle(action: String) -> bool:
	return action == "assign_crew_operation"

func handle(action: String, payload: Dictionary) -> Dictionary:
	if action != "assign_crew_operation":
		return {"ok": false, "reason": "Unknown crew operation action."}
	return _assign(str(payload.get("crew_id", "")), str(payload.get("operation_id", "")), payload)

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
	# FS-001.9. Runs after the latch loop, on the same pass, so an operation that
	# became discoverable during THIS action is offered on the same refresh that
	# revealed it — the discovery text and the panel appearing together is the
	# whole point of reconciling here rather than on the next action.
	_reconcile_callbacks()

func _mark_discovered(operation_id: String) -> void:
	if not (gs.crew_operation_state.get("discovered") is Array):
		gs.crew_operation_state["discovered"] = []
	if operation_id in gs.crew_operation_state["discovered"]:
		return
	gs.crew_operation_state["discovered"].append(operation_id)
	gs.log_activity(
		"Pherris mentions she could work the board herself, if you asked.", AMBER)

# --- FS-001.9: state-driven callbacks --------------------------------------

## A run-level flag out of `crew_operation_state`, defaulted rather than indexed.
##
## The Dictionary is persisted whole and a save written before these flags
## existed comes back without them, so every read has to answer "has not happened
## yet" for a missing key rather than raising.
## Callback flags, PER OPERATION as of batch 6b.
##
## They were flat keys on `crew_operation_state` — `discovery_notified`,
## `loyalty_warning_sent` — which was correct while one operation existed and
## became a bug the moment a second did: the first operation to be discovered
## consumed the flag and every other one went silent forever. Nobody would ever
## have heard from Eli or Deshawn.
##
## Namespaced rather than nested so an old save needs no migration: a v10 record
## carries the flat keys, which no longer match any namespaced lookup, so both
## texts simply arrive once more for a run already in progress. That is a better
## failure than a migration for two booleans whose whole content is "this has
## been said once".
func callback_flag(key: String, operation_id: String = "") -> bool:
	return bool(gs.crew_operation_state.get(_flag_key(key, operation_id), false))

func _set_callback_flag(key: String, value: bool, operation_id: String = "") -> void:
	gs.crew_operation_state[_flag_key(key, operation_id)] = value

func _flag_key(key: String, operation_id: String) -> String:
	return key if operation_id.is_empty() else "%s:%s" % [operation_id, key]

func _phone() -> Object:
	return gm.system("phone") if gm != null else null

## The loyalty an assignment actually requires, read off the requirement list.
##
## Restating "6" in the callback code would be a second copy of a number the
## requirement table already owns — and the failure mode of a drifted copy is a
## text that fires at a loyalty the game does not care about, which reads as a
## bug in Pherris rather than in a constant.
func _loyalty_gate(operation_id: String) -> int:
	for entry in (ASSIGNMENT_REQUIREMENTS.get(operation_id, []) as Array):
		var row: Dictionary = entry
		if str(row.get("type", "")) == LOYALTY_REQUIREMENT_TYPE:
			return int(row.get("min", 0))
	return 0

## The two flag-driven texts, evaluated every reconcile.
##
## Deliberately NOT hung off the events that cause them. Discovery already has a
## latch and loyalty is written by four different paths (wages, proofs, decay,
## dismissal); hooking each of them would put the same two `if`s in four files
## and would still miss the fifth. Reading the current state once per action is
## both cheaper and complete — and it is how the discovery latch above already
## works.
func _reconcile_callbacks() -> void:
	var phone: Object = _phone()
	if phone == null:
		return
	for operation_key in OPERATION_CAPABILITY.keys():
		var operation_id := str(operation_key)
		if not is_discovered(operation_id):
			continue
		# --- the offer, once per run ---
		if not callback_flag("discovery_notified", operation_id):
			phone.push_message(_sender_for(operation_id),
				_adapter_copy(operation_id, "discovery_text", [], DISCOVERY_TEXT))
			_set_callback_flag("discovery_notified", true, operation_id)
		# --- the loyalty complaint, once per episode ---
		#
		# An EPISODE, not a run: the flag clears the moment loyalty recovers, so
		# a second slump months later is heard again. That is the difference
		# between a character with a mood and a tutorial that fires once.
		var crew_id := str((OPERATION_CAPABILITY[operation_id] as Dictionary).get("crew_id", ""))
		if crew_id.is_empty():
			continue
		var record: Dictionary = gs.crew_record(crew_id)
		# Nothing to say about somebody who is not on the crew. Her loyalty is
		# not "low" when she is gone, it is absent, and reading a missing record
		# as 0 would fire the complaint at every player who never hired her.
		if record.is_empty() or not gs.is_recruited(crew_id):
			continue
		var loyalty: int = int(record.get("loyalty", 0))
		var gate: int = _loyalty_gate(operation_id)
		if loyalty < gate:
			if not callback_flag("loyalty_warning_sent", operation_id):
				phone.push_message(_sender_for(operation_id),
					_adapter_copy(operation_id, "loyalty_warning_text", [],
						LOYALTY_WARNING_TEXT))
				_set_callback_flag("loyalty_warning_sent", true, operation_id)
		elif callback_flag("loyalty_warning_sent", operation_id):
			# Re-armed rather than left set. The flag is "there is a complaint
			# standing", and once she is loyal again there is not.
			_set_callback_flag("loyalty_warning_sent", false, operation_id)

## The activity-feed line for a claim that just succeeded.
##
## Three shapes, chosen by what the morning actually produced rather than by an
## authored "she went out" default: a budget the player set, a spend they left
## open, and a board that had nothing on it. Every figure is read off the
## selection the adapter just returned.
## An adapter's own copy, or the coordinator's fallback.
##
## Four optional methods, all checked rather than required, because an adapter
## that only knows how to `settle()` is still a valid adapter:
##
##     sender() -> String
##     discovery_text() -> String
##     assignment_line(selection, spend_limit) -> String
##     settlement_text(assignment) -> String
func _adapter_copy(operation_id: String, method: String, args: Array,
		fallback: String) -> String:
	var adapter: Variant = _adapter_for(operation_id)
	if adapter == null or not (adapter as Object).has_method(method):
		return fallback
	var said: Variant = (adapter as Object).callv(method, args)
	return str(said) if said is String and not str(said).is_empty() else fallback

## Who a given operation's texts come from.
func _sender_for(operation_id: String) -> String:
	return _adapter_copy(operation_id, "sender", [], CALLBACK_FROM)

func _assignment_line(selection: Variant, spend_limit: int) -> String:
	var picked: int = 0
	var spent: int = 0
	if selection is Dictionary:
		picked = int((selection as Dictionary).get("cycles_used", 0))
		spent = int((selection as Dictionary).get("total_spent", 0))
	if picked <= 0:
		# She still spent the day, and the day is still gone. The settlement
		# summary says what came of it; this only says where she is.
		return "Pherris is running your board today. Nothing worth picking up yet."
	if spend_limit >= 0:
		return "Pherris is running your board today. %d item%s, up to $%d." \
			% [picked, "" if picked == 1 else "s", spend_limit]
	return "Pherris is running your board today. %d item%s, $%d out of pocket." \
		% [picked, "" if picked == 1 else "s", spent]

## What she reports back at settlement, in her own words, from real numbers.
##
## One message per settlement, never per item. Which template fires is decided by
## the result: no authored line claims an outcome the night did not have.
func _settlement_text(assignment: Dictionary) -> String:
	var result: Variant = assignment.get("result")
	var sold: int = 0
	var gross: int = 0
	var profit: int = 0
	if result is Dictionary:
		sold = int((result as Dictionary).get("settled_count", 0))
		gross = int((result as Dictionary).get("gross", 0))
		profit = int((result as Dictionary).get("profit_or_loss", 0))
	var bought: int = 0
	var selection: Variant = assignment.get("selection")
	if selection is Dictionary:
		bought = int((selection as Dictionary).get("cycles_used", 0))

	if sold > 0:
		if profit > 0:
			return "Moved %d for $%d. You cleared $%d after what I paid." \
				% [sold, gross, profit]
		return "Moved %d for $%d. Thin margins today, but the board's turning over." \
			% [sold, gross]
	if bought > 0:
		# The fourth case the brief's three do not cover, and it is reachable:
		# she bought stock that is not past its sell delay yet. Saying "nothing
		# worth touching" here would be a lie about money that is already spent.
		return "Picked up %d today. Nothing's turned over yet." \
			% bought
	return "Nothing worth touching on the board today. Kept your money where it is."

## Fire the nightly report for one settled assignment.
##
## Called from `_on_day_ending` after settlement has run and before the clock
## moves, so the text is about the day it is reporting on. Guarded on the result
## being a real Dictionary: an operation with no adapter settles to null, and a
## crew member cannot report on work nothing performed.
func _settlement_callback(assignment: Dictionary) -> void:
	var phone: Object = _phone()
	if phone == null:
		return
	if not (assignment.get("result") is Dictionary):
		return
	var operation_id := str(assignment.get("operation_id", ""))
	phone.push_message(_sender_for(operation_id),
		_adapter_copy(operation_id, "settlement_text", [assignment],
			_settlement_text(assignment)))

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

func _assign(crew_id: String, operation_id: String, payload: Dictionary = {}) -> Dictionary:
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
	var assignment: Dictionary = {
		"day": gs.day,
		"operation_id": operation_id,
		"settled": false,
		"result": null,
		# What the player was willing to let her spend. -1 is no limit; 0 is a
		# real answer that commits her day for nothing, which is the player's
		# right to choose.
		"spend_limit": int(payload.get("spend_limit", -1)),
		# A generic passthrough for whatever an operation needs that is not a
		# budget. `spend_limit` was the only parameter the dispatch ever read,
		# which meant an operation wanting a TARGET — a district to work, a
		# corner to stand on — had nowhere to receive one. Carried as an opaque
		# Dictionary the coordinator never inspects; the adapter owns its shape.
		"params": payload.get("params", {}) if payload.get("params") is Dictionary else {},
		# What she picked this morning. Kept SEPARATE from `result`, which the
		# coordinator defines as whatever settlement returned — writing the
		# selection there would have it overwritten at midnight, losing the
		# purchase record and the stop reason the summary reports.
		"selection": null,
	}
	gs.crew_assignments[crew_id] = assignment

	# She shops immediately. The money leaves when the stock is picked up, which
	# is what makes the assignment a commitment rather than a bet — and it stops
	# the player spending the day's cash elsewhere and having her buy with money
	# that was never there.
	var adapter: Variant = _adapter_for(operation_id)
	if adapter != null and (adapter as Object).has_method("select"):
		assignment["selection"] = adapter.select(crew_id, assignment)
	# FS-001.9: the acknowledgement, logged AFTER she has shopped rather than
	# before. The line reports what she picked up and what it cost, and neither
	# of those exists until `select()` has run — logging first would have meant
	# authoring a line that could not say anything true.
	gs.log_activity(_adapter_copy(operation_id, "assignment_line",
		[assignment["selection"], int(assignment["spend_limit"])],
		_assignment_line(assignment["selection"], int(assignment["spend_limit"]))),
		AMBER)
	return {"ok": true, "crew_id": crew_id, "operation_id": operation_id,
		"selection": assignment["selection"]}

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
		# FS-001.9. Inside `day_ending`, after settlement and before the
		# increment: the report is about the day it is reporting on, and the
		# clock still reads that day while it is written.
		_settlement_callback(assignment)

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
	var adapter: Variant = _adapters.get(operation_id)
	# Still checked rather than trusted: a half-built adapter that cannot settle
	# should read as "nobody owns this" instead of erroring at midnight.
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
		# Filled from the morning's selection once there is one. Null before an
		# assignment exists, which is the honest answer rather than a zero.
		"spend_limit": assignment.get("spend_limit") if assigned_here else null,
		"stop_reason": _selection_field(assignment, "stop_reason") if assigned_here else null,
		"selection": assignment.get("selection") if assigned_here else null,
		# What she WOULD do if asked right now, straight from the adapter — the
		# cash exposure and the storage it needs, so a screen can show the cost
		# of a decision before it is made. Null once she is already out working,
		# because a preview of an assignment that exists is a different question.
		#
		# FS-001.6 declared this slot and left it empty; the adapter that could
		# answer it did not exist yet. FS-001.8 is where it gets filled, and it
		# is filled by ASKING rather than by the screen working it out.
		"preview": _preview(operation_id, crew_id) if known and not assigned_here else null,
		# --- FS-001.9's contextual surfaces ---
		#
		# Home and Hustle are not allowed to work any of this out. They render
		# what the summary hands them, which is why "is she out right now" and
		# "what did last night come to" are FIELDS rather than two screens each
		# reaching into `crew_assignments` and deriving the same answer twice.
		"active_today": assigned_here and not bool(assignment.get("settled", false)),
		"last_night": _last_night(crew_id),
	}

## Last night's settled result, or null.
##
## Day-scoped to `day - 1` on purpose. `assignment_for()` refuses a stale record
## because a claim on a finished day is not a claim on today — that rule is
## load-bearing and does not bend. This is the separate question ("what came back
## last night"), answered separately, and it goes quiet on its own after one day
## rather than leaving yesterday's number on the Home card all week.
func _last_night(crew_id: String) -> Variant:
	if crew_id.is_empty():
		return null
	var entry: Variant = gs.crew_assignments.get(crew_id)
	if not (entry is Dictionary):
		return null
	var assignment: Dictionary = entry
	if int(assignment.get("day", -1)) != int(gs.day) - 1:
		return null
	if not bool(assignment.get("settled", false)):
		return null
	var result: Variant = assignment.get("result")
	if not (result is Dictionary):
		return null
	var row: Dictionary = result
	return {
		"operation_id": str(assignment.get("operation_id", "")),
		"settled_count": int(row.get("settled_count", 0)),
		"gross": int(row.get("gross", 0)),
		"profit_or_loss": int(row.get("profit_or_loss", 0)),
	}

## The adapter's own read of what it would do. The coordinator does not compute
## it — that is the rule this whole file exists to keep.
func _preview(operation_id: String, crew_id: String, spend_limit: int = -1) -> Variant:
	var adapter: Variant = _adapter_for(operation_id)
	if adapter == null or not (adapter as Object).has_method("preview"):
		return null
	return adapter.preview(crew_id, spend_limit)

## A preview at a chosen budget, for a screen offering the player a choice of
## how far to let her go.
func preview_at(operation_id: String, spend_limit: int) -> Variant:
	var expected: Dictionary = OPERATION_CAPABILITY.get(operation_id, {})
	if expected.is_empty():
		return null
	return _preview(operation_id, str(expected["crew_id"]), spend_limit)

## The spends worth offering, from the adapter, derived off the real board.
func spend_options(operation_id: String) -> Array:
	var expected: Dictionary = OPERATION_CAPABILITY.get(operation_id, {})
	if expected.is_empty():
		return []
	var adapter: Variant = _adapter_for(operation_id)
	if adapter == null or not (adapter as Object).has_method("spend_options"):
		return []
	return adapter.spend_options(str(expected["crew_id"]))

## The last claim on this person's day, settled or not, whatever day it was for.
##
## `assignment_for()` is deliberately day-scoped — a stale record is not a claim
## on today. But "what did she bring back last night" is a real question a
## screen needs to answer, and the record is right there. Separate reader rather
## than relaxing the day scope, because the day scope is load-bearing.
func last_assignment(crew_id: String) -> Dictionary:
	var entry: Variant = gs.crew_assignments.get(crew_id)
	return entry if entry is Dictionary else {}

## One field out of the morning's selection, or null when she has not shopped.
func _selection_field(assignment: Dictionary, field: String) -> Variant:
	var selection: Variant = assignment.get("selection")
	return (selection as Dictionary).get(field) if selection is Dictionary else null

## Every operation this build knows how to run, discovered or not.
func operation_ids() -> Array:
	return OPERATION_CAPABILITY.keys()

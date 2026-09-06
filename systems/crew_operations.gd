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
	# BR-D6 (0.9.0): scouting is Eli's from the day he trusts you enough to
	# leave the bag; putting it down is Tone's from the day he is sure.
	"scout_district": [
		{"type": "crew_active", "crew_id": "eli"},
		{"type": "crew_loyalty_min", "crew_id": "eli", "min": 4},
	],
	"hold_it_down": [
		{"type": "crew_active", "crew_id": "tone"},
		{"type": "crew_loyalty_min", "crew_id": "tone", "min": 4},
	],
	"put_it_down": [
		{"type": "crew_active", "crew_id": "tone"},
		{"type": "crew_loyalty_min", "crew_id": "tone", "min": 5},
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
	"hold_it_down": [
		{"type": "crew_active", "crew_id": "tone"},
		{"type": "crew_loyalty_min", "crew_id": "tone", "min": 4},
		{"type": "payroll_not_delinquent", "crew_id": "tone"},
		{"type": "crew_unassigned_today", "crew_id": "tone"},
		{"type": "planning_window_open"},
	],
	"smooth_it_over": [
		{"type": "crew_active", "crew_id": "deshawn"},
		{"type": "crew_loyalty_min", "crew_id": "deshawn", "min": 5},
		{"type": "payroll_not_delinquent", "crew_id": "deshawn"},
		{"type": "crew_unassigned_today", "crew_id": "deshawn"},
		{"type": "planning_window_open"},
	],
	"scout_district": [
		{"type": "crew_active", "crew_id": "eli"},
		{"type": "crew_loyalty_min", "crew_id": "eli", "min": 4},
		{"type": "payroll_not_delinquent", "crew_id": "eli"},
		{"type": "crew_unassigned_today", "crew_id": "eli"},
		{"type": "planning_window_open"},
	],
	"put_it_down": [
		{"type": "crew_active", "crew_id": "tone"},
		{"type": "crew_loyalty_min", "crew_id": "tone", "min": 5},
		{"type": "payroll_not_delinquent", "crew_id": "tone"},
		{"type": "crew_unassigned_today", "crew_id": "tone"},
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
	"scout_district": {"crew_id": "eli", "capability_id": "scout_district"},
	"put_it_down": {"crew_id": "tone", "capability_id": "put_it_down"},
	# HS-D2 (1.2.0): Tone sits on your corners in one district for the night.
	"hold_it_down": {"crew_id": "tone", "capability_id": "hold_it_down"},
}

## BR-D6: what the Crew screen calls each operation, and whether it needs a
## district named.
const OPERATION_LABELS := {
	"907list_run_board": "WORK THE BOARD",
	"run_the_bag": "RUN THE BAG",
	"smooth_it_over": "SMOOTH IT OVER",
	"scout_district": "SCOUT",
	"put_it_down": "PUT IT DOWN",
	"hold_it_down": "HOLD IT DOWN",
}
const OPERATION_TAKES_DISTRICT := ["scout_district", "put_it_down", "smooth_it_over", "hold_it_down"]

## BR-D6: they have their own ideas. Once a member is sure of you (loyalty
## at `PROPOSAL_LOYALTY`), every few mornings one of them texts a proposal
## that fits what is going on -- a problem on a block for Deshawn or Tone,
## a route for Eli, a board for Pherris -- and the reply is the assignment.
const PROPOSAL_LOYALTY := 6
const PROPOSAL_COOLDOWN_DAYS := 3
const PROPOSAL_CHANCE := 0.45

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
	return action in ["assign_crew_operation", "end_crew_brief"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"assign_crew_operation":
			return _assign(str(payload.get("crew_id", "")), str(payload.get("operation_id", "")), payload)
		"end_crew_brief":
			return end_brief(str(payload.get("crew_id", "")))
	return {"ok": false, "reason": "Unknown crew operation action."}

# --- RM-D7..D9 (1.4.0): the standing brief -------------------------------------
#
# What a SPECIALIST LEAD is for. A member at rank 4 or above can be given a
# brief -- their operation, its params and spend limit -- and every morning
# the day-start step claims their day through the same `_assign` path the
# morning tap uses, against the same `ASSIGNMENT_REQUIREMENTS`. The player
# stops re-making a decision they already made, which is the scarce thing
# DD-001 says the organizational layer exists to free.
#
# The brief lives ON the assignment record (`crew_assignments[id].brief`)
# and `_assign` carries it forward when it writes a fresh day-scoped record,
# so the day scope stays load-bearing and nothing reads a stale claim to make
# the brief work. No schema bump: `crew_assignments` already persists whole
# and the validator leaves its keys alone.
#
# A brief SUSPENDS when its gate fails (loyalty, payroll, a member who is
# not active) -- one text naming the reason, once per suspension, and a
# silent resumption the first morning the gate passes again. It ENDS three
# ways only (RM-D8): the player ends it, the member departs, or two nights
# running wrote no proof (a night with nothing to do IS a night that wrote
# no proof -- RM-D3's rule read backwards, so "idle" needs no per-adapter
# definition). A manual assignment to a DIFFERENT operation while a brief
# stands is refused with the brief named; ending it first is the road.

## The rank a brief needs, as a requirement row -- the first use of
## `crew_rank_min` in the build. Evaluated before the operation's own rows so
## "not a lead yet" outranks "it is the afternoon".
const BRIEF_RANK_MIN := 4
const BRIEF_IDLE_NIGHTS := 2

func brief_for(crew_id: String) -> Dictionary:
	var entry: Variant = gs.crew_assignments.get(crew_id)
	if not (entry is Dictionary):
		return {}
	var brief: Variant = (entry as Dictionary).get("brief")
	return brief if brief is Dictionary else {}

func has_brief(crew_id: String) -> bool:
	return not brief_for(crew_id).is_empty()

## Why this person cannot be given a brief right now, or null. Rank first,
## then whatever the operation itself would say this morning.
func brief_blocker(crew_id: String, operation_id: String) -> Variant:
	var verdict: Dictionary = requirements.evaluate_requirement(
		{"type": "crew_rank_min", "crew_id": crew_id, "min": BRIEF_RANK_MIN}, _facts())
	if not bool(verdict["ok"]):
		return verdict
	return assignment_blocker(operation_id)

func _write_brief(crew_id: String, brief: Dictionary) -> void:
	var entry: Variant = gs.crew_assignments.get(crew_id)
	var record: Dictionary = entry if entry is Dictionary else {}
	record["brief"] = brief
	gs.crew_assignments[crew_id] = record

func _erase_brief(crew_id: String) -> void:
	var entry: Variant = gs.crew_assignments.get(crew_id)
	if entry is Dictionary and (entry as Dictionary).has("brief"):
		(entry as Dictionary).erase("brief")
		gs.crew_assignments[crew_id] = entry

## END BRIEF. Stops renewal from tomorrow; today's claim stands, because a
## claimed day is a claimed day.
func end_brief(crew_id: String) -> Dictionary:
	if not has_brief(crew_id):
		return {"ok": false, "reason": "They are not on a brief."}
	_erase_brief(crew_id)
	gs.log_activity("%s is off the brief. Tomorrow is a morning decision again." % _first_name(crew_id), AMBER)
	return {"ok": true}

func _first_name(crew_id: String) -> String:
	return str(gs.crew_member_by_id(crew_id).get("name", crew_id)).split(" ")[0]

## Day start, before the ideas step: every standing brief either claims the
## day, suspends with a reason, stands down, or goes with a departed member.
func day_start_briefs(_today: int) -> void:
	if gs.game_over:
		return
	for crew_key in gs.crew_assignments.keys().duplicate():
		var crew_id := str(crew_key)
		var brief: Dictionary = brief_for(crew_id)
		if brief.is_empty():
			continue
		# RM-D8: the member walked (loyalty zero, or dismissed). The brief
		# goes with them, quietly -- the departure already said everything.
		if not gs.is_recruited(crew_id):
			_erase_brief(crew_id)
			continue
		# A save loaded mid-morning: the day is already claimed. Nothing to
		# renew, and renewing would double-claim it.
		if not assignment_for(crew_id).is_empty():
			continue
		# RM-D8: two nights running with nothing to do. They say so, once,
		# and the brief ends.
		if int(brief.get("idle_nights", 0)) >= BRIEF_IDLE_NIGHTS:
			_erase_brief(crew_id)
			_brief_text(crew_id, str(brief.get("operation_id", "")), "stand_down")
			gs.log_activity("%s stood down. Two nights with nothing to do is two too many." % _first_name(crew_id), AMBER)
			continue
		var operation_id := str(brief.get("operation_id", ""))
		var blocker: Variant = assignment_blocker(operation_id)
		if blocker != null:
			# RM-D7: suspended, not ended. One text per suspension, named by
			# the evaluator's own code; the next morning the gate passes, the
			# brief resumes without a word.
			var code := str((blocker as Dictionary).get("blocker_code", ""))
			if str(brief.get("suspended", "")) != code:
				brief["suspended"] = code
				_write_brief(crew_id, brief)
				_brief_text(crew_id, operation_id, code)
			continue
		if not str(brief.get("suspended", "")).is_empty():
			brief["suspended"] = ""
			_write_brief(crew_id, brief)
		var payload: Dictionary = {"params": brief.get("params", {}), "spend_limit": int(brief.get("spend_limit", -1)),
			"_from_brief": true}
		var result: Dictionary = _assign(crew_id, operation_id, payload)
		if not bool(result.get("ok", false)):
			# The gate passed and the claim still failed (a category error
			# the tables cannot produce). Say so in the feed rather than
			# silently skipping a morning.
			gs.log_activity("%s could not take the brief this morning: %s" % [_first_name(crew_id), str(result.get("reason", ""))], AMBER)

## The brief's own texts, in the member's name. Short, and never the same
## complaint twice in a row.
func _brief_text(crew_id: String, operation_id: String, code: String) -> void:
	var phone: Object = _phone()
	if phone == null:
		return
	var line := ""
	match code:
		"stand_down":
			line = "two nights with nothing to do. im standing down. point me somewhere when theres something"
		"crew_loyalty_min":
			# The standing complaint (`_reconcile_callbacks`) already speaks
			# once per loyalty episode; a second text saying the same thing
			# in the same voice is the clutter TU-D3 forbids.
			return
		"payroll_not_delinquent":
			line = "brief's on hold till I'm paid. that's not a threat, that's arithmetic"
		"crew_active":
			return
		_:
			line = "brief's on hold. %s" % _blocker_copy({"blocker_code": code}).to_lower()
	phone.push_text(_sender_for(operation_id), line, "")

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
	# HS-D2: the line names who said it. It used to name Pherris for every
	# operation on the table.
	gs.log_activity("%s mentions there is something they could take on, if you asked." % _sender_for(operation_id), AMBER)

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
			phone.push_text(_sender_for(operation_id),
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
				phone.push_text(_sender_for(operation_id),
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
	phone.push_text(_sender_for(operation_id),
		_adapter_copy(operation_id, "settlement_text", [assignment],
			_settlement_text(assignment)))

## The feed gets every night of a brief; the phone gets the change.
func _settlement_feed(assignment: Dictionary) -> void:
	if not (assignment.get("result") is Dictionary):
		return
	var operation_id := str(assignment.get("operation_id", ""))
	gs.log_activity("%s: %s" % [_sender_for(operation_id),
		_adapter_copy(operation_id, "settlement_text", [assignment], _settlement_text(assignment))], AMBER)

## Every proof on a record, summed. What a night "did" is measured by
## whether this moved -- RM-D3's producers are the one definition of work.
func _proof_total(crew_id: String) -> int:
	var total := 0
	var proofs: Variant = gs.crew_record(crew_id).get("proofs", {})
	if proofs is Dictionary:
		for value in (proofs as Dictionary).values():
			total += int(value)
	return total

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
	# RM-D7/D8: a standing brief. Rank-gated before the operation's own rows;
	# a member already on a brief for something ELSE is refused until it is
	# ended, unless this is the brief itself renewing.
	var standing: bool = bool(payload.get("standing", false))
	var from_brief: bool = bool(payload.get("_from_brief", false))
	var existing: Dictionary = brief_for(crew_id)
	if standing:
		var rank_verdict: Dictionary = requirements.evaluate_requirement(
			{"type": "crew_rank_min", "crew_id": crew_id, "min": BRIEF_RANK_MIN}, _facts())
		if not bool(rank_verdict["ok"]):
			return {"ok": false, "reason": "A brief is a Specialist Lead's. They are not there yet.",
				"blocker": rank_verdict}
	if not existing.is_empty() and not from_brief and not standing \
			and str(existing.get("operation_id", "")) != operation_id:
		return {"ok": false, "reason": "They are on a brief. End it first.",
			"blocker": {"ok": false, "blocker_code": "on_a_brief",
				"blocker_copy_key": "operations.on_a_brief",
				"current": str(existing.get("operation_id", "")), "required": operation_id}}
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
		"assigned_district_id": str(gs.current_district_id),
	}
	# The brief rides the record forward. A new standing claim writes a fresh
	# brief; a renewal or an ordinary same-operation claim carries the one
	# that was there.
	if standing:
		assignment["brief"] = {
			"operation_id": operation_id,
			"params": assignment["params"],
			"spend_limit": int(assignment["spend_limit"]),
			"since_day": int(gs.day),
			"idle_nights": 0,
			"suspended": "",
			"last_kind": "",
		}
		gs.log_activity("%s is on a standing brief. Mornings are theirs now." % _first_name(crew_id), AMBER)
	elif not existing.is_empty():
		assignment["brief"] = existing
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
		"crew_rank_min": return "A brief is a Specialist Lead's."
		"on_a_brief": return "They are on a brief. End it first."
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
		var proofs_before: int = _proof_total(str(crew_id))
		assignment["result"] = _settle(str(crew_id), assignment, ended_day)
		# RM-D8/D9: on a brief, a night that wrote no proof is an idle night,
		# and the phone hears about a night only when its kind changed.
		var brief: Variant = assignment.get("brief")
		if brief is Dictionary:
			var worked: bool = _proof_total(str(crew_id)) > proofs_before
			(brief as Dictionary)["idle_nights"] = 0 if worked else int((brief as Dictionary).get("idle_nights", 0)) + 1
			var kind := "worked" if worked else "idle"
			var changed: bool = str((brief as Dictionary).get("last_kind", "")) != kind
			(brief as Dictionary)["last_kind"] = kind
			assignment["brief"] = brief
			_settlement_feed(assignment)
			if changed:
				_settlement_callback(assignment)
			continue
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
# --- BR-D6: they have their own ideas ------------------------------------------

## Day start. One proposal a morning at most, from the first trusted member
## with something to propose, on a cooldown per member, seeded on the day.
func day_start_ideas(today: int) -> void:
	if gs.game_over:
		return
	var phone: Object = _phone()
	if phone == null:
		return
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	for operation_id in ["hold_it_down", "put_it_down", "smooth_it_over", "run_the_bag", "907list_run_board", "scout_district"]:
		var crew_id := str((OPERATION_CAPABILITY[operation_id] as Dictionary).get("crew_id", ""))
		if not gs.is_recruited(crew_id):
			continue
		var record: Dictionary = gs.crew_record(crew_id)
		if int(record.get("loyalty", 0)) < PROPOSAL_LOYALTY:
			continue
		if not is_discovered(operation_id):
			continue
		if today - int(record.get("last_proposal_day", -99)) < PROPOSAL_COOLDOWN_DAYS:
			continue
		if assignment_blocker(operation_id) != null:
			continue
		var proposal: Dictionary = _proposal_for(operation_id, crew_id)
		if proposal.is_empty():
			continue
		if rng != null and rng.seeded_int_range(gs.run_seed, "%d:%s:idea" % [today, crew_id], 0, 99) \
				>= int(PROPOSAL_CHANCE * 100.0):
			continue
		record["last_proposal_day"] = today
		gs.crew_records[crew_id] = record
		phone.push_text(_sender_for(operation_id), str(proposal["text"]), "", {
			"kind": "crew_idea",
			"reply_override": {
				"npc": crew_id,
				"a": {"text": str(proposal["yes"]), "reaction": str(proposal["went"])},
				"b": {"text": str(proposal["no"]), "reaction": str(proposal["stayed"])},
				"on_accept": {"kind": "crew_assign", "crew_id": crew_id,
					"operation_id": operation_id, "params": proposal.get("params", {})},
			},
		})
		return

## What a member would propose today, or {} when nothing fits. The text is
## the member's own voice; the params are the situation.
func _proposal_for(operation_id: String, crew_id: String) -> Dictionary:
	var engine: Object = gm.system("consequence") if gm != null else null
	var rules: RefCounted = preload("res://data/consequence_rules.gd").new()
	match operation_id:
		"hold_it_down":
			# HS-D2: a front, or a corner with nobody on it, in a district
			# Curtis has people in.
			var territory: Object = gm.system("territory") if gm != null else null
			if territory == null:
				return {}
			var target := ""
			for block_id in (territory.contested_blocks() as Array):
				target = str(gs.TERRITORY_DEFS.district_of(str(block_id)))
				break
			if target.is_empty():
				for id in gs.territory_nodes.keys():
					var district_id := str(gs.TERRITORY_DEFS.district_of(str(id)))
					if int(gs.district_by_id(district_id).get("rival", 0)) > 0 \
							and int((gs.territory_nodes[id] as Dictionary).get("soldiers", 0)) <= 0:
						target = district_id
						break
			if target.is_empty():
				return {}
			var name := str(gs.district_by_id(target).get("name", target)).capitalize()
			return {"text": "His people been by %s twice this week. I'll sit on it tonight. Say the word." % name,
				"yes": "sit on it", "no": "not tonight", "went": "Say less.",
				"stayed": "Your corner.", "params": {"district_id": target}}
		"put_it_down", "smooth_it_over":
			var worst := ""
			var worst_score := 0.0
			for district_id in (gs.districts_unlocked as Array):
				for family in rules.PRESSURE_FAMILIES:
					var score: float = float(engine.pressure_score(str(district_id), str(family))) if engine != null else 0.0
					if score > worst_score:
						worst_score = score
						worst = str(district_id)
			if worst.is_empty() or worst_score < 2.0:
				return {}
			var name := str(gs.district_by_id(worst).get("name", worst)).capitalize()
			if operation_id == "put_it_down":
				return {"text": "Problem in %s. I can handle it. Say the word." % name,
					"yes": "handle it", "no": "not yet", "went": "Done by tonight.",
					"stayed": "Your call.", "params": {"district_id": worst}}
			return {"text": "people in %s talking about you wrong. give me the day and ill turn it down. you want that?" % name.to_lower(),
				"yes": "do it. appreciate you", "no": "let it ride for now", "went": "say less. ill be out there",
				"stayed": "aight. it aint going anywhere tho", "params": {"district_id": worst}}
		"run_the_bag":
			var economy: Object = gm.system("economy") if gm != null else null
			var routes: Array = economy.known_routes() if economy != null else []
			if routes.is_empty() or gs.inventory.is_empty():
				return {}
			var route: Dictionary = routes[0]
			return {"text": "heard %s is paying over on %s. i can run the bag while you do you. want me to?" % [
					str(route.get("product_name", route.get("product_id", "it"))).to_lower(),
					str(route.get("name", "the other side"))],
				"yes": "run it", "no": "hold the bag", "went": "on it. dont text me till tonight",
				"stayed": "ok. it was a good one tho"}
		"907list_run_board":
			if gs.list_holdings.is_empty():
				return {}
			return {"text": "you got stuff sitting on the list. let me work the board today, I know who's buying",
				"yes": "work it", "no": "ill handle it", "went": "thats why I text you first",
				"stayed": "somebody else will then"}
		"scout_district":
			var unseen := ""
			for district_id in (gs.districts_unlocked as Array):
				if str(district_id) != str(gs.current_district_id) and int(gs.wander_seen.get("arrival:%s" % str(district_id), 0)) == 0:
					unseen = str(district_id)
					break
			if unseen.is_empty():
				return {}
			var name := str(gs.district_by_id(unseen).get("name", unseen)).capitalize()
			return {"text": "you aint been to %s yet. i can go look around for a day and tell you whats what" % name.to_lower(),
				"yes": "go look", "no": "not today", "went": "bet. eyes open",
				"stayed": "later the road wont be quiet", "params": {"district_id": unseen}}
	return {}

## BR-D6: the reply said yes. Assign it, inside the dispatch the reply
## already is. Returns the assignment result so the phone can say why not.
func accept_idea(spec: Dictionary) -> Dictionary:
	var crew_id := str(spec.get("crew_id", ""))
	var operation_id := str(spec.get("operation_id", ""))
	var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
	return _assign(crew_id, operation_id, {"params": params})

func operation_ids() -> Array:
	return OPERATION_CAPABILITY.keys()

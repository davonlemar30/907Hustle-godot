extends RefCounted
## Eli running the bag — the domain half of `run_the_bag`.
##
## The coordinator owns the day: discovery, the assignment gates, claiming his
## day, settling it at night. This owns what the day MEANS, which is the shape
## `list_adapter.gd` established and the reason a second operation needed no
## `if operation_id ==` anywhere in the coordinator.
##
## ## What he does, and why it is this
##
## Batch 3 gave a trip taken holding a real chance of being stopped — the only
## leg of the courier route that could lose money rather than merely earn less
## of it, and the one that reaches a cargo-limited courier. It shipped without a
## counterplay beyond "carry less", which is not a decision so much as a smaller
## version of the same one.
##
## Eli is the counterplay. "Moves small bundles and knows service-road exits"
## has been his roster line since the crew shipped and he has never once done
## anything. Assign him and the day's carrying is his: the stop chance comes
## down by the fraction his rank is worth.
##
## ## He does not carry FOR you
##
## The bag still moves when you move — this is not a second inventory or a
## courier you dispatch to a district. That would be a different operation and a
## much larger one. What his day buys is that the trip is walked by somebody who
## knows which exits are which, and the risk reflects it.
##
## ## Nothing is spent
##
## No `select()`, no `spend_limit`, no `preview()`. The commitment is his day and
## the wage it costs, which is the whole price. An adapter is not obliged to
## implement anything but `settle()`.

const OPERATION_ID := "run_the_bag"
const CAPABILITY_ID := "run_the_bag"

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node, crew_operations: RefCounted) -> void:
	gs = game_state
	gm = manager
	# Registration is RUNTIME, not run state — see crew_operations.register_adapter.
	crew_operations.register_adapter(OPERATION_ID, self)

## No actions of its own. The player assigns through crew_operations.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The runner adapter takes no actions."}

## The fraction of a stop's chance Eli takes off today, or 0.0 when he is not
## out. Read by `EconomySystem.resolve_carry` at the moment of the trip.
##
## Asked of the ASSIGNMENT rather than of the roster: having Eli on the crew is
## not the same as having spent his day on it, and the difference is the whole
## operation. `assignment_for` is day-scoped, so yesterday's claim is not
## today's.
func carry_relief() -> float:
	var ops: Object = gm.system("crew_operations") if gm != null else null
	if ops == null:
		return 0.0
	var assignment: Dictionary = ops.assignment_for("eli")
	if assignment.is_empty():
		return 0.0
	if str(assignment.get("operation_id", "")) != OPERATION_ID:
		return 0.0
	var rank: int = int(gs.crew_record("eli").get("tier", 1))
	return clampf(float(gs.crew_capability_value("eli", CAPABILITY_ID,
		"carry_relief_by_rank", rank, 0.0)), 0.0, 0.95)

## What the night made of it.
##
## Counts the trips he actually covered, which the economy records as it goes —
## a day with no travel in it is a day he spent waiting, and the report says so
## rather than claiming a benefit nothing collected.
func settle(_crew_id: String, assignment: Dictionary, _ended_day: int) -> Variant:
	var covered: int = int(assignment.get("trips_covered", 0))
	var stopped: int = int(assignment.get("stops_absorbed", 0))
	return {"trips_covered": covered, "stops_absorbed": stopped}

# --- his voice --------------------------------------------------------------

func sender() -> String:
	return "Eli"

func discovery_text() -> String:
	return "You keep riding across town with your hands full. " \
		+ "Let me walk it tomorrow. I know which exits nobody watches."

func loyalty_warning_text() -> String:
	return "Ask me again when you've squared up. I'm not carrying for free."

func assignment_line(_selection: Variant, _spend_limit: int) -> String:
	return "Eli has the day. He walks whatever you're moving."

func settlement_text(assignment: Dictionary) -> String:
	var result: Variant = assignment.get("result")
	var covered: int = int((result as Dictionary).get("trips_covered", 0)) \
		if result is Dictionary else 0
	if covered <= 0:
		return "Sat around all day. You never went anywhere with anything."
	return "Walked %d for you. Quiet the whole way, which is the idea." % covered

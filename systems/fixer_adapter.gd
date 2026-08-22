extends RefCounted
## Deshawn smoothing it over — the domain half of `smooth_it_over`.
##
## ## What he does, and why it is this
##
## District Pressure is the block's memory of your routine, and until v0.1.0 the
## only way down was to stop working the corner. v0.1.0 added the other half —
## a clean outcome pays some back — which rewards precision but still does
## nothing for a corner that is already burned.
##
## Deshawn is the third way down. "De-escalates conflicts, recruits through
## trust, keeps Spenard talking" is his roster line, and keeping Spenard talking
## is exactly what a hot block needs: he spends the day among people who have
## been watching you, and by evening they have something else to talk about.
##
## ## It is not free and it is not fast
##
## A day of his, a wage, and points off ONE district. He cannot work a corner he
## is not standing in — the operation takes the district as a parameter and
## defaults to where the player is, which is the `params` passthrough batch 6a
## added for exactly this.
##
## ## Relief, not recovery
##
## `recover_pressure` is used rather than anything that touches `last_gain_day`
## or `quiet_days`. What Deshawn does is take points off; it does not make the
## day a quiet one, and a day you worked is still a day you worked.

const OPERATION_ID := "smooth_it_over"
const CAPABILITY_ID := "smooth_it_over"
const RULES := preload("res://data/consequence_rules.gd")

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node, crew_operations: RefCounted) -> void:
	gs = game_state
	gm = manager
	crew_operations.register_adapter(OPERATION_ID, self)

func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The fixer adapter takes no actions."}

## Which corner he works. The assignment's `params`, or where the player stood
## when they sent him — he cannot smooth over a block he never went to.
func _district_for(assignment: Dictionary) -> String:
	var params: Variant = assignment.get("params")
	if params is Dictionary:
		var named := str((params as Dictionary).get("district_id", ""))
		if not named.is_empty():
			return named
	return str(assignment.get("assigned_district_id", gs.current_district_id))

func _relief_amount() -> float:
	var rank: int = int(gs.crew_record("deshawn").get("tier", 1))
	return maxf(0.0, float(gs.crew_capability_value("deshawn", CAPABILITY_ID,
		"pressure_relief_by_rank", rank, 0.0)))

## What a day of his would be worth on a given corner, without spending it.
## Pure — the screen can show the player what they are buying.
func preview(_crew_id: String, _spend_limit: int) -> Dictionary:
	var district: String = str(gs.current_district_id)
	var engine: Object = gm.system("consequence") if gm != null else null
	var amount: float = _relief_amount()
	var families: Array = []
	if engine != null:
		var rules: RefCounted = RULES.new()
		for family in rules.PRESSURE_FAMILIES:
			var score: float = float(engine.pressure_score(district, str(family)))
			if score > 0.0:
				families.append({"family": str(family), "score": score,
					"band": str(engine.pressure_band(district, str(family)))})
	return {"district_id": district, "relief": amount, "families": families}

## The night. Takes the authored relief off every family that has anything on
## it, in the one district he worked.
##
## Every family rather than the loudest, because what he is doing is talking to
## people rather than addressing one kind of complaint — and because picking
## "the loudest" would make his value depend on which crime the player happened
## to commit most, which is a strange thing for a fixer to care about.
func settle(_crew_id: String, assignment: Dictionary, _ended_day: int) -> Variant:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return null
	var district: String = _district_for(assignment)
	var amount: float = _relief_amount()
	if amount <= 0.0:
		return {"district_id": district, "recovered": 0.0, "families": 0}
	var rules: RefCounted = RULES.new()
	var total: float = 0.0
	var touched: int = 0
	for family in rules.PRESSURE_FAMILIES:
		var moved: float = float(engine.recover_pressure(district, str(family), amount))
		if moved > 0.0:
			total += moved
			touched += 1
	return {"district_id": district, "recovered": total, "families": touched}

# --- his voice --------------------------------------------------------------

func sender() -> String:
	return "Deshawn"

func discovery_text() -> String:
	return "Block's been talking about you. Not all of it good. " \
		+ "Give me a day out there and I'll turn the temperature down."

func loyalty_warning_text() -> String:
	return "I'm out there vouching for you. Least you can do is pay me."

func assignment_line(_selection: Variant, _spend_limit: int) -> String:
	return "Deshawn has the day. He's out on the block, talking."

func settlement_text(assignment: Dictionary) -> String:
	var result: Variant = assignment.get("result")
	var recovered: float = float((result as Dictionary).get("recovered", 0.0)) \
		if result is Dictionary else 0.0
	if recovered <= 0.0:
		return "Nothing out there needed smoothing. Quiet block today."
	return "Talked to everybody worth talking to. People have moved on to something else."

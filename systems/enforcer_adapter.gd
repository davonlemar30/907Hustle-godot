extends RefCounted
## Put it down -- Tone's operation (The Block Remembers, PR 5, BR-D6). Where
## Deshawn handles a problem with community (`smooth_it_over` recovers
## pressure by talking), Tone handles it with force: the pressure comes off
## harder, and it costs heat, because force is the kind of thing a block
## remembers. Rides the crew-operations substrate.

const OPERATION_ID := "put_it_down"
const CAPABILITY_ID := "put_it_down"
const RULES := preload("res://data/consequence_rules.gd")
## What it costs the district in heat. What Tone takes off, by rank, lives on
## `GameState.CREW_CAPABILITIES` as `relief_by_rank` -- RM-D2 (1.4.0) moved it
## there from a constant here, because a rank curve in an adapter was a second
## home for a fact the capability table owns.
const HEAT_COST := 1.5

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node, crew_operations: RefCounted) -> void:
	gs = game_state
	gm = manager
	crew_operations.register_adapter(OPERATION_ID, self)

func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The enforcer adapter takes no actions."}

func _district_for(assignment: Dictionary) -> String:
	var params: Variant = assignment.get("params")
	if params is Dictionary:
		var named := str((params as Dictionary).get("district_id", ""))
		if not named.is_empty():
			return named
	return str(gs.current_district_id)

func relief_amount() -> float:
	var rank: int = int(gs.crew_record("tone").get("tier", 1))
	return maxf(0.0, float(gs.crew_capability_value("tone", CAPABILITY_ID,
		"relief_by_rank", rank, 0.0)))

func settle(_crew_id: String, assignment: Dictionary, _ended_day: int) -> Variant:
	var engine: Object = gm.system("consequence") if gm != null else null
	var heat: Object = gm.system("heat") if gm != null else null
	if engine == null:
		return null
	var district: String = _district_for(assignment)
	var rules: RefCounted = RULES.new()
	var total: float = 0.0
	var touched: int = 0
	for family in rules.PRESSURE_FAMILIES:
		var moved: float = float(engine.recover_pressure(district, str(family), relief_amount()))
		if moved > 0.0:
			total += moved
			touched += 1
	if total > 0.0 and heat != null:
		heat.apply_gain(HEAT_COST, heat.FAMILY_NONE, district, {"source_id": "crew_put_it_down"})
	# RM-D3: a problem actually put down is proof. A quiet district is not.
	if total > 0.0:
		_crew().record_proof("tone", OPERATION_ID)
	return {"district_id": district, "recovered": total, "families": touched,
		"heat": HEAT_COST if total > 0.0 else 0.0}

func _crew() -> Object:
	return gm.system("crew") if gm != null else null

func sender() -> String:
	return "Tone"

func discovery_text() -> String:
	return "Somebody's a problem. Say the word."

func loyalty_warning_text() -> String:
	return "Pay me."

func assignment_line(_selection: Variant, _spend_limit: int) -> String:
	return "Tone has the day. Somebody is about to have a worse one."

func settlement_text(assignment: Dictionary) -> String:
	var result: Variant = assignment.get("result")
	var recovered: float = float((result as Dictionary).get("recovered", 0.0)) \
		if result is Dictionary else 0.0
	if recovered <= 0.0:
		return "Nobody needed it. Quiet."
	return "Handled. They know it was you. That was the point."

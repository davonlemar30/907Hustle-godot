extends RefCounted
## Scout a district -- Eli's second operation (The Block Remembers, PR 5,
## BR-D6). Eli runs routes; a day spent in a district he is not selling in
## comes back as a report: what is open on the board, what Curtis holds,
## what the police are like, and the one route worth the fare. Rides the
## crew-operations substrate like every other operation: assigned in the
## morning, settled at night, reported by text.

const OPERATION_ID := "scout_district"
const CAPABILITY_ID := "scout_district"
const TERRITORY_DEFS := preload("res://data/territory_definitions.gd")

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node, crew_operations: RefCounted) -> void:
	gs = game_state
	gm = manager
	crew_operations.register_adapter(OPERATION_ID, self)

func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The scout adapter takes no actions."}

func _district_for(assignment: Dictionary) -> String:
	var params: Variant = assignment.get("params")
	if params is Dictionary:
		var named := str((params as Dictionary).get("district_id", ""))
		if not named.is_empty():
			return named
	return str(gs.current_district_id)

func settle(_crew_id: String, assignment: Dictionary, _ended_day: int) -> Variant:
	var district_id := _district_for(assignment)
	var district: Dictionary = gs.district_by_id(district_id)
	if district.is_empty():
		return null
	var territory: Object = gm.system("territory") if gm != null else null
	var open := 0
	var curtis := 0
	var yours := 0
	for node in TERRITORY_DEFS.nodes_in(district_id):
		var id := str(node["id"])
		if gs.holds_block(id):
			yours += 1
		elif str(node.get("starting_owner", "")) == TERRITORY_DEFS.OWNER_CURTIS:
			curtis += 1
		else:
			open += 1
	var route: Dictionary = {}
	var economy: Object = gm.system("economy") if gm != null else null
	if economy != null:
		for entry in economy.known_routes():
			if str((entry as Dictionary).get("district_id", "")) == district_id:
				route = entry
				break
	return {"district_id": district_id, "open": open, "curtis": curtis, "yours": yours,
		"police": int(district.get("police", 0)), "rival": int(district.get("rival", 0)),
		"route": route}

func sender() -> String:
	return "Eli"

func discovery_text() -> String:
	return "i can spend a day anywhere in town and come back with what's what. " \
		+ "who's holding, who's watching, what's paying. say where"

func loyalty_warning_text() -> String:
	return "not running all over town for somebody who don't pay me"

func assignment_line(_selection: Variant, _spend_limit: int) -> String:
	return "Eli has the day. He's on the Mover with his eyes open."

func settlement_text(assignment: Dictionary) -> String:
	var result: Variant = assignment.get("result")
	if not (result is Dictionary):
		return "nothing to report. wasted a day"
	var r: Dictionary = result
	var name := str(gs.district_by_id(str(r.get("district_id", ""))).get("name", "there")).capitalize()
	var parts: Array = []
	parts.append("%s: %d open, %d curtis's, %d yours" % [name.to_lower(), int(r.get("open", 0)),
		int(r.get("curtis", 0)), int(r.get("yours", 0))])
	var police: int = int(r.get("police", 0))
	parts.append("cops %s" % ("everywhere" if police >= 3 else ("around" if police == 2 else "thin")))
	var rival: int = int(r.get("rival", 0))
	if rival >= 3:
		parts.append("curtis runs it")
	elif rival >= 1:
		parts.append("curtis has people")
	else:
		parts.append("nobody's block")
	var route: Dictionary = r.get("route", {})
	if not route.is_empty():
		parts.append("%s pays +$%d there" % [str(route.get("product_name", route.get("product_id", "product"))).to_lower(),
			int(route.get("edge", 0))])
	return ". ".join(parts)

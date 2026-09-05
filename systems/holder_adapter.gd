extends RefCounted
## Hold it down -- Tone's other operation (HS-D2, 1.2.0). Where `put_it_down`
## takes pressure off a district by force, this one is presence: Tone sits on
## your corners in one district for the night, and nobody tests a corner Tone
## is sitting on. A contested front there counts two quiet nights in one,
## because his people came by, saw who was standing there, and left.
##
## Rides the crew-operations substrate like the rest: discovered off Tone's
## loyalty, assigned in the morning, exclusive with his other work for the
## day, settled at `day_ending`. The territory system reads the live
## assignment at probe time (`TerritorySystem.held_down_district()`); this
## adapter only reports what the night was.

const OPERATION_ID := "hold_it_down"
const CAPABILITY_ID := "hold_it_down"

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node, crew_operations: RefCounted) -> void:
	gs = game_state
	gm = manager
	crew_operations.register_adapter(OPERATION_ID, self)

func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The holder adapter takes no actions."}

func _district_for(assignment: Dictionary) -> String:
	var params: Variant = assignment.get("params")
	if params is Dictionary:
		var named := str((params as Dictionary).get("district_id", ""))
		if not named.is_empty():
			return named
	return str(gs.current_district_id)

## Settled before Territory's night, so this only reports the posture. The
## probes themselves read the assignment.
func settle(_crew_id: String, assignment: Dictionary, _ended_day: int) -> Variant:
	var territory: Object = gm.system("territory") if gm != null else null
	var district: String = _district_for(assignment)
	var held: int = int(territory.held_in(district)) if territory != null else 0
	var contested := 0
	if territory != null:
		for block_id in (territory.contested_blocks() as Array):
			if str(gs.TERRITORY_DEFS.district_of(str(block_id))) == district:
				contested += 1
	return {"district_id": district, "held": held, "contested": contested}

func sender() -> String:
	return "Tone"

func discovery_text() -> String:
	return "I can sit on a corner for you. Nobody tests a corner I'm sitting on."

func loyalty_warning_text() -> String:
	return "Pay me."

func assignment_line(_selection: Variant, _spend_limit: int) -> String:
	return "Tone has the night. He is going to stand somewhere and not move."

func settlement_text(assignment: Dictionary) -> String:
	var result: Variant = assignment.get("result")
	if not (result is Dictionary):
		return "Sat on it."
	var held: int = int((result as Dictionary).get("held", 0))
	if held <= 0:
		return "Nothing to sit on out there. You know that."
	if int((result as Dictionary).get("contested", 0)) > 0:
		return "They came by. Saw me. Left."
	return "Sat on it. Nobody came by."

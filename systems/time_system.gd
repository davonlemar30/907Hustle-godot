extends RefCounted
## Time system — slot advancement and day-cross.
##
## MORNING → AFTERNOON → EVENING → NIGHT → (day cross) → MORNING. Every advance
## evolves the market (called directly on the economy so the whole tick is one
## dispatch = one notify_changed). A day-cross bumps the day and emits day_crossed
## so later systems (wages, territory income, events) can hook in.

const SLOTS := ["MORNING", "AFTERNOON", "EVENING", "NIGHT"]

var gs: Node
var economy: RefCounted

func setup(game_state: Node, economy_system: RefCounted) -> void:
	gs = game_state
	economy = economy_system

func can_handle(action: String) -> bool:
	return action == "advance_time"

func handle(action: String, _payload: Dictionary) -> Dictionary:
	if action != "advance_time":
		return {"ok": false, "reason": "Unknown time action."}
	var next: int = gs.time_slots_today + 1
	if next >= SLOTS.size():
		gs.day += 1
		gs.time_slots_today = 0
		gs.time_slot = SLOTS[0]
		gs.day_crossed.emit()
	else:
		gs.time_slots_today = next
		gs.time_slot = SLOTS[next]
	economy.evolve()
	return {"ok": true}

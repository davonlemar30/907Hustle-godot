extends RefCounted
## Travel system — moving between districts.
##
## Canon charges the same way for both legs of a trip. `TRAVEL` and `BUS_TRAVEL`
## each spend `access.cashCost` and log either "for $5" or "on your pass"
## (game-core.js:8718-8760), and both run through advanceRun, which costs one
## slot. So: a flat fare plus one slot, in either direction.
##
## Not modelled yet, deliberately:
##   - transit passes (`transitCovered`) that zero the fare
##   - WALK_HOME, the no-fare fallback that costs two slots and 3 health
##   - arrival events on reaching Downtown
## Each is its own feature; this system just moves the player and bills them.

## game-core.js:2850 — "Need $5 fare."
const FARE := 5

var gs: Node
var time_system: RefCounted
## Reached for the wallet. Fare is a spend like any other.
var gm: Node

func setup(game_state: Node, time: RefCounted, manager: Node) -> void:
	gs = game_state
	time_system = time
	gm = manager

func can_handle(action: String) -> bool:
	return action == "travel"

func handle(action: String, payload: Dictionary) -> Dictionary:
	if action != "travel":
		return {"ok": false, "reason": "Unknown travel action."}

	var target: String = str(payload.get("district_id", ""))
	if target.is_empty():
		return {"ok": false, "reason": "No destination."}
	# Canon returns the state unchanged for a move to where you already are.
	if target == gs.current_district_id:
		return {"ok": false, "reason": "You're already here."}
	var district: Dictionary = gs.district_by_id(target)
	if district.is_empty():
		return {"ok": false, "reason": "No such district."}
	if gs.cash < FARE:
		return {"ok": false, "reason": "Need $%d fare." % FARE}

	var wallet: Object = gm.system("wallet")
	wallet.spend(FARE, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "travel_fare"})
	gs.current_district_id = target
	# One slot, the same as any other district action. Routed through the time
	# system rather than reimplemented so the day-cross and the market evolve
	# stay in one place.
	time_system.handle("advance_time", {})
	# The district changed, so the price mirror the screens bind must now show
	# THIS district's market. (The advance only re-walks prices on a day-cross.)
	preload("res://systems/economy.gd").sync_display_prices(gs)

	# Watchers appear during ordinary movement, never during the crime itself.
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	var watcher := ""
	if curtis != null:
		watcher = str(curtis.maybe_watcher_encounter("travel"))
	return {"ok": true, "arrived": district.get("name", ""), "watcher": watcher}

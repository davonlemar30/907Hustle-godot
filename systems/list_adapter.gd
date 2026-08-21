extends RefCounted
## 907List domain adapter — Pherris running the board.
##
## FS-001.7, and the first thing in the game a crew member does that you can
## measure in dollars. `crew_operations.gd` owns the lifecycle — discovery,
## eligibility, whose day is claimed, when the claim closes — and knows nothing
## about listings. This file is the other half: it knows what "running the
## board" means and nothing about how a day ends.
##
## ## Two moments, not one
##
## **Morning (`select`)** — she picks and pays. The money leaves when the stock
## is picked up, which is what makes an assignment a real commitment rather than
## a bet: the cash is gone before anyone knows what the items are worth.
##
## **Night (`settle`)** — the stock turns back into money through the SAME path
## a personal sale uses (`nine07list.settle_holding`), so the value, the Curtis
## broadcast and the Exposure footprint are identical to the player doing it.
##
## Buying up front also removes an exploit that a settle-time purchase would
## create: the player could otherwise assign her, spend the day's cash
## elsewhere, and have her buy with money that was never there.
##
## ## What she will not touch
##
## Rough-condition items. She is a Downtown contact list with a reputation, not
## a scrapper — canon's Broker tier is built on clean deals, and a rough item is
## how a dispute happens. This is the one piece of taste in the selection and it
## is deliberate: everything else about her picking is mechanical.
##
## ## Ordering is cheapest-first, and that is a choice worth naming
##
## She buys up the price list, not down it. Cheap stock spreads a fixed cycle
## budget across more items, and more items is more chances at a good realised
## value — the 907List's whole mechanic is that value is hidden, so volume beats
## a single expensive guess. It also means a small spend limit produces a full
## day's work instead of one purchase and an early stop.
##
## Ties break on the item's ORIGINAL board position. GDScript's `sort_custom` is
## not stable, so two items at the same price would otherwise resolve
## differently on different runs — the index makes the order total.

## Canon's Broker standing is built on clean deals; a rough item is how a
## dispute happens. The one filter she applies.
const REJECTED_CONDITION := "rough"

## Why she stopped, in the order the reasons are checked. First one that fires
## wins, so the reported reason is the most fundamental thing in her way rather
## than whichever happened to be true last.
const STOP_CAPACITY := "capacity"
const STOP_NO_ACCEPTABLE := "no_acceptable"
const STOP_SPEND_LIMIT := "spend_limit"
const STOP_CASH := "cash"
const STOP_CYCLE_CAP := "cycle_cap"

const OPERATION_ID := "907list_run_board"
const CAPABILITY_ID := "907list_run_board"

var gs: Node
var gm: Node
var list_system: RefCounted

func setup(game_state: Node, manager: Node, nine07list: RefCounted,
		crew_operations: RefCounted) -> void:
	gs = game_state
	gm = manager
	list_system = nine07list
	# Registration is RUNTIME, not run state — see crew_operations.register_adapter.
	crew_operations.register_adapter(OPERATION_ID, self)

## No actions of its own. The player assigns through crew_operations; this is
## called by the coordinator, never dispatched to.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The 907List adapter takes no actions."}

# --- morning: picking and paying -------------------------------------------

## What she would work from today: the same board the player sees, minus what
## she will not touch, cheapest first.
##
## Reads `todays_listings()` rather than the item table, so shared consumption
## is already applied — anything the player took this morning is simply not
## there. That is the seam FS-001.2 left open on purpose: nothing in the
## consumption record assumes the buyer is the player.
func acceptable_board() -> Array:
	var ranked: Array = []
	var position: int = 0
	for listing in list_system.todays_listings():
		var item: Dictionary = listing
		if str(item.get("condition", "")) != REJECTED_CONDITION:
			ranked.append({"item": item, "position": position, "buy": int(item["buy"])})
		position += 1
	# Cheapest first, ties broken by original board position so the order is
	# total. `sort_custom` is not stable, so the position is doing real work.
	ranked.sort_custom(func(a, b):
		if int(a["buy"]) == int(b["buy"]):
			return int(a["position"]) < int(b["position"])
		return int(a["buy"]) < int(b["buy"]))
	var out: Array = []
	for entry in ranked:
		out.append(entry["item"])
	return out

## The cycles her rank allows. Read through the capability curve, so a rank
## above the authored range clamps to the top value rather than falling to zero.
func cycle_cap(crew_id: String) -> int:
	var rank: int = int(gs.crew_record(crew_id).get("tier", 1))
	return int(gs.crew_capability_value(
		crew_id, CAPABILITY_ID, "max_cycles_by_rank", rank, 0))

## What she WOULD do, without doing it.
##
## The plan and the purchase run through this one function, which is the whole
## point: a preview that re-derives the answer separately is a second
## implementation, and the day it drifts is the day the player is shown a number
## the game does not honour. `select()` executes exactly what `preview()` shows.
##
## Pure — reads state, writes nothing.
func plan(crew_id: String, spend_limit: int) -> Dictionary:
	var cap: int = cycle_cap(crew_id)
	var capacity: int = list_system.capacity()
	var held: int = gs.list_holdings.size()
	var candidates: Array = acceptable_board()

	var items: Array = []
	var spent: int = 0
	var stop_reason: String = ""
	var index: int = 0

	while true:
		# Priority order, and it is the authored one: the reason she stopped
		# should be the most fundamental thing in her way. Nowhere to put it
		# outranks nothing worth taking, which outranks the budget, which
		# outranks the wallet, which outranks having done enough for one day.
		if held + items.size() >= capacity:
			stop_reason = STOP_CAPACITY
			break
		if index >= candidates.size():
			stop_reason = STOP_NO_ACCEPTABLE
			break
		var item: Dictionary = candidates[index]
		var cost: int = int(item["buy"])
		if spend_limit >= 0 and spent + cost > spend_limit:
			stop_reason = STOP_SPEND_LIMIT
			break
		if gs.cash - spent < cost:
			stop_reason = STOP_CASH
			break
		if items.size() >= cap:
			stop_reason = STOP_CYCLE_CAP
			break
		items.append({"item_id": str(item["id"]), "name": str(item["name"]), "cost": cost})
		spent += cost
		index += 1

	return {
		"items": items,
		"total_spent": spent,
		"cycles_used": items.size(),
		"cycle_cap": cap,
		"stop_reason": stop_reason,
		"spend_limit": spend_limit,
		"storage_capacity": capacity,
		"storage_free": maxi(0, capacity - held),
	}

## The plan, plus what it would cost against what is in the pocket. This is what
## a screen shows before the player commits.
func preview(crew_id: String, spend_limit: int) -> Dictionary:
	var planned: Dictionary = plan(crew_id, spend_limit)
	planned["cash_on_hand"] = gs.cash
	planned["cash_after"] = gs.cash - int(planned["total_spent"])
	return planned

## What she could be asked to spend, as the running total of taking 1, 2, ... up
## to her cap. Derived from the real board rather than offered as round numbers,
## so every option shown is a spend that actually buys something.
func spend_options(crew_id: String) -> Array:
	var full: Dictionary = plan(crew_id, -1)
	var options: Array = []
	var running: int = 0
	for item in full["items"]:
		running += int((item as Dictionary)["cost"])
		options.append({"cycles": options.size() + 1, "spend": running})
	return options

## Buy until something stops her. Runs inside the assignment dispatch, so every
## mutation here rides that action's single `notify_changed()`.
##
## Executes `plan()` rather than re-deciding, so what the player was shown is
## what happens.
##
## Returns `{ok, purchased, total_spent, cycles_used, stop_reason, spend_limit}`.
## `ok` is false only when the board offered her nothing at all — and even then
## the assignment still stands, because she spent the day looking.
func select(crew_id: String, assignment: Dictionary) -> Dictionary:
	var limit: int = int(assignment.get("spend_limit", -1))
	var planned: Dictionary = plan(crew_id, limit)
	var purchased: Array = []

	for entry in planned["items"]:
		var item_id := str((entry as Dictionary)["item_id"])
		var cost: int = int((entry as Dictionary)["cost"])
		var wallet: Object = gm.system("wallet")
		wallet.spend(cost, wallet.ROUTINE_DIRTY_FIRST,
			{"source_id": "list_buy_pherris_%s" % item_id})
		gs.list_holdings.append({
			"item_id": item_id,
			"bought_day": gs.day,
			# The stamp the v6 → v7 migration made room for. Everything the
			# player bought reads "player"; this is the other answer.
			"source": list_system.SOURCE_PHERRIS,
		})
		# The shared seam. Her pickup consumes the opportunity exactly as a
		# personal buy does, so the player cannot take the same listing after.
		list_system._mark_taken(item_id)
		purchased.append({"item_id": item_id, "cost": cost})

	return {
		"ok": not purchased.is_empty(),
		"purchased": purchased,
		"total_spent": int(planned["total_spent"]),
		"cycles_used": purchased.size(),
		"stop_reason": str(planned["stop_reason"]),
		"spend_limit": limit,
	}

# --- night: turning it back into money -------------------------------------

## Which of her holdings are ready to close. Uses the tier's own `sell_delay`,
## so this stays right if Broker standing ever stops being same-day.
func _settleable_index() -> int:
	var delay: int = int(gs.market_tier()["sell_delay"])
	for i in gs.list_holdings.size():
		var held: Dictionary = gs.list_holdings[i]
		if str(held.get("source", "")) != list_system.SOURCE_PHERRIS:
			continue
		if gs.day - int(held.get("bought_day", gs.day)) < delay:
			continue
		return i
	return -1

## Night. Close everything of hers that is ready, through the shared path.
##
## Idempotent by contract: a settled assignment returns its stored result rather
## than running again. The coordinator already guards this, so reaching the
## guard means somebody called in directly — and paying a day out twice is the
## kind of bug that only shows up in the cash total.
##
## Holdings not yet past the sell delay stay held and close on a later night.
func settle(_crew_id: String, assignment: Dictionary, _ended_day: int) -> Dictionary:
	if bool(assignment.get("settled", false)) and assignment.get("result") != null:
		return assignment["result"]

	var results: Array = []
	var gross: int = 0
	var profit: int = 0
	# Re-scan each time rather than caching indices: settling removes a holding
	# and every index after it shifts. Cheap at this size, and obviously correct
	# in a way an index-adjusting loop is not.
	var guard: int = 0
	while guard < 64:
		var index: int = _settleable_index()
		if index < 0:
			break
		var item_id := str((gs.list_holdings[index] as Dictionary).get("item_id", ""))
		var sold: Dictionary = list_system.settle_holding(index, list_system.DELEGATED)
		if not bool(sold.get("ok", false)):
			break
		gross += int(sold["got"])
		profit += int(sold["delta"])
		results.append({
			"item_id": item_id, "got": int(sold["got"]), "delta": int(sold["delta"]),
		})
		guard += 1

	return {
		"settled_count": results.size(),
		"gross": gross,
		"profit_or_loss": profit,
		"individual_results": results,
	}

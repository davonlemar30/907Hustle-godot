extends RefCounted
## 907List — buy low from strangers, sell for what it is actually worth.
##
## Ported from src/data/market.js (LISTING_ITEMS, MARKET_TIERS) and the
## BUY_907LIST / SELL_907LIST reducers.
##
## The mechanic is information, not arithmetic. Every item has a hidden
## `true_value` band, and four of the eighteen are traps that sell for less than
## they cost. A Scrapper's board shows only title and price, so condition is a
## guess; Flipper shows condition, which is what turns the guess into a read.
## That is why the tier matters more than the capacity does.
##
## Not ported, each its own feature: seller reliability, named buyer requests,
## bulk lots, specialist category tags, the carried-value robbery risk that
## prices moving stock between districts.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

## Canon PROFITABLE_FLIP_MARGIN (game-core.js:354). Clearing 30% is the line
## between reading the board and getting lucky.
const PROFITABLE_FLIP_MARGIN := 1.3

var gs: Node
var rng: Node
var time_system: RefCounted
var attributes: RefCounted

func setup(game_state: Node, rng_manager: Node, time: RefCounted,
		attribute_system: RefCounted) -> void:
	gs = game_state
	rng = rng_manager
	time_system = time
	attributes = attribute_system

func can_handle(action: String) -> bool:
	return action in ["list_buy", "list_sell"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"list_buy":
			return _buy(str(payload.get("item_id", "")))
		"list_sell":
			return _sell(int(payload.get("index", -1)))
	return {"ok": false, "reason": "Unknown 907List action."}

## Today's board. Seeded on the day, so it is stable while the day lasts and
## different tomorrow. Items above the player's tier never appear.
func todays_listings() -> Array:
	var tier: Dictionary = gs.market_tier()
	var eligible: Array = []
	for i in gs.listing_items:
		if int(i["tier"]) <= gs.list_tier:
			eligible.append(i)
	if eligible.is_empty():
		return []
	var want: int = int(tier["listings"])
	var out: Array = []
	var seen: Array = []
	# Walk deterministically until the board is full; the offset keeps a day
	# from showing the same item twice.
	var guard: int = 0
	while out.size() < want and guard < 40:
		var pick: int = rng.seeded_int_range(gs.run_seed, "907list:%d:%d" % [gs.day, guard], 0, eligible.size() - 1)
		if not pick in seen:
			seen.append(pick)
			out.append(eligible[pick])
		guard += 1
	return out

func capacity() -> int:
	return int(gs.market_tier()["capacity"])

func buy_blocker(item_id: String) -> String:
	if gs.game_over:
		return "The run is over."
	var item: Dictionary = gs.listing_item_by_id(item_id)
	if item.is_empty():
		return "No such listing."
	if gs.list_holdings.size() >= capacity():
		return "No room. %d is all you can carry." % capacity()
	if gs.cash < int(item["buy"]):
		return "You don't have $%d." % int(item["buy"])
	return ""

func _buy(item_id: String) -> Dictionary:
	var blocked := buy_blocker(item_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var item: Dictionary = gs.listing_item_by_id(item_id)
	gs.cash -= int(item["buy"])
	gs.list_holdings.append({"item_id": item_id, "bought_day": gs.day})
	gs.log_activity("Picked up %s for $%d." % [str(item["name"]), int(item["buy"])], AMBER)
	return {"ok": true}

## What a held item will actually fetch. Seeded on the holding so the number is
## fixed from the moment it is bought — the player is discovering a value that
## already existed, not rolling for one at the till.
func realised_value(holding: Dictionary) -> int:
	var item: Dictionary = gs.listing_item_by_id(str(holding["item_id"]))
	if item.is_empty():
		return 0
	var band: Array = item["true_value"]
	var key := "907list:value:%s:%d" % [str(holding["item_id"]), int(holding["bought_day"])]
	return rng.seeded_int_range(gs.run_seed, key, int(band[0]), int(band[1]))

func sell_blocker(index: int) -> String:
	if gs.game_over:
		return "The run is over."
	if index < 0 or index >= gs.list_holdings.size():
		return "Nothing there."
	var delay: int = int(gs.market_tier()["sell_delay"])
	var held: Dictionary = gs.list_holdings[index]
	if gs.day - int(held["bought_day"]) < delay:
		return "The meet is tomorrow."
	return ""

func _sell(index: int) -> Dictionary:
	var blocked := sell_blocker(index)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var held: Dictionary = gs.list_holdings[index]
	var item: Dictionary = gs.listing_item_by_id(str(held["item_id"]))
	var got: int = realised_value(held)
	var paid: int = int(item["buy"])

	gs.cash += got
	gs.list_holdings.remove_at(index)

	# Canon counts a clean flip, not a sale — a loss does not advance the tier.
	if got > paid:
		gs.list_flips += 1
	_update_tier()

	# Canon (game-core.js:3164): a flip that clears 30% was a good READ, not a
	# lucky one, and reading value is exactly what Intelligence is for. Breaking
	# even teaches nothing, which is why the gate is a margin and not a sale.
	# `list_flips - 1` is canon's session count: how many came before this one,
	# which is what makes the first flips the valuable ones.
	if paid > 0 and float(got) > float(paid) * PROFITABLE_FLIP_MARGIN:
		attributes.train("list_flip", maxi(0, gs.list_flips - 1))

	var delta: int = got - paid
	if delta >= 0:
		gs.log_activity("Flipped %s for $%d (+$%d)." % [str(item["name"]), got, delta], GREEN)
	else:
		gs.log_activity("%s moved for $%d. Down $%d." % [str(item["name"]), got, -delta], RED)
	# A meet is a slot.
	time_system.handle("advance_time", {})
	return {"ok": true, "got": got, "delta": delta}

func _update_tier() -> void:
	var was: int = gs.list_tier
	if gs.list_flips >= gs.BROKER_FLIP_REQUIREMENT:
		gs.list_tier = 3
	elif gs.list_flips >= gs.FLIPPER_FLIP_REQUIREMENT:
		gs.list_tier = maxi(gs.list_tier, 2)
	if gs.list_tier > was:
		gs.log_activity("The board opens up. You're a %s now." % str(gs.market_tier()["name"]).capitalize(), GREEN)

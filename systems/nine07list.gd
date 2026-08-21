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
##
## ## Opportunity ownership (FS-001.2)
##
## A listing is a single opportunity, not a shelf. Canon tracks
## `nineZeroSevenList.taken` — `{day, ids}` — and filters the board pool by it,
## so the same item cannot be bought twice off one day's board no matter how
## many times the screen is reopened. Before this, the port had no such notion:
## a listing could be rebought until the money or the capacity ran out.
##
## Two details worth keeping straight:
##
##   - **The filter runs on the POOL, before generation, not on the output.**
##     That is canon (`listingSlate`), and it means buying an item does not
##     merely subtract a row — the board is regenerated from a smaller pool and
##     its remaining composition changes. Deterministic still holds in the sense
##     that matters: the same seed, day and consumption set always produce the
##     same board. It is a function of state, not invariant under consumption.
##   - **The day reset is lazy**, keyed on `list_taken.day` rather than a
##     day_crossed handler. See the field's own note in game_state.gd.
##
## Canon also excludes items currently HELD from the pool. That is deliberately
## not ported here — it is a separate behaviour from same-day consumption, it
## would change board composition for every existing save, and no acceptance
## criterion in this build asks for it. Named so the gap is legible.
##
## ## The meetup (Build 5e)
##
## A sale is a handoff in a parking lot, and canon resolves how visible it was
## on the `market_meetup` shape at a flat 0.75 — an Intelligence read of picking
## the hour and the lot.
##
## The thing to understand about this one: **the tier has no mechanical
## consequence.** Canon is explicit that the robbery roll is left alone so the
## risk number the page shows stays honest, and the money is already settled by
## the time the tier is picked. What the tier decides is the Exposure footprint
## and nothing else — a clean meetup writes no row at all, a messy one puts
## `presence / met_a_stranger` on the block, and a catastrophe would write
## `violence / robbery_victim`. That last tier is reachable here but toothless
## until the carried-value robbery lands, which is the feature that gives it
## teeth in canon.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

## Canon PROFITABLE_FLIP_MARGIN (game-core.js:354). Clearing 30% is the line
## between reading the board and getting lucky.
const PROFITABLE_FLIP_MARGIN := 1.3

## Canon's flat meetup chance. Not a balance number this build chose — it is the
## constant canon passes at the call site, frozen with the rest of the port.
const MEETUP_CHANCE := 0.75

var gs: Node
var rng: Node
var time_system: RefCounted
var attributes: RefCounted
var gm: Node

func setup(game_state: Node, rng_manager: Node, time: RefCounted,
		attribute_system: RefCounted, manager: Node) -> void:
	gs = game_state
	rng = rng_manager
	time_system = time
	attributes = attribute_system
	gm = manager

func can_handle(action: String) -> bool:
	return action in ["list_buy", "list_sell"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"list_buy":
			return _buy(str(payload.get("item_id", "")))
		"list_sell":
			return _sell(int(payload.get("index", -1)))
	return {"ok": false, "reason": "Unknown 907List action."}

## The listing ids already taken TODAY.
##
## Reads defensively rather than trusting the field: canon normalizes the same
## way (`list.taken` guarded on `Array.isArray`), and a hand-edited or malformed
## save must degrade to "nothing taken" rather than crash the board. A stale day
## reads as empty, which is the lazy reset doing its job.
func taken_today() -> Array:
	var raw: Variant = gs.list_taken
	if not (raw is Dictionary):
		return []
	var taken: Dictionary = raw
	if int(taken.get("day", -1)) != gs.day:
		return []
	var ids: Variant = taken.get("ids", [])
	if not (ids is Array):
		return []
	var out: Array = []
	for id in (ids as Array):
		# Canon drops ids no listing table knows, so a renamed item in an old
		# save cannot permanently suppress a slot on the board.
		if not gs.listing_item_by_id(str(id)).is_empty():
			out.append(str(id))
	return out

## Canon markListingTaken. Rolls the day over lazily, then records the id once.
func _mark_taken(item_id: String) -> void:
	var raw: Variant = gs.list_taken
	if not (raw is Dictionary) or int((raw as Dictionary).get("day", -1)) != gs.day:
		gs.list_taken = {"day": gs.day, "ids": []}
	var ids: Variant = gs.list_taken.get("ids", [])
	if not (ids is Array):
		gs.list_taken["ids"] = []
		ids = gs.list_taken["ids"]
	if not item_id in (ids as Array):
		(ids as Array).append(item_id)

## Today's board. Seeded on the day, so it is stable while the day lasts and
## different tomorrow. Items above the player's tier never appear, and neither
## do the ones already taken today — see the header on why that filter runs on
## the pool rather than the result.
func todays_listings() -> Array:
	var tier: Dictionary = gs.market_tier()
	var consumed: Array = taken_today()
	var eligible: Array = []
	for i in gs.listing_items:
		if int(i["tier"]) <= gs.list_tier:
			if str(i["id"]) in consumed:
				continue
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
	# Opportunity ownership. Deliberately checked LAST: the money and capacity
	# reasons are ones the player can act on, and this one they cannot, so it
	# should never mask a more useful message.
	#
	# Silent at the state layer by design — the board does not offer a consumed
	# listing, so reaching this is a stale tap or a replayed action, not a
	# choice the player made. The guard exists because "the UI does not offer
	# it" is not the same guarantee as "the system will not do it".
	if not _offered_today(item_id):
		return "That one is gone."
	return ""

## Is this listing actually on today's board? Consumption is the reason it
## usually is not, but this also rejects an id that is off-tier or simply never
## generated today — which is the real contract: a buy validates against the
## board that exists, not against the item table.
func _offered_today(item_id: String) -> bool:
	for listing in todays_listings():
		if str(listing["id"]) == item_id:
			return true
	return false

func _buy(item_id: String) -> Dictionary:
	var blocked := buy_blocker(item_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var item: Dictionary = gs.listing_item_by_id(item_id)
	gs.cash -= int(item["buy"])
	gs.list_holdings.append({"item_id": item_id, "bought_day": gs.day})
	# The opportunity is spent whether or not the flip ever pays off.
	_mark_taken(item_id)
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

	# Canon recordMarketFlip: the money itself is news, on both channels that
	# trade in it.
	#
	# `value` carries the payout because that is what Curtis's network filter
	# reads — a big 907List day is exactly how a flip is meant to reach him, and
	# a $40 space heater is exactly how it is meant not to. Without the filter
	# (ported in this build, see Exposure.clears_curtis_filter) this observation
	# would raise his awareness on every trivial flip, which is the opposite of
	# canon's design for his attention.
	#
	# Household AND network: until canon's v1.19 the only financial channel was
	# the one the player lives on, so the people who trade in money for a living
	# could never hear about the money. Tracked rather than raw, so a network
	# arrival credits awareness the one way it is supposed to.
	#
	# No Heat. A flip is legitimate commerce as far as anyone watching is
	# concerned; what it costs is visibility, not police attention.
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis != null:
		for channel in ["household", "network"]:
			curtis.broadcast_tracked({
				"type": "financial", "event": "907list_profit",
				"location": gs.current_district_id, "value": got, "channel": channel,
			})

	# How visible the handoff was. Canon keys this on the day, the slot and a
	# nonce; the held item is this build's nonce, which is unique per holding.
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	var tier: String = ""
	if resolver != null:
		var key := "meetup:%d:%d:%s" % [gs.day, gs.time_slots_today, str(held["item_id"])]
		var outcome: Dictionary = resolver.resolve_action("market_meetup", MEETUP_CHANCE,
			attributes.value("intelligence"), gs.run_seed, key)
		tier = str(outcome["tier"])
		resolver.broadcast_outcome("market_meetup", tier, gs.current_district_id, got)

	var delta: int = got - paid
	if delta >= 0:
		gs.log_activity("Flipped %s for $%d (+$%d)." % [str(item["name"]), got, delta], GREEN)
	else:
		gs.log_activity("%s moved for $%d. Down $%d." % [str(item["name"]), got, -delta], RED)
	# The only tier the player is ever told about: somebody clocked the handoff.
	# The rest of the spread is silent by design — see the header.
	if tier == "messy":
		gs.log_activity("Somebody was paying attention to that meet.", AMBER)

	# A meet is a slot.
	time_system.handle("advance_time", {})
	return {"ok": true, "got": got, "delta": delta, "tier": tier}

func _update_tier() -> void:
	var was: int = gs.list_tier
	if gs.list_flips >= gs.BROKER_FLIP_REQUIREMENT:
		gs.list_tier = 3
	elif gs.list_flips >= gs.FLIPPER_FLIP_REQUIREMENT:
		gs.list_tier = maxi(gs.list_tier, 2)
	if gs.list_tier > was:
		gs.log_activity("The board opens up. You're a %s now." % str(gs.market_tier()["name"]).capitalize(), GREEN)

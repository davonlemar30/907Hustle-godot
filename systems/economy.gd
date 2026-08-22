extends RefCounted
## Economy system — market buy / sell, and canon's market walk.
##
## The walk is the full canon model now (Phase 5 part 2): per-area markets
## (state.world.markets), the xorshift32 stream carried in GameState.rng_state,
## marketPrice's 0.34 mean-reversion with per-product volatility clamped to
## [min x 0.72, max x 1.2] (game-core.js:1331), availability restock rolls, and
## canon's cadence — markets move ONCE PER DAY, inside day-end settlement
## (evolveMarkets is called from processDayEnd, game-core.js:6654), not per
## slot. The earlier keyed +/-20% per-slot model treated the nightly cadence as
## a bug and "fixed" it; canon says nightly was the design.
##
## The walk primitives are STATIC and pure: GameState.init_markets() (canon
## initialMarket, run creation) and evolve() here (canon evolveMarkets, nightly)
## share one formula instead of drifting apart. The parity runner replays the
## recorded oracle walks through these same statics.
##
## Still simplified vs the full web trade, each its own later feature: no
## buy/sell spread or tradeProjection, no plug gating/standing, no
## weighted-average cost, no event price modifiers (no events system), and
## dealerSupplyFactor is 1 (no dealers). Buy DOES enforce and consume
## availability now, as canon's BUY branch does (game-core.js:7561-7566) —
## with a spoken rejection reason where canon rejects silently, because this
## build's action layer surfaces every refusal.

var gs: Node
var rng: Node
## Reached for the wallet. Buying and selling product both move cash.
var gm: Node

func setup(game_state: Node, rng_manager: Node, manager: Node) -> void:
	gs = game_state
	rng = rng_manager
	gm = manager

func can_handle(action: String) -> bool:
	return action == "market_buy" or action == "market_sell" or action == "market_evolve"

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"market_buy":
			return _buy(payload)
		"market_sell":
			return _sell(payload)
		"market_evolve":
			evolve()
			return {"ok": true}
	return {"ok": false, "reason": "Unknown economy action."}

# --- canon walk primitives (static, pure) ----------------------------------

## Port of marketPrice (game-core.js:1331). One stream draw. `previous` is null
## on the initial walk; after that it is the price the walk last produced.
static func price_step(prod: Dictionary, bias: Dictionary, stream, previous) -> int:
	var anchor: float = float(prod["base"]) * float(bias.get(prod["id"], 1.0))
	var prior: float = float(previous) if previous != null else anchor
	var reversion: float = prior + (anchor - prior) * 0.34
	var movement: float = 1.0 + (stream.next() * 2.0 - 1.0) * float(prod.get("volatility", 0.0))
	return int(round(clampf(reversion * movement, float(prod["min"]) * 0.72, float(prod["max"]) * 1.2)))

## Canon's availability roll: a gate draw against the area's restock chance,
## then a quantity draw only when it passes. The bounds differ between run
## creation (4..12 Outer / 4..9 else, game-core.js:1326) and the nightly evolve
## (3..13 Outer / 3..9 else, game-core.js:4493) — that asymmetry is canon.
static func availability_roll(chance: float, market_role: String, stream, initial: bool) -> int:
	var gate: float = stream.next()
	if gate > chance:
		return 0
	var low: int = 4 if initial else 3
	var high: int
	if market_role == "Outer":
		high = 12 if initial else 13
	else:
		high = 9
	return stream.next_int(low, high)

## Canon initialMarket for one area: per product in products order — price
## (previous=null), then the availability roll. History starts as [price].
static func walk_initial_area(district: Dictionary, products: Array, stream) -> Dictionary:
	var prices: Dictionary = {}
	var availability: Dictionary = {}
	var history: Dictionary = {}
	for prod in products:
		var pid: String = str(prod["id"])
		prices[pid] = price_step(prod, district["bias"], stream, null)
		availability[pid] = availability_roll(
			float(district["availability"].get(pid, 0.0)), str(district["market_role"]), stream, true)
		history[pid] = [prices[pid]]
	return {"prices": prices, "availability": availability, "history": history, "updated_at": 0}

## Canon evolveMarkets for one area: per product — price walked from the
## previous price, then the availability roll (evolve bounds). History keeps
## the last 8, canon's slice(-8).
static func walk_evolve_area(district: Dictionary, products: Array, market: Dictionary, stream) -> void:
	for prod in products:
		var pid: String = str(prod["id"])
		var price: int = price_step(prod, district["bias"], stream, market["prices"].get(pid))
		market["prices"][pid] = price
		var hist: Array = market["history"].get(pid, [])
		hist.append(price)
		if hist.size() > 8:
			hist = hist.slice(hist.size() - 8)
		market["history"][pid] = hist
		market["availability"][pid] = availability_roll(
			float(district["availability"].get(pid, 0.0)), str(district["market_role"]), stream, false)

## Screens bind products[].price; keep it mirroring the CURRENT district's
## market so every existing consumer (Market rows, Home snapshot) stays correct
## without knowing markets exist. Call after any walk and after travel.
static func sync_display_prices(game_state: Node) -> void:
	var market: Dictionary = game_state.markets.get(game_state.current_district_id, {})
	if market.is_empty():
		return
	for prod in game_state.products:
		var pid: String = str(prod["id"])
		if market["prices"].has(pid):
			prod["price"] = int(market["prices"][pid])

# --- actions ----------------------------------------------------------------

func _buy(p: Dictionary) -> Dictionary:
	var id: String = p.get("product_id", "")
	var qty: int = int(p.get("quantity", 1))
	var prod: Dictionary = gs.product_by_id(id)
	if prod.is_empty():
		return {"ok": false, "reason": "Unknown product."}
	if prod.get("locked", false):
		return {"ok": false, "reason": "%s is locked." % prod.name}
	if qty <= 0:
		return {"ok": false, "reason": "Nothing to buy."}
	# Canon BUY: `qty > available` rejects, and a purchase consumes supply
	# (game-core.js:7561-7566). Canon rejects without a message; the reason
	# string is this build's action layer speaking, a named divergence.
	var market: Dictionary = gs.markets.get(gs.current_district_id, {})
	var available: int = int(market.get("availability", {}).get(id, 0)) if not market.is_empty() else 0
	if qty > available:
		return {"ok": false, "reason": "Not enough supply."}
	var cost: int = int(prod.price) * qty
	if gs.cash < cost:
		return {"ok": false, "reason": "Not enough cash."}
	if gs.cargo_used() + qty > gs.cargo_max:
		return {"ok": false, "reason": "Cargo full."}
	var wallet: Object = gm.system("wallet")
	wallet.spend(cost, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "market_buy_%s" % id})
	gs.inventory[id] = int(gs.inventory.get(id, 0)) + qty
	market["availability"][id] = available - qty
	return {"ok": true}

func _sell(p: Dictionary) -> Dictionary:
	var id: String = p.get("product_id", "")
	var qty: int = int(p.get("quantity", 1))
	var prod: Dictionary = gs.product_by_id(id)
	if prod.is_empty():
		return {"ok": false, "reason": "Unknown product."}
	if qty <= 0:
		return {"ok": false, "reason": "Nothing to sell."}
	var have: int = int(gs.inventory.get(id, 0))
	if have < qty:
		return {"ok": false, "reason": "Not enough to sell."}
	# TI-003 §6 Dirty: "Market criminal sales".
	var wallet: Object = gm.system("wallet")
	wallet.credit(int(prod.price) * qty, wallet.DIRTY,
		{"source_id": "market_sell_%s" % id})
	var left: int = have - qty
	if left <= 0:
		gs.inventory.erase(id)
	else:
		gs.inventory[id] = left
	# FS-003 §6: "A completed criminal market sale adds +0.25 Market pressure,
	# capped at +1 Market pressure per district per day from ordinary sales."
	#
	# The cap is the point of the rule rather than an afterthought: it lets
	# dealing VOLUME become locally recognisable without turning each individual
	# sale into a crisis. Four sales in a district make it known; the fifth is
	# free, and tomorrow starts over.
	#
	# Sales only. Buying product is not what makes a corner recognisable — the
	# repeated handoff is. And it is one gain per TRANSACTION, not per unit: a
	# ten-unit sale is one handoff.
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine != null:
		engine.add_market_pressure(gs.current_district_id)
	return {"ok": true}

## Canon evolveMarkets (game-core.js:4483): one stream batch off rng_state,
## every area in districts (canon NEIGHBORHOODS) order, cursor written back
## after — `state.run.rngState = random.state`. Runs nightly on day-cross.
func evolve() -> void:
	if gs.markets.is_empty():
		return
	var stream = rng.make_stream(gs.rng_state)
	var absolute: int = (gs.day - 1) * 4 + gs.time_slots_today
	for d in gs.districts:
		var market: Dictionary = gs.markets.get(d["id"], {})
		if market.is_empty():
			continue
		walk_evolve_area(d, gs.products, market, stream)
		market["updated_at"] = absolute
	gs.rng_state = stream.state
	sync_display_prices(gs)

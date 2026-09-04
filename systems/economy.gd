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

# --- what a sale actually pays (v0.2.0) -------------------------------------

const RULES := preload("res://data/consequence_rules.gd")

## The per-unit price a sale in `district_id` actually pays right now.
##
## THE ONE function. `_sell` credits from it and the Market screen displays from
## it, because a preview that re-derives the answer separately is a second
## implementation, and the day it drifts is the day the player is shown a number
## the game does not honour.
##
## The board price is what the district is worth. What it pays YOU is that,
## less what the corner has learned about you: Market Pressure's authored band
## penalty, scaled by `MARKET_PRESSURE_PRICE_SCALE`. A QUIET district pays the
## board price exactly, so nothing changes for a player who has not worked a
## corner hard enough to be recognised there.
##
## Floors at $1. A corner that pays nothing is a corner nobody would stand on,
## and a zero would make the sell button a button that takes your product.
## BR-D4: what a unit costs to BUY here, right now. The board price less the
## supply cut the run's Ship Creek lots earn it. THE ONE function for the
## buy side, as `sell_unit_price` is for the sell side.
func buy_unit_price(district_id: String, product_id: String) -> int:
	var market: Dictionary = gs.markets.get(district_id, {})
	var board: int = int((market.get("prices", {}) as Dictionary).get(product_id, 0)) \
		if not market.is_empty() else int(gs.product_by_id(product_id).get("price", 0))
	var territory: Object = gm.system("territory") if gm != null else null
	var discount: float = float(territory.supply_discount()) if territory != null else 0.0
	return maxi(1, int(round(float(board) * (1.0 - discount))))

func sell_unit_price(district_id: String, product_id: String) -> int:
	var market: Dictionary = gs.markets.get(district_id, {})
	var board: int = int((market.get("prices", {}) as Dictionary).get(product_id, 0)) \
		if not market.is_empty() else 0
	if board <= 0:
		# No walked market for this district yet — fall back to the display
		# mirror, which is what every other read of an unwalked board does.
		board = int(gs.product_by_id(product_id).get("price", 0))
	if board <= 0:
		return 0
	var penalty: float = market_price_penalty(district_id)
	if penalty <= 0.0:
		return board
	return maxi(1, int(round(float(board) * (1.0 - penalty))))

## The fraction the corner holds back, 0.0 when it has nothing on you.
func market_price_penalty(district_id: String) -> float:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return 0.0
	var rules: RefCounted = RULES.new()
	var score: float = float(engine.pressure_score(district_id, rules.FAMILY_MARKET))
	return clampf(rules.pressure_penalty(score) * rules.MARKET_PRESSURE_PRICE_SCALE,
		0.0, 0.9)

# --- where the route is (v0.2.0) --------------------------------------------

## The best place to take `product_id` from where the player is standing, or an
## empty Dictionary when nowhere pays better.
##
## This is the one profitable strategy in the game and until now there was NO
## SURFACE ANYWHERE that could see it. `sell_unit_price` could always price a
## remote district; nothing ever asked it to. The economy instrument had to read
## `gs.markets` directly to play the route, which is the tell — a strategy only
## a test can find is not a strategy the player has.
##
## `known_only` is what makes this honest rather than omniscient. Word reaches
## you about places you know about, and `districts_unlocked` is that list.
##
## Reports what a sale THERE would actually pay, not the board price, so the
## Market Pressure penalty on a corner you have burned is visible from here
## instead of being a surprise on arrival.
func best_route(product_id: String, known_only: bool = true) -> Dictionary:
	var here: String = str(gs.current_district_id)
	var here_market: Dictionary = gs.markets.get(here, {})
	if here_market.is_empty():
		return {}
	var cost: int = int((here_market.get("prices", {}) as Dictionary).get(product_id, 0))
	if cost <= 0:
		return {}
	# A route you cannot stock is not a route. `best_route` reported the
	# spread without ever checking this corner had any to sell you, so a
	# sold-out product still advertised somewhere to take it.
	if int((here_market.get("availability", {}) as Dictionary).get(product_id, 0)) <= 0:
		return {}
	var best: Dictionary = {}
	var best_edge: int = 0
	for district in gs.districts:
		var row: Dictionary = district
		var there: String = str(row["id"])
		if there == here:
			continue
		if known_only and not there in gs.districts_unlocked:
			continue
		if (gs.markets.get(there, {}) as Dictionary).is_empty():
			continue
		var pays: int = sell_unit_price(there, product_id)
		var edge: int = pays - cost
		# The trip has to clear its own bus fare before it is a trip. A
		# one-dollar spread is arithmetic, not a route, and reporting it as
		# one is the same class of claim as the authored hint this replaced.
		if edge <= int(gs.TravelFare):
			continue
		if edge > best_edge:
			best_edge = edge
			best = {"district_id": there, "name": str(row["name"]), "pays": pays,
				"cost": cost, "edge": edge, "trend": price_trend(there, product_id)}
	return best

## "up", "down" or "flat", from the district's own price history.
##
## `walk_evolve_area` keeps canon's last eight prices per product and nothing has
## ever read them. Two are enough to say which way a corner is moving, which is
## the difference between a number and a reason to hurry.
func price_trend(district_id: String, product_id: String) -> String:
	var history: Variant = (gs.markets.get(district_id, {}) as Dictionary).get("history", {})
	if not (history is Dictionary):
		return "flat"
	var series: Variant = (history as Dictionary).get(product_id)
	if not (series is Array) or (series as Array).size() < 2:
		return "flat"
	var rows: Array = series
	var last: int = int(rows[rows.size() - 1])
	var previous: int = int(rows[rows.size() - 2])
	if last > previous:
		return "up"
	if last < previous:
		return "down"
	return "flat"

## Every route worth taking right now, best edge first. What the Phone reports.
func known_routes() -> Array:
	var out: Array = []
	for product in gs.products:
		var product_id := str((product as Dictionary)["id"])
		if bool((product as Dictionary).get("locked", false)):
			continue
		var route: Dictionary = best_route(product_id)
		if route.is_empty():
			continue
		route["product_id"] = product_id
		route["product_name"] = str((product as Dictionary)["name"])
		out.append(route)
	out.sort_custom(func(a, b): return int(a["edge"]) > int(b["edge"]))
	return out

# --- the carry (v0.2.0, Leg 4) ----------------------------------------------

## A trip taken holding, resolved.
##
## Called by `TravelSystem` once the move has been paid for and the slot spent —
## travel owns WHEN, this owns WHAT, because inventory is written here and
## nowhere else. Returns a report the caller can log and a screen can read; an
## empty Dictionary means the trip was quiet.
##
## `origin_district_id` is where the trip STARTED. That is the corner whose
## Market Pressure raises the odds: the road out of a block you have been
## working is where somebody is looking for you, and keying it on the
## destination would let a courier launder a hot corner by leaving it.
func resolve_carry(origin_district_id: String) -> Dictionary:
	var units: int = gs.cargo_used()
	if units <= 0 or gs.game_over:
		return {}
	var rules: RefCounted = RULES.new()
	var engine: Object = gm.system("consequence") if gm != null else null
	var steps: int = 0
	if engine != null:
		steps = int(rules.pressure_steps(
			engine.pressure_score(origin_district_id, rules.FAMILY_MARKET)))
	var chance: float = rules.carry_stop_chance(units, _carried_value(),
		float(gs.heat), steps)
	# Eli, if his day was spent on it (batch 6b). He knows which exits nobody
	# watches, and the relief is the fraction of the chance that buys off.
	# Asked of the adapter rather than of the roster: having him on the crew is
	# not the same as having spent his day on this.
	var runner: Object = gm.system("runner_adapter") if gm != null else null
	var relief: float = float(runner.carry_relief()) if runner != null else 0.0
	if relief > 0.0:
		chance *= (1.0 - relief)
	# One keyed roll per trip. Leading with the varying components, per the
	# v0.1.0 seeded-key audit: day and slot move every trip, the district does
	# not.
	# Count the trip on his assignment before the roll, so a quiet day still
	# reports as a day he walked rather than as a day nothing happened.
	_credit_runner_trip(false)
	var key := "%d:%d:carry:%s" % [gs.day, gs.time_slots_today, origin_district_id]
	if rng.seeded_random(gs.run_seed, key) >= chance:
		return {}

	# Stopped. HOW it goes is the resolver's, not a second dice table of ours —
	# the `escape` shape is already authored and Intelligence already reads it.
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	var attributes: Object = gm.system("attributes") if gm != null else null
	var tier: String = "failure"
	if resolver != null and attributes != null:
		tier = str((resolver.resolve_action(rules.CARRY_RESOLVER_ACTION,
			rules.CARRY_ESCAPE_CHANCE, int(attributes.effective("intelligence")),
			gs.run_seed, key + ":stop") as Dictionary)["tier"])

	var seized: Dictionary = _seize_fraction(rules.carry_seize_fraction(tier))
	var heat_raw: float = rules.carry_stop_heat(tier)
	if heat_raw > 0.0:
		var heat: Object = gm.system("heat") if gm != null else null
		if heat != null:
			heat.apply_gain(heat_raw, heat.FAMILY_MARKET, origin_district_id,
				{"source_id": "carry_stop"})
	var report: Dictionary = {
		"stopped": true, "tier": tier, "units_before": units,
		"units_seized": int(seized["units"]), "value_seized": int(seized["value"]),
		"chance": chance,
	}
	gs.log_activity(_carry_line(report), RED if int(seized["units"]) > 0 else AMBER)
	return report

## Tally a carried trip against Eli's assignment, if he is out on it.
##
## Written on the ASSIGNMENT record rather than on GameState: it is a fact about
## his day, it round-trips with `crew_assignments` and needs no new save field,
## and it is gone when the day is.
func _credit_runner_trip(was_stopped: bool) -> void:
	var ops: Object = gm.system("crew_operations") if gm != null else null
	if ops == null:
		return
	var assignment: Dictionary = ops.assignment_for("eli")
	if assignment.is_empty() or str(assignment.get("operation_id", "")) != "run_the_bag":
		return
	if was_stopped:
		assignment["stops_absorbed"] = int(assignment.get("stops_absorbed", 0)) + 1
	else:
		assignment["trips_covered"] = int(assignment.get("trips_covered", 0)) + 1

## What the bag is worth, priced where it is standing.
func _carried_value() -> int:
	var prices: Dictionary = (gs.markets.get(str(gs.current_district_id), {}) as Dictionary).get("prices", {})
	var total: int = 0
	for product_id in gs.inventory.keys():
		total += int(prices.get(str(product_id), 0)) * int(gs.inventory[product_id])
	return total

## Take `fraction` of what is being carried, cheapest-first so a partial loss is
## a bad day rather than a run-ender. Returns what went.
##
## Rounds UP on a partial: a stop that finds a bag and takes nothing out of it
## is not a stop, and `int(0.34 * 1)` is zero for every single-unit load.
func _seize_fraction(fraction: float) -> Dictionary:
	if fraction <= 0.0:
		return {"units": 0, "value": 0}
	var prices: Dictionary = (gs.markets.get(str(gs.current_district_id), {}) as Dictionary).get("prices", {})
	var ordered: Array = []
	for product_id in gs.inventory.keys():
		ordered.append({"id": str(product_id),
			"price": int(prices.get(str(product_id), 0))})
	ordered.sort_custom(func(a, b): return int(a["price"]) < int(b["price"]))
	var target: int = int(ceil(float(gs.cargo_used()) * clampf(fraction, 0.0, 1.0)))
	var taken_units: int = 0
	var taken_value: int = 0
	for entry in ordered:
		if taken_units >= target:
			break
		var product_id := str(entry["id"])
		var held: int = int(gs.inventory.get(product_id, 0))
		var take: int = mini(held, target - taken_units)
		if take <= 0:
			continue
		taken_units += take
		taken_value += take * int(entry["price"])
		if held - take <= 0:
			gs.inventory.erase(product_id)
		else:
			gs.inventory[product_id] = held - take
	return {"units": taken_units, "value": taken_value}

const CARRY_LINES := {
	"clean": "Transit officer works the car and steps off two stops later. Nothing said.",
	"messy": "They go through the bag on the platform and keep what is on top.",
	"failure": "The bag does not come back. Neither does the afternoon.",
	"catastrophic": "Everything on you, gone, and somebody wrote your name down.",
}

func _carry_line(report: Dictionary) -> String:
	return str(CARRY_LINES.get(str(report["tier"]), CARRY_LINES["failure"]))

const AMBER := Color(0.882, 0.651, 0.227)
const RED := Color(0.827, 0.161, 0.125)
const GREEN := Color(0.451, 0.722, 0.404)

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
	# BR-D4: the one buy price. Board price less what held Ship Creek lots
	# cut off it; the Market screen previews from the same function.
	var cost: int = buy_unit_price(gs.current_district_id, id) * qty
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
	# What the corner actually pays, after what it has learned about you.
	var unit: int = sell_unit_price(gs.current_district_id, id)
	var revenue: int = unit * qty
	# TI-003 §6 Dirty: "Market criminal sales".
	var wallet: Object = gm.system("wallet")
	wallet.credit(revenue, wallet.DIRTY, {"source_id": "market_sell_%s" % id})
	gs.record_earning("market", revenue)
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
	# SQ-D10: the corner's own trigger, asked BEFORE the pressure gain below.
	# `corner_stiff`'s once-per-district-per-day bound is DERIVED from
	# `add_market_pressure`'s own day-stamped counter (see
	# `systems/corner.gd::first_sale_today`), and after that call the answer is
	# always "something sold today" -- so the order of these two lines is
	# load-bearing and not incidental.
	var corner: Object = gm.system("corner") if gm != null else null
	var corner_opened: bool = corner != null \
		and bool(corner.try_open_stiff(str(gs.current_district_id), id, revenue))

	var engine: Object = gm.system("consequence") if gm != null else null
	if engine != null:
		engine.add_market_pressure(gs.current_district_id)

	# v0.2.0, Leg 1 of the trading path's risk term: the handoff is the visible
	# act, and it is the one leg that had no cost of any kind. Scaled by the
	# VALUE moved rather than by units or by `product.heat` — see the rules
	# file for why — and routed through the one Heat owner, so Deshawn damps it
	# and the district multiplier that has been dormant since FS-003.9 finally
	# has something to scale.
	var rules: RefCounted = RULES.new()
	var heat: Object = gm.system("heat") if gm != null else null
	if heat != null and revenue > 0:
		var raw: float = minf(float(revenue) * rules.MARKET_SELL_HEAT_PER_DOLLAR,
			rules.MARKET_SELL_HEAT_CAP)
		heat.apply_gain(raw, heat.FAMILY_MARKET, gs.current_district_id,
			{"source_id": "market_sell"})

	# v0.2.0, Leg 3: the handoff takes a slot. Routed through the time system
	# by hand rather than dispatched, the same way Boost, Stickup, Jobs and the
	# 907List all spend their slot — a nested dispatch would fire a second
	# notify_changed inside this one's stack and break the one-refresh contract.
	# The slot is still spent when the corner opens: the handoff happened and
	# the hour went with it. What the chain decides is whether the last of the
	# money stays, which is a different question from whether the sale did.
	if rules.MARKET_SELL_COSTS_SLOT:
		var time_system: Object = gm.system("time") if gm != null else null
		if time_system != null:
			time_system.handle("advance_time", {})
	return {"ok": true, "unit_price": unit, "revenue": revenue,
		"corner": corner_opened}

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
	explain_moves()

const CAUSES := preload("res://data/market_causes.gd")
var _last_cause_day: int = -1

## WS-D5 (0.8.0): when the board under the player's feet moves hard, the
## feed says why. Flavor over a roll the walk already made -- it never
## moves a price. The biggest mover in the current district, one line a
## day, only past `MOVE_THRESHOLD`. Seeded on the day and the product, so
## a run replays its own rumors.
func explain_moves() -> void:
	if _last_cause_day == int(gs.day):
		return
	var market: Dictionary = gs.markets.get(gs.current_district_id, {})
	if market.is_empty():
		return
	var history: Dictionary = market.get("history", {})
	var best_id := ""
	var best_move := 0.0
	var best_direction := "flat"
	for prod in gs.products:
		var pid := str(prod["id"])
		if bool(prod.get("locked", false)):
			continue
		var series: Variant = history.get(pid)
		if not (series is Array) or (series as Array).size() < 2:
			continue
		var rows: Array = series
		var previous: float = float(rows[rows.size() - 2])
		var last: float = float(rows[rows.size() - 1])
		if previous <= 0.0:
			continue
		var move: float = (last - previous) / previous
		if absf(move) > absf(best_move):
			best_move = move
			best_id = pid
			best_direction = "up" if move > 0.0 else "down"
	if best_id.is_empty() or absf(best_move) < CAUSES.MOVE_THRESHOLD:
		return
	_last_cause_day = int(gs.day)
	var line := CAUSES.line_for(best_id, best_direction, int(gs.day) * 31 + best_id.hash())
	if not line.is_empty():
		gs.log_activity(line, AMBER if best_direction == "down" else GREEN)

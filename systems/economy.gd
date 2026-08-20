extends RefCounted
## Economy system — market buy / sell / evolve.
##
## Simplified vs the full web trade model (no buy/sell spread, plug modifiers, or
## weighted-average cost yet — those arrive with later 3b work). Buy/sell are
## price × quantity against cash + inventory, capped by cargo. Prices evolve with
## a seeded ±20% walk clamped to each product's min/max, so results are
## deterministic and replay-stable via RngManager.

const VARIANCE := 0.20

var gs: Node
var rng: Node

func setup(game_state: Node, rng_manager: Node) -> void:
	gs = game_state
	rng = rng_manager

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
	var cost: int = int(prod.price) * qty
	if gs.cash < cost:
		return {"ok": false, "reason": "Not enough cash."}
	if gs.cargo_used() + qty > gs.cargo_max:
		return {"ok": false, "reason": "Cargo full."}
	gs.cash -= cost
	gs.inventory[id] = int(gs.inventory.get(id, 0)) + qty
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
	gs.cash += int(prod.price) * qty
	var left: int = have - qty
	if left <= 0:
		gs.inventory.erase(id)
	else:
		gs.inventory[id] = left
	return {"ok": true}

## Seeded price walk — each product ±VARIANCE around its base, clamped to min/max.
## Keyed by day + product id so a replay of the same day produces the same prices.
func evolve() -> void:
	for prod in gs.products:
		var key: String = "market_evolve_day%d_%s" % [gs.day, prod.id]
		var swing: float = (float(rng.seeded_random(gs.run_seed, key)) * 2.0 - 1.0) * VARIANCE
		var np: int = int(round(float(prod.base) * (1.0 + swing)))
		prod.price = clampi(np, int(prod.min), int(prod.max))

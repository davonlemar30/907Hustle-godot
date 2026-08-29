extends RefCounted
## ConfrontationLoop — the chassis half of the resolution loop.
##
## The loop is not a system of its own and deliberately never becomes one: a
## confrontation is a CHAIN, opened and resolved by the source system that owns
## its stakes (stickup this slice; the Lift's caught chain next), through the
## same `ConsequenceEngine` seams every other chain uses. What is genuinely
## shared between those adapters — round bookkeeping, verb burning, the round
## log, tip-payload reads, and the reshaping of a chain's decision block into
## the next round — lives here as static helpers, so two adapters cannot drift
## on the rules that make the loop one machine.
##
## ## Where the round state lives, and the divergence that decides it
##
## The build brief says round state is transient and a reload replays from
## round one. This port does the opposite ON PURPOSE, and the divergence is
## named here rather than smuggled: the engine's whole architecture (TI-003)
## persists the active chain with snapshotted odds precisely so a reload shows
## the decision the player was actually looking at — and a loop that banked
## $430 two rounds ago cannot replay honestly without persisting the bank
## anyway. So the loop state rides `decision.loop` inside the persisted chain,
## the save validator's coercion leaves unlisted keys alone, and a reload
## resumes mid-round with the same odds, the same bank, and the same burned
## verbs. Determinism is still absolute: every roll is keyed on the chain's
## own source key plus stage and choice, so nothing re-rolls either way.
##
## ## Rounds and the commit receipt
##
## Every committed choice claims the engine's `committed_choice` receipt. A
## multi-round chain commits more than once, so the engine keys that receipt
## with `decision.round` from round one onward (round zero keeps the original
## key so every existing single-decision chain and mid-chain save is
## untouched). `present_round` below is the ONE place the round number moves,
## which is what keeps the receipt keys and the rendered round honest with
## each other.

const SCRIPTS := preload("res://data/confrontation_scripts.gd")

## How many round-log lines the chain carries. The sheet renders the tail; the
## activity feed already tells the run's larger story.
const LOG_LIMIT := 6

# --- loop state access -------------------------------------------------------

static func loop_of(chain: Dictionary) -> Dictionary:
	var decision: Dictionary = chain.get("decision", {})
	var loop: Variant = decision.get("loop", {})
	return loop if loop is Dictionary else {}

static func has_loop(chain: Dictionary) -> bool:
	return not loop_of(chain).is_empty()

## Append one line to the round log, oldest dropped past the limit.
static func append_log(loop: Dictionary, line: String) -> void:
	if line.is_empty():
		return
	var log: Array = loop.get("log", [])
	log.append(line)
	if log.size() > LOG_LIMIT:
		log = log.slice(log.size() - LOG_LIMIT)
	loop["log"] = log

# --- verb burning (Q6's rules, enforced in one place) ------------------------

static func burn(loop: Dictionary, choice_id: String) -> void:
	var burned: Array = loop.get("burned", [])
	if not choice_id in burned:
		burned.append(choice_id)
	loop["burned"] = burned

static func is_burned(loop: Dictionary, choice_id: String) -> bool:
	return choice_id in (loop.get("burned", []) as Array)

## Strip burned verbs from an action list. Deterministic outs are never burned
## (nothing ever calls `burn` with one), so the guaranteed out survives this
## filter by construction rather than by exemption.
static func without_burned(loop: Dictionary, choices: Array) -> Array:
	var out: Array = []
	for choice in choices:
		if not is_burned(loop, str(choice)):
			out.append(choice)
	return out

# --- presenting the next round -----------------------------------------------

## Reshape the active chain's decision block into a new round: new action set,
## new snapshotted odds, commit cleared, round bumped. The engine's commit
## receipt reads `decision.round`, so bumping it here is what arms the next
## commit — this is the only writer of that field after `open_chain`.
static func present_round(chain: Dictionary, loop: Dictionary, allowed: Array,
		deterministic: Array, shown: Dictionary) -> void:
	var decision: Dictionary = chain.get("decision", {})
	decision["allowed_choices"] = allowed
	decision["deterministic_choices"] = deterministic
	decision["shown_probabilities"] = shown
	decision["committed_choice"] = ""
	decision["round"] = int(decision.get("round", 0)) + 1
	decision["loop"] = loop
	chain["decision"] = decision

# --- fractions ---------------------------------------------------------------

static func banked_fraction(loop: Dictionary) -> float:
	var take: int = int(loop.get("take_total", 0))
	if take <= 0:
		return 0.0
	return clampf(float(int(loop.get("banked", 0))) / float(take), 0.0, 1.0)

# --- tip payloads (Q7's seam) ------------------------------------------------

## Entry-time modifiers from phone tips, degraded to no-ops until the tip
## system lands. Reads `gs.tip_effects` only if the property exists, so this
## build carries the seam without carrying the schema — the crew `proofs`
## pattern applied one field earlier.
##
## A row is live when it names this target, is stamped for today, and either
## carries no slot window or contains the current slot. Shapes it understands
## are the `TIP_MODIFIERS` table's; anything else is ignored rather than
## guessed at.
static func tip_modifiers_for(gs: Node, target_id: String, tier: int) -> Dictionary:
	var mods: Dictionary = {
		"take_multiplier": 1.0,
		"remove_final_decay": false,
		"extra_left": 0,
		"no_free_out_round_one": false,
	}
	if not ("tip_effects" in gs):
		return mods
	var rows: Variant = gs.get("tip_effects")
	if not (rows is Array):
		return mods
	for entry in (rows as Array):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		if str(row.get("target_id", "")) != target_id:
			continue
		if int(row.get("day", -1)) != int(gs.day):
			continue
		var slots: Variant = row.get("slots", [])
		if slots is Array and not (slots as Array).is_empty() \
				and not int(gs.time_slots_today) in (slots as Array):
			continue
		match str(row.get("type", "")):
			"fat_night":
				var by_tier: Dictionary = SCRIPTS.TIP_MODIFIERS["fat_night"]["take_multiplier"]
				mods["take_multiplier"] = float(row.get("multiplier",
					by_tier.get(tier, 1.0)))
				mods["remove_final_decay"] = true
			"trap":
				mods["extra_left"] = int(SCRIPTS.TIP_MODIFIERS["trap"]["extra_left"])
				mods["no_free_out_round_one"] = true
	return mods

# --- the luggage rule (STR-D3) ------------------------------------------------
#
# What an authored `effects` table (`cash_fraction`/`cash_flat`,
# `goods_fraction`, `health`, `heat`) actually costs the player, moved here
# once Travel's own checkpoint (0.5.0 PR C) became this shape's second
# author, not just its second reader -- exactly the drift two adapters
# sharing one rule are supposed to be protected from. Distinct from
# `economy.gd`'s own `_seize_fraction` (the older, silent carry-stop tax,
# price-ordered and unauthored): that mechanic predates this one and is
# untouched here, on purpose -- unifying the two would be a bigger, unrelated
# refactor this build never asked for.

## Take a fraction of held product, floored at 1 unit for any authored
## fraction above zero. The floor is correct for an authored fraction; it is
## wrong for an authored zero, which is why every caller here skips the call
## entirely rather than letting "no loss" round up to "lose one anyway".
static func lose_cargo(gs: Node, fraction: float) -> int:
	var taken: int = 0
	for product_id in gs.inventory.keys():
		var held: int = int(gs.inventory[product_id])
		if held <= 0:
			continue
		var lose: int = held if fraction >= 1.0 else maxi(1, int(ceil(float(held) * fraction)))
		lose = mini(lose, held)
		gs.inventory[product_id] = held - lose
		taken += lose
	for product_id in gs.inventory.keys():
		if int(gs.inventory[product_id]) <= 0:
			gs.inventory.erase(product_id)
	return taken

## Heat through the one owner, same as every other criminal-adjacent gain.
## `source_tag` names the caller for the ledger entry (`"wander_encounter"`,
## `"travel_stop"`) -- the family stays `FAMILY_NONE` for both: neither a
## wander encounter nor a checkpoint stop is a Boost/Stick/Market action.
static func apply_heat(gs: Node, gm: Node, amount: float, source_tag: String) -> float:
	var heat: Object = gm.system("heat") if gm != null else null
	if heat == null:
		return 0.0
	return heat.apply_gain(amount, heat.FAMILY_NONE, gs.current_district_id,
		{"source_id": source_tag})

## Apply one resolved choice's authored effects table. `source_tag` prefixes
## the wallet/heat ledger entries (`"<source_tag>:<choice_id>"` for cash,
## `source_tag` alone for heat) so two different encounter families never
## share one receipt line.
static func apply_effects(gs: Node, gm: Node, effects: Dictionary, choice_id: String,
		source_tag: String) -> Dictionary:
	var goods_fraction: float = float(effects.get("goods_fraction", 0.0))
	var lost_goods: int = lose_cargo(gs, goods_fraction) if goods_fraction > 0.0 else 0
	var lost_cash: int = 0
	var wallet: Object = gm.system("wallet") if gm != null else null
	if wallet != null:
		var fraction: float = float(effects.get("cash_fraction", 0.0))
		var flat: int = int(effects.get("cash_flat", 0))
		# DIRTY in-hand cash only (STR-D3, the street-stop precedent: clean,
		# documented money is not street-visible) -- capped at the dirty
		# balance before spending, the same discipline `retaliation.gd`'s own
		# cash loss already applies, so `ROUTINE_DIRTY_FIRST` can never
		# actually reach clean underneath it.
		var owed: int = flat if flat > 0 \
			else int(round(float(wallet.dirty_balance()) * fraction))
		lost_cash = mini(owed, int(wallet.dirty_balance()))
		if lost_cash > 0:
			wallet.spend(lost_cash, wallet.ROUTINE_DIRTY_FIRST,
				{"source_id": "%s:%s" % [source_tag, choice_id]})
	var hurt: int = int(effects.get("health", 0))
	if hurt > 0:
		var crew: Object = gm.system("crew") if gm != null else null
		if crew != null:
			hurt = int(crew.absorbed_damage(hurt))
		gs.health = clampi(gs.health - hurt, 0, gs.health_max)
	var heat_gain: float = float(effects.get("heat", 0.0))
	if heat_gain > 0.0:
		heat_gain = apply_heat(gs, gm, heat_gain, source_tag)
	return {"goods": lost_goods, "cash": lost_cash, "health": hurt, "heat": heat_gain}

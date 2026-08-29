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

const AMBER := Color(0.882, 0.651, 0.227)

const LOOP := preload("res://systems/confrontation_loop.gd")
## Read for `gate_chance()` only — the interruption-severity formula STR-D4
## reuses rather than re-deriving. See `data/travel_events.gd`'s own header.
const EVENTS := preload("res://data/wander_events.gd")
const TRAVEL_EVENTS := preload("res://data/travel_events.gd")

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
	# The same gate the Street card wears, enforced on the ACTION rather than
	# only on the button (v0.1.0). A locked card cannot be tapped, but a travel
	# dispatch can arrive from anywhere, and "may the player go here" must have
	# one answer regardless of who asked.
	if not target in gs.districts_unlocked:
		return {"ok": false, "reason": "You don't know your way around there yet."}
	if gs.cash < FARE:
		return {"ok": false, "reason": "Need $%d fare." % FARE}

	var wallet: Object = gm.system("wallet")
	wallet.spend(FARE, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "travel_fare"})
	var previous_district: String = str(gs.current_district_id)
	gs.current_district_id = target
	# One slot, the same as any other district action. Routed through the time
	# system rather than reimplemented so the day-cross and the market evolve
	# stay in one place.
	time_system.handle("advance_time", {})
	# The district changed, so the price mirror the screens bind must now show
	# THIS district's market. (The advance only re-walks prices on a day-cross.)
	preload("res://systems/economy.gd").sync_display_prices(gs)

	# STR-D4: the checkpoint. Same interruption gate Wander rolls on a walk,
	# invoked here instead: crossing districts while hot or holding product
	# can put a patrol stop in the road. Rolled before the carry check below
	# so the two can never both land on one trip -- a checkpoint IS the
	# street noticing you in transit, and charging the older, silent
	# carry-stop tax on top of an interactive stop the player just answered
	# would be the same event taxed twice. A quiet roll changes nothing;
	# carry proceeds exactly as it always has.
	var checkpointed: bool = _roll_checkpoint(target)

	# v0.2.0: the carry. A trip taken holding is the trading path's one real
	# risk, and this is the moment it happens — after the fare and the slot,
	# because a stop on the way does not refund either.
	#
	# Keyed on the district being LEFT: the road out of a corner you have been
	# working is where somebody is looking for you, and keying it on the
	# destination would let a courier launder a hot block by leaving it.
	# Economy performs it because inventory is written there and nowhere else.
	var origin: String = previous_district
	var carry: Dictionary = {}
	var economy: Object = gm.system("economy")
	if economy != null and not checkpointed:
		carry = economy.resolve_carry(origin)

	# Watchers appear during ordinary movement, never during the crime itself.
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	var watcher := ""
	if curtis != null:
		watcher = str(curtis.maybe_watcher_encounter("travel"))

	# Arriving somewhere is the other moment a delayed consequence can become
	# eligible — TI-003 §15 gates activation on the player being PRESENT, and
	# the day-start check alone would only ever catch somebody who slept there.
	#
	# Without this, "avoid the district" would degrade to "avoid sleeping in the
	# district", and a player could work a threatened block every afternoon
	# without ever meeting anybody. The engine still owns every gate; this only
	# asks the question again now that the answer can have changed.
	#
	# Asked AFTER the slot is spent, so a chain that opens here holds the day it
	# is actually opening on.
	var engine: Object = gm.system("consequence")
	if engine != null and not gs.game_over:
		engine.try_surface_delayed(int(gs.day), gs.current_district_id)
	return {"ok": true, "arrived": district.get("name", ""), "watcher": watcher,
		"carry": carry, "checkpointed": checkpointed}

# --- STR-D4: the checkpoint --------------------------------------------------

## Which attribute a checkpoint choice rolls against. The card's own
## `"shape"` ("negotiation", Charisma) is the default -- TALK and HAND OVER (not
## rolled at all) both stay on it; RUN IT is the one choice authored against
## the grain of its own card, the same override shape PR B's
## `CHOICE_ATTRIBUTE_OVERRIDES` established for STASH IT.
func _attribute_for_choice(choice_id: String) -> String:
	var overrides: Dictionary = TRAVEL_EVENTS.CHECKPOINT.get("attribute_overrides", {})
	if overrides.has(choice_id):
		return str(overrides[choice_id])
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	if resolver == null:
		return "charisma"
	var mapped: String = str(resolver.ACTION_ATTRIBUTE_MAP.get(
		str(TRAVEL_EVENTS.CHECKPOINT["shape"]), "charisma"))
	return mapped if not mapped.is_empty() else "charisma"

## Roll the checkpoint gate for this trip. Returns true (and opens the chain)
## if it fired, false if the trip stays quiet -- the caller's own signal for
## whether the older carry-stop tax should still run.
##
## Reads `WanderSystem.attention_steps()` rather than a travel-flavored
## reinvention of it (STR-D4: "the SAME interruption machinery"). Keyed on
## day and slot leading, the destination trailing -- unlike a wander, a
## travel dispatch always advances the slot before this roll, so no two
## checkpoint rolls in one run can ever share a day+slot pair; there is no
## `wander_count`-style third component to add because there is nothing for
## it to disambiguate.
func _roll_checkpoint(target: String) -> bool:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null or engine.has_active() or gs.game_over:
		return false
	var wander: Object = gm.system("wander") if gm != null else null
	var steps: int = int(wander.attention_steps()) if wander != null else 0
	var key := "%d:%d:travel:%s:gate" % [gs.day, gs.time_slots_today, target]
	# `travel.gd` is not RNG-constructed (unlike Wander/Stickup); reached the
	# same way this file already reaches Curtis, rather than widening every
	# `setup()` call site in `game_manager.gd` for one seeded roll.
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null or rng.seeded_random(gs.run_seed, key) >= EVENTS.gate_chance(steps):
		return false
	_open_checkpoint(target, key)
	return true

func _open_checkpoint(target: String, key: String) -> void:
	var engine: Object = gm.system("consequence")
	var attributes: Object = gm.system("attributes") if gm != null else null
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	var script: Dictionary = TRAVEL_EVENTS.CHECKPOINT
	var choices: Array = (script["choices"] as Array).duplicate()
	var base_table: Dictionary = script.get("base", {})
	var shown: Dictionary = {}
	var inputs: Dictionary = {}
	for choice_id in choices:
		var base: Variant = base_table.get(str(choice_id))
		if base == null:
			continue
		var attribute := _attribute_for_choice(str(choice_id))
		shown[str(choice_id)] = float(base)
		inputs[str(choice_id)] = {"attribute": attribute,
			"raw": int(attributes.effective(attribute)) if attributes != null else 1}
	var district: Dictionary = gs.district_by_id(target)
	gs.log_activity("A cruiser lights up behind you before you clear the line.", AMBER)
	engine.open_chain(engine.KIND_TRAVEL_STOP, {
		"district_id": target,
		"return_route": "STREET",
		"source": {
			"family": "travel", "action_id": "travel",
			"definition_id": str(script["definition_id"]),
			"opponent": str(script.get("opponent", "")),
			"target_name": str(district.get("name", "")),
			"source_rng_key": key,
		},
		"decision": {
			"definition_id": str(script["definition_id"]),
			"allowed_choices": choices,
			"deterministic_choices": (script.get("deterministic", []) as Array).duplicate(),
			"resolver_inputs": inputs,
			"shown_probabilities": shown,
			"arrest_risks": {},
		},
	})

## Adapter contract: `ConsequenceEngine._resolve_choice` dispatches here by
## `source.action_id == "travel"`.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var decision: Dictionary = chain.get("decision", {})
	var source: Dictionary = chain.get("source", {})
	var script: Dictionary = TRAVEL_EVENTS.CHECKPOINT
	var tier: String
	if choice_id == "hand_over":
		tier = "deterministic"
	else:
		var attribute := _attribute_for_choice(choice_id)
		var attributes: Object = gm.system("attributes") if gm != null else null
		var raw: int = int(attributes.effective(attribute)) if attributes != null else 1
		var resolver: Object = gm.system("outcome_resolver")
		tier = str((resolver.resolve_action(str(script["shape"]),
			float((decision.get("shown_probabilities", {}) as Dictionary)
				.get(choice_id, 0.5)), raw, gs.run_seed,
			"%s:%s" % [str(source.get("source_rng_key", "")), choice_id]) as Dictionary)["tier"])

	var effects: Dictionary = (script.get("effects", {}) as Dictionary) \
		.get(choice_id, {}).get(tier, {})
	var applied: Dictionary = LOOP.apply_effects(gs, gm, effects, choice_id, "travel_stop")
	gs.log_activity(_feed_line_for(choice_id, tier), AMBER)

	decision["resolved_tier"] = tier
	decision["result"] = {
		"choice_id": choice_id, "tier": tier, "arrested": false, "banned": false,
		"cash": -int(applied["cash"]), "goods": -int(applied["goods"]),
		"health": -int(applied["health"]), "heat": float(applied["heat"]), "pressure": 0,
		"take_disposition": "lose" if (int(applied["goods"]) > 0 or int(applied["cash"]) > 0) else "keep",
	}
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": tier, "arrested": false}

func _feed_line_for(choice_id: String, tier: String) -> String:
	if choice_id == "hand_over":
		return "They take the bag and wave you through. You keep the rest."
	match tier:
		"clean":
			return "It comes to nothing. You're moving again in a minute."
		"messy":
			return "It takes longer than it should, but you're moving again."
		"failure":
			return "It doesn't go your way."
		_:
			return "It goes badly, all the way through."

func choice_label(choice_id: String) -> String:
	return str((TRAVEL_EVENTS.CHOICE_LABELS as Dictionary).get(choice_id, choice_id.capitalize()))

func choice_copy(choice_id: String) -> String:
	return str((TRAVEL_EVENTS.CHOICE_COPY as Dictionary).get(choice_id, ""))

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
## OG-D3: what the beater burns instead of the fare.
const GAS := 2
## A cold morning the beater does not start: seeded, one day in ten in
## a late-fall run. Battery below -10, and no block heater.
const COLD_START_CHANCE := 0.10
## Downtown parking: a window, once in seven trips.
const PARKING_CHANCE := 0.15
const ARRIVAL_AMBER := Color(0.882, 0.651, 0.227)
const RED := Color(0.827, 0.161, 0.125)
const GREEN := Color(0.451, 0.722, 0.404)

## BR-D5: the first time the bus lets you off somewhere, the place says
## what it is. A sheet, once per district, tracked in the wander ledger
## under the arrival's own id so it rides the save without a new field.
const ARRIVALS := {
	"mountain_view": {
		"title": "MOUNTAIN VIEW",
		"line": "The People Mover lets you off on Mountain View Drive and the air changes. Samoan out of one car, Somali out of a doorway, Hmong from the grocery, a kid on a bike yelling in three of them. Red Apple on the corner, Juba Market past it, the rec center and the courts behind. Everybody here is somebody's cousin, and every one of them just looked at you.",
	},
	"downtown": {
		"title": "DOWNTOWN",
		"line": "Fourth Avenue at the hour the suits leave and the bar crowd hasn't come. Cameras on every corner, a bike cop at the light, and money walking around looking for somewhere to go.",
	},
	"airport_industrial": {
		"title": "SHIP CREEK",
		"line": "Post Road. Diesel, wind off the inlet, containers stacked four high and nobody on foot but you. The streetlights stop at the railyard.",
	},
}

## OG-D3: the ride is a scene. One card per trip: the mode, a line about
## the ride in, the destination's banner, and the door. The People Mover
## lines are the routes the World Bible names; the beater's are shorter,
## because so is the ride.
const RIDES := {
	"north_star_lot": {
		"bus": "The 7 down Spenard Road. A woman with three laundry bags, a man asleep against the window, and the Chevron sign coming up on the right like it always does.",
		"car": "Spenard Road in twelve minutes, the heater finally working by the time you park behind the Wash & Go.",
	},
	"downtown": {
		"bus": "Forty minutes on the People Mover, the transit center, and Fourth Avenue opening up under the cameras. Everybody on the bus knew where you were going.",
		"car": "Down Minnesota and across on Fifth. Twelve minutes. You park on G Street and pay attention to who watched you do it.",
	},
	"airport_industrial": {
		"bus": "The last run out Post Road. The driver looks at you in the mirror when you pull the cord, because nobody gets off here on purpose.",
		"car": "Out past the railyard with the lights thinning. The beater is the only car on Post Road that is not a truck, and everybody who sees it knows that.",
	},
	"mountain_view": {
		"bus": "The 45 across the Glenn. Three languages on the bus before Bragaw, and a kid who asks you where you're from like it is a real question.",
		"car": "Across the Glenn and down the Drive. Ten minutes, and a plate that is not from around here, which the block reads before it reads you.",
	},
}

## OG-D3: whether this trip is in the beater. A dead battery is a day on
## the People Mover.
func _driving() -> bool:
	return gs.has_vehicle() and not bool(gs.beater_dead_today)

## Day start: the cold, and whether the beater turns over.
func day_start_beater(today: int) -> void:
	gs.beater_dead_today = false
	if not gs.has_vehicle():
		return
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null:
		return
	if rng.seeded_int_range(gs.run_seed, "%d:cold_start" % today, 0, 99) < int(COLD_START_CHANCE * 100.0):
		gs.beater_dead_today = true
		gs.log_activity("Fourteen below. The beater turns over twice and quits. People Mover today.", AMBER)

## Downtown parking, on arrival by car.
func _park(target: String) -> void:
	if target != "downtown" or not _driving():
		return
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null:
		return
	if rng.seeded_int_range(gs.run_seed, "%d:%d:parking" % [gs.day, gs.time_slots_today], 0, 99) \
			>= int(PARKING_CHANCE * 100.0):
		return
	if not gs.trunk.is_empty():
		gs.trunk = {}
		gs.log_activity("Back at the car: the passenger window is on the seat and the trunk is open. Whatever was in it is gone. Downtown.", RED)
		return
	var wallet: Object = gm.system("wallet")
	var taken: int = mini(60, int(gs.cash))
	if taken > 0:
		wallet.spend(taken, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "parking_window"})
	gs.log_activity("Back at the car: the passenger window is on the seat. $%d in glass and a tow ticket under the wiper. Downtown." % taken, RED)

## OG-D3: Sonny's nephew sells the beater. Bought through the phone: the
## offer is a text, yes is the keys.
func buy_beater() -> Dictionary:
	if gs.has_vehicle():
		return {"ok": false, "reason": "You already have the car."}
	if gs.cash < gs.BEATER_PRICE:
		return {"ok": false, "reason": "Need $%d." % gs.BEATER_PRICE}
	var wallet: Object = gm.system("wallet")
	wallet.spend(gs.BEATER_PRICE, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "beater"})
	gs.vehicle = "beater"
	gs.cargo_max = int(gs.cargo_max) + int(gs.BEATER_CARGO)
	gs.log_activity("A '04 Corolla with a cracked dash, a heater that works and a plate from the Valley. Yours. The day just got bigger.", GREEN)
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null:
		# Uninsured, and she noticed. Curtis's people can read a plate.
		exposure.record_observation("yalonda", {"type": "financial", "event": "uninsured_car", "source": "household"})
		exposure.record_observation("curtis", {"type": "growth", "event": "has_a_car", "source": "network"})
	return {"ok": true}

## The trunk: everything on you goes in, or everything in it comes out.
func trunk_stash() -> Dictionary:
	if not gs.has_vehicle():
		return {"ok": false, "reason": "No trunk to stash in."}
	if gs.inventory.is_empty():
		return {"ok": false, "reason": "Nothing on you."}
	for pid in gs.inventory.keys():
		gs.trunk[pid] = int(gs.trunk.get(pid, 0)) + int(gs.inventory[pid])
	gs.inventory = {}
	gs.log_activity("Everything goes in the trunk under the spare. The checkpoint needs a reason to open that.", AMBER)
	return {"ok": true}

func trunk_take() -> Dictionary:
	if not gs.has_vehicle():
		return {"ok": false, "reason": "No trunk."}
	if gs.trunk.is_empty():
		return {"ok": false, "reason": "The trunk is empty."}
	var room: int = int(gs.cargo_max) - int(gs.cargo_used())
	var moved := 0
	for pid in gs.trunk.keys().duplicate():
		var units: int = mini(int(gs.trunk[pid]), room - moved)
		if units <= 0:
			continue
		gs.inventory[pid] = int(gs.inventory.get(pid, 0)) + units
		gs.trunk[pid] = int(gs.trunk[pid]) - units
		if int(gs.trunk[pid]) <= 0:
			gs.trunk.erase(pid)
		moved += units
	if moved == 0:
		return {"ok": false, "reason": "No room on you."}
	gs.log_activity("%d out of the trunk and onto you." % moved, AMBER)
	return {"ok": true, "moved": moved}

## Sonny's nephew, by text, once, when the money is there.
func day_start_beater_offer(today: int) -> void:
	if gs.has_vehicle() or today < 5 or int(gs.cash) < gs.BEATER_PRICE:
		return
	if int(gs.wander_seen.get("beater_offer", 0)) > 0:
		return
	var phone: Object = gm.system("phone")
	if phone == null:
		return
	gs.wander_seen["beater_offer"] = 1
	phone.push_text("Sonny", "my nephew is selling his corolla. 04. runs. heater works. $%d cash and its yours. you want it?" % gs.BEATER_PRICE, "", {
		"kind": "beater_offer",
		"reply_override": {
			"npc": "sonny",
			"a": {"text": "yeah. ill bring the cash", "reaction": "keys under the mat at the rebel. dont crash it in front of the store"},
			"b": {"text": "not right now", "reaction": "ok. it wont last"},
			"on_accept": {"kind": "buy_vehicle"},
		},
	})

func _ride(from_district: String, to_district: String) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return
	var nav: Node = (loop as SceneTree).root.get_node_or_null("/root/ScreenManager")
	if nav == null:
		return
	var by_car: bool = _driving()
	var lines: Dictionary = RIDES.get(to_district, {})
	var line := str(lines.get("car" if by_car else "bus", ""))
	var name := str(gs.district_by_id(to_district).get("name", to_district))
	nav.enqueue_flow_sheet({
		"kind": "ride",
		"district_id": to_district,
		"kicker": "THE BEATER" if by_car else "THE PEOPLE MOVER",
		"title": name,
		"line": line,
		"cost": ("Gas $%d  ·  one slot" % GAS) if by_car else ("$%d fare  ·  one slot" % FARE),
		"button": "PARK" if by_car else "STEP OFF",
	})

func _first_arrival(district_id: String) -> void:
	if not ARRIVALS.has(district_id):
		return
	var key := "arrival:%s" % district_id
	if int(gs.wander_seen.get(key, 0)) > 0:
		return
	gs.wander_seen[key] = 1
	var arrival: Dictionary = ARRIVALS[district_id]
	gs.log_activity(str(arrival["line"]), ARRIVAL_AMBER)
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return
	var nav: Node = (loop as SceneTree).root.get_node_or_null("/root/ScreenManager")
	if nav != null:
		nav.enqueue_flow_sheet({"kind": "arrival", "title": str(arrival["title"]),
			"line": str(arrival["line"])})

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
	return action in ["travel", "trunk_stash", "trunk_take", "buy_beater"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	# OG-D3: the beater's own actions ride the travel system.
	match action:
		"trunk_stash":
			return trunk_stash()
		"trunk_take":
			return trunk_take()
		"buy_beater":
			return buy_beater()
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
	var driving: bool = _driving()
	var cost: int = GAS if driving else FARE
	if gs.cash < cost:
		return {"ok": false, "reason": "Need $%d %s." % [cost, "for gas" if driving else "fare"]}

	var wallet: Object = gm.system("wallet")
	wallet.spend(cost, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "travel_gas" if driving else "travel_fare"})
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
	_ride(previous_district, target)
	_park(target)
	_first_arrival(target)
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
	if rng == null or rng.seeded_random(gs.run_seed, key) \
			>= EVENTS.gate_chance_from(TRAVEL_EVENTS.CHECKPOINT_BASE_CHANCE, steps):
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
			"opener": "A cruiser lights up behind you before you clear the line.",
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

## BB-D1 (0.7.0): the checkpoint's own result, through the engine's seam.
## Before this the result stage fell through to the sheet's boost copy and a
## searched trunk read "The take is gone and the room remembers your face."
func result_headline(choice_id: String, tier: String, _effects: Dictionary) -> String:
	var row: Array = TRAVEL_EVENTS.result_copy(choice_id, tier)
	return str(row[0]) if row.size() == 2 else ""

func result_body(choice_id: String, tier: String, _effects: Dictionary) -> String:
	var row: Array = TRAVEL_EVENTS.result_copy(choice_id, tier)
	return str(row[1]) if row.size() == 2 else ""

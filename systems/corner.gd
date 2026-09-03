extends RefCounted
## The corner — SQ-D10 (0.6.0 PR D).
##
## `MARKET_SCRIPTS` has sat in `data/confrontation_scripts.gd` since the loop
## was written, fully authored and consumed by nothing. Its own header said the
## triggers "live in the sell path and Post Up"; neither of those files had ever
## heard of it. This is that wiring, and it is the whole of this file's job.
##
## ## Two scripts, one adapter, no new chassis
##
## `corner_stiff` and `corner_push` are both `KIND_CONFRONTATION` chains running
## on `ConfrontationLoop`'s shared helpers, the same as Stickup's rooms, the
## wander shakedown and the doorstep's enforcement room. Nothing here is a new
## loop; `_open`/`_round`/`_exit` below are one chassis parameterised by script
## id, and what differs between the two is entirely in the authored table.
##
## The reason they share an adapter rather than living in `economy.gd` and
## `consequence_engine.gd` respectively: an adapter is registered under ONE
## `action_id` and the engine finds a chain's source through that string. Two
## corner scripts under two action ids would be two registrations, two
## `resolve_consequence` implementations and two places for the round rules to
## drift — which is the exact thing `confrontation_loop.gd` exists to prevent.
## They are the same kind of moment (somebody on the corner has decided the
## terms), so they are one adapter.
##
## ## What each one is
##
## **`corner_stiff` — the short count.** Triggers on a completed market sell in
## a district whose Market Pressure is already visible to the player (KNOWN or
## worse — a corner nobody has noticed does not produce a buyer who thinks he
## can shave thirty dollars off you), at a seeded low chance, **at most once per
## district per day**.
##
## **`corner_push` — Curtis's people.** Triggers on Post Up in Spenard once
## Curtis is `watching` or further along, rare. STAND ON IT writes a `defiance`
## observation into his ledger and STEP OFF writes `submission` — his THREAT
## lens prices both, which is what makes this Curtis and not a generic
## shakedown. Queued through the engine rather than opened inline: Post Up
## already advances the clock and then asks the engine to surface anything
## delayed, and a corner push is exactly a thing that surfaces on a corner.
##
## ## The day bound is DERIVED, not persisted
##
## Ground rules: derive before you persist. `corner_stiff`'s "once per district
## per day" reads the day-stamped counter `add_market_pressure` already keeps on
## the district's own Market pressure row (`market_gain_day` /
## `market_gain_today`, `consequence_engine.gd:1071`). That pair already answers
## "has anything sold in this district today", so the corner fires on the FIRST
## sale of the day in a district and structurally cannot fire twice — no new
## field, no schema bump, and no second idea of what "today" means. Read BEFORE
## `_sell` calls `add_market_pressure`, because after it the answer is always
## "yes".

const SCRIPTS := preload("res://data/confrontation_scripts.gd")
const LOOP := preload("res://systems/confrontation_loop.gd")
const RULES := preload("res://data/consequence_rules.gd")

const GREEN := Color(0.451, 0.722, 0.404)
const AMBER := Color(0.882, 0.651, 0.227)
const RED := Color(0.827, 0.161, 0.125)

## The two trigger chances. Low on purpose: a corner room on every sale would
## make selling a minigame rather than a trade, and STR-D1's own danger list
## ("must not turn the button into a tax") applies to the sell button too.
const STIFF_CHANCE := 0.18
const PUSH_CHANCE := 0.12

## The Market band at or above which a buyer thinks he can shave the count. The
## player can SEE this band on the Market screen, which is the point — a corner
## nobody has noticed does not produce this buyer.
const STIFF_MIN_BAND := "KNOWN"

## Curtis's own corner. `corner_push` is his, and his people work Spenard.
const PUSH_DISTRICT := "north_star_lot"

var gs: Node
var gm: Node
var rng: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager
	rng = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")

func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The corner has nothing to dispatch."}

func _engine() -> Object:
	return gm.system("consequence") if gm != null else null

# --- corner_stiff: the trigger on the sell path ------------------------------

## Whether nothing has sold in this district yet today.
##
## The derivation described in the header. `market_gain_day` is stamped and
## `market_gain_today` zeroed by `add_market_pressure` on the first sale of a
## day; a row whose stamp is not today, or whose gain is still zero, has seen
## no sale. MUST be asked before `_sell` adds its pressure.
func first_sale_today(district_id: String) -> bool:
	var engine: Object = _engine()
	if engine == null:
		return false
	var row: Dictionary = engine.pressure_row(district_id, "market")
	if int(row.get("market_gain_day", -1)) != int(gs.day):
		return true
	return float(row.get("market_gain_today", 0.0)) <= 0.0

## Called by `economy.gd::_sell` after the money and the goods have moved and
## BEFORE the slot is spent. Returns true when it opened a chain.
##
## Deliberately after the transaction: the sale HAPPENED. What the room decides
## is whether the last thirty dollars of it stays, which is a different question
## from whether the sale went through, and modelling it as a pre-condition would
## make a corner argument able to cancel a trade the player already made.
func try_open_stiff(district_id: String, product_id: String, revenue: int) -> bool:
	var engine: Object = _engine()
	if engine == null or engine.has_active():
		return false
	if not first_sale_today(district_id):
		return false
	if not _band_at_least(district_id, "market", STIFF_MIN_BAND):
		return false
	# Nothing to be short of.
	var shorted: int = _short_amount(revenue)
	if shorted <= 0:
		return false
	# SQ-D11: a Godot-only roll, seeded directly, never a new oracle shape.
	# Varying components first, house style.
	var key := "%d:%d:%s:corner_stiff" % [int(gs.day), int(gs.time_slots_today),
		district_id]
	if rng == null or rng.seeded_random(gs.run_seed, key) >= STIFF_CHANCE:
		return false
	_open("corner_stiff", district_id, {
		"product_id": product_id, "revenue": revenue, "shorted": shorted,
		"rng_key": key,
	})
	return true

## What he is short by: a fifth of the take, floored at $10 and capped at $60.
## Derived from the sale rather than authored flat, so a big handoff is worth
## arguing about and a small one is not.
func _short_amount(revenue: int) -> int:
	if revenue < 40:
		return 0
	return clampi(int(round(float(revenue) * 0.2)), 10, 60)

# --- corner_push: the trigger on Post Up -------------------------------------

## Called by `consequence_engine.gd::_post_up` after the hour has passed and
## after `try_surface_delayed` has had its say — a queued consequence that was
## already waiting outranks a fresh corner push, the same precedence every other
## surfacing site uses.
func try_open_push(district_id: String) -> bool:
	var engine: Object = _engine()
	if engine == null or engine.has_active():
		return false
	if district_id != PUSH_DISTRICT:
		return false
	if not str(gs.curtis_phase) in ["watching", "approaching"]:
		return false
	var key := "%d:%d:%s:corner_push" % [int(gs.day), int(gs.time_slots_today),
		district_id]
	if rng == null or rng.seeded_random(gs.run_seed, key) >= PUSH_CHANCE:
		return false
	_open("corner_push", district_id, {"rng_key": key})
	return true

# --- the chassis (one, parameterised) ----------------------------------------

func _script_for(script_id: String) -> Dictionary:
	return SCRIPTS.MARKET_SCRIPTS.get(script_id, {})

func _beat_at(script_id: String, index: int) -> Dictionary:
	var beats: Array = _script_for(script_id).get("beats", [])
	if beats.is_empty():
		return {}
	return beats[clampi(index, 0, beats.size() - 1)]

func _open(script_id: String, district_id: String, context: Dictionary) -> void:
	var engine: Object = _engine()
	var script: Dictionary = _script_for(script_id)
	var loop: Dictionary = {
		"script_id": script_id,
		"beat_index": 0,
		"round": 1,
		"log": [],
		"burned": [],
		"crew_called": false,
		"sheet_title": str(script.get("sheet_title", "")),
		"stage": 0,
		"stage_count": int(script.get("cap", 1)),
		"left_label": "STILL HERE",
		"left": 1 if script_id == "corner_stiff" else 2,
		"banked": int(context.get("shorted", 0)),
	}
	var stub: Dictionary = {"decision": {}}
	_present(stub, loop, script_id, 0)
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": district_id,
		"return_route": "MARKET" if script_id == "corner_stiff" else "STREET",
		"source": {
			"family": "corner",
			"action_id": "corner",
			"kind": script_id,
			"target_id": script_id,
			"target_name": str(script.get("opponent", "")),
			"opponent": str(script.get("opponent", "")),
			"source_rng_key": str(context.get("rng_key", "")),
			"product_id": str(context.get("product_id", "")),
			"revenue": int(context.get("revenue", 0)),
			"shorted": int(context.get("shorted", 0)),
			"contested_take": int(context.get("shorted", 0)),
		},
		"decision": stub["decision"],
	})
	gs.log_activity(_open_line(script_id), AMBER)

func _open_line(script_id: String) -> String:
	if script_id == "corner_stiff":
		return "The count is short, and he is still standing there."
	return "Two of Curtis's people have opinions about this corner."

## Put one authored beat on the table. The one place a beat becomes a round.
func _present(chain: Dictionary, loop: Dictionary, script_id: String,
		index: int) -> void:
	var script: Dictionary = _script_for(script_id)
	var beat: Dictionary = _beat_at(script_id, index)
	var actions: Dictionary = script.get("actions", {})

	loop["beat_index"] = index
	loop["stage"] = index
	loop["beat"] = str(beat.get("beat", ""))
	LOOP.append_log(loop, str(beat.get("log", "")))

	var offered: Array = LOOP.without_burned(loop, beat.get("choices", []))
	# A crew call authored INTO a script's own action table (corner_push's
	# CALL TONE) is that script's, not the chassis's — it is offered because
	# the beat offers it, and it still answers to `CREW_CALLS`' availability
	# rules through the shared question in `wander.gd`.
	var final_offer: Array = []
	for choice_id in offered:
		if SCRIPTS.CREW_CALLS.has(str(choice_id)):
			if bool(loop.get("crew_called", false)) or not _crew_available(str(choice_id)):
				continue
		final_offer.append(str(choice_id))

	var shown: Dictionary = {}
	for choice_id in final_offer:
		var action: Dictionary = actions.get(str(choice_id), {})
		if bool(action.get("deterministic", false)) or not action.has("base"):
			continue
		shown[str(choice_id)] = float(action["base"])

	var deterministic: Array = []
	for choice_id in final_offer:
		if str(choice_id) in (beat.get("deterministic", []) as Array):
			deterministic.append(str(choice_id))

	LOOP.present_round(chain, loop, final_offer, deterministic, shown)
	var decision: Dictionary = chain.get("decision", {})
	decision["definition_id"] = script_id
	loop["round"] = index + 1
	decision["loop"] = loop
	chain["decision"] = decision

func _crew_available(call_id: String) -> bool:
	var wander: Object = gm.system("wander") if gm != null else null
	if wander == null:
		return false
	return bool(wander._crew_call_available(call_id))

# --- resolution --------------------------------------------------------------

## The engine's one adapter method. Registered under `"corner"`.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var loop: Dictionary = LOOP.loop_of(chain)
	var script_id := str(loop.get("script_id",
		(chain.get("source", {}) as Dictionary).get("kind", "")))
	var index: int = int(loop.get("beat_index", 0))
	var script: Dictionary = _script_for(script_id)
	var action: Dictionary = (script.get("actions", {}) as Dictionary).get(choice_id, {})

	if SCRIPTS.CREW_CALLS.has(choice_id):
		return _resolve_crew_call(chain, loop, script_id, choice_id)

	if bool(action.get("deterministic", false)):
		return _exit(chain, loop, script_id, choice_id, "deterministic")

	# SQ-D11: the action's own authored shape and attribute, both of which the
	# oracle already carries. Nothing new is added to `OUTCOME_SHAPES`.
	var resolver: Object = gm.system("outcome_resolver")
	var attributes: Object = gm.system("attributes")
	var shape := str(action.get("shape", "confrontation"))
	var attribute := str(action.get("attribute", "combat"))
	var chance: float = float(action.get("base", 0.5))
	var tier := "failure"
	if resolver != null:
		tier = str((resolver.resolve_action(shape, chance,
			int(attributes.effective(attribute)) if attributes != null else 1,
			gs.run_seed, "%d:%s:%s:corner" % [index,
				str((chain.get("source", {}) as Dictionary).get("source_rng_key", "")),
				choice_id]) as Dictionary)["tier"])

	# Success and catastrophe both end it. A plain `failure` burns the verb and
	# opens the next beat where one is authored — the chassis's own Q6 rule,
	# not a corner-specific one.
	if tier == "failure":
		var beats: Array = script.get("beats", [])
		if index + 1 < mini(beats.size(), int(script.get("cap", 1))):
			LOOP.burn(loop, choice_id)
			_present(chain, loop, script_id, index + 1)
			gs.active_consequence = chain
			return {"ok": true, "tier": "continued"}
	return _exit(chain, loop, script_id, choice_id, tier)

func _resolve_crew_call(chain: Dictionary, loop: Dictionary, script_id: String,
		call_id: String) -> Dictionary:
	var call: Dictionary = SCRIPTS.CREW_CALLS[call_id]
	var crew_id := str(call.get("crew_id", ""))
	var record: Dictionary = gs.crew_record(crew_id)
	record["loyalty"] = maxi(0, int(record.get("loyalty", 0))
		- int(call.get("loyalty_cost", 1)))
	gs.crew_records[crew_id] = record
	if float(call.get("heat", 0.0)) > 0.0:
		LOOP.apply_heat(gs, gm, float(call["heat"]), "corner")
	loop["crew_called"] = true
	LOOP.append_log(loop, "You made a call. It ended there.")
	# Tone ending it IS holding the corner, and Curtis's ledger reads it that
	# way — the observation is the corner's, not the call's.
	return _exit(chain, loop, script_id, call_id, "deterministic")

## Every exit, both scripts. The authored `observation` row on the action that
## was taken reaches Curtis through Exposure, receipted, so a reload at the
## result stage cannot double-write it.
func _exit(chain: Dictionary, loop: Dictionary, script_id: String,
		choice_id: String, tier: String) -> Dictionary:
	var engine: Object = _engine()
	var decision: Dictionary = chain.get("decision", {})
	var source: Dictionary = chain.get("source", {})
	var script: Dictionary = _script_for(script_id)
	var action: Dictionary = (script.get("actions", {}) as Dictionary).get(choice_id, {})

	var recovered := 0
	var hurt := 0
	var heat := 0.0
	var resolution := SCRIPTS.RESOLUTION_WON
	var line := ""

	if script_id == "corner_stiff":
		var shorted: int = int(source.get("shorted", 0))
		match choice_id:
			"let_it_ride":
				resolution = SCRIPTS.RESOLUTION_SURRENDERED
				line = "You eat the short and let him walk. The corner stays quiet."
			"count_again":
				if tier in ["clean", "messy"]:
					recovered = shorted
					line = "You count it back to him out loud. He finds the rest."
				else:
					resolution = SCRIPTS.RESOLUTION_BEATEN
					line = "He has a number and it is not yours. He leaves with the difference."
			_:
				if tier in ["clean", "messy"]:
					recovered = shorted
					heat = 0.5
					line = "He pays the rest. He will remember being made to."
				else:
					resolution = SCRIPTS.RESOLUTION_BEATEN
					hurt = 6 if tier == "failure" else 10
					heat = 1.0
					line = "It turns physical over thirty dollars, and it does not go your way."
		if recovered > 0:
			var wallet: Object = gm.system("wallet")
			if wallet != null:
				wallet.credit(recovered, wallet.DIRTY,
					{"source_id": "corner_stiff_recovered"})
	else:
		match choice_id:
			"step_off":
				resolution = SCRIPTS.RESOLUTION_SURRENDERED
				line = "You give them the corner. The block sees you do it."
			"call_tone":
				line = "Tone gets there and stands where they were standing. Nobody argues."
			_:
				if tier in ["clean", "messy"]:
					heat = 1.0
					line = "You are still on the corner when they leave it."
				else:
					resolution = SCRIPTS.RESOLUTION_BEATEN
					hurt = 8 if tier == "failure" else 14
					heat = 1.5
					line = "They take the corner and make sure it is remembered."

	if hurt > 0:
		var crew: Object = gm.system("crew") if gm != null else null
		if crew != null:
			hurt = int(crew.absorbed_damage(hurt))
		gs.health = clampi(int(gs.health) - hurt, 0, int(gs.health_max))
	if heat > 0.0:
		heat = LOOP.apply_heat(gs, gm, heat, "corner")

	gs.log_activity(line, GREEN if resolution == SCRIPTS.RESOLUTION_WON else AMBER)
	LOOP.append_log(loop, line)
	_record_observation(chain, action)

	decision["resolved_tier"] = tier
	decision["result"] = {
		"choice_id": choice_id, "tier": tier, "resolution": resolution,
		"arrested": false, "banned": false,
		"cash": recovered, "goods": 0, "health": -hurt, "heat": heat, "pressure": 0,
		"take_disposition": "keep" if recovered > 0 else "lose",
		"room_log": (loop.get("log", []) as Array).duplicate(),
	}
	decision["loop"] = loop
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": tier, "arrested": false}

## `corner_push`'s whole political point: STAND ON IT writes `defiance`,
## STEP OFF writes `submission`, and Curtis's THREAT lens prices both. Read off
## the action's own authored `observation` row rather than matched here, so the
## table stays the one place that decides what a road means.
func _record_observation(chain: Dictionary, action: Dictionary) -> void:
	var spec: Variant = action.get("observation")
	if not (spec is Dictionary):
		return
	var engine: Object = _engine()
	var cause_id := str(chain.get("cause_id", ""))
	if engine == null or cause_id.is_empty() \
			or not engine.record_receipt(cause_id, "corner:observation"):
		return
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure == null:
		return
	var row: Dictionary = (spec as Dictionary).duplicate()
	row["location"] = str(chain.get("district_id", gs.current_district_id))
	exposure.record_observation("curtis", row)

# --- the engine's copy seam ---------------------------------------------------

## BB-D1 (0.7.0): the corner's own endings. Keyed by script, then by the road
## taken, then by the resolution `_exit` recorded -- a short count recovered
## and a short count eaten are different facts about the same thirty dollars.
const RESULT_COPY := {
	"corner_stiff": {
		"let_it_ride": {
			"surrendered": ["YOU EAT THE SHORT", "Thirty dollars to keep the corner quiet. Sometimes that is the play, and nobody but you will remember it."],
		},
		"count_again": {
			"won": ["HE FINDS THE REST", "You count it back to him out loud. Numbers do not get embarrassed, and neither do you."],
			"beaten": ["HE HAS HIS OWN NUMBER", "It is not yours. He leaves with the difference, and the corner watches him do it."],
		},
		"press_him": {
			"won": ["HE PAYS THE REST", "Full price. He will remember being made to, and so will the two people who watched."],
			"beaten": ["OVER THIRTY DOLLARS", "It turns physical over a short count and it does not go your way. The corner takes note of both facts."],
		},
	},
	"corner_push": {
		"stand_on_it": {
			"won": ["STILL ON THE CORNER", "They leave it before you do. The block saw that, and by tonight so will Curtis."],
			"beaten": ["THEY TAKE THE CORNER", "And they make sure it is remembered. Curtis will hear you stood, and he will hear how it ended."],
		},
		"step_off": {
			"surrendered": ["YOU STEP OFF", "Live to sell somewhere else. The block remembers who moved, and Curtis keeps the block's records."],
		},
		"call_tone": {
			"won": ["TONE STANDS WHERE THEY WERE", "Nobody argues with it. It cost a favor, and Curtis noticed who you called."],
		},
	},
}

func result_copy(choice_id: String, effects: Dictionary) -> Array:
	var loop: Dictionary = LOOP.loop_of(gs.active_consequence)
	var script_id := str(loop.get("script_id",
		(gs.active_consequence.get("source", {}) as Dictionary).get("kind", "")))
	return ((RESULT_COPY.get(script_id, {}) as Dictionary).get(choice_id, {}) as Dictionary) \
		.get(str(effects.get("resolution", "")), [])

func result_headline(choice_id: String, _tier: String, effects: Dictionary) -> String:
	var row: Array = result_copy(choice_id, effects)
	return str(row[0]) if row.size() == 2 else ""

func result_body(choice_id: String, _tier: String, effects: Dictionary) -> String:
	var row: Array = result_copy(choice_id, effects)
	return str(row[1]) if row.size() == 2 else ""

func choice_label(choice_id: String) -> String:
	for script in SCRIPTS.MARKET_SCRIPTS.values():
		var action: Dictionary = (script as Dictionary)["actions"].get(choice_id, {})
		if not action.is_empty():
			return str(action.get("label", ""))
	return ""

func choice_copy(choice_id: String) -> String:
	for script in SCRIPTS.MARKET_SCRIPTS.values():
		var action: Dictionary = (script as Dictionary)["actions"].get(choice_id, {})
		if not action.is_empty():
			return str(action.get("copy", ""))
	return ""

## The deterministic roads state their own price, ENC-D6's seam — the screen's
## fallback ("no injury, no Heat, no arrest") is true of neither of these.
func choice_guarantee(choice_id: String) -> String:
	match choice_id:
		"let_it_ride":
			return "Guaranteed: the short stays short. Nobody remembers it but you."
		"step_off":
			return "Guaranteed: nobody is hurt. The block knows whose corner it is now."
		"call_tone":
			return "Guaranteed: it ends. It costs a favor you will want back later."
	return ""

## The band read, shared shape with `wander.gd`'s own. Bands, never the score.
func _band_at_least(district_id: String, family: String, floor_band: String) -> bool:
	var engine: Object = _engine()
	if engine == null:
		return false
	var rules: RefCounted = RULES.new()
	var order: Array = [rules.BAND_QUIET, rules.BAND_KNOWN, rules.BAND_WATCHED,
		rules.BAND_HOT]
	return order.find(str(engine.pressure_band(district_id, family))) \
		>= order.find(floor_band)

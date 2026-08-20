extends RefCounted
## Stickup — armed robbery, and the first thing in the game that raises Heat.
##
## Ported from game-core.js (STICKUP reducer ~8491, stickChance ~2440) and the
## STICK_TARGETS table in src/data/districts.js.
##
## Canon's chance formula:
##   base   = tier 1 → 0.62 · tier 2 → 0.52 · tier 3 → 0.40
##   chance = clamp(base
##                  + (combat - 2) * 0.08
##                  + weaponBonus            (firearm 0.12 · other 0.06)
##                  + planning               (casing * 0.06, crew on tier 3)
##                  - resistance * 0.08
##                  - heat * 0.012
##                  + districtDelta,
##                  0.15, 0.90)
##
## Three of those terms need systems that do not exist yet. Rather than invent
## values, each is pinned at its canon neutral and named here so the gap is
## legible when those systems land:
##   combat        → ATTRIBUTE_DEFAULTS.combat = 1, so the term is a flat -0.08
##   weaponBonus   → 0 (no equipment system; tier 2+ gating is relaxed to suit)
##   planning      → 0 (no casing, no crew)
##   districtDelta → 0 (no district heat/attention tracking)
##
## Heat is the real cost and it IS ported: canon clamps 0-15 and this does too.

const RED := Color(0.827, 0.161, 0.125)
const GREEN := Color(0.451, 0.722, 0.404)

## Canon ATTRIBUTE_DEFAULTS.combat for a fresh run (src/data/attributes.js).
const COMBAT_DEFAULT := 1

var gs: Node
var rng: Node
var time_system: RefCounted
var gm: Node

func setup(game_state: Node, rng_manager: Node, time: RefCounted, manager: Node) -> void:
	gs = game_state
	rng = rng_manager
	time_system = time
	gm = manager
	gs.day_crossed.connect(_on_day_crossed)

## Canon scales generated heat by DESHAWN_HEAT_REDUCTION when he is on the crew.
## Returns the heat actually applied.
func _apply_heat(amount: int) -> float:
	var mult: float = 1.0
	var crew: Object = gm.system("crew") if gm != null else null
	if crew != null:
		mult = crew.heat_multiplier()
	# Kept fractional deliberately: rounding here is what made the reduction
	# invisible on small amounts.
	var scaled: float = float(amount) * mult if amount > 0 else 0.0
	gs.heat = clampf(gs.heat + scaled, 0.0, float(gs.heat_max))
	return scaled

func _curtis() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Curtis")

func can_handle(action: String) -> bool:
	return action == "stickup"

func handle(action: String, payload: Dictionary) -> Dictionary:
	if action != "stickup":
		return {"ok": false, "reason": "Unknown stickup action."}
	return _run(str(payload.get("target_id", "")))

## Targets visible from where the player is standing, at or below their tier.
func visible_targets() -> Array:
	var out: Array = []
	for t in gs.stick_targets:
		if str(t["area"]) != gs.current_district_id:
			continue
		if int(t["tier"]) > gs.stick_tier:
			continue
		out.append(t)
	return out

## Why this target can't be hit right now, or "" if it can. Canon's reasons,
## verbatim where they still apply.
func blocker(target_id: String) -> String:
	if gs.game_over:
		return "The run is over."
	var t: Dictionary = gs.stick_target_by_id(target_id)
	if t.is_empty():
		return "No such target."
	if str(t["area"]) != gs.current_district_id:
		return "Wrong part of town."
	if int(t["tier"]) > gs.stick_tier:
		return "You are not there yet."
	var slots: Array = t.get("slots", [])
	if not slots.is_empty() and not gs.time_slots_today in slots:
		var names := ["Morning", "Afternoon", "Evening", "Night"]
		var when: Array = []
		for s in slots:
			when.append(names[int(s)])
		return "Runs %s only." % " or ".join(when)
	if gs.stick_daily_count >= gs.STICK_DAILY_CAP:
		return "Two in a day is how people get named. Tomorrow."
	return ""

## Canon stickChance, with the unbuilt terms pinned at neutral (see header).
func chance_for(target: Dictionary) -> float:
	var tier: int = int(target["tier"])
	var base: float = 0.62 if tier == 1 else (0.52 if tier == 2 else 0.40)
	var c: float = base \
		+ (float(COMBAT_DEFAULT) - 2.0) * 0.08 \
		- float(target["resistance"]) * gs.DISTRICT_DIFF_STEP \
		- gs.heat * 0.012
	return clampf(c, 0.15, 0.90)

func _run(target_id: String) -> Dictionary:
	var blocked := blocker(target_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var t: Dictionary = gs.stick_target_by_id(target_id)

	# Canon keys this roll on seed:stickup:day:slot:targetId.
	var key := "stickup:%d:%d:%s" % [gs.day, gs.time_slots_today, target_id]
	var roll: float = rng.seeded_random(gs.run_seed, key)
	var success: bool = roll < chance_for(t)

	gs.stick_attempts += 1
	gs.stick_daily_count += 1

	var result: Dictionary
	if success:
		var band: Array = t["take"]
		var take: int = rng.seeded_int_range(gs.run_seed, key + ":take", int(band[0]), int(band[1]))
		gs.cash += take
		var applied: float = _apply_heat(int(t["heat"]))
		gs.stick_rep += 1
		gs.stick_successes += 1
		# Canon: a successful robbery is loud in Curtis's world.
		var curtis: Node = _curtis()
		if curtis != null:
			curtis.raise_awareness(2)
			curtis.mark_criminal_activity()
		gs.log_activity("%s: +$%d, heat +%.1f." % [str(t["name"]), take, applied], GREEN)
		result = {"ok": true, "success": true, "take": take, "heat": applied}
	else:
		# Canon still charges heat on a bad attempt — being seen is the cost,
		# whether or not the money moved.
		var missed_heat: float = _apply_heat(maxi(1, int(t["heat"]) - 1))
		gs.log_activity("%s went wrong. Heat +%.1f, nothing to show." % [str(t["name"]), missed_heat], RED)
		result = {"ok": true, "success": false, "take": 0, "heat": missed_heat}

	# A robbery is a slot, the same as any other district action.
	time_system.handle("advance_time", {})
	return result

func _on_day_crossed() -> void:
	gs.stick_daily_count = 0

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
##   combat        → LIVE as of Phase 5c (was pinned, and pinned WRONG — see below)
##   weaponBonus   → 0 (no equipment system; tier 2+ gating is relaxed to suit)
##   planning      → 0 (no casing, no crew)
##   districtDelta → 0 (no district heat/attention tracking)
##
## The combat term reads canon's `combatCompat` (game-core.js:2402), which is
## `Attributes.compatibilityRating` — the stored value offset onto the 1-5 scale
## this formula was tuned against. The pin was `ATTRIBUTE_DEFAULTS.combat = 1`,
## the STORED default, where canon reads the COMPATIBILITY value of 2. That made
## the term -0.08 instead of 0, and every robbery in this build 8 points harder
## than canon from Phase 3d until Phase 5c.
##
## Heat is the real cost and it IS ported: canon clamps 0-15 and this does too.
##
## ## Tiered resolution (Build 5e)
##
## The roll is no longer binary. `outcome_resolver` splits `chance_for()` across
## canon's four tiers and Combat decides how the pool is read — a second look at
## 3, catastrophe immunity at 6. Stickup is the vertical proof for that engine,
## so what follows is the whole consequence spread rather than success/failure:
##
## | tier         | cash | heat            | health   | Curtis        |
## |--------------|------|-----------------|----------|---------------|
## | clean        | take | target x 0.5    | —        | +1            |
## | messy        | take | target x 1.0    | -5..-10  | +2, criminal  |
## | failure      | $0   | max(1, heat-1)  | —        | +1            |
## | catastrophic | $0   | target x 1.5    | -15..-25 | +3, criminal  |
##
## A clean take is quieter because nobody watched you struggle; a catastrophe is
## louder because you were. The Exposure footprint moves with it —
## `broadcast_outcome` is now the ONLY place this file talks to Curtis about
## what the block saw.
##
## **This spread is the port's, not canon's.** Canon's failure branch runs
## through an arrest system, dirty cash, district heat weighting, a witness roll
## and a retaliation queue, none of which exist in this build; inventing them to
## reach canon's exact numbers would be guessing. What IS canon-exact is the
## thing that had to be: the tier pick itself. Same seed, same chance, same
## Combat, same tier as the web build. The divergences are listed in the PR.

const RED := Color(0.827, 0.161, 0.125)
const GREEN := Color(0.451, 0.722, 0.404)
const AMBER := Color(0.882, 0.651, 0.227)

## Health cost per tier, as canon's `[min, max]` band shape. Clean and failure
## are absent rather than zeroed: no band means no injury roll is keyed at all,
## which keeps those two tiers off the RNG entirely.
const INJURY_BANDS := {
	"messy": [5, 10],
	"catastrophic": [15, 25],
}

## What each tier does to Curtis: how far his awareness moves, and whether the
## night counts as criminal activity (which is what stops the quiet streak from
## bleeding awareness back down).
const CURTIS_BY_TIER := {
	"clean": {"awareness": 1, "criminal": false},
	"messy": {"awareness": 2, "criminal": true},
	"failure": {"awareness": 1, "criminal": false},
	"catastrophic": {"awareness": 3, "criminal": true},
}

## The authored arrest gate lives in the shared rules module, not here. Stick
## decides nothing about what an arrest costs — see systems/arrest.gd.
const RULES := preload("res://data/consequence_rules.gd")

var gs: Node
var rng: Node
var time_system: RefCounted
var gm: Node
var attributes: RefCounted

func setup(game_state: Node, rng_manager: Node, time: RefCounted, manager: Node,
		attribute_system: RefCounted) -> void:
	gs = game_state
	rng = rng_manager
	time_system = time
	gm = manager
	attributes = attribute_system
	gs.day_crossed.connect(_on_day_crossed)

## Canon scales generated heat by DESHAWN_HEAT_REDUCTION when he is on the crew.
## Returns the heat actually applied.
##
## Takes a float since the tier conversion: clean halves the target's heat and
## catastrophic multiplies it by 1.5, and rounding either to an int here is what
## would flatten the difference between them on a 1-heat target.
##
## The scaling itself is gone from this file. It lived here AND in boost.gd, in
## identical copies, and both now route through the one owner (TI-003 §7). This
## does no multiplication of its own — that is what keeps Deshawn applying once.
func _apply_heat(amount: float) -> float:
	var heat: Object = gm.system("heat") if gm != null else null
	if heat == null:
		return 0.0
	return heat.apply_gain(amount, heat.FAMILY_STICK, gs.current_district_id,
		{"source_id": "stickup"})

## The shared cash owner. A stickup take is dirty money by definition.
func _wallet() -> Object:
	return gm.system("wallet")

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
		+ (float(attributes.compat("combat")) - 2.0) * 0.08 \
		- float(target["resistance"]) * gs.DISTRICT_DIFF_STEP \
		- gs.heat * 0.012 \
		- _pressure_penalty()
	return clampf(c, 0.15, 0.90)

## TI-003 §8's local difficulty penalty for the Stick family, subtracted before
## the existing clamp. Zero in a QUIET district, which is every fresh run.
##
## `resistance` and this are not the same thing and must not be confused: the
## target's resistance is how hard THAT mark is, permanently. Pressure is how
## much attention YOU have brought to this district, and it decays.
func _pressure_penalty() -> float:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return 0.0
	return engine.difficulty_penalty(gs.current_district_id, "stick")

func _run(target_id: String) -> Dictionary:
	var blocked := blocker(target_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var t: Dictionary = gs.stick_target_by_id(target_id)

	# TI-003 §14: the arrest gate reads "pre-source Heat" — the Heat the player
	# was ALREADY carrying when they walked up, snapshotted here before this
	# robbery generates any of its own. Reading the live meter after resolution
	# would let a loud job decide its own arrest, which is regression-shaped: the
	# tiers that generate the most Heat are exactly the tiers being gated.
	var pre_source_heat: float = float(gs.heat)

	# Canon keys this roll on seed:stickup:day:slot:targetId, and the resolver
	# joins seed and context exactly as canon's template string does.
	var key := "stickup:%d:%d:%s" % [gs.day, gs.time_slots_today, target_id]
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	if resolver == null:
		return {"ok": false, "reason": "No outcome resolver."}
	# The RAW combat value, not compat() — anything routed through the resolver
	# reads the stored attribute and carries no inline offset. See its header.
	var outcome: Dictionary = resolver.resolve_action(
		"robbery", chance_for(t), attributes.value("combat"), gs.run_seed, key)
	var tier: String = str(outcome["tier"])
	var success: bool = resolver.is_success_tier(tier)

	gs.stick_attempts += 1
	gs.stick_daily_count += 1

	# Health first, and only for the two tiers that carry a band. Keyed off the
	# same string as the tier pick, so a reload replays the injury too.
	var damage: int = 0
	if INJURY_BANDS.has(tier):
		var hurt: Array = INJURY_BANDS[tier]
		damage = rng.seeded_int_range(gs.run_seed, key + ":injury", int(hurt[0]), int(hurt[1]))
		gs.health = clampi(gs.health - damage, 0, gs.health_max)

	var result: Dictionary
	var applied: float
	if success:
		var band: Array = t["take"]
		var take: int = rng.seeded_int_range(gs.run_seed, key + ":take", int(band[0]), int(band[1]))
		_wallet().credit(take, _wallet().DIRTY, {"source_id": "stickup_take"})
		# A clean take is half the heat of a loud one: the money moved and
		# nobody watched you struggle for it.
		applied = _apply_heat(float(t["heat"]) * (0.5 if tier == "clean" else 1.0))
		gs.stick_rep += 1
		gs.stick_successes += 1
		# Canon: a tier-3 job is organized work, and from the second one Curtis
		# is told about it directly over the network. The count rides along, so
		# his read gets worse each time rather than once. Success-only, as canon
		# has it — a blown job is not organized work, it is a blown job.
		if int(t["tier"]) == 3:
			gs.stick_organized_hits += 1
			if gs.stick_organized_hits >= 2:
				var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
				if exposure != null:
					exposure.record_observation("curtis", {
						"type": "violence", "event": "organized_hit",
						"count": gs.stick_organized_hits, "source": "network",
					})
		if tier == "clean":
			gs.log_activity("%s gives it up without a scene. +$%d, heat +%.1f."
				% [str(t["name"]), take, applied], GREEN)
		else:
			gs.log_activity("%s gives it up, but not quietly. +$%d, heat +%.1f, -%d health."
				% [str(t["name"]), take, applied, damage], AMBER)
		result = {"ok": true, "success": true, "tier": tier, "take": take,
			"heat": applied, "damage": damage}
	else:
		# Canon still charges heat on a bad attempt — being seen is the cost,
		# whether or not the money moved. A catastrophe amplifies it because you
		# were loud; a plain failure stays at the pre-tier number.
		applied = _apply_heat((float(t["heat"]) * 1.5) if tier == "catastrophic"
			else float(maxi(1, int(t["heat"]) - 1)))
		if tier == "catastrophic":
			gs.log_activity("%s fights back harder than the plan allowed. Heat +%.1f, -%d health, nothing to show."
				% [str(t["name"]), applied, damage], RED)
		else:
			gs.log_activity("%s went wrong. Heat +%.1f, nothing to show."
				% [str(t["name"]), applied], RED)
		result = {"ok": true, "success": false, "tier": tier, "take": 0,
			"heat": applied, "damage": damage}

	# What Curtis makes of it, and what the block ends up knowing. Both are
	# keyed off the tier now: broadcast_outcome is the single entry point for
	# post-resolution Exposure effects, so this file no longer hand-rolls a
	# `violence / stickup` row of its own.
	var curtis: Node = _curtis()
	if curtis != null:
		var reads: Dictionary = CURTIS_BY_TIER.get(tier, CURTIS_BY_TIER["failure"])
		curtis.raise_awareness(int(reads["awareness"]))
		if bool(reads["criminal"]):
			curtis.mark_criminal_activity()
	resolver.broadcast_outcome("robbery", tier, gs.current_district_id,
		result["take"] if success else null)

	var engine_for_pressure: Object = gm.system("consequence") if gm != null else null

	# FS-003 §6: "Stick uses the resolved outcome table above" — the same tiered
	# gains a Caught encounter uses, under the `stick` family. A clean take is
	# +0.5 because nobody watched you struggle; a catastrophe is +2.0 because
	# everybody did.
	#
	# Written before the Cause is allocated, and deliberately with no cause_id:
	# the source robbery's Pressure is not a consequence effect and carries no
	# receipt, because a robbery resolves once inside one dispatch and cannot be
	# replayed. The bleed it schedules is keyed on the target and the day.
	var rules_pressure: RefCounted = RULES.new()
	var pressure_gain: float = float(rules_pressure.PRESSURE_BY_TIER.get(tier, 0.0))
	if pressure_gain > 0.0 and engine_for_pressure != null:
		engine_for_pressure.add_pressure(gs.current_district_id, "stick", pressure_gain,
			"stickup:%s:%d:%d" % [target_id, gs.day, gs.time_slots_today])
		result["pressure"] = pressure_gain

	# TI-003 §4: "Every qualifying risky source action gets one stable Cause ID."
	# Allocated for EVERY attempt, not only the ones that end badly, because two
	# later consumers need it and neither can know at this point whether it will
	# be wanted: the arrest gate below, and FS-003.10's retaliation scheduler,
	# which keys its schedule roll on the Cause. Allocation is a counter bump and
	# writes no history row, so an attempt nothing answers costs one integer.
	var cause_id: String = ""
	var engine: Object = engine_for_pressure
	if engine != null:
		cause_id = engine.allocate_cause_id()
	result["cause_id"] = cause_id
	result["pre_source_heat"] = pre_source_heat

	# TI-003 §15: the delayed answer, rolled once against the Cause.
	#
	# Scheduled BEFORE the arrest gate below rather than instead of it. An arrest
	# suppresses the row at booking commit (§13 step 7), which means a save taken
	# between the robbery and the booking decision carries a row that is about to
	# be cleared — correct, because the arrest has not happened yet. Skipping the
	# schedule on an arrest instead would make the queue depend on a decision the
	# player has not made.
	var retaliation: Object = gm.system("retaliation") if gm != null else null
	if retaliation != null and not cause_id.is_empty():
		var queued: Dictionary = retaliation.schedule(target_id, tier,
			cause_id, gs.current_district_id)
		result["retaliation_queued"] = not queued.is_empty()

	# TI-003 §14's gate. A blown job books when the player was already carrying
	# more Heat than the tier tolerates; a catastrophe books at every tier.
	var rules: RefCounted = RULES.new()
	var arrested: bool = rules.stick_arrests(int(t["tier"]), tier, pre_source_heat)
	# FS-003.13's post-arrest cooldown. Applied AFTER the authored gate for the
	# same reason Boost applies it after its own: the gate answers "were you
	# already hot when you tried this", and the cooldown answers the separate
	# question of whether the same precinct is picking you up two days running.
	var arrest_owner: Object = gm.system("arrest") if gm != null else null
	if arrested and arrest_owner != null and arrest_owner.in_cooldown(int(gs.day)):
		arrested = false
		result["arrest_suppressed"] = "cooldown"
	result["arrested"] = arrested
	if arrested and engine != null and not engine.has_active():
		var opened: Dictionary = _open_booking(t, tier, cause_id, pre_source_heat, result)
		if bool(opened.get("ok", false)):
			# TI-003 §14: "Arrest enters Booking under the same Cause and keeps
			# source time unsettled until Booking commits it." So no
			# `advance_time` here — the robbery's own slot is settled by the
			# booking commit, exactly once, alongside the time being held.
			return result

	# A robbery is a slot, the same as any other district action.
	time_system.handle("advance_time", {})
	return result

# --- the arrest adapter (TI-003 §14) ---------------------------------------

## Open the booking chain for a robbery that ended in cuffs.
##
## The chain opens directly at `result` rather than at `decision`. There was no
## decision: the robbery already resolved through this system's own tier roll,
## and the player answers for it rather than choosing how it went. Opening at
## `decision` with an empty choice list and immediately walking past it would
## put a stage in the save that nothing ever rendered.
func _open_booking(target: Dictionary, tier_name: String, cause_id: String,
		pre_source_heat: float, source_result: Dictionary) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var arrest: Object = gm.system("arrest")
	if engine == null or arrest == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var tier: int = int(target["tier"])
	var opened: Dictionary = engine.open_chain(engine.KIND_STICK_BOOKING, {
		"cause_id": cause_id,
		"initial_stage": engine.STAGE_RESULT,
		"district_id": gs.current_district_id,
		"return_route": "STICKUP",
		"source": {
			"family": "stick",
			"action_id": "stickup",
			"target_id": str(target["id"]),
			"target_name": str(target["name"]),
			"target_tier": tier,
			"source_day": int(gs.day),
			"source_slot": int(gs.time_slots_today),
			"source_rng_key": "stickup:%d:%d:%s" % [gs.day, gs.time_slots_today, str(target["id"])],
			"pre_encounter_heat": pre_source_heat,
			"contested_take": 0,
		},
		"decision": {
			"definition_id": "stick_booking",
			# No responses. The robbery is over; what follows is procedure.
			"allowed_choices": [],
			"resolved_tier": tier_name,
			"result": {
				"choice_id": "",
				"tier": tier_name,
				"cash": int(source_result.get("take", 0)),
				"health": -int(source_result.get("damage", 0)),
				"heat": float(source_result.get("heat", 0.0)),
				"arrested": true,
				"target_name": str(target["name"]),
			},
		},
	})
	if not bool(opened.get("ok", false)):
		return opened
	arrest.attach_booking(gs.active_consequence, {
		"family": "stick",
		"tier": tier,
		"target_id": str(target["id"]),
		"cause_id": cause_id,
	})
	return {"ok": true}

func _on_day_crossed() -> void:
	gs.stick_daily_count = 0

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
	# Driven by DayLifecycle in declared order (`DAY_START_ORDER:stickup_day_reset`).
	# This used to be `gs.day_crossed.connect(_on_day_crossed)` — the exact
	# pattern day_lifecycle.gd exists to abolish, surviving in one of the two
	# places the ordering contract names. See `day_reset()` below.

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

## Canon's updateStickTier, which this port had never had.
##
## `stick_tier` gates `visible_targets()` and `blocker()` and was written exactly
## once in the whole build — `= 1`, at reset. `stick_rep` counted every
## successful take and nothing read it. The result was a ladder with rungs
## authored and no way to climb: tier-2 and tier-3 targets existed in
## `stick_targets`, including the two biggest paydays in the surface, and a real
## player could never reach any of them. The simulation harness set
## `stick_tier = 3` by hand, which is how a missing progression hides — the only
## thing that ever exercised the upper tiers was a test that skipped the climb.
##
## Shaped after `BoostSystem._update_tier()` deliberately. The two are the same
## idea told twice, and a second shape would be a second thing to reason about.
## Rep is the count of jobs that came off, so the ladder is climbed by doing the
## work rather than by paying for it — which is the whole point of it being a
## progression rather than a purchase.
func _update_tier() -> void:
	var was: int = gs.stick_tier
	if gs.stick_rep >= gs.STICK_TIER2_REP:
		gs.stick_tier = maxi(gs.stick_tier, 2)
	# Tier 3 is organised work. Canon already treats it that way — it tells
	# Curtis about the second tier-3 job directly over the network — so the gate
	# is the same one Boost's tier 3 reads: somebody who can be put somewhere.
	var crew: Object = gm.system("crew") if gm != null else null
	var has_crew: bool = (not gs.STICK_TIER3_NEEDS_FIELD_CREW) \
		or (crew != null and crew.has_field_crew())
	if gs.stick_rep >= gs.STICK_TIER3_REP and has_crew:
		gs.stick_tier = maxi(gs.stick_tier, 3)
	if gs.stick_tier > was:
		gs.log_activity("Word gets around. Bigger rooms will take your call now.", GREEN)

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
	if gs.stick_daily_count >= daily_cap():
		return "That's enough attention for one day. Tomorrow."
	return ""

## STK-D1 (0.3.0): the daily cap scales with rep instead of sitting flat at
## two forever. Reuses the exact milestones tier progression already reads
## (`_update_tier`'s own `STICK_TIER2_REP`/`STICK_TIER3_REP`) rather than
## authoring new thresholds — proving yourself capable of a bigger room is
## the same story as earning another attempt at the smaller ones, told once.
## The cap stays a COUNT, `blocker()`'s own semantics unchanged; only what it
## is compared against moves.
func daily_cap() -> int:
	var cap: int = gs.STICK_DAILY_CAP
	if gs.stick_rep >= gs.STICK_TIER2_REP:
		cap += 1
	if gs.stick_rep >= gs.STICK_TIER3_REP:
		cap += 1
	return mini(cap, 4)

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

	# Tier 2 and 3 targets are ROOMS: the robbery is a multi-round confrontation
	# chain, not a single roll (the REPLACE ruling). Tier 1 deliberately falls
	# through to the shipped single-roll path below, byte-for-byte — a mark is
	# one beat, the daily texture stays fast, and the tier-1 parity probe stays
	# untouched. See `data/confrontation_scripts.gd` for the authored rooms.
	if _scripts().has_room(t):
		return _open_room(t, pre_source_heat)

	# Canon keys this roll on seed:stickup:day:slot:targetId, and the resolver
	# joins seed and context exactly as canon's template string does.
	var key := "stickup:%d:%d:%s" % [gs.day, gs.time_slots_today, target_id]
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	if resolver == null:
		return {"ok": false, "reason": "No outcome resolver."}
	# The RAW combat value, not compat() — anything routed through the resolver
	# reads the stored attribute and carries no inline offset. See its header.
	var outcome: Dictionary = resolver.resolve_action(
		"robbery", chance_for(t), attributes.effective("combat"), gs.run_seed, key)
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
		# Through Tone, who has been surfaced on the Crew screen doing nothing
		# since the port began. One owner for the reduction — see
		# `CrewSystem.absorbed_damage`.
		damage = _crew_absorbed(damage)
		gs.health = clampi(gs.health - damage, 0, gs.health_max)

	var result: Dictionary
	var applied: float
	if success:
		var band: Array = t["take"]
		var take: int = rng.seeded_int_range(gs.run_seed, key + ":take", int(band[0]), int(band[1]))
		_wallet().credit(take, _wallet().DIRTY, {"source_id": "stickup_take"})
		gs.record_earning("stick", take)
		# A clean take is half the heat of a loud one: the money moved and
		# nobody watched you struggle for it.
		applied = _apply_heat(float(t["heat"]) * (0.5 if tier == "clean" else 1.0))
		gs.stick_rep += 1
		gs.stick_successes += 1
		_update_tier()
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
		# PRESS-D1 (0.4.0 PR D): capped the same way Boost's own gains are,
		# Market's precedent for both. `result["pressure"]` reports what
		# actually landed (post-cap), not the authored tier amount, so a
		# capped day's own reporting stays honest about it.
		result["pressure"] = engine_for_pressure.add_capped_pressure(
			gs.current_district_id, "stick", pressure_gain,
			rules_pressure.PRESSURE_STICK_DAILY_CAP,
			"stickup:%s:%d:%d" % [target_id, gs.day, gs.time_slots_today])

	# v0.1.0's HOT escape lever, read off the SAME resolved tier as the gain
	# above so the two can never disagree about what just happened. Only `clean`
	# credits anything; the table decides, not this call site. Banked now, paid
	# at POST_SETTLE.
	if engine_for_pressure != null:
		var recovered: float = engine_for_pressure.credit_clean_outcome(
			gs.current_district_id, "stick", tier)
		if recovered > 0.0:
			result["pressure_recovery"] = recovered

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
		# ENC-D1: no booking without a decision. The old direct-to-Booking
		# entry (`_open_booking`, still below) is retired as an ENTRY path —
		# the player answers fight/run/talk/yield to the responding officer
		# before any arrest resolves. See `_open_stick_caught`.
		var opened: Dictionary = _open_stick_caught(t, tier, cause_id, pre_source_heat, result)
		if bool(opened.get("ok", false)):
			# ENC-D9: the blown job's slot is owed, not spent — the chain
			# owes it and the engine's existing Continue/Booking settlement
			# pays it exactly once, same as the old entry's own time contract.
			return result

	# A robbery is a slot, the same as any other district action.
	time_system.handle("advance_time", {})
	return result

# --- the arrest adapter (TI-003 §14, ENC-D1..D9) ----------------------------

## Open the booking chain directly at `result`, with no decision. **Retired as
## an ENTRY path (ENC-D1) — nothing calls this any more.** Kept, unedited, as a
## RESOLUTION target: a save written before this build can already hold a
## `KIND_STICK_BOOKING` chain sitting at `result`, `booking` or `release`, and
## it has to keep loading and resolving exactly as it always did. The engine's
## own stage machine and `ArrestSystem`'s projections carry a chain from here
## on regardless of which adapter opened it, so this function needs no live
## caller to keep doing its job. See `_open_stick_caught` for the entry every
## new arrest actually takes.
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

## ENC-D3/D4: the real entry. Opened at `decision` the moment the authored
## gate says the law shows up — mirrors `boost.gd::_open_caught` seam-for-seam:
## snapshotted `shown_probabilities`, `arrest_risks` and `resolver_inputs`, so
## a reload reproduces exactly the decision the player was looking at.
##
## `contested_take: 0` and `entry_tier` on `source` are this encounter's own
## facts, not Boost's: there is no cash or merchandise in dispute (the source
## robbery already resolved its own take, or lack of one — ENC-D4), and
## `entry_tier` is read back at resolve time so a catastrophic entry's odds
## penalty (ENC-D6) is applied exactly once, from the same snapshot the shown
## odds were computed against.
func _open_stick_caught(target: Dictionary, tier_name: String, cause_id: String,
		pre_source_heat: float, _source_result: Dictionary) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var rules: RefCounted = RULES.new()
	var resolver: Object = gm.system("outcome_resolver")
	var catastrophic_entry: bool = tier_name == "catastrophic"

	var shown: Dictionary = {}
	var inputs: Dictionary = {}
	var risks: Dictionary = {}
	for choice_key in rules.CAUGHT_CHOICES:
		var choice_id := str(choice_key)
		risks[choice_id] = rules.stick_caught_arrest_risk(choice_id)
		if rules.is_deterministic(choice_id):
			continue
		var action_type: String = rules.resolver_for(choice_id)
		var attribute: String = resolver.attribute_for(action_type)
		# The RAW stored attribute, never compat() — see outcome_resolver's header.
		var raw: int = int(gs.attributes.get(attribute, 0))
		inputs[choice_id] = {"attribute": attribute, "raw": raw}
		shown[choice_id] = resolver.success_probability(action_type,
			rules.stick_caught_chance(choice_id, catastrophic_entry), raw, 0)

	return engine.open_chain(engine.KIND_STICK_CAUGHT, {
		"cause_id": cause_id,
		"district_id": gs.current_district_id,
		"return_route": "STICKUP",
		"source": {
			"family": "stick",
			"action_id": "stickup",
			"target_id": str(target["id"]),
			"target_name": str(target["name"]),
			"target_tier": int(target["tier"]),
			"source_day": int(gs.day),
			"source_slot": int(gs.time_slots_today),
			"source_rng_key": "stickup:%d:%d:%s" % [gs.day, gs.time_slots_today, str(target["id"])],
			"pre_encounter_heat": pre_source_heat,
			"contested_take": 0,
			"entry_tier": tier_name,
		},
		"decision": {
			"definition_id": "stick_caught",
			"allowed_choices": rules.CAUGHT_CHOICES.duplicate(),
			"deterministic_choices": rules.CAUGHT_DETERMINISTIC.duplicate(),
			"resolver_inputs": inputs,
			"shown_probabilities": shown,
			"arrest_risks": risks,
		},
	})

## ENC-D6's effect order, mirroring `boost.gd::resolve_consequence`: resolve
## the tier (or take Yield's authored row), injury, heat, pressure, the
## resolver's own observation, then the arrest gate — every mutating step
## behind its own receipt so a reload between two of them cannot replay one.
##
## No cooldown re-check here: `_run` already asked `ArrestSystem.in_cooldown`
## before this chain ever opened (ENC-D3), so being inside the decision means
## the law is already standing in front of the player — whether THIS answer
## ends in cuffs is a fresh question the cooldown does not reach twice.
func _resolve_caught(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var rules: RefCounted = RULES.new()
	var source: Dictionary = chain.get("source", {})
	var cause_id := str(chain.get("cause_id", ""))
	var catastrophic_entry: bool = str(source.get("entry_tier", "")) == "catastrophic"

	var tier_name: String = "deterministic"
	if not rules.is_deterministic(choice_id):
		var action_type: String = rules.resolver_for(choice_id)
		var resolver: Object = gm.system("outcome_resolver")
		var attribute: String = resolver.attribute_for(action_type)
		var raw: int = int(gs.attributes.get(attribute, 0))
		var outcome: Dictionary = resolver.resolve_action(action_type,
			rules.stick_caught_chance(choice_id, catastrophic_entry), raw,
			gs.run_seed, "consequence:%s:stick_caught:%s:outcome" % [cause_id, choice_id])
		tier_name = str(outcome["tier"])

	var result: Dictionary = {
		"choice_id": choice_id, "tier": tier_name,
		"health": 0, "heat": 0.0, "arrested": false,
	}

	# 1. Injury, on its own key.
	var band: Array = rules.stick_caught_injury_band(choice_id, tier_name)
	if band.size() == 2 and engine.record_receipt(cause_id, "stick_caught:injury"):
		var damage: int = rng.seeded_int_range(gs.run_seed,
			"consequence:%s:stick_caught:%s:injury" % [cause_id, choice_id],
			int(band[0]), int(band[1]))
		damage = _crew_absorbed(damage)
		gs.health = clampi(gs.health - damage, 0, gs.health_max)
		result["health"] = -damage

	# 2. Heat, through the one owner — raw here, HeatSystem applies Deshawn and
	#    district scaling same as every other criminal gain.
	var raw_heat: float = rules.stick_caught_raw_heat(choice_id, tier_name)
	if raw_heat > 0.0 and engine.record_receipt(cause_id, "stick_caught:heat"):
		result["heat"] = _apply_heat(raw_heat)

	# 3. District Pressure, once — the same "stick" family ledger the source
	#    robbery itself already fed, and the same PRESS-D1 daily cap: this
	#    encounter's own gain and the robbery's are two draws against one
	#    per-district-per-day room, not two separate budgets.
	var pressure: float = rules.stick_caught_pressure_gain(choice_id, tier_name)
	if pressure > 0.0 and engine.record_receipt(cause_id, "stick_caught:pressure"):
		result["pressure"] = engine.add_capped_pressure(gs.current_district_id,
			"stick", pressure, rules.PRESSURE_STICK_DAILY_CAP, cause_id)

	# 4. The resolver's own footprint for the shape that was rolled. Yield
	#    rolls nothing, so it carries none.
	if not rules.is_deterministic(choice_id) \
			and engine.record_receipt(cause_id, "stick_caught:observation"):
		var resolver_obs: Object = gm.system("outcome_resolver")
		resolver_obs.broadcast_outcome(rules.resolver_for(choice_id), tier_name,
			str(chain.get("district_id", "")))

	# 5. The arrest gate. Stick-authored, per-choice, per-tier — never the
	#    Boost table's. Yield is the deterministic surrender: no roll in, no
	#    way out of it either.
	var arrested: bool = rules.stick_caught_arrests(choice_id, tier_name)
	result["arrested"] = arrested

	var decision: Dictionary = chain.get("decision", {})
	decision["resolved_tier"] = tier_name
	decision["result"] = result
	chain["decision"] = decision

	engine.advance_stage(engine.STAGE_RESULT)
	if arrested:
		var arrest_owner: Object = gm.system("arrest") if gm != null else null
		if arrest_owner != null:
			arrest_owner.attach_booking(chain, {
				"family": "stick",
				"tier": int(source.get("target_tier", 1)),
				"target_id": str(source.get("target_id", "")),
				"cause_id": cause_id,
			})

	_caught_feed_line(choice_id, tier_name, result)
	return {"ok": true, "tier": tier_name, "arrested": arrested}

func _caught_feed_line(choice_id: String, tier_name: String, result: Dictionary) -> void:
	if choice_id == "yield":
		gs.log_activity("You put your hands up before it went any further.", AMBER)
		return
	var arrested: bool = bool(result.get("arrested", false))
	var verb: String = str({"fight": "went at", "run": "ran from", "talk": "talked to"}
		.get(choice_id, "answered"))
	if arrested:
		gs.log_activity("You %s the officer and it ends in cuffs." % verb, RED)
	elif tier_name in ["clean", "messy"]:
		gs.log_activity("You %s the officer and got clear." % verb, GREEN)
	else:
		gs.log_activity("You %s the officer, and talk was as far as it got." % verb, AMBER)

## The two-a-day cap, reset for the new day.
##
## A declared DAY_START step rather than a `day_crossed` handler, and the
## difference is the whole reason `day_lifecycle.gd` exists: a signal runs at
## whatever position in the handler list its `connect()` call happened to
## occupy, which nothing declares and nothing tests. Moving a line in
## `GameManager._ready()` used to be able to reorder this silently.
##
## It also moved LATER, from MARKET to DAY_START, and that is correct rather
## than incidental: the count is a fact about what has already happened today,
## the same shape as `heat_gain_today` and `wanders_today`, and those are
## cleared at the start of the new day rather than in the middle of the night's
## bookkeeping. Nothing between the two positions reads it.
##
## Takes the day for interface uniformity with every other step, and does not
## use it — the cap is a count, not a date.
func day_reset(_today: int) -> void:
	gs.stick_daily_count = 0

## Damage after Tone. Forwarded rather than reached for inline so both of this
## build's damage sites read identically and neither can drift.
func _crew_absorbed(raw: int) -> int:
	var crew: Object = gm.system("crew") if gm != null else null
	return raw if crew == null else int(crew.absorbed_damage(raw))

# --- the rooms (tier 2-3 confrontation loop) ---------------------------------
#
# The REPLACE ruling, wired. A tier 2-3 robbery opens a `confrontation` chain
# and plays out in authored stages: the take is rolled ONCE at entry on the
# same `:take` key the single roll always used, partitioned across stages, and
# banked stage by stage. TAKE AND GO is the guaranteed out from the first bank
# onward; a failed stage becomes the exit fork rather than a terminal row; a
# catastrophic stage ends it on the spot. Exits translate the loop's
# resolution states back into exactly the consequence vocabulary the single
# roll already speaks — heat through the one owner, retaliation scheduled on
# the cause, Curtis by tier, pressure by tier, the arrest gate against
# pre-source Heat — so everything DOWNSTREAM of a robbery is unchanged and the
# loop only decides how the money and the noise were arrived at.
#
# Stickup is its own chain adapter (`action_id: "stickup"`, already registered
# for booking chains), so `resolve_consequence` below is reached through the
# engine's existing seam and nothing new is registered anywhere.

const SCRIPTS := preload("res://data/confrontation_scripts.gd")
const LOOP := preload("res://systems/confrontation_loop.gd")

## A failed RUN WITH IT that still gets away messy costs the caught table's
## `run_messy` band — the authored precedent for "you got out, not cleanly".
const ROOM_RUN_MESSY_INJURY := [1, 5]
## And one that does not get away costs `run_failure`'s. Without this band the
## rolled run would strictly dominate the guaranteed drop — same downside plus
## upside — and a relief valve nobody should ever pull is not a choice.
const ROOM_RUN_FAILURE_INJURY := [4, 10]

func _scripts() -> RefCounted:
	return SCRIPTS.new()

func _engine() -> Object:
	return gm.system("consequence") if gm != null else null

## The engine's adapter-copy seam: the loop's vocabulary is this file's, not
## the engine's fallback table's. No branch on chain kind needed here — the
## room's own TALK/PRESS/WATCH/etc. labels are the only ones this table
## carries, and the caught encounter's fight/run/talk/yield fall through to
## the engine's own `choice_id.capitalize()` default for their LABEL exactly
## as Boost's four already do (see `boost.gd`'s comment on the same choice);
## "talk" happens to resolve to the same word either way.
func choice_label(choice_id: String) -> String:
	return _scripts().choice_label(choice_id)

## BB-D1 (0.7.0): the room's own result copy reaches the sheet through the
## adapter seam now, the same way its labels always have. The tables are
## unchanged (`STICK_RESULT_HEADLINES` / `STICK_RESULT_BODIES`); what moved is
## WHO reads them -- the sheet used to key on `KIND_CONFRONTATION`, which is
## every room in the game, and so the doorstep and the corner and Dre all
## ended in a stickup's words. The caught encounter keeps its own kind-specific
## arm in the sheet; nothing else shares that kind.
func result_headline(_choice_id: String, _tier: String, effects: Dictionary) -> String:
	if bool(effects.get("interim", false)):
		return str(SCRIPTS.STICK_INTERIM_HEADLINES.get(str(effects.get("interim_kind", "")), ""))
	return str(SCRIPTS.STICK_RESULT_HEADLINES.get(str(effects.get("resolution", "")), ""))

## An interim's body is the round's own log line where one was authored (the
## bank line names the stack and the sum); the watch and the slip carry their
## own fixed lines.
func result_body(_choice_id: String, _tier: String, effects: Dictionary) -> String:
	if bool(effects.get("interim", false)):
		var kind := str(effects.get("interim_kind", ""))
		if kind == "banked":
			var log: Array = effects.get("room_log", [])
			if not log.is_empty():
				return str(log[log.size() - 1])
		return str(SCRIPTS.STICK_INTERIM_BODIES.get(kind, ""))
	return str(SCRIPTS.STICK_RESULT_BODIES.get(str(effects.get("resolution", "")), ""))

## Unlike the label, TALK's copy genuinely differs by kind (ENC-D7: the caught
## encounter's TALK is to the responding officer, not the mark), so this one
## does branch — on the ACTIVE chain, the same fact `_is_caught_active` reads
## for `choice_guarantee` below.
func choice_copy(choice_id: String) -> String:
	if _is_caught_active():
		return str(SCRIPTS.STICK_CAUGHT_CHOICE_COPY.get(choice_id, ""))
	return _scripts().choice_copy(choice_id)

## ENC-D6: Stick Caught's YIELD is a guaranteed SURRENDER — it books,
## deliberately — so the screen's own "no injury, no Heat, no arrest" default
## would be a lie for this one choice. See `ConsequenceEngine.choice_guarantee`
## for why this seam exists at all.
func choice_guarantee(choice_id: String) -> String:
	if choice_id == "yield" and _is_caught_active():
		return "Guaranteed: no injury, no Heat. Straight to cuffs."
	return ""

func _is_caught_active() -> bool:
	var engine: Object = _engine()
	return engine != null \
		and str(gs.active_consequence.get("chain_kind", "")) == engine.KIND_STICK_CAUGHT

## Open the room. The chain owes the robbery's one slot (settled on Continue),
## and NOTHING is counted yet: attempts and the daily cap move on the first
## committed action, so WALK at the door costs exactly what it says — nothing.
func _open_room(t: Dictionary, pre_source_heat: float) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	if engine.has_active():
		return {"ok": false, "reason": "Deal with what is in front of you."}
	var scripts: RefCounted = _scripts()
	var target_id := str(t["id"])
	var script: Dictionary = scripts.script_for(target_id)
	var tier: int = int(t["tier"])
	var key := "stickup:%d:%d:%s" % [gs.day, gs.time_slots_today, target_id]

	# One realised take for the whole room, on the key the single roll always
	# used — the band is the budget, the stages only partition it. The tip
	# multiplier (fat night) scales the realised roll before partition and is
	# a no-op until the tip system lands.
	var band: Array = t["take"]
	var tips: Dictionary = LOOP.tip_modifiers_for(gs, target_id, tier)
	var take: int = rng.seeded_int_range(gs.run_seed, key + ":take",
		int(band[0]), int(band[1]))
	take = maxi(1, int(round(float(take) * float(tips["take_multiplier"]))))
	var pots: Array = scripts.stage_pots(take, tier)

	var opening: Dictionary = scripts.beat(script, 0)
	var loop: Dictionary = {
		"script_id": target_id,
		"sheet_title": str(script.get("sheet_title", "")),
		"left_label": str(script.get("left_label", "IN YOUR WAY")),
		"left": int(script.get("left", 1)) + int(tips["extra_left"]),
		"stage": 0,
		"stage_count": scripts.stage_count(script),
		"pots": pots,
		"take_total": take,
		"banked": 0,
		"burned": [],
		"log": [],
		"watched": false,
		"started": false,
		"all_clean": true,
		"mode": "stage",
		"beat": str(opening.get("enter", "")),
		"tip_no_decay": bool(tips["remove_final_decay"]),
	}
	var actions: Dictionary = _room_stage_actions(script, loop)

	return engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": gs.current_district_id,
		"return_route": "STICKUP",
		"source": {
			"family": "stick",
			"action_id": "stickup",
			"target_id": target_id,
			"target_name": str(t["name"]),
			"target_tier": tier,
			"opponent": str(script.get("opponent", "")),
			"source_day": int(gs.day),
			"source_slot": int(gs.time_slots_today),
			"source_rng_key": key,
			"pre_encounter_heat": pre_source_heat,
			"contested_take": take,
		},
		"decision": {
			"definition_id": "stick_room",
			"allowed_choices": actions["allowed"],
			"deterministic_choices": actions["deterministic"],
			"shown_probabilities": _room_shown(t, script, loop, actions["allowed"]),
			"loop": loop,
		},
	})

## The stage's action set. Exactly one guaranteed out per round by
## construction: WALK before anything is committed, TAKE AND GO from then on.
## WATCH never appears on the last stage — there is no next move to buy.
func _room_stage_actions(script: Dictionary, loop: Dictionary) -> Dictionary:
	var allowed: Array = ["press"]
	if bool(script.get("talk", false)):
		allowed.append("talk")
	var last: bool = int(loop["stage"]) >= int(loop["stage_count"]) - 1
	if not last:
		allowed.append("watch")
	if not bool(loop.get("started", false)):
		allowed.append("walk")
	else:
		allowed.append("take_and_go")
	allowed = LOOP.without_burned(loop, allowed)
	var deterministic: Array = []
	for out in ["watch", "walk", "take_and_go"]:
		if out in allowed:
			deterministic.append(out)
	return {"allowed": allowed, "deterministic": deterministic}

## One stage's chance for one rolled verb. PRESS reads `chance_for()` live —
## combat, heat, resistance and Pressure exactly as the single roll would —
## and TALK reads its authored crowd base; both take the stage delta and the
## watched bonus, re-clamped to the same [0.15, 0.90] floor and ceiling.
func _room_chance(t: Dictionary, script: Dictionary, loop: Dictionary,
		choice_id: String) -> float:
	var scripts: RefCounted = _scripts()
	var stage: int = int(loop["stage"])
	var base: float = SCRIPTS.STICK_TALK_BASE if choice_id == "talk" else chance_for(t)
	var mod: float = scripts.stage_mod(script, stage)
	if bool(loop.get("tip_no_decay", false)) \
			and stage == int(loop["stage_count"]) - 1 and mod < 0.0:
		mod = 0.0
	if bool(loop.get("watched", false)):
		mod += SCRIPTS.WATCH_BONUS
	return clampf(base + mod, 0.15, 0.90)

## Snapshotted odds for every rolled verb on offer — the same
## `success_probability` read every other decision snapshot uses, so a reload
## re-renders the numbers the player actually saw.
func _room_shown(t: Dictionary, script: Dictionary, loop: Dictionary,
		allowed: Array) -> Dictionary:
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	if resolver == null:
		return {}
	var shown: Dictionary = {}
	for entry in allowed:
		var choice_id := str(entry)
		match choice_id:
			"press":
				shown[choice_id] = resolver.success_probability("robbery",
					_room_chance(t, script, loop, choice_id),
					attributes.effective("combat"), 0)
			"talk":
				shown[choice_id] = resolver.success_probability("negotiation",
					_room_chance(t, script, loop, choice_id),
					attributes.effective("charisma"), 0)
			"run_with_it":
				shown[choice_id] = resolver.success_probability("escape",
					SCRIPTS.STICK_FORK_RUN_BASE,
					attributes.effective("combat"), 0)
	return shown

## The engine's resolution seam. Called once per committed round; the receipt
## that guards the commit is the engine's, keyed on `decision.round`.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var kind := str(chain.get("chain_kind", ""))
	if kind == engine.KIND_STICK_CAUGHT:
		return _resolve_caught(chain, choice_id)
	if kind != engine.KIND_CONFRONTATION:
		return {"ok": false, "reason": "Not a moment this system owns."}
	var loop: Dictionary = LOOP.loop_of(chain)
	if loop.is_empty():
		return {"ok": false, "reason": "The room is already empty."}
	var source: Dictionary = chain.get("source", {})
	var t: Dictionary = gs.stick_target_by_id(str(source.get("target_id", "")))
	var script: Dictionary = _scripts().script_for(str(source.get("target_id", "")))
	if t.is_empty() or script.is_empty():
		return {"ok": false, "reason": "That room is gone."}

	if str(loop.get("mode", "stage")) == "fork":
		return _room_fork(chain, loop, t, choice_id)
	return _room_stage(chain, loop, t, script, choice_id)

## One stage round. Success banks and advances (or wins on the last stage), a
## plain failure becomes the exit fork, a catastrophe ends it here.
func _room_stage(chain: Dictionary, loop: Dictionary, t: Dictionary,
		script: Dictionary, choice_id: String) -> Dictionary:
	var scripts: RefCounted = _scripts()

	# WALK — the free abort, before anything has been committed. The chain
	# closes with its slot released: looking at a room costs nothing, which is
	# the same price looking at the target card always had.
	if choice_id == "walk":
		var time_block: Dictionary = chain.get("time", {})
		time_block["source_slots_remaining"] = 0
		chain["time"] = time_block
		var engine: Object = _engine()
		engine.clear_chain()
		gs.log_activity("You look at %s for a while and keep walking." % str(t["name"]), AMBER)
		return {"ok": true, "walked": true}

	# The first committed action is when the attempt becomes real: the counter
	# and the daily cap move here, not at the door.
	if not bool(loop.get("started", false)):
		loop["started"] = true
		gs.stick_attempts += 1
		gs.stick_daily_count += 1

	var stage: int = int(loop["stage"])
	var last: bool = stage >= int(loop["stage_count"]) - 1

	# TAKE AND GO — the guaranteed out once anything is banked. Deterministic:
	# what is in the jacket leaves with you, priced only in the noise the
	# banked fraction makes.
	if choice_id == "take_and_go":
		return _room_exit(chain, loop, t, SCRIPTS.RESOLUTION_ESCAPED,
			"messy" if int(loop["banked"]) > 0 else "failure", {})

	# WATCH THE ROOM — deterministic: this stage's stack stays on the table,
	# the next stage comes easier and hurts less if it goes wrong.
	if choice_id == "watch":
		loop["watched"] = true
		LOOP.append_log(loop, "You let the stack sit and count the room instead.")
		# BB-D4 (0.7.0): the round has a result before the next stage.
		return LOOP.present_interim(_engine(), gs, chain, loop, choice_id,
			"deterministic", "watched", {}, stage + 1)

	# PRESS or TALK — the rolled verbs. One keyed roll per stage per verb.
	var action_type: String = "negotiation" if choice_id == "talk" else "robbery"
	var attribute: String = "charisma" if choice_id == "talk" else "combat"
	var resolver: Object = gm.system("outcome_resolver")
	var key := "%s:stage:%d:%s" % [str(chain["source"]["source_rng_key"]), stage, choice_id]
	var outcome: Dictionary = resolver.resolve_action(action_type,
		_room_chance(t, script, loop, choice_id), attributes.effective(attribute),
		gs.run_seed, key)
	var tier := str(outcome["tier"])

	if resolver.is_success_tier(tier):
		var pot: int = int((loop["pots"] as Array)[stage])
		loop["banked"] = int(loop["banked"]) + pot
		if tier != "clean":
			loop["all_clean"] = false
		# The count going down is somebody stepping off, and it is authored:
		# a clean PRESS backs one off; TALK working backs one off regardless,
		# because that is the whole point of talking.
		if choice_id == "talk" or tier == "clean":
			loop["left"] = maxi(0, int(loop["left"]) - 1)
		# WATCH's bonus is spent by the stage it bought.
		loop["watched"] = false
		var bank_line := str(scripts.beat(script, stage).get("bank_log", ""))
		if not bank_line.is_empty():
			LOOP.append_log(loop, bank_line % pot)
		if last:
			return _room_exit(chain, loop, t, SCRIPTS.RESOLUTION_WON,
				"clean" if bool(loop["all_clean"]) else "messy", {})
		# BB-D4: the stack that just banked is a result the player reads
		# before the next stage is on the table.
		return LOOP.present_interim(_engine(), gs, chain, loop, choice_id, tier,
			"banked", {}, stage + 1)

	if tier == "catastrophic":
		return _room_exit(chain, loop, t, SCRIPTS.RESOLUTION_BEATEN,
			"catastrophic", {})

	# Plain failure: the verb is burned and the situation changes — the fork is
	# the new round, with its own out. The room is no longer yours; the
	# question is what happens to the jacket.
	LOOP.burn(loop, choice_id)
	loop["watched"] = false
	LOOP.append_log(loop, "It slips.")
	# BB-D4: the slip is a result the player reads; CONTINUE presents the fork.
	return LOOP.present_interim(_engine(), gs, chain, loop, choice_id, tier,
		"slipped", {}, "fork")

## The fork, on the table. Split out of `_room_stage` so `present_next_round`
## can reach it the same way the slip itself used to.
func _present_fork(chain: Dictionary, loop: Dictionary, t: Dictionary,
		script: Dictionary) -> Dictionary:
	loop["mode"] = "fork"
	loop["beat"] = SCRIPTS.STICK_FORK_BEAT
	var allowed: Array = ["run_with_it", "drop_and_run"]
	LOOP.present_round(chain, loop, allowed, ["drop_and_run"],
		_room_shown(t, script, loop, allowed))
	return {"ok": true, "forked": true}

## BB-D4: the engine's `_continue` hands an interim chain back here. The
## loop's own note says what comes next: a stage number, or the fork.
func present_next_round(chain: Dictionary) -> Dictionary:
	var loop: Dictionary = LOOP.loop_of(chain)
	var pending: Variant = LOOP.take_pending(loop)
	if loop.is_empty() or pending == null:
		return {"ok": false, "reason": "Nothing to move on to."}
	var source: Dictionary = chain.get("source", {})
	var t: Dictionary = gs.stick_target_by_id(str(source.get("target_id", "")))
	var script: Dictionary = _scripts().script_for(str(source.get("target_id", "")))
	if t.is_empty() or script.is_empty():
		return {"ok": false, "reason": "That room is gone."}
	if str(pending) == "fork":
		return _present_fork(chain, loop, t, script)
	return _room_advance(chain, loop, t, script, int(pending))

## Advance the loop to the next stage: new beat, new action set, new odds, new
## round receipt.
func _room_advance(chain: Dictionary, loop: Dictionary, t: Dictionary,
		script: Dictionary, next_stage: int) -> Dictionary:
	loop["stage"] = next_stage
	loop["mode"] = "stage"
	loop["beat"] = str(_scripts().beat(script, next_stage).get("enter", ""))
	var actions: Dictionary = _room_stage_actions(script, loop)
	LOOP.present_round(chain, loop, actions["allowed"], actions["deterministic"],
		_room_shown(t, script, loop, actions["allowed"]))
	return {"ok": true, "stage": next_stage}

## The exit fork after a slipped stage. DROP IT AND RUN is the guaranteed out;
## RUN WITH IT rolls `escape` — Combat, because mid-robbery the problem is the
## grip, not the map.
func _room_fork(chain: Dictionary, loop: Dictionary, t: Dictionary,
		choice_id: String) -> Dictionary:
	if choice_id == "drop_and_run":
		return _room_exit(chain, loop, t, SCRIPTS.RESOLUTION_SURRENDERED,
			"failure", {})
	var resolver: Object = gm.system("outcome_resolver")
	var stage: int = int(loop["stage"])
	var key := "%s:stage:%d:%s" % [str(chain["source"]["source_rng_key"]), stage, choice_id]
	var outcome: Dictionary = resolver.resolve_action("escape",
		SCRIPTS.STICK_FORK_RUN_BASE, attributes.effective("combat"), gs.run_seed, key)
	var tier := str(outcome["tier"])
	if resolver.is_success_tier(tier):
		var spec: Dictionary = {}
		if tier == "messy":
			spec["injury_band"] = ROOM_RUN_MESSY_INJURY
		return _room_exit(chain, loop, t, SCRIPTS.RESOLUTION_ESCAPED, "messy", spec)
	if tier == "catastrophic":
		return _room_exit(chain, loop, t, SCRIPTS.RESOLUTION_BEATEN, "catastrophic", {})
	return _room_exit(chain, loop, t, SCRIPTS.RESOLUTION_BEATEN, "failure",
		{"injury_band": ROOM_RUN_FAILURE_INJURY})

## Every way out of a room lands here — ONE translation from the loop's
## resolution state into the consequence vocabulary the single roll already
## speaks, so the two paths cannot drift on what a robbery costs.
##
## `tier_equiv` is the tier the downstream systems are told: it drives heat
## shape, Curtis's read, the Exposure footprint, District Pressure and the
## retaliation schedule through exactly the tables the single roll uses.
func _room_exit(chain: Dictionary, loop: Dictionary, t: Dictionary,
		resolution: String, tier_equiv: String, spec: Dictionary) -> Dictionary:
	var engine: Object = _engine()
	var cause_id := str(chain.get("cause_id", ""))
	var source: Dictionary = chain.get("source", {})
	var banked: int = int(loop.get("banked", 0))
	var keeps: bool = resolution in [SCRIPTS.RESOLUTION_WON, SCRIPTS.RESOLUTION_ESCAPED]
	var credited: int = 0

	# 1. The money, exactly once.
	if keeps and banked > 0 and engine.record_receipt(cause_id, "room:cash"):
		_wallet().credit(banked, _wallet().DIRTY, {"source_id": "stickup_take"})
		gs.record_earning("stick", banked)
		credited = banked

	# 2. Rep. A room run end to end always counts; a partial counts when it
	# mostly came off — half a take you walked out with is a job that worked.
	if resolution == SCRIPTS.RESOLUTION_WON \
			or (keeps and LOOP.banked_fraction(loop) >= SCRIPTS.STICK_REP_FRACTION):
		if engine.record_receipt(cause_id, "room:rep"):
			gs.stick_rep += 1
			gs.stick_successes += 1
			_update_tier()
			# Canon: from the second organised (tier-3) job, Curtis is told
			# directly over the network — same wire as the single roll.
			if int(t["tier"]) == 3:
				gs.stick_organized_hits += 1
				if gs.stick_organized_hits >= 2:
					var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
					if exposure != null:
						exposure.record_observation("curtis", {
							"type": "violence", "event": "organized_hit",
							"count": gs.stick_organized_hits, "source": "network",
						})

	# 3. The noise. Scaled by how much of the room actually left with you —
	# the "clean take is half the heat" rule generalised to partial takes —
	# and the single roll's own shapes at the extremes.
	var raw_heat: float
	match tier_equiv:
		"clean":
			raw_heat = float(t["heat"]) * 0.5
		"messy":
			raw_heat = maxf(SCRIPTS.STICK_HEAT_FLOOR,
				float(t["heat"]) * LOOP.banked_fraction(loop)) \
				if resolution == SCRIPTS.RESOLUTION_ESCAPED else float(t["heat"])
		"catastrophic":
			raw_heat = float(t["heat"]) * 1.5
		_:
			raw_heat = float(maxi(1, int(t["heat"]) - 1))
	var applied: float = 0.0
	if engine.record_receipt(cause_id, "room:heat"):
		applied = _apply_heat(raw_heat)

	# 4. Injury, keyed and Tone-absorbed. Catastrophic rooms hurt like
	# catastrophic robberies; a messy escape costs the caught table's
	# `run_messy` band; everything else walks out whole.
	var damage: int = 0
	var band: Array = spec.get("injury_band",
		INJURY_BANDS.get(tier_equiv, []) if tier_equiv == "catastrophic" else [])
	if band.size() == 2 and engine.record_receipt(cause_id, "room:injury"):
		damage = rng.seeded_int_range(gs.run_seed,
			str(source.get("source_rng_key", "")) + ":room:injury",
			int(band[0]), int(band[1]))
		damage = _crew_absorbed(damage)
		gs.health = clampi(gs.health - damage, 0, gs.health_max)

	# 5. What Curtis makes of it and what the block saw — the single roll's
	# own tables, fed the equivalent tier.
	var curtis: Node = _curtis()
	if curtis != null and engine.record_receipt(cause_id, "room:curtis"):
		var reads: Dictionary = CURTIS_BY_TIER.get(tier_equiv, CURTIS_BY_TIER["failure"])
		curtis.raise_awareness(int(reads["awareness"]))
		if bool(reads["criminal"]):
			curtis.mark_criminal_activity()
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	if resolver != null and engine.record_receipt(cause_id, "room:observation"):
		resolver.broadcast_outcome("robbery", tier_equiv, gs.current_district_id,
			credited if credited > 0 else null)

	# 6. District Pressure by the same tiered gains, and the clean credit when
	# it was clean. PRESS-D1: the same per-district-per-day "stick" room this
	# tier's other two gain sources draw from, not a separate budget.
	var rules: RefCounted = RULES.new()
	var pressure_gain: float = float(rules.PRESSURE_BY_TIER.get(tier_equiv, 0.0))
	var pressure_applied: float = 0.0
	if pressure_gain > 0.0 and engine.record_receipt(cause_id, "room:pressure"):
		pressure_applied = engine.add_capped_pressure(gs.current_district_id,
			"stick", pressure_gain, rules.PRESSURE_STICK_DAILY_CAP, cause_id)
	if engine.record_receipt(cause_id, "room:clean_credit"):
		engine.credit_clean_outcome(gs.current_district_id, "stick", tier_equiv)

	# 7. The delayed answer, on the chain's own cause. The queue dedupes on
	# (actor, cause), so this cannot double-schedule across a reload.
	var retaliation: Object = gm.system("retaliation") if gm != null else null
	if retaliation != null:
		retaliation.schedule(str(t["id"]), tier_equiv, cause_id, gs.current_district_id)

	# 8. The arrest gate — beaten exits only, against the PRE-SOURCE snapshot,
	# with the same cooldown suppression the single roll applies.
	var arrested: bool = false
	if resolution == SCRIPTS.RESOLUTION_BEATEN:
		arrested = rules.stick_arrests(int(t["tier"]), tier_equiv,
			float(source.get("pre_encounter_heat", 0.0)))
		var arrest_owner: Object = gm.system("arrest") if gm != null else null
		if arrested and arrest_owner != null and arrest_owner.in_cooldown(int(gs.day)):
			arrested = false
		if arrested and arrest_owner != null:
			arrest_owner.attach_booking(gs.active_consequence, {
				"family": "stick",
				"tier": int(t["tier"]),
				"target_id": str(t["id"]),
				"cause_id": cause_id,
			})

	# 9. The result the scene renders: exact, signed, and carrying the
	# resolution state the headlines key on.
	var decision: Dictionary = chain.get("decision", {})
	decision["resolved_tier"] = tier_equiv
	decision["result"] = {
		"resolution": resolution,
		"cash": credited,
		"health": -damage,
		"heat": applied,
		"pressure": pressure_applied,
		"arrested": arrested,
		"banked": banked,
		"target_name": str(t["name"]),
	}
	decision["loop"] = loop
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)

	_room_feed_line(t, resolution, credited, applied, damage)
	return {"ok": true, "resolution": resolution, "tier": tier_equiv,
		"cash": credited, "arrested": arrested}

func _room_feed_line(t: Dictionary, resolution: String, credited: int,
		applied: float, damage: int) -> void:
	var name := str(t["name"])
	match resolution:
		SCRIPTS.RESOLUTION_WON:
			gs.log_activity("%s comes off end to end. +$%d, heat +%.1f."
				% [name, credited, applied], GREEN)
		SCRIPTS.RESOLUTION_ESCAPED:
			if credited > 0:
				gs.log_activity("You take $%d off %s and leave the rest sitting."
					% [credited, name], AMBER)
			else:
				# Watched, banked nothing, left — an hour of casing that never
				# became a robbery, and the room still noticed somebody was in it.
				gs.log_activity("You read %s for a while and let it be." % name, AMBER)
		SCRIPTS.RESOLUTION_SURRENDERED:
			gs.log_activity("You drop the take at %s and buy the door." % name, AMBER)
		_:
			gs.log_activity("%s comes apart. Heat +%.1f, -%d health, nothing kept."
				% [name, applied, damage], RED)

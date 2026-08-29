extends Node
## The confrontation-loop gate suite — the rooms, driven end to end.
##
## Shares `tests/territory/territory_asserts.gd` for the same reason that file
## gives: this is the port's own rule set, not oracle truth, and it belongs in
## a harness that answers in seconds. The parity runner's stickup coverage is
## deliberately untouched by the feature this suite guards — tier 1 keeps the
## shipped single-roll path byte-for-byte, and check block 2 below is the
## regression tripwire that keeps that sentence true.
##
## ## How outcomes are found
##
## The parity runner's `_find_stickup_day` pattern: the per-stage rolls are
## keyed on day, slot, stage and choice, so walking the day is walking the
## seed. Days are found by PURE simulation (the same resolver call the live
## path makes, on the same key), then only the found day is driven through the
## real dispatch — the suite proves the dispatch agrees with the simulation,
## which is exactly the determinism contract, and it keeps the autosave count
## in the dozens rather than the thousands.
##
## ## What is deliberately asserted with the multiplier baked in
##
## Heat expectations write Spenard's 1.3 stick multiplier into the literal,
## the same way the parity runner's `STICKUP_EXPECTED` table does and for the
## same reason: the number a check asserts should be the number a player would
## see, not a re-derivation from the constant the code reads.

const ASSERTS := preload("res://tests/territory/territory_asserts.gd")
const SCRIPTS := preload("res://data/confrontation_scripts.gd")
const LOOP := preload("res://systems/confrontation_loop.gd")

## The check floor: a suite that returned early is a suite that failed.
## Updated whenever checks are added; the report call enforces it.
## 0.1.2: +40 for the Lift's caught-loop escalation + BRIBE (check block 10),
## +13 for the HAND IT BACK guaranteed-out follow-up.
## 0.3.0 (ENC-D1..D9): +38 for the stick-caught decision (check block 11) —
## hot/cold/catastrophic entry, yield's deterministic booking, cooldown
## suppression, and ENC-D9's source-time contract.
## 0.3.0 (STK-D1): +1 — `_check_authored_tables`'s own target-iteration loop
## picked up the new tier-1 Spenard target automatically; no code changed,
## the check floor still has to move with what the loop now covers.
## 0.6.0 (SQ-D1..D5, PR A): +35 for check block 14 — the route ladder's stage
## split in both directions, the shared builder's single ownership of the
## chain's copy, the duplicated palette asserted equal, and the blocking
## sheet's two removed dismissal gestures.
const MIN_CHECKS := 286

## The tier-2 probe room: Spenard, night slot, resistance 1, take [100, 180].
const T2_TARGET := "spenard_fuel_till"
## The tier-3 probe room: Spenard, evening slot works, three stages, talk.
const T3_TARGET := "rec_center_dice"

var a: RefCounted
var gs: Node
var gm: Node
var rng: Node

func _ready() -> void:
	a = ASSERTS.new()
	gs = get_node("/root/GameState")
	gm = get_node("/root/GameManager")
	rng = get_node("/root/RngManager")

	_check_authored_tables()
	_check_tier1_untouched()
	_check_room_opens_and_walks()
	_check_full_win_t2()
	_check_take_and_go()
	_check_fork_and_drop()
	_check_catastrophic_booking()
	_check_watch_and_talk()
	_check_reload_shape()
	_check_lift_escalation()
	_check_lift_bribe()
	_check_lift_hand_it_back()
	_check_stick_caught()
	_check_encounter_overlay()

	a.report("confrontation", get_tree(), MIN_CHECKS)

# --- probe setup -------------------------------------------------------------

## Spenard, night, cold, alone, tier ladder open. Combat 1 keeps every resolver
## tier reachable — below advantage, well below catastrophe immunity.
func _reset_probe(slot: int = 3) -> void:
	gs.reset_to_new_game()
	gs.current_district_id = "north_star_lot"
	gs.time_slots_today = slot
	gs.time_slot = ["MORNING", "AFTERNOON", "EVENING", "NIGHT"][slot]
	gs.heat = 0.0
	gs.attributes = {"combat": 1, "charisma": 1, "intelligence": 1}
	gs.stick_tier = 3
	gs.stick_daily_count = 0

## The pure half of the determinism contract: the stage tier this day/stage/
## choice WILL produce, computed off the same chance and the same key the live
## path uses.
func _stage_tier(day: int, slot: int, target_id: String, stage: int,
		choice: String, watched: bool = false) -> String:
	var stickup: RefCounted = gm.system("stickup") as RefCounted
	var resolver: RefCounted = gm.system("outcome_resolver") as RefCounted
	var t: Dictionary = gs.stick_target_by_id(target_id)
	var script: Dictionary = SCRIPTS.new().script_for(target_id)
	var loop := {"stage": stage, "stage_count": SCRIPTS.new().stage_count(script),
		"watched": watched, "tip_no_decay": false}
	var action_type := "negotiation" if choice == "talk" else "robbery"
	var attribute := "charisma" if choice == "talk" else "combat"
	var chance: float = stickup._room_chance(t, script, loop, choice)
	var key := "stickup:%d:%d:%s:stage:%d:%s" % [day, slot, target_id, stage, choice]
	var attributes: RefCounted = gm.system("attributes") as RefCounted
	return str(resolver.resolve_action(action_type, chance,
		attributes.effective(attribute), gs.run_seed, key)["tier"])

func _success(tier: String) -> bool:
	return tier in ["clean", "messy"]

## First day whose stage-tier sequence matches `wanted` per stage (empty string
## matches anything). Scans the same window the parity runner uses.
##
## Resets the probe FIRST: `chance_for()` reads live Heat and Pressure, and a
## scan computed against whatever the previous check left on the meters would
## find days the driven probe then disagrees with — the exact flake this
## suite exists to rule out.
func _find_day(slot: int, target_id: String, wanted: Array) -> int:
	_reset_probe(slot)
	for day in range(1, 400):
		var hit := true
		for stage in range(wanted.size()):
			var want := str(wanted[stage])
			if want.is_empty():
				continue
			var tier := _stage_tier(day, slot, target_id, stage, "press")
			var matched: bool
			match want:
				"success": matched = _success(tier)
				"failure": matched = tier == "failure"
				"catastrophic": matched = tier == "catastrophic"
				_: matched = tier == want
			if not matched:
				hit = false
				break
		if hit:
			return day
	return -1

func _engine() -> Object:
	return gm.system("consequence")

func _commit(choice_id: String) -> bool:
	return gm.dispatch("resolve_consequence_choice", {"choice_id": choice_id})

## Continue past a settled room without letting the retaliation the exit just
## scheduled surface into the next check's assertions — the queue is cleared
## because the answer is another check's subject, not this one's.
func _close_out() -> void:
	gs.consequence_queue = []
	gm.dispatch("consequence_continue", {})

## The chassis invariant, asserted at every presented round: at least one
## guaranteed out, and every declared out actually on offer.
func _assert_guaranteed_out(label: String) -> void:
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	var deterministic: Array = decision.get("deterministic_choices", [])
	var allowed: Array = decision.get("allowed_choices", [])
	a.check("%s: a guaranteed out exists" % label, not deterministic.is_empty())
	for out in deterministic:
		a.check("%s: out '%s' is on offer" % [label, str(out)], str(out) in allowed)

# --- 1. the authored tables --------------------------------------------------

func _check_authored_tables() -> void:
	var scripts: RefCounted = SCRIPTS.new()

	# Tier boundary: every tier 2-3 target has a room, no tier 1 target does.
	for target in gs.stick_targets:
		var t: Dictionary = target
		var id := str(t["id"])
		if int(t["tier"]) >= 2:
			a.check("room exists for %s" % id, scripts.has_room(t))
		else:
			a.eq_bool("no room for tier-1 %s" % id, scripts.has_room(t), false)

	# Script shape: beats, mods and the partition all agree on the stage count,
	# and nothing exceeds the round cap.
	for target_id in SCRIPTS.STICK_SCRIPTS.keys():
		var script: Dictionary = scripts.script_for(str(target_id))
		var t: Dictionary = gs.stick_target_by_id(str(target_id))
		var count: int = scripts.stage_count(script)
		var tier: int = int(t.get("tier", 0))
		a.check("%s stage count within cap" % target_id,
			count >= 1 and count <= SCRIPTS.ROUND_CAP)
		a.eq_int("%s stages match tier partition" % target_id,
			count, (SCRIPTS.STICK_PARTITION[tier] as Array).size())
		a.eq_int("%s stage mods cover stages" % target_id,
			(script.get("stage_mods", []) as Array).size(), count)
		for stage in range(count):
			a.check("%s stage %d has beat copy" % [target_id, stage],
				not str(scripts.beat(script, stage).get("enter", "")).is_empty())

	# The partition is exact: the parts always sum to the whole, across bands.
	for take in [1, 30, 101, 157, 180, 500, 933, 1200, 1500]:
		for tier in [2, 3]:
			var pots: Array = scripts.stage_pots(take, tier)
			var total := 0
			for pot in pots:
				total += int(pot)
			a.eq_int("partition sums (take %d tier %d)" % [take, tier], total, take)

	# Every loop verb has a label and a line.
	for choice_id in SCRIPTS.STICK_CHOICE_LABELS.keys():
		a.check("label for %s" % choice_id,
			not scripts.choice_label(str(choice_id)).is_empty())
		a.check("copy for %s" % choice_id,
			not scripts.choice_copy(str(choice_id)).is_empty())

	# The authored-not-wired tables hold their shape for the slices that trust
	# them: the Lift's three tiers of beats, the bribe rows, the market and
	# meetup scripts, the tip table.
	for tier in [1, 2, 3]:
		a.check("lift beats authored for tier %d" % tier,
			(SCRIPTS.LIFT_BEATS[tier] as Array).size() >= 2)
	a.check("bribe skips tier 3", not 3 in (SCRIPTS.LIFT_BRIBE["tiers"] as Array))
	a.eq_int("bribe is once per store",
		int(SCRIPTS.LIFT_BRIBE["per_store_limit"]), 1)
	a.check("market scripts authored",
		SCRIPTS.MARKET_SCRIPTS.has("corner_stiff") and SCRIPTS.MARKET_SCRIPTS.has("corner_push"))
	a.check("meetup scene capped for mobile",
		int(SCRIPTS.MEETUP_SCRIPT["cap"]) <= SCRIPTS.ROUND_CAP)
	a.check("tip table names the meetup suppression",
		bool((SCRIPTS.TIP_MODIFIERS["buyer_confirmed"] as Dictionary)["suppress_meetup_scene"]))

# --- 2. tier 1 is byte-for-byte the single roll ------------------------------

func _check_tier1_untouched() -> void:
	# A CLEAN day, scanned the way the parity runner scans its own probe: a
	# catastrophic tier-1 day legitimately opens a booking chain and would make
	# "opens no chain" assert the wrong thing.
	_reset_probe(0)
	var stickup: RefCounted = gm.system("stickup") as RefCounted
	var resolver: RefCounted = gm.system("outcome_resolver") as RefCounted
	var attrs: RefCounted = gm.system("attributes") as RefCounted
	var t: Dictionary = gs.stick_target_by_id("washgo_regular")
	var clean_day: int = -1
	for day in range(1, 400):
		var outcome: Dictionary = resolver.resolve_action("robbery",
			stickup.chance_for(t), attrs.effective("combat"), gs.run_seed,
			"stickup:%d:0:washgo_regular" % day)
		if str(outcome["tier"]) == "clean":
			clean_day = day
			break
	a.check("a clean tier-1 day exists", clean_day > 0)
	if clean_day <= 0:
		return
	_reset_probe(0)
	gs.day = clean_day
	var attempts_before: int = gs.stick_attempts
	a.check("tier-1 dispatch resolves", gm.dispatch("stickup", {"target_id": "washgo_regular"}))
	a.eq_bool("tier 1 opens no chain", _engine().has_active(), false)
	a.eq_int("tier 1 counts the attempt immediately", gs.stick_attempts, attempts_before + 1)
	a.eq_int("tier 1 spends its slot inline", gs.time_slots_today, 1)

# --- 3. the door -------------------------------------------------------------

func _check_room_opens_and_walks() -> void:
	_reset_probe(3)
	gs.day = 5
	a.check("room dispatch accepted", gm.dispatch("stickup", {"target_id": T2_TARGET}))
	a.eq_bool("a chain is open", _engine().has_active(), true)
	a.eq_str("chain kind", str(gs.active_consequence.get("chain_kind", "")), "confrontation")
	a.eq_int("nothing counted at the door", gs.stick_attempts, 0)
	a.eq_int("daily cap untouched at the door", gs.stick_daily_count, 0)
	a.eq_int("no slot spent at the door", gs.time_slots_today, 3)
	var loop: Dictionary = LOOP.loop_of(gs.active_consequence)
	a.eq_int("loop opens at stage 0", int(loop.get("stage", -1)), 0)
	a.eq_int("tier-2 room has two stages", int(loop.get("stage_count", 0)), 2)
	a.check("the beat is authored copy", not str(loop.get("beat", "")).is_empty())
	_assert_guaranteed_out("at the door")

	# WALK: free in every currency — no chain, no attempt, no cap, no slot.
	a.check("walk resolves", _commit("walk"))
	a.eq_bool("walk closes the chain", _engine().has_active(), false)
	a.eq_int("walk counts nothing", gs.stick_attempts, 0)
	a.eq_int("walk spends no cap", gs.stick_daily_count, 0)
	a.eq_int("walk spends no slot", gs.time_slots_today, 3)

# --- 4. the full tier-2 win --------------------------------------------------

func _check_full_win_t2() -> void:
	var day: int = _find_day(3, T2_TARGET, ["success", "success"])
	a.check("a two-stage win day exists in the scan window", day > 0)
	if day <= 0:
		return
	_reset_probe(3)
	gs.day = day
	var t: Dictionary = gs.stick_target_by_id(T2_TARGET)
	var band: Array = t["take"]
	var expected_take: int = rng.seeded_int_range(gs.run_seed,
		"stickup:%d:3:%s:take" % [day, T2_TARGET], int(band[0]), int(band[1]))
	var cash_before: int = gs.cash

	gm.dispatch("stickup", {"target_id": T2_TARGET})
	var loop: Dictionary = LOOP.loop_of(gs.active_consequence)
	a.eq_int("realised take rides the entry :take key",
		int(loop.get("take_total", 0)), expected_take)

	a.check("stage 1 press commits", _commit("press"))
	loop = LOOP.loop_of(gs.active_consequence)
	a.eq_int("first commit starts the attempt", gs.stick_attempts, 1)
	a.eq_int("first commit spends the daily cap", gs.stick_daily_count, 1)
	a.eq_int("stage advanced", int(loop.get("stage", -1)), 1)
	var pots: Array = loop.get("pots", [])
	a.eq_int("stage one banked its pot", int(loop.get("banked", 0)), int(pots[0]))
	a.check("the log remembers the bank", not (loop.get("log", []) as Array).is_empty())
	a.eq_int("round bumped for the next receipt",
		int((gs.active_consequence["decision"] as Dictionary).get("round", -1)), 1)
	_assert_guaranteed_out("mid-room")
	a.check("take-and-go replaces walk once started",
		"take_and_go" in ((gs.active_consequence["decision"] as Dictionary)["allowed_choices"] as Array))

	a.check("stage 2 press commits", _commit("press"))
	a.eq_str("the room resolves to result", str(_engine().active_stage()), "result")
	var result: Dictionary = (gs.active_consequence["decision"] as Dictionary).get("result", {})
	a.eq_str("resolution is won", str(result.get("resolution", "")), SCRIPTS.RESOLUTION_WON)
	a.eq_int("the whole band left with you", int(result.get("cash", 0)), expected_take)
	a.eq_int("the wallet agrees", gs.cash, cash_before + expected_take)
	a.eq_int("a run room is rep", gs.stick_rep, 1)
	a.check("heat landed", float(result.get("heat", 0.0)) > 0.0)
	a.check("the answer is scheduled or rolled",
		true if gs.consequence_queue.is_empty() else
		str((gs.consequence_queue[0] as Dictionary).get("cause_id", "")) == str(gs.active_consequence.get("cause_id", "")))
	a.eq_int("no slot spent before continue", gs.time_slots_today, 3)

	var day_before: int = gs.day
	# The exit scheduled a retaliation against this cause. Continue is about to
	# cross the night, and a surfaced retaliation on the new morning would put a
	# fresh chain on the board mid-assert — clear the queue first, because what
	# this check is holding to account is the CONTINUE, not the answer.
	gs.consequence_queue = []
	a.check("continue settles", gm.dispatch("consequence_continue", {}))
	a.eq_bool("chain cleared", _engine().has_active(), false)
	a.eq_int("the robbery's slot crossed the night", gs.day, day_before + 1)

# --- 5. take and go ----------------------------------------------------------

func _check_take_and_go() -> void:
	var day: int = _find_day(3, T2_TARGET, ["success"])
	a.check("a stage-one success day exists", day > 0)
	if day <= 0:
		return
	_reset_probe(3)
	gs.day = day
	var cash_before: int = gs.cash
	var heat_before: float = gs.heat
	gm.dispatch("stickup", {"target_id": T2_TARGET})
	_commit("press")
	var loop: Dictionary = LOOP.loop_of(gs.active_consequence)
	var banked: int = int(loop.get("banked", 0))
	var take: int = int(loop.get("take_total", 1))
	a.check("leave early resolves", _commit("take_and_go"))
	var result: Dictionary = (gs.active_consequence["decision"] as Dictionary).get("result", {})
	a.eq_str("resolution is escaped", str(result.get("resolution", "")), SCRIPTS.RESOLUTION_ESCAPED)
	a.eq_int("banked cash credited", gs.cash, cash_before + banked)
	# Heat is the target's 3, scaled by the banked fraction, floored at 1.0,
	# through Spenard's 1.3 stick multiplier — the fraction is the discount
	# leaving early buys.
	var expected_heat: float = maxf(1.0, 3.0 * float(banked) / float(take)) * 1.3
	a.near("partial heat scales with the banked fraction",
		gs.heat - heat_before, expected_heat, 0.001)
	_close_out()

# --- 6. the fork -------------------------------------------------------------

func _check_fork_and_drop() -> void:
	var day: int = _find_day(3, T2_TARGET, ["failure"])
	a.check("a stage-one failure day exists", day > 0)
	if day <= 0:
		return
	_reset_probe(3)
	gs.day = day
	var cash_before: int = gs.cash
	var health_before: int = gs.health
	var heat_before: float = gs.heat
	gm.dispatch("stickup", {"target_id": T2_TARGET})
	_commit("press")

	var decision: Dictionary = gs.active_consequence["decision"]
	var loop: Dictionary = LOOP.loop_of(gs.active_consequence)
	a.eq_str("a slipped stage forks", str(loop.get("mode", "")), "fork")
	a.check("press is burned for the encounter", LOOP.is_burned(loop, "press"))
	var allowed: Array = decision.get("allowed_choices", [])
	a.check("the fork offers run-with-it", "run_with_it" in allowed)
	a.check("the fork offers the drop", "drop_and_run" in allowed)
	a.eq_int("the fork is a new round", int(decision.get("round", -1)), 1)
	a.check("the fork re-authors the beat",
		str(loop.get("beat", "")) == SCRIPTS.STICK_FORK_BEAT)
	_assert_guaranteed_out("at the fork")

	a.check("the drop resolves", _commit("drop_and_run"))
	var result: Dictionary = (gs.active_consequence["decision"] as Dictionary).get("result", {})
	a.eq_str("resolution is surrendered",
		str(result.get("resolution", "")), SCRIPTS.RESOLUTION_SURRENDERED)
	a.eq_int("dropped money is not kept", gs.cash, cash_before)
	a.eq_int("the drop costs no blood", gs.health, health_before)
	# Today's failure shape: max(1, heat - 1) = 2, through Spenard's 1.3.
	a.near("the drop's heat is the failure shape", gs.heat - heat_before, 2.6, 0.001)
	# The commit receipts carry the round keying: base key for round zero, the
	# suffixed key for the fork's round.
	var receipts: Array = _engine().receipts_for(str(gs.active_consequence.get("cause_id", "")))
	a.check("round-zero receipt keeps the original key",
		"confrontation:committed_choice" in receipts)
	a.check("the fork's commit is its own receipt",
		"confrontation:committed_choice:round:1" in receipts)
	_close_out()

# --- 7. catastrophic, and the cuffs ------------------------------------------

func _check_catastrophic_booking() -> void:
	var day: int = _find_day(3, T2_TARGET, ["catastrophic"])
	a.check("a catastrophic day exists", day > 0)
	if day <= 0:
		return
	_reset_probe(3)
	gs.day = day
	var health_before: int = gs.health
	gm.dispatch("stickup", {"target_id": T2_TARGET})
	_commit("press")
	var result: Dictionary = (gs.active_consequence["decision"] as Dictionary).get("result", {})
	a.eq_str("resolution is beaten", str(result.get("resolution", "")), SCRIPTS.RESOLUTION_BEATEN)
	a.eq_str("the tier is catastrophic",
		str((gs.active_consequence["decision"] as Dictionary).get("resolved_tier", "")), "catastrophic")
	var damage: int = health_before - gs.health
	a.check("catastrophe costs its band", damage >= 15 and damage <= 25)
	a.eq_bool("a catastrophe books at every tier", bool(result.get("arrested", false)), true)
	a.check("continue walks into booking", gm.dispatch("consequence_continue", {}))
	a.eq_str("the chain waits at booking", str(_engine().active_stage()), "booking")
	# Leave the probe clean for whatever runs next: this suite only ever
	# resets THROUGH reset_to_new_game, which clears the chain.

# --- 8. watch, and the crowd verb --------------------------------------------

func _check_watch_and_talk() -> void:
	# WATCH is worth exactly its authored bonus, asserted on the chance read
	# itself so the claim survives any reshuffling of the flow around it.
	_reset_probe(2)
	gs.day = 9
	var stickup: RefCounted = gm.system("stickup") as RefCounted
	var scripts: RefCounted = SCRIPTS.new()
	var t: Dictionary = gs.stick_target_by_id(T3_TARGET)
	var script: Dictionary = scripts.script_for(T3_TARGET)
	var cold := {"stage": 1, "stage_count": 3, "watched": false, "tip_no_decay": false}
	var warm := {"stage": 1, "stage_count": 3, "watched": true, "tip_no_decay": false}
	a.near("watch buys its authored bonus",
		stickup._room_chance(t, script, warm, "press")
			- stickup._room_chance(t, script, cold, "press"),
		SCRIPTS.WATCH_BONUS, 0.0001)

	# Driven: watching forfeits the stage pot and advances.
	gm.dispatch("stickup", {"target_id": T3_TARGET})
	var loop: Dictionary = LOOP.loop_of(gs.active_consequence)
	a.check("the crowd room offers talk",
		"talk" in ((gs.active_consequence["decision"] as Dictionary)["allowed_choices"] as Array))
	a.check("watch is on offer before the last stage",
		"watch" in ((gs.active_consequence["decision"] as Dictionary)["allowed_choices"] as Array))
	_commit("watch")
	loop = LOOP.loop_of(gs.active_consequence)
	a.eq_int("watch advances the stage", int(loop.get("stage", -1)), 1)
	a.eq_int("watch banks nothing", int(loop.get("banked", -1)), 0)
	a.eq_bool("watch arms the bonus", bool(loop.get("watched", false)), true)
	a.eq_int("watching is still an attempt", gs.stick_attempts, 1)
	# The last stage never offers watch: there is no next move to buy.
	_commit("take_and_go")
	_close_out()

	# The tier-3 room's structure: goodie_stash runs its decay a stage early
	# (resistance 3), and never offers talk — a stash spot has no crowd.
	var stash_script: Dictionary = scripts.script_for("goodie_stash")
	a.eq_bool("the stash has no crowd to talk down",
		bool(stash_script.get("talk", false)), false)
	a.near("the stash clock starts early",
		scripts.stage_mod(stash_script, 1), -0.07, 0.0001)
	a.near("the dice game clock starts on time",
		scripts.stage_mod(script, 1), 0.0, 0.0001)

# --- 9. the loop survives the save shape -------------------------------------

func _check_reload_shape() -> void:
	var day: int = _find_day(3, T2_TARGET, ["success"])
	if day <= 0:
		a.check("reload shape needs a success day", false)
		return
	_reset_probe(3)
	gs.day = day
	gm.dispatch("stickup", {"target_id": T2_TARGET})
	_commit("press")

	# Round-trip the chain through the validator the way a load would: the
	# loop's own keys are not in the validator's coercion list, and the
	# contract this asserts is that they come back untouched rather than
	# stripped or defaulted. The verdict's own copy is read — never the input —
	# so a validator that rebuilt the block from its known keys would fail here
	# instead of passing vacuously.
	var validator: RefCounted = preload("res://autoload/save_validator.gd").new()
	var verdict: Dictionary = validator.validate_state(
		{"active_consequence": gs.active_consequence.duplicate(true)})
	var validated: Dictionary = verdict.get("state", {})
	a.check("the validator returned a state", not validated.is_empty())
	var chain: Dictionary = validated.get("active_consequence", {})
	var decision: Dictionary = chain.get("decision", {})
	var loop: Variant = decision.get("loop", {})
	a.check("the loop block survives validation",
		loop is Dictionary and not (loop as Dictionary).is_empty())
	if loop is Dictionary:
		a.eq_int("banked survives validation",
			int((loop as Dictionary).get("banked", -1)),
			int(LOOP.loop_of(gs.active_consequence).get("banked", -2)))
	a.eq_int("the round counter survives validation",
		int(decision.get("round", -1)), 1)

	# Close it out so the suite ends with no chain on the board.
	_commit("take_and_go")
	_close_out()

# --- 10. the Lift's caught-loop escalation + BRIBE (0.1.2) ------------------

## Opens a boost_caught chain, retrying days until one actually opens. Boost
## has no day-scan predictor the way stickup's rooms do above -- the outcome
## key depends on a cause_id allocated only once the chain opens -- so this is
## the same bounded retry the parity suite's own caught-loop probes use.
func _open_lift_chain(tier: int, target_id: String) -> bool:
	gs.boost_tier = tier
	for day in range(1, 300):
		gs.day = day
		gs.heat = 0.0
		gs.health = gs.health_max
		gs.active_consequence = {}
		if gm.dispatch("boost", {"target_id": target_id}) \
				and not (gs.active_consequence as Dictionary).is_empty():
			return true
	return false

## A lift needs a target the run has clocked (batch 14) -- the parity
## runner's `_clock_every_boost_target`, copied rather than shared since this
## suite does not import that file.
func _clock_every_boost_target() -> void:
	for target in gs.boost_targets:
		var target_id := str((target as Dictionary)["id"])
		if not target_id in gs.boost_targets_discovered:
			gs.boost_targets_discovered.append(target_id)

## `gs.run_seed` defaults to the literal "907hustle" (game_state.gd:37) and
## `reset_to_new_game()` never touches it, so it is the same in every reset in
## every context -- this suite, a live session, anywhere. That makes the
## caught-outcome roll ("consequence:%s:boost_caught:%s:outcome" %
## [cause_id, choice_id]) fully predictable from the cause_id alone, and
## cause_id is allocated sequentially off `gs.next_cause_sequence` -- so
## PRE-SETTING that counter steers which cause_id the next opened chain gets,
## rather than retrying fresh days hoping to land on a roll nobody chose.
## `34` (set the counter to one less, per how `open_chain` allocates) is the
## first sequence, verified live against this exact seed and these exact
## attributes, at which fight, talk AND run all fail in turn at tier 1 --
## letting this drive the whole escalation ladder to its cap deterministically
## in one pass instead of gambling on a blind day search finding "caught AND
## fails" together, which this build measures at roughly one day in 800.
const _LIFT_ALL_FAIL_CAUSE_SEQ := 33
## Same technique, needing only fight to fail once (one escalation is enough
## to reach round 1, where HAND IT BACK first becomes available) -- verified
## live the same way, against the same seed and attributes.
const _LIFT_FIGHT_FAIL_CAUSE_SEQ := 14

func _check_lift_escalation() -> void:
	gs.reset_to_new_game()
	gs.attributes = {"combat": 1, "charisma": 1, "intelligence": 1}
	gs.boost_store_bans = []
	gs.boost_bribes_used = []
	_clock_every_boost_target()
	var engine: Object = gm.system("consequence")
	var rules: RefCounted = preload("res://data/consequence_rules.gd").new()

	gs.next_cause_sequence = _LIFT_ALL_FAIL_CAUSE_SEQ
	var opened := _open_lift_chain(1, "night_owl")
	a.check("a tier-1 chain opens for the escalation probe", opened)
	if not opened:
		return
	var cause_id := str(engine.active_summary().get("cause_id", ""))
	a.eq_str("the probe landed on the predicted cause",
		cause_id, "cause:%08d" % (_LIFT_ALL_FAIL_CAUSE_SEQ + 1))

	# Round zero: five choices at tier 1 (SETTLE IT joins the authored four).
	var decision0: Dictionary = (gs.active_consequence as Dictionary).get("decision", {})
	var allowed0: Array = decision0.get("allowed_choices", [])
	a.eq_int("the fresh tier-1 decision offers five choices", allowed0.size(), 5)
	a.check("bribe is among them", "bribe" in allowed0)
	var base_run_odds: float = float(
		(decision0.get("shown_probabilities", {}) as Dictionary).get("run", -1.0))
	var base_talk_odds: float = float(
		(decision0.get("shown_probabilities", {}) as Dictionary).get("talk", -1.0))

	# Round 1: fight fails and burns.
	a.check("fight commits", _commit("fight"))
	a.eq_str("fight's failure escalates rather than resolving",
		engine.active_stage(), engine.STAGE_DECISION)
	var decision1: Dictionary = (gs.active_consequence as Dictionary).get("decision", {})
	var allowed1: Array = decision1.get("allowed_choices", [])
	var shown1: Dictionary = decision1.get("shown_probabilities", {})
	var loop1: Dictionary = LOOP.loop_of(gs.active_consequence)
	a.check("a fight failure burns fight out of the choice list",
		not "fight" in allowed1)
	a.check("run and talk remain available", "run" in allowed1 and "talk" in allowed1)
	a.check("bribe remains available through the escalation", "bribe" in allowed1)
	a.near("run's odds drop by one round of LIFT_ESCALATION's verb_penalty",
		float(shown1.get("run", -1.0)), base_run_odds - 0.10)
	a.near("talk's odds drop by the same one round",
		float(shown1.get("talk", -1.0)), base_talk_odds - 0.10)
	a.check("the loop carries a beat for the round just presented",
		not str(loop1.get("beat", "")).is_empty())
	a.check("fight is recorded as burned", LOOP.is_burned(loop1, "fight"))
	a.eq_int("the loop is on round 1", int(loop1.get("round", -1)), 1)

	# Round 2: talk fails and burns too.
	a.check("talk commits", _commit("talk"))
	a.eq_str("talk's failure escalates a second time",
		engine.active_stage(), engine.STAGE_DECISION)
	var decision2: Dictionary = (gs.active_consequence as Dictionary).get("decision", {})
	var allowed2: Array = decision2.get("allowed_choices", [])
	var shown2: Dictionary = decision2.get("shown_probabilities", {})
	a.check("talk is burned alongside fight",
		not "fight" in allowed2 and not "talk" in allowed2)
	a.check("only run is left to roll", "run" in allowed2)
	a.near("run's odds now carry two rounds of degradation",
		float(shown2.get("run", -1.0)), base_run_odds - 0.20)
	a.eq_int("the loop is on round 2",
		int(LOOP.loop_of(gs.active_consequence).get("round", -1)), 2)

	# Round 3: run is the last verb standing. Its failure resolves through
	# CAUGHT_EFFECTS directly -- the cap and the exhaustion are the same
	# attempt by construction, since there is no fourth rolled verb to offer.
	a.check("run commits", _commit("run"))
	a.eq_str("the last verb's failure resolves instead of escalating a fourth time",
		engine.active_stage(), engine.STAGE_RESULT)
	var outcome: Dictionary = engine.result_summary()
	a.eq_str("the terminal tier is failure, exactly as predicted",
		str(outcome.get("resolved_tier", "")), "failure")
	var expected_row: Dictionary = rules.effects_for("run", "failure")
	var result: Dictionary = outcome.get("result", {})
	a.eq_str("the terminal take disposition matches run/failure's unedited row",
		str(result.get("take_disposition", "")), str(expected_row.get("take", "")))
	a.eq_bool("the terminal ban matches run/failure's unedited row",
		bool(result.get("banned", false)), bool(expected_row.get("ban", false)))
	if engine.active_stage() == engine.STAGE_BOOKING:
		_close_out()
	gs.active_consequence = {}

## SETTLE IT: cost, no-ban resolution, once-per-store, and tier-3 absence.
func _check_lift_bribe() -> void:
	gs.reset_to_new_game()
	gs.attributes = {"combat": 1, "charisma": 1, "intelligence": 1}
	gs.boost_store_bans = []
	gs.boost_bribes_used = []
	_clock_every_boost_target()
	var engine: Object = gm.system("consequence")
	var boost: Object = gm.system("boost")

	var opened := _open_lift_chain(1, "night_owl")
	a.check("a tier-1 chain opens for the bribe probe", opened)
	if not opened:
		gs.active_consequence = {}
		return
	var source: Dictionary = (gs.active_consequence as Dictionary).get("source", {})
	var contested: int = int(source.get("contested_take", 0))
	var expected_cost: int = maxi(40, int(ceil(float(contested) * 2.0)))

	# Short of the price: the engine's own pre-commit gate refuses it (the
	# choice_blocked seam), not resolve_consequence returning ok:false after
	# the round's one commit is already spent.
	gs.cash = expected_cost - 1
	gs.clean_cash = gs.cash
	gs.dirty_cash = 0
	a.check("bribe reads blocked when short of its price",
		not boost.choice_blocked("bribe").is_empty())
	a.check("an unaffordable bribe is refused rather than committed",
		not gm.dispatch("resolve_consequence_choice", {"choice_id": "bribe"}))
	a.eq_str("a refused bribe leaves the round uncommitted",
		str((gs.active_consequence as Dictionary).get("decision", {}).get("committed_choice", "x")), "")

	# Affordable: resolves deterministically, no ban, goods back, cash spent,
	# the store remembered.
	gs.cash = expected_cost + 500
	gs.clean_cash = gs.cash
	gs.dirty_cash = 0
	var cash_before: int = int(gs.cash)
	a.check("an affordable bribe commits",
		gm.dispatch("resolve_consequence_choice", {"choice_id": "bribe"}))
	var outcome: Dictionary = engine.result_summary()
	a.eq_str("the bribe resolves to its own tier",
		str(outcome.get("resolved_tier", "")), "bribed")
	a.eq_int("the bribe costs exactly 2x the contested take, floored",
		cash_before - int(gs.cash), expected_cost)
	a.check("the bribe carries no ban",
		not bool((outcome.get("result", {}) as Dictionary).get("banned", false)))
	a.check("the store is remembered as bribed",
		str(source.get("target_id", "")) in (gs.boost_bribes_used as Array))
	a.eq_str("the chain settles at the result stage",
		engine.active_stage(), engine.STAGE_RESULT)
	gs.active_consequence = {}

	# Once per store: a second lift on the same store no longer offers it.
	opened = _open_lift_chain(1, "night_owl")
	a.check("a second chain opens on the same store", opened)
	if opened:
		var decision2: Dictionary = (gs.active_consequence as Dictionary).get("decision", {})
		a.check("a store already bribed this run does not offer it again",
			not "bribe" in (decision2.get("allowed_choices", []) as Array))
	gs.active_consequence = {}

	# Tier 3: the Armed Guard does not take money.
	gs.boost_bribes_used = []
	opened = _open_lift_chain(3, "warehouse_club")
	a.check("a tier-3 chain opens for the absence probe", opened)
	if opened:
		var decision3: Dictionary = (gs.active_consequence as Dictionary).get("decision", {})
		a.eq_int("tier 3 offers the authored four with no bribe",
			(decision3.get("allowed_choices", []) as Array).size(), 4)
		a.check("bribe is absent at tier 3",
			not "bribe" in (decision3.get("allowed_choices", []) as Array))
	gs.active_consequence = {}

## HAND IT BACK: absent on the original decision, on offer once escalation
## starts, and resolves as a real guaranteed out -- goods back, no ban, no
## arrest, the store left bribable and re-liftable exactly as if this run
## had never touched it.
func _check_lift_hand_it_back() -> void:
	gs.reset_to_new_game()
	gs.attributes = {"combat": 1, "charisma": 1, "intelligence": 1}
	gs.boost_store_bans = []
	gs.boost_bribes_used = []
	_clock_every_boost_target()
	var engine: Object = gm.system("consequence")

	gs.next_cause_sequence = _LIFT_FIGHT_FAIL_CAUSE_SEQ
	var opened := _open_lift_chain(1, "night_owl")
	a.check("a tier-1 chain opens for the hand-it-back probe", opened)
	if not opened:
		return
	var decision0: Dictionary = (gs.active_consequence as Dictionary).get("decision", {})
	a.check("hand_it_back is absent from the original decision",
		not "hand_it_back" in (decision0.get("allowed_choices", []) as Array))

	a.check("fight commits", _commit("fight"))
	a.eq_str("fight's failure escalates", engine.active_stage(), engine.STAGE_DECISION)
	var decision1: Dictionary = (gs.active_consequence as Dictionary).get("decision", {})
	var allowed1: Array = decision1.get("allowed_choices", [])
	a.check("hand_it_back joins the offer once escalation starts",
		"hand_it_back" in allowed1)
	a.check("hand_it_back is flagged deterministic",
		"hand_it_back" in (decision1.get("deterministic_choices", []) as Array))

	a.check("hand_it_back commits", _commit("hand_it_back"))
	a.eq_str("hand_it_back resolves immediately",
		engine.active_stage(), engine.STAGE_RESULT)
	var outcome: Dictionary = engine.result_summary()
	a.eq_str("the tier is handed_back", str(outcome.get("resolved_tier", "")), "handed_back")
	var result: Dictionary = outcome.get("result", {})
	a.eq_str("the goods come back", str(result.get("take_disposition", "")), "return")
	a.eq_bool("no ban", bool(result.get("banned", false)), false)
	a.eq_bool("no arrest", bool(result.get("arrested", false)), false)
	a.check("the store is not remembered as bribed or banned",
		not "night_owl" in (gs.boost_bribes_used as Array)
		and not "night_owl" in (gs.boost_store_bans as Array))
	gs.active_consequence = {}

# --- 11. the caught decision (0.3.0, ENC-D1..D9) -----------------------------
#
# The blown-job answer: a single-roll (tier 1) stickup that comes up Failure
# over the tier's Heat gate, or Catastrophic at any Heat, now opens
# fight/run/talk/yield before any arrest resolves -- no more decision-less
# entry to Booking (ENC-D1). Rooms are untouched (ENC-D2) and keep their own
# coverage above; this block is the single-roll path's own.

## Heat set BEFORE `chance_for` reads it, mirroring the parity runner's own
## `_stick_gate_ready` split for the same reason: the chance a day produces
## moves with the Heat, so each Heat value needs its own scan.
func _reset_caught_probe(heat: float, slot: int = 0) -> void:
	gs.reset_to_new_game()
	gs.current_district_id = "north_star_lot"
	gs.time_slots_today = slot
	gs.time_slot = ["MORNING", "AFTERNOON", "EVENING", "NIGHT"][slot]
	gs.stick_daily_count = 0
	gs.attributes = {"combat": 1, "charisma": 1, "intelligence": 1}
	gs.heat = heat

## The single-roll path's own day-scan -- `chance_for`, not a room's stage
## chance, since every tier-1 target (this probe's `washgo_regular`) has no
## script at all (`has_room` is false for every tier-1 id).
func _find_tier1_day(heat: float, target_id: String, want_tier: String, slot: int = 0) -> int:
	_reset_caught_probe(heat, slot)
	var stickup: RefCounted = gm.system("stickup") as RefCounted
	var resolver: RefCounted = gm.system("outcome_resolver") as RefCounted
	var t: Dictionary = gs.stick_target_by_id(target_id)
	var chance: float = stickup.chance_for(t)
	for day in range(1, 400):
		var key := "stickup:%d:%d:%s" % [day, slot, target_id]
		var outcome: Dictionary = resolver.resolve_action("robbery", chance, 1, gs.run_seed, key)
		if str(outcome["tier"]) == want_tier:
			return day
	return -1

func _check_stick_caught() -> void:
	var rules: RefCounted = preload("res://data/consequence_rules.gd").new()
	var target_id := "washgo_regular"

	# A HOT plain failure opens the decision -- driven end to end, because this
	# is also where ENC-D9's source-time contract gets proved: owed the moment
	# the decision opens, still owed through result and into booking, settled
	# exactly once when the booking itself commits.
	var hot_day: int = _find_tier1_day(13.0, target_id, "failure")
	a.check("a hot failure day exists in the scan window", hot_day > 0)
	if hot_day > 0:
		_reset_caught_probe(13.0)
		gs.day = hot_day
		a.check("the hot robbery dispatches", gm.dispatch("stickup", {"target_id": target_id}))
		a.eq_str("a hot failure opens the caught decision",
			str(gs.active_consequence.get("chain_kind", "")), "stick_caught")
		a.eq_str("it opens at decision, not result", str(_engine().active_stage()), "decision")
		var decision: Dictionary = gs.active_consequence.get("decision", {})
		var allowed: Array = decision.get("allowed_choices", [])
		a.eq_int("the authored four are on offer, and only them", allowed.size(), 4)
		for verb in ["fight", "run", "talk", "yield"]:
			a.check("%s is offered" % verb, verb in allowed)
		a.check("no BRIBE here -- there is no take and no store",
			not "bribe" in allowed and not "hand_it_back" in allowed)
		a.eq_bool("the source slot is owed the moment the decision opens",
			_engine().source_time_owed(), true)

		var cause_before: String = str(gs.active_consequence.get("cause_id", ""))
		a.check("yield commits", _commit("yield"))
		var result: Dictionary = _engine().result_summary()
		a.eq_str("yield's tier is deterministic",
			str(result.get("resolved_tier", "")), "deterministic")
		a.eq_bool("yield books, deliberately",
			bool((result.get("result", {}) as Dictionary).get("arrested", false)), true)
		a.eq_str("the result stage is reached, not skipped",
			str(_engine().active_stage()), "result")
		a.eq_bool("the source slot is still owed at result",
			_engine().source_time_owed(), true)
		a.check("continue walks into booking", gm.dispatch("consequence_continue", {}))
		a.eq_str("booking rides the SAME chain", str(_engine().active_stage()), "booking")
		a.eq_str("the same cause carries the booking",
			str(gs.active_consequence.get("cause_id", "")), cause_before)
		a.eq_bool("the source slot is still owed -- booking has not committed yet",
			_engine().source_time_owed(), true)
		a.check("the booking commits", gm.dispatch("resolve_booking_choice", {"choice_id": "serve_time"}))
		a.eq_bool("the booking commit settles the source slot, exactly once",
			_engine().source_time_owed(), false)
		a.eq_int("the release receipt counts the source slot exactly once",
			int((gs.active_consequence.get("booking", {}) as Dictionary).get("source_slots_settled", -1)), 1)
		a.check("release settles", gm.dispatch("consequence_continue", {}))
		a.eq_bool("the chain closes clean", _engine().has_active(), false)

	# A SUB-GATE failure (Heat under the tier's gate) is no ceremony at all --
	# heat, a log line, move on, exactly as it always has been.
	var cold_day: int = _find_tier1_day(0.0, target_id, "failure")
	a.check("a cold failure day exists in the scan window", cold_day > 0)
	if cold_day > 0:
		_reset_caught_probe(0.0)
		gs.day = cold_day
		a.check("the cold robbery dispatches", gm.dispatch("stickup", {"target_id": target_id}))
		a.eq_bool("a sub-gate failure opens no chain", _engine().has_active(), false)
		a.eq_int("it still spends its slot inline, the old sub-gate shape",
			gs.time_slots_today, 1)

	# CATASTROPHIC opens at every Heat, and its entry degrades the shown odds
	# by the one authored penalty (ENC-D6) -- the number the player is shown
	# must be the number that gets rolled, so this is asserted on the LIVE
	# snapshot, not re-derived from the rule in isolation.
	var cat_day: int = _find_tier1_day(0.0, target_id, "catastrophic")
	a.check("a catastrophic day exists in the scan window", cat_day > 0)
	if cat_day > 0:
		_reset_caught_probe(0.0)
		gs.day = cat_day
		a.check("the catastrophic robbery dispatches", gm.dispatch("stickup", {"target_id": target_id}))
		a.eq_str("catastrophic opens the caught decision even at zero heat",
			str(gs.active_consequence.get("chain_kind", "")), "stick_caught")
		var shown: Dictionary = (gs.active_consequence.get("decision", {}) as Dictionary) \
			.get("shown_probabilities", {})
		var resolver: RefCounted = gm.system("outcome_resolver") as RefCounted
		var expected_run: float = resolver.success_probability("escape",
			rules.stick_caught_chance("run", true), 1, 0)
		var undegraded_run: float = resolver.success_probability("escape",
			rules.stick_caught_chance("run", false), 1, 0)
		a.near("the shown odds carry the catastrophic-entry penalty",
			float(shown.get("run", -1.0)), expected_run, 0.0001)
		a.check("the penalty actually moved the number from an ordinary entry",
			not is_equal_approx(expected_run, undegraded_run))

	# Cooldown suppresses entry outright -- ArrestSystem's exact current
	# semantics (ENC-D3): the law does not show, full stop, same as any other
	# arrest gate the cooldown already covers.
	var suppressed_day: int = _find_tier1_day(13.0, target_id, "failure")
	a.check("a suppressible hot-failure day exists", suppressed_day > 0)
	if suppressed_day > 0:
		_reset_caught_probe(13.0)
		gs.day = suppressed_day
		gs.arrest_record = {"priors": 0, "last_arrest_day": -1,
			"cooldown_until_day": suppressed_day + 1, "charges": []}
		a.check("the robbery dispatches under cooldown",
			gm.dispatch("stickup", {"target_id": target_id}))
		a.eq_bool("cooldown suppresses the caught decision entirely",
			_engine().has_active(), false)
		a.eq_int("a cooldown-suppressed arrest still spends its slot",
			gs.time_slots_today, 1)
	gs.arrest_record = {"priors": 0, "last_arrest_day": -1, "charges": []}
	gs.active_consequence = {}

# --- check block 14: SQ-D1..D5, the encounter overlay (0.6.0 PR A) -----------
#
# Presentation-only coverage in a suite that is otherwise about resolution,
# because the thing at risk is not a number: it is the route ladder. SQ-D2
# narrows `blocking_route()` from "any live chain" to "booking or release", and
# that one function has three readers (`resolved_route`, the boot/CONTINUE
# path, and the flow-sheet drain's guard). Get the split wrong in either
# direction and either the player navigates away from a live decision or a
# booking becomes unreachable — neither of which any existing check would
# notice, because both leave every authored number exactly where it was.
#
# The arms below are the ones the danger list names, in both directions, plus
# the structural proof that SQ-D1's extraction did not leave two copies of the
# chain's copy behind.

const ENCOUNTER_SHEET := preload("res://ui/components/encounter_sheet.gd")
const SURFACE_BASE := preload("res://ui/screens/surface_base.gd")

func _check_encounter_overlay() -> void:
	var nav: Node = get_node_or_null("/root/ScreenManager")
	if nav == null:
		a.check("ScreenManager is available for the route ladder arms", false)
		return

	# --- SQ-D2: the stage split, from the one place that owns it -------------
	a.eq_bool("decision rides the sheet",
		ENCOUNTER_SHEET.stage_rides_sheet("decision"), true)
	a.eq_bool("result rides the sheet",
		ENCOUNTER_SHEET.stage_rides_sheet("result"), true)
	a.eq_bool("booking does NOT ride the sheet",
		ENCOUNTER_SHEET.stage_rides_sheet("booking"), false)
	a.eq_bool("release does NOT ride the sheet",
		ENCOUNTER_SHEET.stage_rides_sheet("release"), false)
	a.eq_bool("an unknown stage does not ride the sheet (fails closed)",
		ENCOUNTER_SHEET.stage_rides_sheet("nonsense"), false)

	# --- the ladder, driven through the real chain ---------------------------
	_reset_probe()
	gs.active_consequence = {}
	gs.game_over = false
	a.eq_str("no chain, no blocking route", str(nav.blocking_route()), "")

	# A real tier-2 room, opened through the real dispatch, so the arms below
	# are asserting against a chain the game actually produces rather than a
	# hand-built dictionary that might not resemble one.
	var day: int = _find_day(3, T2_TARGET, ["messy"])
	a.check("a tier-2 probe day exists for the ladder arms", day > 0)
	if day <= 0:
		return
	_reset_probe(3)
	gs.day = day
	a.check("the probe robbery dispatches", gm.dispatch("stickup", {"target_id": T2_TARGET}))
	a.eq_str("the room opens at decision", str(_engine().active_stage()), "decision")

	a.eq_str("a live DECISION does not force the consequence route",
		str(nav.blocking_route()), "")
	a.eq_str("...so ordinary navigation resolves to where it was asked to go",
		str(nav.resolved_route(nav.HOME)), nav.HOME)
	a.eq_str("...including the boot/CONTINUE landing",
		str(nav.resolved_route(nav.STREET)), nav.STREET)

	# The sheet builds against that live chain, and it builds the DECISION.
	var built: Control = ENCOUNTER_SHEET.build_sheet(_engine(), gs, Callable())
	a.check("the sheet builds content for a live decision", built != null)
	if built != null:
		var actions: Array = _sheet_action_buttons(built)
		a.check("the decision sheet carries at least one commit button",
			not actions.is_empty())
		var commits: int = 0
		for b in actions:
			if str((b as Button).get_meta(ENCOUNTER_SHEET.ACTION_META, "")) \
					== ENCOUNTER_SHEET.ACTION_COMMIT:
				commits += 1
		a.eq_int("one commit button per undisabled choice row",
			commits, _undisabled_choice_count())
		built.free()

	# --- the same chain at booking DOES take the screen ----------------------
	#
	# Forced by stage rather than by driving a robbery all the way to an arrest:
	# the ladder reads `stage`, and what this arm is about is the ladder.
	var saved_stage := str(gs.active_consequence.get("stage", ""))
	gs.active_consequence["stage"] = "booking"
	a.eq_str("a live BOOKING forces the consequence route",
		str(nav.blocking_route()), nav.CONSEQUENCE)
	a.eq_str("...and ordinary navigation is overridden by it",
		str(nav.resolved_route(nav.HOME)), nav.CONSEQUENCE)
	a.check("the sheet refuses to build for a booking",
		ENCOUNTER_SHEET.build_sheet(_engine(), gs, Callable()) == null)
	gs.active_consequence["stage"] = "release"
	a.eq_str("a live RELEASE forces the consequence route",
		str(nav.blocking_route()), nav.CONSEQUENCE)
	gs.active_consequence["stage"] = saved_stage

	# --- game over still outranks everything (the ladder's rung 1) -----------
	gs.game_over = true
	a.eq_str("game over outranks a live decision",
		str(nav.blocking_route()), nav.GAME_OVER)
	gs.active_consequence["stage"] = "booking"
	a.eq_str("game over outranks a live booking too",
		str(nav.blocking_route()), nav.GAME_OVER)
	gs.game_over = false
	gs.active_consequence["stage"] = saved_stage

	# --- SQ-D1: one owner for the chain's copy -------------------------------
	#
	# The extraction is only worth anything if the screen stopped carrying its
	# own copy. These are the tables that used to live in `consequence.gd` and
	# would silently fork the day somebody edited one of them.
	var screen_src: String = FileAccess.get_file_as_string(
		"res://ui/screens/consequence.gd")
	a.check("consequence.gd no longer declares its own choice copy",
		not screen_src.contains("const CHOICE_COPY"))
	a.check("consequence.gd no longer declares its own arrest warnings",
		not screen_src.contains("const ARREST_WARNINGS"))
	a.check("consequence.gd no longer declares its own result rows",
		not screen_src.contains("const RESULT_ROWS"))
	a.check("consequence.gd no longer builds its own odds bands",
		not screen_src.contains("func _odds_text"))

	# --- SQ-D1: the duplicated palette is asserted equal, not trusted --------
	#
	# `encounter_sheet.gd` is a RefCounted and cannot inherit `surface_base`'s
	# colours (its own header says why). The same discipline `wander_events.gd`
	# ships its duplicated STASH IT label under applies here.
	var surface: Object = SURFACE_BASE
	a.check("the sheet's GREEN matches the screens'",
		ENCOUNTER_SHEET.GREEN == surface.GREEN)
	a.check("the sheet's RED matches the screens'",
		ENCOUNTER_SHEET.RED == surface.RED)
	a.check("the sheet's AMBER matches the screens'",
		ENCOUNTER_SHEET.AMBER == surface.AMBER)
	a.check("the sheet's MUTED matches the screens'",
		ENCOUNTER_SHEET.MUTED == surface.MUTED)
	a.check("the sheet's CREAM matches the screens'",
		ENCOUNTER_SHEET.CREAM == surface.CREAM)

	# --- SQ-D3: a blocking sheet cannot be dismissed by touching it ----------
	var plain := ModalSheet.new()
	var plain_content := Control.new()
	plain.setup(plain_content)
	a.eq_bool("an ordinary sheet defaults to non-blocking", plain.blocking, false)
	a.eq_int("an ordinary sheet builds its handle bar",
		_handle_count(plain), 1)
	plain.free()

	var locked := ModalSheet.new()
	locked.blocking = true
	var locked_content := Control.new()
	locked.setup(locked_content)
	a.eq_bool("a blocking sheet reports itself as such", locked.blocking, true)
	a.eq_int("a blocking sheet builds NO handle bar", _handle_count(locked), 0)
	# The scrim still exists and still stops the tap; it just does not dismiss.
	locked._on_scrim_input(_left_click())
	a.eq_bool("a scrim tap does not dismiss a blocking sheet",
		is_instance_valid(locked) and not locked._exiting, true)
	locked.free()

	gs.active_consequence = {}

## Every button `encounter_sheet.gd` built inside `root`, found by the metadata
## it stamps rather than by its text — the text is authored copy and a check
## matching on it would break the day somebody rewrites a label.
func _sheet_action_buttons(root: Node) -> Array:
	var out: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is Button and node.has_meta(ENCOUNTER_SHEET.ACTION_META):
			out.append(node)
	return out

func _undisabled_choice_count() -> int:
	var count: int = 0
	for row in _engine().choice_summaries():
		if not bool((row as Dictionary).get("disabled", false)):
			count += 1
	return count

## How many grab-bars the sheet's card actually contains. Counted structurally
## (a CenterContainer with its own `gui_input` wiring, which is what
## `_build_handle` makes) rather than by node name, so the check is about the
## control existing rather than about what it was called.
func _handle_count(sheet: ModalSheet) -> int:
	var count: int = 0
	var stack: Array[Node] = [sheet]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is CenterContainer and (node as Control).gui_input.get_connections().size() > 0:
			count += 1
	return count

func _left_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

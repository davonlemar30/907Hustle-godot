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
const MIN_CHECKS := 212

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

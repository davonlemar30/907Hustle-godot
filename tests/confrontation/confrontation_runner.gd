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
## 0.6.0 (SQ-D6..D9, PR B): +288 for check block 15. The bulk of that is the
## two STRUCTURAL arms, which sweep every encounter card x every role x every
## tier rather than driving one example each: 0.5.0 shipped two of four cards
## with no guaranteed out at all, on a chassis whose stated rule is one
## guaranteed out per round, and "an author remembered" is exactly the
## enforcement that failed. These arms are what replace it. The remaining ~16
## are the two DRIVEN arms: an encounter resolved through the real dispatch
## putting one row in the real ledger at the district the chain opened in, and
## the doorstep's enforcement room admitting the same calls on the same terms,
## and the arm that pins the beat to the SITUATION LINE — the one place the
## room's own copy was reaching the chip and the log and not the sentence.
## 0.6.0 (POOL-D1, PR C): 630 -> 1102, +472 and not one new line of test code.
## The structural sweeps iterate the card registry, so eight new cards brought
## their own coverage with them -- roles declared and filled exactly once,
## surrender deterministic and the other two not, every road labelled, copied,
## priced and observable at every tier. That is what the sweeps were for.
## The remaining +28 is `_check_guaranteed_prices_are_stated`, added after the
## real build showed a road labelled CERTAIN under a fallback line promising it
## cost nothing, on the one card where surrender is the WORST road.
## 0.6.0 (SQ-D10, PR D): 1130 -> 1203, +73 for check block 16 — the corner's
## two trigger sites in both directions, the derived once-per-district-per-day
## bound, both of Curtis's observation roads reaching his ledger receipted,
## and the arm that matters most: an ordinary sale on a corner that CANNOT
## fire is byte-for-byte what it was.
const MIN_CHECKS := 1203

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
	_check_verb_triad()
	_check_corner()

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

# --- check block 15: SQ-D6..D9, the triad and what it made structural -------
#
# The four arms here are what turn four rulings into things a future author
# cannot quietly break. Two of them exist because 0.5.0 shipped cards that DID
# break the rule they were written under — `wander_stopped_on_foot` and
# `wander_young_ones` both shipped with `"deterministic": []`, no guaranteed
# out at all, on a chassis whose stated rule is one guaranteed out per round.
# Care was what enforced that rule, and care missed twice out of four.

const EVENTS := preload("res://data/wander_events.gd")

func _check_verb_triad() -> void:
	_check_roles_structural()
	_check_room_beats_authored()
	_check_observation_rows()
	_check_observation_written()
	_check_beat_is_the_situation()
	_check_guaranteed_prices_are_stated()
	_check_crew_calls()
	_check_doorstep_crew_calls()

## SQ-D6, the arm that makes the ruling unbreakable: EVERY encounter card
## declares all three roles, each role is filled exactly once, and the
## `surrender` road is in `deterministic`.
##
## Read off the card table rather than off a driven encounter, deliberately —
## a card that is currently ungated out of the pool is still a card, and the
## day its requirement is met it must already obey this.
func _check_roles_structural() -> void:
	var cards: Array = []
	for card in EVENTS.CARDS:
		if str((card as Dictionary)["kind"]) == EVENTS.KIND_ENCOUNTER:
			cards.append(card)
	a.check("there are encounter cards to check at all", not cards.is_empty())

	for entry in cards:
		var card: Dictionary = entry
		var card_id := str(card["id"])
		var encounter: Dictionary = card["encounter"]
		var roles: Dictionary = EVENTS.roles_of(card)
		var choices: Array = encounter["choices"]
		var deterministic: Array = encounter.get("deterministic", [])

		for role in EVENTS.ROLES:
			var filled := str(EVENTS.choice_for_role(card, role))
			a.check("%s declares a %s road (got '%s')" % [card_id, role, filled],
				not filled.is_empty())
			a.check("%s's %s road is one of its own choices" % [card_id, role],
				filled in choices)

		# Exactly once, not at least once: two choices claiming `surrender`
		# would make "the guaranteed out" ambiguous, and the chassis reads it
		# as a single road.
		var counts: Dictionary = {}
		for choice_id in roles.keys():
			var role_name := str(roles[choice_id])
			counts[role_name] = int(counts.get(role_name, 0)) + 1
		for role in EVENTS.ROLES:
			a.eq_int("%s fills %s exactly once" % [card_id, role],
				int(counts.get(role, 0)), 1)

		# The rule this whole arm exists for.
		var out := str(EVENTS.choice_for_role(card, EVENTS.ROLE_SURRENDER))
		a.check("%s's surrender road '%s' is deterministic" % [card_id, out],
			out in deterministic)
		# ...and the two rolled roads are NOT, or the odds would render as
		# CERTAIN on a road that rolls.
		for role in [EVENTS.ROLE_FIGHT, EVENTS.ROLE_RUN]:
			var rolled := str(EVENTS.choice_for_role(card, role))
			a.check("%s's %s road '%s' is not deterministic"
				% [card_id, role, rolled], not rolled in deterministic)
			a.check("%s's %s road has an authored base chance"
				% [card_id, role], (encounter.get("base", {}) as Dictionary).has(rolled))

		# Every offered road has a label, a line, and an effects row per tier.
		for choice_id in choices:
			a.check("%s's '%s' has a label" % [card_id, str(choice_id)],
				not str(EVENTS.CHOICE_LABELS.get(str(choice_id), "")).is_empty())
			a.check("%s's '%s' has copy" % [card_id, str(choice_id)],
				not str(EVENTS.CHOICE_COPY.get(str(choice_id), "")).is_empty())
			a.check("%s's '%s' has an effects table" % [card_id, str(choice_id)],
				(encounter.get("effects", {}) as Dictionary).has(str(choice_id)))

## SQ-D7 read structurally. The parity suite drives the room; this asserts the
## AUTHORING rule that makes driving it worth anything — every beat is its own
## situation, with its own copy, its own roads and its own numbers.
func _check_room_beats_authored() -> void:
	for entry in EVENTS.CARDS:
		var card: Dictionary = entry
		if str(card["kind"]) != EVENTS.KIND_ENCOUNTER:
			continue
		var room: Dictionary = (card["encounter"] as Dictionary).get("room", {})
		if room.is_empty():
			continue
		var card_id := str(card["id"])
		var beats: Array = room.get("beats", [])
		a.check("%s's room authors beats" % card_id, not beats.is_empty())
		a.check("%s's room never authors past the chassis cap" % card_id,
			beats.size() <= int(SCRIPTS.ROUND_CAP))
		a.eq_int("%s's room cap matches the chassis cap" % card_id,
			int(room.get("cap", 0)), int(SCRIPTS.ROUND_CAP))

		var seen: Array = []
		for index in beats.size():
			var beat: Dictionary = beats[index]
			var text := str(beat.get("beat", ""))
			a.check("%s beat %d has its own situation copy" % [card_id, index],
				not text.is_empty())
			a.check("%s beat %d is not a repeat of an earlier one"
				% [card_id, index], not text in seen)
			seen.append(text)
			a.check("%s beat %d has its own round-log line" % [card_id, index],
				not str(beat.get("log", "")).is_empty())
			# The rule that survives every beat: one guaranteed out, always.
			var out := ""
			for choice_id in (beat.get("roles", {}) as Dictionary).keys():
				if str((beat["roles"] as Dictionary)[choice_id]) == EVENTS.ROLE_SURRENDER:
					out = str(choice_id)
			a.check("%s beat %d declares a surrender road" % [card_id, index],
				not out.is_empty())
			a.check("%s beat %d's surrender road is deterministic" % [card_id, index],
				out in (beat.get("deterministic", []) as Array))
			a.check("%s beat %d offers its surrender road" % [card_id, index],
				out in (beat.get("choices", []) as Array))
			# ...and every rolled road it offers has a number and a table.
			for choice_id in (beat.get("choices", []) as Array):
				if str(choice_id) == out:
					continue
				a.check("%s beat %d's '%s' has a base chance"
					% [card_id, index, str(choice_id)],
					(beat.get("base", {}) as Dictionary).has(str(choice_id)))
				a.check("%s beat %d's '%s' has an effects table"
					% [card_id, index, str(choice_id)],
					(beat.get("effects", {}) as Dictionary).has(str(choice_id)))

## SQ-D8: every road of every card resolves to a writable observation — either
## the card's own authored row or the role fallback — and never to nothing.
##
## Structural for the same reason as the roles arm: the rule is "every
## encounter writes one", and a card added tomorrow has to satisfy it the day
## it is added, not the day somebody happens to drive it.
func _check_observation_rows() -> void:
	var exposure: Node = get_node_or_null("/root/Exposure")
	if exposure == null:
		a.check("Exposure is available for the observation arms", false)
		return
	var tiers: Array = ["clean", "messy", "failure", "catastrophic"]
	for entry in EVENTS.CARDS:
		var card: Dictionary = entry
		if str(card["kind"]) != EVENTS.KIND_ENCOUNTER:
			continue
		var card_id := str(card["id"])
		var roles: Dictionary = EVENTS.roles_of(card)
		# Every road the card offers AT THE DOOR, and every road any of its
		# BEATS offers inside a room. The room's roads were the gap: SWING is
		# declared per beat, not on the card, so a lookup that only read the
		# card's own roles found nothing for it — and a fight that took three
		# rounds was the one resolution in the build that wrote no observation
		# at all. Found live, on the real build, after the structural arm above
		# passed clean; this is what makes that impossible to repeat.
		var all_roads: Dictionary = {}
		for choice_id in roles.keys():
			all_roads[str(choice_id)] = str(roles[choice_id])
		for beat in (((card["encounter"] as Dictionary).get("room", {}) as Dictionary)
				.get("beats", []) as Array):
			for choice_id in ((beat as Dictionary).get("roles", {}) as Dictionary).keys():
				all_roads[str(choice_id)] = str((beat["roles"] as Dictionary)[choice_id])
		for choice_id in all_roads.keys():
			var role := str(all_roads[choice_id])
			var check_tiers: Array = ["deterministic"] if role == EVENTS.ROLE_SURRENDER \
				else tiers
			for tier in check_tiers:
				var row: Dictionary = EVENTS.observation_for(card, str(choice_id), str(tier))
				a.check("%s/%s/%s resolves to an observation"
					% [card_id, str(choice_id), str(tier)], not row.is_empty())
				# A category Exposure does not know is dropped with a warning,
				# which is a silent no-write in everything but the log.
				a.check("%s/%s/%s names a category Exposure knows"
					% [card_id, str(choice_id), str(tier)],
					str(row.get("type", "")) in exposure.CATEGORIES)
				a.check("%s/%s/%s names an event" % [card_id, str(choice_id), str(tier)],
					not str(row.get("event", "")).is_empty())
				var npc := str(row.get("npc", EVENTS.OBSERVATION_NPC))
				a.check("%s/%s/%s names an NPC with a lens"
					% [card_id, str(choice_id), str(tier)],
					exposure.NPC_LENSES.has(npc))

## SQ-D9: availability gating, once per loop, no verb burned, and the ruling's
## own exclusion — a police stop admits none.
func _check_crew_calls() -> void:
	var wander: Object = gm.system("wander")
	var engine: Object = gm.system("consequence")

	# The ruling's per-card answer, read off the cards themselves.
	a.eq_bool("the shakedown admits crew calls",
		EVENTS.admits_crew(EVENTS.card_by_id("wander_shakedown")), true)
	a.eq_bool("the young ones admit crew calls",
		EVENTS.admits_crew(EVENTS.card_by_id("wander_young_ones")), true)
	a.eq_bool("Curtis's tax admits crew calls",
		EVENTS.admits_crew(EVENTS.card_by_id("wander_curtis_tax")), true)
	a.eq_bool("a police stop admits NONE",
		EVENTS.admits_crew(EVENTS.card_by_id("wander_stopped_on_foot")), false)

	# --- not recruited: no call, on a card that admits them ------------------
	_reset_probe()
	gs.active_consequence = {}
	gs.crew_records = {}
	gs.crew_assignments = {}
	wander._play_encounter(EVENTS.card_by_id("wander_young_ones"), "test:crew:none")
	var offered: Array = (gs.active_consequence.get("decision", {}) as Dictionary) \
		.get("allowed_choices", [])
	a.eq_bool("an unrecruited Tone is not offered", "call_tone" in offered, false)
	gs.active_consequence = {}

	# --- recruited, loyal, unassigned: offered, and deterministic ------------
	_reset_probe()
	gs.crew_records = {"tone": {"recruited": true, "status": "active", "loyalty": 4, "tier": 1}}
	gs.crew_assignments = {}
	wander._play_encounter(EVENTS.card_by_id("wander_young_ones"), "test:crew:ready")
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	offered = decision.get("allowed_choices", [])
	a.eq_bool("a recruited, loyal, unassigned Tone IS offered",
		"call_tone" in offered, true)
	a.eq_bool("...and the call is deterministic, never rolled",
		"call_tone" in (decision.get("deterministic_choices", []) as Array), true)
	a.eq_bool("...and it does not displace the card's own guaranteed out",
		"cross_the_street" in (decision.get("deterministic_choices", []) as Array), true)
	a.eq_int("...and the triad is still all there",
		(offered as Array).size(), 4)

	# The call resolves the encounter on its authored resolution, costs a point
	# of loyalty, and burns no verb.
	var loyalty_before: int = int((gs.crew_record("tone") as Dictionary).get("loyalty", 0))
	var health_before: int = int(gs.health)
	var summary: Dictionary = engine.active_summary()
	a.check("the call dispatches", gm.dispatch("resolve_consequence_choice", {
		"consequence_id": str(summary.get("consequence_id", "")),
		"cause_id": str(summary.get("cause_id", "")),
		"choice_id": "call_tone"}))
	var result: Dictionary = (gs.active_consequence.get("decision", {}) as Dictionary) \
		.get("result", {})
	a.eq_str("Tone's call resolves WON",
		str(result.get("resolution", "")), SCRIPTS.RESOLUTION_WON)
	a.eq_int("a call costs exactly its authored loyalty",
		int((gs.crew_record("tone") as Dictionary).get("loyalty", 0)),
		loyalty_before - int(SCRIPTS.CREW_CALLS["call_tone"]["loyalty_cost"]))
	a.eq_int("a call costs no health", int(gs.health), health_before)
	a.eq_int("a call takes nothing carried", int(result.get("goods", 0)), 0)
	a.eq_bool("a call burns no verb",
		"call_tone" in (LOOP.loop_of(gs.active_consequence).get("burned", []) as Array),
		false)
	gm.dispatch("consequence_continue", {})
	gs.active_consequence = {}

	# --- assigned today: not offered ----------------------------------------
	_reset_probe()
	gs.crew_records = {"tone": {"recruited": true, "status": "active", "loyalty": 4, "tier": 1}}
	gs.crew_assignments = {"tone": {"day": int(gs.day), "operation_id": "anything"}}
	wander._play_encounter(EVENTS.card_by_id("wander_young_ones"), "test:crew:busy")
	a.eq_bool("a Tone already spent today is not offered",
		"call_tone" in ((gs.active_consequence.get("decision", {}) as Dictionary)
			.get("allowed_choices", []) as Array), false)
	gs.active_consequence = {}

	# --- loyalty at zero: not offered ---------------------------------------
	_reset_probe()
	gs.crew_records = {"tone": {"recruited": true, "status": "active", "loyalty": 0, "tier": 1}}
	gs.crew_assignments = {}
	wander._play_encounter(EVENTS.card_by_id("wander_young_ones"), "test:crew:spent")
	a.eq_bool("a Tone with no loyalty left is not offered",
		"call_tone" in ((gs.active_consequence.get("decision", {}) as Dictionary)
			.get("allowed_choices", []) as Array), false)
	gs.active_consequence = {}

	# --- once per loop: spent inside a room, gone from the next round --------
	_reset_probe()
	gs.crew_records = {"tone": {"recruited": true, "status": "active", "loyalty": 4, "tier": 1}}
	gs.crew_assignments = {}
	gs.inventory = {"weed": 6}
	wander._play_encounter(EVENTS.card_by_id("wander_shakedown"), "test:crew:room")
	var chain: Dictionary = gs.active_consequence
	wander._open_shakedown_room(chain, "stand")
	var room_choices: Array = (gs.active_consequence.get("decision", {}) as Dictionary) \
		.get("allowed_choices", [])
	a.eq_bool("a call is offered inside the room too",
		"call_tone" in room_choices, true)
	var loop: Dictionary = LOOP.loop_of(gs.active_consequence)
	loop["crew_called"] = true
	wander._present_beat(gs.active_consequence, loop, 1)
	a.eq_bool("...and is gone from the next beat once spent",
		"call_tone" in ((gs.active_consequence.get("decision", {}) as Dictionary)
			.get("allowed_choices", []) as Array), false)
	a.eq_bool("...while the beat's own guaranteed out is still there",
		"give_it_up" in ((gs.active_consequence.get("decision", {}) as Dictionary)
			.get("deterministic_choices", []) as Array), true)
	gs.active_consequence = {}
	gs.crew_records = {}
	gs.crew_assignments = {}

## SQ-D8 driven end to end, not just read off the table: an encounter resolved
## through the real dispatch puts a row in the real ledger, at the district the
## CHAIN opened in, exactly once.
##
## The receipt is the half that matters. A chain sits at `result` until the
## player presses Continue, and a save taken there and reloaded twice would
## write the same observation twice without one — the same exactly-once problem
## `boost_caught:observation` already solved, borrowed rather than re-solved.
func _check_observation_written() -> void:
	var wander: Object = gm.system("wander")
	var engine: Object = gm.system("consequence")
	var exposure: Node = get_node_or_null("/root/Exposure")
	if exposure == null:
		a.check("Exposure is available for the write-through arm", false)
		return

	_reset_probe()
	gs.active_consequence = {}
	gs.npc_ledgers = {}
	gs.current_district_id = "north_star_lot"
	wander._play_encounter(EVENTS.card_by_id("wander_young_ones"), "test:obs:write")
	var opened_district := str(gs.active_consequence.get("district_id", ""))
	var summary: Dictionary = engine.active_summary()
	var cause_id := str(summary.get("cause_id", ""))

	# The player answers, and then WALKS somewhere else before pressing
	# Continue. The observation must still name where it happened.
	a.check("the surrender road dispatches", gm.dispatch("resolve_consequence_choice", {
		"consequence_id": str(summary.get("consequence_id", "")),
		"cause_id": cause_id, "choice_id": "cross_the_street"}))
	gs.current_district_id = "downtown"

	var ledger: Array = exposure.ledger_of(EVENTS.OBSERVATION_NPC)
	a.eq_int("resolving wrote exactly one observation", ledger.size(), 1)
	if ledger.is_empty():
		gs.active_consequence = {}
		return
	var row: Dictionary = ledger[0]
	a.eq_str("...of the authored category",
		str(row.get("type", "")), "submission")
	a.eq_str("...with the authored event",
		str(row.get("event", "")), "ceded_the_corner")
	a.eq_str("...at the district the CHAIN opened in, not where the player is now",
		str(row.get("location", "")), opened_district)
	a.eq_int("...counted once", int(row.get("count", 0)), 1)

	a.eq_bool("the observation receipt is claimed",
		engine.has_receipt(cause_id, "wander_encounter:observation"), true)
	# The reload case, simulated the way the engine itself would see it: the
	# receipt outlives the chain's stage, so a second pass writes nothing.
	wander._record_encounter_observation(gs.active_consequence,
		"cross_the_street", "deterministic")
	a.eq_int("a second pass over the same chain writes nothing",
		(exposure.ledger_of(EVENTS.OBSERVATION_NPC) as Array).size(), 1)

	gm.dispatch("consequence_continue", {})
	gs.active_consequence = {}
	gs.npc_ledgers = {}

## SQ-D9's second named surface: the doorstep's enforcement room admits the
## same calls on the same terms, through the same availability question.
func _check_doorstep_crew_calls() -> void:
	var doorstep: Object = gm.system("doorstep")
	if doorstep == null:
		a.check("the doorstep system is registered", false)
		return
	_reset_probe()
	gs.active_consequence = {}
	gs.crew_records = {}
	gs.crew_assignments = {}
	doorstep._open_enforcement("rent", {})
	a.eq_bool("no crew, no call in the enforcement room",
		"call_tone" in ((gs.active_consequence.get("decision", {}) as Dictionary)
			.get("allowed_choices", []) as Array), false)
	gs.active_consequence = {}

	_reset_probe()
	gs.active_consequence = {}
	gs.crew_records = {"tone": {"recruited": true, "status": "active", "loyalty": 3, "tier": 1}}
	gs.crew_assignments = {}
	doorstep._open_enforcement("rent", {})
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	a.eq_bool("an available Tone IS offered in the enforcement room",
		"call_tone" in (decision.get("allowed_choices", []) as Array), true)
	a.eq_bool("...deterministically",
		"call_tone" in (decision.get("deterministic_choices", []) as Array), true)
	a.eq_bool("...and the room's own YIELD is still the card's guaranteed out",
		"yield" in (decision.get("deterministic_choices", []) as Array), true)

	var health_before: int = int(gs.health)
	var summary: Dictionary = _engine().active_summary()
	a.check("the enforcement call dispatches", gm.dispatch("resolve_consequence_choice", {
		"consequence_id": str(summary.get("consequence_id", "")),
		"cause_id": str(summary.get("cause_id", "")), "choice_id": "call_tone"}))
	a.eq_str("Tone ends the room the way a clean FIGHT does",
		str((gs.active_consequence.get("decision", {}) as Dictionary)
			.get("resolved_tier", "")), "fight_clean")
	a.eq_int("...and nobody gets hurt doing it", int(gs.health), health_before)
	a.eq_int("...at the authored loyalty cost",
		int((gs.crew_record("tone") as Dictionary).get("loyalty", 0)), 2)
	gs.active_consequence = {}
	gs.crew_records = {}
	gs.crew_assignments = {}

## SQ-D7's on-screen half: whatever beat is live IS the situation the sheet
## shows, on every chain kind that runs a room.
##
## This arm exists because the beat reached the STAGE chip and the round log
## and did not reach the situation line — `situation_body` read the beat only
## inside its `KIND_CONFRONTATION` arm, which was correct while the
## confrontation chain was the only kind that ran a room. The wander room is
## the second, and all three of its authored beats rendered under the card's
## standing opener instead. Caught on the real build, after the structural and
## driven arms both passed clean, which is exactly the class of thing a
## screenshot catches and a state assertion does not.
func _check_beat_is_the_situation() -> void:
	var wander: Object = gm.system("wander")
	var engine: Object = gm.system("consequence")
	_reset_probe()
	gs.active_consequence = {}
	gs.inventory = {"weed": 6}
	var card: Dictionary = EVENTS.card_by_id("wander_shakedown")
	var beats: Array = (card["encounter"] as Dictionary)["room"]["beats"]
	wander._play_encounter(card, "test:beat:situation")
	wander._open_shakedown_room(gs.active_consequence, "stand")

	var summary: Dictionary = engine.active_summary()
	# Every authored beat, not just the first: the bug rendered the same wrong
	# line on all three, so an arm that only checked one would have to be
	# lucky as well as right.
	for index in beats.size():
		wander._present_beat(gs.active_consequence,
			LOOP.loop_of(gs.active_consequence), index)
		a.eq_str("beat %d is the situation the sheet renders" % index,
			ENCOUNTER_SHEET.situation_body(engine, summary),
			str((beats[index] as Dictionary)["beat"]))

	# ...and with no room live, the kind's own standing line is still what
	# shows. The fix is a precedence, not a replacement.
	gs.active_consequence = {}
	wander._play_encounter(card, "test:beat:no_room")
	a.eq_str("with no beat live, the kind's own line still shows",
		ENCOUNTER_SHEET.situation_body(engine, engine.active_summary()),
		"You went out to see what was around. This is what was around.")
	gs.active_consequence = {}

## ENC-D6's seam, applied to the roster: every deterministic road states its
## OWN guaranteed price rather than inheriting the screen's fallback.
##
## The fallback is "Guaranteed: no injury, no Heat, no arrest." It was true for
## every deterministic choice that shipped before 0.3.0 and it is true for
## almost none of SQ-D6's surrender roads — HANDS OUT lets a search find what
## is on you, OFF THE BLOCK leaves half your cargo behind, and WAIT IT OUT (the
## warrant check, the one card where surrender is the WORST road) costs the
## whole bag and the loudest Heat on the card. Caught on the real build: the
## sheet rendered "CERTAIN" beside a road that takes everything, under a line
## promising it takes nothing.
func _check_guaranteed_prices_are_stated() -> void:
	var wander: Object = gm.system("wander")
	for entry in EVENTS.CARDS:
		var card: Dictionary = entry
		if str(card["kind"]) != EVENTS.KIND_ENCOUNTER:
			continue
		var card_id := str(card["id"])
		var roads: Array = [str(EVENTS.choice_for_role(card, EVENTS.ROLE_SURRENDER))]
		for beat in (((card["encounter"] as Dictionary).get("room", {}) as Dictionary)
				.get("beats", []) as Array):
			for choice_id in ((beat as Dictionary).get("deterministic", []) as Array):
				if not str(choice_id) in roads:
					roads.append(str(choice_id))
		for road in roads:
			var said := str(wander.choice_guarantee(str(road)))
			a.check("%s's guaranteed road '%s' states its own price"
				% [card_id, str(road)], not said.is_empty())
			# The fallback would be a lie on every one of them, so none may
			# read like it.
			a.check("%s's '%s' does not claim it costs nothing"
				% [card_id, str(road)],
				not said.contains("no injury, no Heat, no arrest"))

	# The warrant check specifically: the price is stated, and it names the
	# two things that road actually costs.
	var warrant := str(wander.choice_guarantee("wait_it_out"))
	a.check("the warrant check's surrender road names what it takes",
		warrant.contains("everything you are carrying"))
	a.eq_bool("...and it is the card's declared surrender road",
		str(EVENTS.choice_for_role(EVENTS.card_by_id("wander_warrant_check"),
			EVENTS.ROLE_SURRENDER)) == "wait_it_out", true)

# --- check block 16: SQ-D10, the corner (0.6.0 PR D) -------------------------
#
# `MARKET_SCRIPTS` had sat authored and unconsumed since the loop was written.
# What these arms are actually guarding is the two things a trigger site can
# get wrong in ways nothing else notices: it fires when it should not, and an
# ordinary sale stops being ordinary.

const CORNER_SCRIPTS := SCRIPTS.MARKET_SCRIPTS
const RULES_CONST := preload("res://data/consequence_rules.gd")

func _check_corner() -> void:
	_check_corner_scripts_authored()
	_check_corner_stiff_trigger()
	_check_corner_stiff_day_bound()
	_check_ordinary_sell_unchanged()
	_check_corner_push_trigger()
	_check_corner_push_ledger()

## The beats SQ-D7 required and SQ-D10 said to author only if missing. Both
## scripts declared `cap: 2` and no beats, which under the round rule is a
## script that cannot run two rounds.
func _check_corner_scripts_authored() -> void:
	for script_id in CORNER_SCRIPTS.keys():
		var script: Dictionary = CORNER_SCRIPTS[script_id]
		var beats: Array = script.get("beats", [])
		a.eq_int("%s authors one beat per round of its own cap" % str(script_id),
			beats.size(), int(script["cap"]))
		var seen: Array = []
		for index in beats.size():
			var beat: Dictionary = beats[index]
			var text := str(beat.get("beat", ""))
			a.check("%s beat %d has its own situation" % [str(script_id), index],
				not text.is_empty() and not text in seen)
			seen.append(text)
			a.check("%s beat %d declares a guaranteed out" % [str(script_id), index],
				not (beat.get("deterministic", []) as Array).is_empty())
			for choice_id in (beat.get("deterministic", []) as Array):
				a.check("%s beat %d's out '%s' is one of its choices"
					% [str(script_id), index, str(choice_id)],
					str(choice_id) in (beat.get("choices", []) as Array))
			for choice_id in (beat.get("choices", []) as Array):
				a.check("%s beat %d's '%s' is in the script's action table"
					% [str(script_id), index, str(choice_id)],
					(script["actions"] as Dictionary).has(str(choice_id))
						or SCRIPTS.CREW_CALLS.has(str(choice_id)))

	# SQ-D10's header correction, asserted rather than trusted: the file may no
	# longer claim the four wired tables are unwired.
	var src: String = FileAccess.get_file_as_string(
		"res://data/confrontation_scripts.gd")
	a.check("the scripts file no longer claims MARKET_SCRIPTS is unwired",
		not src.contains("MARKET_SCRIPTS and STASH_IT — corner scripts"))
	a.check("...and names where STASH_IT actually is",
		src.contains("NOT on the Lift"))

## Fires when authored, never otherwise. Each precondition is removed one at a
## time so a gate that has quietly stopped mattering shows up as a card that
## still fires without it.
func _check_corner_stiff_trigger() -> void:
	var corner: Object = gm.system("corner")
	var engine: Object = gm.system("consequence")
	var district := "north_star_lot"

	# Baseline: everything satisfied EXCEPT the band. A quiet corner produces
	# no buyer who thinks he can shave the count.
	_reset_probe()
	gs.active_consequence = {}
	gs.current_district_id = district
	a.eq_bool("a QUIET corner never stiffs you",
		corner.try_open_stiff(district, "weed", 200), false)

	# Band satisfied. Seeds are walked to find one that fires, which also
	# proves the roll is a roll rather than a constant.
	var fired := false
	for day in range(1, 40):
		_reset_probe()
		gs.active_consequence = {}
		gs.current_district_id = district
		gs.day = day
		engine.add_pressure(district, "market", 4.0, "cause:corner:probe:%d" % day)
		if corner.try_open_stiff(district, "weed", 200):
			fired = true
			break
	a.eq_bool("a KNOWN-or-worse corner does stiff you, some days", fired, true)
	if fired:
		a.eq_str("...and it opens a confrontation chain",
			str(gs.active_consequence.get("chain_kind", "")), engine.KIND_CONFRONTATION)
		var decision: Dictionary = gs.active_consequence.get("decision", {})
		a.eq_str("...on the corner_stiff script",
			str(decision.get("definition_id", "")), "corner_stiff")
		a.eq_str("...opening on the script's first authored beat",
			str((decision.get("loop", {}) as Dictionary).get("beat", "")),
			str((CORNER_SCRIPTS["corner_stiff"]["beats"] as Array)[0]["beat"]))
		a.check("...offering the beat's own roads",
			(decision.get("allowed_choices", []) as Array)
				== (CORNER_SCRIPTS["corner_stiff"]["beats"] as Array)[0]["choices"])
		a.eq_bool("...with LET IT RIDE as the guaranteed out",
			"let_it_ride" in (decision.get("deterministic_choices", []) as Array), true)
		# The take in dispute is derived from the sale, not authored flat.
		a.eq_int("...over a fifth of the sale, floored and capped",
			int((gs.active_consequence.get("source", {}) as Dictionary).get("shorted", 0)),
			40)

	# A sale too small to argue about never opens one, however hot the corner.
	_reset_probe()
	gs.active_consequence = {}
	gs.current_district_id = district
	engine.add_pressure(district, "market", 8.0, "cause:corner:tiny")
	a.eq_bool("a sale too small to be worth arguing over never stiffs you",
		corner.try_open_stiff(district, "weed", 20), false)
	# ...and neither does anything, while a chain is already open.
	gs.active_consequence = {"stage": "decision", "chain_kind": "wander_encounter"}
	a.eq_bool("the corner never opens over a live chain",
		corner.try_open_stiff(district, "weed", 400), false)
	gs.active_consequence = {}

## Once per district per day, and DERIVED — the whole reason this PR needed no
## schema bump. `first_sale_today` reads `add_market_pressure`'s own day-stamped
## counter, so the bound cannot drift from what the game thinks "today" is.
func _check_corner_stiff_day_bound() -> void:
	var corner: Object = gm.system("corner")
	var engine: Object = gm.system("consequence")
	var district := "north_star_lot"

	_reset_probe()
	gs.active_consequence = {}
	gs.current_district_id = district
	a.eq_bool("before any sale, today is a first sale", corner.first_sale_today(district), true)
	engine.add_market_pressure(district)
	a.eq_bool("after one sale, it is not", corner.first_sale_today(district), false)
	a.eq_bool("...so the corner cannot fire a second time today",
		corner.try_open_stiff(district, "weed", 400), false)

	# A different district is a different corner.
	gs.districts_unlocked = ["north_star_lot", "downtown"]
	a.eq_bool("a different district is still a first sale",
		corner.first_sale_today("downtown"), true)

	# Tomorrow starts over, on the counter the game already keeps.
	gs.day = int(gs.day) + 1
	a.eq_bool("tomorrow starts over", corner.first_sale_today(district), true)
	gs.active_consequence = {}

## The other half, and the one a trigger site most often breaks: an ordinary
## sale must be byte-for-byte what it was. Driven through the real dispatch on
## a corner that CANNOT fire, with every accounting the sell path owns compared
## against a run with the corner system removed from the equation entirely.
func _check_ordinary_sell_unchanged() -> void:
	var economy: Object = gm.system("economy")
	var engine: Object = gm.system("consequence")
	var wallet: Object = gm.system("wallet")
	var district := "north_star_lot"

	_reset_probe()
	gs.active_consequence = {}
	gs.current_district_id = district
	gs.inventory = {"weed": 10}
	gs.time_slots_today = 0
	var dirty_before: int = int(wallet.dirty_balance())
	var pressure_before: float = float(engine.pressure_score(district, "market"))
	var heat_before: float = float(gs.heat)
	var slots_before: int = int(gs.time_slots_today)

	# QUIET corner: the trigger's band gate refuses, so this is an ordinary
	# sale by construction rather than by luck.
	var result: Dictionary = economy.handle("market_sell",
		{"product_id": "weed", "quantity": 4})
	a.check("an ordinary sale still succeeds (%s)"
		% str(result.get("reason", "")), bool(result.get("ok", false)))
	a.eq_bool("...and did not open a corner", bool(result.get("corner", false)), false)
	a.eq_bool("...and left no chain behind", engine.has_active(), false)
	a.eq_int("...crediting its revenue to DIRTY",
		int(wallet.dirty_balance()) - dirty_before, int(result.get("revenue", 0)))
	a.eq_int("...taking the units it sold", int(gs.inventory.get("weed", 0)), 6)
	a.check("...adding the district's own market pressure",
		float(engine.pressure_score(district, "market")) > pressure_before)
	a.check("...adding the sale's own heat", float(gs.heat) > heat_before)
	# `MARKET_SELL_COSTS_SLOT` is authored `false` today, so the honest
	# assertion is that the corner's trigger did not change whatever that
	# constant says — read from the rules rather than restated, so this arm
	# keeps holding the day somebody flips it.
	a.eq_int("...and spending exactly the slots the rules authorise",
		int(gs.time_slots_today),
		slots_before + (1 if RULES_CONST.MARKET_SELL_COSTS_SLOT else 0))
	gs.active_consequence = {}

## Curtis-gated, Spenard only, and rare.
func _check_corner_push_trigger() -> void:
	var corner: Object = gm.system("corner")

	_reset_probe()
	gs.active_consequence = {}
	gs.current_district_id = "north_star_lot"
	gs.curtis_phase = "invisible"
	a.eq_bool("no push before Curtis is looking",
		corner.try_open_push("north_star_lot"), false)

	gs.curtis_phase = "watching"
	a.eq_bool("no push outside his own corner",
		corner.try_open_push("downtown"), false)

	var fired := false
	for day in range(1, 60):
		_reset_probe()
		gs.active_consequence = {}
		gs.current_district_id = "north_star_lot"
		gs.curtis_phase = "watching"
		gs.day = day
		if corner.try_open_push("north_star_lot"):
			fired = true
			break
	a.eq_bool("a watching Curtis does push, some days", fired, true)
	if fired:
		var decision: Dictionary = gs.active_consequence.get("decision", {})
		a.eq_str("the push runs the corner_push script",
			str(decision.get("definition_id", "")), "corner_push")
		a.eq_bool("...offering STAND ON IT",
			"stand_on_it" in (decision.get("allowed_choices", []) as Array), true)
		a.eq_bool("...and STEP OFF as a guaranteed out",
			"step_off" in (decision.get("deterministic_choices", []) as Array), true)
		# CALL TONE is authored into the beat but is a CREW call, so it is
		# offered only when he is actually available -- no crew on this probe.
		a.eq_bool("...but not CALL TONE with no crew recruited",
			"call_tone" in (decision.get("allowed_choices", []) as Array), false)
	gs.active_consequence = {}

## The whole political point: STAND ON IT writes `defiance`, STEP OFF writes
## `submission`, and Curtis's THREAT lens has to see both.
func _check_corner_push_ledger() -> void:
	var corner: Object = gm.system("corner")
	var engine: Object = gm.system("consequence")
	var exposure: Node = get_node_or_null("/root/Exposure")
	if exposure == null:
		a.check("Exposure is available for the ledger arms", false)
		return

	for road in [["stand_on_it", "defiance", "held_the_corner"],
			["step_off", "submission", "ceded_the_corner"]]:
		var choice_id := str((road as Array)[0])
		var wanted_type := str((road as Array)[1])
		var wanted_event := str((road as Array)[2])
		# A day whose push opens AND whose chosen road resolves in one round.
		#
		# The second condition is not fussiness: a STAND ON IT that rolls a
		# plain `failure` BURNS itself (the chassis's Q6 rule) and opens the
		# script's second beat, where the only road left is STEP OFF — so a
		# search that took the first day a push opened would end up asserting
		# `defiance` against a chain that had, correctly, resolved as
		# `submission`. Found by writing exactly that test first.
		var resolved := false
		for day in range(1, 90):
			_reset_probe()
			gs.active_consequence = {}
			gs.npc_ledgers = {}
			gs.current_district_id = "north_star_lot"
			gs.curtis_phase = "watching"
			gs.day = day
			if not corner.try_open_push("north_star_lot"):
				continue
			var probe: Dictionary = engine.active_summary()
			gm.dispatch("resolve_consequence_choice", {
				"consequence_id": str(probe.get("consequence_id", "")),
				"cause_id": str(probe.get("cause_id", "")), "choice_id": choice_id})
			if engine.has_active() and str(engine.active_stage()) == "result":
				resolved = true
				break
			# Otherwise it escalated to beat two; clear and try the next day.
			while engine.has_active():
				if str(engine.active_stage()) == "decision":
					var s2: Dictionary = engine.active_summary()
					gm.dispatch("resolve_consequence_choice", {
						"consequence_id": str(s2.get("consequence_id", "")),
						"cause_id": str(s2.get("cause_id", "")), "choice_id": "step_off"})
				else:
					gm.dispatch("consequence_continue", {})
			gs.active_consequence = {}
			gs.npc_ledgers = {}
		a.eq_bool("a push resolves on the %s road in one round" % choice_id,
			resolved, true)
		if not resolved:
			continue
		var ledger: Array = exposure.ledger_of("curtis")
		a.eq_int("%s writes exactly one row into Curtis's ledger" % choice_id,
			ledger.size(), 1)
		if not ledger.is_empty():
			a.eq_str("...of the authored category",
				str((ledger[0] as Dictionary).get("type", "")), wanted_type)
			a.eq_str("...with the authored event",
				str((ledger[0] as Dictionary).get("event", "")), wanted_event)
			a.eq_str("...at the corner it happened on",
				str((ledger[0] as Dictionary).get("location", "")), "north_star_lot")
			# His THREAT lens must actually price it, or the row is decoration.
			a.check("...and his lens has a weight for it",
				exposure.CIVILIAN.has(wanted_type) or exposure.THREAT.has(wanted_type))
		# Receipted, so a save reloaded at the result stage and continued
		# cannot write the row twice. Asserted through the receipt rather than
		# by calling the writer again: `Exposure.record_observation` refuses
		# outside a dispatch by design, so a direct second call would prove
		# nothing about the receipt.
		a.eq_bool("...and the receipt that stops a reload double-writing is claimed",
			engine.has_receipt(str(engine.active_summary().get("cause_id", "")),
				"corner:observation"), true)
		if engine.has_active():
			gm.dispatch("consequence_continue", {})
		gs.active_consequence = {}
	gs.npc_ledgers = {}

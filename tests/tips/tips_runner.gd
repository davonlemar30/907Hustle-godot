extends Node
## Word of Mouth slice 1's own suite (`tests/tips/`), same shape as
## `tests/territory/` and `tests/confrontation/`: seconds rather than the
## parity runner's ten minutes, on the shared `territory_asserts.gd` harness.
##
## Covers the build's own acceptance list (seeded determinism, the budget
## cap, the ramp's bounds and quiet fraction, requirement gating, the
## fat-night payload actually consumed by a driven room, the dead-line hold,
## and the save round-trip) plus the two corrections `systems/tips.gd`'s own
## header documents against the build prompt: Eli names the lowest-pressure
## district rather than a dry shelf, and generation never checks
## `phone_active` — only the dead-line hold does, which is `push_message`'s
## job already and is what `_test_dead_line_holds` is proving.

const ASSERTS := preload("res://tests/territory/territory_asserts.gd")
const LOOP := preload("res://systems/confrontation_loop.gd")
const TIP_EVENTS := preload("res://data/tip_events.gd")
const RULES := preload("res://data/consequence_rules.gd")

const MIN_CHECKS := 93

var a: RefCounted
var gs: Node
var gm: Node
var rng: Node

func _ready() -> void:
	a = ASSERTS.new()
	gs = get_node("/root/GameState")
	gm = get_node("/root/GameManager")
	rng = get_node("/root/RngManager")

	_test_budget_determinism()
	_test_budget_cap_per_day()
	_test_ramp_bounds_and_quiet_fraction()
	_test_pherris_gating()
	_test_eli_gating_and_pressure_pick()
	_test_fat_night_gating_by_tier()
	_test_fat_night_payload_consumed_by_a_driven_room()
	_test_dead_line_holds_tips()
	_test_save_round_trip()

	a.report("tips", get_tree(), MIN_CHECKS)

# --- setup -------------------------------------------------------------------

func _fresh() -> void:
	gs.street_name = "Tips"
	gs.reset_to_new_game()
	gs.day = 7
	gs.cash = 5000
	# WS-D1 (0.8.0): the hustle rows open on discovery, not on the clock. A
	# tip about a stickup window presumes the player knows what a stickup is.
	gs.hustles_discovered = ["market", "boost", "stickup", "list"]

func _recruit(id: String, tier: int = 1) -> void:
	gs.crew_records[id] = {
		"recruited": true, "status": "active", "tier": tier, "loyalty": 5,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": gs.day,
	}

func _unlock_second_district() -> void:
	if not "downtown" in gs.districts_unlocked:
		gs.districts_unlocked.append("downtown")

## A guaranteed-profitable route, home turf to downtown, on a product both
## districts actually walked a market for — `known_routes()` reads the
## walked board, not the authored anchor, so the fixture writes both.
func _force_profitable_route() -> void:
	_unlock_second_district()
	var here := str(gs.current_district_id)
	(gs.markets[here]["prices"] as Dictionary)["weed"] = 20
	(gs.markets[here]["availability"] as Dictionary)["weed"] = 5
	(gs.markets["downtown"]["prices"] as Dictionary)["weed"] = 20 + int(gs.TravelFare) + 50
	(gs.markets["downtown"]["availability"] as Dictionary)["weed"] = 5

func _tips() -> Object:
	return gm.system("tips")

func _economy() -> Object:
	return gm.system("economy")

# --- 1. seeded determinism ----------------------------------------------------

func _test_budget_determinism() -> void:
	_fresh()
	_recruit("pherris")
	_recruit("eli")
	_unlock_second_district()
	_tips().push_tip(7)
	var first_inbox: Array = gs.phone_inbox.duplicate(true)
	var first_misses: int = int(gs.tip_misses)

	_fresh()
	_recruit("pherris")
	_recruit("eli")
	_unlock_second_district()
	_tips().push_tip(7)
	var second_inbox: Array = gs.phone_inbox.duplicate(true)

	a.eq_str("the same day rolls the same outcome", str(second_inbox), str(first_inbox))
	a.eq_int("and leaves the same drought counter", int(gs.tip_misses), first_misses)

# --- 2. the budget cap --------------------------------------------------------

func _test_budget_cap_per_day() -> void:
	_fresh()
	_recruit("pherris")
	_recruit("eli")
	_recruit("tone")
	_unlock_second_district()
	gs.stick_tier = 3
	var one_generator_fired := false
	var two_generators_never_fired := true
	for day in range(1, 41):
		gs.day = day
		# Emptied per day so the delta reads the GENERATOR, not the inbox cap:
		# 40 days of tips overflows PHONE_INBOX_MAX partway through, and a push
		# into a full inbox moves its size by zero (v22, the scrolling fix).
		gs.phone_inbox = []
		var before: int = gs.phone_inbox.size()
		_tips().push_tip(day)
		var delta: int = gs.phone_inbox.size() - before
		# Pherris' own double-text is one generator, two messages — the cap is
		# on how many GENERATORS a day can draw, not on message count.
		if delta > 0:
			one_generator_fired = true
		if delta > 2:
			two_generators_never_fired = false
	a.check("at least one of 40 days fires with everyone eligible", one_generator_fired)
	a.check("no day ever pushes more than one generator's worth of texts",
		two_generators_never_fired)

# --- 3. ramp bounds + quiet fraction ------------------------------------------

func _test_ramp_bounds_and_quiet_fraction() -> void:
	_fresh()
	_recruit("pherris")
	_recruit("eli")
	_recruit("tone")
	_unlock_second_district()
	gs.stick_tier = 3
	var ceiling: int = int(TIP_EVENTS.miss_ceiling())
	var quiet_days := 0
	var total_days := 60
	for day in range(1, total_days + 1):
		gs.day = day
		# Same reset as the budget test above, same reason: a day that fired
		# into a capped-full inbox would read as quiet and poison the fraction.
		gs.phone_inbox = []
		var before: int = gs.phone_inbox.size()
		a.check("tip_misses stays within [0, ceiling] on day %d" % day,
			int(gs.tip_misses) >= 0 and int(gs.tip_misses) <= ceiling)
		_tips().push_tip(day)
		if gs.phone_inbox.size() == before:
			quiet_days += 1
	var fraction: float = float(quiet_days) / float(total_days)
	a.check("quiet fraction over %d days lands in the designed band (got %f)"
			% [total_days, fraction],
		fraction >= 0.20 and fraction <= 0.60)

# --- 4. requirement gating -----------------------------------------------------

func _test_pherris_gating() -> void:
	_fresh()
	_force_profitable_route()
	a.eq_bool("no Pherris text without Pherris recruited",
		_tips().pherris_eligible(), false)
	_recruit("pherris")
	a.eq_bool("Pherris eligible once recruited, ranked and a route exists",
		_tips().pherris_eligible(), true)

	_fresh()
	_recruit("pherris")
	_unlock_second_district()
	# Flatten EVERY product to the same price in both districts — not just
	# the one `_force_profitable_route` used. `known_routes()` scans the
	# whole catalogue, and the seeded walk gives some other product a real
	# spread of its own; a fixture that only neutralised weed left that
	# spread standing and the route it implied.
	var here := str(gs.current_district_id)
	for entry in (gs.products as Array):
		var product_id := str((entry as Dictionary)["id"])
		(gs.markets[here]["prices"] as Dictionary)[product_id] = 10
		(gs.markets["downtown"]["prices"] as Dictionary)[product_id] = 10
	a.eq_bool("and nothing without a route worth the fare that actually clears",
		_economy().known_routes().is_empty(), true)

func _test_eli_gating_and_pressure_pick() -> void:
	_fresh()
	_recruit("eli")
	a.eq_bool("no Eli text with only one district unlocked",
		_tips().eli_eligible(), false)
	_unlock_second_district()
	a.eq_bool("Eli eligible once a second corridor exists to name",
		_tips().eli_eligible(), true)

	# The pressure pick itself: raise downtown's market pressure so home turf
	# is unambiguously the safer read, then prove the generated text names
	# the low-pressure district rather than the high one.
	var engine: Object = gm.system("consequence")
	var here := str(gs.current_district_id)
	engine.add_pressure("downtown", RULES.FAMILY_MARKET, 5.0)
	gs.day = 8
	_tips().push_tip(8)
	var texted := false
	for m in gs.phone_inbox:
		if str((m as Dictionary).get("from", "")) == "Eli":
			texted = true
			a.check("Eli names the lower-pressure district, not the raised one",
				str((m as Dictionary).get("text", "")).contains(_district_name(here).to_lower()))
	a.check("an Eli read actually landed to check", texted)

func _district_name(district_id: String) -> String:
	for d in gs.districts:
		if str((d as Dictionary).get("id", "")) == district_id:
			return str((d as Dictionary).get("name", district_id))
	return district_id

func _test_fat_night_gating_by_tier() -> void:
	_fresh()
	gs.stick_tier = 1
	a.eq_bool("no fat-night target above the player's own stick tier",
		_tips().fat_night_targets().is_empty(), true)
	gs.stick_tier = 2
	a.check("tier 2 opens the tier-2 targets",
		not _tips().fat_night_targets().is_empty())
	for entry in _tips().fat_night_targets():
		a.check("every offered target is tier 2 or 3, never tier 1",
			int((entry as Dictionary).get("tier", 0)) >= 2)

	_fresh()
	gs.stick_tier = 3
	# WS-D1 (0.8.0): the row opens on discovery, not on the clock.
	gs.hustles_discovered.erase("stickup")
	a.eq_bool("and nothing before Stickup itself has opened (undiscovered)",
		_tips().fat_night_targets().is_empty(), true)

# --- 5. the payload a driven room actually consumes ---------------------------

func _test_fat_night_payload_consumed_by_a_driven_room() -> void:
	var row: Dictionary = {}
	var found_day := -1
	# A self-contained search, same shape as `confrontation_runner.gd`'s
	# `_find_day` — pinned at the ramp's ceiling so the budget roll's own
	# 85% is the only thing being searched over, not a multi-day walk.
	for day in range(1, 121):
		_fresh()
		_recruit("pherris")
		_recruit("eli")
		_recruit("tone")
		_unlock_second_district()
		gs.stick_tier = 3
		gs.tip_misses = int(TIP_EVENTS.miss_ceiling())
		gs.day = day
		_tips().push_tip(day)
		for entry in (gs.tip_effects as Array):
			if str((entry as Dictionary).get("type", "")) == "fat_night":
				row = entry
				found_day = day
				break
		if found_day > 0:
			break
	a.check("a fat-night row exists within the search window", found_day > 0)
	if found_day <= 0:
		return

	var target_id: String = str(row.get("target_id", ""))
	var multiplier: float = float(row.get("multiplier", 1.0))
	var slots: Array = row.get("slots", [])
	var target: Dictionary = gs.stick_target_by_id(target_id)
	a.check("the row names a real T2/T3 target", int(target.get("tier", 0)) >= 2)

	gs.current_district_id = str(target.get("area", gs.current_district_id))
	gs.time_slots_today = int(slots[0]) if not slots.is_empty() else 2
	var band: Array = target["take"]
	var key := "stickup:%d:%d:%s:take" % [gs.day, gs.time_slots_today, target_id]
	var base_roll: int = rng.seeded_int_range(gs.run_seed, key, int(band[0]), int(band[1]))
	var expected: int = maxi(1, int(round(float(base_roll) * multiplier)))

	a.check("the room opens clean", gm.dispatch("stickup", {"target_id": target_id}))
	var loop: Dictionary = LOOP.loop_of(gs.active_consequence)
	a.eq_int("the realised take is the base roll times the tip multiplier",
		int(loop.get("take_total", 0)), expected)
	a.check("multiplier actually moved the take off the unscaled roll",
		int(loop.get("take_total", 0)) != base_roll or base_roll == expected)

# --- 6. the dead line ----------------------------------------------------------

func _test_dead_line_holds_tips() -> void:
	var fired := false
	for attempt in range(1, 21):
		_fresh()
		_recruit("pherris")
		_force_profitable_route()
		gs.tip_misses = int(TIP_EVENTS.miss_ceiling())
		gs.phone_active = false
		gs.day = attempt
		var before: int = gs.phone_held_inbox.size()
		_tips().push_tip(attempt)
		if gs.phone_held_inbox.size() > before:
			fired = true
			a.eq_int("a dead-line tip touches the live inbox not at all",
				gs.phone_inbox.size(), 0)
			break
	a.check("a dead-line tip landed in the held inbox within 20 attempts", fired)

# --- 7. save round-trip --------------------------------------------------------

func _test_save_round_trip() -> void:
	# The real capture/_apply pair, JSON round-tripped, same shape
	# `territory_runner.gd::_test_save_round_trip` uses — proof against the
	# actual save path rather than against the validator standing in for it.
	_fresh()
	gs.tip_effects = [{"type": "fat_night", "target_id": "rec_center_dice",
		"day": 7, "slots": [2, 3], "multiplier": 2.5}]
	gs.tip_misses = 2

	var save_system: Node = get_node("/root/SaveSystem")
	var captured: Dictionary = save_system.capture()
	var text: String = JSON.stringify(captured)
	var restored: Variant = JSON.parse_string(text)
	a.check("the captured state survives JSON", restored is Dictionary)

	_fresh()
	save_system._apply(restored as Dictionary)

	a.eq_int("tip_misses survives the round trip", int(gs.tip_misses), 2)
	var rows: Array = gs.tip_effects
	a.eq_int("tip_effects keeps its one row", rows.size(), 1)
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		a.eq_str("the row's type survives", str(row.get("type", "")), "fat_night")
		a.eq_str("the row's target survives", str(row.get("target_id", "")), "rec_center_dice")
		a.eq_int("the row's day survives", int(row.get("day", -1)), 7)
		a.near("the row's multiplier survives", float(row.get("multiplier", 0.0)), 2.5)
		var slots: Array = row.get("slots", [])
		a.eq_int("the row keeps both slots", slots.size(), 2)
		if slots.size() == 2:
			a.eq_int("the first slot survives", int(slots[0]), 2)
			a.eq_int("the second slot survives", int(slots[1]), 3)

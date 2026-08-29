extends Node
## Adversarial nested-save-shape suite.
##
## This suite calls the same load-time validator used by SaveSystem and also
## exercises the _migrate -> _validate_nested_shapes seam. It never writes a
## save, so it is safe to run in isolation and proves validation is load-only.

const VALIDATOR := preload("res://autoload/save_validator.gd")
var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	_test_crew_records()
	_test_markets()
	_test_shark_loans()
	_test_observation_queue()
	_test_phone_messages()
	_test_list_holdings()
	_test_consequence_state()
	_test_district_pressure()
	_test_arrest_record()
	_test_v9_fields()
	_test_v10_fields()
	_test_v15_boost_discovery()
	_test_validator_node_lifetime()
	_test_v16_territory_nodes()
	_test_v17_market_discovery()
	_test_v18_boost_bribes_used()
	_test_v19_tips()
	_test_v20_dre_lending()
	_test_v21_dre_intro_offered()
	_test_v22_growth_caps()
	_test_v23_opportunities()
	_test_v24_dre_pending_penance()
	_test_stick_booking_still_validates()
	_test_decision_stage_reload()
	_test_load_pipeline()
	if failures.is_empty():
		print("save_validation: PASS — %d checks, 0 failures" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("save_validation: FAIL — %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(1)

func _check(label: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _state(field: String, value: Variant) -> Dictionary:
	return {"day": 1, "cash": 100, "street_name": "Test", field: value,
		"unknown_top_level": {"must_survive": true}}

func _result(state: Dictionary) -> Dictionary:
	return VALIDATOR.new().validate_state(state)

func _fixed(state: Dictionary) -> Dictionary:
	return _result(state)["state"] as Dictionary

func _test_crew_records() -> void:
	var original := _state("crew_records", {"eli": {"recruited": true, "unknown": "keep"}})
	var fixed := _fixed(original)
	var record: Dictionary = fixed["crew_records"]["eli"]
	_check("crew record remains a dictionary", record is Dictionary)
	_check("crew status defaults", record.get("status", "") == "active")
	_check("crew tier defaults", int(record.get("tier", -1)) == 1)
	_check("crew loyalty defaults", int(record.get("loyalty", -1)) == 5)
	_check("crew wage defaults", int(record.get("wage_due", -1)) == 0)
	_check("crew unknown key survives", record.get("unknown", "") == "keep")
	_check("input is not mutated", not (original["crew_records"]["eli"] as Dictionary).has("status"))

func _test_markets() -> void:
	var fixed := _fixed(_state("markets", {"downtown": null, "unknown": {"keep": true}}))
	_check("null market entry is repaired", fixed["markets"]["downtown"] is Dictionary)
	_check("market defaults prices", ((fixed["markets"]["downtown"] as Dictionary).get("prices", {}) as Dictionary).is_empty())
	_check("market unknown district survives", (fixed["markets"]["unknown"] as Dictionary).get("keep", false))

func _test_shark_loans() -> void:
	var fixed := _fixed(_state("shark_loans", [{"id": "bad", "amount": "not-an-int", "due_day": "tomorrow"}]))
	var loan: Dictionary = (fixed["shark_loans"] as Array)[0]
	_check("loan row survives as dictionary", loan is Dictionary)
	_check("loan id repairs to int", loan.get("id", null) is int)
	_check("loan amount repairs to safe int", int(loan.get("amount", -1)) == 0)
	_check("loan due day repairs to safe int", int(loan.get("due_day", -1)) == 0)

func _test_observation_queue() -> void:
	var fixed := _fixed(_state("observation_queue", [{"npc_id": 7, "spec": [], "deliver_on_day": "soon"}, null]))
	var row: Dictionary = (fixed["observation_queue"] as Array)[0]
	_check("observation invalid row is retained safely", row is Dictionary)
	_check("observation npc id defaults", row.get("npc_id", "sentinel") == "")
	_check("observation spec defaults", (row.get("spec", null) as Dictionary).is_empty())
	_check("observation day defaults", int(row.get("deliver_on_day", -1)) == 0)
	_check("observation null row is dropped", (fixed["observation_queue"] as Array).size() == 1)

func _test_phone_messages() -> void:
	var fixed := _fixed(_state("phone_inbox", [{"id": 7, "from": null, "text": "ok", "day": "today", "slot": 1, "read": "no"}]))
	var message: Dictionary = (fixed["phone_inbox"] as Array)[0]
	_check("phone message remains a dictionary", message is Dictionary)
	_check("phone id defaults", message.get("id", "sentinel") == "")
	_check("phone sender defaults", message.get("from", "sentinel") == "")
	_check("phone day defaults", int(message.get("day", -1)) == 0)
	_check("phone read defaults", not bool(message.get("read", true)))

func _test_list_holdings() -> void:
	var fixed := _fixed(_state("list_holdings", [{"item_id": {"bad": true}, "bought_day": "yesterday"}, 7]))
	var holding: Dictionary = (fixed["list_holdings"] as Array)[0]
	_check("holding remains a dictionary", holding is Dictionary)
	_check("holding item id defaults", holding.get("item_id", "sentinel") == "")
	_check("holding day defaults", int(holding.get("bought_day", 0)) == -1)
	_check("holding source defaults", holding.get("source", "") == "player")
	_check("invalid holding row is dropped", (fixed["list_holdings"] as Array).size() == 1)

func _test_consequence_state() -> void:
	var state := _state("active_consequence", {
		"stage": [], "source": null, "decision": {"result": "bad"},
		"time": {"source_time_settled": "no"}, "unknown": "keep",
	})
	state["consequence_history"] = {"cause:bad": {"effect_receipts": "not-array"}}
	state["consequence_queue"] = [null, {"queue_id": 7}]
	var fixed := _fixed(state)
	var chain: Dictionary = fixed["active_consequence"]
	_check("active chain remains a dictionary", chain is Dictionary)
	_check("active stage defaults", chain.get("stage", "sentinel") == "")
	_check("active source defaults", ((chain.get("source", {}) as Dictionary).is_empty()))
	_check("active decision result defaults", ((chain["decision"] as Dictionary).get("result", {}) as Dictionary).is_empty())
	_check("active unknown key survives", chain.get("unknown", "") == "keep")
	_check("history receipts repair to array", ((fixed["consequence_history"]["cause:bad"] as Dictionary).get("effect_receipts", null) is Array))
	_check("null consequence queue row drops", (fixed["consequence_queue"] as Array).size() == 1)
	_check("queue id repairs to string", ((fixed["consequence_queue"] as Array)[0] as Dictionary).get("queue_id", null) is String)

func _test_district_pressure() -> void:
	var fixed := _fixed(_state("district_pressure", {"downtown": {"stick": {"score": "hot"}}}))
	var row: Dictionary = ((fixed["district_pressure"]["downtown"] as Dictionary)["stick"] as Dictionary)
	_check("pressure score defaults", float(row.get("score", -1.0)) == 0.0)
	_check("pressure last gain defaults", row.get("last_gain_day", null) is int)
	_check("pressure quiet days defaults", row.get("quiet_days", null) is int)
	_check("pressure market fields default", row.get("market_gain_today", null) is float)

func _test_arrest_record() -> void:
	var fixed := _fixed(_state("arrest_record", {"priors": "three", "last_arrest_day": null, "charges": [null, {"unknown": true}]}))
	var record: Dictionary = fixed["arrest_record"]
	_check("arrest priors default", int(record.get("priors", -1)) == 0)
	_check("arrest day default", int(record.get("last_arrest_day", 0)) == -1)
	_check("invalid charge drops", (record["charges"] as Array).size() == 1)
	_check("charge unknown key survives", ((record["charges"] as Array)[0] as Dictionary).get("unknown", false))

func _test_v9_fields() -> void:
	var valid := _state("arrest_record", {
		"priors": 1, "last_arrest_day": 8, "charges": [], "cooldown_until_day": 12,
	})
	valid["consequence_flags"] = {
		"retaliation_first_expiry_seen": true,
		"retaliation_last_ambient_day": 14,
		"future_flag": "preserve",
	}
	var valid_result := _result(valid)
	var valid_fixed: Dictionary = valid_result["state"]
	var valid_record: Dictionary = valid_fixed["arrest_record"]
	var valid_flags: Dictionary = valid_fixed["consequence_flags"]
	_check("valid v9 cooldown remains unchanged", int(valid_record["cooldown_until_day"]) == 12)
	_check("valid v9 retaliation expiry flag remains unchanged", valid_flags["retaliation_first_expiry_seen"] is bool and valid_flags["retaliation_first_expiry_seen"] == true)
	_check("valid v9 ambient day remains unchanged", int(valid_flags["retaliation_last_ambient_day"]) == 14)
	_check("valid v9 unknown flag survives", valid_flags.get("future_flag", "") == "preserve")
	_check("valid v9 shape is a validation no-op", (valid_result["repairs"] as Array).is_empty())
	_check("valid v9 payload remains byte-shape equivalent", valid_fixed == valid)

	var wrong_type := _state("arrest_record", {
		"cooldown_until_day": "tomorrow", "charges": [],
	})
	wrong_type["consequence_flags"] = {
		"retaliation_first_expiry_seen": "yes",
		"retaliation_last_ambient_day": "never",
	}
	var wrong_fixed: Dictionary = _fixed(wrong_type)
	_check("wrong-type cooldown defaults inactive", int((wrong_fixed["arrest_record"] as Dictionary)["cooldown_until_day"]) == -1)
	_check("wrong-type expiry flag defaults false", (wrong_fixed["consequence_flags"] as Dictionary)["retaliation_first_expiry_seen"] is bool and not (wrong_fixed["consequence_flags"] as Dictionary)["retaliation_first_expiry_seen"])
	_check("wrong-type ambient day defaults inactive", int((wrong_fixed["consequence_flags"] as Dictionary)["retaliation_last_ambient_day"]) == -1)

	var out_of_range := _state("arrest_record", {
		"cooldown_until_day": -2, "charges": [],
	})
	out_of_range["consequence_flags"] = {"retaliation_last_ambient_day": -2}
	var range_fixed: Dictionary = _fixed(out_of_range)
	_check("out-of-range cooldown defaults inactive", int((range_fixed["arrest_record"] as Dictionary)["cooldown_until_day"]) == -1)
	_check("out-of-range ambient day defaults inactive", int((range_fixed["consequence_flags"] as Dictionary)["retaliation_last_ambient_day"]) == -1)

	var v8_missing := _state("arrest_record", {"priors": 0, "last_arrest_day": -1, "charges": []})
	var missing_result := _result(v8_missing)
	_check("v8 missing consequence flags does not crash", missing_result["state"] is Dictionary)
	_check("v8 missing consequence flags remains absent for migration defaults", not (missing_result["state"] as Dictionary).has("consequence_flags"))

	var wrong_flags := _state("consequence_flags", "not-a-dictionary")
	var wrong_flags_fixed: Dictionary = _fixed(wrong_flags)
	_check("wrong-type consequence flags default to dictionary", wrong_flags_fixed["consequence_flags"] is Dictionary)

## v10: the surface-visibility facts and the HOT lever's within-day ledger.
##
## The three of them fail in different directions, which is why they get three
## arms rather than one. A malformed `districts_unlocked` can strand the player
## outside their own home turf; a negative `job_contacts` reads as zero right up
## until somebody writes a gate that tests `!= 0`; and a negative clean credit
## would ADD Pressure at settlement, which is the exact opposite of the lever.
func _test_v10_fields() -> void:
	# A valid payload is a no-op, byte-shape identical.
	var valid := _state("districts_unlocked", ["north_star_lot", "downtown"])
	valid["job_contacts"] = 2
	valid["pressure_clean_credits"] = {"north_star_lot": {"boost": 0.5}}
	var valid_result := _result(valid)
	var valid_fixed: Dictionary = valid_result["state"]
	_check("valid v10 districts survive", valid_fixed["districts_unlocked"] == ["north_star_lot", "downtown"])
	_check("valid v10 job contacts survive", int(valid_fixed["job_contacts"]) == 2)
	_check("valid v10 credits survive", is_equal_approx(float((valid_fixed["pressure_clean_credits"] as Dictionary)["north_star_lot"]["boost"]), 0.5))
	_check("valid v10 shape is a validation no-op", (valid_result["repairs"] as Array).is_empty())
	_check("valid v10 payload remains byte-shape equivalent", valid_fixed == valid)

	# Wrong types at the top of each field.
	var wrong := _state("districts_unlocked", "spenard")
	wrong["job_contacts"] = "two"
	wrong["pressure_clean_credits"] = ["not", "a", "dict"]
	var wrong_fixed: Dictionary = _fixed(wrong)
	_check("wrong-type districts default to home turf", wrong_fixed["districts_unlocked"] == ["north_star_lot"])
	_check("wrong-type job contacts default to none", int(wrong_fixed["job_contacts"]) == 0)
	_check("wrong-type credits default to empty", wrong_fixed["pressure_clean_credits"] is Dictionary and (wrong_fixed["pressure_clean_credits"] as Dictionary).is_empty())

	# Rows inside the district list: non-strings dropped, duplicates dropped,
	# and home turf restored if the save somehow lost it.
	var rows := _state("districts_unlocked", ["downtown", 7, "downtown", "", null, "airport_industrial"])
	var rows_fixed: Dictionary = _fixed(rows)
	_check("non-string district rows drop", not 7 in (rows_fixed["districts_unlocked"] as Array))
	_check("empty district rows drop", not "" in (rows_fixed["districts_unlocked"] as Array))
	_check("duplicate district rows drop", (rows_fixed["districts_unlocked"] as Array).count("downtown") == 1)
	_check("home turf is restored when missing", (rows_fixed["districts_unlocked"] as Array)[0] == "north_star_lot")
	_check("real districts survive the sweep", "airport_industrial" in (rows_fixed["districts_unlocked"] as Array))

	# Negatives, on both fields that can hold one.
	var negative := _state("job_contacts", -3)
	negative["pressure_clean_credits"] = {"downtown": {"stick": -2.0}}
	var negative_fixed: Dictionary = _fixed(negative)
	_check("negative job contacts default to none", int(negative_fixed["job_contacts"]) == 0)
	_check("a negative credit cannot add pressure", is_equal_approx(float((negative_fixed["pressure_clean_credits"] as Dictionary)["downtown"]["stick"]), 0.0))

	# A malformed family map under a real district.
	var nested := _state("pressure_clean_credits", {"downtown": "not-a-family-map"})
	var nested_fixed: Dictionary = _fixed(nested)
	_check("malformed credit family map defaults", (nested_fixed["pressure_clean_credits"] as Dictionary)["downtown"] is Dictionary)
	var wrong_credit := _state("pressure_clean_credits", {"downtown": {"boost": "half"}})
	var wrong_credit_fixed: Dictionary = _fixed(wrong_credit)
	_check("wrong-type credit defaults to nothing owed", is_equal_approx(float((wrong_credit_fixed["pressure_clean_credits"] as Dictionary)["downtown"]["boost"]), 0.0))

	# Absent is not malformed: a v9 save reaches this validator with none of the
	# three, and must come out with none of them so _apply() supplies defaults.
	var absent := _state("day", 4)
	var absent_result := _result(absent)
	var absent_fixed: Dictionary = absent_result["state"]
	_check("absent v10 districts stay absent", not absent_fixed.has("districts_unlocked"))
	_check("absent v10 job contacts stay absent", not absent_fixed.has("job_contacts"))
	_check("absent v10 credits stay absent", not absent_fixed.has("pressure_clean_credits"))
	_check("absent v10 fields need no repair", (absent_result["repairs"] as Array).is_empty())

## v15: the Boost discovery latch.
##
## Repaired against the AUTHORED CATALOGUE rather than against a shape, which is
## what makes this arm different from every array arm above it. `wander_recent`
## holds card ids and a bogus one costs nothing — it fails to match and the card
## comes up again. A bogus BOOST target id is load-bearing in the other
## direction: `blocker()` tests membership in this list before it looks the
## target up, so an id nothing in the catalogue carries would pass the discovery
## gate and then resolve to `{}` in `boost_target_by_id`. Dropping it is the only
## repair with a true history behind it — a run that never discovered a place
## that does not exist.
##
## SABOTAGE: drop the `authored.has()` branch -> "an unknown target id drops"
##           fails and a fabricated id survives into the run.
## SABOTAGE: return early instead of defaulting on a wrong type -> "a wrong-type
##           latch defaults to nothing clocked" fails.
func _test_v15_boost_discovery() -> void:
	# A valid payload is a no-op, byte-shape identical. Two real ids from the
	# authored table, which is the shape a real save carries.
	var valid := _state("boost_targets_discovered", ["night_owl", "northern_value"])
	var valid_result := _result(valid)
	var valid_fixed: Dictionary = valid_result["state"]
	_check("valid v15 latch survives",
		valid_fixed["boost_targets_discovered"] == ["night_owl", "northern_value"])
	_check("valid v15 shape is a validation no-op",
		(valid_result["repairs"] as Array).is_empty())
	_check("valid v15 payload remains byte-shape equivalent", valid_fixed == valid)

	# Wrong type at the top.
	var wrong := _fixed(_state("boost_targets_discovered", "night_owl"))
	_check("a wrong-type latch defaults to nothing clocked",
		wrong["boost_targets_discovered"] is Array
		and (wrong["boost_targets_discovered"] as Array).is_empty())

	# Rows: non-strings, empties, duplicates and ids no catalogue carries.
	var rows := _fixed(_state("boost_targets_discovered",
		["night_owl", 7, "night_owl", "", null, "a_shop_that_never_was",
		"spenard_fuel"]))
	var clocked: Array = rows["boost_targets_discovered"]
	_check("a non-string target id drops", not 7 in clocked)
	_check("an empty target id drops", not "" in clocked)
	_check("a duplicate target id drops", clocked.count("night_owl") == 1)
	_check("an unknown target id drops", not "a_shop_that_never_was" in clocked)
	_check("real target ids survive the sweep",
		"night_owl" in clocked and "spenard_fuel" in clocked)
	_check("the sweep keeps only what it should", clocked.size() == 2)

	# Absent is not malformed: a v14 save reaches this validator without the
	# field and must come out without it, so `_apply()` supplies the default.
	var absent_result := _result(_state("day", 4))
	_check("an absent v15 latch stays absent",
		not (absent_result["state"] as Dictionary).has("boost_targets_discovered"))
	_check("an absent v15 latch needs no repair",
		(absent_result["repairs"] as Array).is_empty())

	# And the migration itself: a v14 payload comes through the real chain with
	# an empty latch, not a missing one and not a guessed one.
	var save_system: Node = get_node("/root/SaveSystem")
	var v14: Dictionary = save_system._migrate({"save_version": 14,
		"state": _state("boost_daily_hits", {"night_owl": 3})})
	_check("a v14 save migrates", not v14.is_empty())
	_check("and arrives with nothing clocked",
		not v14.has("boost_targets_discovered")
		or (v14["boost_targets_discovered"] as Array).is_empty())

## 0.1.2 PR D: `_validate_boost_bribes_used`, same shape as
## `_validate_boost_discovery` above and for the same reason -- every entry
## must be a real target id, and (unlike a discovery latch) a store bought
## from twice would be a bribe that quietly worked as extortion.
##
## SABOTAGE: drop the `authored.has()` branch -> "an unknown target id drops"
##           fails and a fabricated id survives into the run.
## SABOTAGE: return early instead of defaulting on a wrong type -> "a wrong-type
##           latch defaults to nothing bought" fails.
func _test_v18_boost_bribes_used() -> void:
	var valid := _state("boost_bribes_used", ["night_owl", "northern_value"])
	var valid_result := _result(valid)
	var valid_fixed: Dictionary = valid_result["state"]
	_check("valid v18 latch survives",
		valid_fixed["boost_bribes_used"] == ["night_owl", "northern_value"])
	_check("valid v18 shape is a validation no-op",
		(valid_result["repairs"] as Array).is_empty())
	_check("valid v18 payload remains byte-shape equivalent", valid_fixed == valid)

	var wrong := _fixed(_state("boost_bribes_used", "night_owl"))
	_check("a wrong-type latch defaults to nothing bought",
		wrong["boost_bribes_used"] is Array
		and (wrong["boost_bribes_used"] as Array).is_empty())

	var rows := _fixed(_state("boost_bribes_used",
		["night_owl", 7, "night_owl", "", null, "a_shop_that_never_was",
		"spenard_fuel"]))
	var bought: Array = rows["boost_bribes_used"]
	_check("a non-string target id drops", not 7 in bought)
	_check("an empty target id drops", not "" in bought)
	_check("a duplicate target id drops", bought.count("night_owl") == 1)
	_check("an unknown target id drops", not "a_shop_that_never_was" in bought)
	_check("real target ids survive the sweep",
		"night_owl" in bought and "spenard_fuel" in bought)
	_check("the sweep keeps only what it should", bought.size() == 2)

	var absent_result := _result(_state("day", 4))
	_check("an absent v18 latch stays absent",
		not (absent_result["state"] as Dictionary).has("boost_bribes_used"))
	_check("an absent v18 latch needs no repair",
		(absent_result["repairs"] as Array).is_empty())

	# The migration itself: a v17 payload comes through the real chain with an
	# empty latch, not a missing one and not a guessed one -- purely additive,
	# since SETTLE IT did not exist before this build.
	var save_system: Node = get_node("/root/SaveSystem")
	var v17: Dictionary = save_system._migrate({"save_version": 17,
		"state": _state("market_discovered", true)})
	_check("a v17 save migrates", not v17.is_empty())
	_check("and arrives with nothing bought",
		not v17.has("boost_bribes_used")
		or (v17["boost_bribes_used"] as Array).is_empty())

## SaveValidator used to call `GAME_STATE.new()` independently for the Boost
## discovery and bribe catalogues without freeing either Node. A load then
## leaked two complete state objects while every harness still printed PASS.
## Count live Nodes around repeated validations so this remains a lifecycle
## contract rather than something visible only in Godot's shutdown warning.
func _test_validator_node_lifetime() -> void:
	var before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for _probe in range(3):
		var state := _state("boost_targets_discovered", ["night_owl"])
		state["boost_bribes_used"] = ["night_owl"]
		_fixed(state)
	var after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check("save validation releases temporary GameState nodes", after == before)

## 0.1.2 (Word of Mouth): `tip_effects` (a row per active payload) and
## `tip_misses` (the ramp counter), same two-field split as v9's arrest
## record and v18's latch -- one array of rows, one clamped int.
func _test_v19_tips() -> void:
	var valid_row := {"type": "fat_night", "target_id": "rec_center_dice",
		"day": 12, "slots": [2, 3], "multiplier": 2.5}
	var valid_result := _result(_state("tip_effects", [valid_row]))
	var valid_fixed: Dictionary = valid_result["state"]
	_check("a valid tip_effects row survives",
		(valid_fixed["tip_effects"] as Array) == [valid_row])
	_check("a valid tip_effects shape is a validation no-op",
		(valid_result["repairs"] as Array).is_empty())

	var wrong := _fixed(_state("tip_effects", "fat_night"))
	_check("a wrong-type tip_effects defaults to no active tips",
		wrong["tip_effects"] is Array and (wrong["tip_effects"] as Array).is_empty())

	var swept := _fixed(_state("tip_effects", [
		"not_a_row",
		{"type": "fat_night", "target_id": "goodie_stash", "day": 9,
			"slots": ["two", 3, null], "multiplier": "a lot"},
	]))
	var rows: Array = swept["tip_effects"]
	_check("a non-dictionary row drops", rows.size() == 1)
	var repaired: Dictionary = rows[0]
	_check("target_id survives on the kept row",
		str(repaired.get("target_id", "")) == "goodie_stash")
	_check("a wrong-type multiplier defaults rather than dropping the row",
		float(repaired.get("multiplier", -1.0)) == 1.0)
	var slots: Array = repaired.get("slots", [])
	_check("bad slot entries drop, the real one survives",
		slots.size() == 1 and int(slots[0]) == 3)

	var ceiling: int = int(preload("res://data/tip_events.gd").miss_ceiling())
	_check("tip_misses within range passes untouched",
		int(_fixed(_state("tip_misses", 1))["tip_misses"]) == 1)
	_check("a negative tip_misses defaults to zero",
		int(_fixed(_state("tip_misses", -3))["tip_misses"]) == 0)
	_check("tip_misses beyond the ramp's own ceiling clamps",
		int(_fixed(_state("tip_misses", ceiling + 50))["tip_misses"]) == ceiling)
	_check("a wrong-type tip_misses defaults to zero",
		int(_fixed(_state("tip_misses", "a lot"))["tip_misses"]) == 0)

	var absent_result := _result(_state("day", 4))
	_check("an absent tip_effects stays absent",
		not (absent_result["state"] as Dictionary).has("tip_effects"))
	_check("an absent tip_misses stays absent",
		not (absent_result["state"] as Dictionary).has("tip_misses"))

	# Purely additive, same as v18: Word of Mouth did not exist before this
	# build, so a v18 save never had a live window or a drought running.
	var save_system: Node = get_node("/root/SaveSystem")
	var v18: Dictionary = save_system._migrate({"save_version": 18,
		"state": _state("boost_bribes_used", [])})
	_check("a v18 save migrates", not v18.is_empty())
	_check("and arrives with no active tip",
		v18.has("tip_effects") and (v18["tip_effects"] as Array).is_empty())
	_check("and arrives with no drought yet",
		v18.has("tip_misses") and int(v18["tip_misses"]) == 0)

## Dre Lending & Loan-Shark Progression, PR A (0.1.2, v20): `dre_introduced`,
## `dre_access_tier`, `dre_account` (a closed six-state machine, unlike a
## tip's open-ended `type`), and `dre_account_history`.
func _test_v20_dre_lending() -> void:
	var valid_account := {"status": "active", "principal": 1000, "interest": 200,
		"fee": 0, "opened_day": 3, "due_day": 8, "term_days": 5,
		"extension_used": false, "offer_id": "first_loan"}
	var valid := _state("dre_account", valid_account)
	valid["dre_introduced"] = true
	valid["dre_access_tier"] = 1
	valid["dre_account_history"] = {"loans_taken": 1, "repaid_on_time": 0,
		"repaid_late": 0, "extensions": 0, "defaults": 0,
		"total_principal_borrowed": 1000, "total_interest_paid": 0}
	var valid_result := _result(valid)
	var valid_fixed: Dictionary = valid_result["state"]
	_check("a valid dre_account survives", valid_fixed["dre_account"] == valid_account)
	_check("valid dre_introduced survives", valid_fixed["dre_introduced"] == true)
	_check("valid dre_access_tier survives", int(valid_fixed["dre_access_tier"]) == 1)
	_check("a valid dre shape is a validation no-op",
		(valid_result["repairs"] as Array).is_empty())

	# Wrong types at the top of each field.
	var wrong := _state("dre_account", "not-a-dict")
	wrong["dre_introduced"] = "yes"
	wrong["dre_access_tier"] = "one"
	wrong["dre_account_history"] = "not-a-dict-either"
	var wrong_fixed: Dictionary = _fixed(wrong)
	_check("a non-Dictionary dre_account defaults to clear",
		str((wrong_fixed["dre_account"] as Dictionary)["status"]) == "clear")
	_check("a non-bool dre_introduced coerces rather than crashing",
		wrong_fixed["dre_introduced"] is bool)
	_check("a non-numeric dre_access_tier defaults to 0",
		int(wrong_fixed["dre_access_tier"]) == 0)
	_check("a non-Dictionary dre_account_history defaults empty",
		int((wrong_fixed["dre_account_history"] as Dictionary)["loans_taken"]) == 0)

	# The tier ceiling: 0-5 (design doc section 7), clamped not defaulted.
	_check("an out-of-range tier clamps to the ceiling",
		int(_fixed(_state("dre_access_tier", 99))["dre_access_tier"]) == 5)
	_check("a negative tier clamps to the floor",
		int(_fixed(_state("dre_access_tier", -3))["dre_access_tier"]) == 0)

	# The closed status enum: an unrecognised status is not just a wrong
	# type, it is a debt the game would never be able to settle again.
	var bad_status := valid_account.duplicate()
	bad_status["status"] = "haunted"
	var bad_status_fixed: Dictionary = _fixed(_state("dre_account", bad_status))
	var repaired_account: Dictionary = bad_status_fixed["dre_account"]
	_check("an unrecognised status repairs to clear",
		str(repaired_account["status"]) == "clear")
	_check("a repaired-to-clear account has its principal zeroed",
		int(repaired_account["principal"]) == 0)
	_check("a repaired-to-clear account has its interest zeroed",
		int(repaired_account["interest"]) == 0)
	_check("a repaired-to-clear account has its fee zeroed",
		int(repaired_account["fee"]) == 0)

	# Negative money on an otherwise-valid active account.
	var negative_money := valid_account.duplicate()
	negative_money["principal"] = -500
	negative_money["fee"] = -10
	var negative_fixed: Dictionary = _fixed(_state("dre_account", negative_money))
	var negative_account: Dictionary = negative_fixed["dre_account"]
	_check("a negative principal defaults to zero", int(negative_account["principal"]) == 0)
	_check("a negative fee defaults to zero", int(negative_account["fee"]) == 0)
	_check("interest untouched by the sweep survives",
		int(negative_account["interest"]) == 200)

	# Negative lifetime counters.
	var negative_history := _fixed(_state("dre_account_history",
		{"loans_taken": -1, "repaid_on_time": 0, "repaid_late": 0, "extensions": 0,
			"defaults": 0, "total_principal_borrowed": -1000, "total_interest_paid": 0}))
	var history_fixed: Dictionary = negative_history["dre_account_history"]
	_check("a negative loans_taken defaults to zero", int(history_fixed["loans_taken"]) == 0)
	_check("a negative lifetime total defaults to zero",
		int(history_fixed["total_principal_borrowed"]) == 0)

	# Absent is not malformed: a v19 save reaches this validator with none of
	# the four and must come out with none of them, so `_apply()` supplies
	# GameState's own defaults.
	var absent_result := _result(_state("day", 4))
	var absent_state: Dictionary = absent_result["state"]
	_check("an absent dre_account stays absent", not absent_state.has("dre_account"))
	_check("an absent dre_introduced stays absent", not absent_state.has("dre_introduced"))
	_check("an absent dre_access_tier stays absent", not absent_state.has("dre_access_tier"))
	_check("an absent dre_account_history stays absent",
		not absent_state.has("dre_account_history"))
	_check("absent dre fields need no repair", (absent_result["repairs"] as Array).is_empty())

	# The migration itself, through the real chain: a v19 payload carrying
	# the legacy debt fields comes back with a structured account and the
	# two old keys gone, not lingering unread.
	var save_system: Node = get_node("/root/SaveSystem")
	var zero_debt := _state("day", 4)
	zero_debt["debt"] = 0
	zero_debt["debt_due_days"] = 0
	var v19_zero: Dictionary = save_system._migrate({"save_version": 19, "state": zero_debt})
	_check("a v19 save with no debt migrates", not v19_zero.is_empty())
	_check("and arrives with a clear account",
		str((v19_zero.get("dre_account", {}) as Dictionary).get("status", "")) == "clear")
	_check("and the legacy keys are gone, not just unread",
		not v19_zero.has("debt") and not v19_zero.has("debt_due_days"))

	var positive_debt := _state("day", 4)
	positive_debt["debt"] = 900
	positive_debt["debt_due_days"] = 2
	var v19_positive: Dictionary = save_system._migrate({"save_version": 19,
		"state": positive_debt})
	_check("a v19 save with positive debt migrates", not v19_positive.is_empty())
	_check("and arrives with an active account carrying the whole amount as principal",
		int((v19_positive.get("dre_account", {}) as Dictionary).get("principal", -1)) == 900)
	_check("and arrives introduced", bool(v19_positive.get("dre_introduced", false)))

## Dre Lending & Loan-Shark Progression, PR B (0.1.2, v21): `dre_intro_offered`.
func _test_v21_dre_intro_offered() -> void:
	var valid_result := _result(_state("dre_intro_offered", true))
	_check("a valid dre_intro_offered survives",
		(valid_result["state"] as Dictionary)["dre_intro_offered"] == true)
	_check("a valid shape is a validation no-op",
		(valid_result["repairs"] as Array).is_empty())

	var wrong_fixed: Dictionary = _fixed(_state("dre_intro_offered", "yes"))
	_check("a non-bool dre_intro_offered defaults false, not a crash",
		wrong_fixed["dre_intro_offered"] == false)

	var absent_result := _result(_state("day", 4))
	_check("an absent dre_intro_offered stays absent",
		not (absent_result["state"] as Dictionary).has("dre_intro_offered"))

	# The migration itself: a v20 save (PR A already shipped, PR B had not)
	# comes back with the latch derived from whether it already carries an
	# introduction -- see the v20 -> v21 arm's own comment for why that is
	# the honest read rather than a blind default.
	var save_system: Node = get_node("/root/SaveSystem")
	var never_met := _state("dre_introduced", false)
	var v20_never_met: Dictionary = save_system._migrate({"save_version": 20,
		"state": never_met})
	_check("a v20 save that never met Dre migrates", not v20_never_met.is_empty())
	_check("and arrives with no mention on record",
		not bool(v20_never_met.get("dre_intro_offered", true)))

	var already_met := _state("dre_introduced", true)
	var v20_already_met: Dictionary = save_system._migrate({"save_version": 20,
		"state": already_met})
	_check("a v20 save that already met Dre migrates", not v20_already_met.is_empty())
	_check("and arrives with the mention implied by the meeting it already had",
		bool(v20_already_met.get("dre_intro_offered", false)))

## FS-002.3 (`86bbj1jpm`): the first Territory arm in this validator, and the
## root-cause fix for `86bbjxtab` — nothing validated the ids in a loaded
## `held_blocks`/`territory_nodes` before this.
##
## SABOTAGE: comment out the `TERRITORY_DEFS.has_id()` guard in
##           `_validate_territory_nodes` -> "an unknown territory node id is
##           dropped" fails, and the malformed-row check crashes instead of
##           repairing (see the bottom of this function for the crash proof).
func _test_v16_territory_nodes() -> void:
	# A valid payload is a no-op, byte-shape identical — same contract every
	# other v-numbered arm in this file makes.
	var valid := _state("territory_nodes", {
		"wash_and_go_lot": {"soldiers": 2}, "fourth_ave_strip": {"soldiers": 1},
	})
	valid["soldiers_idle"] = 3
	var valid_result := _result(valid)
	var valid_fixed: Dictionary = valid_result["state"]
	_check("valid v16 nodes survive", valid_fixed["territory_nodes"] == valid["territory_nodes"])
	_check("valid v16 soldiers_idle survives", int(valid_fixed["soldiers_idle"]) == 3)
	_check("valid v16 shape is a validation no-op", (valid_result["repairs"] as Array).is_empty())
	_check("valid v16 payload remains byte-shape equivalent", valid_fixed == valid)

	# Wrong type at the top.
	var wrong_top := _fixed(_state("territory_nodes", "not-a-dict"))
	_check("a non-Dictionary territory_nodes is defaulted", wrong_top["territory_nodes"] == {})

	# An unknown id — the 86bbjxtab root cause. Dropped, not carried through.
	var unknown := _fixed(_state("territory_nodes", {
		"wash_and_go_lot": {"soldiers": 1}, "a_corner_that_never_was": {"soldiers": 1},
	}))
	var unknown_nodes: Dictionary = unknown["territory_nodes"]
	_check("an unknown territory node id is dropped",
		not "a_corner_that_never_was" in unknown_nodes)
	_check("a known id survives the sweep", "wash_and_go_lot" in unknown_nodes)

	# A malformed row — non-Dictionary. This is the fixture the ticket's own
	# list was missing: today, before this arm, a String here loads clean and
	# crashes the first time `territory.gd:141`-equivalent code indexes it as a
	# Dictionary. The validator drops it instead of trusting it.
	var malformed := _fixed(_state("territory_nodes", {
		"wash_and_go_lot": "not-a-dict-either",
	}))
	var malformed_nodes: Dictionary = malformed["territory_nodes"]
	_check("a non-Dictionary row is dropped rather than crashing the load",
		not "wash_and_go_lot" in malformed_nodes)

	# Soldiers: wrong type, then negative.
	var bad_soldiers := _fixed(_state("territory_nodes", {
		"wash_and_go_lot": {"soldiers": "four"},
	}))
	_check("a non-numeric soldier count defaults to 0",
		int((bad_soldiers["territory_nodes"] as Dictionary)["wash_and_go_lot"]["soldiers"]) == 0)
	var negative_soldiers := _fixed(_state("territory_nodes", {
		"wash_and_go_lot": {"soldiers": -3},
	}))
	_check("a negative soldier count is repaired to 0",
		int((negative_soldiers["territory_nodes"] as Dictionary)["wash_and_go_lot"]["soldiers"]) == 0)

	# The capacity clamp: three held corners cap the roster at 8
	# (2 base + 3*2). A hand-edited save claiming 20 posted must not be trusted
	# to prove its own capacity — the clamp runs off the CLEANED set, in
	# deterministic (sorted-id) order.
	var overcapacity := _fixed(_state("territory_nodes", {
		"spenard_rec_lot": {"soldiers": 20},
		"wash_and_go_lot": {"soldiers": 20},
		"fourth_ave_strip": {"soldiers": 20},
	}))
	var over_nodes: Dictionary = overcapacity["territory_nodes"]
	var total_posted := 0
	for id in over_nodes.keys():
		total_posted += int((over_nodes[id] as Dictionary)["soldiers"])
	_check("a posted sum exceeding capacity is capped at the cleaned capacity (got %d)"
		% total_posted, total_posted == 8)
	_check("the clamp is deterministic: the alphabetically-first id keeps its soldiers",
		int((over_nodes["fourth_ave_strip"] as Dictionary)["soldiers"]) == 8)
	_check("and a later id in sorted order is zeroed out",
		int((over_nodes["spenard_rec_lot"] as Dictionary)["soldiers"]) == 0)

	# soldiers_idle: wrong type, then negative.
	var idle_wrong := _fixed(_state("day", 1))
	idle_wrong["soldiers_idle"] = "none"
	var idle_wrong_fixed := _result(idle_wrong)["state"] as Dictionary
	_check("a non-numeric soldiers_idle defaults to 0", int(idle_wrong_fixed["soldiers_idle"]) == 0)
	var idle_negative := _fixed(_state("day", 1))
	idle_negative["soldiers_idle"] = -5
	var idle_negative_fixed := _result(idle_negative)["state"] as Dictionary
	_check("a negative soldiers_idle is repaired to 0", int(idle_negative_fixed["soldiers_idle"]) == 0)

	# And the migration itself, through the real chain: a v15 payload with a
	# corrupted row loads clean rather than crashing SaveSystem.load_run().
	var save_system: Node = get_node("/root/SaveSystem")
	var v15_state := _state("held_blocks", {
		"wash_and_go_lot": {"soldiers": "bad-type"},
		"fourth_ave_strip": {"soldiers": 2},
	})
	var v15_migrated: Dictionary = save_system._migrate({"save_version": 15, "state": v15_state})
	_check("a v15 save with a bad row migrates", not v15_migrated.is_empty())
	var v15_validated: Dictionary = save_system._validate_nested_shapes(v15_migrated)
	var v15_nodes: Dictionary = v15_validated.get("territory_nodes", {})
	_check("the bad-typed soldier count is repaired through the real pipeline",
		int((v15_nodes.get("wash_and_go_lot", {}) as Dictionary).get("soldiers", -1)) == 0)
	_check("and the good row survives it",
		int((v15_nodes.get("fourth_ave_strip", {}) as Dictionary).get("soldiers", -1)) == 2)

## v17: the Market discovery latch. A plain bool, so there is no shape to
## repair — the interesting case is the migration arm's inherited-history
## rule, which the v16 -> v17 arm in save_system.gd states and this proves:
## a v16 save whose `wander_count` had already cleared the OLD gate
## (>= 1, PR 4's predecessor) comes back with the surface already open, not
## re-hidden, because re-hiding something the player already has is a worse
## failure than the migration doing nothing.
##
## SABOTAGE: remove the v16 -> v17 arm -> `_migrate` returns `{}` for both
##           v16 fixtures below (falls through to the `_:` wildcard).
## SABOTAGE: always stamp `market_discovered = true` in the arm -> the
##           `wander_count == 0` fixture fails.
func _test_v17_market_discovery() -> void:
	var save_system: Node = get_node("/root/SaveSystem")

	# A v16 save that had already walked had already cleared the old gate —
	# the migration preserves what the player already has. _migrate() returns
	# the flattened state dict directly, not a {save_version, state} wrapper.
	var walked: Dictionary = save_system._migrate({"save_version": 16,
		"state": _state("wander_count", 3)})
	_check("a v16 save that had walked migrates", not walked.is_empty())
	_check("and arrives with the market already found",
		bool(walked.get("market_discovered", false)))

	# A v16 save that never walked never cleared the old gate either — under
	# EITHER rule it has not found the market, which is the honest history.
	var never_walked: Dictionary = save_system._migrate({"save_version": 16,
		"state": _state("wander_count", 0)})
	_check("a v16 save that never walked migrates", not never_walked.is_empty())
	_check("and arrives with the market still unfound",
		not bool(never_walked.get("market_discovered", true)))

	# A v17 payload is already current: no migration involved, and the shape
	# validator is a no-op on a plain bool, the same contract every other
	# v-numbered arm in this file makes.
	var current := _state("market_discovered", true)
	var current_result := _result(current)
	var current_fixed: Dictionary = current_result["state"]
	_check("valid v17 latch survives", bool(current_fixed["market_discovered"]))
	_check("valid v17 shape is a validation no-op",
		(current_result["repairs"] as Array).is_empty())
	_check("valid v17 payload remains byte-shape equivalent", current_fixed == current)

## The scrolling-degradation fix (v22): both inbox halves hold
## `GameState.PHONE_INBOX_MAX`, `shark_loans` sheds terminal notes, and the
## consequence layer sheds terminal queue rows and dead-Cause history rows
## (the liveness audit lives on `ConsequenceEngine.prune_settled`).
## The validator clamp is the load-time backstop for the inboxes; the
## v21 -> v22 arm is the one-time application of all of it to a long run's
## save.
##
## SABOTAGE: remove the cap clamp in `_validate_phone_messages` -> "an
## over-cap inbox is trimmed" fails; remove the v21 -> v22 arm -> `_migrate`
## returns `{}` for the v21 payload and every "through the real chain" check
## here fails.
func _test_v22_growth_caps() -> void:
	var cap: int = preload("res://autoload/game_state.gd").PHONE_INBOX_MAX

	var big_inbox: Array = []
	for i in range(cap + 5):
		big_inbox.append({"id": "m%d" % i, "from": "Eli", "text": "line %d" % i,
			"day": i, "slot": 0, "read": false})
	var inbox_result := _result(_state("phone_inbox", big_inbox))
	var trimmed: Array = (inbox_result["state"] as Dictionary)["phone_inbox"]
	_check("an over-cap inbox is trimmed", trimmed.size() == cap)
	_check("the inbox keeps its front — newest-first order",
		str((trimmed[0] as Dictionary)["id"]) == "m0")
	_check("the trim is named in repairs", not (inbox_result["repairs"] as Array).is_empty())

	var held_result := _result(_state("phone_held_inbox", big_inbox.duplicate(true)))
	var held: Array = (held_result["state"] as Dictionary)["phone_held_inbox"]
	_check("an over-cap held inbox is trimmed", held.size() == cap)
	_check("the held inbox keeps its back — oldest-first order",
		str((held[0] as Dictionary)["id"]) == "m5")

	var at_cap := _result(_state("phone_inbox", big_inbox.slice(0, cap)))
	_check("an at-cap inbox is a validation no-op",
		(at_cap["repairs"] as Array).is_empty())

	# The migration itself, through the real chain: a v21 save carrying more
	# than the cap and every loan status comes back bounded, with only the
	# terminal notes gone. A note with no status at all (the pre-canonical
	# fixture shape) is not guessed terminal and survives.
	var save_system: Node = get_node("/root/SaveSystem")
	var v21 := _state("phone_inbox", big_inbox.duplicate(true))
	v21["phone_held_inbox"] = big_inbox.duplicate(true)
	v21["shark_loans"] = [
		{"id": 1, "borrower_id": "nora", "amount": 200, "term": 2,
			"opened_day": 1, "due_day": 3, "status": "active", "risk_label": "STEADY"},
		{"id": 2, "borrower_id": "rico", "amount": 300, "term": 4,
			"opened_day": 1, "due_day": 5, "status": "repaid", "risk_label": "STEADY"},
		{"id": 3, "borrower_id": "vera", "amount": 150, "term": 2,
			"opened_day": 2, "due_day": 4, "status": "defaulted", "risk_label": "SHAKY"},
		{"id": 4, "borrower_id": "nora", "amount": 100, "term": 7,
			"opened_day": 2, "due_day": 9, "status": "enforced", "risk_label": "STEADY"},
		{"id": 5, "borrower": "nora", "principal": 100, "due_day": 3, "term": 2},
	]
	v21["active_consequence"] = {"cause_id": "cause:00000009", "stage": "decision"}
	v21["consequence_queue"] = [
		{"queue_id": "q1", "cause_id": "cause:00000007", "actor_id": "cousin",
			"status": "pending", "trigger_day": 3, "expires_end_day": 6,
			"created_sequence": 1},
		{"queue_id": "q2", "cause_id": "cause:00000005", "actor_id": "cousin",
			"status": "resolved", "trigger_day": 1, "expires_end_day": 4,
			"created_sequence": 2},
		{"queue_id": "q3", "cause_id": "cause:00000003", "actor_id": "cousin",
			"status": "expired", "trigger_day": 1, "expires_end_day": 2,
			"created_sequence": 3},
	]
	v21["consequence_history"] = {
		"cause:00000009": {"effect_receipts": ["commit:x"],
			"resolved_consequence_ids": [], "scheduled_actor_ids": []},
		"cause:00000007": {"effect_receipts": [],
			"resolved_consequence_ids": [], "scheduled_actor_ids": ["cousin"]},
		"cause:00000005": {"effect_receipts": ["room:cash"],
			"resolved_consequence_ids": ["consequence:00000005"],
			"scheduled_actor_ids": ["cousin"]},
		"cause:00000001": {"effect_receipts": ["room:heat"],
			"resolved_consequence_ids": [], "scheduled_actor_ids": []},
	}
	var migrated: Dictionary = save_system._migrate({"save_version": 21, "state": v21})
	_check("a v21 save over the caps migrates", not migrated.is_empty())
	_check("and its inbox arrives at the cap",
		(migrated.get("phone_inbox", []) as Array).size() == cap)
	_check("and its inbox kept the newest — the front",
		str(((migrated["phone_inbox"] as Array)[0] as Dictionary)["id"]) == "m0")
	_check("and its held inbox arrives at the cap",
		(migrated.get("phone_held_inbox", []) as Array).size() == cap)
	_check("and its held inbox kept the newest — the back",
		str(((migrated["phone_held_inbox"] as Array)[0] as Dictionary)["id"]) == "m5")
	var loans: Array = migrated.get("shark_loans", [])
	var kept_ids: Array = []
	for loan in loans:
		kept_ids.append(int((loan as Dictionary).get("id", -1)))
	_check("terminal notes are gone from a migrated save",
		not 2 in kept_ids and not 4 in kept_ids)
	_check("an active note survives migration", 1 in kept_ids)
	_check("a defaulted note survives migration — it is an open decision", 3 in kept_ids)
	_check("a status-less legacy note survives migration", 5 in kept_ids)

	# The consequence layer's half of the arm, same fixture: terminal queue
	# rows leave, and a history row survives only for a Cause something can
	# still address — the active chain's or a pending row's.
	var queue_ids: Array = []
	for row in (migrated.get("consequence_queue", []) as Array):
		queue_ids.append(str((row as Dictionary).get("queue_id", "")))
	_check("a pending queue row survives migration", "q1" in queue_ids)
	_check("resolved and expired queue rows are gone",
		not "q2" in queue_ids and not "q3" in queue_ids)
	var kept_history: Dictionary = migrated.get("consequence_history", {})
	_check("the active chain's history row survives", kept_history.has("cause:00000009"))
	_check("a pending row's history row survives", kept_history.has("cause:00000007"))
	_check("a resolved Cause's history row is gone", not kept_history.has("cause:00000005"))
	_check("an unreferenced Cause's history row is gone",
		not kept_history.has("cause:00000001"))
	_check("a surviving row keeps its receipts untouched",
		str((kept_history.get("cause:00000009", {}) as Dictionary).get(
			"effect_receipts", [])) == str(["commit:x"]))

func _instance(id: int, definition_id: String, state: String) -> Dictionary:
	return {"instance_id": id, "definition_id": definition_id, "state": state,
		"source_context": {}, "offered_day": 3, "offered_slot": -1,
		"accepted_day": -1, "accepted_slot": -1, "deadline_day": -1,
		"deadline_slot": -1, "objective_progress": {}, "resolved_result": {},
		"receipt_id": ""}

func _test_v23_opportunities() -> void:
	# Wrong-type top-level fields default to their empty shape.
	var bad_offers := _fixed(_state("opportunity_offers", "not an array"))
	_check("a malformed opportunity_offers defaults to empty",
		(bad_offers["opportunity_offers"] as Array).is_empty())
	var bad_history := _fixed(_state("opportunity_history", ["not", "a", "dict"]))
	_check("a malformed opportunity_history defaults to empty",
		(bad_history["opportunity_history"] as Dictionary).is_empty())

	# Each array only ever holds its own phase's states -- an offer sitting
	# in `active_opportunities`, or vice versa, is exactly as inconsistent
	# as a shark note with no status, and is repaired the same way: to the
	# one state the array's own name promises.
	var wrong_offer_state := _fixed(_state("opportunity_offers",
		[_instance(1, "dre_first_money", "active")]))
	var offers: Array = wrong_offer_state["opportunity_offers"]
	_check("an offer row claiming 'active' is corrected to 'offered'",
		str((offers[0] as Dictionary)["state"]) == "offered")

	var wrong_active_state := _fixed(_state("active_opportunities",
		[_instance(2, "dre_first_money", "offered")]))
	var active: Array = wrong_active_state["active_opportunities"]
	_check("an active row claiming 'offered' is corrected to 'active'",
		str((active[0] as Dictionary)["state"]) == "active")

	# A ready row is legal in active_opportunities but not in offers.
	var ready_in_active := _fixed(_state("active_opportunities",
		[_instance(3, "dre_first_money", "ready")]))
	_check("'ready' is accepted in active_opportunities",
		str(((ready_in_active["active_opportunities"] as Array)[0] \
			as Dictionary)["state"]) == "ready")

	# Missing nested fields default in rather than dropping the whole row.
	var thin_row := {"instance_id": 4, "definition_id": "dre_first_money",
		"state": "offered"}
	var thin_result := _fixed(_state("opportunity_offers", [thin_row]))
	var thin: Dictionary = (thin_result["opportunity_offers"] as Array)[0]
	_check("a thin offer row is not dropped", thin.get("instance_id", -1) == 4)
	_check("its source_context defaults to an empty dict",
		thin.get("source_context") is Dictionary)
	_check("its objective_progress defaults to an empty dict",
		thin.get("objective_progress") is Dictionary)
	_check("its offered_day defaults rather than staying absent",
		int(thin.get("offered_day", -999)) == -1)

	# opportunity_history rows: outcome is the closed terminal subset of the
	# lifecycle enum, count is never negative.
	var bad_outcome := _fixed(_state("opportunity_history",
		{"dre_first_money": {"outcome": "active", "count": 1, "last_resolved_day": 4}}))
	var history_row: Dictionary = (bad_outcome["opportunity_history"] \
		as Dictionary)["dre_first_money"]
	_check("a live state is not a legal history outcome; corrected to completed",
		str(history_row["outcome"]) == "completed")

	var bad_count := _fixed(_state("opportunity_history",
		{"dre_first_money": {"outcome": "completed", "count": -3, "last_resolved_day": 4}}))
	_check("a negative history count is corrected",
		int(((bad_count["opportunity_history"] as Dictionary)["dre_first_money"] \
			as Dictionary)["count"]) >= 0)

	# The counter never sits behind a live instance's own id -- the same
	# invariant shark_next_loan_id protects, checked here across both arrays.
	var behind := _state("opportunity_next_instance_id", 1)
	behind["active_opportunities"] = [_instance(9, "dre_first_money", "active")]
	var behind_fixed := _fixed(behind)
	_check("a counter behind a live instance id is raised past it",
		int(behind_fixed["opportunity_next_instance_id"]) >= 10)

	var ahead := _state("opportunity_next_instance_id", 40)
	ahead["opportunity_offers"] = [_instance(2, "dre_first_money", "offered")]
	var ahead_fixed := _fixed(ahead)
	_check("a counter already ahead of every live id is left alone",
		int(ahead_fixed["opportunity_next_instance_id"]) == 40)

	# The real migration chain: a v22 save (this build's own predecessor,
	# from the unrelated long-run-memory fix) carries none of these fields
	# at all. The v22 -> v23 arm is purely additive -- it writes nothing
	# itself, the same as the v3 -> v4 / v4 -> v5 arms it follows -- so the
	# whole claim to check here is that a v22 save still migrates cleanly;
	# the field's own empty-default value is `_apply()`'s job, proven
	# through GameState's declared defaults, not this validator's.
	var save_system: Node = get_node("/root/SaveSystem")
	var v22 := _state("day", 9)
	var migrated: Dictionary = save_system._migrate({"save_version": 22, "state": v22})
	_check("a v22 save with no opportunity fields migrates", not migrated.is_empty())

func _test_v24_dre_pending_penance() -> void:
	# Same shape as _validate_dre_intro_offered -- manual wrong-type check,
	# not the shared _bool helper, so an absent field stays absent rather
	# than picking up a spurious "missing; defaulted" repair on every
	# fixture that predates this field. See the validator's own comment.
	var wrong_type := _fixed(_state("dre_pending_penance", "not a bool"))
	_check("a wrong-type dre_pending_penance defaults to false",
		wrong_type["dre_pending_penance"] == false)
	var valid_true := _result(_state("dre_pending_penance", true))
	_check("a valid true value is a validation no-op",
		(valid_true["repairs"] as Array).is_empty())
	_check("and survives untouched", _fixed(_state("dre_pending_penance", true)) \
		["dre_pending_penance"] == true)

	# The real migration chain: a v23 save (PR C's own predecessor) carries
	# no restitution latch at all, and the v23 -> v24 arm is purely
	# additive, same as v22 -> v23 immediately above.
	var save_system: Node = get_node("/root/SaveSystem")
	var v23 := _state("day", 9)
	var migrated: Dictionary = save_system._migrate({"save_version": 23, "state": v23})
	_check("a v23 save with no restitution latch migrates", not migrated.is_empty())

## PR A (0.3.0, ENC-D1..D9): new stickup arrests open `stick_caught` at
## decision, but a save written before this build can already hold a
## `stick_booking` chain opened the old way -- direct to `result`, no
## decision, `allowed_choices: []`. `_validate_active_consequence` has no
## enumerated kind list (it coerces by KEY, never by `chain_kind`'s value —
## see its own loop over `["consequence_id", "cause_id", "chain_kind", ...]`),
## so this proves nothing added one that would reject an old save on load.
func _test_stick_booking_still_validates() -> void:
	var old_chain := {
		"consequence_id": "consequence:00000001", "cause_id": "cause:00000001",
		"chain_kind": "stick_booking", "stage": "result",
		"district_id": "north_star_lot", "return_route": "STICKUP",
		"source": {"family": "stick", "action_id": "stickup", "target_id": "washgo_regular"},
		"decision": {
			"definition_id": "stick_booking", "allowed_choices": [],
			"resolved_tier": "catastrophic",
			"result": {"choice_id": "", "tier": "catastrophic", "arrested": true},
		},
		"booking": {},
		"time": {"source_slots_remaining": 1, "source_time_settled": false},
	}
	var fixed := _fixed(_state("active_consequence", old_chain))
	var chain: Dictionary = fixed["active_consequence"]
	_check("an old stick_booking chain kind survives untouched",
		chain.get("chain_kind", "") == "stick_booking")
	_check("its decision-less choice list survives",
		(chain["decision"] as Dictionary).get("allowed_choices", ["x"]) == [])
	_check("its already-resolved arrest survives",
		((chain["decision"] as Dictionary).get("result", {}) as Dictionary).get("arrested", false) == true)
	_check("it still owes its source slot",
		int((chain["time"] as Dictionary).get("source_slots_remaining", 0)) == 1)
	_check("it is still sitting at result, not fast-forwarded",
		chain.get("stage", "") == "result")

## SQ-D4: a decision-stage chain survives a reload with everything the sheet
## rebuilds itself from, and NOTHING about the sheet itself.
##
## The whole reason the overlay needed no schema bump is that presentation is
## DERIVED — kind plus stage, read back off the chain the validator already
## carried. This arm is what keeps that true: if a later slice ever persists a
## sheet flag, the first check below is what says so, and the rest prove the
## fields the rebuild actually depends on (the round, the bank, the burned
## verbs, the snapshotted odds) come back exactly as they went in.
##
## The loop block rides `decision.loop` and is deliberately NOT in
## PERSIST_FIELDS — the validator's coercion leaves unlisted keys alone, which
## is the property this arm pins.
func _test_decision_stage_reload() -> void:
	var mid_round := {
		"consequence_id": "consequence:00000007", "cause_id": "cause:00000007",
		"chain_kind": "wander_encounter", "stage": "decision",
		"district_id": "north_star_lot", "return_route": "HOME",
		"source": {"family": "wander", "action_id": "wander",
			"card_id": "wander_shakedown", "opponent": "Two off the wall",
			"shape": "confrontation", "source_rng_key": "wander:3:2:1"},
		"decision": {
			"definition_id": "wander_shakedown",
			"allowed_choices": ["keep_fighting", "give_it_up"],
			"deterministic_choices": ["give_it_up"],
			"shown_probabilities": {"keep_fighting": 0.35},
			"committed_choice": "",
			"round": 2,
			"loop": {
				"round": 2, "base_chance": 0.45, "banked_health": 4,
				"stage": 1, "stage_count": 3, "left": 1, "banked": 0,
				"left_label": "ROUNDS LEFT",
				"burned": ["stand"],
				"log": ["It does not end there.", "Round 1: it gets loud again."],
			},
		},
		"booking": {},
		"time": {"source_slots_remaining": 1, "source_time_settled": false},
	}
	var fixed := _fixed(_state("active_consequence", mid_round))
	var chain: Dictionary = fixed["active_consequence"]
	var decision: Dictionary = chain["decision"]
	var loop: Dictionary = decision.get("loop", {})

	_check("a decision-stage chain reloads still at decision",
		chain.get("stage", "") == "decision")
	_check("nothing about the SHEET is persisted (no presentation key)",
		not chain.has("sheet") and not chain.has("presentation") \
			and not decision.has("sheet"))
	_check("the round survives the reload", int(decision.get("round", 0)) == 2)
	_check("the loop block survives the reload", not loop.is_empty())
	_check("the loop round survives", int(loop.get("round", 0)) == 2)
	_check("the banked damage survives", int(loop.get("banked_health", 0)) == 4)
	_check("the burned verbs survive",
		(loop.get("burned", []) as Array) == ["stand"])
	_check("the round log survives",
		(loop.get("log", []) as Array).size() == 2)
	_check("the snapshotted odds survive",
		is_equal_approx(float((decision.get("shown_probabilities", {}) as Dictionary) \
			.get("keep_fighting", 0.0)), 0.35))
	_check("the guaranteed out survives",
		"give_it_up" in (decision.get("deterministic_choices", []) as Array))
	_check("an uncommitted round reloads uncommitted",
		str(decision.get("committed_choice", "x")) == "")

	# The other half of SQ-D4: a chain that reloads at BOOKING is still a
	# booking, so the route ladder still sends it to the full screen.
	var booked: Dictionary = mid_round.duplicate(true)
	booked["stage"] = "booking"
	var booked_fixed: Dictionary = _fixed(_state("active_consequence", booked))
	_check("a booking-stage chain reloads still at booking",
		(booked_fixed["active_consequence"] as Dictionary).get("stage", "") == "booking")

func _test_load_pipeline() -> void:
	var save_system: Node = get_node("/root/SaveSystem")
	var payload := {"save_version": 8, "state": _state("markets", {"north_star_lot": null})}
	var migrated: Dictionary = save_system._migrate(payload)
	var fixed: Dictionary = save_system._validate_nested_shapes(migrated)
	_check("load pipeline still accepts required state", not fixed.is_empty())
	_check("load pipeline repairs before apply", fixed["markets"]["north_star_lot"] is Dictionary)

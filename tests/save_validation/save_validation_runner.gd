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
	_test_v16_territory_nodes()
	_test_v17_market_discovery()
	_test_v18_boost_bribes_used()
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

func _test_load_pipeline() -> void:
	var save_system: Node = get_node("/root/SaveSystem")
	var payload := {"save_version": 8, "state": _state("markets", {"north_star_lot": null})}
	var migrated: Dictionary = save_system._migrate(payload)
	var fixed: Dictionary = save_system._validate_nested_shapes(migrated)
	_check("load pipeline still accepts required state", not fixed.is_empty())
	_check("load pipeline repairs before apply", fixed["markets"]["north_star_lot"] is Dictionary)

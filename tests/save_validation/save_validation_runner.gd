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

func _test_load_pipeline() -> void:
	var save_system: Node = get_node("/root/SaveSystem")
	var payload := {"save_version": 8, "state": _state("markets", {"north_star_lot": null})}
	var migrated: Dictionary = save_system._migrate(payload)
	var fixed: Dictionary = save_system._validate_nested_shapes(migrated)
	_check("load pipeline still accepts required state", not fixed.is_empty())
	_check("load pipeline repairs before apply", fixed["markets"]["north_star_lot"] is Dictionary)

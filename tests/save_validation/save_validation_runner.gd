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

func _test_load_pipeline() -> void:
	var save_system: Node = get_node("/root/SaveSystem")
	var payload := {"save_version": 8, "state": _state("markets", {"north_star_lot": null})}
	var migrated: Dictionary = save_system._migrate(payload)
	var fixed: Dictionary = save_system._validate_nested_shapes(migrated)
	_check("load pipeline still accepts required state", not fixed.is_empty())
	_check("load pipeline repairs before apply", fixed["markets"]["north_star_lot"] is Dictionary)

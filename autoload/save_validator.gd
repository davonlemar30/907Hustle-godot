extends RefCounted
## Nested save-shape repair for load-time payloads.
##
## This validator is deliberately load-only. It returns a deep copy, repairs
## known fields to safe defaults, preserves unknown keys, and never writes a
## repaired payload back to disk. The save schema remains v8.

func validate_state(input: Dictionary) -> Dictionary:
	var state: Dictionary = input.duplicate(true)
	var repairs: Array[String] = []
	_validate_crew_records(state, repairs)
	_validate_markets(state, repairs)
	_validate_shark_loans(state, repairs)
	_validate_observation_queue(state, repairs)
	_validate_phone_messages(state, "phone_inbox", repairs)
	_validate_phone_messages(state, "phone_held_inbox", repairs)
	_validate_list_holdings(state, repairs)
	_validate_active_consequence(state, repairs)
	_validate_consequence_history(state, repairs)
	_validate_consequence_queue(state, repairs)
	_validate_district_pressure(state, repairs)
	_validate_arrest_record(state, repairs)
	return {"state": state, "repairs": repairs}

func _repair(repairs: Array[String], path: String, reason: String) -> void:
	repairs.append("%s: %s" % [path, reason])

func _string(row: Dictionary, key: String, default_value: String,
		path: String, repairs: Array[String]) -> void:
	if not row.has(key):
		row[key] = default_value
		_repair(repairs, path, "missing; defaulted")
	elif not row[key] is String:
		row[key] = default_value
		_repair(repairs, path, "wrong type; defaulted")

func _int(row: Dictionary, key: String, default_value: int,
		path: String, repairs: Array[String]) -> void:
	if not row.has(key):
		row[key] = default_value
		_repair(repairs, path, "missing; defaulted")
	elif not (row[key] is int or row[key] is float):
		row[key] = default_value
		_repair(repairs, path, "wrong type; defaulted")
	else:
		row[key] = int(row[key])

func _float(row: Dictionary, key: String, default_value: float,
		path: String, repairs: Array[String]) -> void:
	if not row.has(key):
		row[key] = default_value
		_repair(repairs, path, "missing; defaulted")
	elif not (row[key] is int or row[key] is float):
		row[key] = default_value
		_repair(repairs, path, "wrong type; defaulted")
	else:
		row[key] = float(row[key])

func _bool(row: Dictionary, key: String, default_value: bool,
		path: String, repairs: Array[String]) -> void:
	if not row.has(key):
		row[key] = default_value
		_repair(repairs, path, "missing; defaulted")
	elif not row[key] is bool:
		row[key] = default_value
		_repair(repairs, path, "wrong type; defaulted")

func _dict(row: Dictionary, key: String, default_value: Dictionary,
		path: String, repairs: Array[String]) -> Dictionary:
	if not row.has(key):
		row[key] = default_value.duplicate(true)
		_repair(repairs, path, "missing; defaulted")
	elif not row[key] is Dictionary:
		row[key] = default_value.duplicate(true)
		_repair(repairs, path, "wrong type; defaulted")
	return row[key] as Dictionary

func _array(row: Dictionary, key: String, default_value: Array,
		path: String, repairs: Array[String]) -> Array:
	if not row.has(key):
		row[key] = default_value.duplicate(true)
		_repair(repairs, path, "missing; defaulted")
	elif not row[key] is Array:
		row[key] = default_value.duplicate(true)
		_repair(repairs, path, "wrong type; defaulted")
	return row[key] as Array

func _validate_crew_records(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("crew_records"):
		return
	if not state["crew_records"] is Dictionary:
		state["crew_records"] = {}
		_repair(repairs, "crew_records", "wrong type; defaulted")
		return
	var records: Dictionary = state["crew_records"]
	for crew_id in records.keys():
		var path := "crew_records.%s" % str(crew_id)
		if not records[crew_id] is Dictionary:
			records[crew_id] = {}
			_repair(repairs, path, "wrong type; defaulted to empty record")
		var record: Dictionary = records[crew_id]
		_bool(record, "recruited", false, path + ".recruited", repairs)
		_string(record, "status", "active", path + ".status", repairs)
		_int(record, "tier", 1, path + ".tier", repairs)
		record["tier"] = clampi(int(record["tier"]), 1, 3)
		_int(record, "loyalty", 5, path + ".loyalty", repairs)
		record["loyalty"] = clampi(int(record["loyalty"]), 0, 10)
		_int(record, "wage_due", 0, path + ".wage_due", repairs)

func _validate_markets(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("markets"):
		return
	if not state["markets"] is Dictionary:
		state["markets"] = {}
		_repair(repairs, "markets", "wrong type; defaulted")
		return
	var markets: Dictionary = state["markets"]
	for district_id in markets.keys():
		var path := "markets.%s" % str(district_id)
		if not markets[district_id] is Dictionary:
			markets[district_id] = {}
			_repair(repairs, path, "wrong type; defaulted to empty market")
		var market: Dictionary = markets[district_id]
		_validate_numeric_map(market, "prices", path, repairs)
		_validate_numeric_map(market, "availability", path, repairs)
		if not market.has("history"):
			market["history"] = {}
			_repair(repairs, path + ".history", "missing; defaulted")
		elif not market["history"] is Dictionary:
			market["history"] = {}
			_repair(repairs, path + ".history", "wrong type; defaulted")
		else:
			var history: Dictionary = market["history"]
			for product_id in history.keys():
				if not history[product_id] is Array:
					history[product_id] = []
					_repair(repairs, "%s.history.%s" % [path, str(product_id)],
						"wrong type; defaulted")
				else:
					var values: Array = history[product_id]
					var clean: Array = []
					for value in values:
						if value is int or value is float:
							clean.append(int(value))
						else:
							_repair(repairs, "%s.history.%s" % [path, str(product_id)],
								"invalid value dropped")
					history[product_id] = clean
		_int(market, "updated_at", 0, path + ".updated_at", repairs)

func _validate_numeric_map(row: Dictionary, key: String, path: String,
		repairs: Array[String]) -> void:
	if not row.has(key):
		row[key] = {}
		_repair(repairs, path + "." + key, "missing; defaulted")
	elif not row[key] is Dictionary:
		row[key] = {}
		_repair(repairs, path + "." + key, "wrong type; defaulted")
	else:
		var values: Dictionary = row[key]
		for name in values.keys():
			if values[name] is int or values[name] is float:
				values[name] = int(values[name])
			else:
				values[name] = 0
				_repair(repairs, "%s.%s.%s" % [path, key, str(name)],
					"wrong type; defaulted")

func _validate_shark_loans(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("shark_loans"):
		return
	if not state["shark_loans"] is Array:
		state["shark_loans"] = []
		_repair(repairs, "shark_loans", "wrong type; defaulted")
		return
	var clean: Array = []
	for index in (state["shark_loans"] as Array).size():
		var value: Variant = (state["shark_loans"] as Array)[index]
		if not value is Dictionary:
			_repair(repairs, "shark_loans[%d]" % index, "invalid row dropped")
			continue
		var loan: Dictionary = value
		# PR #46's round-trip fixture carries an older, opaque loan shape
		# (`borrower`/`principal`). Preserve that unknown shape byte-for-byte and
		# validate only fields it actually carries. Current loans use the
		# canonical `borrower_id`/`amount` shape and receive typed defaults.
		if loan.has("borrower_id") or loan.has("amount"):
			_string(loan, "borrower_id", "", "shark_loans[%d].borrower_id" % index, repairs)
			_int(loan, "id", -1, "shark_loans[%d].id" % index, repairs)
			_int(loan, "amount", 0, "shark_loans[%d].amount" % index, repairs)
			_int(loan, "term", 0, "shark_loans[%d].term" % index, repairs)
			_int(loan, "opened_day", 0, "shark_loans[%d].opened_day" % index, repairs)
			_int(loan, "due_day", 0, "shark_loans[%d].due_day" % index, repairs)
			_string(loan, "status", "active", "shark_loans[%d].status" % index, repairs)
			_string(loan, "risk_label", "", "shark_loans[%d].risk_label" % index, repairs)
		else:
			if loan.has("id"):
				_int(loan, "id", -1, "shark_loans[%d].id" % index, repairs)
			if loan.has("borrower"):
				_string(loan, "borrower", "", "shark_loans[%d].borrower" % index, repairs)
			if loan.has("principal"):
				_int(loan, "principal", 0, "shark_loans[%d].principal" % index, repairs)
			if loan.has("due_day"):
				_int(loan, "due_day", 0, "shark_loans[%d].due_day" % index, repairs)
			if loan.has("term"):
				_int(loan, "term", 0, "shark_loans[%d].term" % index, repairs)
		clean.append(loan)
	state["shark_loans"] = clean

func _validate_observation_queue(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("observation_queue"):
		return
	if not state["observation_queue"] is Array:
		state["observation_queue"] = []
		_repair(repairs, "observation_queue", "wrong type; defaulted")
		return
	var clean: Array = []
	for index in (state["observation_queue"] as Array).size():
		var value: Variant = (state["observation_queue"] as Array)[index]
		if not value is Dictionary:
			_repair(repairs, "observation_queue[%d]" % index, "invalid row dropped")
			continue
		var row: Dictionary = value
		_string(row, "npc_id", "", "observation_queue[%d].npc_id" % index, repairs)
		_dict(row, "spec", {}, "observation_queue[%d].spec" % index, repairs)
		_int(row, "deliver_on_day", 0,
			"observation_queue[%d].deliver_on_day" % index, repairs)
		clean.append(row)
	state["observation_queue"] = clean

func _validate_phone_messages(state: Dictionary, field: String,
		repairs: Array[String]) -> void:
	if not state.has(field):
		return
	if not state[field] is Array:
		state[field] = []
		_repair(repairs, field, "wrong type; defaulted")
		return
	var clean: Array = []
	for index in (state[field] as Array).size():
		var value: Variant = (state[field] as Array)[index]
		if not value is Dictionary:
			_repair(repairs, "%s[%d]" % [field, index], "invalid message dropped")
			continue
		var message: Dictionary = value
		_string(message, "id", "", "%s[%d].id" % [field, index], repairs)
		_string(message, "from", "", "%s[%d].from" % [field, index], repairs)
		_string(message, "text", "", "%s[%d].text" % [field, index], repairs)
		_int(message, "day", 0, "%s[%d].day" % [field, index], repairs)
		_int(message, "slot", 0, "%s[%d].slot" % [field, index], repairs)
		_bool(message, "read", false, "%s[%d].read" % [field, index], repairs)
		if message.has("action") and not message["action"] is Dictionary:
			message["action"] = {}
			_repair(repairs, "%s[%d].action" % [field, index], "wrong type; defaulted")
		clean.append(message)
	state[field] = clean

func _validate_list_holdings(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("list_holdings"):
		return
	if not state["list_holdings"] is Array:
		state["list_holdings"] = []
		_repair(repairs, "list_holdings", "wrong type; defaulted")
		return
	var clean: Array = []
	for index in (state["list_holdings"] as Array).size():
		var value: Variant = (state["list_holdings"] as Array)[index]
		if not value is Dictionary:
			_repair(repairs, "list_holdings[%d]" % index, "invalid holding dropped")
			continue
		var holding: Dictionary = value
		_string(holding, "item_id", "", "list_holdings[%d].item_id" % index, repairs)
		_int(holding, "bought_day", -1,
			"list_holdings[%d].bought_day" % index, repairs)
		_string(holding, "source", "player", "list_holdings[%d].source" % index, repairs)
		clean.append(holding)
	state["list_holdings"] = clean

func _validate_active_consequence(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("active_consequence"):
		return
	if not state["active_consequence"] is Dictionary:
		state["active_consequence"] = {}
		_repair(repairs, "active_consequence", "wrong type; defaulted")
		return
	var chain: Dictionary = state["active_consequence"]
	if chain.is_empty():
		return
	for key in ["consequence_id", "cause_id", "chain_kind", "stage", "district_id", "return_route"]:
		_string(chain, key, "", "active_consequence." + key, repairs)
	_int(chain, "created_day", 0, "active_consequence.created_day", repairs)
	_int(chain, "created_slot", 0, "active_consequence.created_slot", repairs)
	_dict(chain, "source", {}, "active_consequence.source", repairs)
	var decision := _dict(chain, "decision", {}, "active_consequence.decision", repairs)
	_string(decision, "definition_id", "", "active_consequence.decision.definition_id", repairs)
	_array(decision, "allowed_choices", [], "active_consequence.decision.allowed_choices", repairs)
	_string(decision, "committed_choice", "", "active_consequence.decision.committed_choice", repairs)
	_dict(decision, "resolver_inputs", {}, "active_consequence.decision.resolver_inputs", repairs)
	_dict(decision, "shown_probabilities", {}, "active_consequence.decision.shown_probabilities", repairs)
	_array(decision, "deterministic_choices", [], "active_consequence.decision.deterministic_choices", repairs)
	_dict(decision, "arrest_risks", {}, "active_consequence.decision.arrest_risks", repairs)
	_string(decision, "resolved_tier", "", "active_consequence.decision.resolved_tier", repairs)
	_dict(decision, "result", {}, "active_consequence.decision.result", repairs)
	_dict(chain, "booking", {}, "active_consequence.booking", repairs)
	var time_block := _dict(chain, "time", {}, "active_consequence.time", repairs)
	_int(time_block, "source_slots_remaining", 0,
		"active_consequence.time.source_slots_remaining", repairs)
	_bool(time_block, "source_time_settled", false,
		"active_consequence.time.source_time_settled", repairs)

func _validate_consequence_history(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("consequence_history"):
		return
	if not state["consequence_history"] is Dictionary:
		state["consequence_history"] = {}
		_repair(repairs, "consequence_history", "wrong type; defaulted")
		return
	var history: Dictionary = state["consequence_history"]
	for cause_id in history.keys():
		var path := "consequence_history.%s" % str(cause_id)
		if not history[cause_id] is Dictionary:
			history[cause_id] = {}
			_repair(repairs, path, "wrong type; defaulted to empty receipt row")
		var row: Dictionary = history[cause_id]
		_array(row, "effect_receipts", [], path + ".effect_receipts", repairs)
		_array(row, "resolved_consequence_ids", [], path + ".resolved_consequence_ids", repairs)
		_array(row, "scheduled_actor_ids", [], path + ".scheduled_actor_ids", repairs)

func _validate_consequence_queue(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("consequence_queue"):
		return
	if not state["consequence_queue"] is Array:
		state["consequence_queue"] = []
		_repair(repairs, "consequence_queue", "wrong type; defaulted")
		return
	var clean: Array = []
	for index in (state["consequence_queue"] as Array).size():
		var value: Variant = (state["consequence_queue"] as Array)[index]
		if not value is Dictionary:
			_repair(repairs, "consequence_queue[%d]" % index, "invalid row dropped")
			continue
		var row: Dictionary = value
		for key in ["queue_id", "cause_id", "actor_id", "district_id", "status"]:
			_string(row, key, "", "consequence_queue[%d].%s" % [index, key], repairs)
		_int(row, "trigger_day", 0, "consequence_queue[%d].trigger_day" % index, repairs)
		_int(row, "expires_end_day", 0, "consequence_queue[%d].expires_end_day" % index, repairs)
		_int(row, "created_sequence", 0, "consequence_queue[%d].created_sequence" % index, repairs)
		clean.append(row)
	state["consequence_queue"] = clean

func _validate_district_pressure(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("district_pressure"):
		return
	if not state["district_pressure"] is Dictionary:
		state["district_pressure"] = {}
		_repair(repairs, "district_pressure", "wrong type; defaulted")
		return
	var pressure: Dictionary = state["district_pressure"]
	for district_id in pressure.keys():
		var district_path := "district_pressure.%s" % str(district_id)
		if not pressure[district_id] is Dictionary:
			pressure[district_id] = {}
			_repair(repairs, district_path, "wrong type; defaulted")
		var families: Dictionary = pressure[district_id]
		for family in families.keys():
			var path := district_path + "." + str(family)
			if not families[family] is Dictionary:
				families[family] = {}
				_repair(repairs, path, "wrong type; defaulted")
			var row: Dictionary = families[family]
			_float(row, "score", 0.0, path + ".score", repairs)
			_int(row, "last_gain_day", -1, path + ".last_gain_day", repairs)
			_int(row, "quiet_days", 0, path + ".quiet_days", repairs)
			_int(row, "market_gain_day", -1, path + ".market_gain_day", repairs)
			_float(row, "market_gain_today", 0.0, path + ".market_gain_today", repairs)

func _validate_arrest_record(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("arrest_record"):
		return
	if not state["arrest_record"] is Dictionary:
		state["arrest_record"] = {"priors": 0, "last_arrest_day": -1, "charges": []}
		_repair(repairs, "arrest_record", "wrong type; defaulted")
		return
	var record: Dictionary = state["arrest_record"]
	_int(record, "priors", 0, "arrest_record.priors", repairs)
	_int(record, "last_arrest_day", -1, "arrest_record.last_arrest_day", repairs)
	var charges := _array(record, "charges", [], "arrest_record.charges", repairs)
	var clean: Array = []
	for index in charges.size():
		if charges[index] is Dictionary:
			clean.append(charges[index])
		else:
			_repair(repairs, "arrest_record.charges[%d]" % index, "invalid charge dropped")
	record["charges"] = clean

extends RefCounted
## The state script, for the authored tables this validator repairs against.
## Preloaded rather than reached through the tree: this is a RefCounted, it has
## no tree, and a repair table belongs with the data it describes.
const GAME_STATE := preload("res://autoload/game_state.gd")
## Nested save-shape repair for load-time payloads.
##
## This validator is deliberately load-only. It returns a deep copy, repairs
## known fields to safe defaults, preserves unknown keys, and never writes a
## repaired payload back to disk. The save schema is v10. Older saves are
## migrated before this validator runs, so every arm below reads a v10 shape.

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
	_validate_consequence_flags(state, repairs)
	_validate_districts_unlocked(state, repairs)
	_validate_job_contacts(state, repairs)
	_validate_pressure_clean_credits(state, repairs)
	_validate_attribute_sessions(state, repairs)
	_validate_gym_streak(state, repairs)
	_validate_venues_entered(state, repairs)
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
			_shark_term(loan, index, repairs)
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

## An authored term, or the nearest one. A note whose term is not in the rate
## table loads fine and then takes down the night it settles, so it is repaired
## here rather than defended everywhere it is read.
func _shark_term(loan: Dictionary, index: int, repairs: Array[String]) -> void:
	var term: int = int(loan.get("term", 0))
	if GAME_STATE.SHARK_TERMS.has(term):
		return
	var snapped: int = GAME_STATE.nearest_shark_term(term)
	loan["term"] = snapped
	_repair(repairs, "shark_loans[%d].term" % index,
		"unauthored term %d snapped to %d" % [term, snapped])

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

# --- v10: the surface-visibility facts and the HOT lever's ledger -----------

## The district discovery latch. Every entry must be a non-empty String, and
## home turf must be in it — a run that has lost `north_star_lot` cannot travel
## home, which is worse than any malformed row this validator normally sees.
func _validate_districts_unlocked(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("districts_unlocked"):
		return
	if not state["districts_unlocked"] is Array:
		state["districts_unlocked"] = ["north_star_lot"]
		_repair(repairs, "districts_unlocked", "wrong type; defaulted")
		return
	var known: Array = state["districts_unlocked"]
	var cleaned: Array = []
	for index in range(known.size()):
		var entry: Variant = known[index]
		if not entry is String or str(entry).is_empty():
			_repair(repairs, "districts_unlocked[%d]" % index, "not a district id; dropped")
			continue
		if str(entry) in cleaned:
			_repair(repairs, "districts_unlocked[%d]" % index, "duplicate; dropped")
			continue
		cleaned.append(str(entry))
	if not "north_star_lot" in cleaned:
		cleaned.push_front("north_star_lot")
		_repair(repairs, "districts_unlocked", "home turf missing; restored")
	state["districts_unlocked"] = cleaned

## The job-contact count. Never negative: the gate reads `>= 1`, and a negative
## would be indistinguishable from zero right up until somebody writes a gate
## that reads `!= 0`.
func _validate_job_contacts(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("job_contacts"):
		return
	if not (state["job_contacts"] is int or state["job_contacts"] is float):
		state["job_contacts"] = 0
		_repair(repairs, "job_contacts", "wrong type; defaulted")
		return
	var contacts: int = int(state["job_contacts"])
	if contacts < 0:
		contacts = 0
		_repair(repairs, "job_contacts", "negative; defaulted")
	state["job_contacts"] = contacts

## The day's banked clean recovery: district -> family -> float, same shape as
## `district_pressure` one level shallower. A negative credit would ADD pressure
## on settlement, which is the opposite of what the ledger is for.
func _validate_pressure_clean_credits(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("pressure_clean_credits"):
		return
	if not state["pressure_clean_credits"] is Dictionary:
		state["pressure_clean_credits"] = {}
		_repair(repairs, "pressure_clean_credits", "wrong type; defaulted")
		return
	var credits: Dictionary = state["pressure_clean_credits"]
	for district_id in credits.keys():
		var district_path := "pressure_clean_credits.%s" % str(district_id)
		if not credits[district_id] is Dictionary:
			credits[district_id] = {}
			_repair(repairs, district_path, "wrong type; defaulted")
		var families: Dictionary = credits[district_id]
		for family in families.keys():
			var path := district_path + "." + str(family)
			if not (families[family] is int or families[family] is float):
				families[family] = 0.0
				_repair(repairs, path, "wrong type; defaulted")
			elif float(families[family]) < 0.0:
				families[family] = 0.0
				_repair(repairs, path, "negative credit; defaulted")
			else:
				families[family] = float(families[family])

## v11. Session counts feed `AttributesSystem.growth`'s log2 denominator, so a
## negative one produces a growth rate larger than the authored base and a
## non-integer one produces a float where the curve expects a count. Both are
## clamped rather than dropped: the count is evidence the activity happened, and
## losing it would hand the player back the valuable early sessions.
func _validate_attribute_sessions(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("attribute_sessions"):
		return
	if not state["attribute_sessions"] is Dictionary:
		state["attribute_sessions"] = {}
		_repair(repairs, "attribute_sessions", "wrong type; defaulted")
		return
	var sessions: Dictionary = state["attribute_sessions"]
	for activity in sessions.keys():
		var path := "attribute_sessions.%s" % str(activity)
		if not (sessions[activity] is int or sessions[activity] is float):
			sessions[activity] = 0
			_repair(repairs, path, "wrong type; defaulted")
		elif int(sessions[activity]) < 0:
			sessions[activity] = 0
			_repair(repairs, path, "negative session count; defaulted")
		else:
			sessions[activity] = int(sessions[activity])

## v11. The streak grants +1 effective Combat, so a corrupt one is a free
## permanent point. `gym_last_day` is the liveness half — a day in the future
## would keep a broken streak alive forever, so it is snapped back to -1, which
## reads as "never trained" and costs the player only the streak they were not
## honestly holding.
func _validate_gym_streak(state: Dictionary, repairs: Array[String]) -> void:
	if state.has("gym_streak"):
		if not (state["gym_streak"] is int or state["gym_streak"] is float):
			state["gym_streak"] = 0
			_repair(repairs, "gym_streak", "wrong type; defaulted")
		elif int(state["gym_streak"]) < 0:
			state["gym_streak"] = 0
			_repair(repairs, "gym_streak", "negative streak; defaulted")
		else:
			state["gym_streak"] = int(state["gym_streak"])
	if not state.has("gym_last_day"):
		return
	if not (state["gym_last_day"] is int or state["gym_last_day"] is float):
		state["gym_last_day"] = -1
		_repair(repairs, "gym_last_day", "wrong type; defaulted")
		return
	state["gym_last_day"] = int(state["gym_last_day"])
	var day_value: Variant = state.get("day", 0)
	var today: int = int(day_value) if (day_value is int or day_value is float) else 0
	if int(state["gym_last_day"]) > today:
		state["gym_last_day"] = -1
		state["gym_streak"] = 0
		_repair(repairs, "gym_last_day", "trained in the future; streak cleared")

## v11. Ids only, no duplicates — the array's whole job is `has_entered`, and a
## duplicate or a non-string cannot make that answer more true.
func _validate_venues_entered(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("venues_entered"):
		return
	if not state["venues_entered"] is Array:
		state["venues_entered"] = []
		_repair(repairs, "venues_entered", "wrong type; defaulted")
		return
	var clean: Array = []
	for index in (state["venues_entered"] as Array).size():
		var value: Variant = (state["venues_entered"] as Array)[index]
		if not value is String:
			_repair(repairs, "venues_entered[%d]" % index, "non-string dropped")
			continue
		if value in clean:
			_repair(repairs, "venues_entered[%d]" % index, "duplicate dropped")
			continue
		clean.append(value)
	state["venues_entered"] = clean

func _validate_arrest_record(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("arrest_record"):
		return
	if not state["arrest_record"] is Dictionary:
		state["arrest_record"] = {"priors": 0, "last_arrest_day": -1, "charges": [],
			"cooldown_until_day": -1}
		_repair(repairs, "arrest_record", "wrong type; defaulted")
		return
	var record: Dictionary = state["arrest_record"]
	_int(record, "priors", 0, "arrest_record.priors", repairs)
	_int(record, "last_arrest_day", -1, "arrest_record.last_arrest_day", repairs)
	# This key is additive in v9. Leave it absent on a v8 record so legacy
	# round-trips stay byte-identical; _apply() supplies the GameState default.
	if record.has("cooldown_until_day"):
		_int(record, "cooldown_until_day", -1, "arrest_record.cooldown_until_day", repairs)
		if int(record["cooldown_until_day"]) < -1:
			record["cooldown_until_day"] = -1
			_repair(repairs, "arrest_record.cooldown_until_day", "out of range; defaulted")
	var charges := _array(record, "charges", [], "arrest_record.charges", repairs)
	var clean: Array = []
	for index in charges.size():
		if charges[index] is Dictionary:
			clean.append(charges[index])
		else:
			_repair(repairs, "arrest_record.charges[%d]" % index, "invalid charge dropped")
	record["charges"] = clean

func _validate_consequence_flags(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("consequence_flags"):
		return
	if not state["consequence_flags"] is Dictionary:
		state["consequence_flags"] = {}
		_repair(repairs, "consequence_flags", "wrong type; defaulted")
		return
	var flags: Dictionary = state["consequence_flags"]
	# An empty dictionary is the canonical v8 -> v9 migrated shape. Known keys
	# are optional so valid empty/forward-compatible dictionaries remain intact.
	if flags.has("retaliation_first_expiry_seen"):
		_bool(flags, "retaliation_first_expiry_seen", false,
			"consequence_flags.retaliation_first_expiry_seen", repairs)
	if flags.has("retaliation_last_ambient_day"):
		_int(flags, "retaliation_last_ambient_day", -1,
			"consequence_flags.retaliation_last_ambient_day", repairs)
		if int(flags["retaliation_last_ambient_day"]) < -1:
			flags["retaliation_last_ambient_day"] = -1
			_repair(repairs, "consequence_flags.retaliation_last_ambient_day",
				"out of range; defaulted")

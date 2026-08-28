extends RefCounted
## The state script, for the authored tables this validator repairs against.
## Preloaded rather than reached through the tree: this is a RefCounted, it has
## no tree, and a repair table belongs with the data it describes.
const GAME_STATE := preload("res://autoload/game_state.gd")
## The wander ramp's authored numbers, for the clamp that keeps a corrupt save
## from pinning the discovery roll at its cap. It is here because the clamp
## has to agree with the ramp.
const WANDER_EVENTS := preload("res://data/wander_events.gd")
## The Territory board, for `_validate_territory_nodes` — the arm FS-002.3
## added as the root-cause fix for `86bbjxtab` (an unknown territory id
## silently killing nightly settlement). Nothing validated the ids in a loaded
## `held_blocks`/`territory_nodes` before this.
const TERRITORY_DEFS := preload("res://data/territory_definitions.gd")
## Word of Mouth's ramp cap, for the same reason `WANDER_EVENTS` is here: the
## clamp on a corrupt `tip_misses` has to agree with the ramp it is clamping.
const TIP_EVENTS := preload("res://data/tip_events.gd")
## Nested save-shape repair for load-time payloads.
##
## This validator is deliberately load-only. It returns a deep copy, repairs
## known fields to safe defaults, preserves unknown keys, and never writes a
## repaired payload back to disk. The save schema is v21. Older saves are
## migrated before this validator runs, so every arm below reads a v21 shape.

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
	_validate_heat_day(state, repairs)
	_validate_wander(state, repairs)
	_validate_boost_discovery(state, repairs)
	_validate_boost_bribes_used(state, repairs)
	_validate_tip_effects(state, repairs)
	_validate_tip_misses(state, repairs)
	_validate_dre_introduced(state, repairs)
	_validate_dre_intro_offered(state, repairs)
	_validate_dre_access_tier(state, repairs)
	_validate_dre_account(state, repairs)
	_validate_dre_account_history(state, repairs)
	_validate_territory_nodes(state, repairs)
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

## v12. Two fields that both fail in the player's favour if left alone, which is
## why they are repaired rather than trusted.
##
## A negative `heat_gain_today` reads as a quiet day no matter what the run
## actually did, so every day would decay. A `lay_low_day` in the future blocks
## going quiet until the run reaches it — the opposite failure, and the one that
## costs the player something they are owed.
func _validate_heat_day(state: Dictionary, repairs: Array[String]) -> void:
	if state.has("heat_gain_today"):
		if not (state["heat_gain_today"] is int or state["heat_gain_today"] is float):
			state["heat_gain_today"] = 0.0
			_repair(repairs, "heat_gain_today", "wrong type; defaulted")
		elif float(state["heat_gain_today"]) < 0.0:
			state["heat_gain_today"] = 0.0
			_repair(repairs, "heat_gain_today", "negative gain; defaulted")
		else:
			state["heat_gain_today"] = float(state["heat_gain_today"])
	if not state.has("lay_low_day"):
		return
	if not (state["lay_low_day"] is int or state["lay_low_day"] is float):
		state["lay_low_day"] = -1
		_repair(repairs, "lay_low_day", "wrong type; defaulted")
		return
	state["lay_low_day"] = int(state["lay_low_day"])
	var day_value: Variant = state.get("day", 0)
	var today: int = int(day_value) if (day_value is int or day_value is float) else 0
	if int(state["lay_low_day"]) > today:
		state["lay_low_day"] = -1
		_repair(repairs, "lay_low_day", "went quiet in the future; cleared")

## v13. The wander ramp and its seen-cards ledger.
##
## The ramp is the one that can be abused: it is the numerator of the discovery
## chance, so a large enough `wander_misses` pins the roll at its 70% cap
## forever. Clamping it to the number of misses that actually reaches the cap
## costs an honest save nothing — past that point the extra misses were already
## doing nothing — and takes the exploit away.
func _validate_wander(state: Dictionary, repairs: Array[String]) -> void:
	# The same number the live path caps at — one owner, so the two cannot
	# disagree and repair an honest save.
	var ceiling: int = int(WANDER_EVENTS.miss_ceiling())
	for field in ["wander_misses", "wander_count", "wanders_today"]:
		if not state.has(field):
			continue
		if not (state[field] is int or state[field] is float):
			state[field] = 0
			_repair(repairs, field, "wrong type; defaulted")
		elif int(state[field]) < 0:
			state[field] = 0
			_repair(repairs, field, "negative; defaulted")
		else:
			state[field] = int(state[field])
	if state.has("wander_misses") and int(state["wander_misses"]) > ceiling:
		_repair(repairs, "wander_misses",
			"beyond the cap (%d); clamped" % int(state["wander_misses"]))
		state["wander_misses"] = ceiling

	if state.has("wander_seen"):
		if not state["wander_seen"] is Dictionary:
			state["wander_seen"] = {}
			_repair(repairs, "wander_seen", "wrong type; defaulted")
		else:
			var seen: Dictionary = state["wander_seen"]
			for card_id in seen.keys():
				var path := "wander_seen.%s" % str(card_id)
				if not (seen[card_id] is int or seen[card_id] is float):
					seen[card_id] = 0
					_repair(repairs, path, "wrong type; defaulted")
				elif int(seen[card_id]) < 0:
					seen[card_id] = 0
					_repair(repairs, path, "negative count; defaulted")
				else:
					seen[card_id] = int(seen[card_id])

	if not state.has("wander_recent"):
		return
	if not state["wander_recent"] is Array:
		state["wander_recent"] = []
		_repair(repairs, "wander_recent", "wrong type; defaulted")
		return
	var clean: Array = []
	for index in (state["wander_recent"] as Array).size():
		var value: Variant = (state["wander_recent"] as Array)[index]
		if not value is String:
			_repair(repairs, "wander_recent[%d]" % index, "non-string dropped")
			continue
		clean.append(value)
	state["wander_recent"] = clean

## v15. The Boost discovery latch.
##
## Repaired against the authored catalogue rather than against a shape, which is
## the difference that matters: a malformed row here is not merely untidy, it is
## a target id the boost blocker will happily match on and `boost_target_by_id`
## will answer `{}` for. An id nothing in the catalogue carries is dropped, not
## defaulted — there is no safe target to substitute, and a run that never
## discovered it is exactly the state dropping it produces.
##
## Duplicates go too. The array is a SET the whole build reads with `in`, so a
## second copy of an id changes no verdict and is only a way for the file to
## grow without bound across a long run.
func _validate_boost_discovery(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("boost_targets_discovered"):
		return
	if not state["boost_targets_discovered"] is Array:
		state["boost_targets_discovered"] = []
		_repair(repairs, "boost_targets_discovered", "wrong type; defaulted")
		return
	# The authored ids, off the state script rather than a list retyped here.
	var authored: Dictionary = {}
	for target in (GAME_STATE.new().boost_targets as Array):
		if target is Dictionary:
			authored[str((target as Dictionary).get("id", ""))] = true
	var found: Array = state["boost_targets_discovered"]
	var cleaned: Array = []
	for index in range(found.size()):
		var entry: Variant = found[index]
		if not entry is String or str(entry).is_empty():
			_repair(repairs, "boost_targets_discovered[%d]" % index,
				"not a target id; dropped")
			continue
		if not authored.has(str(entry)):
			_repair(repairs, "boost_targets_discovered[%d]" % index,
				"no such boost target; dropped")
			continue
		if str(entry) in cleaned:
			_repair(repairs, "boost_targets_discovered[%d]" % index,
				"duplicate; dropped")
			continue
		cleaned.append(str(entry))
	state["boost_targets_discovered"] = cleaned

## 0.1.2. Same shape as `_validate_boost_discovery`, same reason: every entry
## must be a real target id, and a store cannot be bought from twice.
func _validate_boost_bribes_used(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("boost_bribes_used"):
		return
	if not state["boost_bribes_used"] is Array:
		state["boost_bribes_used"] = []
		_repair(repairs, "boost_bribes_used", "wrong type; defaulted")
		return
	var authored: Dictionary = {}
	for target in (GAME_STATE.new().boost_targets as Array):
		if target is Dictionary:
			authored[str((target as Dictionary).get("id", ""))] = true
	var found: Array = state["boost_bribes_used"]
	var cleaned: Array = []
	for index in range(found.size()):
		var entry: Variant = found[index]
		if not entry is String or str(entry).is_empty():
			_repair(repairs, "boost_bribes_used[%d]" % index,
				"not a target id; dropped")
			continue
		if not authored.has(str(entry)):
			_repair(repairs, "boost_bribes_used[%d]" % index,
				"no such boost target; dropped")
			continue
		if str(entry) in cleaned:
			_repair(repairs, "boost_bribes_used[%d]" % index,
				"duplicate; dropped")
			continue
		cleaned.append(str(entry))
	state["boost_bribes_used"] = cleaned

## 0.1.2 (Word of Mouth). Structural only, same as `_validate_active_consequence`
## — `type` is not checked against a known set because `tip_modifiers_for`
## already degrades an unrecognised type to a no-op by design, and a validator
## that rejected the next slice's tip type would be the thing breaking the
## save, not the tip.
func _validate_tip_effects(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("tip_effects"):
		return
	if not state["tip_effects"] is Array:
		state["tip_effects"] = []
		_repair(repairs, "tip_effects", "wrong type; defaulted")
		return
	var cleaned: Array = []
	for index in (state["tip_effects"] as Array).size():
		var value: Variant = (state["tip_effects"] as Array)[index]
		if not value is Dictionary:
			_repair(repairs, "tip_effects[%d]" % index, "invalid row dropped")
			continue
		var row: Dictionary = value
		_string(row, "type", "", "tip_effects[%d].type" % index, repairs)
		_string(row, "target_id", "", "tip_effects[%d].target_id" % index, repairs)
		_int(row, "day", 0, "tip_effects[%d].day" % index, repairs)
		_float(row, "multiplier", 1.0, "tip_effects[%d].multiplier" % index, repairs)
		var slots := _array(row, "slots", [], "tip_effects[%d].slots" % index, repairs)
		for slot_index in slots.size():
			if not (slots[slot_index] is int or slots[slot_index] is float):
				_repair(repairs, "tip_effects[%d].slots[%d]" % [index, slot_index],
					"wrong type; dropped")
				slots[slot_index] = null
			else:
				slots[slot_index] = int(slots[slot_index])
		row["slots"] = slots.filter(func(entry): return entry != null)
		cleaned.append(row)
	state["tip_effects"] = cleaned

## Same ramp, same clamp shape as `_validate_wander`'s `wander_misses` arm —
## one owner (`TIP_EVENTS.miss_ceiling()`) so the two cannot disagree and
## repair an honest save.
func _validate_tip_misses(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("tip_misses"):
		return
	if not (state["tip_misses"] is int or state["tip_misses"] is float):
		state["tip_misses"] = 0
		_repair(repairs, "tip_misses", "wrong type; defaulted")
		return
	if int(state["tip_misses"]) < 0:
		state["tip_misses"] = 0
		_repair(repairs, "tip_misses", "negative; defaulted")
		return
	state["tip_misses"] = int(state["tip_misses"])
	var ceiling: int = int(TIP_EVENTS.miss_ceiling())
	if int(state["tip_misses"]) > ceiling:
		_repair(repairs, "tip_misses", "beyond the cap (%d); clamped" % int(state["tip_misses"]))
		state["tip_misses"] = ceiling

## Dre Lending & Loan-Shark Progression, PR A (0.1.2, v20).
##
## Defaults rather than coerces on a wrong type -- same as every other
## `_bool` arm in this file. GDScript's `bool()` constructor has no String
## overload, so `bool(state["dre_introduced"])` raises outright on exactly
## the kind of hand-edited or corrupted value ("yes", "1") a repair arm
## exists to survive.
func _validate_dre_introduced(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("dre_introduced"):
		return
	if not state["dre_introduced"] is bool:
		state["dre_introduced"] = false
		_repair(repairs, "dre_introduced", "wrong type; defaulted")

## PR B (0.1.2, v21). Same defaults-not-coerces reasoning as `dre_introduced`
## just above -- `bool()` on an arbitrary Variant is a crash, not a repair.
func _validate_dre_intro_offered(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("dre_intro_offered"):
		return
	if not state["dre_intro_offered"] is bool:
		state["dre_intro_offered"] = false
		_repair(repairs, "dre_intro_offered", "wrong type; defaulted")

## Tier is a milestone latch, 0 (Unknown) through 5 (Operator) -- design doc
## section 7. Clamped rather than defaulted on out-of-range, same reasoning
## as stick_tier's ceiling: a save claiming tier 9 is closer to "the highest
## real tier" than to "Unknown", and clamping says so.
func _validate_dre_access_tier(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("dre_access_tier"):
		return
	if not (state["dre_access_tier"] is int or state["dre_access_tier"] is float):
		state["dre_access_tier"] = 0
		_repair(repairs, "dre_access_tier", "wrong type; defaulted")
		return
	var tier: int = clampi(int(state["dre_access_tier"]), 0, 5)
	if tier != int(state["dre_access_tier"]):
		_repair(repairs, "dre_access_tier", "out of range; clamped")
	state["dre_access_tier"] = tier

const DRE_ACCOUNT_STATUSES := ["clear", "active", "due", "extended", "overdue", "suspended"]

## The one loan a player can carry (design doc section 10.1, section 9).
## `status` is a closed six-state machine, unlike a tip's open-ended `type`
## -- an unrecognised status is repaired to "clear" and its amounts zeroed
## with it, because a status the game does not know how to settle is a debt
## the player can never resolve otherwise.
func _validate_dre_account(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("dre_account"):
		return
	if not state["dre_account"] is Dictionary:
		state["dre_account"] = {
			"status": "clear", "principal": 0, "interest": 0, "fee": 0,
			"opened_day": -1, "due_day": -1, "term_days": 0,
			"extension_used": false, "offer_id": "",
		}
		_repair(repairs, "dre_account", "wrong type; defaulted")
		return
	var account: Dictionary = state["dre_account"]
	_string(account, "status", "clear", "dre_account.status", repairs)
	if not str(account["status"]) in DRE_ACCOUNT_STATUSES:
		_repair(repairs, "dre_account.status", "unrecognised; defaulted to clear")
		account["status"] = "clear"
	_int(account, "principal", 0, "dre_account.principal", repairs)
	_int(account, "interest", 0, "dre_account.interest", repairs)
	_int(account, "fee", 0, "dre_account.fee", repairs)
	for money_field in ["principal", "interest", "fee"]:
		if int(account[money_field]) < 0:
			_repair(repairs, "dre_account.%s" % money_field, "negative; defaulted")
			account[money_field] = 0
	_int(account, "opened_day", -1, "dre_account.opened_day", repairs)
	_int(account, "due_day", -1, "dre_account.due_day", repairs)
	_int(account, "term_days", 0, "dre_account.term_days", repairs)
	if int(account["term_days"]) < 0:
		_repair(repairs, "dre_account.term_days", "negative; defaulted")
		account["term_days"] = 0
	_bool(account, "extension_used", false, "dre_account.extension_used", repairs)
	_string(account, "offer_id", "", "dre_account.offer_id", repairs)
	if str(account["status"]) == "clear":
		for zeroed_field in ["principal", "interest", "fee"]:
			if int(account[zeroed_field]) != 0:
				_repair(repairs, "dre_account.%s" % zeroed_field,
					"nonzero on a clear account; zeroed")
				account[zeroed_field] = 0
	state["dre_account"] = account

## Lifetime counters, all non-negative -- design doc section 10.1. Structural
## only, same shape as _validate_active_consequence's nested-dict arms.
func _validate_dre_account_history(state: Dictionary, repairs: Array[String]) -> void:
	if not state.has("dre_account_history"):
		return
	if not state["dre_account_history"] is Dictionary:
		state["dre_account_history"] = {
			"loans_taken": 0, "repaid_on_time": 0, "repaid_late": 0,
			"extensions": 0, "defaults": 0,
			"total_principal_borrowed": 0, "total_interest_paid": 0,
		}
		_repair(repairs, "dre_account_history", "wrong type; defaulted")
		return
	var history: Dictionary = state["dre_account_history"]
	var fields := ["loans_taken", "repaid_on_time", "repaid_late", "extensions",
		"defaults", "total_principal_borrowed", "total_interest_paid"]
	for field in fields:
		_int(history, field, 0, "dre_account_history.%s" % field, repairs)
		if int(history[field]) < 0:
			_repair(repairs, "dre_account_history.%s" % field, "negative; defaulted")
			history[field] = 0
	state["dre_account_history"] = history

## v16 (FS-002.3). Drop rows whose id the authored board does not carry, clamp
## soldiers non-negative, and cap a posted sum that exceeds the capacity those
## same (cleaned) rows would grant — a corrupted save is not trusted to prove
## its own capacity is real. Load-only, no write-back, following
## `_validate_boost_discovery`'s shape.
func _validate_territory_nodes(state: Dictionary, repairs: Array[String]) -> void:
	if state.has("territory_nodes"):
		if not state["territory_nodes"] is Dictionary:
			state["territory_nodes"] = {}
			_repair(repairs, "territory_nodes", "wrong type; defaulted")
		else:
			var nodes: Dictionary = state["territory_nodes"]
			# Sorted so the capacity clamp below runs in a deterministic order —
			# which row eats an over-capacity cut must not depend on Dictionary
			# iteration order, which GDScript does not promise across payloads.
			var ids: Array = nodes.keys()
			ids.sort()
			var cleaned: Dictionary = {}
			for node_id in ids:
				var path := "territory_nodes.%s" % str(node_id)
				var row: Variant = nodes[node_id]
				if not TERRITORY_DEFS.has_id(str(node_id)):
					_repair(repairs, path, "no such territory node; dropped")
					continue
				if not row is Dictionary:
					_repair(repairs, path, "wrong type; dropped")
					continue
				var clean_row: Dictionary = (row as Dictionary).duplicate(true)
				_int(clean_row, "soldiers", 0, path + ".soldiers", repairs)
				if int(clean_row["soldiers"]) < 0:
					clean_row["soldiers"] = 0
					_repair(repairs, path + ".soldiers", "negative; repaired to 0")
				cleaned[str(node_id)] = clean_row
			# Capacity, computed off the CLEANED set — a corrupted board must not
			# be able to claim a capacity larger than the corners it actually has
			# left once the unrecognised rows above are already gone.
			var capacity: int = int(GAME_STATE.SOLDIER_BASE_CAPACITY) 				+ cleaned.size() * int(GAME_STATE.SOLDIER_CAPACITY_PER_BLOCK)
			var running: int = 0
			for node_id in cleaned.keys():
				var clean_row: Dictionary = cleaned[node_id]
				var posted: int = int(clean_row["soldiers"])
				var allowed: int = maxi(0, capacity - running)
				if posted > allowed:
					clean_row["soldiers"] = allowed
					_repair(repairs, "territory_nodes.%s.soldiers" % str(node_id),
						"posted sum exceeded capacity; capped")
					posted = allowed
				running += posted
			state["territory_nodes"] = cleaned
	# `soldiers_idle`: a top-level scalar, repaired the same way
	# `_validate_heat_day` repairs a negative gain.
	if state.has("soldiers_idle"):
		if not (state["soldiers_idle"] is int or state["soldiers_idle"] is float):
			state["soldiers_idle"] = 0
			_repair(repairs, "soldiers_idle", "wrong type; defaulted")
		elif int(state["soldiers_idle"]) < 0:
			state["soldiers_idle"] = 0
			_repair(repairs, "soldiers_idle", "negative; repaired to 0")
		else:
			state["soldiers_idle"] = int(state["soldiers_idle"])

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

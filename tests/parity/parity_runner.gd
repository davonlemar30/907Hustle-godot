extends Node
## Phase 5 parity runner — replays recorded oracle truth against the Godot port.
##
## Runs headless in CI:
##   godot --headless --path . res://tests/parity/parity_runner.tscn
## and quits with a non-zero exit code on any mismatch, so a PR that drifts a
## deterministic primitive fails before it merges.
##
## Fixtures come from scripts/parity/gen_fixtures.mjs, which runs the WEB
## ORACLE and records what it actually produced. This side never re-derives an
## expected value from its own code — recorded truth or nothing.
##
## Sections:
##   hashes   — string_hash + both normalisations (unit, unit10k)
##   seeds    — normalize_seed coercion table
##   streams  — xorshift32 draw sequences (values AND the state cursor per draw)
##   market   — ENFORCED since the part-2 economy port: the hand-copied
##              bias/availability/volatility tables must equal the oracle's
##              (data parity), the lifecycle walks must replay identically
##              through economy.gd's own walk statics (formula parity), and
##              GameState.init_markets() must reproduce createRun's actual
##              opening market and cursor byte-for-byte (end-to-end parity)
##   phone    — the Phase 6 substrate: the bill clock day by day, the deferred
##              restoration a payment schedules, the message-id format (proven
##              in the generator against a message canon actually minted), the
##              held-inbox flush and its order, and the Word Around Town pool
##   attrs    — the Phase 5c substrate: the compatibility offset, the label
##              tiers, the growth curve, and the three shipped chance formulas
##              that read them. PURE oracle — `attributeSystem` is exported, so
##              there is no formula copy here to prove, only agreement to hold
##   recovery — the Phase 5d ladder: canon's layLowPreview against every heat
##              value that changes its answer, and treatmentCost at full price
##   saveload — the Phase 4 acceptance test, automated: a lived-in run through
##              the real dispatch layer → save → scramble → load → deep-compare
##
## Float comparisons use an absolute epsilon of 1e-12: every fixture float is a
## float64 produced by the same arithmetic, and JSON round-trips doubles
## losslessly, so real agreement lands at 0.0 and the epsilon only absorbs
## printf-shaped noise.

const FIXTURES := "res://tests/parity/fixtures/rng_fixtures.json"
const EPS := 1e-12

var _failures: Array[String] = []
var _checks := 0

func _ready() -> void:
	var fixtures: Dictionary = _load_fixtures()
	if fixtures.is_empty():
		_fail("fixtures", "could not read %s" % FIXTURES)
	else:
		_check_hashes(fixtures.get("hashes", []))
		_check_seeds(fixtures.get("seeds", []))
		_check_streams(fixtures.get("streams", []))
		_check_market_static(fixtures.get("market_static", {}))
		_check_market_walks(fixtures.get("market_walks", []))
		_check_initial_markets(fixtures.get("initial_markets", []))
		_check_phone(fixtures.get("phone", {}))
		_check_attributes(fixtures.get("attributes", {}))
		_check_recovery(fixtures.get("recovery", {}))
		_check_save_roundtrip()
	_finish()

func _load_fixtures() -> Dictionary:
	var file := FileAccess.open(FIXTURES, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

# --- sections ---------------------------------------------------------------

func _check_hashes(rows: Array) -> void:
	var rng := get_node("/root/RngManager")
	for row in rows:
		var key: String = str(row["key"])
		_expect_int("hash(%s)" % key.c_escape(), rng.string_hash(key), int(row["hash"]))
		_expect_float("unit(%s)" % key.c_escape(),
			float(rng.string_hash(key)) / rng.HASH_CEILING, float(row["unit"]))
		_expect_float("unit10k(%s)" % key.c_escape(),
			float(rng.string_hash(key) % 10000) / 10000.0, float(row["unit10k"]))

func _check_seeds(rows: Array) -> void:
	var rng := get_node("/root/RngManager")
	for row in rows:
		# JSON numbers arrive as float; canon's normalizeSeed coerces through
		# Number() anyway, so the type wobble is part of what is being tested.
		var input: Variant = row["input"]
		_expect_int("normalize_seed(%s)" % str(input),
			rng.normalize_seed(input), int(row["normalized"]))

func _check_streams(rows: Array) -> void:
	var rng := get_node("/root/RngManager")
	for row in rows:
		var seed_label: String = str(row["seed"])
		var stream = rng.make_stream(row["seed"])
		_expect_int("stream(%s) seed" % seed_label, stream.state, int(row["normalized"]))
		var draw_index := 0
		for draw in row["draws"]:
			var op: String = str(draw["op"])
			var label := "stream(%s) draw %d %s" % [seed_label, draw_index, op]
			match op:
				"next":
					_expect_float(label, stream.next(), float(draw["value"]))
				"int":
					_expect_int(label,
						stream.next_int(int(draw["min"]), int(draw["max"])), int(draw["value"]))
				"pick":
					var items: Array = draw["items"]
					_expect_str(label, str(stream.pick(items)), str(draw["value"]))
			_expect_int(label + " state", stream.state, int(draw["state"]))
			draw_index += 1

## Data parity: the tables the walk runs on. A transcription typo in the
## hand-copied bias/availability/volatility numbers would corrupt every price
## while the formula stayed provably correct — so the tables are checked
## against what the oracle actually carries.
func _check_market_static(static_data: Dictionary) -> void:
	var gs := get_node("/root/GameState")
	for row in static_data.get("products", []):
		var prod: Dictionary = gs.product_by_id(str(row["id"]))
		var label := "static product %s" % str(row["id"])
		_expect_int(label + " base", int(prod.get("base", -1)), int(row["base"]))
		_expect_int(label + " min", int(prod.get("min", -1)), int(row["min"]))
		_expect_int(label + " max", int(prod.get("max", -1)), int(row["max"]))
		_expect_float(label + " volatility", float(prod.get("volatility", -1.0)), float(row["volatility"]))
	for row in static_data.get("areas", []):
		var d: Dictionary = gs.district_by_id(str(row["id"]))
		var label := "static area %s" % str(row["id"])
		_expect_str(label + " role", str(d.get("market_role", "")), str(row["role"]))
		var bias: Dictionary = row["bias"]
		for pid in bias.keys():
			_expect_float(label + " bias." + str(pid),
				float(d.get("bias", {}).get(pid, -1.0)), float(bias[pid]))
		var avail: Dictionary = row["availability"]
		for pid in avail.keys():
			_expect_float(label + " availability." + str(pid),
				float(d.get("availability", {}).get(pid, -1.0)), float(avail[pid]))

## Formula parity: replay each recorded lifecycle (one initial frame + N
## nightly evolve frames on one stream) through economy.gd's own walk statics.
func _check_market_walks(walks: Array) -> void:
	var gs := get_node("/root/GameState")
	var rng := get_node("/root/RngManager")
	var economy_script := preload("res://systems/economy.gd")
	for walk in walks:
		var seed_label: String = str(walk["seed"])
		var stream = rng.make_stream(walk["seed"])
		var local_markets: Dictionary = {}
		var frame_index := 0
		for frame in walk["frames"]:
			var kind: String = str(frame["kind"])
			for d in gs.districts:
				var area_id: String = str(d["id"])
				if kind == "initial":
					local_markets[area_id] = economy_script.walk_initial_area(d, gs.products, stream)
				else:
					economy_script.walk_evolve_area(d, gs.products, local_markets[area_id], stream)
				var want: Dictionary = frame["areas"][area_id]
				var label := "walk(%s) frame %d %s %s" % [seed_label, frame_index, kind, area_id]
				for pid in want["prices"].keys():
					_expect_int(label + " price." + str(pid),
						int(local_markets[area_id]["prices"][pid]), int(want["prices"][pid]))
					_expect_int(label + " avail." + str(pid),
						int(local_markets[area_id]["availability"][pid]), int(want["availability"][pid]))
			_expect_int("walk(%s) frame %d cursor" % [seed_label, frame_index],
				stream.state, int(frame["state"]))
			frame_index += 1

## End-to-end parity, pure oracle: GameState.init_markets() against the
## recorded output of the web build's createRun for the same seed — every
## price, every availability, and the stream cursor left behind.
func _check_initial_markets(rows: Array) -> void:
	var gs := get_node("/root/GameState")
	var original_seed: String = gs.run_seed
	for row in rows:
		var seed_value: Variant = row["seed"]
		# JSON numbers arrive as float; a whole float renders "907.0", which
		# normalizes identically but reads badly — use the int form.
		if seed_value is float and seed_value == floorf(seed_value):
			gs.run_seed = str(int(seed_value))
		else:
			gs.run_seed = str(seed_value)
		gs.init_markets()
		var label := "createRun(%s)" % gs.run_seed
		for area_id in row["areas"].keys():
			var want: Dictionary = row["areas"][area_id]
			var got: Dictionary = gs.markets.get(str(area_id), {})
			if got.is_empty():
				_fail(label, "no market for area %s" % str(area_id))
				continue
			for pid in want["prices"].keys():
				_expect_int("%s %s price.%s" % [label, str(area_id), str(pid)],
					int(got["prices"][pid]), int(want["prices"][pid]))
				_expect_int("%s %s avail.%s" % [label, str(area_id), str(pid)],
					int(got["availability"][pid]), int(want["availability"][pid]))
		_expect_int(label + " rng_state", gs.rng_state, int(row["rng_state"]))
	gs.run_seed = original_seed

## Phase 5d recovery, against canon's two exported selectors.
##
## `layLowPreview` is a `min` against current Heat wrapped around a `max(1, …)`,
## which means it has three regimes — below 1, between 1 and 2, and at or above
## 2 — and the fixture walks all three plus both boundaries. The treatment
## ladder's reveal points are checked here too, because "which card is on
## screen" is the whole design of that screen.
func _check_recovery(fixture: Dictionary) -> void:
	if fixture.is_empty():
		_fail("recovery", "no recovery fixtures")
		return
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var rec: RefCounted = gm.system("recovery") as RefCounted
	if rec == null:
		_fail("recovery", "no recovery system registered")
		return
	var original_heat: float = gs.heat
	var original_health: int = gs.health
	var original_area: String = gs.current_district_id

	for row in fixture["lay_low"]:
		gs.heat = float(row["heat"])
		gs.current_district_id = str(row["area"])
		_expect_float("lay low preview @heat %s" % str(row["heat"]),
			float(rec.lay_low_preview()), float(row["heat_reduction"]))
	for row in fixture["treatment_costs"]:
		_expect_int("treatment cost %d" % int(row["base"]),
			rec.treatment_cost(int(row["base"])), int(row["cost"]))

	# The reveal ladder. Canon surfaces first aid always, the clinic at 82 and
	# the doctor at 55 — the boundary is inclusive on both. The doctor is only
	# ever a TREATMENT card when the contact is open; canon renders the locked
	# card instead of it, never as well as it.
	var original_ledgers: Dictionary = gs.npc_ledgers.duplicate(true)
	gs.npc_ledgers = {}
	for spec in [[100, 1], [83, 1], [82, 2], [56, 2], [55, 2], [10, 2]]:
		gs.health = int(spec[0])
		_expect_int("recovery cards visible @health %d (doctor closed)" % int(spec[0]),
			rec.visible_treatments().size(), int(spec[1]))
	_expect_true("doctor closed on a fresh ledger", not rec.doctor_open())

	# Mina at TRUSTED opens the third rung. Written straight onto the ledger so
	# the check does not depend on which events happen to carry her weights.
	var exposure := get_node("/root/Exposure")
	gs.npc_ledgers = {"mina": [
		{"key": "k1", "type": "discretion", "event": "quiet", "location": "",
			"source": "witnessed", "count": 9, "day": gs.day},
	]}
	_expect_true("mina reaches trusted", exposure.disposition("mina") >= 6.0)
	_expect_true("doctor opens at trusted", rec.doctor_open())
	gs.health = 55
	_expect_int("recovery cards visible @health 55 (doctor open)",
		rec.visible_treatments().size(), 3)
	gs.npc_ledgers = original_ledgers

	gs.heat = original_heat
	gs.health = original_health
	gs.current_district_id = original_area

## Phase 5c attributes, against oracle-recorded truth.
##
## Every fixture in this section came out of canon's own exported
## `attributeSystem`, so there is no copied formula to verify — only agreement.
## The formula rows are the important ones: they pin the compatibility offset
## that three shipped surfaces read, and that this port had wrong from Phase 3d
## until 5c.
func _check_attributes(fixture: Dictionary) -> void:
	if fixture.is_empty():
		_fail("attributes", "no attribute fixtures")
		return
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var attrs: RefCounted = gm.system("attributes") as RefCounted
	if attrs == null:
		_fail("attributes", "no attributes system registered")
		return
	var original_name: String = gs.street_name
	var original_attrs: Dictionary = gs.attributes.duplicate(true)
	gs.street_name = ""

	# Static tables — a transcription typo cannot hide behind a correct formula.
	_expect_str("attrs ids", str(attrs.IDS), str(fixture["ids"]))
	_expect_int("attrs min", attrs.MIN, int(fixture["min"]))
	_expect_int("attrs max", attrs.MAX, int(fixture["max"]))
	_expect_int("attrs cap floor", attrs.GROWTH_CAP_PENALTY_FLOOR,
		int(fixture["growth_cap_penalty_floor"]))
	_expect_float("attrs cap penalty", attrs.GROWTH_CAP_PENALTY,
		float(fixture["growth_cap_penalty"]))
	var want_rates: Dictionary = fixture["growth_rates"]
	for key in want_rates.keys():
		_expect_float("attrs rate %s" % str(key),
			float(attrs.GROWTH_RATES.get(str(key), -1.0)), float(want_rates[key]))
	_expect_int("attrs rate count", attrs.GROWTH_RATES.size(), want_rates.size())
	var want_map: Dictionary = fixture["growth_attributes"]
	for key in want_map.keys():
		_expect_str("attrs trains %s" % str(key),
			str(attrs.GROWTH_ATTRIBUTES.get(str(key), "")), str(want_map[key]))

	# The compatibility offset, across the whole clamp range.
	for row in fixture["compat"]:
		var stored: int = int(row["stored"])
		gs.attributes = {"combat": stored, "charisma": stored, "intelligence": stored}
		_expect_int("attrs normalized(%d)" % stored, attrs.value("combat"), int(row["normalized"]))
		_expect_int("attrs compat(%d)" % stored, attrs.compat("combat"), int(row["compat"]))
		_expect_str("attrs label(%d)" % stored, attrs.label_for("combat"), str(row["label"]))

	# A hand-edited save can carry a float, a negative, or nothing at all.
	for row in fixture["normalize_edge"]:
		var raw: Variant = row["input"]
		if raw == null:
			gs.attributes = {}
		else:
			gs.attributes = {"combat": raw, "charisma": 1, "intelligence": 1}
		_expect_int("attrs normalize(%s)" % str(raw), attrs.value("combat"), int(row["normalized"]))

	for row in fixture["labels"]:
		_expect_str("attrs label tier %d" % int(row["value"]),
			attrs.label(int(row["value"])), str(row["label"]))

	# Growth: the log2 taper and the cap penalty, per activity.
	for row in fixture["growth"]:
		var activity: String = str(row["activity"])
		var label := "attrs growth %s s%d c%d" % [activity, int(row["sessions"]), int(row["current"])]
		_expect_float(label, attrs.growth(int(row["current"]), int(row["sessions"]), activity),
			float(row["growth"]))
		_expect_str(label + " trains", attrs.growth_attribute(activity), str(row["attribute"]))
	var unknown: Dictionary = fixture["growth_unknown"]
	_expect_float("attrs unknown growth", attrs.growth(1, 0, "not_a_real_activity"),
		float(unknown["growth"]))
	_expect_true("attrs unknown trains nothing", attrs.growth_attribute("not_a_real_activity").is_empty())
	_expect_true("attrs unknown read is empty", attrs.growth_for("not_a_real_activity", 0).is_empty())

	_check_attribute_formulas(gs, gm, attrs, fixture["formulas"])
	_check_street_identity(gs, attrs, fixture)

	gs.attributes = original_attrs
	gs.street_name = original_name

## The three shipped surfaces, driven through their real `chance_for` /
## `default_probability`, at every attribute value the fixture records. This is
## the check that would have caught the pinning bug: at a stored 1 the stickup
## term is 0 and tier 1 reads 0.62, not the 0.54 this port shipped for two
## phases.
func _check_attribute_formulas(gs: Node, gm: Node, attrs: RefCounted, rows: Array) -> void:
	var stickup: RefCounted = gm.system("stickup") as RefCounted
	var boost: RefCounted = gm.system("boost") as RefCounted
	var shark: RefCounted = gm.system("shark") as RefCounted
	if stickup == null or boost == null or shark == null:
		_fail("attrs formulas", "a surface system is missing")
		return
	# A tier-1 stickup target with no resistance, and zero heat, so the recorded
	# term is the only thing moving the number.
	var target := {"tier": 1, "resistance": 0}
	var original_heat: float = gs.heat
	gs.heat = 0.0
	for row in rows:
		var stored: int = int(row["stored"])
		gs.attributes = {"combat": stored, "charisma": stored, "intelligence": stored}
		_expect_int("attrs compat combat @%d" % stored,
			attrs.compat("combat"), int(row["combat_compat"]))
		_expect_int("attrs compat intel @%d" % stored,
			attrs.compat("intelligence"), int(row["intelligence_compat"]))
		_expect_int("attrs compat charisma @%d" % stored,
			attrs.compat("charisma"), int(row["charisma_compat"]))
		_expect_float("stickup tier1 chance @%d" % stored,
			stickup.chance_for(target), float(row["stick_tier1_clean"]))
		# Boost tier 1 has no window bonus, so the skill blend is all of it.
		_expect_float("boost tier1 chance @%d" % stored,
			boost.chance_for({"tier": 1, "window": -1}), float(row["boost_tier1"]))
		# Shark: the highest-risk borrower on a $500 note, deliberately — a
		# low-risk borrower clamps to the 0.03 floor at every attribute value,
		# which would make this row agree for the wrong reason.
		var loan := {"borrower_id": _riskiest_borrower(gs), "amount": 500, "term": 7}
		var borrower: Dictionary = gs.borrower_by_id(str(loan["borrower_id"]))
		var expected: float = clampf(
			float(borrower["risk"]) + 0.18 - 0.04 + float(row["shark_term"]), 0.03, 0.82)
		_expect_true("shark prob @%d is off the clamp" % stored,
			expected > 0.03 and expected < 0.82)
		_expect_float("shark default prob @%d" % stored,
			shark.default_probability(loan), expected)
	gs.heat = original_heat

## Street Identity, against canon's own getStreetIdentity / identityProfile.
##
## Identity is cosmetic — it gates nothing and modifies no roll — but it is
## derived from two rules that are easy to get subtly wrong: a lead of MORE than
## the balance margin is a lane (an exact margin is not), and a tie between
## behaviour columns is not a signal and must fall through to the default label.
## The fixtures cover both boundaries in each direction.
func _check_street_identity(gs: Node, attrs: RefCounted, fixture: Dictionary) -> void:
	_expect_int("identity balance margin", attrs.IDENTITY_BALANCE_MARGIN,
		int(fixture["identity_balance_margin"]))
	_expect_int("identity recent days", attrs.IDENTITY_RECENT_DAYS,
		int(fixture["identity_recent_days"]))
	var want_columns: Dictionary = fixture["identity_behavior_columns"]
	for key in want_columns.keys():
		_expect_str("identity column %s" % str(key),
			str(attrs.IDENTITY_BEHAVIOR_COLUMNS.get(str(key), "")), str(want_columns[key]))
	_expect_int("identity column count", attrs.IDENTITY_BEHAVIOR_COLUMNS.size(), want_columns.size())
	var want_matrix: Dictionary = fixture["identity_matrix"]
	for lane in want_matrix.keys():
		var want_row: Dictionary = want_matrix[lane]
		var got_row: Dictionary = attrs.IDENTITY_MATRIX.get(str(lane), {})
		for column in want_row.keys():
			_expect_str("identity matrix %s.%s" % [str(lane), str(column)],
				str(got_row.get(str(column), "")), str(want_row[column]))
	var want_desc: Dictionary = fixture["identity_descriptions"]
	for key in want_desc.keys():
		_expect_str("identity description %s" % str(key),
			str(attrs.IDENTITY_DESCRIPTIONS.get(str(key), "")), str(want_desc[key]))
	_expect_int("identity description count", attrs.IDENTITY_DESCRIPTIONS.size(), want_desc.size())

	var original_day: int = gs.day
	var original_ledgers: Dictionary = gs.npc_ledgers.duplicate(true)
	for row in fixture["identity"]:
		var name: String = str(row["name"])
		gs.attributes = (row["attrs"] as Dictionary).duplicate(true)
		gs.day = int(row["day"])
		gs.npc_ledgers = (row["ledgers"] as Dictionary).duplicate(true)
		_expect_int("identity[%s] recent rows" % name,
			attrs.recent_observations().size(), int(row["recent_count"]))
		var profile: Dictionary = attrs.identity_profile()
		_expect_str("identity[%s] dominant" % name, str(profile["dominant"]), str(row["dominant"]))
		_expect_str("identity[%s] behavior" % name, str(profile["behavior"]), str(row["behavior"]))
		_expect_str("identity[%s] label" % name, str(profile["label"]), str(row["label"]))
		_expect_str("identity[%s] description" % name,
			str(profile["description"]), str(row["description"]))
		_expect_str("identity[%s] street_identity" % name,
			attrs.street_identity(), str(row["identity"]))
	gs.day = original_day
	gs.npc_ledgers = original_ledgers

func _riskiest_borrower(gs: Node) -> String:
	var best := ""
	var best_risk := -1.0
	for b in gs.shark_borrowers:
		if float(b["risk"]) > best_risk:
			best_risk = float(b["risk"])
			best = str(b["id"])
	return best

## Phase 6 phone substrate, against oracle-recorded truth.
##
## Everything here runs through the real dispatch layer, the same way the save
## round-trip does. `street_name` is held empty for the duration so no autosave
## fires — the save file belongs to _check_save_roundtrip, which backs it up and
## puts it back, and a stray autosave from this section would poison that backup.
func _check_phone(phone_fixture: Dictionary) -> void:
	if phone_fixture.is_empty():
		_fail("phone", "no phone fixtures")
		return
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var phone: RefCounted = gm.system("phone") as RefCounted
	if phone == null:
		_fail("phone", "no phone system registered")
		return
	var original_name: String = gs.street_name
	gs.street_name = ""

	_expect_int("phone bill", int(gs.PHONE_BILL), int(phone_fixture["bill"]))
	_check_phone_clock(gs, gm, phone_fixture.get("clock", {}))
	_check_phone_restore(gs, gm, phone_fixture.get("restore", {}))
	_check_phone_message(gs, gm, phone, phone_fixture.get("message", {}))
	_check_phone_held_flush(gs, gm, phone_fixture.get("held_flush", {}))
	_check_phone_intel(gs, phone, phone_fixture.get("intel", []))

	gs.street_name = original_name

## Advance one whole day through the real time system (four slots, the fourth
## crossing), which is what the oracle's advanceRun-to-dayEndPending +
## CONFIRM_END_DAY pair adds up to.
func _cross_day(gm: Node) -> void:
	for i in range(4):
		gm.dispatch("advance_time", {})

func _expect_phone_state(label: String, gs: Node, want: Dictionary) -> void:
	_expect_true(label + " active", gs.phone_active == bool(want["active"]))
	_expect_int(label + " bill_due_day", gs.phone_due_day, int(want["bill_due_day"]))
	_expect_int(label + " days_past_due", gs.phone_days_past_due, int(want["days_past_due"]))
	_expect_int(label + " reactivate_at_slot", gs.phone_reactivate_at_slot, int(want["reactivate_at_slot"]))
	_expect_str(label + " inbox", str(_ids(gs.phone_inbox)), str(want["inbox"]))
	_expect_str(label + " held", str(_ids(gs.phone_held_inbox)), str(want["held"]))

func _ids(messages: Array) -> Array:
	var out: Array = []
	for m in messages:
		out.append(str(m.get("id", "")))
	return out

## The unpaid bill clock, day by day: the counter starts the morning after the
## day that ENDED on the due date, and the line dies once it passes two days of
## grace. This is the fixture that would catch an off-by-one in _settle_phone.
func _check_phone_clock(gs: Node, gm: Node, clock: Dictionary) -> void:
	var frames: Array = clock.get("frames", [])
	if frames.is_empty():
		_fail("phone clock", "no frames")
		return
	gs.reset_to_new_game()
	var index := 0
	for frame in frames:
		var row: Dictionary = frame
		if index > 0:
			_cross_day(gm)
		_expect_int("phone clock frame %d day" % index, gs.day, int(row["day"]))
		_expect_phone_state("phone clock frame %d" % index, gs, row["phone"])
		index += 1

## Paying a dead line does not turn it back on — it schedules the restoration
## for the next slot. Three recorded steps: offline, paid, advanced.
func _check_phone_restore(gs: Node, gm: Node, restore: Dictionary) -> void:
	var steps: Array = restore.get("steps", [])
	if steps.size() < 3:
		_fail("phone restore", "expected 3 steps, got %d" % steps.size())
		return
	# The clock check left the run at the same day the oracle paid on.
	var offline: Dictionary = steps[0]
	_expect_int("phone restore day", gs.day, int(offline["day"]))
	_expect_phone_state("phone restore offline", gs, offline["phone"])

	var cash_before: int = gs.cash
	_expect_true("phone restore pay dispatch", gm.dispatch("pay_phone_bill", {"surface": "store"}))
	_expect_int("phone restore cash spent", cash_before - gs.cash, int(gs.PHONE_BILL))
	_expect_phone_state("phone restore paid", gs, steps[1]["phone"])

	_expect_true("phone restore advance dispatch", gm.dispatch("advance_time", {}))
	_expect_phone_state("phone restore advanced", gs, steps[2]["phone"])

## The message id is `day:slot:string_hash(from:text)`. The generator proved
## that format against a message the oracle actually minted; this replays the
## same from/text at the same day and slot and requires the same id.
func _check_phone_message(gs: Node, gm: Node, phone: RefCounted, fixture: Dictionary) -> void:
	if fixture.is_empty():
		_fail("phone message", "no fixture")
		return
	var want: Dictionary = fixture["message"]
	gs.reset_to_new_game()
	gs.day = int(want["day"])
	var slot_index: int = int(want["slot"])
	gs.time_slot = phone.SLOTS[slot_index]
	gs.time_slots_today = slot_index

	var minted: Dictionary = phone.push_message(str(want["from"]), str(want["text"]))
	_expect_str("phone message id", str(minted["id"]), str(want["id"]))
	_expect_str("phone message from", str(minted["from"]), str(want["from"]))
	_expect_str("phone message text", str(minted["text"]), str(want["text"]))
	_expect_int("phone message day", int(minted["day"]), int(want["day"]))
	_expect_int("phone message slot", int(minted["slot"]), slot_index)
	_expect_true("phone message unread", minted["read"] == want["read"])
	_expect_true("phone message carries no action", not minted.has("action"))
	_expect_str("phone message inbox", str(_ids(gs.phone_inbox)), str(fixture["inbox_before"]))

	_expect_true("phone dismiss dispatch", gm.dispatch("dismiss_phone_message", {"id": str(want["id"])}))
	_expect_str("phone after dismiss", str(_ids(gs.phone_inbox)), str(fixture["after_dismiss"]))
	# Canon returns the input state unchanged when there is nothing to remove;
	# the action layer says so out loud instead, so a re-dismiss must fail.
	_expect_true("phone re-dismiss refused", not gm.dispatch("dismiss_phone_message", {"id": str(want["id"])}))

	phone.push_message(str(want["from"]), str(want["text"]))
	_expect_true("phone clear dispatch", gm.dispatch("clear_phone_inbox", {}))
	_expect_str("phone after clear", str(_ids(gs.phone_inbox)), str(fixture["after_clear"]))
	_expect_true("phone re-clear refused", not gm.dispatch("clear_phone_inbox", {}))

## Restoration flushes the held stack REVERSED onto the front of the live inbox,
## so the newest held text lands on top. Order is the whole point of this one.
func _check_phone_held_flush(gs: Node, gm: Node, flush: Dictionary) -> void:
	if flush.is_empty():
		_fail("phone held flush", "no fixture")
		return
	var at: Dictionary = flush["at"]
	var before: Dictionary = flush["before"]
	gs.reset_to_new_game()
	gs.day = int(at["day"])
	gs.time_slots_today = int(at["slot"])
	gs.phone_active = bool(before["active"])
	gs.phone_due_day = int(before["bill_due_day"])
	gs.phone_days_past_due = int(before["days_past_due"])
	gs.phone_inbox = _stub_messages(before["inbox"], gs.day, int(at["slot"]))
	gs.phone_held_inbox = _stub_messages(before["held"], gs.day, int(at["slot"]))
	gs.cash = 500

	_expect_true("phone flush pay dispatch", gm.dispatch("pay_phone_bill", {"surface": "store"}))
	_expect_true("phone flush advance dispatch", gm.dispatch("advance_time", {}))
	_expect_phone_state("phone flush after", gs, flush["after"])

func _stub_messages(ids: Array, day: int, slot_index: int) -> Array:
	var out: Array = []
	for id in ids:
		out.append({"id": str(id), "from": "Fixture", "text": str(id),
			"day": day, "slot": slot_index, "read": false})
	return out

## The Word Around Town pool, straight out of the oracle's exported PHONE_INTEL.
func _check_phone_intel(gs: Node, phone: RefCounted, rows: Array) -> void:
	if rows.is_empty():
		_fail("phone intel", "no fixture")
		return
	for row in rows:
		var area: String = str(row["area"])
		gs.current_district_id = area
		var slots: Array = row["slots"]
		for slot_index in range(slots.size()):
			gs.time_slot = phone.SLOTS[slot_index]
			var want: Array = slots[slot_index]
			var got: Array = phone.intel()
			_expect_int("phone intel %s slot %d count" % [area, slot_index], got.size(), want.size())
			for line_index in range(mini(got.size(), want.size())):
				_expect_str("phone intel %s slot %d line %d" % [area, slot_index, line_index],
					str(got[line_index]), str(want[line_index]))
	gs.current_district_id = "north_star_lot"

## The Phase 4 acceptance test, automated. Mirrors the manual verification the
## save/load PR shipped with: real dispatches, exposure + curtis + crew +
## territory + shark state, a Color-carrying feed entry and fractional heat —
## then scramble every persisted field silently and load the autosave back.
func _check_save_roundtrip() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var exposure := get_node("/root/Exposure")
	var curtis := get_node("/root/Curtis")
	var saves := get_node("/root/SaveSystem")

	# The test autosaves into the real user:// slot. Whatever run lives there
	# belongs to whoever ran this — put it back exactly as found afterwards.
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	gs.street_name = "Parity"
	gs.reset_to_new_game()
	_expect_true("dispatch market_buy", gm.dispatch("market_buy", {"product_id": "weed", "quantity": 2}))
	_expect_true("dispatch apply_job", gm.dispatch("apply_job", {"job_id": "wash_go"}))
	_expect_true("dispatch work_shift", gm.dispatch("work_shift", {"approach": "work_hard"}))
	_expect_true("dispatch advance_time", gm.dispatch("advance_time", {}))
	_expect_true("dispatch travel", gm.dispatch("travel", {"district_id": "downtown"}))
	exposure.record_observation("yalonda", {"type": "financial", "event": "rent_paid", "source": "household"})
	exposure.broadcast_observation({"type": "violence", "event": "stickup", "channel": "neighborhood", "day": gs.day})
	curtis.raise_awareness(4)
	gs.crew_records["eli"] = {"recruited": true, "loyalty": 6, "tier": 1, "wage_due": 45,
		"wage_missed_since": 0, "recruited_day": 1, "status": "active"}
	gs.held_blocks["wash_and_go_lot"] = {"soldiers": 1, "claimed_day": 1, "income_collected": 55}
	gs.soldiers_idle = 1
	gs.shark_loans.append({"id": 1, "borrower": "nora", "principal": 100, "due_day": 3, "term": 2})
	# Phone inbox (v3): a live message, a held one, and a pending restoration —
	# all three fields have to survive the round-trip.
	var phone_sys: RefCounted = gm.system("phone") as RefCounted
	phone_sys.push_message("Night Owl", "Shift covered. Come by.")
	gs.phone_held_inbox.append({"id": "held:1", "from": "Goodie", "text": "Hit me when the bars are back.",
		"day": gs.day, "slot": 0, "read": false})
	gs.phone_reactivate_at_slot = 9
	gs.log_activity("Parity entry", Color(1, 0.29, 0.239))
	gs.heat = 1.6
	# Attributes (v4): a raised value AND banked sub-point progress, because the
	# progress float is the half that a coercion bug would silently round away.
	gs.attributes["intelligence"] = 3
	gs.attribute_progress["intelligence"] = 0.45
	gs.notify_changed()

	var before: Dictionary = saves.capture()
	saves.save_run()

	# Scramble WITHOUT notify so the autosave on disk stays the good one.
	gs.street_name = "WRONG"
	gs.cash = 99999
	gs.day = 40
	gs.heat = 9.0
	gs.products[0].price = 1
	gs.inventory = {}
	gs.npc_ledgers = {}
	gs.observation_queue = []
	gs.crew_records = {}
	gs.held_blocks = {}
	gs.shark_loans = []
	gs.activity_log = []
	gs.job_records = {}
	gs.curtis_awareness = 0
	gs.curtis_phase = "invisible"
	gs.markets = {}
	gs.rng_state = 0
	gs.phone_inbox = []
	gs.phone_held_inbox = []
	gs.phone_reactivate_at_slot = -1
	gs.attributes = {"combat": 9, "charisma": 9, "intelligence": 9}
	gs.attribute_progress = {"combat": 0.0, "charisma": 0.0, "intelligence": 0.0}

	_expect_true("load_run", saves.load_run())
	var after: Dictionary = saves.capture()
	for key in before.keys():
		# Deep content equality (==), NEVER str(): dictionary key order shifts
		# across a round-trip and str() flags phantom diffs.
		_checks += 1
		if not (before[key] == after.get(key)):
			_fail("saveload", "field '%s' drifted across save→load" % key)
	_expect_int("restored price[0]", int(gs.products[0].price), int(before["product_prices"]["weed"]))
	_expect_true("heat restored as float", gs.heat is float)
	_expect_int("attribute restored", int(gs.attributes["intelligence"]), 3)
	_expect_float("attribute progress restored", float(gs.attribute_progress["intelligence"]), 0.45)
	_expect_true("day restored as int", gs.day is int)

	_check_v2_migration(gs, saves)

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## The v2 → v3 arm, which is the migration chain's first arm that actually
## transforms data rather than stamping a version. A v2 save's activity_log rows
## predate the `day` field; they come back stamped -1 (honestly undated) rather
## than back-dated to a day they did not happen on, and the phone inbox fields
## default in absent.
##
## The reset first is not decoration. `_apply` SKIPS a field the save does not
## carry, which keeps whatever is live rather than GameState's declared default
## — the two are the same thing only on a fresh boot, and a fresh boot is the
## only place load_run() is ever called from. Loading a legacy save over the
## lived-in run this function runs after would leak that run's inbox into the
## assertion and prove nothing about the migration.
func _check_v2_migration(gs: Node, saves: Node) -> void:
	gs.reset_to_new_game()
	var v2_state: Dictionary = {
		"day": 5, "cash": 300, "street_name": "Legacy",
		"activity_log": [
			{"text": "old row", "time": "MORNING", "color": Color(1, 1, 1)},
			{"text": "dated row", "day": 4, "time": "NIGHT", "color": Color(1, 1, 1)},
		],
	}
	var file := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("v2 migration", "could not write the fixture save")
		return
	file.store_string(var_to_str({"save_version": 2, "state": v2_state}))
	file.close()

	_expect_true("v2 migration loads", saves.load_run())
	_expect_int("v2 migration day", gs.day, 5)
	_expect_int("v2 migration undated row", int(gs.activity_log[0].get("day", 0)), -1)
	_expect_int("v2 migration dated row kept", int(gs.activity_log[1].get("day", 0)), 4)
	_expect_true("v2 migration inbox defaults empty", gs.phone_inbox.is_empty())
	_expect_int("v2 migration reactivate defaults", gs.phone_reactivate_at_slot, -1)
	# v3 → v4 is additive: a save that predates the attribute system never
	# trained anything, so canon's fresh-run defaults ARE its history.
	_expect_int("v2 migration attributes default", int(gs.attributes["combat"]), 1)
	_expect_float("v2 migration progress default", float(gs.attribute_progress["combat"]), 0.0)
	# A version this build has never heard of stays invalid, arm or no arm.
	var future := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if future != null:
		future.store_string(var_to_str({"save_version": saves.SAVE_VERSION + 1, "state": v2_state}))
		future.close()
	_expect_true("future version refused", not saves.load_run())

# --- plumbing ---------------------------------------------------------------

func _expect_int(label: String, got: int, want: int) -> void:
	_checks += 1
	if got != want:
		_fail(label, "got %d, want %d" % [got, want])

func _expect_float(label: String, got: float, want: float) -> void:
	_checks += 1
	if absf(got - want) > EPS:
		_fail(label, "got %.17f, want %.17f" % [got, want])

func _expect_str(label: String, got: String, want: String) -> void:
	_checks += 1
	if got != want:
		_fail(label, "got %s, want %s" % [got, want])

func _expect_true(label: String, got: bool) -> void:
	_checks += 1
	if not got:
		_fail(label, "expected true")

func _fail(label: String, detail: String) -> void:
	_failures.append("%s: %s" % [label, detail])

func _finish() -> void:
	if _failures.is_empty():
		print("parity: PASS — %d checks, 0 failures" % _checks)
	else:
		print("parity: FAIL — %d checks, %d failures" % [_checks, _failures.size()])
		for failure in _failures:
			printerr("  " + failure)
	# Deferred: quitting inside _ready while the tree is still initialising is
	# exactly the mid-flush free ScreenManager defers to avoid.
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

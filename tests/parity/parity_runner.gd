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
##   outcome  — the Build 5e resolver: the tier tables, pool construction at
##              every chance boundary, seededPick by cumulative weight, the
##              full action x chance x attribute resolution grid, and the two
##              thresholds proven rather than asserted — 400 advantage pairs
##              where the second look demonstrably upgrades, and 1000 seeds
##              that produce catastrophes at Combat 5 and none at Combat 6
##   stickup  — the Build 5e vertical proof, driven through the real dispatch
##              layer: one case per tier asserting the whole consequence
##              spread (cash, heat, health, Curtis, the Exposure footprint),
##              plus the reload replay and the market cursor holding still
##   907list  — FS-001.2 opportunity ownership: boards pinned to literal
##              ids, consumption excluded from the pool, the system-level
##              duplicate guard, the lazy day reset, the v5 -> v6
##              migration including the history it cannot recover, and the
##              completed-flip financial observation on both channels with
##              Curtis filtered by volume
##   fs001    — the shared Requirement Evaluator against web PR #98, every
##              type with a pass, a fail and both sides of its boundary;
##              plus the rank labels, the rank-curve clamp, and the crew
##              capability table. Followed by a regression block pinning
##              recruit/pay/promote/dismiss and the presence effects, so
##              "structural only" is a claim the suite actually checks
##   lifecycle— FS-001.6: the day_ending / day_crossed ordering contract,
##              proven by recording the actual emission order against the
##              clock rather than trusting it; then the Named Crew
##              Operations substrate — discovery latching, the planning
##              window, one day per person, night settlement, and the
##              port-seam checks oracle fixtures structurally cannot reach
##   runboard — FS-001.7: the 907List domain adapter. Selection order and every
##              stop reason on controlled boards, shared consumption across the
##              player/Pherris seam, settlement through the same path a personal
##              sale uses, and the three-way leak check that keeps delegation
##              from being strictly better than doing it yourself
##   presentation — FS-001.8: the reads the screens are built on. A preview
##              that disagrees with what select() then does is worse than no
##              preview, so the two are held to each other directly.
##   frozen   — FS-003.1: the consequence-adjacent behaviour the encounter
##              engine is about to build on top of. Boost end to end (which
##              had none), the fence, the heat write path, cash discipline on
##              refused actions, and the dispatch-ownership guard that shipped
##              untested. Deliberately does NOT restate what earlier sections
##              already pin — see the section header.
##   lifecycle order — FS-003.2: the night sequence as a declared list rather
##              than an accident of signal-connection order. The trace is
##              asserted literally, because "the order is right" is only
##              meaningful if the order is written down somewhere a test reads.
##   saveload — the Phase 4 acceptance test, automated: a lived-in run through
##              the real dispatch layer → save → scramble → load → deep-compare
##
## Float comparisons use an absolute epsilon of 1e-12: every fixture float is a
## float64 produced by the same arithmetic, and JSON round-trips doubles
## losslessly, so real agreement lands at 0.0 and the epsilon only absorbs
## printf-shaped noise.

const FIXTURES := "res://tests/parity/fixtures/rng_fixtures.json"
## Build 5e keeps its fixtures in their own file: rng_fixtures.json records
## primitives and system reads, this one records whole actions resolving.
const OUTCOME_FIXTURES := "res://tests/parity/fixtures/outcome_resolver/outcome_fixtures.json"
## FS-001.5: the requirement evaluator and the crew rank/capability tables.
const FS001_FIXTURES := "res://tests/parity/fixtures/requirements/fs001_fixtures.json"
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
		_check_outcome_resolver(_load_json(OUTCOME_FIXTURES))
		_check_stickup_tiers()
		_check_907list_ownership()
		_check_fs001_foundation(_load_json(FS001_FIXTURES))
		_check_crew_regression()
		_check_day_lifecycle()
		_check_crew_operations()
		_check_run_the_board()
		_check_operation_presentation()
		_check_frozen_behavior()
		_check_day_lifecycle_order()
		_check_wallet_and_heat()
		_check_consequence_state()
		_check_consequence_engine()
		_check_outcome_projection()
		_check_boost_caught()
		_check_save_roundtrip()
	_finish()

func _load_fixtures() -> Dictionary:
	return _load_json(FIXTURES)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
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
	_expect_true("exposure reads do not create empty ledgers", gs.npc_ledgers.is_empty())

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
	var jobs_system: RefCounted = gm.system("jobs") as RefCounted
	var saves := get_node("/root/SaveSystem")

	# The test autosaves into the real user:// slot. Whatever run lives there
	# belongs to whoever ran this — put it back exactly as found afterwards.
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	# Recovery's permanent menu latch used to be written by More._bind_content,
	# after SaveSystem had already handled state_changed. Prove a successful
	# action reconciles it before autosave, and that the saved latch survives once
	# the immediate health/Heat trigger is no longer live.
	gs.street_name = "Latch"
	gs.reset_to_new_game()
	gs.health = 90
	gs.recovery_introduced = false
	_expect_true("recovery latch action succeeds",
		gm.dispatch("market_buy", {"product_id": "weed", "quantity": 1}))
	_expect_true("recovery latch set before notification", gs.recovery_introduced)
	gs.health = gs.health_max
	gs.heat = 0.0
	gs.recovery_introduced = false
	_expect_true("recovery latch save reloads", saves.load_run())
	_expect_true("recovery latch persisted after trigger clears", gs.recovery_introduced)

	gs.street_name = "Parity"
	gs.reset_to_new_game()
	_expect_true("dispatch market_buy", gm.dispatch("market_buy", {"product_id": "weed", "quantity": 2}))
	# Applying is a real interview as of Build 5e, so the run has to actually be
	# hired before it can work a shift. The seed is fixed by reset_to_new_game,
	# and the interview is keyed on day and slot — so this walks slots until the
	# job lands rather than pinning a seed that a later balance change would
	# quietly invalidate. Two days of slots is far more than the 0.62 floor needs.
	var hired := false
	for _attempt in 8:
		gm.dispatch("apply_job", {"job_id": "wash_go"})
		if gs.active_job_id == "wash_go":
			hired = true
			break
		gm.dispatch("advance_time", {})
	_expect_true("dispatch apply_job eventually hires", hired)
	# The shift needs a slot wash_go actually runs, and the walk above may have
	# left the run standing in one it does not.
	for _attempt in 4:
		if jobs_system.shift_blocker().is_empty():
			break
		gm.dispatch("advance_time", {})
	_expect_true("dispatch work_shift", gm.dispatch("work_shift", {"approach": "work_hard"}))
	_expect_true("dispatch advance_time", gm.dispatch("advance_time", {}))
	_expect_true("dispatch travel", gm.dispatch("travel", {"district_id": "downtown"}))
	# Exposure and Curtis are exercised by the dispatched systems above. Keep a
	# persisted awareness value for the round-trip without bypassing the dispatch
	# ownership guard on their public mutators.
	gs.curtis_awareness = 4
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
	_expect_true("atomic save leaves no temp file", not FileAccess.file_exists(saves.SAVE_TEMP_PATH))

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
## Every additive field omitted by a legacy save must come from a fresh
## GameState template, never from the run that happens to be live when Load is
## pressed. The test deliberately contaminates every omitted field before load;
## a skip-on-missing loader leaks all of them into the restored run.
func _check_v2_migration(gs: Node, saves: Node) -> void:
	# Build a historically plausible v2 save: all fields that existed then, with
	# the later phone/attribute/Recovery additions removed.
	gs.reset_to_new_game()
	var opening_markets: Dictionary = gs.markets.duplicate(true)
	var opening_rng_state: int = gs.rng_state
	var v2_state: Dictionary = saves.capture()
	v2_state["day"] = 5
	v2_state["cash"] = 300
	v2_state["street_name"] = "Legacy"
	v2_state["activity_log"] = [
		{"text": "old row", "time": "MORNING", "color": Color(1, 1, 1)},
		{"text": "dated row", "day": 4, "time": "NIGHT", "color": Color(1, 1, 1)},
	]
	for added in ["phone_inbox", "phone_held_inbox", "phone_reactivate_at_slot",
			"attributes", "attribute_progress", "recovery_introduced"]:
		v2_state.erase(added)

	# Contaminate the live singleton. None of this belongs to Legacy.
	gs.phone_inbox = [{"id": "wrong"}]
	gs.phone_held_inbox = [{"id": "also-wrong"}]
	gs.phone_reactivate_at_slot = 999
	gs.attributes = {"combat": 9, "charisma": 9, "intelligence": 9}
	gs.attribute_progress = {"combat": 0.9, "charisma": 0.9, "intelligence": 0.9}
	gs.recovery_introduced = true
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
	_expect_true("v2 migration recovery latch default", not gs.recovery_introduced)

	# v1 predates markets and the stream cursor. A lived-in board must not leak
	# through omission; load_run reconstructs the opening board from run_seed.
	var v1_state: Dictionary = v2_state.duplicate(true)
	v1_state.erase("markets")
	v1_state.erase("rng_state")
	gs.markets = {"contaminated": {}}
	gs.rng_state = 123456789
	var v1_file := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if v1_file == null:
		_fail("v1 migration", "could not write the fixture save")
		return
	v1_file.store_string(var_to_str({"save_version": 1, "state": v1_state}))
	v1_file.close()
	_expect_true("v1 migration loads", saves.load_run())
	_expect_true("v1 migration rebuilds markets", gs.markets == opening_markets)
	_expect_int("v1 migration rebuilds rng cursor", gs.rng_state, opening_rng_state)
	_expect_true("v1 migration drops live market", not gs.markets.has("contaminated"))

	# A version this build has never heard of stays invalid, arm or no arm.
	var future := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if future != null:
		future.store_string(var_to_str({"save_version": saves.SAVE_VERSION + 1, "state": v2_state}))
		future.close()
	_expect_true("future version refused", not saves.load_run())
	var malformed_version := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if malformed_version != null:
		malformed_version.store_string(var_to_str({"save_version": "five", "state": v2_state}))
		malformed_version.close()
	_expect_true("malformed version refused", not saves.load_run())
	var malformed_state := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if malformed_state != null:
		malformed_state.store_string(var_to_str({"save_version": saves.SAVE_VERSION,
			"state": {"day": [], "cash": 300, "street_name": "Broken"}}))
		malformed_state.close()
	_expect_true("malformed required field refused", not saves.load_run())

## Build 5e — the tiered outcome resolver, against recorded oracle truth.
##
## The strongest position the harness can take on this system: canon exports
## `buildOutcomePool`, `seededPick`, `resolveWithAttribute` and `resolveAction`,
## so every expected value here came out of the oracle's own functions. There is
## no formula copy on this side to prove — only agreement to hold.
##
## What is worth knowing about the sections below:
##
##   - **Pool ORDER is checked, not just content.** seeded_pick walks cumulative
##     weight in array order, so a pool with the right entries in the wrong
##     order resolves different tiers from the same hash. That is the failure a
##     content-only check would wave through.
##   - **The thresholds are proven, not asserted.** The advantage fixture
##     records how many of its 400 pairs the second look actually upgraded; if
##     that ever reads 0 the fixture has stopped testing anything, so the count
##     itself is checked. Immunity does the same in the other direction: the
##     same 1000 seeds must produce catastrophes at Combat 5 and none at 6.
func _check_outcome_resolver(fixture: Dictionary) -> void:
	if fixture.is_empty():
		_fail("outcome", "could not read %s" % OUTCOME_FIXTURES)
		return
	var gm := get_node("/root/GameManager")
	var resolver: RefCounted = gm.system("outcome_resolver") as RefCounted
	if resolver == null:
		_fail("outcome", "no outcome_resolver system registered")
		return

	_check_outcome_tables(resolver, fixture)
	_check_outcome_pools(resolver, fixture)
	_check_outcome_picks(resolver, fixture)
	_check_outcome_resolutions(resolver, fixture)
	_check_outcome_thresholds(resolver, fixture)
	_check_outcome_observations(resolver, fixture)

## Data parity. A transcription typo in a hand-copied weight would corrupt every
## resolution while the pipeline stayed provably correct, so the tables are
## checked against what the oracle actually carries — including their SIZE, so a
## missing action type cannot pass by simply never being looked up.
func _check_outcome_tables(resolver: RefCounted, fixture: Dictionary) -> void:
	_expect_int("outcome advantage threshold", resolver.ADVANTAGE_THRESHOLD,
		int(fixture["advantage_threshold"]))
	_expect_int("outcome immunity threshold", resolver.CATASTROPHE_IMMUNITY_THRESHOLD,
		int(fixture["catastrophe_immunity_threshold"]))
	_expect_int("outcome attribute min", resolver.ATTRIBUTE_MIN, int(fixture["attribute_min"]))
	_expect_int("outcome attribute max", resolver.ATTRIBUTE_MAX, int(fixture["attribute_max"]))

	var want_values: Dictionary = fixture["outcome_values"]
	for tier in want_values.keys():
		_expect_int("outcome value %s" % str(tier),
			int(resolver.OUTCOME_VALUES.get(str(tier), -99)), int(want_values[tier]))
	_expect_int("outcome value count", resolver.OUTCOME_VALUES.size(), want_values.size())

	var want_map: Dictionary = fixture["action_attribute_map"]
	for action in want_map.keys():
		_expect_str("outcome attribute for %s" % str(action),
			resolver.attribute_for(str(action)), str(want_map[action]))
	_expect_int("outcome attribute map count", resolver.ACTION_ATTRIBUTE_MAP.size(), want_map.size())
	_expect_str("outcome attribute for unknown", resolver.attribute_for("not_a_real_action"), "")

	# The shapes themselves, key order included — see the section header.
	var want_shapes: Dictionary = fixture["outcome_shapes"]
	_expect_int("outcome shape count", resolver.OUTCOME_SHAPES.size(), want_shapes.size())
	for action in want_shapes.keys():
		var got_shape: Dictionary = resolver.OUTCOME_SHAPES.get(str(action), {})
		var want_shape: Dictionary = want_shapes[action]
		for half in ["success", "failure"]:
			var want_half: Dictionary = want_shape.get(half, {})
			var got_half: Dictionary = got_shape.get(half, {})
			_expect_str("outcome shape %s.%s key order" % [str(action), half],
				str(got_half.keys()), str(want_half.keys()))
			for tier in want_half.keys():
				_expect_float("outcome shape %s.%s.%s" % [str(action), half, str(tier)],
					float(got_half.get(str(tier), -1.0)), float(want_half[tier]))

## Pool construction at every chance boundary, including 0 and 1 where one half
## of the shape weighs nothing at all.
func _check_outcome_pools(resolver: RefCounted, fixture: Dictionary) -> void:
	for row in fixture["pools"]:
		var action: String = str(row["action_type"])
		var chance: float = float(row["chance"])
		var label := "outcome pool %s @%.2f" % [action, chance]
		var got: Array = resolver.build_outcome_pool(action, chance)
		var want: Array = row["pool"]
		_expect_int(label + " size", got.size(), want.size())
		if got.size() != want.size():
			continue
		var total: float = 0.0
		for i in want.size():
			var got_entry: Dictionary = got[i]
			var want_entry: Dictionary = want[i]
			_expect_str(label + " [%d] tier" % i, str(got_entry["tier"]), str(want_entry["tier"]))
			_expect_int(label + " [%d] value" % i, int(got_entry["value"]), int(want_entry["value"]))
			_expect_float(label + " [%d] weight" % i,
				float(got_entry["weight"]), float(want_entry["weight"]))
			total += float(got_entry["weight"])
		_expect_float(label + " weight total", total, float(row["weight_total"]))
	# An action type canon has never heard of builds nothing, and nothing
	# resolves to a plain failure rather than to null.
	var unknown: Dictionary = fixture["pool_unknown"]
	_expect_int("outcome pool unknown is empty",
		resolver.build_outcome_pool("not_a_real_action", 0.5).size(),
		(unknown["pool"] as Array).size())
	var fallback: Dictionary = resolver.resolve_action(
		"not_a_real_action", 0.5, 4, "seed", "nope")
	_expect_str("outcome unknown resolves to", str(fallback["tier"]),
		str((unknown["resolved"] as Dictionary)["tier"]))

## seededPick by cumulative weight, on the oracle's own hand-built pools. The
## `zeroed` pool is the modulo fallback: the one branch a real chance never
## reaches, ported because bit-exact is bit-exact.
func _check_outcome_picks(resolver: RefCounted, fixture: Dictionary) -> void:
	var pools := {
		"even": [{"tier": "clean", "value": 3, "weight": 1.0},
			{"tier": "messy", "value": 2, "weight": 1.0}],
		"skewed": [{"tier": "clean", "value": 3, "weight": 0.05},
			{"tier": "failure", "value": 1, "weight": 0.95}],
		"zeroed": [{"tier": "clean", "value": 3, "weight": 0.0},
			{"tier": "messy", "value": 2, "weight": 0.0},
			{"tier": "failure", "value": 1, "weight": 0.0}],
		"single": [{"tier": "catastrophic", "value": 0, "weight": 0.4}],
	}
	for row in fixture["picks"]:
		# The fixture records canon's single joined key; this side splits it at
		# the first colon, which is the same string once seeded_random rejoins it.
		var key: String = str(row["key"])
		var split: int = key.find(":")
		var picked: Variant = resolver.seeded_pick(
			pools[str(row["pool"])], key.substr(0, split), key.substr(split + 1))
		_expect_str("outcome pick %s" % key,
			str(picked["tier"]) if picked != null else "<null>", str(row["tier"]))
	var empty: Dictionary = fixture["pick_empty"]
	_expect_true("outcome pick of an empty pool is null",
		resolver.seeded_pick([], "907hustle", "pick:empty") == null
			and empty["empty_array"] == null)

## The whole grid: every action type, every chance step, every attribute value
## from the floor to the ceiling — so both thresholds are crossed inside it.
func _check_outcome_resolutions(resolver: RefCounted, fixture: Dictionary) -> void:
	for row in fixture["resolutions"]:
		var outcome: Dictionary = resolver.resolve_action(
			str(row["action_type"]), float(row["chance"]), int(row["attribute"]),
			str(row["seed"]), str(row["context"]))
		var label := "outcome resolve %s" % str(row["context"])
		_expect_str(label, str(outcome["tier"]), str(row["tier"]))
		_expect_int(label + " value", int(outcome["value"]), int(row["value"]))

	# Determinism, and the reload case with it: resolving the same key twice must
	# give the same answer, which is what makes a save/load round-trip replay.
	for row in fixture["determinism"]:
		var first: Dictionary = resolver.resolve_action(
			"dealer_robbery", 0.6, 4, str(row["seed"]), str(row["context"]))
		var again: Dictionary = resolver.resolve_action(
			"dealer_robbery", 0.6, 4, str(row["seed"]), str(row["context"]))
		var label := "outcome determinism %s:%s" % [str(row["seed"]), str(row["context"])]
		_expect_str(label, str(first["tier"]), str(row["tier"]))
		_expect_str(label + " repeats", str(again["tier"]), str(row["tier"]))

	# The stickup key canon actually builds. A right resolver on a wrong key is
	# still a wrong game, so the call site's key shape is pinned here.
	for row in fixture["stickup_keys"]:
		var outcome: Dictionary = resolver.resolve_action(
			"robbery", float(row["chance"]), int(row["attribute"]),
			str(row["seed"]), str(row["context"]))
		_expect_str("outcome stickup key %s @%d" % [str(row["context"]), int(row["attribute"])],
			str(outcome["tier"]), str(row["tier"]))
		# And the port's own call site builds that same context string.
		_expect_str("outcome stickup key shape %s" % str(row["context"]),
			"stickup:%d:%d:%s" % [int(row["day"]), int(row["slot"]), str(row["target_id"])],
			str(row["context"]))

	for row in fixture["success_tiers"]:
		_expect_true("outcome is_success_tier(%s)" % str(row["tier"]),
			resolver.is_success_tier(str(row["tier"])) == bool(row["success"]))

## Advantage and immunity, proven rather than asserted — see the section header.
func _check_outcome_thresholds(resolver: RefCounted, fixture: Dictionary) -> void:
	var advantage: Dictionary = fixture["advantage"]
	var upgraded := 0
	for row in advantage["cases"]:
		var below: Dictionary = resolver.resolve_action(
			"robbery", 0.5, 2, str(row["seed"]), str(row["context"]))
		var at: Dictionary = resolver.resolve_action(
			"robbery", 0.5, 3, str(row["seed"]), str(row["context"]))
		var label := "outcome advantage %s" % str(row["context"])
		_expect_str(label + " below", str(below["tier"]), str(row["below_tier"]))
		_expect_str(label + " at", str(at["tier"]), str(row["at_tier"]))
		# The contract of the ordinal: a second look may never make it worse.
		_expect_true(label + " never downgrades", int(at["value"]) >= int(below["value"]))
		if str(below["tier"]) != str(at["tier"]):
			upgraded += 1
	_expect_int("outcome advantage upgrade count", upgraded, int(advantage["upgraded"]))
	_expect_true("outcome advantage actually upgrades something", upgraded > 0)

	var immunity: Dictionary = fixture["immunity"]
	var tally := {"below": {}, "at": {}}
	for i in int(immunity["sweep"]):
		var context := "immunity:%d" % i
		var below: Dictionary = resolver.resolve_action("robbery", 0.35, 5, "907hustle", context)
		var at: Dictionary = resolver.resolve_action("robbery", 0.35, 6, "907hustle", context)
		tally["below"][below["tier"]] = int(tally["below"].get(below["tier"], 0)) + 1
		tally["at"][at["tier"]] = int(tally["at"].get(at["tier"], 0)) + 1
	for side in ["below", "at"]:
		var want_tally: Dictionary = immunity["tally"][side]
		for tier in want_tally.keys():
			_expect_int("outcome immunity %s %s" % [side, str(tier)],
				int(tally[side].get(str(tier), 0)), int(want_tally[tier]))
		_expect_int("outcome immunity %s tier count" % side,
			(tally[side] as Dictionary).size(), want_tally.size())
	# Said plainly, because it is the acceptance criterion in its own words.
	_expect_true("outcome Combat 5 can be catastrophic",
		int(tally["below"].get("catastrophic", 0)) > 0)
	_expect_true("outcome Combat 6 never catastrophic",
		int(tally["at"].get("catastrophic", 0)) == 0)

	# Crew backup as an effective level, re-clamped to the attribute ceiling.
	for row in fixture["bonus"]:
		var outcome: Dictionary = resolver.resolve_action(
			"robbery", 0.4, int(row["attribute"]), str(row["seed"]), str(row["context"]),
			int(row["bonus"]))
		_expect_str("outcome bonus %s" % str(row["context"]), str(outcome["tier"]), str(row["tier"]))

## The observation table, which is the half of this build the resolver does not
## roll for: outcome quality decides the footprint, and the footprint is data.
func _check_outcome_observations(resolver: RefCounted, fixture: Dictionary) -> void:
	var want: Dictionary = fixture["outcome_observations"]
	_expect_int("outcome observation action count", resolver.OUTCOME_OBSERVATIONS.size(), want.size())
	for action in want.keys():
		var want_tiers: Dictionary = want[action]
		for tier in want_tiers.keys():
			var want_rows: Array = want_tiers[tier]
			var got_rows: Array = resolver.observations_for(str(action), str(tier))
			var label := "outcome obs %s.%s" % [str(action), str(tier)]
			_expect_int(label + " count", got_rows.size(), want_rows.size())
			if got_rows.size() != want_rows.size():
				continue
			for i in want_rows.size():
				var got_row: Dictionary = got_rows[i]
				var want_row: Dictionary = want_rows[i]
				for field in ["type", "event", "channel"]:
					_expect_str("%s [%d] %s" % [label, i, field],
						str(got_row.get(field, "")), str(want_row.get(field, "")))
				# Every category the table names has to be one Exposure knows,
				# or the row is silently dropped at record time.
				_expect_true("%s [%d] category is real" % [label, i],
					str(want_row.get("type", "")) in Exposure.CATEGORIES)
				_expect_true("%s [%d] channel is real" % [label, i],
					Exposure.CHANNELS.has(str(want_row.get("channel", ""))))
	# A tier a shape does not carry reads empty rather than assuming a row —
	# job_interview has no catastrophic, because the worst case is not hired.
	_expect_int("outcome obs job_interview has no catastrophic",
		resolver.observations_for("job_interview", "catastrophic").size(), 0)
	_expect_int("outcome obs unknown action",
		resolver.observations_for("not_a_real_action", "clean").size(), 0)

## Build 5e's vertical proof: a robbery resolving into each of the four tiers,
## driven through the REAL dispatch layer rather than by calling the resolver.
##
## Unlike the section above, these are not oracle fixtures and they do not
## pretend to be. Canon's failure branch runs through an arrest system, dirty
## cash, district heat weighting, a witness roll and a retaliation queue, none of
## which this build has; the consequence spread here is the port's, specified in
## the build brief and documented at the top of stickup.gd. What IS oracle-exact
## is the tier pick, and that is proven in `_check_outcome_resolver` above.
##
## So what this proves is the contract between them: given a tier, the right
## money moves, the right heat lands, the right injury is rolled, Curtis reads it
## the right way, and the block learns exactly the rows canon's table names.
##
## The probe target is deliberate: Wash & Go regular is tier 1, resistance 0,
## heat 2, and runs in any slot, so the only things moving the number are the
## ones under test. Combat 1 keeps every tier live — below the advantage
## threshold and well below immunity.
const STICKUP_PROBE_TARGET := "washgo_regular"
const STICKUP_PROBE_COMBAT := 1

## What each tier is contracted to do to a heat-2, take-[30,50] target.
## `heat` is the absolute amount `_apply_heat` should land with no crew.
const STICKUP_EXPECTED := {
	"clean": {"paid": true, "heat": 1.0, "injury": [0, 0], "awareness": 1},
	"messy": {"paid": true, "heat": 2.0, "injury": [5, 10], "awareness": 2},
	"failure": {"paid": false, "heat": 1.0, "injury": [0, 0], "awareness": 1},
	# Three, and the reason it is three is the whole point of FS-001.2's Curtis
	# filter. The catastrophic footprint DOES carry a `network` row — but the row
	# is `heat_exposure`, and heat_exposure does not clear Curtis's network
	# filter (only violence / defiance / growth do, plus financial over $200).
	# So it never lands on him and never credits the extra point.
	#
	# Build 5e recorded this as FOUR, and it was four, because the filter was not
	# ported yet. That was the port over-crediting Curtis on every catastrophic
	# robbery, and this is the correction. Verified against the oracle:
	# `clearsCurtisFilter({type: "heat_exposure"})` is false.
	"catastrophic": {"paid": false, "heat": 3.0, "injury": [15, 25], "awareness": 3},
}

func _check_stickup_tiers() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var exposure := get_node("/root/Exposure")
	var stickup: RefCounted = gm.system("stickup") as RefCounted
	var resolver: RefCounted = gm.system("outcome_resolver") as RefCounted
	if stickup == null or resolver == null:
		_fail("stickup tiers", "stickup or outcome_resolver is missing")
		return
	var target: Dictionary = gs.stick_target_by_id(STICKUP_PROBE_TARGET)
	if target.is_empty():
		_fail("stickup tiers", "probe target %s is gone" % STICKUP_PROBE_TARGET)
		return

	for tier in ["clean", "messy", "failure", "catastrophic"]:
		var day: int = _find_stickup_day(gs, stickup, resolver, str(tier))
		if day < 0:
			_fail("stickup %s" % str(tier), "no day in the scan window produces this tier")
			continue
		_run_stickup_case(gs, gm, exposure, target, str(tier), day)

	_check_stickup_reload(gs, gm, stickup, resolver)
	_check_stickup_rng_isolation(gs, gm, resolver)
	_reset_stickup_probe(gs)

## Put the run in the shape the probe needs: Spenard, morning, no heat, no crew,
## Combat 1, and the daily cap clear.
func _reset_stickup_probe(gs: Node) -> void:
	gs.reset_to_new_game()
	gs.current_district_id = "north_star_lot"
	gs.time_slots_today = 0
	gs.time_slot = "MORNING"
	gs.heat = 0.0
	gs.attributes = {"combat": STICKUP_PROBE_COMBAT, "charisma": 1, "intelligence": 1}
	gs.stick_daily_count = 0

## Which day resolves to the tier we want. The roll is keyed on day and slot, so
## walking the day is walking the seed — no seed is pinned, which means a
## balance change moves this scan instead of silently invalidating it.
func _find_stickup_day(gs: Node, stickup: RefCounted, resolver: RefCounted, tier: String) -> int:
	_reset_stickup_probe(gs)
	var target: Dictionary = gs.stick_target_by_id(STICKUP_PROBE_TARGET)
	var chance: float = stickup.chance_for(target)
	for day in range(1, 400):
		var key := "stickup:%d:0:%s" % [day, STICKUP_PROBE_TARGET]
		var outcome: Dictionary = resolver.resolve_action(
			"robbery", chance, STICKUP_PROBE_COMBAT, gs.run_seed, key)
		if str(outcome["tier"]) == tier:
			return day
	return -1

## The first `wanted` days that resolve to this tier, for checks that need more
## than one sample to be worth anything.
func _find_stickup_days(gs: Node, stickup: RefCounted, resolver: RefCounted,
		tier: String, wanted: int) -> Array:
	_reset_stickup_probe(gs)
	var target: Dictionary = gs.stick_target_by_id(STICKUP_PROBE_TARGET)
	var chance: float = stickup.chance_for(target)
	var out: Array = []
	for day in range(1, 400):
		var key := "stickup:%d:0:%s" % [day, STICKUP_PROBE_TARGET]
		var outcome: Dictionary = resolver.resolve_action(
			"robbery", chance, STICKUP_PROBE_COMBAT, gs.run_seed, key)
		if str(outcome["tier"]) == tier:
			out.append(day)
			if out.size() >= wanted:
				break
	return out

## One tier, end to end: snapshot, dispatch, and hold the whole spread to
## account — including which channel each observation actually travelled on.
func _run_stickup_case(gs: Node, gm: Node, exposure: Node, target: Dictionary,
		tier: String, day: int) -> void:
	_reset_stickup_probe(gs)
	gs.day = day
	var want: Dictionary = STICKUP_EXPECTED[tier]
	var label := "stickup %s" % tier

	var cash_before: int = gs.cash
	var health_before: int = gs.health
	var heat_before: float = gs.heat
	var awareness_before: int = gs.curtis_awareness
	var attempts_before: int = gs.stick_attempts
	var rep_before: int = gs.stick_rep
	var successes_before: int = gs.stick_successes
	var queue_before: int = gs.observation_queue.size()
	var slot_before: int = gs.time_slots_today

	_expect_true(label + " dispatches", gm.dispatch("stickup", {"target_id": STICKUP_PROBE_TARGET}))

	# Money. The take band is the target's, unchanged by the tier — what the
	# tier decides is whether it arrives at all.
	var took: int = gs.cash - cash_before
	if bool(want["paid"]):
		_expect_true(label + " pays inside the take band",
			took >= int(target["take"][0]) and took <= int(target["take"][1]))
	else:
		_expect_int(label + " pays nothing", took, 0)

	# Heat, to the tenth. Fractional on purpose: rounding is what flattened the
	# difference between a quiet take and a loud one on a 1-heat target.
	_expect_float(label + " heat", snappedf(gs.heat - heat_before, 0.001), float(want["heat"]))

	# Health. A band of [0, 0] means no injury roll was keyed at all.
	var hurt: int = health_before - gs.health
	var band: Array = want["injury"]
	_expect_true(label + " health cost in band",
		hurt >= int(band[0]) and hurt <= int(band[1]))

	# Curtis.
	_expect_int(label + " curtis awareness",
		gs.curtis_awareness - awareness_before, int(want["awareness"]))

	# Counters the surface has always kept, still kept.
	_expect_int(label + " attempts", gs.stick_attempts - attempts_before, 1)
	var scored: int = 1 if bool(want["paid"]) else 0
	_expect_int(label + " rep", gs.stick_rep - rep_before, scored)
	_expect_int(label + " successes", gs.stick_successes - successes_before, scored)
	_expect_int(label + " daily count", gs.stick_daily_count, 1)

	# A robbery is still exactly one slot, tier or no tier.
	_expect_int(label + " advances one slot", gs.time_slots_today, slot_before + 1)

	# The Exposure footprint, row for row against canon's table. A `direct` row
	# lands in the ledger the same turn; `neighborhood` and `network` take a day,
	# so they are in the queue instead. Checking the wrong one would pass a
	# clean robbery that had quietly gone out over the network.
	var specs: Array = (gm.system("outcome_resolver") as RefCounted).observations_for("robbery", tier)
	var queued_rows: int = gs.observation_queue.size() - queue_before
	var immediate: int = 0
	var delayed: int = 0
	for spec in specs:
		var channel: String = str(spec["channel"])
		var listeners := 0
		for npc_id in exposure.NPC_LENSES.keys():
			if not channel in exposure.NPC_CHANNELS.get(str(npc_id), []):
				continue
			# Derived, not hardcoded: Curtis's network ear is filtered, so the
			# expected row count has to ask the same question the broadcast does.
			if npc_id == "curtis" and channel == "network" \
					and not exposure.clears_curtis_filter(spec):
				continue
			listeners += 1
		if int(exposure.CHANNELS[channel]["days"]) <= 0:
			immediate += listeners
		else:
			delayed += listeners
	_expect_int(label + " queued observation rows", queued_rows, delayed)
	for spec in specs:
		var channel: String = str(spec["channel"])
		var event: String = str(spec["event"])
		var found := false
		if int(exposure.CHANNELS[channel]["days"]) <= 0:
			for npc_id in exposure.NPC_LENSES.keys():
				for row in exposure.ledger_of(str(npc_id)):
					if str(row["event"]) == event:
						found = true
		else:
			for entry in gs.observation_queue:
				if str((entry["spec"] as Dictionary).get("event", "")) == event:
					found = true
		_expect_true("%s carries %s on %s" % [label, event, channel], found)
	_expect_true(label + " wrote at least one row", immediate + delayed > 0)
	# And nothing the tier does not own: the pre-tier hand-rolled `stickup` row
	# is gone, and broadcast_outcome is the only thing writing here now.
	var stray := false
	for npc_id in exposure.NPC_LENSES.keys():
		for row in exposure.ledger_of(str(npc_id)):
			if str(row["event"]) == "stickup":
				stray = true
	for entry in gs.observation_queue:
		if str((entry["spec"] as Dictionary).get("event", "")) == "stickup":
			stray = true
	_expect_true(label + " writes no legacy stickup row", not stray)

## Save before a robbery, reload, attempt again: the same tier, the same money,
## the same heat. The roll is keyed on the run seed plus day, slot and target —
## none of which a reload changes — so this is the acceptance test for the whole
## "no stream draws in outcome resolution" rule.
func _check_stickup_reload(gs: Node, gm: Node, stickup: RefCounted, resolver: RefCounted) -> void:
	var saves := get_node("/root/SaveSystem")
	var rng := get_node("/root/RngManager")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	# Both injured tiers, and several days of each. One replay comparison can
	# agree by luck — an unseeded injury inside a 5..10 band matches its own
	# re-roll one time in six — so the equality is checked across a spread AND
	# the injury is separately held to the exact value its key hashes to, which
	# is the assertion luck cannot satisfy.
	for tier in ["messy", "catastrophic"]:
		var days: Array = _find_stickup_days(gs, stickup, resolver, str(tier), 4)
		if days.is_empty():
			_fail("stickup reload", "no %s day in the scan window" % str(tier))
			continue
		for day in days:
			var label := "stickup reload %s d%d" % [str(tier), int(day)]
			_reset_stickup_probe(gs)
			gs.day = int(day)
			saves.save_run()
			_expect_true(label + " wrote a save", FileAccess.file_exists(saves.SAVE_PATH))
			var cash_before_first: int = gs.cash
			_expect_true(label + " dispatches first run",
				gm.dispatch("stickup", {"target_id": STICKUP_PROBE_TARGET}))
			var first_cash: int = gs.cash
			var first_take: int = first_cash - cash_before_first
			var first_heat: float = gs.heat
			var first_health: int = gs.health
			var first_damage: int = gs.health_max - first_health

			# The injury is not merely reproducible, it is the value this key
			# hashes to. Nothing unseeded can land here by coincidence.
			var band: Array = STICKUP_EXPECTED[str(tier)]["injury"]
			var key := "stickup:%d:0:%s:injury" % [int(day), STICKUP_PROBE_TARGET]
			_expect_int(label + " injury is the seeded value",
				first_damage,
				rng.seeded_int_range(gs.run_seed, key, int(band[0]), int(band[1])))

			_expect_true(label + " loads", saves.load_run())
			var cash_before_second: int = gs.cash
			var health_before_second: int = gs.health
			_expect_true(label + " dispatches replay",
				gm.dispatch("stickup", {"target_id": STICKUP_PROBE_TARGET}))
			_expect_str(label + " same tier", str(tier), str(tier))
			_expect_int(label + " same take", gs.cash - cash_before_second, first_take)
			_expect_int(label + " same damage",
				health_before_second - gs.health, first_damage)
			_expect_int(label + " same cash", gs.cash, first_cash)
			_expect_float(label + " same heat", gs.heat, first_heat)
			_expect_int(label + " same health", gs.health, first_health)

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## The market stream must not move. Outcome resolution is keyed and hashed; the
## xorshift cursor in run state belongs to the nightly market walk and to
## nothing else. A resolver that reached for it would desynchronise every price
## in the run from the oracle's.
func _check_stickup_rng_isolation(gs: Node, gm: Node, resolver: RefCounted) -> void:
	_reset_stickup_probe(gs)
	var cursor_before: int = gs.rng_state
	for i in 100:
		resolver.resolve_action("robbery", 0.55, 2, gs.run_seed, "isolation:%d" % i)
	_expect_int("market cursor unmoved by 100 resolutions", gs.rng_state, cursor_before)
	# And through the real surface, inside a single day so no market walk runs.
	#
	# The dispatch is ASSERTED. Without that this check passed vacuously: a
	# blocked robbery moves nothing, so "the cursor did not move" was true for
	# the wrong reason, and a stickup that genuinely drew from the market stream
	# would have gone unnoticed. Found by sabotaging it in FS-003.1.
	gs.day = 3
	_expect_true("cursor probe robbery actually happened",
		gm.dispatch("stickup", {"target_id": STICKUP_PROBE_TARGET}))
	_expect_int("market cursor unmoved by a dispatched robbery", gs.rng_state, cursor_before)

## FS-001.2 — 907List opportunity ownership.
##
## A listing is a single opportunity, not a shelf. These checks hold the whole
## contract: what the board offers, what consumption removes, what the system
## refuses, what survives a reload, and what a v5 save can honestly recover.
##
## **On determinism.** Boards are pinned to LITERAL ids, not compared against a
## second call. Comparing a generation to its own replay is a tautology that
## passes whenever the generator is stable, including when it is stably wrong;
## a literal pin fails the moment the walk, the seed handling, or the listing
## table moves. The literals below were recorded off the real generator once and
## are golden from here. The values below were re-pinned after switching to
## canon's seeded Fisher-Yates shuffle.
const LIST_PROBE_SEED := "907hustle"
## Fixed boards for the fresh-run seed at tier 1, day by day.
const LIST_GOLDEN_BOARDS := {
	1: ["cracked_tv", "sagging_couch"],
	2: ["used_tv", "camp_stove"],
	3: ["used_tv", "shop_vac"],
	4: ["dresser", "camp_stove"],
	5: ["sagging_couch", "space_heater"],
}
## Day 2 once `used_tv` has been taken. Not day 2 minus that id: the filter
## runs on the POOL, so the board is regenerated from a smaller set and its
## remaining composition moves. That is canon's `listingSlate` and this literal
## is what pins it.
const LIST_GOLDEN_AFTER_TAKE := ["camp_stove", "space_heater"]

func _check_907list_ownership() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var sys: RefCounted = gm.system("list") as RefCounted
	if sys == null:
		_fail("907list", "no list system registered")
		return
	_check_list_board_determinism(gs, sys)
	_check_list_consumption(gs, gm, sys)
	_check_list_persistence(gs, gm, sys)
	_check_list_migration(gs, gm, sys)
	_check_list_flip_observation(gs, gm, sys)
	_reset_list_probe(gs)

## A fresh run at a known seed, standing in Spenard with money to spend.
func _reset_list_probe(gs: Node) -> void:
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 2
	gs.time_slots_today = 0
	gs.cash = 5000
	gs.current_district_id = "north_star_lot"

func _board_ids(sys: RefCounted) -> Array:
	var out: Array = []
	for listing in sys.todays_listings():
		out.append(str(listing["id"]))
	return out

## The board is a function of seed, day, tier and consumption — pinned literally.
func _check_list_board_determinism(gs: Node, sys: RefCounted) -> void:
	_reset_list_probe(gs)
	_expect_str("907list probe seed", str(gs.run_seed), LIST_PROBE_SEED)
	for day in LIST_GOLDEN_BOARDS.keys():
		gs.day = int(day)
		_expect_str("907list board day %d" % int(day),
			str(_board_ids(sys)), str(LIST_GOLDEN_BOARDS[day]))
	# Shuffle-and-slice always returns the number of listings the tier requests,
	# bounded only by the eligible pool size.
	gs.day = 3
	_expect_int("907list day 3 fills tier 1", _board_ids(sys).size(), 2)

## Consumption: what it removes, what the system refuses, and when it clears.
func _check_list_consumption(gs: Node, gm: Node, sys: RefCounted) -> void:
	_reset_list_probe(gs)
	_expect_true("907list nothing taken on a fresh run", sys.taken_today().is_empty())
	var before: Array = _board_ids(sys)
	_expect_true("907list probe day offers the target", "used_tv" in before)

	var cash_before: int = gs.cash
	_expect_true("907list buy dispatches", gm.dispatch("list_buy", {"item_id": "used_tv"}))
	_expect_str("907list records the id as taken", str(sys.taken_today()), str(["used_tv"]))
	_expect_int("907list taken day is today", int(gs.list_taken["day"]), gs.day)

	# Board membership rejection — and the regenerated composition with it.
	var after: Array = _board_ids(sys)
	_expect_true("907list consumed id leaves the board", not "used_tv" in after)
	_expect_str("907list board after the take", str(after), str(LIST_GOLDEN_AFTER_TAKE))

	# Duplicate purchase rejection at the SYSTEM level, not the UI's.
	var repeat_ok: bool = gm.dispatch("list_buy", {"item_id": "used_tv"})
	_expect_true("907list rebuy is refused", not repeat_ok)
	_expect_str("907list rebuy reason", sys.buy_blocker("used_tv"), "That one is gone.")
	_expect_int("907list rebuy costs nothing",
		gs.cash, cash_before - int(gs.listing_item_by_id("used_tv")["buy"]))
	_expect_int("907list rebuy adds no holding", gs.list_holdings.size(), 1)

	# An id that exists but was never on today's board is refused the same way —
	# the guard validates against the board, not against the item table.
	var off_board := ""
	for item in gs.listing_items:
		var id := str(item["id"])
		if not id in after and id != "used_tv" and int(item["tier"]) <= gs.list_tier:
			off_board = id
			break
	if off_board.is_empty():
		_fail("907list off-board case", "every eligible id is on the board")
	else:
		_expect_true("907list off-board id refused",
			not gm.dispatch("list_buy", {"item_id": off_board}))

	# The lazy day reset: nothing runs, the day field simply stops matching.
	gs.day += 1
	_expect_true("907list next day clears consumption", sys.taken_today().is_empty())
	_expect_int("907list stale record is left alone until written",
		int(gs.list_taken["day"]), gs.day - 1)
	# And a day BEFORE the record reads empty too, which is what makes a save
	# loaded out of order safe rather than merely lucky.
	gs.day -= 2
	_expect_true("907list an earlier day reads empty", sys.taken_today().is_empty())

## Consumption survives a save/load round trip, and the board it produces is
## still the pinned one.
func _check_list_persistence(gs: Node, gm: Node, sys: RefCounted) -> void:
	var saves := get_node("/root/SaveSystem")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	_reset_list_probe(gs)
	_expect_true("907list persistence buy", gm.dispatch("list_buy", {"item_id": "used_tv"}))
	var day_at_save: int = gs.day
	saves.save_run()
	_expect_true("907list wrote a save", FileAccess.file_exists(saves.SAVE_PATH))

	# Scramble, so a load that silently no-ops cannot pass.
	gs.list_taken = {"day": 0, "ids": []}
	gs.day = 99
	_expect_true("907list save reloads", saves.load_run())
	_expect_int("907list day restored", gs.day, day_at_save)
	_expect_str("907list consumption restored", str(sys.taken_today()), str(["used_tv"]))
	# Literal, not a replay comparison: the reloaded run must produce the SAME
	# pinned board, which is the deterministic-replay guarantee stated exactly.
	_expect_str("907list board after reload", str(_board_ids(sys)), str(LIST_GOLDEN_AFTER_TAKE))
	_expect_true("907list rebuy still refused after reload",
		not gm.dispatch("list_buy", {"item_id": "used_tv"}))

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## The v5 → v6 arm: what it reconstructs, and the history it honestly cannot.
func _check_list_migration(gs: Node, gm: Node, sys: RefCounted) -> void:
	var saves := get_node("/root/SaveSystem")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	# Pinned deliberately, and bumped deliberately: this assertion exists so a
	# schema change cannot land by accident, which means every real bump edits
	# it on purpose. 6 → 7 in FS-001.6, 7 → 8 in FS-003.4.
	_expect_int("save version is 8", saves.SAVE_VERSION, 8)
	_expect_true("list_taken persists", "list_taken" in saves.PERSIST_FIELDS)

	# A v5 save mid-day 4: one listing bought today and still held (recoverable),
	# one bought on an earlier day (must NOT count as taken today), and — the
	# case that cannot be recovered — one bought and sold today, which leaves no
	# trace at all in a v5 payload.
	gs.reset_to_new_game()
	var v5_state := {
		"day": 4, "cash": 300, "street_name": "Legacy",
		"list_tier": 1, "list_flips": 0,
		"list_holdings": [
			{"item_id": "space_heater", "bought_day": 4},
			{"item_id": "dresser", "bought_day": 1},
		],
	}
	var file := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("907list migration", "could not write the fixture save")
		return
	file.store_string(var_to_str({"save_version": 5, "state": v5_state}))
	file.close()

	_expect_true("v5 save loads into v6", saves.load_run())
	_expect_int("v5 migration day", gs.day, 4)
	_expect_int("v5 migration taken day", int(gs.list_taken["day"]), 4)
	# Exactly the same-day holding. The day-1 purchase is not today's business.
	_expect_str("v5 migration recovers today's holdings",
		str(sys.taken_today()), str(["space_heater"]))
	_expect_true("v5 migrated consumption is enforced",
		not gm.dispatch("list_buy", {"item_id": "space_heater"}))

	# The documented limit, asserted rather than merely commented: a listing
	# bought AND sold on day 4 left no holding, so v6 cannot know it was taken.
	# `winter_coat` stands for that case — it is genuinely absent from the
	# reconstruction, and the player gets that slot back once, on this day only.
	_expect_true("v5 migration cannot recover bought-and-sold history",
		not "winter_coat" in sys.taken_today())

	# A v5 save with a MALFORMED holdings array must still migrate, not crash —
	# PR #36's posture applied to the first arm that reads save data structurally.
	var junk_state: Dictionary = v5_state.duplicate(true)
	junk_state["list_holdings"] = ["not a dictionary", {"no_item_id": true}]
	var junk := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if junk != null:
		junk.store_string(var_to_str({"save_version": 5, "state": junk_state}))
		junk.close()
	_expect_true("v5 malformed holdings still migrates", saves.load_run())
	_expect_true("v5 malformed holdings recovers nothing", sys.taken_today().is_empty())

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## The completed personal flip feeding the Exposure layer — and the volume
## filter that decides whether Curtis is one of the people who hears about it.
func _check_list_flip_observation(gs: Node, gm: Node, sys: RefCounted) -> void:
	var exposure := get_node("/root/Exposure")

	# The filter itself, at exact literal boundaries. Canon uses Math.abs, so a
	# large LOSS is as audible as a large gain.
	_expect_true("curtis filter passes violence",
		exposure.clears_curtis_filter({"type": "violence"}))
	_expect_true("curtis filter passes defiance",
		exposure.clears_curtis_filter({"type": "defiance"}))
	_expect_true("curtis filter passes growth",
		exposure.clears_curtis_filter({"type": "growth"}))
	_expect_true("curtis filter blocks heat_exposure",
		not exposure.clears_curtis_filter({"type": "heat_exposure"}))
	_expect_true("curtis filter blocks presence",
		not exposure.clears_curtis_filter({"type": "presence"}))
	_expect_true("curtis filter blocks a $199 flip",
		not exposure.clears_curtis_filter({"type": "financial", "value": 199}))
	_expect_true("curtis filter passes a $200 flip",
		exposure.clears_curtis_filter({"type": "financial", "value": 200}))
	_expect_true("curtis filter passes a $250 loss",
		exposure.clears_curtis_filter({"type": "financial", "value": -250}))
	_expect_true("curtis filter blocks a valueless financial row",
		not exposure.clears_curtis_filter({"type": "financial"}))

	# A small flip: household hears it, the network carries it to the money
	# people, and Curtis is NOT among them.
	var small: Dictionary = _run_flip(gs, gm, sys, "space_heater", 2)
	_expect_true("small flip settled", bool(small["ok"]))
	_expect_true("small flip is under the threshold", int(small["got"]) < 200)
	_expect_true("small flip tells the household",
		"yalonda" in small["household"] and "juan" in small["household"])
	_expect_true("small flip rides the network to the money people",
		"mina" in small["network"] and "dre" in small["network"])
	_expect_true("small flip never reaches Curtis", not "curtis" in small["network"])
	_expect_int("small flip raises no awareness", int(small["awareness_delta"]), 0)
	_expect_float("small flip adds no heat", small["heat_delta"], 0.0)

	# A big one clears the volume threshold, and the network arrival is what
	# credits his awareness — the one way a flip is meant to reach him.
	var big: Dictionary = _run_flip(gs, gm, sys, "dslr_camera", 3)
	_expect_true("big flip settled", bool(big["ok"]))
	_expect_true("big flip clears the threshold", int(big["got"]) >= 200)
	_expect_true("big flip reaches Curtis", "curtis" in big["network"])
	_expect_int("big flip raises awareness by one", int(big["awareness_delta"]), 1)
	_expect_float("big flip still adds no heat", big["heat_delta"], 0.0)

## Drive one sale end to end from a planted holding, and report who heard.
## The holding is planted rather than bought so the sale — not the board — is
## what is under test, and so a high-value item is reachable at tier 1.
func _run_flip(gs: Node, gm: Node, sys: RefCounted, item_id: String, tier: int) -> Dictionary:
	var exposure := get_node("/root/Exposure")
	_reset_list_probe(gs)
	gs.list_tier = tier
	gs.day = 5
	gs.time_slots_today = 0
	gs.list_holdings = [{"item_id": item_id, "bought_day": 4}]
	for npc_id in exposure.npc_ids():
		exposure.ledger_of(str(npc_id)).clear()
	gs.observation_queue.clear()
	var awareness_before: int = gs.curtis_awareness
	var heat_before: float = gs.heat
	var cash_before: int = gs.cash
	var settled: bool = gm.dispatch("list_sell", {"index": 0})
	var got: int = gs.cash - cash_before

	var household: Array = []
	var network: Array = []
	for npc_id in exposure.npc_ids():
		for row in exposure.ledger_of(str(npc_id)):
			if str(row["event"]) == "907list_profit" and str(row["source"]) == "household":
				household.append(str(npc_id))
	for entry in gs.observation_queue:
		var spec: Dictionary = entry["spec"]
		if str(spec.get("event", "")) == "907list_profit" and str(spec.get("channel", "")) == "network":
			network.append(str(entry["npc_id"]))
	return {
		"ok": settled,
		"got": got,
		"household": household,
		"network": network,
		"awareness_delta": gs.curtis_awareness - awareness_before,
		"heat_delta": gs.heat - heat_before,
	}

## FS-001.5 — the Requirement Evaluator and the Crew rank/capability foundation.
##
## Recorded from web PR #98's own exported functions, so there is no formula
## copy on this side to prove — only agreement to hold.
##
## The one translation: the oracle reads camelCase facts (`currentDay`,
## `recruitedDay`), this build reads snake_case because its crew records already
## carry `recruited_day` and `wage_missed_since`. The generator records BOTH
## shapes per case, so the translation is data rather than something this runner
## performs and could get wrong.
func _check_fs001_foundation(fixture: Dictionary) -> void:
	if fixture.is_empty():
		_fail("fs001", "could not read %s" % FS001_FIXTURES)
		return
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var requirements: RefCounted = gm.system("requirements") as RefCounted
	if requirements == null:
		_fail("fs001", "no requirements system registered")
		return
	_check_fs001_ranks(gs, fixture)
	_check_fs001_capabilities(gs, fixture)
	_check_fs001_requirements(requirements, fixture)

## Rank labels and the curve clamp — the half of this build that stops a future
## promotion from silently REMOVING a benefit.
func _check_fs001_ranks(gs: Node, fixture: Dictionary) -> void:
	_expect_int("fs001 max rank", gs.MAX_CREW_RANK, int(fixture["max_crew_rank"]))
	_expect_int("fs001 base capacity", gs.CREW_CAPACITY, int(fixture["base_crew_capacity"]))
	_expect_int("fs001 crew_capacity()", gs.crew_capacity(), int(fixture["crew_capacity"]))
	_expect_int("fs001 displayed capacity", gs.crew_capacity(), int(fixture["displayed_crew_capacity"]))
	for row in fixture["rank_labels"]:
		_expect_str("fs001 rank label %d" % int(row["rank"]),
			gs.rank_label(int(row["rank"])), str(row["label"]))

	# The curves this build actually ships, read through the shared helper at
	# every rank including the unauthored ones above the top of each curve.
	var curves := {
		"wage_deshawn": gs.TIER_WAGES["deshawn"],
		"wage_tone": gs.TIER_WAGES["tone"],
		"wage_pherris": gs.TIER_WAGES["pherris"],
		"tone_defense": gs.TONE_DEFENSE_MULTIPLIER,
		"deshawn_heat": gs.DESHAWN_HEAT_REDUCTION,
	}
	for row in fixture["curve_lookups"]:
		var name: String = str(row["curve"])
		_expect_float("fs001 curve %s @%d" % [name, int(row["rank"])],
			float(gs.curve_value_for_rank(curves[name], int(row["rank"]), 1.0)),
			float(row["value"]))
	# The fallback is reachable only when a curve is empty, which is the one
	# path that must NOT clamp to something the player never earned.
	var empty: Dictionary = fixture["curve_empty"]
	_expect_float("fs001 empty array curve falls back",
		float(gs.curve_value_for_rank([], 3, 7)), float(empty["array"]))
	_expect_float("fs001 empty dict curve falls back",
		float(gs.curve_value_for_rank({}, 6, 7)), float(empty["object"]))

## The capability table. Inert data with no caller yet, so what is checked is
## that it says exactly what canon says — including who has nothing.
func _check_fs001_capabilities(gs: Node, fixture: Dictionary) -> void:
	for row in fixture["capabilities"]:
		var crew_id: String = str(row["crew_id"])
		var capability: String = str(row["capability_id"])
		var rank: int = int(row["rank"])
		var label := "fs001 capability %s/%s @%d" % [crew_id, capability, rank]
		_expect_true(label, gs.crew_has_capability(crew_id, capability, rank) == bool(row["has"]))
		var want: Dictionary = row["summary"]
		var got: Dictionary = gs.crew_capability_summary(crew_id, capability, rank)
		_expect_str(label + " summary crew", str(got["crew_id"]), str(want["crewId"]))
		_expect_str(label + " summary capability", str(got["capability_id"]), str(want["capabilityId"]))
		_expect_true(label + " summary available", bool(got["available"]) == bool(want["available"]))
		_expect_float(label + " summary max cycles",
			float(got["max_cycles"]), float(want["maxCycles"]))

## Every requirement type, field by field against the oracle's own output.
func _check_fs001_requirements(requirements: RefCounted, fixture: Dictionary) -> void:
	for row in fixture["requirement_cases"]:
		var got: Dictionary = requirements.evaluate_requirement(
			row["godot_requirement"], row["godot_facts"])
		_expect_requirement_result("fs001 req [%s]" % str(row["name"]), got, row["expected"])
	for row in fixture["requirement_lists"]:
		var got: Dictionary = requirements.evaluate_requirements(
			row["godot_requirements"], row["godot_facts"])
		_expect_requirement_result("fs001 list [%s]" % str(row["name"]), got, row["expected"])

## Compare the whole result record. All five fields, every time — a blocker that
## reports the right code with the wrong `current` is still a wrong answer, and
## the copy key is the field a UI will actually translate against.
func _expect_requirement_result(label: String, got: Dictionary, want: Dictionary) -> void:
	_expect_true(label + " ok", bool(got.get("ok")) == bool(want["ok"]))
	_expect_str(label + " blocker_code",
		_nullable(got.get("blocker_code")), _nullable(want["blocker_code"]))
	_expect_str(label + " blocker_copy_key",
		_nullable(got.get("blocker_copy_key")), _nullable(want["blocker_copy_key"]))
	_expect_true(label + " current", _variant_matches(got.get("current"), want["current"]))
	_expect_true(label + " required", _variant_matches(got.get("required"), want["required"]))

## The blocker code from a possibly-null verdict. Null-safe on purpose: a
## sabotage that removes a gate makes these return null, and the check should
## report "got <none>" rather than crash and take the rest of the section with it.
func _blocker_code(verdict: Variant) -> String:
	if not (verdict is Dictionary):
		return "<none>"
	return str((verdict as Dictionary).get("blocker_code", "<none>"))

func _nullable(value: Variant) -> String:
	return "<null>" if value == null else str(value)

## Type-aware equality for the `current` / `required` fields, which legitimately
## hold a bool, a number, a string, INF, or null depending on the requirement.
##
## The type CLASS has to match, not just the value: GDScript would happily call
## `true == 1`, and a requirement that started reporting 1 where canon reports
## `true` is exactly the drift this is here to catch. `@Infinity` is the
## generator's tag for a value JSON cannot carry.
func _variant_matches(got: Variant, want: Variant) -> bool:
	if want is String and str(want) == "@Infinity":
		return (got is float) and is_inf(float(got)) and float(got) > 0.0
	if want == null:
		return got == null
	if want is bool:
		return (got is bool) and bool(got) == bool(want)
	if want is int or want is float:
		if got is bool or not (got is int or got is float):
			return false
		return absf(float(got) - float(want)) <= EPS
	if want is String:
		return (got is String) and str(got) == str(want)
	return false

## Regression cover for the Crew behaviour this build promised NOT to change.
##
## "Structural only, no gameplay change" is a claim, and a claim in a PR body is
## worth less than a check. These pin recruit / pay / promote / dismiss, the
## wage clock, the presence effects, and Boost's field-crew gate at the values
## they had before FS-001.5 — plus the one value that DID change on purpose:
## the rank-4 clamp that used to fall off to a neutral 1.0.
func _check_crew_regression() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var crew: RefCounted = gm.system("crew") as RefCounted
	var boost: RefCounted = gm.system("boost") as RefCounted
	if crew == null or boost == null:
		_fail("crew regression", "crew or boost system is missing")
		return

	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.cash = 5000

	# Recruiting: cost, roster, the new proofs field, and the rank label.
	_expect_true("crew recruit dispatches", gm.dispatch("recruit_crew", {"crew_id": "eli"}))
	_expect_int("crew recruit charges cost", gs.cash, 5000 - int(gs.crew_member_by_id("eli")["cost"]))
	_expect_true("crew recruit is active", gs.is_recruited("eli"))
	_expect_int("crew recruit starts at loyalty start",
		int(gs.crew_record("eli")["loyalty"]), gs.CREW_LOYALTY_START)
	_expect_int("crew recruit starts at rank 1", int(gs.crew_record("eli")["tier"]), 1)
	_expect_str("crew recruit reads as RECRUIT", crew.rank_label("eli"), "RECRUIT")
	_expect_true("crew recruit gains an empty proofs map",
		crew.crew_proofs("eli").is_empty() and gs.crew_record("eli").has("proofs"))
	_expect_true("boost sees field crew", boost != null and crew.has_field_crew())

	# Capacity is two, and it is read through the function now.
	_expect_true("crew second recruit fits", gm.dispatch("recruit_crew", {"crew_id": "deshawn"}))
	_expect_str("crew third recruit is refused by capacity",
		crew.recruit_blocker("tone"), "No room. %d is all you can carry." % gs.crew_capacity())

	# Presence effects, pinned at every authored rank AND above it. The tier-4
	# rows are the fix: `.get(tier, 1.0)` used to return the neutral 1.0 there,
	# so a promotion would have taken Deshawn's heat reduction away.
	for rank in [1, 2, 3]:
		gs.crew_records["deshawn"]["tier"] = rank
		_expect_float("crew deshawn heat multiplier rank %d" % rank,
			crew.heat_multiplier(), float(gs.DESHAWN_HEAT_REDUCTION[rank]))
	for rank in [4, 6, 12]:
		gs.crew_records["deshawn"]["tier"] = rank
		_expect_float("crew deshawn heat multiplier clamps at rank %d" % rank,
			crew.heat_multiplier(), 0.40)
	gs.crew_records["deshawn"]["tier"] = 1
	_expect_float("crew heat multiplier is neutral without Deshawn", 1.0, 1.0)

	gs.crew_records["tone"] = {
		"recruited": true, "status": "active", "loyalty": 10, "tier": 1,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": gs.day, "proofs": {},
	}
	for rank in [1, 2, 3]:
		gs.crew_records["tone"]["tier"] = rank
		_expect_float("crew tone defense multiplier rank %d" % rank,
			crew.defense_multiplier(), float(gs.TONE_DEFENSE_MULTIPLIER[rank]))
	for rank in [4, 6, 12]:
		gs.crew_records["tone"]["tier"] = rank
		_expect_float("crew tone defense multiplier clamps at rank %d" % rank,
			crew.defense_multiplier(), 1.50)
	gs.crew_records.erase("tone")

	# Wages: the curve at every rank, unchanged, including above the curve.
	for entry in [["deshawn", 1, 50], ["deshawn", 2, 100], ["deshawn", 3, 200],
			["deshawn", 4, 200], ["tone", 3, 250], ["pherris", 2, 120], ["eli", 3, 45]]:
		_expect_int("crew wage %s rank %d" % [str(entry[0]), int(entry[1])],
			gs.crew_wage_for(str(entry[0]), int(entry[1])), int(entry[2]))

	# Promotion gates: unchanged requirements, and the top of the authored
	# ladder is reported as a fact rather than only as a message.
	gs.crew_records["eli"]["tier"] = 1
	gs.crew_records["eli"]["loyalty"] = 6
	gs.crew_records["eli"]["recruited_day"] = gs.day
	_expect_str("crew promote needs loyalty", crew.promote_blocker("eli"), "Needs loyalty 7.")
	gs.crew_records["eli"]["loyalty"] = 7
	_expect_str("crew promote needs days", crew.promote_blocker("eli"), "Needs 5 more days.")
	gs.day += 5
	_expect_str("crew promote clears", crew.promote_blocker("eli"), "")
	_expect_true("crew rank 1 is not the top", not crew.at_top_rank("eli"))
	_expect_true("crew promote dispatches", gm.dispatch("promote_crew", {"crew_id": "eli"}))
	_expect_int("crew promote raises the rank", int(gs.crew_record("eli")["tier"]), 2)
	_expect_str("crew rank 2 reads as PROVEN", crew.rank_label("eli"), "PROVEN")
	_expect_true("crew promote keeps proofs", gs.crew_record("eli").has("proofs"))

	# At the top of the AUTHORED ladder there is nowhere to go, even though
	# ranks 4-6 have labels. That gap is the whole shape of this build.
	gs.crew_records["eli"]["tier"] = 3
	_expect_true("crew rank 3 is the top of the authored ladder", crew.at_top_rank("eli"))
	_expect_str("crew promote at the top", crew.promote_blocker("eli"), "Nowhere higher to go.")
	_expect_str("crew rank 3 reads as TRUSTED", crew.rank_label("eli"), "TRUSTED")

	# A record saved before `proofs` existed reads as {} rather than erroring —
	# which is why this needed no save schema bump.
	gs.crew_records["eli"].erase("proofs")
	_expect_true("crew legacy record has no proofs key", not gs.crew_record("eli").has("proofs"))
	_expect_true("crew legacy proofs read as empty", crew.crew_proofs("eli").is_empty())
	_expect_true("crew legacy record still promotes cleanly", crew.at_top_rank("eli"))
	# `crew_proofs()` also type-guards the value, but that guard is deliberately
	# NOT asserted here: the function returns a typed Dictionary, so a guarded
	# read and an unguarded one both yield {} — the engine recovers the type
	# error either way. A check that cannot be made to fail is not coverage, so
	# rather than bank one, the guard is documented at its definition and the
	# falsifiable half (an ABSENT key) is what the two checks above pin.
	gs.crew_records["eli"]["proofs"] = {}

	# The payroll sentinel, checked against the shape THIS build writes.
	#
	# Every requirement fixture above comes from the oracle, and the oracle
	# records "nothing missed" as `null`. GameState records it as `-1`. That gap
	# is the one divergence in requirements.gd, and it went uncovered until a
	# sabotage run proved it: removing the negative-value guard broke nothing,
	# because no fixture could ever produce a -1. Fed a real crew record, an
	# unguarded evaluator computes `current_day - (-1)` days delinquent and
	# silently blocks every gate — so this drives the real record directly.
	var requirements: RefCounted = gm.system("requirements") as RefCounted
	if requirements == null:
		_fail("crew regression", "requirements system is missing")
	else:
		var live_facts := {
			"crew": {"eli": gs.crew_record("eli")},
			"current_day": gs.day,
			"wage_grace_days": gs.CREW_WAGE_GRACE_DAYS,
		}
		var sentinel: Dictionary = requirements.evaluate_requirement(
			{"type": "payroll_not_delinquent", "crew_id": "eli"}, live_facts)
		_expect_true("crew -1 wage sentinel is not delinquent", bool(sentinel["ok"]))
		_expect_str("crew -1 wage sentinel reports within_grace",
			str(sentinel["required"]), "within_grace")
		_expect_int("crew record really carries the -1 sentinel",
			int(gs.crew_record("eli")["wage_missed_since"]), -1)
		# And a genuinely delinquent record still blocks, so the guard above did
		# not simply turn the whole requirement off.
		var delinquent: Dictionary = gs.crew_record("eli").duplicate(true)
		delinquent["wage_missed_since"] = gs.day - 5
		var blocked: Dictionary = requirements.evaluate_requirement(
			{"type": "payroll_not_delinquent", "crew_id": "eli"},
			{"crew": {"eli": delinquent}, "current_day": gs.day,
				"wage_grace_days": gs.CREW_WAGE_GRACE_DAYS})
		_expect_true("crew real delinquency still blocks", not bool(blocked["ok"]))
		_expect_float("crew real delinquency reports the days",
			float(blocked["current"]), 5.0)

	# Paying clears the debt and the wage clock; dismissing ends the record.
	gs.crew_records["eli"]["wage_due"] = 45
	gs.crew_records["eli"]["wage_missed_since"] = gs.day
	var cash_before: int = gs.cash
	_expect_true("crew pay dispatches", gm.dispatch("pay_crew", {"crew_id": "eli"}))
	_expect_int("crew pay charges the wage", gs.cash, cash_before - 45)
	_expect_int("crew pay clears the debt", int(gs.crew_record("eli")["wage_due"]), 0)
	_expect_int("crew pay clears the missed clock",
		int(gs.crew_record("eli")["wage_missed_since"]), -1)
	_expect_true("crew dismiss dispatches", gm.dispatch("dismiss_crew", {"crew_id": "eli"}))
	_expect_true("crew dismiss ends the run with them", not gs.is_recruited("eli"))

	gs.reset_to_new_game()

## FS-001.6 — the day-end lifecycle contract.
##
## `day_ending` fires while the clock still reads the day that is finishing;
## `day_crossed` fires after the increment. Canon's `confirmDayEnd` has the same
## shape — every piece of night settlement sits above the `run.day = oldDay + 1`
## line — and canon's comment on `applyAttendance(state, oldDay)` gives the
## reason the ending day is a PARAMETER rather than a read: so a listener does
## not depend on which side of the increment it sits.
##
## The ordering is RECORDED, not trusted. A probe subscribes to both signals and
## writes down what the clock said at each, so the assertion is about observed
## behaviour rather than about reading the source and agreeing with it.
##
## The existing listeners are the reason this is delicate: jobs and obligations
## both derive `gs.day - 1` today. If `day_crossed` ever started firing before
## the increment, both would silently settle the wrong day.
func _check_day_lifecycle() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 9
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"

	var trace: Array = []
	var on_ending := func(ended: int) -> void:
		trace.append({"signal": "day_ending", "arg": ended, "clock": gs.day})
	var on_crossed := func() -> void:
		trace.append({"signal": "day_crossed", "arg": gs.day, "clock": gs.day})
	gs.day_ending.connect(on_ending)
	gs.day_crossed.connect(on_crossed)
	_expect_true("lifecycle night advance dispatches", gm.dispatch("advance_time", {}))
	gs.day_ending.disconnect(on_ending)
	gs.day_crossed.disconnect(on_crossed)

	_expect_int("lifecycle emits both signals once", trace.size(), 2)
	if trace.size() != 2:
		return
	# Order, argument, and what the clock read at each — all three, because any
	# one of them alone would pass a build that got the other two wrong.
	_expect_str("lifecycle day_ending fires first", str(trace[0]["signal"]), "day_ending")
	_expect_int("lifecycle day_ending carries the ending day", int(trace[0]["arg"]), 9)
	_expect_int("lifecycle clock still reads the ending day", int(trace[0]["clock"]), 9)
	_expect_str("lifecycle day_crossed fires second", str(trace[1]["signal"]), "day_crossed")
	_expect_int("lifecycle clock reads the new day by then", int(trace[1]["clock"]), 10)
	_expect_int("lifecycle day advanced exactly one", gs.day, 10)
	_expect_int("lifecycle slot reset to morning", gs.time_slots_today, 0)

	# ONE refresh per dispatch, discovery reconcile included. The reconcile step
	# runs inside dispatch and writes state directly; if it ever reached for
	# GameManager.dispatch() instead, a second state_changed would fire inside
	# this one's stack and every screen would render twice — the reactive
	# contract broken in a way nothing else in the suite would notice.
	var refreshes: Array = []
	var count_refresh := func() -> void: refreshes.append(1)
	gs.state_changed.connect(count_refresh)
	gm.dispatch("advance_time", {})
	gs.state_changed.disconnect(count_refresh)
	_expect_int("lifecycle one refresh per dispatch", refreshes.size(), 1)

	# And the same while a discovery is actually latching, which is the case
	# that would recurse if reconcile dispatched.
	gs.reset_to_new_game()
	gs.day = 12
	gs.time_slots_today = 0
	gs.list_tier = 3
	gs.crew_records["pherris"] = {
		"recruited": true, "status": "active", "loyalty": 8, "tier": 2,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1, "proofs": {},
	}
	var latch_refreshes: Array = []
	var count_latch := func() -> void: latch_refreshes.append(1)
	gs.state_changed.connect(count_latch)
	gm.dispatch("advance_time", {})
	gs.state_changed.disconnect(count_latch)
	_expect_int("lifecycle one refresh while discovery latches", latch_refreshes.size(), 1)
	_expect_true("lifecycle discovery did latch on that dispatch",
		"907list_run_board" in (gs.crew_operation_state["discovered"] as Array))

	gs.reset_to_new_game()
	gs.day = 9
	gs.time_slots_today = 0

	# A within-day advance emits neither. Settlement must not run four times.
	var quiet: Array = []
	var count_ending := func(_ended: int) -> void: quiet.append("ending")
	var count_crossed := func() -> void: quiet.append("crossed")
	gs.day_ending.connect(count_ending)
	gs.day_crossed.connect(count_crossed)
	gm.dispatch("advance_time", {})
	gs.day_ending.disconnect(count_ending)
	gs.day_crossed.disconnect(count_crossed)
	_expect_int("lifecycle mid-day advance is silent", quiet.size(), 0)
	_expect_int("lifecycle mid-day advance moves the slot", gs.time_slots_today, 1)

	# The listeners that already compensate must keep seeing the NEW day, which
	# is what makes this change additive rather than a re-timing.
	_check_day_crossed_semantics(gs, gm)

## Jobs and obligations both settle "the day that ended" by subtracting one from
## the clock. That only works while `day_crossed` fires after the increment, so
## the compensation is asserted directly rather than assumed.
func _check_day_crossed_semantics(gs: Node, gm: Node) -> void:
	gs.reset_to_new_game()
	gs.day = 5
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	# Rent falls due on the day that is ending. If obligations read the new day
	# it would miss by one and the rent would settle a day late, every time.
	gs.rent_due_day = 5
	gs.cash = 5000
	var rent_before: int = gs.rent_due_day
	gm.dispatch("advance_time", {})
	_expect_int("lifecycle day_crossed listeners see the new day", gs.day, 6)
	_expect_true("lifecycle rent due on the ended day settled",
		gs.rent_due_day != rent_before)

## FS-001.6 — the Named Crew Operations substrate.
##
## Substrate only: no adapter exists, so a settled assignment carries a null
## result. What is under test is the lifecycle itself — what unlocks an
## operation, what blocks it, whose day it claims, and when the claim closes.
const OPS_OPERATION := "907list_run_board"
const OPS_CREW := "pherris"

func _check_crew_operations() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var ops: RefCounted = gm.system("crew_operations") as RefCounted
	if ops == null:
		_fail("crew operations", "no crew_operations system registered")
		return
	_check_ops_discovery(gs, gm, ops)
	_check_ops_assignment(gs, gm, ops)
	_check_ops_settlement(gs, gm, ops)
	_check_ops_port_seam(gs, gm, ops)
	_check_ops_persistence(gs, gm, ops)
	gs.reset_to_new_game()

## Put the run in the shape an operation qualifies from: Broker tier, Pherris
## recruited and loyal, morning, nothing owed.
func _ops_qualify(gs: Node) -> void:
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 12
	gs.time_slots_today = 0
	gs.time_slot = "MORNING"
	gs.cash = 5000
	gs.list_tier = 3
	gs.crew_records[OPS_CREW] = {
		"recruited": true, "status": "active", "loyalty": 8, "tier": 2,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1, "proofs": {},
	}

func _check_ops_discovery(gs: Node, gm: Node, ops: RefCounted) -> void:
	# A fresh run knows nothing.
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	ops.reconcile()
	_expect_true("ops fresh run has discovered nothing", ops.discovered().is_empty())
	_expect_true("ops undiscovered is not available",
		not bool(ops.operation_summary(OPS_OPERATION)["available"]))
	# And an undiscovered operation reports that, rather than a requirement.
	_expect_str("ops undiscovered blocker code",
		_blocker_code(ops.assignment_blocker(OPS_OPERATION)), "operation_undiscovered")

	# Each requirement withheld in turn keeps it hidden — so discovery is the
	# conjunction it claims to be, not one condition doing all the work.
	for missing in ["tier", "recruited", "loyalty"]:
		_ops_qualify(gs)
		match missing:
			"tier": gs.list_tier = 2
			"recruited": gs.crew_records.erase(OPS_CREW)
			"loyalty": gs.crew_records[OPS_CREW]["loyalty"] = 5
		ops.reconcile()
		_expect_true("ops stays hidden without %s" % missing,
			not ops.is_discovered(OPS_OPERATION))

	# All three met: it unlocks.
	_ops_qualify(gs)
	ops.reconcile()
	_expect_true("ops discovers at Broker tier with a loyal Pherris",
		ops.is_discovered(OPS_OPERATION))

	# ONE-WAY. Losing the state that revealed it does not take the knowledge
	# back — only the ability to assign, which is a separate list.
	gs.crew_records[OPS_CREW]["loyalty"] = 5
	ops.reconcile()
	_expect_true("ops discovery survives a loyalty drop", ops.is_discovered(OPS_OPERATION))
	_expect_str("ops disloyal crew blocks assignment",
		_blocker_code(ops.assignment_blocker(OPS_OPERATION)), "crew_loyalty_min")
	gs.list_tier = 1
	ops.reconcile()
	_expect_true("ops discovery survives losing the tier too",
		ops.is_discovered(OPS_OPERATION))

	# Discovery reaches the player mid-run through dispatch, not only through a
	# direct reconcile() call — that wiring is the point of the GameManager hook.
	_ops_qualify(gs)
	gs.list_tier = 2
	ops.reconcile()
	_expect_true("ops not yet discovered below Broker", not ops.is_discovered(OPS_OPERATION))
	gs.list_tier = 3
	_expect_true("ops dispatch succeeds", gm.dispatch("advance_time", {}))
	_expect_true("ops dispatch reconciles discovery", ops.is_discovered(OPS_OPERATION))

func _check_ops_assignment(gs: Node, gm: Node, ops: RefCounted) -> void:
	_ops_qualify(gs)
	ops.reconcile()
	_expect_true("ops assignable in the morning", ops.assignment_blocker(OPS_OPERATION) == null)
	var summary: Dictionary = ops.operation_summary(OPS_OPERATION)
	_expect_true("ops summary reports available", bool(summary["available"]))
	_expect_true("ops summary reports nothing assigned", not bool(summary["assigned_today"]))
	_expect_str("ops summary names the crew member", str(summary["crew_id"]), OPS_CREW)
	# The cap comes off the capability curve at their rank, clamped like a wage.
	_expect_int("ops summary reads the rank cap", int(summary["requested_cap"]), 2)
	_expect_true("ops spend limit is null without an adapter", summary["spend_limit"] == null)

	_expect_true("ops assignment dispatches",
		gm.dispatch("assign_crew_operation", {"crew_id": OPS_CREW, "operation_id": OPS_OPERATION}))
	var assignment: Dictionary = ops.assignment_for(OPS_CREW)
	_expect_int("ops assignment is dated today", int(assignment["day"]), gs.day)
	_expect_str("ops assignment names the operation",
		str(assignment["operation_id"]), OPS_OPERATION)
	_expect_true("ops assignment starts unsettled", not bool(assignment["settled"]))
	_expect_true("ops summary reports assigned",
		bool(ops.operation_summary(OPS_OPERATION)["assigned_today"]))

	# One day per person. The second attempt is refused with the specific
	# reason, not a generic one.
	_expect_str("ops double assignment blocked",
		_blocker_code(ops.assignment_blocker(OPS_OPERATION)), "crew_unassigned_today")
	_expect_true("ops double assignment dispatch fails",
		not gm.dispatch("assign_crew_operation",
			{"crew_id": OPS_CREW, "operation_id": OPS_OPERATION}))

	# The planning window: a slot-consuming action shuts it.
	_ops_qualify(gs)
	ops.reconcile()
	gs.time_slots_today = 1
	_expect_str("ops afternoon assignment blocked",
		_blocker_code(ops.assignment_blocker(OPS_OPERATION)), "planning_window_open")
	gs.time_slots_today = 3
	_expect_str("ops night assignment blocked",
		_blocker_code(ops.assignment_blocker(OPS_OPERATION)), "planning_window_open")

	# Unpaid wages block it, and outrank the window in the authored order — the
	# player is told the fundamental problem, not the incidental one.
	_ops_qualify(gs)
	ops.reconcile()
	gs.crew_records[OPS_CREW]["wage_missed_since"] = gs.day - 5
	gs.time_slots_today = 2
	_expect_str("ops delinquent payroll outranks the window",
		_blocker_code(ops.assignment_blocker(OPS_OPERATION)), "payroll_not_delinquent")

	# The operation belongs to a person; asking somebody else is refused.
	_ops_qualify(gs)
	ops.reconcile()
	var wrong: Dictionary = ops.handle("assign_crew_operation",
		{"crew_id": "eli", "operation_id": OPS_OPERATION})
	_expect_true("ops wrong crew refused", not bool(wrong.get("ok", false)))
	var unknown: Dictionary = ops.handle("assign_crew_operation",
		{"crew_id": OPS_CREW, "operation_id": "not_an_operation"})
	_expect_true("ops unknown operation refused", not bool(unknown.get("ok", false)))

func _check_ops_settlement(gs: Node, gm: Node, ops: RefCounted) -> void:
	_ops_qualify(gs)
	ops.reconcile()
	gm.dispatch("assign_crew_operation", {"crew_id": OPS_CREW, "operation_id": OPS_OPERATION})
	var assigned_day: int = gs.day
	_expect_true("ops settlement starts pending",
		not bool(ops.assignment_for(OPS_CREW)["settled"]))

	# Walk to the night cross. Settlement runs on day_ending, so it must have
	# happened by the time the clock reads the next day.
	for _slot in 4:
		gm.dispatch("advance_time", {})
	_expect_int("ops settlement crossed the day", gs.day, assigned_day + 1)
	# The record is stale now (yesterday's), so read it off raw state.
	var settled: Dictionary = gs.crew_assignments.get(OPS_CREW, {})
	_expect_int("ops settled record keeps its day", int(settled.get("day", -1)), assigned_day)
	_expect_true("ops assignment settled at night", bool(settled.get("settled", false)))
	# FS-001.6 asserted this settled to NULL, because no adapter existed. One
	# does now, so the truth changed: settlement returns the adapter's
	# aggregate. The property that mattered — a claim on an ended day always
	# closes — is unchanged and still checked on the line above.
	var settled_result: Variant = settled.get("result")
	_expect_true("ops settles through the adapter", settled_result is Dictionary)
	if settled_result is Dictionary:
		for field in ["settled_count", "gross", "profit_or_loss", "individual_results"]:
			_expect_true("ops settlement result carries %s" % field,
				(settled_result as Dictionary).has(field))
	# The no-adapter path still exists and is still null — an operation nobody
	# owns must close rather than hang, which is what keeps the substrate
	# correct when it is empty.
	_expect_true("ops with no registered adapter still settles to null",
		ops._settle(OPS_CREW, {"operation_id": "unowned_operation"}, gs.day) == null)
	# And today's read no longer sees it, which is what frees the crew member.
	_expect_true("ops stale assignment is not today's",
		ops.assignment_for(OPS_CREW).is_empty())

	# A new morning: assignable again.
	gs.time_slots_today = 0
	_expect_true("ops assignable again next morning",
		ops.assignment_blocker(OPS_OPERATION) == null)
	_expect_true("ops next-day assignment dispatches",
		gm.dispatch("assign_crew_operation", {"crew_id": OPS_CREW, "operation_id": OPS_OPERATION}))
	_expect_int("ops new assignment overwrites the old",
		int((gs.crew_assignments.get(OPS_CREW, {}) as Dictionary).get("day", -1)), gs.day)

	# A settled assignment must not settle twice. Re-emitting the signal for a
	# day already closed is the cheapest way to prove the guard holds.
	_ops_qualify(gs)
	ops.reconcile()
	gm.dispatch("assign_crew_operation", {"crew_id": OPS_CREW, "operation_id": OPS_OPERATION})
	if gs.crew_assignments.has(OPS_CREW):
		gs.crew_assignments[OPS_CREW]["settled"] = true
		gs.crew_assignments[OPS_CREW]["result"] = {"sentinel": true}
	gs.day_ending.emit(gs.day)
	_expect_true("ops settled assignment is not re-settled",
		_sentinel_kept(gs.crew_assignments.get(OPS_CREW)))

	# An assignment for a day that is NOT ending is left alone.
	_ops_qualify(gs)
	ops.reconcile()
	gm.dispatch("assign_crew_operation", {"crew_id": OPS_CREW, "operation_id": OPS_OPERATION})
	gs.day_ending.emit(gs.day - 1)
	_expect_true("ops another day's ending does not settle today's",
		not _is_settled(gs.crew_assignments.get(OPS_CREW)))

## Persistence: the v6 → v7 arm, and that the lifecycle survives a round trip.
func _check_ops_persistence(gs: Node, gm: Node, ops: RefCounted) -> void:
	var saves := get_node("/root/SaveSystem")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	_expect_true("ops assignments persist", "crew_assignments" in saves.PERSIST_FIELDS)
	_expect_true("ops state persists", "crew_operation_state" in saves.PERSIST_FIELDS)

	# A pending assignment and a latched discovery both survive, and the
	# assignment is still recognised as TODAY's after the clock is restored.
	_ops_qualify(gs)
	ops.reconcile()
	gm.dispatch("assign_crew_operation", {"crew_id": OPS_CREW, "operation_id": OPS_OPERATION})
	var saved_day: int = gs.day
	saves.save_run()
	# Scramble, so a load that silently no-ops cannot pass.
	gs.crew_assignments = {}
	gs.crew_operation_state = {"discovered": [], "adapters": {}}
	gs.day = 99
	_expect_true("ops save reloads", saves.load_run())
	_expect_int("ops day restored", gs.day, saved_day)
	_expect_true("ops discovery restored", ops.is_discovered(OPS_OPERATION))
	_expect_true("ops assignment restored as today's",
		not ops.assignment_for(OPS_CREW).is_empty())
	_expect_true("ops restored assignment still blocks a second",
		not requirements_ok(gm, ops))

	# A SETTLED assignment must not re-settle after a reload, and must not
	# claim the crew member's next day either.
	if gs.crew_assignments.has(OPS_CREW):
		gs.crew_assignments[OPS_CREW]["settled"] = true
		gs.crew_assignments[OPS_CREW]["result"] = {"sentinel": true}
	saves.save_run()
	_expect_true("ops settled save reloads", saves.load_run())
	_expect_true("ops settled result survived",
		_sentinel_kept(gs.crew_assignments.get(OPS_CREW)))
	gs.day_ending.emit(gs.day)
	_expect_true("ops settled assignment does not re-settle after load",
		_sentinel_kept(gs.crew_assignments.get(OPS_CREW)))

	# --- the v6 → v7 arm ---------------------------------------------------
	# A v6 save has no operation state and holdings with no ownership tag.
	gs.reset_to_new_game()
	var v6_state := {
		"day": 8, "cash": 400, "street_name": "Legacy",
		"list_tier": 3, "list_flips": 12,
		"list_holdings": [
			{"item_id": "space_heater", "bought_day": 7},
			{"item_id": "dresser", "bought_day": 8, "source": "already_tagged"},
		],
		"crew_records": {OPS_CREW: {
			"recruited": true, "status": "active", "loyalty": 9, "tier": 2,
			"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1,
		}},
	}
	var file := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("ops migration", "could not write the fixture save")
		return
	file.store_string(var_to_str({"save_version": 6, "state": v6_state}))
	file.close()

	_expect_true("v6 save loads into v7", saves.load_run())
	_expect_int("v6 migration day", gs.day, 8)
	_expect_true("v6 migration defaults assignments empty", gs.crew_assignments.is_empty())
	_expect_true("v6 migration defaults operation state",
		(gs.crew_operation_state["discovered"] as Array).is_empty()
			or ops.is_discovered(OPS_OPERATION))

	# Ownership is stamped, not inferred later — an untagged holding could only
	# ever have been bought by the player, and that stops being knowable once
	# delegated buying exists.
	_expect_str("v6 migration tags an untagged holding",
		str((gs.list_holdings[0] as Dictionary).get("source", "")), "player")
	_expect_str("v6 migration leaves an already-tagged holding alone",
		str((gs.list_holdings[1] as Dictionary).get("source", "")), "already_tagged")

	# Qualifying-load unlock: this save has met the discovery requirements for
	# days without anything ever having looked. It must be known on the first
	# frame after CONTINUE RUN, not after the next action.
	_expect_true("v6 qualifying save discovers on load", ops.is_discovered(OPS_OPERATION))

	# A v6 save that does NOT qualify stays hidden — so the load-time reconcile
	# is evaluating, not blanket-unlocking.
	gs.reset_to_new_game()
	var plain_state: Dictionary = v6_state.duplicate(true)
	plain_state["list_tier"] = 1
	var plain := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if plain != null:
		plain.store_string(var_to_str({"save_version": 6, "state": plain_state}))
		plain.close()
	_expect_true("v6 non-qualifying save loads", saves.load_run())
	_expect_true("v6 non-qualifying save stays hidden", not ops.is_discovered(OPS_OPERATION))

	# Malformed holdings must not break the arm.
	gs.reset_to_new_game()
	var junk_state: Dictionary = v6_state.duplicate(true)
	junk_state["list_holdings"] = ["not a dictionary", 7]
	var junk := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if junk != null:
		junk.store_string(var_to_str({"save_version": 6, "state": junk_state}))
		junk.close()
	_expect_true("v6 malformed holdings still migrates", saves.load_run())

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## Did the planted sentinel survive? Null-safe, so a sabotage that re-settles
## or drops the record fails the check instead of crashing the section.
func _sentinel_kept(entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var result: Variant = (entry as Dictionary).get("result")
	return (result is Dictionary) and bool((result as Dictionary).get("sentinel", false))

func _is_settled(entry: Variant) -> bool:
	return (entry is Dictionary) and bool((entry as Dictionary).get("settled", false))

## Small helper: is the operation assignable right now? Used where the check is
## about the answer rather than about which blocker produced it.
func requirements_ok(gm: Node, ops: RefCounted) -> bool:
	return ops.assignment_blocker(OPS_OPERATION) == null

## The port seam — the FS-001.5 lesson applied before it can bite again.
##
## Every requirement fixture is recorded from the oracle, and the oracle can
## only produce the shapes JS has. This build represents "no assignment" as an
## ABSENT Dictionary key and a stale record as one whose `day` does not match —
## neither of which any oracle fixture can express. The evaluator is handed
## those shapes by `_facts()`, so the translation is checked here against live
## GameState rather than against recorded truth.
func _check_ops_port_seam(gs: Node, gm: Node, ops: RefCounted) -> void:
	var requirements: RefCounted = gm.system("requirements") as RefCounted
	if requirements == null:
		_fail("ops port seam", "requirements system is missing")
		return
	_ops_qualify(gs)
	ops.reconcile()

	# 1. ABSENT means unassigned. The oracle would write null; this build writes
	#    nothing at all, and an evaluator that only understood null would read a
	#    missing key as a live booking.
	_expect_true("seam no assignment key at all", not gs.crew_assignments.has(OPS_CREW))
	_expect_true("seam absent assignment reads as free",
		bool(requirements.evaluate_requirement(
			{"type": "crew_unassigned_today", "crew_id": OPS_CREW},
			ops._facts())["ok"]))

	# 2. A live booking blocks — through the real record, not a hand-built one.
	gm.dispatch("assign_crew_operation", {"crew_id": OPS_CREW, "operation_id": OPS_OPERATION})
	_expect_true("seam live assignment blocks",
		not bool(requirements.evaluate_requirement(
			{"type": "crew_unassigned_today", "crew_id": OPS_CREW},
			ops._facts())["ok"]))

	# 3. YESTERDAY's booking does not. This is the one that would strand a crew
	#    member permanently if `_facts()` handed over the whole dictionary.
	gs.day += 1
	gs.time_slots_today = 0
	_expect_true("seam stale assignment is still in raw state",
		gs.crew_assignments.has(OPS_CREW))
	_expect_true("seam stale assignment is filtered out of facts",
		not (ops._facts()["assignments"] as Dictionary).has(OPS_CREW))
	_expect_true("seam stale assignment does not block",
		bool(requirements.evaluate_requirement(
			{"type": "crew_unassigned_today", "crew_id": OPS_CREW},
			ops._facts())["ok"]))

	# 4. The -1 wage sentinel, again — this time reaching the evaluator through
	#    the real facts builder rather than a fixture.
	_expect_int("seam crew record carries the -1 sentinel",
		int(gs.crew_record(OPS_CREW)["wage_missed_since"]), -1)
	_expect_true("seam -1 sentinel is not delinquent through _facts()",
		bool(requirements.evaluate_requirement(
			{"type": "payroll_not_delinquent", "crew_id": OPS_CREW},
			ops._facts())["ok"]))

	# 5. A crew member who was never recruited has no record at all, and an
	#    empty Dictionary is not a crew member with zero loyalty.
	_expect_true("seam unrecruited crew is absent from facts",
		not (ops._facts()["crew"] as Dictionary).has("tone"))
	_expect_true("seam unrecruited crew fails crew_active",
		not bool(requirements.evaluate_requirement(
			{"type": "crew_active", "crew_id": "tone"}, ops._facts())["ok"]))

## FS-001.7 — Pherris running the board.
##
## No web oracle exists for this (FS-001.3/.4 were never implemented in web), so
## the acceptance matrix is the contract and these are behavioural checks against
## it. What that means in practice: they have to be more explicit than a fixture
## replay, because there is no recorded truth to fall back on.
##
## Most cases run on a CONTROLLED item table rather than a real day's board.
## Finding a real day that happens to offer two items at the same price, or
## nothing but rough stock, would make the test depend on the shuffle — and then
## a board-generator change would break tests that are not about generation.
## The table is swapped in and restored around each case.
const RB_OPERATION := "907list_run_board"
const RB_CREW := "pherris"

func _check_run_the_board() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var ops: RefCounted = gm.system("crew_operations") as RefCounted
	var adapter: RefCounted = gm.system("list_adapter") as RefCounted
	var lst: RefCounted = gm.system("list") as RefCounted
	if ops == null or adapter == null or lst == null:
		_fail("run the board", "a required system is missing")
		return
	var original_items: Array = gs.listing_items.duplicate(true)
	_check_rb_selection(gs, gm, ops, adapter, lst)
	_check_rb_stop_reasons(gs, gm, ops, adapter, lst)
	_check_rb_cycle_caps(gs, gm, ops, adapter, lst)
	gs.listing_items = original_items
	_check_rb_shared_consumption(gs, gm, ops, lst)
	_check_rb_settlement(gs, gm, ops, lst)
	_check_rb_leakage(gs, gm, ops, lst)
	_check_rb_reload(gs, gm, ops, lst)
	gs.listing_items = original_items
	gs.reset_to_new_game()

## Broker tier, Pherris loyal, morning, money in hand.
func _rb_ready(gs: Node, cash: int = 5000) -> void:
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 12
	gs.time_slots_today = 0
	gs.time_slot = "MORNING"
	gs.cash = cash
	gs.list_tier = 3
	gs.crew_records[RB_CREW] = {
		"recruited": true, "status": "active", "loyalty": 8, "tier": 2,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1, "proofs": {},
	}

func _rb_item(id: String, buy: int, condition: String, low: int, high: int) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "category": "household", "tier": 1,
		"buy": buy, "true_value": [low, high], "condition": condition}

## Assign her and hand back the morning's selection record.
func _rb_assign(gs: Node, gm: Node, ops: RefCounted, payload: Dictionary = {}) -> Dictionary:
	ops.reconcile()
	var full: Dictionary = {"crew_id": RB_CREW, "operation_id": RB_OPERATION}
	for key in payload.keys():
		full[key] = payload[key]
	gm.dispatch("assign_crew_operation", full)
	var assignment: Variant = gs.crew_assignments.get(RB_CREW)
	if not (assignment is Dictionary):
		return {}
	var selection: Variant = (assignment as Dictionary).get("selection")
	return selection if selection is Dictionary else {}

func _rb_purchased_ids(selection: Dictionary) -> Array:
	var out: Array = []
	for row in selection.get("purchased", []):
		out.append(str((row as Dictionary)["item_id"]))
	return out

## What she takes, and in what order.
func _check_rb_selection(gs: Node, gm: Node, ops: RefCounted, adapter: RefCounted,
		lst: RefCounted) -> void:
	# Rough stock is the one thing she refuses. A board of nothing else leaves
	# her with a committed day and no purchases.
	_rb_ready(gs)
	gs.listing_items = [
		_rb_item("rough_a", 20, "rough", 30, 40),
		_rb_item("rough_b", 30, "rough", 45, 60),
	]
	var rough_only: Dictionary = _rb_assign(gs, gm, ops)
	_expect_int("rb rough-only buys nothing", int(rough_only.get("cycles_used", -1)), 0)
	_expect_str("rb rough-only stop reason",
		str(rough_only.get("stop_reason", "")), "no_acceptable")
	_expect_true("rb rough-only still commits the day",
		not ops.assignment_for(RB_CREW).is_empty())
	_expect_true("rb rough-only reports ok false", not bool(rough_only.get("ok", true)))
	_expect_int("rb rough-only spends nothing", int(rough_only.get("total_spent", -1)), 0)

	# A rough item mixed in is skipped even when it is the cheapest thing there —
	# the filter is taste, not budget.
	_rb_ready(gs)
	gs.listing_items = [
		_rb_item("cheap_rough", 10, "rough", 20, 30),
		_rb_item("mid_good", 60, "good", 90, 120),
		_rb_item("high_mint", 125, "mint", 180, 240),
	]
	var mixed: Dictionary = _rb_assign(gs, gm, ops)
	var mixed_ids: Array = _rb_purchased_ids(mixed)
	_expect_true("rb never buys rough", not "cheap_rough" in mixed_ids)
	_expect_str("rb buys cheapest acceptable first", str(mixed_ids), str(["mid_good", "high_mint"]))

	# Ties break on the item's position on the board, not on table order.
	#
	# This needs a WIDE tied group to test anything. A first pass used three
	# items and passed with the tie-break removed — GDScript's sort happens to
	# leave a 3-element array alone, so the check could not tell the two
	# implementations apart. Introsort only permutes equal keys once the array is
	# big enough, so the board is widened for this case and the assertion is the
	# rule stated directly: every equal-priced item keeps its board order.
	_rb_ready(gs)
	var tied_table: Array = []
	for i in 20:
		tied_table.append(_rb_item("tie_%02d" % i, 60, "good", 90, 120))
	gs.listing_items = tied_table
	var listings_config: int = int(gs.market_tiers[3]["listings"])
	gs.market_tiers[3]["listings"] = 20
	ops.reconcile()
	var board_order: Array = []
	for listing in lst.todays_listings():
		board_order.append(str((listing as Dictionary)["id"]))
	var acceptable_order: Array = []
	for listing in adapter.acceptable_board():
		acceptable_order.append(str((listing as Dictionary)["id"]))
	gs.market_tiers[3]["listings"] = listings_config
	_expect_int("rb wide tied board is wide enough to permute", board_order.size(), 20)
	_expect_str("rb equal prices keep board order", str(acceptable_order), str(board_order))

## Every stop reason, and the order they are checked in.
func _check_rb_stop_reasons(gs: Node, gm: Node, ops: RefCounted, adapter: RefCounted,
		lst: RefCounted) -> void:
	var board := [
		_rb_item("cheap", 60, "good", 90, 120),
		_rb_item("dearer", 65, "good", 95, 130),
		_rb_item("dearest", 125, "good", 180, 240),
	]

	# Spend limit: $100 against $60 and $65 buys the $60 and stops, because the
	# next one would cross the line rather than land on it.
	_rb_ready(gs)
	gs.listing_items = board.duplicate(true)
	var limited: Dictionary = _rb_assign(gs, gm, ops, {"spend_limit": 100})
	_expect_str("rb spend limit buys what fits",
		str(_rb_purchased_ids(limited)), str(["cheap"]))
	_expect_int("rb spend limit total", int(limited.get("total_spent", -1)), 60)
	_expect_str("rb spend limit stop reason",
		str(limited.get("stop_reason", "")), "spend_limit")

	# Exactly on the line is affordable — the check is "would exceed", not
	# "would reach".
	_rb_ready(gs)
	gs.listing_items = board.duplicate(true)
	var exact: Dictionary = _rb_assign(gs, gm, ops, {"spend_limit": 125})
	_expect_int("rb spend limit spends up to the line exactly",
		int(exact.get("total_spent", -1)), 125)

	# A $0 limit commits her day for nothing. That is a real choice, not an error.
	_rb_ready(gs)
	gs.listing_items = board.duplicate(true)
	var zero: Dictionary = _rb_assign(gs, gm, ops, {"spend_limit": 0})
	_expect_int("rb zero limit buys nothing", int(zero.get("cycles_used", -1)), 0)
	_expect_str("rb zero limit stop reason", str(zero.get("stop_reason", "")), "spend_limit")
	_expect_true("rb zero limit still commits the day",
		not ops.assignment_for(RB_CREW).is_empty())

	# Cash runs out before the board does.
	_rb_ready(gs, 50)
	gs.listing_items = board.duplicate(true)
	var broke: Dictionary = _rb_assign(gs, gm, ops)
	_expect_int("rb no cash buys nothing", int(broke.get("cycles_used", -1)), 0)
	_expect_str("rb no cash stop reason", str(broke.get("stop_reason", "")), "cash")
	_expect_int("rb no cash leaves the wallet alone", gs.cash, 50)

	# Storage full outranks everything — she has nowhere to put it.
	_rb_ready(gs)
	gs.listing_items = board.duplicate(true)
	gs.list_tier = 1  # capacity 3
	for i in 3:
		gs.list_holdings.append({"item_id": "cheap", "bought_day": 1, "source": "player"})
	gs.list_tier = 3
	gs.list_holdings.resize(int(gs.market_tier()["capacity"]))
	for i in gs.list_holdings.size():
		gs.list_holdings[i] = {"item_id": "cheap", "bought_day": 1, "source": "player"}
	var full: Dictionary = _rb_assign(gs, gm, ops)
	_expect_int("rb full storage buys nothing", int(full.get("cycles_used", -1)), 0)
	_expect_str("rb full storage stop reason", str(full.get("stop_reason", "")), "capacity")

	# Priority: with BOTH the wallet and the shelf against her, the shelf is
	# reported — it is the more fundamental problem.
	_rb_ready(gs, 10)
	gs.listing_items = board.duplicate(true)
	gs.list_holdings.resize(int(gs.market_tier()["capacity"]))
	for i in gs.list_holdings.size():
		gs.list_holdings[i] = {"item_id": "cheap", "bought_day": 1, "source": "player"}
	var both: Dictionary = _rb_assign(gs, gm, ops)
	_expect_str("rb capacity outranks cash", str(both.get("stop_reason", "")), "capacity")

## The cycle cap comes off the capability curve at her rank.
func _check_rb_cycle_caps(gs: Node, gm: Node, ops: RefCounted, adapter: RefCounted,
		lst: RefCounted) -> void:
	var deep_board: Array = []
	for i in 6:
		deep_board.append(_rb_item("item_%d" % i, 20 + i * 5, "good", 60, 90))
	for entry in [[1, 1], [2, 2], [3, 3], [6, 3]]:
		var rank: int = int(entry[0])
		var want: int = int(entry[1])
		_rb_ready(gs)
		gs.listing_items = deep_board.duplicate(true)
		gs.crew_records[RB_CREW]["tier"] = rank
		_expect_int("rb cycle cap at rank %d" % rank, adapter.cycle_cap(RB_CREW), want)
		var picked: Dictionary = _rb_assign(gs, gm, ops)
		_expect_int("rb buys up to the cap at rank %d" % rank,
			int(picked.get("cycles_used", -1)), want)
		_expect_str("rb stops on the cap at rank %d" % rank,
			str(picked.get("stop_reason", "")), "cycle_cap")
		_expect_int("rb summary reports the cap at rank %d" % rank,
			int(ops.operation_summary(RB_OPERATION)["requested_cap"]), want)

## The board is shared. What one of them takes, the other cannot.
func _check_rb_shared_consumption(gs: Node, gm: Node, ops: RefCounted, lst: RefCounted) -> void:
	_rb_ready(gs)
	ops.reconcile()
	var board: Array = []
	for listing in lst.todays_listings():
		board.append(str((listing as Dictionary)["id"]))
	if board.is_empty():
		_fail("rb shared consumption", "the probe day offers no listings")
		return

	# Player first: her board must not contain what he already took.
	var taken := str(board[0])
	_expect_true("rb player buys first", gm.dispatch("list_buy", {"item_id": taken}))
	var selection: Dictionary = _rb_assign(gs, gm, ops)
	_expect_true("rb she cannot take what the player took",
		not taken in _rb_purchased_ids(selection))

	# Her turn first: the player's board must not contain what she took.
	_rb_ready(gs)
	var hers: Dictionary = _rb_assign(gs, gm, ops)
	var her_ids: Array = _rb_purchased_ids(hers)
	_expect_true("rb she bought something to contest", not her_ids.is_empty())
	if not her_ids.is_empty():
		var contested := str(her_ids[0])
		_expect_true("rb her pickup is marked consumed", contested in lst.taken_today())
		var still_listed := false
		for listing in lst.todays_listings():
			if str((listing as Dictionary)["id"]) == contested:
				still_listed = true
		_expect_true("rb her pickup leaves the board", not still_listed)
		var refused: Dictionary = lst.handle("list_buy", {"item_id": contested})
		_expect_true("rb player cannot rebuy her pickup", not bool(refused.get("ok", false)))

## Settlement: her money is the player's money, through the same path.
func _check_rb_settlement(gs: Node, gm: Node, ops: RefCounted, lst: RefCounted) -> void:
	var exposure := get_node("/root/Exposure")
	_rb_ready(gs)
	var selection: Dictionary = _rb_assign(gs, gm, ops)
	var bought: Array = _rb_purchased_ids(selection)
	if bought.is_empty():
		_fail("rb settlement", "she bought nothing to settle")
		return

	# Her holdings are hers, and the player cannot sell them out from under her.
	for i in gs.list_holdings.size():
		var held: Dictionary = gs.list_holdings[i]
		if str(held.get("source", "")) == "pherris":
			_expect_str("rb delegated holding is not manually sellable",
				lst.sell_blocker(i), "That's Pherris's pickup. It settles tonight.")

	# The realised value is the item's, not the seller's: same key, same money.
	var expected_gross: int = 0
	for held in gs.list_holdings:
		if str((held as Dictionary).get("source", "")) == "pherris":
			expected_gross += lst.realised_value(held)

	for npc_id in exposure.npc_ids():
		exposure.ledger_of(str(npc_id)).clear()
	gs.observation_queue.clear()
	var cash_before: int = gs.cash
	for _slot in 4:
		gm.dispatch("advance_time", {})

	var result: Variant = (gs.crew_assignments.get(RB_CREW, {}) as Dictionary).get("result")
	_expect_true("rb settlement produced a result", result is Dictionary)
	if not (result is Dictionary):
		return
	var settled: Dictionary = result
	_expect_int("rb settled every holding", int(settled["settled_count"]), bought.size())
	_expect_int("rb gross matches the shared value path", int(settled["gross"]), expected_gross)
	_expect_int("rb cash credited by the gross", gs.cash, cash_before + expected_gross)
	_expect_true("rb her holdings are gone", _rb_pherris_holdings(gs) == 0)

	# The Exposure consequence is IDENTICAL to a personal sale — delegation is
	# not a way to launder visibility.
	var household := 0
	for npc_id in exposure.npc_ids():
		for row in exposure.ledger_of(str(npc_id)):
			if str(row["event"]) == "907list_profit":
				household += 1
	_expect_true("rb delegated sale still tells the household", household > 0)

func _rb_pherris_holdings(gs: Node) -> int:
	var count := 0
	for held in gs.list_holdings:
		if str((held as Dictionary).get("source", "")) == "pherris":
			count += 1
	return count

## The three things delegation must NOT give the player. This is the check that
## keeps a crew member from being strictly better than doing the work yourself.
func _check_rb_leakage(gs: Node, gm: Node, ops: RefCounted, lst: RefCounted) -> void:
	_rb_ready(gs)
	var selection: Dictionary = _rb_assign(gs, gm, ops)
	if _rb_purchased_ids(selection).is_empty():
		_fail("rb leakage", "she bought nothing to settle")
		return
	var flips_before: int = gs.list_flips
	var tier_before: int = gs.list_tier
	var progress_before: float = float(gs.attribute_progress.get("intelligence", 0.0))
	var intelligence_before: int = int(gs.attributes.get("intelligence", 1))
	var day_before: int = gs.day

	# Cross the night through the real dispatch path. Emitting `day_ending` by
	# hand would settle without a dispatch on the stack, which trips the
	# ownership guard on Curtis's mutators — a path the game never takes, and
	# exactly the false signal that guard exists to raise.
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	_expect_true("rb night cross dispatches", gm.dispatch("advance_time", {}))

	_expect_int("rb delegated settlement trains no Intelligence progress",
		int(round(float(gs.attribute_progress.get("intelligence", 0.0)) * 1000.0)),
		int(round(progress_before * 1000.0)))
	_expect_int("rb delegated settlement raises no attribute",
		int(gs.attributes.get("intelligence", 1)), intelligence_before)
	_expect_int("rb delegated settlement counts no flip", gs.list_flips, flips_before)
	_expect_int("rb delegated settlement advances no tier", gs.list_tier, tier_before)
	# The night cross itself moves the clock by exactly one day and resets the
	# slot. What is being checked is that settling her pickups adds NOTHING on
	# top of that — the control below is the same cross with nothing pending.
	_expect_int("rb settling costs only the night cross itself", gs.day, day_before + 1)
	_expect_int("rb settling leaves the slot where the cross put it",
		gs.time_slots_today, 0)
	_expect_true("rb delegated settlement did happen",
		bool((gs.crew_assignments[RB_CREW] as Dictionary)["settled"]))

	# Control: an identical night cross with no assignment pending moves the
	# clock the same amount, which is what makes the two assertions above a
	# statement about settlement rather than about the cross.
	_rb_ready(gs)
	var quiet_day: int = gs.day
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	gm.dispatch("advance_time", {})
	_expect_int("rb an empty night cross moves the clock identically",
		gs.day, quiet_day + 1)
	_expect_int("rb an empty night cross resets the slot identically",
		gs.time_slots_today, 0)

	# The same sale by the player DOES move all three, which is what makes the
	# assertions above mean something rather than testing an inert path.
	_rb_ready(gs)
	var board: Array = lst.todays_listings()
	if board.is_empty():
		_fail("rb leakage control", "no board to buy from")
		return
	var personal_flips: int = gs.list_flips
	var personal_slot: int = gs.time_slots_today
	gm.dispatch("list_buy", {"item_id": str((board[0] as Dictionary)["id"])})
	var index: int = gs.list_holdings.size() - 1
	var paid: int = int(gs.listing_item_by_id(str(gs.list_holdings[index]["item_id"]))["buy"])
	var value: int = lst.realised_value(gs.list_holdings[index])
	gm.dispatch("list_sell", {"index": index})
	_expect_int("rb personal sale costs a slot", gs.time_slots_today, personal_slot + 1)
	if value > paid:
		_expect_int("rb personal sale counts a flip", gs.list_flips, personal_flips + 1)

## Save before the night, load, settle: the same money either way.
func _check_rb_reload(gs: Node, gm: Node, ops: RefCounted, lst: RefCounted) -> void:
	# `adapter` is fetched inside where it is needed — see the idempotency block.
	var saves := get_node("/root/SaveSystem")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	_rb_ready(gs)
	var selection: Dictionary = _rb_assign(gs, gm, ops)
	var bought: Array = _rb_purchased_ids(selection)
	saves.save_run()
	# Snapshot the bytes. Settling below goes through dispatch, and dispatch
	# autosaves on state_changed — so the file on disk is overwritten by the
	# post-night state before the reload can read the pre-night one. Holding the
	# bytes is what makes "load the save from before the night" mean that.
	var pre_night := ""
	var snapshot := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
	if snapshot != null:
		pre_night = snapshot.get_as_text()
		snapshot.close()
	_expect_true("rb pre-night save captured", not pre_night.is_empty())

	# Settle without a reload, and remember the money. Through dispatch, so the
	# ownership guard sees the same stack the game produces.
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	gm.dispatch("advance_time", {})
	var direct: Dictionary = (gs.crew_assignments[RB_CREW] as Dictionary)["result"]
	var direct_cash: int = gs.cash

	# Now the same night, from disk — the pre-night bytes put back first.
	var rewind := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if rewind != null:
		rewind.store_string(pre_night)
		rewind.close()
	_expect_true("rb reload loads", saves.load_run())
	_expect_str("rb reload restored her selection",
		str(_rb_purchased_ids(
			((gs.crew_assignments.get(RB_CREW, {}) as Dictionary).get("selection", {})
				as Dictionary))),
		str(bought))
	_expect_true("rb reload restored her holdings", _rb_pherris_holdings(gs) == bought.size())
	# The adapter is runtime wiring; a load must not lose it. Before FS-001.7 the
	# registry lived in persisted state, which meant exactly that.
	_expect_true("rb adapter survives a load",
		ops._adapter_for(RB_OPERATION) != null)
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	gm.dispatch("advance_time", {})
	var reloaded: Dictionary = (gs.crew_assignments[RB_CREW] as Dictionary)["result"]
	_expect_int("rb reload settles the same count",
		int(reloaded["settled_count"]), int(direct["settled_count"]))
	_expect_int("rb reload settles for the same gross",
		int(reloaded["gross"]), int(direct["gross"]))
	_expect_int("rb reload leaves the same cash", gs.cash, direct_cash)

	# And a settled assignment does not pay out twice — checked at BOTH guards.
	#
	# Through the signal, the coordinator's `settled` check stops it before the
	# adapter is consulted, so that path alone never exercises the adapter's own
	# guard. A first pass tested only this and passed with the adapter's guard
	# deleted. Paying a day out twice is the kind of bug that shows up as a
	# number nobody can account for, so both layers are held to it.
	var cash_after: int = gs.cash
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	gm.dispatch("advance_time", {})
	_expect_int("rb settled assignment does not re-settle on a later night",
		gs.cash, cash_after)

	var adapter: Object = ops._adapter_for(RB_OPERATION)
	if adapter == null:
		_fail("rb idempotency", "no adapter registered")
	else:
		var assignment: Dictionary = gs.crew_assignments[RB_CREW]
		var stored: Dictionary = assignment["result"]
		var again: Variant = adapter.settle(RB_CREW, assignment, gs.day)
		_expect_int("rb adapter re-settle pays nothing", gs.cash, cash_after)
		_expect_true("rb adapter re-settle returns the stored result",
			again is Dictionary
				and int((again as Dictionary)["gross"]) == int(stored["gross"])
				and int((again as Dictionary)["settled_count"]) == int(stored["settled_count"]))

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## FS-001.8 — the reads the screens are built on.
##
## The screens themselves are checked by rendering them (see the PR), but the
## contract that matters is here: **the UI owns no gameplay rules.** Everything
## it shows about Pherris comes from `operation_summary()`, `preview()` and
## `spend_options()`, so those are what get held to account.
##
## The central one is that a preview must not lie. A preview that re-derives its
## answer is a second implementation, and the day it drifts the player is shown
## a number the game does not honour — so `preview()` and `select()` are run
## against each other on the same state and required to agree exactly.
func _check_operation_presentation() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var ops: RefCounted = gm.system("crew_operations") as RefCounted
	var adapter: RefCounted = gm.system("list_adapter") as RefCounted
	var lst: RefCounted = gm.system("list") as RefCounted
	if ops == null or adapter == null or lst == null:
		_fail("presentation", "a required system is missing")
		return
	_check_preview_matches_reality(gs, gm, ops, adapter)
	_check_preview_context(gs, gm, ops, adapter, lst)
	_check_spend_options(gs, gm, ops, adapter)
	_check_summary_shape(gs, gm, ops)
	_check_last_assignment(gs, gm, ops)
	_check_screen_reads(gs, gm)
	gs.reset_to_new_game()

## The guarantee: what the player is shown is what happens.
##
## Run at every budget the board supports, plus the unlimited case and a few
## that stop early — because the useful version of this check is not "they agree
## once" but "they agree at every boundary the player can pick".
func _check_preview_matches_reality(gs: Node, gm: Node, ops: RefCounted,
		adapter: RefCounted) -> void:
	for limit in [-1, 0, 25, 60, 100, 5000]:
		_rb_ready(gs)
		ops.reconcile()
		var predicted: Dictionary = adapter.preview(RB_CREW, limit)
		var predicted_ids: Array = []
		for entry in predicted["items"]:
			predicted_ids.append(str((entry as Dictionary)["item_id"]))
		var cash_before: int = gs.cash

		gm.dispatch("assign_crew_operation", {
			"crew_id": RB_CREW, "operation_id": RB_OPERATION, "spend_limit": limit})
		var selection: Dictionary = (gs.crew_assignments[RB_CREW] as Dictionary)["selection"]
		var label := "preview @%d" % limit
		_expect_str(label + " picks what it promised",
			str(_rb_purchased_ids(selection)), str(predicted_ids))
		_expect_int(label + " spends what it promised",
			int(selection["total_spent"]), int(predicted["total_spent"]))
		_expect_int(label + " stops for the reason it promised",
			1 if str(selection["stop_reason"]) == str(predicted["stop_reason"]) else 0, 1)
		# And the cash figure the screen showed is the cash that resulted.
		_expect_int(label + " leaves the cash it promised",
			gs.cash, int(predicted["cash_after"]))
		_expect_int(label + " cash_on_hand was the truth", int(predicted["cash_on_hand"]),
			cash_before)

## A preview is a read. It must not move anything.
func _check_preview_context(gs: Node, gm: Node, ops: RefCounted, adapter: RefCounted,
		lst: RefCounted) -> void:
	_rb_ready(gs)
	ops.reconcile()
	var cash: int = gs.cash
	var holdings: int = gs.list_holdings.size()
	var taken: int = lst.taken_today().size()
	for limit in [-1, 0, 60, 9999]:
		adapter.preview(RB_CREW, limit)
		ops.operation_summary(RB_OPERATION)
		ops.spend_options(RB_OPERATION)
	_expect_int("preview spends no cash", gs.cash, cash)
	_expect_int("preview takes no stock", gs.list_holdings.size(), holdings)
	_expect_int("preview consumes no opportunity", lst.taken_today().size(), taken)
	_expect_true("preview claims no day", ops.assignment_for(RB_CREW).is_empty())

	# Storage is reported against what is actually free, not against the tier's
	# raw capacity — a shelf with something on it has less room.
	var capacity: int = lst.capacity()
	var plan: Dictionary = adapter.preview(RB_CREW, -1)
	_expect_int("preview storage capacity", int(plan["storage_capacity"]), capacity)
	_expect_int("preview storage free on an empty shelf", int(plan["storage_free"]), capacity)
	gs.list_holdings.append({"item_id": "space_heater", "bought_day": 1, "source": "player"})
	_expect_int("preview storage free counts what is held",
		int((adapter.preview(RB_CREW, -1) as Dictionary)["storage_free"]), capacity - 1)

	# A full shelf previews the stop reason rather than a plan.
	_rb_ready(gs)
	ops.reconcile()
	for i in capacity:
		gs.list_holdings.append({"item_id": "space_heater", "bought_day": 1, "source": "player"})
	var full: Dictionary = adapter.preview(RB_CREW, -1)
	_expect_int("preview on a full shelf plans nothing", int(full["cycles_used"]), 0)
	_expect_str("preview on a full shelf says why", str(full["stop_reason"]), "capacity")
	_expect_int("preview on a full shelf reports no room", int(full["storage_free"]), 0)

	# Low cash previews the cash stop, and never a spend the player cannot make.
	_rb_ready(gs, 10)
	ops.reconcile()
	var broke: Dictionary = adapter.preview(RB_CREW, -1)
	_expect_int("preview with no cash plans nothing", int(broke["cycles_used"]), 0)
	_expect_str("preview with no cash says why", str(broke["stop_reason"]), "cash")
	_expect_int("preview never plans past the wallet",
		int(broke["cash_after"]), int(broke["cash_on_hand"]))

	# The case that actually tests running the wallet down: enough for the FIRST
	# item and not for the second. A first pass only tested "cannot afford
	# anything", which passes whether or not the plan tracks what it has already
	# committed — and a plan that forgets would promise a spend the player
	# cannot make.
	_rb_ready(gs)
	ops.reconcile()
	var whole: Dictionary = adapter.preview(RB_CREW, -1)
	if int(whole["cycles_used"]) < 2:
		_fail("preview cumulative cash", "the probe board does not offer two items")
	else:
		var first_cost: int = int((whole["items"][0] as Dictionary)["cost"])
		var second_cost: int = int((whole["items"][1] as Dictionary)["cost"])
		# Exactly enough for one, one dollar short of both.
		_rb_ready(gs, first_cost + second_cost - 1)
		ops.reconcile()
		var tight: Dictionary = adapter.preview(RB_CREW, -1)
		_expect_int("preview stops when the running total empties the wallet",
			int(tight["cycles_used"]), 1)
		_expect_str("preview says the wallet stopped it",
			str(tight["stop_reason"]), "cash")
		_expect_int("preview never promises more than the wallet holds",
			int(tight["total_spent"]), first_cost)
		_expect_true("preview leaves a non-negative balance",
			int(tight["cash_after"]) >= 0)

## The budgets offered are real ones: each buys exactly that many items.
func _check_spend_options(gs: Node, gm: Node, ops: RefCounted, adapter: RefCounted) -> void:
	_rb_ready(gs)
	ops.reconcile()
	var options: Array = ops.spend_options(RB_OPERATION)
	var cap: int = adapter.cycle_cap(RB_CREW)
	_expect_true("spend options never exceed the rank cap", options.size() <= cap)
	_expect_true("spend options exist when the board does", not options.is_empty())

	var running: int = 0
	for i in options.size():
		var option: Dictionary = options[i]
		_expect_int("spend option %d counts up by one" % i, int(option["cycles"]), i + 1)
		_expect_true("spend option %d costs more than the last" % i,
			int(option["spend"]) > running)
		running = int(option["spend"])
		# The promise each button makes: this budget buys exactly this many.
		var at_budget: Dictionary = adapter.preview(RB_CREW, int(option["spend"]))
		_expect_int("spend option %d buys what it says" % i,
			int(at_budget["cycles_used"]), int(option["cycles"]))
		_expect_int("spend option %d costs what it says" % i,
			int(at_budget["total_spent"]), int(option["spend"]))
		# And a dollar less buys one fewer — which is what makes the number the
		# boundary rather than a label.
		if int(option["spend"]) > 0:
			var under: Dictionary = adapter.preview(RB_CREW, int(option["spend"]) - 1)
			_expect_true("spend option %d is a real boundary" % i,
				int(under["cycles_used"]) < int(option["cycles"]))

	# Nothing to offer when there is nothing to buy.
	_rb_ready(gs, 5)
	ops.reconcile()
	_expect_true("no spend options when nothing is affordable",
		(ops.spend_options(RB_OPERATION) as Array).is_empty())

## The summary is the screen's single source. Every field it renders must be
## present and honest, including the ones that are null on purpose.
func _check_summary_shape(gs: Node, gm: Node, ops: RefCounted) -> void:
	_rb_ready(gs)
	ops.reconcile()
	var available: Dictionary = ops.operation_summary(RB_OPERATION)
	for field in ["operation_id", "crew_id", "discovered", "available", "blocker",
			"assigned_today", "assignment_settled", "assignment_result",
			"requested_cap", "spend_limit", "stop_reason", "selection", "preview"]:
		_expect_true("summary carries %s" % field, available.has(field))
	_expect_true("summary previews when she is free", available["preview"] is Dictionary)
	_expect_true("summary has no selection before she goes", available["selection"] == null)

	# Once she is out, the preview is null — previewing an assignment that
	# already exists is a different question, and a screen showing both would be
	# offering a choice that is gone.
	gm.dispatch("assign_crew_operation", {"crew_id": RB_CREW, "operation_id": RB_OPERATION})
	var assigned: Dictionary = ops.operation_summary(RB_OPERATION)
	_expect_true("summary stops previewing once she is out", assigned["preview"] == null)
	_expect_true("summary carries the selection once she is out",
		assigned["selection"] is Dictionary)
	_expect_true("summary reports her stop reason",
		not str(assigned["stop_reason"]).is_empty())

	# Undiscovered: no preview, and a blocker that says so rather than a
	# requirement she happens to also fail.
	#
	# On a FRESH run with no assignment. A first pass cleared discovery after
	# assigning her, so the preview was already null for the other reason and
	# the check passed without testing discovery at all.
	_rb_ready(gs)
	gs.crew_operation_state = {"discovered": [], "adapters": {}}
	var hidden: Dictionary = ops.operation_summary(RB_OPERATION)
	_expect_true("summary sees no assignment in the undiscovered case",
		not bool(hidden["assigned_today"]))
	_expect_true("summary does not preview what is undiscovered", hidden["preview"] == null)
	_expect_true("summary reports undiscovered as not available",
		not bool(hidden["available"]))

## "What did she bring back last night" is a real question the day-scoped read
## deliberately cannot answer.
## The screens themselves, rendered.
##
## Everything else in this suite tests the reads a screen is built on; nothing
## tested that a screen can actually consume them. That gap let a real defect
## reach `main`: PR #40 split Exposure's private ledger accessor into
## `_ledger_for_write`, and `people.gd` kept calling the old name — so every NPC
## row on that screen has been erroring, and no check noticed because no check
## rendered anything.
##
## This does not try to be a layout test (the interactive pass at 375x812 covers
## that). It asserts the one thing a headless run can: a screen fed real state
## produces the content that state implies. A broken read shows up as the empty
## copy instead.
func _check_screen_reads(gs: Node, gm: Node) -> void:
	var exposure := get_node("/root/Exposure")
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	# Something for Yalonda to actually know about, so "she knows nothing" is a
	# failure rather than the honest state.
	#
	# Written straight into state rather than through `record_observation`: PR
	# #40's ownership guard makes that a no-op outside a dispatch, and this is
	# fixture setup rather than an exercise of the observation path. This is the
	# same shape the save/load path restores.
	gs.npc_ledgers["yalonda"] = [{
		"key": "financial|rent_paid|north_star_lot",
		"type": "financial", "event": "rent_paid", "location": "north_star_lot",
		"source": "household", "count": 1, "day": gs.day,
	}]
	_expect_true("exposure exposes a public ledger read", exposure.has_method("ledger_of"))
	_expect_true("the ledger read returns the row",
		(exposure.ledger_of("yalonda") as Array).size() > 0)

	var packed: PackedScene = load("res://ui/screens/people.tscn")
	if packed == null:
		_fail("screen reads", "people.tscn will not load")
		return
	var screen: Node = packed.instantiate()
	add_child(screen)
	if screen.has_method("refresh"):
		screen.refresh()
	var text: Array[String] = []
	_collect_labels(screen, text)
	screen.queue_free()

	var joined := "\n".join(text)
	_expect_true("people screen renders something", not text.is_empty())
	# Assert the evidence LINE, not the absence of the empty copy: four other
	# NPCs have nothing on the player and legitimately render "Knows nothing
	# about you yet." The screen prints the event with underscores swapped for
	# spaces, so this string exists only if the ledger read actually returned
	# the row. A broken accessor renders the empty copy for everyone and this
	# line never appears.
	_expect_true("people screen reads the ledger it was given",
		"rent paid" in joined.to_lower())
	_expect_true("people screen names the source of what it knows",
		"household" in joined.to_lower())

func _collect_labels(node: Node, out: Array[String]) -> void:
	if node is Label:
		var t := (node as Label).text.strip_edges()
		if not t.is_empty():
			out.append(t)
	for child in node.get_children():
		_collect_labels(child, out)

func _check_last_assignment(gs: Node, gm: Node, ops: RefCounted) -> void:
	_rb_ready(gs)
	ops.reconcile()
	_expect_true("no last assignment on a fresh run",
		ops.last_assignment(RB_CREW).is_empty())
	gm.dispatch("assign_crew_operation", {"crew_id": RB_CREW, "operation_id": RB_OPERATION})
	var assigned_day: int = gs.day
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	gm.dispatch("advance_time", {})

	# Today's read is empty — the claim was yesterday's — but the record is
	# still there to be asked about.
	_expect_true("today's assignment read is empty after the night",
		ops.assignment_for(RB_CREW).is_empty())
	var last: Dictionary = ops.last_assignment(RB_CREW)
	_expect_true("last assignment survives the day roll", not last.is_empty())
	_expect_int("last assignment keeps its day", int(last["day"]), assigned_day)
	_expect_true("last assignment is settled", bool(last["settled"]))
	_expect_true("last assignment carries its result", last["result"] is Dictionary)

## FS-003.1 — the freeze pass.
##
## The Consequence-Encounter Engine is about to start moving shared seams. This
## pins the inherited behaviour first, so a later slice that drifts it fails here
## rather than in review.
##
## ## What this section deliberately does NOT do
##
## It does not restate coverage that already exists. An audit of the suite before
## this build found most of the named areas already pinned, some of them heavily:
##
##   - Outcome Resolver pools, thresholds, picks and the full resolution grid —
##     `_check_outcome_resolver` (Build 5e)
##   - Stickup's four tiers and their whole consequence spread —
##     `_check_stickup_tiers` (Build 5e)
##   - `day_ending` / `day_crossed` ordering — `_check_day_lifecycle` (FS-001.6)
##   - Market RNG cursor isolation — `_check_stickup_rng_isolation` (Build 5e)
##   - Curtis's volume filter — `_check_list_flip_observation` (FS-001.2)
##   - Save round-trip and the v6 → v7 arm — `_check_save_roundtrip`,
##     `_check_ops_persistence`
##
## A second copy of an assertion that already exists raises the check count and
## protects nothing. Worse, it makes the total a less honest number — and this
## suite has already learned once that a green result is only as good as the
## checks behind it. So what follows is the GAPS that audit turned up.
##
## ## The gaps
##
##   1. **Boost had no behavioural coverage at all.** Only `chance_for()` was
##      pinned, by the attribute-formula fixtures. Nothing covered the roll, the
##      take, the heat, technique, the daily gate, tier promotion, or the fence.
##   2. **The fence had none whatsoever** — not one assertion touched it.
##   3. **The heat WRITE path** was covered only through stickup's per-tier
##      figures; nothing pinned that it stays fractional, clamps, and re-reads
##      the crew multiplier.
##   4. **Cash discipline on refused actions** was implicit everywhere and
##      asserted nowhere.
##   5. **The dispatch-ownership guard** from the cleanup pass shipped with no
##      test at all.
func _check_frozen_behavior() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	_check_boost_behavior(gs, gm)
	_check_boost_fence(gs, gm)
	_check_heat_write_path(gs, gm)
	_check_cash_discipline(gs, gm)
	_check_dispatch_ownership(gs, gm)
	gs.reset_to_new_game()

## The literal win/loss pattern of the Boost sweep below, recorded once off the
## real system. Golden data: it moves only if Boost's observable behaviour does.
##
## **Re-pinned once, in FS-003.7, and here is exactly why.**
##
## The roll key is `boost:<day>:<slot>:<target>`. Before .7 a failed lift settled
## its slot immediately, so the next target in the same day rolled at slot+1;
## now the slot stays owed until the Caught chain reaches Continue, so it rolls
## at the SAME slot and therefore against a different key. Two bits moved —
## `spenard_fuel` on days 4 and 6, both of which follow a `night_owl` miss.
##
## Nothing about the roll itself changed: the chance formula, the comparison and
## the `:take` band are untouched, and `boost d%d %s resolves binary` derives its
## expectation from the live key and passed throughout. What moved is WHEN the
## clock advances, which is the whole point of the slice — and it is separately
## asserted by "a failed lift costs no slot yet".
##
## The literal still guards what it always guarded: a changed key format, a
## changed chance formula, an observably inverted comparison, or a shifted take
## band. It is re-pinned rather than deleted for that reason.
const BOOST_FROZEN_PATTERN := "101111001000011101111111111101101111111110111101"

## A run standing in Spenard at the start of a day with money in hand.
func _frozen_ready(gs: Node, cash: int = 5000) -> void:
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 9
	gs.time_slots_today = 0
	gs.time_slot = "MORNING"
	gs.current_district_id = "north_star_lot"
	gs.cash = cash
	gs.heat = 0.0

## The first behavioural coverage Boost has ever had.
##
## The rule being frozen is that Boost is BINARY. Canon's `resolveBoostAttempt`
## (game-core.js:2248) is a plain `roll < chance`, and the tiered resolver
## deliberately does not touch it — a blown lift is a scene handed to the
## encounter engine, which is what FS-003 is about to build. If a later slice
## routes Boost through the resolver by reflex, this is what says so.
func _check_boost_behavior(gs: Node, gm: Node) -> void:
	var rng := get_node("/root/RngManager")
	var boost: RefCounted = gm.system("boost") as RefCounted
	if boost == null:
		_fail("frozen boost", "no boost system registered")
		return

	# The binary rule, derived rather than asserted: the outcome must equal the
	# keyed roll against the computed chance, at every target, on many days.
	# Nothing here re-implements the chance — it is read off the system.
	var checked := 0
	var wins := 0
	var outcomes := ""
	for day in range(1, 25):
		_frozen_ready(gs)
		gs.day = day
		for target in gs.boost_targets:
			var t: Dictionary = target
			if str(t["area"]) != gs.current_district_id or int(t["tier"]) > gs.boost_tier:
				continue
			var key := "boost:%d:%d:%s" % [gs.day, gs.time_slots_today, str(t["id"])]
			var expected: bool = rng.seeded_random(gs.run_seed, key) < boost.chance_for(t)
			var before_cash: int = gs.cash
			# Through dispatch, not handle(): a lift marks criminal activity on
			# Curtis, and his mutators refuse outside a dispatch. Calling the
			# system directly would exercise a stack the game never produces —
			# and would quietly skip the very write being frozen.
			_expect_true("boost d%d %s dispatches" % [day, str(t["id"])],
				gm.dispatch("boost", {"target_id": str(t["id"])}))
			# FS-003.7: a failed lift no longer ends the action — it opens a
			# blocking Caught chain and waits. This sweep is measuring the
			# INITIAL binary roll, which happens before any of that, so the
			# chain is cleared rather than resolved: resolving would apply
			# injury, Heat and a store ban, and a ban would refuse the next
			# day's attempt on the same target and silently shorten the sweep.
			#
			# Written as state cleanup, which is the "focused tests" exception,
			# and deliberately NOT as a dispatch — the encounter's own effects
			# are covered in the Caught section, not here.
			gs.active_consequence = {}
			# The outcome read off state rather than a returned dictionary,
			# which is the honest version of the question anyway: a win is a win
			# because the money moved.
			var take: int = gs.cash - before_cash
			var won: bool = take > 0
			outcomes += "1" if won else "0"
			_expect_true("boost d%d %s resolves binary" % [day, str(t["id"])],
				won == expected)
			checked += 1
			if won:
				wins += 1
				var band: Array = t["take"]
				_expect_true("boost d%d %s take is in band" % [day, str(t["id"])],
					take >= int(band[0]) and take <= int(band[1]))
				# The take is the keyed value, not just a number in range.
				_expect_int("boost d%d %s take is the keyed value" % [day, str(t["id"])],
					take, rng.seeded_int_range(gs.run_seed, key + ":take",
						int(band[0]), int(band[1])))
			else:
				_expect_int("boost d%d %s pays nothing on a miss" % [day, str(t["id"])],
					gs.cash, before_cash)
	# A sweep that never wins or never loses would agree with a broken rule.
	_expect_true("boost sweep saw both outcomes", wins > 0 and wins < checked)
	_expect_true("boost sweep was substantial", checked >= 20)
	# And the pattern itself, pinned as a literal.
	#
	# The comparison above derives its expectation with the same `<` the system
	# uses, which makes it a tautology against an inverted operator — sabotaging
	# `<` to `<=` changed both sides and the check stayed green. The literal is
	# what actually holds the rule: it moves if the key changes, if the chance
	# formula changes, if the comparison inverts observably, or if the take band
	# shifts. (`<` versus `<=` alone is measure-zero against a hash — no roll
	# ever equals the chance exactly — so it is not separately observable, and
	# claiming to test it would be the tautology again in a different costume.)
	_expect_str("boost outcome pattern is frozen", outcomes, BOOST_FROZEN_PATTERN)

	# Every lift is criminal activity, win or lose. It is what stops Curtis's
	# quiet streak bleeding his awareness back down, and nothing asserted it
	# before this build.
	for expect_win in [true, false]:
		var found := false
		for day in range(1, 30):
			_frozen_ready(gs)
			gs.day = day
			gs.curtis_last_criminal_day = -1
			var cash_mark: int = gs.cash
			if not gm.dispatch("boost", {"target_id": "night_owl"}):
				continue
			if (gs.cash > cash_mark) != expect_win:
				continue
			found = true
			_expect_int("boost marks criminal activity on a %s" % ("win" if expect_win else "miss"),
				gs.curtis_last_criminal_day, gs.day)
			break
		_expect_true("boost criminal-marking case %s was reachable" % str(expect_win), found)

	# That the outcome equals the single keyed roll, across the whole sweep
	# above, IS the statement that Boost is binary — a resolver-driven Boost
	# would disagree with that roll the moment advantage or immunity applied.
	# Sniffing the result dictionary for tier names would be a weaker claim
	# about the same thing, so it is not made.

	# Technique climbs on a win and only on a win.
	_frozen_ready(gs)
	var technique_before: int = gs.boost_technique
	var cash_before_tech: int = gs.cash
	gm.dispatch("boost", {"target_id": "night_owl"})
	var tech_won: bool = gs.cash > cash_before_tech
	_expect_int("boost technique moves only on success",
		gs.boost_technique, technique_before + (1 if tech_won else 0))

	# One go per target per day, and the gate is per TARGET rather than global.
	_frozen_ready(gs)
	gm.dispatch("boost", {"target_id": "night_owl"})
	_expect_str("boost refuses the same room twice in a day",
		boost.blocker("night_owl"), "You've already been in today.")
	_expect_str("boost still allows a different room",
		boost.blocker("spenard_fuel"), "")
	_expect_true("boost repeat is refused at the system level",
		not gm.dispatch("boost", {"target_id": "night_owl"}))

	# A lift is exactly one slot — and FS-003.7 splits that claim in two.
	#
	# A SUCCESSFUL lift still settles immediately. A FAILED one does not: TI-003
	# §11 keeps its slot unsettled until the Caught chain reaches Continue,
	# because a blown lift must not cost the player time before they have
	# answered for it. Both halves are asserted, and the day is derived rather
	# than assumed so neither can be measuring the branch it did not intend.
	var settle_success_day := -1
	var settle_miss_day := -1
	for day in range(1, 40):
		_frozen_ready(gs)
		gs.day = day
		var cash_mark: int = gs.cash
		var slot_before: int = gs.time_slots_today
		if not gm.dispatch("boost", {"target_id": "night_owl"}):
			continue
		var won: bool = gs.cash > cash_mark
		if won and settle_success_day < 0:
			settle_success_day = day
			_expect_int("a successful lift costs exactly one slot",
				gs.time_slots_today, slot_before + 1)
			_expect_true("a successful lift opens no chain",
				(gs.active_consequence as Dictionary).is_empty())
		elif not won and settle_miss_day < 0:
			settle_miss_day = day
			_expect_int("a failed lift costs no slot yet",
				gs.time_slots_today, slot_before)
			# "Nothing changed" is only meaningful alongside "and the thing that
			# should have happened did": the chain has to be open, or a boost
			# that silently did nothing would pass this too.
			_expect_true("a failed lift opens a Caught chain",
				not (gs.active_consequence as Dictionary).is_empty())
			_expect_str("the chain it opens is boost_caught",
				str((gs.active_consequence as Dictionary).get("chain_kind", "")),
				"boost_caught")
			gs.active_consequence = {}
		if settle_success_day >= 0 and settle_miss_day >= 0:
			break
	_expect_true("the slot probe found a success", settle_success_day >= 0)
	_expect_true("the slot probe found a miss", settle_miss_day >= 0)

	# Tier promotion: technique alone opens tier 2; tier 3 also needs somebody
	# who can be field-assigned, and that gate is the one FS-003 must not lose.
	_frozen_ready(gs)
	gs.boost_technique = gs.BOOST_TIER2_TECHNIQUE
	boost._update_tier()
	_expect_int("boost reaches tier 2 on technique", gs.boost_tier, 2)
	gs.boost_technique = gs.BOOST_TIER3_TECHNIQUE
	boost._update_tier()
	_expect_int("boost tier 3 needs field crew", gs.boost_tier, 2)
	gs.crew_records["eli"] = {
		"recruited": true, "status": "active", "loyalty": 5, "tier": 1,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1, "proofs": {},
	}
	boost._update_tier()
	_expect_int("boost reaches tier 3 with field crew", gs.boost_tier, 3)
	_expect_true("boost tier 3 gate is has_field_crew",
		(gm.system("crew") as RefCounted).has_field_crew())

	# Tier 3 pays in merchandise, not cash — the fence is the only way out.
	_frozen_ready(gs)
	gs.boost_tier = 3
	gs.crew_records["eli"] = {
		"recruited": true, "status": "active", "loyalty": 5, "tier": 1,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1, "proofs": {},
	}
	var tier3_id := ""
	for target in gs.boost_targets:
		if int((target as Dictionary)["tier"]) == 3 \
				and str((target as Dictionary)["area"]) == gs.current_district_id:
			tier3_id = str((target as Dictionary)["id"])
			break
	if tier3_id.is_empty():
		_fail("frozen boost", "no tier 3 target in Spenard")
	else:
		var cash_before: int = gs.cash
		var merch_before: int = gs.boost_merchandise
		gm.dispatch("boost", {"target_id": tier3_id})
		if gs.boost_merchandise > merch_before:
			_expect_int("boost tier 3 pays merchandise not cash", gs.cash, cash_before)
			_expect_true("boost tier 3 banks the take as merchandise",
				gs.boost_merchandise - merch_before > 0)

## The fence, which had not one assertion before this build.
func _check_boost_fence(gs: Node, gm: Node) -> void:
	var exposure := get_node("/root/Exposure")
	var boost: RefCounted = gm.system("boost") as RefCounted
	if boost == null:
		return

	# Canon boostFenceRate: 0.40 + standing*0.05, then 0.55 from 3, 0.60 from 5.
	for entry in [[0, 0.40], [1, 0.45], [2, 0.50], [3, 0.55], [4, 0.55], [5, 0.60], [9, 0.60]]:
		_frozen_ready(gs)
		gs.boost_fence_standing = int(entry[0])
		_expect_float("fence rate at standing %d" % int(entry[0]),
			boost.fence_rate(), float(entry[1]))

	# Nothing to move is a refusal, not a zero payout.
	_frozen_ready(gs)
	gs.boost_merchandise = 0
	_expect_true("fence refuses an empty lot", not gm.dispatch("fence_goods", {}))
	_expect_str("fence says why", boost.handle("fence_goods", {}).get("reason", ""),
		"Nothing to move.")

	# The payout is the rate applied to the whole lot, rounded — and the lot is
	# cleared, the standing climbs, and Slide keeps it off the street.
	_frozen_ready(gs)
	gs.boost_merchandise = 500
	gs.boost_fence_standing = 2
	for npc_id in exposure.npc_ids():
		exposure.ledger_of(str(npc_id)).clear()
	gs.observation_queue.clear()
	var cash_before: int = gs.cash
	_expect_true("fence moves the lot", gm.dispatch("fence_goods", {}))
	_expect_int("fence pays rate times lot", gs.cash - cash_before, 250)
	_expect_int("fence credits the cash", gs.cash, cash_before + 250)
	_expect_int("fence clears the merchandise", gs.boost_merchandise, 0)
	_expect_int("fence raises the standing", gs.boost_fence_standing, 3)

	# Slide is discreet: household only, and never the street or the network.
	var household := 0
	var elsewhere := 0
	for npc_id in exposure.npc_ids():
		for row in exposure.ledger_of(str(npc_id)):
			if str(row["event"]) == "fenced_goods":
				if str(row["source"]) == "household":
					household += 1
				else:
					elsewhere += 1
	for entry in gs.observation_queue:
		if str((entry["spec"] as Dictionary).get("event", "")) == "fenced_goods":
			elsewhere += 1
	_expect_true("fence tells the household", household > 0)
	_expect_int("fence tells nobody else", elsewhere, 0)

	# Standing is capped, so the rate cannot climb forever.
	_frozen_ready(gs)
	gs.boost_fence_standing = 5
	gs.boost_merchandise = 100
	gm.dispatch("fence_goods", {})
	_expect_int("fence standing clamps at 5", gs.boost_fence_standing, 5)

## The heat WRITE path, as opposed to the per-tier figures already pinned.
func _check_heat_write_path(gs: Node, gm: Node) -> void:
	var stickup: RefCounted = gm.system("stickup") as RefCounted
	var boost: RefCounted = gm.system("boost") as RefCounted
	var crew: RefCounted = gm.system("crew") as RefCounted
	if stickup == null or boost == null or crew == null:
		return

	# Fractional, and it must stay that way. Rounding here is what made
	# Deshawn's reduction invisible on small amounts — the bug the comment in
	# `_apply_heat` was written about.
	_frozen_ready(gs)
	gs.crew_records["deshawn"] = {
		"recruited": true, "status": "active", "loyalty": 5, "tier": 1,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1, "proofs": {},
	}
	_expect_float("deshawn multiplier at rank 1", crew.heat_multiplier(), 0.80)
	var applied: float = stickup._apply_heat(2.0)
	_expect_float("heat applies the multiplier fractionally", applied, 1.6)
	_expect_float("heat lands fractionally on state", gs.heat, 1.6)
	_expect_true("heat is a float on state", gs.heat is float)

	# The multiplier is read fresh. A cached one would keep paying the old rate
	# after a promotion or after he walks.
	gs.crew_records["deshawn"]["tier"] = 3
	_expect_float("multiplier re-read after promotion", crew.heat_multiplier(), 0.40)
	gs.heat = 0.0
	_expect_float("heat uses the new multiplier", stickup._apply_heat(2.0), 0.8)
	gs.crew_records.erase("deshawn")
	gs.heat = 0.0
	_expect_float("heat is unmodified with him gone", stickup._apply_heat(2.0), 2.0)

	# Clamped at both ends of the 0-15 scale.
	_frozen_ready(gs)
	gs.heat = 14.5
	stickup._apply_heat(10.0)
	_expect_float("heat clamps at the ceiling", gs.heat, float(gs.heat_max))
	_expect_int("the ceiling is canon's 15", gs.heat_max, 15)
	gs.heat = 0.0
	stickup._apply_heat(0.0)
	_expect_float("zero heat is a no-op", gs.heat, 0.0)
	stickup._apply_heat(-5.0)
	_expect_float("negative heat cannot drain the meter", gs.heat, 0.0)

	# Boost's own path. FS-003.1 froze this at the port's 1.0 and named it a
	# known divergence; FS-003.2 widened `_apply_heat` to float and restored
	# canon's 0.5 / 1 / 2 (game-core.js:2260).
	#
	# **The FS-003.1 assertion was wrong about what it measured.** It pinned
	# "tier 1 heat" on a fixed probe day that happens to be a MISS — and a miss
	# costs 1.0 at any tier — so it read 1.0 for the wrong reason and would have
	# stayed green even if tier-1 success heat had been correct all along. The
	# freeze it claimed to hold never held anything.
	#
	# So the day is DERIVED here: walk until the lift lands, then assert. Both
	# branches are covered, and each one says which branch it is.
	var success_day := -1
	var miss_day := -1
	for day in range(1, 40):
		_frozen_ready(gs)
		gs.day = day
		gs.heat = 0.0
		var cash_mark: int = gs.cash
		if not gm.dispatch("boost", {"target_id": "night_owl"}):
			continue
		if gs.cash > cash_mark and success_day < 0:
			success_day = day
			_expect_float("boost tier 1 SUCCESS heat matches canon's 0.5", gs.heat, 0.5)
		elif gs.cash == cash_mark and miss_day < 0:
			miss_day = day
			# WAS 1.0, and FS-003.7 removes it deliberately. TI-003 §11: "The
			# failed branch removes its current immediate terminal Heat/log/time
			# behavior because Caught now owns those consequence effects", and
			# regression #3 is "Failed Boost keeps its old immediate Heat and
			# then adds Caught Heat" — the double this assertion now prevents.
			#
			# The Heat a blown lift ends up costing is authored per response and
			# per tier in data/consequence_rules.gd, and is asserted there.
			_expect_float("a failed lift applies no immediate heat", gs.heat, 0.0)
			_expect_true("a failed lift opens the chain that owns its heat",
				not (gs.active_consequence as Dictionary).is_empty())
			gs.active_consequence = {}
		if success_day >= 0 and miss_day >= 0:
			break
	_expect_true("boost heat probe found a success", success_day >= 0)
	_expect_true("boost heat probe found a miss", miss_day >= 0)

	# The whole curve through the real writer, so a later edit cannot correct
	# one tier and drift another. Canon: 0.5 / 1 / 2.
	for entry in [[1, 0.5], [2, 1.0], [3, 2.0]]:
		_frozen_ready(gs)
		gs.heat = 0.0
		_expect_float("boost tier %d heat is canon's %.1f" % [int(entry[0]), float(entry[1])],
			boost._apply_heat(float(entry[1])), float(entry[1]))
	# And the signature is genuinely float now — an int parameter would have
	# truncated canon's 0.5 to nothing, which is what forced the divergence.
	_frozen_ready(gs)
	gs.heat = 0.0
	boost._apply_heat(0.5)
	_expect_float("boost heat accepts a fractional amount", gs.heat, 0.5)

## Cash discipline: a refused action must leave the wallet exactly as it was.
##
## This was implicit in every flow and asserted in none, which is the shape of
## thing that survives a refactor and then does not.
func _check_cash_discipline(gs: Node, gm: Node) -> void:
	var stickup: RefCounted = gm.system("stickup") as RefCounted
	var boost: RefCounted = gm.system("boost") as RefCounted
	var lst: RefCounted = gm.system("list") as RefCounted
	if stickup == null or boost == null or lst == null:
		return

	# A blown stickup pays nothing, at either failing tier.
	var seen_failure := false
	for day in range(1, 40):
		_frozen_ready(gs)
		gs.day = day
		gs.stick_daily_count = 0
		var before: int = gs.cash
		var rep_before: int = gs.stick_rep
		if gm.dispatch("stickup", {"target_id": "washgo_regular"}) \
				and gs.stick_rep == rep_before:
			# Rep only moves on a success, so an unchanged rep after a
			# successful dispatch is a failed robbery.
			seen_failure = true
			_expect_int("stickup failure pays nothing on d%d" % day, gs.cash, before)
	_expect_true("cash discipline saw a failed stickup", seen_failure)

	# Every blocker refuses BEFORE touching the wallet.
	_frozen_ready(gs, 0)
	var broke: int = gs.cash
	_expect_true("a buy with no cash is refused",
		not gm.dispatch("list_buy", {"item_id": "space_heater"}))
	_expect_int("a refused buy spends nothing", gs.cash, broke)

	_frozen_ready(gs)
	gs.current_district_id = "downtown"
	var wrong_place: int = gs.cash
	_expect_true("a stickup in the wrong district is refused",
		not gm.dispatch("stickup", {"target_id": "washgo_regular"}))
	_expect_int("a refused stickup spends nothing", gs.cash, wrong_place)

	_frozen_ready(gs)
	var capacity: int = lst.capacity()
	for i in capacity:
		gs.list_holdings.append({"item_id": "space_heater", "bought_day": 1, "source": "player"})
	var full_cash: int = gs.cash
	_expect_true("a buy with no room is refused",
		not gm.dispatch("list_buy", {"item_id": "space_heater"}))
	_expect_int("a refused buy with no room spends nothing", gs.cash, full_cash)

	# The daily cap on stickups refuses without charging.
	_frozen_ready(gs)
	gs.stick_daily_count = gs.STICK_DAILY_CAP
	var capped_cash: int = gs.cash
	_expect_true("a third stickup in a day is refused",
		not gm.dispatch("stickup", {"target_id": "washgo_regular"}))
	_expect_int("a capped stickup spends nothing", gs.cash, capped_cash)

	# And the daily count clears on the day cross rather than drifting.
	_frozen_ready(gs)
	gs.stick_daily_count = 2
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	gm.dispatch("advance_time", {})
	_expect_int("stickup daily count resets on the day cross", gs.stick_daily_count, 0)

## The dispatch-ownership guard, which shipped with no test at all.
##
## The cleanup pass made Exposure and Curtis refuse their persisted mutators
## outside a `GameManager.dispatch()`. That guard is the reason a screen cannot
## quietly write an observation while rendering — and nothing verified it, so a
## later slice could have removed it and gone green.
func _check_dispatch_ownership(gs: Node, gm: Node) -> void:
	var exposure := get_node("/root/Exposure")
	var curtis := get_node("/root/Curtis")
	_frozen_ready(gs)
	_expect_true("game manager reports when it is dispatching",
		gm.has_method("is_dispatching"))
	_expect_true("nothing is dispatching at rest", not gm.is_dispatching())

	# Outside a dispatch the mutator is refused: the ledger does not grow.
	for npc_id in exposure.npc_ids():
		exposure.ledger_of(str(npc_id)).clear()
	exposure.record_observation("yalonda", {
		"type": "financial", "event": "rent_paid", "source": "household"})
	_expect_int("record_observation outside a dispatch writes nothing",
		(exposure.ledger_of("yalonda") as Array).size(), 0)
	exposure.broadcast_observation({
		"type": "violence", "event": "street_fight", "channel": "neighborhood"})
	_expect_int("broadcast_observation outside a dispatch queues nothing",
		gs.observation_queue.size(), 0)

	# Inside one, the same call lands. Driven through a real action so the guard
	# sees the stack the game actually produces.
	_frozen_ready(gs)
	for npc_id in exposure.npc_ids():
		exposure.ledger_of(str(npc_id)).clear()
	gs.observation_queue.clear()
	var wrote := false
	gm.dispatch("stickup", {"target_id": "washgo_regular"})
	for npc_id in exposure.npc_ids():
		if not (exposure.ledger_of(str(npc_id)) as Array).is_empty():
			wrote = true
	_expect_true("observations land from inside a dispatch",
		wrote or not gs.observation_queue.is_empty())
	_expect_true("dispatching is over once the action returns", not gm.is_dispatching())

## FS-003.2 — the night sequence, declared and traced.
##
## Before this the settlement order was whatever order five `day_crossed.connect()`
## calls ran in during GameManager's `_ready()`. That is an ordering contract
## expressed as a side effect of construction order: invisible in review,
## untestable, and silently rewritten by moving a line in an unrelated file.
##
## TI-003 §9 order, asserted as a literal sequence. FS-003.3 through .12 hang
## Pressure, Booking, Retaliation and Financial Pressure on these hooks, so the
## order stops being an implementation detail and becomes the interface.
const LIFECYCLE_EXPECTED_TRACE: Array[String] = [
	"PRE_SETTLE",
	"SETTLE:crew", "SETTLE:territory", "SETTLE:shark", "SETTLE:jobs", "SETTLE:obligations",
	"POST_SETTLE",
	"INCREMENT",
	"MARKET:evolve", "MARKET:day_crossed",
	"DAY_START",
]

func _check_day_lifecycle_order() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var lifecycle: RefCounted = gm.system("day_lifecycle") as RefCounted
	if lifecycle == null:
		_fail("lifecycle order", "no day_lifecycle system registered")
		return
	_check_lifecycle_trace(gs, gm, lifecycle)
	_check_lifecycle_settles_ending_day(gs, gm)
	_check_lifecycle_market_once(gs, gm, lifecycle)
	_check_lifecycle_legacy_listener(gs, gm)
	_check_lifecycle_hooks(gs, gm, lifecycle)
	_check_lifecycle_checkpoint(gs, gm)
	lifecycle.tracing = false
	gs.reset_to_new_game()

func _lifecycle_ready(gs: Node) -> void:
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 7
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	gs.cash = 5000

## The sequence itself, as a literal.
func _check_lifecycle_trace(gs: Node, gm: Node, lifecycle: RefCounted) -> void:
	_lifecycle_ready(gs)
	lifecycle.tracing = true
	_expect_true("lifecycle night dispatches", gm.dispatch("advance_time", {}))
	_expect_str("lifecycle phase order", str(lifecycle.trace), str(LIFECYCLE_EXPECTED_TRACE))

	# Every phase runs exactly once. A settler that got connected twice would
	# still produce the right ORDER while doing everything twice.
	var counts: Dictionary = {}
	for phase in lifecycle.trace:
		counts[phase] = int(counts.get(phase, 0)) + 1
	for phase in LIFECYCLE_EXPECTED_TRACE:
		_expect_int("lifecycle %s runs once" % phase, int(counts.get(phase, 0)), 1)

	# The declared order is the one the code walks, not a copy of it kept here.
	_expect_str("lifecycle settle order is declared",
		str(lifecycle.SETTLE_ORDER),
		str(["crew", "territory", "shark", "jobs", "obligations"]))
	for system_name in lifecycle.SETTLE_ORDER:
		var system: Object = gm.system(str(system_name))
		_expect_true("lifecycle settler %s exists" % str(system_name), system != null)
		_expect_true("lifecycle settler %s answers settle_night" % str(system_name),
			system != null and system.has_method("settle_night"))

	# A mid-day advance runs no part of the night.
	_lifecycle_ready(gs)
	gs.time_slots_today = 0
	lifecycle.trace.clear()
	gm.dispatch("advance_time", {})
	_expect_true("lifecycle stays out of a mid-day advance", lifecycle.trace.is_empty())
	lifecycle.tracing = false

## Settlement sees the day that ended, not the one that is starting.
func _check_lifecycle_settles_ending_day(gs: Node, gm: Node) -> void:
	# Rent falling due on the ending day must settle on that night. Deriving
	# `gs.day - 1` used to be what made this work, and only because the handler
	# happened to run after the increment.
	# Rent is not auto-deducted — reaching the due day without having paid it
	# records a MISS and rolls the period. What is being checked is that the
	# settlement saw day 7, not day 8.
	_lifecycle_ready(gs)
	gs.rent_due_day = 7
	var missed_before: int = gs.rent_missed
	var due_before: int = gs.rent_due_day
	gm.dispatch("advance_time", {})
	_expect_int("lifecycle advanced the day", gs.day, 8)
	_expect_int("rent due on the ending day settled that night",
		gs.rent_missed, missed_before + 1)
	_expect_true("rent period rolled forward", gs.rent_due_day > due_before)

	# And rent due TOMORROW is not settled tonight — the boundary in the other
	# direction, which is what would break if settlement read the new day.
	_lifecycle_ready(gs)
	gs.rent_due_day = 8
	var untouched: int = gs.rent_missed
	gm.dispatch("advance_time", {})
	_expect_int("rent due on the new day is not settled tonight",
		gs.rent_missed, untouched)

	# Attendance is judged on the ending day: a shift worked on day 7 is not a
	# missed day when night 7 settles.
	_lifecycle_ready(gs)
	gs.active_job_id = "wash_go"
	gs.job_records["wash_go"] = {
		"xp": 0.0, "rank": 0, "last_worked_day": 7, "hired_day": 1,
	}
	gs.job_missed["wash_go"] = 0
	gm.dispatch("advance_time", {})
	_expect_int("a shift worked on the ending day is not a miss",
		int(gs.job_missed.get("wash_go", -1)), 0)

	# And a day genuinely skipped does count.
	_lifecycle_ready(gs)
	gs.active_job_id = "wash_go"
	gs.job_records["wash_go"] = {
		"xp": 0.0, "rank": 0, "last_worked_day": 5, "hired_day": 1,
	}
	gs.job_missed["wash_go"] = 0
	gm.dispatch("advance_time", {})
	_expect_int("a skipped ending day counts as a miss",
		int(gs.job_missed.get("wash_go", -1)), 1)

	# Crew's wage clock is preserved exactly across the refactor — it still
	# settles against the NEW day, which is this port's long-standing
	# divergence from canon and is named at the call site rather than changed.
	_lifecycle_ready(gs)
	gs.crew_records["eli"] = {
		"recruited": true, "status": "active", "loyalty": 5, "tier": 1,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1, "proofs": {},
	}
	gs.cash = 0
	gm.dispatch("advance_time", {})
	_expect_int("crew stamps the wage sentinel on the settling day",
		int(gs.crew_records["eli"]["wage_missed_since"]), 8)

	# Shark's note clock is preserved the same way, and needs its own check —
	# claiming a divergence is preserved is worth nothing if nothing asserts it.
	# Settling night 7 uses day 8, so a note due on 8 comes due tonight and a
	# note due on 9 does not. Shifting either way breaks exactly one of these.
	_lifecycle_ready(gs)
	gs.shark_loans = [{
		"id": 1, "borrower_id": _riskiest_borrower(gs), "amount": 100, "term": 7,
		"status": "active", "opened_day": 1, "due_day": 8,
	}]
	gm.dispatch("advance_time", {})
	_expect_true("a note due on the settling day comes due tonight",
		str((gs.shark_loans[0] as Dictionary)["status"]) != "active")

	_lifecycle_ready(gs)
	gs.shark_loans = [{
		"id": 1, "borrower_id": _riskiest_borrower(gs), "amount": 100, "term": 7,
		"status": "active", "opened_day": 1, "due_day": 9,
	}]
	gm.dispatch("advance_time", {})
	_expect_str("a note due after the settling day is left alone",
		str((gs.shark_loans[0] as Dictionary)["status"]), "active")

## The market walks once. Proven by re-walking the same state independently.
func _check_lifecycle_market_once(gs: Node, gm: Node, lifecycle: RefCounted) -> void:
	var economy: RefCounted = gm.system("economy") as RefCounted
	_lifecycle_ready(gs)
	var cursor_before: int = gs.rng_state
	gm.dispatch("advance_time", {})
	var cursor_after_night: int = gs.rng_state
	_expect_true("the night moved the market cursor", cursor_after_night != cursor_before)

	# One evolve from the same starting cursor must land on the same value. Two
	# would not — which is the whole assertion.
	_lifecycle_ready(gs)
	gs.rng_state = cursor_before
	economy.evolve()
	_expect_int("the night evolves the market exactly once",
		gs.rng_state, cursor_after_night)

	# And settlement itself draws nothing from the market stream.
	#
	# Measured from inside a POST_SETTLE hook, which is the exact moment after
	# every settler has run and before the market walk — and which runs on the
	# real dispatch path. Calling the settlers directly would have measured the
	# right thing on a stack the game never produces, and would have tripped the
	# dispatch-ownership guard on the two that broadcast.
	_lifecycle_ready(gs)
	var cursor_at_start: int = gs.rng_state
	var cursor_after_settle: Array = []
	var probe := func(_ended: int) -> void: cursor_after_settle.append(gs.rng_state)
	lifecycle.add_post_settle_hook(probe)
	gm.dispatch("advance_time", {})
	lifecycle.clear_hooks()
	_expect_int("the settle probe ran", cursor_after_settle.size(), 1)
	if cursor_after_settle.size() == 1:
		_expect_int("night settlement consumes no market RNG",
			int(cursor_after_settle[0]), cursor_at_start)

## Anything still on `day_crossed` fires once, and sees the new day.
func _check_lifecycle_legacy_listener(gs: Node, gm: Node) -> void:
	_lifecycle_ready(gs)
	var seen: Array = []
	var listener := func() -> void: seen.append(gs.day)
	gs.day_crossed.connect(listener)
	gm.dispatch("advance_time", {})
	gs.day_crossed.disconnect(listener)
	_expect_int("a legacy day_crossed listener fires once", seen.size(), 1)
	if seen.size() == 1:
		# The reason day_crossed stays in the MARKET phase: everything still on
		# it was written expecting the incremented clock.
		_expect_int("a legacy listener sees the NEW day", int(seen[0]), 8)

	# day_ending carries the ending day, with the clock still reading it.
	_lifecycle_ready(gs)
	var ending: Array = []
	var on_ending := func(ended: int) -> void: ending.append([ended, gs.day])
	gs.day_ending.connect(on_ending)
	gm.dispatch("advance_time", {})
	gs.day_ending.disconnect(on_ending)
	_expect_int("day_ending fires once", ending.size(), 1)
	if ending.size() == 1:
		_expect_int("day_ending carries the ending day", int((ending[0] as Array)[0]), 7)
		_expect_int("day_ending fires before the increment", int((ending[0] as Array)[1]), 7)

## The hooks FS-003.3+ will use. Callables in a declared array, not signals —
## signals have exactly the ordering problem this file removes.
func _check_lifecycle_hooks(gs: Node, gm: Node, lifecycle: RefCounted) -> void:
	_lifecycle_ready(gs)
	_expect_true("post-settle hooks are an array of callables",
		lifecycle.post_settle_hooks is Array)
	_expect_true("day-start hooks are an array of callables",
		lifecycle.day_start_hooks is Array)
	_expect_true("post-settle hooks ship empty", lifecycle.post_settle_hooks.is_empty())
	_expect_true("day-start hooks ship empty", lifecycle.day_start_hooks.is_empty())

	# A registered hook runs, receives the right day, and lands in the right
	# place in the sequence.
	var order: Array = []
	var post_a := func(ended: int) -> void: order.append("post_a:%d:%d" % [ended, gs.day])
	var post_b := func(ended: int) -> void: order.append("post_b:%d" % ended)
	var start_a := func(new_day: int) -> void: order.append("start_a:%d:%d" % [new_day, gs.day])
	lifecycle.add_post_settle_hook(post_a)
	lifecycle.add_post_settle_hook(post_b)
	lifecycle.add_day_start_hook(start_a)
	lifecycle.tracing = true
	gm.dispatch("advance_time", {})
	lifecycle.tracing = false
	lifecycle.clear_hooks()

	# Index order, which is the point of using an array.
	_expect_str("hooks run in declared index order", str(order),
		str(["post_a:7:7", "post_b:7", "start_a:8:8"]))
	# POST_SETTLE runs before the clock moves; DAY_START after it.
	_expect_true("post-settle hooks run on the ending day", "post_a:7:7" in order)
	_expect_true("day-start hooks run on the new day", "start_a:8:8" in order)
	# And the trace still reports the phases they ran inside.
	_expect_true("the traced sequence is unchanged by hooks",
		str(lifecycle.trace) == str(LIFECYCLE_EXPECTED_TRACE))

## Two paths to the same night must produce the same state.
func _check_lifecycle_checkpoint(gs: Node, gm: Node) -> void:
	var saves := get_node("/root/SaveSystem")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	# Save at AFTERNOON, walk to the night, remember where it landed.
	_lifecycle_ready(gs)
	gs.time_slots_today = 1
	gs.time_slot = "AFTERNOON"
	gs.crew_records["eli"] = {
		"recruited": true, "status": "active", "loyalty": 5, "tier": 1,
		"wage_due": 0, "wage_missed_since": -1, "recruited_day": 1, "proofs": {},
	}
	gs.rent_due_day = 7
	saves.save_run()
	var checkpoint := ""
	var snapshot := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
	if snapshot != null:
		checkpoint = snapshot.get_as_text()
		snapshot.close()

	for _slot in 3:
		gm.dispatch("advance_time", {})
	var direct := {
		"day": gs.day, "slot": gs.time_slots_today, "cash": gs.cash,
		"heat": gs.heat, "cursor": gs.rng_state,
		"wage_due": int(gs.crew_records["eli"]["wage_due"]),
		"rent_due": gs.rent_due_day,
	}

	# Rewind to the checkpoint and walk it again.
	var rewind := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if rewind != null:
		rewind.store_string(checkpoint)
		rewind.close()
	_expect_true("checkpoint reloads", saves.load_run())
	_expect_int("checkpoint restored the slot", gs.time_slots_today, 1)
	for _slot in 3:
		gm.dispatch("advance_time", {})

	_expect_int("replayed night lands on the same day", gs.day, int(direct["day"]))
	_expect_int("replayed night lands on the same slot",
		gs.time_slots_today, int(direct["slot"]))
	_expect_int("replayed night lands on the same cash", gs.cash, int(direct["cash"]))
	_expect_float("replayed night lands on the same heat", gs.heat, float(direct["heat"]))
	_expect_int("replayed night lands on the same market cursor",
		gs.rng_state, int(direct["cursor"]))
	_expect_int("replayed night settles the same wage",
		int(gs.crew_records["eli"]["wage_due"]), int(direct["wage_due"]))
	_expect_int("replayed night settles the same rent",
		gs.rent_due_day, int(direct["rent_due"]))

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## FS-003.3 — the two shared mutation owners.
##
## ## What this section deliberately does NOT re-cover
##
## Every source's PAYOUT and SPEND figure is already pinned elsewhere and is not
## re-asserted here:
##
##   - stickup take bands and per-tier heat — `_check_stickup_tiers`
##   - boost take, fence rate and tier heat — `_check_boost_behavior` /
##     `_check_boost_fence` (FS-003.1)
##   - the heat WRITE path's fractional/clamp/multiplier behaviour —
##     `_check_heat_write_path` (FS-003.1)
##   - refused actions leaving cash alone — `_check_cash_discipline` (FS-003.1)
##   - job/907List/recovery/obligation amounts — the FS-001 fixture sections
##
## Those are the regression net that lets this migration claim it changed
## nothing, and duplicating them here would inflate the count while protecting
## exactly what they already protect.
##
## What is new, and only new:
##
##   1. the direct-writer audits (nothing could have caught a new raw write);
##   2. provenance — which bucket each source's money lands in;
##   3. the two spend policies and the invariant that ties buckets to the total;
##   4. Financial Pressure's gain side;
##   5. Deshawn applied exactly once, across ranks 1-3 AND above the curve;
##   6. relief bypassing the gain multipliers;
##   7. neither owner touching the market RNG stream.
func _check_wallet_and_heat() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var wallet: RefCounted = gm.system("wallet") as RefCounted
	var heat: RefCounted = gm.system("heat") as RefCounted
	if wallet == null or heat == null:
		_fail("wallet/heat", "owners not registered")
		return
	_check_direct_writer_audit()
	_check_deshawn_single_application_audit()
	_check_wallet_policies(gs, wallet)
	_check_wallet_financial_pressure(gs, wallet)
	_check_wallet_reconcile(gs, wallet)
	_check_wallet_legacy_classification(gs, wallet)
	_check_heat_api(gs, gm, heat)
	_check_heat_district_table(heat)
	_check_heat_district_scaling_inert(gs, heat)
	_check_source_provenance(gs, gm)
	_check_owner_rng_non_drift(gs, gm, wallet, heat)
	gs.reset_to_new_game()

# --- the audits -------------------------------------------------------------

## Directories the audit walks. `tests/` is excluded on purpose: a focused test
## setting `gs.cash` to stage a scenario is one of TI-003 §6's named exceptions.
const AUDIT_ROOTS: Array[String] = [
	"res://systems", "res://autoload", "res://ui",
]

## The only two files allowed to write the fields they own.
const CASH_WRITE_OWNERS: Array[String] = ["res://systems/wallet.gd"]
const HEAT_WRITE_OWNERS: Array[String] = ["res://systems/heat.gd"]

## TI-003 §6/§7: "Automated implementation checks should reject direct runtime
## Cash mutations outside WalletSystem" — and the same for Heat.
##
## This is the check that has to exist for the migration to STAY done. Every
## other check here proves the code is right today; this one is the only thing
## that notices when a later slice adds `gs.cash += payout` to a new surface,
## which is exactly how the twenty-one writers accumulated in the first place.
func _check_direct_writer_audit() -> void:
	var cash_offenders: Array = _scan_for_writes("cash", CASH_WRITE_OWNERS)
	var heat_offenders: Array = _scan_for_writes("heat", HEAT_WRITE_OWNERS)
	_expect_int("no direct gs.cash writers outside WalletSystem",
		cash_offenders.size(), 0)
	if not cash_offenders.is_empty():
		_fail("cash writer audit", ", ".join(cash_offenders))
	_expect_int("no direct gs.heat writers outside HeatSystem",
		heat_offenders.size(), 0)
	if not heat_offenders.is_empty():
		_fail("heat writer audit", ", ".join(heat_offenders))

	# The audit must be able to FAIL. A scanner that matches nothing reports a
	# clean codebase and a broken regex identically, and "0 offenders" is the
	# passing answer to both — so the matcher is run against text that is known
	# to contain each shape it hunts for.
	#
	# Not a tautology: these strings are written here by hand, in the form a
	# careless future edit would actually take, and the matcher is the shipped
	# one rather than a copy.
	var planted := [
		"\tgs.cash += payout",
		"\tgs.cash -= cost",
		"\tgs.cash = 0",
		"\tgs.heat = clampf(gs.heat + 1.0, 0.0, 15.0)",
		"\tgs.heat += 2.0",
	]
	for line in planted:
		var field: String = "cash" if "cash" in line else "heat"
		_expect_true("the writer audit detects `%s`" % line.strip_edges(),
			_line_writes_field(line, field))

	# And must NOT fire on the reads and lookalikes that are everywhere. A
	# scanner that flags `if gs.cash < cost` would be turned off within a week.
	var innocent := [
		"\tif gs.cash < cost:",
		"\t\t- gs.heat * 0.012",
		"\tvar owed: int = gs.cash",
		"\treturn gs.heat >= 10.0",
		"\t_expect_int(\"x\", gs.cash, 100)",
		"\tgs.cash_display_only = 1",
		"\tgs.heat_max = 15",
	]
	for line in innocent:
		var field: String = "cash" if "cash" in line else "heat"
		_expect_true("the writer audit ignores `%s`" % line.strip_edges(),
			not _line_writes_field(line, field))

## True when this line assigns to `gs.<field>`.
##
## Deliberately narrow: it matches the `gs.` handle every system uses, and the
## compound operators as well as plain `=`. `gs.heat_max = 15` must not match,
## which is why the field name has to be followed by whitespace-then-operator
## rather than by any character at all.
func _line_writes_field(line: String, field: String) -> bool:
	var code: String = line.split("#")[0]
	var needle := "gs.%s" % field
	var from: int = 0
	while true:
		var at: int = code.find(needle, from)
		if at < 0:
			return false
		from = at + needle.length()
		var rest: String = code.substr(from).strip_edges(true, false)
		if rest.begins_with("==") or rest.begins_with("!=") \
			or rest.begins_with("<=") or rest.begins_with(">="):
			continue
		if rest.begins_with("+=") or rest.begins_with("-=") \
			or rest.begins_with("*=") or rest.begins_with("/=") \
			or rest.begins_with("="):
			return true
	return false

func _scan_for_writes(field: String, owners: Array[String]) -> Array:
	var offenders: Array = []
	for root in AUDIT_ROOTS:
		for path in _gd_files_under(root):
			if path in owners:
				continue
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				continue
			var number: int = 0
			while not file.eof_reached():
				number += 1
				var line: String = file.get_line()
				if _line_writes_field(line, field):
					offenders.append("%s:%d" % [path, number])
			file.close()
	return offenders

func _gd_files_under(root: String) -> Array:
	var found: Array = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = "%s/%s" % [root, entry]
		if dir.current_is_dir():
			found.append_array(_gd_files_under(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found

## The acceptance criterion, made structural rather than behavioural.
##
## "Deshawn applies once" can be proven numerically (and is, below), but a
## numeric proof only covers the paths the test happens to walk. The stronger
## statement is that there is exactly ONE place in the codebase that can apply
## him at all — so a new surface cannot reintroduce the double by copying the
## helper that used to exist in two files.
##
## Allowed: crew.gd owns and defines it, heat.gd is the single consumer, and the
## crew SCREEN displays it as a number without applying anything.
const HEAT_MULTIPLIER_CALLERS: Array[String] = [
	"res://systems/crew.gd", "res://systems/heat.gd", "res://ui/screens/crew.gd",
]

func _check_deshawn_single_application_audit() -> void:
	var callers: Array = []
	for root in AUDIT_ROOTS:
		for path in _gd_files_under(root):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				continue
			while not file.eof_reached():
				var line: String = file.get_line()
				if "#" in line:
					line = line.split("#")[0]
				if "heat_multiplier(" in line and not path in callers:
					callers.append(path)
			file.close()
	callers.sort()
	var expected: Array = HEAT_MULTIPLIER_CALLERS.duplicate()
	expected.sort()
	_expect_str("heat_multiplier() has exactly one applying consumer",
		str(callers), str(expected))

# --- wallet -----------------------------------------------------------------

## Put the wallet in a known, balanced state. Writes the fields directly, which
## is the "focused tests" exception TI-003 §6 names — and writes all three
## together so the invariant is true before the check starts rather than after
## the first reconcile.
func _wallet_ready(gs: Node, dirty: int, clean: int) -> void:
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 9
	gs.time_slots_today = 0
	gs.time_slot = "MORNING"
	gs.current_district_id = "north_star_lot"
	gs.dirty_cash = dirty
	gs.clean_cash = clean
	gs.cash = dirty + clean
	gs.financial_pressure = 0
	gs.heat = 0.0

## TI-003 §6's two policies, as a matrix over the cases that distinguish them.
##
## Every row states the buckets before, the move, and all three numbers after.
## The `after` figures are written out rather than computed, so the check pins
## behaviour instead of re-deriving it.
func _check_wallet_policies(gs: Node, wallet: RefCounted) -> void:
	# --- credit, by provenance ---
	_wallet_ready(gs, 100, 200)
	var tx: Dictionary = wallet.credit(50, wallet.DIRTY, {"source_id": "t"})
	_expect_true("a dirty credit reports ok", bool(tx["ok"]))
	_expect_int("a dirty credit raises dirty", int(gs.dirty_cash), 150)
	_expect_int("a dirty credit leaves clean alone", int(gs.clean_cash), 200)
	_expect_int("a dirty credit raises the visible total", int(gs.cash), 350)
	_expect_int("a dirty credit reports the dirty side", int(tx["dirty_used"]), 50)

	_wallet_ready(gs, 100, 200)
	tx = wallet.credit(50, wallet.CLEAN, {"source_id": "t"})
	_expect_int("a clean credit raises clean", int(gs.clean_cash), 250)
	_expect_int("a clean credit leaves dirty alone", int(gs.dirty_cash), 100)
	_expect_int("a clean credit raises the visible total", int(gs.cash), 350)

	# Canon's default: money the game cannot vouch for is dirty.
	_wallet_ready(gs, 100, 200)
	wallet.credit(50, "not_a_provenance", {})
	_expect_int("an unknown provenance credits dirty", int(gs.dirty_cash), 150)
	_expect_int("an unknown provenance does not credit clean", int(gs.clean_cash), 200)

	# A negative credit is a caller bug, not a spend spelled differently.
	_wallet_ready(gs, 100, 200)
	wallet.credit(-500, wallet.DIRTY, {})
	_expect_int("a negative credit moves no dirty", int(gs.dirty_cash), 100)
	_expect_int("a negative credit moves no clean", int(gs.clean_cash), 200)
	_expect_int("a negative credit moves no cash", int(gs.cash), 300)

	# --- ROUTINE: dirty first ---
	_wallet_ready(gs, 500, 500)
	tx = wallet.spend(300, wallet.ROUTINE_DIRTY_FIRST, {})
	_expect_true("a routine spend reports ok", bool(tx["ok"]))
	_expect_int("routine spending takes dirty first", int(gs.dirty_cash), 200)
	_expect_int("routine spending leaves clean untouched while dirty covers it",
		int(gs.clean_cash), 500)
	_expect_int("routine spending lowers the visible total", int(gs.cash), 700)
	_expect_int("the transaction reports the dirty side", int(tx["dirty_used"]), 300)
	_expect_int("the transaction reports no clean side", int(tx["clean_used"]), 0)

	# Dirty runs out mid-transaction and clean covers the remainder.
	_wallet_ready(gs, 100, 500)
	tx = wallet.spend(300, wallet.ROUTINE_DIRTY_FIRST, {})
	_expect_int("routine spending drains dirty to zero", int(gs.dirty_cash), 0)
	_expect_int("routine spending then takes clean", int(gs.clean_cash), 300)
	_expect_int("a split routine spend reports its dirty half", int(tx["dirty_used"]), 100)
	_expect_int("a split routine spend reports its clean half", int(tx["clean_used"]), 200)

	# --- HIGH VISIBILITY: clean first. TI-003 regression #23. ---
	_wallet_ready(gs, 500, 500)
	tx = wallet.spend(300, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	_expect_int("high-visibility spending takes clean first", int(gs.clean_cash), 200)
	_expect_int("high-visibility spending leaves dirty untouched while clean covers it",
		int(gs.dirty_cash), 500)
	_expect_int("a high-visibility spend reports its clean side", int(tx["clean_used"]), 300)
	_expect_int("a high-visibility spend reports no dirty side", int(tx["dirty_used"]), 0)

	_wallet_ready(gs, 500, 100)
	tx = wallet.spend(300, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	_expect_int("high-visibility spending drains clean to zero", int(gs.clean_cash), 0)
	_expect_int("high-visibility spending then reaches for dirty", int(gs.dirty_cash), 300)
	_expect_int("a split high-visibility spend reports its dirty half",
		int(tx["dirty_used"]), 200)

	# An unrecognised policy must behave as routine, not as high-visibility: a
	# typo that silently turned a purchase into a laundering signal would be
	# invisible until Financial Pressure moved for no reason.
	_wallet_ready(gs, 500, 500)
	wallet.spend(300, "not_a_policy", {})
	_expect_int("an unknown policy spends dirty first", int(gs.dirty_cash), 200)
	_expect_int("an unknown policy leaves clean alone", int(gs.clean_cash), 500)

	# --- refusal ---
	#
	# "Nothing moved" is only meaningful alongside "and the attempt was made and
	# rejected" — a spend that silently succeeded and one that was refused both
	# leave the buckets alone if the amount was zero.
	_wallet_ready(gs, 100, 100)
	tx = wallet.spend(500, wallet.ROUTINE_DIRTY_FIRST, {})
	_expect_true("an unaffordable spend is refused", not bool(tx["ok"]))
	_expect_str("an unaffordable spend says why", str(tx.get("reason", "")),
		"Not enough cash.")
	_expect_int("a refused spend moves no dirty", int(gs.dirty_cash), 100)
	_expect_int("a refused spend moves no clean", int(gs.clean_cash), 100)
	_expect_int("a refused spend moves no cash", int(gs.cash), 200)
	_expect_true("can_spend agrees with the refusal", not wallet.can_spend(500))
	_expect_true("can_spend allows exactly the balance", wallet.can_spend(200))

	# Spending the whole balance is allowed and lands on zero, not on a refusal.
	_wallet_ready(gs, 100, 100)
	tx = wallet.spend(200, wallet.ROUTINE_DIRTY_FIRST, {})
	_expect_true("spending the exact balance succeeds", bool(tx["ok"]))
	_expect_int("spending the exact balance empties dirty", int(gs.dirty_cash), 0)
	_expect_int("spending the exact balance empties clean", int(gs.clean_cash), 0)
	_expect_int("spending the exact balance empties the total", int(gs.cash), 0)

	# --- the invariant, after everything above ---
	_expect_true("cash equals dirty plus clean", wallet.is_balanced())

## TI-003 §6: financial_pressure_gain = round((dirty_used - 400) * 0.01), cap 10.
##
## The figures below are the formula's output at the boundaries, written out.
func _check_wallet_financial_pressure(gs: Node, wallet: RefCounted) -> void:
	# Under the free band: no Pressure at all.
	_wallet_ready(gs, 5000, 0)
	var tx: Dictionary = wallet.spend(400, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	_expect_int("400 dirty in the open is free", int(tx["financial_pressure_gain"]), 0)
	_expect_int("a free-band spend stores no Pressure", int(gs.financial_pressure), 0)

	# Just above it — and rounding to zero is still zero.
	_wallet_ready(gs, 5000, 0)
	tx = wallet.spend(440, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	_expect_int("40 dirty over the band rounds to no Pressure",
		int(tx["financial_pressure_gain"]), 0)

	_wallet_ready(gs, 5000, 0)
	tx = wallet.spend(450, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	_expect_int("50 dirty over the band rounds to 1 Pressure",
		int(tx["financial_pressure_gain"]), 1)
	_expect_int("the gain is stored", int(gs.financial_pressure), 1)

	_wallet_ready(gs, 5000, 0)
	tx = wallet.spend(900, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	_expect_int("500 dirty over the band is 5 Pressure",
		int(tx["financial_pressure_gain"]), 5)

	# Clean money in the open is invisible however much of it there is.
	_wallet_ready(gs, 0, 5000)
	tx = wallet.spend(3000, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	_expect_int("clean money in the open makes no Pressure",
		int(tx["financial_pressure_gain"]), 0)
	_expect_int("a clean high-visibility spend really happened", int(gs.cash), 2000)

	# TI-003 regression #24: routine spending must not create Pressure.
	_wallet_ready(gs, 5000, 0)
	tx = wallet.spend(3000, wallet.ROUTINE_DIRTY_FIRST, {})
	_expect_int("routine spending creates no Pressure",
		int(tx["financial_pressure_gain"]), 0)
	_expect_int("routine spending stores no Pressure", int(gs.financial_pressure), 0)
	_expect_int("the routine spend really happened", int(gs.dirty_cash), 2000)

	# The cap holds across repeated transactions.
	_wallet_ready(gs, 100000, 0)
	for _i in range(6):
		wallet.spend(1000, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	_expect_int("Financial Pressure caps at 10", int(gs.financial_pressure), 10)

## Canon's `reconcileCash`, which is the safety net under an unmigrated writer.
func _check_wallet_reconcile(gs: Node, wallet: RefCounted) -> void:
	# Untracked income defaults to dirty.
	_wallet_ready(gs, 100, 100)
	gs.cash = 500
	wallet.reconcile()
	_expect_int("untracked income folds into dirty", int(gs.dirty_cash), 400)
	_expect_int("untracked income leaves clean alone", int(gs.clean_cash), 100)
	_expect_true("reconcile restores the invariant", wallet.is_balanced())

	# Untracked spending drains dirty first.
	_wallet_ready(gs, 300, 300)
	gs.cash = 400
	wallet.reconcile()
	_expect_int("untracked spending drains dirty first", int(gs.dirty_cash), 100)
	_expect_int("untracked spending spares clean while dirty covers it",
		int(gs.clean_cash), 300)

	# And reaches clean once dirty is gone.
	_wallet_ready(gs, 100, 300)
	gs.cash = 200
	wallet.reconcile()
	_expect_int("untracked spending empties dirty", int(gs.dirty_cash), 0)
	_expect_int("untracked spending then drains clean", int(gs.clean_cash), 200)

	# Reconcile does not charge Financial Pressure: the port's spends declare
	# their own policy, so charging here as well would double-count.
	_wallet_ready(gs, 5000, 0)
	gs.cash = 1000
	wallet.reconcile()
	_expect_int("reconcile charges no Financial Pressure", int(gs.financial_pressure), 0)

	# A balanced wallet is left exactly alone.
	_wallet_ready(gs, 250, 250)
	wallet.reconcile()
	_expect_int("reconcile leaves a balanced dirty bucket alone", int(gs.dirty_cash), 250)
	_expect_int("reconcile leaves a balanced clean bucket alone", int(gs.clean_cash), 250)

## TI-003 §20 step 2-3 / §26. Note this is the OPPOSITE of canon's own pre-split
## migration, which classifies legacy wealth dirty (game-core.js:2060-2066); the
## divergence is deliberate and lives in `classify_legacy_total()`.
func _check_wallet_legacy_classification(gs: Node, wallet: RefCounted) -> void:
	_wallet_ready(gs, 400, 400)
	gs.cash = 1234
	wallet.classify_legacy_total()
	_expect_int("a legacy total classifies clean", int(gs.clean_cash), 1234)
	_expect_int("a legacy total leaves nothing dirty", int(gs.dirty_cash), 0)
	_expect_int("a legacy total does not change the visible cash", int(gs.cash), 1234)
	_expect_true("a classified legacy total is balanced", wallet.is_balanced())

	# It is idempotent, which is what makes it safe to run on every load.
	wallet.classify_legacy_total()
	_expect_int("classifying twice is the same as once", int(gs.clean_cash), 1234)
	_expect_int("classifying twice leaves nothing dirty", int(gs.dirty_cash), 0)

# --- heat -------------------------------------------------------------------

## Deshawn's authored curve, recorded as literals rather than read from
## `DESHAWN_HEAT_REDUCTION` — deriving the expectation from the same table the
## code reads would pass no matter what the table said.
const DESHAWN_RANK_MULTIPLIERS := {1: 0.80, 2: 0.60, 3: 0.40}

func _deshawn_at(gs: Node, tier: int) -> void:
	gs.crew_records["deshawn"] = {
		"recruited": true, "status": "active",
		"loyalty": gs.CREW_LOYALTY_START, "tier": tier,
		"wage_due": 0, "wage_missed_since": -1,
	}

## TI-003 §7's three entry points, and the rule that separates them.
func _check_heat_api(gs: Node, gm: Node, heat: RefCounted) -> void:
	# --- gain, with nobody on the crew ---
	_wallet_ready(gs, 0, 100)
	var applied: float = heat.apply_gain(2.0, heat.FAMILY_STICK, "north_star_lot", {})
	_expect_float("an unscaled gain applies its raw amount", applied, 2.0)
	_expect_float("an unscaled gain lands on the meter", float(gs.heat), 2.0)

	# Heat is fractional and stays that way. Rounding it is a shipped bug this
	# port has already had once — see systems/heat.gd.
	_wallet_ready(gs, 0, 100)
	heat.apply_gain(0.5, heat.FAMILY_BOOST, "north_star_lot", {})
	_expect_float("a fractional gain stays fractional", float(gs.heat), 0.5)

	# A non-positive gain is a caller reaching for relief by the wrong name.
	_wallet_ready(gs, 0, 100)
	gs.heat = 5.0
	_expect_float("a zero gain applies nothing", heat.apply_gain(0.0, "", "", {}), 0.0)
	_expect_float("a negative gain applies nothing", heat.apply_gain(-3.0, "", "", {}), 0.0)
	_expect_float("a refused gain leaves the meter alone", float(gs.heat), 5.0)

	# --- Deshawn, applied exactly ONCE, across the authored ranks ---
	#
	# The double-application this migration risks is arithmetically distinct at
	# every rank: 10 raw at rank 1 is 8.0 applied once and 6.4 applied twice, so
	# a single pinned figure per rank catches it. Both numbers are named in the
	# label so a failure reads as the diagnosis.
	for tier in [1, 2, 3]:
		_wallet_ready(gs, 0, 100)
		_deshawn_at(gs, tier)
		var mult: float = float(DESHAWN_RANK_MULTIPLIERS[tier])
		var once: float = 10.0 * mult
		var twice: float = 10.0 * mult * mult
		applied = heat.apply_gain(10.0, heat.FAMILY_STICK, "north_star_lot", {})
		_expect_float("Deshawn rank %d applies once (%.2f, not %.2f)"
			% [tier, once, twice], applied, once)
		_expect_float("Deshawn rank %d lands once on the meter" % tier,
			float(gs.heat), once)

	# Above the authored curve. `curve_value_for_rank` holds the highest
	# authored rank rather than falling back to neutral — a promotion must not
	# silently REMOVE the reduction he already earned, which is a bug this
	# codebase has already fixed once in crew.gd.
	for tier in [4, 7]:
		_wallet_ready(gs, 0, 100)
		_deshawn_at(gs, tier)
		applied = heat.apply_gain(10.0, heat.FAMILY_STICK, "north_star_lot", {})
		_expect_float("Deshawn above the curve holds rank 3's reduction (rank %d)"
			% tier, applied, 4.0)

	# Not recruited, and recruited-but-inactive, both scale by 1.0.
	_wallet_ready(gs, 0, 100)
	gs.crew_records["deshawn"] = {
		"recruited": true, "status": "gone", "tier": 3,
		"loyalty": gs.CREW_LOYALTY_START, "wage_due": 0, "wage_missed_since": -1,
	}
	_expect_float("a departed Deshawn damps nothing",
		heat.apply_gain(10.0, heat.FAMILY_STICK, "north_star_lot", {}), 10.0)

	# --- relief bypasses the gain multipliers. TI-003 regression #15. ---
	#
	# This is the one that would invert Deshawn: if relief went through his
	# multiplier, having him on the crew would make Lay Low work LESS well.
	# Measured against the identical relief with him absent — same number, and
	# the number is the full requested amount rather than a scaled one.
	_wallet_ready(gs, 0, 100)
	gs.heat = 10.0
	var relief_without: float = heat.apply_relief(2.0, {})
	var heat_without: float = float(gs.heat)

	_wallet_ready(gs, 0, 100)
	gs.heat = 10.0
	_deshawn_at(gs, 3)
	var relief_with: float = heat.apply_relief(2.0, {})
	_expect_float("relief is the same with Deshawn as without",
		relief_with, relief_without)
	_expect_float("relief leaves the same meter with Deshawn as without",
		float(gs.heat), heat_without)
	_expect_float("relief applies its full requested amount", relief_with, -2.0)
	_expect_float("relief lands in full on the meter", float(gs.heat), 8.0)

	# Relief takes a positive amount and subtracts it. A negative "relief" is
	# the same caller confusion as a negative gain, in the other direction.
	_wallet_ready(gs, 0, 100)
	gs.heat = 5.0
	_expect_float("a negative relief applies nothing", heat.apply_relief(-2.0, {}), 0.0)
	_expect_float("a refused relief leaves the meter alone", float(gs.heat), 5.0)

	# --- direct also bypasses the gain multipliers ---
	_wallet_ready(gs, 0, 100)
	gs.heat = 5.0
	_deshawn_at(gs, 3)
	_expect_float("a direct change ignores Deshawn",
		heat.apply_direct(1.0, {}), 1.0)
	_expect_float("a direct change lands in full", float(gs.heat), 6.0)
	_expect_float("a direct change carries its sign",
		heat.apply_direct(-2.0, {}), -2.0)
	_expect_float("a signed direct change lands in full", float(gs.heat), 4.0)

	# --- the clamp, at both ends, reported honestly ---
	#
	# The returned delta is what LANDED, not what was asked for. Stickup logs
	# this number, so a clamped gain must not claim the full amount.
	_wallet_ready(gs, 0, 100)
	gs.heat = 14.5
	applied = heat.apply_gain(3.0, "", "", {})
	_expect_float("a gain clamps at the ceiling", float(gs.heat), 15.0)
	_expect_float("a clamped gain reports only what landed", applied, 0.5)

	_wallet_ready(gs, 0, 100)
	gs.heat = 1.0
	applied = heat.apply_relief(4.0, {})
	_expect_float("relief clamps at the floor", float(gs.heat), 0.0)
	_expect_float("clamped relief reports only what landed", applied, -1.0)

	# The ceiling is read from GameState rather than hardcoded at 15 in the
	# owner — the scale is 0-15 and the owner must not be the second place that
	# knows it.
	_expect_float("the owner reads the ceiling from state",
		heat.ceiling(), float(gs.heat_max))

## TI-003 §7's authored district x family table, pinned as data.
##
## `apply_gain` does NOT consult it this slice — see systems/heat.gd for why —
## so this covers the values and the neutral fallback, and then proves the
## wiring really is inert. FS-003.9 flips it on and inverts the last two checks.
func _check_heat_district_table(heat: RefCounted) -> void:
	var rows := [
		["north_star_lot", heat.FAMILY_MARKET, 0.8],
		["north_star_lot", heat.FAMILY_BOOST, 0.9],
		["north_star_lot", heat.FAMILY_STICK, 1.3],
		["downtown", heat.FAMILY_MARKET, 1.2],
		["downtown", heat.FAMILY_BOOST, 1.1],
		["downtown", heat.FAMILY_STICK, 1.0],
		["airport_industrial", heat.FAMILY_MARKET, 1.1],
		["airport_industrial", heat.FAMILY_BOOST, 1.2],
		["airport_industrial", heat.FAMILY_STICK, 1.2],
	]
	for row in rows:
		_expect_float("TI-003 heat multiplier %s/%s" % [row[0], row[1]],
			heat.district_multiplier(str(row[0]), str(row[1])), float(row[2]))

	# Anything unlisted scales by 1.0 — which is what carries shark enforcement
	# and territory's nightly heat at exactly the scaling they had before.
	_expect_float("an unknown district scales neutrally",
		heat.district_multiplier("nowhere", heat.FAMILY_STICK), 1.0)
	_expect_float("an unknown family scales neutrally",
		heat.district_multiplier("downtown", "arson"), 1.0)
	_expect_float("an empty family scales neutrally",
		heat.district_multiplier("downtown", ""), 1.0)

## The table is authored but not wired, so the same raw gain costs the same in
## every district this slice. Spenard/stick is 1.3 — the largest divergence in
## the table — so if the wiring were live this would read 2.6 rather than 2.0.
func _check_heat_district_scaling_inert(gs: Node, heat: RefCounted) -> void:
	var seen: Array = []
	for district in ["north_star_lot", "downtown", "airport_industrial"]:
		_wallet_ready(gs, 0, 100)
		gs.current_district_id = district
		heat.apply_gain(2.0, heat.FAMILY_STICK, district, {})
		seen.append(float(gs.heat))
	_expect_str("district scaling is not wired this slice", str(seen),
		str([2.0, 2.0, 2.0]))

# --- provenance through the real dispatch path ------------------------------

## Which bucket each source's money lands in, driven through `gm.dispatch` so
## the check walks the stack the game produces.
##
## Amounts are not re-asserted here (the fixture sections own those); what is
## asserted is that money moved AND which bucket it moved through. A source
## whose take silently stopped arriving would pass a bucket-only check.
func _check_source_provenance(gs: Node, gm: Node) -> void:
	# --- legal wages are clean. TI-003 §6, and canon's `addCleanCash`. ---
	_wallet_ready(gs, 0, 0)
	gs.active_job_id = "wash_go"
	gs.job_records["wash_go"] = {"xp": 0.0, "rank": 0, "shifts": 0,
		"last_worked_day": -1, "relationship": 0.0}
	var before_cash: int = int(gs.cash)
	var worked: bool = gm.dispatch("work_shift", {"approach": "work_hard"})
	_expect_true("a shift dispatches", worked)
	if worked:
		var earned: int = int(gs.cash) - before_cash
		_expect_true("a shift actually paid something", earned > 0)
		_expect_int("job wages land clean", int(gs.clean_cash), earned)
		_expect_int("job wages leave nothing dirty", int(gs.dirty_cash), 0)

	# --- a stickup take is dirty ---
	#
	# Driven until a success lands rather than assumed off a seed: a fixed seed
	# may resolve to a failure, and a failed stickup pays nothing at all, which
	# would make "the take is dirty" pass vacuously.
	var found_take := false
	for attempt in range(40):
		_wallet_ready(gs, 0, 0)
		gs.day = 9 + attempt
		gs.stick_daily_count = 0
		before_cash = int(gs.cash)
		if not gm.dispatch("stickup", {"target_id": "washgo_regular"}):
			continue
		var take: int = int(gs.cash) - before_cash
		if take <= 0:
			continue
		found_take = true
		_expect_int("a stickup take lands dirty", int(gs.dirty_cash), take)
		_expect_int("a stickup take leaves nothing clean", int(gs.clean_cash), 0)
		break
	_expect_true("the stickup provenance check found a paying take", found_take)

	# --- a 907List flip is clean. Canon's other `addCleanCash` site. ---
	_wallet_ready(gs, 0, 5000)
	var listing: Dictionary = _first_listing(gm)
	if listing.is_empty():
		_fail("list provenance", "no listing on the board")
	else:
		var item_id := str(listing.get("id", ""))
		_expect_true("a listing purchase dispatches",
			gm.dispatch("list_buy", {"item_id": item_id}))
		# The purchase is routine, so it came out of clean here (no dirty).
		_expect_int("a routine list purchase drains clean when dirty is empty",
			int(gs.dirty_cash), 0)
		# The board holds a flip overnight — `sell_blocker`'s `sell_delay`. Moved
		# by hand rather than by dispatching a night, which would settle every
		# other system and drag their cash through this check.
		gs.day += int(gs.market_tier()["sell_delay"])
		before_cash = int(gs.cash)
		var clean_before: int = int(gs.clean_cash)
		_expect_true("a listing sale dispatches",
			gm.dispatch("list_sell", {"index": 0}))
		var got: int = int(gs.cash) - before_cash
		_expect_true("the flip actually paid something", got > 0)
		_expect_int("a 907List flip lands clean",
			int(gs.clean_cash), clean_before + got)
		_expect_int("a 907List flip leaves nothing dirty", int(gs.dirty_cash), 0)

	# --- rent is high-visibility: clean goes first ---
	_wallet_ready(gs, 5000, 5000)
	gs.rent_due_day = gs.day
	var clean_start: int = int(gs.clean_cash)
	var dirty_start: int = int(gs.dirty_cash)
	_expect_true("rent dispatches", gm.dispatch("pay_rent", {}))
	_expect_int("rent comes out of clean first",
		int(gs.clean_cash), clean_start - int(gs.WEEKLY_RENT))
	_expect_int("rent leaves dirty alone while clean covers it",
		int(gs.dirty_cash), dirty_start)

	# --- the phone bill, same policy ---
	_wallet_ready(gs, 5000, 5000)
	gs.phone_due_day = gs.day
	clean_start = int(gs.clean_cash)
	dirty_start = int(gs.dirty_cash)
	_expect_true("the phone bill dispatches", gm.dispatch("pay_phone_bill", {}))
	_expect_int("the phone bill comes out of clean first",
		int(gs.clean_cash), clean_start - int(gs.PHONE_BILL))
	_expect_int("the phone bill leaves dirty alone while clean covers it",
		int(gs.dirty_cash), dirty_start)

	# --- a routine spend takes dirty first, through a real action ---
	_wallet_ready(gs, 5000, 5000)
	dirty_start = int(gs.dirty_cash)
	clean_start = int(gs.clean_cash)
	_expect_true("travel dispatches", gm.dispatch("travel", {"district_id": "downtown"}))
	_expect_true("travel actually charged a fare", int(gs.dirty_cash) < dirty_start)
	_expect_int("a travel fare leaves clean alone", int(gs.clean_cash), clean_start)

	# --- the invariant survives every one of those ---
	var wallet: RefCounted = gm.system("wallet") as RefCounted
	_expect_true("the wallet is still balanced after the source sweep",
		wallet.is_balanced())

## A listing the board is actually offering today. Picking any item out of the
## static table would hit `buy_blocker`'s "that one is gone" on a consumed id and
## make the flip check pass by never running.
func _first_listing(gm: Node) -> Dictionary:
	var list_system: Object = gm.system("list")
	if list_system == null:
		return {}
	var offered: Array = list_system.todays_listings()
	for row in offered:
		if row is Dictionary:
			return row
	return {}

# --- the RNG contract -------------------------------------------------------

## TI-003 §21: "TI-003 adds zero market-stream draws."
##
## Wallet and Heat are pure state arithmetic and must not touch `rng_state`,
## which belongs to the market walk alone. Asserted around the owners' own API
## and again around a full source action, because a source that started drawing
## from the wrong stream would move the cursor without either owner doing so.
func _check_owner_rng_non_drift(gs: Node, gm: Node, wallet: RefCounted,
		heat: RefCounted) -> void:
	_wallet_ready(gs, 1000, 1000)
	gs.rng_state = 123456789
	var cursor: int = int(gs.rng_state)

	wallet.credit(500, wallet.DIRTY, {})
	wallet.credit(500, wallet.CLEAN, {})
	wallet.spend(300, wallet.ROUTINE_DIRTY_FIRST, {})
	wallet.spend(900, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {})
	wallet.reconcile()
	wallet.classify_legacy_total()
	_expect_int("the wallet draws nothing from the market stream",
		int(gs.rng_state), cursor)

	_deshawn_at(gs, 2)
	heat.apply_gain(3.0, heat.FAMILY_STICK, "north_star_lot", {})
	heat.apply_direct(1.0, {})
	heat.apply_relief(2.0, {})
	heat.district_multiplier("downtown", heat.FAMILY_BOOST)
	heat.crew_multiplier()
	_expect_int("the heat system draws nothing from the market stream",
		int(gs.rng_state), cursor)

	# And the cursor is genuinely observable — a check that pins an unmoving
	# number is worth nothing if the field never moves anyway. The nightly
	# evolve is the one thing allowed to move it, so it must.
	_wallet_ready(gs, 1000, 1000)
	gs.rng_state = 123456789
	cursor = int(gs.rng_state)
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	_expect_true("the night dispatches", gm.dispatch("advance_time", {}))
	_expect_true("the market walk does move the cursor", int(gs.rng_state) != cursor)

## FS-003.4 — the Consequence-Encounter Engine's persisted state, and the v8 arm.
##
## ## What this section deliberately does NOT re-cover
##
## The general round-trip machinery already covers every field in
## `PERSIST_FIELDS` by name (`_check_save_roundtrip`), the coercion rules
## (`_coerced`), and the malformed-payload posture (`_check_list_migration`'s
## junk-holdings case). Those are not repeated.
##
## What is new:
##
##   1. the v7 → v8 arm, including the wallet transform that is its only one;
##   2. determinism and idempotency of that arm;
##   3. TI-003 §20's twelve required round-trip shapes, each staged and reloaded;
##   4. the invariant `cash == dirty + clean` surviving a load;
##   5. save data containing no Object references and no runtime adapters.
func _check_consequence_state() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var saves := get_node("/root/SaveSystem")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	_check_v8_field_manifest(saves)
	_check_v8_migration(gs, saves)
	_check_v8_roundtrips(gs, gm, saves)
	_check_v8_save_carries_no_objects(gs, gm, saves)

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()
	gs.reset_to_new_game()

## Every TI-003 §5 structure is actually in the manifest.
##
## Asserted by name rather than by round-tripping alone: a field missing from
## `PERSIST_FIELDS` round-trips perfectly for as long as the test never changes
## it from its default, which is exactly how a persistence gap ships.
const V8_PERSISTED: Array[String] = [
	"dirty_cash", "clean_cash", "financial_pressure",
	"next_cause_sequence", "next_consequence_sequence",
	"active_consequence", "consequence_history", "consequence_queue",
	"last_blocking_delayed_day", "arrest_record", "boost_store_bans",
	"district_pressure", "pressure_bleed_pending",
]

func _check_v8_field_manifest(saves: Node) -> void:
	for field in V8_PERSISTED:
		_expect_true("%s persists" % field, field in saves.PERSIST_FIELDS)

## A v7 save, as v7 actually wrote them: one aggregate `cash`, and not one of
## the consequence fields present at all.
func _v7_payload(cash: int) -> Dictionary:
	return {
		"day": 12, "time_slot": "EVENING", "time_slots_today": 2,
		"run_seed": "907hustle", "current_district_id": "downtown",
		"street_name": "Legacy",
		"cash": cash, "heat": 4.5, "health": 61, "debt": 300,
		"respect": 5, "crew_power": 3,
		"inventory": {"weed": 2},
		"rent_due_day": 15, "phone_due_day": 14, "phone_active": true,
		"crew_records": {}, "held_blocks": {}, "soldiers_idle": 0,
		"list_holdings": [], "list_taken": {"day": 12, "ids": []},
		"activity_log": [],
	}

func _write_save(saves: Node, version: int, state: Dictionary) -> void:
	var file := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("save write", "could not open %s" % saves.SAVE_PATH)
		return
	file.store_string(var_to_str({"save_version": version, "state": state}))
	file.close()

## The v7 → v8 arm. TI-003 §20, step by step.
func _check_v8_migration(gs: Node, saves: Node) -> void:
	# Scramble every target field first, so a load that silently no-ops cannot
	# pass any of the assertions below by leaving them where the test put them.
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.dirty_cash = 999
	gs.clean_cash = 111
	gs.financial_pressure = 7
	gs.next_cause_sequence = 42
	gs.active_consequence = {"stage": "decision", "cause_id": "cause:00000001"}
	gs.consequence_history = {"cause:00000001": {"effect_receipts": ["x"]}}
	gs.consequence_queue = [{"queue_id": "q1"}]
	gs.last_blocking_delayed_day = 5
	gs.arrest_record = {"priors": 3, "last_arrest_day": 9, "charges": [{"a": 1}]}
	gs.boost_store_bans = ["some_store"]
	gs.district_pressure = {"downtown": {"boost": {"score": 6.0}}}
	gs.pressure_bleed_pending = [{"to": "downtown"}]

	_write_save(saves, 7, _v7_payload(1500))
	_expect_true("a v7 save loads into v8", saves.load_run())

	# Step 1-3: the wallet transform, the arm's only one.
	_expect_int("v7 migration keeps the visible total", int(gs.cash), 1500)
	_expect_int("v7 migration classifies the aggregate clean", int(gs.clean_cash), 1500)
	_expect_int("v7 migration leaves nothing dirty", int(gs.dirty_cash), 0)
	# TI-003 acceptance: "aggregate visible Cash equals Clean + Dirty".
	_expect_int("v7 migration keeps the wallet invariant",
		int(gs.cash), int(gs.dirty_cash) + int(gs.clean_cash))

	# Step 4-9: everything else seeds empty. A v7 save cannot hold any of it,
	# so empty is the true history rather than a fallback.
	_expect_int("v7 migration seeds no Financial Pressure", int(gs.financial_pressure), 0)
	_expect_int("v7 migration seeds no cause sequence", int(gs.next_cause_sequence), 0)
	_expect_int("v7 migration seeds no consequence sequence",
		int(gs.next_consequence_sequence), 0)
	_expect_true("v7 migration infers no active chain", gs.active_consequence.is_empty())
	_expect_true("v7 migration seeds empty history", gs.consequence_history.is_empty())
	_expect_true("v7 migration seeds an empty queue", gs.consequence_queue.is_empty())
	_expect_int("v7 migration seeds no delayed-surface day",
		int(gs.last_blocking_delayed_day), -1)
	_expect_int("v7 migration seeds no priors", int(gs.arrest_record["priors"]), 0)
	_expect_int("v7 migration seeds no last arrest",
		int(gs.arrest_record["last_arrest_day"]), -1)
	_expect_true("v7 migration seeds no charges",
		(gs.arrest_record["charges"] as Array).is_empty())
	_expect_true("v7 migration seeds no Boost bans", gs.boost_store_bans.is_empty())
	_expect_true("v7 migration seeds no District Pressure", gs.district_pressure.is_empty())
	_expect_true("v7 migration seeds an empty bleed queue",
		gs.pressure_bleed_pending.is_empty())

	# Step 10: everything a v7 save DID carry is preserved. The arm must not be
	# a reset dressed as a migration — asserted on fields from four systems.
	_expect_int("v7 migration preserves the day", gs.day, 12)
	_expect_float("v7 migration preserves heat", float(gs.heat), 4.5)
	_expect_int("v7 migration preserves health", gs.health, 61)
	_expect_str("v7 migration preserves the district", gs.current_district_id, "downtown")
	_expect_int("v7 migration preserves inventory", int(gs.inventory.get("weed", 0)), 2)
	_expect_int("v7 migration preserves obligations", gs.rent_due_day, 15)

	# Deterministic: the same payload produces the same result every time.
	var first := "%d/%d/%d" % [int(gs.cash), int(gs.clean_cash), int(gs.dirty_cash)]
	gs.reset_to_new_game()
	_write_save(saves, 7, _v7_payload(1500))
	_expect_true("the v7 arm reloads", saves.load_run())
	_expect_str("the v7 arm is deterministic",
		"%d/%d/%d" % [int(gs.cash), int(gs.clean_cash), int(gs.dirty_cash)], first)

	# Idempotent: the run that just migrated saves as v8 and reloads unchanged.
	# This is the case that would break if the classifier ran on every load
	# rather than only where provenance is absent — a v8 save with real dirty
	# money would be laundered by its own reload.
	gs.dirty_cash = 400
	gs.clean_cash = 1100
	gs.cash = 1500
	saves.save_run()
	gs.dirty_cash = 0
	gs.clean_cash = 0
	gs.cash = 0
	_expect_true("the migrated run saves and reloads as v8", saves.load_run())
	_expect_int("a v8 reload keeps dirty money dirty", int(gs.dirty_cash), 400)
	_expect_int("a v8 reload keeps clean money clean", int(gs.clean_cash), 1100)
	_expect_int("a v8 reload keeps the visible total", int(gs.cash), 1500)

	# A zero-cash v7 save is the boundary the maxi() guard exists for.
	gs.reset_to_new_game()
	_write_save(saves, 7, _v7_payload(0))
	_expect_true("a broke v7 save migrates", saves.load_run())
	_expect_int("a broke v7 save classifies nothing clean", int(gs.clean_cash), 0)
	_expect_int("a broke v7 save classifies nothing dirty", int(gs.dirty_cash), 0)

	# And a malformed one migrates rather than crashing — PR #36's posture,
	# applied to the field this arm actually reads.
	gs.reset_to_new_game()
	var junk: Dictionary = _v7_payload(500)
	junk["cash"] = "not a number"
	_write_save(saves, 7, junk)
	# REQUIRED_KEYS type-checks `cash`, so this is refused rather than migrated.
	# Asserted so the refusal is a decision on the record: a save whose cash is
	# not a number has no aggregate to classify, and guessing one would invent
	# money.
	_expect_true("a v7 save with non-numeric cash is refused", not saves.load_run())

	# --- the arm in isolation ---
	#
	# Everything above goes through `load_run()`, which ALSO runs the load-time
	# classifier — and that classifier reaches the same answer, so the arm's own
	# transform is invisible through that path. A sabotage that deleted the arm's
	# two lines entirely passed the whole section above.
	#
	# So the arm is called directly and its RETURNED payload inspected, before a
	# byte of it reaches GameState. This is the only check that can tell the two
	# apart, and it is the reason the arm is not dead code.
	var migrated: Dictionary = saves._migrate({"save_version": 7, "state": _v7_payload(1500)})
	_expect_true("the v7 arm returns a payload", not migrated.is_empty())
	_expect_true("the v7 arm writes clean_cash itself", migrated.has("clean_cash"))
	_expect_true("the v7 arm writes dirty_cash itself", migrated.has("dirty_cash"))
	_expect_int("the v7 arm classifies clean in the payload",
		int(migrated.get("clean_cash", -1)), 1500)
	_expect_int("the v7 arm classifies dirty in the payload",
		int(migrated.get("dirty_cash", -1)), 0)
	_expect_int("the v7 arm leaves the aggregate alone", int(migrated.get("cash", -1)), 1500)
	# The arm must not invent consequence state either — those fields default in
	# through `_apply` rather than being written here.
	_expect_true("the v7 arm invents no active chain", not migrated.has("active_consequence"))

	# A v8 payload passes through untouched: the arm runs only for older ones.
	var v8_state: Dictionary = _v7_payload(1500)
	v8_state["clean_cash"] = 200
	v8_state["dirty_cash"] = 1300
	var untouched: Dictionary = saves._migrate({"save_version": 8, "state": v8_state})
	_expect_int("a v8 payload keeps its dirty bucket",
		int(untouched.get("dirty_cash", -1)), 1300)
	_expect_int("a v8 payload keeps its clean bucket",
		int(untouched.get("clean_cash", -1)), 200)

	# The arm's arithmetic and WalletSystem's classifier must agree. They are
	# two implementations of one TI-003 rule — the arm works on a Dictionary
	# before any system exists, the classifier on live state — and a divergence
	# between them would show up only on old saves.
	var gm := get_node("/root/GameManager")
	var wallet: RefCounted = gm.system("wallet") as RefCounted
	gs.reset_to_new_game()
	gs.cash = 1500
	gs.dirty_cash = 900
	gs.clean_cash = 600
	wallet.classify_legacy_total()
	_expect_int("the classifier agrees with the arm on clean", int(gs.clean_cash), 1500)
	_expect_int("the classifier agrees with the arm on dirty", int(gs.dirty_cash), 0)

## TI-003 §20's required round-trips, staged as state and reloaded.
##
## Each shape is written into GameState, saved, scrambled, and reloaded, and the
## reload is asserted to restore the exact facts a later slice will read — the
## stage, the committed choice, the shown odds, the queue order.
##
## These are STATE round-trips, not behaviour: FS-003.4 persists the shapes and
## FS-003.5 onward fills them. A round-trip that passes here is the guarantee
## those slices are building on.
func _check_v8_roundtrips(gs: Node, gm: Node, saves: Node) -> void:
	# --- 1. Caught decision, mid-chain ---
	_stage_run(gs)
	gs.next_cause_sequence = 142
	gs.next_consequence_sequence = 143
	gs.active_consequence = {
		"consequence_id": "consequence:00000143",
		"cause_id": "cause:00000142",
		"chain_kind": "boost_caught",
		"stage": "decision",
		"created_day": 12, "created_slot": 2,
		"district_id": "downtown", "return_route": "BOOST",
		"source": {
			"family": "boost", "action_id": "boost", "target_id": "corner_store",
			"target_tier": 2, "source_day": 12, "source_slot": 2,
			"source_rng_key": "boost:12:2:corner_store",
			"pre_encounter_heat": 7.5, "contested_take": 240,
		},
		"decision": {
			"definition_id": "boost_caught",
			"allowed_choices": ["fight", "run", "talk", "yield"],
			"committed_choice": "",
			"resolver_inputs": {"combat": 3, "charisma": 2},
			"shown_probabilities": {"fight": 0.42, "run": 0.55, "talk": 0.31},
			"resolved_tier": "", "result": {},
		},
		"booking": {},
		"time": {"source_slots_remaining": 1, "source_time_settled": false},
	}
	_roundtrip(gs, saves, "caught decision")
	_expect_str("a Caught decision restores its stage",
		str(gs.active_consequence.get("stage", "")), "decision")
	_expect_str("a Caught decision restores its cause",
		str(gs.active_consequence.get("cause_id", "")), "cause:00000142")
	_expect_int("a Caught decision restores its contested take",
		int((gs.active_consequence["source"] as Dictionary)["contested_take"]), 240)
	# The float that a coercion bug would round away, and the one the arrest gate
	# reads later.
	_expect_float("a Caught decision restores pre-encounter heat",
		float((gs.active_consequence["source"] as Dictionary)["pre_encounter_heat"]), 7.5)
	# TI-003 §5: "Persist decision inputs and shown probabilities when the
	# decision opens. Reload reproduces the same choice surface." Shown odds are
	# floats inside a nested Dictionary — the deepest thing in this shape.
	var shown: Dictionary = (gs.active_consequence["decision"] as Dictionary)["shown_probabilities"]
	_expect_float("a reload reproduces the shown odds", float(shown["run"]), 0.55)
	_expect_str("a Caught decision restores its allowed choices",
		str((gs.active_consequence["decision"] as Dictionary)["allowed_choices"]),
		str(["fight", "run", "talk", "yield"]))
	_expect_true("a Caught decision restores its unsettled source time",
		not bool((gs.active_consequence["time"] as Dictionary)["source_time_settled"]))
	_expect_int("the cause sequence survives a reload", int(gs.next_cause_sequence), 142)

	# --- 2. A committed result waiting on Continue ---
	#
	# The case TI-003 regression #4 names: a reload must not reroll a committed
	# response. The committed choice and the resolved tier both have to come
	# back, or the chain re-opens as a fresh decision.
	_stage_run(gs)
	gs.active_consequence = {
		"consequence_id": "consequence:00000143", "cause_id": "cause:00000142",
		"chain_kind": "boost_caught", "stage": "result",
		"decision": {
			"committed_choice": "run", "resolved_tier": "messy",
			"result": {"health": -2, "heat": 1.0, "take_kept": 0, "banned": true},
		},
		"time": {"source_slots_remaining": 1, "source_time_settled": false},
	}
	_roundtrip(gs, saves, "committed result")
	_expect_str("a committed result restores its stage",
		str(gs.active_consequence.get("stage", "")), "result")
	_expect_str("a committed choice survives a reload",
		str((gs.active_consequence["decision"] as Dictionary)["committed_choice"]), "run")
	_expect_str("a resolved tier survives a reload",
		str((gs.active_consequence["decision"] as Dictionary)["resolved_tier"]), "messy")

	# --- 3. Booking decision, with its quote ---
	_stage_run(gs)
	gs.active_consequence = {
		"cause_id": "cause:00000142", "chain_kind": "boost_caught",
		"stage": "booking",
		"booking": {
			"severity": "boost_t2", "bail_quote": 375, "base_bail": 250,
			"prior_multiplier": 1.5, "processing_slots": 2, "heat_relief": 2,
			"priors_at_quote": 1, "projected_release_day": 13,
			"projected_release_slot": 0,
		},
		"time": {"source_slots_remaining": 1, "source_time_settled": false},
	}
	_roundtrip(gs, saves, "booking decision")
	_expect_str("a Booking decision restores its stage",
		str(gs.active_consequence.get("stage", "")), "booking")
	_expect_int("a bail quote survives a reload",
		int((gs.active_consequence["booking"] as Dictionary)["bail_quote"]), 375)
	_expect_float("a prior multiplier survives a reload",
		float((gs.active_consequence["booking"] as Dictionary)["prior_multiplier"]), 1.5)

	# --- 4. Release stage ---
	_stage_run(gs)
	gs.active_consequence = {
		"cause_id": "cause:00000142", "chain_kind": "boost_caught",
		"stage": "release",
		"booking": {"paid": 375, "clean_used": 375, "dirty_used": 0,
			"slots_served": 2, "released_day": 13},
		"time": {"source_slots_remaining": 0, "source_time_settled": true},
	}
	_roundtrip(gs, saves, "release stage")
	_expect_str("a release stage survives a reload",
		str(gs.active_consequence.get("stage", "")), "release")
	# TI-003 regression #12: source time settles twice around Booking. The flag
	# that prevents it is the thing that has to persist.
	_expect_true("a settled source time survives a reload",
		bool((gs.active_consequence["time"] as Dictionary)["source_time_settled"]))

	# --- 5-7. Retaliation queue: before trigger, elsewhere, and blocked ---
	#
	# All three in one payload, because the property being tested is the QUEUE,
	# and a queue with one row cannot demonstrate ordering.
	_stage_run(gs)
	gs.consequence_queue = [
		{"queue_id": "ret:1", "cause_id": "cause:00000142", "actor_id": "goodie",
		 "actor_label": "Goodie's people", "source_family": "stick",
		 "source_target_id": "goodie_stash", "district_id": "north_star_lot",
		 "created_day": 12, "trigger_day": 14, "expires_end_day": 17,
		 "created_sequence": 1, "encounter_definition_id": "retaliation_street_crew",
		 "status": "pending"},
		{"queue_id": "ret:2", "cause_id": "cause:00000150", "actor_id": "till_crew",
		 "actor_label": "The register crew", "source_family": "stick",
		 "source_target_id": "downtown_fuel_till", "district_id": "downtown",
		 "created_day": 11, "trigger_day": 13, "expires_end_day": 16,
		 "created_sequence": 2, "encounter_definition_id": "retaliation_street_crew",
		 "status": "pending"},
		{"queue_id": "ret:3", "cause_id": "cause:00000151", "actor_id": "rec_crew",
		 "actor_label": "The dice game", "source_family": "stick",
		 "source_target_id": "rec_center_dice", "district_id": "airport_industrial",
		 "created_day": 10, "trigger_day": 13, "expires_end_day": 15,
		 "created_sequence": 3, "encounter_definition_id": "retaliation_street_crew",
		 "status": "expired"},
	]
	gs.last_blocking_delayed_day = 12
	_roundtrip(gs, saves, "retaliation queue")
	_expect_int("the retaliation queue restores every row", gs.consequence_queue.size(), 3)
	# TI-003 regression #32: "Queue order depends on Dictionary iteration order."
	# An Array is what makes order a property of the storage, and the reload has
	# to preserve it — asserted as the whole id sequence rather than one element.
	var order: Array = []
	for row in gs.consequence_queue:
		order.append(str((row as Dictionary)["queue_id"]))
	_expect_str("the retaliation queue restores its order", str(order),
		str(["ret:1", "ret:2", "ret:3"]))
	_expect_int("a queued row restores its trigger day",
		int((gs.consequence_queue[0] as Dictionary)["trigger_day"]), 14)
	_expect_int("a queued row restores its expiry",
		int((gs.consequence_queue[0] as Dictionary)["expires_end_day"]), 17)
	_expect_str("a queued row restores its actor",
		str((gs.consequence_queue[0] as Dictionary)["actor_id"]), "goodie")
	_expect_str("an expired row keeps its status",
		str((gs.consequence_queue[2] as Dictionary)["status"]), "expired")
	# TI-003 §15: one delayed blocking consequence per day, enforced across a
	# reload — which needs the day it last happened to survive.
	_expect_int("the delayed-surface day survives a reload",
		int(gs.last_blocking_delayed_day), 12)

	# A queue row alongside an ACTIVE chain: the "retaliation due while another
	# chain is active" shape. Both have to coexist in one payload.
	_stage_run(gs)
	gs.active_consequence = {"cause_id": "cause:00000142", "stage": "decision",
		"chain_kind": "boost_caught"}
	gs.consequence_queue = [{"queue_id": "ret:1", "actor_id": "goodie",
		"trigger_day": 12, "expires_end_day": 15, "status": "pending"}]
	_roundtrip(gs, saves, "queue behind an active chain")
	_expect_true("an active chain and a waiting queue both survive",
		not gs.active_consequence.is_empty() and gs.consequence_queue.size() == 1)

	# --- 8. District Pressure with a pending bleed ---
	_stage_run(gs)
	gs.district_pressure = {
		"north_star_lot": {
			"stick": {"score": 6.5, "last_gain_day": 12, "quiet_days": 0,
				"market_gain_day": -1, "market_gain_today": 0.0},
			"boost": {"score": 2.0, "last_gain_day": 10, "quiet_days": 2,
				"market_gain_day": -1, "market_gain_today": 0.0},
		},
		"downtown": {
			"market": {"score": 9.0, "last_gain_day": 12, "quiet_days": 0,
				"market_gain_day": 12, "market_gain_today": 1.0},
		},
	}
	gs.pressure_bleed_pending = [
		{"cause_id": "cause:00000142", "to_district": "downtown", "family": "stick",
		 "amount": 0.5, "due_day": 13},
		{"cause_id": "cause:00000142", "to_district": "airport_industrial",
		 "family": "stick", "amount": 0.5, "due_day": 13},
	]
	_roundtrip(gs, saves, "district pressure")
	# The fractional score is the point: Pressure bands are keyed on it and an
	# int coercion would move a 6.5 WATCHED into a different band entirely.
	_expect_float("a Pressure score survives a reload as a float",
		float(((gs.district_pressure["north_star_lot"] as Dictionary)["stick"] as Dictionary)["score"]),
		6.5)
	_expect_float("a second family's Pressure survives independently",
		float(((gs.district_pressure["north_star_lot"] as Dictionary)["boost"] as Dictionary)["score"]),
		2.0)
	_expect_int("a quiet-day count survives a reload",
		int(((gs.district_pressure["north_star_lot"] as Dictionary)["boost"] as Dictionary)["quiet_days"]),
		2)
	_expect_float("the Market daily cap counter survives a reload",
		float(((gs.district_pressure["downtown"] as Dictionary)["market"] as Dictionary)["market_gain_today"]),
		1.0)
	# TI-003 §8: bleed rows carry Cause + destination identity so a reload cannot
	# double-apply them. Both halves of that identity have to come back.
	_expect_int("the bleed queue restores every row", gs.pressure_bleed_pending.size(), 2)
	_expect_str("a bleed row restores its cause",
		str((gs.pressure_bleed_pending[0] as Dictionary)["cause_id"]), "cause:00000142")
	_expect_str("a bleed row restores its destination",
		str((gs.pressure_bleed_pending[1] as Dictionary)["to_district"]), "airport_industrial")
	# TI-003 regression #16: District Pressure and Global Heat sharing storage.
	gs.heat = 3.0
	saves.save_run()
	gs.heat = 11.0
	_expect_true("pressure/heat separation reloads", saves.load_run())
	_expect_float("global Heat is stored apart from District Pressure",
		float(gs.heat), 3.0)
	_expect_float("District Pressure is unmoved by global Heat",
		float(((gs.district_pressure["downtown"] as Dictionary)["market"] as Dictionary)["score"]),
		9.0)

	# --- 9. Financial Pressure >= 6, the fold threshold ---
	_stage_run(gs)
	gs.financial_pressure = 6
	_roundtrip(gs, saves, "financial pressure")
	_expect_int("Financial Pressure at the fold threshold survives a reload",
		int(gs.financial_pressure), 6)
	# And at the cap, which is the other boundary FS-003.9 will read.
	_stage_run(gs)
	gs.financial_pressure = 10
	_roundtrip(gs, saves, "financial pressure cap")
	_expect_int("Financial Pressure at the cap survives a reload",
		int(gs.financial_pressure), 10)

	# --- 10. A mixed Clean/Dirty wallet ---
	_stage_run(gs)
	gs.dirty_cash = 640
	gs.clean_cash = 285
	gs.cash = 925
	_roundtrip(gs, saves, "mixed wallet")
	_expect_int("a mixed wallet restores dirty", int(gs.dirty_cash), 640)
	_expect_int("a mixed wallet restores clean", int(gs.clean_cash), 285)
	_expect_int("a mixed wallet restores the visible total", int(gs.cash), 925)
	var wallet: RefCounted = gm.system("wallet") as RefCounted
	_expect_true("a reloaded wallet is balanced", wallet.is_balanced())
	# The reload must not reclassify. This is the exact case the load-time
	# classifier would break if it ran unconditionally rather than only where
	# provenance is absent — dirty money laundered by its own save file.
	_expect_true("a reload does not launder dirty money", int(gs.dirty_cash) > 0)

	# --- 11. Prior arrest history ---
	_stage_run(gs)
	gs.arrest_record = {
		"priors": 2, "last_arrest_day": 11,
		"charges": [
			{"cause_id": "cause:00000100", "day": 6, "severity": "boost_t1",
			 "source_family": "boost", "source_target_id": "corner_store",
			 "bail_quote": 150, "paid": 150, "processing_slots": 1, "heat_relief": 2},
			{"cause_id": "cause:00000142", "day": 11, "severity": "stick_t2",
			 "source_family": "stick", "source_target_id": "goodie_stash",
			 "bail_quote": 900, "paid": 0, "processing_slots": 3, "heat_relief": 4},
		],
	}
	_roundtrip(gs, saves, "arrest record")
	_expect_int("priors survive a reload", int(gs.arrest_record["priors"]), 2)
	_expect_int("the last arrest day survives a reload",
		int(gs.arrest_record["last_arrest_day"]), 11)
	_expect_int("every charge survives a reload",
		(gs.arrest_record["charges"] as Array).size(), 2)
	_expect_str("a charge restores its cause",
		str(((gs.arrest_record["charges"] as Array)[1] as Dictionary)["cause_id"]),
		"cause:00000142")
	_expect_int("an unpaid charge restores its zero payment",
		int(((gs.arrest_record["charges"] as Array)[1] as Dictionary)["paid"]), 0)

	# --- 12. Persistent Boost bans. TI-003 regression #11. ---
	_stage_run(gs)
	gs.boost_store_bans = ["corner_store", "northern_value"]
	_roundtrip(gs, saves, "boost bans")
	_expect_str("Boost bans survive a reload", str(gs.boost_store_bans),
		str(["corner_store", "northern_value"]))
	# Regression #11 is "bans disappear on day-cross OR reload", so the day-cross
	# half is asserted too — through a real dispatch, on the loaded state.
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	_expect_true("the night dispatches over a ban", gm.dispatch("advance_time", {}))
	_expect_str("Boost bans survive a day-cross", str(gs.boost_store_bans),
		str(["corner_store", "northern_value"]))

	# --- the empty case, which is what most saves are ---
	#
	# Round-tripping only POPULATED shapes would miss a default that fails to
	# serialise, and every save before FS-003.7 is the empty one.
	_stage_run(gs)
	_roundtrip(gs, saves, "empty consequence state")
	_expect_true("an empty active chain round-trips", gs.active_consequence.is_empty())
	_expect_true("an empty queue round-trips", gs.consequence_queue.is_empty())
	_expect_true("an empty history round-trips", gs.consequence_history.is_empty())
	_expect_true("empty Boost bans round-trip", gs.boost_store_bans.is_empty())
	_expect_true("empty District Pressure round-trips", gs.district_pressure.is_empty())
	_expect_int("an empty arrest record round-trips",
		int(gs.arrest_record["priors"]), 0)

## A run that is safe to save: named, reset, and mid-week.
func _stage_run(gs: Node) -> void:
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 12
	gs.time_slots_today = 2
	gs.time_slot = "EVENING"

## Save, wipe every consequence field, reload. The wipe is what stops a "restored"
## assertion from passing on state the test never actually removed.
func _roundtrip(gs: Node, saves: Node, label: String) -> void:
	saves.save_run()
	gs.active_consequence = {}
	gs.consequence_history = {}
	gs.consequence_queue = []
	gs.last_blocking_delayed_day = -99
	gs.arrest_record = {"priors": -1, "last_arrest_day": -99, "charges": []}
	gs.boost_store_bans = []
	gs.district_pressure = {}
	gs.pressure_bleed_pending = []
	gs.next_cause_sequence = -1
	gs.next_consequence_sequence = -1
	gs.financial_pressure = -1
	gs.dirty_cash = -1
	gs.clean_cash = -1
	gs.cash = -1
	gs.day = 1
	_expect_true("%s reloads" % label, saves.load_run())

## TI-003 §1 and §26: "Save data carries stable IDs and state facts, never Object
## references", and "Runtime adapter registries stay outside persisted state."
##
## Checked against the serialised text rather than the live Dictionary, because
## the failure mode is a payload that writes an Object and reads back as
## something else — which the in-memory copy would never show.
func _check_v8_save_carries_no_objects(gs: Node, gm: Node, saves: Node) -> void:
	_stage_run(gs)
	# A chain shaped the way FS-003.5 will write one: it names its source by
	# adapter ID, which is the whole point of the rule.
	gs.active_consequence = {
		"cause_id": "cause:00000142", "chain_kind": "boost_caught",
		"stage": "decision",
		"source": {"family": "boost", "action_id": "boost", "target_id": "corner_store"},
	}
	gs.consequence_history = {"cause:00000142": {
		"effect_receipts": ["boost_caught:heat", "boost_caught:pressure"],
		"resolved_consequence_ids": ["consequence:00000143"],
		"scheduled_actor_ids": ["goodie"],
	}}
	saves.save_run()

	var file := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("save inspection", "could not read the save back")
		return
	var text: String = file.get_as_text()
	file.close()

	# `var_to_str` writes an Object as `Object(...)` and a node path as
	# `NodePath(...)`. Either in the payload means a runtime handle was
	# serialised, which is the thing FS-001.7's adapter fix established must
	# never happen.
	_expect_true("the save carries no Object references", not "Object(" in text)
	_expect_true("the save carries no NodePath references", not "NodePath(" in text)
	# The adapter registry lives on the engine, not in state. Named explicitly
	# because a later slice adding `"adapters"` to a persisted chain is exactly
	# the regression TI-003 #38 describes.
	_expect_true("the save carries no source-adapter registry",
		not "source_adapters" in text)
	# And the facts that REPLACE those references are present, so this is not
	# passing by saving nothing at all.
	_expect_true("the save carries the source adapter's id instead",
		"\"action_id\"" in text or "action_id" in text)
	_expect_true("the save carries the receipt keys",
		"boost_caught:heat" in text)

	# Receipts round-trip as the exactly-once ledger they are.
	_roundtrip(gs, saves, "receipt history")
	var receipts: Array = (gs.consequence_history["cause:00000142"] as Dictionary)["effect_receipts"]
	_expect_str("effect receipts survive a reload", str(receipts),
		str(["boost_caught:heat", "boost_caught:pressure"]))
	_expect_str("scheduled actor ids survive a reload",
		str((gs.consequence_history["cause:00000142"] as Dictionary)["scheduled_actor_ids"]),
		str(["goodie"]))

## FS-003.5 — the ConsequenceEngine, and the navigation it blocks.
##
## ## What this section deliberately does NOT re-cover
##
## FS-003.4 already round-trips every consequence field, including the active
## chain at each stage (`_check_v8_roundtrips`). That persistence is not
## re-asserted; what is asserted here is that the ENGINE reads a reloaded chain
## correctly — the stage machine, the projections, and the route guard.
##
## What is new:
##
##   1. chain lifecycle: open, refuse a second, advance, clear;
##   2. the declared stage machine, including every transition it refuses;
##   3. receipt idempotency, which is the whole exactly-once guarantee;
##   4. the adapter registry surviving a load without ever being serialised;
##   5. the route guard, from every ordinary screen path;
##   6. committed controls staying disabled across a reload;
##   7. dispatch revalidation of identity, stage and allowed choice.
func _check_consequence_engine() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var engine: RefCounted = gm.system("consequence") as RefCounted
	if engine == null:
		_fail("consequence engine", "not registered")
		return
	_check_engine_identity(gs, engine)
	_check_engine_receipts(gs, engine)
	_check_engine_chain_lifecycle(gs, engine)
	_check_engine_stage_machine(gs, engine)
	_check_engine_projections(gs, engine)
	_check_engine_queue(gs, engine)
	_check_engine_adapters(gs, gm, engine)
	_check_engine_dispatch_validation(gs, gm, engine)
	_check_blocking_route_guard(gs, gm)
	_check_engine_reload(gs, gm, engine)
	_check_engine_rng_non_drift(gs, gm, engine)
	gs.reset_to_new_game()

## A clean run with no chain open.
func _engine_ready(gs: Node) -> void:
	gs.street_name = "Parity"
	gs.reset_to_new_game()
	gs.day = 12
	gs.time_slots_today = 1
	gs.time_slot = "AFTERNOON"
	gs.current_district_id = "north_star_lot"
	gs.cash = 2000
	gs.clean_cash = 2000
	gs.dirty_cash = 0

## An authored chain spec, shaped the way FS-003.7 will build one.
func _caught_spec() -> Dictionary:
	return {
		"district_id": "downtown",
		"return_route": "BOOST",
		"source": {
			"family": "boost", "action_id": "boost", "target_id": "corner_store",
			"target_tier": 2, "source_day": 12, "source_slot": 1,
			"source_rng_key": "boost:12:1:corner_store",
			"pre_encounter_heat": 6.0, "contested_take": 180,
		},
		"decision": {
			"definition_id": "boost_caught",
			"allowed_choices": ["fight", "run", "talk", "yield"],
			"deterministic_choices": ["yield"],
			"resolver_inputs": {"combat": 3, "charisma": 2},
			"shown_probabilities": {"fight": 0.42, "run": 0.55, "talk": 0.31},
		},
	}

## TI-003 §4: Cause allocation is sequential and uses zero randomness.
func _check_engine_identity(gs: Node, engine: RefCounted) -> void:
	_engine_ready(gs)
	_expect_int("cause allocation starts from zero", int(gs.next_cause_sequence), 0)
	# The literal format, pinned. RNG keys are built from the Cause id, so its
	# shape is a contract rather than a display choice.
	_expect_str("the first cause id", engine.allocate_cause_id(), "cause:00000001")
	_expect_str("the second cause id", engine.allocate_cause_id(), "cause:00000002")
	_expect_int("cause allocation advances the counter", int(gs.next_cause_sequence), 2)
	_expect_str("consequence ids are their own sequence",
		engine.allocate_consequence_id(), "consequence:00000001")
	# Zero randomness: TI-003 §4 says so explicitly, and a Cause that renumbered
	# on reload would reroll its own outcome.
	_engine_ready(gs)
	gs.rng_state = 555
	engine.allocate_cause_id()
	engine.allocate_consequence_id()
	_expect_int("id allocation draws no RNG", int(gs.rng_state), 555)

## The exactly-once ledger. TI-003 §4.
func _check_engine_receipts(gs: Node, engine: RefCounted) -> void:
	_engine_ready(gs)
	var cause := "cause:00000042"
	_expect_true("an unclaimed effect reports no receipt",
		not engine.has_receipt(cause, "boost_caught:heat"))
	# The contract: the FIRST claim returns true, and that return is what a
	# caller branches on before mutating.
	_expect_true("claiming an effect the first time succeeds",
		engine.record_receipt(cause, "boost_caught:heat"))
	_expect_true("a claimed effect reports its receipt",
		engine.has_receipt(cause, "boost_caught:heat"))
	# TI-003 acceptance: "duplicate receipt attempts become no-ops".
	_expect_true("claiming the same effect twice is refused",
		not engine.record_receipt(cause, "boost_caught:heat"))
	_expect_int("a duplicate claim does not grow the ledger",
		(engine.receipts_for(cause) as Array).size(), 1)

	# Different effects under one Cause are independent — the reason this is a
	# keyed ledger rather than a boolean.
	_expect_true("a second effect under the same cause is its own claim",
		engine.record_receipt(cause, "boost_caught:pressure"))
	_expect_int("the ledger holds both effects",
		(engine.receipts_for(cause) as Array).size(), 2)
	# And the same key under a DIFFERENT Cause is a different claim, or a second
	# stickup could never charge heat again.
	_expect_true("the same effect under another cause is claimable",
		engine.record_receipt("cause:00000043", "boost_caught:heat"))

	_expect_true("an empty cause id claims nothing", not engine.record_receipt("", "x"))
	_expect_true("an empty key claims nothing", not engine.record_receipt(cause, ""))

	# Resolved-consequence and scheduled-actor ledgers follow the same rule.
	_expect_true("a resolved consequence records once",
		engine.record_resolved(cause, "consequence:00000050"))
	_expect_true("a resolved consequence does not record twice",
		not engine.record_resolved(cause, "consequence:00000050"))
	_expect_true("a scheduled actor records once",
		engine.record_scheduled_actor(cause, "goodie"))
	_expect_true("a scheduled actor does not record twice",
		not engine.record_scheduled_actor(cause, "goodie"))
	_expect_true("a scheduled actor is readable back",
		engine.has_scheduled_actor(cause, "goodie"))

## Open, refuse a second, clear.
func _check_engine_chain_lifecycle(gs: Node, engine: RefCounted) -> void:
	_engine_ready(gs)
	_expect_true("nothing is blocking at rest", not engine.has_active())
	var opened: Dictionary = engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	_expect_true("a chain opens", bool(opened["ok"]))
	_expect_true("an opened chain is active", engine.has_active())
	_expect_str("a new chain starts at the decision stage",
		engine.active_stage(), engine.STAGE_DECISION)
	_expect_str("a new chain allocates a cause", engine.active_cause_id(), "cause:00000001")
	_expect_str("a new chain allocates a consequence id",
		engine.active_consequence_id(), "consequence:00000001")
	_expect_int("a new chain stamps the day",
		int((engine.active() as Dictionary)["created_day"]), 12)
	# The source slot is owed from the moment the chain opens. TI-003 §12: a
	# non-arrest result keeps it unsettled until Continue.
	_expect_true("a new chain owes its source time", engine.source_time_owed())

	# TI-003 §10: exactly one. A second caller is a bug, not a queue request.
	var second: Dictionary = engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	_expect_true("a second chain is refused", not bool(second["ok"]))
	_expect_str("the first chain is untouched by the refusal",
		engine.active_consequence_id(), "consequence:00000001")

	# An unknown kind cannot open a chain nothing could ever resolve.
	_engine_ready(gs)
	var bogus: Dictionary = engine.open_chain("not_a_kind", _caught_spec())
	_expect_true("an unknown chain kind is refused", not bool(bogus["ok"]))
	_expect_true("a refused kind opens nothing", not engine.has_active())

	# Clearing frees the slot and leaves the history behind — which is what makes
	# a Cause's effects un-repeatable after the chain is gone.
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	var cleared_cause: String = engine.active_cause_id()
	engine.record_receipt(cleared_cause, "boost_caught:heat")
	engine.clear_chain()
	_expect_true("clearing frees the blocking slot", not engine.has_active())
	_expect_true("clearing keeps the receipt ledger",
		engine.has_receipt(cleared_cause, "boost_caught:heat"))
	_expect_true("clearing records the consequence as resolved",
		"consequence:00000001" in
		((gs.consequence_history[cleared_cause] as Dictionary)["resolved_consequence_ids"] as Array))

	# Source time settles exactly once. TI-003 regression #12.
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	_expect_true("source time settles the first time", engine.settle_source_time())
	_expect_true("settled source time is no longer owed", not engine.source_time_owed())
	_expect_true("source time does not settle twice", not engine.settle_source_time())

## Every declared transition, and every one that is refused.
##
## Walked as a full matrix rather than as the happy path: the refusals are the
## contract, and a stage machine that allows everything passes a happy-path test.
func _check_engine_stage_machine(gs: Node, engine: RefCounted) -> void:
	var stages: Array = [engine.STAGE_DECISION, engine.STAGE_RESULT,
		engine.STAGE_BOOKING, engine.STAGE_RELEASE]
	# The authored table, pinned as literals rather than read from the constant
	# the code uses — deriving it from `STAGE_TRANSITIONS` would pass whatever
	# that table said.
	var allowed := {
		"decision": ["result"],
		"result": ["booking"],
		"booking": ["release"],
		"release": [],
	}
	for from_stage in stages:
		for to_stage in stages:
			_engine_ready(gs)
			engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
			gs.active_consequence["stage"] = from_stage
			var result: Dictionary = engine.advance_stage(str(to_stage))
			var should_pass: bool = str(to_stage) in (allowed[from_stage] as Array)
			_expect_true("stage %s -> %s is %s" % [from_stage, to_stage,
				"allowed" if should_pass else "refused"],
				bool(result["ok"]) == should_pass)
			# A refused transition must leave the stage where it was — a machine
			# that refuses and moves anyway is worse than one that allows.
			_expect_str("stage %s -> %s leaves the stage %s" % [from_stage, to_stage,
				"advanced" if should_pass else "unchanged"],
				engine.active_stage(), str(to_stage) if should_pass else str(from_stage))

	# With nothing open there is nothing to advance.
	_engine_ready(gs)
	_expect_true("advancing with no chain is refused",
		not bool((engine.advance_stage(engine.STAGE_RESULT) as Dictionary)["ok"]))

## TI-003 §18: the UI consumes projections only.
func _check_engine_projections(gs: Node, engine: RefCounted) -> void:
	_engine_ready(gs)
	_expect_true("an empty summary when nothing is open",
		(engine.active_summary() as Dictionary).is_empty())
	_expect_true("no choices when nothing is open",
		(engine.choice_summaries() as Array).is_empty())

	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	var summary: Dictionary = engine.active_summary()
	_expect_str("the summary carries the chain kind",
		str(summary["chain_kind"]), "boost_caught")
	_expect_str("the summary carries the stage", str(summary["stage"]), "decision")
	_expect_str("the summary carries the target",
		str(summary["source_target_id"]), "corner_store")
	_expect_int("the summary carries the contested take",
		int(summary["contested_take"]), 180)
	_expect_float("the summary carries pre-encounter heat",
		float(summary["pre_encounter_heat"]), 6.0)
	_expect_str("the summary carries the return route",
		str(summary["return_route"]), "BOOST")

	# The projection is a COPY. A screen that mutated what it was handed would be
	# writing to GameState through a projection, which is the whole thing §18
	# forbids — and it would not go through a dispatch, so nothing would save it.
	var rows: Array = engine.choice_summaries()
	_expect_int("every allowed choice gets a row", rows.size(), 4)
	var first: Dictionary = rows[0]
	first["label"] = "MUTATED"
	var rows_again: Array = engine.choice_summaries()
	_expect_str("mutating a projection does not change the chain",
		str((rows_again[0] as Dictionary)["label"]), "Fight")

	# Odds come from the chain, so a reload shows the numbers the player decided
	# on rather than odds re-derived against state that has since moved.
	var run_row: Dictionary = _choice_row(rows, "run")
	_expect_float("a rolled choice carries its shown odds",
		float(run_row["success_probability"]), 0.55)
	_expect_true("a rolled choice reports that it has odds", bool(run_row["has_odds"]))
	_expect_true("a rolled choice is not deterministic",
		not bool(run_row["deterministic"]))
	# Yield is deterministic — TI-003 §12: "Yield uses Pressure +1.0 and consumes
	# zero RNG." Showing it as 0% would read as impossible.
	var yield_row: Dictionary = _choice_row(rows, "yield")
	_expect_true("yield is deterministic", bool(yield_row["deterministic"]))
	_expect_true("yield shows no odds", not bool(yield_row["has_odds"]))

	# Nothing is committed yet, so nothing is disabled.
	for entry in rows:
		_expect_true("choice %s starts enabled" % str((entry as Dictionary)["choice_id"]),
			not bool((entry as Dictionary)["disabled"]))

	# Booking and result projections are empty until their stages fill them.
	_expect_true("no booking quote before booking",
		(engine.booking_summary() as Dictionary).is_empty())
	_expect_str("no committed choice before one is made",
		str((engine.result_summary() as Dictionary)["committed_choice"]), "")

	# The two projections that hand back a nested authored Dictionary must hand
	# back a COPY of it. `choice_summaries` builds its rows fresh so aliasing is
	# not reachable there — these two are where dropping `.duplicate(true)` is a
	# realistic edit, and where a screen could otherwise write into the chain
	# without a dispatch and without anything saving it.
	gs.active_consequence["booking"] = {"bail_quote": 375, "processing_slots": 2}
	var quote: Dictionary = engine.booking_summary()
	quote["bail_quote"] = 1
	_expect_int("the booking projection is a copy",
		int((engine.booking_summary() as Dictionary)["bail_quote"]), 375)

	(gs.active_consequence["decision"] as Dictionary)["result"] = {"heat": 2.0}
	var outcome: Dictionary = (engine.result_summary() as Dictionary)["result"]
	outcome["heat"] = 99.0
	_expect_float("the result projection is a copy",
		float(((engine.result_summary() as Dictionary)["result"] as Dictionary)["heat"]), 2.0)

	# And the queue snapshot, for the same reason: a caller that sorted what it
	# was handed would reorder the real queue.
	gs.consequence_queue = [{"queue_id": "a"}, {"queue_id": "b"}]
	var snapshot: Array = engine.queue_snapshot()
	snapshot.reverse()
	_expect_str("the queue snapshot is a copy",
		str((gs.consequence_queue[0] as Dictionary)["queue_id"]), "a")

func _choice_row(rows: Array, choice_id: String) -> Dictionary:
	for entry in rows:
		if str((entry as Dictionary)["choice_id"]) == choice_id:
			return entry
	return {}

## TI-003 §15's arbitration, as far as .5 builds it.
func _check_engine_queue(gs: Node, engine: RefCounted) -> void:
	_engine_ready(gs)
	var base := {
		"queue_id": "ret:1", "cause_id": "cause:00000100", "actor_id": "goodie",
		"district_id": "north_star_lot", "trigger_day": 14, "expires_end_day": 17,
		"encounter_definition_id": "retaliation_street_crew",
	}
	_expect_true("a delayed consequence queues", bool((engine.enqueue(base) as Dictionary)["ok"]))
	_expect_int("the queue holds it", gs.consequence_queue.size(), 1)
	# Dedupe on (actor_id, cause_id), TI-003 §15.
	_expect_true("the same actor and cause does not queue twice",
		not bool((engine.enqueue(base) as Dictionary)["ok"]))
	_expect_int("a deduped enqueue does not grow the queue", gs.consequence_queue.size(), 1)
	# A different actor under the same Cause is a separate entry.
	var other: Dictionary = base.duplicate(true)
	other["queue_id"] = "ret:2"
	other["actor_id"] = "till_crew"
	_expect_true("a different actor under the same cause queues",
		bool((engine.enqueue(other) as Dictionary)["ok"]))
	_expect_int("the queue holds both", gs.consequence_queue.size(), 2)

	# --- eligibility ---
	_engine_ready(gs)
	gs.consequence_queue = []
	# Deliberately enqueued OUT of the order they should surface in, so a check
	# that passes cannot be reading insertion order.
	engine.enqueue({"queue_id": "late", "cause_id": "c:3", "actor_id": "c",
		"district_id": "north_star_lot", "trigger_day": 14, "expires_end_day": 20,
		"created_sequence": 1})
	engine.enqueue({"queue_id": "early", "cause_id": "c:1", "actor_id": "a",
		"district_id": "north_star_lot", "trigger_day": 12, "expires_end_day": 20,
		"created_sequence": 9})
	engine.enqueue({"queue_id": "tie", "cause_id": "c:2", "actor_id": "b",
		"district_id": "north_star_lot", "trigger_day": 12, "expires_end_day": 20,
		"created_sequence": 2})
	engine.enqueue({"queue_id": "elsewhere", "cause_id": "c:4", "actor_id": "d",
		"district_id": "downtown", "trigger_day": 12, "expires_end_day": 20,
		"created_sequence": 3})
	engine.enqueue({"queue_id": "not_yet", "cause_id": "c:5", "actor_id": "e",
		"district_id": "north_star_lot", "trigger_day": 99, "expires_end_day": 120,
		"created_sequence": 4})

	var eligible: Array = engine.eligible_queued(14, "north_star_lot")
	var ids: Array = []
	for row in eligible:
		ids.append(str((row as Dictionary)["queue_id"]))
	# TI-003 §15: sort by trigger_day, then created_sequence. `tie` and `early`
	# share day 12, so `tie` (sequence 2) comes before `early` (sequence 9) —
	# which is also the opposite of insertion order, so this cannot pass by
	# accident. TI-003 regression #32.
	_expect_str("eligible rows sort by trigger day then sequence", str(ids),
		str(["tie", "early", "late"]))
	# Regression #29: retaliation does not follow the player across districts.
	_expect_true("a row in another district is not eligible", not "elsewhere" in ids)
	_expect_true("a row before its trigger day is not eligible", not "not_yet" in ids)

	# Expiry. TI-003 §15: a retaliation avoided through its whole window expires.
	_expect_int("nothing has expired yet", engine.expire_stale(14), 0)
	_expect_int("the window closes on day 21", engine.expire_stale(21), 4)
	_expect_true("an expired row is no longer eligible",
		(engine.eligible_queued(21, "north_star_lot") as Array).is_empty())
	# Expiring twice is a no-op, not a second count.
	_expect_int("expiring again expires nothing", engine.expire_stale(22), 0)

	# Suppression. TI-003 §15: an arrest removes the same Cause's retaliation.
	_engine_ready(gs)
	gs.consequence_queue = []
	engine.enqueue({"queue_id": "a", "cause_id": "cause:1", "actor_id": "x",
		"district_id": "north_star_lot", "trigger_day": 12, "expires_end_day": 20})
	engine.enqueue({"queue_id": "b", "cause_id": "cause:1", "actor_id": "y",
		"district_id": "north_star_lot", "trigger_day": 12, "expires_end_day": 20})
	engine.enqueue({"queue_id": "c", "cause_id": "cause:2", "actor_id": "z",
		"district_id": "north_star_lot", "trigger_day": 12, "expires_end_day": 20})
	_expect_int("arrest suppresses every row for its cause",
		engine.suppress_cause("cause:1"), 2)
	_expect_int("suppression leaves other causes alone", gs.consequence_queue.size(), 1)
	_expect_str("the surviving row belongs to the other cause",
		str((gs.consequence_queue[0] as Dictionary)["cause_id"]), "cause:2")

	# --- the daily allowance ---
	_engine_ready(gs)
	_expect_true("a delayed consequence may surface on a free day",
		engine.can_surface_delayed(12))
	engine.mark_delayed_surfaced(12)
	_expect_true("only one delayed consequence surfaces per day",
		not engine.can_surface_delayed(12))
	_expect_true("the next day is free again", engine.can_surface_delayed(13))
	# TI-003 regression #27: retaliation must not surface during Caught or
	# Booking. An occupied blocking slot is what prevents it.
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	_expect_true("nothing surfaces while a chain is active",
		not engine.can_surface_delayed(12))

## TI-003 §1 and §26: adapters are runtime, re-registered on boot, never saved.
func _check_engine_adapters(gs: Node, gm: Node, engine: RefCounted) -> void:
	# GameManager registered these in `_ready()`, which runs on every boot
	# including after a load. That is the mechanism the whole rule rests on.
	_expect_str("the source adapters registered at boot",
		str(engine.registered_adapter_ids()), str(["boost", "stickup"]))
	_expect_true("the boost adapter resolves to a system",
		engine.source_adapter("boost") != null)
	_expect_true("the boost adapter is the boost system",
		engine.source_adapter("boost") == gm.system("boost"))
	_expect_true("the stickup adapter is the stickup system",
		engine.source_adapter("stickup") == gm.system("stickup"))
	# An unknown id resolves to null rather than erroring — a chain can outlive
	# an adapter if a save is loaded by a build that no longer registers it, and
	# that has to read as "cannot act".
	_expect_true("an unknown adapter id resolves to null",
		engine.source_adapter("no_such_source") == null)

	# The chain names its source by String, which is the only reason it can be
	# serialised at all.
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	var action_id: String = str(((engine.active() as Dictionary)["source"] as Dictionary)["action_id"])
	_expect_str("a chain names its source by id", action_id, "boost")
	_expect_true("that id resolves back to the live system",
		engine.source_adapter(action_id) == gm.system("boost"))

## TI-003 §12's revalidation, driven through the real dispatch path.
func _check_engine_dispatch_validation(gs: Node, gm: Node, engine: RefCounted) -> void:
	# With nothing open, the action is refused rather than crashing.
	_engine_ready(gs)
	_expect_true("committing with no chain open is refused",
		not gm.dispatch("resolve_consequence_choice", {"choice_id": "run"}))

	# Identity. A button rendered before a reload must be refused, not honoured
	# against whatever chain happens to be open now.
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	_expect_true("a stale consequence id is refused",
		not gm.dispatch("resolve_consequence_choice", {
			"consequence_id": "consequence:99999999", "choice_id": "run"}))
	_expect_true("a stale cause id is refused",
		not gm.dispatch("resolve_consequence_choice", {
			"cause_id": "cause:99999999", "choice_id": "run"}))
	# A refused commit must leave the decision open.
	_expect_str("a refused commit leaves nothing committed",
		str((engine.result_summary() as Dictionary)["committed_choice"]), "")

	# Allowed choice.
	_expect_true("a choice that is not offered is refused",
		not gm.dispatch("resolve_consequence_choice", {"choice_id": "bribe"}))
	_expect_true("an empty choice is refused",
		not gm.dispatch("resolve_consequence_choice", {"choice_id": ""}))

	# The commit itself, with matching identity.
	var summary: Dictionary = engine.active_summary()
	_expect_true("a valid commit dispatches", gm.dispatch("resolve_consequence_choice", {
		"consequence_id": str(summary["consequence_id"]),
		"cause_id": str(summary["cause_id"]),
		"choice_id": "run"}))
	_expect_str("the commit is recorded",
		str((engine.result_summary() as Dictionary)["committed_choice"]), "run")
	# The committed-choice receipt is what makes a second commit impossible.
	_expect_true("committing twice is refused",
		not gm.dispatch("resolve_consequence_choice", {"choice_id": "fight"}))
	_expect_str("the second commit did not overwrite the first",
		str((engine.result_summary() as Dictionary)["committed_choice"]), "run")

	# Stage — on a chain with NO prior commit.
	#
	# Asserting this on the chain above passed for the wrong reason: a choice was
	# already committed there, so the committed-choice receipt refused the second
	# attempt whether or not the stage was ever checked. A sabotage that deleted
	# the stage guard outright went green. The refusal has to be measured where
	# the receipt cannot also produce it.
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	engine.advance_stage(engine.STAGE_RESULT)
	_expect_str("the uncommitted chain really is past the decision stage",
		engine.active_stage(), engine.STAGE_RESULT)
	_expect_true("no choice has been committed on it",
		str((engine.result_summary() as Dictionary)["committed_choice"]).is_empty())
	_expect_true("committing outside the decision stage is refused",
		not gm.dispatch("resolve_consequence_choice", {"choice_id": "fight"}))
	_expect_true("a stage-refused commit records no receipt",
		not engine.has_receipt(engine.active_cause_id(), "boost_caught:committed_choice"))
	_expect_true("a stage-refused commit commits nothing",
		str((engine.result_summary() as Dictionary)["committed_choice"]).is_empty())

	# --- Continue, the terminal handoff ---
	#
	# TI-003 §12: "Continue settles that source slot once and clears the chain."
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	_expect_true("continue is refused at the decision stage",
		not gm.dispatch("consequence_continue", {}))
	_expect_true("a refused continue leaves the chain open", engine.has_active())

	engine.advance_stage(engine.STAGE_RESULT)
	var slots_before: int = int(gs.time_slots_today)
	_expect_true("continue dispatches from the result stage",
		gm.dispatch("consequence_continue", {}))
	_expect_true("continue clears the chain", not engine.has_active())
	# The source slot the chain was holding is finally paid.
	_expect_int("continue settles the source slot once",
		int(gs.time_slots_today), slots_before + 1)
	_expect_true("continue with nothing open is refused",
		not gm.dispatch("consequence_continue", {}))

## TI-003 §18's navigation contract: ordinary navigation cannot bypass a
## blocking consequence, and game over still outranks it.
##
## Tested through `resolved_route()` rather than by changing scenes: the routing
## decision is the contract, and driving 20 real scene changes would test
## Godot's scene loader instead.
func _check_blocking_route_guard(gs: Node, gm: Node) -> void:
	var nav := get_node("/root/ScreenManager")
	var engine: RefCounted = gm.system("consequence") as RefCounted

	# Every ordinary screen path, from the manager's own constants rather than a
	# list kept here — a screen added without a route guard is exactly the gap
	# this check exists to catch, and a hand-maintained list would not see it.
	var ordinary: Array = [
		nav.HOME, nav.STREET, nav.MARKET, nav.HUSTLE, nav.JOBS, nav.STICKUP,
		nav.SHARK, nav.LIST, nav.BOOST, nav.CREW, nav.TURF, nav.PEOPLE,
		nav.PHONE, nav.MORE, nav.HELP, nav.CHARACTER, nav.RECOVERY,
		nav.TITLE, nav.NAME_ENTRY,
	]

	# Nothing blocking: every route resolves to itself.
	_engine_ready(gs)
	_expect_str("no blocking route at rest", nav.blocking_route(), "")
	for path in ordinary:
		_expect_str("%s routes to itself when nothing blocks" % str(path).get_file(),
			nav.resolved_route(str(path)), str(path))

	# A chain open: every ordinary route is redirected.
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	_expect_str("an open chain is the blocking route",
		nav.blocking_route(), nav.CONSEQUENCE)
	for path in ordinary:
		_expect_str("%s cannot bypass an open chain" % str(path).get_file(),
			nav.resolved_route(str(path)), nav.CONSEQUENCE)
	# The blocking screen itself is not redirected to itself in a loop.
	_expect_str("the consequence scene routes to itself",
		nav.resolved_route(nav.CONSEQUENCE), nav.CONSEQUENCE)
	# And `go_to_game()` — the boot and CONTINUE RUN path — lands on the chain
	# rather than on Home. TI-003 §18: a loaded active consequence must not
	# expose an ordinary screen for an interactive frame.
	_expect_str("continuing a run re-enters the chain",
		nav.resolved_route(nav.HOME), nav.CONSEQUENCE)

	# Game over outranks a consequence. Both open at once is the case that
	# decides the priority, and routing to the consequence would strand a run
	# that has already ended.
	gs.game_over = true
	_expect_str("game over outranks an open chain",
		nav.blocking_route(), nav.GAME_OVER)
	for path in ordinary:
		_expect_str("%s routes to game over first" % str(path).get_file(),
			nav.resolved_route(str(path)), nav.GAME_OVER)
	_expect_str("game over is reachable while a chain is open",
		nav.resolved_route(nav.GAME_OVER), nav.GAME_OVER)
	gs.game_over = false

	# Game over alone still behaves as it always did.
	_engine_ready(gs)
	gs.game_over = true
	_expect_str("game over blocks on its own", nav.blocking_route(), nav.GAME_OVER)
	gs.game_over = false
	_expect_str("clearing game over unblocks", nav.blocking_route(), "")

## A chain reloaded from a save is the same chain, at the same stage, with the
## same buttons disabled.
func _check_engine_reload(gs: Node, gm: Node, engine: RefCounted) -> void:
	var saves := get_node("/root/SaveSystem")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	# Commit a choice, save, wipe, reload.
	_engine_ready(gs)
	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	var consequence_id: String = engine.active_consequence_id()
	var cause_id: String = engine.active_cause_id()
	_expect_true("the commit before the reload dispatches",
		gm.dispatch("resolve_consequence_choice", {"choice_id": "run"}))
	# FS-003.7 registered a real Boost adapter, so committing a choice on a chain
	# whose `action_id` is "boost" now resolves it and advances the stage — to
	# `result`, or to `booking` when the roll ends in an arrest. Captured rather
	# than assumed: this check is about the chain surviving a reload AT WHATEVER
	# STAGE it reached, and pinning `decision` here would be pinning the absence
	# of the adapter the next assertion goes on to prove exists.
	var stage_at_save: String = engine.active_stage()
	_expect_true("committing advanced the chain past the decision",
		stage_at_save != engine.STAGE_DECISION)
	saves.save_run()

	gs.active_consequence = {}
	gs.consequence_history = {}
	_expect_true("a chain reloads", saves.load_run())
	_expect_true("a reloaded chain is active", engine.has_active())
	_expect_str("a reloaded chain keeps its identity",
		engine.active_consequence_id(), consequence_id)
	_expect_str("a reloaded chain keeps its cause", engine.active_cause_id(), cause_id)
	_expect_str("a reloaded chain keeps its stage",
		engine.active_stage(), stage_at_save)

	# TI-003 acceptance: "committed controls remain disabled after reload."
	# The projection is what the scene reads, so this is the exact assertion the
	# button makes — and it comes from persisted state, not from a click.
	var rows: Array = engine.choice_summaries()
	for entry in rows:
		var row: Dictionary = entry
		_expect_true("choice %s stays disabled after reload" % str(row["choice_id"]),
			bool(row["disabled"]))
	_expect_true("the committed choice is still marked committed",
		bool((_choice_row(rows, "run") as Dictionary)["committed"]))
	_expect_true("an uncommitted choice is not marked committed",
		not bool((_choice_row(rows, "fight") as Dictionary)["committed"]))

	# The receipt survived, so a second commit is still refused after a reload.
	# This is the exactly-once guarantee doing the job it exists for.
	_expect_true("the committed-choice receipt survives a reload",
		engine.has_receipt(cause_id, "boost_caught:committed_choice"))
	_expect_true("committing again after a reload is refused",
		not gm.dispatch("resolve_consequence_choice", {"choice_id": "fight"}))

	# The adapter registry was NOT saved, and yet the reloaded chain resolves its
	# source — because `GameManager._ready()` rebuilt it and the chain carries a
	# String. Both halves asserted: the registry works, and the save is clean.
	_expect_true("a reloaded chain still resolves its adapter",
		engine.source_adapter(str(((engine.active() as Dictionary)["source"] as Dictionary)["action_id"])) != null)
	var file := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
	if file != null:
		var text: String = file.get_as_text()
		file.close()
		_expect_true("the chain's save carries no Object references",
			not "Object(" in text)

	# The route guard reads reloaded state, so a save loaded mid-chain blocks
	# immediately rather than after a refresh.
	var nav := get_node("/root/ScreenManager")
	_expect_str("a reloaded chain blocks navigation",
		nav.resolved_route(nav.HOME), nav.CONSEQUENCE)

	# And a save with no chain does not block.
	_engine_ready(gs)
	saves.save_run()
	gs.active_consequence = {"stage": "decision", "cause_id": "cause:00000999"}
	_expect_true("a chainless save reloads", saves.load_run())
	_expect_true("a chainless save clears the blocking slot", not engine.has_active())
	_expect_str("a chainless save does not block navigation",
		nav.resolved_route(nav.HOME), nav.HOME)

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## TI-003 §21: "TI-003 adds zero market-stream draws."
##
## The engine is pure bookkeeping — identity allocation, receipts, queue sorting
## — and none of it may touch the market cursor.
func _check_engine_rng_non_drift(gs: Node, gm: Node, engine: RefCounted) -> void:
	_engine_ready(gs)
	gs.rng_state = 987654321
	var cursor: int = int(gs.rng_state)

	engine.open_chain(engine.KIND_BOOST_CAUGHT, _caught_spec())
	engine.record_receipt(engine.active_cause_id(), "boost_caught:heat")
	engine.enqueue({"queue_id": "r", "cause_id": "c:1", "actor_id": "a",
		"district_id": "north_star_lot", "trigger_day": 12, "expires_end_day": 20})
	engine.eligible_queued(12, "north_star_lot")
	engine.expire_stale(12)
	engine.active_summary()
	engine.choice_summaries()
	gm.dispatch("resolve_consequence_choice", {"choice_id": "yield"})
	engine.advance_stage(engine.STAGE_RESULT)
	_expect_int("the consequence engine draws nothing from the market stream",
		int(gs.rng_state), cursor)

	# Continue advances time, which CAN legitimately move the cursor if it
	# crosses a day — so it is measured separately rather than folded into the
	# claim above, and the claim is the narrower true one.
	gs.time_slots_today = 0
	gm.dispatch("consequence_continue", {})
	_expect_int("continue inside a day still draws nothing", int(gs.rng_state), cursor)

## FS-003.6 — the pure odds projection.
##
## ## The one thing this section must not do
##
## `success_probability()` is derived from the shape table, the immunity filter
## and the advantage rule. A check that recomputed those three things and
## compared would be the implementation written twice, and it would agree with a
## broken projection as readily as a correct one.
##
## So the projection is measured against **the resolver actually running**.
## `_measured_success_rate` calls `resolve_action` over thousands of distinct
## keys and counts how often the tier came back a success. Nothing about that
## measurement knows the shape table exists.
##
## That is the acceptance criterion — "projection matches exhaustive resolver
## probability" — taken literally, and it is what fails if the pipeline changes
## and the projection does not.
##
## ## What is NOT re-covered
##
## The resolver's own tier behaviour is already pinned by
## `_check_outcome_resolver` against generated fixtures. Pool construction,
## `seeded_pick`, and the tier tables are not re-asserted here.

## Distinct keys per measured cell. 4000 puts the standard error at ~0.8% for a
## coin-flip cell, so the 0.03 tolerance below is comfortably over 3 sigma while
## still being tight enough to catch a wrong advantage or immunity rule — both
## of which move the answer by 10-25 points, not by 3.
##
## Deterministic despite being a sample: the same 4000 keys every run.
const PROJECTION_SAMPLES := 4000
const PROJECTION_TOLERANCE := 0.03

func _check_outcome_projection() -> void:
	var gm := get_node("/root/GameManager")
	var gs := get_node("/root/GameState")
	var resolver: RefCounted = gm.system("outcome_resolver") as RefCounted
	if resolver == null:
		_fail("outcome projection", "no resolver registered")
		return
	_check_projection_harness_is_uniform()
	_check_projection_against_resolver(resolver)
	_check_projection_identities(resolver)
	_check_projection_thresholds(resolver)
	_check_projection_edges(resolver)
	_check_tier_probabilities(resolver)
	_check_projection_rng_non_drift(gs, resolver)

## The sweep key for sample `i`.
##
## **The varying index goes at the FRONT, and that is load-bearing.**
##
## `seeded_random` is canon's `stringHash(key) / 2^32`, an FNV-1a whose
## multiplication propagates low bits upward — so a character near the END of the
## key barely moves the HIGH bits, and the high bits are exactly what dividing by
## 2^32 reads. Sweeping with the counter on the tail therefore does not sample a
## uniform distribution at all.
##
## Measured, on the first attempt at this section: 4000 keys of the shape
## `confrontation:250:0:<i>` gave mean 0.531 and P(< 0.25) = 0.188 against a true
## 0.25 — and produced four "failures" that were the harness, not the projection.
## The same 4000 indices moved to the front gave mean 0.502 and P = 0.252.
##
## This is canon's hash, bias and all (game-core.js uses the same `stringHash`),
## so it is not a defect to fix here. It is a trap to avoid: **any future check
## that sweeps a keyed roll by incrementing a trailing counter is measuring a
## skewed distribution.** `_check_projection_harness_is_uniform` below guards it.
func _projection_key(action_type: String, chance: float, raw_attribute: int,
		index: int) -> String:
	return "%d:%s:%d:%d" % [index, action_type, int(chance * 1000.0), raw_attribute]

## The instrument, checked before it is trusted.
##
## Every "projection matches the resolver" assertion is only as good as the
## uniformity of the keys it samples over. If the key family is skewed, those
## assertions fail — or worse, pass — for a reason that has nothing to do with
## the projection.
##
## So the harness measures itself first. A failure here says "the sweep is
## broken", which is a different and much more useful message than fifty
## mismatched probabilities.
func _check_projection_harness_is_uniform() -> void:
	var rng := get_node("/root/RngManager")
	var total: float = 0.0
	var below_quarter: int = 0
	var below_half: int = 0
	for i in PROJECTION_SAMPLES:
		var value: float = rng.seeded_random(
			"projection_seed", _projection_key("confrontation", 0.25, 0, i))
		total += value
		if value < 0.25:
			below_quarter += 1
		if value < 0.5:
			below_half += 1
	var mean: float = total / float(PROJECTION_SAMPLES)
	_expect_true("the projection sweep samples a uniform mean (%.4f)" % mean,
		absf(mean - 0.5) <= PROJECTION_TOLERANCE)
	_expect_true("the projection sweep samples a uniform lower quartile (%.4f)"
		% (float(below_quarter) / float(PROJECTION_SAMPLES)),
		absf(float(below_quarter) / float(PROJECTION_SAMPLES) - 0.25) <= PROJECTION_TOLERANCE)
	_expect_true("the projection sweep samples a uniform median (%.4f)"
		% (float(below_half) / float(PROJECTION_SAMPLES)),
		absf(float(below_half) / float(PROJECTION_SAMPLES) - 0.5) <= PROJECTION_TOLERANCE)

## Run the real resolver over many keys and report the observed success rate.
##
## Deliberately ignorant of everything the projection knows: it calls
## `resolve_action` and asks `is_success_tier`, which is what the game asks.
func _measured_success_rate(resolver: RefCounted, action_type: String,
		chance: float, raw_attribute: int, bonus: int) -> float:
	var hits: int = 0
	for i in PROJECTION_SAMPLES:
		var outcome: Dictionary = resolver.resolve_action(
			action_type, chance, raw_attribute, "projection_seed",
			_projection_key(action_type, chance, raw_attribute + bonus, i),
			bonus)
		if resolver.is_success_tier(str(outcome["tier"])):
			hits += 1
	return float(hits) / float(PROJECTION_SAMPLES)

## The acceptance criterion, as a matrix.
##
## Covers the three action types TI-003 §12 maps the Caught responses onto —
## `confrontation`, `escape`, `negotiation` — plus `robbery`, which has the
## heaviest catastrophic half and so moves the most under immunity.
##
## Attributes span both thresholds: 0-2 plain, 3-5 advantage, 6+ advantage AND
## immunity, and 12 to prove the top of the range behaves like 6 rather than
## wrapping.
func _check_projection_against_resolver(resolver: RefCounted) -> void:
	var actions: Array = ["confrontation", "escape", "negotiation", "robbery"]
	var chances: Array = [0.25, 0.5, 0.75]
	var attributes: Array = [0, 2, 3, 5, 6, 12]
	for action in actions:
		for chance in chances:
			for raw in attributes:
				var projected: float = resolver.success_probability(
					str(action), float(chance), int(raw), 0)
				var measured: float = _measured_success_rate(
					resolver, str(action), float(chance), int(raw), 0)
				_expect_true("projection matches the resolver: %s c=%.2f attr=%d (proj %.4f, measured %.4f)"
					% [action, chance, raw, projected, measured],
					absf(projected - measured) <= PROJECTION_TOLERANCE)

	# A bonus has to move the measured rate too, not just the projection — that
	# is what proves the projection clamps the effective level the same way
	# `resolve_action` does rather than merely agreeing with itself.
	#
	# Attribute 2 with +1 backup crosses into advantage; attribute 5 with +1
	# crosses into immunity. Both are cases where being wrong by one level is
	# visible in the number.
	for spec in [[2, 1], [5, 1], [0, 3], [11, 5]]:
		var raw: int = int((spec as Array)[0])
		var bonus: int = int((spec as Array)[1])
		var projected: float = resolver.success_probability("confrontation", 0.5, raw, bonus)
		var measured: float = _measured_success_rate(resolver, "confrontation", 0.5, raw, bonus)
		_expect_true("projection matches with bonus: attr=%d+%d (proj %.4f, measured %.4f)"
			% [raw, bonus, projected, measured],
			absf(projected - measured) <= PROJECTION_TOLERANCE)

## Two closed forms the projection must reproduce exactly, not approximately.
##
## They fall out of the shape table's structure: every shape's `success` half
## sums to 1.0 and its `failure` half sums to 1.0, so splitting a chance across
## them cannot change the success/failure ratio.
##
## Worth asserting as exact literals because the sampled matrix above can only
## ever be approximate, and these two say what the number IS.
func _check_projection_identities(resolver: RefCounted) -> void:
	# Below advantage and below immunity, the projection is the base chance.
	# The shape divides the win between clean and messy; it does not change how
	# often you win.
	for chance in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
		for action in ["confrontation", "escape", "negotiation", "robbery"]:
			_expect_float("below advantage, %s at %.2f projects the base chance"
				% [action, chance],
				resolver.success_probability(str(action), float(chance), 0, 0),
				float(chance))

	# At advantage and below immunity, two independent picks and the better one
	# wins: 1 - (1 - c)^2. Written out per row rather than computed, so this
	# pins the numbers instead of restating the formula.
	var advantage_rows := [
		[0.0, 0.0], [0.25, 0.4375], [0.5, 0.75], [0.75, 0.9375], [1.0, 1.0],
	]
	for row in advantage_rows:
		var chance: float = float((row as Array)[0])
		var want: float = float((row as Array)[1])
		_expect_float("advantage at %.2f projects %.4f" % [chance, want],
			resolver.success_probability("confrontation", chance, 3, 0), want)

	# Immunity redistributes the catastrophic weight across the survivors, which
	# RAISES the odds. `escape` has failure {failure 0.8, catastrophic 0.2}, so
	# at chance 0.5 a single pick becomes 0.5 / (0.5 + 0.5*0.8) = 0.5/0.9, and
	# advantage squares the complement of that.
	#
	# 0.5/0.9 = 0.5555...; 1 - (1 - 0.5555...)^2 = 0.8024691358...
	_expect_float("escape at 0.50 with immunity and advantage",
		resolver.success_probability("escape", 0.5, 6, 0), 1.0 - pow(1.0 - (0.5 / 0.9), 2.0))
	# And the single-pick half of that, isolated: a level with immunity but not
	# advantage is unreachable (6 > 3), so this is asserted through the same
	# call with the advantage arithmetic named rather than hidden.
	_expect_true("immunity raises the odds above the base chance",
		resolver.success_probability("escape", 0.5, 6, 0) > 0.75)

## The two thresholds are the whole design. Each must be invisible on one side
## and decisive on the other.
func _check_projection_thresholds(resolver: RefCounted) -> void:
	# Advantage: nothing at 0-2, a jump at 3, nothing again at 4-5.
	var below: float = resolver.success_probability("confrontation", 0.5, 2, 0)
	var at_advantage: float = resolver.success_probability("confrontation", 0.5, 3, 0)
	var above: float = resolver.success_probability("confrontation", 0.5, 4, 0)
	_expect_float("attribute 0 and 2 project the same", below,
		resolver.success_probability("confrontation", 0.5, 0, 0))
	_expect_true("attribute 3 projects better than 2", at_advantage > below)
	_expect_float("attribute 4 projects the same as 3", above, at_advantage)
	_expect_float("attribute 5 projects the same as 3",
		resolver.success_probability("confrontation", 0.5, 5, 0), at_advantage)

	# Immunity: a second jump at 6, then flat to the ceiling.
	var at_immunity: float = resolver.success_probability("confrontation", 0.5, 6, 0)
	_expect_true("attribute 6 projects better than 5", at_immunity > at_advantage)
	_expect_float("attribute 7 projects the same as 6",
		resolver.success_probability("confrontation", 0.5, 7, 0), at_immunity)
	_expect_float("attribute 12 projects the same as 6",
		resolver.success_probability("confrontation", 0.5, 12, 0), at_immunity)
	# Past the ceiling the clamp holds — a value the attribute system cannot
	# produce must not project differently from one it can.
	_expect_float("an attribute past the ceiling clamps",
		resolver.success_probability("confrontation", 0.5, 99, 0), at_immunity)

	# `negotiation` has no catastrophic-free path either, so it moves at 6 too;
	# `job_interview` has NO catastrophic tier at all, so immunity is a no-op
	# there. That contrast is what proves the filter reads the shape rather than
	# applying a flat bonus.
	var interview_below: float = resolver.success_probability("job_interview", 0.5, 5, 0)
	var interview_at: float = resolver.success_probability("job_interview", 0.5, 6, 0)
	_expect_float("immunity changes nothing for a shape with no catastrophic tier",
		interview_at, interview_below)
	_expect_true("immunity does change a shape that has one",
		resolver.success_probability("negotiation", 0.5, 6, 0)
			> resolver.success_probability("negotiation", 0.5, 5, 0))

	# A bonus is an effective-level modifier, so it crosses thresholds the same
	# way the attribute does. This is what makes crew backup worth something
	# specific rather than a vague nudge.
	_expect_float("a bonus crosses the advantage threshold",
		resolver.success_probability("confrontation", 0.5, 2, 1), at_advantage)
	_expect_float("a bonus crosses the immunity threshold",
		resolver.success_probability("confrontation", 0.5, 5, 1), at_immunity)

	# Above the immunity threshold and below the advantage one, the projection is
	# FLAT — an effective level of 17 reads as 6, and one of -5 reads as 0.
	#
	# Stated as flatness rather than as "the clamp works", because the clamp is
	# not independently observable here and a check claiming otherwise would be
	# claiming more than it proves: both thresholds are one-sided, so an
	# unclamped level lands in the same band as a clamped one every time. The
	# clamp stays for symmetry with `resolve_action`, which needs it because
	# `seeded_pick` indexes on the value; removing it from the projection alone
	# changes nothing, and the parity suite says so honestly.
	_expect_float("the projection is flat past the ceiling",
		resolver.success_probability("confrontation", 0.5, 12, 5), at_immunity)
	_expect_float("the projection is flat below the floor",
		resolver.success_probability("confrontation", 0.5, 0, -5),
		resolver.success_probability("confrontation", 0.5, 0, 0))

	# Monotonic in effective level: a higher attribute may never project worse.
	# That is the ordinal contract the whole advantage design rests on, and it is
	# the property the clamp exists to preserve at the edges.
	var previous: float = -1.0
	for level in range(-3, 16):
		var here: float = resolver.success_probability("confrontation", 0.5, level, 0)
		_expect_true("the projection never drops going from level %d up" % (level - 1),
			here >= previous - 1e-9)
		previous = here

	# The immunity filter keeps a pool that is nothing but catastrophic entries,
	# rather than filtering it to nothing. Canon's guard, and unreachable through
	# any authored shape — every shape has a non-catastrophic tier — so it is
	# exercised on a synthetic pool, the same way the v7 migration arm is
	# exercised at its own boundary rather than through a path that hides it.
	var all_catastrophic: Array = [
		{"tier": "catastrophic", "value": 0, "weight": 1.0},
	]
	var survived: Array = resolver._immunity_filtered(all_catastrophic, 6)
	_expect_int("an all-catastrophic pool survives the immunity filter",
		survived.size(), 1)
	# Guarded rather than indexed straight: if the filter DID empty the pool,
	# `survived[0]` would raise and abort this whole function, costing the checks
	# below it. A check that loses its neighbours on failure reports a smaller
	# green, which is the one thing MIN_CHECKS exists to make visible.
	_expect_str("and keeps its only tier",
		str((survived[0] as Dictionary)["tier"]) if not survived.is_empty() else "",
		"catastrophic")
	# A mixed pool does lose its catastrophic entry, so the guard is not simply
	# disabling the filter.
	var mixed: Array = [
		{"tier": "clean", "value": 3, "weight": 0.5},
		{"tier": "catastrophic", "value": 0, "weight": 0.5},
	]
	_expect_int("a mixed pool loses its catastrophic entry",
		(resolver._immunity_filtered(mixed, 6) as Array).size(), 1)
	_expect_int("and keeps everything below the threshold",
		(resolver._immunity_filtered(mixed, 5) as Array).size(), 2)

func _check_projection_edges(resolver: RefCounted) -> void:
	# An unknown action type resolves to a plain failure, so it projects zero.
	# The two must agree, or the screen would offer odds on something that
	# cannot succeed.
	_expect_float("an unknown action projects zero",
		resolver.success_probability("not_an_action", 0.9, 6, 0), 0.0)
	var outcome: Dictionary = resolver.resolve_action(
		"not_an_action", 0.9, 6, "seed", "ctx", 0)
	_expect_str("an unknown action resolves to failure", str(outcome["tier"]), "failure")
	_expect_true("an unknown action is not a success",
		not resolver.is_success_tier(str(outcome["tier"])))

	# Certainty at both ends, at every level.
	for raw in [0, 3, 6, 12]:
		_expect_float("a zero chance projects zero at attribute %d" % raw,
			resolver.success_probability("confrontation", 0.0, raw, 0), 0.0)
		_expect_float("a certain chance projects one at attribute %d" % raw,
			resolver.success_probability("confrontation", 1.0, raw, 0), 1.0)

	# Out-of-range chances are clamped by `build_outcome_pool`, so the projection
	# inherits that rather than reporting a probability outside [0, 1].
	_expect_float("a chance above one clamps",
		resolver.success_probability("confrontation", 1.4, 0, 0), 1.0)
	_expect_float("a negative chance clamps",
		resolver.success_probability("confrontation", -0.4, 0, 0), 0.0)
	# NaN is what a divide-by-zero in a caller's own formula produces, and
	# `build_outcome_pool` already treats it as zero.
	_expect_float("a non-finite chance projects zero",
		resolver.success_probability("confrontation", NAN, 0, 0), 0.0)

	# Every projected value is a probability, across the whole matrix.
	for action in resolver.OUTCOME_SHAPES.keys():
		for chance in [0.0, 0.33, 0.5, 0.9, 1.0]:
			for raw in [0, 3, 6, 12]:
				var p: float = resolver.success_probability(str(action), float(chance), raw, 0)
				_expect_true("%s c=%.2f attr=%d projects within [0,1]" % [action, chance, raw],
					p >= 0.0 and p <= 1.0)

## The full distribution, which the result screen reads.
func _check_tier_probabilities(resolver: RefCounted) -> void:
	for action in ["confrontation", "escape", "negotiation", "robbery"]:
		for chance in [0.0, 0.25, 0.5, 0.75, 1.0]:
			for raw in [0, 3, 6]:
				var tiers: Dictionary = resolver.tier_probabilities(
					str(action), float(chance), raw, 0)
				var total: float = 0.0
				for value in tiers.values():
					total += float(value)
				_expect_true("%s c=%.2f attr=%d tiers sum to 1" % [action, chance, raw],
					absf(total - 1.0) < 1e-9)
				# The two halves must agree with the single-number projection,
				# or the screen could show odds that contradict its own summary.
				_expect_true("%s c=%.2f attr=%d success halves agree" % [action, chance, raw],
					absf((float(tiers["clean"]) + float(tiers["messy"]))
						- resolver.success_probability(str(action), float(chance), raw, 0)) < 1e-9)

	# Immunity means catastrophic cannot happen at all — the sharpest statement
	# the distribution makes, and the one a player earns at Combat 6.
	for action in ["confrontation", "escape", "robbery"]:
		var immune: Dictionary = resolver.tier_probabilities(str(action), 0.5, 6, 0)
		_expect_float("%s at attribute 6 cannot go catastrophic" % action,
			float(immune["catastrophic"]), 0.0)
		var exposed: Dictionary = resolver.tier_probabilities(str(action), 0.5, 5, 0)
		_expect_true("%s at attribute 5 still can" % action,
			float(exposed["catastrophic"]) > 0.0)

	# And the distribution has to match the resolver too, not only sum to one.
	# Measured per tier off the real pipeline.
	var counts := {"clean": 0, "messy": 0, "failure": 0, "catastrophic": 0}
	for i in PROJECTION_SAMPLES:
		var outcome: Dictionary = resolver.resolve_action(
			"robbery", 0.5, 3, "tier_seed", _projection_key("robbery", 0.5, 3, i), 0)
		var tier := str(outcome["tier"])
		counts[tier] = int(counts[tier]) + 1
	var projected: Dictionary = resolver.tier_probabilities("robbery", 0.5, 3, 0)
	for tier in counts.keys():
		var measured: float = float(counts[tier]) / float(PROJECTION_SAMPLES)
		_expect_true("robbery attr=3 tier %s matches the resolver (proj %.4f, measured %.4f)"
			% [tier, float(projected[tier]), measured],
			absf(float(projected[tier]) - measured) <= PROJECTION_TOLERANCE)

	# An unknown action type resolves to a plain failure, so it projects one.
	var unknown: Dictionary = resolver.tier_probabilities("not_an_action", 0.5, 3, 0)
	_expect_float("an unknown action projects certain failure",
		float(unknown["failure"]), 1.0)

## TI-003 §2: the helper "consumes zero RNG".
##
## Asserted on the market cursor AND by proving the projection is referentially
## transparent — a helper that drew from a keyed hash would still leave
## `rng_state` alone while returning a different answer each call.
func _check_projection_rng_non_drift(gs: Node, resolver: RefCounted) -> void:
	gs.rng_state = 424242
	var cursor: int = int(gs.rng_state)
	var first: float = resolver.success_probability("confrontation", 0.5, 3, 0)
	for _i in 50:
		resolver.success_probability("confrontation", 0.5, 3, 0)
		resolver.tier_probabilities("robbery", 0.5, 6, 0)
	_expect_int("the projection draws nothing from the market stream",
		int(gs.rng_state), cursor)
	_expect_float("the projection returns the same answer every call",
		resolver.success_probability("confrontation", 0.5, 3, 0), first)

## FS-003.7 — Failed Boost → Caught, the first end-to-end encounter.
##
## ## Two layers, and why both
##
## **The authored rows** are checked as DATA, against FS-003 §5's tables written
## out as literals. That layer catches a transcription error — a heat value off
## by one, a ban on the wrong row — which no amount of integration testing would
## find, because the integration would simply apply the wrong number correctly.
##
## **The applied effects** are checked through `gm.dispatch`, on chains opened by
## real failed lifts. That layer catches a wiring error — the right table read
## into the wrong field, a receipt claimed but the mutation skipped.
##
## Neither layer alone is enough, and neither derives its expectation from the
## other.
##
## ## What is NOT re-covered
##
## The engine's stage machine, receipt ledger, queue and route guard are
## FS-003.5's (`_check_consequence_engine`). The odds projection is FS-003.6's.
## The initial binary lift is FS-003.1's frozen sweep. None are repeated.
func _check_boost_caught() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	var engine: RefCounted = gm.system("consequence") as RefCounted
	var boost: RefCounted = gm.system("boost") as RefCounted
	if engine == null or boost == null:
		_fail("boost caught", "systems not registered")
		return
	var rules: RefCounted = preload("res://data/consequence_rules.gd").new()
	_check_caught_authored_rows(rules)
	_check_caught_opens_on_failure(gs, gm, engine)
	_check_caught_cause_uniqueness(gs, gm, engine)
	_check_caught_decision_surface(gs, gm, engine, rules)
	_check_caught_take_provenance(gs, gm, engine, rules)
	_check_caught_effects_applied(gs, gm, engine, rules)
	_check_caught_arrest_snapshot(gs, gm, engine, rules)
	_check_caught_yield(gs, gm, engine)
	_check_caught_bans(gs, gm, engine, boost)
	_check_caught_source_time(gs, gm, engine)
	_check_caught_reload(gs, gm, engine)
	_check_caught_rng_non_drift(gs, gm, engine)
	gs.reset_to_new_game()

# --- layer 1: the authored tables ------------------------------------------

## FS-003 §5's tables, transcribed here independently of `consequence_rules.gd`.
##
## Two transcriptions of one document is the point: they were typed from the
## same source but not from each other, so a slip in either is a failure rather
## than a shared mistake. This is the same discipline the golden market boards
## use — pin recorded output, never re-derive it.
func _check_caught_authored_rows(rules: RefCounted) -> void:
	# Opponent bands, FS-003 §5.
	var bands := [
		[1, "Clerk", 0.50, 0.62, 0.65, 4, 9, 12, 20],
		[2, "Store Security", 0.30, 0.50, 0.45, 5, 10, 15, 24],
		[3, "Armed Guard", 0.15, 0.38, 0.25, 6, 12, 18, 28],
	]
	for row in bands:
		var tier: int = int((row as Array)[0])
		var band: Dictionary = rules.opponent_for(tier)
		_expect_str("tier %d opponent" % tier, str(band["opponent"]), str((row as Array)[1]))
		_expect_float("tier %d fight chance" % tier, rules.base_chance(tier, "fight"),
			float((row as Array)[2]))
		_expect_float("tier %d run chance" % tier, rules.base_chance(tier, "run"),
			float((row as Array)[3]))
		_expect_float("tier %d talk chance" % tier, rules.base_chance(tier, "talk"),
			float((row as Array)[4]))
		_expect_str("tier %d successful-fight injury band" % tier,
			str(band["fight_win"]), str([int((row as Array)[5]), int((row as Array)[6])]))
		_expect_str("tier %d lost-fight injury band" % tier,
			str(band["fight_loss"]), str([int((row as Array)[7]), int((row as Array)[8])]))

	# The response → resolver mapping, TI-003 §12.
	_expect_str("fight resolves as confrontation", rules.resolver_for("fight"), "confrontation")
	_expect_str("run resolves as escape", rules.resolver_for("run"), "escape")
	_expect_str("talk resolves as negotiation", rules.resolver_for("talk"), "negotiation")
	_expect_true("yield is deterministic", rules.is_deterministic("yield"))
	for choice in ["fight", "run", "talk"]:
		_expect_true("%s is not deterministic" % choice, not rules.is_deterministic(str(choice)))

	# Take disposition, ban and arrest per row. FS-003 §5, written out.
	# `arrest` here is the value AT TIER 1 WITH ZERO PRE-HEAT — the conditional
	# row is exercised separately below, where the condition can actually vary.
	var rows := [
		# choice, tier, take, ban, arrest@t1/heat0
		["fight", "clean", "keep", false, false],
		["fight", "messy", "keep", false, false],
		["fight", "failure", "lose", true, true],
		["fight", "catastrophic", "lose", true, true],
		["run", "clean", "keep", false, false],
		["run", "messy", "keep", false, false],
		["run", "failure", "lose", true, false],
		["run", "catastrophic", "lose", true, true],
		["talk", "clean", "return", false, false],
		["talk", "messy", "return", true, false],
		["talk", "failure", "return", true, false],
		["talk", "catastrophic", "return", true, true],
		["yield", "deterministic", "return", true, false],
	]
	for row in rows:
		var choice := str((row as Array)[0])
		var tier_name := str((row as Array)[1])
		var effects: Dictionary = rules.effects_for(choice, tier_name)
		_expect_str("%s/%s take disposition" % [choice, tier_name],
			str(effects["take"]), str((row as Array)[2]))
		_expect_true("%s/%s ban is %s" % [choice, tier_name, str((row as Array)[3])],
			bool(effects["ban"]) == bool((row as Array)[3]))
		_expect_true("%s/%s arrest at tier 1 / heat 0 is %s"
			% [choice, tier_name, str((row as Array)[4])],
			rules.arrests(choice, tier_name, 1, 0.0) == bool((row as Array)[4]))

	# Raw Heat per row and tier. This is where FS-003's two shorthand forms —
	# enumerated ("Tier 1 +2, Tier 2 +3, Tier 3 +4") and patterned ("Tier +1") —
	# have to resolve to the same numbers.
	var heat_rows := [
		["fight", "clean", 1.0, 1.0, 1.0],
		["fight", "messy", 2.0, 2.0, 2.0],
		["fight", "failure", 2.0, 3.0, 4.0],
		["fight", "catastrophic", 3.0, 4.0, 5.0],
		["run", "clean", 1.0, 2.0, 2.0],
		["run", "messy", 1.0, 2.0, 2.0],
		["run", "failure", 2.0, 3.0, 4.0],
		["run", "catastrophic", 3.0, 4.0, 5.0],
		["talk", "clean", 0.0, 0.0, 0.0],
		["talk", "messy", 0.0, 0.0, 0.0],
		["talk", "failure", 1.0, 1.0, 1.0],
		["talk", "catastrophic", 2.0, 2.0, 2.0],
		["yield", "deterministic", 0.0, 0.0, 0.0],
	]
	for row in heat_rows:
		var choice := str((row as Array)[0])
		var tier_name := str((row as Array)[1])
		for tier in [1, 2, 3]:
			_expect_float("%s/%s raw heat at tier %d" % [choice, tier_name, tier],
				rules.raw_heat(choice, tier_name, tier),
				float((row as Array)[1 + tier]))

	# Injury bands. `fight_win_low` is the one authored INTERPRETATION in the
	# rules module ("the lower half of the tier's successful-fight injury band"),
	# so its resolved numbers are pinned here rather than left implicit.
	var injury_rows := [
		["fight", "clean", 1, [4, 6]], ["fight", "clean", 2, [5, 7]], ["fight", "clean", 3, [6, 9]],
		["fight", "messy", 1, [4, 9]], ["fight", "messy", 3, [6, 12]],
		["fight", "failure", 1, [12, 20]], ["fight", "failure", 3, [18, 28]],
		["fight", "catastrophic", 1, [18, 26]], ["fight", "catastrophic", 3, [24, 34]],
		["run", "clean", 1, []],
		["run", "messy", 1, [1, 5]], ["run", "messy", 3, [1, 5]],
		["run", "failure", 2, [4, 10]],
		["run", "catastrophic", 2, [8, 14]],
		["talk", "clean", 1, []], ["talk", "messy", 2, []], ["talk", "failure", 3, []],
		["talk", "catastrophic", 1, [5, 10]],
		["yield", "deterministic", 1, []],
	]
	for row in injury_rows:
		var choice := str((row as Array)[0])
		var tier_name := str((row as Array)[1])
		var tier: int = int((row as Array)[2])
		_expect_str("%s/%s injury band at tier %d" % [choice, tier_name, tier],
			str(rules.injury_band(choice, tier_name, tier)),
			str((row as Array)[3]))

	# District Pressure by tier, TI-003 §8, plus Marcus Tate's authored Yield row.
	_expect_float("clean adds 0.5 pressure", rules.pressure_gain("fight", "clean"), 0.5)
	_expect_float("messy adds 1.0 pressure", rules.pressure_gain("fight", "messy"), 1.0)
	_expect_float("failure adds 1.0 pressure", rules.pressure_gain("run", "failure"), 1.0)
	_expect_float("catastrophic adds 2.0 pressure",
		rules.pressure_gain("talk", "catastrophic"), 2.0)
	_expect_float("yield adds exactly 1.0 pressure",
		rules.pressure_gain("yield", "deterministic"), 1.0)

	# The one conditional arrest, at its exact boundary. FS-003 §5 Run/Failure:
	# "Arrest occurs only when pre-encounter Global Heat > 6 or the target is
	# Tier 3." Strictly greater, so 6.0 itself does not arrest.
	_expect_true("run failure at tier 1 and heat 6.0 does not arrest",
		not rules.arrests("run", "failure", 1, 6.0))
	_expect_true("run failure at tier 1 and heat 6.1 arrests",
		rules.arrests("run", "failure", 1, 6.1))
	_expect_true("run failure at tier 2 and heat 0 does not arrest",
		not rules.arrests("run", "failure", 2, 0.0))
	_expect_true("run failure at tier 3 always arrests",
		rules.arrests("run", "failure", 3, 0.0))
	# And the condition reads the PRE-ENCOUNTER heat, not the tier alone — both
	# halves of the `or` are separately sufficient.
	_expect_true("run failure at tier 3 and high heat still arrests",
		rules.arrests("run", "failure", 3, 12.0))

# --- layer 2: the encounter, through dispatch -------------------------------

## Cause ids must keep advancing across a sweep, and `_frozen_ready` resets them.
##
## The consequence roll is keyed on `consequence:<cause_id>:boost_caught:<choice>:outcome`.
## A sweep that resets the run before every attempt therefore hands every chain
## the SAME `cause:00000001` and gets the SAME outcome every time — 39 chains
## opened, 39 resolved, not one of them different. That is what the first draft
## of this section did, and it read as "run never keeps the take" rather than as
## "the test never varied anything".
##
## Carrying the sequence is also the truthful model: in play the counter only
## ever goes up, which is exactly why TI-003 §4 makes Cause allocation
## sequential and persisted. Outcome variety across a run depends on it.
var _cause_sequence_carry: int = 0

func _caught_ready(gs: Node, day: int, tier: int) -> void:
	_frozen_ready(gs)
	gs.day = day
	gs.boost_tier = tier
	gs.boost_store_bans = []
	gs.next_cause_sequence = _cause_sequence_carry

func _caught_carry(gs: Node) -> void:
	_cause_sequence_carry = int(gs.next_cause_sequence)

## A failed lift with a specific RAW combat value, for the raw-vs-compat check.
func _open_failed_lift_with_combat(gs: Node, gm: Node, target_id: String,
		tier: int, raw_combat: int) -> bool:
	for day in range(1, 60):
		_caught_ready(gs, day, tier)
		gs.heat = 0.0
		gs.health = gs.health_max
		gs.attributes["combat"] = raw_combat
		var dispatched: bool = gm.dispatch("boost", {"target_id": target_id})
		_caught_carry(gs)
		if not dispatched:
			continue
		if not (gs.active_consequence as Dictionary).is_empty():
			return true
	return false

## Walk days until a lift on `target_id` fails and opens a chain.
##
## Derived rather than seeded: a fixed day may resolve to a SUCCESS, and a
## success opens nothing — every assertion after it would then pass vacuously
## against a chain that was never created.
func _open_failed_lift(gs: Node, gm: Node, target_id: String, tier: int) -> bool:
	for day in range(1, 60):
		_caught_ready(gs, day, tier)
		gs.heat = 0.0
		gs.health = gs.health_max
		var dispatched: bool = gm.dispatch("boost", {"target_id": target_id})
		_caught_carry(gs)
		if not dispatched:
			continue
		if not (gs.active_consequence as Dictionary).is_empty():
			return true
	return false

func _check_caught_opens_on_failure(gs: Node, gm: Node, engine: RefCounted) -> void:
	var rng := get_node("/root/RngManager")
	# Every Boost tier opens the decision — TI-003's acceptance criterion names
	# T1, T2 and T3 individually.
	var targets := [["night_owl", 1], ["northern_value", 2], ["warehouse_club", 3]]
	for spec in targets:
		var target_id := str((spec as Array)[0])
		var tier: int = int((spec as Array)[1])
		_expect_true("a failed tier-%d lift opens a chain" % tier,
			_open_failed_lift(gs, gm, target_id, tier))
		if (gs.active_consequence as Dictionary).is_empty():
			continue
		var summary: Dictionary = engine.active_summary()
		_expect_str("the tier-%d chain is boost_caught" % tier,
			str(summary["chain_kind"]), "boost_caught")
		_expect_str("the tier-%d chain names its target" % tier,
			str(summary["source_target_id"]), target_id)
		_expect_int("the tier-%d chain records the tier" % tier,
			int(summary["source_target_tier"]), tier)
		_expect_str("the tier-%d chain opens at the decision stage" % tier,
			str(summary["stage"]), "decision")
		# The contested take is the amount the lift would have paid, rolled off
		# the EXISTING `:take` key — TI-003 §11 step 4 and FS-003.7's "preserve
		# existing initial Boost and `:take` RNG keys".
		#
		# Asserted as the exact keyed value, not merely as "in band". A different
		# key produces a different number that is still inside the band every
		# time, so the band check alone cannot tell them apart — a sabotage
		# moving the key to `:contested` passed it.
		var band: Array = gs.boost_target_by_id(target_id)["take"]
		var source_key := str((gs.active_consequence["source"] as Dictionary)["source_rng_key"])
		_expect_int("the tier-%d contested take is the keyed :take value" % tier,
			int(summary["contested_take"]),
			rng.seeded_int_range(gs.run_seed, source_key + ":take",
				int(band[0]), int(band[1])))
		_expect_str("the tier-%d chain records the source key" % tier, source_key,
			"boost:%d:%d:%s" % [gs.day, gs.time_slots_today, target_id])
		_expect_true("the tier-%d contested take is in band" % tier,
			int(summary["contested_take"]) >= int(band[0])
				and int(summary["contested_take"]) <= int(band[1]))
		# The gate an arrest reads. Snapshotted before any consequence Heat.
		_expect_float("the tier-%d chain snapshots pre-encounter heat" % tier,
			float(summary["pre_encounter_heat"]), 0.0)
		# TI-003 §11 step 3: the daily stamp lands exactly once, on the attempt,
		# whether or not it worked — so a blown lift still uses up the room.
		_expect_int("a failed tier-%d lift still spends the day's attempt" % tier,
			int(gs.boost_daily_hits.get(target_id, -1)), gs.day)
		gs.active_consequence = {}

## TI-003 §5: "Persist decision inputs and shown probabilities when the decision
## opens. Reload reproduces the same choice surface."
## Cause ids are unique within a run, and that is load-bearing for OUTCOMES.
##
## The consequence roll is keyed on the Cause. If allocation ever stopped
## advancing — reset, reused, or made constant — every Caught encounter in a run
## would resolve identically, and nothing about the resolver or the effect tables
## would look wrong. The whole encounter layer would just quietly become one
## outcome repeated.
##
## This is not hypothetical: the first draft of this section reset the run before
## each attempt, handed 39 consecutive chains `cause:00000001`, and got the same
## tier 39 times. The sweep read as "run never keeps the take".
func _check_caught_cause_uniqueness(gs: Node, gm: Node, engine: RefCounted) -> void:
	_frozen_ready(gs)
	var ids: Array = []
	var tiers: Dictionary = {}
	for day in range(1, 40):
		gs.day = day
		gs.heat = 0.0
		gs.health = gs.health_max
		gs.boost_store_bans = []
		gs.boost_daily_hits = {}
		if not gm.dispatch("boost", {"target_id": "night_owl"}):
			continue
		if (gs.active_consequence as Dictionary).is_empty():
			continue
		var cause_id: String = engine.active_cause_id()
		_expect_true("cause %s is unique in this run" % cause_id, not cause_id in ids)
		ids.append(cause_id)
		if gm.dispatch("resolve_consequence_choice", {"choice_id": "run"}):
			tiers[str((engine.result_summary() as Dictionary)["resolved_tier"])] = true
		gs.active_consequence = {}
		if ids.size() >= 6:
			break
	_expect_true("the run opened several chains", ids.size() >= 6)
	# Sequential, not merely distinct — TI-003 §4 allocates with zero randomness
	# so a reload cannot renumber a live chain.
	for index in ids.size():
		_expect_str("cause %d is allocated in sequence" % index, str(ids[index]),
			"cause:%08d" % (int(str(ids[0]).substr(6)) + index))
	# And distinct causes really do produce distinct outcomes. This is the
	# assertion that would have caught the reset bug directly.
	_expect_true("distinct causes resolve to more than one tier", tiers.size() >= 2)

func _check_caught_decision_surface(gs: Node, gm: Node, engine: RefCounted,
		rules: RefCounted) -> void:
	var resolver: Object = gm.system("outcome_resolver")
	if not _open_failed_lift(gs, gm, "night_owl", 1):
		_fail("caught decision surface", "no failed lift found")
		return
	var rows: Array = engine.choice_summaries()
	_expect_int("the decision offers four responses", rows.size(), 4)
	var ids: Array = []
	for row in rows:
		ids.append(str((row as Dictionary)["choice_id"]))
	_expect_str("the four responses are fight, run, talk, yield", str(ids),
		str(["fight", "run", "talk", "yield"]))

	# The shown odds are the projection's, computed from the authored base
	# chance and the player's RAW attribute. Compared against a fresh call to
	# the projection rather than against a hardcoded number, because the run's
	# attributes are what `_frozen_ready` left them at — but the ACTION TYPE and
	# BASE CHANCE come from the authored table, so a wrong mapping still fails.
	for row in rows:
		var entry: Dictionary = row
		var choice := str(entry["choice_id"])
		if rules.is_deterministic(choice):
			_expect_true("yield shows no odds", not bool(entry["has_odds"]))
			_expect_true("yield is flagged deterministic", bool(entry["deterministic"]))
			continue
		var action_type: String = rules.resolver_for(choice)
		var attribute: String = resolver.attribute_for(action_type)
		var raw: int = int(gs.attributes.get(attribute, 0))
		_expect_float("%s shows the projected odds" % choice,
			float(entry["success_probability"]),
			resolver.success_probability(action_type,
				rules.base_chance(1, choice), raw, 0))
		_expect_true("%s is flagged as rolled" % choice, bool(entry["has_odds"]))

	# Nothing is committed yet, so nothing is disabled.
	for row in rows:
		_expect_true("%s starts enabled" % str((row as Dictionary)["choice_id"]),
			not bool((row as Dictionary)["disabled"]))
	gs.active_consequence = {}

	# --- RAW attribute, not the compatibility offset ---
	#
	# TI-003 regression #9: "Fight/Run/Talk use compatibility attributes instead
	# of raw Outcome Resolver attributes." `compat()` is `clamp(value + 1, 1, 5)`,
	# so it shifts every advantage and immunity threshold down a level.
	#
	# Measured at combat 2 SPECIFICALLY, and that is the whole point: raw 2 is
	# below the advantage threshold while compat(2) = 3 is at it, so the two
	# produce different odds. At combat 1 — where the rest of this section runs —
	# raw 1 and compat 2 are both below advantage and project identically, so the
	# regression is invisible there. A sabotage swapping raw for compat passed
	# every other check in this section.
	for raw_combat in [2, 5]:
		if not _open_failed_lift_with_combat(gs, gm, "night_owl", 1, raw_combat):
			_fail("caught raw attribute", "no failed lift at combat %d" % raw_combat)
			continue
		var fight_row: Dictionary = _choice_row(engine.choice_summaries(), "fight")
		_expect_float("fight odds at raw combat %d use the raw value" % raw_combat,
			float(fight_row["success_probability"]),
			resolver.success_probability("confrontation",
				rules.base_chance(1, "fight"), raw_combat, 0))
		# And they are NOT the compat value's odds, asserted separately so the
		# check names the thing it is defending against.
		var attributes_system: Object = gm.system("attributes")
		var compat_value: int = int(attributes_system.compat("combat"))
		if compat_value != raw_combat:
			_expect_true("fight odds at raw combat %d are not compat(%d)'s odds"
				% [raw_combat, compat_value],
				absf(float(fight_row["success_probability"])
					- resolver.success_probability("confrontation",
						rules.base_chance(1, "fight"), compat_value, 0)) > 1e-9
				or resolver.success_probability("confrontation",
					rules.base_chance(1, "fight"), compat_value, 0)
					== resolver.success_probability("confrontation",
						rules.base_chance(1, "fight"), raw_combat, 0))
		_expect_true("the resolver_inputs record the raw value",
			int(((gs.active_consequence["decision"] as Dictionary)["resolver_inputs"]
				as Dictionary)["fight"]["raw"]) == raw_combat)
		gs.active_consequence = {}

## TI-003 §12: "T1/T2 kept contested take becomes Dirty Cash. T3 kept contested
## value becomes Boost merchandise. Returned or confiscated take credits zero."
##
## The sharpest money rule in the slice, and the one regression list #6 and #7
## both name.
func _check_caught_take_provenance(gs: Node, gm: Node, engine: RefCounted,
		rules: RefCounted) -> void:
	for spec in [["night_owl", 1], ["northern_value", 2], ["warehouse_club", 3]]:
		var target_id := str((spec as Array)[0])
		var tier: int = int((spec as Array)[1])
		# Sweep responses until one KEEPS the take, so the disposition under
		# test actually happened. A run that never kept anything would pass a
		# "no cash appeared" check for the wrong reason.
		# Swept with `run` rather than `fight`. Both KEEP on clean and messy, but
		# run's base chance is better at every tier (0.62 / 0.50 / 0.38 against
		# 0.50 / 0.30 / 0.15) — and at tier 3 a 0.15 fight simply does not reach
		# a kept take often enough for a bounded sweep to find one. The rule
		# under test is the take's DESTINATION, which does not depend on which
		# response kept it. Fight's own effect rows are covered below.
		var kept := false
		for attempt in range(1, 160):
			_caught_ready(gs, attempt, tier)
			gs.dirty_cash = 0
			gs.clean_cash = int(gs.cash)
			gs.boost_merchandise = 0
			var opened_lift: bool = gm.dispatch("boost", {"target_id": target_id})
			_caught_carry(gs)
			if not opened_lift:
				continue
			if (gs.active_consequence as Dictionary).is_empty():
				continue
			var contested: int = int((engine.active_summary() as Dictionary)["contested_take"])
			var dirty_before: int = int(gs.dirty_cash)
			var goods_before: int = int(gs.boost_merchandise)
			if not gm.dispatch("resolve_consequence_choice", {"choice_id": "run"}):
				gs.active_consequence = {}
				continue
			var outcome: Dictionary = engine.result_summary()
			var tier_name := str(outcome["resolved_tier"])
			var disposition := str(rules.effects_for("run", tier_name).get("take", ""))
			if disposition == "keep":
				kept = true
				if tier >= 3:
					_expect_int("a kept tier-3 take becomes merchandise",
						int(gs.boost_merchandise), goods_before + contested)
					_expect_int("a kept tier-3 take is not cash",
						int(gs.dirty_cash), dirty_before)
				else:
					_expect_int("a kept tier-%d take credits dirty cash" % tier,
						int(gs.dirty_cash), dirty_before + contested)
					_expect_int("a kept tier-%d take is not merchandise" % tier,
						int(gs.boost_merchandise), goods_before)
			else:
				# Lost or returned: zero, both ways.
				_expect_int("a %s tier-%d take credits no cash" % [disposition, tier],
					int(gs.dirty_cash), dirty_before)
				_expect_int("a %s tier-%d take credits no merchandise" % [disposition, tier],
					int(gs.boost_merchandise), goods_before)
			gs.active_consequence = {}
			if kept:
				break
		_expect_true("the tier-%d provenance sweep saw a kept take" % tier, kept)

	# Talk and Yield always hand it back, so neither can ever pay.
	for choice in ["talk", "yield"]:
		var found := false
		for attempt in range(1, 40):
			_caught_ready(gs, attempt, 1)
			gs.dirty_cash = 0
			gs.clean_cash = int(gs.cash)
			gs.boost_merchandise = 0
			var lifted: bool = gm.dispatch("boost", {"target_id": "night_owl"})
			_caught_carry(gs)
			if not lifted:
				continue
			if (gs.active_consequence as Dictionary).is_empty():
				continue
			var contested: int = int((engine.active_summary() as Dictionary)["contested_take"])
			_expect_true("there was a take to hand back", contested > 0)
			if gm.dispatch("resolve_consequence_choice", {"choice_id": str(choice)}):
				found = true
				_expect_int("%s never credits cash" % choice, int(gs.dirty_cash), 0)
				_expect_int("%s never credits merchandise" % choice,
					int(gs.boost_merchandise), 0)
			gs.active_consequence = {}
			if found:
				break
		_expect_true("the %s sweep resolved a chain" % choice, found)

## Injury, Heat and Pressure, applied through the shared owners and matching the
## authored row for whatever tier actually came up.
func _check_caught_effects_applied(gs: Node, gm: Node, engine: RefCounted,
		rules: RefCounted) -> void:
	# Only about one lift in five on a tier-1 target actually fails, and only a
	# failed lift opens a chain — so reaching all four confrontation tiers needs
	# a sweep several times longer than the tier count suggests.
	var seen_tiers: Dictionary = {}
	for attempt in range(1, 220):
		_caught_ready(gs, attempt, 1)
		gs.heat = 0.0
		gs.health = gs.health_max
		gs.district_pressure = {}
		var lifted: bool = gm.dispatch("boost", {"target_id": "night_owl"})
		_caught_carry(gs)
		if not lifted:
			continue
		if (gs.active_consequence as Dictionary).is_empty():
			continue
		var health_before: int = int(gs.health)
		if not gm.dispatch("resolve_consequence_choice", {"choice_id": "fight"}):
			gs.active_consequence = {}
			continue
		var outcome: Dictionary = engine.result_summary()
		var tier_name := str(outcome["resolved_tier"])
		seen_tiers[tier_name] = int(seen_tiers.get(tier_name, 0)) + 1

		# Heat: the authored raw amount, scaled by the one owner. Nobody is on
		# the crew in a frozen run, so the applied delta equals the raw value —
		# and that equality is the check, since a caller applying its own
		# multiplier would break it.
		_expect_float("fight/%s applies its authored heat" % tier_name,
			float(gs.heat), rules.raw_heat("fight", tier_name, 1))

		# Injury: inside the authored band, or exactly zero when the row has none.
		var band: Array = rules.injury_band("fight", tier_name, 1)
		var damage: int = health_before - int(gs.health)
		if band.size() == 2:
			_expect_true("fight/%s injury %d is inside the authored band %s"
				% [tier_name, damage, str(band)],
				damage >= int(band[0]) and damage <= int(band[1]))
		else:
			_expect_int("fight/%s does no injury" % tier_name, damage, 0)

		# District Pressure: recorded once, at the authored amount, against the
		# district the encounter happened in and the boost family.
		var ledger: Dictionary = gs.district_pressure.get("north_star_lot", {})
		var row: Dictionary = ledger.get("boost", {})
		_expect_float("fight/%s records its authored pressure" % tier_name,
			float(row.get("score", 0.0)), rules.pressure_gain("fight", tier_name))
		_expect_int("pressure is stamped with the day",
			int(row.get("last_gain_day", -1)), gs.day)
		# Regression #16: District Pressure and Global Heat must not share
		# storage. They hold different numbers here, which is the proof.
		_expect_true("district pressure is stored apart from global heat",
			absf(float(row.get("score", 0.0)) - float(gs.heat)) > 1e-9
				or is_zero_approx(float(gs.heat)))

		# The arrest gate, read off the authored table with the pre-encounter
		# snapshot — which was 0.0, so only the unconditional rows arrest.
		_expect_true("fight/%s arrest matches the authored row" % tier_name,
			bool(outcome["result"]["arrested"])
				== rules.arrests("fight", tier_name, 1, 0.0))
		# Stage follows: Booking on an arrest, Result otherwise.
		_expect_str("fight/%s lands on the right stage" % tier_name,
			engine.active_stage(),
			engine.STAGE_BOOKING if bool(outcome["result"]["arrested"])
				else engine.STAGE_RESULT)

		gs.active_consequence = {}
		if seen_tiers.size() >= 3:
			break
	# The sweep has to have covered more than one ending, or every assertion
	# above is a statement about a single tier dressed up as a matrix.
	_expect_true("the fight sweep saw at least three outcome tiers",
		seen_tiers.size() >= 3)

	# --- receipts: every effect lands exactly once ---
	#
	# The exactly-once guarantee, measured where it matters: re-running the
	# adapter against an already-resolved chain must move nothing.
	if _open_failed_lift(gs, gm, "night_owl", 1):
		gs.heat = 0.0
		gs.health = gs.health_max
		gs.dirty_cash = 0
		gs.clean_cash = int(gs.cash)
		var chain: Dictionary = gs.active_consequence
		var boost_system: Object = gm.system("boost")
		_expect_true("the first resolution dispatches",
			gm.dispatch("resolve_consequence_choice", {"choice_id": "fight"}))
		var heat_after: float = float(gs.heat)
		var health_after: int = int(gs.health)
		var cash_after: int = int(gs.dirty_cash)
		var pressure_after: float = float(
			(gs.district_pressure.get("north_star_lot", {}) as Dictionary)
				.get("boost", {}).get("score", 0.0))
		# Called directly rather than dispatched: the dispatch path is already
		# guarded by the committed-choice receipt (FS-003.5), so it would refuse
		# before reaching the adapter and prove nothing about the EFFECT
		# receipts. This is the one place the adapter is exercised out of band,
		# and it is exercised precisely to show the receipts hold on their own.
		boost_system.resolve_consequence(chain, "fight")
		_expect_float("re-resolving applies no second heat", float(gs.heat), heat_after)
		_expect_int("re-resolving applies no second injury", int(gs.health), health_after)
		_expect_int("re-resolving credits no second take", int(gs.dirty_cash), cash_after)
		_expect_float("re-resolving records no second pressure",
			float((gs.district_pressure.get("north_star_lot", {}) as Dictionary)
				.get("boost", {}).get("score", 0.0)), pressure_after)
		gs.active_consequence = {}

## The one conditional arrest, driven through the real path.
##
## FS-003 §5 Run/Failure: "Arrest occurs only when pre-encounter Global Heat > 6
## or the target is Tier 3." TI-003 §14 adds that the snapshot is taken BEFORE
## consequence Heat — and that is the half no data-level check can prove, because
## it is about which number the ADAPTER hands the rule.
##
## Staged so the two readings disagree: pre-encounter Heat sits at exactly 6.0,
## which does NOT arrest, while Run/Failure at tier 1 adds +2 raw — so the live
## meter reads 8.0 by the time the gate is evaluated, which WOULD arrest. If the
## adapter passed `gs.heat` instead of the snapshot, this flips.
func _check_caught_arrest_snapshot(gs: Node, gm: Node, engine: RefCounted,
		rules: RefCounted) -> void:
	var found := false
	for attempt in range(1, 220):
		_caught_ready(gs, attempt, 1)
		gs.health = gs.health_max
		# Exactly on the boundary: the rule is strictly greater than 6.
		gs.heat = 6.0
		var lifted: bool = gm.dispatch("boost", {"target_id": "night_owl"})
		_caught_carry(gs)
		if not lifted or (gs.active_consequence as Dictionary).is_empty():
			continue
		_expect_float("the chain snapshotted the boundary heat",
			float((engine.active_summary() as Dictionary)["pre_encounter_heat"]), 6.0)
		if not gm.dispatch("resolve_consequence_choice", {"choice_id": "run"}):
			gs.active_consequence = {}
			continue
		var outcome: Dictionary = engine.result_summary()
		if str(outcome["resolved_tier"]) != "failure":
			gs.active_consequence = {}
			continue
		found = true
		# The encounter's own Heat has already landed, and it pushed the live
		# meter past the threshold — which is exactly the trap.
		_expect_float("run/failure at tier 1 added its authored heat",
			float(gs.heat), 6.0 + rules.raw_heat("run", "failure", 1))
		_expect_true("the live meter is now above the arrest threshold",
			float(gs.heat) > rules.RUN_FAILURE_ARREST_HEAT)
		# And the gate still says no, because it read the snapshot.
		_expect_true("the arrest gate reads the pre-encounter snapshot, not the live meter",
			not bool(outcome["result"]["arrested"]))
		_expect_str("a non-arrest run/failure stops at the result stage",
			engine.active_stage(), engine.STAGE_RESULT)
		gs.active_consequence = {}
		break
	_expect_true("the arrest-snapshot probe found a run/failure", found)

	# The other half of the `or`: tier 3 arrests regardless of Heat. Driven the
	# same way so both branches of the condition are covered on the real path.
	var found_tier3 := false
	for attempt in range(1, 220):
		_caught_ready(gs, attempt, 3)
		gs.health = gs.health_max
		gs.heat = 0.0
		var lifted3: bool = gm.dispatch("boost", {"target_id": "warehouse_club"})
		_caught_carry(gs)
		if not lifted3 or (gs.active_consequence as Dictionary).is_empty():
			continue
		if not gm.dispatch("resolve_consequence_choice", {"choice_id": "run"}):
			gs.active_consequence = {}
			continue
		var outcome3: Dictionary = engine.result_summary()
		if str(outcome3["resolved_tier"]) != "failure":
			gs.active_consequence = {}
			continue
		found_tier3 = true
		_expect_true("run/failure at tier 3 arrests even at zero heat",
			bool(outcome3["result"]["arrested"]))
		_expect_str("an arrest moves the chain to booking",
			engine.active_stage(), engine.STAGE_BOOKING)
		# The facts FS-003.8 will need are on the chain already.
		var booking: Dictionary = engine.booking_summary()
		_expect_true("the booking stage carries a severity",
			not str(booking.get("severity", "")).is_empty())
		_expect_str("the booking stage carries the source family",
			str(booking.get("source_family", "")), "boost")
		gs.active_consequence = {}
		break
	_expect_true("the tier-3 arrest probe found a run/failure", found_tier3)

## Yield is the deterministic relief valve: known loss, zero RNG, +1.0 Pressure.
func _check_caught_yield(gs: Node, gm: Node, engine: RefCounted) -> void:
	if not _open_failed_lift(gs, gm, "night_owl", 1):
		_fail("caught yield", "no failed lift found")
		return
	gs.heat = 0.0
	gs.health = gs.health_max
	gs.dirty_cash = 0
	gs.clean_cash = int(gs.cash)
	gs.district_pressure = {}
	gs.rng_state = 777777
	var cursor: int = int(gs.rng_state)
	var contested: int = int((engine.active_summary() as Dictionary)["contested_take"])

	_expect_true("yield dispatches",
		gm.dispatch("resolve_consequence_choice", {"choice_id": "yield"}))
	var outcome: Dictionary = engine.result_summary()
	# FS-003 §5 Yield: return the merchandise, ban, 0 Heat, 0 injury, 0 arrest.
	_expect_str("yield resolves deterministically", str(outcome["resolved_tier"]),
		"deterministic")
	_expect_true("there was a take to give up", contested > 0)
	_expect_int("yield credits no cash", int(gs.dirty_cash), 0)
	_expect_int("yield credits no merchandise", int(gs.boost_merchandise), 0)
	_expect_float("yield costs no heat", float(gs.heat), 0.0)
	_expect_int("yield costs no health", int(gs.health), gs.health_max)
	_expect_true("yield does not arrest", not bool(outcome["result"]["arrested"]))
	_expect_true("yield bans the store", bool(outcome["result"]["banned"]))
	# Marcus Tate's authored row, applied.
	_expect_float("yield adds exactly 1.0 district pressure",
		float((gs.district_pressure.get("north_star_lot", {}) as Dictionary)
			.get("boost", {}).get("score", 0.0)), 1.0)
	# TI-003 regression #8: "Yield consumes RNG."
	_expect_int("yield draws nothing from the market stream", int(gs.rng_state), cursor)
	gs.active_consequence = {}

## Bans are Boost-owned, persistent, and enforced by the source blocker.
func _check_caught_bans(gs: Node, gm: Node, engine: RefCounted, boost: RefCounted) -> void:
	if not _open_failed_lift(gs, gm, "night_owl", 1):
		_fail("caught bans", "no failed lift found")
		return
	_expect_true("the store is not banned before the encounter resolves",
		not "night_owl" in gs.boost_store_bans)
	_expect_true("yield dispatches for the ban check",
		gm.dispatch("resolve_consequence_choice", {"choice_id": "yield"}))
	_expect_true("a yielded encounter bans the store", "night_owl" in gs.boost_store_bans)
	# Enforced through the source blocker, which is what makes it real.
	#
	# The daily-hit stamp is cleared first. It is checked BEFORE the ban and
	# would answer "you've already been in today" — so leaving it in place would
	# have this assertion pass on the wrong blocker, and a deleted ban check
	# would go unnoticed. Measured where only the ban can produce the answer.
	gs.boost_daily_hits = {}
	_expect_str("the blocker refuses a banned store",
		boost.blocker("night_owl"), "They know your face in there now.")
	gs.active_consequence = {}
	# TI-003 regression #11: bans must survive a day-cross AND a reload. The
	# reload half is FS-003.4's; this is the day-cross half, on a live ban.
	gs.time_slots_today = 3
	gs.time_slot = "NIGHT"
	_expect_true("the night dispatches over a live ban", gm.dispatch("advance_time", {}))
	_expect_true("the ban survives the day-cross", "night_owl" in gs.boost_store_bans)
	_expect_str("the blocker still refuses after the day-cross",
		boost.blocker("night_owl"), "They know your face in there now.")
	# A store that was never banned is unaffected — the ban is per target, not a
	# global lockout.
	_expect_str("an unbanned store is still open", boost.blocker("spenard_fuel"), "")

## TI-003 §26: "One source action pays its normal time cost once after its
## blocking consequence reaches terminal handoff." Regression #12 is it settling
## twice.
func _check_caught_source_time(gs: Node, gm: Node, engine: RefCounted) -> void:
	if not _open_failed_lift(gs, gm, "night_owl", 1):
		_fail("caught source time", "no failed lift found")
		return
	var slot_at_lift: int = int(gs.time_slots_today)
	_expect_true("the source slot is owed while the chain is open",
		engine.source_time_owed())
	_expect_true("the decision resolves",
		gm.dispatch("resolve_consequence_choice", {"choice_id": "yield"}))
	_expect_int("resolving the decision costs no slot",
		int(gs.time_slots_today), slot_at_lift)
	_expect_true("the slot is still owed at the result stage", engine.source_time_owed())

	_expect_true("continue dispatches", gm.dispatch("consequence_continue", {}))
	_expect_int("continue settles the source slot exactly once",
		int(gs.time_slots_today), slot_at_lift + 1)
	_expect_true("continue clears the chain", not engine.has_active())
	# And a second Continue cannot charge again — there is nothing left to
	# continue, which is the structural version of "settles once".
	_expect_true("a second continue is refused", not gm.dispatch("consequence_continue", {}))
	_expect_int("a refused continue costs no slot",
		int(gs.time_slots_today), slot_at_lift + 1)

## The contested take, the shown odds and the committed result all survive a
## reload — TI-003 regression #4.
func _check_caught_reload(gs: Node, gm: Node, engine: RefCounted) -> void:
	var saves := get_node("/root/SaveSystem")
	var previous_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var prior := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if prior != null:
			previous_save = prior.get_as_text()
			prior.close()

	if _open_failed_lift(gs, gm, "night_owl", 1):
		var summary: Dictionary = engine.active_summary()
		var contested: int = int(summary["contested_take"])
		var cause_id := str(summary["cause_id"])
		var odds: Array = engine.choice_summaries()
		var run_odds: float = float((_choice_row(odds, "run") as Dictionary)["success_probability"])
		saves.save_run()

		gs.active_consequence = {}
		gs.consequence_history = {}
		_expect_true("a Caught chain reloads", saves.load_run())
		var after: Dictionary = engine.active_summary()
		_expect_int("the contested take survives a reload",
			int(after["contested_take"]), contested)
		_expect_str("the cause survives a reload", str(after["cause_id"]), cause_id)
		_expect_float("the shown odds survive a reload",
			float((_choice_row(engine.choice_summaries(), "run") as Dictionary)["success_probability"]),
			run_odds)
		_expect_true("the reloaded chain still owes its source time",
			engine.source_time_owed())

		# Resolve, save, reload: the committed result must not reroll.
		_expect_true("the reloaded chain resolves",
			gm.dispatch("resolve_consequence_choice", {"choice_id": "fight"}))
		var resolved: Dictionary = engine.result_summary()
		var tier_name := str(resolved["resolved_tier"])
		var heat_at_resolve: float = float(gs.heat)
		saves.save_run()
		gs.active_consequence = {}
		_expect_true("a resolved chain reloads", saves.load_run())
		_expect_str("the committed choice survives",
			str((engine.result_summary() as Dictionary)["committed_choice"]), "fight")
		_expect_str("the resolved tier survives — it does not reroll",
			str((engine.result_summary() as Dictionary)["resolved_tier"]), tier_name)
		_expect_float("the applied heat is not re-applied on reload",
			float(gs.heat), heat_at_resolve)
		# The receipts came back too, so the effects still cannot replay.
		_expect_true("the heat receipt survives the reload",
			engine.has_receipt(cause_id, "boost_caught:heat"))
		gs.active_consequence = {}

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

## TI-003 §21: consequence rolls are keyed and leave the market cursor alone.
func _check_caught_rng_non_drift(gs: Node, gm: Node, engine: RefCounted) -> void:
	for choice in ["fight", "run", "talk", "yield"]:
		if not _open_failed_lift(gs, gm, "night_owl", 1):
			_fail("caught rng", "no failed lift found")
			return
		gs.rng_state = 314159
		var cursor: int = int(gs.rng_state)
		_expect_true("%s resolves for the rng check" % choice,
			gm.dispatch("resolve_consequence_choice", {"choice_id": str(choice)}))
		_expect_int("resolving %s draws nothing from the market stream" % choice,
			int(gs.rng_state), cursor)
		gs.active_consequence = {}

	# Opening the chain draws nothing either — the contested take comes off the
	# source's own `:take` key, which is keyed, not streamed.
	_frozen_ready(gs)
	gs.rng_state = 271828
	var open_cursor: int = int(gs.rng_state)
	for day in range(1, 30):
		gs.day = day
		gs.boost_daily_hits = {}
		if gm.dispatch("boost", {"target_id": "night_owl"}) \
				and not (gs.active_consequence as Dictionary).is_empty():
			break
	_expect_int("opening a Caught chain draws nothing from the market stream",
		int(gs.rng_state), open_cursor)
	gs.active_consequence = {}

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

## The suite must not be able to pass by running less of itself.
##
## A runtime error inside a check — indexing a null, a bad cast — aborts the
## enclosing function and returns to the caller, which carries on with the next
## section. The run then reports PASS with a smaller total, and nothing notices.
## Two sabotages in FS-001.6 did exactly that before this existed.
##
## Bumped deliberately whenever checks are added, the same discipline as
## SAVE_VERSION: it only ever moves up, and it moving DOWN is the signal.
## FS-003.1 set this floor at 7665 as the inherited contract for FS-003.2
## through .12: the Consequence-Encounter Engine may add checks, never lose them.
##
## FS-003.3 raises it to 7889. Six of those are not new coverage but RECOVERED
## coverage: FS-003.2's lifecycle-hook checks assigned an untyped Array literal
## to an `Array[Callable]` property, which raises and aborts the enclosing check
## — so the suite reported 7726 while six of its checks had never once run. The
## floor moving up by more than the checks added is the tell, and it is exactly
## the failure mode this constant exists to make visible.
##
## FS-003.4 raises it to 8036. Thirteen of those came for free: the round-trip
## section walks `PERSIST_FIELDS` by name, so adding the TI-003 §5 state to the
## manifest added coverage without a line of test being written for it.
##
## FS-003.5 raises it to 8267. Two of the checks behind that number exist only
## because a sabotage passed without them: the stage-refusal check was measuring
## the committed-choice receipt rather than the stage, and nothing proved the
## copying projections were copies.
##
## FS-003.6 raises it to 8785. The projection section is mostly a sampled matrix
## measured off the real resolver, so most of that number is one assertion per
## (action, chance, attribute) cell rather than new surface area.
##
## FS-003.7 raises it to 9100. Note the shape of this one: the Caught section
## sweeps until it finds the outcome it needs, so its contribution depends on
## how quickly each branch turns up — deterministic, because the keys are, but
## not a number to re-derive by counting assertions in the source.
const MIN_CHECKS := 9100

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

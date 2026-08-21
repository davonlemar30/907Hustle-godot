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
##   market   — canon market-walk fixtures: PENDING until the part-2 economy
##              port; counted and reported, not compared, so the fixture format
##              is locked in now without failing a build on a known gap
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
		_report_market_pending(fixtures.get("market_walks", []))
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

func _report_market_pending(walks: Array) -> void:
	var frames := 0
	for walk in walks:
		frames += (walk.get("steps", []) as Array).size()
	print("parity: market walk fixtures present (%d walks, %d frames) — PENDING the part-2 economy port, not compared" % [walks.size(), frames])

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
	gs.log_activity("Parity entry", Color(1, 0.29, 0.239))
	gs.heat = 1.6
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
	_expect_true("day restored as int", gs.day is int)

	if previous_save.is_empty():
		DirAccess.open("user://").remove(saves.SAVE_PATH.get_file())
	else:
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(previous_save)
			restore.close()

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

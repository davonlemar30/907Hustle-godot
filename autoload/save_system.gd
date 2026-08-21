extends Node
## SaveSystem — Phase 4: persist the run, restore the run.
##
## Port of canon's autosave loop (ui.built.js App useEffect: serializeRun →
## localStorage on EVERY state change while in-game) and inspectSave
## (game-core.js:2179): the title screen asks one question — "is there a valid
## save?" — and gets the same five-field preview canon builds (name, day, part,
## district, cash) plus debt.
##
## What was ported:
## - Autosave on every state change while a run is live. Canon gates on
##   `screen === "game"`; here the gate is `street_name != ""`, which is the
##   same fact — a run exists once it has a name, and nothing fires
##   state_changed before name entry sets one.
## - inspectSave's shape: {exists, valid, preview}. An unreadable or
##   incompatible file is exists-but-not-valid, never a crash.
## - Save versioning from the first byte. Canon's history (migrateSave handles
##   versions 3-10, game-core.js:1719) says the migration chain WILL be needed;
##   _migrate() is that chain, one `match` arm per version bump.
##
## Deliberate divergences, each with its reason:
## - Format is Godot variant text (var_to_str), not JSON. activity_log rows
##   carry Color values JSON cannot represent, and a JSON round-trip turns
##   every int into a float, which a typed GDScript var refuses at assignment.
##   var_to_str round-trips every type exactly and str_to_var evaluates no code.
## - One file (user://907hustle_run.save) with the version INSIDE the payload,
##   not canon's per-version localStorage keys (SAVE_KEY + 8 LEGACY_SAVE_KEYS).
##   The key-per-version scheme exists because localStorage cannot atomically
##   rename; a file has no such constraint, so the legacy-key scan is not
##   ported. No Godot-build save predates this file, so there is nothing legacy
##   to find.
##
## Not ported: migrateSave's v3-v10 transforms (they migrate WEB saves this
## build cannot read), seedExposureLedgers (version 1 here already includes the
## ledgers), and canon's save-error copy on the title screen beyond the one
## line the load failure toast uses.
##
## What persists: every mutable run field in GameState — the clock, player
## stats, inventory, jobs/obligations, all six hustle surfaces, crew records
## and the wage clock, territory, the exposure substrate (npc_ledgers +
## observation_queue) and every Curtis awareness field — plus the current
## market prices as a {product_id: price} slice. Canon tables (districts,
## products' static fields, stick_targets, crew_roster, …) and the UI-scaffold
## placeholders that no system writes yet (todays_take, income_sources,
## hustle_surfaces, active_operation, eli_report) are NOT
## saved: a data-tuning commit must win over a stale save, and a placeholder
## that persists becomes a fake fact.

const SAVE_PATH := "user://907hustle_run.save"
## v2 (Phase 5 part 2): adds `markets` (per-area prices/availability/history)
## and `rng_state` (the xorshift stream cursor). Both additive — the v1→v2
## migration arm only stamps the version, and a v1 save's missing fields
## default in; load_run() then walks fresh markets off the run seed, so an old
## save resumes with a coherent board instead of an empty one.
##
## v3 (Phase 6): adds the phone inbox (`phone_inbox`, `phone_held_inbox`,
## `phone_reactivate_at_slot`) and changes the SHAPE of `activity_log` rows,
## which now carry the day they were logged on. The inbox fields are additive
## and default in; the log rows are not, so the v2→v3 arm walks them and stamps
## the ones that predate the field. See _migrate for what it stamps and why.
##
## v4 (Phase 5c): adds `attributes` and `attribute_progress`. Purely additive —
## a v3 save has neither, and both default in at canon's fresh-run values (all
## attributes 1, all progress 0). That is the right answer rather than a
## convenience: a run that predates the attribute system genuinely never trained
## anything, so defaults ARE its history.
## v5 (Phase 5d): adds `recovery_introduced`. Additive; a v4 save defaults to
## false and the flag re-arms the moment health or heat makes Recovery relevant
## again, which is the same thing canon's own flag does on a fresh load.
const SAVE_VERSION := 5

## Every mutable GameState field, captured and applied by name. products.price
## is the one mutable value living inside a canon table; it rides separately as
## "product_prices" so the table's static fields never round-trip.
const PERSIST_FIELDS: Array[String] = [
	# Run clock + identity
	"day", "time_slot", "time_slots_today", "run_seed", "current_district_id",
	"street_name",
	# Markets + the stream cursor (v2)
	"markets", "rng_state",
	# Player stats
	"cash", "heat", "health", "debt", "debt_due_days", "respect", "crew_power",
	"inventory",
	# Attributes (v4)
	"attributes", "attribute_progress",
	# Jobs
	"active_job_id", "job_records", "job_missed", "jobs_discovered",
	# Obligations + game over
	"rent_due_day", "rent_missed", "household_warnings",
	"phone_due_day", "phone_days_past_due", "phone_active",
	# Recovery (v5)
	"recovery_introduced",
	# Phone inbox (v3)
	"phone_inbox", "phone_held_inbox", "phone_reactivate_at_slot",
	"game_over", "game_over_reason",
	# Stickup
	"stick_tier", "stick_daily_count", "stick_rep", "stick_attempts",
	"stick_successes", "stick_organized_hits",
	# Shark
	"shark_loans", "shark_next_loan_id",
	# 907List
	"list_tier", "list_flips", "list_holdings",
	# Boost
	"boost_tier", "boost_technique", "boost_merchandise",
	"boost_fence_standing", "boost_daily_hits",
	# Crew + territory
	"crew_records", "held_blocks", "soldiers_idle",
	# Exposure substrate
	"npc_ledgers", "observation_queue",
	# Curtis awareness
	"curtis_awareness", "curtis_phase", "curtis_floor", "curtis_quiet_streak",
	"curtis_last_criminal_day", "curtis_watchers_seen", "curtis_last_watcher_day",
	"curtis_recent_watcher_lines", "curtis_phase_messages_sent",
	# Feed
	"activity_log",
]

## A save missing any of these is not a run. Everything else defaults in from
## GameState's own declarations, canon's mergeDefaults pattern.
const REQUIRED_KEYS: Array[String] = ["day", "cash", "street_name"]

var gs: Node
## True while a load is being applied, so the notify_changed that announces the
## loaded state does not immediately autosave what was just read.
var _suspended: bool = false

func _ready() -> void:
	gs = get_node("/root/GameState")
	gs.state_changed.connect(_on_state_changed)

## The autosave loop. Canon saves the whole state on every reducer pass; this
## fires once per successful dispatch (GameManager emits exactly one
## notify_changed per success), which is the same cadence.
func _on_state_changed() -> void:
	if _suspended:
		return
	if str(gs.street_name).is_empty():
		return  # No run yet — the title/name-entry screens are up.
	save_run()

# --- write -----------------------------------------------------------------

func save_run() -> void:
	var payload := {"save_version": SAVE_VERSION, "state": capture()}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: could not open %s for write (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(var_to_str(payload))
	file.close()

## Snapshot every persisted field. Deep-duplicated so the snapshot cannot alias
## live state a later mutation would silently rewrite.
func capture() -> Dictionary:
	var state: Dictionary = {}
	for field in PERSIST_FIELDS:
		state[field] = _deep(gs.get(field))
	var prices: Dictionary = {}
	for prod in gs.products:
		prices[str(prod.id)] = int(prod.price)
	state["product_prices"] = prices
	return state

# --- read ------------------------------------------------------------------

func has_save() -> bool:
	return bool(inspect().get("valid", false))

## Canon inspectSave: never throws, and an unreadable save is exists-but-not-
## valid so the title can say so instead of crashing.
func inspect() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"exists": false, "valid": false, "preview": {}}
	var state := _migrate(_read_payload())
	if state.is_empty():
		return {"exists": true, "valid": false, "preview": {}}
	var district: Dictionary = gs.district_by_id(str(state.get("current_district_id", "")))
	return {"exists": true, "valid": true, "preview": {
		"name": str(state.get("street_name", "")),
		"day": int(state.get("day", 1)),
		"part": str(state.get("time_slot", "MORNING")),
		"district": str(district.get("name", "SPENARD")),
		"cash": int(state.get("cash", 0)),
		"debt": int(state.get("debt", 0)),
	}}

## Restore the saved run into GameState. Returns false (state untouched) if the
## file is missing, unreadable, or from an unknown version.
func load_run() -> bool:
	var state := _migrate(_read_payload())
	if state.is_empty():
		return false
	_suspended = true
	_apply(state)
	# A pre-v2 save carries no markets. Walk a fresh board off the run seed so
	# the run resumes priced rather than empty; the next day-cross re-walks it.
	if gs.markets.is_empty():
		gs.init_markets()
	else:
		preload("res://systems/economy.gd").sync_display_prices(gs)
	gs.notify_changed()
	_suspended = false
	return true

func _read_payload() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = str_to_var(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}

## The migration chain, built in before it is needed. Each future version bump
## adds one `match` arm transforming version N state to N+1; a version this
## build has never heard of (0, or newer than itself) is invalid, not a guess.
func _migrate(payload: Dictionary) -> Dictionary:
	var version := int(payload.get("save_version", 0))
	var raw: Variant = payload.get("state")
	if version < 1 or version > SAVE_VERSION or not (raw is Dictionary):
		return {}
	var state: Dictionary = raw
	while version < SAVE_VERSION:
		match version:
			1:
				# v1 → v2: markets + rng_state are additive. Nothing to
				# transform — absent fields keep GameState's defaults, and
				# load_run() walks fresh markets when none arrived.
				pass
			2:
				# v2 → v3: the phone inbox fields are additive and default in.
				# activity_log rows are not — they gained a `day`, and a row
				# written before the field existed cannot have one recovered
				# (the log never carried a date). They are stamped -1, which no
				# real day equals, so an old entry is simply never "today".
				# Better a row that is honestly undated than one back-dated to
				# a day it did not happen on.
				# Not named `log` — that is a GDScript built-in.
				var feed: Variant = state.get("activity_log")
				if feed is Array:
					for row in (feed as Array):
						if row is Dictionary and not (row as Dictionary).has("day"):
							(row as Dictionary)["day"] = -1
			3:
				# v3 → v4: attributes + attribute_progress are additive and
				# default in at canon's fresh-run values. A run that predates
				# the system never trained anything, so the defaults are its
				# real history, not a fallback.
				pass
			4:
				# v4 → v5: recovery_introduced is additive and defaults false.
				pass
			_:
				return {}
		version += 1
	for key in REQUIRED_KEYS:
		if not state.has(key):
			return {}
	return state

## Write the saved fields back. A field absent from the save keeps GameState's
## declared default — canon's mergeDefaults, done by omission. Values are
## coerced to the type the live field already has, so a hand-edited or migrated
## save cannot feed a float into a typed int var and fail the assignment.
func _apply(state: Dictionary) -> void:
	for field in PERSIST_FIELDS:
		if not state.has(field):
			continue
		gs.set(field, _coerced(gs.get(field), _deep(state[field])))
	var prices: Dictionary = state.get("product_prices", {})
	for prod in gs.products:
		var id := str(prod.id)
		if prices.has(id):
			prod.price = clampi(int(prices[id]), int(prod.min), int(prod.max))

func _deep(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

func _coerced(current: Variant, incoming: Variant) -> Variant:
	match typeof(current):
		TYPE_INT:
			return int(incoming)
		TYPE_FLOAT:
			return float(incoming)
		TYPE_BOOL:
			return bool(incoming)
		TYPE_STRING:
			return str(incoming)
		_:
			return incoming

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
## Write the complete payload here, then atomically replace SAVE_PATH. Opening
## the only save with WRITE truncates it immediately; a crash or interrupted web
## flush during store_string would otherwise destroy the last valid run.
const SAVE_TEMP_PATH := SAVE_PATH + ".tmp"
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
##
## v6 (FS-001.2): adds `list_taken`, the same-day 907List consumption record.
## The first arm in this chain that RECONSTRUCTS state rather than defaulting
## it, and the first with a limit worth naming — see the v5 → v6 arm in
## _migrate for what it can and cannot recover.
##
## v7 (FS-001.6): adds `crew_assignments` and `crew_operation_state`, the Named
## Crew Operations lifecycle. Both additive. The arm also stamps an explicit
## `source` on every held 907List item, so "who bought this" is never ambiguous
## once delegated buying lands — see the v6 → v7 arm.
##
## v8 (FS-003.4): the Consequence-Encounter Engine's persisted state, TI-003 §5
## — money provenance, Financial Pressure, Cause/consequence sequences, the
## active chain, receipt history, the delayed queue, the arrest record, Boost
## bans, and District Pressure with its bleed queue.
##
## Every consequence field is additive and defaults empty, and empty is the
## honest history rather than a fallback: a v7 save cannot contain an unfinished
## consequence because the system did not exist, so the arm creates no inferred
## chain (TI-003 §20).
##
## The one TRANSFORM is the wallet. `cash` alone cannot say where it came from,
## and the split has to answer that for money already in a save. TI-003 §20/§26
## rules the whole aggregate CLEAN, which is a deliberate divergence from canon's
## own pre-split migration — see `WalletSystem.classify_legacy_total()`, which is
## the single place that rule lives and is what this arm calls.
##
## v9 (FS-003.13): adds `consequence_flags`, the consequence layer's run-level
## one-shot flags. Purely additive and the arm only stamps the version: an empty
## Dictionary is the honest history for a v8 run, because a flag that records
## "this has already been shown once" is false for a run that has never shown it.
##
## v10 (v0.1.0): adds `districts_unlocked`, `job_contacts` and
## `pressure_clean_credits`. All three are additive, and the arm re-derives the
## first two rather than defaulting them blindly -- see the arm for why.
##
## The arrest cooldown FS-003.13 also added rides inside `arrest_record`, which
## v8 already persists whole — so it needs no arm and no default here. A v8 save
## comes back with the key absent, and `ArrestSystem.cooldown_until_day()` reads
## a missing key as -1: no cooldown, which is the correct history for arrests
## that predate the mechanic. One bump, one arm, both new pieces of state
## covered.
const SAVE_VERSION := 12
const SAVE_VALIDATOR := preload("res://autoload/save_validator.gd")

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
	# 907List (list_taken is v6)
	"list_tier", "list_flips", "list_holdings", "list_taken",
	# Boost
	"boost_tier", "boost_technique", "boost_merchandise",
	"boost_fence_standing", "boost_daily_hits",
	# Named Crew Operations (v7)
	"crew_assignments", "crew_operation_state",
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
	# Money provenance + Financial Pressure (v8, TI-003 §§5-6)
	"dirty_cash", "clean_cash", "financial_pressure",
	# Consequence-Encounter Engine (v8, TI-003 §5). Stable IDs and state facts
	# only — runtime source adapters are re-registered on boot and never here.
	"next_cause_sequence", "next_consequence_sequence",
	"active_consequence", "consequence_history", "consequence_queue",
	"last_blocking_delayed_day",
	"arrest_record", "boost_store_bans",
	"district_pressure", "pressure_bleed_pending", "pressure_clean_credits",
	# The consequence layer's run-level one-shot flags (v9, FS-003.13).
	"consequence_flags",
	# Progression discovery latches (v10, surface visibility).
	"districts_unlocked", "job_contacts",
	# Venue interiors (v11). The session counts and the gym streak are the state
	# behind `effectiveAttribute`; `venues_entered` is what the player has walked
	# into, which is what makes the Night Owl's shift findable at all.
	"attribute_sessions", "gym_streak", "gym_last_day", "venues_entered",
	# Heat's teeth (v12). `heat_gain_today` is the quiet-day flag and must
	# survive a mid-day reload or the day gets a decay it did not earn.
	"heat_gain_today", "lay_low_day",
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
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: could not open %s for write (error %d)" % [SAVE_TEMP_PATH, FileAccess.get_open_error()])
		return
	file.store_string(var_to_str(payload))
	file.flush()
	file.close()
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SAVE_TEMP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_warning("SaveSystem: could not replace %s (error %d)" % [SAVE_PATH, err])

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
	state = _validate_nested_shapes(state)
	_suspended = true
	_apply(state)
	# A legacy save may predate a persistent latch while already satisfying its
	# trigger. Reconcile before the loaded state is exposed to screens.
	gs.reconcile_persistent_invariants()
	# Qualifying-load unlock. A save written before Named Crew Operations
	# existed can already satisfy an operation's discovery requirements — a
	# Broker-tier run with Pherris loyal has met them for days without anything
	# ever having looked. Reconciling here means the operation is known on the
	# first frame after CONTINUE RUN rather than after whatever action happens
	# to dispatch next.
	var crew_ops: Object = get_node_or_null("/root/GameManager")
	if crew_ops != null:
		crew_ops = crew_ops.system("crew_operations")
		if crew_ops != null:
			crew_ops.reconcile()
	# A pre-v2 save carries no markets. Walk a fresh board off the run seed so
	# the run resumes priced rather than empty; the next day-cross re-walks it.
	if gs.markets.is_empty():
		gs.init_markets()
	else:
		preload("res://systems/economy.gd").sync_display_prices(gs)
	gs.notify_changed()
	_suspended = false
	return true

## Validate nested containers only while loading. The returned state is a deep
## copy, so a repair cannot mutate the parsed payload or live GameState through
## an alias. Repairs are intentionally not saved back: a malformed save remains
## diagnosable, while this load receives safe defaults for the current run.
func _validate_nested_shapes(state: Dictionary) -> Dictionary:
	var result: Dictionary = SAVE_VALIDATOR.new().validate_state(state)
	for repair in result.get("repairs", []):
		push_warning("SaveValidator: repaired %s" % str(repair))
	return result.get("state", state)

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
	var encoded_version: Variant = payload.get("save_version", 0)
	if not (encoded_version is int or encoded_version is float):
		return {}
	var version := int(encoded_version)
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
			5:
				# v5 → v6: `list_taken` records which 907List opportunities have
				# been consumed today. A v5 save has no such field, and unlike
				# every arm above it, defaulting is not simply correct — it
				# would hand the player back an opportunity they already spent.
				#
				# So this arm reconstructs what it honestly can. A holding
				# bought on the CURRENT day is proof that listing was taken
				# today, and holdings persist, so those ids are recoverable
				# exactly.
				#
				# KNOWN MIGRATION LIMIT, accepted deliberately: a listing bought
				# AND sold on the same day leaves no trace in a v5 save. The
				# holding is gone, and nothing else records the purchase. Those
				# ids cannot be recovered and are not guessed at — the player
				# gets that slot back for the rest of the loading day, once,
				# and every day after behaves correctly.
				#
				# The alternative was suppressing the whole board for the
				# loading day, which punishes every v5 save to be exact about a
				# case most of them never hit. Recovering what is provable and
				# naming what is not is the honest trade.
				var day_value: Variant = state.get("day", 0)
				var current_day := int(day_value) if (day_value is int or day_value is float) else 0
				var recovered: Array = []
				var holdings: Variant = state.get("list_holdings")
				if holdings is Array:
					for entry in (holdings as Array):
						if not (entry is Dictionary):
							continue
						var held: Dictionary = entry
						if int(held.get("bought_day", -1)) != current_day:
							continue
						var item_id := str(held.get("item_id", ""))
						if not item_id.is_empty() and not item_id in recovered:
							recovered.append(item_id)
				state["list_taken"] = {"day": current_day, "ids": recovered}
			6:
				# v6 → v7: crew_assignments and crew_operation_state are
				# additive and default in. A v6 save never ran an operation, so
				# empty IS its history — the same argument the v3 → v4 attribute
				# arm makes, and it holds for the same reason.
				#
				# The one transform is ownership. Delegated buying (FS-001.7)
				# will tag holdings with who bought them, and a holding with no
				# tag would then be ambiguous rather than simply old. Every
				# holding in a v6 save was bought by the player — there was no
				# other way to buy one — so that is stamped rather than inferred
				# later. Cheap to do now, impossible to reconstruct afterwards.
				var carried: Variant = state.get("list_holdings")
				if carried is Array:
					for entry in (carried as Array):
						if entry is Dictionary and not (entry as Dictionary).has("source"):
							(entry as Dictionary)["source"] = "player"
			7:
				# v7 → v8: the Consequence-Encounter Engine's state, TI-003 §5.
				#
				# Everything except the wallet is additive and defaults empty.
				# Empty is not a fallback here — it is the only true answer. A
				# v7 save cannot hold an unfinished consequence, a prior arrest,
				# a Boost ban or a Pressure score, because none of those systems
				# existed while it was being played. TI-003 §20 says the same:
				# "A pre-TI-003 Godot save contains no unfinished consequence,
				# so migration creates no inferred active chain."
				#
				# The WALLET is the one transform, and it is the v6 → v7
				# `source: "player"` case again: stamp what is knowable while it
				# is still knowable. A v7 save records one aggregate `cash` and
				# nothing about where it came from. Every day it stays
				# un-migrated is a day that number could be split by a rule
				# nobody wrote down, so the rule is written down here, once.
				#
				# TI-003 §20 step 2-3 and §26 rule the whole aggregate CLEAN:
				# "Old Godot saves enter with prior aggregate Cash classified
				# Clean." That is a DELIBERATE DIVERGENCE from canon, which
				# classifies its own pre-split saves dirty (game-core.js:2060) on
				# the grounds that nothing in pre-split play ever laundered
				# anything. Both readings are argued in
				# `WalletSystem.classify_legacy_total()`; TI-003 is the approved
				# implementation contract for this port and wins.
				#
				# Done arithmetically rather than by calling the wallet, because
				# migration runs on a plain Dictionary before any of it reaches
				# GameState and before a system instance is in play. The rule is
				# identical and `_check_v8_migration` asserts the two agree.
				var carried_cash: Variant = state.get("cash", 0)
				var aggregate: int = int(carried_cash) \
					if (carried_cash is int or carried_cash is float) else 0
				state["clean_cash"] = maxi(0, aggregate)
				state["dirty_cash"] = 0
			8:
				# v8 → v9: `consequence_flags` is additive and defaults to an
				# empty Dictionary. Empty is the only true answer for the same
				# reason the v3 → v4 attribute arm defaults: every flag in there
				# records "this has already been shown to the player once", and
				# a v8 run has never shown any of them.
				#
				# FS-003.13's arrest cooldown needs no arm of its own. It lives
				# inside `arrest_record`, which v8 already persists whole, and a
				# v8 record comes back without the key — which
				# `ArrestSystem.cooldown_until_day()` reads as -1, meaning no
				# cooldown. Arming a cooldown here from `last_arrest_day` would
				# be worse than doing nothing: it would suppress arrests on a
				# loaded run for a booking the mechanic did not exist during.
				pass
			9:
				# v9 -> v10: the surface-visibility facts, plus the HOT lever's
				# banked recovery.
				#
				# `pressure_clean_credits` needs no arm. It is a WITHIN-DAY ledger
				# that empties every night, and a v9 save was written by a build with
				# no clean-recovery lever at all, so empty is not a default standing
				# in for history -- it is the history.
				#
				# The other two are stamped rather than defaulted, and the difference
				# matters. A v9 run has a real past: it may hold six corners and have
				# Deshawn on the crew. Defaulting `districts_unlocked` to
				# `["north_star_lot"]` would take Downtown away from somebody who has
				# been trading there for a fortnight, and defaulting `job_contacts`
				# to 0 would re-lock Jobs on a run that has been working them.
				#
				# So the arm derives both from state v9 already carries -- the same
				# derivation `GameState._reconcile_progression_latches()` runs on
				# every dispatch, applied once to the loading save. That also makes
				# this arm redundant-by-design rather than load-bearing: the reconcile
				# would settle both on the next action anyway, and the arm only stops
				# the surfaces reading locked for the frame in between.
				var blocks: Variant = state.get("held_blocks")
				var corners: int = (blocks as Dictionary).size() \
					if blocks is Dictionary else 0
				var known: Array = ["north_star_lot"]
				if corners >= 1:
					known.append("downtown")
				if corners >= 2:
					known.append("airport_industrial")
				state["districts_unlocked"] = known
				var records: Variant = state.get("crew_records")
				var contacts: int = 0
				if records is Dictionary:
					for contact_id in ["deshawn", "pherris"]:
						var record: Variant = (records as Dictionary).get(contact_id)
						if record is Dictionary \
								and bool((record as Dictionary).get("recruited", false)) \
								and str((record as Dictionary).get("status", "active")) == "active":
							contacts += 1
				state["job_contacts"] = contacts
			10:
				# v10 -> v11: the venue interiors. Every field is additive and
				# every default IS the history rather than standing in for it —
				# a v10 save was written by a build with no gym and no counter
				# to walk into, so zero sessions, no streak and nothing entered
				# is exactly what happened.
				#
				# The one thing worth being explicit about: `jobs_discovered` is
				# NOT touched. The Night Owl shift has been unreachable in every
				# build up to this one, and a v10 run has genuinely never been
				# offered it. Stamping it in would hand a loading save a job it
				# was never told about; walking into the counter offers it, the
				# same as for a fresh run.
				pass
			11:
				# v11 -> v12: Heat's teeth. Both fields are additive.
				#
				# `heat_gain_today` defaults to 0.0, which reads as "nothing
				# loud has happened today" — and for a v11 save that is not a
				# guess. The field did not exist, so the day it was written on
				# has no record either way, and the generous reading costs the
				# player at most one 0.75 decay they might not have earned.
				# Defaulting the other way would charge every loading save for a
				# day it may well have spent doing nothing.
				#
				# `lay_low_day` defaults to -1, which no real day equals, so a
				# loading run may go quiet once today. A v11 build had no cap at
				# all, so this cannot take away something the save was relying
				# on having already spent.
				pass
			_:
				return {}
		version += 1
	for key in REQUIRED_KEYS:
		if not state.has(key):
			return {}
	if not (state["day"] is int or state["day"] is float):
		return {}
	if not (state["cash"] is int or state["cash"] is float):
		return {}
	if not (state["street_name"] is String):
		return {}
	return state

## Write the saved fields back. Every field begins from a fresh GameState
## instance, then the save overlays fields it carries — canon's mergeDefaults.
## Reading defaults from the current singleton is unsafe: a legacy load can
## happen after a run has already mutated it (game over routes back to Title),
## and omitted additive fields would inherit that live run instead of defaults.
func _apply(state: Dictionary) -> void:
	var defaults: Node = preload("res://autoload/game_state.gd").new()
	for field in PERSIST_FIELDS:
		var default_value: Variant = defaults.get(field)
		var incoming: Variant = state.get(field, default_value)
		gs.set(field, _coerced(default_value, _deep(incoming)))
	defaults.free()
	var prices: Dictionary = state.get("product_prices", {})
	for prod in gs.products:
		var id := str(prod.id)
		if prices.has(id):
			prod.price = clampi(int(prices[id]), int(prod.min), int(prod.max))
	_classify_loaded_wallet(state)

## Guarantee `cash == dirty_cash + clean_cash` on everything that loads.
##
## From v8 the buckets are persisted and the migration arm has already split any
## older aggregate, so the normal path here does nothing at all. It stays for the
## case the arm cannot cover: a v8 payload whose bucket fields are absent or
## malformed, which `_apply` fills from GameState's defaults rather than from
## this save. Those defaults belong to a different balance, so without this the
## invariant would load broken.
##
## Reconcile rather than reclassify: a save that carries real buckets keeps them,
## and only the drift is folded. That is canon's rule (dirty-first) and it is the
## right one here — a v8 save with buckets that do not sum has been edited or
## truncated, and its provenance is no longer trustworthy enough to call clean.
func _classify_loaded_wallet(state: Dictionary) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var wallet: Object = gm.system("wallet") if gm != null else null
	var carried := state.has("dirty_cash") and state.has("clean_cash")
	if wallet == null:
		# No manager (a load driven before systems exist). Fold by hand so the
		# invariant still holds; the arithmetic is the wallet's, inlined.
		var drift: int = int(gs.cash) - (int(gs.dirty_cash) + int(gs.clean_cash))
		if drift > 0:
			gs.dirty_cash = int(gs.dirty_cash) + drift
		elif drift < 0:
			var deficit: int = -drift
			var from_dirty: int = mini(int(gs.dirty_cash), deficit)
			gs.dirty_cash = int(gs.dirty_cash) - from_dirty
			gs.clean_cash = maxi(0, int(gs.clean_cash) - (deficit - from_dirty))
		return
	if not carried:
		# Not reachable from a migrated payload — the v7 arm writes both fields —
		# but a hand-edited or truncated v8 save can land here, and TI-003 §20's
		# rule is the right answer for a total with no provenance at all.
		wallet.classify_legacy_total()
		return
	wallet.reconcile()

func _deep(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

func _coerced(current: Variant, incoming: Variant) -> Variant:
	match typeof(current):
		TYPE_INT:
			if not (incoming is int or incoming is float or incoming is bool or incoming is String):
				return current
			return int(incoming)
		TYPE_FLOAT:
			if not (incoming is int or incoming is float or incoming is bool or incoming is String):
				return current
			return float(incoming)
		TYPE_BOOL:
			if not (incoming is bool):
				return current
			return bool(incoming)
		TYPE_STRING:
			if not (incoming is String):
				return current
			return str(incoming)
		TYPE_DICTIONARY:
			return incoming if incoming is Dictionary else _deep(current)
		TYPE_ARRAY:
			return incoming if incoming is Array else _deep(current)
		_:
			return incoming

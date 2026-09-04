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
## stats, inventory, jobs/obligations, all six hustle surfaces, today's
## day-scoped earnings, crew records and the wage clock, territory, the
## exposure substrate (npc_ledgers + observation_queue) and every Curtis
## awareness field — plus the current market prices as a {product_id: price}
## slice. Canon tables (districts, products' static fields, stick_targets,
## crew_roster, …) and the UI-scaffold placeholders that no system writes yet
## (hustle_surfaces, active_operation) are NOT
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
##
## v15 (batch 14): adds `boost_targets_discovered`, the Boost discovery latch.
## Additive, and the arm stamps the version only. An empty array is the honest
## history rather than a default standing in for one: a v14 run was written by a
## build where every target in range was on the screen from the first minute, so
## it has never once been out LOOKING for one. On load every target starts
## undiscovered and has to be found through play, the same as for a fresh run --
## the call the v11 arm made about the Night Owl and the v13 arm made about
## `jobs_discovered`, for the same reason.
##
## v17: adds `market_discovered`, the Street Market discovery latch (PR 4).
## Additive. The v16 -> v17 arm does not simply default it false: a v16 save
## was written by a build where Market opened the moment `wander_count`
## reached 1, so a save with a walk already behind it has EARNED the surface
## under the rule that was live when it was written. Re-hiding it on load
## would take away something the player already has, which is a worse
## failure than the migration doing nothing — the same argument the v10 arm
## makes for re-deriving `districts_unlocked` rather than defaulting it
## empty.
## v20: replaces the dormant `debt`/`debt_due_days` pair with a structured
## `dre_account` (Dre Lending & Loan-Shark Progression, PR A). Those two
## fields leave PERSIST_FIELDS entirely — `GameState.debt`/`debt_due_days`
## are computed properties now, so writing them back through the generic
## `gs.set(field, ...)` loop would hit a read-only property and fail. The
## v19 -> v20 arm reads them out of the RAW state dict one last time (they
## are still real keys in a v19 payload), builds the account they describe,
## and erases them from the dict rather than leaving two unread keys sitting
## in every save henceforth. A zero legacy debt becomes a clear account,
## honestly never having met Dre; a positive one becomes an active/due/
## overdue account carrying the whole flat amount as principal, because a
## principal/interest split the old field never recorded cannot be repaired,
## only guessed at, and this migration does not guess.
## v21: `dre_intro_offered` (Dre Lending PR B) -- purely additive, one bool
## latching whether Juan's day-start mention has fired yet.
## v22: no new fields — the scrolling-degradation fix. The arrays that grew
## without bound (measured to ~1,400 Phone-screen nodes and a six-figure-byte
## save by a driven day 60) are bounded at runtime from this build on:
## `phone_inbox`/`phone_held_inbox` hold `GameState.PHONE_INBOX_MAX` each
## (newest kept); `shark_loans` sheds terminal notes (repaid / forgiven /
## enforced) on each night's settle; and the consequence layer sheds what it is
## provably done with each morning — terminal queue rows (resolved / expired)
## and history rows for Causes nothing can address again (not the active
## chain's, no pending/surfaced queue row; the liveness audit lives on
## `ConsequenceEngine.prune_settled`). The arm applies all of it once to a
## loading v21 save, so a long run's save gets its relief at load rather than
## trickling in push by push.
## v23: `opportunity_offers`, `active_opportunities`, `opportunity_history`,
## `opportunity_next_instance_id` (Street Opportunity and Mission System, PR
## C). GameState declared these fields one version early -- v22's PR landed
## them by accident alongside unrelated work -- so this bump is the first one
## that actually reads or writes them. Purely additive: no v22 save has ever
## seen an opportunity offered, so empty arrays/dict and a fresh counter are
## that save's honest history, the same call the v3 -> v4 and v4 -> v5 arms
## make for their own untouched-until-now fields.
## v24: `dre_pending_penance` (Dre Lending PR D, DRE-ARC-03 / restitution) --
## purely additive, one bool latching whether a cleared-by-payment suspension
## still owes its follow-up penance contract. No v23 save has ever suspended
## through the real collection encounter this build adds, so `false` is that
## save's honest history.
## v25: `wander_quiet_streak` (The Street Answers Back PR A, STR-D2) --
## purely additive, one counter of consecutive quiet wanders that did not
## exist as a concept before this build's interruption gate. No v24 save has
## ever had a streak running, so `0` is that save's honest history -- the
## same call `wander_misses` itself got at v13.
## v26: `hustles_discovered` (The World Speaks PR 1, WS-D1) -- the hustle
## paths the run has been shown. A v25 save had every path on the board by
## its own old rules (Market on its latch, Boost at three walks, Stickup on
## day two, 907List on day three), so the migration derives the array from
## exactly those rules: nothing a v25 player could already see closes on
## them. A fresh run starts empty, and `jobs_discovered` starts with Wash & Go
## alone -- no migration needed for that one, an old save keeps what it knew.
## v27: `phone_reply_history` (The World Speaks PR 3, WS-D3) -- how the
## player has answered each NPC's texts. Purely additive: no v26 save ever
## answered anybody, because nobody could be answered. Empty is that save's
## honest history.
## v28: `job_applications` (The Block Remembers PR 1, BR-D2) -- applications
## in flight. Additive: no earlier save ever had one pending, because the
## interview resolved on the tap.
## v29: `rent_arrears_day` (One Good Run PR 1, OG-D1) -- the rent
## escalation clock. Additive: -1 for every earlier save, which is "not in
## arrears", and a save that was would have rolled its due day already.
## v30: `weapon`, `vehicle`, `trunk` (One Good Run PR 3, OG-D3) -- the
## player's kit. Additive: hands, no car, nothing in a trunk that does not
## exist.
## v31: `game_over_kind`, `leaving`, `run_earnings` (One Good Run PR 4,
## OG-D4) -- the ending. Additive.
## v32: `hot_goods` (One Good Run PR 5, OG-D5) -- what the Lift walked out
## with and has not fenced. Additive: an empty coat.
const SAVE_VERSION := 32
const SAVE_VALIDATOR := preload("res://autoload/save_validator.gd")
const TERRITORY_DEFS := preload("res://data/territory_definitions.gd")

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
	"cash", "heat", "health", "crew_power",
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
	# Crew + territory (territory_nodes/territory_fronts: v16, FS-002.3)
	"crew_records", "territory_nodes", "territory_fronts", "soldiers_idle",
	# Exposure substrate
	"npc_ledgers", "observation_queue",
	# Curtis awareness
	"curtis_awareness", "curtis_phase", "curtis_floor", "curtis_quiet_streak",
	"curtis_last_criminal_day", "curtis_watchers_seen", "curtis_last_watcher_day",
	"curtis_recent_watcher_lines", "curtis_phase_messages_sent",
	# Feed
	"activity_log",
	# Day-scoped earnings (PR 2, playtest finding 3)
	"todays_earnings",
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
	# Wander (v13). The ramp and the seen-cards ledger; both are the run's own
	# history of going out and looking, and neither can be reconstructed.
	"wander_misses", "wander_count", "wander_seen", "wander_recent",
	# The hustle latches (v26, WS-D1). One-way discovery, like the two axes
	# above it; what the city has shown you cannot be reconstructed.
	"hustles_discovered",
	# The reply history (v27, WS-D3): counts per NPC of answered, distanced
	# and ghosted texts. What a future text reads to know who you are.
	"phone_reply_history",
	# Applications in flight (v28, BR-D2).
	"job_applications",
	# The rent escalation clock (v29, OG-D1).
	"rent_arrears_day",
	# The kit (v30, OG-D3).
	"weapon", "vehicle", "trunk",
	# The ending (v31, OG-D4).
	"game_over_kind", "leaving", "run_earnings", "curtis_doorstep",
	# Stolen goods (v32, OG-D5).
	"hot_goods",
	# The interruption gate's quiet streak (v25, STR-D2). Same reasoning as
	# wander_misses above: the run's own history of a mechanic that reads it.
	"wander_quiet_streak",
	# The day's walk count (v14), for the effort falloff.
	"wanders_today",
	# Boost's discovery axis (v15). A one-way latch like `districts_unlocked`:
	# what the player has clocked cannot be reconstructed from anything else,
	# because the alternative history -- never having walked past it -- leaves
	# exactly the same trace.
	"boost_targets_discovered",
	# Market's discovery latch (v17). Same shape, same reason.
	"market_discovered",
	# The Lift's SETTLE IT valve (v18). Same shape as boost_store_bans, same
	# reason: a store already bought this run cannot be reconstructed from
	# anything else.
	"boost_bribes_used",
	# Word of Mouth's active payloads and drought counter (v19). A live
	# fat-night window is exactly as irreplaceable as a bought-off store --
	# it names a day, a target and a multiplier nothing else in the save
	# carries, and the ramp counter is `wander_misses` again under a new
	# name.
	"tip_effects",
	"tip_misses",
	# Dre Lending & Loan-Shark Progression, PR A (v20). Replaces the dormant
	# `debt`/`debt_due_days` pair -- see the migration arm and GameState's
	# computed properties of the same names.
	"dre_introduced", "dre_access_tier", "dre_account", "dre_account_history",
	# PR B (v21): the day-start latch deciding whether Juan's mention has
	# fired. Separate from `dre_introduced` -- see that field's own header.
	"dre_intro_offered",
	# Street Opportunity and Mission System, PR C (v23). The shared substrate
	# Dre's first two authored contracts run on -- see systems/opportunities.gd.
	"opportunity_offers", "active_opportunities", "opportunity_history",
	"opportunity_next_instance_id",
	# PR D (v24): the restitution latch. See its own header in game_state.gd.
	"dre_pending_penance",
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
	# `debt` left PERSIST_FIELDS in v20 (GameState.debt is computed off
	# `dre_account` now) -- the raw migrated dict never carries a "debt" key
	# again, so the preview derives the same figure the live getter does
	# rather than reading a key that no longer exists.
	var account: Dictionary = state.get("dre_account", {})
	var owed: int = 0
	if str(account.get("status", "clear")) != "clear":
		owed = int(account.get("principal", 0)) + int(account.get("interest", 0)) \
			+ int(account.get("fee", 0))
	return {"exists": true, "valid": true, "preview": {
		"name": str(state.get("street_name", "")),
		"day": int(state.get("day", 1)),
		"part": str(state.get("time_slot", "MORNING")),
		"district": str(district.get("name", "SPENARD")),
		"cash": int(state.get("cash", 0)),
		"debt": owed,
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
	# Street Opportunity and Mission System, PR C: the same qualifying-load
	# reasoning as crew_ops immediately above, for a save that can already
	# satisfy a definition's requirements — a PR B player who sought Dre out
	# before this system existed never fired the reconcile that offers First
	# Money. See `Opportunities.reconcile_on_load()`'s own header.
	var opportunities: Object = get_node_or_null("/root/GameManager")
	if opportunities != null:
		opportunities = opportunities.system("opportunities")
		if opportunities != null:
			opportunities.reconcile_on_load()
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
			12:
				# v12 -> v13: Wander. Every field is additive and every default
				# IS the history — a v12 save was written by a build whose
				# Wander button spent a slot and printed the weather, so nothing
				# was ever found and no card was ever drawn.
				#
				# `jobs_discovered` is deliberately untouched, the same call the
				# v11 arm made about the Night Owl. A loading run has genuinely
				# never been out looking, and the ramp starts it at the oracle's
				# 30% like anybody else.
				pass
			13:
				# v13 -> v14: `wanders_today`, additive and zero. A v13 save was
				# written by a build where every walk was worth the same, so
				# there is no count to carry — and zero is the generous reading,
				# which hands the loading day a full-value walk it may already
				# have taken. One walk, once, in exchange for not having to
				# invent a number that was never recorded.
				pass
			14:
				# v14 -> v15: `boost_targets_discovered`, additive and EMPTY.
				#
				# This is the one arm in the chain where the empty default is
				# generous to nobody, and it is still the right answer. A v14
				# run could have been lifting Northern Value for a fortnight,
				# and it comes back with the shop off its list until the player
				# walks past it again — which reads as a loss until you ask what
				# the alternative would have to be. Stamping in every target in
				# range would hand a loading save the whole board at once, which
				# is precisely the thing this batch removed; stamping in the
				# ones it has HIT would need `boost_daily_hits`, which is one
				# day deep and holds nothing about the run before today.
				#
				# There is no third option. The field did not exist, a v14 build
				# never asked the question, and a walk is one slot: the honest
				# reading is that the run has never been out looking, and the
				# cost of saying so is a few walks the player was going to take
				# anyway. Named here rather than found out later.
				#
				# `boost_store_bans` is deliberately untouched. A ban is a face
				# somebody remembers, not a place you forgot — re-finding a shop
				# you are banned from does not un-ban you, and the blocker still
				# refuses it in the order it always did.
				pass
			15:
				# v15 -> v16: FS-002.3's canonical Territory state. `held_blocks`
				# (keyed off `spenard_blocks` display rows) becomes
				# `territory_nodes` (keyed off `data/territory_definitions.gd`
				# ids) plus `territory_fronts`. Same ids either way — the six
				# corners never got a second naming scheme — so this is a field
				# rename and a prune, not a re-keying.
				#
				# Dropped per holding: `claimed_day` and `income_collected`.
				# Both are dead. `income_collected` is written once at claim and
				# read nowhere — PR 1's audit of `86bbjxtjb` found the only other
				# write in the whole build was a save fixture setting up a
				# round-trip test. `claimed_day` backs no mechanic that exists.
				# Carrying a dead field into a new field name is how a migration
				# invents a THIRD truth while retiring the second.
				#
				# Soldiers are preserved exactly, clamped non-negative — this arm
				# trusts a save no further than that; `save_validator.gd` is the
				# load-time backstop for anything worse (a non-Dictionary row, a
				# String where soldiers should be).
				#
				# An id the definitions do not carry (an orphan, 86bbjxtab)
				# migrates AS-IS rather than being dropped here. Dropping it here
				# would be silent data loss on every load, before the validator
				# — and its own test coverage — ever gets a say. The validator
				# drops it instead, where the decision shows up in `repairs`.
				var old_blocks: Variant = state.get("held_blocks")
				var new_nodes: Dictionary = {}
				var new_fronts: Dictionary = {}
				if old_blocks is Dictionary:
					for block_id in (old_blocks as Dictionary).keys():
						var rec: Variant = (old_blocks as Dictionary)[block_id]
						if not (rec is Dictionary):
							continue
						var soldiers_value: Variant = (rec as Dictionary).get("soldiers", 0)
						var soldiers: int = int(soldiers_value) 							if (soldiers_value is int or soldiers_value is float) else 0
						new_nodes[str(block_id)] = {"soldiers": maxi(0, soldiers)}
						var def: Dictionary = TERRITORY_DEFS.by_id(str(block_id))
						if str(def.get("starting_owner", "")) == TERRITORY_DEFS.OWNER_CURTIS:
							# D-6 (FS-002.3, docs/DECISIONS.md): a migrated
							# holding is never confiscated, even where the
							# seeding rule says this node starts Curtis-secure.
							# The player already had it — the capture already
							# happened, off camera, before this build could
							# describe it. The capture reward a real FS-002.4/.5
							# takeover will attach is marked spent so it cannot
							# be claimed twice for a corner already free, and the
							# node is flagged contested so a later build can
							# tell this apart from a corner nobody has touched.
							new_fronts[str(block_id)] = {
								"capture_reward_consumed": true,
								"conflict_active": true,
							}
				state["territory_nodes"] = new_nodes
				state["territory_fronts"] = new_fronts
				state.erase("held_blocks")
			16:
				# v16 -> v17: `market_discovered`. A v16 save was written by a
				# build where Market opened the instant `wander_count` reached
				# 1 — so a save with a walk already behind it had ALREADY
				# passed the old gate and the surface was already open. This
				# arm stamps `market_discovered = true` for exactly that case,
				# preserving what the player already has. A save that has
				# never walked (`wander_count == 0`) had not found it under
				# either rule, and comes back false — the honest history
				# either way.
				var walks_value: Variant = state.get("wander_count", 0)
				var walks: int = int(walks_value) \
					if (walks_value is int or walks_value is float) else 0
				state["market_discovered"] = walks >= 1
			17:
				# v17 -> v18: `boost_bribes_used`. Purely additive -- SETTLE IT
				# did not exist before this build, so no v17 save has bought a
				# walk from anywhere, and every one comes back empty.
				state["boost_bribes_used"] = []
			18:
				# v18 -> v19: `tip_effects`, `tip_misses`. Purely additive --
				# Word of Mouth did not exist before this build, so no v18 save
				# has a live tip window or a drought running, and both come
				# back at their fresh-run defaults.
				state["tip_effects"] = []
				state["tip_misses"] = 0
			19:
				# v19 -> v20: `debt`/`debt_due_days` -> `dre_account` and its
				# three siblings. See this arm's own paragraph by SAVE_VERSION
				# for why this reads and erases the two legacy keys instead of
				# defaulting them in blind, same as the v16 -> v17 arm reading
				# `wander_count` before deciding what `market_discovered`
				# should be for a save that predates the field entirely.
				var legacy_debt: int = int(state.get("debt", 0))
				var legacy_due_days: int = int(state.get("debt_due_days", 0))
				state.erase("debt")
				state.erase("debt_due_days")
				state["dre_introduced"] = legacy_debt > 0
				state["dre_access_tier"] = 1 if legacy_debt > 0 else 0
				if legacy_debt > 0:
					var opened_day: int = int(state.get("day", 1))
					var status := "active"
					if legacy_due_days < 0:
						status = "overdue"
					elif legacy_due_days == 0:
						status = "due"
					state["dre_account"] = {
						"status": status, "principal": legacy_debt,
						"interest": 0, "fee": 0,
						"opened_day": opened_day,
						"due_day": opened_day + legacy_due_days,
						"term_days": maxi(legacy_due_days, 0),
						"extension_used": false, "offer_id": "",
					}
				else:
					state["dre_account"] = {
						"status": "clear", "principal": 0, "interest": 0,
						"fee": 0, "opened_day": -1, "due_day": -1,
						"term_days": 0, "extension_used": false, "offer_id": "",
					}
				state["dre_account_history"] = {
					"loans_taken": 0, "repaid_on_time": 0, "repaid_late": 0,
					"extensions": 0, "defaults": 0,
					"total_principal_borrowed": 0, "total_interest_paid": 0,
				}
			20:
				# v20 -> v21: `dre_intro_offered`. Purely additive -- PR B did
				# not exist before this build, so no v20 save has heard Juan's
				# mention yet. A save already carrying `dre_introduced == true`
				# (from a v20 run driven through a test or game_eval, never
				# through real play -- PR A shipped no door onto it) implies
				# the mention already happened; anything else comes back
				# false, the honest history either way.
				state["dre_intro_offered"] = bool(state.get("dre_introduced", false))
			21:
				# v21 -> v22: no new fields — the caps land (see the version
				# header). Trims are one-time transforms of state the runtime
				# now bounds; each keeps the NEWEST messages, honouring each
				# half's own order (inbox newest-first keeps the front, held
				# oldest-first keeps the back). Terminal shark notes drop under
				# the same rule `settle_night` now applies every night; a note
				# with no status at all (the pre-canonical shape older
				# round-trip fixtures carry) is not guessed terminal and stays.
				var cap: int = preload("res://autoload/game_state.gd").PHONE_INBOX_MAX
				var live_inbox: Variant = state.get("phone_inbox")
				if live_inbox is Array and (live_inbox as Array).size() > cap:
					state["phone_inbox"] = (live_inbox as Array).slice(0, cap)
				var held_inbox: Variant = state.get("phone_held_inbox")
				if held_inbox is Array and (held_inbox as Array).size() > cap:
					state["phone_held_inbox"] = (held_inbox as Array).slice(
						(held_inbox as Array).size() - cap)
				var notes: Variant = state.get("shark_loans")
				if notes is Array:
					var open_notes: Array = []
					for entry in (notes as Array):
						if entry is Dictionary and str((entry as Dictionary).get(
								"status", "active")) in ["repaid", "forgiven", "enforced"]:
							continue
						open_notes.append(entry)
					state["shark_loans"] = open_notes
				# The consequence layer's half of the same cleanup, mirroring
				# `ConsequenceEngine.prune_settled` (the liveness audit is on
				# that function): terminal queue rows go, and a history row
				# survives only for a Cause something can still address — the
				# active chain's, or one a pending/surfaced queue row names.
				# A malformed row (no Dictionary, no status) is left for the
				# validator, whose job that is; this arm only applies the
				# retention rule to rows it can read.
				var live_causes: Dictionary = {}
				var carried_active: Variant = state.get("active_consequence")
				if carried_active is Dictionary:
					var active_cause := str((carried_active as Dictionary).get("cause_id", ""))
					if not active_cause.is_empty():
						live_causes[active_cause] = true
				var queue: Variant = state.get("consequence_queue")
				if queue is Array:
					var live_rows: Array = []
					for entry in (queue as Array):
						if not (entry is Dictionary):
							live_rows.append(entry)
							continue
						var queue_row: Dictionary = entry
						if str(queue_row.get("status", "pending")) in ["resolved", "expired"]:
							continue
						live_causes[str(queue_row.get("cause_id", ""))] = true
						live_rows.append(queue_row)
					state["consequence_queue"] = live_rows
				var history: Variant = state.get("consequence_history")
				if history is Dictionary:
					var kept_history: Dictionary = {}
					for cause_id in (history as Dictionary):
						if live_causes.has(str(cause_id)):
							kept_history[cause_id] = (history as Dictionary)[cause_id]
					state["consequence_history"] = kept_history
			22:
				# v22 -> v23: opportunity_offers / active_opportunities /
				# opportunity_history / opportunity_next_instance_id. Purely
				# additive -- see this arm's own paragraph by SAVE_VERSION.
				pass
			23:
				# v23 -> v24: dre_pending_penance. Purely additive -- see this
				# arm's own paragraph by SAVE_VERSION.
				pass
			24:
				# v24 -> v25: wander_quiet_streak. Purely additive -- see this
				# arm's own paragraph by SAVE_VERSION.
				pass
			31:
				# v31 -> v32: hot_goods. Additive; see SAVE_VERSION.
				pass
			30:
				# v30 -> v31: game_over_kind, leaving, run_earnings. A v30 save
				# that was already over was evicted, the only ending it had.
				if bool(state.get("game_over", false)) and str(state.get("game_over_kind", "")).is_empty():
					state["game_over_kind"] = "evicted"
			29:
				# v29 -> v30: weapon, vehicle, trunk. Additive; see SAVE_VERSION.
				pass
			28:
				# v28 -> v29: rent_arrears_day. Additive; see SAVE_VERSION.
				pass
			27:
				# v27 -> v28: job_applications. Additive; see SAVE_VERSION.
				pass
			26:
				# v26 -> v27: phone_reply_history. Purely additive -- see this
				# arm's own paragraph by SAVE_VERSION.
				pass
			25:
				# v25 -> v26: hustles_discovered, derived from the gates a v25
				# save opened by rule, so nothing it could see closes on it.
				var known: Array = []
				if bool(state.get("market_discovered", false)):
					known.append("market")
				if int(state.get("wander_count", 0)) >= 3:
					known.append("boost")
				if int(state.get("day", 1)) >= 2:
					known.append("stickup")
				if int(state.get("day", 1)) >= 3:
					known.append("list")
				state["hustles_discovered"] = known
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

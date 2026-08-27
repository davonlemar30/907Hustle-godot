extends Node
## GameState — the single source of truth for the run.
##
## Runtime state is mutated by systems through GameManager.dispatch(); screens
## read it and refresh from state_changed. Static tables remain alongside the
## mutable run fields for now, while SaveSystem explicitly persists only the
## mutable manifest.

## Emitted after any batch of state changes. Screens connect to this and re-render
## everything in one pass (the web-reducer pattern). Call notify_changed() after
## mutating fields to trigger a refresh.
signal state_changed
## Emitted while the clock STILL READS the day that is finishing, immediately
## before it advances. `ended_day` is passed explicitly so a listener never has
## to reason about whether it sits above or below the increment.
##
## This is canon's shape. `confirmDayEnd` (game-core.js:6601) does every piece of
## night settlement while `run.day` is still `oldDay`, then bumps the clock near
## the end — and canon's own comment on `applyAttendance(state, oldDay)` says
## why the day is a parameter rather than a read: *"so the rung does not depend
## on sitting above the `run.day = oldDay + 1` line further down."*
##
## `day_crossed` below fires AFTER the increment and keeps its existing meaning.
## Two signals rather than one because the port already has listeners written
## against each answer: jobs and obligations both derive `gs.day - 1` today,
## which is exactly the compensation this removes the need for in new code.
signal day_ending(ended_day: int)
## Emitted when the run rolls past NIGHT into a new day. Listeners see the NEW
## day on the clock — unchanged semantics, and deliberately so.
signal day_crossed

# --- Run clock -------------------------------------------------------------
var day: int = 14
# Uppercase slot name shown in the top bar; the ordered set lives in TimeSystem.
var time_slot: String = "EVENING"
var time_slots_today: int = 2  # 0 MORNING · 1 AFTERNOON · 2 EVENING · 3 NIGHT
var run_seed: String = "907hustle"
var city: String = "ANCHORAGE, AK"
var current_district_id: String = "north_star_lot"

# --- Player stats (value / max) -------------------------------------------
var cash: int = 847
# Money provenance (TI-003 §5-6). `cash` above stays the one visible total and
# the one number every blocker checks; these two ride underneath it, and
# WalletSystem holds the invariant `cash == dirty_cash + clean_cash`.
#
# Persisted from v8 (FS-003.4). A v7 save carries neither, so its arm classifies
# the whole aggregate through `WalletSystem.classify_legacy_total()` — TI-003
# §20's rule, which deliberately differs from canon's. The defaults below match
# the `cash` default so a fresh GameState is already balanced.
var dirty_cash: int = 0
var clean_cash: int = 847
# Accumulated by high-visibility dirty spending (TI-003 §6), persisted from v8.
# The decay-and-fold rollover that reads it is §17, which is FS-003.9.
var financial_pressure: int = 0
# Heat is fractional. Canon carries it as a float and logs it to one decimal
# (`Math.round(addedHeat * 10) / 10`), and it has to stay fractional here or the
# multipliers that scale it round away to nothing — Deshawn's 0.80 against a
# base-2 stickup is 1.6, which as an int is just 2 again.
var heat: float = 6.0
var heat_max: int = 15
var health: int = 78
var health_max: int = 100
var debt: int = 1200
var debt_due_days: int = 2
var cargo_max: int = 10  # canon: web cargoCapacity
var respect: int = 4

# --- Attributes (canon: src/data/attributes.js) ----------------------------
## Canon's three: combat, charisma, intelligence. Stored 0..12, starting at 1.
## **Formulas do not read these directly** — they read `attributes.compat()`,
## which offsets onto the pre-v1.10 1-5 scale those formulas were tuned against.
## See systems/attributes.gd's header; getting this wrong is worth ~40% of the
## run economy by canon's own measurement, and this port had it wrong from
## Phase 3d until Phase 5c.
var attributes: Dictionary = {"combat": 1, "charisma": 1, "intelligence": 1}
## Fractional progress toward the next whole point, per attribute. Canon banks
## growth here and spends 1.0 at a time, so the player crosses a threshold
## rather than watching a decimal climb.
var attribute_progress: Dictionary = {"combat": 0.0, "charisma": 0.0, "intelligence": 0.0}
var crew_power: int = 11

# Numeric holdings per product id — the economy's source of truth. cargo_used()
# is the sum, shown in the HUD as cargo. Buy/sell mutate this via the economy system.
var inventory: Dictionary = {"weed": 4, "shrooms": 2, "pills": 3}

func cargo_used() -> int:
	var n := 0
	for q in inventory.values():
		n += int(q)
	return n

# --- Districts (canon: src/data/locations.js NEIGHBORHOODS) ----------------
# risk/police/rival are the raw 0-4 scores; travel is the how-you-get-there.
## market_role / bias / availability are canon NEIGHBORHOODS data (src/data/
## locations.js): market_role gates the availability roll ceiling ("Outer" rolls
## higher), bias multiplies a product's base into this area's price anchor
## (absent id = 1.0, flat citywide), availability is the nightly restock chance
## per product. `role` here stays the DISPLAY string; canon's role lives in
## market_role so the two never collide.
var districts: Array = [
	{"id": "north_star_lot", "name": "SPENARD", "role": "HOME TURF", "risk": 1, "police": 1, "rival": 0, "accent": Color(0.842, 0.842, 0.842), "blurb": "Safest footing in the city. Thin margins, low patrol.",
		"market_role": "Home",
		"bias": {"weed": 0.78, "shrooms": 0.88, "cocaine": 1.02, "meth": 0.95},
		"availability": {"weed": 1.0, "shrooms": 0.88, "pills": 0.82, "lean": 0.7, "coke": 0.62, "molly": 0.68, "cocaine": 0.55, "meth": 0.48}},
	{"id": "downtown", "name": "DOWNTOWN", "role": "COMMERCIAL", "risk": 2, "police": 3, "rival": 1, "accent": Color(0.882, 0.263, 0.196), "blurb": "Nightlife money moves fast under cameras and Curtis's buyers.",
		"market_role": "Commercial",
		"bias": {"weed": 1.08, "shrooms": 1.32, "cocaine": 1.46, "meth": 1.08},
		"availability": {"weed": 0.9, "shrooms": 0.9, "pills": 0.82, "lean": 0.78, "coke": 0.8, "molly": 0.86, "cocaine": 0.78, "meth": 0.58}},
	{"id": "airport_industrial", "name": "SHIP CREEK", "role": "PORT CORRIDOR", "risk": 4, "police": 2, "rival": 3, "accent": Color(0.604, 0.114, 0.094), "blurb": "Loading yards, rare supply, and expensive mistakes.",
		"market_role": "Outer",
		"bias": {"weed": 1.12, "shrooms": 1.18, "cocaine": 1.32, "meth": 1.62},
		"availability": {"weed": 0.72, "shrooms": 0.7, "pills": 0.7, "lean": 0.74, "coke": 0.78, "molly": 0.72, "cocaine": 0.7, "meth": 0.86}},
]

# --- Per-area markets (canon: state.world.markets) -------------------------
## area_id -> {prices: {pid: int}, availability: {pid: int}, history: {pid: [int]},
## updated_at: int}. Walked nightly by economy.evolve() off the rng_state stream.
var markets: Dictionary = {}
## The xorshift32 stream cursor, canon state.run.rngState. Owned by whoever
## draws from the stream (today: the market walk); written back after a batch.
var rng_state: int = 0

## Canon initialMarket (game-core.js:1323) for every area, in districts order —
## which is canon NEIGHBORHOODS order, and initialMarket is createRun's FIRST
## stream consumer (proven by the parity generator's offset-0 verification), so
## a new run's markets here are byte-identical to the web build's for the same
## numeric seed. The walk primitives are static on economy.gd — one source of
## truth for the formula, whether the caller is this init or the nightly evolve.
func init_markets() -> void:
	var economy_script := preload("res://systems/economy.gd")
	var stream = get_node("/root/RngManager").make_stream(run_seed)
	markets = {}
	for d in districts:
		markets[d["id"]] = economy_script.walk_initial_area(d, products, stream)
	rng_state = stream.state
	economy_script.sync_display_prices(self)

# --- Spenard local venues (canon: Locations doc + jobs/gambling data) -------
var spenard_venues: Array = [
	{"name": "Home", "tag": "BASE", "desc": "Your unit off Spenard Road. Rent weekly, Yalonda next door."},
	{"name": "Night Owl", "tag": "SOCIAL", "desc": "Mina's counter. A shift, a coffee, word around town."},
	{"name": "Spenard Gym", "tag": "TRAIN", "desc": "Build strength. Let some heat cool off."},
	{"name": "The Nile", "tag": "CARDS", "desc": "Biniam's game. Gamble and hear what's moving."},
]

var personal_contacts: int = 3

# --- Market products (canon: src/data/products.js + per-district anchors) --------
# price = the current district's anchor (base x district bias). role folds in the
# owned quantity for the mid-game snapshot; hint is the route read for this district.
# trend ("up"/"flat") drives the hint's arrow icon — it is a field rather than a
# glyph in the hint string because no theme font carries an arrow.
var products: Array = [
	{"id": "weed", "name": "WEED", "role": "DEPENDABLE · OWN 4oz", "owned": "4oz", "route": "+$11 Ship Creek", "color": Color(0.451, 0.722, 0.404), "price": 27, "base": 34, "volatility": 0.12, "min": 18, "max": 68, "hint": "SELL SHIP CREEK  +$11", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "shrooms", "name": "SHROOMS", "role": "VOLATILE · OWN 2", "owned": "2", "route": "+$36 Downtown", "color": Color(0.373, 0.663, 0.847), "price": 72, "base": 82, "volatility": 0.25, "min": 35, "max": 180, "hint": "SELL DOWNTOWN  +$36", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "pills", "name": "PILLS", "role": "STEADY MARGIN · OWN 3", "owned": "3", "route": "Stable citywide", "color": Color(0.882, 0.651, 0.227), "price": 105, "base": 105, "volatility": 0.18, "min": 55, "max": 220, "hint": "— STABLE CITYWIDE", "trend": "flat", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "lean", "name": "LEAN", "role": "PREMIUM", "owned": "0", "route": "Downtown margin", "color": Color(0.62, 0.5, 0.85), "price": 155, "base": 155, "volatility": 0.22, "min": 80, "max": 330, "hint": "+30% MARGIN DOWNTOWN", "trend": "up", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "coke", "name": "COKE", "role": "HIGH MARGIN", "owned": "0", "route": "Stable citywide", "color": Color(0.9, 0.89, 0.86), "price": 290, "base": 290, "volatility": 0.3, "min": 145, "max": 690, "hint": "— STABLE CITYWIDE", "trend": "flat", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "molly", "name": "MOLLY", "role": "CLUB DEMAND", "owned": "0", "route": "Downtown margin", "color": Color(1, 0.29, 0.239), "price": 215, "base": 215, "volatility": 0.28, "min": 105, "max": 480, "hint": "+30% MARGIN DOWNTOWN", "trend": "up", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "cocaine", "name": "COCAINE", "role": "PREMIUM", "owned": "0", "route": "+$127 Downtown", "color": Color(0.85, 0.72, 0.42), "price": 296, "base": 290, "volatility": 0.3, "min": 145, "max": 690, "hint": "SELL DOWNTOWN  +$127", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "meth", "name": "METH", "role": "EXTREME RISK", "owned": "0", "route": "Locked", "color": Color(0.6, 0.6, 0.6), "price": 176, "base": 185, "volatility": 0.38, "min": 70, "max": 560, "hint": "NEEDS SHIP CREEK TURF", "trend": "flat", "hint_color": Color(0.827, 0.161, 0.125), "locked": true},
]

# Which products the Home "Market Snapshot" summarizes (by id), in display order.
var home_snapshot: Array = ["weed", "meth", "pills"]

# --- Turf & crew (canon: locations.js TERRITORIES / SPENARD_BLOCKS) --------------
# The Home mini-map is a 12-cell grid. Which cells light up is derived from the
# blocks actually held -- see spenard_blocks / held_blocks further down, which
# the territory system owns. This used to be three hardcoded names.
var map_cells: int = 12
var eli_report: String = "One corner stayed quiet, one got pressured."

# --- Tonight's Operation ---------------------------------------------------------
var active_operation: Dictionary = {
	"title": "TONIGHT'S OPERATION",
	"body": "Curtis is probing Minnesota Off-Ramp. Police pressure rising in North Spenard.",
	"actions": ["MOVE PRODUCT", "POST ELI", "LAY LOW"],
}

# --- Activity feed ---------------------------------------------------------------
## Rows carry the day they were logged on so a screen can ask for "today" —
## canon stamps every entry `Day N · SLOT` (game-core.js logEntry) and the Phone's
## Today's Log filters on it. The editor-time preview rows below are dated to the
## preview day.
var activity_log: Array = [
	{"text": "Afternoon: Sold 3 pills in Midtown.", "day": 14, "time": "3:46 PM", "color": Color(0.451, 0.722, 0.404)},
	{"text": "Morning: Paid bus pass.", "day": 14, "time": "8:12 AM", "color": Color(0.373, 0.663, 0.847)},
	{"text": "Night watch: No arrests yet.", "day": 14, "time": "9:31 PM", "color": Color(0.62, 0.5, 0.85)},
]

# --- Hustle hub (canon: web HustleScreen income surfaces + Curtis) --------------
## Earnings accumulated during the current day, by source category.
## Reset at DAY_START. Persisted so a mid-day reload does not lose today's work.
## Keys: "jobs", "market", "stick", "boost", "shark", "territory", "list"
## (matching the hustle surface ids). The sum is what the Hustle screen shows.
var todays_earnings: Dictionary = {}

## Record an earning in a source category. Called by systems after a successful
## income dispatch. Does not touch `cash` — the system that calls this has
## already credited the wallet. This is bookkeeping, not a transaction.
func record_earning(source: String, amount: int) -> void:
	if amount <= 0:
		return
	todays_earnings[source] = int(todays_earnings.get(source, 0)) + amount

## Today's aggregate earnings. Derived, never stored separately.
func todays_take() -> int:
	var total := 0
	for v in todays_earnings.values():
		total += int(v)
	return total

# The six income surfaces. color = the existing per-row accent (kept as-is so the
# look is unchanged); only the data is driven from here.
var hustle_surfaces: Array = [
	{"id": "jobs", "label": "JOBS", "desc": "Applications, callbacks, and available shifts.", "status": "NIGHT OWL", "detail": "RANK 1 · $55–75 ›", "color": Color(0.451, 0.722, 0.404)},
	{"id": "list", "label": "907LIST", "desc": "Buy low, read the listing, find the next buyer.", "status": "2/4 HELD", "detail": "FLIPPER TIER ›", "color": Color(0.373, 0.663, 0.847)},
	{"id": "market", "label": "STREET MARKET", "desc": "Buy, sell, and finish a market session.", "status": "12 SOLD", "detail": "SESSION OPEN ›", "color": Color(0.882, 0.651, 0.227)},
	{"id": "boost", "label": "BOOST", "desc": "Store lifts, targets, and the fence.", "status": "TIER 1", "detail": "FENCE: DOWNTOWN ›", "color": Color(0.475, 0.733, 0.757)},
	{"id": "stick", "label": "STICKUP", "desc": "Street robbery, registers, and organized work.", "status": "TIER 1", "detail": "2 SUCCESSES ›", "color": Color(1, 0.29, 0.239)},
	{"id": "shark", "label": "SHARK", "desc": "Fund borrowers and resolve defaults.", "status": "1 OPEN", "detail": "$250 OUT ›", "color": Color(0.62, 0.5, 0.85)},
]
# Curtis's people, and how hard they are looking. Canon scale is 0-15, the same
# as Heat, and the phase floors ratchet: once he notices you he does not fully
# forget. Owned by autoload/curtis.gd. This used to be a static 4/8.
const AWARENESS_MAX := 15
var curtis_awareness: int = 0
var curtis_phase: String = "invisible"
## The highest phase floor ever reached. Decay never goes below it.
var curtis_floor: int = 0
var curtis_quiet_streak: int = 0
var curtis_last_criminal_day: int = -1
var curtis_watchers_seen: int = 0
var curtis_last_watcher_day: int = -1
var curtis_recent_watcher_lines: Array = []
var curtis_phase_messages_sent: Array = []

func product_by_id(id: String) -> Dictionary:
	for p in products:
		if p.get("id", "") == id:
			return p
	return {}

## Emit state_changed so every connected screen re-renders. Call after mutations.
func notify_changed() -> void:
	state_changed.emit()

func district_by_id(id: String) -> Dictionary:
	for d in districts:
		if d.get("id", "") == id:
			return d
	return {}

## Heat rounded for display. The stored value stays fractional.
func heat_shown() -> int:
	return int(round(heat))

func current_district() -> Dictionary:
	return district_by_id(current_district_id)

## Label for a district's travel affordance. Derived rather than stored: a baked
## "YOU ARE HERE" string goes stale the moment the player travels.
func travel_label_for(district_id: String) -> String:
	if district_id == current_district_id:
		return "YOU ARE HERE"
	return "BUS · $%d" % TravelFare

## Canon charges the same flat fare in either direction (game-core.js:8718-8760).
const TravelFare := 5

# --- Run identity + lifecycle ---------------------------------------------
## The name the player picks on the name-entry screen. Canon calls this
## state.player.streetName (game-core.js:1511).
var street_name: String = ""

## Longest street name canon accepts (game-core.js:58 STREET_NAME_MAX).
const STREET_NAME_MAX: int = 16

## Port of sanitizeStreetName (game-core.js:83-86). Keeps letters, digits,
## spaces, apostrophes, hyphens and periods; collapses runs of whitespace;
## trims; caps at STREET_NAME_MAX. Trims again because the slice can leave a
## trailing space.
func sanitize_street_name(input: String) -> String:
	var re := RegEx.new()
	re.compile("[^A-Za-z0-9 '\\-.]")
	var out := re.sub(input, "", true)
	var ws := RegEx.new()
	ws.compile("\\s+")
	out = ws.sub(out, " ", true).strip_edges()
	if out.length() > STREET_NAME_MAX:
		out = out.substr(0, STREET_NAME_MAX)
	return out.strip_edges()

## Reset to the canon opening state — the START_RUN branch of the web reducer
## (game-core.js:7415-7458): "$name wakes in Yalonda's spare room with $100 and
## a city that has not opened yet."
##
## Deliberately NOT the CHOOSE_BACKGROUND branch, which starts an established
## week at $375 with a $620 note from Dre. That is a different opening and a
## screen this build does not have.
## The authored catalogues, and the reason this exists.
##
## These ten are DATA, not run state: districts, venues, products, jobs, stickup
## targets, borrowers, listings, tiers, boost targets, the crew roster. Nothing
## in production writes to any of them — audited, and the audit is the check
## `the catalogues are restored by a new run`.
##
## The parity suite writes to them constantly, because a check that wants to know
## what a one-item board does has to build a one-item board. And until batch 9
## `reset_to_new_game()` restored none of them, so a check that swapped a
## catalogue and did not put it back corrupted every check after it.
##
## **That was not hypothetical.** `_check_board_fills` replaced the entire 907List
## catalogue with a single $20 item to prove a short pool yields a short board,
## and never restored it. Every profile the economy instrument measured after
## that point — which is all of them — was trading a one-item board worth about
## $14 a flip. The `flipper` profile has been on record at 4% of the day job
## since batch 3. Measured on a restored catalogue it is 358%. Two batches of
## balance decisions were taken against a number that was an artefact of the
## harness.
##
## Restoring here rather than in the offending check is the difference between
## fixing an instance and closing a class: every check in the suite calls
## `reset_to_new_game`, so no future one can leak a catalogue either.
const CATALOGUE_FIELDS: Array[String] = [
	"districts", "spenard_venues", "products", "jobs", "stick_targets",
	"shark_borrowers", "listing_items", "market_tiers", "boost_targets",
	"crew_roster",
]

## Snapshotted on first use rather than in `_ready`, because an autoload's
## `_ready` ordering against the systems that read it is exactly the
## chicken-and-egg the HANDOFF warns about. The first `reset_to_new_game` of a
## process happens before any check has had a chance to write, so the snapshot
## it takes is the authored data.
var _authored_catalogues: Dictionary = {}

func _restore_catalogues() -> void:
	for field in CATALOGUE_FIELDS:
		if not _authored_catalogues.has(field):
			_authored_catalogues[field] = get(field).duplicate(true)
			continue
		set(field, (_authored_catalogues[field] as Variant).duplicate(true))

func reset_to_new_game() -> void:
	# Authored data first: a run cannot start against a catalogue somebody else
	# left behind.
	_restore_catalogues()
	day = 1
	time_slot = "MORNING"
	time_slots_today = 0
	current_district_id = "north_star_lot"
	cash = 100
	# Canon's START_RUN classifies starting funds clean, and TI-003 §6 lists
	# "starting funds" under Clean income. Set alongside `cash` rather than
	# through the wallet: this is initialization, which is one of the audit's
	# named exceptions, and the wallet is not constructed yet on a title-screen
	# reset.
	dirty_cash = 0
	clean_cash = 100
	financial_pressure = 0
	heat = 0.0
	health = 100
	debt = 0
	debt_due_days = 0
	respect = 0
	attributes = {"combat": 1, "charisma": 1, "intelligence": 1}
	attribute_progress = {"combat": 0.0, "charisma": 0.0, "intelligence": 0.0}
	crew_power = 0
	inventory = {}
	# TI-003 §5 consequence state. A new run has no history, which is not a
	# fallback — it is the only true answer for a run that has not happened.
	next_cause_sequence = 0
	next_consequence_sequence = 0
	active_consequence = {}
	consequence_history = {}
	consequence_queue = []
	last_blocking_delayed_day = -1
	arrest_record = {
		"priors": 0, "last_arrest_day": -1, "charges": [], "cooldown_until_day": -1,
	}
	boost_store_bans = []
	district_pressure = {}
	pressure_bleed_pending = []
	pressure_clean_credits = {}
	consequence_flags = {}
	# Progression starts where the player does: home turf, nobody met.
	districts_unlocked = ["north_star_lot"]
	job_contacts = 0
	# Venues: nothing walked into, nothing trained, no streak running.
	attribute_sessions = {}
	gym_streak = 0
	gym_last_day = -1
	venues_entered = []
	# Heat starts cool, quiet and un-laid-low.
	heat_gain_today = 0.0
	lay_low_day = -1
	# Nothing walked, nothing found, nothing seen.
	wander_misses = 0
	wander_count = 0
	wander_seen = {}
	wander_recent = []
	wanders_today = 0
	# Jobs and obligations reset with the run.
	active_job_id = ""
	job_records = {}
	job_missed = {}
	jobs_discovered = ["wash_go", "spenard_chevron", "rebel_convenience", "northern_value", "day_labor"]
	rent_due_day = 7
	rent_missed = 0
	household_warnings = 0
	phone_due_day = 7
	phone_days_past_due = 0
	phone_active = true
	phone_inbox = []
	phone_held_inbox = []
	phone_reactivate_at_slot = -1
	recovery_introduced = false
	game_over = false
	game_over_reason = ""
	stick_tier = 1
	stick_daily_count = 0
	stick_rep = 0
	stick_attempts = 0
	stick_successes = 0
	stick_organized_hits = 0
	shark_loans = []
	shark_next_loan_id = 1
	list_tier = 1
	list_flips = 0
	list_holdings = []
	list_taken = {"day": 0, "ids": []}
	boost_tier = 1
	boost_technique = 0
	boost_merchandise = 0
	boost_fence_standing = 0
	boost_daily_hits = {}
	# Nothing clocked. Every target has to be found before it can be lifted.
	boost_targets_discovered = []
	# Nobody has shown you the corner yet.
	market_discovered = false
	crew_records = {}
	crew_assignments = {}
	crew_operation_state = {"discovered": [], "adapters": {}}
	territory_nodes = {}
	territory_fronts = {}
	soldiers_idle = 0
	npc_ledgers = {}
	observation_queue = []
	curtis_awareness = 0
	curtis_phase = "invisible"
	curtis_floor = 0
	curtis_quiet_streak = 0
	curtis_last_criminal_day = -1
	curtis_watchers_seen = 0
	curtis_last_watcher_day = -1
	curtis_recent_watcher_lines = []
	curtis_phase_messages_sent = []
	activity_log = []
	todays_earnings = {}
	# Markets walk from the run seed, canon createRun order (initialMarket is
	# its first stream consumer), so the opening board is deterministic.
	init_markets()
	notify_changed()

# --- Jobs (canon: src/data/jobs.js SPENARD_JOBS) ---------------------------
# Pay is a [min, max] band, not a flat rate. A shift rolls inside the band, then
# scales by rank (1 + rank*0.10) and by the approach the player picks.
# slots are indices into TimeSystem.SLOTS: 0 MORNING · 1 AFTERNOON · 2 EVENING · 3 NIGHT.
var jobs: Array = [
	{"id": "wash_go", "name": "Wash & Go Attendant", "pay": [40, 60], "slots": [0, 1, 2, 3], "starter": true, "day_labor": false},
	{"id": "spenard_chevron", "name": "Spenard Chevron Clerk", "pay": [48, 60], "slots": [0, 1, 2, 3], "starter": true, "day_labor": false},
	{"id": "rebel_convenience", "name": "Rebel Convenience Clerk", "pay": [48, 60], "slots": [0, 1, 2, 3], "starter": true, "day_labor": false},
	{"id": "northern_value", "name": "Northern Value Floor Staff", "pay": [48, 60], "slots": [0, 1, 2], "starter": true, "day_labor": false},
	{"id": "night_owl", "name": "Night Owl counter shift", "pay": [55, 75], "slots": [2], "starter": false, "day_labor": false},
	{"id": "juan_warehouse", "name": "Spenard Warehouse Dock", "pay": [70, 95], "slots": [0, 1], "starter": false, "day_labor": false},
	{"id": "ship_creek", "name": "Ship Creek Freight", "pay": [110, 140], "slots": [0], "starter": false, "day_labor": false},
	{"id": "day_labor", "name": "Day Labor Pickup", "pay": [40, 60], "slots": [0, 1], "starter": false, "day_labor": true},
]

## How a shift is worked. Canon JOB_APPROACHES (src/data/jobs.js).
var job_approaches: Array = [
	{"id": "work_hard", "label": "WORK HARD", "pay_mult": 1.10, "xp": 2.0, "health": -2, "desc": "+10% pay · 2 XP · -2 Health"},
	{"id": "socialize", "label": "SOCIALIZE", "pay_mult": 1.0, "xp": 1.0, "health": 0, "desc": "+1 relationship · 1 XP"},
	{"id": "take_it_easy", "label": "TAKE IT EASY", "pay_mult": 1.0, "xp": 0.0, "health": 1, "desc": "+1 Health · no XP"},
	{"id": "learn_job", "label": "LEARN THE JOB", "pay_mult": 1.0, "xp": 1.5, "health": 0, "desc": "1.5 XP · learn the room"},
]

## Canon JOB_RANK_THRESHOLDS — XP needed for rank 1, 2, 3.
const JOB_RANK_THRESHOLDS := [4.0, 8.0, 14.0]

var active_job_id: String = ""
## Per-job bookkeeping, keyed by job id: {xp, rank, last_worked_day, hired_day}.
var job_records: Dictionary = {}
## Consecutive days ended without working, keyed by job id. Working resets it.
var job_missed: Dictionary = {}
## Job ids the player knows about. Canon seeds this from a Week Zero shuffle over
## STARTER_JOB_IDS; here the four starters plus day labour are known from Day 1.
var jobs_discovered: Array = ["wash_go", "spenard_chevron", "rebel_convenience", "northern_value", "day_labor"]

func job_by_id(id: String) -> Dictionary:
	for j in jobs:
		if j.get("id", "") == id:
			return j
	return {}

func approach_by_id(id: String) -> Dictionary:
	for a in job_approaches:
		if a.get("id", "") == id:
			return a
	return {}

func active_job() -> Dictionary:
	return job_by_id(active_job_id)

## Canon jobRankForXp — how many thresholds the XP has passed.
func job_rank_for_xp(xp: float) -> int:
	var rank := 0
	for t in JOB_RANK_THRESHOLDS:
		if xp >= float(t):
			rank += 1
	return rank

## Canon jobPayRange — the band scaled by rank.
func job_pay_range(job_id: String) -> Dictionary:
	var job: Dictionary = job_by_id(job_id)
	if job.is_empty():
		return {}
	var rec: Dictionary = job_records.get(job_id, {})
	var rank: int = int(rec.get("rank", 0))
	var mult: float = 1.0 + float(rank) * 0.10
	var band: Array = job["pay"]
	return {"min": int(round(float(band[0]) * mult)), "max": int(round(float(band[1]) * mult)), "rank": rank}

# --- Obligations (canon: game-core.js WEEKLY_RENT / PHONE_BILL) ------------
## Rent is Yalonda's — the same spare room the name-entry screen refers to.
const WEEKLY_RENT := 150
const PHONE_BILL := 75

var rent_due_day: int = 7
var rent_missed: int = 0
## Canon: household.warnings; 3 means evicted.
var household_warnings: int = 0
const HOUSEHOLD_WARNING_LIMIT := 3

var phone_due_day: int = 7
var phone_days_past_due: int = 0
var phone_active: bool = true

# --- Phone inbox (canon: state.phone.inbox / heldInbox / reactivateAtSlot) --
## Canon keeps one object, `state.phone` = {active, billDueDay, daysPastDue,
## inbox, heldInbox, reactivateAtSlot}. The three scalars above landed with the
## obligations port under flat names and keep them; these are the rest of it.
##
## Row shape is canon's pushPhoneMessage item (game-core.js:735):
##   {id, from, text, day, slot, read, action?}
## `slot` is the SLOT INDEX, not the uppercase name — canon renders it as
## SLOTS[message.slot] and the id is built from the index.
##
## Order matters and the two halves disagree on purpose: a live message is
## unshifted (newest first), a held one is pushed (oldest first), and the flush
## on restoration reverses the held half before prepending it.
var phone_inbox: Array = []
var phone_held_inbox: Array = []
## Canon carries `null` here; -1 is the Godot stand-in for "nothing scheduled".
## Set when a dead line is paid for, cleared by the next slot advance.
var phone_reactivate_at_slot: int = -1

## Canon flags.recoveryIntroduced: once Recovery has been relevant it stays on
## the menu, so a run that heals back to 100 does not lose the screen it just
## used. Set the first time the feature becomes available, never cleared.
var recovery_introduced: bool = false

## Recovery is visible while it is relevant and remains visible after the first
## time it matters. The UI only reads this selector; the persistent latch is
## reconciled by the action/load layers before they announce changed state.
func recovery_available() -> bool:
	return recovery_introduced or health < health_max or heat > 1.0

## Restore invariants whose persisted representation includes a historical
## latch. This must run before notify_changed(): SaveSystem is one listener on
## that signal, so repairing the flag during a screen refresh is already too
## late for the autosave triggered by the same action.
func reconcile_persistent_invariants() -> void:
	if health < health_max or heat > 1.0:
		recovery_introduced = true
	_reconcile_progression_latches()

## The two v0.1.0 discovery latches, re-derived from canonical facts.
##
## Written as "add when the fact is true", never "remove when it is false" —
## that is what makes them one-way. The design pass is explicit about it: once
## the player knows Downtown exists, losing the corner that taught them does not
## take the knowledge back.
##
## Living here rather than in the systems that own the facts is deliberate. Both
## latches read facts from MORE THAN ONE system (territory for blocks, crew for
## the roster), so no single owner can settle them, and this function is already
## the declared place where persistent invariants settle before autosave.
func _reconcile_progression_latches() -> void:
	# Territory expansion is what opens the city. The gate table's own rationale
	# for the two locked districts is "territory not yet expanded", so the fact
	# it reads is the held-block count: one corner earns Downtown, a second
	# earns Ship Creek.
	var corners: int = territory_nodes.size()
	if corners >= 1 and not "downtown" in districts_unlocked:
		districts_unlocked.append("downtown")
	if corners >= 2 and not "airport_industrial" in districts_unlocked:
		districts_unlocked.append("airport_industrial")

	# A way IN to work. Two of them, and batch 16 added the second because the
	# first was not reachable on the run that needs it.
	#
	# The original rule was "somebody recruited whose ROLE is putting people
	# together" — Deshawn the fixer/recruiter and Pherris the connector; Eli
	# runs bundles and Tone stands at a door, and neither knows anybody hiring.
	# That is a good rule and it was the ONLY one, which made the Jobs screen
	# unreachable on a fresh run: Deshawn costs $100 against a starting $100 and
	# then draws $50 a day, with $150 of rent landing on day 7. "Meet someone
	# who hires" was a hint asking the player to go broke to read it.
	#
	# Meanwhile the run STARTS knowing five places that hire, `apply_job`
	# dispatches perfectly well when called, and batch 10 built a whole second
	# path to work — walking the block with LOOK FOR WORK until somebody
	# mentions the freight yard. The gate never learned about it, so a player
	# could be told about a job and still not be allowed through the door to
	# apply for it.
	#
	# So a job you FOUND YOURSELF counts. Not the five you start knowing about —
	# those are what everybody on the block knows and they are true on day one,
	# so counting them would open the gate at reset and make it no gate at all.
	# The two in `DISCOVERY_JOBS` are the ones that have to be turned up, and
	# turning one up is the same achievement as knowing somebody who hires:
	# you now have a way in that you did not have this morning.
	var met: int = 0
	for contact_id in JOB_CONTACT_CREW_IDS:
		if is_recruited(str(contact_id)):
			met += 1
	for job_id in WANDER_EVENTS.DISCOVERY_JOBS:
		if str(job_id) in jobs_discovered:
			met += 1
	job_contacts = maxi(job_contacts, met)

## Crew whose canon role is connecting people to work (see the character pages:
## Deshawn "Fixer / Recruiter", Pherris "Connector").
const JOB_CONTACT_CREW_IDS: Array[String] = ["deshawn", "pherris"]

## The wander discovery pool, for the second way in. Preloaded rather than
## retyped: the list of jobs that must be FOUND is authored in one place, and a
## second copy here would open the gate on a job the walk cannot produce the day
## somebody edits that table.
const WANDER_EVENTS := preload("res://data/wander_events.gd")

var game_over: bool = false
var game_over_reason: String = ""

## Prepend a feed entry. Home shows the newest three, so new events go on top.
## `time` is the slot rather than a clock reading — the run has no wall clock.
func log_activity(text: String, color: Color = Color(0.608, 0.608, 0.608)) -> void:
	activity_log.push_front({"text": text, "day": day, "time": time_slot, "color": color})
	if activity_log.size() > 12:
		activity_log.resize(12)

# --- Stickup (canon: src/data/districts.js STICK_TARGETS) ------------------
# take is a [min,max] band. resistance and heat feed the chance and the cost.
# slots empty means any slot; otherwise indices into TimeSystem.SLOTS.
var stick_targets: Array = [
	{"id": "chilkoots_stumbler", "name": "Stumbler outside Koots", "area": "north_star_lot", "tier": 1, "take": [40, 80], "slots": [3], "resistance": 0, "heat": 2, "desc": "Somebody weaving out of Chilkoot Charlie's alone, cab money visible."},
	{"id": "washgo_regular", "name": "Wash & Go regular", "area": "north_star_lot", "tier": 1, "take": [30, 50], "slots": [], "resistance": 0, "heat": 2, "desc": "Same guy every week. Quarters and a phone, back to the door."},
	{"id": "fourth_ave_crawler", "name": "Fourth Avenue bar crawler", "area": "downtown", "tier": 1, "take": [50, 100], "slots": [2, 3], "resistance": 0, "heat": 2, "desc": "Bar to bar on 4th with a fresh ATM stop in between."},
	{"id": "c_street_atm", "name": "C Street ATM run", "area": "downtown", "tier": 1, "take": [60, 100], "slots": [2], "resistance": 1, "heat": 2, "desc": "Office types pull dinner cash on C Street. Heads down, cards out."},
	{"id": "lot_hauler", "name": "Long-haul driver at the truck lot", "area": "airport_industrial", "tier": 1, "take": [40, 90], "slots": [0, 1], "resistance": 0, "heat": 2, "desc": "Overnighting off International with the cab curtains drawn."},
	{"id": "spenard_fuel_till", "name": "Spenard Chevron night till", "area": "north_star_lot", "tier": 2, "take": [100, 180], "slots": [3], "resistance": 1, "heat": 3, "desc": "One clerk after midnight, and a till that fattens until morning."},
	{"id": "downtown_fuel_till", "name": "Holiday register on C Street", "area": "downtown", "tier": 2, "take": [100, 200], "slots": [], "resistance": 1, "heat": 3, "desc": "The register sits open between customers. One clerk, no partition."},
	{"id": "rec_center_dice", "name": "Dice game behind the rec center", "area": "north_star_lot", "tier": 3, "take": [500, 1200], "slots": [2, 3], "resistance": 2, "heat": 4, "desc": "Folding-table money. Fast pockets, faster tempers, no cameras."},
	{"id": "goodie_stash", "name": "Goodie's stash spot", "area": "north_star_lot", "tier": 3, "take": [800, 1500], "slots": [], "resistance": 3, "heat": 4, "desc": "Everybody knows Goodie keeps a spot. Finding out is the easy part."},
]

## Canon STICK_DAILY_CAP — "two in a day is how people get named."
const STICK_DAILY_CAP := 2
## Canon DISTRICT_DIFF_STEP, how much a point of resistance costs.
const DISTRICT_DIFF_STEP := 0.08

var stick_tier: int = 1
var stick_daily_count: int = 0
var stick_rep: int = 0
var stick_attempts: int = 0
var stick_successes: int = 0
## Tier-3 jobs pulled off. Canon starts telling Curtis at two.
var stick_organized_hits: int = 0

func stick_target_by_id(id: String) -> Dictionary:
	for t in stick_targets:
		if t.get("id", "") == id:
			return t
	return {}

# --- Shark (canon: game-core.js SHARK_BORROWERS / SHARK_TERMS) -------------
var shark_borrowers: Array = [
	{"id": "nora", "name": "Nora Pike", "risk": 0.08, "risk_label": "LOW", "max": 100, "desc": "Food-cart owner covering a repair before the lunch rush."},
	{"id": "jamal", "name": "Jamal Briggs", "risk": 0.18, "risk_label": "MEDIUM", "max": 250, "desc": "Dock worker bridging the week before overtime clears."},
	{"id": "kelsey", "name": "Kelsey Roy", "risk": 0.28, "risk_label": "ELEVATED", "max": 500, "desc": "Bartender with steady cash and inconsistent timing."},
	{"id": "leon", "name": "Leon Grant", "risk": 0.42, "risk_label": "HIGH", "max": 500, "desc": "Street runner whose next score always settles everything."},
]

## Interest rate by term length in days. Shorter term, higher rate.
const SHARK_TERMS := {2: 0.40, 4: 0.25, 7: 0.15}

## The authored term nearest a given one, for input that is not authored.
##
## Nothing the player can reach produces an unauthored term — the Shark screen
## offers three buttons and `_fund` refuses anything else. A SAVE can carry one:
## hand-edited, corrupted, or written by a build whose term table differed. Left
## alone that save loads cleanly and then crashes on the night it settles, in
## `interest_for`, reading a rate that is not there. Snapping is the fail-closed
## answer — the note keeps a rate the player can be shown, and ties go to the
## longer (cheaper) term because a repair should not silently cost them money.
static func nearest_shark_term(term: int) -> int:
	var best: int = -1
	var best_gap: int = 1 << 30
	for authored in SHARK_TERMS.keys():
		var gap: int = absi(int(authored) - term)
		if gap < best_gap or (gap == best_gap and int(authored) > best):
			best = int(authored)
			best_gap = gap
	return best
## Dre takes a cut of the interest on every note that comes back.
const SHARK_DRE_CUT := 0.12

var shark_loans: Array = []
var shark_next_loan_id: int = 1

func borrower_by_id(id: String) -> Dictionary:
	for b in shark_borrowers:
		if b.get("id", "") == id:
			return b
	return {}

# --- 907List (canon: src/data/market.js LISTING_ITEMS / MARKET_TIERS) -------
# A flip market. Every item has a `buy` price and a hidden `true_value` band,
# and four of them are traps: the `rough` ones sell for less than they cost.
# Which fields the board shows you is the tier's whole point — a Scrapper sees
# only title and price, so condition is a guess until Flipper.
var listing_items: Array = [
	{"id": "space_heater", "name": "Space heater", "category": "household", "tier": 1, "buy": 25, "true_value": [42, 58], "condition": "good"},
	{"id": "winter_coat", "name": "Winter coat bundle", "category": "household", "tier": 1, "buy": 35, "true_value": [56, 78], "condition": "good"},
	{"id": "dresser", "name": "Solid dresser", "category": "furniture", "tier": 1, "buy": 40, "true_value": [64, 88], "condition": "good"},
	{"id": "shop_vac", "name": "Shop vacuum", "category": "household", "tier": 1, "buy": 45, "true_value": [71, 97], "condition": "fair"},
	{"id": "used_tv", "name": "Used television", "category": "electronics", "tier": 1, "buy": 55, "true_value": [86, 116], "condition": "good"},
	{"id": "camp_stove", "name": "Camp stove", "category": "household", "tier": 1, "buy": 60, "true_value": [93, 125], "condition": "mint"},
	{"id": "cracked_tv", "name": "Flatscreen, cracked bezel", "category": "electronics", "tier": 1, "buy": 65, "true_value": [30, 48], "condition": "rough"},
	{"id": "sagging_couch", "name": "Couch, sags in the middle", "category": "furniture", "tier": 1, "buy": 60, "true_value": [28, 46], "condition": "rough"},
	{"id": "office_chair", "name": "Ergonomic office chair", "category": "furniture", "tier": 2, "buy": 95, "true_value": [140, 186], "condition": "good"},
	{"id": "bluetooth_speaker", "name": "Bluetooth speaker set", "category": "electronics", "tier": 2, "buy": 105, "true_value": [154, 205], "condition": "mint"},
	{"id": "game_console", "name": "Game console, two pads", "category": "electronics", "tier": 2, "buy": 125, "true_value": [183, 243], "condition": "good"},
	{"id": "chest_freezer", "name": "Chest freezer", "category": "household", "tier": 2, "buy": 140, "true_value": [204, 271], "condition": "fair"},
	{"id": "flood_console", "name": "Console, was in a flood", "category": "electronics", "tier": 2, "buy": 125, "true_value": [58, 92], "condition": "rough"},
	{"id": "sectional_couch", "name": "Leather sectional", "category": "furniture", "tier": 3, "buy": 165, "true_value": [244, 320], "condition": "good"},
	{"id": "dslr_camera", "name": "DSLR body and lens", "category": "electronics", "tier": 3, "buy": 175, "true_value": [258, 340], "condition": "mint"},
	{"id": "dining_set", "name": "Dining set, six chairs", "category": "furniture", "tier": 3, "buy": 185, "true_value": [273, 359], "condition": "good"},
	{"id": "snow_blower", "name": "Two-stage snow blower", "category": "household", "tier": 3, "buy": 195, "true_value": [288, 378], "condition": "good"},
	{"id": "seized_blower", "name": "Snow blower, seized last winter", "category": "household", "tier": 3, "buy": 190, "true_value": [82, 128], "condition": "rough"},
]

## Canon MARKET_TIERS. `fields` is what the board will show at that tier.
var market_tiers: Dictionary = {
	1: {"name": "SCRAPPER", "listings": 2, "capacity": 3, "sell_delay": 1, "shows_condition": false, "quick_sell": false, "blurb": "A random poster with no reputation. Two listings, no detail."},
	2: {"name": "FLIPPER", "listings": 4, "capacity": 4, "sell_delay": 1, "shows_condition": true, "quick_sell": true, "blurb": "Condition, seller reliability, Downtown meetups, quick sells."},
	3: {"name": "BROKER", "listings": 4, "capacity": 6, "sell_delay": 0, "shows_condition": true, "quick_sell": true, "blurb": "Named buyers text what they need. Verified status sells same day."},
}

## Canon: tier 3 opens at ten clean flips.
const BROKER_FLIP_REQUIREMENT := 10
## Tier 2 is the laptop. Canon gates it on a purchase; here it is flips, since
## the gear store is a later feature.
const FLIPPER_FLIP_REQUIREMENT := 3

var list_tier: int = 1
var list_flips: int = 0
## Items currently held, each {item_id, bought_day}.
var list_holdings: Array = []
## Canon `nineZeroSevenList.taken` — which of today's listings have already been
## bought, so the same opportunity cannot be taken twice off one day's board.
##
## Shape is `{day: int, ids: Array[String]}` and the RESET IS LAZY, keyed on the
## day field rather than driven by a day_crossed handler. Canon does it this way
## (`markListingTaken`) and the choice is load-bearing: a save written on day 4
## and loaded on day 9 is correctly empty without anything having run in
## between, and no ordering question arises about whether consumption clears
## before or after the systems that settle on a day cross.
##
## `systems/nine07list.gd` owns every read and write of this. Nothing else
## should touch it.
var list_taken: Dictionary = {"day": 0, "ids": []}

func listing_item_by_id(id: String) -> Dictionary:
	for i in listing_items:
		if i.get("id", "") == id:
			return i
	return {}

func market_tier() -> Dictionary:
	return market_tiers.get(list_tier, market_tiers[1])

# --- Boost (canon: game-core.js BOOST_TARGETS) -----------------------------
var boost_targets: Array = [
	{"id": "night_owl", "name": "Night Owl", "area": "north_star_lot", "tier": 1, "take": [15, 40], "window": -1, "desc": "The counter you already know. The camera by the back aisle has a blind spot everyone in Spenard learned first."},
	{"id": "spenard_fuel", "name": "Spenard Chevron", "area": "north_star_lot", "tier": 1, "take": [15, 40], "window": -1, "desc": "Two pumps and a cooler aisle. The clerk watches the lot, never the shelves."},
	{"id": "fourth_ave_market", "name": "Rebel Convenience on 4th", "area": "downtown", "tier": 1, "take": [15, 40], "window": -1, "desc": "One camera, aimed at the register, exactly like the sticker on the door promises."},
	{"id": "downtown_fuel", "name": "Holiday on C Street", "area": "downtown", "tier": 1, "take": [15, 40], "window": -1, "desc": "The snack aisle sits behind a pillar the security mirror cannot see around."},
	{"id": "service_stop", "name": "Denali Express", "area": "airport_industrial", "tier": 1, "take": [15, 40], "window": -1, "desc": "A truck-stop shop off Old Seward. Everything is bolted down except what you came in for."},
	{"id": "airport_fuel", "name": "Shell on International", "area": "airport_industrial", "tier": 1, "take": [15, 40], "window": -1, "desc": "Half the customers are on the clock and all of them are on their phones."},
	{"id": "northern_value", "name": "Northern Value", "area": "north_star_lot", "tier": 2, "take": [60, 150], "window": 1, "desc": "The Spenard thrift barn. Racks too dense to police, tags too cheap to chase."},
	{"id": "midtown_pharmacy", "name": "Northern Lights Pharmacy", "area": "north_star_lot", "tier": 2, "take": [60, 150], "window": 2, "desc": "The pickup line keeps every eye in the building pointed forward."},
	{"id": "fourth_ave_electronics", "name": "Gateway Electronics on 4th", "area": "downtown", "tier": 2, "take": [60, 150], "window": 3, "desc": "Locked cases up front, open stock in the back. The one clerk cannot be both places."},
	{"id": "warehouse_club", "name": "Arctic Cash & Carry", "area": "north_star_lot", "tier": 3, "take": [200, 500], "window": -1, "desc": "The membership desk checks cards on the way in, never boxes on the way out."},
	{"id": "loading_dock_seven", "name": "Ship Creek Yards, Dock Seven", "area": "airport_industrial", "tier": 3, "take": [200, 500], "window": -1, "desc": "The manifest says more than the fence-line cameras ever will."},
	{"id": "delivery_route_4", "name": "Minnesota Drive Route", "area": "downtown", "tier": 3, "take": [200, 500], "window": -1, "desc": "A box truck running the same loop every day. A schedule is a kind of key."},
]

## Canon: technique >= 5 opens tier 2; tier 3 also needs field-assignable crew.
const BOOST_TIER2_TECHNIQUE := 5
const BOOST_TIER3_TECHNIQUE := 13

## Stickup's ladder, which had rungs authored and no way to climb them.
##
## `stick_tier` was written exactly ONCE in the whole repo — `= 1`, here in
## `reset_to_new_game()` — and `stick_rep` was incremented on every successful
## take and read by nothing at all. So four of the nine authored stick targets
## were unreachable for the entire life of a run: both tier-2 tills, the dice
## game behind the rec center ($500-1200) and Goodie's stash ($800-1500). The
## simulation harness had been setting `stick_tier = 3` by hand to measure them,
## which is the tell.
##
## The rungs mirror Boost's, because the two ladders are the same idea told
## twice: Boost counts clean technique, Stick counts jobs that came off. Tier 3
## additionally wants ORGANISED work — canon already tracks `stick_organized_hits`
## and already tells Curtis about the second one — for the same reason Boost's
## tier 3 wants field crew: the top of the ladder is where the work stops being
## something you do alone.
const STICK_TIER2_REP := 4
const STICK_TIER3_REP := 11
## Tier 3 also wants a crew that can stand somewhere while you work. Same gate
## Boost's tier 3 reads, and the same reason.
const STICK_TIER3_NEEDS_FIELD_CREW := true

var boost_tier: int = 1
var boost_technique: int = 0
var boost_merchandise: int = 0
var boost_fence_standing: int = 0
## target_id -> day it was last hit. One go per target per day.
var boost_daily_hits: Dictionary = {}

## The target ids the player has actually clocked (batch 14). A one-way
## discovery latch, the same shape as `districts_unlocked`.
##
## Boost had a TIER axis and nothing else: every target in the district at or
## below your tier was on the screen from the first minute of the run, so the
## surface opened at its widest and only ever got narrower — a permanent ban
## takes a shop off the list and nothing ever puts one back on. Twelve targets,
## bans permanent, and the list only shrinks.
##
## This is the second axis, and it runs the other way. A target arrives on the
## screen because you were out walking with your eyes open, which means the pool
## REFILLS with play rather than draining with it, and a run that gets three
## shops banned has somewhere to go that is not "stop boosting". Discovery is
## `WanderSystem`'s to grant; this array is only the record of what it granted.
##
## Empty is the honest start: a fresh run has never been out looking.
var boost_targets_discovered: Array = []

## Whether the player has found the street corner where product moves
## (v17). A one-way discovery latch, same shape as `boost_targets_discovered`
## and `districts_unlocked`: WanderSystem sets it true when the market
## discovery event fires (playtest finding — Market unlocked on the first
## walk of EVERY run, deterministically, which read as scripted rather than
## found); `surface_visibility.gd` reads it to gate the Hustle row.
var market_discovered: bool = false

func boost_target_by_id(id: String) -> Dictionary:
	for t in boost_targets:
		if t.get("id", "") == id:
			return t
	return {}

# --- Crew (canon: src/data/npcs.js CREW, src/data/crew.js) -----------------
# power feeds crew_power, which the HUD has shown as 0 since the first build.
# Every one of them canFieldAssign, which is what tier 3 Boost waits on.
var crew_roster: Array = [
	{"id": "eli", "name": "Eli 'Shortcut' Ward", "role": "RUNNER", "power": 3, "cost": 120, "wage": 45, "desc": "Moves small bundles and knows service-road exits."},
	{"id": "deshawn", "name": "Deshawn", "role": "FIXER / RECRUITER", "power": 1, "cost": 100, "wage": 50, "desc": "De-escalates conflicts, recruits through trust, keeps Spenard talking."},
	{"id": "pherris", "name": "Pherris Dickens", "role": "CONNECTOR", "power": 2, "cost": 180, "wage": 60, "desc": "Turns a Downtown contact list into buyers, rumors, and social control."},
	{"id": "tone", "name": "Anton 'Tone' Bell", "role": "ENFORCER / LOOKOUT", "power": 5, "cost": 250, "wage": 85, "desc": "Protects the garage and changes confrontation choices."},
]

## Canon TIER_WAGES. Eli has no curve and keeps his base wage at every tier.
const TIER_WAGES := {
	"deshawn": [50, 100, 200],
	"tone": [85, 150, 250],
	"pherris": [60, 120, 220],
}
## Canon TIER_REQUIREMENTS: loyalty AND days since recruited.
const CREW_TIER_REQUIREMENTS := {
	2: {"loyalty": 7, "days": 5},
	3: {"loyalty": 9, "days": 12},
}
const CREW_LOYALTY_MIN := 0
const CREW_LOYALTY_MAX := 10
const CREW_LOYALTY_START := 5
## Two unpaid nights before loyalty starts falling.
const CREW_WAGE_GRACE_DAYS := 2
## Canon capacity without base upgrades.
const CREW_CAPACITY := 2

## Canon effect tables, keyed by tier.
const TONE_DEFENSE_MULTIPLIER := {1: 1.15, 2: 1.30, 3: 1.50}
const DESHAWN_HEAT_REDUCTION := {1: 0.80, 2: 0.60, 3: 0.40}

# --- Crew progression (canon: src/data/crew-progression.js) ----------------
## FS-001.5. Structural only: ranks 4-6 have LABELS but no authored promotion
## requirements, so nothing can reach them yet. They exist so the curves below
## have somewhere to clamp to and so a later slice adds a rule rather than a
## concept.

## Canon CREW_RANKS. The player sees these; the number is internal.
const RANK_LABELS := {
	1: "RECRUIT", 2: "PROVEN", 3: "TRUSTED",
	4: "SPECIALIST LEAD", 5: "LIEUTENANT", 6: "INNER CIRCLE",
}
const MAX_CREW_RANK := 6

## Canon crewRankLabel. Anything outside 1..6 clamps rather than falling back to
## a sentinel — an out-of-range rank is a bug to fix, not a label to invent.
func rank_label(rank: int) -> String:
	return str(RANK_LABELS[clampi(rank, 1, MAX_CREW_RANK)])

## Canon curveValueForRank. **A rank above the highest authored entry keeps that
## entry** — it never drops back to the fallback.
##
## This is the whole point of the helper. `TIER_WAGES.deshawn` has three values;
## before this, a hypothetical rank 4 read `.get(4, 1.0)` on the effect tables
## and silently returned the neutral 1.0, which would have handed a Rank 4
## Deshawn NO heat reduction — a promotion that removes a benefit. Clamping up
## is the only safe direction for a curve the player has already earned.
##
## Handles both shapes canon uses: an Array indexed from rank 1, and a
## Dictionary with numeric rank keys (which may be sparse).
func curve_value_for_rank(curve: Variant, rank: int, fallback: Variant = 1.0) -> Variant:
	var requested: int = maxi(1, rank)
	if curve is Array:
		var arr: Array = curve
		if arr.is_empty():
			return fallback
		var value: Variant = arr[mini(arr.size(), requested) - 1]
		return fallback if value == null else value
	if curve is Dictionary:
		var dict: Dictionary = curve
		var keys: Array = []
		for key in dict.keys():
			if key is int or key is float:
				keys.append(int(key))
		if keys.is_empty():
			return fallback
		keys.sort()
		# The highest authored rank at or below the one asked for.
		var selected: int = keys[0]
		for key in keys:
			if key > requested:
				break
			selected = key
		var found: Variant = dict[selected]
		return fallback if found == null else found
	return fallback

## Canon CREW_CAPABILITIES — what a named crew member can eventually be ASKED to
## do. Inert data: nothing assigns, reserves a day, or executes anything off it.
## Named Crew Operations (FS-001.6) is the caller.
##
## **Only Pherris is authored, and that is canon, not an omission.** The build
## brief listed capabilities for Eli, Tone and Deshawn as well; the oracle has
## none for them, and inventing three would hand FS-001.6 data it then has to
## migrate away from. Their existing effects (Tone's defense multiplier,
## Deshawn's heat reduction) are presence effects, not delegable operations —
## a different mechanism, already shipped, and untouched here.
## GENERALISED in batch 6b. The note that stood here said only Pherris was
## authored and that this was canon rather than an omission — that the oracle
## has no capabilities for the other three and inventing some would hand FS-001.6
## data to migrate away from.
##
## That was the right call then and it is the wrong one now, for a reason that
## has nothing to do with the oracle: two of the three had a shipped effect that
## did nothing. Tone's defence multiplier was printed on the Crew screen and
## multiplied nothing until batch 6b; Eli had no effect of any kind. A crew
## member who costs a nightly wage and returns a number nobody reads is worse
## than one who is not implemented, because the player is paying for it.
##
## The two added here are DELEGABLE OPERATIONS — a day claimed, a wage owed, a
## result at settlement — which is the shape `907list_run_board` established.
## Tone stays a presence effect and is deliberately not here: what he does is
## stand near you, and standing near you is not something you assign.
##
## Capability ids are constrained. `tests/parity/fixtures/requirements/
## fs001_fixtures.json` asserts `eli/territory_operations` and
## `deshawn/network_operations` are `has: false` at rank 3, so those two names
## are burned and these are deliberately not them.
const CREW_CAPABILITIES := {
	"pherris": {
		"907list_run_board": {"min_rank": 1, "max_cycles_by_rank": [1, 2, 3]},
	},
	# "Moves small bundles and knows service-road exits." Batch 3 gave a trip
	# taken holding a real chance of being stopped; this is the answer to it.
	# The curve is the FRACTION of that chance he takes off.
	"eli": {
		"run_the_bag": {"min_rank": 1, "carry_relief_by_rank": [0.45, 0.60, 0.75]},
	},
	# "De-escalates conflicts, recruits through trust, keeps Spenard talking."
	# v0.1.0 made District Pressure recoverable on a clean outcome; this is the
	# other way down. The curve is points of Pressure taken off one district.
	"deshawn": {
		"smooth_it_over": {"min_rank": 1, "pressure_relief_by_rank": [1.0, 1.5, 2.0]},
	},
}

## The capability definition, or an empty dictionary when there is none.
func capability_definition(crew_id: String, capability_id: String) -> Dictionary:
	var owned: Dictionary = CREW_CAPABILITIES.get(crew_id, {})
	return owned.get(capability_id, {})

## Canon crewHasCapability. Rank matters: a capability is defined for a person
## AND gated on how far they have come.
func crew_has_capability(crew_id: String, capability_id: String, rank: int) -> bool:
	var definition: Dictionary = capability_definition(crew_id, capability_id)
	if definition.is_empty():
		return false
	return rank >= int(definition.get("min_rank", 1))

## Canon crewCapabilityValue: one field of a capability, read through the rank
## curve, or the fallback when the capability is not available at that rank.
func crew_capability_value(crew_id: String, capability_id: String, field: String,
		rank: int, fallback: Variant = null) -> Variant:
	var definition: Dictionary = capability_definition(crew_id, capability_id)
	if definition.is_empty() or not crew_has_capability(crew_id, capability_id, rank):
		return fallback
	return curve_value_for_rank(definition.get(field), rank, fallback)

## Canon crewCapabilitySummary — the shape a UI or an operation would read.
func crew_capability_summary(crew_id: String, capability_id: String, rank: int) -> Dictionary:
	var available: bool = crew_has_capability(crew_id, capability_id, rank)
	return {
		"crew_id": crew_id,
		"capability_id": capability_id,
		"available": available,
		"max_cycles": crew_capability_value(
			crew_id, capability_id, "max_cycles_by_rank", rank, 0) if available else 0,
	}

## Canon crewCapacity. A FUNCTION rather than a bare const read, because base
## upgrades extend it later and every caller should already be asking rather
## than reading. CREW_CAPACITY stays as the floor it returns.
func crew_capacity() -> int:
	return CREW_CAPACITY

## id -> {recruited, loyalty, tier, wage_due, wage_missed_since, recruited_day, status}
var crew_records: Dictionary = {}

# --- Named Crew Operations (FS-001.6) -------------------------------------
## Delegation state. Substrate only in this build: the lifecycle runs, discovery
## unlocks, assignments are taken and settled — but no operation has a domain
## adapter yet, so a settled assignment carries a null result. FS-001.7 plugs
## Pherris's "Run the Board" in without touching any of this.

## crew_id -> {day, operation_id, settled, result}.
##
## Keyed by CREW MEMBER, not by operation: the scarce thing is a person's day,
## and one person cannot be in two places. An entry whose `day` is not today is
## stale rather than deleted — a day-scoped read is cheaper than a nightly sweep
## and cannot leave a half-cleared record behind.
var crew_assignments: Dictionary = {}

## {discovered: Array[String], adapters: Dictionary}
##
## `discovered` is ONE-WAY. Once an operation is known it stays known, even if
## the state that revealed it goes away — learning that Pherris can work the
## board is something the player found out, not a buff they are holding.
## `adapters` is empty until FS-001.7 registers one.
var crew_operation_state: Dictionary = {"discovered": [], "adapters": {}}

func crew_member_by_id(id: String) -> Dictionary:
	for c in crew_roster:
		if c.get("id", "") == id:
			return c
	return {}

func crew_record(id: String) -> Dictionary:
	return crew_records.get(id, {})

func is_recruited(id: String) -> bool:
	var r: Dictionary = crew_record(id)
	return bool(r.get("recruited", false)) and str(r.get("status", "active")) == "active"

func recruited_crew() -> Array:
	var out: Array = []
	for c in crew_roster:
		if is_recruited(str(c["id"])):
			out.append(c)
	return out

## Canon wageFor: the tier curve where one exists, otherwise the base wage.
func crew_wage_for(id: String, tier: int) -> int:
	if TIER_WAGES.has(id):
		var curve: Array = TIER_WAGES[id]
		return int(curve[clampi(tier - 1, 0, curve.size() - 1)])
	return int(crew_member_by_id(id).get("wage", 0))

# --- Territory (FS-002.3, canon: src/data/locations.js SPENARD_BLOCKS) -----
# earning_potential is per staffed soldier, with diminishing returns.
# heat_exposure is charged nightly for OWNING the block, staffed or not:
# an empty corner you hold is still a corner people know is yours.
#
# The board itself lives in data/territory_definitions.gd as of FS-002.3.
# `spenard_blocks` is deleted whole, not deprecated alongside it — see that
# file's header for why a retired truth cannot survive next to its
# replacement.
const TERRITORY_DEFS := preload("res://data/territory_definitions.gd")

const SOLDIER_RECRUIT_COST := 140
const SOLDIER_BASE_CAPACITY := 2
const SOLDIER_CAPACITY_PER_BLOCK := 2
## D-1 (`86bbjxtfa`, Batch 18 PR 4): the missing rule, not a balance tweak.
## Territory shipped with a one-time recruit cost and no recurring one — every
## other earner in the build spends a slot or draws a wage; a soldier drew
## neither. $20/soldier/night, charged on the full roster
## (`soldiers_total()` — idle AND posted), the same way a crew wage is charged
## whether or not that member did anything today. See `territory.gd:settle_night`.
const SOLDIER_UPKEEP_PER_NIGHT := 20
## Canon SOLDIER_INCOME_BASE_DIMINISH — the second soldier on a corner earns
## 85% of the first, the third 85% of that.
const SOLDIER_INCOME_DIMINISH := 0.85

## Ownership + staffing truth (FS-002.3, save v16). node_id -> {soldiers: int}.
## Successor to `held_blocks`, sparse the same way: a key's PRESENCE is what
## "held" means, same as it always has. `claimed_day` and `income_collected`
## are not carried — both are dead (see the v16 migration arm in
## `save_system.gd` for why), and this is the one place either could have been
## reintroduced by habit.
var territory_nodes: Dictionary = {}
## Curtis-relationship bookkeeping for the four Curtis-secure nodes (FS-002.3,
## save v16). node_id -> {capture_reward_consumed: bool, conflict_active: bool}.
##
## Populated ONLY by the v16 migration, for a save that already held a
## Curtis-secure node before this file existed — the capture already
## happened, off camera, and a migrated holding is never confiscated. A fresh
## run starts with this empty and nothing in the current build writes to it
## during play: contested takeovers are FS-002.4/.5 (Build 18b), and this
## field exists now so that slice does not need a second Territory migration
## to add it.
var territory_fronts: Dictionary = {}
## Soldiers hired but not posted to a block.
var soldiers_idle: int = 0

## The authored row for an id, or `{}` for one the table does not carry — see
## `TERRITORY_DEFS.by_id()` for why that is a real, expected case rather than
## only a corrupted-save concern.
func block_by_id(id: String) -> Dictionary:
	return TERRITORY_DEFS.by_id(id)

func holds_block(id: String) -> bool:
	return territory_nodes.has(id)

func soldiers_total() -> int:
	var n: int = soldiers_idle
	for rec in territory_nodes.values():
		n += int(rec.get("soldiers", 0))
	return n

## Canon: 2, plus 2 for every block held. Counts PLAYER-HELD nodes
## (`territory_nodes.size()`), never the six authored nodes — the highest-risk
## line in this migration, because getting it backwards silently jumps
## capacity 2 -> 14 the moment a save carries the four Curtis-secure nodes as
## definitions without them being held.
func soldier_capacity() -> int:
	return SOLDIER_BASE_CAPACITY + territory_nodes.size() * SOLDIER_CAPACITY_PER_BLOCK

# --- Exposure ledgers (canon: src/exposure/engine.js) ----------------------
## npc_id -> Array of observation rows. The Exposure autoload owns the shape;
## GameState only holds it so a run resets and (later) saves with everything else.
var npc_ledgers: Dictionary = {}
## Observations in transit. Channels that take days to carry news queue here and
## are delivered on day-cross.
var observation_queue: Array = []

# --- Consequence-Encounter Engine (TI-003 §5) ------------------------------
## Everything below is state the ConsequenceEngine owns. It lands here rather
## than in the engine because GameState owns persisted run facts (TI-003 §26)
## and because a save must round-trip it without an engine instance existing.
##
## **Stable IDs and state facts only, never Object references.** TI-003 §1 makes
## this the standing rule and FS-001.7's runtime adapter registry is the
## precedent: `consequence_engine` re-registers its source adapters on every
## boot, and nothing here can name one.
##
## FS-003.4 adds and persists these. Nothing writes them yet — the engine that
## does is FS-003.5, and the behaviour that fills them is .7 onward. Empty IS
## the honest history of a save that predates the system, which is the same
## argument the v3 → v4 attributes arm makes.

## Cause allocation. TI-003 §4: `cause_id = "cause:%08d" % next_cause_sequence`,
## allocated with zero randomness so a reload cannot renumber a live chain.
var next_cause_sequence: int = 0
var next_consequence_sequence: int = 0

## The one active blocking chain, or empty when nothing is blocking. TI-003 §10
## is explicit that there is exactly one — the queue is how a second waits.
var active_consequence: Dictionary = {}

## cause_id -> {effect_receipts, resolved_consequence_ids, scheduled_actor_ids}.
## The exactly-once ledger: an effect and its receipt land in the same dispatch,
## so a reload mid-chain cannot apply either of them twice.
var consequence_history: Dictionary = {}

## Delayed consequences waiting for their day and their district. An Array, not
## a Dictionary, because TI-003 regression #32 is "queue order depends on
## Dictionary iteration order" — order has to be a property of the storage.
var consequence_queue: Array = []

## The day a delayed blocking consequence last surfaced. TI-003 §15 allows one
## per day; this is what enforces it across a reload.
var last_blocking_delayed_day: int = -1

## TI-003 §5. Priors drive bail multipliers and processing time, so this is the
## record that makes a second arrest cost more than the first.
##
## `cooldown_until_day` is FS-003.13's post-arrest gate suppression deadline:
## the last day an arrest gate stays shut after a booking committed, or -1 for a
## run that has never been booked. It lives inside this Dictionary rather than as
## a field of its own so it persists under the existing manifest entry — see
## `ArrestSystem.cooldown_until_day()`.
var arrest_record: Dictionary = {
	"priors": 0, "last_arrest_day": -1, "charges": [], "cooldown_until_day": -1,
}

## Boost-owned and persistent by target id (TI-003 §5). Kept here for the same
## reason as everything else in this block: it has to survive a reload, and
## TI-003 regression #11 is "Boost bans disappear on day-cross or reload".
var boost_store_bans: Array = []

## district_id -> family -> {score, last_gain_day, quiet_days, market_gain_day,
## market_gain_today}. TI-003 §8. Separate storage from global `heat` on
## purpose — regression #16 is the two sharing it.
var district_pressure: Dictionary = {}

## Pressure scheduled to bleed into adjacent districts tomorrow (TI-003 §8).
## Rows carry Cause + destination identity so a reload cannot double-apply.
var pressure_bleed_pending: Array = []

# --- Progression facts (v0.1.0, surface visibility) ------------------------
#
# Two durable facts the access layer reads. Both are DISCOVERY LATCHES: they
# only ever move forwards, because what they record is knowledge, and a player
# does not un-learn that Downtown exists by abandoning a corner. Derived
# eligibility is never stored beside them — a gate reads these facts live, so
# there is no second copy to contradict them.
#
# Reconciled in `reconcile_persistent_invariants()`, which runs inside every
# successful dispatch before `state_changed`, so an unlock reaches the screen on
# the same refresh as the action that earned it.

## District ids the player has learned they can travel to.
##
## Ids, not display names: `north_star_lot` / `downtown` / `airport_industrial`
## are what `districts`, the market keys, `district_pressure` and the save all
## already use, and a second vocabulary of pretty names would be one rename away
## from silently gating nothing.
##
## Plain `Array` rather than `Array[String]` for the reason every other
## persisted array here is: `SaveSystem._apply` overlays a decoded Variant onto
## the field, and a typed array rejects the untyped one it gets back.
var districts_unlocked: Array = ["north_star_lot"]

## How many named contacts capable of putting WORK in front of the player have
## been met. Gates the Jobs surface.
##
## Yalonda deliberately does not count. The player starts knowing her and she is
## housing, not a referral — a job gate she satisfies is a gate that is open on
## day one, which is the thing this build exists to stop.
var job_contacts: int = 0

## district_id -> family -> float. Pressure a CLEAN outcome has earned back
## today and not yet been paid (v0.1.0, the HOT escape lever).
##
## Credits accrue as actions resolve during the day and are drained at
## POST_SETTLE, which is why they are state rather than a local: the autosave
## fires once per dispatch, so a player who lifts cleanly at noon and closes the
## tab must still be holding that credit when the run reopens. A counter that
## reset on load would silently withhold the recovery the outcome earned — the
## same failure `market_gain_today` is stored on the Pressure row to avoid.
##
## Always empty between days. `apply_clean_recovery` clears it as it pays.
var pressure_clean_credits: Dictionary = {}

# --- Venues (batch 7) --------------------------------------------------------

## activity id -> how many sessions of it have happened. Read by
## `AttributesSystem.train`, whose whole diminishing-returns curve is a function
## of "how many came before this one".
##
## A Dictionary rather than a field per activity, because `GROWTH_RATES` is a
## table and canon's design is that a new growth source is a row rather than a
## code path — a counter per row would undo that.
var attribute_sessions: Dictionary = {}

## Canon `gymStreakBonus`: three consecutive days at the Spenard Gym are worth
## +1 effective Combat on the next check.
##
## Two fields rather than a list of days: the streak only ever needs to answer
## "how many in a row" and "was the last one recent enough to still count", and
## a list would grow without bound for a question with two integers in it.
## `gym_last_day` is -1 for a run that has never trained.
var gym_streak: int = 0
var gym_last_day: int = -1

## Which venue interiors the player has walked into. Ordering is arrival order.
##
## Its one job today is first-visit copy and the Night Owl's shift offer — the
## `night_owl` job has been in `jobs` since the port began with nothing in the
## codebase ever adding it to `jobs_discovered`, which made it dead data. Now
## the counter is where you find out about the counter.
var venues_entered: Array = []

# --- Heat's teeth (batch 8) ---------------------------------------------------

## How much Heat this day has GENERATED, for the quiet-day decay rule.
##
## Gains only. Relief does not reduce it, because the question it answers is
## "did you do anything today", not "where did you end up" — a player who robs
## someone at noon and lays low twice has still had a loud day.
##
## Persisted for the reason `pressure_clean_credits` is: the autosave fires once
## per dispatch, so a run closed after the robbery and reopened before the night
## must still be having the day it was having. A counter that reset on load
## would hand back a decay the day had not earned.
var heat_gain_today: float = 0.0

## The day Lay Low was last used. Once a day.
##
## It had no blocker of any kind — no cost, no cap, no gate — which made four
## slots a day worth 8.0 of shedding for free, against a street stop that can
## only take 2.0 back. A cap is what makes Heat something to carry rather than
## something to grind off.
var lay_low_day: int = -1

# --- Wander (batch 10) --------------------------------------------------------

## How many wanders in a row have found nothing. The oracle's ramp reads this:
## 30% base, +10% per miss, capped at 70%, reset by a find.
##
## Persisted for the reason every other within-run counter is: the autosave
## fires once per dispatch, and a player four misses deep who closes the tab is
## still four misses deep when they come back. Losing it would silently hand
## them the drought again.
var wander_misses: int = 0

## Total wanders this run. Part of the draw key, so two walks taken in the SAME
## slot are two different walks rather than the same one twice.
var wander_count: int = 0

## card id -> how many times it has come up. What makes a `once` card once.
var wander_seen: Dictionary = {}

## The last few card ids, so the same beat does not land twice running. Same
## idea as `curtis_recent_watcher_lines`, and capped the same way.
var wander_recent: Array = []

## Walks taken TODAY, for the effort falloff (batch 13). An hour on the block is
## worth something; the third hour on the same block on the same day is not
## worth as much, and the arithmetic should say so rather than paying three
## identical times and calling it a choice.
##
## Persisted for the same reason `heat_gain_today` is — the autosave fires once
## per dispatch, and a player two walks deep who closes the tab is still two
## walks deep. Cleared at DAY_START.
var wanders_today: int = 0

## Run-level one-shot flags owned by the consequence layer (FS-003.13 Task 5).
##
## A Dictionary rather than a field per flag, for the reason PERSIST_FIELDS is a
## list of names: a flag that lives in here costs no manifest entry and no
## migration arm, so the next one-shot callback is a key rather than a schema
## decision. Everything in it is a fact about THIS RUN that must not repeat after
## a reload — currently only `retaliation_first_expiry_seen`, the flag that keeps
## PX-003 §8's avoidance callback to once per run.
##
## Read with `.get(key, default)` everywhere, never indexed: an old save comes
## back with the Dictionary empty and every flag must default to "has not
## happened yet".
var consequence_flags: Dictionary = {}

extends Node
## GameState — the single source of truth for the run.
##
## For now this is a static mid-game snapshot (DAY 14, EVENING) sourced from the
## web build v1.35 (src/data/*). It is deliberately plain data + a couple of
## helpers: the reducer port (Phase 3) will make these fields mutate via a
## dispatch, and screens that read them today will update for free.
##
## Screens read from here in _ready() instead of hardcoding values — Street is
## the first consumer. Retrofitting Home/Market/Hustle onto GameState is a
## follow-up pass.

## Emitted after any batch of state changes. Screens connect to this and re-render
## everything in one pass (the web-reducer pattern). Call notify_changed() after
## mutating fields to trigger a refresh.
signal state_changed
## Emitted when the run rolls past NIGHT into a new day.
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
	{"id": "airport_industrial", "name": "INDUSTRIAL", "role": "SERVICE ROADS", "risk": 4, "police": 2, "rival": 3, "accent": Color(0.604, 0.114, 0.094), "blurb": "Loading yards, rare supply, and expensive mistakes.",
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
	{"name": "North Star Garage", "tag": "BASE", "desc": "Your operation. Recruit crew, stash product."},
	{"name": "Night Owl Mini-Mart", "tag": "SHOP", "desc": "Mina's counter. Tools, a shift, word around town."},
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
	{"id": "weed", "name": "WEED", "role": "DEPENDABLE · OWN 4oz", "owned": "4oz", "route": "+$11 Industrial", "color": Color(0.451, 0.722, 0.404), "price": 27, "base": 34, "volatility": 0.12, "min": 18, "max": 68, "hint": "SELL INDUSTRIAL  +$11", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "shrooms", "name": "SHROOMS", "role": "VOLATILE · OWN 2", "owned": "2", "route": "+$36 Downtown", "color": Color(0.373, 0.663, 0.847), "price": 72, "base": 82, "volatility": 0.25, "min": 35, "max": 180, "hint": "SELL DOWNTOWN  +$36", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "pills", "name": "PILLS", "role": "STEADY MARGIN · OWN 3", "owned": "3", "route": "Stable citywide", "color": Color(0.882, 0.651, 0.227), "price": 105, "base": 105, "volatility": 0.18, "min": 55, "max": 220, "hint": "— STABLE CITYWIDE", "trend": "flat", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "lean", "name": "LEAN", "role": "PREMIUM", "owned": "0", "route": "Downtown margin", "color": Color(0.62, 0.5, 0.85), "price": 155, "base": 155, "volatility": 0.22, "min": 80, "max": 330, "hint": "+30% MARGIN DOWNTOWN", "trend": "up", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "coke", "name": "COKE", "role": "HIGH MARGIN", "owned": "0", "route": "Stable citywide", "color": Color(0.9, 0.89, 0.86), "price": 290, "base": 290, "volatility": 0.3, "min": 145, "max": 690, "hint": "— STABLE CITYWIDE", "trend": "flat", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "molly", "name": "MOLLY", "role": "CLUB DEMAND", "owned": "0", "route": "Downtown margin", "color": Color(1, 0.29, 0.239), "price": 215, "base": 215, "volatility": 0.28, "min": 105, "max": 480, "hint": "+30% MARGIN DOWNTOWN", "trend": "up", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "cocaine", "name": "COCAINE", "role": "PREMIUM", "owned": "0", "route": "+$127 Downtown", "color": Color(0.85, 0.72, 0.42), "price": 296, "base": 290, "volatility": 0.3, "min": 145, "max": 690, "hint": "SELL DOWNTOWN  +$127", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "meth", "name": "METH", "role": "EXTREME RISK", "owned": "0", "route": "Locked", "color": Color(0.6, 0.6, 0.6), "price": 176, "base": 185, "volatility": 0.38, "min": 70, "max": 560, "hint": "NEEDS INDUSTRIAL TURF", "trend": "flat", "hint_color": Color(0.827, 0.161, 0.125), "locked": true},
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
var activity_log: Array = [
	{"text": "Afternoon: Sold 3 pills in Midtown.", "time": "3:46 PM", "color": Color(0.451, 0.722, 0.404)},
	{"text": "Morning: Paid bus pass.", "time": "8:12 AM", "color": Color(0.373, 0.663, 0.847)},
	{"text": "Night watch: No arrests yet.", "time": "9:31 PM", "color": Color(0.62, 0.5, 0.85)},
]

# --- People & events -------------------------------------------------------------
var pending_messages: Array = [
	{"npc_id": "yalonda", "name": "YALONDA", "preview": "\"You owe me a favor. Slide through when you're ready.\"", "timestamp": "12m ago"},
]

# --- Hustle hub (canon: web HustleScreen income surfaces + Curtis) --------------
var todays_take: int = 312
# Source split shown as chips under Today's Take (sums to todays_take).
var income_sources: Dictionary = {"jobs": 180, "market": 87, "stick": 45}
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
func reset_to_new_game() -> void:
	day = 1
	time_slot = "MORNING"
	time_slots_today = 0
	current_district_id = "north_star_lot"
	cash = 100
	heat = 0.0
	health = 100
	debt = 0
	debt_due_days = 0
	respect = 0
	crew_power = 0
	inventory = {}
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
	boost_tier = 1
	boost_technique = 0
	boost_merchandise = 0
	boost_fence_standing = 0
	boost_daily_hits = {}
	crew_records = {}
	held_blocks = {}
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

var game_over: bool = false
var game_over_reason: String = ""

## Prepend a feed entry. Home shows the newest three, so new events go on top.
## `time` is the slot rather than a clock reading — the run has no wall clock.
func log_activity(text: String, color: Color = Color(0.608, 0.608, 0.608)) -> void:
	activity_log.push_front({"text": text, "time": time_slot, "color": color})
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

func listing_item_by_id(id: String) -> Dictionary:
	for i in listing_items:
		if i.get("id", "") == id:
			return i
	return {}

func market_tier() -> Dictionary:
	return market_tiers.get(list_tier, market_tiers[1])

# --- Boost (canon: game-core.js BOOST_TARGETS) -----------------------------
var boost_targets: Array = [
	{"id": "night_owl", "name": "Night Owl Mini-Mart", "area": "north_star_lot", "tier": 1, "take": [15, 40], "window": -1, "desc": "The counter you already know. The camera by the back aisle has a blind spot everyone in Spenard learned first."},
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

var boost_tier: int = 1
var boost_technique: int = 0
var boost_merchandise: int = 0
var boost_fence_standing: int = 0
## target_id -> day it was last hit. One go per target per day.
var boost_daily_hits: Dictionary = {}

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

## id -> {recruited, loyalty, tier, wage_due, wage_missed_since, recruited_day, status}
var crew_records: Dictionary = {}

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

# --- Territory (canon: src/data/locations.js SPENARD_BLOCKS) ---------------
# earning_potential is per staffed soldier, with diminishing returns.
# heat_exposure is charged nightly for OWNING the block, staffed or not:
# an empty corner you hold is still a corner people know is yours.
var spenard_blocks: Array = [
	{"id": "spenard_rec_lot", "cell": 1, "name": "Spenard Rec Center Lot", "earning": 45, "heat_exposure": 1, "patrol": 1, "claim_cost": 180},
	{"id": "wash_and_go_lot", "cell": 2, "name": "Wash & Go Lot", "earning": 55, "heat_exposure": 1, "patrol": 1, "claim_cost": 220},
	{"id": "minnesota_offramp", "cell": 5, "name": "Minnesota Off-Ramp", "earning": 65, "heat_exposure": 2, "patrol": 1, "claim_cost": 260},
	{"id": "service_road_chokepoint", "cell": 6, "name": "Service Road Chokepoint", "earning": 70, "heat_exposure": 2, "patrol": 3, "claim_cost": 300},
	{"id": "fourth_ave_strip", "cell": 9, "name": "Fourth Avenue Strip", "earning": 80, "heat_exposure": 2, "patrol": 2, "claim_cost": 320},
	{"id": "northern_lights_motels", "cell": 10, "name": "Northern Lights Motel Row", "earning": 100, "heat_exposure": 3, "patrol": 2, "claim_cost": 400},
]

const SOLDIER_RECRUIT_COST := 140
const SOLDIER_BASE_CAPACITY := 2
const SOLDIER_CAPACITY_PER_BLOCK := 2
## Canon SOLDIER_INCOME_BASE_DIMINISH — the second soldier on a corner earns
## 85% of the first, the third 85% of that.
const SOLDIER_INCOME_DIMINISH := 0.85

## block_id -> {soldiers: int, claimed_day: int, income_collected: int}
var held_blocks: Dictionary = {}
## Soldiers hired but not posted to a block.
var soldiers_idle: int = 0

func block_by_id(id: String) -> Dictionary:
	for b in spenard_blocks:
		if b.get("id", "") == id:
			return b
	return {}

func holds_block(id: String) -> bool:
	return held_blocks.has(id)

func soldiers_total() -> int:
	var n: int = soldiers_idle
	for rec in held_blocks.values():
		n += int(rec.get("soldiers", 0))
	return n

## Canon: 2, plus 2 for every block held.
func soldier_capacity() -> int:
	return SOLDIER_BASE_CAPACITY + held_blocks.size() * SOLDIER_CAPACITY_PER_BLOCK

# --- Exposure ledgers (canon: src/exposure/engine.js) ----------------------
## npc_id -> Array of observation rows. The Exposure autoload owns the shape;
## GameState only holds it so a run resets and (later) saves with everything else.
var npc_ledgers: Dictionary = {}
## Observations in transit. Channels that take days to carry news queue here and
## are delivered on day-cross.
var observation_queue: Array = []

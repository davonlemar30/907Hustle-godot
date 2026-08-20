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
var heat: int = 6
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
var districts: Array = [
	{"id": "north_star_lot", "name": "SPENARD", "role": "HOME TURF", "risk": 1, "police": 1, "rival": 0, "accent": Color(0.842, 0.842, 0.842), "blurb": "Safest footing in the city. Thin margins, low patrol."},
	{"id": "downtown", "name": "DOWNTOWN", "role": "COMMERCIAL", "risk": 2, "police": 3, "rival": 1, "accent": Color(0.882, 0.263, 0.196), "blurb": "Nightlife money moves fast under cameras and Curtis's buyers."},
	{"id": "airport_industrial", "name": "INDUSTRIAL", "role": "SERVICE ROADS", "risk": 4, "police": 2, "rival": 3, "accent": Color(0.604, 0.114, 0.094), "blurb": "Loading yards, rare supply, and expensive mistakes."},
]

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
	{"id": "weed", "name": "WEED", "role": "DEPENDABLE · OWN 4oz", "owned": "4oz", "route": "+$11 Industrial", "color": Color(0.451, 0.722, 0.404), "price": 27, "base": 34, "min": 18, "max": 68, "hint": "SELL INDUSTRIAL  +$11", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "shrooms", "name": "SHROOMS", "role": "VOLATILE · OWN 2", "owned": "2", "route": "+$36 Downtown", "color": Color(0.373, 0.663, 0.847), "price": 72, "base": 82, "min": 35, "max": 180, "hint": "SELL DOWNTOWN  +$36", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "pills", "name": "PILLS", "role": "STEADY MARGIN · OWN 3", "owned": "3", "route": "Stable citywide", "color": Color(0.882, 0.651, 0.227), "price": 105, "base": 105, "min": 55, "max": 220, "hint": "— STABLE CITYWIDE", "trend": "flat", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "lean", "name": "LEAN", "role": "PREMIUM", "owned": "0", "route": "Downtown margin", "color": Color(0.62, 0.5, 0.85), "price": 155, "base": 155, "min": 80, "max": 330, "hint": "+30% MARGIN DOWNTOWN", "trend": "up", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "molly", "name": "MOLLY", "role": "CLUB DEMAND", "owned": "0", "route": "Downtown margin", "color": Color(1, 0.29, 0.239), "price": 215, "base": 215, "min": 105, "max": 480, "hint": "+30% MARGIN DOWNTOWN", "trend": "up", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "coke", "name": "COKE", "role": "HIGH MARGIN", "owned": "0", "route": "Stable citywide", "color": Color(0.9, 0.89, 0.86), "price": 290, "base": 290, "min": 145, "max": 690, "hint": "— STABLE CITYWIDE", "trend": "flat", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "cocaine", "name": "COCAINE", "role": "PREMIUM", "owned": "0", "route": "+$127 Downtown", "color": Color(0.85, 0.72, 0.42), "price": 296, "base": 290, "min": 145, "max": 690, "hint": "SELL DOWNTOWN  +$127", "trend": "up", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "meth", "name": "METH", "role": "EXTREME RISK", "owned": "0", "route": "Locked", "color": Color(0.6, 0.6, 0.6), "price": 176, "base": 185, "min": 70, "max": 560, "hint": "NEEDS INDUSTRIAL TURF", "trend": "flat", "hint_color": Color(0.827, 0.161, 0.125), "locked": true},
]

# Which products the Home "Market Snapshot" summarizes (by id), in display order.
var home_snapshot: Array = ["weed", "meth", "pills"]

# --- Turf & crew (canon: locations.js TERRITORIES / SPENARD_BLOCKS) --------------
# held_blocks: each held block + which mini-map grid cell (0-11) it lights.
var map_cells: int = 12
var held_blocks: Array = [
	{"name": "Minnesota Dr.", "cell": 2},
	{"name": "Burlwood", "cell": 9},
	{"name": "W. 36th Ave.", "cell": 10},
]
var soldiers: int = 6
var soldiers_shown: int = 6
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
var curtis_attention: int = 4
var curtis_attention_max: int = 8

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
	heat = 0
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
	activity_log = []
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

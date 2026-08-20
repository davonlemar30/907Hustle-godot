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

# --- Run clock -------------------------------------------------------------
var day: int = 14
var part: String = "EVENING"
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
var cargo: int = 9
var cargo_max: int = 18
var respect: int = 4
var crew_power: int = 11

# --- Districts (canon: src/data/locations.js NEIGHBORHOODS) ----------------
# risk/police/rival are the raw 0-4 scores; travel is the how-you-get-there.
var districts: Array = [
	{"id": "north_star_lot", "name": "SPENARD", "role": "HOME TURF", "risk": 1, "police": 1, "rival": 0, "travel": "YOU ARE HERE", "here": true, "accent": Color(0.842, 0.842, 0.842), "blurb": "Safest footing in the city. Thin margins, low patrol."},
	{"id": "downtown", "name": "DOWNTOWN", "role": "COMMERCIAL", "risk": 2, "police": 3, "rival": 1, "travel": "BUS · $5", "here": false, "accent": Color(0.882, 0.263, 0.196), "blurb": "Nightlife money moves fast under cameras and Curtis's buyers."},
	{"id": "airport_industrial", "name": "INDUSTRIAL", "role": "SERVICE ROADS", "risk": 4, "police": 2, "rival": 3, "travel": "TRAVEL", "here": false, "accent": Color(0.604, 0.114, 0.094), "blurb": "Loading yards, rare supply, and expensive mistakes."},
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
var products: Array = [
	{"id": "weed", "name": "WEED", "role": "DEPENDABLE · OWN 4oz", "owned": "4oz", "route": "+$11 Industrial", "color": Color(0.451, 0.722, 0.404), "price": 27, "hint": "▲ SELL INDUSTRIAL  +$11", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "shrooms", "name": "SHROOMS", "role": "VOLATILE · OWN 2", "owned": "2", "route": "+$36 Downtown", "color": Color(0.373, 0.663, 0.847), "price": 72, "hint": "▲ SELL DOWNTOWN  +$36", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "pills", "name": "PILLS", "role": "STEADY MARGIN · OWN 12", "owned": "12", "route": "Stable citywide", "color": Color(0.882, 0.651, 0.227), "price": 105, "hint": "— STABLE CITYWIDE", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "lean", "name": "LEAN", "role": "PREMIUM", "owned": "0", "route": "Downtown margin", "color": Color(0.62, 0.5, 0.85), "price": 155, "hint": "↗ +30% MARGIN DOWNTOWN", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "molly", "name": "MOLLY", "role": "CLUB DEMAND", "owned": "0", "route": "Downtown margin", "color": Color(1, 0.29, 0.239), "price": 215, "hint": "↗ +30% MARGIN DOWNTOWN", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "coke", "name": "COKE", "role": "HIGH MARGIN", "owned": "0", "route": "Stable citywide", "color": Color(0.9, 0.89, 0.86), "price": 290, "hint": "— STABLE CITYWIDE", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "cocaine", "name": "COCAINE", "role": "PREMIUM", "owned": "0", "route": "+$127 Downtown", "color": Color(0.85, 0.72, 0.42), "price": 296, "hint": "▲ SELL DOWNTOWN  +$127", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "meth", "name": "METH", "role": "EXTREME RISK", "owned": "0", "route": "Locked", "color": Color(0.6, 0.6, 0.6), "price": 176, "hint": "NEEDS INDUSTRIAL TURF", "hint_color": Color(0.827, 0.161, 0.125), "locked": true},
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

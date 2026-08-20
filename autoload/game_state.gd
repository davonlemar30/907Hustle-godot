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
	{"id": "weed", "name": "WEED", "role": "DEPENDABLE · OWN 4oz", "color": Color(0.451, 0.722, 0.404), "price": 27, "hint": "▲ SELL INDUSTRIAL  +$11", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "shrooms", "name": "SHROOMS", "role": "VOLATILE · OWN 2", "color": Color(0.373, 0.663, 0.847), "price": 72, "hint": "▲ SELL DOWNTOWN  +$36", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "pills", "name": "PILLS", "role": "STEADY MARGIN · OWN 12", "color": Color(0.882, 0.651, 0.227), "price": 105, "hint": "— STABLE CITYWIDE", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "lean", "name": "LEAN", "role": "PREMIUM", "color": Color(0.62, 0.5, 0.85), "price": 155, "hint": "↗ +30% MARGIN DOWNTOWN", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "molly", "name": "MOLLY", "role": "CLUB DEMAND", "color": Color(1, 0.29, 0.239), "price": 215, "hint": "↗ +30% MARGIN DOWNTOWN", "hint_color": Color(0.373, 0.663, 0.847), "locked": false},
	{"id": "coke", "name": "COKE", "role": "HIGH MARGIN", "color": Color(0.9, 0.89, 0.86), "price": 290, "hint": "— STABLE CITYWIDE", "hint_color": Color(0.608, 0.608, 0.608), "locked": false},
	{"id": "cocaine", "name": "COCAINE", "role": "PREMIUM", "color": Color(0.85, 0.72, 0.42), "price": 296, "hint": "▲ SELL DOWNTOWN  +$127", "hint_color": Color(0.451, 0.722, 0.404), "locked": false},
	{"id": "meth", "name": "METH", "role": "EXTREME RISK", "color": Color(0.6, 0.6, 0.6), "price": 176, "hint": "NEEDS INDUSTRIAL TURF", "hint_color": Color(0.827, 0.161, 0.125), "locked": true},
]

func district_by_id(id: String) -> Dictionary:
	for d in districts:
		if d.get("id", "") == id:
			return d
	return {}

func current_district() -> Dictionary:
	return district_by_id(current_district_id)

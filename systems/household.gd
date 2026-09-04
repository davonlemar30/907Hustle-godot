extends RefCounted
## Household -- Yalonda and Juan, talking back (SA-D4, 1.1.0).
##
## The two people who see you every day have opinions, and every third
## morning one of them says one out loud: a line in the feed, chosen from
## what is true right now -- the rent, the police, the car, the crew, the
## name you have earned, and what their own ledger says about you. Yalonda
## on one morning, Juan on the next. When it is the police, Yalonda also
## texts it, because that one she wants in writing.
##
## Pure flavour: nothing here writes a ledger, moves money, or gates a
## surface. It is the house noticing, which the ticket asked for and the
## review named as the thing the apartment was missing.

const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)
const BLUE := Color(0.373, 0.663, 0.847)
const MUTED := Color(0.608, 0.608, 0.608)

## One morning in three. Day 3 is Yalonda's, day 6 Juan's, and so on.
const EVERY := 3

## Ordered: the first true condition speaks. `text` is the line's phone
## version, sent alongside the feed line when present.
const YALONDA := [
	{"id": "rent_late", "line": "You know what day it is. So do I."},
	{"id": "heat_watched", "line": "There was a car outside last night that wasn't anybody's. Keep that away from my door.",
		"text": "There was a car outside last night. Not one of ours. Keep that away from my door.", "context": "yalonda_house"},
	{"id": "heat_noticed", "line": "Sirens on the Drive last night. I sleep light."},
	{"id": "cold", "line": "Juan vouched for you. I'm still deciding if he was right."},
	{"id": "car", "line": "That car of yours is on the street side. Plow comes Tuesday."},
	{"id": "connected", "line": "People say your name at the store now. Say it quietly."},
	{"id": "known", "line": "Lani says you're doing all right. Lani doesn't say that."},
	{"id": "trusted", "line": "There's a plate in the oven. Don't tell Juan it was for you."},
	{"id": "default", "line": "Eat something. Lock up when you come in."},
]

const JUAN := [
	{"id": "crew", "line": "Tone was outside asking for you. Man doesn't blink. You good with that?"},
	{"id": "heat_watched", "line": "Two cops at the Chevron asked about the building. I said I just live here. I do."},
	{"id": "car", "line": "Your Corolla's got a lean to it. Tire, probably. I got a jack."},
	{"id": "player", "line": "Guys at the shop know who you are now. That's a thing, bro. Not sure which thing."},
	{"id": "warm", "line": "Ma made too much. She says it's not for you. It's for you."},
	{"id": "broke", "line": "You need forty until Friday? Don't make it a thing."},
	{"id": "default", "line": "Cold one today. Plug the block heater in if you got one, and you don't."},
]

const BROKE_LINE := 40

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The house takes no actions."}

## DAY_START. Whose morning it is, and what they say.
func day_start(today: int) -> void:
	if gs.game_over or today < EVERY or today % EVERY != 0:
		return
	var speaker := speaker_for(today)
	var pick: Dictionary = line_for(speaker)
	if pick.is_empty():
		return
	var name := "Yalonda" if speaker == "yalonda" else "Juan"
	gs.log_activity("%s: \"%s\"" % [name, str(pick["line"])], AMBER if speaker == "yalonda" else BLUE)
	if pick.has("text"):
		var phone: Object = gm.system("phone") if gm != null else null
		if phone != null:
			phone.push_text(name, str(pick["text"]), str(pick.get("context", "")))

func speaker_for(today: int) -> String:
	return "yalonda" if (today / EVERY) % 2 == 1 else "juan"

## The first true condition, in the table's order. Pure.
func line_for(speaker: String) -> Dictionary:
	var table: Array = YALONDA if speaker == "yalonda" else JUAN
	for entry in table:
		if _holds(str((entry as Dictionary)["id"]), speaker):
			return entry
	return {}

func _holds(condition: String, speaker: String) -> bool:
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	var heat_sys: Object = gm.system("heat") if gm != null else null
	var band: String = str(heat_sys.band()) if heat_sys != null else "COOL"
	var own_band: String = str(exposure.band_of(speaker)) if exposure != null else "neutral"
	match condition:
		"rent_late":
			return int(gs.rent_arrears_day) >= 0
		"heat_watched":
			return band in ["WATCHED", "BURNING"]
		"heat_noticed":
			return band != "" and band != "COOL"
		"cold":
			return own_band in ["cold", "hostile"]
		"car":
			return bool(gs.has_vehicle())
		"connected":
			return exposure != null and bool(exposure.has_rank("connected"))
		"known":
			return exposure != null and bool(exposure.has_rank("known"))
		"player":
			return exposure != null and bool(exposure.has_rank("player"))
		"trusted":
			return own_band in ["trusted", "bonded"]
		"warm":
			return own_band in ["warm", "trusted", "bonded"]
		"crew":
			return not gs.recruited_crew().is_empty()
		"broke":
			return int(gs.cash) < BROKE_LINE
		"default":
			return true
	return false

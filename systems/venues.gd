extends RefCounted
## Venues — the interiors behind the four cards on the Street screen.
##
## Two of the four are built here. The choice of which two was made by asking
## what each venue would front rather than what each would look like:
##
## - **The Spenard Gym** fronts `attributes.gd`, which has shipped a complete
##   nine-source growth table since the port began with exactly ONE caller.
##   `bag_work`, `cardio` and `sparring` were authored, rated, mapped to Combat
##   and then never reachable. The gym is the door.
## - **The Night Owl** fronts a job that was dead data. `night_owl` has been in
##   `gs.jobs` from the start — pay [55, 75], EVENING only, and Mina carved out
##   of firing because canon has her stop scheduling you rather than fire you —
##   and NOTHING in the codebase ever appended it to `jobs_discovered`, so
##   `jobs._apply` refused it forever. The counter is where you hear about the
##   counter.
##
## The other two are deliberately not built, and the reasons are worth keeping:
##
## - **The Nile** needs a gambling system. What exists for it is the resolution
##   half only — three callerless outcome shapes (`gambling`, `tonk_read`,
##   `celo_read`) with attribute mappings and observation footprints, and no
##   economy, stakes, opponents or screen under them. Its NPC, Biniam, is not on
##   the Exposure roster either. That is a build, not an interior.
## - **Home** would duplicate the Home nav tab wholesale — the operation card,
##   the market snapshot, turf and crew, the activity feed, People. Its one
##   distinctive obligation, rent, is already payable from the Phone.
##
## Nothing here owns money, heat or time. Money goes through the wallet, heat
## through Heat, and a slot through the time system — the same three owners
## every other surface uses.

const GREEN := Color(0.451, 0.722, 0.404)
const AMBER := Color(0.882, 0.651, 0.227)
const RED := Color(0.827, 0.161, 0.125)
const BLUE := Color(0.373, 0.663, 0.847)

const GYM := "spenard_gym"
const NIGHT_OWL := "night_owl"

## What a day at the gym costs and is worth.
##
## Three rows rather than three functions, for the reason `GROWTH_RATES` is a
## table: the gym's whole content is "which of these three did you do", and a
## fourth is a row. `growth_id` is the key into that table, so the two cannot
## drift — an activity whose id is not a growth source trains nothing, loudly.
const GYM_ACTIVITIES := [
	{"id": "cardio", "growth_id": "cardio", "name": "Run the treadmill",
		"cost": 15, "health": 0, "min_health": 20,
		"desc": "An hour of nothing but your own breathing. Cheap, and it adds up slower than anything else here."},
	{"id": "bag_work", "growth_id": "bag_work", "name": "Work the heavy bag",
		"cost": 15, "health": 0, "min_health": 20,
		"desc": "Nobody hits back. You learn where your weight goes before you learn what happens when it is wrong."},
	{"id": "sparring", "growth_id": "sparring", "name": "Get in the ring",
		"cost": 25, "health": 8, "min_health": 45,
		"desc": "Somebody hits back. Worth more than the other two put together, and you leave wearing it."},
]

## Canon has the Night Owl as a social floor as well as a counter: a night spent
## being read well is a Charisma source (`night_owl_social`, 0.15). One row
## because there is one thing to do there.
const NIGHT_OWL_SOCIAL_COST := 20

## SA-D3 (1.1.0): what Mina's read of you buys. Her band is the same ledger
## the People screen shows; nothing here is a second scale. Cold: the
## counter, and nothing else. Neutral: the counter and a quiet night.
## Warm: she tells you one true thing about the block. Trusted: the coffee
## is on her, and she still tells you. Bonded: she texts you what she
## heard, the kind of lead the phone bill is for.
const COUNTER_LINES := {
	"hostile": "Mina does not look up. Somebody else takes your money.",
	"cold": "Mina looks up, and goes back to what she was doing. That is the whole conversation.",
	"neutral": "Mina looks up, and goes back to what she was doing. That is as close to a welcome as this place gets.",
	"warm": "Mina has the coffee poured before you sit. She has things to tell you and she will get to them.",
	"trusted": "Mina waves the money off. \"Sit down.\" She has already heard something.",
	"bonded": "Mina keeps the end of the counter for you now. Whatever she hears, you hear.",
}
const MINA_TIERS := {"hostile": 0, "cold": 0, "neutral": 1, "warm": 2, "trusted": 3, "bonded": 4}
const MINA_FREE_AT := 3
const MINA_READS_AT := 2
const MINA_TEXTS_AT := 4
const NIGHT_OWL_GROWTH := "night_owl_social"

var gs: Node
var gm: Node
var time_system: RefCounted

func setup(game_state: Node, manager: Node, time_sys: RefCounted) -> void:
	gs = game_state
	gm = manager
	time_system = time_sys

func can_handle(action: String) -> bool:
	return action in ["enter_venue", "gym_train", "night_owl_social"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"enter_venue":
			return _enter(str(payload.get("venue_id", "")))
		"gym_train":
			return _train(str(payload.get("activity_id", "")))
		"night_owl_social":
			return _night()
	return {"ok": false, "reason": "Unknown venue action."}

# --- reads -------------------------------------------------------------------

func has_entered(venue_id: String) -> bool:
	return venue_id in gs.venues_entered

func activity_by_id(activity_id: String) -> Dictionary:
	for a in GYM_ACTIVITIES:
		if str(a["id"]) == activity_id:
			return a
	return {}

## How many sessions of this activity came before the next one. The number
## `AttributesSystem.train` needs, and the reason the counter is persisted.
func sessions(activity_id: String) -> int:
	return maxi(0, int(gs.attribute_sessions.get(activity_id, 0)))

## Why this activity cannot be done right now, or "" if it can. Structured the
## way every other surface's blocker is: the caller renders the string, and an
## empty string is the only "yes".
func train_blocker(activity_id: String) -> String:
	if gs.game_over:
		return "The run is over"
	var activity: Dictionary = activity_by_id(activity_id)
	if activity.is_empty():
		return "No such session"
	if gs.cash < int(activity["cost"]):
		return "You need $%d" % int(activity["cost"])
	if gs.health < int(activity["min_health"]):
		return "You are in no shape for it"
	return ""

func social_blocker() -> String:
	if gs.game_over:
		return "The run is over"
	if gs.cash < night_owl_price():
		return "You need $%d" % night_owl_price()
	return ""

# --- SA-D3: Mina's trust, read off her ledger --------------------------------

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func mina_band() -> String:
	var exposure: Node = _exposure()
	return str(exposure.band_of("mina")) if exposure != null else "neutral"

func mina_tier() -> int:
	return int(MINA_TIERS.get(mina_band(), 1))

func counter_line() -> String:
	return str(COUNTER_LINES.get(mina_band(), COUNTER_LINES["neutral"]))

## The coffee is on her from trusted up.
func night_owl_price() -> int:
	return 0 if mina_tier() >= MINA_FREE_AT else NIGHT_OWL_SOCIAL_COST

## One true thing about the block, in her words. The first that applies:
## somebody asking after you, the police out front, the corner running hot,
## or who was in asking for hands. Pure: reads state, writes nothing.
func mina_read() -> String:
	if str(gs.curtis_phase) != "invisible":
		return "Somebody was in asking what nights you come by. Didn't leave a name. Wasn't a cop."
	var heat_sys: Object = gm.system("heat")
	if heat_sys != null and str(heat_sys.band()) in ["WATCHED", "BURNING"]:
		return "Two units sat out front last week for no reason I could see. Just saying."
	var wander_sys: Object = gm.system("wander")
	if wander_sys != null and bool(wander_sys.facts().get("market_pressure_visible", false)):
		return "People keep saying the corner's expensive lately. That's usually right before it gets loud."
	return "Quiet. Ray was in asking if anybody wanted dock hours. Nobody did."

## What the streak is doing, for the screen. `days` is how many in a row,
## `live` is whether it still counts, and `to_bonus` is how many more are
## needed — 0 once the bonus is running.
func gym_streak_state() -> Dictionary:
	var attributes: Object = gm.system("attributes") if gm != null else null
	var needed: int = int(attributes.STREAK_DAYS) if attributes != null else 3
	var days: int = int(gs.gym_streak)
	var last: int = int(gs.gym_last_day)
	var live: bool = last >= 0 and gs.day - last <= 1
	return {
		"days": days if live else 0,
		"live": live and days >= needed,
		"to_bonus": maxi(0, needed - (days if live else 0)),
		"trained_today": last == gs.day,
	}

# --- actions -----------------------------------------------------------------

## Walking in. Costs nothing and takes no time — it is a door, not an action —
## but it is a dispatch rather than a screen-side write because it mutates, and
## a screen never mutates.
func _enter(venue_id: String) -> Dictionary:
	if venue_id.is_empty():
		return {"ok": false, "reason": "No such venue."}
	if has_entered(venue_id):
		return {"ok": true, "first_visit": false}
	gs.venues_entered.append(venue_id)
	if venue_id == NIGHT_OWL:
		_offer_the_counter()
	return {"ok": true, "first_visit": true}

## Mina, the first time you come in through the front rather than to rob it.
##
## This is the fix for the dead `night_owl` job. It has been in the roster since
## the port began, correctly priced and correctly slotted, and unreachable
## because `jobs_discovered` is seeded with five ids and nothing ever added a
## sixth. A job you can never find is worse than a job that is not there — the
## data says the game has it.
func _offer_the_counter() -> void:
	if NIGHT_OWL in gs.jobs_discovered:
		return
	gs.jobs_discovered.append(NIGHT_OWL)
	gs.log_activity("Mina mentions the counter is short a night.", BLUE)
	var phone: Object = gm.system("phone") if gm != null else null
	if phone != null:
		phone.push_text("Mina",
			"we're short evenings if you want them. it's not much and you'd be "
			+ "working next to me. say the word and i'll put you on.", "mina_counter")

func _train(activity_id: String) -> Dictionary:
	var blocked: String = train_blocker(activity_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked + "."}
	var activity: Dictionary = activity_by_id(activity_id)
	var cost: int = int(activity["cost"])
	var wallet: Object = gm.system("wallet")
	# Routine, not high-visibility. A gym membership is the most ordinary thing
	# a person spends money on and leaves nobody a record worth reading.
	wallet.spend(cost, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "gym_%s" % activity_id})

	var hurt: int = int(activity["health"])
	if hurt > 0:
		gs.health = clampi(gs.health - hurt, 0, gs.health_max)

	var before: int = sessions(activity_id)
	gs.attribute_sessions[activity_id] = before + 1
	var attributes: Object = gm.system("attributes")
	var improved: bool = bool(attributes.train(str(activity["growth_id"]), before))
	_advance_streak()

	var line := "%s at the gym for $%d." % [str(activity["name"]), cost]
	if hurt > 0:
		line = "%s at the gym for $%d, and %d health for the privilege." % [
			str(activity["name"]), cost, hurt]
	gs.log_activity(line, AMBER if hurt > 0 else GREEN)
	time_system.handle("advance_time", {})
	return {"ok": true, "improved": improved, "cost": cost, "health": -hurt,
		"sessions": before + 1}

## Canon's gym streak, advanced once per DAY rather than once per session.
##
## Training twice in one day is two sessions and one day — a streak counts days
## in a row, and letting a second session bump it would let a player buy the
## bonus in an afternoon.
func _advance_streak() -> void:
	var last: int = int(gs.gym_last_day)
	if last == gs.day:
		return
	if last == gs.day - 1:
		gs.gym_streak = int(gs.gym_streak) + 1
	else:
		gs.gym_streak = 1
	gs.gym_last_day = gs.day
	var attributes: Object = gm.system("attributes")
	if attributes != null and int(gs.gym_streak) == int(attributes.STREAK_DAYS):
		gs.log_activity("Three days running. It shows in how you stand.", GREEN)

## A night at the counter. Charisma, a drink, and Mina seeing you somewhere that
## is not a crime scene.
func _night() -> Dictionary:
	var blocked: String = social_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked + "."}
	var wallet: Object = gm.system("wallet")
	var price: int = night_owl_price()
	if price > 0:
		wallet.spend(price, wallet.ROUTINE_DIRTY_FIRST,
			{"source_id": "night_owl_social"})

	var before: int = sessions(NIGHT_OWL_GROWTH)
	gs.attribute_sessions[NIGHT_OWL_GROWTH] = before + 1
	var attributes: Object = gm.system("attributes")
	var improved: bool = bool(attributes.train(NIGHT_OWL_GROWTH, before))

	# Mina reads DISCRETION at 4.0 and violence at -4.0 — she is the one lens in
	# the game that scores a quiet night as information about you. A night here
	# is the cheapest discretion the player can buy, which is exactly why it
	# costs a slot they could have spent earning.
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null:
		exposure.record_observation("mina", {
			"type": "discretion", "event": "ordinary_night",
			"source": "household", "location": str(gs.current_district_id),
		})
	if price > 0:
		gs.log_activity("A night at the Night Owl counter. $%d and nothing happened." % price, GREEN)
	else:
		gs.log_activity("A night at the Night Owl counter. Mina would not take the money.", GREEN)
	# SA-D3: what her trust buys. Warm and up, she tells you one true thing;
	# bonded, it is on your phone too, where you can read it tomorrow.
	var read := ""
	if mina_tier() >= MINA_READS_AT:
		read = mina_read()
		gs.log_activity("Mina, low, wiping the counter: \"%s\"" % read, BLUE)
		if mina_tier() >= MINA_TEXTS_AT:
			var phone: Object = gm.system("phone")
			if phone != null:
				phone.push_text("Mina", read.to_lower().replace("didn't", "didnt").replace("wasn't", "wasnt"), "mina_lead")
	time_system.handle("advance_time", {})
	return {"ok": true, "improved": improved, "cost": price,
		"sessions": before + 1, "read": read}

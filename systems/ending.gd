extends RefCounted
## The ending -- One Good Run (PR 4, OG-D4). D-2, open since the project
## began, ruled per docs/VISION_REVIEW.md §5:
##
##   The run ends when you get out: clean money past a threshold that
##   scales with what you built, a Boss's name, and a day you choose. The
##   run ends at that day's close.
##
##   The run ends when the city gets you: evicted (the house warnings,
##   kept), locked up (the third serious booking is a sentence), or Curtis
##   (Exposure maxed and nobody standing with you -- he comes to the door).
##
##   Both are one screen: the reckoning. What you built, what it cost, who
##   remembers you.
##
## `gs.game_over_kind` names which; `gs.leaving` is the day you chose.

const RANK := preload("res://data/rank.gd")

## What leaving clean costs: the more you built, the more you are walking
## away from, and the more it takes to walk away with.
const WAY_OUT_BASE := 3000
const WAY_OUT_PER_CORNER := 400
const WAY_OUT_PER_CREW := 300
## The severities that count toward a sentence.
const SERIOUS := ["stick_t2", "stick_t3", "boost_t2"]
const SENTENCE_AT := 3
## Mornings maxed and alone before Curtis comes himself. The first is a text
## from a number you do not have saved; the second is his car; the third is
## the door.
const DOORSTEP_AT := 3
const DOORSTEP_TEXT := "You out here by yourself. I noticed."
const DOORSTEP_LINES := [
	"Curtis's people are parked across from the building. Nobody with you but Juan.",
	"Same car, closer. He stops sending people after this.",
]

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

func can_handle(action: String) -> bool:
	return action in ["leave_city", "stay"]

func handle(action: String, _payload: Dictionary) -> Dictionary:
	match action:
		"leave_city":
			return _leave()
		"stay":
			gs.leaving = false
			gs.log_activity("Not today. The room is still yours.", AMBER)
			return {"ok": true}
	return {"ok": false, "reason": "Unknown ending action."}

# --- the way out -------------------------------------------------------------

func way_out_threshold() -> int:
	return WAY_OUT_BASE + WAY_OUT_PER_CORNER * int(gs.territory_nodes.size()) \
		+ WAY_OUT_PER_CREW * int(gs.recruited_crew().size())

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

## Why you cannot leave yet, or "".
func leave_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	if gs.leaving:
		return "Tonight."
	var exposure: Node = _exposure()
	if exposure != null and not exposure.has_rank("boss"):
		return "Not a boss yet. Nobody leaves as less."
	var need: int = way_out_threshold()
	if int(gs.clean_cash) < need:
		return "Need $%s clean. Dirty money does not travel." % _commas(need)
	return ""

func _leave() -> Dictionary:
	var blocked := leave_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	gs.leaving = true
	gs.log_activity("You decide. Tonight, when the day closes, you are on the last flight out with what is clean. Whatever is not stays.", GREEN)
	return {"ok": true}

## POST_SETTLE: the day you chose closes.
func settle_way_out(_ended_day: int) -> void:
	if gs.game_over or not gs.leaving:
		return
	_end("out", "You made it out.")

# --- the city gets you ------------------------------------------------------

## The booking commit calls this once per booking, behind its own receipt.
func note_booking(severity: String) -> void:
	if not severity in SERIOUS:
		return
	var record: Dictionary = gs.arrest_record
	record["serious"] = int(record.get("serious", 0)) + 1
	gs.arrest_record = record
	if int(record["serious"]) >= SENTENCE_AT and not gs.game_over:
		_end("sentence", "Third serious booking. The judge does not need to hear the rest.")

## DAY_START: Curtis, when Exposure is maxed and nobody is standing with you.
func day_start_curtis(_today: int) -> void:
	if gs.game_over:
		return
	if int(gs.curtis_awareness) < int(gs.AWARENESS_MAX) or not gs.recruited_crew().is_empty():
		gs.curtis_doorstep = 0
		return
	gs.curtis_doorstep = int(gs.curtis_doorstep) + 1
	if gs.curtis_doorstep >= DOORSTEP_AT:
		_end("curtis", "Curtis comes to the door himself. Nobody is standing with you, and he knew that before he knocked.")
		return
	if gs.curtis_doorstep == 1:
		var phone: Object = gm.system("phone") if gm != null else null
		if phone != null:
			phone.push_text("Curtis", DOORSTEP_TEXT, "curtis_doorstep")
	gs.log_activity(str(DOORSTEP_LINES[mini(gs.curtis_doorstep, DOORSTEP_LINES.size()) - 1]), RED)

func _end(kind: String, reason: String) -> void:
	gs.game_over = true
	gs.game_over_kind = kind
	gs.game_over_reason = reason
	gs.log_activity(reason, GREEN if kind == "out" else RED)

# --- the reckoning ----------------------------------------------------------

const HEADS := {
	"out": "YOU MADE IT OUT",
	"evicted": "NOWHERE TO GO",
	"sentence": "THE SENTENCE",
	"curtis": "CURTIS",
	"": "THE RUN ENDED",
}
const KICKERS := {
	"out": "ONE GOOD RUN",
	"evicted": "THE CITY GOT YOU",
	"sentence": "THE CITY GOT YOU",
	"curtis": "THE CITY GOT YOU",
	"": "THE RUN",
}

## One line per person you met, by where you left them.
const NPC_LINES := {
	"yalonda": {
		"cold": "Yalonda changes the locks the same day. She does not tell your sister why.",
		"neutral": "Yalonda rents the room out the next week. She keeps the envelope you left.",
		"warm": "Yalonda tells your sister you were all right. From her, that is a reference.",
		"trusted": "Yalonda keeps the room empty a month before she lets it go. She would not say that was for you.",
		"bonded": "Yalonda still has your number. She uses it, once a year, on the day you left.",
	},
	"juan": {
		"cold": "Juan tells people he barely knew you. He is not wrong.",
		"neutral": "Juan gets a new roommate. He does not mention the last one.",
		"warm": "Juan keeps the People Mover pass you left on the table. He uses it to Ship Creek every morning.",
		"trusted": "Juan is at the dock at six every day and tells the new guys about the roommate who got out.",
		"bonded": "Juan comes to see you, once, outside. He brings the cold with him in a way you both laugh about.",
	},
	"mina": {
		"cold": "Mina does not look up when your name comes through the Night Owl. She heard it.",
		"neutral": "Mina makes your coffee for somebody else now. She never asked how they take it.",
		"warm": "Mina keeps your stool empty at the counter for a while. Regulars notice, and nobody sits there.",
		"trusted": "Mina writes your name on the wall behind the register, small, where the regulars go.",
		"bonded": "Mina closes the Night Owl for one night. She does not say why, and the block does not ask.",
	},
	"dre": {
		"cold": "Dre puts your name on a list he keeps. He is patient with lists.",
		"neutral": "Dre fronts money to the next new face. The terms are the same. They always are.",
		"warm": "Dre tells people you paid. In Spenard, that is the only obituary that matters.",
		"trusted": "Dre keeps a chair at the back of the Nile that nobody else sits in. It is yours, if you ever come back.",
		"bonded": "Dre and you are the two names on this city now, and he says yours first.",
	},
	"curtis": {
		"cold": "Curtis never learned your name. That was the whole plan, and it worked.",
		"neutral": "Curtis knows the name. He files it. He has a lot of files.",
		"warm": "Curtis knows what you took and where. His people watch the corners you held for a month after.",
		"trusted": "Curtis holds a meeting about you. Nobody says your name in it, which is how you know it was about you.",
		"bonded": "Curtis. There is a version of this city where one of you had to leave, and it was you.",
	},
}
const CREW_LINES := {
	"stayed": "%s stays on. There is a crew without you now, and it has your shape.",
	"around": "%s is still around. Somebody else's crew, by spring.",
	"gone": "%s was gone before you were.",
}

func _band_of(npc_id: String) -> String:
	var exposure: Node = _exposure()
	return str(exposure.band_of(npc_id)) if exposure != null else "neutral"

## Everything the screen shows, in one dictionary, so the screen has no
## opinions.
func reckoning() -> Dictionary:
	var kind := str(gs.game_over_kind)
	var exposure: Node = _exposure()
	var people: Array = []
	for npc_id in ["yalonda", "juan", "mina", "dre", "curtis"]:
		if exposure == null or (exposure.ledger_of(npc_id) as Array).is_empty():
			if not npc_id in ["yalonda", "juan"]:
				continue
		var lines: Dictionary = NPC_LINES.get(npc_id, {})
		var band: String = _band_of(npc_id)
		people.append(str(lines.get(band, lines.get("neutral", ""))))
	var crew: Array = []
	for id in gs.recruited_crew():
		var loyalty: int = int(gs.crew_record(str(id)).get("loyalty", 0))
		var name := str(gs.crew_member_by_id(str(id)).get("name", str(id))).split(" ")[0]
		var shape := "stayed" if loyalty >= 7 else ("around" if loyalty >= 4 else "gone")
		crew.append(str(CREW_LINES[shape]) % name)
	var corners: Array = []
	for id in gs.territory_nodes.keys():
		corners.append(str(gs.block_by_id(str(id)).get("name", str(id))))
	var earned := 0
	for source in gs.run_earnings.keys():
		earned += int(gs.run_earnings[source])
	return {
		"kind": kind,
		"kicker": str(KICKERS.get(kind, KICKERS[""])),
		"head": str(HEADS.get(kind, HEADS[""])),
		"reason": str(gs.game_over_reason),
		"days": int(gs.day),
		"earned": earned,
		"clean": int(gs.clean_cash),
		"cash": int(gs.cash),
		"rank": str(exposure.rank()["name"]) if exposure != null else "",
		# SA-D1 (1.1.0): the road not taken. What there was against what
		# you took: the name against six, the corners against the board,
		# the districts against the city.
		"rank_index": int(exposure.rank_index()) if exposure != null else 0,
		"rank_count": RANK.TIERS.size(),
		"corner_count": gs.TERRITORY_DEFS.NODES.size(),
		"districts_known": (gs.districts_unlocked as Array).size(),
		"district_count": (gs.districts as Array).size(),
		"corners": corners,
		"crew": crew,
		"people": people,
	}

func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

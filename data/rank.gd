extends RefCounted
## Rank -- earn your name (One Good Run PR 2, OG-D2).
##
## `gs.respect` was a HUD number nothing ever wrote. Rank replaces it and is
## DERIVED: it is what the city's ledgers say about you, summed. Every
## observation any NPC holds -- Yalonda seeing the rent, Mina seeing you
## behind her counter, Curtis's people seeing you hold a corner -- is a row,
## and the rows weigh by what kind of thing they record. Nothing persists
## but the ledgers, which already do.
##
## Six tiers. Nobody is the run's first morning. Boss is the ending's door.

const TIERS := [
	{"id": "nobody", "name": "NOBODY", "floor": 0,
		"line": "Nobody. A new face with a bag."},
	{"id": "new_face", "name": "NEW FACE", "floor": 3,
		"line": "Somebody at the laundromat asks Juan who you are. That is the first time."},
	{"id": "known", "name": "KNOWN", "floor": 8,
		"line": "Known. People stop asking Juan who you are and start asking you."},
	{"id": "player", "name": "PLAYER", "floor": 15,
		"line": "A player. Your name gets said in rooms you are not in, and it means something when it is."},
	{"id": "connected", "name": "CONNECTED", "floor": 25,
		"line": "Connected. The people who matter in this city know how to reach you, and they do."},
	{"id": "boss", "name": "BOSS", "floor": 40,
		"line": "Boss. There is a version of Anchorage where your name is the answer to a question, and you are standing in it."},
]

## What a row is worth, by category. Quiet, honest, paying-on-time rows
## build a name slowly; standing your ground, growing, holding ground build
## it fast. Submission and being seen hot build nothing.
const TYPE_WEIGHTS := {
	"presence": 1, "honesty": 1, "financial": 1, "loyalty": 1, "discretion": 1,
	"violence": 1, "betrayal": 1,
	"defiance": 2, "growth": 2, "territory": 2,
	"submission": 0, "heat_exposure": 0,
}
## A row counts at most this many times: a name is made of many things,
## not one thing done thirty times.
const COUNT_CAP := 3

## Who notices, and what they say, when a rank is reached.
const NOTICES := {
	"new_face": {"from": "Juan", "text": "somebody at the wash and go asked me who you were. told em youre my roommate. thats a first"},
	"known": {"from": "Juan", "text": "people know your name now. thats good and its not good. you know that right"},
	"player": {"from": "Deshawn", "text": "block's saying your name like it means something. keep it meaning something"},
	"connected": {"from": "Pherris", "text": "got three people this week asking me how to reach you. I said through me. you're welcome"},
	"boss": {"from": "Dre", "text": "There's a name on this city now. Mine used to be the only one. Come see me before you do anything about that."},
}

static func score_of(ledgers: Dictionary) -> int:
	var total := 0
	for npc_id in ledgers.keys():
		var rows: Variant = ledgers[npc_id]
		if not (rows is Array):
			continue
		for row in rows:
			if not (row is Dictionary):
				continue
			var weight: int = int(TYPE_WEIGHTS.get(str((row as Dictionary).get("type", "")), 1))
			total += weight * mini(int((row as Dictionary).get("count", 1)), COUNT_CAP)
	return total

static func tier_for(score: int) -> Dictionary:
	var best: Dictionary = TIERS[0]
	for tier in TIERS:
		if score >= int(tier["floor"]):
			best = tier
	return best

static func index_of(tier_id: String) -> int:
	for i in TIERS.size():
		if str(TIERS[i]["id"]) == tier_id:
			return i
	return 0

static func by_index(index: int) -> Dictionary:
	return TIERS[clampi(index, 0, TIERS.size() - 1)]

## The next tier up from a score, or {} at the top.
static func next_after(score: int) -> Dictionary:
	var current := index_of(str(tier_for(score)["id"]))
	if current >= TIERS.size() - 1:
		return {}
	return TIERS[current + 1]

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
	# TU-D2: money earns a name too -- what you do with it, capped per thing.
	"presence": 1, "honesty": 1, "financial": 2, "loyalty": 1, "discretion": 1,
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

## TU-D2 (1.3.0): a thing that happened counts once, however many people
## heard about it. A shift's `steady_work` reaches every ledger on the
## neighbourhood channel; before this it scored on each of them, so a
## couple of shifts made a Known and a week made a Connected, and the
## playtest could not say how. Rows are folded by their key (type, event,
## location), the count is the highest any one ledger holds, and showing
## up -- presence -- is capped as a whole, because being around is not a
## name. What earns a name is what you did on the street: the cards.
const PRESENCE_CAP := 3

## key -> {"type", "event", "location", "count"}: every distinct thing the
## city has written down about you, folded across ledgers.
static func folded(ledgers: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for npc_id in ledgers.keys():
		var rows: Variant = ledgers[npc_id]
		if not (rows is Array):
			continue
		for row in rows:
			if not (row is Dictionary):
				continue
			var r: Dictionary = row
			var key := str(r.get("key", "%s|%s|%s" % [str(r.get("type", "")), str(r.get("event", "")), str(r.get("location", ""))]))
			var count: int = mini(int(r.get("count", 1)), COUNT_CAP)
			if out.has(key):
				out[key]["count"] = maxi(int(out[key]["count"]), count)
			else:
				out[key] = {"type": str(r.get("type", "")), "event": str(r.get("event", "")),
					"location": str(r.get("location", "")), "count": count}
	return out

static func _row_points(entry: Dictionary) -> int:
	return int(TYPE_WEIGHTS.get(str(entry.get("type", "")), 1)) * int(entry.get("count", 1))

static func score_of(ledgers: Dictionary) -> int:
	var total := 0
	var presence := 0
	for entry in folded(ledgers).values():
		var points: int = _row_points(entry)
		if str((entry as Dictionary).get("type", "")) == "presence":
			presence += points
		else:
			total += points
	return total + mini(presence, PRESENCE_CAP)

## The three things that did the most, in words: "talked the cousin down",
## "the knife at the ice machine". Event ids read as sentences once the
## underscores go, which is how they were named.
static func reasons_of(ledgers: Dictionary, limit: int = 3) -> Array:
	var entries: Array = folded(ledgers).values()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _row_points(a) > _row_points(b))
	var out: Array = []
	for entry in entries:
		if _row_points(entry) <= 0:
			continue
		var event := str((entry as Dictionary).get("event", "")).replace("_", " ")
		if event.is_empty() or event == "staged" or event in out:
			continue
		out.append(event)
		if out.size() >= limit:
			break
	return out

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

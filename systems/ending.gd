extends RefCounted
## The ending -- One Good Run (PR 4, OG-D4), corrected by FL-D1 and FL-D3
## (1.5.1, "The Floor"). D-2 is closed.
##
## ## What ends a run, as of 1.5.1
##
##   **Death.** `health <= 0`. Checked in ONE place -- `note_health()`, called
##   from `GameState.reconcile_persistent_invariants()`, which every successful
##   dispatch already runs before `state_changed`. No write site checks health;
##   the fourteen writers are untouched. The web canon ended the run here
##   (`game-core.js:6504`, `endRun(state, "killed")`) and the port never carried
##   it over, which is the bug this closes.
##
##   **The city gets you:** evicted (the house warnings, kept), locked up (the
##   third serious booking is a sentence), or Curtis (Exposure maxed and nobody
##   standing with you -- he comes to the door).
##
## ## What does NOT end a run any more
##
## **There is no way out.** 1.0.0 shipped a "cash out": at Boss, with clean
## money past a scaling threshold, the player left and the run was declared
## won. The owner ruled that out of the game in 1.5.1 -- 907Hustle is a long
## career in which a surviving player keeps building wealth and organization,
## and legitimacy at the top EXPANDS what the player can do rather than ending
## the run. **No money threshold of any kind replaces it.** `leave_city`,
## `stay`, `_leave`, `leave_blocker`, `way_out_threshold` and the three
## `WAY_OUT_*` constants are deleted, not deprecated (the `spenard_blocks`
## rule). The `"out"` KIND survives for saves that already ended that way and
## is never produced again; every legacy arm is commented as such.
##
## **Injury is not death** (FL-D2). Nothing about health above zero changes:
## recovery, the clinic, the doctor and the gym's min-health gates stay as they
## are, and the two rooms authored to floor health at 1 (`territory.gd`'s
## contest loss, `businesses.gd`'s lean loss) keep their floor.
##
## Every ending is one screen: the reckoning. What you built, what it cost, who
## remembers you. `gs.game_over_kind` names which.

const RANK := preload("res://data/rank.gd")

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

## FL-D3: this system dispatches nothing. `leave_city` and `stay` were the
## only two actions it ever handled and both are gone with the road they served
## -- an unknown action is refused by `GameManager` before it reaches here,
## which is what makes the negative arm in parity assertable.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "Unknown ending action."}

# --- the floor (FL-D1) ------------------------------------------------------

## Zero is death, and it is checked in ONE place.
##
## Called from `GameState.reconcile_persistent_invariants()`, which runs inside
## every successful dispatch BEFORE `state_changed` -- so the reckoning is on
## screen on the same refresh as the hit that caused it, and the encounter sheet
## that dealt it does not get a frame to render over a dead player.
##
## **No write site checks health.** The fourteen writers are untouched, which is
## the whole point of doing it here: a new room that hurts the player inherits
## the floor without knowing the floor exists.
##
## Safe to call with `gm` absent -- the lifecycle ordering tests drive settlement
## without every system registered -- because it touches nothing but `gs`.
##
## The reason names no source. The feed's last line is the source.
func note_health() -> void:
	if gs == null or gs.game_over:
		return
	if int(gs.health) > 0:
		return
	_end("dead", DEATH_REASON)

## VOX-D1, the Power register: a death is a fact. Nobody narrates it.
const DEATH_REASON := "On the ground, with what you had on you. Nobody calls it in."

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

## POST_SETTLE `way_out`: the step keeps its NAME and loses its job.
##
## FL-D3 (owner default 3): the lifecycle trace is pinned literally in parity
## (`POST_SETTLE:way_out`), and keeping the name means the pin, the step list
## and the phase ordering all stay exactly as shipped while the road underneath
## them is gone. All this does now is neutralise a stale `leaving` flag on a
## save written before 1.5.1 -- the validator repairs it on load, and this
## catches the one that was already in memory. It ends nothing.
func settle_way_out(_ended_day: int) -> void:
	if gs == null:
		return
	gs.leaving = false

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
	# Legacy only: `"out"` is never produced after FL-D3, but a save that
	# already ended that way still renders its green line.
	gs.log_activity(reason, GREEN if kind == "out" else RED)

# --- the reckoning ----------------------------------------------------------

const HEADS := {
	# FL-D1: the floor. Owner default, 2026-09-06.
	"dead": "IT ENDS HERE",
	# Legacy only (FL-D3): kept so a save that ended this way before 1.5.1 still
	# renders. No road produces it.
	"out": "YOU MADE IT OUT",
	"evicted": "NOWHERE TO GO",
	"sentence": "THE SENTENCE",
	"curtis": "CURTIS",
	"": "THE RUN ENDED",
}
const KICKERS := {
	"dead": "THE CITY GOT YOU",
	# Legacy only (FL-D3), as above.
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

extends RefCounted
## The doorstep — DOOR-D1/D2 (0.5.0 PR D).
##
## Three obligations already ratchet toward the run's own end conditions —
## Dre's account (`gs.dre_account`), a Book loan gone bad (`gs.shark_loans`),
## and rent arrears (`gs.rent_missed`/`gs.household_warnings`) — and until
## this PR every one of them let the player just keep tapping around it:
## Dre's own ultimatum waited for `dre_lender.settle_night` to notice it,
## a defaulted Book note sat available-but-ignorable until the player felt
## like resolving it, and rent's escalation was pure log lines counting down
## to a game over the player never got to answer. DOOR-D1 forces the visit
## instead, staged: first the word (unchanged — see below), then the
## collection (a forced decision, assets on the table), then enforcement
## (STR-D5's second room, a real physical risk that was never modelled for
## any of these three before now).
##
## ## "The word" needed no new code
##
## The mildest stage already exists as the passive warning each obligation
## already prints the first time it goes bad (Dre's "due"/"overdue" phone
## messages, `shark.gd`'s "the note needs a decision" log line, rent's own
## per-miss log line) — none of them block anything, and forcing a screen
## interrupt on the day's FIRST sign of trouble would fight the same balance
## guard this build's other interruption gates were tuned against (STR-D1's
## own danger list: "must not turn the button into a tax that makes it not
## worth pressing"). What DOOR-D1 actually asks to stop being avoidable is
## the two stages that cost something real, so those are the two this file
## adds.
##
## ## Nothing new persisted
##
## Every stage below is computed off a field that already exists and never
## resets on its own once an obligation goes bad: `dre_account.due_day`,
## a shark loan's own `due_day`, and `gs.rent_missed`/`household_warnings`.
## `gs.day - due_day` is a valid, ever-growing "how overdue" measure for
## both Dre and Book without a new field, and rent's own warning counter
## already climbs on its own. Ground rules: "derive before you persist" —
## this PR found nothing that could not be, so `SAVE_VERSION` does not move.
##
## ## One room, three tenants
##
## STR-D5 calls this "the build's SECOND room" — singular. Three independent
## implementations would triple the surface a future round-mechanics change
## has to find and fix; `_open_enforcement`/`_room_round`/`_room_exit` below
## are one chassis (built on `ConfrontationLoop`'s shared helpers, same as
## the shakedown room) parameterized by `family`, with each family's own
## `_close_*` function the only place that actually differs.
##
## ## Book's room points the other way
##
## Dre and rent are debts the PLAYER owes — the room's health risk is what
## collecting FROM the player looks like. The Book is the one place in this
## game the player is the LENDER (`shark.gd`'s existing `enforce`/`extend`/
## `forgive`, all of them currently risk-free), so a defaulted note left
## unresolved does not put a collector on the player's doorstep — it forces
## the player to stop avoiding what THEY have been putting off. FIGHT here
## is the player pressing a resistant borrower, and it is the player who can
## come away hurt if it goes badly — the same shape `dre_collect_hard`'s own
## PRESS verb already has, just no longer optional. Recorded as a flagged
## choice in `docs/DECISIONS.md`, not left to read as an inconsistency.

const LOOP := preload("res://systems/confrontation_loop.gd")

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

## Days past `due_day`, while suspended, before Dre's account escalates past
## the existing pay-now/stall ultimatum into the enforcement room.
const DRE_ENFORCEMENT_DELAY_DAYS := 5
## Days past `due_day`, while defaulted, before a Book note forces the
## enforce/extend/forgive decision the player could otherwise defer forever.
const BOOK_COLLECTION_DELAY_DAYS := 2
## Days past `due_day`, still defaulted, before that same note escalates
## into the room.
const BOOK_ENFORCEMENT_DELAY_DAYS := 6
## `household_warnings` count that forces the room -- one short of
## `HOUSEHOLD_WARNING_LIMIT`, so a player who survives it still has the
## existing end condition as the actual last word, never this room.
const RENT_ENFORCEMENT_AT_WARNING := 2

const ROOM_ROUND_CAP := 3
## `LIFT_ESCALATION`'s own per-round penalty, reused rather than re-picked --
## the established shape for "an escalating room degrades its own odds by a
## fixed step per round."
const ROOM_ROUND_PENALTY := -0.10

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

## No action of its own, same as `retaliation.gd` -- the visit is never
## something the player asks for, and every response to one goes through
## the engine's `resolve_consequence_choice`.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The doorstep takes no actions."}

func _wallet() -> Object:
	return gm.system("wallet") if gm != null else null

func _crew() -> Object:
	return gm.system("crew") if gm != null else null

func _engine() -> Object:
	return gm.system("consequence") if gm != null else null

# --- DOOR-D1: the threshold table --------------------------------------------

## `{}` if Dre has no forced visit due, else `{"family":"dre","stage":1|2,
## "severity":<days overdue>}`. Stage 1 is the existing ultimatum
## (`dre_collector.open_player_default_encounter`'s own trigger, read here
## rather than re-derived); stage 2 is this PR's own enforcement room.
func _dre_visit() -> Dictionary:
	var account: Dictionary = gs.dre_account
	var status := str(account.get("status", "clear"))
	var due_day: int = int(account.get("due_day", gs.day))
	var overdue: int = int(gs.day) - due_day
	if status == "overdue":
		var lender: Object = gm.system("dre") if gm != null else null
		var delay: int = int(lender.OVERDUE_RESPONSE_DELAY_DAYS) if lender != null else 2
		if overdue >= delay:
			return {"family": "dre", "stage": 1, "severity": overdue}
	elif status == "suspended" and overdue >= DRE_ENFORCEMENT_DELAY_DAYS:
		return {"family": "dre", "stage": 2, "severity": overdue}
	return {}

## The single worst defaulted Book note, if any crosses a threshold --
## `{}` otherwise, else `{"family":"book","stage":1|2,"severity":<days
## overdue>,"loan_id":<id>}`.
func _book_visit() -> Dictionary:
	var worst: Dictionary = {}
	for entry in gs.shark_loans:
		var loan: Dictionary = entry
		if str(loan.get("status", "")) != "defaulted":
			continue
		var overdue: int = int(gs.day) - int(loan.get("due_day", gs.day))
		if overdue < BOOK_COLLECTION_DELAY_DAYS:
			continue
		var stage: int = 2 if overdue >= BOOK_ENFORCEMENT_DELAY_DAYS else 1
		if worst.is_empty() or overdue > int(worst["severity"]):
			worst = {"family": "book", "stage": stage, "severity": overdue,
				"loan_id": int(loan["id"])}
	return worst

## `{}` if rent has no forced visit due, else `{"family":"rent","stage":1|2,
## "severity":<household_warnings>}`. Stage 1 matches the existing
## `_household_warning` first call exactly -- this does not change when
## that warning starts, only what standing in front of it now costs.
func _rent_visit() -> Dictionary:
	var warnings: int = int(gs.household_warnings)
	if warnings >= RENT_ENFORCEMENT_AT_WARNING:
		return {"family": "rent", "stage": 2, "severity": warnings}
	if warnings >= 1:
		return {"family": "rent", "stage": 1, "severity": warnings}
	return {}

## DOOR-D2: the most escalated obligation wins; a tie breaks on whichever is
## more overdue in its own terms. Ties that survive even that (identical
## stage AND severity) resolve in table order -- dre, then book, then rent --
## a fixed, deterministic rule rather than an unstated one.
func worst_visit() -> Dictionary:
	var candidates: Array = [_dre_visit(), _book_visit(), _rent_visit()]
	var best: Dictionary = {}
	for entry in candidates:
		if entry.is_empty():
			continue
		if best.is_empty() or int(entry["stage"]) > int(best["stage"]) \
				or (int(entry["stage"]) == int(best["stage"]) \
					and int(entry["severity"]) > int(best["severity"])):
			best = entry
	return best

## DOOR-D2's own day-start hook, registered in `GameManager`. Refuses quietly
## whenever the floor is already spoken for -- by the engine's own active-chain
## guard, or by the run already being over -- exactly the way every other
## forced-open mechanism in this build defers rather than errors.
func try_force_visit(_today: int) -> void:
	var engine: Object = _engine()
	if engine == null or bool(engine.has_active()) or bool(gs.game_over):
		return
	var visit: Dictionary = worst_visit()
	if visit.is_empty():
		return
	match str(visit["family"]):
		"dre":
			if int(visit["stage"]) == 1:
				var collector: Object = gm.system("dre_collector") if gm != null else null
				if collector != null:
					collector.open_player_default_encounter()
			else:
				_open_enforcement("dre", visit)
		"book":
			if int(visit["stage"]) == 1:
				_open_book_collection(visit)
			else:
				_open_enforcement("book", visit)
		"rent":
			if int(visit["stage"]) == 1:
				_open_rent_collection(visit)
			else:
				_open_enforcement("rent", visit)

# --- stage 1: Book's forced decision ------------------------------------------

## The existing `enforce`/`extend`/`forgive` menu, forced rather than
## optional -- all three stay exactly the risk-free rolls `shark.gd` already
## makes them; only reaching this decision is new.
func _open_book_collection(visit: Dictionary) -> void:
	var engine: Object = _engine()
	var loan: Dictionary = gm.system("shark").loan_by_id(int(visit["loan_id"]))
	var borrower: Dictionary = gs.borrower_by_id(str(loan.get("borrower_id", "")))
	gs.log_activity("%s's note is still open, and it is not going away." \
		% str(borrower.get("name", "The note")), AMBER)
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": gs.current_district_id,
		"return_route": "HOME",
		"source": {"family": "book", "kind": "book_collection", "action_id": "doorstep",
			"target_id": str(borrower.get("id", "")), "target_name": str(borrower.get("name", "")),
			"loan_id": int(visit["loan_id"])},
		"decision": {
			"allowed_choices": ["enforce", "extend", "forgive"],
			"deterministic_choices": ["enforce", "extend", "forgive"],
			"shown_probabilities": {},
		},
	})

# --- stage 1: rent's forced decision ------------------------------------------

func _open_rent_collection(visit: Dictionary) -> void:
	var engine: Object = _engine()
	var owed: int = int(gs.rent_missed) * int(gs.WEEKLY_RENT)
	gs.log_activity("Yalonda is not asking again. The back rent is $%d." % owed, AMBER)
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": gs.current_district_id,
		"return_route": "HOME",
		"source": {"family": "rent", "kind": "rent_collection", "action_id": "doorstep",
			"target_name": "Yalonda", "contested_take": owed},
		"decision": {
			"allowed_choices": ["pay", "ignore"],
			"deterministic_choices": ["pay", "ignore"],
			"shown_probabilities": {},
		},
	})

func choice_blocked(choice_id: String) -> String:
	if choice_id != "pay":
		return ""
	var owed: int = int(gs.rent_missed) * int(gs.WEEKLY_RENT)
	if int(gs.cash) < owed:
		return "You don't have $%d." % owed
	return ""

# --- stage 2: the enforcement room --------------------------------------------

## Every family opens the same three-verb room: FIGHT (confrontation,
## Combat), TALK (negotiation, Charisma), YIELD (deterministic). `base`
## reflects how each family's own fiction is already leaning -- Dre and
## rent read as a hostile visitor easier talked down than fought off; the
## Book reads as the reverse, since FIGHT there is the player pressing,
## not defending.
const ROOM_BASE: Dictionary = {
	"dre": {"fight": 0.40, "talk": 0.55},
	"book": {"fight": 0.55, "talk": 0.45},
	"rent": {"fight": 0.35, "talk": 0.55},
}

## The card's own title (`consequence.gd`'s `KIND_CONFRONTATION` arm reads
## `loop.sheet_title`, falling back to a generic line no room should ever
## actually show) plus the stakes-strip chrome every loop-driven screen
## reads unconditionally -- the same fields Boost's own escalation room
## populates for the identical "nothing to bank" reason (D-22 / this room's
## own header): there is no take in dispute here, only a debt closing one
## way or another, so BANKED stays honestly $0 and ROUNDS LEFT is the
## countdown that actually means something.
func _sheet_title(family: String) -> String:
	match family:
		"dre": return "THE COLLECTION"
		"book": return "THE NOTE COMES DUE"
		_: return "THE LAST WARNING"

func _open_enforcement(family: String, visit: Dictionary) -> void:
	var engine: Object = _engine()
	var base: Dictionary = ROOM_BASE.get(family, {"fight": 0.45, "talk": 0.50})
	var loop: Dictionary = {
		"round": 1,
		"family": family,
		"loan_id": int(visit.get("loan_id", -1)),
		"log": [],
		"sheet_title": _sheet_title(family),
		"stage": 0,
		"stage_count": ROOM_ROUND_CAP,
		"left_label": "ROUNDS LEFT",
		"left": ROOM_ROUND_CAP - 1,
		"banked": 0,
	}
	LOOP.append_log(loop, _room_open_line(family))
	gs.log_activity(_room_open_line(family), RED)
	var shown: Dictionary = {
		"fight": clampf(float(base["fight"]) + ROOM_ROUND_PENALTY, 0.10, 0.95),
		"talk": clampf(float(base["talk"]) + ROOM_ROUND_PENALTY, 0.10, 0.95),
	}
	# `present_round` writes `decision.loop`/`allowed_choices`/etc. into
	# whatever chain dict it is handed; building that decision block on a
	# throwaway stub and lifting it back out is simpler than opening the
	# real chain first and mutating it after.
	var stub: Dictionary = _chain_stub()
	LOOP.present_round(stub, loop, ["fight", "talk", "yield"], ["yield"], shown)
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": gs.current_district_id,
		"return_route": "HOME",
		"source": _visit_source(family, visit),
		"decision": stub["decision"],
	})

func _room_open_line(family: String) -> String:
	match family:
		"dre":
			return "Dre doesn't send a message this time. He sends people."
		"book":
			return "The note is not going to collect itself. Not today."
		_:
			return "Yalonda's cousin is at the door, and he is not here to talk about the weather."

func _visit_source(family: String, visit: Dictionary) -> Dictionary:
	match family:
		"dre":
			return {"family": "dre", "kind": "dre_enforcement", "action_id": "doorstep",
				"target_name": "Dre's people"}
		"book":
			var loan: Dictionary = gm.system("shark").loan_by_id(int(visit["loan_id"]))
			var borrower: Dictionary = gs.borrower_by_id(str(loan.get("borrower_id", "")))
			return {"family": "book", "kind": "book_enforcement", "action_id": "doorstep",
				"target_id": str(borrower.get("id", "")),
				"target_name": str(borrower.get("name", "")), "loan_id": int(visit["loan_id"])}
		_:
			return {"family": "rent", "kind": "rent_enforcement", "action_id": "doorstep",
				"target_name": "Yalonda's cousin"}

## A throwaway dict shaped just enough for `ConfrontationLoop.present_round`
## to write `decision.loop`/`decision.allowed_choices` into -- see
## `_open_enforcement`'s own comment for why.
func _chain_stub() -> Dictionary:
	return {"decision": {}}

func _room_round(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = _engine()
	var decision: Dictionary = chain.get("decision", {})
	var source: Dictionary = chain.get("source", {})
	var family := str(source.get("family", ""))
	var loop: Dictionary = LOOP.loop_of(chain)

	if choice_id == "yield":
		return _room_exit(chain, loop, family, "yield")

	var round_num: int = int(loop.get("round", 1))
	var base: Dictionary = ROOM_BASE.get(family, {"fight": 0.45, "talk": 0.50})
	var shape := "confrontation" if choice_id == "fight" else "negotiation"
	var attribute := "combat" if choice_id == "fight" else "charisma"
	var chance: float = clampf(float(base.get(choice_id, 0.45))
		+ ROOM_ROUND_PENALTY * float(round_num), 0.10, 0.95)
	var attributes: Object = gm.system("attributes") if gm != null else null
	var raw: int = int(attributes.effective(attribute)) if attributes != null else 1
	var resolver: Object = gm.system("outcome_resolver")
	# Round leads -- the seeded-key audit's own rule (varying components
	# first, never a trailing counter): two rounds of the same chain would
	# otherwise differ only in the last character of the key.
	var key := "%d:%s:%s:room" % [round_num, str(chain.get("cause_id", "")), choice_id]
	var tier := str((resolver.resolve_action(shape, chance, raw, gs.run_seed, key)
		as Dictionary)["tier"])

	if tier in ["clean", "failure", "catastrophic"]:
		LOOP.append_log(loop, _room_round_line(choice_id, tier, round_num))
		return _room_exit(chain, loop, family, "%s_%s" % [choice_id, tier])

	# MESSY: keeps going, capped the same way the shakedown room's own
	# round cap works -- a doorstep confrontation that has gone this long
	# ends on the cap rather than looping forever.
	LOOP.append_log(loop, _room_round_line(choice_id, tier, round_num))
	if round_num >= ROOM_ROUND_CAP:
		return _room_exit(chain, loop, family, "%s_messy" % choice_id)
	loop["round"] = round_num + 1
	loop["stage"] = round_num
	loop["left"] = ROOM_ROUND_CAP - (round_num + 1)
	var next_shown: Dictionary = {
		"fight": clampf(float(base["fight"]) + ROOM_ROUND_PENALTY * float(round_num + 1), 0.10, 0.95),
		"talk": clampf(float(base["talk"]) + ROOM_ROUND_PENALTY * float(round_num + 1), 0.10, 0.95),
	}
	LOOP.present_round(chain, loop, ["fight", "talk", "yield"], ["yield"], next_shown)
	gs.active_consequence = chain
	return {"ok": true, "tier": "continued"}

func _room_round_line(choice_id: String, tier: String, round_num: int) -> String:
	if tier == "clean":
		match choice_id:
			"fight": return "Round %d: they back off. This is over." % round_num
			_: return "Round %d: they take the deal." % round_num
	if tier == "messy":
		return "Round %d: nobody backs off yet." % round_num
	return "Round %d: it does not go your way." % round_num

## The room's exit, on every road -- health through the crew's own absorber,
## the debt itself closed one of three ways so the identical visit cannot
## re-open tomorrow. Never sets `game_over` directly (DOOR-D1: "never
## scripted death") -- the worst road only ever costs health and the debt;
## the run's own existing end conditions are the only thing that can end it.
func _room_exit(chain: Dictionary, loop: Dictionary, family: String, road: String) -> Dictionary:
	var engine: Object = _engine()
	var decision: Dictionary = chain.get("decision", {})
	var hurt := 0
	var mode := "forgiven"
	var line := ""
	match road:
		"yield":
			hurt = 0
			# Book's own fiction points the other way from Dre/rent's: there
			# is no "player pays" road for a note the PLAYER is owed on, so
			# YIELD there means walking away from collecting it at all --
			# the note's own existing "forgive", not "enforce". Every other
			# family's YIELD is "pay whatever is on hand and be done."
			mode = "forgiven" if family == "book" else "paid"
			line = "You let the note go. It is not worth what collecting it costs." \
				if family == "book" \
				else "You give them everything you have on you. That settles it, for now."
		"fight_clean":
			hurt = 0
			mode = "forgiven"
			line = "You make it not worth their time. They leave empty-handed."
		"talk_clean":
			hurt = 0
			mode = "paid"
			line = "You talk it down to a number you can actually cover."
		"fight_messy", "talk_messy":
			hurt = 4
			mode = "paid" if road == "talk_messy" else "forgiven"
			line = "It takes longer than it should, but it ends."
		"fight_failure", "talk_failure":
			hurt = 12
			mode = "forgiven"
			line = "It does not go your way. They leave anyway -- there is nothing left to take."
		_:
			hurt = 20
			mode = "forgiven"
			line = "It goes badly, all the way through."
	if hurt > 0:
		var crew: Object = _crew()
		if crew != null:
			hurt = int(crew.absorbed_damage(hurt))
		gs.health = clampi(int(gs.health) - hurt, 0, int(gs.health_max))
	match family:
		"dre":
			_close_dre_debt(mode)
		"book":
			_close_book_loan(int(chain.get("source", {}).get("loan_id", -1)), mode)
		_:
			_close_rent_arrears(mode)
	gs.log_activity(line, AMBER if hurt > 0 else GREEN)
	decision["resolved_tier"] = road
	decision["result"] = {"resolution": road, "health": -hurt, "family": family}
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": road}

# --- closing each family's debt out -------------------------------------------

func _close_dre_debt(mode: String) -> void:
	if mode == "paid":
		var lender: Object = gm.system("dre") if gm != null else null
		if lender != null and bool(lender.handle("dre_repay", {}).get("ok", false)):
			return
		# `dre_repay` refuses outright when the account cannot be covered in
		# full (`repay_blocker()`'s own gate) -- correct for the ordinary
		# menu, wrong for a room whose whole point is that this ends today.
		# Take whatever is on hand instead of leaving the account exactly as
		# overdue as it already was, which would just re-open the identical
		# visit tomorrow.
		var wallet: Object = _wallet()
		if wallet != null:
			var take: int = mini(int(gs.debt), int(gs.cash))
			if take > 0:
				wallet.spend(take, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "doorstep_dre_settle"})
	gs.dre_account = {"status": "clear"}

func _close_book_loan(loan_id: int, mode: String) -> void:
	var shark: Object = gm.system("shark") if gm != null else null
	if shark == null:
		return
	shark._resolve_defaulted(loan_id, "enforce" if mode == "paid" else "forgive")

func _close_rent_arrears(mode: String) -> void:
	if mode == "paid":
		var owed: int = int(gs.rent_missed) * int(gs.WEEKLY_RENT)
		var wallet: Object = _wallet()
		# Take whatever is on hand toward the arrears rather than requiring
		# every dollar before anything moves -- the collection stage's own
		# "pay" choice already blocks itself below full affordability
		# (`choice_blocked`), but the room's YIELD is meant to be unblockable,
		# and a player short of the total should not walk away with the
		# arrears forgiven for free just because they could not cover it all.
		if wallet != null:
			var take: int = mini(owed, int(gs.cash))
			if take > 0:
				wallet.spend(take, wallet.HIGH_VISIBILITY_CLEAN_FIRST, {"source_id": "doorstep_rent"})
	gs.rent_missed = 0
	gs.household_warnings = 0

# --- adapter contract ----------------------------------------------------------

func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var kind := str((chain.get("source", {}) as Dictionary).get("kind", ""))
	match kind:
		"book_collection":
			return _resolve_book_collection(chain, choice_id)
		"rent_collection":
			return _resolve_rent_collection(chain, choice_id)
		_:
			return _room_round(chain, choice_id)

func _resolve_book_collection(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = _engine()
	var decision: Dictionary = chain.get("decision", {})
	var source: Dictionary = chain.get("source", {})
	var loan_id: int = int(source.get("loan_id", -1))
	var shark: Object = gm.system("shark")
	var result: Dictionary = shark._resolve_defaulted(loan_id, choice_id)
	decision["resolved_tier"] = choice_id
	decision["result"] = {"resolution": choice_id, "ok": bool(result.get("ok", false))}
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": choice_id}

func _resolve_rent_collection(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = _engine()
	var decision: Dictionary = chain.get("decision", {})
	if choice_id == "pay":
		_close_rent_arrears("paid")
		gs.log_activity("Back rent paid in full. Yalonda says nothing, which is something.", GREEN)
	else:
		gs.log_activity("You let it sit. It will not sit much longer.", AMBER)
	decision["resolved_tier"] = choice_id
	decision["result"] = {"resolution": choice_id}
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": choice_id}

func choice_label(choice_id: String) -> String:
	match choice_id:
		"fight": return "FIGHT"
		"talk": return "TALK"
		"yield": return "YIELD"
		"enforce": return "ENFORCE"
		"extend": return "EXTEND"
		"forgive": return "FORGIVE"
		"pay": return "PAY IT OFF"
		"ignore": return "NOT TODAY"
		_: return choice_id.capitalize()

func choice_copy(choice_id: String) -> String:
	match choice_id:
		"fight": return "Make it not worth the trouble."
		"talk": return "Find a number everybody can live with."
		"yield": return "Give up what's on you and be done with it."
		"enforce": return "Collect the hard way. Heat, no roll."
		"extend": return "Two more days. The note stays open."
		"forgive": return "Let it go. Word travels."
		"pay": return "Clear every week you owe, right now."
		"ignore": return "Walk past it. It will still be here tomorrow."
		_: return ""

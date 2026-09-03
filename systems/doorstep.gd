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
## SQ-D9's authored table. The rules for a crew call live in one place and this
## reads them; it does not restate them.
const SCRIPTS := preload("res://data/confrontation_scripts.gd")

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
	var offered: Array = ["fight", "talk", "yield"] + _crew_calls(loop)
	LOOP.present_round(stub, loop, offered, ["yield"] + _crew_calls(loop), shown)
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

	# SQ-D9, answered before the room's own verbs: a call ends the room
	# wherever it was placed.
	if SCRIPTS.CREW_CALLS.has(choice_id):
		return _resolve_crew_call(chain, choice_id)

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
	# BB-D4 (0.7.0): the round ends in a result the player reads; CONTINUE
	# presents the next one through `present_next_round`.
	return LOOP.present_interim(engine, gs, chain, loop, choice_id, tier,
		"escalate", {}, round_num + 1)

## BB-D4: the next round of the enforcement room, from the loop's own note.
func present_next_round(chain: Dictionary) -> Dictionary:
	var loop: Dictionary = LOOP.loop_of(chain)
	var pending: Variant = LOOP.take_pending(loop)
	if loop.is_empty() or pending == null:
		return {"ok": false, "reason": "Nothing to move on to."}
	var family := str((chain.get("source", {}) as Dictionary).get("family", ""))
	var base: Dictionary = ROOM_BASE.get(family, {"fight": 0.45, "talk": 0.50})
	var next_round: int = int(pending)
	loop["round"] = next_round
	loop["stage"] = next_round - 1
	loop["left"] = ROOM_ROUND_CAP - next_round
	var next_shown: Dictionary = {
		"fight": clampf(float(base["fight"]) + ROOM_ROUND_PENALTY * float(next_round), 0.10, 0.95),
		"talk": clampf(float(base["talk"]) + ROOM_ROUND_PENALTY * float(next_round), 0.10, 0.95),
	}
	var calls: Array = _crew_calls(loop)
	LOOP.present_round(chain, loop, ["fight", "talk", "yield"] + calls,
		["yield"] + calls, next_shown)
	gs.active_consequence = chain
	return {"ok": true, "tier": "continued"}

# --- SQ-D9: crew calls in the enforcement room -------------------------------
#
# The ruling names this room specifically, alongside the general street: three
# people at your door over a debt is exactly the situation where somebody
# standing next to you changes the arithmetic. The rules -- who, what
# resolution, what it costs -- are `CREW_CALLS`' in
# `data/confrontation_scripts.gd` and are not re-stated here; the availability
# question is the same one `systems/wander.gd::_crew_call_available` asks, and
# is asked through that adapter rather than reimplemented, so the two rooms
# cannot drift on what "he is around" means.
#
# Once per room and no verb burned, same as everywhere else.

func _crew_calls(loop: Dictionary) -> Array:
	if bool(loop.get("crew_called", false)):
		return []
	var wander: Object = gm.system("wander") if gm != null else null
	if wander == null:
		return []
	var out: Array = []
	for call_id in SCRIPTS.CREW_CALLS.keys():
		if wander._crew_call_available(str(call_id)):
			out.append(str(call_id))
	return out

## A call, resolved against the room's own exit table. Tone ends it the way a
## clean FIGHT does (they leave empty-handed); Deshawn ends it the way YIELD
## does (the stakes are settled, nobody is hurt) -- which is what
## `CREW_CALLS`' authored `resolution` says in this room's vocabulary. The
## debt still closes: a room that ended is a room that ended, and leaving the
## account exactly as overdue as it was would just re-open the identical
## visit tomorrow.
func _resolve_crew_call(chain: Dictionary, call_id: String) -> Dictionary:
	var call: Dictionary = SCRIPTS.CREW_CALLS[call_id]
	var loop: Dictionary = LOOP.loop_of(chain)
	var crew_id := str(call.get("crew_id", ""))

	var record: Dictionary = gs.crew_record(crew_id)
	record["loyalty"] = maxi(0, int(record.get("loyalty", 0))
		- int(call.get("loyalty_cost", 1)))
	gs.crew_records[crew_id] = record
	if float(call.get("heat", 0.0)) > 0.0:
		LOOP.apply_heat(gs, gm, float(call["heat"]), "doorstep_enforcement")

	loop["crew_called"] = true
	var road := "fight_clean" if str(call.get("resolution", "")) == SCRIPTS.RESOLUTION_WON \
		else "yield"
	LOOP.append_log(loop, "You made a call. It ended there.")
	return _room_exit(chain, loop, str((chain.get("source", {}) as Dictionary)
		.get("family", "")), road)

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

## What the visit came to, in its own words -- BB-D1 (0.7.0). Every doorstep
## chain rides `KIND_CONFRONTATION`, which until this seam meant every one of
## them ended on the STICKUP room's result copy: Dre's people leaving your
## door read "The room closed before the door did. What was banked stayed
## behind." Keyed by the chain's own `kind` for the two forced decisions and
## by family + road for the enforcement room, which is exactly how
## `_room_exit` already names its outcomes.
const RESULT_COPY := {
	"book_collection": {
		"enforce": ["YOU COLLECT", "The note closes the hard way. Word travels about how."],
		"extend": ["TWO MORE DAYS", "The note stays open. So does the question of whether he was ever going to pay."],
		"forgive": ["YOU LET IT GO", "Somebody owed you and now nobody does. The book remembers who forgave what."],
	},
	"rent_collection": {
		"pay": ["BACK RENT, PAID", "Every week you owed, in her hand. Yalonda says nothing, which is something."],
		"ignore": ["NOT TODAY", "You let it sit. It will not sit much longer, and next time it does not knock."],
	},
	"dre": {
		"escalate": ["NOBODY BACKS OFF", "They did not come to be talked out of it in one round, and you did not fold in one either. It goes again."],
		"yield": ["YOU PAY WHAT YOU HAVE", "Everything on you goes into a hand that does not count it. That settles it for now, and for now is the word Dre uses."],
		"fight_clean": ["THEY LEAVE EMPTY-HANDED", "You make it not worth their time. Dre will hear that too, and he will hear it as a number."],
		"talk_clean": ["A NUMBER YOU CAN COVER", "You talk it down to something real and pay it. Dre gets less than he asked for and more than he expected."],
		"fight_messy": ["IT ENDS, EVENTUALLY", "Longer than it should have taken, and it cost some skin. The account closes anyway."],
		"talk_messy": ["IT ENDS, EVENTUALLY", "Longer than it should have taken, and it cost some skin. The account closes anyway."],
		"fight_failure": ["IT DOES NOT GO YOUR WAY", "They leave anyway. There is nothing left on you to take, and Dre knows exactly how much that is."],
		"talk_failure": ["IT DOES NOT GO YOUR WAY", "They leave anyway. There is nothing left on you to take, and Dre knows exactly how much that is."],
		"fight_catastrophic": ["DRE'S PEOPLE MAKE THEIR POINT", "They did not come to collect. They came so that next time you would pay before they had to."],
		"talk_catastrophic": ["DRE'S PEOPLE MAKE THEIR POINT", "They did not come to collect. They came so that next time you would pay before they had to."],
	},
	"book": {
		"escalate": ["HE IS STILL TALKING", "He has not paid and he has not left. Whatever he is going to do, he has not decided it yet."],
		"yield": ["YOU LET THE NOTE GO", "It is not worth what collecting it costs. Everybody on the book heard you say that."],
		"fight_clean": ["YOU COLLECT", "He pays because the alternative was standing in front of you longer."],
		"talk_clean": ["HE FINDS THE MONEY", "It turns out he had it. They usually do."],
		"fight_messy": ["IT ENDS, EVENTUALLY", "It took longer and cost more than a note this size should. The book closes it either way."],
		"talk_messy": ["IT ENDS, EVENTUALLY", "It took longer and cost more than a note this size should. The book closes it either way."],
		"fight_failure": ["HE HAS NOTHING", "You leave with a bruise and the note. The note is worth less than it was."],
		"talk_failure": ["HE HAS NOTHING", "You leave with a bruise and the note. The note is worth less than it was."],
		"fight_catastrophic": ["IT COMES APART", "Collecting a debt became a fight, and the fight became a story. You lost both."],
		"talk_catastrophic": ["IT COMES APART", "Collecting a debt became a fight, and the fight became a story. You lost both."],
	},
	"rent": {
		"escalate": ["HE IS STILL ON THE PORCH", "He did not get what he came for and he is not leaving without something. It goes again."],
		"yield": ["YOU PAY WHAT YOU HAVE", "Everything on you goes toward the back rent. Yalonda's cousin counts it on the porch and does not say whether it is enough."],
		"fight_clean": ["HE GOES BACK DOWN THE STAIRS", "You make it not worth his time. Yalonda will not send him twice, and she will not forget she had to send him once."],
		"talk_clean": ["A NUMBER YALONDA CAN LIVE WITH", "You talk him down to what you can actually cover and hand it over. The porch goes quiet."],
		"fight_messy": ["IT ENDS ON THE PORCH", "Louder than the street needed, and it cost some skin. The rent gets settled anyway."],
		"talk_messy": ["IT ENDS ON THE PORCH", "Louder than the street needed, and it cost some skin. The rent gets settled anyway."],
		"fight_failure": ["HE LEAVES ANYWAY", "There was nothing left to take. He tells Yalonda that, and she believes it less than he does."],
		"talk_failure": ["HE LEAVES ANYWAY", "There was nothing left to take. He tells Yalonda that, and she believes it less than he does."],
		"fight_catastrophic": ["THE LAST WARNING, DELIVERED", "He did not come to talk about the rent. He came so you would understand what the next visit is."],
		"talk_catastrophic": ["THE LAST WARNING, DELIVERED", "He did not come to talk about the rent. He came so you would understand what the next visit is."],
	},
}

## The table's key for the active chain: the forced decisions by their own
## `kind`, the enforcement room by the family that sent it.
func result_copy(choice_id: String, effects: Dictionary) -> Array:
	var source: Dictionary = gs.active_consequence.get("source", {})
	var kind := str(source.get("kind", ""))
	var road := "escalate" if bool(effects.get("interim", false)) \
		else str(effects.get("resolution", choice_id))
	var table: Dictionary = {}
	if RESULT_COPY.has(kind):
		table = RESULT_COPY[kind]
	else:
		table = RESULT_COPY.get(str(effects.get("family", source.get("family", ""))), {})
	return table.get(road, [])

func result_headline(choice_id: String, _tier: String, effects: Dictionary) -> String:
	var row: Array = result_copy(choice_id, effects)
	return str(row[0]) if row.size() == 2 else ""

func result_body(choice_id: String, _tier: String, effects: Dictionary) -> String:
	var row: Array = result_copy(choice_id, effects)
	return str(row[1]) if row.size() == 2 else ""

func choice_label(choice_id: String) -> String:
	match choice_id:
		"fight": return "FIGHT"
		"talk": return "TALK"
		"yield": return "SURRENDER"
		"call_tone": return "CALL TONE"
		"let_deshawn_talk": return "LET DESHAWN TALK"
		"enforce": return "ENFORCE"
		"extend": return "EXTEND"
		"forgive": return "FORGIVE"
		"pay": return "PAY"
		"ignore": return "NOT TODAY"
		_: return choice_id.capitalize()

func choice_copy(choice_id: String) -> String:
	match choice_id:
		"fight": return "Make it not worth the trouble."
		"talk": return "Find a number everybody can live with."
		"yield": return "Give up what's on you and be done with it."
		"call_tone": return "He ends it by standing there. Costs a favor."
		"let_deshawn_talk": return "His voice, not yours. Everybody walks."
		"enforce": return "Collect the hard way. Heat, no roll."
		"extend": return "Two more days. The note stays open."
		"forgive": return "Let it go. Word travels."
		"pay": return "Clear every week you owe, right now."
		"ignore": return "Walk past it. It will still be here tomorrow."
		_: return ""

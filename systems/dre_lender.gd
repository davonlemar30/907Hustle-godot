extends RefCounted
## Dre Lender — Dre Lending & Loan-Shark Progression, PR A + PR B (Structured
## Debt to Dre; Introduction and earned access). Design doc:
## `docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md`. Rulings:
## `docs/DECISIONS.md`, D-7 (DRE-D1 through DRE-D12).
##
## Owns the ONE loan a player can carry (`gs.dre_account`, MVP: no
## concurrent Dre debts — design doc §10.1), the state machine that walks it
## clear → active → due → (extended →) overdue → suspended → clear, the
## lifetime counters (`gs.dre_account_history`) behind every later credit
## and access decision, and — as of PR B — the one-time introduction that is
## the only door onto any of it. Tiers past Borrower, contracts, and the
## collection encounter are later PRs.
##
## ## PR A shipped the mechanism before the door; PR B is the door
##
## `dre_borrow` refuses a player who is not `dre_introduced`. Through PR A
## that flag could only be set by a test or a live `game_eval` — no path in
## the actual game ever set it, on purpose (the build prompt is explicit: "a
## debug/temporary `dre_introduced` default of `true` is FORBIDDEN"). PR B
## is the door: `push_intro_offer()` is the day-start check that decides
## whether Juan mentions Dre at all (DRE-D1), and `dre_seek_out` is the one
## slot-costing action that turns a mention into `dre_introduced = true`
## (DRE-D2). Nothing about the loan machinery itself changed to make this
## true — the whole borrow/repay/extend/default loop was already proven
## correct in PR A; PR B only had to open a door onto a room that already
## worked.
##
## ## The overdue → suspended edge is a real event, not a timer
##
## The design doc's own state diagram fires `Overdue --> Suspended` on
## "Collection/default resolves" — an EVENT: once `OVERDUE_RESPONSE_DELAY_
## DAYS` has passed with nothing paid, `dre_collector.open_player_default_
## encounter()` opens a chain through the same `KIND_CONFRONTATION` chassis
## DRE-ARC-03 uses (two deterministic choices, PAY NOW or accept the
## suspension, no roll). `"overdue"` status does not itself decay, so
## nothing is lost by waiting for it.
##
## As of 0.5.0 PR D (DOOR-D2), the trigger for that event moved OUT of this
## file's own `settle_night` and into `systems/doorstep.gd`'s day-start
## hook. "One visit per day-start, worst debt first" needs Dre, a defaulted
## Book note, and rent arrears compared against EACH OTHER before anything
## opens — a check still living inside `dre_lender.gd`'s own settlement
## could not see the other two, and would race whichever of THEM tried to
## open first. `doorstep.gd`'s own `_dre_visit()` reads exactly the same
## `dre_account.status`/`due_day`/`OVERDUE_RESPONSE_DELAY_DAYS` this file
## already owns; nothing about the state machine itself changed, only who
## asks whether tonight is the night to act on it.
##
## ## Numbers are provisional
##
## $1,000 principal / $1,200 total due / 5-day term, +2 days / +$100 per
## extension: canon (the ClickUp "Dre Smooth" character page), not measured.
## PR E's economy-profile pass is the authority on whether these numbers
## survive; nothing here should be read as balance-final.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

## The one offer this build can present — see the header on provisional
## numbers. $1,200 total due on a $1,000 principal is a flat $200 (20%)
## over 5 days; the Trusted Customer band (design doc §7, tier 2+) reuses
## this same 20%/5-day pricing at a higher principal and is PR B's to wire.
const FIRST_LOAN_PRINCIPAL := 1000
const FIRST_LOAN_INTEREST := 200
const FIRST_LOAN_TERM_DAYS := 5

## DRE-D2 / the build prompt: the extension itself is a phone action and
## costs no slot — only the first meeting does, and that meeting is PR B's.
const EXTENSION_TERM_DAYS := 2
const EXTENSION_FEE := 100

## The window after "overdue" before Dre's response opens — see the header.
## No longer a substitute for the real event; it IS the authored delay
## before it.
const OVERDUE_RESPONSE_DELAY_DAYS := 2

var gs: Node
var gm: Node
var time_system: RefCounted

func setup(game_state: Node, manager: Node, time_sys: RefCounted) -> void:
	gs = game_state
	gm = manager
	time_system = time_sys

func can_handle(action: String) -> bool:
	return action in ["dre_borrow", "dre_repay", "dre_request_extension", "dre_seek_out",
		"dre_do_penance"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"dre_borrow":
			return _borrow()
		"dre_repay":
			return _repay()
		"dre_request_extension":
			return _request_extension()
		"dre_do_penance":
			return _do_penance()
		"dre_seek_out":
			return _seek_out()
	return {"ok": false, "reason": "Unknown Dre action."}

func _wallet() -> Object:
	return gm.system("wallet")

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func _phone() -> Object:
	return gm.system("phone") if gm != null else null

# --- introduction (DRE-D1, PR B) ----------------------------------------------

## Called once from the `"dre_intro"` `DAY_START_ORDER` step, after `"tips"` —
## a day-start signal, same shape as Word of Mouth's, so it reads the fully
## settled day rather than a half-finished one.
##
## DRE-D1's trigger, verbatim: `day >= 2` AND no prior mention AND (cash at
## or under $80, OR rent is due within a day and cash is under the weekly
## rent). The rent-pressure clause is deliberate: canon's flat cash check
## alone can miss a player who is doing fine on cash but about to miss rent,
## and Dre is meant to be a second honest road in, not just a poverty flag.
func push_intro_offer(today: int) -> void:
	if gs.dre_intro_offered:
		return
	if today < 2:
		return
	var broke: bool = gs.cash <= 80
	var rent_pressure: bool = (gs.rent_due_day - today <= 1) and gs.cash < gs.WEEKLY_RENT
	if not (broke or rent_pressure):
		return
	gs.dre_intro_offered = true
	var phone: Object = _phone()
	if phone != null:
		phone.push_text("Juan",
			"if you're short, talk to Dre. he fronts money to people who keep " \
			+ "their word. ask around Spenard. you'll find him.", "juan_dre_mention")

## "" if the player can go meet Dre right now, the reason otherwise.
func seek_out_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	if not gs.dre_intro_offered:
		return "Nobody's mentioned him to you."
	if gs.dre_introduced:
		return "You already know him."
	return ""

## The one-time meeting, DRE-D2: costs the slot the loan offer itself never
## will again. Writes nothing about the account — `dre_introduced` and the
## tier latch are the whole result; the offer is just what tier 1 makes
## visible on the contact surface, not a separate write here.
func _seek_out() -> Dictionary:
	var blocked := seek_out_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	gs.dre_introduced = true
	gs.dre_access_tier = maxi(int(gs.dre_access_tier), 1)
	gs.log_activity("You find Dre outside the Mini-Mart. He already knew you'd come.", AMBER)
	time_system.handle("advance_time", {})
	return {"ok": true}

# --- penance (restitution follow-up, PR D) -----------------------------------

## "" if the small penance contract is there to do, the reason otherwise.
func penance_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	if not gs.dre_pending_penance:
		return "There's nothing to make right."
	return ""

## Symbolic, not mechanical: the account already cleared on payment (D-4/
## D-7). This is the conversation that closes the relationship side of it,
## costs no slot, and completes `dre_penance` (data/dre_contracts.gd) through
## the ordinary action_result path.
func _do_penance() -> Dictionary:
	var blocked := penance_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	gs.dre_pending_penance = false
	gs.log_activity("You give Dre your word. He doesn't forgive you; he decides to keep doing business.", AMBER)
	return {"ok": true}

# --- borrow ------------------------------------------------------------------

## "" if a first loan can be accepted right now, the reason otherwise. Dre's
## own voice for the one line design doc §14.3 recommends showing rather
## than a raw refusal: "Clear what you owe before asking again."
func borrow_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	if not gs.dre_introduced:
		return "Dre doesn't know you yet."
	if str(gs.dre_account.get("status", "clear")) != "clear":
		return "Clear what you owe before asking again."
	return ""

func _borrow() -> Dictionary:
	var blocked := borrow_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	_wallet().credit(FIRST_LOAN_PRINCIPAL, _wallet().DIRTY, {"source_id": "dre_borrow"})
	gs.dre_account = {
		"status": "active", "principal": FIRST_LOAN_PRINCIPAL,
		"interest": FIRST_LOAN_INTEREST, "fee": 0,
		"opened_day": gs.day, "due_day": gs.day + FIRST_LOAN_TERM_DAYS,
		"term_days": FIRST_LOAN_TERM_DAYS, "extension_used": false,
		"offer_id": "first_loan",
	}
	var history: Dictionary = gs.dre_account_history
	history["loans_taken"] = int(history.get("loans_taken", 0)) + 1
	history["total_principal_borrowed"] = int(history.get("total_principal_borrowed", 0)) \
		+ FIRST_LOAN_PRINCIPAL
	gs.dre_account_history = history
	var exposure: Node = _exposure()
	if exposure != null:
		exposure.record_observation("dre", {"type": "financial", "event": "accepted_terms",
			"source": "direct"})
	gs.log_activity("Dre puts $%d in your hand. $%d comes back by Day %d; your word rides with it." % [
		FIRST_LOAN_PRINCIPAL, FIRST_LOAN_PRINCIPAL + FIRST_LOAN_INTEREST,
		gs.day + FIRST_LOAN_TERM_DAYS], AMBER)
	return {"ok": true, "due_day": gs.day + FIRST_LOAN_TERM_DAYS}

# --- repay -------------------------------------------------------------------

func repay_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	if str(gs.dre_account.get("status", "clear")) == "clear":
		return "You don't owe Dre anything."
	var total: int = gs.debt
	if gs.cash < total:
		return "You don't have $%d." % total
	return ""

func _repay() -> Dictionary:
	var blocked := repay_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var account: Dictionary = gs.dre_account
	var due_day: int = int(account.get("due_day", gs.day))
	var interest: int = int(account.get("interest", 0))
	var fee: int = int(account.get("fee", 0))
	var total: int = int(account.get("principal", 0)) + interest + fee
	var was_suspended: bool = str(account.get("status", "")) == "suspended"
	_wallet().spend(total, _wallet().ROUTINE_DIRTY_FIRST, {"source_id": "dre_repay"})

	# D-4/D-7 still rules full repayment alone clears the account (unchanged
	# by PR D) — but a suspension is a bigger break than a late payment, and
	# the relationship repair for it is a small authored follow-up, not
	# silent. See `dre_pending_penance`'s own header in game_state.gd and
	# `dre_penance` in data/dre_contracts.gd.
	if was_suspended:
		gs.dre_pending_penance = true

	var history: Dictionary = gs.dre_account_history
	history["total_interest_paid"] = int(history.get("total_interest_paid", 0)) + interest + fee
	var exposure: Node = _exposure()
	var late: bool = gs.day > due_day
	var early: bool = gs.day < due_day
	if late:
		history["repaid_late"] = int(history.get("repaid_late", 0)) + 1
		if exposure != null:
			exposure.record_observation("dre", {"type": "financial",
				"event": "debt_repaid_late", "source": "direct"})
		gs.log_activity("You pay Dre in full. The money is square; the lateness stays on your name.", AMBER)
	else:
		history["repaid_on_time"] = int(history.get("repaid_on_time", 0)) + 1
		if exposure != null:
			exposure.record_observation("dre", {"type": "financial",
				"event": "debt_repaid_early" if early else "debt_repaid",
				"source": "direct"})
		gs.log_activity("You put Dre's money back in his hand%s." \
			% (" before he has to ask" if early else " on time"), GREEN)
	gs.dre_account_history = history
	gs.dre_account = {
		"status": "clear", "principal": 0, "interest": 0, "fee": 0,
		"opened_day": -1, "due_day": -1, "term_days": 0,
		"extension_used": false, "offer_id": "",
	}
	return {"ok": true, "paid": total, "late": late}

# --- extension -----------------------------------------------------------

func extension_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	var account: Dictionary = gs.dre_account
	var status := str(account.get("status", "clear"))
	if status == "clear":
		return "There's nothing to extend."
	if bool(account.get("extension_used", false)):
		return "You already got the one extension."
	if not status in ["active", "due"]:
		return "Too late for that now."
	return ""

func _request_extension() -> Dictionary:
	var blocked := extension_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var account: Dictionary = gs.dre_account
	account["due_day"] = int(account.get("due_day", gs.day)) + EXTENSION_TERM_DAYS
	account["fee"] = int(account.get("fee", 0)) + EXTENSION_FEE
	account["extension_used"] = true
	account["status"] = "extended"
	gs.dre_account = account
	var history: Dictionary = gs.dre_account_history
	history["extensions"] = int(history.get("extensions", 0)) + 1
	gs.dre_account_history = history
	var exposure: Node = _exposure()
	if exposure != null:
		exposure.record_observation("dre", {"type": "honesty",
			"event": "asked_before_due", "source": "direct"})
	gs.log_activity("Dre sells you two more days for $%d. Time costs more when it belongs to somebody else." \
		% EXTENSION_FEE, AMBER)
	return {"ok": true, "due_day": int(account["due_day"])}

# --- settlement ----------------------------------------------------------

## The account's own clock, driven by `DayLifecycle.SETTLE_ORDER` (DRE-D11:
## right after `shark`, before `jobs` — see that file's header for why).
## One transition per call, same discipline `shark.gd::settle_night` uses:
## a normal run crosses one day at a time, so a state machine that only
## ever needs to notice the day that just ended never needs to replay a
## history it can just walk forward.
func settle_night(ended_day: int) -> void:
	if gs.game_over:
		return
	var account: Dictionary = gs.dre_account
	var status := str(account.get("status", "clear"))
	var due_day: int = int(account.get("due_day", -1))
	var phone: Object = _phone()
	match status:
		"active", "extended":
			if ended_day + 2 == due_day and phone != null:
				phone.push_text("Dre", "Due tomorrow. I shouldn't have to ask twice.",
					"dre_due_tomorrow", {"kind": "dre_debt"})
			if ended_day + 1 >= due_day:
				account["status"] = "due"
				gs.dre_account = account
				if phone != null:
					phone.push_text("Dre", "Today's the day. Bring me what we agreed.",
						"dre_due_today", {"kind": "dre_debt"})
		"due":
			account["status"] = "overdue"
			gs.dre_account = account
			gs.log_activity("Dre's money didn't show. From here, the debt is about respect.", RED)
			if phone != null:
				phone.push_text("Dre",
					"You missed the day. Call me before I decide what that means.",
					"dre_missed", {"kind": "dre_debt"})
		"overdue":
			# Triggering moved to `systems/doorstep.gd` (0.5.0 PR D, DOOR-D2)
			# so Dre's own urgency can be weighed against a defaulted Book
			# note and rent arrears before anything opens. This branch is
			# intentionally empty now -- "overdue" is a status this state
			# machine still owns and still reads every night; only the
			# decision to act on it moved.
			pass

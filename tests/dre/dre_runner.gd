extends Node
## Dre Lending & Loan-Shark Progression, PR A's own suite (`tests/dre/`), same
## shape as `tests/tips/` and `tests/confrontation/`: seconds rather than the
## parity runner's ten minutes, on the shared `territory_asserts.gd` harness.
##
## Covers the build prompt's own PR A acceptance list: the full state-machine
## walk clear -> active -> due -> extended -> overdue -> suspended -> clear,
## save/load at every state, idempotent repay, wallet provenance (borrow is
## dirty, never earnings), the v19 -> v20 migration's three fixture shapes
## (legacy debt zero / positive / corrupt), and `dre`'s position in
## `DayLifecycle.SETTLE_ORDER`. Save-validation gets its own arms in
## `tests/save_validation/save_validation_runner.gd` alongside this suite,
## not duplicated here.

const ASSERTS := preload("res://tests/territory/territory_asserts.gd")

const MIN_CHECKS := 183

var a: RefCounted
var gs: Node
var gm: Node

func _ready() -> void:
	a = ASSERTS.new()
	gs = get_node("/root/GameState")
	gm = get_node("/root/GameManager")

	_test_full_state_machine_walk()
	_test_extension()
	_test_repay_variants()
	_test_idempotent_repay()
	_test_wallet_provenance()
	_test_save_load_at_every_state()
	_test_migration_fixtures()
	_test_lifecycle_ordering()
	_test_debt_getter_compatibility()
	_test_blockers()

	a.report("dre", get_tree(), MIN_CHECKS)

# --- setup -------------------------------------------------------------------

func _fresh() -> void:
	gs.street_name = "Dre"
	gs.reset_to_new_game()
	gs.day = 1
	gs.cash = 100

func _introduced() -> void:
	_fresh()
	gs.dre_introduced = true

func _fund(amount: int) -> void:
	gs.cash = amount
	gs.dirty_cash = amount
	gs.clean_cash = 0

func _dre() -> Object:
	return gm.system("dre")

func _cross_day() -> void:
	for slot in range(4):
		gm.dispatch("advance_time", {})

# --- 1. the full state-machine walk -------------------------------------------

func _test_full_state_machine_walk() -> void:
	_introduced()
	a.eq_str("a fresh account is clear", str(gs.dre_account.get("status", "")), "clear")
	a.eq_int("nobody owes anything on a clear account", gs.debt, 0)

	a.eq_bool("borrow succeeds once introduced", gm.dispatch("dre_borrow", {}), true)
	a.eq_str("borrowing opens an active account",
		str(gs.dre_account.get("status", "")), "active")
	a.eq_int("the account carries the authored principal",
		int(gs.dre_account.get("principal", -1)), 1000)
	a.eq_int("the account carries the authored interest",
		int(gs.dre_account.get("interest", -1)), 200)
	a.eq_int("debt reads the full total due", gs.debt, 1200)
	a.eq_int("cash carries the principal", gs.cash, 1100)

	var due_day: int = int(gs.dre_account["due_day"])
	a.eq_int("the due day is the authored 5-day term out", due_day, gs.day + 5)

	# Walk to the night before due. The LAST cross in this loop ends the day
	# two before due (ended_day + 2 == due_day), which is exactly when
	# "due tomorrow" fires -- so by the time the loop exits (gs.day ==
	# due_day - 1) the text is already sent and the account is still active.
	var inbox_before_loop: int = gs.phone_inbox.size()
	while gs.day < due_day - 1:
		_cross_day()
	a.eq_str("still active the night before due",
		str(gs.dre_account.get("status", "")), "active")
	a.check("a due-tomorrow text landed", gs.phone_inbox.size() > inbox_before_loop)

	# The due day itself: one more cross ends day (due_day - 1), which is
	# exactly the transition that opens the due day.
	_cross_day()
	a.eq_str("the due day flips the account to due",
		str(gs.dre_account.get("status", "")), "due")
	a.eq_int("due day carries the whole due day, debt_due_days reads zero",
		gs.debt_due_days, 0)

	# The due day ends unpaid -> overdue.
	_cross_day()
	a.eq_str("an unpaid due day becomes overdue",
		str(gs.dre_account.get("status", "")), "overdue")
	a.check("debt_due_days reads negative once overdue", gs.debt_due_days < 0)

	# The authored grace, then suspension.
	var dre: Object = _dre()
	var grace: int = int(dre.OVERDUE_GRACE_DAYS)
	for day_index in range(grace):
		a.eq_str("still overdue during the grace window (day %d of %d)"
				% [day_index + 1, grace],
			str(gs.dre_account.get("status", "")), "overdue")
		_cross_day()
	a.eq_str("the grace window's end suspends the account",
		str(gs.dre_account.get("status", "")), "suspended")
	a.eq_int("suspension keeps the debt outstanding, not forgiven", gs.debt, 1200)

	# Restitution: a suspended account can still be paid off in full.
	_fund(5000)
	a.eq_bool("a suspended account can still be repaid", gm.dispatch("dre_repay", {}), true)
	a.eq_str("repayment clears a suspended account",
		str(gs.dre_account.get("status", "")), "clear")
	a.eq_int("and the debt is gone", gs.debt, 0)

# --- 2. extension --------------------------------------------------------

func _test_extension() -> void:
	_introduced()
	gm.dispatch("dre_borrow", {})
	var due_before: int = int(gs.dre_account["due_day"])

	a.eq_bool("an extension can be requested while active",
		gm.dispatch("dre_request_extension", {}), true)
	a.eq_str("the account status reads extended",
		str(gs.dre_account.get("status", "")), "extended")
	a.eq_int("the due day moves out by the authored two days",
		int(gs.dre_account["due_day"]), due_before + 2)
	a.eq_int("the extension fee lands on fee, not interest",
		int(gs.dre_account["fee"]), 100)
	a.eq_int("interest is untouched by the extension",
		int(gs.dre_account["interest"]), 200)
	a.eq_bool("extension_used latches true", bool(gs.dre_account["extension_used"]), true)

	a.eq_bool("a second extension on the same loan is refused",
		gm.dispatch("dre_request_extension", {}), false)
	a.eq_int("one extension is recorded in the lifetime history",
		int(gs.dre_account_history["extensions"]), 1)

	# Once overdue, an extension is no longer on offer.
	_introduced()
	gm.dispatch("dre_borrow", {})
	while str(gs.dre_account.get("status", "")) != "overdue":
		_cross_day()
	a.eq_bool("an overdue account cannot be extended",
		gm.dispatch("dre_request_extension", {}), false)

# --- 3. repay variants, by exact day against the due day ----------------------

func _test_repay_variants() -> void:
	_introduced()
	gm.dispatch("dre_borrow", {})
	var due_day: int = int(gs.dre_account["due_day"])
	gs.day = due_day - 2
	_fund(5000)
	gm.dispatch("dre_repay", {})
	a.eq_int("an early repay counts as on time", int(gs.dre_account_history["repaid_on_time"]), 1)
	a.eq_int("an early repay does not count as late", int(gs.dre_account_history["repaid_late"]), 0)

	_introduced()
	gm.dispatch("dre_borrow", {})
	due_day = int(gs.dre_account["due_day"])
	gs.day = due_day
	_fund(5000)
	gm.dispatch("dre_repay", {})
	a.eq_int("repaying exactly on the due day counts as on time",
		int(gs.dre_account_history["repaid_on_time"]), 1)

	_introduced()
	gm.dispatch("dre_borrow", {})
	due_day = int(gs.dre_account["due_day"])
	gs.day = due_day + 3
	_fund(5000)
	gm.dispatch("dre_repay", {})
	a.eq_int("repaying after the due day counts as late",
		int(gs.dre_account_history["repaid_late"]), 1)
	a.eq_int("a late repay does not also count on time",
		int(gs.dre_account_history["repaid_on_time"]), 0)

# --- 4. idempotent repay -------------------------------------------------

func _test_idempotent_repay() -> void:
	_introduced()
	gm.dispatch("dre_borrow", {})
	_fund(5000)
	var cash_before: int = gs.cash
	a.eq_bool("the first repay succeeds", gm.dispatch("dre_repay", {}), true)
	var cash_after_first: int = gs.cash
	a.eq_int("the first repay spends exactly the total due",
		cash_before - cash_after_first, 1200)
	a.eq_bool("a second repay on an already-clear account is refused",
		gm.dispatch("dre_repay", {}), false)
	a.eq_int("and cash is untouched by the refused second call",
		gs.cash, cash_after_first)

# --- 5. wallet provenance --------------------------------------------------

func _test_wallet_provenance() -> void:
	_introduced()
	var dirty_before: int = int(gs.dirty_cash)
	var clean_before: int = int(gs.clean_cash)
	var earnings_before: Dictionary = gs.todays_earnings.duplicate()
	gm.dispatch("dre_borrow", {})
	a.eq_int("the principal lands as dirty cash",
		int(gs.dirty_cash) - dirty_before, 1000)
	a.eq_int("clean cash is untouched by a Dre loan",
		int(gs.clean_cash), clean_before)
	a.eq_str("borrowing writes no earnings source",
		str(gs.todays_earnings), str(earnings_before))

# --- 6. save/load at every state -------------------------------------------

## Field-by-field, each coerced to its own type before comparing — JSON has
## no distinct int, so a whole-dict `str()` comparison across the round trip
## fails on `0` vs `0.0` even when nothing actually changed (the same trap
## `tips_runner.gd`'s own save round-trip test hit first).
func _round_trip() -> void:
	var save_system: Node = get_node("/root/SaveSystem")
	var captured: Dictionary = save_system.capture()
	var text: String = JSON.stringify(captured)
	var restored: Variant = JSON.parse_string(text)
	a.check("captured state survives JSON", restored is Dictionary)
	var before_account: Dictionary = gs.dre_account.duplicate()
	var before_tier: int = int(gs.dre_access_tier)
	var before_introduced: bool = bool(gs.dre_introduced)
	var before_history: Dictionary = gs.dre_account_history.duplicate()
	_fresh()
	save_system._apply(restored as Dictionary)
	var after_account: Dictionary = gs.dre_account
	a.eq_str("dre_account.status survives the round trip",
		str(after_account.get("status", "")), str(before_account.get("status", "")))
	for money_field in ["principal", "interest", "fee", "opened_day", "due_day", "term_days"]:
		a.eq_int("dre_account.%s survives the round trip" % money_field,
			int(after_account.get(money_field, -999)), int(before_account.get(money_field, -999)))
	a.eq_bool("dre_account.extension_used survives the round trip",
		bool(after_account.get("extension_used", false)),
		bool(before_account.get("extension_used", false)))
	a.eq_int("dre_access_tier survives the round trip", int(gs.dre_access_tier), before_tier)
	a.eq_bool("dre_introduced survives the round trip", bool(gs.dre_introduced), before_introduced)
	var after_history: Dictionary = gs.dre_account_history
	for field in ["loans_taken", "repaid_on_time", "repaid_late", "extensions",
			"defaults", "total_principal_borrowed", "total_interest_paid"]:
		a.eq_int("dre_account_history.%s survives the round trip" % field,
			int(after_history.get(field, -999)), int(before_history.get(field, -999)))

func _test_save_load_at_every_state() -> void:
	_introduced()
	_round_trip()  # clear

	_introduced()
	gm.dispatch("dre_borrow", {})
	_round_trip()  # active

	_introduced()
	gm.dispatch("dre_borrow", {})
	while str(gs.dre_account.get("status", "")) != "due":
		_cross_day()
	_round_trip()  # due

	_introduced()
	gm.dispatch("dre_borrow", {})
	gm.dispatch("dre_request_extension", {})
	_round_trip()  # extended

	_introduced()
	gm.dispatch("dre_borrow", {})
	while str(gs.dre_account.get("status", "")) != "overdue":
		_cross_day()
	_round_trip()  # overdue

	_introduced()
	gm.dispatch("dre_borrow", {})
	while str(gs.dre_account.get("status", "")) != "suspended":
		_cross_day()
	_round_trip()  # suspended

# --- 7. migration fixtures -------------------------------------------------

func _migrate(state: Dictionary) -> Dictionary:
	var save_system: Node = get_node("/root/SaveSystem")
	return save_system._migrate({"save_version": 19, "state": state})

func _v19_state(debt: Variant, debt_due_days: Variant) -> Dictionary:
	return {"day": 4, "cash": 500, "street_name": "Legacy",
		"debt": debt, "debt_due_days": debt_due_days}

func _test_migration_fixtures() -> void:
	var zero: Dictionary = _migrate(_v19_state(0, 0))
	a.check("a v19 save with no debt migrates", not zero.is_empty())
	a.eq_str("a zero legacy debt becomes a clear account",
		str((zero.get("dre_account", {}) as Dictionary).get("status", "")), "clear")
	a.eq_bool("a zero legacy debt did not imply an introduction",
		bool(zero.get("dre_introduced", true)), false)
	a.check("debt is not a live key on a migrated payload", not zero.has("debt"))
	a.check("debt_due_days is not a live key on a migrated payload",
		not zero.has("debt_due_days"))

	var positive: Dictionary = _migrate(_v19_state(1500, 3))
	a.check("a v19 save with positive debt migrates", not positive.is_empty())
	var positive_account: Dictionary = positive.get("dre_account", {})
	a.eq_str("a positive legacy debt becomes an active account",
		str(positive_account.get("status", "")), "active")
	a.eq_int("the whole legacy amount becomes principal",
		int(positive_account.get("principal", -1)), 1500)
	a.eq_int("legacy debt carries no interest or fee breakdown it never had",
		int(positive_account.get("interest", -1)), 0)
	a.eq_int("due_day is derived from the save's own day plus the legacy countdown",
		int(positive_account.get("due_day", -1)), 4 + 3)
	a.eq_bool("a positive legacy debt implies a prior introduction",
		bool(positive.get("dre_introduced", false)), true)
	a.eq_int("a positive legacy debt implies Borrower access",
		int(positive.get("dre_access_tier", -1)), 1)

	var due_today: Dictionary = _migrate(_v19_state(800, 0))
	a.eq_str("a legacy debt due in zero days becomes due, not active",
		str((due_today.get("dre_account", {}) as Dictionary).get("status", "")), "due")

	var overdue: Dictionary = _migrate(_v19_state(800, -2))
	a.eq_str("a legacy debt already past its countdown becomes overdue",
		str((overdue.get("dre_account", {}) as Dictionary).get("status", "")), "overdue")

	var corrupt: Dictionary = _migrate(_v19_state("not_a_number", "also_not_a_number"))
	a.check("a corrupt legacy debt still migrates rather than failing closed",
		not corrupt.is_empty())
	a.eq_str("an unparseable legacy debt reads as zero and becomes clear",
		str((corrupt.get("dre_account", {}) as Dictionary).get("status", "")), "clear")

	var history: Dictionary = positive.get("dre_account_history", {})
	a.eq_int("a fresh migration carries no invented lifetime history",
		int(history.get("loans_taken", -1)), 0)

# --- 8. lifecycle ordering -------------------------------------------------

func _test_lifecycle_ordering() -> void:
	var lifecycle: Object = gm.system("day_lifecycle")
	a.check("day_lifecycle is registered", lifecycle != null)
	if lifecycle == null:
		return
	var order: Array = lifecycle.SETTLE_ORDER
	var shark_index: int = order.find("shark")
	var dre_index: int = order.find("dre")
	var jobs_index: int = order.find("jobs")
	a.check("dre is declared in SETTLE_ORDER", dre_index >= 0)
	a.check("dre settles after shark (DRE-D11)", dre_index > shark_index)
	a.check("dre settles before jobs (DRE-D11)", dre_index < jobs_index)
	a.eq_bool("dre answers settle_night", _dre().has_method("settle_night"), true)

# --- 9. the debt/debt_due_days compatibility projection ------------------

func _test_debt_getter_compatibility() -> void:
	_introduced()
	a.eq_int("debt reads zero on a clear account", gs.debt, 0)
	a.eq_int("debt_due_days reads zero on a clear account", gs.debt_due_days, 0)

	gm.dispatch("dre_borrow", {})
	a.eq_int("debt reads the live total on an active account", gs.debt, 1200)
	a.eq_int("debt_due_days reads positive days out while active",
		gs.debt_due_days, int(gs.dre_account["due_day"]) - gs.day)

	while str(gs.dre_account.get("status", "")) != "overdue":
		_cross_day()
	a.check("debt_due_days reads negative once overdue", gs.debt_due_days < 0)
	a.eq_int("debt is unaffected by which side of due the day sits on", gs.debt, 1200)

# --- 10. blockers, in the player-facing voice the build calls for -------

func _test_blockers() -> void:
	_fresh()
	a.eq_str("borrowing before an introduction refuses by name",
		gm.system("dre").borrow_blocker(), "Dre doesn't know you yet.")

	_introduced()
	gm.dispatch("dre_borrow", {})
	a.eq_str("a second borrow refuses with Dre's own recommended line",
		gm.system("dre").borrow_blocker(), "Clear what you owe before asking again.")

	_fresh()
	a.eq_str("repaying nothing refuses by name",
		gm.system("dre").repay_blocker(), "You don't owe Dre anything.")

	_introduced()
	gm.dispatch("dre_borrow", {})
	gs.cash = 50
	a.eq_str("repaying without enough cash names the exact amount",
		gm.system("dre").repay_blocker(), "You don't have $1200.")

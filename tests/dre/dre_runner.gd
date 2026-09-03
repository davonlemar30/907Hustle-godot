extends Node
## Dre Lending & Loan-Shark Progression, PR A + PR B's own suite
## (`tests/dre/`), same shape as `tests/tips/` and `tests/confrontation/`:
## seconds rather than the parity runner's ten minutes, on the shared
## `territory_asserts.gd` harness.
##
## PR A: the full state-machine walk clear -> active -> due -> extended ->
## overdue -> suspended -> clear, save/load at every state, idempotent
## repay, wallet provenance (borrow is dirty, never earnings), the
## v19 -> v20 migration's three fixture shapes (legacy debt zero / positive
## / corrupt), and `dre`'s position in `DayLifecycle.SETTLE_ORDER`.
##
## PR B: Juan's mention trigger (DRE-D1) fires under its exact conditions and
## nowhere else, `dre_seek_out`'s one-slot meeting, and the two new
## `requirements.gd` types this build adds, tested directly against the pure
## evaluator rather than through a screen. The `hustle.shark` gate swap
## itself (day_min -> dre_access_tier_min) is proven in
## `tests/parity/parity_runner.gd`'s `GATE_CASES`/`HUSTLE_RUNGS` tables, not
## duplicated here.
##
## Save-validation gets its own arms in
## `tests/save_validation/save_validation_runner.gd` alongside this suite,
## not duplicated here.
##
## PR C: the Street Opportunity and Mission System substrate through its one
## real content pair, DRE-ARC-01 (recorded, never tracked as an instance —
## see `systems/opportunities.gd`'s header) and DRE-ARC-02, First Money.
## The reconcile seam end to end (offer -> accept -> resolve, on time and
## late), that a failed dispatch cannot advance an objective, decline, the
## qualifying-load catch-up's three branches plus the legacy pre-PR-A edge
## case, and the closed completion-effect allowlist failing closed.
##
## PR D: DRE-ARC-03 (A Reminder) through both resolution roads -- negotiate
## (no chain, a direct roll) and hard (a real `KIND_CONFRONTATION` chain,
## PRESS rolled, WALK deterministic) -- the disposition gate, and the
## player-default ultimatum `dre_lender.gd`'s old flat overdue timer now
## opens instead: PAY NOW clearing the account, stalling suspending it for
## real, and the restitution -> penance follow-up once payment clears a
## suspension. `tests/confrontation/` owns the chassis itself (rounds,
## receipts, stage transitions); this suite only proves Dre's own content
## drives it correctly, the same division PR B already draws for
## `requirements.gd`'s pure evaluator versus this suite's own fixtures.
##
## PR E: DRE-ARC-04, the sponsored Book loan, end to end -- the one true
## fresh-run walk from Juan's mention through Junior Lender rather than each
## stage proven in isolation, the route gate opening on the sponsorship
## offer before tier 4, the tier/suspension clauses on `fund_blocker` (the
## exception is exactly one borrower wide, never a second gate), and the
## Collector bond discount going live. `tests/parity/parity_runner.gd` owns
## the economy-side proof (the leveraged-lender profile and the structural
## no-risk-free-carry check) -- not duplicated here, the same division this
## suite has always drawn between behavioral and economic coverage.
##
## 0.4.0 PR A (SCR-D1..D3, D-16): the substrate's first non-Dre content,
## `data/score_contracts.gd`'s `score_slide_special` -- the new
## `boost_target_discovered` requirement type, the offer/deadline/resolve/
## expire lifecycle, the receipt guard, and a wrong-target success leaving it
## untouched. Boost's own chance_for() roll is not re-tested here (that
## suite's own job); this suite proves `opportunities.gd` reacts correctly
## to whatever result Boost hands it.

const ASSERTS := preload("res://tests/territory/territory_asserts.gd")
const SCRIPTS := preload("res://data/confrontation_scripts.gd")

const MIN_CHECKS := 404

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
	_test_intro_trigger()
	_test_seek_out()
	_test_requirement_types()
	_test_decline_path_leaves_everything_else_reachable()
	_test_opportunity_first_money_lifecycle()
	_test_opportunity_late_resolution_still_promotes()
	_test_opportunity_objective_advances_only_from_success()
	_test_opportunity_decline()
	_test_opportunity_reconcile_on_load()
	_test_opportunity_effect_allowlist_fails_closed()
	_test_opportunity_offer_is_not_duplicated_by_a_repeat_check()
	_test_opportunity_accepted_commitment_cap()
	_test_boost_target_discovered_requirement()
	_test_score_slide_special_lifecycle()
	_test_a_reminder_offer_and_disposition_gate()
	_test_a_reminder_negotiate_road()
	_test_a_reminder_hard_road_walk()
	_test_a_reminder_hard_road_press()
	_test_repeat_collection_generation()
	_test_repeat_collection_negotiate_road()
	_test_repeat_collection_hard_road_walk()
	_test_repeat_collection_hard_road_press()
	_test_repeat_collection_history_stays_compact()
	_test_repeat_collection_expiry()
	_test_repeatable_attempts_requirement()
	_test_repeatable_attempts_fact()
	_test_repeat_collection_leaned_on_gated_on_attempts()
	_test_repeat_premium_gated_on_three_attempts()
	_test_repeat_errand_lifecycle()
	_test_generate_repeatables_retries_past_a_dud()
	_test_player_default_ultimatum_pay_now()
	_test_player_default_ultimatum_stall_suspends()
	_test_restitution_then_penance()
	_test_full_arc_integration_drive()
	_test_book_gate_opens_only_through_the_arc()
	_test_locked_borrowers_refuse()
	_test_bond_term_parity()

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

	# The authored delay, then Dre's own response (PR D) -- a real
	# collection encounter, not an automatic flip. See dre_collector.gd;
	# the fuller version of this walk lives in
	# _test_player_default_ultimatum_stall_suspends.
	var dre: Object = _dre()
	var delay: int = int(dre.OVERDUE_RESPONSE_DELAY_DAYS)
	var engine: Object = gm.system("consequence")
	for day_index in range(delay):
		a.eq_str("still overdue during the delay (day %d of %d)"
				% [day_index + 1, delay],
			str(gs.dre_account.get("status", "")), "overdue")
		_cross_day()
	a.eq_bool("the delay's end opens Dre's own response instead of "
		+ "auto-suspending", engine.has_active(), true)
	gm.dispatch("resolve_consequence_choice", {"choice_id": "stall"})
	gm.dispatch("consequence_continue", {})
	a.eq_str("stalling is what actually suspends the account",
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
	while str(gs.dre_account.get("status", "")) != "overdue":
		_cross_day()
	# PR D: suspension is a real collection encounter now, not a pure day
	# count -- see dre_lender.gd's settle_night "overdue" branch. Walk to
	# where the encounter opens, then stall it, the same round trip
	# _test_full_state_machine_walk and _test_player_default_ultimatum_
	# stall_suspends both drive.
	var engine: Object = gm.system("consequence")
	for _i in range(6):
		if engine.has_active():
			break
		_cross_day()
	gm.dispatch("resolve_consequence_choice", {"choice_id": "stall"})
	gm.dispatch("consequence_continue", {})
	a.eq_str("stalling reaches suspended before this round trip",
		str(gs.dre_account.get("status", "")), "suspended")
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

# --- 11. Juan's mention, DRE-D1's exact trigger --------------------------

func _dre_texts_from_juan() -> int:
	var n := 0
	for m in gs.phone_inbox:
		if str((m as Dictionary).get("from", "")) == "Juan" \
				and str((m as Dictionary).get("text", "")).contains("Dre"):
			n += 1
	return n

func _test_intro_trigger() -> void:
	# Day 1: never fires, however broke.
	_fresh()
	gs.day = 1
	gs.cash = 0
	gm.system("dre").push_intro_offer(1)
	a.eq_bool("day 1 never mentions Dre, however broke",
		gs.dre_intro_offered, false)

	# Day 2+, comfortable cash, rent nowhere near due: does not fire.
	_fresh()
	gs.day = 3
	gs.cash = 500
	gs.rent_due_day = 20
	gm.system("dre").push_intro_offer(3)
	a.eq_bool("a comfortable player with no rent pressure hears nothing",
		gs.dre_intro_offered, false)

	# The broke clause, isolated: cash <= 80, rent far off.
	_fresh()
	gs.day = 2
	gs.cash = 80
	gs.rent_due_day = 20
	gm.system("dre").push_intro_offer(2)
	a.eq_bool("cash at or under 80 mentions Dre on its own", gs.dre_intro_offered, true)
	a.eq_int("exactly one Juan text about Dre lands", _dre_texts_from_juan(), 1)

	# The rent-pressure clause, isolated: cash between 80 and the weekly
	# rent, rent due within a day. Neither clause alone would fire this.
	_fresh()
	gs.day = 5
	gs.cash = 100
	gs.rent_due_day = 6
	gm.system("dre").push_intro_offer(5)
	a.eq_bool("rent due tomorrow with cash short of it mentions Dre too",
		gs.dre_intro_offered, true)

	# Rent due soon, but enough cash to cover it: neither clause fires.
	_fresh()
	gs.day = 5
	gs.cash = int(gs.WEEKLY_RENT)
	gs.rent_due_day = 6
	gm.system("dre").push_intro_offer(5)
	a.eq_bool("rent due soon with enough cash to cover it stays quiet",
		gs.dre_intro_offered, false)

	# Rent due in two days is not "within one day" -- the clause is narrow
	# on purpose, matching DRE-D1's literal wording.
	_fresh()
	gs.day = 5
	gs.cash = 100
	gs.rent_due_day = 7
	gm.system("dre").push_intro_offer(5)
	a.eq_bool("rent two days out does not count as due within one day",
		gs.dre_intro_offered, false)

	# Once per run: a second day-start check does not re-fire or push a
	# second text, even if the trigger conditions are still true.
	_fresh()
	gs.day = 2
	gs.cash = 10
	gm.system("dre").push_intro_offer(2)
	gs.day = 3
	gm.system("dre").push_intro_offer(3)
	a.eq_int("the mention is a one-shot, not a nightly nag", _dre_texts_from_juan(), 1)

# --- 12. dre_seek_out, the one-slot meeting -------------------------------

func _test_seek_out() -> void:
	_fresh()
	a.eq_str("seeking Dre out before anyone's mentioned him refuses by name",
		gm.system("dre").seek_out_blocker(), "Nobody's mentioned him to you.")
	a.eq_bool("and the dispatch itself is refused",
		gm.dispatch("dre_seek_out", {}), false)

	gs.dre_intro_offered = true
	var slot_before: int = int(gs.time_slots_today)
	a.eq_bool("seeking him out succeeds once he's been mentioned",
		gm.dispatch("dre_seek_out", {}), true)
	a.eq_bool("the meeting sets dre_introduced", gs.dre_introduced, true)
	a.eq_int("and opens Borrower access", int(gs.dre_access_tier), 1)
	a.check("the meeting costs the one authored slot (DRE-D2)",
		int(gs.time_slots_today) != slot_before or int(gs.day) > 2)

	a.eq_str("seeking him out again refuses -- you already know him",
		gm.system("dre").seek_out_blocker(), "You already know him.")

	# A player already past Borrower keeps their tier -- the meeting only
	# ever raises it to 1, never lowers an access already earned by a
	# later PR's own milestones.
	_fresh()
	gs.dre_intro_offered = true
	gs.dre_access_tier = 2
	gm.dispatch("dre_seek_out", {})
	a.eq_int("the meeting never lowers an already-earned tier",
		int(gs.dre_access_tier), 2)

# --- 13. the two new requirement types, against the pure evaluator ------

func _test_requirement_types() -> void:
	var req := preload("res://systems/requirements.gd").new()

	var below := req.evaluate_requirement(
		{"type": "dre_access_tier_min", "min": 4}, {"dre_access_tier": 1})
	a.eq_bool("tier 1 fails a tier-4 requirement", bool(below["ok"]), false)
	a.eq_str("and names itself as the blocker",
		str(below["blocker_code"]), "dre_access_tier_min")
	a.near("current reports where the player is",
		float(below["current"]), 1.0)
	a.near("required reports where the line is",
		float(below["required"]), 4.0)

	var at := req.evaluate_requirement(
		{"type": "dre_access_tier_min", "min": 4}, {"dre_access_tier": 4})
	a.eq_bool("tier 4 clears a tier-4 requirement", bool(at["ok"]), true)

	var missing := req.evaluate_requirement(
		{"type": "dre_access_tier_min", "min": 4}, {})
	a.eq_bool("an absent fact reads as tier 0 and fails closed",
		bool(missing["ok"]), false)

	var clear_ok := req.evaluate_requirement(
		{"type": "dre_account_clear"}, {"dre_account_status": "clear"})
	a.eq_bool("a clear account passes dre_account_clear", bool(clear_ok["ok"]), true)

	var clear_blocked := req.evaluate_requirement(
		{"type": "dre_account_clear"}, {"dre_account_status": "suspended"})
	a.eq_bool("a suspended account fails dre_account_clear",
		bool(clear_blocked["ok"]), false)
	a.eq_str("current reports the actual status",
		str(clear_blocked["current"]), "suspended")

	var clear_absent := req.evaluate_requirement({"type": "dre_account_clear"}, {})
	a.eq_bool("an absent fact reads as clear -- a fresh run has no account yet",
		bool(clear_absent["ok"]), true)

	var unknown := req.evaluate_requirement({"type": "not_a_real_type"}, {})
	a.eq_bool("an unknown requirement type still fails closed", bool(unknown["ok"]), false)

# --- 14. declining Dre leaves everything else reachable -------------------

func _test_decline_path_leaves_everything_else_reachable() -> void:
	var access: Node = get_node("/root/SurfaceVisibility")
	_fresh()
	gs.day = 5
	gs.wander_count = 3
	gs.market_discovered = true
	# WS-D1 (0.8.0): the hustle rows open on discovery now, not on the clock.
	gs.hustles_discovered = ["market", "boost", "stickup", "list"]
	gs.job_contacts = 1
	# Deliberately never seek Dre out -- everything else on the ladder that
	# does not read dre_access_tier still opens on its own facts.
	for surface_id in ["hustle.market", "hustle.boost", "hustle.stickup",
			"hustle.list", "menu.jobs"]:
		a.check("%s is reachable without ever meeting Dre" % surface_id,
			access.is_unlocked(surface_id))
	a.eq_bool("but the shark stays shut", access.is_unlocked(access.HUSTLE_SHARK), false)
	gs.reset_to_new_game()

# --- 15. Street Opportunity and Mission System, PR C ------------------------
#
# DRE-ARC-01 (recorded, not tracked -- see systems/opportunities.gd's header
# for why) and DRE-ARC-02 (First Money, the first real instance) through the
# real dispatch seam. `_round_trip`-style in-memory save/load already covers
# straight persistence for `dre_account`; these tests exercise the substrate
# itself: the reconcile seam, the qualifying-load catch-up, the closed
# effect allowlist, and that nothing here can be advanced except through an
# authoritative dispatch result.

func _opportunities() -> Object:
	return gm.system("opportunities")

func _test_opportunity_first_money_lifecycle() -> void:
	_fresh()
	gs.dre_intro_offered = true
	gm.dispatch("dre_seek_out", {})
	a.eq_bool("DRE-ARC-01 is recorded the moment seek_out succeeds",
		gs.opportunity_history.has("dre_the_introduction"), true)
	a.eq_str("recorded completed", str((gs.opportunity_history["dre_the_introduction"] \
			as Dictionary)["outcome"]), "completed")
	a.eq_int("First Money offers itself in the same reconcile pass",
		gs.opportunity_offers.size(), 1)
	var offer: Dictionary = gs.opportunity_offers[0]
	a.eq_str("the offer names First Money", str(offer["definition_id"]), "dre_first_money")
	a.eq_str("in the offered state", str(offer["state"]), "offered")

	gm.dispatch("dre_borrow", {})
	a.eq_int("borrowing accepts it -- the offer array empties",
		gs.opportunity_offers.size(), 0)
	a.eq_int("and it lands in active_opportunities",
		gs.active_opportunities.size(), 1)
	a.eq_str("in the active state",
		str((gs.active_opportunities[0] as Dictionary)["state"]), "active")
	a.eq_int("dre_access_tier has not moved yet -- Trusted Customer is earned "
		+ "by resolving, not by accepting", int(gs.dre_access_tier), 1)

	_fund(2000)
	gm.dispatch("dre_repay", {})
	a.eq_int("repaying resolves it -- active_opportunities empties",
		gs.active_opportunities.size(), 0)
	a.eq_bool("dre_first_money is now in history",
		gs.opportunity_history.has("dre_first_money"), true)
	a.eq_int("recorded exactly once", int((gs.opportunity_history["dre_first_money"] \
			as Dictionary)["count"]), 1)
	a.eq_int("Trusted Customer is latched", int(gs.dre_access_tier), 2)

	a.eq_bool("a second repay is refused by dre_lender itself",
		gm.dispatch("dre_repay", {}), false)
	a.eq_int("so the history count cannot double from a refused repeat",
		int((gs.opportunity_history["dre_first_money"] as Dictionary)["count"]), 1)

func _test_opportunity_late_resolution_still_promotes() -> void:
	_fresh()
	gs.dre_intro_offered = true
	gm.dispatch("dre_seek_out", {})
	gm.dispatch("dre_borrow", {})
	while str(gs.dre_account.get("status", "")) != "overdue":
		_cross_day()
	_fund(2000)
	a.eq_bool("a late repay still succeeds", gm.dispatch("dre_repay", {}), true)
	a.eq_int("and First Money still resolves",
		gs.active_opportunities.size(), 0)
	a.eq_int("Trusted Customer is still earned -- the design doc's recovery "
		+ "completion, not only the clean one", int(gs.dre_access_tier), 2)

func _test_opportunity_objective_advances_only_from_success() -> void:
	_fresh()
	gs.dre_intro_offered = true
	gm.dispatch("dre_seek_out", {})
	gm.dispatch("dre_borrow", {})
	gs.cash = 0
	a.eq_bool("a repay Dre's own blocker refuses dispatches false",
		gm.dispatch("dre_repay", {}), false)
	a.eq_int("a failed dispatch never reaches the reconcile seam -- "
		+ "the instance is exactly where it was", gs.active_opportunities.size(), 1)
	a.eq_str("still active, not completed",
		str((gs.active_opportunities[0] as Dictionary)["state"]), "active")
	a.eq_bool("and no history was written for a resolution that never happened",
		gs.opportunity_history.has("dre_first_money"), false)

func _test_opportunity_decline() -> void:
	_fresh()
	gs.dre_intro_offered = true
	gm.dispatch("dre_seek_out", {})
	var instance_id: int = int((gs.opportunity_offers[0] as Dictionary)["instance_id"])
	a.eq_bool("declining the offer by instance id succeeds",
		gm.dispatch("opportunity_decline", {"instance_id": instance_id}), true)
	a.eq_int("the offer is gone", gs.opportunity_offers.size(), 0)
	a.eq_str("recorded declined, not completed",
		str((gs.opportunity_history["dre_first_money"] as Dictionary)["outcome"]), "declined")
	# The contract does not own the door it points at -- section 5.4's
	# pillar, "a contract observes; a domain system settles." Declining the
	# OFFER does not touch dre_lender's own rules, the same way PR B's
	# decline test proves not seeking Dre out breaks nothing else.
	a.eq_bool("but dre_borrow itself is untouched by the decline -- the "
		+ "domain stays authoritative", gm.dispatch("dre_borrow", {}), true)
	a.eq_bool("declining an offer that no longer exists is refused by name",
		gm.dispatch("opportunity_decline", {"instance_id": instance_id}), false)

func _test_opportunity_reconcile_on_load() -> void:
	# Never touched, account clear: offers fresh.
	_fresh()
	gs.dre_introduced = true
	gs.dre_access_tier = 1
	_opportunities().reconcile_on_load()
	a.eq_int("First Money offers itself for a never-touched, eligible player",
		gs.opportunity_offers.size(), 1)

	# A first loan already open under normal PR C play.
	_fresh()
	gs.dre_introduced = true
	gs.dre_access_tier = 1
	gs.dre_account["status"] = "active"
	gs.dre_account_history["loans_taken"] = 1
	_opportunities().reconcile_on_load()
	a.eq_int("a first loan already open is activated retroactively",
		gs.active_opportunities.size(), 1)
	a.eq_str("as dre_first_money", str((gs.active_opportunities[0] \
			as Dictionary)["definition_id"]), "dre_first_money")

	# The legacy edge case: a v19 -> v20 migrated debt carries an open
	# account with loans_taken still at its GameState default of zero,
	# because the field did not exist yet to migrate (PR A's own arm).
	_fresh()
	gs.dre_introduced = true
	gs.dre_access_tier = 1
	gs.dre_account["status"] = "overdue"
	_opportunities().reconcile_on_load()
	a.eq_int("a legacy open debt with no loans_taken is activated, not offered",
		gs.active_opportunities.size(), 1)
	a.eq_int("and nothing doubles up in opportunity_offers",
		gs.opportunity_offers.size(), 0)

	# Already resolved before this system existed.
	_fresh()
	gs.dre_introduced = true
	gs.dre_access_tier = 1
	gs.dre_account_history["loans_taken"] = 1
	_opportunities().reconcile_on_load()
	a.eq_bool("an already-resolved first loan completes retroactively",
		gs.opportunity_history.has("dre_first_money"), true)
	a.eq_int("and Trusted Customer is granted immediately",
		int(gs.dre_access_tier), 2)

	# Idempotent: a second reconcile against the same state does not re-run.
	_opportunities().reconcile_on_load()
	a.eq_int("a repeat reconcile does not recount an already-recorded arc",
		int((gs.opportunity_history["dre_first_money"] as Dictionary)["count"]), 1)
	gs.reset_to_new_game()

func _test_opportunity_effect_allowlist_fails_closed() -> void:
	_fresh()
	var before_tier: int = int(gs.dre_access_tier)
	_opportunities()._apply_effect({"type": "set_field_directly", "field": "dre_access_tier",
		"min": 5})
	a.eq_int("an unlisted effect type mutates nothing, not even a named GameState field",
		int(gs.dre_access_tier), before_tier)

func _test_opportunity_offer_is_not_duplicated_by_a_repeat_check() -> void:
	_fresh()
	gs.dre_introduced = true
	gs.dre_access_tier = 1
	_opportunities()._maybe_offer("dre_first_money")
	_opportunities()._maybe_offer("dre_first_money")
	a.eq_int("re-checking eligibility (what a re-rendered screen would do, "
		+ "were it not read-only) never mints a second offer",
		gs.opportunity_offers.size(), 1)
	gs.reset_to_new_game()

func _test_opportunity_accepted_commitment_cap() -> void:
	# OPP-D2, unreachable by this build's own content (First Money is the
	# only thing that can ever be offered) but enforced anyway -- fabricated
	# filler instances stand in for the repeatable content that will one day
	# reach this for real.
	_fresh()
	gs.dre_introduced = true
	gs.dre_access_tier = 1
	gs.active_opportunities = [
		{"instance_id": 90, "definition_id": "filler_a", "state": "active"},
		{"instance_id": 91, "definition_id": "filler_b", "state": "active"},
		{"instance_id": 92, "definition_id": "filler_c", "state": "active"},
	]
	_opportunities()._maybe_offer("dre_first_money")
	a.eq_int("First Money can still be offered at the cap -- offering is free",
		gs.opportunity_offers.size(), 1)
	_opportunities().accept("dre_first_money")
	a.eq_int("but accepting it at the cap is refused",
		gs.opportunity_offers.size(), 1)
	a.eq_int("active_opportunities does not grow past the cap",
		gs.active_opportunities.size(), 3)

	gs.active_opportunities = []
	_opportunities().accept("dre_first_money")
	a.eq_int("freeing a slot lets the same still-offered instance accept",
		gs.active_opportunities.size(), 1)
	gs.reset_to_new_game()

# --- 15b. score_slide_special (0.4.0 PR A, SCR-D1..D3) -----------------------

## `requirements.gd`'s own pure-evaluator coverage, same shape as
## `_test_requirement_types()` above -- the new `boost_target_discovered`
## type this build adds.
func _test_boost_target_discovered_requirement() -> void:
	var req := preload("res://systems/requirements.gd").new()

	var missing := req.evaluate_requirement(
		{"type": "boost_target_discovered", "target_id": "northern_value"}, {})
	a.eq_bool("an absent discovery list fails closed", bool(missing["ok"]), false)

	var not_yet := req.evaluate_requirement(
		{"type": "boost_target_discovered", "target_id": "northern_value"},
		{"boost_targets_discovered": ["night_owl"]})
	a.eq_bool("a discovered list without the named target still fails",
		bool(not_yet["ok"]), false)

	var found := req.evaluate_requirement(
		{"type": "boost_target_discovered", "target_id": "northern_value"},
		{"boost_targets_discovered": ["night_owl", "northern_value"]})
	a.eq_bool("the named target present in the list passes", bool(found["ok"]), true)

## The Score's own lifecycle: offer on discovery, the 3-day window computed
## at offer time, resolution keyed to the named target AND a real success
## (never a mere attempt), the receipt guard, a wrong-target success leaving
## it untouched, and expiry. Resolution is proven against `reconcile()`
## directly rather than fighting Boost's own seeded chance_for() roll to
## force a win inside a 3-day window in a unit test -- Boost's own RNG has
## its coverage in `tests/parity/parity_runner.gd` already; what this suite
## owns is proving `opportunities.gd` reacts correctly to the result Boost
## hands it, the same division this file draws everywhere else (see this
## file's own header on PR D). The real end-to-end dispatch path is proven
## live via the godot-ai MCP instead (PR A's own body).
func _test_score_slide_special_lifecycle() -> void:
	_fresh()
	a.eq_int("no offer before the target is discovered",
		gs.opportunity_offers.size(), 0)

	gs.boost_targets_discovered = ["northern_value"]
	_opportunities().settle_night(gs.day)
	a.eq_int("the Score offers itself once the target is discovered",
		gs.opportunity_offers.size(), 1)
	var offer: Dictionary = gs.opportunity_offers[0]
	a.eq_str("naming score_slide_special", str(offer["definition_id"]), "score_slide_special")
	a.eq_int("a 3-day window computed at offer time",
		int(offer["deadline_day"]), int(offer["offered_day"]) + 3)

	a.eq_int("a repeat nightly sweep does not mint a second offer",
		gs.opportunity_offers.size(), 1)

	var cash_before: int = gs.cash
	_opportunities().reconcile("boost", {"target_id": "night_owl"},
		{"ok": true, "success": true, "take": 60, "tier": 1})
	a.eq_int("a success at a DIFFERENT target leaves the offer alone",
		gs.opportunity_offers.size(), 1)
	a.eq_int("and pays no bonus", gs.cash, cash_before)

	_opportunities().reconcile("boost", {"target_id": "northern_value"},
		{"ok": true, "success": false, "take": 0, "tier": 2})
	a.eq_int("a blown attempt at the named target does not fail the Score -- "
		+ "only the window does (SCR-D1)", gs.opportunity_offers.size(), 1)

	_opportunities().reconcile("boost", {"target_id": "northern_value"},
		{"ok": true, "success": true, "take": 105, "tier": 2})
	a.eq_int("a real success at the named target resolves it",
		gs.opportunity_offers.size(), 0)
	a.eq_bool("recorded in history", gs.opportunity_history.has("score_slide_special"), true)
	a.eq_str("completed, not failed or expired",
		str((gs.opportunity_history["score_slide_special"] as Dictionary)["outcome"]), "completed")
	a.eq_int("the authored $50 bonus lands as dirty cash, on top of Boost's "
		+ "own $105 this test's own result dict stands in for",
		gs.cash - cash_before, 50)

	var cash_after_first: int = gs.cash
	_opportunities().reconcile("boost", {"target_id": "northern_value"},
		{"ok": true, "success": true, "take": 105, "tier": 2})
	a.eq_int("the receipt guard refuses a second credit -- there is nothing "
		+ "left active or offered for reconcile to even find",
		gs.cash, cash_after_first)

	# Expiry: a fresh offer, never touched, aged past its own window.
	_fresh()
	gs.boost_targets_discovered = ["northern_value"]
	_opportunities().settle_night(gs.day)
	var deadline: int = int((gs.opportunity_offers[0] as Dictionary)["deadline_day"])
	gs.day = deadline + 1
	_opportunities().settle_night(gs.day)
	a.eq_int("the offer is gone once its own window has passed",
		gs.opportunity_offers.size(), 0)
	a.eq_str("recorded expired, not failed or completed",
		str((gs.opportunity_history["score_slide_special"] as Dictionary)["outcome"]), "expired")

	# In-memory reload, mid-offer -- the `_round_trip()` pattern above, without
	# touching the real user:// save slot.
	_fresh()
	gs.boost_targets_discovered = ["northern_value"]
	_opportunities().settle_night(gs.day)
	var save_system: Node = get_node("/root/SaveSystem")
	var captured: Dictionary = save_system.capture()
	var restored: Variant = JSON.parse_string(JSON.stringify(captured))
	var before_deadline: int = int((gs.opportunity_offers[0] as Dictionary)["deadline_day"])
	_fresh()
	save_system._apply(restored as Dictionary)
	a.eq_int("the offer survives a reload", gs.opportunity_offers.size(), 1)
	a.eq_int("with its own deadline intact",
		int((gs.opportunity_offers[0] as Dictionary)["deadline_day"]), before_deadline)
	gs.reset_to_new_game()

# --- 16. DRE-ARC-03, A Reminder (PR D) ---------------------------------------

func _collector() -> Object:
	return gm.system("dre_collector")

func _consequence() -> Object:
	return gm.system("consequence")

## Trusted Customer, resolved account, no Dre history yet -- exactly the
## three OPP-D requirements `dre_a_reminder` authors, satisfied by
## construction rather than by playing First Money out for real (already
## proven end to end by _test_opportunity_first_money_lifecycle).
func _trusted_customer() -> void:
	_fresh()
	gs.dre_introduced = true
	gs.dre_access_tier = 2

func _test_a_reminder_offer_and_disposition_gate() -> void:
	_trusted_customer()
	_opportunities()._maybe_offer("dre_a_reminder")
	a.eq_bool("A Reminder offers itself at Trusted Customer with a clear "
		+ "account and no Dre history", _collector().collect_blocker().is_empty(), true)

	# The gate, isolated: same tier and account, disposition pushed
	# negative. Ledger written directly (record_observation refuses outside
	# a live dispatch) -- a repeated walked_a_debt-shaped row, the same
	# event PR A already authors, is enough to carry the score well under
	# the floor without inventing a new fixture event.
	_trusted_customer()
	gs.npc_ledgers["dre"] = [{"key": "test:walked_a_debt", "type": "financial",
		"event": "walked_a_debt", "location": "", "source": "direct", "count": 3, "day": 1}]
	var exposure := get_node("/root/Exposure")
	a.check("the fixture actually pushes disposition negative",
		exposure.disposition("dre") < 0.0)
	_opportunities()._maybe_offer("dre_a_reminder")
	a.eq_bool("but a cold-or-worse disposition keeps Dre from offering it",
		_collector().collect_blocker().is_empty(), false)
	gs.reset_to_new_game()

## Searches days/slots for a negotiate outcome in `wanted` (["clean","messy"]
## for success, ["failure","catastrophic"] for failure), the same technique
## `tests/confrontation/confrontation_runner.gd`'s own `_find_day` uses:
## compute the tier with the exact call the production code makes, off a
## candidate day/slot, before ever touching real dispatch state.
func _find_negotiate_day(wanted: Array) -> Dictionary:
	var resolver: Object = gm.system("outcome_resolver")
	var attrs: Object = gm.system("attributes")
	for day in range(1, 200):
		for slot in range(4):
			var key := "%d:%d:dre_collection:negotiate" % [day, slot]
			var tier: String = str(resolver.resolve_action("negotiation",
				SCRIPTS.DRE_COLLECTION_NEGOTIATE_CHANCE, attrs.effective("charisma"),
				gs.run_seed, key)["tier"])
			if tier in wanted:
				return {"day": day, "slot": slot, "tier": tier}
	return {}

func _test_a_reminder_negotiate_road() -> void:
	var success := _find_negotiate_day(["clean", "messy"])
	a.check("a negotiate success day/slot exists in the search window",
		not success.is_empty())
	_trusted_customer()
	gs.day = int(success.get("day", 1))
	gs.time_slots_today = int(success.get("slot", 0))
	_opportunities()._maybe_offer("dre_a_reminder")
	var cash_before: int = gs.cash
	a.eq_bool("negotiating dispatches", gm.dispatch("dre_collect_negotiate", {}), true)
	a.check("a successful negotiate pays the player's fee",
		gs.cash > cash_before)
	a.eq_int("and Collector is earned", int(gs.dre_access_tier), 3)
	a.eq_str("recorded completed",
		str((gs.opportunity_history["dre_a_reminder"] as Dictionary)["outcome"]), "completed")

	var failure := _find_negotiate_day(["failure", "catastrophic"])
	a.check("a negotiate failure day/slot exists in the search window",
		not failure.is_empty())
	_trusted_customer()
	gs.day = int(failure.get("day", 1))
	gs.time_slots_today = int(failure.get("slot", 0))
	_opportunities()._maybe_offer("dre_a_reminder")
	var cash_before2: int = gs.cash
	gm.dispatch("dre_collect_negotiate", {})
	a.eq_int("a failed negotiate pays nothing", gs.cash, cash_before2)
	a.eq_int("and Collector is not earned on a failed road", int(gs.dre_access_tier), 2)
	a.eq_str("recorded failed",
		str((gs.opportunity_history["dre_a_reminder"] as Dictionary)["outcome"]), "failed")
	gs.reset_to_new_game()

func _test_a_reminder_hard_road_walk() -> void:
	_trusted_customer()
	_opportunities()._maybe_offer("dre_a_reminder")
	a.eq_bool("going hard opens a chain", gm.dispatch("dre_collect_hard", {}), true)
	a.eq_bool("and the engine agrees one is active", _consequence().has_active(), true)
	var cash_before: int = gs.cash
	a.eq_bool("walking away resolves the chain",
		gm.dispatch("resolve_consequence_choice", {"choice_id": "walk"}), true)
	a.eq_int("walking pays nothing", gs.cash, cash_before)
	a.eq_int("and does not promote Collector", int(gs.dre_access_tier), 2)
	a.eq_str("recorded failed, not completed",
		str((gs.opportunity_history["dre_a_reminder"] as Dictionary)["outcome"]), "failed")
	var exposure := get_node("/root/Exposure")
	var found_refused := false
	for row in exposure.ledger_of("dre"):
		if str((row as Dictionary)["event"]) == "refused_work":
			found_refused = true
	a.eq_bool("walking away is refused_work to Dre, by name", found_refused, true)
	gm.dispatch("consequence_continue", {})
	a.eq_bool("continuing closes the chain out", _consequence().has_active(), false)
	gs.reset_to_new_game()

## PRESS's own cause_id is a monotonic counter, not a function of day/slot
## (ConsequenceEngine.allocate_cause_id), so unlike negotiate this cannot be
## searched for a specific tier by walking the calendar. Assert on whichever
## tier the one live roll actually lands on instead -- still fully
## deterministic and reproducible for a fixed run_seed and cause sequence,
## just not aimed at one tier in particular.
func _test_a_reminder_hard_road_press() -> void:
	_trusted_customer()
	_opportunities()._maybe_offer("dre_a_reminder")
	gm.dispatch("dre_collect_hard", {})
	var cash_before: int = gs.cash
	var health_before: int = gs.health
	gm.dispatch("resolve_consequence_choice", {"choice_id": "press"})
	var result: Dictionary = gs.active_consequence.get("decision", {}).get("result", {})
	var tier := str(result.get("resolution", ""))
	a.check("press resolves to one of the four authored tiers",
		tier in ["clean", "messy", "failure", "catastrophic"])
	var collected: bool = bool(result.get("collected", false))
	if collected:
		a.check("a collecting tier pays the player's fee", gs.cash > cash_before)
		a.eq_int("and promotes Collector", int(gs.dre_access_tier), 3)
		a.eq_str("recorded completed",
			str((gs.opportunity_history["dre_a_reminder"] as Dictionary)["outcome"]), "completed")
	else:
		a.eq_int("a non-collecting tier pays nothing", gs.cash, cash_before)
		a.eq_int("and does not promote Collector", int(gs.dre_access_tier), 2)
		a.eq_str("recorded failed",
			str((gs.opportunity_history["dre_a_reminder"] as Dictionary)["outcome"]), "failed")
	if tier == "catastrophic":
		a.check("catastrophic is the one tier that can cost health",
			gs.health <= health_before)
	gm.dispatch("consequence_continue", {})
	gs.reset_to_new_game()

# --- 16b. dre_repeat_collection (0.4.0 PR B, REP-D1..D5) ---------------------

const REPEAT_CONTRACTS := preload("res://data/dre_repeat_contracts.gd")

## Junior Lender, satisfied by construction -- the same reduced-setup
## discipline `_trusted_customer()` uses above, already proven reachable for
## real by `_test_full_arc_integration_drive()`.
## Junior Lender by construction, not by playing the arc out (already proven
## reachable for real by `_test_full_arc_integration_drive`) -- but the
## history for every earlier milestone has to be marked resolved too, or
## `settle_night`'s own generic sweep re-offers `dre_first_money`/
## `dre_a_reminder`/`dre_book_sponsorship` alongside the repeatable (their
## own tier requirements are trivially satisfied by a bare tier-4 fixture)
## and eats the whole 3-cap before generation ever runs. A real run never
## hits this: each milestone resolves in sequence long before Junior Lender,
## landing in history, never sitting in `opportunity_offers` at the same
## time as the next one.
func _junior_lender() -> void:
	_fresh()
	gs.dre_introduced = true
	gs.dre_access_tier = 4
	gs.opportunity_history = {
		"dre_first_money": {"outcome": "completed", "count": 1, "last_resolved_day": 1},
		"dre_a_reminder": {"outcome": "completed", "count": 1, "last_resolved_day": 1},
		"dre_book_sponsorship": {"outcome": "completed", "count": 1, "last_resolved_day": 1},
	}

func _test_repeat_collection_generation() -> void:
	# Below Junior Lender: DRE-D12/REP-D1's own gate, nothing generates.
	_trusted_customer()
	_opportunities().settle_night(gs.day)
	a.eq_bool("no repeatable generates below Junior Lender",
		_offer_exists_any("dre_repeat_collection"), false)

	# At Junior Lender: generates.
	_junior_lender()
	_opportunities().settle_night(gs.day)
	a.eq_bool("a repeatable collection offers itself at Junior Lender",
		_offer_exists_any("dre_repeat_collection"), true)
	var offer: Dictionary = _find_offer("dre_repeat_collection")
	var ctx: Dictionary = offer.get("source_context", {})
	a.check("the borrower is one of the authored pool",
		str(ctx.get("target_id", "")) in ["reggie_voss", "katrina_bell", "omar_deng"])
	a.check("the seeded clean fee sits inside its authored band",
		int(ctx.get("fee_clean", 0)) >= REPEAT_CONTRACTS.FEE_BAND["clean"][0] \
		and int(ctx.get("fee_clean", 0)) <= REPEAT_CONTRACTS.FEE_BAND["clean"][1])
	a.eq_int("a 4-day window from the offer",
		int(offer["deadline_day"]), int(offer["offered_day"]) + 4)

	# Determinism: the same day, replayed from scratch, picks the same
	# borrower and the same fees -- REP-D1's "a reload regenerates the same
	# offer," proven without an actual save/reload since generation is a
	# pure function of run_seed + day.
	var first_borrower := str(ctx.get("target_id", ""))
	var first_fee := int(ctx.get("fee_clean", 0))
	_junior_lender()
	_opportunities().settle_night(gs.day)
	var replay: Dictionary = _find_offer("dre_repeat_collection").get("source_context", {})
	a.eq_str("the same day picks the same borrower",
		str(replay.get("target_id", "")), first_borrower)
	a.eq_int("and the same seeded fee", int(replay.get("fee_clean", 0)), first_fee)

	# The 3-cap (OPP-D2/REP-D1), offered+active combined.
	_junior_lender()
	gs.active_opportunities = [
		{"instance_id": 90, "definition_id": "filler_a", "state": "active"},
		{"instance_id": 91, "definition_id": "filler_b", "state": "active"},
		{"instance_id": 92, "definition_id": "filler_c", "state": "active"},
	]
	_opportunities().settle_night(gs.day)
	a.eq_bool("generation refuses at the 3-cap, offered+active combined",
		_offer_exists_any("dre_repeat_collection"), false)

	# One new offer per settle_night call, never a flood -- even with the
	# generated offer already live and still eligible-looking (nothing about
	# `_maybe_offer`'s own idempotence applies to a `repeatable: true`
	# definition, which is exactly why this needs its own proof).
	_junior_lender()
	_opportunities().settle_night(gs.day)
	_opportunities().settle_night(gs.day)
	a.eq_int("a second settle_night call does not mint a second offer",
		gs.opportunity_offers.size(), 1)
	gs.reset_to_new_game()

func _offer_exists_any(definition_id: String) -> bool:
	return not _find_offer(definition_id).is_empty()

func _find_offer(definition_id: String) -> Dictionary:
	for entry in gs.opportunity_offers:
		if str((entry as Dictionary).get("definition_id", "")) == definition_id:
			return entry
	return {}

func _test_repeat_collection_negotiate_road() -> void:
	var success := _find_negotiate_day(["clean", "messy"])
	a.check("a negotiate success day/slot exists in the search window",
		not success.is_empty())
	_junior_lender()
	gs.day = int(success.get("day", 1))
	gs.time_slots_today = int(success.get("slot", 0))
	_opportunities().settle_night(gs.day)
	var ctx: Dictionary = _find_offer("dre_repeat_collection").get("source_context", {})
	var expected_fee := int(ctx.get("fee_%s" % str(success["tier"]), 0))
	var cash_before: int = gs.cash
	a.eq_bool("negotiating dispatches", gm.dispatch("dre_collect_negotiate", {}), true)
	a.eq_int("a successful negotiate pays exactly the seeded band fee, not "
		+ "the flat authored one dre_a_reminder uses",
		gs.cash - cash_before, expected_fee)
	a.eq_int("Junior Lender does not move -- there is no further tier to grant",
		int(gs.dre_access_tier), 4)
	a.eq_str("recorded against dre_repeat_collection, not dre_a_reminder",
		str((gs.opportunity_history["dre_repeat_collection"] as Dictionary)["outcome"]),
		"completed")
	a.eq_int("dre_a_reminder's own history count is untouched by a repeatable "
		+ "resolving -- still the fixture's own 1, not bumped by this resolution",
		int((gs.opportunity_history["dre_a_reminder"] as Dictionary)["count"]), 1)
	gs.reset_to_new_game()

func _test_repeat_collection_hard_road_walk() -> void:
	_junior_lender()
	_opportunities().settle_night(gs.day)
	var target_name := str(_find_offer("dre_repeat_collection")
		.get("source_context", {}).get("target_name", ""))
	a.eq_bool("going hard opens a chain", gm.dispatch("dre_collect_hard", {}), true)
	a.eq_str("naming the generated borrower, not Dontae Wells",
		str(gs.active_consequence.get("source", {}).get("target_name", "")), target_name)
	gm.dispatch("resolve_consequence_choice", {"choice_id": "walk"})
	a.eq_str("walking away is recorded against the repeatable",
		str((gs.opportunity_history["dre_repeat_collection"] as Dictionary)["outcome"]),
		"failed")
	gm.dispatch("consequence_continue", {})
	gs.reset_to_new_game()

## Same reasoning as `_test_a_reminder_hard_road_press()` above: PRESS's
## cause_id is a monotonic counter, not searchable by day/slot, so this
## asserts on whichever of the four authored tiers the one live roll lands
## on rather than aiming at a specific one.
func _test_repeat_collection_hard_road_press() -> void:
	_junior_lender()
	_opportunities().settle_night(gs.day)
	var ctx: Dictionary = _find_offer("dre_repeat_collection").get("source_context", {})
	gm.dispatch("dre_collect_hard", {})
	var cash_before: int = gs.cash
	gm.dispatch("resolve_consequence_choice", {"choice_id": "press"})
	var result: Dictionary = gs.active_consequence.get("decision", {}).get("result", {})
	var tier := str(result.get("resolution", ""))
	a.check("press resolves to one of the four authored tiers",
		tier in ["clean", "messy", "failure", "catastrophic"])
	if bool(result.get("collected", false)):
		var expected_fee := int(ctx.get("fee_%s" % tier, 0))
		a.eq_int("a collecting tier pays exactly the seeded band fee",
			gs.cash - cash_before, expected_fee)
		a.eq_str("recorded completed against the repeatable",
			str((gs.opportunity_history["dre_repeat_collection"] as Dictionary)["outcome"]),
			"completed")
	else:
		a.eq_int("a non-collecting tier pays nothing", gs.cash, cash_before)
	gm.dispatch("consequence_continue", {})
	gs.reset_to_new_game()

## REP-D5: verifies the bound this build needed turned out to already
## exist. `_write_history` stores one compact row PER DEFINITION ID, not one
## per occurrence -- resolving a repeatable three separate times (three
## separate generations, three separate negotiate roads) increments the same
## row's `count` rather than growing an array or minting new keys. No new
## persisted field, no new cap: the umbrella's own section 9.4/20.1 shape
## ("a definition ID, outcome key, count, and last-resolved day answer every
## future question") already bounds this by construction.
## Not pinned to `dre_repeat_collection` specifically: PR C's own catalogue
## (D-18) means `repeatable_attempts` climbing past 1 makes
## `dre_repeat_collection_leaned_on` eligible too, so the seeded pick across
## three real rounds is not guaranteed to choose the same definition every
## time -- and should not need to, since the property under test
## (`_write_history` keeps one compact row per definition, `resolve()`/
## `fail()` both incrementing rather than appending) holds for whichever
## repeatable actually gets offered each round. Reads back the offered
## definition id each round rather than assuming one.
func _test_repeat_collection_history_stays_compact() -> void:
	# One fixture for the whole test, not per iteration -- resetting between
	# rounds would wipe the very accumulation this test exists to prove.
	# Any resolution (collected or not) increments `count` the same way
	# (`resolve()` and `fail()` both call `_write_history`), so the outcome
	# of each individual negotiate roll is not the thing under test here.
	#
	# `_cross_day()` alone drives generation here -- NOT a manual
	# `settle_night()` call on top of it. The real day-lifecycle already
	# calls `settle_night()` once per day-cross; calling it a second time by
	# hand in the same round briefly doubled up two simultaneous offers
	# (one from each call) and was the actual cause the first version of
	# this test chased before landing here.
	_junior_lender()
	_cross_day()
	var seen_before: Dictionary = {}
	for i in range(3):
		var live: Dictionary = _find_offer("dre_repeat_collection")
		if live.is_empty():
			live = _find_offer("dre_repeat_collection_leaned_on")
		a.check("round %d generated a fresh offer to resolve" % (i + 1), not live.is_empty())
		var definition_id := str(live.get("definition_id", ""))
		var before: int = int(seen_before.get(definition_id, 0))
		gm.dispatch("dre_collect_negotiate", {})
		a.eq_int("round %d's definition history row increments by exactly one" % (i + 1),
			int((gs.opportunity_history[definition_id] as Dictionary)["count"]), before + 1)
		seen_before[definition_id] = before + 1
		_cross_day()
	gs.reset_to_new_game()

func _test_repeat_collection_expiry() -> void:
	_junior_lender()
	_opportunities().settle_night(gs.day)
	var deadline: int = int(_find_offer("dre_repeat_collection")["deadline_day"])
	gs.day = deadline + 1
	_opportunities().settle_night(gs.day)
	a.eq_bool("an unaccepted repeatable expires past its own window",
		_offer_exists_any("dre_repeat_collection"), false)
	a.eq_str("recorded expired, not failed or completed",
		str((gs.opportunity_history["dre_repeat_collection"] as Dictionary)["outcome"]),
		"expired")
	a.eq_bool("collect_blocker refuses once the offer is gone",
		_collector().collect_blocker().is_empty(), false)
	gs.reset_to_new_game()

# --- 16c. PR C's catalogue: gating, the errand, the retry loop (D-18) --------

func _test_repeatable_attempts_requirement() -> void:
	var req := preload("res://systems/requirements.gd").new()

	var missing := req.evaluate_requirement(
		{"type": "repeatable_attempts_min", "min": 1}, {})
	a.eq_bool("an absent attempt count fails closed", bool(missing["ok"]), false)

	var below := req.evaluate_requirement(
		{"type": "repeatable_attempts_min", "min": 3}, {"repeatable_attempts": 2})
	a.eq_bool("2 attempts fails a 3-attempt requirement", bool(below["ok"]), false)

	var at := req.evaluate_requirement(
		{"type": "repeatable_attempts_min", "min": 3}, {"repeatable_attempts": 3})
	a.eq_bool("3 attempts clears a 3-attempt requirement", bool(at["ok"]), true)

## `repeatable_attempts` sums `count` across every repeatable's own history
## row (D-18) -- proven directly against `opportunities.gd`'s own computed
## fact rather than by playing enough rounds to change eligibility, which
## `_test_repeat_collection_generation` and the history-compactness test
## above already exercise for real.
func _test_repeatable_attempts_fact() -> void:
	_junior_lender()
	a.eq_int("zero attempts before anything has ever resolved",
		int(_opportunities()._facts()["repeatable_attempts"]), 0)
	gs.opportunity_history["dre_repeat_collection"] = {"outcome": "failed", "count": 2, "last_resolved_day": 1}
	gs.opportunity_history["dre_repeat_errand"] = {"outcome": "completed", "count": 1, "last_resolved_day": 1}
	a.eq_int("sums count across every repeatable definition, not just one",
		int(_opportunities()._facts()["repeatable_attempts"]), 3)
	gs.reset_to_new_game()

func _test_repeat_collection_leaned_on_gated_on_attempts() -> void:
	_junior_lender()
	_opportunities().settle_night(gs.day)
	a.eq_bool("the leaned-on variant is not yet eligible with zero attempts",
		_offer_exists_any("dre_repeat_collection_leaned_on"), false)

	_junior_lender()
	gs.opportunity_history["dre_repeat_collection"] = {"outcome": "failed", "count": 1, "last_resolved_day": 1}
	_opportunities().settle_night(gs.day)
	a.eq_bool("the base collection is not re-offered with the leaned-on "
		+ "variant now sharing eligibility -- both are equally live candidates, "
		+ "only one generates",
		gs.opportunity_offers.size() <= 1, true)
	gs.reset_to_new_game()

func _test_repeat_premium_gated_on_three_attempts() -> void:
	_junior_lender()
	gs.opportunity_history["dre_repeat_collection"] = {"outcome": "failed", "count": 2, "last_resolved_day": 1}
	_opportunities().settle_night(gs.day)
	a.eq_bool("the premium tier is not yet eligible at 2 attempts",
		_offer_exists_any("dre_repeat_premium"), false)

	_junior_lender()
	gs.opportunity_history["dre_repeat_collection"] = {"outcome": "failed", "count": 3, "last_resolved_day": 1}
	# Force the premium pick deterministically by making it the ONLY
	# eligible candidate -- the base collection and the leaned-on variant
	# are both still requirement-eligible at 3 attempts too, and this test
	# is about the gate, not about which of three equally-eligible
	# candidates a seeded pick happens to choose.
	gs.opportunity_offers = [
		{"instance_id": 90, "definition_id": "dre_repeat_collection", "state": "offered",
			"source_context": {}, "deadline_day": -1},
		{"instance_id": 91, "definition_id": "dre_repeat_collection_leaned_on", "state": "offered",
			"source_context": {}, "deadline_day": -1},
	]
	_opportunities().settle_night(gs.day)
	a.eq_bool("the premium tier offers itself once 3 attempts and the other "
		+ "two slots are already spoken for", _offer_exists_any("dre_repeat_premium"), true)
	gs.reset_to_new_game()

func _test_repeat_errand_lifecycle() -> void:
	# No reachable district: the fresh-run default (only Spenard unlocked)
	# leaves the errand's own candidate pool empty, so it correctly never
	# offers rather than naming an unreachable destination.
	_junior_lender()
	_opportunities().settle_night(gs.day)
	a.eq_bool("the errand does not offer with no unlocked destination",
		_offer_exists_any("dre_repeat_errand"), false)

	_junior_lender()
	gs.districts_unlocked = ["north_star_lot", "downtown"]
	# The base collection and the leaned-on variant are ALSO eligible at
	# tier 4 with zero attempts -- without excluding them, a seeded pick
	# landing on either one first (both always succeed) would return before
	# the errand is ever tried, and this test is about the errand
	# specifically, not about which of three eligible templates a seeded
	# pick happens to favor. Two placeholders, not three: the premium tier
	# is already naturally ineligible (needs 3 attempts, there are zero),
	# and filling all three non-errand slots would trip the 3-cap itself
	# and block generation entirely, errand included.
	gs.opportunity_offers = [
		{"instance_id": 90, "definition_id": "dre_repeat_collection", "state": "offered",
			"source_context": {}, "deadline_day": -1},
		{"instance_id": 91, "definition_id": "dre_repeat_collection_leaned_on", "state": "offered",
			"source_context": {}, "deadline_day": -1},
	]
	_opportunities().settle_night(gs.day)
	var offer: Dictionary = _find_offer("dre_repeat_errand")
	a.eq_bool("the errand offers itself once a destination is reachable",
		not offer.is_empty(), true)
	a.eq_str("picks the one reachable non-home district",
		str((offer.get("source_context", {}) as Dictionary).get("district_id", "")), "downtown")
	a.eq_int("a 3-day window from the offer",
		int(offer["deadline_day"]), int(offer["offered_day"]) + 3)

	# 3 offers on the board through this point: the two placeholders above
	# plus the real errand -- the placeholders are never touched by any of
	# what follows, so they stay a constant +2 on every count below.
	var cash_before: int = gs.cash
	_opportunities().reconcile("travel", {"district_id": "airport_industrial"}, {"ok": true})
	a.eq_int("traveling somewhere else does not settle it",
		gs.opportunity_offers.size(), 3)
	a.eq_int("and pays nothing", gs.cash, cash_before)

	_opportunities().reconcile("travel", {"district_id": "downtown"}, {"ok": false})
	a.eq_int("a refused travel (result.ok false) does not settle it either",
		gs.opportunity_offers.size(), 3)

	# A real dispatch from here, not a direct reconcile() call: Exposure's
	# `record_observation` refuses outside a live dispatch (the same
	# dispatch-guard discipline `_test_a_reminder_offer_and_disposition_
	# gate`'s own comment notes above), so the completion effect's ledger
	# write needs the genuine `GameManager.dispatch()` path to prove out.
	# `travel` also charges its own $5 fare ahead of the errand's $70 credit,
	# a real cost this assertion accounts for rather than hides.
	gm.dispatch("travel", {"district_id": "downtown"})
	a.eq_int("arriving at the named district settles it, leaving only the "
		+ "two untouched placeholders", gs.opportunity_offers.size(), 2)
	a.eq_str("recorded completed",
		str((gs.opportunity_history["dre_repeat_errand"] as Dictionary)["outcome"]), "completed")
	a.eq_int("the authored $%d fee lands net of travel's own $5 fare" % REPEAT_CONTRACTS.ERRAND_FEE,
		gs.cash - cash_before, REPEAT_CONTRACTS.ERRAND_FEE - 5)
	var found_errand := false
	for row in get_node("/root/Exposure").ledger_of("dre"):
		if str((row as Dictionary).get("event", "")) == "ran_an_errand":
			found_errand = true
	a.eq_bool("Dre's own ledger records the errand", found_errand, true)
	gs.reset_to_new_game()

## The generation retry loop (D-18): a pick that turns out to be a dud must
## not silently burn the night's one generation slot when a different
## eligible template could have used it instead.
## Finds a day where the FIRST seeded pick, against the exact two-candidate
## pool this test's own fixture produces (`dre_repeat_collection` then
## `dre_repeat_errand`, dict-iteration order), lands on the errand -- the one
## that is guaranteed to be a dud with no unlocked destination. Without
## forcing this, the test can pass by accident on a day whose first pick
## happens to be the collection outright, exercising nothing about the
## retry loop at all (confirmed: this is exactly what the first version of
## this test did, and sabotaging the retry loop away did not turn it red).
func _find_errand_first_pick_day() -> int:
	var rng := get_node("/root/RngManager")
	for day in range(1, 200):
		if rng.seeded_int_range(gs.run_seed, "%d:repeat_pick:2" % day, 0, 1) == 1:
			return day
	return -1

func _test_generate_repeatables_retries_past_a_dud() -> void:
	var day := _find_errand_first_pick_day()
	a.check("a day where the errand is the first pick exists in the search window",
		day > 0)
	_junior_lender()
	gs.day = day
	# No unlocked destination -- the errand is requirement-eligible (tier 4
	# only) but will always be a dud here. The base collection is the only
	# OTHER eligible candidate at zero attempts, so a correct retry loop
	# lands on it once the errand's own attempt fails -- and this day is
	# chosen specifically so the errand IS what gets tried first.
	_opportunities().settle_night(gs.day)
	a.eq_bool("a dud errand pick does not leave the night empty -- the base "
		+ "collection still generates", _offer_exists_any("dre_repeat_collection"), true)
	a.eq_int("and nothing else snuck in alongside it",
		gs.opportunity_offers.size(), 1)
	gs.reset_to_new_game()

# --- 17. the player-default ultimatum (PR D) ---------------------------------

## Walks a fresh loan all the way to the point `dre_lender.gd`'s old flat
## timer used to auto-suspend at, then a bounded few nights further --
## `OVERDUE_RESPONSE_DELAY_DAYS` more settles -- for `dre_collector.gd` to
## actually open the ultimatum. Bounded rather than an exact day count on
## purpose: the arithmetic is easy to get one settle off by rewriting it
## from scratch in a comment, and a bounded loop proves the real behaviour
## instead of a second copy of it.
func _reach_ultimatum() -> void:
	_trusted_customer()
	gm.dispatch("dre_borrow", {})
	while str(gs.dre_account.get("status", "")) != "overdue":
		_cross_day()
	for _i in range(6):
		if _consequence().has_active():
			break
		_cross_day()

func _test_player_default_ultimatum_pay_now() -> void:
	_reach_ultimatum()
	a.eq_bool("the overdue account eventually opens Dre's own ultimatum",
		_consequence().has_active(), true)
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	a.eq_str("with exactly the two authored choices",
		str(decision.get("allowed_choices", [])), str(["pay_now", "stall"]))
	_fund(5000)
	a.eq_bool("paying now dispatches",
		gm.dispatch("resolve_consequence_choice", {"choice_id": "pay_now"}), true)
	a.eq_str("and the account clears", str(gs.dre_account.get("status", "")), "clear")
	gm.dispatch("consequence_continue", {})
	gs.reset_to_new_game()

func _test_player_default_ultimatum_stall_suspends() -> void:
	_reach_ultimatum()
	a.eq_bool("stalling is refused nothing -- no cash check on the choice that "
		+ "does not need one", _collector().choice_blocked("stall").is_empty(), true)
	a.eq_bool("stalling dispatches",
		gm.dispatch("resolve_consequence_choice", {"choice_id": "stall"}), true)
	a.eq_str("and the account actually suspends",
		str(gs.dre_account.get("status", "")), "suspended")
	var exposure := get_node("/root/Exposure")
	var found_walked := false
	for row in exposure.ledger_of("dre"):
		if str((row as Dictionary)["event"]) == "walked_a_debt":
			found_walked = true
	a.eq_bool("walked_a_debt still fires, now from the real encounter",
		found_walked, true)
	gm.dispatch("consequence_continue", {})
	gs.reset_to_new_game()

# --- 18. The Book, earned (PR E) ---------------------------------------------

## The build prompt's own PR E test requirement: fresh run -> Juan -> borrow
## -> repay -> collection -> sponsored loan -> Book open, driven for real
## rather than by direct state assignment, since every earlier test in this
## file proves one STAGE works and this is the only one that proves the
## whole chain actually connects -- that reaching Collector through a real
## A Reminder success leaves the account in a shape `dre_book_sponsorship`'s
## own requirements actually evaluate true against, and so on back to Juan.
##
## The sponsored note's own settlement is a seeded roll like any other Book
## note (`shark.gd::settle_night`), so this drives it with the same bounded
## "cross days until the state changes" technique `_reach_ultimatum` uses
## rather than searching for a specific outcome -- and handles either branch
## it lands on, the same way `_test_a_reminder_hard_road_press` handles
## PRESS's four unsearchable tiers, since `_resolve_sponsorship` fires on
## repaid OR enforced alike (not extended -- see shark.gd's own header).
func _test_full_arc_integration_drive() -> void:
	var access := get_node("/root/SurfaceVisibility")
	_fresh()
	gs.day = 2
	gs.cash = 50
	_cross_day()
	a.eq_bool("Juan's text fires under DRE-D1's own conditions",
		gs.dre_intro_offered, true)
	a.eq_bool("seeking Dre out dispatches", gm.dispatch("dre_seek_out", {}), true)
	a.eq_int("Borrower access earned", int(gs.dre_access_tier), 1)

	a.eq_bool("First Money borrows", gm.dispatch("dre_borrow", {}), true)
	_fund(5000)
	gs.day = int(gs.dre_account["due_day"])
	a.eq_bool("and repays on time", gm.dispatch("dre_repay", {}), true)
	a.eq_int("Trusted Customer earned", int(gs.dre_access_tier), 2)

	var negotiate := _find_negotiate_day(["clean", "messy"])
	a.check("a negotiate success day/slot exists in the search window",
		not negotiate.is_empty())
	gs.day = int(negotiate.get("day", gs.day))
	gs.time_slots_today = int(negotiate.get("slot", 0))
	_opportunities()._maybe_offer("dre_a_reminder")
	a.eq_bool("A Reminder negotiates clean",
		gm.dispatch("dre_collect_negotiate", {}), true)
	a.eq_int("Collector earned", int(gs.dre_access_tier), 3)

	a.eq_bool("the Book route stays closed before the sponsorship offer exists",
		access.route_allowed("res://ui/screens/shark.tscn"), false)
	_opportunities()._maybe_offer("dre_book_sponsorship")
	a.eq_bool("Dre's sponsorship offer is live",
		_opportunities().is_offered_or_active("dre_book_sponsorship"), true)
	a.eq_bool("which opens the Book route early, before tier 4",
		access.route_allowed("res://ui/screens/shark.tscn"), true)

	var shark_sys: Object = gm.system("shark")
	a.eq_str("Priya is fundable the moment the sponsorship is live",
		shark_sys.fund_blocker("priya", 150), "")
	var loan_id: int = int(gs.shark_next_loan_id)
	a.eq_bool("funding Priya dispatches and accepts the milestone",
		gm.dispatch("fund_shark", {"borrower_id": "priya", "amount": 150, "term": 4}),
		true)
	a.eq_bool("the milestone is active now, not yet resolved",
		gs.opportunity_history.has("dre_book_sponsorship"), false)

	for _i in range(10):
		if str(shark_sys.loan_by_id(loan_id).get("status", "")) != "active":
			break
		_cross_day()
	var final_status := str(shark_sys.loan_by_id(loan_id).get("status", ""))
	if final_status == "defaulted":
		a.eq_bool("a defaulted sponsored note still resolves the milestone on enforce",
			gm.dispatch("enforce_shark", {"loan_id": loan_id}), true)
		final_status = "enforced"
	a.check("Priya's note reached a terminal state the milestone resolves on",
		final_status in ["repaid", "enforced"])
	a.eq_str("the sponsorship milestone completed",
		str((gs.opportunity_history.get("dre_book_sponsorship", {}) as Dictionary)
			.get("outcome", "")), "completed")
	a.eq_int("Junior Lender earned", int(gs.dre_access_tier), 4)
	a.eq_bool("and the Book route stays open on the ordinary tier now",
		access.route_allowed("res://ui/screens/shark.tscn"), true)
	gs.reset_to_new_game()

## "Gate opens only through the arc" (PR E test requirement): Collector alone
## is not enough, the sponsorship offer alone IS enough before tier 4, and
## Junior Lender opens it with no sponsorship involved at all -- the three
## facts `dre_book_visible` (surface_visibility.gd) is built from.
func _test_book_gate_opens_only_through_the_arc() -> void:
	var access := get_node("/root/SurfaceVisibility")
	_trusted_customer()
	gs.dre_access_tier = 3
	a.eq_bool("Collector alone, no sponsorship offered, keeps the Book closed",
		access.route_allowed("res://ui/screens/shark.tscn"), false)
	_opportunities()._maybe_offer("dre_book_sponsorship")
	a.eq_bool("the sponsorship offer alone opens it, before tier 4",
		access.route_allowed("res://ui/screens/shark.tscn"), true)

	_trusted_customer()
	gs.dre_access_tier = 4
	a.eq_bool("and Junior Lender opens it with no sponsorship involved at all",
		access.route_allowed("res://ui/screens/shark.tscn"), true)
	gs.reset_to_new_game()

## "Locked borrowers refuse" (PR E test requirement): the sponsorship
## exception is exactly one borrower wide, never a second, wider door.
func _test_locked_borrowers_refuse() -> void:
	_trusted_customer()
	gs.dre_access_tier = 3
	var shark_sys: Object = gm.system("shark")
	a.eq_bool("every borrower reads locked before any sponsorship exists",
		shark_sys.is_locked("nora"), true)
	a.eq_bool("Priya too, before Dre has actually vouched for her",
		shark_sys.is_locked("priya"), true)
	a.check("funding a locked borrower is refused with a reason",
		not shark_sys.fund_blocker("nora", 50).is_empty())

	_opportunities()._maybe_offer("dre_book_sponsorship")
	a.eq_bool("the sponsorship opens Priya specifically",
		shark_sys.is_locked("priya"), false)
	a.eq_bool("but nobody else -- the exception is exactly one borrower wide",
		shark_sys.is_locked("nora"), true)
	a.check("funding Nora still refuses at Collector, sponsorship notwithstanding",
		not shark_sys.fund_blocker("nora", 50).is_empty())
	_fund(500)
	a.eq_str("funding Priya is not refused", shark_sys.fund_blocker("priya", 150), "")
	gs.reset_to_new_game()

## "Bond term parity" (PR E test requirement): the pinned-neutral bonded term
## goes live at Collector, per the ruling above `default_probability`'s own
## header.
func _test_bond_term_parity() -> void:
	_trusted_customer()
	var shark_sys: Object = gm.system("shark")
	# Leon, high risk, at the top amount/term bumps -- chosen so neither
	# reading is anywhere near the [0.03, 0.82] clamp. Nora's low risk was
	# tried first and clamped the BONDED reading to the 0.03 floor, which
	# understated the delta rather than testing it.
	var loan := {"borrower_id": "leon", "amount": 500, "term": 2}
	gs.dre_access_tier = 2
	var unbonded: float = shark_sys.default_probability(loan)
	gs.dre_access_tier = 3
	var bonded: float = shark_sys.default_probability(loan)
	a.check("the Collector bond discount actually lowers the odds",
		bonded < unbonded)
	a.near("by exactly 0.08 off the unbonded reading", unbonded - bonded, 0.08)
	gs.dre_access_tier = 4
	var also_bonded: float = shark_sys.default_probability(loan)
	a.near("Junior Lender keeps the same discount as Collector", also_bonded, bonded)
	gs.reset_to_new_game()

func _test_restitution_then_penance() -> void:
	_reach_ultimatum()
	gm.dispatch("resolve_consequence_choice", {"choice_id": "stall"})
	gm.dispatch("consequence_continue", {})
	a.eq_bool("suspended and nothing pending yet",
		gs.dre_pending_penance, false)

	_fund(5000)
	a.eq_bool("paying off a suspended account still succeeds -- D-4/D-7, "
		+ "unchanged by PR D", gm.dispatch("dre_repay", {}), true)
	a.eq_str("and clears the account the same as any other repay",
		str(gs.dre_account.get("status", "")), "clear")
	a.eq_bool("but this time it leaves the penance latch behind",
		gs.dre_pending_penance, true)

	_opportunities()._maybe_offer("dre_penance")
	a.eq_str("penance is not blocked now that it is pending",
		gm.system("dre").penance_blocker(), "")
	a.eq_bool("making it right dispatches", gm.dispatch("dre_do_penance", {}), true)
	a.eq_bool("and clears the latch", gs.dre_pending_penance, false)
	a.eq_str("dre_penance is recorded completed",
		str((gs.opportunity_history["dre_penance"] as Dictionary)["outcome"]), "completed")
	gs.reset_to_new_game()

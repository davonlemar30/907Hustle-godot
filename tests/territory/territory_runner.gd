extends Node
## FS-002.1 — freeze inherited Territory behaviour (`86bbj1jn9`).
##
## ## This is not a recording exercise
##
## The ticket reads like one: nine behaviours, write them down before FS-002.3
## moves the state underneath them. Audited against the existing suite, four of
## the nine had any coverage at all, and the gaps were not the small ones:
##
##   - `post_soldier` and `pull_soldier` are dispatched **nowhere** in 20,288
##     lines of parity runner. Two of Territory's five actions had never been
##     driven.
##   - `block_income()` is asserted **nowhere**.
##   - `SOLDIER_INCOME_DIMINISH` (0.85) — the rule `territory.gd`'s own header
##     calls "the shape of the decision" — appears in **zero checks**.
##   - The `settler` economy profile never posts a second soldier, so the
##     diminishing curve has never executed in a measured run either. The 636%
##     that profile reports is a curve that never bent.
##
## So this file is mostly writing the missing 80%, not transcribing the
## existing 20%. The surface is genuinely small — `territory.gd` is 240 lines
## with no hidden state — which is what makes that a coverage gap rather than
## archaeology.
##
## ## Everything is derived, nothing is memorised
##
## Standing rule 8. No expected income is a literal: every one is computed here
## from `gs.SOLDIER_INCOME_DIMINISH` and the block's own authored `earning`, by
## the same rule `block_income()` claims to implement. If somebody re-authors a
## corner's earning, these checks follow it. If somebody changes the DIMINISH
## constant, they fail — which is the sabotage below, and the point.
##
## The one thing deliberately NOT derived is the shape of the rule itself. The
## expected value is built with an explicit `pow(diminish, i)` loop rather than
## by calling `block_income()`, because a fixture that calls the function it is
## testing proves only that the function is consistent with itself.
##
## ## What PR 3 will break here, on purpose
##
## `held_blocks` is retired as ownership truth in FS-002.3 and `spenard_blocks`
## is deleted outright. The checks below reach through `gs.holds_block()`,
## `gs.block_by_id()` and the five dispatched actions wherever they can, because
## those are the seams that survive. Where a check reads `gs.held_blocks`
## directly it is marked, and it is marked because it is a migration site.

const ASSERTS := preload("res://tests/territory/territory_asserts.gd")

## The check floor. See `_ready()` for why a count is a gate.
const MIN_CHECKS := 134

var a: RefCounted
var gs: Node
var gm: Node

## The cheapest and dearest authored corners, by id. Named rather than indexed
## so a re-ordered table does not silently change what is under test.
const CHEAPEST := "spenard_rec_lot"
const DEAREST := "northern_lights_motels"

func _ready() -> void:
	a = ASSERTS.new()
	gs = get_node("/root/GameState")
	gm = get_node("/root/GameManager")

	_test_claim()
	_test_abandon()
	_test_post_and_pull()
	_test_recruit_and_capacity()
	_test_income_curve()
	_test_nightly_heat()
	_test_deshawn_multiplier()
	_test_soldier_conservation()
	_test_capacity_invariant()
	_test_market_cursor_untouched()
	_test_settlement_order_reason()
	_test_save_round_trip()
	_test_screen_reads()

	# The floor, in the shape `parity_runner.gd` uses it. A suite whose checks
	# quietly stop RUNNING still prints PASS — an early `return` in a test
	# function, a renamed action every dispatch now fails on — and the count is
	# the only thing that notices. Raised in the same PR that raises the count.
	a.check("the suite ran its full complement (%d checks, floor %d)"
		% [a.checks, MIN_CHECKS], a.checks >= MIN_CHECKS)

	a.report("territory", get_tree())

## A run with money and no corners. Every test starts from one.
##
## Cash is set on the three fields together rather than through the wallet: this
## is initialization, which is one of the audit's named exceptions, and a test
## that spent a slot earning $5,000 first would be testing the wrong thing.
func _fresh(cash: int = 5000, idle: int = 0) -> void:
	gs.street_name = "Territory"
	gs.reset_to_new_game()
	gs.cash = cash
	gs.clean_cash = cash
	gs.dirty_cash = 0
	gs.soldiers_idle = idle

func _block(id: String) -> Dictionary:
	return gs.block_by_id(id)

func _terr() -> Object:
	return gm.system("territory")

# --- claiming ---------------------------------------------------------------

func _test_claim() -> void:
	# The idle-soldier requirement. Canon requires a free soldier to occupy the
	# corner as it is taken, and this is the arm sabotage #2 deletes.
	_fresh(5000, 0)
	a.eq_bool("a claim with no free soldier is refused",
		gm.dispatch("claim_block", {"block_id": CHEAPEST}), false)
	a.eq_bool("and the corner is not held", gs.holds_block(CHEAPEST), false)
	a.check("the blocker says why",
		_terr().claim_blocker(CHEAPEST).contains("soldier"))

	# Cost, read off the authored row rather than typed here.
	var cost: int = int(_block(CHEAPEST)["claim_cost"])
	_fresh(cost - 1, 1)
	a.eq_bool("a claim one dollar short is refused",
		gm.dispatch("claim_block", {"block_id": CHEAPEST}), false)

	_fresh(cost, 1)
	a.eq_bool("a claim with exactly the cost and a free soldier lands",
		gm.dispatch("claim_block", {"block_id": CHEAPEST}), true)
	a.eq_int("and it cost exactly the authored claim cost", int(gs.cash), 0)
	a.eq_bool("and the corner is held", gs.holds_block(CHEAPEST), true)
	# The claiming soldier goes ONTO the corner — it is not a fee paid in
	# soldiers, it is the soldier standing there.
	a.eq_int("the claiming soldier is posted, not spent",
		int((gs.held_blocks[CHEAPEST] as Dictionary).get("soldiers", 0)), 1)
	a.eq_int("and no longer idle", int(gs.soldiers_idle), 0)

	a.eq_bool("claiming the same corner twice is refused",
		gm.dispatch("claim_block", {"block_id": CHEAPEST}), false)
	a.eq_bool("claiming a corner that does not exist is refused",
		gm.dispatch("claim_block", {"block_id": "no_such_corner"}), false)

	# Canon's neutral-claim cost ordering: every authored corner's claim cost
	# tracks its earning. Derived from the table, so re-authoring a row keeps
	# this honest rather than breaking it.
	var rising := true
	for i in range(1, gs.spenard_blocks.size()):
		var prev: Dictionary = gs.spenard_blocks[i - 1]
		var cur: Dictionary = gs.spenard_blocks[i]
		if int(cur["claim_cost"]) <= int(prev["claim_cost"]) \
				or int(cur["earning"]) <= int(prev["earning"]):
			rising = false
	a.check("the authored table rises in both cost and earning together", rising)

# --- abandoning -------------------------------------------------------------

func _test_abandon() -> void:
	_fresh(5000, 1)
	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	var cash_after_claim: int = int(gs.cash)

	a.eq_bool("abandoning a corner you do not hold is refused",
		gm.dispatch("abandon_block", {"block_id": DEAREST}), false)

	a.eq_bool("abandoning yours succeeds",
		gm.dispatch("abandon_block", {"block_id": CHEAPEST}), true)
	# The soldiers come back; the claim cost does not. This is the arm sabotage
	# #3 removes.
	a.eq_int("the soldier comes back", int(gs.soldiers_idle), 1)
	a.eq_int("the claim cost does not", int(gs.cash), cash_after_claim)
	a.eq_bool("and the corner is no longer held", gs.holds_block(CHEAPEST), false)

	# More than one posted soldier all come back together.
	#
	# Two corners held, so giving one back still leaves a cap of 4 for a roster
	# of 4 and the return is not confounded by the discharge rule below.
	_fresh(100000, 4)
	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	gm.dispatch("claim_block", {"block_id": DEAREST})
	gm.dispatch("post_soldier", {"block_id": DEAREST})
	gm.dispatch("post_soldier", {"block_id": DEAREST})
	a.eq_int("three posted on the dear corner",
		int((gs.held_blocks[DEAREST] as Dictionary)["soldiers"]), 3)
	a.eq_int("and none left idle", int(gs.soldiers_idle), 0)
	gm.dispatch("abandon_block", {"block_id": DEAREST})
	a.eq_int("all three come back idle", int(gs.soldiers_idle), 3)
	a.capacity_respected("and the roster still fits the remaining corner", gs)

	# `86bbjxtb6`, from the other side: when giving a corner back drops the cap
	# BELOW the roster, the overhang walks. Same setup, but the last corner goes
	# too — a cap of 2 cannot carry 4.
	gm.dispatch("abandon_block", {"block_id": CHEAPEST})
	a.eq_int("no corners left", gs.held_blocks.size(), 0)
	a.eq_int("and the roster is cut to the base capacity rather than exceeding it",
		gs.soldiers_total(), int(gs.SOLDIER_BASE_CAPACITY))
	a.capacity_respected("after the last corner goes back", gs)

# --- posting and pulling ----------------------------------------------------
#
# Neither action is dispatched anywhere in the parity runner. These are the
# first checks in the build to drive them.

func _test_post_and_pull() -> void:
	_fresh(5000, 2)
	a.eq_bool("posting to a corner you do not hold is refused",
		gm.dispatch("post_soldier", {"block_id": CHEAPEST}), false)

	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	a.eq_int("the claim consumed one of the two", int(gs.soldiers_idle), 1)

	a.eq_bool("posting a free soldier lands",
		gm.dispatch("post_soldier", {"block_id": CHEAPEST}), true)
	a.eq_int("two are posted", int((gs.held_blocks[CHEAPEST] as Dictionary)["soldiers"]), 2)
	a.eq_int("and none are free", int(gs.soldiers_idle), 0)

	a.eq_bool("posting with nobody free is refused",
		gm.dispatch("post_soldier", {"block_id": CHEAPEST}), false)
	a.eq_str("and the blocker says so", _terr().post_blocker(CHEAPEST), "Nobody free.")

	a.eq_bool("pulling one back lands", gm.dispatch("pull_soldier", {"block_id": CHEAPEST}), true)
	a.eq_int("one posted", int((gs.held_blocks[CHEAPEST] as Dictionary)["soldiers"]), 1)
	a.eq_int("one free", int(gs.soldiers_idle), 1)

	a.eq_bool("pulling the last one lands", gm.dispatch("pull_soldier", {"block_id": CHEAPEST}), true)
	a.eq_bool("pulling from an empty corner is refused",
		gm.dispatch("pull_soldier", {"block_id": CHEAPEST}), false)
	a.eq_bool("pulling from a corner you do not hold is refused",
		gm.dispatch("pull_soldier", {"block_id": DEAREST}), false)
	# A corner can be held with nobody on it. That is legal, and it is the
	# liability the whole design turns on.
	a.eq_bool("a corner emptied by pulling is still held", gs.holds_block(CHEAPEST), true)

# --- recruiting and the cap -------------------------------------------------

func _test_recruit_and_capacity() -> void:
	_fresh(5000, 0)
	a.eq_int("a fresh run's capacity is the base",
		gs.soldier_capacity(), int(gs.SOLDIER_BASE_CAPACITY))

	var cost: int = int(gs.SOLDIER_RECRUIT_COST)
	_fresh(cost - 1, 0)
	a.eq_bool("recruiting one dollar short is refused", gm.dispatch("recruit_soldier", {}), false)

	_fresh(cost, 0)
	a.eq_bool("recruiting with exactly the cost lands", gm.dispatch("recruit_soldier", {}), true)
	a.eq_int("and it cost exactly the authored recruit cost", int(gs.cash), 0)
	a.eq_int("and the soldier is idle", int(gs.soldiers_idle), 1)

	# The cap, and that it moves with held corners rather than being fixed.
	_fresh(100000, 0)
	while gm.dispatch("recruit_soldier", {}):
		pass
	a.eq_int("with no corners the roster fills to the base capacity",
		gs.soldiers_total(), int(gs.SOLDIER_BASE_CAPACITY))
	a.eq_str("and the blocker explains the cap, not the money",
		_terr().recruit_soldier_blocker(), "No room for another. Hold more corners first.")

	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	a.eq_int("one corner raises the cap by the authored per-block amount",
		gs.soldier_capacity(),
		int(gs.SOLDIER_BASE_CAPACITY) + int(gs.SOLDIER_CAPACITY_PER_BLOCK))
	while gm.dispatch("recruit_soldier", {}):
		pass
	a.eq_int("and the roster fills to the new cap",
		gs.soldiers_total(), gs.soldier_capacity())
	a.capacity_respected("after filling to the cap", gs)

# --- the diminishing curve --------------------------------------------------
#
# `SOLDIER_INCOME_DIMINISH` appears in zero checks anywhere else in the build,
# and the profile that measures Territory never posts a second soldier — so
# until this function, the curve had never executed in anything that asserted.

func _expected_income(block_id: String, soldiers: int) -> int:
	var earning: float = float(_block(block_id)["earning"])
	var diminish: float = float(gs.SOLDIER_INCOME_DIMINISH)
	var total: float = 0.0
	for i in range(soldiers):
		total += earning * pow(diminish, i)
	return int(round(total))

func _test_income_curve() -> void:
	# 0 through 3 soldiers on one corner, against the rule rather than against
	# remembered numbers.
	for n in range(0, 4):
		_fresh(100000, 0)
		# Capacity is 2 + 2 per block, so three on one corner needs the room.
		gs.soldiers_idle = 8
		gm.dispatch("claim_block", {"block_id": DEAREST})
		for _i in range(n - 1 if n > 0 else 0):
			gm.dispatch("post_soldier", {"block_id": DEAREST})
		if n == 0:
			gm.dispatch("pull_soldier", {"block_id": DEAREST})
		a.eq_int("%d posted is %d soldiers on the corner" % [n, n],
			int((gs.held_blocks[DEAREST] as Dictionary)["soldiers"]), n)
		a.eq_int("%d soldiers earn the curve's answer" % n,
			int(_terr().block_income(DEAREST)), _expected_income(DEAREST, n))

	# The constant itself, pinned as a VALUE.
	#
	# Rule 8 says derive through the rule rather than memorising the answer, and
	# every expectation above does. But `_expected_income()` reads
	# `SOLDIER_INCOME_DIMINISH` from the same place `block_income()` does, so a
	# change to the constant moves the fixture and the code together and the
	# curve checks stay green — which is exactly what sabotage #1 demonstrated
	# on the first run of this file.
	#
	# So the constant is pinned here directly. It is canon
	# (`SOLDIER_INCOME_BASE_DIMINISH`, ported in Phase 3e) rather than this
	# port's own invention, which makes it oracle truth and therefore the one
	# number in this file that IS memorised, deliberately.
	a.near("the diminishing constant is canon's 0.85",
		float(gs.SOLDIER_INCOME_DIMINISH), 0.85)
	a.check("and it is a real discount, not a rounding artefact",
		float(gs.SOLDIER_INCOME_DIMINISH) > 0.0
			and float(gs.SOLDIER_INCOME_DIMINISH) < 1.0)

	# And the property that constant exists to produce: every additional soldier
	# on a corner earns strictly less than the one before. This is the rule the
	# header calls "the shape of the decision", and it fails for ANY diminish of
	# 1.0 or above regardless of what the fixture derives.
	var marginal_falls := true
	var previous: int = -1
	for n in range(1, 5):
		var marginal: int = _expected_income(DEAREST, n) - _expected_income(DEAREST, n - 1)
		if previous >= 0 and marginal >= previous:
			marginal_falls = false
		previous = marginal
	a.check("each soldier on a corner earns strictly less than the one before",
		marginal_falls)

	# The shape of the decision, stated as the header states it: two soldiers on
	# the Motel Row against one each on Motel Row and Fourth Avenue.
	#
	# Derived, not quoted. The header's "$185 vs $180" is true of today's table
	# and this asserts the RELATION, which is what the design turns on.
	var stacked: int = _expected_income(DEAREST, 2)
	var split: int = _expected_income(DEAREST, 1) + _expected_income("fourth_ave_strip", 1)
	a.check("stacking two on the best corner beats splitting them (%d vs %d)"
		% [stacked, split], stacked > split)
	a.check("but only just — the second soldier is worth less than the first",
		float(stacked - _expected_income(DEAREST, 1))
			< float(_expected_income(DEAREST, 1)))

	# `nightly_income()` is the sum over every held corner.
	_fresh(100000, 0)
	gs.soldiers_idle = 8
	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	gm.dispatch("claim_block", {"block_id": DEAREST})
	gm.dispatch("post_soldier", {"block_id": DEAREST})
	a.eq_int("nightly income sums every held corner",
		int(_terr().nightly_income()),
		_expected_income(CHEAPEST, 1) + _expected_income(DEAREST, 2))

	# A corner you do not hold earns nothing, and neither does one with nobody
	# on it.
	a.eq_int("a corner you do not hold earns nothing",
		int(_terr().block_income("minnesota_offramp")), 0)
	gm.dispatch("pull_soldier", {"block_id": CHEAPEST})
	a.eq_int("a held corner with nobody on it earns nothing",
		int(_terr().block_income(CHEAPEST)), 0)

# --- the heat of holding ----------------------------------------------------

func _test_nightly_heat() -> void:
	# "An empty corner you hold is still a corner people know is yours." This is
	# the arm sabotage #4 removes.
	_fresh(100000, 0)
	gs.soldiers_idle = 4
	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	gm.dispatch("pull_soldier", {"block_id": CHEAPEST})
	a.eq_int("the corner is empty", int((gs.held_blocks[CHEAPEST] as Dictionary)["soldiers"]), 0)
	a.near("an empty held corner still costs its authored heat",
		_terr().nightly_heat(), float(_block(CHEAPEST)["heat_exposure"]))

	gm.dispatch("claim_block", {"block_id": DEAREST})
	a.near("and nightly heat is the sum over every held corner, staffed or not",
		_terr().nightly_heat(),
		float(_block(CHEAPEST)["heat_exposure"]) + float(_block(DEAREST)["heat_exposure"]))

	_fresh(100000, 0)
	a.near("holding nothing costs no heat", _terr().nightly_heat(), 0.0)

	# And that settlement actually applies it.
	_fresh(100000, 0)
	gs.soldiers_idle = 2
	gm.dispatch("claim_block", {"block_id": DEAREST})
	gs.heat = 0.0
	var expected_heat: float = _terr().nightly_heat()
	_terr().settle_night(int(gs.day))
	a.near("settling the night applies the holding heat", float(gs.heat), expected_heat)

# --- Deshawn ----------------------------------------------------------------

func _test_deshawn_multiplier() -> void:
	# Territory heat routes through `HeatSystem.apply_gain`, which is the ONE
	# site that consults `crew.heat_multiplier()`. Deshawn damps corner heat the
	# same way he damps a stickup.
	for rank in [1, 2, 3]:
		_fresh(100000, 0)
		gs.soldiers_idle = 2
		gm.dispatch("claim_block", {"block_id": DEAREST})
		gs.crew_records["deshawn"] = {"recruited": true, "status": "active",
			"tier": rank, "loyalty": 5, "wage_due": 0}
		gs.heat = 0.0
		var raw: float = _terr().nightly_heat()
		var expected: float = raw * float(gs.curve_value_for_rank(
			gs.DESHAWN_HEAT_REDUCTION, rank, 1.0))
		_terr().settle_night(int(gs.day))
		a.near("Deshawn at rank %d damps corner heat by his authored curve" % rank,
			float(gs.heat), expected)

	# Without him, the raw figure lands unscaled.
	_fresh(100000, 0)
	gs.soldiers_idle = 2
	gm.dispatch("claim_block", {"block_id": DEAREST})
	gs.heat = 0.0
	var raw_only: float = _terr().nightly_heat()
	_terr().settle_night(int(gs.day))
	a.near("without Deshawn the raw holding heat lands unscaled",
		float(gs.heat), raw_only)

# --- the two invariants nothing asserted -------------------------------------

func _test_soldier_conservation() -> void:
	# Four soldiers and two corners: a cap of 6 carrying a roster of 4, so every
	# transition below is one the capacity rule has no opinion about and
	# conservation is measured on its own.
	_fresh(100000, 4)
	var roster: int = gs.soldiers_total()
	a.eq_int("the roster under test", roster, 4)
	a.soldiers_conserved("a fresh roster", gs, roster)

	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	a.soldiers_conserved("a claim moves a soldier, it does not spend one", gs, roster)

	gm.dispatch("post_soldier", {"block_id": CHEAPEST})
	a.soldiers_conserved("posting moves one", gs, roster)

	gm.dispatch("pull_soldier", {"block_id": CHEAPEST})
	a.soldiers_conserved("pulling moves it back", gs, roster)

	gm.dispatch("claim_block", {"block_id": DEAREST})
	gm.dispatch("post_soldier", {"block_id": DEAREST})
	a.soldiers_conserved("across two corners", gs, roster)
	a.capacity_respected("two corners carry this roster", gs)

	# Abandoning one of two: the cap falls to 4 and the roster is 4, so nothing
	# is discharged and the return is pure conservation.
	gm.dispatch("abandon_block", {"block_id": DEAREST})
	a.soldiers_conserved("abandoning returns exactly what was posted", gs, roster)
	a.no_negative_soldiers("after a full claim/post/pull/abandon cycle", gs)

	# Recruiting is the one action that legitimately changes the total, and it
	# needs the room: one corner held is a cap of 4 against a roster of 4, so
	# make room first by holding a second.
	gm.dispatch("claim_block", {"block_id": DEAREST})
	var before: int = gs.soldiers_total()
	a.eq_bool("there is room to recruit", gm.dispatch("recruit_soldier", {}), true)
	a.soldiers_conserved("recruiting adds exactly one", gs, before + 1)

func _test_capacity_invariant() -> void:
	# `86bbjxtb6`, as a permanent check. Hold three, recruit to the cap, give all
	# three back. The cap falls by 6 and the roster must fall with it.
	_fresh(100000, 3)
	for id in [CHEAPEST, "wash_and_go_lot", "minnesota_offramp"]:
		gm.dispatch("claim_block", {"block_id": id})
	while gm.dispatch("recruit_soldier", {}):
		pass
	a.capacity_respected("at the cap with three corners", gs)
	var at_cap: int = gs.soldiers_total()
	a.check("three corners genuinely raised the cap (%d soldiers)" % at_cap,
		at_cap > int(gs.SOLDIER_BASE_CAPACITY))

	for id in [CHEAPEST, "wash_and_go_lot", "minnesota_offramp"]:
		gm.dispatch("abandon_block", {"block_id": id})
	a.eq_int("no corners left", gs.held_blocks.size(), 0)
	a.capacity_respected("after giving every corner back", gs)
	a.no_negative_soldiers("after giving every corner back", gs)
	a.eq_int("and the roster is exactly the base capacity",
		gs.soldiers_total(), int(gs.SOLDIER_BASE_CAPACITY))

# --- rule 2 -----------------------------------------------------------------

func _test_market_cursor_untouched() -> void:
	# "Territory randomness must not advance the market xorshift stream."
	# Territory draws no randomness at all today, which is exactly the state
	# worth pinning before FS-002.4 and .5 add contested takeovers and warfare.
	_fresh(100000, 0)
	gs.soldiers_idle = 6
	a.market_cursor_unchanged("claiming does not move the market stream", gs,
		func() -> void: gm.dispatch("claim_block", {"block_id": DEAREST}))
	a.market_cursor_unchanged("posting does not move the market stream", gs,
		func() -> void: gm.dispatch("post_soldier", {"block_id": DEAREST}))
	a.market_cursor_unchanged("pulling does not move the market stream", gs,
		func() -> void: gm.dispatch("pull_soldier", {"block_id": DEAREST}))
	a.market_cursor_unchanged("recruiting does not move the market stream", gs,
		func() -> void: gm.dispatch("recruit_soldier", {}))
	a.market_cursor_unchanged("nightly settlement does not move the market stream", gs,
		func() -> void: _terr().settle_night(int(gs.day)))
	a.market_cursor_unchanged("abandoning does not move the market stream", gs,
		func() -> void: gm.dispatch("abandon_block", {"block_id": DEAREST}))

# --- D-5: why crew settles before territory ---------------------------------

## The documented reason was false in three files and the ordering is still
## right. This proves both halves, because prose that has been wrong for four
## batches does not get to be the only record.
##
## Claim A (the false one): "territory income is computed off crew power."
## Claim B (the real one):  crew-before-territory decides what the night COSTS,
##                          because a Deshawn who departs tonight no longer
##                          damps tonight's corner heat.
func _test_settlement_order_reason() -> void:
	# --- A. Territory income does not read crew power at all.
	#
	# Behavioural, not a grep: set `crew_power` to wildly different values and
	# the corners earn exactly the same. If income were computed off it — the
	# claim `day_lifecycle.gd`, `time_system.gd` and `crew.gd` all carried —
	# this would be impossible.
	_fresh(100000, 0)
	gs.soldiers_idle = 4
	gm.dispatch("claim_block", {"block_id": DEAREST})
	gm.dispatch("post_soldier", {"block_id": DEAREST})
	gs.crew_power = 0
	var at_zero: int = int(_terr().nightly_income())
	gs.crew_power = 999
	var at_max: int = int(_terr().nightly_income())
	a.eq_int("corner income is identical at crew power 0 and 999", at_zero, at_max)
	a.check("and it is not zero, so the comparison means something", at_zero > 0)

	# --- B. The ordering decides the night's HEAT, through Deshawn.
	#
	# One Deshawn, one unpaid wage past the grace period and loyalty already on
	# the floor, so `crew.settle_night()` marks him departed. Then the same
	# night settled both ways round.
	var scaled_first: float = _heat_with_order(["territory", "crew"])
	var crew_first: float = _heat_with_order(["crew", "territory"])

	a.check("settling crew first costs MORE corner heat (%f vs %f)"
		% [crew_first, scaled_first], crew_first > scaled_first)
	a.near("because a departed Deshawn damps nothing", crew_first,
		_terr_raw_heat_for_order_test())
	a.check("and settling territory first would have let him damp it one last time",
		scaled_first < _terr_raw_heat_for_order_test())

	# And the SHIPPED order is the one that costs more.
	#
	# Driven off `SETTLE_ORDER` itself rather than off a literal, so swapping
	# crew and territory in that constant changes this MEASUREMENT and not just
	# an index comparison. That is the difference between asserting the reason
	# and asserting the trace: the first sabotage run of this file only tripped
	# the index check, which would still pass if the ordering stopped mattering.
	var lifecycle: Object = gm.system("day_lifecycle")
	var order: Array = lifecycle.SETTLE_ORDER
	var as_shipped: float = _heat_with_order(order)
	a.near("settling in the shipped SETTLE_ORDER costs the undamped heat",
		as_shipped, _terr_raw_heat_for_order_test())
	a.check("which is strictly more than settling territory first would (%f vs %f)"
		% [as_shipped, scaled_first], as_shipped > scaled_first)
	a.check("SETTLE_ORDER ships crew before territory",
		order.find("crew") < order.find("territory"))
	a.check("and jobs and obligations run LAST, which HANDOFF.md denied for four batches",
		order.find("jobs") > order.find("territory")
			and order.find("obligations") == order.size() - 1)

## The raw holding heat for the order test's board, before any multiplier.
func _terr_raw_heat_for_order_test() -> float:
	return float(_block(DEAREST)["heat_exposure"])

## Settle one night with Deshawn one missed wage from walking, in the given
## order, and return the heat that landed.
func _heat_with_order(order: Array) -> float:
	_fresh(100000, 0)
	gs.soldiers_idle = 2
	gm.dispatch("claim_block", {"block_id": DEAREST})
	# Far enough into the run that `wage_missed_since` can be a real past day.
	# A NEGATIVE one reads as "unset" at `crew.gd:335` and is overwritten with
	# tonight, which resets the grace window and means he never departs — which
	# is how the first version of this check quietly measured nothing.
	gs.day = 10
	gm.dispatch("claim_block", {"block_id": DEAREST})
	# On the floor and already past the grace window, so tonight's unpaid wage
	# is the one that takes him.
	gs.crew_records["deshawn"] = {"recruited": true, "status": "active",
		"tier": 3, "loyalty": int(gs.CREW_LOYALTY_MIN) + 1, "wage_due": 500,
		"wage_missed_since": int(gs.day) - int(gs.CREW_WAGE_GRACE_DAYS) - 1}
	gs.cash = 0
	gs.clean_cash = 0
	gs.dirty_cash = 0
	gs.heat = 0.0
	for system_name in order:
		var system: Object = gm.system(str(system_name))
		if system != null and system.has_method("settle_night"):
			system.settle_night(int(gs.day))
	# The premise guard. Without it this helper reports a number whether or not
	# the departure it is built on ever happened, and a comparison between two
	# runs that both did nothing passes for the wrong reason.
	a.eq_bool("the unpaid wage took Deshawn (order: %s)" % str(order),
		gs.is_recruited("deshawn"), false)
	a.check("and a corner was held to charge heat for (order: %s)" % str(order),
		not gs.held_blocks.is_empty())
	return float(gs.heat)

# --- the save --------------------------------------------------------------

func _test_save_round_trip() -> void:
	# The legacy shape, round-tripped through the real capture/apply pair. This
	# is the behaviour FS-002.3's migration has to preserve, so it is pinned
	# here BEFORE the migration exists rather than alongside it.
	_fresh(100000, 0)
	gs.soldiers_idle = 5
	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	gm.dispatch("claim_block", {"block_id": DEAREST})
	gm.dispatch("post_soldier", {"block_id": DEAREST})

	var held_before: int = gs.held_blocks.size()
	var idle_before: int = int(gs.soldiers_idle)
	var total_before: int = gs.soldiers_total()
	var income_before: int = int(_terr().nightly_income())

	var save_system: Node = get_node("/root/SaveSystem")
	var captured: Dictionary = save_system.capture()
	# Round-trip through JSON, because that is what a real save is — and it is
	# where an int quietly becomes a float.
	var text: String = JSON.stringify(captured)
	var restored: Variant = JSON.parse_string(text)
	a.check("the captured state survives JSON", restored is Dictionary)

	_fresh(0, 0)
	save_system._apply(restored as Dictionary)

	a.eq_int("held corners survive the round trip", gs.held_blocks.size(), held_before)
	a.eq_int("idle soldiers survive the round trip", int(gs.soldiers_idle), idle_before)
	a.soldiers_conserved("and the roster total is conserved across it", gs, total_before)
	a.eq_bool("the cheap corner is still held", gs.holds_block(CHEAPEST), true)
	a.eq_bool("the dear corner is still held", gs.holds_block(DEAREST), true)
	a.eq_int("posted soldiers survive on the corner they were on",
		int((gs.held_blocks[DEAREST] as Dictionary).get("soldiers", 0)), 2)
	a.eq_int("and income is unchanged by the round trip",
		int(_terr().nightly_income()), income_before)
	a.capacity_respected("after a load", gs)

	# The defect PR 0 guarded, pinned: a held id with no authored definition
	# must not kill the night, and must not be counted as earning.
	gs.held_blocks["ghost_corner"] = {"soldiers": 2}
	a.eq_int("an id with no definition earns nothing",
		int(_terr().block_income("ghost_corner")), 0)
	a.eq_int("and does not change what the real corners earn",
		int(_terr().nightly_income()), income_before)
	_terr().settle_night(int(gs.day))
	a.check("and nightly settlement survives it (86bbjxtab)", true)

# --- what the screens read --------------------------------------------------

func _test_screen_reads() -> void:
	# Turf and Home read Territory through five entry points between them, and
	# FS-002.3 moves the state under all five. Screen-smoke cannot catch a
	# break: it runs on a FRESH save where `held_blocks` is empty, so every one
	# of these paths is skipped and the screens pass without executing.
	#
	# These are not screen tests. They pin the READS, so PR 3 has something that
	# fails when it moves the state.
	_fresh(100000, 0)
	gs.soldiers_idle = 6
	gm.dispatch("claim_block", {"block_id": CHEAPEST})
	gm.dispatch("claim_block", {"block_id": DEAREST})
	gm.dispatch("post_soldier", {"block_id": DEAREST})

	# turf.gd:25 — the status card.
	a.eq_int("Turf's HELD count", gs.held_blocks.size(), 2)
	# 6 recruited: 3 standing on corners (1 + 2), 3 still free.
	a.eq_int("Turf's soldier total", gs.soldiers_total(), 6)
	a.eq_int("Turf's capacity",
		gs.soldier_capacity(),
		int(gs.SOLDIER_BASE_CAPACITY) + 2 * int(gs.SOLDIER_CAPACITY_PER_BLOCK))
	a.eq_int("Turf's free count", int(gs.soldiers_idle), 3)

	# turf.gd:16 — the row list walks the authored table.
	a.eq_int("Turf renders a row per authored corner",
		gs.spenard_blocks.size(), 6)

	# home.gd:437 — the mini-map derives a cell from every held corner, and a
	# canonical node with no `cell` makes the map go dark. Nothing else asserts
	# this, and PR 3 is where it breaks.
	var cells_found: int = 0
	for id in gs.held_blocks.keys():
		var b: Dictionary = gs.block_by_id(str(id))
		if b.is_empty():
			continue
		a.check("held corner '%s' carries a map cell" % id, b.has("cell"))
		a.check("and it is inside the map (%s)" % str(b.get("cell", -1)),
			int(b.get("cell", -1)) >= 0 and int(b.get("cell", -1)) < int(gs.map_cells))
		cells_found += 1
	a.eq_int("every held corner resolved to a definition", cells_found, 2)

	# home.gd:458 — the one line that reports income on the Home screen.
	a.check("Home's turf line has an income to report",
		int(_terr().nightly_income()) > 0)

	# more.gd:128 — the block count.
	a.eq_int("More's block count", gs.held_blocks.size(), 2)

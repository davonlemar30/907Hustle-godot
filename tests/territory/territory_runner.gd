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
## ## What PR 3 broke here, as anticipated
##
## `held_blocks` was retired as ownership truth in FS-002.3 (Batch 18 PR 3) and
## `spenard_blocks` was deleted outright, both replaced by `gs.territory_nodes`
## and `data/territory_definitions.gd`. The checks below were written reaching
## through `gs.holds_block()`, `gs.block_by_id()` and the five dispatched
## actions wherever they could, because those are the seams PR 3 preserved —
## and every remaining direct read was mechanically swept to the new field
## names rather than rewritten by hand, which is the proof the seams held.

const ASSERTS := preload("res://tests/territory/territory_asserts.gd")
## FS-002.3: the authored board, off the canonical data file. `gs.spenard_blocks`
## is deleted.
const DEFS := preload("res://data/territory_definitions.gd")

## The check floor. See `_ready()` for why a count is a gate.
const MIN_CHECKS := 170

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
	_test_v16_migration()
	_test_v16_migration_capacity_hazard()
	_test_upkeep()

	# The floor, in the shape `parity_runner.gd` uses it. A suite whose checks
	# quietly stop RUNNING still prints PASS — an early `return` in a test
	# function, a renamed action every dispatch now fails on — and the count is
	# the only thing that notices. Raised in the same PR that raises the count.
	# Passed to `report()` rather than checked here — see that function for the
	# self-referential off-by-one this used to have.
	a.report("territory", get_tree(), MIN_CHECKS)

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
	# OG-D2: corners need a Player behind them; this suite is about corners.
	_stage_rank("player")

## OG-D2 (1.0.0): synthetic ledger rows that add up to a rank, for arms
## that are about corners or crew rather than about earning a name. The
## gate itself is asserted where it belongs.
func _stage_rank(tier_id: String) -> void:
	var rank := preload("res://data/rank.gd")
	var want: int = int(rank.by_index(rank.index_of(tier_id))["floor"])
	var rows: Array = []
	var have := 0
	var i := 0
	while have < want:
		rows.append({"key": "stage:%d" % i, "type": "growth", "event": "staged",
			"location": "north_star_lot", "source": "network", "count": 1, "day": 1})
		have += 2
		i += 1
	gs.npc_ledgers["juan"] = rows

func _block(id: String) -> Dictionary:
	return gs.block_by_id(id)

func _terr() -> Object:
	return gm.system("territory")

## OG-D6 (1.0.0): his blocks fight back. A claim on a Curtis block opens a
## confrontation now, and the fight is a roll. This suite is about what a
## held corner DOES -- soldiers, income, heat, the cap -- so when a claim
## opens the fight, the fight is won here by hand: the same `_take_from_curtis`
## the FIGHT road's win resolves through, with the chain cleared as state
## cleanup. The fight itself, both ways, is asserted in parity's
## `_check_his_blocks_fight_back`.
func _claim_block(block_id: String) -> bool:
	var ok: bool = gm.dispatch("claim_block", {"block_id": block_id})
	if not ok:
		return false
	var chain: Dictionary = gs.active_consequence
	if not chain.is_empty() and str((chain.get("source", {}) as Dictionary).get("action_id", "")) == "territory":
		gs.active_consequence = {}
		_terr()._take_from_curtis(block_id)
		# HS-D1: a front halves the block's income and adds heat; this suite
		# measures the held corner, so the front is closed as state cleanup.
		# The front's own arithmetic is asserted in parity.
		gs.territory_fronts.erase(block_id)
	return true

# --- claiming ---------------------------------------------------------------

func _test_claim() -> void:
	# The idle-soldier requirement. Canon requires a free soldier to occupy the
	# corner as it is taken, and this is the arm sabotage #2 deletes.
	_fresh(5000, 0)
	a.eq_bool("a claim with no free soldier is refused",
		_claim_block(CHEAPEST), false)
	a.eq_bool("and the corner is not held", gs.holds_block(CHEAPEST), false)
	a.check("the blocker says why",
		_terr().claim_blocker(CHEAPEST).contains("soldier"))

	# Cost, read off the authored row rather than typed here.
	var cost: int = int(_block(CHEAPEST)["claim_cost"])
	_fresh(cost - 1, 1)
	a.eq_bool("a claim one dollar short is refused",
		_claim_block(CHEAPEST), false)

	_fresh(cost, 1)
	a.eq_bool("a claim with exactly the cost and a free soldier lands",
		_claim_block(CHEAPEST), true)
	a.eq_int("and it cost exactly the authored claim cost", int(gs.cash), 0)
	a.eq_bool("and the corner is held", gs.holds_block(CHEAPEST), true)
	# The claiming soldier goes ONTO the corner — it is not a fee paid in
	# soldiers, it is the soldier standing there.
	a.eq_int("the claiming soldier is posted, not spent",
		int((gs.territory_nodes[CHEAPEST] as Dictionary).get("soldiers", 0)), 1)
	a.eq_int("and no longer idle", int(gs.soldiers_idle), 0)

	a.eq_bool("claiming the same corner twice is refused",
		_claim_block(CHEAPEST), false)
	a.eq_bool("claiming a corner that does not exist is refused",
		_claim_block("no_such_corner"), false)

	# Canon's neutral-claim cost ordering: every authored corner's claim cost
	# tracks its earning. Derived from the table, so re-authoring a row keeps
	# this honest rather than breaking it.
	# BR-D4 (0.9.0): per district -- Ship Creek's lots deliberately earn less
	# than Spenard's corners, because they are supply, not income.
	var rising := true
	var spenard: Array = DEFS.nodes_in("north_star_lot")
	for i in range(1, spenard.size()):
		var prev: Dictionary = spenard[i - 1]
		var cur: Dictionary = spenard[i]
		if int(cur["claim_cost"]) <= int(prev["claim_cost"]) \
				or int(cur["earning"]) <= int(prev["earning"]):
			rising = false
	a.check("the authored table rises in both cost and earning together", rising)

# --- abandoning -------------------------------------------------------------

func _test_abandon() -> void:
	_fresh(5000, 1)
	_claim_block(CHEAPEST)
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
	_claim_block(CHEAPEST)
	_claim_block(DEAREST)
	gm.dispatch("post_soldier", {"block_id": DEAREST})
	gm.dispatch("post_soldier", {"block_id": DEAREST})
	a.eq_int("three posted on the dear corner",
		int((gs.territory_nodes[DEAREST] as Dictionary)["soldiers"]), 3)
	a.eq_int("and none left idle", int(gs.soldiers_idle), 0)
	gm.dispatch("abandon_block", {"block_id": DEAREST})
	a.eq_int("all three come back idle", int(gs.soldiers_idle), 3)
	a.capacity_respected("and the roster still fits the remaining corner", gs)

	# `86bbjxtb6`, from the other side: when giving a corner back drops the cap
	# BELOW the roster, the overhang walks. Same setup, but the last corner goes
	# too — a cap of 2 cannot carry 4.
	gm.dispatch("abandon_block", {"block_id": CHEAPEST})
	a.eq_int("no corners left", gs.territory_nodes.size(), 0)
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

	_claim_block(CHEAPEST)
	a.eq_int("the claim consumed one of the two", int(gs.soldiers_idle), 1)

	a.eq_bool("posting a free soldier lands",
		gm.dispatch("post_soldier", {"block_id": CHEAPEST}), true)
	a.eq_int("two are posted", int((gs.territory_nodes[CHEAPEST] as Dictionary)["soldiers"]), 2)
	a.eq_int("and none are free", int(gs.soldiers_idle), 0)

	a.eq_bool("posting with nobody free is refused",
		gm.dispatch("post_soldier", {"block_id": CHEAPEST}), false)
	a.eq_str("and the blocker says so", _terr().post_blocker(CHEAPEST), "Nobody free.")

	a.eq_bool("pulling one back lands", gm.dispatch("pull_soldier", {"block_id": CHEAPEST}), true)
	a.eq_int("one posted", int((gs.territory_nodes[CHEAPEST] as Dictionary)["soldiers"]), 1)
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

	_claim_block(CHEAPEST)
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
		_claim_block(DEAREST)
		for _i in range(n - 1 if n > 0 else 0):
			gm.dispatch("post_soldier", {"block_id": DEAREST})
		if n == 0:
			gm.dispatch("pull_soldier", {"block_id": DEAREST})
		a.eq_int("%d posted is %d soldiers on the corner" % [n, n],
			int((gs.territory_nodes[DEAREST] as Dictionary)["soldiers"]), n)
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
	_claim_block(CHEAPEST)
	_claim_block(DEAREST)
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
	_claim_block(CHEAPEST)
	gm.dispatch("pull_soldier", {"block_id": CHEAPEST})
	a.eq_int("the corner is empty", int((gs.territory_nodes[CHEAPEST] as Dictionary)["soldiers"]), 0)
	a.near("an empty held corner still costs its authored heat",
		_terr().nightly_heat(), float(_block(CHEAPEST)["heat_exposure"]))

	_claim_block(DEAREST)
	a.near("and nightly heat is the sum over every held corner, staffed or not",
		_terr().nightly_heat(),
		float(_block(CHEAPEST)["heat_exposure"]) + float(_block(DEAREST)["heat_exposure"]))

	_fresh(100000, 0)
	a.near("holding nothing costs no heat", _terr().nightly_heat(), 0.0)

	# And that settlement actually applies it.
	_fresh(100000, 0)
	gs.soldiers_idle = 2
	_claim_block(DEAREST)
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
		_claim_block(DEAREST)
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
	_claim_block(DEAREST)
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

	_claim_block(CHEAPEST)
	a.soldiers_conserved("a claim moves a soldier, it does not spend one", gs, roster)

	gm.dispatch("post_soldier", {"block_id": CHEAPEST})
	a.soldiers_conserved("posting moves one", gs, roster)

	gm.dispatch("pull_soldier", {"block_id": CHEAPEST})
	a.soldiers_conserved("pulling moves it back", gs, roster)

	_claim_block(DEAREST)
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
	_claim_block(DEAREST)
	var before: int = gs.soldiers_total()
	a.eq_bool("there is room to recruit", gm.dispatch("recruit_soldier", {}), true)
	a.soldiers_conserved("recruiting adds exactly one", gs, before + 1)

func _test_capacity_invariant() -> void:
	# `86bbjxtb6`, as a permanent check. Hold three, recruit to the cap, give all
	# three back. The cap falls by 6 and the roster must fall with it.
	_fresh(100000, 3)
	for id in [CHEAPEST, "wash_and_go_lot", "minnesota_offramp"]:
		_claim_block(id)
	while gm.dispatch("recruit_soldier", {}):
		pass
	a.capacity_respected("at the cap with three corners", gs)
	var at_cap: int = gs.soldiers_total()
	a.check("three corners genuinely raised the cap (%d soldiers)" % at_cap,
		at_cap > int(gs.SOLDIER_BASE_CAPACITY))

	for id in [CHEAPEST, "wash_and_go_lot", "minnesota_offramp"]:
		gm.dispatch("abandon_block", {"block_id": id})
	a.eq_int("no corners left", gs.territory_nodes.size(), 0)
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
		func() -> void: _claim_block(DEAREST))
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
	_claim_block(DEAREST)
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
	# "Jobs and obligations run last" held literally for four batches and
	# through Dre Lending PR A (which inserted `dre` between `shark` and
	# `jobs`, not after `obligations`). Street Opportunity and Mission
	# System PR C is the first system with a genuine reason to settle AFTER
	# obligations: its settlement-fact objectives (design doc section 10.2)
	# read facts obligations' own settlement just wrote -- rent missed, a
	# job lost -- the same reasoning that put obligations after jobs in the
	# first place, one step later in the chain. What this test still
	# guards -- jobs and obligations settling together, in that order,
	# after everything territory/crew/shark/dre-related -- still holds.
	a.check("jobs and obligations still run together, in that order, "
		+ "right after dre", order.find("jobs") > order.find("territory")
			and order.find("obligations") == order.find("jobs") + 1)
	a.check("and opportunities is the new last -- the one system authored "
		+ "to need the fully settled night", order.find("opportunities") == order.size() - 1)

## The raw holding heat for the order test's board, before any multiplier.
func _terr_raw_heat_for_order_test() -> float:
	return float(_block(DEAREST)["heat_exposure"])

## Settle one night with Deshawn one missed wage from walking, in the given
## order, and return the heat that landed.
func _heat_with_order(order: Array) -> float:
	_fresh(100000, 0)
	gs.soldiers_idle = 2
	_claim_block(DEAREST)
	# Far enough into the run that `wage_missed_since` can be a real past day.
	# A NEGATIVE one reads as "unset" at `crew.gd:335` and is overwritten with
	# tonight, which resets the grace window and means he never departs — which
	# is how the first version of this check quietly measured nothing.
	gs.day = 10
	_claim_block(DEAREST)
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
		not gs.territory_nodes.is_empty())
	return float(gs.heat)

# --- the save --------------------------------------------------------------

func _test_save_round_trip() -> void:
	# The legacy shape, round-tripped through the real capture/apply pair. This
	# is the behaviour FS-002.3's migration has to preserve, so it is pinned
	# here BEFORE the migration exists rather than alongside it.
	_fresh(100000, 0)
	gs.soldiers_idle = 5
	_claim_block(CHEAPEST)
	_claim_block(DEAREST)
	gm.dispatch("post_soldier", {"block_id": DEAREST})

	var held_before: int = gs.territory_nodes.size()
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

	a.eq_int("held corners survive the round trip", gs.territory_nodes.size(), held_before)
	a.eq_int("idle soldiers survive the round trip", int(gs.soldiers_idle), idle_before)
	a.soldiers_conserved("and the roster total is conserved across it", gs, total_before)
	a.eq_bool("the cheap corner is still held", gs.holds_block(CHEAPEST), true)
	a.eq_bool("the dear corner is still held", gs.holds_block(DEAREST), true)
	a.eq_int("posted soldiers survive on the corner they were on",
		int((gs.territory_nodes[DEAREST] as Dictionary).get("soldiers", 0)), 2)
	a.eq_int("and income is unchanged by the round trip",
		int(_terr().nightly_income()), income_before)
	a.capacity_respected("after a load", gs)

	# The defect PR 0 guarded, pinned: a held id with no authored definition
	# must not kill the night, and must not be counted as earning.
	gs.territory_nodes["ghost_corner"] = {"soldiers": 2}
	a.eq_int("an id with no definition earns nothing",
		int(_terr().block_income("ghost_corner")), 0)
	a.eq_int("and does not change what the real corners earn",
		int(_terr().nightly_income()), income_before)
	_terr().settle_night(int(gs.day))
	a.check("and nightly settlement survives it (86bbjxtab)", true)

# --- what the screens read --------------------------------------------------

func _test_screen_reads() -> void:
	# Turf and Home read Territory through five entry points between them, and
	# FS-002.3 moved the state under all five. Screen-smoke cannot catch a
	# break: it runs on a FRESH save where `territory_nodes` is empty, so every
	# one of these paths is skipped and the screens pass without executing.
	#
	# These are not screen tests. They pin the READS, so PR 3 has something that
	# fails when it moves the state.
	_fresh(100000, 0)
	gs.soldiers_idle = 6
	_claim_block(CHEAPEST)
	_claim_block(DEAREST)
	gm.dispatch("post_soldier", {"block_id": DEAREST})

	# turf.gd:25 — the status card.
	a.eq_int("Turf's HELD count", gs.territory_nodes.size(), 2)
	# 6 recruited: 3 standing on corners (1 + 2), 3 still free.
	a.eq_int("Turf's soldier total", gs.soldiers_total(), 6)
	a.eq_int("Turf's capacity",
		gs.soldier_capacity(),
		int(gs.SOLDIER_BASE_CAPACITY) + 2 * int(gs.SOLDIER_CAPACITY_PER_BLOCK))
	a.eq_int("Turf's free count", int(gs.soldiers_idle), 3)

	# turf.gd:16 — the row list walks the authored table.
	a.eq_int("Turf renders a row per authored Spenard corner",
		(DEFS.nodes_in("north_star_lot") as Array).size(), 6)

	# home.gd:437 — the mini-map derives a cell from every held corner, and a
	# canonical node with no `cell` makes the map go dark. Nothing else asserts
	# this, and PR 3 is where it breaks.
	var cells_found: int = 0
	for id in gs.territory_nodes.keys():
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
	a.eq_int("More's block count", gs.territory_nodes.size(), 2)

# --- FS-002.3: the v15 -> v16 migration --------------------------------------
#
# The one-way door. `held_blocks` (spenard_blocks display rows) becomes
# `territory_nodes` (data/territory_definitions.gd ids) plus `territory_fronts`.
# Driven through `SaveSystem._migrate()` directly, the same technique
# `parity_runner.gd`'s `_check_v10_migration` uses — the arm asked in isolation,
# before a load's `reconcile_persistent_invariants()` can mask a missing one.

func _saves() -> Node:
	return get_node("/root/SaveSystem")

## A minimal v15 payload: the three required keys plus a `held_blocks` shape a
## real v15 save could have carried, including the two dead fields
## (`claimed_day`, `income_collected`) that only existed pre-migration.
func _v15_payload(held: Dictionary, idle: int = 0) -> Dictionary:
	return {"day": 20, "cash": 500, "street_name": "Legacy", "soldiers_idle": idle,
		"held_blocks": held}

func _test_v16_migration() -> void:
	# One neutral corner, one Curtis-secure corner, both held with a real
	# soldier count and the two dead fields still on them — exactly what a v15
	# save looked like.
	var payload := _v15_payload({
		"wash_and_go_lot": {"soldiers": 2, "claimed_day": 5, "income_collected": 110},
		"fourth_ave_strip": {"soldiers": 1, "claimed_day": 12, "income_collected": 80},
	}, 3)
	var migrated: Dictionary = _saves()._migrate({"save_version": 15, "state": payload})
	a.check("the v15 payload migrates", not migrated.is_empty())
	a.eq_bool("held_blocks does not survive the arm", migrated.has("held_blocks"), false)

	var nodes: Dictionary = migrated.get("territory_nodes", {})
	a.eq_int("both corners carry over", nodes.size(), 2)
	a.eq_int("soldiers are preserved on the neutral corner",
		int((nodes.get("wash_and_go_lot", {}) as Dictionary).get("soldiers", -1)), 2)
	a.eq_int("soldiers are preserved on the Curtis-secure corner",
		int((nodes.get("fourth_ave_strip", {}) as Dictionary).get("soldiers", -1)), 1)
	a.eq_bool("claimed_day does not survive the rename",
		(nodes.get("wash_and_go_lot", {}) as Dictionary).has("claimed_day"), false)
	a.eq_bool("income_collected does not survive the rename",
		(nodes.get("wash_and_go_lot", {}) as Dictionary).has("income_collected"), false)

	# D-6 (docs/DECISIONS.md): a migrated holding is never confiscated, even
	# where the seeding rule calls this node Curtis-secure. The neutral corner
	# gets no fronts entry at all — it was never anyone's but the player's.
	var fronts: Dictionary = migrated.get("territory_fronts", {})
	a.eq_bool("the neutral corner has no fronts entry", fronts.has("wash_and_go_lot"), false)
	a.check("the Curtis-secure corner is flagged, not confiscated",
		fronts.has("fourth_ave_strip"))
	a.eq_bool("its capture reward is marked already consumed",
		bool((fronts.get("fourth_ave_strip", {}) as Dictionary)
			.get("capture_reward_consumed", false)), true)
	a.eq_bool("and it is flagged contested for a later build to read",
		bool((fronts.get("fourth_ave_strip", {}) as Dictionary)
			.get("conflict_active", false)), true)

	# A Curtis-secure node the save never held gets no fronts entry either —
	# fronts records a MIGRATED capture, not a standing fact about the board.
	# minnesota_offramp is Curtis-secure and was never in `held`.
	a.eq_bool("an untouched Curtis-secure corner has no fronts entry",
		fronts.has("minnesota_offramp"), false)
	a.eq_bool("and is not migrated as held either",
		nodes.has("minnesota_offramp"), false)

	# An id the definitions do not carry (86bbjxtab) migrates AS-IS. Dropping it
	# during migration would be silent data loss before the validator — and its
	# own coverage — gets a say.
	var orphan_payload := _v15_payload({"ghost_corner": {"soldiers": 2}}, 0)
	var orphan_migrated: Dictionary = _saves()._migrate(
		{"save_version": 15, "state": orphan_payload})
	var orphan_nodes: Dictionary = orphan_migrated.get("territory_nodes", {})
	a.check("an orphan id survives the migration rather than being dropped",
		orphan_nodes.has("ghost_corner"))
	a.eq_int("with its soldier count intact",
		int((orphan_nodes.get("ghost_corner", {}) as Dictionary).get("soldiers", -1)), 2)

	# Negative soldiers on a v15 row are clamped at the arm, not trusted through
	# to the validator.
	var negative_payload := _v15_payload({"wash_and_go_lot": {"soldiers": -4}}, 0)
	var negative_migrated: Dictionary = _saves()._migrate(
		{"save_version": 15, "state": negative_payload})
	var negative_nodes: Dictionary = negative_migrated.get("territory_nodes", {})
	a.eq_int("a negative soldier count is clamped to 0 at migration",
		int((negative_nodes.get("wash_and_go_lot", {}) as Dictionary).get("soldiers", -1)), 0)

	# Soldier conservation across the whole migration — the TOTAL, not just
	# presence. A malicious or accidental arm could map holdings correctly and
	# still drop the soldiers standing on them.
	var conserve_payload := _v15_payload({
		"spenard_rec_lot": {"soldiers": 2}, "wash_and_go_lot": {"soldiers": 1},
	}, 4)
	var conserve_migrated: Dictionary = _saves()._migrate(
		{"save_version": 15, "state": conserve_payload})
	var conserve_nodes: Dictionary = conserve_migrated.get("territory_nodes", {})
	var posted_total := 0
	for id in conserve_nodes.keys():
		posted_total += int((conserve_nodes[id] as Dictionary).get("soldiers", 0))
	a.eq_int("soldier conservation holds across migration (idle + posted)",
		int(conserve_migrated.get("soldiers_idle", -1)) + posted_total, 4 + 3)

	# And through a REAL load, not just the isolated arm — the same
	# belt-and-suspenders `_check_v10_migration` applies.
	var real_gs := gs
	var saves := _saves()
	saves.save_run()  # preserve whatever is currently on disk
	var prior_save := ""
	if FileAccess.file_exists(saves.SAVE_PATH):
		var f := FileAccess.open(saves.SAVE_PATH, FileAccess.READ)
		if f != null:
			prior_save = f.get_as_text()
			f.close()
	var payload_str := var_to_str({"save_version": 15, "state": _v15_payload({
		"wash_and_go_lot": {"soldiers": 1}, "fourth_ave_strip": {"soldiers": 1},
	}, 2)})
	var out := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	if out != null:
		out.store_string(payload_str)
		out.close()
	a.check("a v15 save loads through the real pipeline", saves.load_run())
	a.eq_int("and lands on both corners", real_gs.territory_nodes.size(), 2)
	a.capacity_respected("after a real v15 -> v16 load", real_gs)
	if not prior_save.is_empty():
		var restore := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(prior_save)
			restore.close()
	_fresh(100000, 0)

## Hazard #1 from the build prompt, named "the highest-risk line in the build":
## `soldier_capacity() = 2 + held.size() * 2`, and six nodes are seeded, four of
## them Curtis-secure. If the compat selector counted NODES rather than
## PLAYER-HELD nodes, capacity would silently jump 2 -> 14 the moment a save
## carries the four Curtis-secure definitions without holding any of them.
func _test_v16_migration_capacity_hazard() -> void:
	_fresh(100000, 0)
	a.eq_int("capacity with nothing held is the base, not the board size",
		gs.soldier_capacity(), int(gs.SOLDIER_BASE_CAPACITY))
	a.check("the authored Spenard board is six nodes, so a size()-based bug would show",
		(DEFS.nodes_in("north_star_lot") as Array).size() == 6)

	# The exact hazard scenario: a save with all four Curtis-secure fronts
	# entries present (from a prior migration) and NOTHING actually held.
	gs.territory_fronts = {
		"minnesota_offramp": {"capture_reward_consumed": true, "conflict_active": true},
		"service_road_chokepoint": {"capture_reward_consumed": true, "conflict_active": true},
		"fourth_ave_strip": {"capture_reward_consumed": true, "conflict_active": true},
		"northern_lights_motels": {"capture_reward_consumed": true, "conflict_active": true},
	}
	a.eq_int("fronts entries alone do not raise capacity",
		gs.soldier_capacity(), int(gs.SOLDIER_BASE_CAPACITY))
	_fresh(100000, 0)

# --- D-1: the recurring cost Territory never had (Batch 18 PR 4) ------------

func _test_upkeep() -> void:
	# The computation, derived through the rule rather than memorised — same
	# pattern the income curve checks use.
	_fresh(100000, 0)
	gs.soldiers_idle = 3
	a.eq_int("upkeep with 3 idle soldiers and no corners",
		_terr().nightly_upkeep(), 3 * int(gs.SOLDIER_UPKEEP_PER_NIGHT))
	_fresh(100000, 0)
	a.eq_int("with nobody recruited, upkeep is zero", _terr().nightly_upkeep(), 0)

	# It is charged even with no corner held — the exact "over-extended" case
	# D-1 exists to price: a soldier recruited before any corner is claimed.
	_fresh(100000, 3)
	a.eq_bool("no corners held", gs.territory_nodes.is_empty(), true)
	var cash_before_idle_only: int = int(gs.cash)
	_terr().settle_night(int(gs.day))
	a.eq_int("idle soldiers with no corner still draw upkeep",
		cash_before_idle_only - int(gs.cash), 3 * int(gs.SOLDIER_UPKEEP_PER_NIGHT))

	# Charged on the FULL roster — idle and posted together — the same as a
	# crew wage is charged whether or not that member worked today.
	_fresh(100000, 4)
	_claim_block(CHEAPEST)
	gm.dispatch("post_soldier", {"block_id": CHEAPEST})
	# 4 recruited: 2 posted on the corner, 2 idle.
	a.eq_int("the roster under test", gs.soldiers_total(), 4)
	var cash_before: int = int(gs.cash)
	var income_expected: int = _terr().nightly_income()
	var upkeep_expected: int = _terr().nightly_upkeep()
	_terr().settle_night(int(gs.day))
	a.eq_int("upkeep is charged on the whole roster, posted and idle alike",
		upkeep_expected, 4 * int(gs.SOLDIER_UPKEEP_PER_NIGHT))
	a.eq_int("the wallet nets income minus upkeep in one settlement",
		int(gs.cash) - cash_before, income_expected - upkeep_expected)

	# Insolvency: pays what it can, no debt, no crash. Cash short of the full
	# bill still drops to exactly zero rather than refusing the whole charge —
	# `_wallet().spend()` would refuse an amount larger than cash on hand, and
	# `_settle_upkeep()` exists specifically to not do that.
	_fresh(10, 5)
	a.check("cash is short of the full bill",
		int(gs.cash) < 5 * int(gs.SOLDIER_UPKEEP_PER_NIGHT))
	_terr().settle_night(int(gs.day))
	a.eq_int("a short bill takes every dollar there is, not zero and not a refusal",
		int(gs.cash), 0)

	# And solvency: a roster the player can afford draws exactly the bill, not
	# a partial one.
	_fresh(1000, 2)
	var cash_before_solvent: int = int(gs.cash)
	_terr().settle_night(int(gs.day))
	a.eq_int("a roster the player can afford draws exactly the bill",
		cash_before_solvent - int(gs.cash), 2 * int(gs.SOLDIER_UPKEEP_PER_NIGHT))

	# Market-RNG non-drift: upkeep is a wallet operation, not a roll, and
	# rule 2 applies to it the same as every other Territory transition.
	_fresh(100000, 3)
	a.market_cursor_unchanged("nightly upkeep does not move the market stream", gs,
		func() -> void: _terr().settle_night(int(gs.day)))

	_fresh(100000, 0)

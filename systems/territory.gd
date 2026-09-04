extends RefCounted
## Territory — corners you hold, soldiers who stand on them, money that arrives
## whether you did anything that day or not.
##
## Ported from src/data/locations.js SPENARD_BLOCKS and the CLAIM_BLOCK /
## RECRUIT_SOLDIER / ASSIGN_SOLDIER reducers plus the nightly block settlement
## (game-core.js ~4710).
##
## The shape of the decision:
##
##   - A block earns nothing on its own. Income comes from soldiers standing on
##     it, and each additional soldier earns 0.85x the one before. So a second
##     corner is worth more than a second soldier on the first ONLY if it earns
##     at least 85% as much: two soldiers on the Motel Row (100) make $185,
##     while splitting them across Motel Row and Fourth Ave (80) makes $180.
##     Which way round it falls is the decision.
##   - Ownership costs heat every night regardless. Canon is explicit about why:
##     an empty corner you hold is still a corner people know is yours. So a
##     block you cannot staff is a pure liability.
##   - Holding blocks raises the soldier cap (2 per block), which is what lets
##     the operation grow rather than just widen.
##   - **D-1 (Batch 18 PR 4):** every soldier draws $20 a night, posted or
##     idle — the same as a crew member draws a wage whether or not they did
##     anything that day. Widening (a new corner) buys heat AND the payroll
##     for whoever staffs it; stacking (a second soldier on a corner already
##     held) buys neither. An unstaffed corner was always a liability for its
##     heat; now the soldiers standing on nothing are one too.
##
## This is the first income in the game that arrives without an action — and,
## since D-1, the first recurring COST that does too. Before D-1 it was also
## the first thing that could outrun the rent with nothing on the other side of
## the ledger; the soldiers standing on the payroll are that other side now.
##
## Not ported, each 3f's business: police raids on staffed corners (the
## `policeRaidChance` / patrol-frequency roll), Curtis pressure and contested
## takeovers, soldier attrition, block manager assignment and income policies,
## and the district-level TERRITORIES takeover.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager
	# Driven by DayLifecycle in declared order. See systems/day_lifecycle.gd.

func can_handle(action: String) -> bool:
	return action in ["claim_block", "abandon_block", "recruit_soldier", "post_soldier", "pull_soldier"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	var block_id: String = str(payload.get("block_id", ""))
	match action:
		"claim_block":
			return _claim(block_id)
		"abandon_block":
			return _abandon(block_id)
		"recruit_soldier":
			return _recruit_soldier()
		"post_soldier":
			return _post(block_id)
		"pull_soldier":
			return _pull(block_id)
	return {"ok": false, "reason": "Unknown territory action."}

# --- claiming --------------------------------------------------------------

func claim_blocker(block_id: String) -> String:
	if gs.game_over:
		return "The run is over."
	var b: Dictionary = gs.block_by_id(block_id)
	if b.is_empty():
		return "No such corner."
	if gs.holds_block(block_id):
		return "Already yours."
	# Canon requires a free soldier to occupy the corner as it is taken.
	if gs.soldiers_idle < 1:
		return "Need a soldier free to stand on it."
	if gs.cash < int(b["claim_cost"]):
		return "Need $%d." % int(b["claim_cost"])
	return ""

## The shared owners. Claiming and recruiting are routine spends; corner
## income is dirty and the nightly heat is a criminal gain.
func _wallet() -> Object:
	return gm.system("wallet")

func _heat() -> Object:
	return gm.system("heat")

func _claim(block_id: String) -> Dictionary:
	var blocked := claim_blocker(block_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var b: Dictionary = gs.block_by_id(block_id)
	_wallet().spend(int(b["claim_cost"]), _wallet().ROUTINE_DIRTY_FIRST,
		{"source_id": "territory_claim"})
	gs.soldiers_idle -= 1
	# {"soldiers": int} only — FS-002.3 dropped `claimed_day` and
	# `income_collected`. Both were dead: the first backed no mechanic, the
	# second was written once and read never (86bbjxtjb's PR 1 audit found it
	# unreferenced everywhere but a save fixture).
	gs.territory_nodes[block_id] = {"soldiers": 1}
	gs.log_activity("%s is yours. Nobody hands you a key. You just stop getting asked to leave." % str(b["name"]), GREEN)
	return {"ok": true}

func _abandon(block_id: String) -> Dictionary:
	if not gs.holds_block(block_id):
		return {"ok": false, "reason": "Not yours."}
	var rec: Dictionary = gs.territory_nodes[block_id]
	# The soldiers come back; the claim cost does not.
	gs.soldiers_idle += int(rec.get("soldiers", 0))
	gs.territory_nodes.erase(block_id)
	gs.log_activity("You walk off %s and somebody else is standing there by dark." % _block_name(block_id), AMBER)
	# Giving up a corner takes 2 off the cap with it, and the roster does not
	# get to stay above the cap because the corner it was sized for is gone
	# (86bbjxtb6). Hold 3, recruit to 8, abandon all 3 and the old code left 8
	# soldiers standing under a capacity of 2 — permanently, because every other
	# path checks the cap and only this one hands soldiers back.
	#
	# The excess walks rather than the abandon being refused: a player who
	# over-recruited must still be able to shrink, and a corner you cannot give
	# up is a worse rule than a soldier you cannot keep. The cap is unchanged and
	# stays the single truth; this is the one path that was not reading it.
	_discharge_over_capacity()
	return {"ok": true}

## The roster cannot exceed `gs.soldier_capacity()`. Every path that can raise
## the count checks it; this is for the one path that LOWERS the cap.
##
## Only idle soldiers can be discharged, which is always enough: the cap is
## `2 + 2 x blocks` and a block can never hold more than the 2 it is worth plus
## the base, so any overhang after an abandon is sitting in `soldiers_idle`.
func _discharge_over_capacity() -> void:
	var over: int = gs.soldiers_total() - gs.soldier_capacity()
	if over <= 0:
		return
	var let_go: int = mini(over, gs.soldiers_idle)
	if let_go <= 0:
		return
	gs.soldiers_idle -= let_go
	gs.log_activity("%d soldier%s off the payroll — no corners left to stand on."
		% [let_go, "" if let_go == 1 else "s"], AMBER)

# --- soldiers --------------------------------------------------------------

func recruit_soldier_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	if gs.soldiers_total() >= gs.soldier_capacity():
		return "No room for another. Hold more corners first."
	if gs.cash < gs.SOLDIER_RECRUIT_COST:
		return "Need $%d." % gs.SOLDIER_RECRUIT_COST
	return ""

func _recruit_soldier() -> Dictionary:
	var blocked := recruit_soldier_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	_wallet().spend(gs.SOLDIER_RECRUIT_COST, _wallet().ROUTINE_DIRTY_FIRST,
		{"source_id": "territory_soldier"})
	gs.soldiers_idle += 1
	gs.log_activity("Another one on the payroll. Another one who knows your name.", GREEN)
	return {"ok": true}

func post_blocker(block_id: String) -> String:
	if not gs.holds_block(block_id):
		return "Not yours."
	if gs.soldiers_idle < 1:
		return "Nobody free."
	return ""

func _post(block_id: String) -> Dictionary:
	var blocked := post_blocker(block_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var rec: Dictionary = gs.territory_nodes[block_id]
	rec["soldiers"] = int(rec.get("soldiers", 0)) + 1
	gs.soldiers_idle -= 1
	return {"ok": true}

func _pull(block_id: String) -> Dictionary:
	if not gs.holds_block(block_id):
		return {"ok": false, "reason": "Not yours."}
	var rec: Dictionary = gs.territory_nodes[block_id]
	if int(rec.get("soldiers", 0)) <= 0:
		return {"ok": false, "reason": "Nobody posted there."}
	rec["soldiers"] = int(rec["soldiers"]) - 1
	gs.soldiers_idle += 1
	return {"ok": true}

# --- reads -----------------------------------------------------------------

## The display name for a held corner, and the reason nightly settlement no
## longer dies on an id it does not recognise (86bbjxtab).
##
## `gs.block_by_id()` returns `{}` for an unknown id, and three sites used to
## index straight into that — `["name"]` on an empty Dictionary is an "Invalid
## access" that aborts `settle_night` part-way through. The player saw corners
## stop paying, silently, on a board that still read "6 HELD", because the
## error went to stderr and nothing in the build reads stderr.
##
## A held row CAN outlive its definition: a save carries `territory_nodes` verbatim
## and nothing validates the ids in it, so an edited save, a rolled-back build
## or a renamed corner all produce one. FS-002.3 adds the second id namespace
## and the migration between them, which is exactly the change that would mint
## these by accident — so the read is made total first.
##
## Falls back to the id rather than to "" so the line the player reads names
## something, and so the row stays identifiable in the log.
func _block_name(block_id: String) -> String:
	var b: Dictionary = gs.block_by_id(block_id)
	if b.is_empty():
		return block_id
	return str(b.get("name", block_id))

# --- income ----------------------------------------------------------------

## Canon: each soldier on a corner earns earningPotential * 0.85^index — the
## second is worth 85% of the first, the third 85% of that.
func block_income(block_id: String) -> int:
	if not gs.holds_block(block_id):
		return 0
	var b: Dictionary = gs.block_by_id(block_id)
	# An id in `territory_nodes` that the authored table does not carry earns
	# nothing rather than crashing the night. See `_block_name` for why a held
	# row can outlive its definition at all.
	if b.is_empty():
		return 0
	var n: int = int(gs.territory_nodes[block_id].get("soldiers", 0))
	var total: float = 0.0
	for i in range(n):
		total += float(b["earning"]) * pow(gs.SOLDIER_INCOME_DIMINISH, i)
	return int(round(total))

func nightly_income() -> int:
	var total: int = 0
	for id in gs.territory_nodes.keys():
		total += block_income(str(id))
	return total

## Held blocks cost heat whether or not anyone is standing on them.
func nightly_heat() -> float:
	var total: float = 0.0
	for id in gs.territory_nodes.keys():
		total += float(gs.block_by_id(str(id)).get("heat_exposure", 0))
	return total

## D-1 (86bbjxtfa, Batch 18 PR 4): the recurring cost Territory never had. Read
## as int, same rounding rule `block_income()` already uses — Territory has
## never carried a fractional dollar and this does not start.
func nightly_upkeep() -> int:
	return gs.soldiers_total() * int(gs.SOLDIER_UPKEEP_PER_NIGHT)

## Nightly corner income, the heat of holding them, and — as of D-1 — the
## payroll for every soldier on the roster. Reads no day at all, so the
## parameter is accepted and unused — the interface is uniform on purpose.
##
## Runs through the SAME declared step Territory has settled through since
## FS-003.2 (`SETTLE_ORDER:territory`, right after `SETTLE_ORDER:crew` — the
## "alongside crew wages" D-1 asks for is that adjacency, already declared).
## No new phase, no new step name, and definitely no `day_crossed.connect()`:
## the brief's warning against that pattern is about bypassing the lifecycle
## entirely, and this was never outside it.
func settle_night(_ended_day: int) -> void:
	if gs.game_over:
		return

	# Corner-specific work only runs with a corner to be specific about. This
	# used to be the function's only early-return condition; it is narrowed to
	# a guard around just this block, because upkeep (below) must still run for
	# a soldier recruited before any corner is ever claimed — the exact
	# "over-extended" case D-1 exists to price.
	if not gs.territory_nodes.is_empty():
		var income: int = nightly_income()
		if income > 0:
			# TI-003 §6 classifies territory income as criminal: "current criminal
			# Territory income once its payout caller migrates". This is that caller.
			_wallet().credit(income, _wallet().DIRTY, {"source_id": "territory_income"})
			gs.record_earning("territory", income)
			gs.log_activity("The corners bring in $%d. It comes in twenties, it comes in ones, it comes." % income, GREEN)

		# Deshawn damps this the same way he damps a stickup — it is heat the
		# operation generates, and it routes through the same multiplier. HeatSystem
		# fetches him now, so this no longer does.
		#
		# No family: holding corners is not one of TI-003 §7's three, so it scales
		# by Deshawn and by nothing else — the scaling this line already had. Passed
		# as `FAMILY_NONE` rather than as a bare "" so the exemption is named at both
		# ends and cannot be re-derived from a dictionary miss (86bbjxtbm).
		var raw: float = nightly_heat()
		if raw > 0.0:
			_heat().apply_gain(raw, _heat().FAMILY_NONE, gs.current_district_id,
				{"source_id": "territory_nightly"})

		var unstaffed: Array = []
		for id in gs.territory_nodes.keys():
			if int(gs.territory_nodes[id].get("soldiers", 0)) <= 0:
				unstaffed.append(_block_name(str(id)))
		if not unstaffed.is_empty():
			gs.log_activity("%s sat empty all night. Still yours. Somebody noticed it was." % ", ".join(unstaffed), RED)

	_settle_upkeep()

## Pays what it can, rather than refusing outright the way `_wallet().spend()`
## does everywhere else in this file. Every other call site in `territory.gd`
## checks a blocker before spending — `wallet.gd`'s own docs say a refusal
## there means a blocker was missed, not that a player was refused — and that
## contract does not fit an AUTOMATIC nightly charge with no blocker to check.
## Every other nightly obligation in the build (rent, the phone bill) is
## player-initiated with a due date and a miss penalty rather than a forced
## deduction; inventing that same debt-and-consequence machinery for one
## upkeep line is a bigger change than D-1 asks for. So this is the smallest
## honest thing an automatic charge can do when the till is short: take
## whatever is there, log the shortfall, and stop — no debt, no departure, no
## grace period. FS-002.4/.5 can build a real consequence on top of this if the
## ruling later wants one; nothing here forecloses it.
func _settle_upkeep() -> void:
	var soldiers: int = gs.soldiers_total()
	if soldiers <= 0:
		return
	var owed: int = nightly_upkeep()
	var paid: int = mini(owed, int(gs.cash))
	if paid <= 0:
		gs.log_activity("%d soldiers and nothing to pay them with. They know before you tell them." % soldiers, RED)
		return
	_wallet().spend(paid, _wallet().ROUTINE_DIRTY_FIRST, {"source_id": "territory_upkeep"})
	if paid < owed:
		gs.log_activity("Paid $%d of $%d owed in soldier upkeep — nothing left." % [paid, owed], RED)
	else:
		gs.log_activity("$%d in upkeep for %d soldiers." % [paid, soldiers], AMBER)

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
##
## This is the first income in the game that arrives without an action, which is
## also the first thing that can outrun the rent.
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
	gs.day_crossed.connect(_on_day_crossed)

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

func _claim(block_id: String) -> Dictionary:
	var blocked := claim_blocker(block_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var b: Dictionary = gs.block_by_id(block_id)
	gs.cash -= int(b["claim_cost"])
	gs.soldiers_idle -= 1
	gs.held_blocks[block_id] = {"soldiers": 1, "claimed_day": gs.day, "income_collected": 0}
	gs.log_activity("%s is yours." % str(b["name"]), GREEN)
	return {"ok": true}

func _abandon(block_id: String) -> Dictionary:
	if not gs.holds_block(block_id):
		return {"ok": false, "reason": "Not yours."}
	var rec: Dictionary = gs.held_blocks[block_id]
	# The soldiers come back; the claim cost does not.
	gs.soldiers_idle += int(rec.get("soldiers", 0))
	gs.held_blocks.erase(block_id)
	gs.log_activity("Walked away from %s." % str(gs.block_by_id(block_id)["name"]), AMBER)
	return {"ok": true}

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
	gs.cash -= gs.SOLDIER_RECRUIT_COST
	gs.soldiers_idle += 1
	gs.log_activity("Another soldier goes on the payroll.", GREEN)
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
	var rec: Dictionary = gs.held_blocks[block_id]
	rec["soldiers"] = int(rec.get("soldiers", 0)) + 1
	gs.soldiers_idle -= 1
	return {"ok": true}

func _pull(block_id: String) -> Dictionary:
	if not gs.holds_block(block_id):
		return {"ok": false, "reason": "Not yours."}
	var rec: Dictionary = gs.held_blocks[block_id]
	if int(rec.get("soldiers", 0)) <= 0:
		return {"ok": false, "reason": "Nobody posted there."}
	rec["soldiers"] = int(rec["soldiers"]) - 1
	gs.soldiers_idle += 1
	return {"ok": true}

# --- income ----------------------------------------------------------------

## Canon: each soldier on a corner earns earningPotential * 0.85^index — the
## second is worth 85% of the first, the third 85% of that.
func block_income(block_id: String) -> int:
	if not gs.holds_block(block_id):
		return 0
	var b: Dictionary = gs.block_by_id(block_id)
	var n: int = int(gs.held_blocks[block_id].get("soldiers", 0))
	var total: float = 0.0
	for i in range(n):
		total += float(b["earning"]) * pow(gs.SOLDIER_INCOME_DIMINISH, i)
	return int(round(total))

func nightly_income() -> int:
	var total: int = 0
	for id in gs.held_blocks.keys():
		total += block_income(str(id))
	return total

## Held blocks cost heat whether or not anyone is standing on them.
func nightly_heat() -> float:
	var total: float = 0.0
	for id in gs.held_blocks.keys():
		total += float(gs.block_by_id(str(id)).get("heat_exposure", 0))
	return total

func _on_day_crossed() -> void:
	if gs.game_over or gs.held_blocks.is_empty():
		return

	var income: int = nightly_income()
	if income > 0:
		gs.cash += income
		gs.log_activity("The corners brought in $%d." % income, GREEN)

	# Deshawn damps this the same way he damps a stickup — it is heat the
	# operation generates, and it routes through the same multiplier.
	var raw: float = nightly_heat()
	if raw > 0.0:
		var crew: Object = gm.system("crew") if gm != null else null
		var mult: float = crew.heat_multiplier() if crew != null else 1.0
		gs.heat = clampf(gs.heat + raw * mult, 0.0, float(gs.heat_max))

	var unstaffed: Array = []
	for id in gs.held_blocks.keys():
		if int(gs.held_blocks[id].get("soldiers", 0)) <= 0:
			unstaffed.append(str(gs.block_by_id(str(id))["name"]))
	if not unstaffed.is_empty():
		gs.log_activity("%s sat empty. Still yours, still noticed." % ", ".join(unstaffed), RED)

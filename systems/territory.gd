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
	return action in ["claim_block", "abandon_block", "recruit_soldier", "post_soldier", "pull_soldier", "stand_watch"]

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
		"stand_watch":
			return _stand_watch(block_id)
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
	# OG-D2: a corner needs a name behind it.
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null and not exposure.has_rank("player"):
		return "You are not a player yet. A corner needs a name behind it."
	# BR-D4: a block is claimed where it stands. The district has to be one
	# the run knows, and you have to be in it.
	var district := str(b.get("district", "north_star_lot"))
	if not district in gs.districts_unlocked:
		return "You don't know that part of town yet."
	if gs.current_district_id != district:
		return "You have to be standing there."
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

# --- OG-D6 (1.0.0 PR 6): his blocks fight back ----------------------------------
#
# A block that starts as Curtis's is not claimed, it is taken. The tap
# opens a confrontation on the engine's own chassis: one contested road
# (FIGHT: your crew, your kit, his people) and one guaranteed out (RUN).
# Winning is the claim, plus a night Curtis's people come back for it.
# Losing is no block, a hospital bill, and Curtis knowing your name a
# little better. And every night, Curtis probes: an undefended corner in a
# district he has people in can be lost; a defended one can lose a
# soldier; a corner taken from him last night is contested at even odds.

const CONTEST_BASE := 0.35
const CONTEST_PER_CREW := 0.08
const CONTEST_PER_SOLDIER := 0.04
const CONTEST_BLOCK_HEAT := 0.05
const CONTEST_AWARENESS := 0.02
const CONTEST_WIN_AWARENESS := 2
const CONTEST_LOSS_AWARENESS := 3
const CONTEST_LOSS_HEALTH := 8
const PROBE_UNDEFENDED := 0.15
const PROBE_DEFENDED := 0.05
const PROBE_CONTESTED := 0.5
## HS-D1 (1.2.0): a front is a bill. A block his people keep coming by pays
## half -- the customers stay home -- and costs a point of raw heat a night
## on top of its own exposure. It stays contested until it has survived
## FRONT_QUIET_NIGHTS nights; then his people stop coming by and it is yours
## the way the others are.
const CONTESTED_INCOME := 0.5
const CONTESTED_HEAT := 1.0
const FRONT_QUIET_NIGHTS := 3
## HS-D2 (1.2.0): a corner somebody is standing on tonight -- Tone, on the
## whole district, or you, on one block for a slot -- is almost never tested,
## and a front there counts two quiet nights in one.
const PROBE_HELD_DOWN := 0.02
## HS-D3 (1.2.0): he comes back. Every RECOVERY_EVERY nights, in a district
## he has people in, he sends them back to the weakest block you took from
## him -- the fewest soldiers, ties to the cheaper one -- and it is
## contested again, at even odds, unless somebody is standing on it. He
## does not come back to a district he is out of, and he does not send
## people while a front there is still open.
const RECOVERY_EVERY := 4
const RECOVERY_CHANCE := 0.5
## And then he does not. A district where every block he started with is
## yours, none of them contested, for DISMANTLE_NIGHTS settles in a row, is
## one he is out of: no probes, no recovery, and the corners there pay a
## quarter more, because his customers are yours now.
const DISMANTLE_NIGHTS := 2
const DISMANTLED_INCOME := 1.25

## The blocks he started with in a district.
func curtis_start_blocks(district_id: String) -> Array:
	var out: Array = []
	for b in gs.TERRITORY_DEFS.nodes_in(district_id):
		if str((b as Dictionary).get("starting_owner", "")) == gs.TERRITORY_DEFS.OWNER_CURTIS:
			out.append(str((b as Dictionary)["id"]))
	return out

## How many of the blocks he started with he still holds there.
func his_hold(district_id: String) -> int:
	var n := 0
	for id in curtis_start_blocks(district_id):
		if not gs.holds_block(str(id)):
			n += 1
	return n

func is_dismantled(district_id: String) -> bool:
	return district_id in (gs.curtis_dismantled as Array)

func dismantle_hold(district_id: String) -> int:
	return int((gs.curtis_dismantle_hold as Dictionary).get(district_id, 0))

## The condition, tonight: everything he started with there is yours and
## nobody is fighting over any of it.
func dismantle_condition(district_id: String) -> bool:
	var his: Array = curtis_start_blocks(district_id)
	if his.is_empty():
		return false
	for id in his:
		if not gs.holds_block(str(id)) or is_contested(str(id)):
			return false
	return true

## Nightly, after the probes: the weakest block you took from him, back on
## the board. Pure of side effects except the front and the line.
func _curtis_recovers(ended_day: int) -> void:
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null or ended_day % RECOVERY_EVERY != 0:
		return
	for district_id in gs.TERRITORY_DEFS.DISTRICT_ORDER:
		var district := str(district_id)
		if int(gs.district_by_id(district).get("rival", 0)) <= 0 or is_dismantled(district):
			continue
		var weakest := ""
		var weakest_soldiers := 999
		var weakest_cost := 999999
		var open_front := false
		for id in curtis_start_blocks(district):
			if not gs.holds_block(str(id)):
				continue
			if is_contested(str(id)):
				open_front = true
				break
			var soldiers: int = int((gs.territory_nodes[id] as Dictionary).get("soldiers", 0))
			var cost: int = int(gs.block_by_id(str(id)).get("claim_cost", 0))
			if soldiers < weakest_soldiers or (soldiers == weakest_soldiers and cost < weakest_cost):
				weakest = str(id)
				weakest_soldiers = soldiers
				weakest_cost = cost
		if open_front or weakest.is_empty():
			continue
		if is_held_down(weakest):
			continue
		var roll: int = rng.seeded_int_range(gs.run_seed, "%d:recover:%s" % [ended_day, district], 0, 99)
		if roll >= int(RECOVERY_CHANCE * 100.0):
			continue
		gs.territory_fronts[weakest] = {"capture_reward_consumed": true, "conflict_active": true, "quiet": 0}
		gs.log_activity("His people are back on %s. Different faces, same car." % _block_name(weakest), RED)
		_probe_text("Curtis's people are back on %s. Different faces, same car." % _block_name(weakest))

## Nightly, after recovery: the hold toward him being out of a district,
## and the night it lands.
func _settle_dismantling() -> void:
	for district_id in gs.TERRITORY_DEFS.DISTRICT_ORDER:
		var district := str(district_id)
		if is_dismantled(district):
			continue
		if not dismantle_condition(district):
			if dismantle_hold(district) > 0:
				gs.curtis_dismantle_hold[district] = 0
			continue
		var hold: int = dismantle_hold(district) + 1
		gs.curtis_dismantle_hold[district] = hold
		if hold < DISMANTLE_NIGHTS:
			gs.log_activity("Every block of his in %s is yours tonight. One more night like this and he stops coming." % _district_name(district), AMBER)
			continue
		_dismantle(district)

func _dismantle(district: String) -> void:
	gs.curtis_dismantled.append(district)
	gs.curtis_dismantle_hold.erase(district)
	var name := _district_name(district)
	gs.log_activity("Curtis is out of %s. His people stopped coming, then stopped being his. The corners here are yours the way the block is." % name, GREEN)
	var phone: Object = gm.system("phone") if gm != null else null
	if phone != null:
		phone.push_text("Goodie", "curtis pulled his people out of %s. thats not a thing he does. everybody heard." % name.to_lower(), "goodie_dismantled")
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null:
		for npc_id in ["curtis", "dre", "goodie"]:
			exposure.record_observation(npc_id, {"type": "growth", "event": "dismantled_curtis",
				"source": "network", "location": district})

func _district_name(district_id: String) -> String:
	return str(gs.district_by_id(district_id).get("name", district_id)).capitalize()
const HELD_DOWN_QUIET := 2

## The district Tone is sitting on tonight, or "". Reads the live
## assignment: crew operations settle at PRE_SETTLE, so by the time the
## night's probes run the assignment is settled and still today's.
func held_down_district() -> String:
	var entry: Variant = gs.crew_assignments.get("tone")
	if not (entry is Dictionary):
		return ""
	var assignment: Dictionary = entry
	if int(assignment.get("day", -1)) != int(gs.day) or str(assignment.get("operation_id", "")) != "hold_it_down":
		return ""
	var params: Variant = assignment.get("params")
	if params is Dictionary:
		return str((params as Dictionary).get("district_id", ""))
	return ""

## You, on this corner, tonight.
func is_watched(block_id: String) -> bool:
	return int((gs.territory_nodes.get(block_id, {}) as Dictionary).get("watch_day", -1)) == int(gs.day)

## Somebody is standing on it tonight, one way or the other.
func is_held_down(block_id: String) -> bool:
	if is_watched(block_id):
		return true
	var district: String = held_down_district()
	return not district.is_empty() and str(gs.TERRITORY_DEFS.district_of(block_id)) == district

func stand_watch_blocker(block_id: String) -> String:
	if gs.game_over:
		return "The run is over"
	if not gs.holds_block(block_id):
		return "Not yours"
	if str(gs.TERRITORY_DEFS.district_of(block_id)) != str(gs.current_district_id):
		return "You stand watch where you stand"
	if is_watched(block_id):
		return "You are already on it tonight"
	return ""

## One slot, one corner, tonight. Zero money: it costs the part of the day
## you would have spent earning, which is the whole price.
func _stand_watch(block_id: String) -> Dictionary:
	var blocked := stand_watch_blocker(block_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked + "."}
	var rec: Dictionary = gs.territory_nodes[block_id]
	rec["watch_day"] = int(gs.day)
	gs.territory_nodes[block_id] = rec
	gs.log_activity("You stand on %s until the block stops looking. It takes the rest of the part." % _block_name(block_id), AMBER)
	var time_sys: Object = gm.system("time") if gm != null else null
	if time_sys != null:
		time_sys.handle("advance_time", {})
	return {"ok": true}

func is_contested(block_id: String) -> bool:
	return bool((gs.territory_fronts.get(block_id, {}) as Dictionary).get("conflict_active", false))

func front_quiet(block_id: String) -> int:
	return int((gs.territory_fronts.get(block_id, {}) as Dictionary).get("quiet", 0))

## Every block his people are still coming by.
func contested_blocks() -> Array:
	var out: Array = []
	for id in gs.territory_nodes.keys():
		if is_contested(str(id)):
			out.append(str(id))
	return out

func _is_curtis_block(block_id: String) -> bool:
	return str(gs.block_by_id(block_id).get("starting_owner", "")) == gs.TERRITORY_DEFS.OWNER_CURTIS

## What taking a Curtis block is worth, on the odds.
func contest_chance(block_id: String) -> float:
	var b: Dictionary = gs.block_by_id(block_id)
	var chance: float = CONTEST_BASE
	chance += CONTEST_PER_CREW * float(gs.recruited_crew().size())
	chance += CONTEST_PER_SOLDIER * float(gs.soldiers_idle)
	chance += float(gs.weapon_def().get("fight_bonus", 0.0))
	chance -= CONTEST_BLOCK_HEAT * float(b.get("heat_exposure", 0))
	chance -= CONTEST_AWARENESS * float(gs.curtis_awareness)
	return clampf(chance, 0.10, 0.85)

func _open_contest(block_id: String) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var b: Dictionary = gs.block_by_id(block_id)
	var name := str(b.get("name", block_id))
	gs.log_activity("%s is Curtis's. His people are standing on it, and they were told you might come." % name, AMBER)
	return engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": gs.current_district_id,
		"return_route": "HOME",
		"source": {"family": "territory", "kind": "block_contest", "action_id": "territory",
			"target_id": block_id, "target_name": name,
			"opponent": "Curtis's people on %s" % name},
		"decision": {
			"allowed_choices": ["take_it", "back_off"],
			"deterministic_choices": ["back_off"],
			"shown_probabilities": {"take_it": contest_chance(block_id)},
		},
	})

## The engine's seam: the committed road resolves here.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var decision: Dictionary = chain.get("decision", {})
	var source: Dictionary = chain.get("source", {})
	var block_id := str(source.get("target_id", ""))
	var b: Dictionary = gs.block_by_id(block_id)
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	var tier := "deterministic"
	var health := 0
	if choice_id == "take_it":
		var resolver: Object = gm.system("outcome_resolver")
		var attributes: Object = gm.system("attributes")
		var key := "%d:%d:contest:%s" % [gs.day, gs.time_slots_today, block_id]
		tier = "failure"
		if resolver != null:
			tier = str((resolver.resolve_action("confrontation", contest_chance(block_id),
				int(attributes.effective("combat")) if attributes != null else 1,
				gs.run_seed, key) as Dictionary)["tier"])
		if tier in ["clean", "messy"]:
			_take_from_curtis(block_id)
			if curtis != null:
				curtis.raise_awareness(CONTEST_WIN_AWARENESS)
			if tier == "messy":
				health = CONTEST_LOSS_HEALTH / 2
		else:
			if curtis != null:
				curtis.raise_awareness(CONTEST_LOSS_AWARENESS)
			health = CONTEST_LOSS_HEALTH if tier == "failure" else CONTEST_LOSS_HEALTH * 2
			gs.log_activity("You do not take %s. His people make sure you remember trying." % str(b.get("name", "")), RED)
	else:
		if curtis != null:
			curtis.raise_awareness(1)
		gs.log_activity("You look at %s for a while and walk. They watched you do it." % str(b.get("name", "")), AMBER)
	if health > 0:
		var crew: Object = gm.system("crew")
		if crew != null:
			health = int(crew.absorbed_damage(health))
		gs.health = clampi(gs.health - health, 1, gs.health_max)
	decision["resolved_tier"] = tier
	decision["result"] = {"choice_id": choice_id, "tier": tier, "arrested": false, "banned": false,
		"cash": 0, "goods": 0, "health": -health, "heat": 0.0, "pressure": 0, "take_disposition": "keep"}
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": tier, "arrested": false}

## The claim, once the fight is won: the cost, the soldier, and a front
## Curtis will come back for.
func _take_from_curtis(block_id: String) -> void:
	var b: Dictionary = gs.block_by_id(block_id)
	_wallet().spend(mini(int(b["claim_cost"]), int(gs.cash)), _wallet().ROUTINE_DIRTY_FIRST,
		{"source_id": "territory_claim"})
	gs.soldiers_idle = maxi(0, int(gs.soldiers_idle) - 1)
	gs.territory_nodes[block_id] = {"soldiers": 1}
	gs.territory_fronts[block_id] = {"capture_reward_consumed": false, "conflict_active": true, "quiet": 0}
	gs.log_activity("%s is yours, and it was his. His people leave slowly, so you know they will be back." % str(b.get("name", block_id)), GREEN)

func choice_label(choice_id: String) -> String:
	return {"take_it": "FIGHT", "back_off": "RUN"}.get(choice_id, choice_id.capitalize())

func choice_copy(choice_id: String) -> String:
	return {
		"take_it": "Take it. Your crew, your kit, against whoever he left standing on it.",
		"back_off": "Not today. They watched you look at it.",
	}.get(choice_id, "")

func choice_guarantee(choice_id: String) -> String:
	if choice_id == "back_off":
		return "Guaranteed: nobody swings. Curtis hears you were looking."
	return ""

func result_headline(choice_id: String, tier: String, _effects: Dictionary) -> String:
	if choice_id == "back_off":
		return "YOU WALK"
	match tier:
		"clean": return "IT'S YOURS"
		"messy": return "IT'S YOURS, BARELY"
		"failure": return "NOT TODAY"
	return "HIS PEOPLE"

func result_body(choice_id: String, tier: String, _effects: Dictionary) -> String:
	if choice_id == "back_off":
		return "You look at the corner and walk. His people watch you do it, and one of them makes a call."
	match tier:
		"clean": return "They leave. Not fast, and not all at once, but they leave, and the corner is yours before dark. Curtis will hear how."
		"messy": return "It costs you, and it takes longer than it should, but by dark it is yours. Somebody will be back for it."
		"failure": return "There were more of them than you saw. You leave the corner where it was, and a piece of yourself on it."
	return "It goes badly, all the way through. His people put you on the ground in front of the block, and the block remembers that better than it remembers anything you held."

# --- Curtis probes -----------------------------------------------------------

## The chance a block gets tested tonight, by its state. Pure, so the suite
## can pin it.
func probe_chance(block_id: String) -> float:
	var district_id: String = str(gs.TERRITORY_DEFS.district_of(block_id))
	var rival: int = int(gs.district_by_id(district_id).get("rival", 0))
	if rival <= 0 or is_dismantled(district_id):
		return 0.0
	# HS-D2: somebody standing on it beats every other state.
	if is_held_down(block_id):
		return PROBE_HELD_DOWN
	if bool((gs.territory_fronts.get(block_id, {}) as Dictionary).get("conflict_active", false)):
		return PROBE_CONTESTED
	var soldiers: int = int((gs.territory_nodes.get(block_id, {}) as Dictionary).get("soldiers", 0))
	return PROBE_UNDEFENDED if soldiers <= 0 else PROBE_DEFENDED

## Nightly: every held block in a district Curtis has people in.
func _curtis_probes(ended_day: int) -> void:
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null:
		return
	for id in gs.territory_nodes.keys().duplicate():
		var block_id := str(id)
		var chance: float = probe_chance(block_id)
		var contested: bool = is_contested(block_id)
		var roll: int = rng.seeded_int_range(gs.run_seed, "%d:probe:%s" % [ended_day, block_id], 0, 99)
		if chance <= 0.0 or roll >= int(chance * 100.0):
			# HS-D1: a contested block that made it through the night is a
			# night quieter; three of those and his people stop coming by.
			if contested:
				_front_survived(block_id)
				# HS-D2: his people came by, saw who was standing there, left.
				if is_held_down(block_id) and is_contested(block_id):
					_front_survived(block_id)
			continue
		var soldiers: int = int((gs.territory_nodes[block_id] as Dictionary).get("soldiers", 0))
		if soldiers <= 0:
			_lose_block(block_id, "Nobody was standing on it.")
		else:
			var rec: Dictionary = gs.territory_nodes[block_id]
			rec["soldiers"] = soldiers - 1
			gs.territory_nodes[block_id] = rec
			_probe_text("Curtis's people tested %s last night. One of yours walked. The corner held." % _block_name(block_id))
			gs.log_activity("Curtis's people tested %s. One soldier walked off it rather than find out. It held." % _block_name(block_id), AMBER)

## HS-D1: one more night the front held. At FRONT_QUIET_NIGHTS the front
## closes: the block earns full, costs its own heat only, and probes at
## the ordinary rate.
func _front_survived(block_id: String) -> void:
	var front: Dictionary = gs.territory_fronts.get(block_id, {})
	front["quiet"] = int(front.get("quiet", 0)) + 1
	if int(front["quiet"]) >= FRONT_QUIET_NIGHTS:
		front["conflict_active"] = false
		gs.territory_fronts[block_id] = front
		gs.log_activity("His people stop coming by %s. It is yours the way the others are." % _block_name(block_id), GREEN)
		_probe_text("Curtis's people gave up on %s. Nobody's been by in three nights." % _block_name(block_id))
		return
	gs.territory_fronts[block_id] = front

## A block Curtis takes back.
func _lose_block(block_id: String, why: String) -> void:
	var name: String = _block_name(block_id)
	gs.territory_nodes.erase(block_id)
	gs.territory_fronts.erase(block_id)
	_discharge_over_capacity()
	gs.log_activity("%s is Curtis's again. %s By morning his people are on it like they never left." % [name, why], RED)
	_probe_text("Curtis took %s back last night. %s" % [name, why])

## Somebody on the crew says it, if there is somebody; the feed says it
## either way.
func _probe_text(text: String) -> void:
	var phone: Object = gm.system("phone") if gm != null else null
	if phone == null:
		return
	for id in ["deshawn", "eli", "tone", "pherris"]:
		if gs.is_recruited(id):
			phone.push_text(str(gs.crew_member_by_id(id).get("name", id)).split(" ")[0], text.to_lower() if id != "tone" else text, "")
			return

func _claim(block_id: String) -> Dictionary:
	var blocked := claim_blocker(block_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	# OG-D6: his blocks fight back.
	if _is_curtis_block(block_id):
		return _open_contest(block_id)
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
	# HS-D1: a corner people are fighting over pays half.
	if is_contested(block_id):
		total *= CONTESTED_INCOME
	# HS-D3: where he is out, his customers are yours.
	if is_dismantled(str(gs.TERRITORY_DEFS.district_of(block_id))):
		total *= DISMANTLED_INCOME
	return int(round(total))

func nightly_income() -> int:
	var total: int = 0
	for id in gs.territory_nodes.keys():
		total += block_income(str(id))
	return total

## Held blocks cost heat whether or not anyone is standing on them. HS-D1:
## a contested one costs a point more, because two crews on one corner is
## the kind of thing the block calls in.
func block_heat(block_id: String) -> float:
	var raw: float = float(gs.block_by_id(block_id).get("heat_exposure", 0))
	if is_contested(block_id):
		raw += CONTESTED_HEAT
	return raw

func nightly_heat() -> float:
	var total: float = 0.0
	for id in gs.territory_nodes.keys():
		total += block_heat(str(id))
	return total

# --- BR-D4: the board per district -------------------------------------------

## The authored blocks of one district.
func blocks_in(district_id: String) -> Array:
	return gs.TERRITORY_DEFS.nodes_in(district_id)

## How many of a district's blocks the run holds.
func held_in(district_id: String) -> int:
	var n := 0
	for id in gs.territory_nodes.keys():
		if gs.TERRITORY_DEFS.district_of(str(id)) == district_id:
			n += 1
	return n

## Soldiers posted in one district.
func posted_in(district_id: String) -> int:
	var n := 0
	for id in gs.territory_nodes.keys():
		if gs.TERRITORY_DEFS.district_of(str(id)) == district_id:
			n += int((gs.territory_nodes[id] as Dictionary).get("soldiers", 0))
	return n

## What one district's holdings bring in a night.
func income_in(district_id: String) -> int:
	var total := 0
	for id in gs.territory_nodes.keys():
		if gs.TERRITORY_DEFS.district_of(str(id)) == district_id:
			total += block_income(str(id))
	return total

## What one district's holdings cost in heat a night.
func heat_in(district_id: String) -> float:
	var total := 0.0
	for id in gs.territory_nodes.keys():
		if gs.TERRITORY_DEFS.district_of(str(id)) == district_id:
			total += block_heat(str(id))
	return total

## BR-D4: Ship Creek's value. Every held lot with a `supply_discount` cuts
## that much off every buy, anywhere; capped so three lots do not make
## product free.
const SUPPLY_DISCOUNT_CAP := 0.25

func supply_discount() -> float:
	var total := 0.0
	for id in gs.territory_nodes.keys():
		total += float(gs.block_by_id(str(id)).get("supply_discount", 0.0))
	return minf(total, SUPPLY_DISCOUNT_CAP)

## Why a district's board is closed, or "" when it is open.
func district_blocker(district_id: String) -> String:
	if district_id in gs.districts_unlocked:
		return ""
	match district_id:
		"downtown":
			return "Hold one corner in Spenard to open Downtown."
		"airport_industrial":
			return "Hold two corners to open Ship Creek."
		"mountain_view":
			return "Get established in Spenard. The block opens on day %d, or sooner if somebody names it." % int(gs.MOUNTAIN_VIEW_DAY)
	return "Not yet."

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
		# BR-D4: heat lands where the block stands, district by district.
		for district_id in gs.TERRITORY_DEFS.DISTRICT_ORDER:
			var raw: float = heat_in(str(district_id))
			if raw > 0.0:
				_heat().apply_gain(raw, _heat().FAMILY_NONE, str(district_id),
					{"source_id": "territory_nightly"})

		var unstaffed: Array = []
		for id in gs.territory_nodes.keys():
			if int(gs.territory_nodes[id].get("soldiers", 0)) <= 0:
				unstaffed.append(_block_name(str(id)))
		if not unstaffed.is_empty():
			gs.log_activity("%s sat empty all night. Still yours. Somebody noticed it was." % ", ".join(unstaffed), RED)
		# OG-D6: and Curtis noticed.
		_curtis_probes(_ended_day)
		# HS-D3: he comes back, and then he does not.
		_curtis_recovers(_ended_day)
	_settle_dismantling()

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

extends RefCounted
## Crew — people who work for you, and the wage clock that decides if they stay.
##
## Ported from src/data/npcs.js (CREW), src/data/crew.js (loyalty, tiers, wages,
## effect tables) and the RECRUIT_CREW / PAY_CREW / PROMOTE_CREW_TIER reducers.
##
## The wage clock is the system. A wage accrues every night whether or not it is
## paid; two nights are grace; after that loyalty falls a point a night, and at
## zero loyalty they walk. Paying clears the ledger and buys a point back. Crew
## is the first thing in the game with a running cost.
##
## **This is what makes `crew_power` a live stat** — it has read 0 in the HUD
## since the first build with nothing able to move it. Canon's contribution per
## head is `power + clamp(loyalty - 5, 0, 3) - (wageDue > 0 ? 2 : 0)`, so an
## unpaid crew is worth less than a paid one before they ever leave.
##
## Canon gates recruiting behind things that do not exist yet, each named here:
##   base.controlled / base.visiting → no garage, so recruiting happens anywhere
##   crew.introduced, contactStage   → no NPC introduction arcs, so all four are
##                                     recruitable from Day 1
##   crewRecruitmentEligible proof   → no behaviour/proof tracking
##   crewCapacityFor base upgrades   → capacity fixed at canon's floor of 2
##
## Tone's defense multiplier is stored and surfaced but has nothing to multiply
## until combat encounters land. Deshawn's heat reduction IS applied — see
## `heat_multiplier()`, which stickup and boost both route through.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node

func setup(game_state: Node) -> void:
	gs = game_state
	gs.day_crossed.connect(_on_day_crossed)

func can_handle(action: String) -> bool:
	return action in ["recruit_crew", "pay_crew", "promote_crew", "dismiss_crew"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	var id: String = str(payload.get("crew_id", ""))
	match action:
		"recruit_crew":
			return _recruit(id)
		"pay_crew":
			return _pay(id)
		"promote_crew":
			return _promote(id)
		"dismiss_crew":
			return _dismiss(id)
	return {"ok": false, "reason": "Unknown crew action."}

# --- recruiting ------------------------------------------------------------

func recruit_blocker(id: String) -> String:
	if gs.game_over:
		return "The run is over."
	var person: Dictionary = gs.crew_member_by_id(id)
	if person.is_empty():
		return "Nobody by that name."
	if gs.is_recruited(id):
		return "Already with you."
	if str(gs.crew_record(id).get("status", "")) == "departed":
		return "They already walked."
	if gs.recruited_crew().size() >= gs.CREW_CAPACITY:
		return "No room. %d is all you can carry." % gs.CREW_CAPACITY
	if gs.cash < int(person["cost"]):
		return "Need $%d." % int(person["cost"])
	return ""

func _recruit(id: String) -> Dictionary:
	var blocked := recruit_blocker(id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var person: Dictionary = gs.crew_member_by_id(id)
	gs.cash -= int(person["cost"])
	gs.crew_records[id] = {
		"recruited": true,
		"status": "active",
		"loyalty": gs.CREW_LOYALTY_START,
		"tier": 1,
		"wage_due": 0,
		"wage_missed_since": -1,
		"recruited_day": gs.day,
	}
	_recompute_power()
	gs.log_activity("%s is on the crew." % str(person["name"]).split(" ")[0], GREEN)
	return {"ok": true}

func _dismiss(id: String) -> Dictionary:
	if not gs.is_recruited(id):
		return {"ok": false, "reason": "Not on the crew."}
	var rec: Dictionary = gs.crew_records[id]
	rec["status"] = "departed"
	rec["recruited"] = false
	_recompute_power()
	gs.log_activity("%s is off the crew." % str(gs.crew_member_by_id(id)["name"]).split(" ")[0], AMBER)
	return {"ok": true}

# --- wages -----------------------------------------------------------------

func pay_blocker(id: String) -> String:
	if not gs.is_recruited(id):
		return "Not on the crew."
	var rec: Dictionary = gs.crew_record(id)
	var due: int = int(rec.get("wage_due", 0))
	if due <= 0:
		return "Nothing owed."
	if gs.cash < due:
		return "Need $%d." % due
	return ""

func _pay(id: String) -> Dictionary:
	var blocked := pay_blocker(id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var rec: Dictionary = gs.crew_records[id]
	var amount: int = int(rec["wage_due"])
	gs.cash -= amount
	rec["wage_due"] = 0
	rec["wage_missed_since"] = -1
	rec["loyalty"] = clampi(int(rec["loyalty"]) + 1, gs.CREW_LOYALTY_MIN, gs.CREW_LOYALTY_MAX)
	_recompute_power()
	gs.log_activity("%s folds the full $%d into a pocket." % [str(gs.crew_member_by_id(id)["name"]).split(" ")[0], amount], GREEN)
	return {"ok": true, "paid": amount}

# --- tiers -----------------------------------------------------------------

func promote_blocker(id: String) -> String:
	if not gs.is_recruited(id):
		return "Not on the crew."
	var rec: Dictionary = gs.crew_record(id)
	var target: int = int(rec.get("tier", 1)) + 1
	if not gs.CREW_TIER_REQUIREMENTS.has(target):
		return "Nowhere higher to go."
	var req: Dictionary = gs.CREW_TIER_REQUIREMENTS[target]
	if int(rec.get("loyalty", 0)) < int(req["loyalty"]):
		return "Needs loyalty %d." % int(req["loyalty"])
	var days: int = gs.day - int(rec.get("recruited_day", gs.day))
	if days < int(req["days"]):
		return "Needs %d more days." % (int(req["days"]) - days)
	return ""

func _promote(id: String) -> Dictionary:
	var blocked := promote_blocker(id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var rec: Dictionary = gs.crew_records[id]
	rec["tier"] = int(rec["tier"]) + 1
	_recompute_power()
	gs.log_activity("%s moves up to tier %d. The wage moves with it." % [str(gs.crew_member_by_id(id)["name"]).split(" ")[0], int(rec["tier"])], GREEN)
	return {"ok": true}

# --- effects ---------------------------------------------------------------

## Canon crew power: per head, `power + clamp(loyalty - 5, 0, 3)`, less 2 while
## a wage is outstanding. An unpaid crew is worth less before they ever leave.
func _recompute_power() -> void:
	var total: int = 0
	for person in gs.recruited_crew():
		var rec: Dictionary = gs.crew_record(str(person["id"]))
		total += int(person["power"]) \
			+ clampi(int(rec.get("loyalty", 0)) - gs.CREW_LOYALTY_START, 0, 3) \
			- (2 if int(rec.get("wage_due", 0)) > 0 else 0)
	gs.crew_power = maxi(0, total)

## Canon DESHAWN_HEAT_REDUCTION, applied to heat any surface generates. Returns
## 1.0 when he is not on the crew, so callers can multiply unconditionally.
func heat_multiplier() -> float:
	if not gs.is_recruited("deshawn"):
		return 1.0
	var tier: int = int(gs.crew_record("deshawn").get("tier", 1))
	return float(gs.DESHAWN_HEAT_REDUCTION.get(tier, 1.0))

## Canon TONE_DEFENSE_MULTIPLIER. Stored and surfaced; nothing multiplies it
## until combat encounters land in a later phase.
func defense_multiplier() -> float:
	if not gs.is_recruited("tone"):
		return 1.0
	var tier: int = int(gs.crew_record("tone").get("tier", 1))
	return float(gs.TONE_DEFENSE_MULTIPLIER.get(tier, 1.0))

## Boost tier 3 waits on somebody who can be field-assigned. Every canon crew
## member can be, so this is really "is there anyone at all".
func has_field_crew() -> bool:
	return not gs.recruited_crew().is_empty()

# --- the nightly wage clock ------------------------------------------------

func _on_day_crossed() -> void:
	if gs.game_over:
		return
	for person in gs.crew_roster:
		var id: String = str(person["id"])
		if not gs.is_recruited(id):
			continue
		var rec: Dictionary = gs.crew_records[id]
		var wage: int = gs.crew_wage_for(id, int(rec.get("tier", 1)))
		rec["wage_due"] = int(rec.get("wage_due", 0)) + wage

		if int(rec.get("wage_missed_since", -1)) < 0:
			rec["wage_missed_since"] = gs.day
		var missed_for: int = gs.day - int(rec["wage_missed_since"])
		var first_name: String = str(person["name"]).split(" ")[0]
		if missed_for >= gs.CREW_WAGE_GRACE_DAYS:
			rec["loyalty"] = clampi(int(rec["loyalty"]) - 1, gs.CREW_LOYALTY_MIN, gs.CREW_LOYALTY_MAX)
			gs.log_activity("%s didn't say anything about the money again. That's worse." % first_name, RED)
		else:
			gs.log_activity("No cash for %s's wage tonight. It goes on the ledger." % first_name, AMBER)

		if int(rec["loyalty"]) <= gs.CREW_LOYALTY_MIN:
			rec["status"] = "departed"
			rec["recruited"] = false
			gs.log_activity("%s is gone. Nobody had to say why." % first_name, RED)
	_recompute_power()

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
## Reached for the wallet. Recruiting and paying wages both spend.
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager
	# Driven by DayLifecycle in declared order. See systems/day_lifecycle.gd.

## The exposure layer, or null before it exists. Every system reaches it the
## same way so the null-check lives in one shape rather than five.
func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func _curtis_node() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Curtis")

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
	# Through crew_capacity(), not the const: base upgrades extend it later and
	# every caller should already be asking rather than reading.
	var capacity: int = gs.crew_capacity()
	if gs.recruited_crew().size() >= capacity:
		return "No room. %d is all you can carry." % capacity
	if gs.cash < int(person["cost"]):
		return "Need $%d." % int(person["cost"])
	return ""

func _recruit(id: String) -> Dictionary:
	var blocked := recruit_blocker(id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var person: Dictionary = gs.crew_member_by_id(id)
	var wallet: Object = gm.system("wallet")
	wallet.spend(int(person["cost"]), wallet.ROUTINE_DIRTY_FIRST,
		{"source_id": "crew_recruit_%s" % id})
	gs.crew_records[id] = {
		"recruited": true,
		"status": "active",
		"loyalty": gs.CREW_LOYALTY_START,
		"tier": 1,
		"wage_due": 0,
		"wage_missed_since": -1,
		"recruited_day": gs.day,
		# FS-001.5: behaviour-based gates read this. Nothing writes to it yet —
		# it ships now so the record shape is settled before a save carries one
		# without it. See crew_proofs() for how an older record reads.
		"proofs": {},
	}
	_recompute_power()
	gs.log_activity("%s is on the crew." % str(person["name"]).split(" ")[0], GREEN)
	# Canon: crew_recruited is `growth` on the neighbourhood channel. Curtis
	# weights growth at -3.0, so building an operation is exactly the thing that
	# makes a rival colder — which is the point.
	var curtis: Node = _curtis_node()
	if curtis != null:
		curtis.broadcast_tracked({
			"type": "growth", "event": "crew_recruited",
			"location": gs.current_district_id, "channel": "neighborhood",
		})
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
	var wallet: Object = gm.system("wallet")
	wallet.spend(amount, wallet.ROUTINE_DIRTY_FIRST,
		{"source_id": "crew_wage_%s" % id})
	rec["wage_due"] = 0
	rec["wage_missed_since"] = -1
	rec["loyalty"] = clampi(int(rec["loyalty"]) + 1, gs.CREW_LOYALTY_MIN, gs.CREW_LOYALTY_MAX)
	_recompute_power()
	gs.log_activity("%s folds the full $%d into a pocket." % [str(gs.crew_member_by_id(id)["name"]).split(" ")[0], amount], GREEN)
	var exposure: Node = _exposure()
	if exposure != null:
		exposure.broadcast_observation({
			"type": "loyalty", "event": "paid_the_crew", "channel": "network",
		})
	return {"ok": true, "paid": amount}

# --- tiers -----------------------------------------------------------------

## Is there an authored rank above this one at all?
##
## Separate from `promote_blocker` on purpose. "You cannot promote yet" and
## "there is nothing to promote to" are different facts, and only the first is a
## blocker the player can work against. The screen hides the control on the
## second rather than showing a disabled button for a ladder that does not
## exist — so this is a predicate rather than a string the UI has to match on.
func at_top_rank(id: String) -> bool:
	var rec: Dictionary = gs.crew_record(id)
	return not gs.CREW_TIER_REQUIREMENTS.has(int(rec.get("tier", 1)) + 1)

func promote_blocker(id: String) -> String:
	if not gs.is_recruited(id):
		return "Not on the crew."
	if at_top_rank(id):
		return "Nowhere higher to go."
	var rec: Dictionary = gs.crew_record(id)
	var target: int = int(rec.get("tier", 1)) + 1
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
	gs.log_activity("%s is %s now. The wage moves with it."
		% [str(gs.crew_member_by_id(id)["name"]).split(" ")[0],
			gs.rank_label(int(rec["tier"])).capitalize()], GREEN)
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
	# Through the rank curve, not `.get(tier, 1.0)`. The dictionary lookup was a
	# latent bug: at any rank above 3 it missed and returned the neutral 1.0, so
	# a promotion would have REMOVED the heat reduction Deshawn already earned.
	# Nothing can reach rank 4 today, which is exactly why it had to be fixed
	# before something can — a benefit that silently vanishes on promotion is
	# not the kind of bug that gets noticed, it is the kind that gets shipped.
	return float(gs.curve_value_for_rank(gs.DESHAWN_HEAT_REDUCTION, tier, 1.0))

## Canon TONE_DEFENSE_MULTIPLIER. Stored and surfaced; nothing multiplies it
## until combat encounters land in a later phase.
func defense_multiplier() -> float:
	if not gs.is_recruited("tone"):
		return 1.0
	var tier: int = int(gs.crew_record("tone").get("tier", 1))
	# Same clamp, same reason — see heat_multiplier().
	return float(gs.curve_value_for_rank(gs.TONE_DEFENSE_MULTIPLIER, tier, 1.0))

## What this person has PROVEN, for the gates that read behaviour rather than
## numbers. Empty for an unknown id, and — the case that matters — empty for a
## record saved before the field existed.
##
## No save schema bump for this. `crew_records` already round-trips as a
## Dictionary in PERSIST_FIELDS, and a v6 record without `proofs` reads as `{}`
## here rather than erroring: canon's mergeDefaults pattern applied inside a
## persisted dictionary instead of at the top level.
func crew_proofs(id: String) -> Dictionary:
	var proofs: Variant = gs.crew_record(id).get("proofs", {})
	return proofs if proofs is Dictionary else {}

## The rank a crew member reads as. The player is told this and never the tier
## number — same rule the attribute labels follow.
func rank_label(id: String) -> String:
	return gs.rank_label(int(gs.crew_record(id).get("tier", 1)))

## Boost tier 3 waits on somebody who can be field-assigned. Every canon crew
## member can be, so this is really "is there anyone at all".
func has_field_crew() -> bool:
	return not gs.recruited_crew().is_empty()

# --- the nightly wage clock ------------------------------------------------

## The nightly wage clock, settled FIRST in the declared order: canon settles
## wages before anything reads whether they were paid, and an unpaid crew is
## worth less power — which territory income is computed off.
##
## **`settling_day` is `ended_day + 1`, and that is deliberate.**
##
## Canon's `resolveCrewTracks` runs above the increment and sees the ending day.
## This port has always run it below, seeing the NEW day, and the wage sentinel
## it stamps persists in saves and is read by `payroll_not_delinquent`. Moving
## it now would shift when wages bite by a day and change an eligibility gate
## that is already shipped.
##
## So the arithmetic is explicit rather than positional: the behaviour is
## byte-identical to before this refactor, and the divergence from canon is
## named here rather than hidden in signal ordering. Correcting it is a timing
## change and belongs in its own slice.
## Wages, settled against the day that ENDED.
##
## This used to read `ended_day + 1`. The reason is worth keeping: this port
## originally settled crew BELOW DayLifecycle's increment, so it saw the new day
## on the clock, and when FS-003.2 moved settlement above the increment the `+ 1`
## was kept so behaviour did not change inside a refactor that claimed to change
## nothing. Canon settles here — `applyAttendance(state, oldDay)`, with the
## comment "so the rung does not depend on sitting above the `run.day = oldDay
## + 1` line further down" — and this is the slice that corrects it.
##
## What actually moves: `wage_missed_since` is now stamped with the day the wage
## was missed rather than the morning after. The DELTA it feeds is unchanged for
## a fresh run (stamp and comparison shift together), but the recorded value is
## the honest one, and `requirements.payroll_not_delinquent` — which compares it
## against the LIVE day, not against this settlement — now measures delinquency
## from the night it started instead of a day late.
func settle_night(ended_day: int) -> void:
	if gs.game_over:
		return
	var settling_day: int = ended_day
	for person in gs.crew_roster:
		var id: String = str(person["id"])
		if not gs.is_recruited(id):
			continue
		var rec: Dictionary = gs.crew_records[id]
		var wage: int = gs.crew_wage_for(id, int(rec.get("tier", 1)))
		rec["wage_due"] = int(rec.get("wage_due", 0)) + wage

		if int(rec.get("wage_missed_since", -1)) < 0:
			rec["wage_missed_since"] = settling_day
		var missed_for: int = settling_day - int(rec["wage_missed_since"])
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

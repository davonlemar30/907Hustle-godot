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
##   crew.introduced, contactStage   → no NPC introduction arcs; since OG-D2
##                                     (1.0.0) all four gate on the player being
##                                     KNOWN (`recruit_blocker`), not on a day
##   crewRecruitmentEligible proof   → no behaviour/proof tracking for RECRUITING;
##                                     PROMOTION proofs exist as of RM-D3 (1.4.0)
##   crewCapacityFor base upgrades   → capacity fixed at canon's floor of 2
##
## Tone's defense multiplier IS applied as of batch 6b — see `absorbed_damage()`.
## It was stored and surfaced for the whole life of the port and multiplied
## nothing: the Crew screen printed "defense x1.15" at a player it did nothing
## for. The note here said it was waiting on combat encounters, and combat
## encounters arrived in FS-003.7 — a blown lift opens a Caught chain with
## Fight, Run, Talk and Yield, resolved through the outcome resolver, and every
## bad answer to one costs health. That is the thing it defends against.
##
## Deshawn's heat reduction was already applied — see `heat_multiplier()`, which
## stickup and boost both route through.

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
	# OG-D2: a crew is not bought, it is joined. Nobody joins a nobody.
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null and not exposure.has_rank("known"):
		return "Nobody knows your name yet. Get known first."
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
	gs.log_activity("%s is in. Handshake, no paperwork, all the paperwork that matters." % str(person["name"]).split(" ")[0], GREEN)
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
	gs.log_activity("%s is out. No speech. Just gone from the group text." % str(gs.crew_member_by_id(id)["name"]).split(" ")[0], AMBER)
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

## RM-D4 (1.4.0): the rows a promotion to `tier` has to pass, for this person,
## in authored order -- the shared loyalty/tenure floor first, then their own
## proof (RM-D5). `crew_id` is stamped here so the tables stay per-tier data
## and the evaluator gets the record it asks for.
func tier_requirements(id: String, tier: int) -> Array:
	var rows: Array = []
	for row in (gs.CREW_TIER_REQUIREMENTS.get(tier, []) as Array):
		rows.append(_with_crew(row, id))
	var own: Dictionary = gs.PROMOTION_PROOFS.get(id, {})
	for row in (own.get(tier, []) as Array):
		rows.append(_with_crew(row, id))
	return rows

func _with_crew(row: Dictionary, id: String) -> Dictionary:
	var out: Dictionary = row.duplicate()
	out["crew_id"] = id
	return out

## The facts a promotion is judged against: this person's record and today.
## The same shape `crew_operations._facts()` hands the evaluator, so the
## tenure and loyalty rows read identically in both places.
func _promotion_facts(id: String) -> Dictionary:
	return {"crew": {id: gs.crew_record(id)}, "current_day": gs.day}

## The first failing row and its verdict, or {} when every row passes. Rows
## are walked one at a time rather than through `evaluate_requirements` so
## the copy below can name WHICH proof is short: the verdict carries
## `current` and `required` but not the row's key.
func promote_verdict(id: String) -> Dictionary:
	var requirements: RefCounted = gm.system("requirements") as RefCounted
	if requirements == null:
		return {}
	var target: int = int(gs.crew_record(id).get("tier", 1)) + 1
	var facts: Dictionary = _promotion_facts(id)
	for row in tier_requirements(id, target):
		var verdict: Dictionary = requirements.evaluate_requirement(row, facts)
		if not bool(verdict["ok"]):
			return {"row": row, "verdict": verdict}
	return {}

func promote_blocker(id: String) -> String:
	if not gs.is_recruited(id):
		return "Not on the crew."
	if at_top_rank(id):
		return "Nowhere higher to go."
	var failed: Dictionary = promote_verdict(id)
	if failed.is_empty():
		return ""
	return promotion_blocker_copy(failed["row"], failed["verdict"])

## The blocker in the player's words, with the evaluator's own numbers. The
## loyalty and tenure strings are the exact strings 1.3.0's two `if`s
## produced, asserted in parity; the proof string is new with RM-D5.
func promotion_blocker_copy(row: Dictionary, verdict: Dictionary) -> String:
	var required: int = int(float(verdict.get("required", 0)))
	var current_raw: Variant = verdict.get("current", 0)
	var current: int = int(float(current_raw)) if (current_raw is int or current_raw is float) and is_finite(float(current_raw)) else 0
	match str(row.get("type", "")):
		"crew_loyalty_min":
			return "Needs loyalty %d." % required
		"crew_tenure_days_min":
			return "Needs %d more days." % maxi(1, required - current)
		"proof_counter_min":
			var label := str(gs.PROOF_LABELS.get(str(row.get("key", "")), "proofs"))
			return "Needs %d %s, has %d." % [required, label, current]
	return "Not yet."

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
	# RM-D5: the fourth rung is the first one earned by proof, and the person
	# says so in their own voice. Ranks 2 and 3 keep 1.3.0's silence -- a text
	# there would be new behaviour on a rung this build promised not to touch.
	if int(rec["tier"]) == 4 and PROMOTION_TEXTS.has(id):
		var phone: Object = gm.system("phone") if gm != null else null
		if phone != null:
			phone.push_text(PROMOTION_SENDERS.get(id, id.capitalize()), str(PROMOTION_TEXTS[id]), "")
	return {"ok": true}

## RM-D5: what each of them says the day they make SPECIALIST LEAD. Short,
## in the Power register, a fact rather than a ceremony.
const PROMOTION_SENDERS := {"pherris": "Pherris", "eli": "Eli", "deshawn": "Deshawn", "tone": "Tone"}
const PROMOTION_TEXTS := {
	"pherris": "lead. I heard. I'm going to act like it, so get used to me having opinions about the board",
	"eli": "specialist lead. thats a title. same routes, i just dont wait to be told now",
	"deshawn": "appreciate that. for real. the block hears that kind of thing too, you know",
	"tone": "Lead. Fine. Means I stop waiting for the word.",
}

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

## Canon TONE_DEFENSE_MULTIPLIER.
func defense_multiplier() -> float:
	if not gs.is_recruited("tone"):
		return 1.0
	var tier: int = int(gs.crew_record("tone").get("tier", 1))
	# Same clamp, same reason — see heat_multiplier().
	return float(gs.curve_value_for_rank(gs.TONE_DEFENSE_MULTIPLIER, tier, 1.0))

## Health damage after Tone has stood where he stands.
##
## THE one place his multiplier is consumed, in the shape `heat_multiplier()`
## established and for the same reason: a benefit applied in two places is a
## benefit applied twice the day somebody adds a third caller, and "once" is
## only checkable if there is one function to check.
##
## The curve is a defence STRENGTH — {1: 1.15, 2: 1.30, 3: 1.50} — so damage is
## divided by it rather than multiplied: rank 1 takes about 13% off, rank 3 a
## third. Rounded rather than truncated, and floored at 1 whenever the raw
## damage was real: a hit that lands should cost something, and letting a rank-3
## Tone reduce a 1-point graze to nothing would make him a shield rather than an
## enforcer.
func absorbed_damage(raw: int) -> int:
	if raw <= 0:
		return 0
	var defence: float = defense_multiplier()
	if defence <= 1.0:
		return raw
	return maxi(1, int(round(float(raw) / defence)))

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

## RM-D3 (1.4.0): proof is written where the work settles. Each adapter's
## `settle()` calls this once for a night of REAL work -- a board with at
## least one cycle bought, a bag with a trip covered, relief actually applied,
## a district actually scouted, a corner actually held, a problem actually
## put down -- and never for the "nothing to do" outcome. One counter per
## operation id, keyed by the operation, so a proof is role-specific evidence
## that this person did THEIR job and never a shared pool anybody can grind
## (the owner's 2026-09-06 ruling: not a generic XP system). The requirement
## type that reads it is `proof_counter_min`; nothing else does.
##
## Writes into the same `crew_records[id]` dictionary the record already is;
## no schema bump, for the reason `crew_proofs()` gives.
func record_proof(id: String, key: String, amount: int = 1) -> void:
	if amount <= 0 or not gs.crew_records.has(id):
		return
	var rec: Dictionary = gs.crew_records[id]
	var proofs: Variant = rec.get("proofs", {})
	var table: Dictionary = proofs if proofs is Dictionary else {}
	table[key] = int(table.get(key, 0)) + amount
	rec["proofs"] = table
	gs.crew_records[id] = rec

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
## worth less power.
##
## This used to add "— which territory income is computed off", and that was
## false. `systems/territory.gd` never reads `crew_power`; `crew_power` is read
## by the HUD, the Crew screen and the save, and by nothing that settles. What
## settling first actually decides is Territory's HEAT, because a member marked
## departed below is a Deshawn who no longer damps it. (D-5, 2026-08-23.)
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
			gs.log_activity("No cash for %s tonight. It goes on a ledger only one of you is keeping." % first_name, AMBER)

		if int(rec["loyalty"]) <= gs.CREW_LOYALTY_MIN:
			rec["status"] = "departed"
			rec["recruited"] = false
			gs.log_activity("%s is gone. Nobody had to say why." % first_name, RED)
	_recompute_power()

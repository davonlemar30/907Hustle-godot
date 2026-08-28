extends RefCounted
## Opportunities — the shared substrate for offered, accepted, and settled
## work. Street Opportunity and Mission System, PR C:
## `docs/STREET_OPPORTUNITY_AND_MISSION_SYSTEM_DESIGN.md` (the umbrella; its
## section 9 shapes are the ones below — see `docs/DECISIONS.md`'s OPP-D
## table for the closed rulings, including where it wins over the thinner
## sketch in `docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` section 10.3).
## Dre's first two authored contracts (DRE-ARC-01/02) are its only content
## this build — `data/dre_contracts.gd`.
##
## ## One seam, not a second dispatch loop
##
## `reconcile(action, payload, result)` is called from ONE place —
## `GameManager.dispatch()`, immediately after `crew_ops.reconcile()` and
## before `reconcile_persistent_invariants()` — for every successful
## dispatch, Dre's or anyone else's. It reads what happened and, when a live
## instance's objective matches, mutates instance state directly. It never
## dispatches anything itself: a nested dispatch inside dispatch() would fire
## a second notify_changed inside this one's stack, the exact rule
## `crew_ops.reconcile()` already follows one call above this one.
##
## `reconcile_on_load()` is the qualifying-load counterpart, called from
## `SaveSystem.load_run()` beside the existing `crew_ops.reconcile()` call
## there: a save can already satisfy a definition's requirements the moment
## it loads — a PR B player who sought Dre out before this system existed
## never fired the reconcile this build adds, and would otherwise never see
## First Money at all. See that function's own header for the exact rules.
##
## ## Two authorities, never one thing twice
##
## DRE-ARC-01 (The Introduction) is NOT a tracked offered/active instance.
## `dre_lender._seek_out()` already owns the whole mechanical result —
## `dre_introduced`, the tier-1 latch, the slot cost — and shipped and
## merged before this system existed. Rebuilding that as a second authority
## here would be exactly the "two authorities" the design doc warns against
## (section 5.4 / addendum: "one authority only"). This system only records
## that it happened: a `completed`-only history entry with no
## `completion_effects`, written the first time `dre_seek_out` succeeds.
## DRE-ARC-02 (First Money) is the first real instance this system creates
## and settles end to end.
##
## ## What is deliberately NOT here (addendum, "what this is NOT authorizing")
##
## No adapter registry (umbrella section 19.2) — one Dre-specific seam is the
## whole integration surface a single consumer needs. No procedural
## generation, no unified Score presentation, no `opportunity_accept` dispatch
## action — nothing in this build's content ever needs one; the domain action
## that begins the work (`dre_borrow`) is authored to double as acceptance,
## per OPP-D3's "an authored meeting that both accepts and begins work."

const DRE_CONTRACTS := preload("res://data/dre_contracts.gd")
const REQUIREMENTS := preload("res://systems/requirements.gd")

## Typed completion effects, closed allowlist — addendum ruling OPP-D12, "the
## five PR C-E need." `announce_surface`/`record_proof` wait for a consumer
## and are deliberately absent. An unknown type fails closed with a warning
## rather than mutating anything a data file named.
const EFFECT_TYPES := ["wallet_credit", "exposure_observation", "access_milestone",
	"message", "offer_followup"]

## OPP-D2: three accepted commitments globally across contracts/missions/
## scores. Leads, standing surfaces, obligations, operations, and threats
## never occupy this — by construction, nothing but a contract/mission/score
## instance ever enters `active_opportunities` to begin with.
const MAX_ACCEPTED_COMMITMENTS := 3

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

## The only opportunity action this build's content needs a player-facing
## door for. Declining an offer is otherwise just leaving it alone — see the
## header on `dre_first_money` in `data/dre_contracts.gd` for why that offer
## carries no authored deadline.
func can_handle(action: String) -> bool:
	return action == "opportunity_decline"

func handle(action: String, payload: Dictionary) -> Dictionary:
	if action == "opportunity_decline":
		return decline(int(payload.get("instance_id", -1)))
	return {"ok": false, "reason": "Unknown opportunity action."}

# --- the one seam ------------------------------------------------------------

## Called from `GameManager.dispatch()` with the action that just
## succeeded, its payload, and the handler's own result dictionary — see
## this file's header for exactly where and why. `dre_seek_out` and
## `dre_borrow` are bespoke Dre glue (offer/accept have no generic data
## shape in this build — see "what is deliberately NOT here" above);
## objective completion is read generically off each live instance's
## definition, so a later PR's `action_result` objective needs no new
## branch here, only a new row in `data/dre_contracts.gd`.
func reconcile(action: String, _payload: Dictionary, result: Dictionary) -> void:
	if action == "dre_seek_out":
		_record_introduction_once()
		_maybe_offer("dre_first_money")
	elif action == "dre_borrow":
		_accept("dre_first_money")
	_advance_action_result_objectives(action, result)

## Qualifying load — the crew_operations precedent in `SaveSystem.load_run()`
## for the same reason: a save can already satisfy a definition's
## requirements before this system ever ran a reconcile for it. Every branch
## uses day -1 for anything it cannot honestly know, the same call the v20
## debt migration and the v21 `dre_intro_offered` migration make for a fact
## this build did not exist to record firsthand.
##
## `clear`/`loans_taken` is what tells the three cases apart. A clear account
## with zero loans ever taken means First Money was never touched, so it
## offers fresh if eligible. An open (non-clear) account with at most one
## loan on record means a first loan is in flight that this system never saw
## begin — activated retroactively rather than left to silently never
## resolve. That "at most one" (not "exactly one") is deliberate: the v19 ->
## v20 debt migration can hand a pre-PR-A save an open account with
## `loans_taken` still at its GameState default of zero, since the field did
## not exist yet to migrate — an open account with nothing recorded is that
## history, not a reason to treat it as untouched. Everything else — clear
## with one or more loans taken, or a SECOND loan open with two or more on
## record — means the first loan is already resolved (a second loan cannot
## begin without the first clearing — `dre_lender.borrow_blocker()`), so the
## milestone completes immediately rather than asking the player to somehow
## do it again.
func reconcile_on_load() -> void:
	if gs.dre_introduced:
		_record_introduction_once()
	if _resolved_or_live("dre_first_money"):
		return
	var loans_taken: int = int(gs.dre_account_history.get("loans_taken", 0))
	var clear: bool = str(gs.dre_account.get("status", "clear")) == "clear"
	if clear and loans_taken == 0:
		_maybe_offer("dre_first_money")
	elif not clear and loans_taken <= 1:
		var inst := _new_instance("dre_first_money", "active")
		inst["offered_day"] = -1
		inst["accepted_day"] = -1
		var active: Array = gs.active_opportunities
		active.append(inst)
		gs.active_opportunities = active
	else:
		_apply_effects(_definition("dre_first_money").get("completion_effects", []))
		_write_history("dre_first_money", "completed", -1)

# --- DRE-ARC-01 — recorded, never tracked (see header) ----------------------

func _record_introduction_once() -> void:
	if gs.opportunity_history.has("dre_the_introduction"):
		return
	_write_history("dre_the_introduction", "completed", gs.day)

# --- settlement-fact objectives (DayLifecycle.SETTLE_ORDER, "opportunities") -

## Called from `DayLifecycle` after every other night settlement — see the
## comment on `opportunities`'s place in `SETTLE_ORDER` for why it sits last.
## A no-op every night in this build: `dre_first_money`'s objective is
## `action_result`, not `state_fact`, because nothing in the current Dre
## state machine reaches "clear" except through a live `dre_repay` dispatch
## (reconciled at the point in `GameManager.dispatch()` instead). Declared
## and tested now so a later PR's settlement-driven objective — the design
## doc's own example is "a debt that resolved overnight" — needs no new
## SETTLE_ORDER entry, only a new `state_fact` row in its own data file.
func settle_night(_ended_day: int) -> void:
	_advance_state_fact_objectives()

func _advance_state_fact_objectives() -> void:
	var facts: Dictionary = _facts()
	for entry in (gs.active_opportunities as Array).duplicate():
		var inst: Dictionary = entry
		var definition: Dictionary = _definition(str(inst.get("definition_id", "")))
		for objective in (definition.get("objectives", []) as Array):
			var spec: Dictionary = objective
			if str(spec.get("class", "")) != "state_fact" or not spec.has("fact"):
				continue
			if facts.get(str(spec["fact"]), null) == spec.get("equals", null):
				_resolve(str(inst["definition_id"]), {})

# --- generic objective advancement ------------------------------------------

## `.duplicate()`: `_resolve()` mutates `gs.active_opportunities` when an
## objective completes, and this loop must keep walking the instances that
## were live when the action happened rather than the array it is editing
## out from under itself.
func _advance_action_result_objectives(action: String, result: Dictionary) -> void:
	for entry in (gs.active_opportunities as Array).duplicate():
		var inst: Dictionary = entry
		var definition: Dictionary = _definition(str(inst.get("definition_id", "")))
		for objective in (definition.get("objectives", []) as Array):
			var spec: Dictionary = objective
			if str(spec.get("class", "")) == "action_result" \
					and str(spec.get("action", "")) == action:
				_resolve(str(inst["definition_id"]), result)

# --- generic instance lifecycle ----------------------------------------------

func _definition(definition_id: String) -> Dictionary:
	return (DRE_CONTRACTS.DEFINITIONS as Dictionary).get(definition_id, {})

## True once a definition has ever been offered, is currently live, or has a
## terminal outcome recorded — the one check every entry point into a
## `repeatable: false` definition's lifecycle shares, so "already handled"
## means the same thing everywhere it is asked.
func _resolved_or_live(definition_id: String) -> bool:
	if gs.opportunity_history.has(definition_id):
		return true
	return _find(gs.opportunity_offers, definition_id) != null \
		or _find(gs.active_opportunities, definition_id) != null

func _find(array: Array, definition_id: String) -> Variant:
	for entry in array:
		if str((entry as Dictionary).get("definition_id", "")) == definition_id:
			return entry
	return null

func _facts() -> Dictionary:
	return {
		"current_day": gs.day,
		"dre_access_tier": gs.dre_access_tier,
		"dre_account_status": str(gs.dre_account.get("status", "clear")),
	}

func _maybe_offer(definition_id: String) -> void:
	if _resolved_or_live(definition_id):
		return
	var definition: Dictionary = _definition(definition_id)
	if definition.is_empty():
		return
	var verdict: Dictionary = REQUIREMENTS.new().evaluate_requirements(
		definition.get("requirements", []), _facts())
	if not bool(verdict.get("ok", false)):
		return
	var offers: Array = gs.opportunity_offers
	offers.append(_new_instance(definition_id, "offered"))
	gs.opportunity_offers = offers

func _new_instance(definition_id: String, state: String) -> Dictionary:
	var id: int = gs.opportunity_next_instance_id
	gs.opportunity_next_instance_id = id + 1
	return {
		"instance_id": id, "definition_id": definition_id, "state": state,
		"source_context": {},
		"offered_day": gs.day, "offered_slot": -1,
		"accepted_day": -1, "accepted_slot": -1,
		"deadline_day": -1, "deadline_slot": -1,
		"objective_progress": {}, "resolved_result": {}, "receipt_id": "",
	}

## The domain action that begins the work doubles as acceptance — OPP-D3.
## No-ops once the offer is gone (declined, or already accepted by an
## earlier call), so a second `dre_borrow` after the first loan's whole arc
## resolves does not reopen a `repeatable: false` milestone. Also no-ops at
## the accepted-commitment cap (OPP-D2) — this build's own content can never
## reach it (First Money is the only thing that can ever be offered), so the
## guard exists purely so a later repeatable-contract PR cannot ship without
## it already enforced. Note what this can and cannot do: `dre_borrow` has
## already succeeded by the time this runs (reconcile fires after the
## handler, never before it), so the cap can refuse to TRACK the milestone,
## never the underlying loan — exactly the "a contract observes; a domain
## system settles" pillar (design doc section 5.4).
func _accept(definition_id: String) -> void:
	if (gs.active_opportunities as Array).size() >= MAX_ACCEPTED_COMMITMENTS:
		return
	var offers: Array = gs.opportunity_offers
	var inst: Variant = _find(offers, definition_id)
	if inst == null:
		return
	offers.erase(inst)
	gs.opportunity_offers = offers
	var accepted: Dictionary = inst
	accepted["state"] = "active"
	accepted["accepted_day"] = gs.day
	var active: Array = gs.active_opportunities
	active.append(accepted)
	gs.active_opportunities = active

## Settles exactly once — `receipt_id` is the claim, checked before any
## mutation, the same idempotency contract `ConsequenceEngine.record_receipt`
## uses for the same reason: a double dispatch of the completing action
## (or a reload replaying one) must not pay the completion effects twice.
func _resolve(definition_id: String, result: Dictionary) -> void:
	var active: Array = gs.active_opportunities
	var inst: Variant = _find(active, definition_id)
	if inst == null:
		return
	var entry: Dictionary = inst
	if not str(entry.get("receipt_id", "")).is_empty():
		return
	var outcome := "late" if bool(result.get("late", false)) else "on_time"
	entry["receipt_id"] = "opportunity:%d:complete" % int(entry["instance_id"])
	entry["resolved_result"] = {"outcome": outcome}
	entry["state"] = "completed"
	active.erase(inst)
	gs.active_opportunities = active
	_apply_effects(_definition(definition_id).get("completion_effects", []))
	_write_history(definition_id, "completed", gs.day)

## Compact terminal record — umbrella section 9.4/20.1: "a definition ID,
## outcome key, count, and last-resolved day answer every future question."
## `count` exists for a later repeatable contract; every definition in this
## build is `repeatable: false` and writes it exactly once.
func _write_history(definition_id: String, outcome: String, day: int) -> void:
	var history: Dictionary = gs.opportunity_history
	var row: Dictionary = history.get(definition_id,
		{"outcome": outcome, "count": 0, "last_resolved_day": day})
	row["outcome"] = outcome
	row["count"] = int(row.get("count", 0)) + 1
	row["last_resolved_day"] = day
	history[definition_id] = row
	gs.opportunity_history = history

# --- decline -----------------------------------------------------------------

func decline(instance_id: int) -> Dictionary:
	var offers: Array = gs.opportunity_offers
	var inst: Variant = null
	for entry in offers:
		if int((entry as Dictionary).get("instance_id", -1)) == instance_id:
			inst = entry
			break
	if inst == null:
		return {"ok": false, "reason": "No such offer."}
	offers.erase(inst)
	gs.opportunity_offers = offers
	_write_history(str((inst as Dictionary)["definition_id"]), "declined", gs.day)
	return {"ok": true}

# --- typed effects (closed allowlist, OPP-D12) -------------------------------

func _apply_effects(effects: Array) -> void:
	for effect in effects:
		_apply_effect(effect)

func _apply_effect(effect: Dictionary) -> void:
	var effect_type := str(effect.get("type", ""))
	if not effect_type in EFFECT_TYPES:
		push_warning("Opportunities: unknown completion effect type '%s'" % effect_type)
		return
	match effect_type:
		"wallet_credit":
			var wallet: Object = gm.system("wallet")
			if wallet != null:
				wallet.credit(int(effect.get("amount", 0)),
					str(effect.get("provenance", wallet.CLEAN)),
					{"source_id": str(effect.get("source_id", "opportunity"))})
		"exposure_observation":
			var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
			if exposure != null:
				exposure.record_observation(str(effect.get("npc_id", "")),
					effect.get("spec", {}))
		"access_milestone":
			var field := str(effect.get("field", ""))
			if field.is_empty():
				return
			gs.set(field, maxi(int(gs.get(field)), int(effect.get("min", 0))))
		"message":
			var phone: Object = gm.system("phone")
			if phone != null:
				phone.push_message(str(effect.get("from", "")), str(effect.get("text", "")))
		"offer_followup":
			_maybe_offer(str(effect.get("definition_id", "")))

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
## that begins the work (`dre_borrow`, `dre_collect_negotiate`,
## `dre_collect_hard`) is authored to double as acceptance, per OPP-D3's "an
## authored meeting that both accepts and begins work."
##
## ## `accept()`/`resolve()`/`fail()` are public — PR D's second consumer
##
## `systems/dre_collector.gd` (PR D) calls these directly rather than going
## through `reconcile()`'s generic action-name matcher: its "hard" road and
## the player-default encounter both resolve on `"resolve_consequence_
## choice"`, an action name shared by every confrontation in the game, so
## the generic matcher cannot safely tell one chain's resolution from
## another's. See `data/dre_contracts.gd`'s header on `dre_a_reminder` for
## the full reasoning. `fail()` exists for the same PR: a `repeatable: false`
## definition can now genuinely fail (walking away from a collection,
## botching a negotiation) rather than only ever completing.
##
## ## `is_offered_or_active()` — PR E's third consumer, a narrower question
##
## `systems/shark.gd` (PR E) reads this to gate a locked borrower row's one
## fundable exception (`dre_book_sponsorship`, DRE-ARC-04). Narrower than
## `_resolved_or_live()` on purpose: a RESOLVED sponsorship must read false
## here, since by then the milestone already promoted Junior Lender, which
## opens the borrower through the ordinary tier gate instead — exactly the
## distinction `_resolved_or_live()` cannot make.
##
## ## A second consumer exists (0.4.0 PR A, SCR-D1..D3, `docs/DECISIONS.md` D-16)
##
## `data/score_contracts.gd`'s `score_slide_special` is the first non-Dre
## content this substrate carries — a Score, observing an existing successful
## `boost` at a named target, per the umbrella's own taxonomy (design doc
## section 6). It needed exactly two small, generic additions, both below:
## an authored `deadline` a definition can declare (`_new_instance()` now
## reads it), and `_expire_overdue()`, the deadline half of the umbrella's own
## shape (section 9.2) that OPP-D11 deferred for lack of a second caller.
## Nothing else moved — `_definition()`/`settle_night()`'s nightly offer sweep
## now read TWO catalogues instead of one, and that is the whole size of the
## change to prove the substrate generalizes.

const DRE_CONTRACTS := preload("res://data/dre_contracts.gd")
const SCORE_CONTRACTS := preload("res://data/score_contracts.gd")
const DRE_REPEAT_CONTRACTS := preload("res://data/dre_repeat_contracts.gd")
const REQUIREMENTS := preload("res://systems/requirements.gd")

## Every authored catalogue this substrate reads offers/definitions from.
## A later PR's own catalogue file is one more entry here, never a new
## `_definition()` branch.
const CATALOGUES := [DRE_CONTRACTS, SCORE_CONTRACTS, DRE_REPEAT_CONTRACTS]

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
		accept("dre_first_money")
	elif action == "dre_do_penance":
		# The conversation IS the acceptance, same as dre_seek_out/dre_borrow
		# above — accept() here, in the same pass, so the generic matcher
		# right below finds dre_penance already active and resolves it off
		# this same action_result. Without this, dre_penance sits offered
		# forever: _advance_action_result_objectives only ever scans
		# active_opportunities, never opportunity_offers.
		accept("dre_penance")
	elif action == "boost" and _resolves_score_slide_special(_payload, result):
		# Bespoke glue, same shape as the three branches above, for the same
		# reason score_contracts.gd's own header gives: there is no accept
		# moment separate from the resolving `boost` dispatch itself, so
		# accept() and resolve() both run here, in one pass, rather than
		# leaving the offer for a generic matcher that only ever scans
		# active_opportunities.
		accept("score_slide_special")
		resolve("score_slide_special", result)
	elif action == "travel" and bool(result.get("ok", false)) \
			and _resolves_repeat_errand(_payload):
		# Same shape again (0.4.0 PR C) -- see data/dre_repeat_contracts.gd's
		# header on why the errand has no separate accept step either.
		accept("dre_repeat_errand")
		resolve("dre_repeat_errand", result)
	_advance_action_result_objectives(action, result)

## True when a live, unexpired `score_slide_special` offer exists AND this
## `boost` dispatch is the one it is about — the named target, and an actual
## success (`result.success`), not merely an attempt. Reads `_find` against
## `opportunity_offers` directly rather than `_resolved_or_live`/generic
## helpers, because this is checking one specific pending offer's own match
## fields, not a general "has this ever been touched" question.
func _resolves_score_slide_special(payload: Dictionary, result: Dictionary) -> bool:
	if not bool(result.get("success", false)):
		return false
	var inst: Variant = _find(gs.opportunity_offers, "score_slide_special")
	if inst == null:
		return false
	var objective: Dictionary = (_definition("score_slide_special").get("objectives", []) as Array)[0]
	return str(payload.get("target_id", "")) == str(objective.get("target_id", ""))

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
##
## Two jobs. First, `state_fact` objectives — a no-op for every definition
## authored so far (`dre_first_money`'s objective is `action_result`, not
## `state_fact`, because nothing in the Dre state machine reaches "clear"
## except through a live `dre_repay` dispatch, reconciled at the point in
## `GameManager.dispatch()` instead); declared and exercised by tests now so
## a later PR's settlement-driven objective needs no new SETTLE_ORDER entry,
## only a new `state_fact` row in its own data file.
##
## Second (PR D), offer eligibility for every declared definition — OPP-D7:
## "Offer generation only at declared lifecycle points... never on screen
## open." `_maybe_offer` is already idempotent (`_resolved_or_live` skips
## anything offered, live, or resolved), so checking a definition nightly
## that was ALSO offered reactively elsewhere (`dre_first_money`, off
## `dre_seek_out`) costs nothing — it only ever fires for something actually
## newly eligible, like DRE-ARC-03 becoming visible once Trusted Customer,
## a clear account, and an acceptable Dre disposition line up on the same
## night.
func settle_night(_ended_day: int) -> void:
	_advance_state_fact_objectives()
	for catalogue in CATALOGUES:
		for definition_id in (catalogue.DEFINITIONS as Dictionary):
			# `repeatable: true` definitions never run through this generic
			# sweep: `_maybe_offer`'s own guard, `_resolved_or_live`, checks
			# `opportunity_history.has(definition_id)` -- true forever after
			# a definition's FIRST resolution, which is exactly right for a
			# one-time definition and exactly wrong for one meant to offer
			# again after every resolution. `_generate_repeatables()` below
			# is their own eligibility path (REP-D1's cap and cadence, not
			# "has this ever resolved").
			var definition: Dictionary = (catalogue.DEFINITIONS as Dictionary)[definition_id]
			if not bool(definition.get("repeatable", false)):
				_maybe_offer(str(definition_id))
	_generate_repeatables()
	_expire_overdue()

## REP-D1 (DRE-D12): at most one new repeatable offer per settle_night call
## (which itself fires at most once per day-cross, so "per in-game day
## start" falls out of that by construction -- no persisted counter needed),
## and never past the 3 accepted-commitment cap (OPP-D2) combined across
## every contract/mission/score, not just repeatables. Selection is a single
## seeded pick across every eligible repeatable definition, not "the first
## one found" -- with one template today the pick is trivial, but the shape
## is ready for PR C's catalogue without another rewrite here.
func _generate_repeatables() -> void:
	if gs.opportunity_offers.size() + gs.active_opportunities.size() \
			>= MAX_ACCEPTED_COMMITMENTS:
		return
	var facts: Dictionary = _facts()
	var eligible: Array = []
	for catalogue in [DRE_REPEAT_CONTRACTS]:
		for definition_id in (catalogue.DEFINITIONS as Dictionary):
			var definition: Dictionary = (catalogue.DEFINITIONS as Dictionary)[definition_id]
			if not bool(definition.get("repeatable", false)):
				continue
			# A repeatable already offered or active is not eligible to
			# generate AGAIN on top of itself -- `_resolved_or_live` cannot
			# serve this check (its `opportunity_history` half stays true
			# forever after a repeatable's very first resolution, which is
			# exactly backwards for a definition meant to offer again after
			# every resolution). `is_offered_or_active` is the narrower,
			# correct question: is THIS specific instance live right now.
			if is_offered_or_active(str(definition_id)):
				continue
			var verdict: Dictionary = REQUIREMENTS.new().evaluate_requirements(
				definition.get("requirements", []), facts)
			if bool(verdict.get("ok", false)):
				eligible.append(str(definition_id))
	if eligible.is_empty():
		return
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null:
		return
	# A requirements pass is necessary but not sufficient for the errand
	# template specifically -- it also needs an actual reachable district,
	# which `requirements.gd` (pure, no GameState access) cannot express as
	# one of its own records. Rather than teach the eligibility filter above
	# every template's own secondary constraints, retry with a shrinking
	# pool: a pick that turns out to be a dud (`_offer_repeatable` returns
	# false) is removed and re-rolled, so one template's bad luck never
	# silently burns the whole night's single generation slot while another
	# eligible template could have used it. Still fully deterministic for a
	# fixed run_seed + day: the same starting pool always shrinks the same
	# way in the same order.
	while not eligible.is_empty():
		# Varying components first (day leads) -- house style, and a
		# separate sub-key (":repeat_pick") from whatever the chosen
		# template's own generation rolls use, per the seeded-key discipline
		# every other draw in this codebase follows. The pool's own current
		# size rides the key so a retry after a shrink is a fresh draw, not
		# a repeat of the same index into a different-length array.
		var pick_key := "%d:repeat_pick:%d" % [gs.day, eligible.size()]
		var index: int = rng.seeded_int_range(gs.run_seed, pick_key, 0, eligible.size() - 1)
		var chosen: String = eligible[index]
		if _offer_repeatable(chosen):
			return
		eligible.remove_at(index)

## Per-template generation. One `match` arm per repeatable definition,
## exactly like `reconcile()`'s own bespoke-glue branches above -- a second
## repeatable template (PR C) adds one more arm here, not a new dispatcher.
## PR C (D-18): one `match` arm per repeatable definition, the same shape
## `_offer_repeatable` already declared for PR B's single template -- a
## fourth template is one more arm here and one more `DEFINITIONS` row,
## never a rewrite of this dispatcher.
## Returns whether a generation attempt actually produced an offer -- false
## is a real, meaningful outcome for the errand template (see below), which
## `_generate_repeatables()`'s own retry loop reads to try a different
## eligible candidate rather than burning the night's single slot on a dud.
func _offer_repeatable(definition_id: String) -> bool:
	match definition_id:
		"dre_repeat_collection":
			return _offer_repeat_collection(definition_id,
				DRE_REPEAT_CONTRACTS.BORROWER_POOL, DRE_REPEAT_CONTRACTS.FEE_BAND)
		"dre_repeat_collection_leaned_on":
			return _offer_repeat_collection(definition_id,
				DRE_REPEAT_CONTRACTS.LEANED_ON_BORROWER_POOL, DRE_REPEAT_CONTRACTS.LEANED_ON_FEE_BAND)
		"dre_repeat_premium":
			return _offer_repeat_collection(definition_id,
				DRE_REPEAT_CONTRACTS.PREMIUM_BORROWER_POOL, DRE_REPEAT_CONTRACTS.PREMIUM_FEE_BAND)
		"dre_repeat_errand":
			return _offer_repeat_errand(definition_id)
	return false

## REP-D2: seeded borrower pick and seeded fee band, both varying components
## first and on their own sub-keys (the definition id trails each key so
## two collection-shaped templates generated on the same run never draw off
## the same seeded value by accident, even though the 1-per-day rule means
## they are never actually generated on the same night), carried on
## `source_context` per the umbrella's own §9.3 ("named target or
## borrower... authored amount/range selection"). The chance tables, injury
## band, and Heat cost are NOT per-instance -- REP-D4: authored content
## riding the existing mechanics, not new ones. `pool`/`fee_band` are handed
## in per call site (see `_offer_repeatable` above) rather than looked up by
## definition id here, so this stays one function for every collection-shaped
## template rather than growing its own match statement.
func _offer_repeat_collection(definition_id: String, pool: Array, fee_band: Dictionary) -> bool:
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null:
		return false
	var borrower: Dictionary = pool[rng.seeded_int_range(
		gs.run_seed, "%d:%s:repeat_borrower" % [gs.day, definition_id], 0, pool.size() - 1)]
	var clean_band: Array = fee_band["clean"]
	var messy_band: Array = fee_band["messy"]
	var inst: Dictionary = _new_instance(definition_id, "offered")
	inst["source_context"] = {
		"target_id": str(borrower["id"]),
		"target_name": str(borrower["name"]),
		"target_desc": str(borrower["desc"]),
		"fee_clean": rng.seeded_int_range(gs.run_seed, "%d:%s:repeat_fee_clean" % [gs.day, definition_id],
			int(clean_band[0]), int(clean_band[1])),
		"fee_messy": rng.seeded_int_range(gs.run_seed, "%d:%s:repeat_fee_messy" % [gs.day, definition_id],
			int(messy_band[0]), int(messy_band[1])),
	}
	var offers: Array = gs.opportunity_offers
	offers.append(inst)
	gs.opportunity_offers = offers
	return true

## The errand's own generation: a seeded destination from the authored pool,
## restricted to districts the run has actually unlocked (an unreachable
## errand is not a choice) and never the district the player is standing in
## right now (nothing to "travel" to). Returns false rather than silently
## offering an unreachable district when no eligible one exists -- rare by
## Junior Lender, when both non-home districts are all but always unlocked
## already, but never assumed; the caller's own retry loop tries a
## different eligible template instead of wasting the night.
func _offer_repeat_errand(definition_id: String) -> bool:
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null:
		return false
	var candidates: Array = []
	for district_id in DRE_REPEAT_CONTRACTS.ERRAND_DISTRICT_POOL:
		if str(district_id) in gs.districts_unlocked and str(district_id) != gs.current_district_id:
			candidates.append(str(district_id))
	if candidates.is_empty():
		return false
	var district_id: String = candidates[rng.seeded_int_range(
		gs.run_seed, "%d:%s:repeat_errand_district" % [gs.day, definition_id],
		0, candidates.size() - 1)]
	var inst: Dictionary = _new_instance(definition_id, "offered")
	inst["source_context"] = {"district_id": district_id}
	var offers: Array = gs.opportunity_offers
	offers.append(inst)
	gs.opportunity_offers = offers
	return true

## Mirrors `_resolves_score_slide_special` (0.4.0 PR A) exactly: a live,
## unexpired `dre_repeat_errand` offer, and this `travel` dispatch actually
## landed at the named district (a refused travel -- wrong fare, unknown
## district -- never reaches `reconcile()` at all, so "dispatched" already
## means "arrived" here).
func _resolves_repeat_errand(payload: Dictionary) -> bool:
	var inst: Variant = _find(gs.opportunity_offers, "dre_repeat_errand")
	if inst == null:
		return false
	var ctx: Dictionary = (inst as Dictionary).get("source_context", {})
	return str(payload.get("district_id", "")) == str(ctx.get("district_id", ""))

## Public — `systems/dre_collector.gd` (PR B) reads a live collection
## instance's own definition to confirm `resolves_via` before treating it as
## theirs to resolve, the same generic-lookup need `ui/screens/boost.gd`
## (PR A) already established for `score_offer_for_target`.
func definition(definition_id: String) -> Dictionary:
	return _definition(definition_id)

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
				resolve(str(inst["definition_id"]), {})

# --- generic objective advancement ------------------------------------------

## `.duplicate()`: `resolve()` mutates `gs.active_opportunities` when an
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
				resolve(str(inst["definition_id"]), result)

# --- generic instance lifecycle ----------------------------------------------

func _definition(definition_id: String) -> Dictionary:
	for catalogue in CATALOGUES:
		var found: Variant = (catalogue.DEFINITIONS as Dictionary).get(definition_id, null)
		if found != null:
			return found
	return {}

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

## Public — PR E's `shark.fund_blocker` reads this to know whether a
## normally tier-locked borrower has a live sponsorship covering them
## right now (offered or accepted; a terminal one no longer applies,
## which is exactly what `_resolved_or_live` cannot tell apart and this
## can). Narrower than `_resolved_or_live` on purpose: a resolved
## `dre_book_sponsorship` means the milestone already paid out Junior
## Lender, which opens the borrower through the ordinary tier gate
## instead — this method correctly reads false once that happens.
func is_offered_or_active(definition_id: String) -> bool:
	return _find(gs.opportunity_offers, definition_id) != null \
		or _find(gs.active_opportunities, definition_id) != null

## The UI's own question, for `ui/screens/boost.gd`'s target row: is a live
## Score naming THIS target on the board right now, and what does it pay if
## pulled inside the window? Reads every definition's own `kind`/first
## objective rather than hardcoding `score_slide_special`'s id, so a second
## Score naming a different target needs no new UI-facing method here.
func score_offer_for_target(target_id: String) -> Dictionary:
	for pool in [gs.opportunity_offers, gs.active_opportunities]:
		for entry in (pool as Array):
			var inst: Dictionary = entry
			var definition: Dictionary = _definition(str(inst.get("definition_id", "")))
			if str(definition.get("kind", "")) != "score":
				continue
			var objectives: Array = definition.get("objectives", [])
			if objectives.is_empty() \
					or str((objectives[0] as Dictionary).get("target_id", "")) != target_id:
				continue
			var bonus := 0
			for effect in (definition.get("completion_effects", []) as Array):
				if str((effect as Dictionary).get("type", "")) == "wallet_credit":
					bonus += int((effect as Dictionary).get("amount", 0))
			return {
				"title": str(definition.get("presentation", {}).get("title", "Score")),
				"bonus": bonus,
				"days_left": int(inst.get("deadline_day", -1)) - gs.day,
			}
	return {}

func _facts() -> Dictionary:
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	return {
		"current_day": gs.day,
		"dre_access_tier": gs.dre_access_tier,
		"dre_account_status": str(gs.dre_account.get("status", "clear")),
		# PR D (DRE-ARC-03): "acceptable Dre disposition" has no shape
		# `requirements.gd` can read on its own -- that evaluator is pure,
		# no GameState/autoload access by design (its own header). Computing
		# it here, once, and handing it in as a plain float is what keeps
		# that purity real rather than nominal.
		"dre_disposition": exposure.disposition("dre") if exposure != null else 0.0,
		"dre_pending_penance": gs.dre_pending_penance,
		# Score's own requirement (SCR-D1's "the named target discovered") --
		# handed in as the raw list rather than a pre-computed bool, so a
		# later Score against a different target needs no new fact key, only
		# its own `boost_target_discovered` requirement record.
		"boost_targets_discovered": gs.boost_targets_discovered,
		# D-18 (PR C): summed across every repeatable's own history row --
		# proven WORK, not proven success, per this fact's own name and
		# `data/dre_repeat_contracts.gd`'s header on why (`count` increments
		# on `fail()` same as `resolve()`). Summed here, once, generically
		# across whatever repeatables exist, rather than requiring each new
		# template to know every other template's own id.
		"repeatable_attempts": _repeatable_attempts(),
	}

func _repeatable_attempts() -> int:
	var total := 0
	for catalogue in CATALOGUES:
		for definition_id in (catalogue.DEFINITIONS as Dictionary):
			var definition: Dictionary = (catalogue.DEFINITIONS as Dictionary)[definition_id]
			if not bool(definition.get("repeatable", false)):
				continue
			var row: Variant = gs.opportunity_history.get(str(definition_id), null)
			if row is Dictionary:
				total += int((row as Dictionary).get("count", 0))
	return total

func _maybe_offer(definition_id: String) -> void:
	if _resolved_or_live(definition_id):
		return
	var definition: Dictionary = _definition(definition_id)
	if definition.is_empty():
		return
	# `dre_the_introduction` (and anything else authored history-only) opts
	# out here — its own empty `requirements` would otherwise pass trivially
	# and mint a real offer for a definition this system deliberately never
	# tracks as one. See its own entry in data/dre_contracts.gd.
	if not bool(definition.get("offerable", true)):
		return
	var verdict: Dictionary = REQUIREMENTS.new().evaluate_requirements(
		definition.get("requirements", []), _facts())
	if not bool(verdict.get("ok", false)):
		return
	var offers: Array = gs.opportunity_offers
	offers.append(_new_instance(definition_id, "offered"))
	gs.opportunity_offers = offers

## OPP-D11's deadline half, first exercised by `score_slide_special`: a
## definition may declare `"deadline": {"window_days": N}` (umbrella section
## 9.1's own shape), counted from the offer appearing — every instance in
## this build is minted as "offered" first, and Dre's own content has no
## `deadline` key at all, so `window_days` defaults to 0 and `deadline_day`
## stays -1 (no deadline), exactly the prior behaviour, unchanged.
func _new_instance(definition_id: String, state: String) -> Dictionary:
	var id: int = gs.opportunity_next_instance_id
	gs.opportunity_next_instance_id = id + 1
	var deadline: Dictionary = _definition(definition_id).get("deadline", {})
	var window_days: int = int(deadline.get("window_days", 0))
	return {
		"instance_id": id, "definition_id": definition_id, "state": state,
		"source_context": {},
		"offered_day": gs.day, "offered_slot": -1,
		"accepted_day": -1, "accepted_slot": -1,
		"deadline_day": gs.day + window_days if window_days > 0 else -1, "deadline_slot": -1,
		"objective_progress": {}, "resolved_result": {}, "receipt_id": "",
	}

## The domain action that begins the work doubles as acceptance — OPP-D3.
## No-ops once the offer is gone (declined, or already accepted by an
## earlier call), so a second `dre_borrow`/`dre_collect_*` after a
## `repeatable: false` milestone's whole arc resolves does not reopen it.
## Also no-ops at the accepted-commitment cap (OPP-D2) — this build's own
## content stays well under it (First Money and DRE-ARC-03 can never be live
## together, since DRE-ARC-03 requires the resolved-and-promoted state only
## First Money's own completion grants; DRE-ARC-03 and the penance follow-up
## CAN overlap, two of three), so the cap is not something this build's
## content is expected to hit; the guard exists purely so a later
## repeatable-contract PR cannot ship without it already enforced.
## Note what this can and cannot do: the domain action has already succeeded
## by the time this runs (reconcile fires after the handler, never before
## it, and `dre_collector`'s own bespoke callers run inside that same
## already-succeeded dispatch), so the cap can refuse to TRACK the
## milestone, never the underlying action — exactly the "a contract
## observes; a domain system settles" pillar (design doc section 5.4).
func accept(definition_id: String) -> void:
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
## `resolved_result` is stored as the caller hands it — First Money's own
## `{"late": bool}` from `dre_repay`'s result, a collection road's own
## `{"road": ..., "tier": ...}`, whatever the resolving moment actually
## determined. Nothing here forces one canonical vocabulary onto it; the
## umbrella's own shape (section 9.2) makes no such promise either, and nothing
## currently reads `resolved_result` back out after the fact — it survives
## only for the life of the instance, compacted away by `_write_history`
## the moment this call ends.
func resolve(definition_id: String, result: Dictionary) -> void:
	var active: Array = gs.active_opportunities
	var inst: Variant = _find(active, definition_id)
	if inst == null:
		return
	var entry: Dictionary = inst
	if not str(entry.get("receipt_id", "")).is_empty():
		return
	entry["receipt_id"] = "opportunity:%d:complete" % int(entry["instance_id"])
	entry["resolved_result"] = result
	entry["state"] = "completed"
	active.erase(inst)
	gs.active_opportunities = active
	_apply_effects(_definition(definition_id).get("completion_effects", []))
	_write_history(definition_id, "completed", gs.day)

## The failure counterpart (PR D) — a `repeatable: false` definition can
## genuinely fail now: walking away from a collection, a botched
## negotiation. No `completion_effects` apply; the underlying action already
## owns its own real consequences (heat, cash, Exposure), and a failed
## milestone does not also grant its success reward. Same receipt-guard
## idempotency contract as `resolve()`, and the same `.duplicate()`-free
## direct mutation, since only one caller (`dre_collector.gd`, so far) ever
## calls this on a given instance.
func fail(definition_id: String, result: Dictionary) -> void:
	var active: Array = gs.active_opportunities
	var inst: Variant = _find(active, definition_id)
	if inst == null:
		return
	var entry: Dictionary = inst
	if not str(entry.get("receipt_id", "")).is_empty():
		return
	entry["receipt_id"] = "opportunity:%d:failed" % int(entry["instance_id"])
	entry["resolved_result"] = result
	entry["state"] = "failed"
	active.erase(inst)
	gs.active_opportunities = active
	_write_history(definition_id, "failed", gs.day)

## OPP-D11's deadline half, first exercised by `score_slide_special` — the
## umbrella's own lifecycle (design doc section 8) draws "Expired" as its own
## terminal state, distinct from "Failed": a window closing is not the same
## fact as accepted work going wrong, so this writes its own outcome label
## rather than routing through `fail()`. Called from `settle_night()`, the
## same declared lifecycle point `_maybe_offer`'s nightly sweep already uses
## (OPP-D7) — never checked reactively on screen open. Checks BOTH lists:
## `score_slide_special` never leaves `opportunity_offers` before it resolves
## (see this file's header), so an offer can expire same as an active
## instance can; `.duplicate()` on each for the same reason
## `_advance_action_result_objectives` needs it — expiring an entry must not
## disturb the array `resolve()`/whatever mutates underneath this loop.
func _expire_overdue() -> void:
	var offers: Array = gs.opportunity_offers
	for entry in offers.duplicate():
		if _is_overdue(entry):
			offers.erase(entry)
			_write_history(str((entry as Dictionary)["definition_id"]), "expired", gs.day)
	gs.opportunity_offers = offers
	var active: Array = gs.active_opportunities
	for entry in active.duplicate():
		if _is_overdue(entry):
			active.erase(entry)
			_write_history(str((entry as Dictionary)["definition_id"]), "expired", gs.day)
	gs.active_opportunities = active

func _is_overdue(entry: Dictionary) -> bool:
	var deadline_day: int = int(entry.get("deadline_day", -1))
	return deadline_day >= 0 and gs.day > deadline_day

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

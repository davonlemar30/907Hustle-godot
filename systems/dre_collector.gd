extends RefCounted
## Dre Collector — Dre Lending & Loan-Shark Progression, PR D. Design doc:
## `docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` section 13.2
## (DRE-ARC-03), section 17.1 (player default). Rulings: `docs/DECISIONS.md`,
## D-9.
##
## Two authored encounters, one adapter, one `KIND_CONFRONTATION` chain kind
## — the build prompt's own words: "through the confrontation/consequence
## chassis... the contract only observes the outcome." Content lives in
## `data/confrontation_scripts.gd` (the `DRE_COLLECTION_*`/`DRE_ULTIMATUM_*`
## constants); this file is the resolution logic.
##
## ## DRE-ARC-03 — the player collects from Dre's borrower
##
## `dre_collect_negotiate` (Charisma, "negotiation" shape) resolves in ONE
## dispatch, no chain — "talk the payment loose" has nothing to observe
## beyond its own roll. `dre_collect_hard` (Combat, "confrontation" shape)
## OPENS a chain with two choices: PRESS (rolled) or WALK (deterministic,
## `refused_work`). Both roads accept the offer the moment they are
## dispatched — OPP-D3, the domain action doubles as acceptance, the same as
## `dre_borrow` already does for First Money.
##
## ## The player-default encounter — Dre collects from the player
##
## Opened by `dre_lender.gd`'s `settle_night` "overdue" branch, not by any
## player dispatch — `open_player_default_encounter()` below. Two
## DETERMINISTIC choices, no roll: PAY NOW (settles the account in full, the
## same call `dre_lender._repay()` already makes) or the player stalling,
## which is the real suspension DRE-D6 asks for.
##
## ## Why neither road calls Opportunities generically
##
## See `data/dre_contracts.gd`'s own header on `dre_a_reminder`:
## `dre_collect_hard` and the player-default ultimatum both resolve on
## `"resolve_consequence_choice"`, an action name shared by every
## confrontation in the game — routing through `Opportunities.reconcile()`'s
## generic action-name matcher would let a completely unrelated chain (a
## Stickup room, say) resolve THIS instance. This file calls
## `Opportunities.accept()`/`resolve()`/`fail()` directly instead, from the
## one place that genuinely knows which chain is which.

const SCRIPTS := preload("res://data/confrontation_scripts.gd")

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node
var gm: Node
var rng: Node
var attributes: Object

func setup(game_state: Node, manager: Node, rng_manager: Node, attribute_system: Object) -> void:
	gs = game_state
	gm = manager
	rng = rng_manager
	attributes = attribute_system

func _wallet() -> Object:
	return gm.system("wallet")

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func _heat() -> Object:
	return gm.system("heat")

func _crew() -> Object:
	return gm.system("crew")

func _engine() -> Object:
	return gm.system("consequence")

func _opportunities() -> Object:
	return gm.system("opportunities")

func can_handle(action: String) -> bool:
	return action in ["dre_collect_negotiate", "dre_collect_hard"]

func handle(action: String, _payload: Dictionary) -> Dictionary:
	match action:
		"dre_collect_negotiate":
			return _negotiate()
		"dre_collect_hard":
			return _open_hard()
	return {"ok": false, "reason": "Unknown Dre collection action."}

# --- DRE-ARC-03: shared blocker ----------------------------------------------

## "" if either road is currently offered, the reason otherwise.
func collect_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	if not _has_offer("dre_a_reminder"):
		return "Dre hasn't asked you for this."
	return ""

func _has_offer(definition_id: String) -> bool:
	for entry in gs.opportunity_offers:
		if str((entry as Dictionary).get("definition_id", "")) == definition_id:
			return true
	return false

# --- negotiate (no chain) -----------------------------------------------------

func _negotiate() -> Dictionary:
	var blocked := collect_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var opportunities: Object = _opportunities()
	opportunities.accept("dre_a_reminder")
	var resolver: Object = gm.system("outcome_resolver")
	# Varying components first — house style (seeded key audit,
	# tests/parity/parity_runner.gd).
	var key := "%d:%d:dre_collection:negotiate" % [gs.day, int(gs.time_slots_today)]
	var outcome: Dictionary = resolver.resolve_action("negotiation",
		SCRIPTS.DRE_COLLECTION_NEGOTIATE_CHANCE, attributes.effective("charisma"),
		gs.run_seed, key)
	var tier := str(outcome["tier"])
	var collected: bool = tier in ["clean", "messy"]
	gs.log_activity(_negotiate_line(tier), GREEN if collected else RED)
	var exposure: Node = _exposure()
	if collected:
		var fee: int = int((SCRIPTS.DRE_COLLECTION_NEGOTIATE_FEE as Dictionary).get(tier, 0))
		if fee > 0:
			_wallet().credit(fee, _wallet().DIRTY, {"source_id": "dre_collection_negotiate"})
		if exposure != null:
			exposure.record_observation("dre", {"type": "honesty",
				"event": "handled_it_clean", "source": "direct"})
			exposure.record_observation("dre", {"type": "financial",
				"event": "collection_negotiated", "source": "direct"})
		opportunities.resolve("dre_a_reminder", {"road": "negotiate", "tier": tier})
	else:
		if tier == "catastrophic" and exposure != null:
			exposure.broadcast_observation({"type": "violence",
				"event": "botched_mission", "channel": "network"})
		opportunities.fail("dre_a_reminder", {"road": "negotiate", "tier": tier})
	return {"ok": true, "tier": tier, "collected": collected}

func _negotiate_line(tier: String) -> String:
	match tier:
		"clean": return "Dontae hands it over before you finish the sentence."
		"messy": return "It takes longer than it should, but it's in your hand."
		"failure": return "He talks in circles. You leave with nothing."
		_: return "It goes sideways fast. You leave with nothing, and word gets around."

# --- hard (opens a chain) -----------------------------------------------------

func _open_hard() -> Dictionary:
	var blocked := collect_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var engine: Object = _engine()
	if engine.has_active():
		return {"ok": false, "reason": "You're already in the middle of something."}
	_opportunities().accept("dre_a_reminder")
	var target: Dictionary = SCRIPTS.DRE_COLLECTION_TARGET
	# The zero-RNG projection, not a live roll — TI-003 §2's rule (and this
	# codebase's own house style: odds are shown as qualitative bands, never
	# raw percentages; that translation happens in the shared consequence
	# screen off this same number, the same source stickup.gd's own rooms
	# feed it from).
	var resolver: Object = gm.system("outcome_resolver")
	var shown: Dictionary = {"press": resolver.success_probability("confrontation",
		SCRIPTS.DRE_COLLECTION_PRESS_CHANCE, attributes.effective("combat"))}
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": gs.current_district_id,
		"return_route": "HOME",
		"source": {"action_id": "dre_collection", "kind": "borrower_collection",
			"family": "dre", "target_id": str(target["id"]),
			"target_name": str(target["name"])},
		"decision": {
			"allowed_choices": ["press", "walk"],
			"deterministic_choices": ["walk"],
			"shown_probabilities": shown,
		},
	})
	gs.log_activity("You go find Dontae Wells.", AMBER)
	return {"ok": true}

# --- the player-default ultimatum (opened by dre_lender.gd, no dispatch) -----

## Called from `dre_lender.settle_night()`'s `"overdue"` branch once
## `OVERDUE_RESPONSE_DELAY_DAYS` has passed unpaid. Refuses quietly if some
## OTHER consequence already has the floor — `settle_night` retries the next
## night, and "overdue" does not decay on its own, so nothing is lost.
func open_player_default_encounter() -> void:
	var engine: Object = _engine()
	if engine == null or engine.has_active():
		return
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": gs.current_district_id,
		"return_route": "HOME",
		"source": {"action_id": "dre_collection", "kind": "player_default",
			"family": "dre", "target_name": "Dre Smooth"},
		"decision": {
			"allowed_choices": ["pay_now", "stall"],
			"deterministic_choices": ["pay_now", "stall"],
		},
	})
	gs.log_activity("Dre wants to talk about what you owe.", RED)

## Blocks PAY NOW when the player cannot actually cover it — checked before
## the round's one commit receipt is claimed, so a blocked tap costs nothing.
func choice_blocked(choice_id: String) -> String:
	if choice_id != "pay_now":
		return ""
	if gs.cash < gs.debt:
		return "You don't have $%d." % gs.debt
	return ""

# --- resolution, both encounters ----------------------------------------------

func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var kind := str((chain.get("source", {}) as Dictionary).get("kind", ""))
	if kind == "player_default":
		return _resolve_ultimatum(chain, choice_id)
	return _resolve_borrower_collection(chain, choice_id)

func _resolve_borrower_collection(chain: Dictionary, choice_id: String) -> Dictionary:
	var cause_id := str(chain.get("cause_id", ""))
	var engine: Object = _engine()
	var decision: Dictionary = chain.get("decision", {})
	var opportunities: Object = _opportunities()

	if choice_id == "walk":
		gs.log_activity("You leave Dontae alone. Dre hears about it.", AMBER)
		if engine.record_receipt(cause_id, "dre_collection:refused_work"):
			var exposure: Node = _exposure()
			if exposure != null:
				exposure.record_observation("dre", {"type": "honesty",
					"event": "refused_work", "source": "direct"})
		decision["result"] = {"resolution": "walked", "collected": false}
		engine.advance_stage(engine.STAGE_RESULT)
		opportunities.fail("dre_a_reminder", {"road": "hard", "resolution": "walked"})
		return {"ok": true, "resolution": "walked"}

	# "press"
	var resolver: Object = gm.system("outcome_resolver")
	var key := "%s:press" % cause_id
	var outcome: Dictionary = resolver.resolve_action("confrontation",
		SCRIPTS.DRE_COLLECTION_PRESS_CHANCE, attributes.effective("combat"),
		gs.run_seed, key)
	var tier := str(outcome["tier"])
	var effects: Dictionary = (SCRIPTS.DRE_COLLECTION_PRESS_EFFECTS as Dictionary).get(tier, {})
	var collected: bool = bool(effects.get("collect", false))

	if engine.record_receipt(cause_id, "dre_collection:heat"):
		_heat().apply_gain(float(effects.get("heat", 0.0)), "", gs.current_district_id,
			{"source_id": "dre_collection_press"})

	if collected and engine.record_receipt(cause_id, "dre_collection:fee"):
		var fee: int = int((SCRIPTS.DRE_COLLECTION_PRESS_FEE as Dictionary).get(tier, 0))
		if fee > 0:
			_wallet().credit(fee, _wallet().DIRTY, {"source_id": "dre_collection_press"})

	if effects.has("injury_band") and engine.record_receipt(cause_id, "dre_collection:injury"):
		var band: Array = effects["injury_band"]
		var damage: int = rng.seeded_int_range(gs.run_seed, "%s:injury" % cause_id,
			int(band[0]), int(band[1]))
		damage = _crew().absorbed_damage(damage)
		gs.health = clampi(gs.health - damage, 0, gs.health_max)

	var exposure2: Node = _exposure()
	if collected:
		if engine.record_receipt(cause_id, "dre_collection:collected_hard"):
			if exposure2 != null:
				# Direct AND a separate neighborhood broadcast, not one call
				# doing double duty: `NPC_CHANNELS["dre"]` has no
				# "neighborhood" entry, so these two audiences never overlap
				# and neither call can double-count the other. Contrast
				# `walked_a_debt` (PR A), which stays direct-only because
				# THAT event's audience already includes "network".
				exposure2.record_observation("dre", {"type": "violence",
					"event": "collected_hard", "source": "direct"})
				exposure2.broadcast_observation({"type": "violence",
					"event": "collected_hard", "channel": "neighborhood"})
	elif tier == "catastrophic":
		if engine.record_receipt(cause_id, "dre_collection:botched"):
			if exposure2 != null:
				exposure2.broadcast_observation({"type": "violence",
					"event": "botched_mission", "channel": "network"})

	gs.log_activity(_press_line(tier), GREEN if collected else RED)
	decision["result"] = {"resolution": tier, "collected": collected}
	engine.advance_stage(engine.STAGE_RESULT)

	if collected:
		opportunities.resolve("dre_a_reminder", {"road": "hard", "tier": tier})
	else:
		opportunities.fail("dre_a_reminder", {"road": "hard", "tier": tier})
	return {"ok": true, "resolution": tier, "collected": collected}

func _press_line(tier: String) -> String:
	match tier:
		"clean": return "Dontae pays up fast once he sees you mean it."
		"messy": return "It gets loud before it gets paid, but it gets paid."
		"failure": return "He's got nothing on him. You leave empty-handed."
		_: return "It gets physical. You leave without the money and worse off."

## The account already cleared on payment (D-4/D-7) or is about to be
## suspended — nothing here reads or writes `Opportunities`; the ultimatum
## is Dre's own account state machine, not a tracked contract.
func _resolve_ultimatum(chain: Dictionary, choice_id: String) -> Dictionary:
	var cause_id := str(chain.get("cause_id", ""))
	var engine: Object = _engine()
	var decision: Dictionary = chain.get("decision", {})

	if choice_id == "pay_now":
		var lender: Object = gm.system("dre")
		var result: Dictionary = lender.handle("dre_repay", {})
		decision["result"] = {"resolution": "paid", "ok": bool(result.get("ok", false))}
		engine.advance_stage(engine.STAGE_RESULT)
		return {"ok": true, "resolution": "paid"}

	# "stall" — the real suspension DRE-D6 asks for, moved here from
	# dre_lender.gd's old flat-timer branch (PR A/pre-PR-D).
	var account: Dictionary = gs.dre_account
	account["status"] = "suspended"
	gs.dre_account = account
	gs.log_activity(
		"Dre stops answering. Make this right before you ask him for anything else.", RED)
	var phone: Object = gm.system("phone")
	if phone != null:
		phone.push_message("Dre",
			"This is what happens now. Straighten this out and we can go back " \
			+ "to how it was.", {"kind": "dre_debt"})
	if engine.record_receipt(cause_id, "dre_collection:walked_a_debt"):
		var exposure: Node = _exposure()
		if exposure != null:
			# `record_observation` only, not also a broadcast — `dre`'s own
			# channel list already includes "network", so a broadcast would
			# reach him a second time for the same fact he already knows as
			# his own business. Unchanged from PR A's own reasoning.
			exposure.record_observation("dre", {"type": "financial",
				"event": "walked_a_debt", "source": "direct"})
	decision["result"] = {"resolution": "suspended"}
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "resolution": "suspended"}

# --- adapter copy -------------------------------------------------------------

func choice_label(choice_id: String) -> String:
	if (SCRIPTS.DRE_COLLECTION_CHOICE_LABELS as Dictionary).has(choice_id):
		return str(SCRIPTS.DRE_COLLECTION_CHOICE_LABELS[choice_id])
	return str((SCRIPTS.DRE_ULTIMATUM_CHOICE_LABELS as Dictionary).get(
		choice_id, choice_id.capitalize()))

func choice_copy(choice_id: String) -> String:
	if (SCRIPTS.DRE_COLLECTION_CHOICE_COPY as Dictionary).has(choice_id):
		return str(SCRIPTS.DRE_COLLECTION_CHOICE_COPY[choice_id])
	return str((SCRIPTS.DRE_ULTIMATUM_CHOICE_COPY as Dictionary).get(choice_id, ""))

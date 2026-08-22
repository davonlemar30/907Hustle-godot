extends RefCounted
## Shark — lending money out and finding out whether it comes back.
##
## Ported from game-core.js FUND_SHARK (~7970), resolveSharkLoans (~6556), and
## the SHARK_BORROWERS / SHARK_TERMS tables.
##
## A note runs on the day clock, which is why this system fits the day_crossed
## machinery the obligations already use. On the due day it settles:
##
##   probability = clamp(borrower.risk
##                       + (amount >= 500 ? 0.18 : amount >= 250 ? 0.08 : 0)
##                       + (term == 2 ? 0.12 : term == 4 ? 0.04 : -0.04)
##                       - intelligence * 0.025
##                       - (bonded with Dre ? 0.08 : 0),
##                       0.03, 0.82)
##
## Repaid: the borrower returns amount + interest, minus Dre's 12% of the
## interest. Defaulted: the note sits open until the player decides.
##
## Pinned at canon neutral because their systems do not exist yet:
##   Dre bond     → false (no relationship bands yet)
##
## Intelligence is LIVE as of Phase 5c. It was pinned at
## `ATTRIBUTE_DEFAULTS.intelligence = 1`, but canon reads `intelligenceCompat`
## (game-core.js:6560) — the stored value offset onto the 1-5 scale — which is 2
## on a fresh run. The term was -0.025 where canon has -0.05, so every note this
## build wrote was 2.5 points likelier to default than canon from Phase 3d until
## Phase 5c.
##
## Enforcement is violent, and canon prices it: `heat + 2`, plus what the block
## and Dre make of it. That was deferred in 3d and is wired now.
##
## Still not ported: the recovered-amount curve on enforcement (canon recovers a
## variable amount and takes Dre's cut off the excess; here the principal comes
## back flat), and Dre's mission arc.
##
## ## Why this is still a hashed roll after Build 5e
##
## The default check is not an action the player takes, so it has no shape in
## canon's OUTCOME_SHAPES and never touches `resolveAction`. It asks whether
## somebody else paid you back — the player is not in the room, and there is no
## Charisma read to make about a phone that does not ring. Canon resolves it the
## way this file already does: `stringHash % 10000 / 10000` against the
## probability above, at game-core.js:6561.
##
## Enforcement, on the other hand, IS an action — and when the consequence
## encounter engine lands, collecting hard is exactly the `confrontation` /
## `negotiation` pair the tier table is waiting for. Until then the collection
## resolves flat, which is canon.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node
var rng: Node
var gm: Node
var attributes: RefCounted

func setup(game_state: Node, rng_manager: Node, manager: Node,
		attribute_system: RefCounted) -> void:
	gs = game_state
	rng = rng_manager
	gm = manager
	attributes = attribute_system
	# Driven by DayLifecycle in declared order. See systems/day_lifecycle.gd.

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func _curtis_node() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Curtis")

func can_handle(action: String) -> bool:
	return action in ["fund_shark", "enforce_shark", "extend_shark", "forgive_shark"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"fund_shark":
			return _fund(str(payload.get("borrower_id", "")), int(payload.get("amount", 0)), int(payload.get("term", 4)))
		"enforce_shark":
			return _resolve_defaulted(int(payload.get("loan_id", -1)), "enforce")
		"extend_shark":
			return _resolve_defaulted(int(payload.get("loan_id", -1)), "extend")
		"forgive_shark":
			return _resolve_defaulted(int(payload.get("loan_id", -1)), "forgive")
	return {"ok": false, "reason": "Unknown shark action."}

func loan_by_id(loan_id: int) -> Dictionary:
	for l in shark_open_loans():
		if int(l["id"]) == loan_id:
			return l
	return {}

func shark_open_loans() -> Array:
	return gs.shark_loans

## Canon refuses a second note to a borrower who already owes.
func has_open_note(borrower_id: String) -> bool:
	for l in gs.shark_loans:
		if str(l["borrower_id"]) == borrower_id and str(l["status"]) in ["active", "extended", "defaulted"]:
			return true
	return false

func fund_blocker(borrower_id: String, amount: int) -> String:
	if gs.game_over:
		return "The run is over."
	var b: Dictionary = gs.borrower_by_id(borrower_id)
	if b.is_empty():
		return "No such borrower."
	if has_open_note(borrower_id):
		return "That borrower already has an open note."
	if amount <= 0:
		return "Pick an amount."
	if amount > int(b["max"]):
		return "%s won't take more than $%d." % [str(b["name"]), int(b["max"])]
	if gs.cash < amount:
		return "You don't have $%d." % amount
	return ""

func _fund(borrower_id: String, amount: int, term: int) -> Dictionary:
	var blocked := fund_blocker(borrower_id, amount)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	if not gs.SHARK_TERMS.has(term):
		return {"ok": false, "reason": "Terms are 2, 4 or 7 days."}
	var b: Dictionary = gs.borrower_by_id(borrower_id)

	_wallet().spend(amount, _wallet().ROUTINE_DIRTY_FIRST, {"source_id": "shark_fund"})
	var loan := {
		"id": gs.shark_next_loan_id,
		"borrower_id": borrower_id,
		"amount": amount,
		"term": term,
		"opened_day": gs.day,
		"due_day": gs.day + term,
		"status": "active",
		"risk_label": str(b["risk_label"]),
	}
	gs.shark_next_loan_id += 1
	gs.shark_loans.append(loan)
	gs.log_activity("%s takes $%d for %d days." % [str(b["name"]), amount, term], AMBER)
	return {"ok": true, "loan_id": int(loan["id"])}

## Canon default probability, with the unbuilt terms at neutral (see header).
func default_probability(loan: Dictionary) -> float:
	var b: Dictionary = gs.borrower_by_id(str(loan["borrower_id"]))
	var amount: int = int(loan["amount"])
	var term: int = int(loan["term"])
	var amount_bump: float = 0.18 if amount >= 500 else (0.08 if amount >= 250 else 0.0)
	var term_bump: float = 0.12 if term == 2 else (0.04 if term == 4 else -0.04)
	var p: float = float(b["risk"]) + amount_bump + term_bump \
		- float(attributes.compat("intelligence")) * 0.025
	return clampf(p, 0.03, 0.82)

func interest_for(loan: Dictionary) -> int:
	return int(round(float(loan["amount"]) * float(gs.SHARK_TERMS[int(loan["term"])])))

func _resolve_defaulted(loan_id: int, how: String) -> Dictionary:
	var loan: Dictionary = loan_by_id(loan_id)
	if loan.is_empty() or str(loan["status"]) != "defaulted":
		return {"ok": false, "reason": "No defaulted note by that id."}
	var b: Dictionary = gs.borrower_by_id(str(loan["borrower_id"]))
	var interest: int = interest_for(loan)

	match how:
		"extend":
			# Canon gives two more days and leaves the note open.
			loan["status"] = "extended"
			loan["due_day"] = gs.day + 2
			gs.log_activity("%s gets two more days. The note stays open." % str(b["name"]), AMBER)
		"forgive":
			loan["status"] = "forgiven"
			# Letting a note go is discretion to the block and a write-off to Dre,
			# who takes a cut of interest that now will not arrive.
			var exposure: Node = _exposure()
			if exposure != null:
				exposure.broadcast_observation({
					"type": "discretion", "event": "let_it_go", "channel": "neighborhood",
				})
				exposure.record_observation("dre", {
					"type": "financial", "event": "let_them_down", "source": "network",
				})
			gs.log_activity("You let %s off the note. Word travels." % str(b["name"]), AMBER)
		"enforce":
			# The principal comes back; the interest does not.
			_wallet().credit(int(loan["amount"]), _wallet().DIRTY,
				{"source_id": "shark_enforce"})
			loan["status"] = "enforced"
			# Canon charges heat for a violent collection, and the block reads it
			# as violence. Deshawn damps the heat like any other source — through
			# HeatSystem now, which fetches his multiplier so this does not.
			#
			# No family is passed: TI-003 §7's district table covers Market,
			# Boost and Stick, and enforcement is none of the three. An unlisted
			# family scales by 1.0, which is exactly the scaling this line had
			# before the migration.
			var applied_heat: float = _heat().apply_gain(2.0, "", gs.current_district_id,
				{"source_id": "shark_enforce"})
			var curtis: Node = _curtis_node()
			if curtis != null:
				curtis.mark_criminal_activity()
				curtis.broadcast_tracked({
					"type": "violence", "event": "collected_hard",
					"location": gs.current_district_id, "channel": "neighborhood",
				})
			gs.log_activity("Collected $%d from %s the hard way. Heat +%.1f." % [int(loan["amount"]), str(b["name"]), applied_heat], RED)
	return {"ok": true, "interest": interest}

## The shared owners. Lending out is a routine spend; principal and interest
## coming back off the street is dirty money.
func _wallet() -> Object:
	return gm.system("wallet")

func _heat() -> Object:
	return gm.system("heat")

## Notes that have come due.
##
## **`settling_day` is `ended_day + 1` for the same reason crew's is** — canon's
## `resolveSharkLoans` runs above the increment and compares the ending day, this
## port has always compared the new one, and shifting it would move when every
## note in a live save comes due. Named here, preserved exactly, filed for its
## own slice. See systems/day_lifecycle.gd.
## Notes coming due, settled against the day that ENDED.
##
## `ended_day + 1` until this slice — see the note on `CrewSystem.settle_night`
## for why the `+ 1` existed and why it is gone. The behavioural half here is
## real and is the point: a note due on day 7 used to resolve on the night that
## ENDED day 6, because `ended_day + 1` already read 7. It now resolves on the
## night that ends day 7, so the player has the whole of the due day to pay it —
## the same rule obligations already applies to rent, and canon's.
func settle_night(ended_day: int) -> void:
	if gs.game_over:
		return
	var settling_day: int = ended_day
	for loan in gs.shark_loans:
		if not str(loan["status"]) in ["active", "extended"]:
			continue
		if settling_day < int(loan["due_day"]):
			continue
		var b: Dictionary = gs.borrower_by_id(str(loan["borrower_id"]))
		# Canon keys this on seed:shark:loanId:dueDay and normalises with
		# `% 10000 / 10000` rather than / 2^32 — see RngManager.seeded_unit_10k.
		# v0.1.0 seeded-key audit: loan id and due day lead the key.
		var key := "%d:%d:shark" % [int(loan["id"]), int(loan["due_day"])]
		var roll: float = rng.seeded_unit_10k(gs.run_seed, key)
		if roll < default_probability(loan):
			loan["status"] = "defaulted"
			gs.log_activity("%s misses the deadline. The note needs a decision." % str(b["name"]), RED)
		else:
			var interest: int = interest_for(loan)
			var dre_cut: int = int(round(float(interest) * gs.SHARK_DRE_CUT))
			var returned: int = int(loan["amount"]) + interest - dre_cut
			_wallet().credit(returned, _wallet().DIRTY, {"source_id": "shark_repaid"})
			loan["status"] = "repaid"
			gs.log_activity("%s returns $%d after Dre's $%d cut." % [str(b["name"]), returned, dre_cut], GREEN)
			# Dre gets paid out of this, so he sees it first-hand. His STREET
			# lens weights financial at 4.0 — lending well is how you build with
			# him without ever speaking to him.
			var exposure_ok: Node = _exposure()
			if exposure_ok != null:
				exposure_ok.record_observation("dre", {
					"type": "financial", "event": "note_returned", "source": "witnessed",
				})

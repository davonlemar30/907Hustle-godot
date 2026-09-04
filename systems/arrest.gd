extends RefCounted
## ArrestSystem — the one owner of booking quotes and the arrest record.
##
## TI-003 §§13-14, §26. Two source systems can put the player in cuffs and they
## must not each invent what that costs. Boost decides *whether* a Caught result
## ends in an arrest; Stick decides the same off its own Heat gate; neither of
## them decides what bail runs, how long processing takes, how much Heat the
## city lets go of, or what a second arrest costs more than a first. That is all
## here, once.
##
## ## The quote is computed at arrest, not at commit
##
## `attach_booking()` runs the moment the arrest is decided and writes the quote
## onto the chain. Everything the player is shown afterwards — bail, priors,
## processing slots, projected release — is read back from that stored block
## rather than recomputed.
##
## That is what makes "bail quote and projected release are stable across
## reload" true rather than merely likely. Recomputing at render time would
## reproduce the same number today, and would quietly start lying the first time
## anything the formula reads (priors, the day, the severity table) moved between
## the quote and the decision. The priors count is the live example: it
## increments during the commit, so a quote recomputed after payment would price
## the arrest the player is currently standing in as if it had already happened.
##
## ## Total time is capped, and that is a player-facing guarantee
##
## FS-003 §7 caps one arrest at four slots and states it under both shortfall
## lanes. TI-003 regression #14 is "a broke player loses every legal Booking
## option", and the cap is what makes that impossible: SERVE IT is always
## offered, always costs $0, and can never hold the player longer than a day.
##
## ## The source slot and the booking slots are different time
##
## TI-003 §13 separates them deliberately:
##
##     8. settle the source action's one slot once;
##     9. advance additional booking slots one by one;
##
## The source slot is the cost of the action the player took — the lift or the
## robbery — and it is owed whether or not it ended in an arrest. The booking
## slots are what the arrest itself costs on top. They are settled in that order
## and counted separately on the release receipt, because collapsing them would
## make the *second* arrest of a run cheaper than the first in wall-clock terms
## without anybody deciding that.
##
## Every one of those slots runs the ordinary lifecycle one at a time (§13 step
## 9): rent comes due, wages accrue, the market walks. Booking gains its weight
## from the simulation that was already running, not from a jail minigame.
##
## ## What this system never does
##
## It does not write `gs.cash` or `gs.heat`. Bail spends through WalletSystem
## under `HIGH_VISIBILITY_CLEAN_FIRST` — bail is a formal, recorded payment, and
## paying it in street money is exactly what Financial Pressure measures. Heat
## relief goes through `HeatSystem.apply_relief`, which bypasses the gain
## multipliers: TI-003 regression #15 is relief passing through them, and it
## would mean having Deshawn on the crew makes getting arrested help you less.

const RULES := preload("res://data/consequence_rules.gd")

## Slots in a day. Duplicated as a literal rather than imported from TimeSystem
## for the same reason DayLifecycle duplicates MORNING: the projection math must
## stay callable without a live TimeSystem so it can be tested directly.
const SLOTS_PER_DAY := 4
const SLOT_NAMES: Array[String] = ["MORNING", "AFTERNOON", "EVENING", "NIGHT"]

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

func can_handle(action: String) -> bool:
	return action == "resolve_booking_choice"

func handle(action: String, payload: Dictionary) -> Dictionary:
	if action != "resolve_booking_choice":
		return {"ok": false, "reason": "Unknown booking action."}
	return _commit(payload)

func _rules() -> RefCounted:
	return RULES.new()

func _engine() -> Object:
	return gm.system("consequence") if gm != null else null

func _wallet() -> Object:
	return gm.system("wallet") if gm != null else null

func _heat() -> Object:
	return gm.system("heat") if gm != null else null

# --- the record -------------------------------------------------------------

## Arrests already on the record. The count BEFORE the booking in progress —
## which is what both the bail multiplier and the processing adjustment read.
func priors() -> int:
	return int((gs.arrest_record as Dictionary).get("priors", 0))

func last_arrest_day() -> int:
	return int((gs.arrest_record as Dictionary).get("last_arrest_day", -1))

## The day the post-arrest cooldown stops covering, or -1 for a run that has
## never been booked.
##
## Read with a default rather than assumed present: `arrest_record` is persisted
## as a whole Dictionary, so a save written before FS-003.13 comes back without
## this key and must read as "no cooldown" instead of as day 0. That is why the
## field needed no schema bump — see the note on `_commit` step 5.
func cooldown_until_day() -> int:
	return int((gs.arrest_record as Dictionary).get("cooldown_until_day", -1))

## Whether an arrest gate is suppressed right now.
##
## Asked by the SOURCE systems, after their own gate has already said yes. That
## order matters: the gate stays the authored one, and the cooldown is a separate
## fact about the last few days rather than a second threshold hidden inside it.
## A source that asked the other way round would make the gate's own tests
## depend on the arrest record.
##
## `today` is passed rather than read off `gs.day` so the answer is a function of
## its arguments: the projection code and the tests ask about days the clock is
## not currently sitting on, and a reader that quietly substituted "now" would
## give them a different answer than the gate gets.
func in_cooldown(today: int) -> bool:
	return _rules().arrest_suppressed(today, cooldown_until_day())

func charges() -> Array:
	return ((gs.arrest_record as Dictionary).get("charges", []) as Array).duplicate(true)

# --- opening a booking ------------------------------------------------------

## Write the booking quote onto an active chain. Called by a source adapter the
## moment its arrest gate says yes.
##
## `context` carries `family`, `tier`, `target_id` and `cause_id`. Everything
## else is derived here, so a source system never has to know the severity table
## exists — it only knows what it is and how big the job was.
##
## Idempotent by inspection: a chain that already carries a quote keeps it. A
## second call would otherwise re-price the arrest against a priors count that
## may have moved, which is the reload hazard this whole file is arranged
## around.
func attach_booking(chain: Dictionary, context: Dictionary) -> Dictionary:
	var existing: Dictionary = chain.get("booking", {})
	if not existing.is_empty() and existing.has("bail_quote"):
		return existing
	var rules: RefCounted = _rules()
	var family := str(context.get("family", ""))
	var tier: int = int(context.get("tier", 1))
	var severity := str(context.get("severity", rules.severity_for(family, tier)))
	var prior_count: int = priors()
	var booking: Dictionary = {
		"pending": true,
		"cause_id": str(context.get("cause_id", chain.get("cause_id", ""))),
		"severity": severity,
		"severity_label": rules.severity_label(severity),
		"source_family": family,
		"source_target_id": str(context.get("target_id", "")),
		"source_tier": tier,
		# The quote, frozen. See the file header.
		"priors_at_quote": prior_count,
		"prior_multiplier": rules.bail_multiplier(prior_count),
		"bail_quote": rules.bail_quote(severity, prior_count),
		"processing_slots": rules.processing_slots(severity, prior_count),
		"heat_relief": rules.heat_relief(severity),
		"quoted_day": int(gs.day),
		"quoted_slot": int(gs.time_slots_today),
		"committed_choice": "",
	}
	chain["booking"] = booking
	return booking

# --- projections ------------------------------------------------------------

## Everything the Booking stage renders, TI-003 §13: "bail quote, bucket use,
## processing slots, projected release day/slot, Heat relief, and prior count
## before the player commits."
##
## Returns plain data. The three lanes come back as rows with their exact cash
## cost, exact slot cost and exact release point already computed, because
## PX-003 §6 requires the player to see the final time result before committing
## rather than discovering it afterwards.
func booking_projection(chain: Dictionary) -> Dictionary:
	var booking: Dictionary = chain.get("booking", {})
	if booking.is_empty():
		return {}
	var out: Dictionary = booking.duplicate(true)
	var wallet: Object = _wallet()
	var cash: int = int(wallet.balance()) if wallet != null else int(gs.cash)
	out["cash_on_hand"] = cash
	# The source action's own slot, still owed while the chain is open. It is
	# part of the release projection because it is time that will genuinely pass
	# before the player is back on the street.
	var time_block: Dictionary = chain.get("time", {})
	var source_slots: int = 0
	if not bool(time_block.get("source_time_settled", false)):
		source_slots = int(time_block.get("source_slots_remaining", 0))
	out["source_slots"] = source_slots
	out["choices"] = _choice_rows(booking, cash, source_slots)
	return out

## The three lanes, priced and timed.
##
## The COST of each lane comes from the frozen quote; the RELEASE POINT is
## projected from the live clock. Those are different kinds of fact and they are
## deliberately sourced differently: the price has to be the price the player was
## quoted, and the release point has to be where the clock actually lands, which
## is what the commit itself computes. Projecting the release from
## `quoted_slot` instead would agree in ordinary play — nothing can move the
## clock while a chain is blocking — and would disagree with the receipt the
## moment anything ever did.
func _choice_rows(booking: Dictionary, cash: int, source_slots: int) -> Array:
	var rules: RefCounted = _rules()
	var severity := str(booking.get("severity", ""))
	var prior_count: int = int(booking.get("priors_at_quote", 0))
	var quote: int = int(booking.get("bail_quote", 0))
	var rows: Array = []
	for choice_id in rules.BOOKING_CHOICES:
		var id := str(choice_id)
		var paid: int = _cash_cost(id, quote, cash)
		var shortfall: int = maxi(0, quote - paid)
		var slots: int = rules.total_booking_slots(severity, prior_count, shortfall)
		var release: Dictionary = project_release(int(gs.day), int(gs.time_slots_today),
			source_slots + slots)
		rows.append({
			"choice_id": id,
			"available": _is_available(id, quote, cash),
			"cash_cost": paid,
			"cash_after": maxi(0, cash - paid),
			"shortfall": shortfall,
			"slots": slots,
			"release_day": int(release["day"]),
			"release_slot": int(release["slot"]),
			"release_slot_name": str(release["slot_name"]),
			"committed": str(booking.get("committed_choice", "")) == id,
			# Any commit disables every lane, the same rule the decision stage
			# uses. Read from persisted state, never from a click.
			"disabled": not str(booking.get("committed_choice", "")).is_empty(),
		})
	return rows

## What this lane actually takes out of the wallet.
func _cash_cost(choice_id: String, quote: int, cash: int) -> int:
	var rules: RefCounted = _rules()
	match choice_id:
		rules.BOOKING_FULL_BAIL:
			return quote
		rules.BOOKING_ALL_CASH:
			# Never more than the quote: putting up "everything you have" against
			# a $150 bail when you are holding $900 would be a donation.
			return mini(maxi(0, cash), quote)
	return 0

## FS-003 §7's availability rules, verbatim.
##
## `all_cash` is deliberately hidden when the player could simply pay — offering
## "put up what you have" beside "post full bail" at the same price is two
## buttons for one action. It is also hidden at $0, where it is Serve with extra
## steps.
func _is_available(choice_id: String, quote: int, cash: int) -> bool:
	var rules: RefCounted = _rules()
	match choice_id:
		rules.BOOKING_FULL_BAIL:
			return cash >= quote
		rules.BOOKING_ALL_CASH:
			return cash < quote and cash > 0
	# Serve is always available. That is the whole point of it.
	return true

## Where the clock lands after `slots` advances from (`day`, `slot`).
##
## Pure arithmetic on the same 0-3 slot index TimeSystem uses, so it can be
## checked directly against a real advance rather than trusted.
func project_release(day: int, slot: int, slots: int) -> Dictionary:
	var absolute: int = maxi(0, slot) + maxi(0, slots)
	var landed_slot: int = absolute % SLOTS_PER_DAY
	return {
		"day": day + int(floor(float(absolute) / float(SLOTS_PER_DAY))),
		"slot": landed_slot,
		"slot_name": SLOT_NAMES[landed_slot],
	}

# --- the commit -------------------------------------------------------------

## TI-003 §13's booking commit order, in order.
##
## Every mutating step claims a receipt first, the same contract the Caught
## effects use: the receipt and the mutation land in the same dispatch, so no
## reload can replay either one.
func _commit(payload: Dictionary) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	if not engine.has_active():
		return {"ok": false, "reason": "Nothing is waiting on you."}
	var chain: Dictionary = gs.active_consequence

	# 1. Validate identity, stage and choice — the same four checks the decision
	#    stage runs, and for the same reason: a button rendered before a reload
	#    must be refused rather than honoured against whatever is open now.
	var consequence_id := str(payload.get("consequence_id", ""))
	if not consequence_id.is_empty() and consequence_id != engine.active_consequence_id():
		return {"ok": false, "reason": "That moment has passed."}
	var cause_payload := str(payload.get("cause_id", ""))
	if not cause_payload.is_empty() and cause_payload != engine.active_cause_id():
		return {"ok": false, "reason": "That moment has passed."}
	if engine.active_stage() != engine.STAGE_BOOKING:
		return {"ok": false, "reason": "They are not done writing it up."}

	var booking: Dictionary = chain.get("booking", {})
	if booking.is_empty() or not booking.has("bail_quote"):
		return {"ok": false, "reason": "They are still writing it up."}
	if not str(booking.get("committed_choice", "")).is_empty():
		return {"ok": false, "reason": "You already made that call."}

	var rules: RefCounted = _rules()
	var choice_id := str(payload.get("choice_id", ""))
	if not choice_id in rules.BOOKING_CHOICES:
		return {"ok": false, "reason": "That is not one of your options."}

	var wallet: Object = _wallet()
	var cash: int = int(wallet.balance()) if wallet != null else int(gs.cash)
	var quote: int = int(booking.get("bail_quote", 0))
	if not _is_available(choice_id, quote, cash):
		return {"ok": false, "reason": "You cannot do that with what you have."}

	var cause_id := str(chain.get("cause_id", ""))
	var severity := str(booking.get("severity", ""))
	var prior_count: int = int(booking.get("priors_at_quote", 0))
	var paid: int = _cash_cost(choice_id, quote, cash)
	var shortfall: int = maxi(0, quote - paid)
	var booking_slots: int = rules.total_booking_slots(severity, prior_count, shortfall)

	# 2-3. Spend through WalletSystem, which applies Financial Pressure from the
	#      dirty portion itself. Bail is high-visibility: it is a formal payment
	#      with a record attached, so Clean drains first (TI-003 §6).
	var financial_pressure_gain: int = 0
	var clean_used: int = 0
	var dirty_used: int = 0
	if paid > 0 and engine.record_receipt(cause_id, "booking:payment"):
		var tx: Dictionary = wallet.spend(paid, wallet.HIGH_VISIBILITY_CLEAN_FIRST,
			{"source_id": "bail", "cause_id": cause_id})
		if not bool(tx.get("ok", false)):
			return {"ok": false, "reason": "Not enough cash."}
		clean_used = int(tx.get("clean_used", 0))
		dirty_used = int(tx.get("dirty_used", 0))
		financial_pressure_gain = int(tx.get("financial_pressure_gain", 0))

	# 4. Heat relief. Through `apply_relief`, which does not touch the gain
	#    multipliers — see the file header.
	var relief_requested: float = float(booking.get("heat_relief", 0.0))
	var relief_applied: float = 0.0
	if relief_requested > 0.0 and engine.record_receipt(cause_id, "booking:relief"):
		relief_applied = -_heat().apply_relief(relief_requested,
			{"source_id": "arrest", "cause_id": cause_id})

	# 5. Priors and the charge record, once.
	var priors_after: int = prior_count
	if engine.record_receipt(cause_id, "booking:record"):
		var record: Dictionary = gs.arrest_record
		priors_after = int(record.get("priors", 0)) + 1
		record["priors"] = priors_after
		record["last_arrest_day"] = int(gs.day)
		# OG-D4: a serious booking counts toward a sentence; the third is
		# the ending. Behind the same receipt, so a reload cannot count it
		# twice.
		var ending: Object = gm.system("ending") if gm != null else null
		if ending != null:
			ending.note_booking(str(booking.get("severity", "")))
		# FS-003.13 Task 3's cooldown deadline, stamped where the rest of the
		# record is written and behind the same receipt — so a reload mid-commit
		# cannot arm it twice, and a run that never committed a booking never
		# arms it at all.
		#
		# Nested inside `arrest_record`, which PERSIST_FIELDS already carries
		# whole. That is deliberate: a new key in an already-persisted Dictionary
		# survives a save/load without a schema bump, and a pre-FS-003.13 save
		# loads with the key absent, which `cooldown_until_day()` reads as -1 —
		# the correct history for a run whose arrests predate the mechanic.
		record["cooldown_until_day"] = rules.arrest_cooldown_until(int(gs.day))
		(record["charges"] as Array).append({
			"cause_id": cause_id,
			"day": int(gs.day),
			"severity": severity,
			"source_family": str(booking.get("source_family", "")),
			"source_target_id": str(booking.get("source_target_id", "")),
			"bail_quote": quote,
			"paid": paid,
			"processing_slots": booking_slots,
			"heat_relief": relief_applied,
			"booking_choice": choice_id,
		})

	# 6. The arrest observation, once. Authored in consequence_rules.gd — see the
	#    comment on ARREST_OBSERVATION for why it is heat_exposure/neighborhood.
	if engine.record_receipt(cause_id, "booking:observation"):
		var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
		if exposure != null:
			var spec: Dictionary = (rules.ARREST_OBSERVATION as Dictionary).duplicate()
			spec["location"] = str(chain.get("district_id", gs.current_district_id))
			exposure.broadcast_observation(spec)

	# 7. Same-Cause retaliation is off. FS-003 §10: "When police already
	#    converted the cause into a booking, the same incident's actor
	#    retaliation entry clears." You already answered for it.
	var suppressed: int = engine.suppress_cause(cause_id)

	# 8. The source action's own slot, settled exactly once.
	var source_slots: int = 0
	if engine.source_time_owed():
		var time_block: Dictionary = chain.get("time", {})
		source_slots = int(time_block.get("source_slots_remaining", 0))
		engine.settle_source_time()

	# 9-10. Store the receipt BEFORE advancing time.
	#
	#    Slot advancement crosses days, runs the whole night sequence, and can
	#    end the run through an unpaid obligation. Writing the release facts
	#    first means the receipt is already true whatever those slots do — and
	#    means a run that ends inside booking still has a coherent chain behind
	#    the Game Over screen rather than a half-written one.
	booking["committed_choice"] = choice_id
	booking["pending"] = false
	booking["paid"] = paid
	booking["clean_used"] = clean_used
	booking["dirty_used"] = dirty_used
	booking["financial_pressure_gain"] = financial_pressure_gain
	booking["shortfall"] = shortfall
	booking["slots_served"] = booking_slots
	booking["source_slots_settled"] = source_slots
	booking["heat_relief_applied"] = relief_applied
	booking["priors_after"] = priors_after
	var release: Dictionary = project_release(int(gs.day), int(gs.time_slots_today),
		source_slots + booking_slots)
	booking["released_day"] = int(release["day"])
	booking["released_slot"] = int(release["slot"])
	chain["booking"] = booking

	# 11. Stage first, then time. The chain has to be at `release` before any
	#     slot advances, because a day-cross inside those slots runs the
	#     day-start lifecycle — and a chain sitting at `booking` while the world
	#     moves is a stage that never happened.
	engine.advance_stage(engine.STAGE_RELEASE)

	var time_system: Object = gm.system("time") if gm != null else null
	if time_system != null:
		# One at a time, TI-003 §13 step 9. Obligations, wages, Exposure, Curtis
		# and the market all settle through their ordinary rules; nothing here
		# knows or cares which of them fired.
		for _slot in range(source_slots + booking_slots):
			time_system.handle("advance_time", {})

	gs.log_activity(_release_line(booking), Color(0.827, 0.161, 0.125))
	return {
		"ok": true, "choice_id": choice_id, "paid": paid,
		"slots": booking_slots, "source_slots": source_slots,
		"priors": priors_after, "heat_relief": relief_applied,
		"financial_pressure_gain": financial_pressure_gain,
		"suppressed_retaliation": suppressed,
	}

func _release_line(booking: Dictionary) -> String:
	var slots: int = int(booking.get("slots_served", 0)) + int(booking.get("source_slots_settled", 0))
	var paid: int = int(booking.get("paid", 0))
	if paid <= 0:
		return "Served it out. %d slots gone." % slots
	if int(booking.get("shortfall", 0)) > 0:
		return "Put up $%d and sat the rest. %d slots gone." % [paid, slots]
	return "Posted $%d and walked. %d slots gone." % [paid, slots]

extends RefCounted
## ConsequenceEngine — one owner for blocking consequence chains.
##
## TI-003 §§4, 10, 18. When a risky action goes wrong, something has to hold the
## situation open across a save, a reload, and a player who put the phone down
## mid-decision. That something is here.
##
## ## What this slice builds, and what it deliberately does not
##
## FS-003.5 is the ORCHESTRATION, not the content. The engine can open a chain,
## carry it through four stages, refuse a bad transition, keep an exactly-once
## ledger, arbitrate a queue, and hand the UI a projection. It knows nothing
## about what being caught costs, what bail runs, how Pressure accrues, or who
## retaliates — those are .7, .8, .9 and .10.
##
## Everything below is therefore written to be filled in rather than replaced.
## `open_chain` takes an authored shape; the stage machine is a declared table;
## the projections read whatever the chain carries. A later slice adds a chain
## kind and authored effects and touches none of this file's control flow.
##
## ## Exactly-once, and why receipts rather than flags
##
## TI-003 §4: "The effect mutation and its receipt land in the same GameManager
## dispatch before autosave."
##
## The failure this prevents is not exotic. Apply Caught's heat, autosave, then
## the player reloads before pressing Continue — without a receipt the chain
## reopens at the same stage and applies that heat again. A boolean per effect
## would work until there were two effects; a keyed ledger per Cause works for
## all of them and reads back as a list of what has already happened.
##
## `record_receipt` returns **false when the key is already present**. That is
## the whole contract: a caller that ignores the return double-applies, a caller
## that respects it cannot.
##
## ## One active chain, and a queue for the rest
##
## TI-003 §10 gives the engine exactly one active blocking chain. A second
## consequence does not stack — it waits in `consequence_queue` until the slot
## is free, its day has come, and the player is standing in the right district.
##
## The queue is an **Array**, and `eligible_queued()` sorts explicitly by
## `trigger_day` then `created_sequence`. TI-003 regression #32 is "queue order
## depends on Dictionary iteration order", and the defence is that ordering is
## never inherited from a container's iteration — it is stated.
##
## ## Runtime adapters live here, never in the save
##
## FS-001.7's precedent, made a standing rule by TI-003 §1 and §26: save data
## carries stable IDs and state facts, never Object references. `_source_adapters`
## is a plain runtime Dictionary rebuilt on every boot by `GameManager._ready()`,
## and a chain names its source by `action_id` — a String the registry resolves.
##
## That is why a chain can survive a reload at all: nothing in it is a handle.

## The four stages, in order. TI-003 §5's `stage` field takes one of these.
const STAGE_DECISION := "decision"
const STAGE_RESULT := "result"
const STAGE_BOOKING := "booking"
const STAGE_RELEASE := "release"

## Which stages may follow which. Declared rather than implied by a chain of
## `if`s, for the same reason DayLifecycle declares its phase order: a transition
## nobody wrote down is a transition nobody can test.
##
## `release` is terminal — the chain clears from there rather than moving on.
## `result` reaches `booking` because an arrest is decided during resolution and
## the booking stage opens after the result is shown.
const STAGE_TRANSITIONS := {
	STAGE_DECISION: [STAGE_RESULT],
	STAGE_RESULT: [STAGE_BOOKING],
	STAGE_BOOKING: [STAGE_RELEASE],
	STAGE_RELEASE: [],
}

## Chain kinds this engine knows how to hold. Content for each arrives later;
## the engine only needs to know a kind is real so a typo cannot open a chain
## nothing can ever resolve.
const KIND_BOOST_CAUGHT := "boost_caught"
const KIND_STICK_BOOKING := "stick_booking"
const KIND_RETALIATION := "retaliation"
const KNOWN_KINDS: Array[String] = [
	KIND_BOOST_CAUGHT, KIND_STICK_BOOKING, KIND_RETALIATION,
]

var gs: Node
var gm: Node

## action_id -> system instance. Runtime only. Never serialised — see the header.
var _source_adapters: Dictionary = {}

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

## The engine handles one action this slice: committing a response to an open
## decision. The authored resolution behind it is FS-003.7's; what lives here is
## the revalidation every commit must pass whoever wrote the content.
func can_handle(action: String) -> bool:
	return action in ["resolve_consequence_choice", "consequence_continue"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"resolve_consequence_choice":
			return _resolve_choice(payload)
		"consequence_continue":
			return _continue(payload)
	return {"ok": false, "reason": "Unknown consequence action."}

# --- source adapters --------------------------------------------------------

## Register a runtime source adapter. Called from `GameManager._ready()` on every
## boot, including after a load — which is what makes a reloaded chain able to
## find its source again without ever having stored a reference to it.
func register_source_adapter(action_id: String, system: Object) -> void:
	if action_id.is_empty() or system == null:
		return
	_source_adapters[action_id] = system

## The system that owns a chain's source, or null. Callers null-check: a chain
## can outlive an adapter if a save is loaded by a build that no longer registers
## it, and that must read as "cannot act" rather than crash.
func source_adapter(action_id: String) -> Object:
	return _source_adapters.get(action_id)

func registered_adapter_ids() -> Array:
	var ids: Array = _source_adapters.keys()
	ids.sort()
	return ids

# --- identity ---------------------------------------------------------------

## TI-003 §4: `cause_id = "cause:%08d" % next_cause_sequence`, allocated with
## **zero randomness**. Two reasons it must not be random: a reload would
## renumber a live chain, and consequence RNG keys are built from the Cause, so a
## renumbered chain would reroll its own outcome.
func allocate_cause_id() -> String:
	gs.next_cause_sequence = int(gs.next_cause_sequence) + 1
	return "cause:%08d" % int(gs.next_cause_sequence)

func allocate_consequence_id() -> String:
	gs.next_consequence_sequence = int(gs.next_consequence_sequence) + 1
	return "consequence:%08d" % int(gs.next_consequence_sequence)

# --- the exactly-once ledger ------------------------------------------------

## The history row for a Cause, created empty on first touch.
func history_for(cause_id: String) -> Dictionary:
	if not gs.consequence_history.has(cause_id):
		gs.consequence_history[cause_id] = {
			"effect_receipts": [], "resolved_consequence_ids": [],
			"scheduled_actor_ids": [],
		}
	return gs.consequence_history[cause_id]

## Has this effect already landed for this Cause?
func has_receipt(cause_id: String, key: String) -> bool:
	if not gs.consequence_history.has(cause_id):
		return false
	var row: Dictionary = gs.consequence_history[cause_id]
	return key in (row.get("effect_receipts", []) as Array)

## Claim an effect. **Returns false when it has already been claimed**, which is
## the caller's signal to skip the mutation entirely:
##
##     if engine.record_receipt(cause_id, "boost_caught:heat"):
##         heat.apply_gain(...)
##
## Written this way round on purpose. `if not has_receipt(): apply(); record()`
## is three lines that can be reordered wrongly; this is one that cannot.
func record_receipt(cause_id: String, key: String) -> bool:
	if cause_id.is_empty() or key.is_empty():
		return false
	if has_receipt(cause_id, key):
		return false
	var row: Dictionary = history_for(cause_id)
	(row["effect_receipts"] as Array).append(key)
	return true

func receipts_for(cause_id: String) -> Array:
	if not gs.consequence_history.has(cause_id):
		return []
	return (gs.consequence_history[cause_id] as Dictionary).get("effect_receipts", [])

## Record that a consequence resolved under this Cause. Same idempotency rule.
func record_resolved(cause_id: String, consequence_id: String) -> bool:
	if cause_id.is_empty() or consequence_id.is_empty():
		return false
	var row: Dictionary = history_for(cause_id)
	var resolved: Array = row["resolved_consequence_ids"]
	if consequence_id in resolved:
		return false
	resolved.append(consequence_id)
	return true

## Record that an actor was scheduled against this Cause. TI-003 §15's dedupe key
## is `(actor_id, cause_id)`, and this is the half of it the history owns.
func record_scheduled_actor(cause_id: String, actor_id: String) -> bool:
	if cause_id.is_empty() or actor_id.is_empty():
		return false
	var row: Dictionary = history_for(cause_id)
	var actors: Array = row["scheduled_actor_ids"]
	if actor_id in actors:
		return false
	actors.append(actor_id)
	return true

func has_scheduled_actor(cause_id: String, actor_id: String) -> bool:
	if not gs.consequence_history.has(cause_id):
		return false
	var row: Dictionary = gs.consequence_history[cause_id]
	return actor_id in (row.get("scheduled_actor_ids", []) as Array)

# --- the active chain -------------------------------------------------------

func has_active() -> bool:
	return not gs.active_consequence.is_empty()

func active() -> Dictionary:
	return gs.active_consequence

func active_stage() -> String:
	return str(gs.active_consequence.get("stage", ""))

func active_cause_id() -> String:
	return str(gs.active_consequence.get("cause_id", ""))

func active_consequence_id() -> String:
	return str(gs.active_consequence.get("consequence_id", ""))

## Open a blocking chain. Refuses when one is already open — TI-003 §10 gives the
## engine exactly one, and a second caller is a bug rather than a queue request.
## Queueing is `enqueue()`, which is a different intent and says so.
##
## `spec` carries the authored shape (source snapshot, allowed choices, shown
## odds). The engine stamps identity, stage and time and does not inspect the
## rest — that is what lets .7 add content without touching this.
func open_chain(kind: String, spec: Dictionary) -> Dictionary:
	if has_active():
		return {"ok": false, "reason": "A consequence is already open."}
	if not kind in KNOWN_KINDS:
		return {"ok": false, "reason": "Unknown consequence kind '%s'." % kind}

	var cause_id := str(spec.get("cause_id", ""))
	if cause_id.is_empty():
		cause_id = allocate_cause_id()
	# A chain normally opens on the decision it is asking the player to make.
	# Not every chain has one: a Stick arrest opens on the RESULT of a robbery
	# that already resolved through the source system, and there was never a
	# response to choose. `initial_stage` lets a source say so rather than
	# opening a decision with no choices and walking straight past it.
	#
	# Validated against the same table every later move is: an unknown stage is
	# refused here rather than becoming a chain nothing can advance.
	var initial_stage := str(spec.get("initial_stage", STAGE_DECISION))
	if not STAGE_TRANSITIONS.has(initial_stage):
		return {"ok": false, "reason": "Unknown consequence stage '%s'." % initial_stage}
	var chain: Dictionary = {
		"consequence_id": allocate_consequence_id(),
		"cause_id": cause_id,
		"chain_kind": kind,
		"stage": initial_stage,
		"created_day": int(gs.day),
		"created_slot": int(gs.time_slots_today),
		"district_id": str(spec.get("district_id", gs.current_district_id)),
		"return_route": str(spec.get("return_route", "")),
		"source": spec.get("source", {}),
		"decision": _decision_block(spec.get("decision", {})),
		"booking": {},
		# TI-003 §12: "A non-arrest result keeps the source slot unsettled until
		# Continue." The source action's one slot is owed and unpaid from here.
		"time": {
			"source_slots_remaining": int(spec.get("source_slots", 1)),
			"source_time_settled": false,
		},
	}
	gs.active_consequence = chain
	history_for(cause_id)
	return {"ok": true, "consequence_id": chain["consequence_id"], "cause_id": cause_id}

## Normalise the decision block so every chain has the same shape whether or not
## its author filled every field. The projections read these keys unconditionally.
func _decision_block(authored: Dictionary) -> Dictionary:
	return {
		"definition_id": str(authored.get("definition_id", "")),
		"allowed_choices": authored.get("allowed_choices", []),
		"committed_choice": str(authored.get("committed_choice", "")),
		"resolver_inputs": authored.get("resolver_inputs", {}),
		"shown_probabilities": authored.get("shown_probabilities", {}),
		"deterministic_choices": authored.get("deterministic_choices", []),
		"resolved_tier": str(authored.get("resolved_tier", "")),
		"result": authored.get("result", {}),
	}

## Move the chain forward. Refuses any transition not in `STAGE_TRANSITIONS`, so
## a slice that adds a stage has to declare how it is reached.
func advance_stage(to_stage: String) -> Dictionary:
	if not has_active():
		return {"ok": false, "reason": "No consequence is open."}
	var from_stage := active_stage()
	var allowed: Array = STAGE_TRANSITIONS.get(from_stage, [])
	if not to_stage in allowed:
		return {"ok": false,
			"reason": "Cannot go from %s to %s." % [from_stage, to_stage]}
	gs.active_consequence["stage"] = to_stage
	return {"ok": true, "stage": to_stage}

## Close the chain. The receipts stay: history outlives the chain, which is what
## makes a Cause's effects un-repeatable after it is gone.
func clear_chain() -> void:
	var cause_id := active_cause_id()
	var consequence_id := active_consequence_id()
	if not cause_id.is_empty() and not consequence_id.is_empty():
		record_resolved(cause_id, consequence_id)
	gs.active_consequence = {}

## Whether the source action's time cost is still owed.
##
## TI-003 §26: "One source action pays its normal time cost once after its
## blocking consequence reaches terminal handoff", and regression #12 is that
## time settling twice around Booking. This flag is how "once" is enforced across
## a reload, so it is read here rather than recomputed.
func source_time_owed() -> bool:
	if not has_active():
		return false
	var time_block: Dictionary = gs.active_consequence.get("time", {})
	return not bool(time_block.get("source_time_settled", false))

## Mark the source slot paid. Returns false if it was already settled, which is
## the same idempotency contract as a receipt and for the same reason.
func settle_source_time() -> bool:
	if not has_active():
		return false
	var time_block: Dictionary = gs.active_consequence.get("time", {})
	if bool(time_block.get("source_time_settled", false)):
		return false
	time_block["source_time_settled"] = true
	gs.active_consequence["time"] = time_block
	return true

# --- the delayed queue ------------------------------------------------------

## Add a delayed consequence. Deduped on TI-003 §15's `(actor_id, cause_id)`.
func enqueue(row: Dictionary) -> Dictionary:
	var cause_id := str(row.get("cause_id", ""))
	var actor_id := str(row.get("actor_id", ""))
	if cause_id.is_empty() or actor_id.is_empty():
		return {"ok": false, "reason": "A queued consequence needs a cause and an actor."}
	for existing in gs.consequence_queue:
		var e: Dictionary = existing
		if str(e.get("cause_id", "")) == cause_id and str(e.get("actor_id", "")) == actor_id:
			return {"ok": false, "reason": "Already queued."}
	var queued: Dictionary = row.duplicate(true)
	if not queued.has("created_sequence"):
		# Monotonic within the queue, so ordering is stable without a clock.
		queued["created_sequence"] = gs.consequence_queue.size() + 1
	if not queued.has("status"):
		queued["status"] = "pending"
	gs.consequence_queue.append(queued)
	record_scheduled_actor(cause_id, actor_id)
	return {"ok": true, "queue_id": str(queued.get("queue_id", ""))}

## Drop every queued row for a Cause. TI-003 §15: an arrest suppresses the
## retaliation that Cause would have produced — you already paid for it.
func suppress_cause(cause_id: String) -> int:
	if cause_id.is_empty():
		return 0
	var kept: Array = []
	var removed: int = 0
	for row in gs.consequence_queue:
		if str((row as Dictionary).get("cause_id", "")) == cause_id:
			removed += 1
			continue
		kept.append(row)
	gs.consequence_queue = kept
	return removed

## Mark rows past their expiry. TI-003 §15: a retaliation the player avoided
## through the whole window simply expires.
func expire_stale(today: int) -> int:
	var expired: int = 0
	for row in gs.consequence_queue:
		var r: Dictionary = row
		if str(r.get("status", "pending")) != "pending":
			continue
		if today > int(r.get("expires_end_day", 0x7FFFFFFF)):
			r["status"] = "expired"
			expired += 1
	return expired

## The rows that could surface right now, in the order TI-003 §15 declares:
## `trigger_day`, then `created_sequence`.
##
## Sorted explicitly. Never returned in queue order and never in Dictionary
## order — regression #32 exists because someone will otherwise assume the
## container's order is the contract.
func eligible_queued(today: int, district_id: String) -> Array:
	var eligible: Array = []
	for row in gs.consequence_queue:
		var r: Dictionary = row
		if str(r.get("status", "pending")) != "pending":
			continue
		if today < int(r.get("trigger_day", 0x7FFFFFFF)):
			continue
		if today > int(r.get("expires_end_day", 0x7FFFFFFF)):
			continue
		# TI-003 §15: retaliation waits for the player to be present. It does not
		# follow them across districts (regression #29).
		if str(r.get("district_id", "")) != district_id:
			continue
		eligible.append(r)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_day: int = int(a.get("trigger_day", 0))
		var b_day: int = int(b.get("trigger_day", 0))
		if a_day != b_day:
			return a_day < b_day
		return int(a.get("created_sequence", 0)) < int(b.get("created_sequence", 0)))
	return eligible

## Whether a delayed consequence may take the blocking slot today.
##
## Three gates, all of TI-003 §15's: the slot must be free, the daily allowance
## unspent, and — checked by the caller through `eligible_queued` — a row must
## actually be due here.
func can_surface_delayed(today: int) -> bool:
	if has_active():
		return false
	return int(gs.last_blocking_delayed_day) != today

## Claim the day's one delayed slot. Separate from `can_surface_delayed` so the
## claim is a deliberate act rather than a side effect of asking.
func mark_delayed_surfaced(today: int) -> void:
	gs.last_blocking_delayed_day = today

# --- dispatch validation ----------------------------------------------------

## TI-003 §12: "Revalidate active identity, stage, allowed choice, and absence of
## a committed-choice receipt."
##
## All four, in that order, before anything mutates. The IDs are revalidated
## rather than trusted because the payload comes from a button that may have been
## rendered before a reload — a stale tap must be refused, not honoured against
## whatever chain happens to be open now.
##
## The authored resolution this gates is FS-003.7's. What this slice guarantees
## is that a resolution can only ever run once, on the chain the player was
## actually looking at.
func _resolve_choice(payload: Dictionary) -> Dictionary:
	if not has_active():
		return {"ok": false, "reason": "Nothing is waiting on you."}
	var chain: Dictionary = gs.active_consequence

	var consequence_id := str(payload.get("consequence_id", ""))
	if not consequence_id.is_empty() and consequence_id != active_consequence_id():
		return {"ok": false, "reason": "That moment has passed."}
	var cause_id := str(payload.get("cause_id", ""))
	if not cause_id.is_empty() and cause_id != active_cause_id():
		return {"ok": false, "reason": "That moment has passed."}

	if active_stage() != STAGE_DECISION:
		return {"ok": false, "reason": "This is already decided."}

	var decision: Dictionary = chain.get("decision", {})
	var choice_id := str(payload.get("choice_id", ""))
	if choice_id.is_empty():
		return {"ok": false, "reason": "Pick something."}
	if not choice_id in (decision.get("allowed_choices", []) as Array):
		return {"ok": false, "reason": "That is not one of your options."}

	# The committed-choice receipt. A reload between the mutation and the
	# autosave cannot produce a second commit, because the receipt and the
	# commit land in the same dispatch.
	if not record_receipt(active_cause_id(), "%s:committed_choice" % str(chain.get("chain_kind", ""))):
		return {"ok": false, "reason": "You already made that call."}

	decision["committed_choice"] = choice_id
	chain["decision"] = decision

	# The authored outcome is FS-003.7's. The engine commits the choice, records
	# it, and stops — deliberately, so the seam is visible rather than implied.
	var adapter_id := str((chain.get("source", {}) as Dictionary).get("action_id", ""))
	var adapter: Object = source_adapter(adapter_id)
	if adapter != null and adapter.has_method("resolve_consequence"):
		var outcome: Dictionary = adapter.resolve_consequence(chain, choice_id)
		if not bool(outcome.get("ok", false)):
			return outcome
	return {"ok": true, "choice_id": choice_id, "stage": active_stage()}

## The terminal handoff. TI-003 §12: "Continue settles that source slot once and
## clears the chain."
##
## Both halves are here because they are one decision — a Continue that settled
## time without clearing, or cleared without settling, is the regression this
## action exists to make impossible (TI-003 #12).
##
## The slot is spent through the time system, which is what makes a consequence
## cost the day it always should have: the source action's slot was never paid
## while the chain was open.
func _continue(payload: Dictionary) -> Dictionary:
	if not has_active():
		return {"ok": false, "reason": "Nothing is waiting on you."}
	var consequence_id := str(payload.get("consequence_id", ""))
	if not consequence_id.is_empty() and consequence_id != active_consequence_id():
		return {"ok": false, "reason": "That moment has passed."}

	# Only the two terminal stages hand back. A Continue from `decision` would
	# let the player walk away from a choice they have not made.
	var stage := active_stage()
	if not stage in [STAGE_RESULT, STAGE_RELEASE]:
		return {"ok": false, "reason": "This is not finished."}

	# A result that ends in an arrest is not a handoff — it is the doorway to
	# Booking, and Continue walks through it.
	#
	# The chain deliberately WAITS at `result` rather than jumping to `booking`
	# the moment the arrest gate fires. PX-003 §5 shows the arrested result with
	# a BOOKING action under it ("THE FIGHT ENDS IN CUFFS"), and TI-003 §18
	# requires the result stage to show "exact changes to Cash, goods, Health,
	# Heat, bans, and arrest state". A chain that advanced itself would render
	# the bail quote over a result the player never got to read.
	#
	# Nothing settles here: the source slot stays owed, because §13 step 8 makes
	# settling it part of the booking commit.
	if stage == STAGE_RESULT and _booking_pending():
		var moved: Dictionary = advance_stage(STAGE_BOOKING)
		if not bool(moved.get("ok", false)):
			return moved
		return {"ok": true, "stage": STAGE_BOOKING, "slots_settled": 0}

	var owed: int = 0
	if source_time_owed():
		var time_block: Dictionary = gs.active_consequence.get("time", {})
		owed = int(time_block.get("source_slots_remaining", 0))
		settle_source_time()

	clear_chain()

	# Settled AFTER the chain is cleared. Advancing time can cross a day, which
	# runs the whole night sequence — and a night that ran while the chain was
	# still open could surface a delayed consequence into a slot that was about
	# to be freed anyway.
	var time_system: Object = gm.system("time") if gm != null else null
	if owed > 0 and time_system != null:
		for _slot in range(owed):
			time_system.handle("advance_time", {})
	return {"ok": true, "slots_settled": owed}

# --- projections ------------------------------------------------------------
#
# TI-003 §18: "Consequence UI consumes projections only." Every one of these
# returns plain data — Strings, ints, floats, Arrays of Dictionaries — and never
# a handle into GameState that a screen could write through.

## What is happening, for the scene's header.
func active_summary() -> Dictionary:
	if not has_active():
		return {}
	var chain: Dictionary = gs.active_consequence
	var source: Dictionary = chain.get("source", {})
	return {
		"consequence_id": active_consequence_id(),
		"cause_id": active_cause_id(),
		"chain_kind": str(chain.get("chain_kind", "")),
		"stage": active_stage(),
		"district_id": str(chain.get("district_id", "")),
		"return_route": str(chain.get("return_route", "")),
		"definition_id": str((chain.get("decision", {}) as Dictionary).get("definition_id", "")),
		"source_family": str(source.get("family", "")),
		"source_target_id": str(source.get("target_id", "")),
		"source_target_tier": int(source.get("target_tier", 0)),
		"contested_take": int(source.get("contested_take", 0)),
		"pre_encounter_heat": float(source.get("pre_encounter_heat", 0.0)),
		"source_time_owed": source_time_owed(),
	}

## One row per response the player may pick.
##
## `committed` is what disables a button, and it is derived from PERSISTED state
## rather than from a click — TI-003 §18 requires committed controls to stay
## disabled after a reload, and a flag set in `_pressed` would not survive one.
func choice_summaries() -> Array:
	if not has_active():
		return []
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	var committed := str(decision.get("committed_choice", ""))
	var deterministic: Array = decision.get("deterministic_choices", [])
	var shown: Dictionary = decision.get("shown_probabilities", {})
	var rows: Array = []
	for entry in (decision.get("allowed_choices", []) as Array):
		var choice_id := str(entry)
		var is_deterministic: bool = choice_id in deterministic
		rows.append({
			"choice_id": choice_id,
			"label": choice_id.capitalize(),
			# A deterministic response has no odds to show, and showing it as
			# 0% would read as "impossible" rather than "certain".
			"deterministic": is_deterministic,
			"success_probability": float(shown.get(choice_id, 0.0)),
			"has_odds": not is_deterministic and shown.has(choice_id),
			"committed": not committed.is_empty() and choice_id == committed,
			# Any commit disables every button, not only the one pressed.
			"disabled": not committed.is_empty(),
		})
	return rows

## Whether the active chain is holding a booking the player has not answered yet.
func _booking_pending() -> bool:
	if not has_active():
		return false
	var booking: Dictionary = gs.active_consequence.get("booking", {})
	return bool(booking.get("pending", false))

## The booking quote, before the player commits to paying it.
##
## The stored block is the source of truth for everything frozen at arrest time —
## quote, priors, severity, relief. The three payment lanes and their release
## points are DERIVED, and ArrestSystem owns that derivation because it owns the
## severity table the slot math reads. This asks it and falls back to the raw
## block, so a build with no ArrestSystem registered still renders a quote
## instead of crashing.
func booking_summary() -> Dictionary:
	if not has_active():
		return {}
	var booking: Dictionary = gs.active_consequence.get("booking", {})
	if booking.is_empty():
		return {}
	var arrest: Object = gm.system("arrest") if gm != null else null
	if arrest != null and arrest.has_method("booking_projection"):
		return arrest.booking_projection(gs.active_consequence)
	return booking.duplicate(true)

## What actually happened, for the result and release stages.
func result_summary() -> Dictionary:
	if not has_active():
		return {}
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	return {
		"committed_choice": str(decision.get("committed_choice", "")),
		"resolved_tier": str(decision.get("resolved_tier", "")),
		"result": (decision.get("result", {}) as Dictionary).duplicate(true),
	}

## Read-only view of the queue, for tests and later slices. Duplicated so a
## caller cannot reorder the real one by sorting what it was handed.
func queue_snapshot() -> Array:
	return gs.consequence_queue.duplicate(true)

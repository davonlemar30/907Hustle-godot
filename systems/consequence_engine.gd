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
## The fourth kind. A person who is in front of you because you went out
## looking, rather than because of something you did to them.
##
## It is a kind rather than a new engine for the same reason the web build gave
## when it routed a blown lift through here — "reusing EncounterModal, no new UI
## shell". A chain is a chain: the screen renders any of them, the stage table
## governs all of them, and a reloaded save finds its source through the same
## runtime adapter registry. What a fourth kind actually costs is this constant
## and one `resolve_consequence` method on the system that opens it.
const KIND_WANDER := "wander_encounter"
## The fifth kind: the multi-round resolution loop (design name "Squared Up";
## the player never reads either name). A confrontation is still one chain —
## what makes it a loop is that its DECISION stage re-presents itself round by
## round instead of resolving on the first commit. The round mechanics live in
## `systems/confrontation_loop.gd` and the authored scripts in
## `data/confrontation_scripts.gd`; the engine's whole contribution is the
## round-keyed commit receipt in `_resolve_choice` and the `loop_summary()`
## projection, because everything else the loop needs the chain already had.
const KIND_CONFRONTATION := "confrontation"
## The sixth kind (0.3.0, ENC-D1..D9): the decision a blown TIER-1 stickup
## opens before any arrest resolves — "the blown job answers to somebody."
## `KIND_STICK_BOOKING` above is retired as a NEW entry path (ENC-D1 supersedes
## TI-003 §14's decision-less booking) but stays a known, resolvable kind: a
## save written before this build can hold one already sitting at `result` or
## `booking`, and it has to keep loading and resolving exactly as it always
## has. Rooms (tier 2-3) are untouched — ENC-D2 — because their own stages
## already are the decision; this kind exists only for the single-roll path.
const KIND_STICK_CAUGHT := "stick_caught"
## The seventh kind (0.5.0 PR C, STR-D4): the same interruption the street
## already runs on a wander, invoked on district travel instead — "the DL2
## airport-security moment, at ground level." Its own kind rather than
## `KIND_WANDER` because the fiction is different (caught mid-transit, not
## caught wandering) and because `travel.gd`, not Wander, is the system that
## opens and resolves it — matching the doc comment above this constant's
## siblings: a fourth (and fifth, sixth...) kind costs one constant and one
## `resolve_consequence` method on the system that opens it, nothing more.
const KIND_TRAVEL_STOP := "travel_stop"
const KNOWN_KINDS: Array[String] = [
	KIND_BOOST_CAUGHT, KIND_STICK_BOOKING, KIND_RETALIATION, KIND_WANDER,
	KIND_CONFRONTATION, KIND_STICK_CAUGHT, KIND_TRAVEL_STOP,
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
	return action in ["resolve_consequence_choice", "consequence_continue", "post_up"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"resolve_consequence_choice":
			return _resolve_choice(payload)
		"consequence_continue":
			return _continue(payload)
		"post_up":
			return _post_up()
	return {"ok": false, "reason": "Unknown consequence action."}

## Why Post Up cannot fire right now, or "" if it can. Public so Market can
## preview it the same way every other slot-costing surface previews its own
## blocker (see wander.gd::blocker()) — a screen reads this to decide a
## button's disabled state and label without dispatching anything.
func post_up_blocker() -> String:
	if bool(gs.game_over):
		return "The run is over"
	if bool(has_active()):
		return "Deal with what is in front of you"
	return ""

## Post Up (PR 5): stand somewhere for an hour and see who comes by. The two
## things a wander spends its slot on — TimeSystem's clock and this engine's
## own retaliation-surfacing check — in the order Post Up's own framing asks
## for: the hour passes FIRST, and the corner's risk is what standing there
## for it bought. Wander checks the other way around because a surfaced
## encounter there has to pre-empt its OWN card draw; Post Up draws no card,
## so there is nothing to pre-empt.
##
## `try_surface_delayed` re-validates `can_surface_delayed` on its own before
## surfacing anything, so this is safe even when `advance_time` itself
## crosses a day and DAY_START's own `surface_delayed` step already opened
## something — the second call simply finds the engine already active and
## declines, the same guard that stops any two callers from racing it.
##
## One dispatch, one notify_changed, same as every other slot-costing action
## — never a bare time_system.handle() call from a screen, which would spend
## the hour without telling anything downstream it had.
func _post_up() -> Dictionary:
	var blocked: String = post_up_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked + "."}
	var time_sys: Object = gm.system("time") if gm != null else null
	if time_sys != null:
		time_sys.handle("advance_time", {})
	var surfaced := str(try_surface_delayed(int(gs.day), str(gs.current_district_id)))
	# SQ-D10: `corner_push`, after the delayed check has had its say. A
	# consequence that was already queued outranks a fresh corner push, the
	# same precedence every other surfacing site uses -- and `try_open_push`
	# refuses outright while a chain is active, so this is belt and braces.
	var corner: Object = gm.system("corner") if gm != null else null
	if surfaced.is_empty() and corner != null:
		corner.try_open_push(str(gs.current_district_id))
	return {"ok": true}

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
		# choice_id -> arrest-risk code, snapshotted with the odds when the
		# decision opened. Persisted for the same reason the odds are: a reload
		# must reproduce the warning the player decided against, not re-derive
		# one against state that has since moved.
		"arrest_risks": authored.get("arrest_risks", {}),
		"resolved_tier": str(authored.get("resolved_tier", "")),
		"result": authored.get("result", {}),
		# The loop's two fields, normalised with the rest so a confrontation
		# chain has them from birth and every other kind carries the neutral
		# values. `round` keys the commit receipt (see `_resolve_choice`);
		# `loop` is the round state `confrontation_loop.gd` owns.
		"round": int(authored.get("round", 0)),
		"loop": authored.get("loop", {}),
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
## time settling twice around Booking. The settled flag is how "once" is enforced
## across a reload, so it is read here rather than recomputed.
##
## A chain carrying ZERO source slots owes nothing, and says so. That is not a
## hypothetical: a delayed retaliation is opened days after the robbery that
## caused it, and that robbery paid its slot at the time. Answering "owed"
## because a boolean has not been flipped would make the projection tell the
## player they are about to lose time they are not.
func source_time_owed() -> bool:
	if not has_active():
		return false
	var time_block: Dictionary = gs.active_consequence.get("time", {})
	if bool(time_block.get("source_time_settled", false)):
		return false
	return int(time_block.get("source_slots_remaining", 0)) > 0

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
##
## The rows that transitioned are handed to the retaliation system, which owns
## PX-003 §8's one-time "it stopped" callback. The engine decides WHAT expired —
## that is the queue's business — and says nothing about it; the copy, the
## channel and the once-per-run flag all belong to the system that authored the
## threat. Passing the rows rather than a count is what lets the callback name
## the district the player actually walked away from.
func expire_stale(today: int) -> int:
	var expired: Array = []
	for row in gs.consequence_queue:
		var r: Dictionary = row
		if str(r.get("status", "pending")) != "pending":
			continue
		if today > int(r.get("expires_end_day", 0x7FFFFFFF)):
			r["status"] = "expired"
			expired.append(r)
	if not expired.is_empty():
		var owner: Object = gm.system("retaliation") if gm != null else null
		if owner != null and owner.has_method("note_expiries"):
			owner.note_expiries(expired)
	return expired.size()

## Drop what the consequence layer is provably done with: queue rows whose
## status is terminal (`resolved` / `expired`), and history rows for Causes
## nothing can address again. Called at day-start BEFORE `expire_stale`, so a
## row expired tonight keeps its terminal status on the queue until tomorrow —
## the same one-night grace the shark ledger gives a settled note, and for the
## same reason: whatever asserted or narrated the transition has already run,
## but nothing same-tick is surprised by a vanishing row.
##
## ## Why a dead Cause is dead — the audit this rule stands on
##
## Every `record_receipt` / `has_receipt` call site in the build (this file's
## commit path, `arrest.gd`'s booking steps, `stickup.gd`'s room resolution,
## `boost.gd`'s caught loop including BRIBE and HAND IT BACK, and
## `retaliation.gd`'s encounter effects) takes its cause_id from the ACTIVE
## chain, or from the dispatch that allocated the Cause moments earlier.
## `has_scheduled_actor` is consulted only by `retaliation.schedule()`, which
## only ever receives the cause_id of the robbery resolving in that same
## dispatch. No code path holds a cause_id across days except the active chain
## and the delayed queue — so a Cause that is not the active chain's and has no
## `pending`/`surfaced` queue row cannot be addressed again, and its receipts
## guard effects that can no longer fire. Pruning runs at day-cross, never
## mid-dispatch, so even the same-dispatch window cannot be caught out.
##
## Without this, `consequence_history` grew one row per Cause for the whole
## run (~1-3 a criminal day) and the queue kept every threat it ever carried —
## the two arrays the v22 memory fix measured and named. The v21 → v22
## migration arm applies this same rule once to a loading save.
func prune_settled() -> Dictionary:
	var live_causes: Dictionary = {}
	var active_cause := active_cause_id()
	if not active_cause.is_empty():
		live_causes[active_cause] = true
	var kept_rows: Array = []
	var queue_dropped: int = 0
	for row in gs.consequence_queue:
		var r: Dictionary = row
		if str(r.get("status", "pending")) in ["resolved", "expired"]:
			queue_dropped += 1
			continue
		live_causes[str(r.get("cause_id", ""))] = true
		kept_rows.append(r)
	gs.consequence_queue = kept_rows
	var history_dropped: int = 0
	for cause_id in gs.consequence_history.keys():
		if not live_causes.has(str(cause_id)):
			gs.consequence_history.erase(cause_id)
			history_dropped += 1
	return {"queue_dropped": queue_dropped, "history_dropped": history_dropped}

## Today's one ambient warning, if a live threat is standing where the player is.
##
## Forwarded rather than implemented here for the same reason `expire_stale`
## forwards its rows: the queue is the engine's, the voice is the retaliation
## system's. The lifecycle calls this by name from `DAY_START_ORDER`.
func push_retaliation_ambient(today: int) -> int:
	var owner: Object = gm.system("retaliation") if gm != null else null
	if owner == null or not owner.has_method("push_ambient_warnings"):
		return 0
	return int(owner.push_ambient_warnings(today))

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

## Surface the oldest eligible delayed consequence, if anything may.
##
## The four gates of TI-003 §15 are all here, in one place, because "may this
## surface" is a question about the QUEUE and belongs to the queue's owner. The
## retaliation system builds the encounter; it never decides whether it is
## allowed to.
##
##   1. nothing is already blocking (regression #27: a retaliation surfacing
##      during Caught or Booking)
##   2. today's one delayed slot is unspent (regression #28)
##   3. a row is due, unexpired, and in THIS district (regression #29: a
##      retaliation following the player across town)
##   4. oldest first, deterministically (regression #32)
##
## Returns the queue_id that surfaced, or "". Called from the day-start
## lifecycle and after travel — the two moments the answer can change.
func try_surface_delayed(today: int, district_id: String) -> String:
	if not can_surface_delayed(today):
		return ""
	var eligible: Array = eligible_queued(today, district_id)
	if eligible.is_empty():
		return ""
	var row: Dictionary = eligible[0]
	var owner: Object = gm.system("retaliation") if gm != null else null
	if owner == null or not owner.has_method("open_encounter"):
		return ""
	var opened: Dictionary = owner.open_encounter(row)
	if not bool(opened.get("ok", false)):
		return ""
	row["status"] = "surfaced"
	# Claimed only once the chain is genuinely open. Claiming before would spend
	# the day's allowance on an encounter that failed to open.
	mark_delayed_surfaced(today)
	return str(row.get("queue_id", ""))

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

	# Ask BEFORE the commit receipt is claimed below, not after -- see
	# `choice_blocked`'s own header for why refusing post-commit would strand
	# the round.
	var blocked := choice_blocked(choice_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}

	# The committed-choice receipt. A reload between the mutation and the
	# autosave cannot produce a second commit, because the receipt and the
	# commit land in the same dispatch.
	#
	# A multi-round chain commits once per ROUND, so the receipt is keyed on
	# `decision.round` from round one onward. Round zero keeps the original
	# unsuffixed key deliberately: every existing single-decision chain — and
	# any mid-chain save written before this field existed — carries round 0
	# and keeps exactly the receipt string it always had.
	var commit_key := "%s:committed_choice" % str(chain.get("chain_kind", ""))
	var commit_round: int = int(decision.get("round", 0))
	if commit_round > 0:
		commit_key += ":round:%d" % commit_round
	if not record_receipt(active_cause_id(), commit_key):
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
	# Stamped even when nothing was owed, so the chain's own record reads
	# "settled" rather than "never asked". A zero-slot chain has to be closed the
	# same way a one-slot chain is.
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
		# The two the scene actually shows a player: the place or the person.
		# `target_id` is a stable identifier and reads like one; these are the
		# words the source system already had for the same thing.
		"source_target_name": str(source.get("target_name", "")),
		"source_opponent": str(source.get("opponent", "")),
		# BB-D2 (0.7.0): the card's own opening line, written into the chain by
		# the adapter that opened it, so the sheet can put the moment on screen
		# instead of a standing line that was true of every card at once.
		"source_opener": str(source.get("opener", "")),
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
## Ask the active chain's source adapter for a piece of copy, falling back to
## whatever the engine would have said on its own.
##
## Null-guarded twice over: a chain can outlive its adapter across a save, and
## an adapter that does not implement the method is the ordinary case rather
## than an error.
func _adapter_copy(choice_id: String, method: String, fallback: String) -> String:
	if not has_active():
		return fallback
	var action_id := str((gs.active_consequence.get("source", {}) as Dictionary)
		.get("action_id", ""))
	var adapter: Object = source_adapter(action_id)
	if adapter == null or not adapter.has_method(method):
		return fallback
	var said := str(adapter.call(method, choice_id))
	return said if not said.is_empty() else fallback

## The description under a choice, for the screen. Same seam as the label.
func choice_description(choice_id: String, fallback: String) -> String:
	return _adapter_copy(choice_id, "choice_copy", fallback)

## The certainty line under a DETERMINISTIC choice, for the screen. Same seam
## as the label and description, and for the same reason this one exists at
## all: the screen's own fallback text ("no injury, no Heat, no arrest") is
## true for every deterministic choice that shipped before 0.3.0 (Boost's
## YIELD, BRIBE, HAND IT BACK), but Stick Caught's YIELD is a guaranteed
## SURRENDER — it books, deliberately (ENC-D6). A chain whose guaranteed
## response is not that fallback says so through its own adapter rather than
## the screen special-casing a chain kind the fallback was never written to
## describe.
func choice_guarantee(choice_id: String, fallback: String) -> String:
	return _adapter_copy(choice_id, "choice_guarantee", fallback)

## Per-choice reason a choice cannot be committed right now, or "" when it can
## be. Same seam as the label and description above: only the source system
## knows a choice's own gating (a store already bought this run, an amount
## the wallet cannot cover), and the engine has no business guessing at it.
## `_resolve_choice` checks this BEFORE claiming the commit receipt, which is
## the whole reason this exists rather than the adapter simply refusing from
## inside `resolve_consequence` -- by then the round's one commit is already
## spent, and a refusal there would leave the chain committed to a choice
## that never happened, with no way to try again this round.
func choice_blocked(choice_id: String) -> String:
	return _adapter_copy(choice_id, "choice_blocked", "")

## BB-D1 (0.7.0): the result's own words, from the adapter that resolved it.
##
## Until this seam existed the sheet carried one result-copy table for every
## chain kind and fell through to Boost's vocabulary for anything it had no
## arm for -- which was every street encounter, every checkpoint, and every
## doorstep. A three-round fistfight on a corner with nothing at stake read
## "The take is gone and the room remembers your face." The adapter that
## resolved the choice is the only thing that knows what actually happened, so
## it is asked first; an empty answer (or no method at all) falls back to the
## sheet's own arms, exactly the way `choice_description` already degrades.
##
## The adapter receives the committed choice, the resolved tier, and a COPY of
## the result block -- plain data, never a handle into the chain.
func result_headline(fallback: String) -> String:
	return _adapter_result_copy("result_headline", fallback)

func result_body(fallback: String) -> String:
	return _adapter_result_copy("result_body", fallback)

func _adapter_result_copy(method: String, fallback: String) -> String:
	if not has_active():
		return fallback
	var action_id := str((gs.active_consequence.get("source", {}) as Dictionary)
		.get("action_id", ""))
	var adapter: Object = source_adapter(action_id)
	if adapter == null or not adapter.has_method(method):
		return fallback
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	var said := str(adapter.call(method, str(decision.get("committed_choice", "")),
		str(decision.get("resolved_tier", "")),
		(decision.get("result", {}) as Dictionary).duplicate(true)))
	return said if not said.is_empty() else fallback

func choice_summaries() -> Array:
	if not has_active():
		return []
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	var committed := str(decision.get("committed_choice", ""))
	var deterministic: Array = decision.get("deterministic_choices", [])
	var shown: Dictionary = decision.get("shown_probabilities", {})
	var risks: Dictionary = decision.get("arrest_risks", {})
	var rows: Array = []
	for entry in (decision.get("allowed_choices", []) as Array):
		var choice_id := str(entry)
		var is_deterministic: bool = choice_id in deterministic
		var blocked_reason := choice_blocked(choice_id)
		rows.append({
			"choice_id": choice_id,
			# The source adapter names its own choices when it has an opinion,
			# the same seam batch 6a opened for delegation copy and for the same
			# reason: `fight`/`run`/`talk`/`yield` are Boost's vocabulary, and a
			# chain whose choices are `stand`/`walk`/`hand_over` should not have
			# to be spelled out in the engine or the screen to say so.
			# `capitalize()` remains the fallback, which is what the three
			# original kinds still use.
			"label": _adapter_copy(choice_id, "choice_label", choice_id.capitalize()),
			# A deterministic response has no odds to show, and showing it as
			# 0% would read as "impossible" rather than "certain".
			"deterministic": is_deterministic,
			"success_probability": float(shown.get(choice_id, 0.0)),
			"has_odds": not is_deterministic and shown.has(choice_id),
			"committed": not committed.is_empty() and choice_id == committed,
			# Any commit disables every button, not only the one pressed --
			# and so does the choice's own gating (e.g. a bribe short of its
			# price), so the button never dispatches a commit the engine
			# would have to refuse.
			"disabled": not committed.is_empty() or not blocked_reason.is_empty(),
			"blocked_reason": blocked_reason,
			# PX-003 §19 point 8: a known booking gate is surfaced BEFORE the
			# player commits. The code says which kind; the copy lives in the
			# scene, and neither reveals the threshold.
			"arrest_risk": str(risks.get(choice_id, "")),
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

## The multi-round chain's round state, for the scene's loop chrome. Empty for
## every chain that is not running a loop, which is what lets the scene ask
## unconditionally — same contract as every projection above: plain data, no
## handles.
func loop_summary() -> Dictionary:
	if not has_active():
		return {}
	var decision: Dictionary = gs.active_consequence.get("decision", {})
	var loop: Variant = decision.get("loop", {})
	if not (loop is Dictionary) or (loop as Dictionary).is_empty():
		return {}
	var state: Dictionary = loop
	return {
		"sheet_title": str(state.get("sheet_title", "")),
		"stage": int(state.get("stage", 0)),
		"stage_count": int(state.get("stage_count", 0)),
		"left": int(state.get("left", 0)),
		"left_label": str(state.get("left_label", "")),
		"banked": int(state.get("banked", 0)),
		# BB-D5 (0.7.0): whether BANKED is money at all. A stickup room banks
		# cash stage by stage (`take_total` is its budget); the corner and the
		# meetup open with a real sum on the table. A street fight banks
		# nothing the strip should print as dollars, and the sheet reads this
		# rather than guessing from the kind.
		"banks_cash": state.has("take_total") or int(state.get("banked", 0)) > 0,
		"beat": str(state.get("beat", "")),
		"log": (state.get("log", []) as Array).duplicate(),
		"mode": str(state.get("mode", "stage")),
	}

# --- District Pressure (TI-003 §8) -----------------------------------------
#
# The engine owns Pressure because Pressure is CROSS-SOURCE memory. A Boost, a
# Stick and a Market sale all write into the same district ledger under
# different families, and the score a Boost reads back may have been raised by a
# robbery two days ago. No single source system can own a number every other
# source system writes to.
#
# Stored per district, per family, in `gs.district_pressure`. Separate storage
# from `gs.heat` on purpose: TI-003 regression #16 is the two sharing it, and
# they answer different questions — Heat is how urgently police want you today,
# Pressure is whether this block has started recognising the routine. Pressure
# never converts into Heat.

const RULES := preload("res://data/consequence_rules.gd")

func _rules() -> RefCounted:
	return RULES.new()

## The ledger row for one district/family, created empty on first touch.
##
## `quiet_days` counts CONSECUTIVE days with no gain and is what the recovery
## rule reads. `market_gain_day` / `market_gain_today` are the daily cap's
## memory, and are only touched by Market.
func pressure_row(district_id: String, family: String) -> Dictionary:
	if not gs.district_pressure.has(district_id):
		gs.district_pressure[district_id] = {}
	var by_family: Dictionary = gs.district_pressure[district_id]
	if not by_family.has(family):
		by_family[family] = {
			"score": 0.0, "last_gain_day": -1, "quiet_days": 0,
			"market_gain_day": -1, "market_gain_today": 0.0,
		}
	return by_family[family]

## Current Pressure, without creating a row. A district nobody has worked reads
## 0.0 rather than allocating a ledger entry every time a screen renders.
func pressure_score(district_id: String, family: String) -> float:
	var by_family: Variant = gs.district_pressure.get(district_id)
	if not (by_family is Dictionary):
		return 0.0
	var row: Variant = (by_family as Dictionary).get(family)
	if not (row is Dictionary):
		return 0.0
	return float((row as Dictionary).get("score", 0.0))

## QUIET / KNOWN / WATCHED / HOT. The only Pressure fact the player ever sees
## (TI-003 §19); the raw score stays underneath.
func pressure_band(district_id: String, family: String) -> String:
	return _rules().pressure_band(pressure_score(district_id, family))

## Percentage points off a source action's success chance, BEFORE its clamp.
## Boost and Stick subtract this; Market has no criminal success roll to apply
## it to yet, so it accrues and displays Pressure without consuming a penalty.
func difficulty_penalty(district_id: String, family: String) -> float:
	return _rules().pressure_penalty(pressure_score(district_id, family))

## Every family's band in one district, for the Boost and Stick status cards.
##
## `loudest` is the worst band present, so a surface that wants one line rather
## than three has one without picking for itself.
func local_attention_summary(district_id: String) -> Dictionary:
	var rules: RefCounted = _rules()
	var families: Dictionary = {}
	var loudest_family := ""
	var loudest_score: float = -1.0
	for family_key in rules.PRESSURE_FAMILIES:
		var family := str(family_key)
		var score: float = pressure_score(district_id, family)
		families[family] = {
			"band": rules.pressure_band(score),
			"penalty": rules.pressure_penalty(score),
			"steps": rules.pressure_steps(score),
		}
		if score > loudest_score:
			loudest_score = score
			loudest_family = family
	return {
		"district_id": district_id,
		"families": families,
		"loudest_family": loudest_family,
		"loudest_band": rules.pressure_band(maxf(0.0, loudest_score)),
	}

## Add Pressure to a district/family, and schedule its bleed.
##
## `cause_id` is the dedupe identity for the bleed rows this schedules. A Cause
## that adds Pressure once can only ever schedule one bleed per destination, so
## a reload cannot double-apply it (TI-003 §8: "Cause + destination identities
## prevent duplicate bleed after reload").
##
## The exactly-once guard on the GAIN itself is the caller's receipt — this
## function is not idempotent and must not be, because Market calls it several
## times a day on purpose.
func add_pressure(district_id: String, family: String, amount: float,
		cause_id: String = "") -> float:
	if district_id.is_empty() or family.is_empty() or amount <= 0.0:
		return 0.0
	var rules: RefCounted = _rules()
	var row: Dictionary = pressure_row(district_id, family)
	var before: float = float(row.get("score", 0.0))
	row["score"] = clampf(before + amount, rules.PRESSURE_MIN, rules.PRESSURE_MAX)
	row["last_gain_day"] = int(gs.day)
	# FS-003 §6: "A new direct or bleed gain resets that family's quiet count."
	row["quiet_days"] = 0
	_schedule_bleed(district_id, family, amount, cause_id)
	return float(row["score"]) - before

## Market's metered gain, TI-003 §8: +0.25 per criminal sale, capped at +1.0 per
## district per family per day.
##
## The cap is stored on the row rather than counted in memory because it has to
## survive a reload — regression #19 is "Market exceeds its +1/day Pressure cap",
## and a counter that resets on load is exactly how that happens.
func add_market_pressure(district_id: String) -> float:
	var rules: RefCounted = _rules()
	var row: Dictionary = pressure_row(district_id, rules.FAMILY_MARKET)
	var today: int = int(gs.day)
	if int(row.get("market_gain_day", -1)) != today:
		row["market_gain_day"] = today
		row["market_gain_today"] = 0.0
	var used: float = float(row.get("market_gain_today", 0.0))
	var room: float = rules.PRESSURE_MARKET_DAILY_CAP - used
	if room <= 0.0:
		return 0.0
	var amount: float = minf(rules.PRESSURE_MARKET_SALE, room)
	# A market sale has no Cause of its own, so the bleed identity is the
	# district and the day. That is enough: the same district can only schedule
	# one market bleed per day, which is what dedupe has to guarantee.
	var applied: float = add_pressure(district_id, rules.FAMILY_MARKET, amount,
		"market:%s:%d" % [district_id, today])
	row["market_gain_today"] = used + amount
	return applied

## PRESS-D1 (0.4.0 PR D): the same per-family daily cap `add_market_pressure`
## above pioneered, generalised for Boost and Stick instead of duplicated —
## Market's own function and its own cap stay untouched (PRESS-D2: "nothing
## else in the Pressure system moves"), this is purely additive. Unlike a
## market sale, a Boost/Stick gain already carries its own `cause_id` from
## the caller (the lift or the robbery that caused it), so the day-tracked
## row field is keyed by FAMILY rather than assumed to be Market's alone —
## `pressure_row(district_id, family)` already returns a row scoped to that
## family, so `"capped_gain_day"/"capped_gain_today"` cannot collide between
## families sharing a district the way a flat field name would risk.
func add_capped_pressure(district_id: String, family: String, amount: float,
		daily_cap: float, cause_id: String = "") -> float:
	if amount <= 0.0:
		return 0.0
	var row: Dictionary = pressure_row(district_id, family)
	var today: int = int(gs.day)
	if int(row.get("capped_gain_day", -1)) != today:
		row["capped_gain_day"] = today
		row["capped_gain_today"] = 0.0
	var used: float = float(row.get("capped_gain_today", 0.0))
	var room: float = daily_cap - used
	if room <= 0.0:
		return 0.0
	var capped_amount: float = minf(amount, room)
	var applied: float = add_pressure(district_id, family, capped_amount, cause_id)
	row["capped_gain_today"] = used + capped_amount
	return applied

## Queue 50% of a NEW gain into each adjacent district for tomorrow.
##
## Never the stored score. FS-003 §6 is explicit: "Bleed uses the new gain from
## the cause. The entire stored score never copies outward again." Bleeding the
## score would compound — Spenard's 4 would put 2 into Downtown, whose 2 would
## put 1 back into Spenard the day after, forever.
func _schedule_bleed(district_id: String, family: String, amount: float,
		cause_id: String) -> void:
	var rules: RefCounted = _rules()
	var bled: float = amount * rules.PRESSURE_BLEED_FRACTION
	if bled <= 0.0:
		return
	var due: int = int(gs.day) + 1
	for neighbour_key in rules.adjacent_districts(district_id):
		var neighbour := str(neighbour_key)
		var bleed_id := "%s|%s|%s|%d" % [cause_id, neighbour, family, int(gs.day)]
		var duplicate := false
		for existing in gs.pressure_bleed_pending:
			if str((existing as Dictionary).get("bleed_id", "")) == bleed_id:
				duplicate = true
				break
		if duplicate:
			continue
		gs.pressure_bleed_pending.append({
			"bleed_id": bleed_id,
			"cause_id": cause_id,
			"source_district_id": district_id,
			"district_id": neighbour,
			"family": family,
			"amount": bled,
			"due_day": due,
		})

## Apply every bleed row that has come due. Runs post-increment, so `today` is
## the new day and a row scheduled yesterday lands now — never on the day the
## gain happened (TI-003 regression #17).
##
## A bled gain does NOT schedule a bleed of its own: it is applied to the row
## directly rather than through `add_pressure`, which is what stops the ping-pong
## described on `_schedule_bleed`. It DOES reset the destination's quiet count,
## because FS-003 §6 names a bled gain alongside a direct one.
func apply_pressure_bleed(today: int) -> int:
	var rules: RefCounted = _rules()
	var applied: int = 0
	var still_pending: Array = []
	for entry in gs.pressure_bleed_pending:
		var pending: Dictionary = entry
		if today < int(pending.get("due_day", 0x7FFFFFFF)):
			still_pending.append(pending)
			continue
		var row: Dictionary = pressure_row(str(pending.get("district_id", "")),
			str(pending.get("family", "")))
		row["score"] = clampf(float(row.get("score", 0.0))
			+ float(pending.get("amount", 0.0)),
			rules.PRESSURE_MIN, rules.PRESSURE_MAX)
		row["last_gain_day"] = today
		row["quiet_days"] = 0
		applied += 1
	gs.pressure_bleed_pending = still_pending
	return applied

## FS-003 §6's recovery, at FS-003.13's rates: every quiet day takes points off,
## and a district in the HOT band sheds them faster than one lower down.
##
## Runs post-increment on day `today`, so the day that just ended is `today - 1`.
## A row whose last gain was on or after that day was not quiet, and its counter
## resets. Bleed runs BEFORE this (TI-003 §9), so a bleed landing this morning
## has already stamped `last_gain_day = today` and correctly reads as not quiet.
##
## The grace check stays even though `PRESSURE_QUIET_GRACE_DAYS` is now 0. With
## a grace of zero the `continue` is unreachable, which is the point: the hold
## behaviour is one constant away rather than one commit away, and the quiet
## counter it reads is still what the Pressure card shows.
func apply_pressure_recovery(today: int) -> int:
	var rules: RefCounted = _rules()
	var recovered: int = 0
	for district_key in gs.district_pressure.keys():
		var by_family: Dictionary = gs.district_pressure[district_key]
		for family_key in by_family.keys():
			var row: Dictionary = by_family[family_key]
			if int(row.get("last_gain_day", -1)) >= today - 1:
				row["quiet_days"] = 0
				continue
			var quiet: int = int(row.get("quiet_days", 0)) + 1
			row["quiet_days"] = quiet
			if quiet <= rules.PRESSURE_QUIET_GRACE_DAYS:
				continue
			var before: float = float(row.get("score", 0.0))
			if before <= rules.PRESSURE_MIN:
				continue
			row["score"] = maxf(rules.PRESSURE_MIN,
				before - rules.quiet_recovery(before))
			recovered += 1
	return recovered

# --- Gain-side recovery: the HOT escape lever (v0.1.0) ---------------------
#
# `apply_pressure_recovery` above only ever fires on a day with no gain on it,
# which means an aggressive player has no counterplay at all: every day they
# work is a day that cannot recover, so HOT becomes the resting state and the
# only exit is to stop playing. This is the other half — a CLEAN outcome pays
# pressure back at settlement.
#
# Credits are BANKED as actions resolve and DRAINED at POST_SETTLE rather than
# applied on the spot, for two reasons. The day's gains all land first, so a
# clean day nets out exactly once instead of racing the bleed; and the drain is
# one declared lifecycle step that a trace can assert, rather than a subtraction
# scattered across three source systems.

## Take Pressure OFF a district/family. The inverse of `add_pressure`, and
## deliberately not a negative call into it: a recovery must not stamp
## `last_gain_day`, must not reset `quiet_days`, and must not schedule a bleed.
## Paying pressure back is not a gain, and a day you worked is not a quiet day.
func recover_pressure(district_id: String, family: String, amount: float) -> float:
	if district_id.is_empty() or family.is_empty() or amount <= 0.0:
		return 0.0
	var by_family: Variant = gs.district_pressure.get(district_id)
	if not (by_family is Dictionary):
		return 0.0
	var row: Variant = (by_family as Dictionary).get(family)
	if not (row is Dictionary):
		return 0.0
	var before: float = float((row as Dictionary).get("score", 0.0))
	if before <= _rules().PRESSURE_MIN:
		return 0.0
	(row as Dictionary)["score"] = maxf(_rules().PRESSURE_MIN, before - amount)
	return before - float((row as Dictionary)["score"])

## Bank what one resolved outcome has earned back. Returns the credited amount,
## which is 0.0 for every tier but `clean` — see `PRESSURE_RECOVERY_BY_TIER`.
##
## Called by the source systems at the same point they call `add_pressure`, so
## the gain and the credit are decided from the same resolved tier and cannot
## drift apart.
func credit_clean_outcome(district_id: String, family: String,
		tier_name: String) -> float:
	if district_id.is_empty() or family.is_empty():
		return 0.0
	var amount: float = _rules().clean_recovery(tier_name)
	if amount <= 0.0:
		return 0.0
	if not gs.pressure_clean_credits.has(district_id):
		gs.pressure_clean_credits[district_id] = {}
	var by_family: Dictionary = gs.pressure_clean_credits[district_id]
	by_family[family] = float(by_family.get(family, 0.0)) + amount
	return amount

## Pay every banked credit and empty the ledger. Runs at POST_SETTLE, after the
## day's gains and before the clock moves.
##
## Returns the number of rows it moved, for the same reason `apply_pressure_bleed`
## does: the ordering tests want a count, and nothing in the game reads it.
func apply_clean_recovery(_ended_day: int) -> int:
	var recovered: int = 0
	for district_key in gs.pressure_clean_credits.keys():
		var by_family: Variant = gs.pressure_clean_credits[district_key]
		if not (by_family is Dictionary):
			continue
		for family_key in (by_family as Dictionary).keys():
			var amount: float = float((by_family as Dictionary)[family_key])
			if recover_pressure(str(district_key), str(family_key), amount) > 0.0:
				recovered += 1
	# Cleared whether or not anything moved. A credit that found a district
	# already at the floor is spent, not owed — carrying it forward would let a
	# quiet week bank recovery against a future crime spree.
	gs.pressure_clean_credits = {}
	return recovered

# --- Financial Pressure rollover (TI-003 §17) ------------------------------

## Decay first. `max(0, financial_pressure - 1)`, every day, unconditionally.
func decay_financial_pressure() -> int:
	var rules: RefCounted = _rules()
	var before: int = int(gs.financial_pressure)
	gs.financial_pressure = maxi(0, before - rules.FINANCIAL_PRESSURE_DECAY)
	return before - int(gs.financial_pressure)

## Then fold, on what REMAINS after the decay.
##
## The ordering is on TI-003's regression list twice — #25 is folding before the
## decay, #26 is Exposure seeing morning Heat before the fold — so both are
## enforced by the lifecycle's declared phase order rather than by this function
## knowing when it runs.
##
## Goes through `HeatSystem.apply_direct`, which means it reaches the meter
## unscaled but still passes through the one owner: Deshawn does not damp it
## (this is not heat a crime generated), and nothing else can write Heat.
func fold_financial_pressure() -> float:
	var rules: RefCounted = _rules()
	if int(gs.financial_pressure) < rules.FINANCIAL_PRESSURE_FOLD_AT:
		return 0.0
	var heat: Object = gm.system("heat") if gm != null else null
	if heat == null:
		return 0.0
	var applied: float = heat.apply_direct(rules.FINANCIAL_PRESSURE_FOLD_HEAT,
		{"source_id": "financial_pressure"})
	if applied > 0.0:
		gs.log_activity("The paper around a recent formal payment started drawing "
			+ "the wrong attention. Heat +%.1f." % applied, Color(0.882, 0.651, 0.227))
	return applied

## Read-only view of the queue, for tests and later slices. Duplicated so a
## caller cannot reorder the real one by sorting what it was handed.
func queue_snapshot() -> Array:
	return gs.consequence_queue.duplicate(true)

extends RefCounted
## RetaliationSystem — the delayed answer.
##
## TI-003 §§15-16. Everything else in the consequence layer happens inside the
## dispatch that caused it. This is the one thing that waits: you rob a register
## on Tuesday, and on Thursday the people who own it find you standing in the
## same district.
##
## ## Why it is a system rather than an adapter on Stick
##
## Stick creates the debt; it does not collect it. By the time a retaliation
## surfaces the robbery is two days gone, the chain that carries it names
## `retaliation` as its `action_id`, and what resolves it is a completely
## different table from the one that resolved the robbery. Hanging that off
## `stickup.gd` would put two unrelated encounters in one file and would make the
## Stick system the owner of a queue it never reads.
##
## It registers with `ConsequenceEngine` through the same runtime source-adapter
## registry Boost uses. "Source adapter" there really means *whoever resolves
## this chain*, and a delayed consequence resolves itself.
##
## ## Three gates, and why the queue can go cold
##
## TI-003 §15 requires all four of these before a queued row may surface: the
## blocking slot is free, the day is inside the trigger/expiry window, the daily
## delayed allowance is unspent, and **the player is standing in the district**.
##
## That last one is the design, not a limitation. FS-003 §9: "Avoiding the source
## district for several days is a valid strategic retreat." A player who robs the
## Spenard Chevron and then works Downtown for a week never meets anybody — the
## entry expires on cause day + 5 and clears without a scene. The player is never
## told this; they learn it by noticing that the trouble stopped when they stopped
## going back. PX-003 §8 is explicit that the expiry stays hidden.
##
## ## Cash loss reads the Dirty bucket, and only the Dirty bucket
##
## TI-003 §16 and regression #39. They take what you took. A player whose money
## came from a job keeps it, which is the provenance split finally doing
## something a player can feel rather than a number the wallet keeps for later.
##
## ## No arrest, ever
##
## Regression #40. This is street justice, and police are not part of it. The
## chain has no booking stage and no arrest gate — its Heat can make a LATER
## source action's arrest gate bite, through the ordinary shared meter, and that
## is the only connection.

const RULES := preload("res://data/consequence_rules.gd")

const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)
const GREEN := Color(0.451, 0.722, 0.404)

var gs: Node
var gm: Node
var rng: Node

func setup(game_state: Node, manager: Node, rng_manager: Node) -> void:
	gs = game_state
	gm = manager
	rng = rng_manager

## No action of its own. A retaliation is never something the player asks for;
## the responses to one go through the engine's `resolve_consequence_choice`.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "Retaliation takes no actions."}

func _rules() -> RefCounted:
	return RULES.new()

func _engine() -> Object:
	return gm.system("consequence") if gm != null else null

func _wallet() -> Object:
	return gm.system("wallet") if gm != null else null

func _heat() -> Object:
	return gm.system("heat") if gm != null else null

# --- scheduling -------------------------------------------------------------

## Roll for a delayed answer to one robbery, and queue it if it lands.
##
## Called by `stickup.gd` after its tier resolves. Returns the queue row that was
## created, or an empty Dictionary — a caller that wants to say "somebody made a
## call before you cleared out" reads the return rather than re-deriving whether
## anything happened.
##
## TI-003 §15's key: `retaliation:schedule:<cause_id>:<actor_id>`. Keyed on the
## Cause, so a reload cannot reroll it — the same night always produces the same
## answer, which is what makes the whole queue reproducible from a save.
func schedule(target_id: String, tier_name: String, cause_id: String,
		district_id: String) -> Dictionary:
	var engine: Object = _engine()
	if engine == null or cause_id.is_empty():
		return {}
	var rules: RefCounted = _rules()
	var chance: float = rules.retaliation_chance(target_id, tier_name)
	if chance <= 0.0:
		return {}
	var actor_id: String = rules.retaliation_actor_id(target_id)
	if actor_id.is_empty():
		return {}
	# TI-003 §15's dedupe half that lives on the Cause. The queue holds the
	# other half; both are checked, because a row can be removed from the queue
	# (arrest suppression) while the Cause still remembers it was scheduled.
	if engine.has_scheduled_actor(cause_id, actor_id):
		return {}
	var roll: float = rng.seeded_random(gs.run_seed,
		"retaliation:schedule:%s:%s" % [cause_id, actor_id])
	if roll >= chance:
		return {}

	var cause_day: int = int(gs.day)
	var row: Dictionary = {
		"queue_id": "retaliation:%s:%s" % [actor_id, cause_id],
		"cause_id": cause_id,
		"actor_id": actor_id,
		"actor_label": rules.retaliation_actor_label(target_id),
		"source_family": "stick",
		"source_target_id": target_id,
		"district_id": district_id,
		"created_day": cause_day,
		"trigger_day": cause_day + rules.RETALIATION_TRIGGER_DELAY,
		"expires_end_day": cause_day + rules.RETALIATION_EXPIRY_DELAY,
		"encounter_definition_id": rules.RETALIATION_DEFINITION,
		"status": "pending",
	}
	var queued: Dictionary = engine.enqueue(row)
	if not bool(queued.get("ok", false)):
		return {}
	# PX-003 §8: the player gets a narrative tail, never a countdown. The line
	# fires only when a row was genuinely created, so it is a real signal rather
	# than atmosphere.
	gs.log_activity("Somebody made a call before you cleared out.", AMBER)
	return row

# --- ambient signals (PX-003 §8, FS-003.13 Task 5) -------------------------

## The one ambient warning today's feed is allowed to carry, if anything is live
## here. Returns the number of lines written, which is 0 or 1.
##
## ## Why this exists at all
##
## Leaving the district is the only counterplay a queued retaliation has, and
## before this the queue was completely silent until it surfaced. FS-003.12
## measured what that produces: three long-run profiles, eleven threats between
## them, zero avoided. Not because avoidance was hard — because nothing in the
## game ever suggested there was something to avoid.
##
## ## What it may and may not say
##
## PX-003 §8 keeps the window hidden, and the lines are written so that hiding it
## is structural rather than a matter of care. Nothing here reads `trigger_day`
## or `expires_end_day` for anything except deciding whether a row is still live,
## the copy never varies with how much time is left, and the line is chosen off
## the row and the day rather than off the row's age. A warning that intensified
## as the window closed would be a countdown with adjectives.
##
## ## Presence, and only presence
##
## Same gate the surfacing arbitration uses (TI-003 regression #29): a row warns
## only in ITS district. Walk away and the feed goes quiet the next morning,
## which is the whole lesson this signal exists to teach.
func push_ambient_warnings(today: int) -> int:
	if int(gs.consequence_flags.get("retaliation_last_ambient_day", -1)) == today:
		return 0
	var rules: RefCounted = _rules()
	var row: Dictionary = _ambient_row(today)
	if row.is_empty():
		return 0
	var lines: Array = rules.RETALIATION_AMBIENT_LINES
	# Seeded on (row, day), never on a counter: a reload has to reproduce the
	# same line, and `randi()` is banned outright in this build anyway.
	var roll: float = rng.seeded_random(gs.run_seed,
		"retaliation:ambient:%s:%d" % [str(row.get("queue_id", "")), today])
	var index: int = clampi(int(roll * float(lines.size())), 0, lines.size() - 1)
	gs.log_activity(str(lines[index]), AMBER)
	row["last_warned_day"] = today
	gs.consequence_flags["retaliation_last_ambient_day"] = today
	return 1

## The row today's warning speaks for, or empty.
##
## Oldest first, by the same (`trigger_day`, `created_sequence`) order the
## surfacing arbitration uses — so the warning and the encounter are talking
## about the same threat rather than two different ones.
func _ambient_row(today: int) -> Dictionary:
	var rules: RefCounted = _rules()
	var candidates: Array = []
	for entry in gs.consequence_queue:
		var candidate: Dictionary = entry
		# `pending` is the whole liveness test: a surfaced or resolved row has
		# already been answered, and an expired one is over.
		if str(candidate.get("status", "pending")) != "pending":
			continue
		if str(candidate.get("district_id", "")) != str(gs.current_district_id):
			continue
		if today < int(candidate.get("created_day", 0)) + rules.RETALIATION_AMBIENT_FROM_DAY:
			continue
		if today > int(candidate.get("expires_end_day", 0x7FFFFFFF)):
			continue
		candidates.append(candidate)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_day: int = int(a.get("trigger_day", 0))
		var b_day: int = int(b.get("trigger_day", 0))
		if a_day != b_day:
			return a_day < b_day
		return int(a.get("created_sequence", 0)) < int(b.get("created_sequence", 0)))
	return candidates[0]

## The one-time callback for the first threat this run ever avoids into expiry.
##
## Called by the engine with the rows it just expired, because the engine owns
## the queue and expiry is its transition to make. Returns true when a message
## was pushed, which is at most once per run.
##
## Once per RUN rather than once per threat, and the flag persists: the callback
## exists to teach that leaving the district works, and a lesson that repeats
## every time it applies stops being a lesson and becomes a notification. The
## flag going into `consequence_flags` is what makes "already learned" survive a
## reload — without it, loading a save from before the first expiry would teach
## it again.
func note_expiries(expired_rows: Array) -> bool:
	if expired_rows.is_empty():
		return false
	if bool(gs.consequence_flags.get("retaliation_first_expiry_seen", false)):
		return false
	var phone: Object = gm.system("phone") if gm != null else null
	if phone == null:
		return false
	var rules: RefCounted = _rules()
	var district_id := str((expired_rows[0] as Dictionary).get("district_id",
		gs.current_district_id))
	var prose := str((phone.AREA_PROSE_NAMES as Dictionary).get(district_id, "the block"))
	phone.push_message(rules.RETALIATION_EXPIRY_CALLBACK_FROM % prose,
		rules.RETALIATION_EXPIRY_CALLBACK % prose)
	# Set AFTER the push, so a push that could not happen does not burn the flag.
	gs.consequence_flags["retaliation_first_expiry_seen"] = true
	return true

# --- activation -------------------------------------------------------------

## Open the blocking encounter for one queued row.
##
## Called by the engine once IT has decided a row may surface — the arbitration
## (one active chain, one delayed consequence per day, the right district, inside
## the window) is TI-003 §15's and belongs to the queue's owner. This builds the
## chain and nothing else.
func open_encounter(row: Dictionary) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var rules: RefCounted = _rules()
	var resolver: Object = gm.system("outcome_resolver")
	var actor_id := str(row.get("actor_id", ""))
	var cause_id := str(row.get("cause_id", ""))

	# The odds are snapshotted here, at the moment the decision opens, for the
	# same reason Caught's are: the player's attributes can move between seeing
	# the choice and making it, and the numbers they decided on are the numbers
	# that have to come back after a reload.
	var shown: Dictionary = {}
	var inputs: Dictionary = {}
	for choice_key in rules.RETALIATION_CHOICES:
		var choice_id := str(choice_key)
		if rules.retaliation_is_deterministic(choice_id):
			continue
		var action_type: String = rules.retaliation_resolver_for(choice_id)
		var attribute: String = resolver.attribute_for(action_type)
		# The RAW stored attribute, never `compat()` — see the resolver's header.
		var raw: int = int(gs.attributes.get(attribute, 0))
		inputs[choice_id] = {"attribute": attribute, "raw": raw}
		shown[choice_id] = resolver.success_probability(action_type,
			rules.retaliation_base_chance(choice_id), raw, 0)

	return engine.open_chain(engine.KIND_RETALIATION, {
		"cause_id": cause_id,
		"district_id": str(row.get("district_id", gs.current_district_id)),
		"return_route": "HOME",
		# A delayed consequence costs no source slot. The robbery that caused it
		# paid its slot two days ago; TI-003 §26's "one source action pays its
		# normal time cost once" was satisfied then.
		"source_slots": 0,
		"source": {
			"family": "stick",
			# Resolved by THIS system rather than by Stick — see the header.
			"action_id": "retaliation",
			"target_id": str(row.get("source_target_id", "")),
			"target_name": str(row.get("actor_label", "")),
			"target_tier": 0,
			"actor_id": actor_id,
			"actor_label": str(row.get("actor_label", "")),
			"queue_id": str(row.get("queue_id", "")),
			"source_day": int(row.get("created_day", gs.day)),
			"pre_encounter_heat": float(gs.heat),
			"contested_take": 0,
		},
		"decision": {
			"definition_id": rules.RETALIATION_DEFINITION,
			"allowed_choices": rules.RETALIATION_CHOICES.duplicate(),
			"deterministic_choices": rules.RETALIATION_DETERMINISTIC.duplicate(),
			"resolver_inputs": inputs,
			"shown_probabilities": shown,
		},
	})

# --- resolution -------------------------------------------------------------

## TI-003 §16's effect tables, applied in order, each behind its own receipt.
##
## Called by the engine after it has revalidated identity, stage and the allowed
## choice — the same contract Boost's Caught resolution runs under.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var rules: RefCounted = _rules()
	var source: Dictionary = chain.get("source", {})
	var cause_id := str(chain.get("cause_id", ""))
	var actor_id := str(source.get("actor_id", ""))
	var district_id := str(chain.get("district_id", gs.current_district_id))
	var receipt_prefix := "retaliation:%s" % actor_id

	# 1. Resolve the tier, or take Yield's single authored row.
	var tier_name: String = "deterministic"
	if not rules.retaliation_is_deterministic(choice_id):
		var action_type: String = rules.retaliation_resolver_for(choice_id)
		var resolver: Object = gm.system("outcome_resolver")
		var attribute: String = resolver.attribute_for(action_type)
		var raw: int = int(gs.attributes.get(attribute, 0))
		var outcome: Dictionary = resolver.resolve_action(action_type,
			rules.retaliation_base_chance(choice_id), raw, gs.run_seed,
			"retaliation:%s:%s:%s:outcome" % [cause_id, actor_id, choice_id])
		tier_name = str(outcome["tier"])

	var effects: Dictionary = rules.retaliation_effects(choice_id, tier_name)
	var result: Dictionary = {
		"choice_id": choice_id, "tier": tier_name,
		"cash": 0, "health": 0, "heat": 0.0, "pressure": 0.0,
		# Regression #40, stated in the result the screen renders rather than
		# only in the absence of a code path.
		"arrested": false,
		"actor_label": str(source.get("actor_label", "")),
	}

	# 2. Cash, from the Dirty bucket only. Computed against the live balance so a
	#    player who spent the take between the robbery and the reckoning has
	#    genuinely less to lose.
	var wallet: Object = _wallet()
	var loss: int = rules.retaliation_cash_loss(choice_id, tier_name,
		int(wallet.dirty_balance()))
	if loss > 0 and engine.record_receipt(cause_id, "%s:cash" % receipt_prefix):
		# ROUTINE_DIRTY_FIRST drains dirty before clean, and `loss` is already
		# bounded by the dirty balance — so clean is unreachable by arithmetic
		# as well as by policy. Regression #39 twice over.
		wallet.spend(loss, wallet.ROUTINE_DIRTY_FIRST,
			{"source_id": "retaliation_take", "cause_id": cause_id})
		result["cash"] = -loss

	# 3. Health. A flat authored loss, not a band — §16 gives one number per row,
	#    so nothing rolls and the `:injury` key TI-003 reserves stays unused.
	var damage: int = int(effects.get("health", 0))
	if damage > 0 and engine.record_receipt(cause_id, "%s:injury" % receipt_prefix):
		gs.health = clampi(int(gs.health) - damage, 0, int(gs.health_max))
		result["health"] = -damage

	# 4. Heat, through the one owner, under the Stick family — this is the same
	#    kind of trouble the robbery was, in the same district.
	var raw_heat: float = float(effects.get("heat", 0.0))
	if raw_heat > 0.0 and engine.record_receipt(cause_id, "%s:heat" % receipt_prefix):
		result["heat"] = _heat().apply_gain(raw_heat, _heat().FAMILY_STICK,
			district_id, {"source_id": "retaliation"})

	# 5. District Pressure, once. A fight in the street is exactly the kind of
	#    thing that makes a block start recognising you.
	var pressure: float = float(effects.get("pressure", 0.0))
	if pressure > 0.0 and engine.record_receipt(cause_id, "%s:pressure" % receipt_prefix):
		engine.add_pressure(district_id, "stick", pressure,
			"%s:%s" % [cause_id, actor_id])
		result["pressure"] = pressure

	# 6. What the block saw. Reuses the resolver's authored footprint for the
	#    shape that was rolled, the same way Caught does.
	if not rules.retaliation_is_deterministic(choice_id) \
			and engine.record_receipt(cause_id, "%s:observation" % receipt_prefix):
		var resolver_obs: Object = gm.system("outcome_resolver")
		resolver_obs.broadcast_outcome(rules.retaliation_resolver_for(choice_id),
			tier_name, district_id)

	# 7. Retire the queue row. The encounter happened; it cannot happen again.
	_settle_queue_row(str(source.get("queue_id", "")), cause_id, actor_id)

	# 8. Store the result and move to the result stage. No booking: regression
	#    #40 is "Retaliation adds an arrest transition", and the absence is
	#    structural — nothing here can reach ArrestSystem.
	var decision: Dictionary = chain.get("decision", {})
	decision["resolved_tier"] = tier_name
	decision["result"] = result
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)

	gs.log_activity(_result_line(source, choice_id, tier_name, result),
		_tone(tier_name, choice_id))
	return {"ok": true, "tier": tier_name, "arrested": false}

## Mark a surfaced row resolved, by id and then by (cause, actor).
##
## Two lookups because the queue_id is convenience and the pair is the contract:
## a row loaded from an older save might carry a differently-formed queue_id, and
## TI-003 §15's identity is `(actor_id, cause_id)`.
func _settle_queue_row(queue_id: String, cause_id: String, actor_id: String) -> void:
	for entry in gs.consequence_queue:
		var row: Dictionary = entry
		var matches_id: bool = not queue_id.is_empty() \
			and str(row.get("queue_id", "")) == queue_id
		var matches_pair: bool = str(row.get("cause_id", "")) == cause_id \
			and str(row.get("actor_id", "")) == actor_id
		if matches_id or matches_pair:
			row["status"] = "resolved"

func _result_line(source: Dictionary, choice_id: String, tier_name: String,
		result: Dictionary) -> String:
	var who := str(source.get("actor_label", "Somebody"))
	var taken: int = -int(result.get("cash", 0))
	if choice_id == "yield":
		if taken > 0:
			return "%s took $%d and left it there." % [who, taken]
		return "%s found nothing on you and left it there." % who
	if tier_name in ["clean", "messy"]:
		return "%s came for it. You did not give it up." % who
	if taken > 0:
		return "%s came for it and took $%d." % [who, taken]
	return "%s came for it. You had nothing left to give." % who

func _tone(tier_name: String, choice_id: String) -> Color:
	if choice_id == "yield":
		return AMBER
	match tier_name:
		"clean": return GREEN
		"messy": return AMBER
	return RED

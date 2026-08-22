extends RefCounted
## Boost — lifting stock, and the ladder that turns it into a trade.
##
## Ported from game-core.js BOOST_TARGETS, boostChance, resolveBoostAttempt,
## updateBoostTier and boostFenceRate.
##
## Canon's chance formula:
##   skill  = tier 1|2 → (combat + intelligence) / 2 · tier 3 → (intelligence + charisma) / 2
##   base   = tier 1 → 0.80 · tier 2 → 0.55 · tier 3 → 0.40
##   chance = clamp(base + (skill - 2) * 0.10 + windowBonus + districtDelta, 0.10, 0.95)
##
## Attributes are LIVE as of Phase 5c; districtDelta is still 0.
##
## They were pinned at `ATTRIBUTE_DEFAULTS` (all 1), which was the wrong number:
## canon blends `combatCompat` / `intelligenceCompat` / `charismaCompat`
## (game-core.js:2228-2230), the stored value offset onto the 1-5 scale. Skill
## was therefore 1 where canon has 2, making `(skill - 2) * 0.10` read -0.10
## instead of 0 — every lift 10 points harder than canon from Phase 3d until
## Phase 5c. At the fresh-run default tier 1 now reads 0.80 and tier 2 reads
## 0.55, or 0.75 inside its window.
##
## Tier 2 targets each have a window slot worth +0.20. Canon only reveals a
## window once you have hit that target, which is what ASK_BOOST_WINDOW is for;
## here the window is shown outright, because the alternative is a hidden
## modifier the player cannot act on and no surface to learn it from.
##
## Tier 3 needs technique 13 AND field-assignable crew, so it is unreachable
## until crew lands in 3e. Its merchandise-and-fence loop is written and tested
## but has no way to trigger yet — that is canon's gate, not an omission.
##
## ## Why this is still a binary roll after Build 5e
##
## Every other risky surface moved onto `outcome_resolver` in 5e. This one did
## not, and that is the oracle's call rather than an unfinished migration:
## canon's `resolveBoostAttempt` (game-core.js:2248) is a plain `roll < chance`
## and has stayed one. Getting caught is not a tier in canon, it is a SCENE —
## the failure hands off to the consequence-encounter engine with the take still
## in play, and THAT resolves on the tier pipeline as `confrontation`, `escape`
## or `negotiation`. The tiers a blown lift deserves already exist in
## OUTCOME_SHAPES; what is missing is the encounter engine that reaches them.
##
## Tiering the lift itself here would invent a shape canon does not have, in a
## shipped surface, with no oracle left to check it against. When the encounter
## engine lands, this becomes a binary roll into three tiered scenes — which is
## canon, and is a different change from the one 5e was.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node
var rng: Node
var time_system: RefCounted
var gm: Node
var attributes: RefCounted

func setup(game_state: Node, rng_manager: Node, time: RefCounted, manager: Node,
		attribute_system: RefCounted) -> void:
	gs = game_state
	rng = rng_manager
	time_system = time
	gm = manager
	attributes = attribute_system

## Heat this lift generated. Was a character-for-character duplicate of
## stickup.gd's helper; both now route through the one owner (TI-003 §7), which
## is what keeps Deshawn applying exactly once.
func _apply_heat(amount: float) -> float:
	var heat: Object = gm.system("heat") if gm != null else null
	if heat == null:
		return 0.0
	return heat.apply_gain(amount, heat.FAMILY_BOOST, gs.current_district_id,
		{"source_id": "boost"})

## The shared cash owner. Boost take and the fence payout are both dirty.
func _wallet() -> Object:
	return gm.system("wallet")

## The shared heat owner.
func _heat() -> Object:
	return gm.system("heat")

func can_handle(action: String) -> bool:
	return action in ["boost", "fence_goods"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"boost":
			return _run(str(payload.get("target_id", "")))
		"fence_goods":
			return _fence()
	return {"ok": false, "reason": "Unknown boost action."}

func visible_targets() -> Array:
	var out: Array = []
	for t in gs.boost_targets:
		if str(t["area"]) != gs.current_district_id:
			continue
		if int(t["tier"]) > gs.boost_tier:
			continue
		out.append(t)
	return out

## Canon boostChance. Tiers 1 and 2 blend combat+intelligence; tier 3 swaps
## combat for charisma, because a tier-3 lift is talked through, not walked out.
func chance_for(target: Dictionary) -> float:
	var tier: int = int(target["tier"])
	var base: float = 0.80 if tier == 1 else (0.55 if tier == 2 else 0.40)
	var skill: float = float(attributes.compat("intelligence") + attributes.compat(
		"charisma" if tier == 3 else "combat")) / 2.0
	var window_bonus: float = 0.20 if tier == 2 and int(target["window"]) == gs.time_slots_today else 0.0
	# TI-003 §8: "Source systems subtract the family penalty before their
	# existing final clamp." Inside the clamp, not after it — a WATCHED district
	# should be able to push a marginal lift down to the floor, not below it.
	#
	# The penalty is 0.00 in a QUIET district, which every fresh run is, so this
	# term is invisible until the player has actually made a routine of it here.
	return clampf(base + (skill - 2.0) * 0.10 + window_bonus - _pressure_penalty(),
		0.10, 0.95)

## How much harder this district has become for Boost work specifically.
##
## Read at chance time rather than cached, because a lift and the Pressure it
## generates land in the same dispatch: the NEXT lift is the one that pays.
func _pressure_penalty() -> float:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return 0.0
	return engine.difficulty_penalty(gs.current_district_id, "boost")

func blocker(target_id: String) -> String:
	if gs.game_over:
		return "The run is over."
	var t: Dictionary = gs.boost_target_by_id(target_id)
	if t.is_empty():
		return "No such place."
	if str(t["area"]) != gs.current_district_id:
		return "Wrong part of town."
	if int(t["tier"]) > gs.boost_tier:
		return "You're not smooth enough yet."
	if int(gs.boost_daily_hits.get(target_id, -1)) == gs.day:
		return "You've already been in today."
	# TI-003 §5: "Boost owns ban semantics. The current source behavior is
	# persistent by target ID." FS-003 §5 says "the current Boost ban duration
	# used by the source system" — there was no ban system to inherit a duration
	# from, and TI-003 is the later and more specific ruling, so a ban is
	# permanent rather than timed. Named in the PR as a resolved ambiguity.
	if target_id in gs.boost_store_bans:
		return "They know your face in there now."
	return ""

func _run(target_id: String) -> Dictionary:
	var blocked := blocker(target_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var t: Dictionary = gs.boost_target_by_id(target_id)
	var tier: int = int(t["tier"])

	var key := "boost:%d:%d:%s" % [gs.day, gs.time_slots_today, target_id]
	var roll: float = rng.seeded_random(gs.run_seed, key)
	var success: bool = roll < chance_for(t)

	gs.boost_daily_hits[target_id] = gs.day

	var result: Dictionary
	if success:
		var band: Array = t["take"]
		var take: int = rng.seeded_int_range(gs.run_seed, key + ":take", int(band[0]), int(band[1]))
		gs.boost_technique += 1
		# Canon scales heat by tier: 0.5 · 1 · 2 (game-core.js:2260). Matched.
		#
		# The int signature above used to truncate canon's 0.5 to nothing, so
		# the call site rounded up to 1 and every tier-1 lift made DOUBLE the
		# heat canon does — on the surface a player uses earliest and most.
		# FS-003.1 froze that with an assertion naming it; this is the fix.
		_apply_heat(0.5 if tier == 1 else (1.0 if tier == 2 else 2.0))
		# FS-003 §6: a clean initial Boost success adds +0.5 Boost pressure. A
		# FAILED lift adds nothing here — it waits for the Caught encounter's
		# resolved tier, which is what makes a blown lift cost more local memory
		# than a clean one rather than double-charging for the same attempt.
		_add_district_pressure(gs.current_district_id, "boost",
			_rules().PRESSURE_BOOST_SUCCESS, "")
		# v0.1.0's HOT escape lever. FS-003 §6 calls this branch "a clean initial
		# Boost success" and that is the tier the credit is authored against, so
		# the success path banks CLEAN and the failed path banks nothing — the
		# blown lift's tier is decided later, by the Caught encounter.
		#
		# Banked, not applied: it is paid at POST_SETTLE, so the day's gains land
		# first. Net effect of a clean lift on this district is zero.
		_credit_clean_outcome(gs.current_district_id, "boost", "clean")
		if tier == 3:
			# Tier 3 comes out as merchandise, not cash. Slide fences it.
			gs.boost_merchandise += take
			gs.log_activity("%s lands. $%d in merchandise waiting for the fence." % [str(t["name"]), take], GREEN)
		else:
			_wallet().credit(take, _wallet().DIRTY, {"source_id": "boost_take"})
			gs.log_activity("Left %s with goods worth $%d." % [str(t["name"]), take], GREEN)
		result = {"ok": true, "success": true, "take": take, "tier": tier}
	else:
		# TI-003 §11: "The failed branch removes its current immediate terminal
		# Heat/log/time behavior because Caught now owns those consequence
		# effects."
		#
		# So no `_apply_heat(1.0)`, no empty-handed toast, and — the one that
		# matters most — no `advance_time`. The slot stays owed until the chain
		# reaches Continue, which is what stops a blown lift from costing the
		# player time before they have answered for it.
		#
		# The contested take is rolled HERE, off the existing `:take` key, so
		# the amount in dispute is the amount the lift would have produced and
		# a reload cannot reroll it (TI-003 regression #4).
		var band: Array = t["take"]
		var contested: int = rng.seeded_int_range(
			gs.run_seed, key + ":take", int(band[0]), int(band[1]))
		# Curtis hears about the attempt whether or not it worked, and exactly
		# once for the source action (TI-003 §11 step 9) — marked before the
		# handoff so a chain that never resolves still counted the activity.
		_mark_criminal_activity()
		var opened: Dictionary = _open_caught(t, tier, contested, key)
		if not bool(opened.get("ok", false)):
			return opened
		# No `_update_tier()` and no time advance: the lift is not over.
		return {"ok": true, "success": false, "take": 0, "tier": tier,
			"caught": true, "contested_take": contested,
			"cause_id": str(opened.get("cause_id", ""))}

	_mark_criminal_activity()
	_update_tier()
	time_system.handle("advance_time", {})
	return result

## Not loud enough to raise awareness on its own, but it is criminal activity,
## which is what stops the quiet streak from bleeding awareness down.
func _mark_criminal_activity() -> void:
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis != null:
		curtis.mark_criminal_activity()

# --- the Caught adapter (TI-003 §§10-12) -----------------------------------
#
# Boost is a consequence SOURCE, so it owns the source-specific half: what the
# contested take is worth, what happens to it, and who gets banned. The engine
# owns the chain, the stages and the receipts.
#
# Registered by name (`"boost"`) in GameManager on every boot. Nothing here is
# ever serialised — a chain names this adapter by String and the registry
# resolves it after a load (TI-003 §1, §26).

const RULES := preload("res://data/consequence_rules.gd")

func _rules() -> RefCounted:
	return RULES.new()

func _engine() -> Object:
	return gm.system("consequence") if gm != null else null

## TI-003 §11 steps 5-12. Snapshot everything the decision needs, then hand the
## blocking slot to the engine.
##
## The odds are snapshotted HERE rather than computed by the screen, because
## §5 requires a reload to reproduce the same choice surface — and the player's
## attributes can change between the decision opening and the decision being
## made (a crew member leaves, an injury lands). The numbers they decided on are
## the numbers that must come back.
func _open_caught(target: Dictionary, tier: int, contested: int,
		source_key: String) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var rules: RefCounted = _rules()
	var resolver: Object = gm.system("outcome_resolver")

	var shown: Dictionary = {}
	var inputs: Dictionary = {}
	# The arrest warnings, snapshotted with everything else the decision shows.
	# They read the SAME pre-encounter Heat the gate itself will read, so the
	# warning cannot promise one thing and the gate deliver another.
	var risks: Dictionary = {}
	for choice_key in rules.CAUGHT_CHOICES:
		risks[str(choice_key)] = rules.caught_arrest_risk(str(choice_key), tier,
			float(gs.heat))
	for choice_id in rules.CAUGHT_CHOICES:
		if rules.is_deterministic(str(choice_id)):
			continue
		var action_type: String = rules.resolver_for(str(choice_id))
		var attribute: String = resolver.attribute_for(action_type)
		# The RAW stored attribute, not the compatibility offset — see the
		# outcome resolver's header. Feeding compat() here would shift every
		# advantage and immunity threshold down a level.
		var raw: int = int(gs.attributes.get(attribute, 0))
		inputs[choice_id] = {"attribute": attribute, "raw": raw}
		shown[choice_id] = resolver.success_probability(
			action_type, rules.base_chance(tier, str(choice_id)), raw, 0)

	return engine.open_chain(engine.KIND_BOOST_CAUGHT, {
		"district_id": gs.current_district_id,
		"return_route": "BOOST",
		"source": {
			"family": "boost",
			"action_id": "boost",
			"target_id": str(target["id"]),
			"target_name": str(target["name"]),
			"target_tier": tier,
			"opponent": str((rules.opponent_for(tier) as Dictionary).get("opponent", "")),
			"source_day": int(gs.day),
			"source_slot": int(gs.time_slots_today),
			"source_rng_key": source_key,
			# The gate an arrest reads later. Snapshotted before any consequence
			# Heat lands, because otherwise the encounter's own Heat would
			# decide whether the encounter ends in an arrest (TI-003 §14).
			"pre_encounter_heat": float(gs.heat),
			"contested_take": contested,
		},
		"decision": {
			"definition_id": "boost_caught",
			"allowed_choices": rules.CAUGHT_CHOICES.duplicate(),
			"deterministic_choices": rules.CAUGHT_DETERMINISTIC.duplicate(),
			"resolver_inputs": inputs,
			"shown_probabilities": shown,
			"arrest_risks": risks,
		},
	})

## TI-003 §12's effect order, in order. Called by the engine once it has
## revalidated identity, stage and the allowed choice.
##
## Every mutating step claims a receipt first. A reload between a mutation and
## the autosave that follows cannot replay it, because the receipt and the
## mutation land in the same dispatch.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = _engine()
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var rules: RefCounted = _rules()
	var source: Dictionary = chain.get("source", {})
	var cause_id := str(chain.get("cause_id", ""))
	var boost_tier: int = int(source.get("target_tier", 1))
	var contested: int = int(source.get("contested_take", 0))
	var pre_heat: float = float(source.get("pre_encounter_heat", 0.0))

	# 1. Resolve the tier, or take Yield's single authored row.
	var tier_name: String = "deterministic"
	if not rules.is_deterministic(choice_id):
		var action_type: String = rules.resolver_for(choice_id)
		var resolver: Object = gm.system("outcome_resolver")
		var attribute: String = resolver.attribute_for(action_type)
		var raw: int = int(gs.attributes.get(attribute, 0))
		var outcome: Dictionary = resolver.resolve_action(
			action_type, rules.base_chance(boost_tier, choice_id), raw,
			gs.run_seed, "consequence:%s:boost_caught:%s:outcome" % [cause_id, choice_id])
		tier_name = str(outcome["tier"])

	var effects: Dictionary = rules.effects_for(choice_id, tier_name)
	var result: Dictionary = {
		"choice_id": choice_id, "tier": tier_name,
		"cash": 0, "goods": 0, "health": 0, "heat": 0.0,
		"banned": false, "arrested": false, "take_disposition": str(effects.get("take", "")),
	}

	# 2. Take disposition, through this adapter because only Boost knows that a
	#    tier-3 haul is merchandise rather than cash (TI-003 §12).
	if str(effects.get("take", "")) == "keep" and contested > 0:
		if engine.record_receipt(cause_id, "boost_caught:take_disposition"):
			if boost_tier >= 3:
				gs.boost_merchandise += contested
				result["goods"] = contested
			else:
				_wallet().credit(contested, _wallet().DIRTY,
					{"source_id": "boost_caught_take"})
				result["cash"] = contested
	# "lose" and "return" both credit zero. They stay separate words because the
	# fiction differs and a later slice may want to tell them apart.

	# 3. The persistent ban.
	if bool(effects.get("ban", false)):
		if engine.record_receipt(cause_id, "boost_caught:ban"):
			var target_id := str(source.get("target_id", ""))
			if not target_id.is_empty() and not target_id in gs.boost_store_bans:
				gs.boost_store_bans.append(target_id)
			result["banned"] = true

	# 4. Injury, rolled on its own key so the outcome and the damage are
	#    independent draws (TI-003 §12).
	var band: Array = rules.injury_band(choice_id, tier_name, boost_tier)
	if band.size() == 2 and engine.record_receipt(cause_id, "boost_caught:injury"):
		var damage: int = rng.seeded_int_range(gs.run_seed,
			"consequence:%s:boost_caught:%s:injury" % [cause_id, choice_id],
			int(band[0]), int(band[1]))
		# Through Tone. See `CrewSystem.absorbed_damage` for why there is one
		# owner rather than a multiply at each site.
		damage = _crew_absorbed(damage)
		gs.health = clampi(gs.health - damage, 0, gs.health_max)
		result["health"] = -damage

	# 5. Criminal Heat, through the one owner. Raw here; HeatSystem applies
	#    Deshawn (and, from FS-003.9, the district multiplier).
	var raw_heat: float = rules.raw_heat(choice_id, tier_name, boost_tier)
	if raw_heat > 0.0 and engine.record_receipt(cause_id, "boost_caught:heat"):
		result["heat"] = _heat().apply_gain(raw_heat, _heat().FAMILY_BOOST,
			str(chain.get("district_id", "")), {"source_id": "boost_caught"})

	# 6. District Pressure, once.
	#
	#    The ledger is written here; the bleed, quiet recovery and difficulty
	#    penalty that READ it are FS-003.9. Recording the gain now rather than
	#    later is deliberate — .9 inherits a ledger with real history in it
	#    instead of starting from zero on every existing save.
	var pressure: float = rules.pressure_gain(choice_id, tier_name)
	if pressure > 0.0 and engine.record_receipt(cause_id, "boost_caught:pressure"):
		_add_district_pressure(str(chain.get("district_id", "")), "boost", pressure, cause_id)
		result["pressure"] = pressure

	# 7. The consequence's own observation, once. Reuses the resolver's authored
	#    footprint for the shape that was rolled, which is what FS-003 means by
	#    "existing street_fight neighborhood observation applies".
	if not rules.is_deterministic(choice_id) \
			and engine.record_receipt(cause_id, "boost_caught:observation"):
		var resolver_obs: Object = gm.system("outcome_resolver")
		resolver_obs.broadcast_outcome(rules.resolver_for(choice_id), tier_name,
			str(chain.get("district_id", "")))

	# 8. The arrest gate, read off the PRE-ENCOUNTER snapshot — then FS-003.13's
	#    cooldown, which can only ever turn a yes into a no. The authored gate is
	#    evaluated first and unchanged: the cooldown is a fact about the last few
	#    days, not a second threshold folded into the gate's own table.
	var arrested: bool = rules.arrests(choice_id, tier_name, boost_tier, pre_heat)
	var arrest_owner: Object = gm.system("arrest") if gm != null else null
	if arrested and arrest_owner != null and arrest_owner.in_cooldown(int(gs.day)):
		arrested = false
		result["arrest_suppressed"] = "cooldown"
	result["arrested"] = arrested

	# 9. Store the result on the chain.
	var decision: Dictionary = chain.get("decision", {})
	decision["resolved_tier"] = tier_name
	decision["result"] = result
	chain["decision"] = decision

	# 10. The result, always. An arrest ATTACHES a booking quote to the chain and
	#     stops there — the chain waits at `result` until the player presses
	#     Continue, which is what carries them into Booking (see the engine's
	#     `_continue`). Advancing straight to `booking` here would render a bail
	#     quote over a result the player never got to read, which PX-003 §5 shows
	#     as the wrong shape: the arrested result is a screen with a BOOKING
	#     action under it, not a screen that is skipped.
	#
	#     The quote itself is ArrestSystem's: Boost decides WHETHER, never what
	#     it costs.
	engine.advance_stage(engine.STAGE_RESULT)
	if arrested:
		if arrest_owner != null:
			arrest_owner.attach_booking(chain, {
				"family": "boost",
				"tier": boost_tier,
				"target_id": str(source.get("target_id", "")),
				"cause_id": cause_id,
			})

	gs.log_activity(_caught_line(source, choice_id, tier_name, result), _caught_tone(tier_name))
	return {"ok": true, "tier": tier_name, "arrested": arrested}

## Write a District Pressure gain, through the owner.
##
## FS-003.7 kept the ledger write here because the Pressure SYSTEM did not exist
## yet; FS-003.9 built it on the engine (TI-003 §8: Pressure is cross-source
## memory, so no single source can own it). This is now a two-line forward so
## Boost's call sites read the same as they did, and so the bleed those gains
## schedule is the engine's business rather than Boost's.
func _add_district_pressure(district_id: String, family: String, amount: float,
		cause_id: String = "") -> void:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null or district_id.is_empty():
		return
	engine.add_pressure(district_id, family, amount, cause_id)

## The gain-side half, forwarded the same way and for the same reason. Sits
## beside `_add_district_pressure` so a reader sees both sides of the ledger in
## one place, and so neither can be added without the other being obvious.
func _credit_clean_outcome(district_id: String, family: String,
		tier_name: String) -> void:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null or district_id.is_empty():
		return
	engine.credit_clean_outcome(district_id, family, tier_name)

func _caught_line(source: Dictionary, choice_id: String, tier_name: String,
		result: Dictionary) -> String:
	var place := str(source.get("target_name", "the store"))
	if choice_id == "yield":
		return "Handed it back at %s and took the walk." % place
	var verb: String = str({"fight": "swung", "run": "ran", "talk": "talked"}.get(choice_id, "answered"))
	if tier_name in ["clean", "messy"]:
		return "You %s at %s and kept it." % [verb, place] if int(result.get("cash", 0)) \
			+ int(result.get("goods", 0)) > 0 else "You %s at %s." % [verb, place]
	return "You %s at %s and it went badly." % [verb, place]

func _caught_tone(tier_name: String) -> Color:
	match tier_name:
		"clean": return GREEN
		"messy": return AMBER
	return RED

## Canon boostFenceRate: 0.40 + standing*0.05, 0.55 from 3, 0.60 from 5.
func fence_rate() -> float:
	var v: int = clampi(gs.boost_fence_standing, 0, 5)
	if v >= 5:
		return 0.60
	if v >= 3:
		return 0.55
	return 0.40 + float(v) * 0.05

func _fence() -> Dictionary:
	if gs.boost_merchandise <= 0:
		return {"ok": false, "reason": "Nothing to move."}
	var payout: int = int(round(float(gs.boost_merchandise) * fence_rate()))
	gs.boost_merchandise = 0
	gs.boost_fence_standing = clampi(gs.boost_fence_standing + 1, 0, 5)
	_wallet().credit(payout, _wallet().DIRTY, {"source_id": "boost_fence"})
	gs.log_activity("Slide takes the lot for $%d." % payout, GREEN)
	# Canon is specific here: Slide is discreet, so the sale reaches the
	# household channel and nothing wider. Yalonda and Juan notice money that
	# has no explanation; the street does not hear about it at all.
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null:
		exposure.broadcast_observation({
			"type": "financial", "event": "fenced_goods", "channel": "household",
		})
	return {"ok": true, "payout": payout}

## Canon updateBoostTier. Tier 3 also needs field-assignable crew, which does
## not exist yet, so it stays out of reach until 3e.
func _update_tier() -> void:
	var was: int = gs.boost_tier
	if gs.boost_technique >= gs.BOOST_TIER2_TECHNIQUE:
		gs.boost_tier = maxi(gs.boost_tier, 2)
	# Canon gates tier 3 on technique AND somebody who can be field-assigned.
	# Crew exists now, so this finally has a way to become true.
	var crew: Object = gm.system("crew") if gm != null else null
	if gs.boost_technique >= gs.BOOST_TIER3_TECHNIQUE and crew != null and crew.has_field_crew():
		gs.boost_tier = maxi(gs.boost_tier, 3)
	if gs.boost_tier > was:
		gs.log_activity("You're getting smooth. Bigger rooms are open now.", GREEN)

## Damage after Tone. Forwarded rather than reached for inline so both of this
## build's damage sites read identically and neither can drift.
func _crew_absorbed(raw: int) -> int:
	var crew: Object = gm.system("crew") if gm != null else null
	return raw if crew == null else int(crew.absorbed_damage(raw))

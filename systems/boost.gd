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
	return clampf(base + (skill - 2.0) * 0.10 + window_bonus, 0.10, 0.95)

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
		if tier == 3:
			# Tier 3 comes out as merchandise, not cash. Slide fences it.
			gs.boost_merchandise += take
			gs.log_activity("%s lands. $%d in merchandise waiting for the fence." % [str(t["name"]), take], GREEN)
		else:
			_wallet().credit(take, _wallet().DIRTY, {"source_id": "boost_take"})
			gs.log_activity("Left %s with goods worth $%d." % [str(t["name"]), take], GREEN)
		result = {"ok": true, "success": true, "take": take, "tier": tier}
	else:
		_apply_heat(1.0)
		gs.log_activity("Walked out of %s empty. Somebody clocked you." % str(t["name"]), RED)
		result = {"ok": true, "success": false, "take": 0, "tier": tier}

	# Not loud enough to raise awareness on its own, but it is criminal activity,
	# which is what stops the quiet streak from bleeding awareness down.
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis != null:
		curtis.mark_criminal_activity()

	_update_tier()
	time_system.handle("advance_time", {})
	return result

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

extends RefCounted
## Outcome resolver — the four tiers, and what the block ends up knowing.
##
## Ported from the web build's `src/data/attributes.js` (the tables) and
## `src/systems/attributes.js` (`buildOutcomePool`, `resolveWithAttribute`,
## `resolveAction`, `isSuccessTier`), plus game-core.js `broadcastOutcome`.
## Attributes.gd named this port as explicitly deferred; this is it landing.
##
## ## The idea
##
## Every risky action in the game already computes a context-sensitive success
## chance out of heat, gear, resistance, disposition and district. Canon does
## not throw that away for a flat weighted table — it SPLITS that chance across
## four tiers. `success` divides the winning half, `failure` divides the losing
## half, and what falls out is one of:
##
##   clean (3) · messy (2) · failure (1) · catastrophic (0)
##
## The integers are an ordinal, and they are the whole contract of advantage: a
## higher attribute may never produce a worse result from the same seed.
##
## ## Why the attribute is not a percentage
##
## Canon grants tabletop advantage rather than a bonus to a number the player
## cannot see:
##
##   - at ADVANTAGE_THRESHOLD (3) you roll twice and keep the better tier
##   - at CATASTROPHE_IMMUNITY_THRESHOLD (6) catastrophic leaves the pool
##
## A single effective level is therefore invisible at 0-1 and 3-4 and decisive
## at 2 and 5. That is deliberate, and it is what makes crew backup (`bonus`)
## worth something specific: it does not make you better at fighting, it takes
## the worst ending off the table.
##
## ## Two things that are easy to get wrong
##
## **The raw value, not the compatibility offset.** `compat()` exists for the
## pre-v1.10 inline `(x - 2) * k` terms and NOTHING else. Canon's own comment is
## explicit: anything routed through `resolve_with_attribute` reads the stored
## value and carries no inline term at all. Feeding compat() in here would shift
## every threshold down a level.
##
## **Pool order is load-bearing.** `seeded_pick` walks cumulative weight in
## array order, so the order entries go into the pool decides which tier a given
## hash lands on. Canon builds it by iterating `shape.success` then
## `shape.failure` in object-literal order — GDScript dictionaries preserve
## insertion order too, so the constants below are transcribed in canon's exact
## key order and must stay that way.
##
## ## What is NOT ported, and why
##
##   - **Streaks** (`gymStreakBonus` / `nileStreakBonus` inside canon's
##     `effectiveAttribute`). Neither venue exists, so the bonus is always 0.
##     `resolve_action` takes the same `bonus` parameter canon does, which is
##     where crew backup already arrives, so the shape is here when they land.
##   - **The consequence-encounter engine.** Canon routes a blown boost and a
##     dealer confrontation into encounters.js, which resolves `confrontation` /
##     `escape` / `negotiation` off this same pipeline. No encounter engine in
##     this build, so those four shapes are ported as data with no caller yet —
##     unlike the deferral this file replaces, they cost one dictionary entry
##     each rather than a large untested branch.
##
## Pure by construction: it reads nothing off GameState and writes nothing to
## it. The one thing it touches beyond arithmetic is `broadcast_outcome`, which
## hands rows to Exposure/Curtis and still writes no GameState field — and the
## CALLER decides whether to call it.

# --- tiers -----------------------------------------------------------------

## Canon OUTCOME_VALUES. The ordinal advantage compares on. Higher is better.
const OUTCOME_VALUES := {"clean": 3, "messy": 2, "failure": 1, "catastrophic": 0}

const TIERS: Array[String] = ["clean", "messy", "failure", "catastrophic"]

## Canon OUTCOME_SHAPES. Shapes, not pools — see the header.
##
## The split is where the design lives. A robbery that goes wrong is usually
## just a failed robbery (0.72) and only sometimes a catastrophe (0.28); a job
## interview cannot be a catastrophe at all, because the worst case is not
## being hired.
##
## **Key order is transcribed from canon and is load-bearing.** See the header.
const OUTCOME_SHAPES := {
	"robbery": {"success": {"clean": 0.55, "messy": 0.45}, "failure": {"failure": 0.72, "catastrophic": 0.28}},
	"dealer_robbery": {"success": {"clean": 0.45, "messy": 0.55}, "failure": {"failure": 0.6, "catastrophic": 0.4}},
	"confrontation": {"success": {"clean": 0.5, "messy": 0.5}, "failure": {"failure": 0.65, "catastrophic": 0.35}},
	"negotiation": {"success": {"clean": 0.5, "messy": 0.5}, "failure": {"failure": 0.7, "catastrophic": 0.3}},
	"escape": {"success": {"clean": 0.6, "messy": 0.4}, "failure": {"failure": 0.8, "catastrophic": 0.2}},
	"job_interview": {"success": {"clean": 0.45, "messy": 0.55}, "failure": {"failure": 1.0}},
	"night_owl": {"success": {"clean": 0.5, "messy": 0.5}, "failure": {"failure": 0.85, "catastrophic": 0.15}},
	"gambling": {"success": {"clean": 0.4, "messy": 0.6}, "failure": {"failure": 0.8, "catastrophic": 0.2}},
	"market_meetup": {"success": {"clean": 0.7, "messy": 0.3}, "failure": {"failure": 0.55, "catastrophic": 0.45}},
	# The two Nile tables read opponents rather than resolving the hand — the
	# hand is played for real elsewhere. What these pools decide is how much the
	# player gets to SEE: a clean read surfaces a tell, a catastrophe surfaces a
	# false one. Neither can go worse than that, which is why neither costs
	# money. Losing money is the game's job, not the attribute's.
	"tonk_read": {"success": {"clean": 0.5, "messy": 0.5}, "failure": {"failure": 0.75, "catastrophic": 0.25}},
	"celo_read": {"success": {"clean": 0.55, "messy": 0.45}, "failure": {"failure": 0.75, "catastrophic": 0.25}},
}

## Canon ACTION_ATTRIBUTE_MAP — which attribute shapes which action.
const ACTION_ATTRIBUTE_MAP := {
	"robbery": "combat",
	"dealer_robbery": "combat",
	"confrontation": "combat",
	"escape": "combat",
	"negotiation": "charisma",
	"job_interview": "charisma",
	"night_owl": "charisma",
	"gambling": "charisma",
	"market_meetup": "intelligence",
	"tonk_read": "charisma",
	"celo_read": "intelligence",
}

## Roll twice and keep the better tier from here up.
const ADVANTAGE_THRESHOLD := 3
## Catastrophic leaves the pool entirely from here up.
const CATASTROPHE_IMMUNITY_THRESHOLD := 6

## Canon's ATTRIBUTE_MIN / ATTRIBUTE_MAX, duplicated rather than read off
## attributes.gd: `bonus` is re-clamped to the same ceiling the attribute lives
## under, and this file must stay resolvable without a live Attributes instance
## so the parity runner can exercise it on its own.
const ATTRIBUTE_MIN := 0
const ATTRIBUTE_MAX := 12

# --- observations ----------------------------------------------------------

## Canon OUTCOME_OBSERVATIONS — **the keystone of the build.**
##
## Outcome quality decides the observation footprint. Doing crime well does not
## make you invisible, it makes you QUIET: a clean robbery still writes its
## financial row, it just travels on `direct` instead of reaching the network. A
## catastrophe goes out on two channels because somebody called it in.
##
## Most tiers are deliberately empty, and that is not an omission. The Exposure
## layer is a tuned economy of attention — canon measured a row for every
## talk-down and every night at the counter as moving every disposition up half
## a band and dragging story pacing with it. What lives here is only the
## difference between doing a thing well and doing it badly.
##
## `type` must be one of Exposure's eleven categories. `event` and `location`
## are free-form, and `location` is filled in by the caller.
const OUTCOME_OBSERVATIONS := {
	"robbery": {
		"clean": [{"type": "financial", "event": "robbery_profit", "channel": "direct"}],
		"messy": [
			{"type": "violence", "event": "robbery_struggle", "channel": "neighborhood"},
			{"type": "heat_exposure", "event": "heat_seen_low", "channel": "neighborhood"},
		],
		"failure": [{"type": "defiance", "event": "attempted_robbery", "channel": "neighborhood"}],
		"catastrophic": [
			{"type": "violence", "event": "robbery_gone_loud", "channel": "neighborhood"},
			{"type": "heat_exposure", "event": "heat_seen_high", "channel": "network"},
		],
	},
	"dealer_robbery": {
		"clean": [{"type": "financial", "event": "robbery_profit", "channel": "direct"}],
		"messy": [{"type": "violence", "event": "dealer_stickup", "channel": "neighborhood"}],
		"failure": [{"type": "defiance", "event": "attempted_robbery", "channel": "neighborhood"}],
		"catastrophic": [
			{"type": "violence", "event": "dealer_stickup", "channel": "neighborhood"},
			{"type": "heat_exposure", "event": "heat_seen_high", "channel": "network"},
		],
	},
	"confrontation": {
		"clean": [],
		"messy": [{"type": "violence", "event": "street_fight", "channel": "neighborhood"}],
		"failure": [],
		"catastrophic": [
			{"type": "violence", "event": "serious_violence", "channel": "neighborhood"},
			{"type": "heat_exposure", "event": "heat_seen_high", "channel": "network"},
		],
	},
	"negotiation": {
		"clean": [],
		"messy": [],
		"failure": [],
		"catastrophic": [{"type": "violence", "event": "street_fight", "channel": "neighborhood"}],
	},
	"escape": {
		"clean": [],
		"messy": [],
		"failure": [],
		# Canon sends this one on `neighborhood`, NOT `network` — an escape seen
		# going wrong is the block watching you run, not somebody calling it in.
		"catastrophic": [{"type": "heat_exposure", "event": "heat_seen_high", "channel": "neighborhood"}],
	},
	"job_interview": {
		# The one non-empty `clean` row outside the robbery family, and the one
		# `household` channel: getting hired is news at home, nowhere else.
		"clean": [{"type": "growth", "event": "hired_on", "channel": "household"}],
		"messy": [],
		"failure": [],
		# No catastrophic key at all — the shape has no catastrophic tier, so a
		# lookup for one must come back empty rather than assume a row.
	},
	"night_owl": {
		"clean": [],
		"messy": [],
		"failure": [],
		"catastrophic": [{"type": "violence", "event": "made_a_scene", "channel": "neighborhood"}],
	},
	"gambling": {
		"clean": [],
		"messy": [],
		"failure": [],
		"catastrophic": [{"type": "financial", "event": "gambling_debt", "channel": "neighborhood"}],
	},
	# Reading a table is not an event anybody reports. Both maps are empty on
	# purpose — what The Nile broadcasts is the money at the end of the night.
	"tonk_read": {"clean": [], "messy": [], "failure": [], "catastrophic": []},
	"celo_read": {"clean": [], "messy": [], "failure": [], "catastrophic": []},
	"market_meetup": {
		# A clean meetup writes nothing. The flip itself already broadcasts when
		# it settles; a well-run handoff in a parking lot is simply not an event
		# anybody reports.
		"clean": [],
		"messy": [{"type": "presence", "event": "met_a_stranger", "channel": "neighborhood"}],
		"failure": [],
		"catastrophic": [{"type": "violence", "event": "robbery_victim", "channel": "neighborhood"}],
	},
}

var rng: Node

func setup(rng_manager: Node) -> void:
	rng = rng_manager

## No actions of its own — this system is called by others, never dispatched to.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The outcome resolver takes no actions."}

# --- the pipeline ----------------------------------------------------------

## Canon buildOutcomePool. Splits a computed success chance across the shape's
## tier weights; each entry is `{tier, value, weight}`.
##
## An unknown action type returns an empty pool, which `resolve_with_attribute`
## reports as null and `resolve_action` turns into a plain failure. Canon does
## the same: a typo at a call site fails to a safe answer rather than inventing
## a shape.
func build_outcome_pool(action_type: String, chance: float) -> Array:
	if not OUTCOME_SHAPES.has(action_type):
		return []
	var shape: Dictionary = OUTCOME_SHAPES[action_type]
	var success: float = clampf(chance if is_finite(chance) else 0.0, 0.0, 1.0)
	var pool: Array = []
	for tier in shape.get("success", {}).keys():
		pool.append({
			"tier": str(tier),
			"value": int(OUTCOME_VALUES[tier]),
			"weight": success * float(shape["success"][tier]),
		})
	for tier in shape.get("failure", {}).keys():
		pool.append({
			"tier": str(tier),
			"value": int(OUTCOME_VALUES[tier]),
			"weight": (1.0 - success) * float(shape["failure"][tier]),
		})
	return pool

## Canon seededPick (src/events/random.js). Cumulative-weight selection off a
## keyed hash — never the market stream, so replaying the same day resolves the
## same way regardless of what else ran first.
##
## The zero-total fallback is canon's and it matters at the boundaries: at
## chance 0 the success half weighs nothing, and job_interview at chance 1 has a
## failure half that weighs nothing. It is only reachable when EVERY entry is
## zero, which happens for a shape whose weights are all zero — never for a
## real chance, but ported because bit-exact is bit-exact.
func seeded_pick(pool: Array, seed_value: String, context: String) -> Variant:
	if pool.is_empty():
		return null
	var weights: Array[float] = []
	var total: float = 0.0
	for entry in pool:
		var w: float = float(entry.get("weight", 0.0))
		if not is_finite(w):
			w = 0.0
		w = maxf(0.0, w)
		weights.append(w)
		total += w
	if total <= 0.0:
		return pool[rng.string_hash(seed_value + ":" + context) % pool.size()]
	var roll: float = rng.seeded_random(seed_value, context) * total
	for index in pool.size():
		roll -= weights[index]
		if roll <= 0.0:
			return pool[index]
	return pool[pool.size() - 1]

## Canon resolveWithAttribute — the one entry point for an attribute-modified
## roll.
##
## `attribute_value` is the RAW stored attribute (see the header): 0-12, not the
## 1-5 compatibility offset.
##
## Note the immunity filter's guard: canon only drops catastrophic when
## something survives. A pool that is nothing but catastrophic entries stays
## intact rather than resolving to nothing.
func resolve_with_attribute(outcome_pool: Array, attribute_value: int, seed_value: String,
		context: String) -> Variant:
	var pool: Array = outcome_pool.duplicate()
	if pool.is_empty():
		return null
	if attribute_value >= CATASTROPHE_IMMUNITY_THRESHOLD:
		var survivors: Array = []
		for entry in pool:
			if str(entry.get("tier", "")) != "catastrophic":
				survivors.append(entry)
		if not survivors.is_empty():
			pool = survivors
	var first: Variant = seeded_pick(pool, seed_value, context)
	if attribute_value < ADVANTAGE_THRESHOLD:
		return first
	var second: Variant = seeded_pick(pool, seed_value, context + ":adv")
	if first == null:
		return second
	if second == null:
		return first
	return first if int(first.get("value", 0)) >= int(second.get("value", 0)) else second

## Canon resolveAction: an action id, a computed chance, the attribute value it
## reads, and the seed the roll is keyed on. Returns `{tier, value}`.
##
## `bonus` is an effective-level modifier from something outside the player —
## crew backup, for now — re-clamped to the same ceiling the attribute lives
## under, so a big guy standing next to you can push a Combat 5 over the
## catastrophe-immunity line but can never push anyone past the top tier.
## Omitting it resolves exactly as before, which is what keeps every call site
## with no backup byte-identical.
##
## **On the signature.** Canon takes one pre-joined key string; this takes
## `seed_value` and `context` separately because RngManager.seeded_random() does
## the joining itself (`hash(seed + ":" + context)`). Canon's key is
## `${run.seed}:stickup:...`, so passing `gs.run_seed` and `"stickup:..."`
## hashes the identical string. Split at the first colon and the two agree.
func resolve_action(action_type: String, chance: float, attribute_value: int,
		seed_value: String, context: String, bonus: int = 0) -> Dictionary:
	var pool: Array = build_outcome_pool(action_type, chance)
	var level: int = clampi(attribute_value + bonus, ATTRIBUTE_MIN, ATTRIBUTE_MAX)
	var outcome: Variant = resolve_with_attribute(pool, level, seed_value, context)
	if outcome == null:
		return {"tier": "failure", "value": int(OUTCOME_VALUES["failure"])}
	return {"tier": str(outcome["tier"]), "value": int(outcome["value"])}

## Canon isSuccessTier. Clean and messy both took the money; what separates them
## is who saw it.
func is_success_tier(tier: String) -> bool:
	return tier == "clean" or tier == "messy"

## Which attribute an action reads, or "" for an unknown id — so a typo at a
## call site resolves to attribute 0 loudly rather than silently picking one.
func attribute_for(action_type: String) -> String:
	return str(ACTION_ATTRIBUTE_MAP.get(action_type, ""))

# --- the join with Exposure ------------------------------------------------

## The rows a tier writes, before any location is filled in. Empty for a tier a
## shape does not carry (job_interview has no catastrophic) and for an unknown
## action type.
func observations_for(action_type: String, tier: String) -> Array:
	var by_tier: Dictionary = OUTCOME_OBSERVATIONS.get(action_type, {})
	return by_tier.get(tier, [])

## Canon broadcastOutcome — **the single entry point for post-resolution
## Exposure effects.** Returns how many rows it wrote.
##
## Every row goes through Curtis.broadcast_tracked(), which is canon's shape:
## the CHANNEL decides propagation inside Exposure, and awareness only rises
## when a row genuinely lands on Curtis over the network. Routing by channel at
## this level instead would double-implement the propagation table and get
## `direct` wrong — `direct` is not "one NPC", it is everyone standing there,
## which in this build is all five.
##
## `value` rides along when the caller has one (canon passes the payout, which
## is what Curtis's financial filter reads); null leaves whatever the spec
## carries.
func broadcast_outcome(action_type: String, tier: String, location: String,
		value: Variant = null) -> int:
	var specs: Array = observations_for(action_type, tier)
	if specs.is_empty():
		return 0
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis == null:
		return 0
	for spec in specs:
		var row: Dictionary = (spec as Dictionary).duplicate()
		# Canon: `spec.location || currentNeighborhoodId`. No spec in the table
		# pins its own location today, but the fallback is canon's and a future
		# row that does pin one must win over the caller's.
		if str(row.get("location", "")).is_empty():
			row["location"] = location
		if value != null:
			row["value"] = value
		curtis.broadcast_tracked(row)
	return specs.size()

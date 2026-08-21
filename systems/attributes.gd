extends RefCounted
## Attributes — the three numbers behind every outcome in the game.
##
## Ported from the web build's `src/data/attributes.js` (the tables) and
## `src/systems/attributes.js` (the logic). Canon carries three attributes —
## **combat, charisma, intelligence** — each starting at 1 and clamped 0..12.
## Until now this build pinned all three at their defaults and hardcoded the
## resulting constants into stickup, boost and shark. This unpins them.
##
## ## The bug the unpinning found
##
## Canon's action formulas do NOT read the stored attribute. They read
## `compatibilityRating`, which is `clamp(value + 1, 1, 5)` — a deliberate
## offset. Canon's own comment says why: those formulas were written against a
## pre-v1.10 attribute that ran 1-5 and started at **2**, and the consolidation
## moved the stored value to a 0-12 scale starting at **1**. Reading the stored
## value directly would quietly dock every one of those formulas a point on day
## one, which canon measured at roughly 40% of the run economy.
##
## The port pinned the STORED default (1) where canon reads the COMPATIBILITY
## value (2), so three shipped surfaces have been running at the wrong
## difficulty since Phase 3d:
##
## | surface | canon term at default | port had | drift |
## |---|---|---|---|
## | stickup `(combatCompat - 2) * 0.08` | 0 | -0.08 | 8 points harder |
## | boost `(skill - 2) * 0.10` | 0 | -0.10 | 10 points harder |
## | shark `- intelligenceCompat * 0.025` | -0.05 | -0.025 | 2.5 points riskier |
##
## The pinning was faithful to the wrong function. Fixed here, and every one of
## those call sites now reads `compat()` so the term moves when the player does.
##
## ## What is ported
##
## The data tables, the reads (`value` / `compat` / `label`), and growth. All of
## it has callers as of this build.
##
## ## What is NOT ported, and why each is absent rather than stubbed
##
##   - **Tiered outcome resolution** (`OUTCOME_SHAPES`, `buildOutcomePool`,
##     `resolveWithAttribute`, `resolveAction`). Canon resolves an action into
##     one of four tiers — clean / messy / failure / catastrophic — with the
##     attribute granting tabletop advantage (a second roll at 3, catastrophe
##     immunity at 6) rather than a percentage bonus. This build's surfaces all
##     resolve binary `roll < chance`. Converting them also changes the Exposure
##     footprint, because canon's `OUTCOME_OBSERVATIONS` keys what the
##     neighborhood learns off the tier. That is a build of its own; porting the
##     resolver now would ship a large untested branch with no caller.
##   - **Streaks** (`gymStreakBonus`, `nileStreakBonus`, `effectiveAttribute`).
##     Three consecutive days at the Spenard Gym or The Nile are worth +1
##     effective level on the next check. Neither venue exists, so the bonus is
##     always 0 and `effectiveAttribute` would be `value` with extra steps.
##   - **Street Identity** is ported as of part 2, below — the Character screen
##     is its caller.
##   - **Six of nine growth sources.** `GROWTH_RATES` is ported whole because it
##     is one table and canon's design is that a new growth source is a row
##     rather than a code path — but only `list_flip` has a surface today. The
##     gym three (bag_work, cardio, sparring) and The Nile's five wait on their
##     venues. A source with no attribute returns null so a typo at a call site
##     fails loudly instead of training nothing, which is canon's rule.

const IDS: Array[String] = ["combat", "charisma", "intelligence"]
const DEFAULTS := {"combat": 1, "charisma": 1, "intelligence": 1}
const MIN := 0
## Not a design ceiling — canon calls this the clamp that stops a corrupt save
## producing a 400-combat player. "8+" is simply the top display tier.
const MAX := 12

## Canon's ATTRIBUTES table: what each one is for, in the player's words.
const TABLE := [
	{"id": "combat", "label": "Combat", "domain": "Violence",
		"purpose": "Robbery, confrontation, escape, and every physical outcome."},
	{"id": "charisma", "label": "Charisma", "domain": "Social",
		"purpose": "Being read well: interviews, tables, first impressions, a room at night."},
	{"id": "intelligence", "label": "Intelligence", "domain": "Economic",
		"purpose": "Appraisal, price certainty, planning, and knowing when not to be somewhere."},
]

## Players never see the number. Checked highest floor first.
const LABEL_TIERS := [
	{"floor": 8, "label": "Elite"},
	{"floor": 6, "label": "Dangerous"},
	{"floor": 4, "label": "Solid"},
	{"floor": 2, "label": "Capable"},
	{"floor": 0, "label": "Green"},
]

## Base rate per session, before log2 diminishing returns.
const GROWTH_RATES := {
	# Combat — the Spenard Gym. No venue yet.
	"bag_work": 0.3, "cardio": 0.2, "sparring": 0.5,
	# Charisma — The Nile's two floors plus Night Owl nights. No venue yet.
	"nile_social": 0.25, "tonk_game": 0.4, "night_owl_social": 0.15,
	# Intelligence — reading a table, a listing, a man's hands. `list_flip` is
	# the one source this build can reach.
	"celo_game": 0.4, "list_flip": 0.2, "coffee_ceremony": 0.15,
}

## Split from GROWTH_RATES so a reducer never hard-codes "this one is Charisma"
## at the call site, and an unknown source is a loud failure not a silent no-op.
const GROWTH_ATTRIBUTES := {
	"bag_work": "combat", "cardio": "combat", "sparring": "combat",
	"nile_social": "charisma", "tonk_game": "charisma", "night_owl_social": "charisma",
	"celo_game": "intelligence", "list_flip": "intelligence", "coffee_ceremony": "intelligence",
}

## Growth past Dangerous needs real experience, not another session on the bag.
const GROWTH_CAP_PENALTY_FLOOR := 6
const GROWTH_CAP_PENALTY := 0.5

# --- Street Identity (canon: src/data/attributes.js) -----------------------
## **Identity is cosmetic.** It never gates content, never modifies a roll and
## never touches disposition — canon is explicit about this. It is the
## neighborhood's shorthand for you, derived on read from your strongest
## attribute and what you have actually been seen doing.
##
## Canon retired a nightly assignment loop with two-night hysteresis and a stored
## label to get here. `street_identity()` is pure: same state in, same label out,
## and it writes nothing. That is the whole point of the rewrite, so do not cache
## it back into GameState.

## Which matrix column an observation category counts toward.
const IDENTITY_BEHAVIOR_COLUMNS := {
	"violence": "violence", "defiance": "violence", "betrayal": "violence",
	"heat_exposure": "violence",
	"presence": "presence", "discretion": "presence", "loyalty": "presence",
	"submission": "presence", "honesty": "presence",
	"financial": "financial", "growth": "financial",
}

## No attribute leads by more than this and you read as Balanced.
const IDENTITY_BALANCE_MARGIN := 2
## How far back the behaviour read looks.
const IDENTITY_RECENT_DAYS := 7

const IDENTITY_MATRIX := {
	"combat": {"violence": "Shooter", "presence": "Enforcer",
		"financial": "Collector", "default": "Muscle"},
	"charisma": {"violence": "Smooth Talker", "presence": "Connected",
		"financial": "Broker", "default": "People Person"},
	"intelligence": {"violence": "Ghost", "presence": "Observer",
		"financial": "Quiet Money", "default": "Calculator"},
	"balanced": {"violence": "Unpredictable", "presence": "Hustler",
		"financial": "Adaptable", "default": "New Face"},
}

const IDENTITY_DESCRIPTIONS := {
	"Shooter": "People step back when you come up the block, and they are not wrong to.",
	"Enforcer": "You are the one somebody sends. Everyone knows which somebody.",
	"Collector": "What you are owed, you collect. The block has watched it happen.",
	"Muscle": "Nobody has decided what you want yet. They have decided what you can do.",
	"Smooth Talker": "You have talked your way out of rooms other people got carried out of.",
	"Connected": "Your name comes up in conversations you were not in.",
	"Broker": "Two people who needed each other met through you, and both of them paid.",
	"People Person": "You know everybody. It has not cost you anything yet.",
	"Ghost": "Things happen near you and nobody can say you were there.",
	"Observer": "You are always at the edge of it, and you are always still there after.",
	"Quiet Money": "No jewelry, no noise, and somehow never short.",
	"Calculator": "You think two moves out. It reads as patience, which suits you.",
	"Unpredictable": "Nobody can guess your next move, which is its own kind of protection.",
	"Hustler": "Whatever the week needs, you are already doing it.",
	"Adaptable": "You have no lane, and that has never once slowed you down.",
	"New Face": "The block is still deciding.",
}

const GREEN := Color(0.451, 0.722, 0.404)

var gs: Node

func setup(game_state: Node) -> void:
	gs = game_state

## No actions of its own — this system is read by others, not dispatched to.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "Attributes takes no actions."}

# --- reading ---------------------------------------------------------------

## Canon normalizedAttributes: floored, clamped, and defaulted per id, so a
## hand-edited save cannot feed a float or a missing key into a formula.
func normalized() -> Dictionary:
	var out: Dictionary = {}
	for id in IDS:
		var raw: Variant = gs.attributes.get(id, DEFAULTS[id])
		var v: int = int(floor(float(raw)))
		out[id] = clampi(v, MIN, MAX)
	return out

func value(attribute: String) -> int:
	return int(normalized().get(attribute, MIN))

## **The compatibility scale — read the file header before changing this.**
##
## Canon's pre-v1.10 formulas were tuned against attributes running 1-5 from a
## base of 2. This maps the current 0-12 scale onto that one: a stored 1 reads
## as the old default of 2, and the old ceiling of 5 still caps it. Every inline
## `(x - 2) * k` term in the game expects THIS value, not the stored one.
func compat(attribute: String) -> int:
	return clampi(value(attribute) + 1, 1, 5)

## Canon attributeLabel. The player is told this and never the number.
func label(v: int) -> String:
	for tier in LABEL_TIERS:
		if v >= int(tier["floor"]):
			return str(tier["label"])
	return str(LABEL_TIERS[LABEL_TIERS.size() - 1]["label"])

func label_for(attribute: String) -> String:
	return label(value(attribute))

# --- growth ----------------------------------------------------------------

## Canon attributeGrowth. Same log2 shape as the Exposure layer's observation
## capping, for the same reason: sessions one through three move the needle,
## four through seven taper, and past that the source alone cannot carry you.
func growth(current_value: int, session_count: int, activity: String) -> float:
	if not GROWTH_RATES.has(activity):
		return 0.0
	var base: float = float(GROWTH_RATES[activity])
	var sessions: int = maxi(0, session_count)
	var diminishing: float = 1.0 / (log(float(sessions) + 2.0) / log(2.0))
	var cap_penalty: float = GROWTH_CAP_PENALTY if current_value >= GROWTH_CAP_PENALTY_FLOOR else 1.0
	return base * diminishing * cap_penalty

## Canon growthAttribute — null for an unknown id, so a typo fails visibly.
func growth_attribute(activity: String) -> String:
	return str(GROWTH_ATTRIBUTES.get(activity, ""))

## The whole growth read for one source in one call: what it trains, and what
## this session is worth given the current value and how many came before.
## Returns an empty dictionary for an unknown source. The caller owns the write.
func growth_for(activity: String, session_count: int) -> Dictionary:
	var attribute: String = growth_attribute(activity)
	if attribute.is_empty():
		return {}
	return {"attribute": attribute, "growth": growth(value(attribute), session_count, activity)}

## Canon improveAttribute: progress banks below 1.0 and spends a whole point
## when it crosses. **The player is told they got better, never by how much** —
## canon keeps the number behind a debug flag, and so does this.
func improve(attribute: String, gained: float) -> bool:
	if not attribute in IDS:
		return false
	if gained <= 0.0:
		return false
	if int(gs.attributes.get(attribute, 0)) >= MAX:
		return false
	gs.attribute_progress[attribute] = float(gs.attribute_progress.get(attribute, 0.0)) + gained
	if float(gs.attribute_progress[attribute]) < 1.0:
		return false
	gs.attribute_progress[attribute] = float(gs.attribute_progress[attribute]) - 1.0
	gs.attributes[attribute] = clampi(int(gs.attributes.get(attribute, 0)) + 1, MIN, MAX)
	gs.log_activity(
		"Something has changed in how you carry yourself. People read you as %s now."
			% label(int(gs.attributes[attribute])), GREEN)
	return true

## Train one source once. Convenience for a surface that has just done the thing
## the source describes; `session_count` is how many times it happened BEFORE
## this one, which is what makes the first sessions the valuable ones.
func train(activity: String, session_count: int) -> bool:
	var read: Dictionary = growth_for(activity, session_count)
	if read.is_empty():
		return false
	return improve(str(read["attribute"]), float(read["growth"]))

# --- Street Identity -------------------------------------------------------

## Canon getRecentObservations: every row any NPC is carrying from the last
## `days` days. A row keeps its most recent sighting in `day` (record_observation
## refreshes it on a repeat), which is exactly what a recency read wants.
func recent_observations(days: int = IDENTITY_RECENT_DAYS) -> Array:
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure == null:
		return []
	var window: int = maxi(1, days)
	var floor_day: int = gs.day - window + 1
	var out: Array = []
	for npc_id in exposure.npc_ids():
		for row in exposure.ledger_of(str(npc_id)):
			if int(row.get("day", 0)) >= floor_day:
				out.append(row)
	return out

## Canon getDominantAttribute. A lead of more than IDENTITY_BALANCE_MARGIN is a
## lane; anything tighter reads as balanced.
func dominant_attribute() -> String:
	var n: Dictionary = normalized()
	var ranked: Array = [
		["combat", int(n["combat"])],
		["charisma", int(n["charisma"])],
		["intelligence", int(n["intelligence"])],
	]
	# Stable sort by value, descending. Canon's Array.sort is not guaranteed
	# stable either, but the ties it produces fall through to "balanced" anyway.
	ranked.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	if int(ranked[0][1]) - int(ranked[1][1]) > IDENTITY_BALANCE_MARGIN:
		return str(ranked[0][0])
	return "balanced"

## Canon getDominantCategory. **A tie is not a signal** — it falls through to the
## attribute's default label rather than picking one arbitrarily.
func dominant_category(observations: Array) -> String:
	var totals: Dictionary = {}
	for row in observations:
		var column: String = str(IDENTITY_BEHAVIOR_COLUMNS.get(str(row.get("type", "")), ""))
		if column.is_empty():
			continue
		totals[column] = int(totals.get(column, 0)) + maxi(1, int(row.get("count", 1)))
	if totals.is_empty():
		return "default"
	var ranked: Array = []
	for key in totals.keys():
		ranked.append([str(key), int(totals[key])])
	ranked.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	if ranked.size() > 1 and int(ranked[0][1]) == int(ranked[1][1]):
		return "default"
	return str(ranked[0][0])

## Canon identityProfile: the label plus the two reads behind it, so a caller can
## vary copy by what kind of person you are rather than by the exact name for it.
func identity_profile() -> Dictionary:
	var dominant: String = dominant_attribute()
	var behavior: String = dominant_category(recent_observations())
	var row: Dictionary = IDENTITY_MATRIX.get(dominant, IDENTITY_MATRIX["balanced"])
	var label_text: String = str(row.get(behavior, row["default"]))
	return {
		"dominant": dominant,
		"behavior": behavior,
		"label": label_text,
		"description": str(IDENTITY_DESCRIPTIONS.get(label_text, IDENTITY_DESCRIPTIONS["New Face"])),
	}

## Canon getStreetIdentity — pure, and never written back anywhere.
func street_identity() -> String:
	return str(identity_profile()["label"])

extends RefCounted
## Authored consequence values — TI-003 §3.
##
## Static design data ONLY. No state, no systems, no RNG: every function here is
## a lookup or a pure derivation, and everything it returns came from FS-003 or
## TI-003 rather than from anyone's judgement while coding.
##
## That separation is the point. TI-003 §23 closes with *"Implementation
## preserves the approved values in this handoff"* — so the values live in one
## file that reads like the design document, and the systems query it. A balance
## change is an edit here and nowhere else.
##
## FS-003.7 fills in the Failed Boost → Caught rows. Arrest severity, District
## Pressure thresholds, Financial Pressure and retaliation land in .8 through .10
## and have their own sections reserved below.

# --- Failed Boost → Caught (FS-003 §5) --------------------------------------

## The opponent you get, by the tier of the room you tried.
##
## Base chances are the STARTING chance handed to the outcome resolver; the
## resolver then splits them across its four tiers and applies advantage and
## catastrophe immunity from the player's raw attribute. So a 50% Fight is not a
## 50% chance of a good outcome — it is a 50% chance of the winning half.
##
## Injury bands are damage, rolled keyed. `fight_win` is what a successful fight
## costs you; `fight_loss` is what losing one does.
const CAUGHT_OPPONENTS := {
	1: {
		"opponent": "Clerk",
		"fight": 0.50, "run": 0.62, "talk": 0.65,
		"fight_win": [4, 9], "fight_loss": [12, 20],
	},
	2: {
		"opponent": "Store Security",
		"fight": 0.30, "run": 0.50, "talk": 0.45,
		"fight_win": [5, 10], "fight_loss": [15, 24],
	},
	3: {
		"opponent": "Armed Guard",
		"fight": 0.15, "run": 0.38, "talk": 0.25,
		"fight_win": [6, 12], "fight_loss": [18, 28],
	},
}

## TI-003 §12's response mapping. Yield is absent because it rolls nothing.
const CAUGHT_RESOLVERS := {
	"fight": "confrontation",
	"run": "escape",
	"talk": "negotiation",
}

const CAUGHT_CHOICES: Array[String] = ["fight", "run", "talk", "yield"]
## The one response that resolves without touching RNG. TI-003 regression #8 is
## "Yield consumes RNG", and this list is what the projection reads to label it.
const CAUGHT_DETERMINISTIC: Array[String] = ["yield"]

## What each response does at each tier, transcribed from FS-003 §5.
##
## `take`: keep · lose · return.
##   - **keep** credits the contested take (Dirty Cash at tier 1-2, merchandise
##     at tier 3 — TI-003 §12).
##   - **lose** is confiscated. **return** is handed back. Both credit zero, and
##     they are separate words because the fiction differs and a later slice may
##     want to tell them apart.
## `ban`: whether the store stops letting you in, permanently.
## `arrest`: true · false · "conditional" (Run/Failure only — see `arrests()`).
## `injury`: which band to roll, or "" for none.
## `heat`: raw Heat BEFORE Deshawn and district scaling. `"tier+N"` means the
##   tier number plus N, which is how FS-003 writes the rows it does not
##   enumerate — Fight/Failure spells out 2·3·4 and Run/Failure writes "Tier +1"
##   for the same shape.
const CAUGHT_EFFECTS := {
	"fight": {
		"clean":        {"take": "keep",   "ban": false, "arrest": false, "injury": "fight_win_low",  "heat": 1.0},
		"messy":        {"take": "keep",   "ban": false, "arrest": false, "injury": "fight_win",      "heat": 2.0},
		"failure":      {"take": "lose",   "ban": true,  "arrest": true,  "injury": "fight_loss",     "heat": "tier+1"},
		"catastrophic": {"take": "lose",   "ban": true,  "arrest": true,  "injury": "fight_loss_bad", "heat": "tier+2"},
	},
	"run": {
		"clean":        {"take": "keep",   "ban": false, "arrest": false,         "injury": "",              "heat": "run_light"},
		"messy":        {"take": "keep",   "ban": false, "arrest": false,         "injury": "run_messy",     "heat": "run_light"},
		"failure":      {"take": "lose",   "ban": true,  "arrest": "conditional", "injury": "run_failure",   "heat": "tier+1"},
		"catastrophic": {"take": "lose",   "ban": true,  "arrest": true,          "injury": "run_disaster",  "heat": "tier+2"},
	},
	"talk": {
		"clean":        {"take": "return", "ban": false, "arrest": false, "injury": "",           "heat": 0.0},
		"messy":        {"take": "return", "ban": true,  "arrest": false, "injury": "",           "heat": 0.0},
		"failure":      {"take": "return", "ban": true,  "arrest": false, "injury": "",           "heat": 1.0},
		"catastrophic": {"take": "return", "ban": true,  "arrest": true,  "injury": "talk_ugly",  "heat": 2.0},
	},
	# The deterministic relief valve. FS-003 §5: "Yield gives the player a known
	# loss when every rolled response looks too dangerous." One row, no tier.
	"yield": {
		"deterministic": {"take": "return", "ban": true, "arrest": false, "injury": "", "heat": 0.0},
	},
}

## Fixed injury bands — the ones that do not vary by tier.
const CAUGHT_FIXED_INJURY := {
	"run_messy": [1, 5],
	"run_failure": [4, 10],
	"run_disaster": [8, 14],
	"talk_ugly": [5, 10],
}

## FS-003 §5: a catastrophic lost fight takes "the lost-fight injury roll +6
## damage before existing mitigation".
const CAUGHT_CATASTROPHIC_INJURY_BONUS := 6

## Run/Failure is the one conditional arrest in the table. FS-003 §5: "Arrest
## occurs only when pre-encounter Global Heat > 6 or the target is Tier 3."
const RUN_FAILURE_ARREST_HEAT := 6.0
const RUN_FAILURE_ARREST_TIER := 3

## District Pressure by resolved tier — TI-003 §8's tiered gains.
const PRESSURE_BY_TIER := {
	"clean": 0.5, "messy": 1.0, "failure": 1.0, "catastrophic": 2.0,
}

## Marcus Tate's authored row, quoted verbatim in TI-003's executive summary:
##
##     boost_caught.yield.pressure_gain = 1.0
##
## Named as its own constant rather than folded into the table above because it
## was one of the two values that held the Phase 5 gate open, and it should be
## findable by the name the decision was recorded under.
const YIELD_PRESSURE_GAIN := 1.0

# --- lookups ---------------------------------------------------------------

func opponent_for(tier: int) -> Dictionary:
	return CAUGHT_OPPONENTS.get(clampi(tier, 1, 3), {})

## The starting chance handed to the resolver for one response at one tier.
## Returns 0.0 for Yield, which does not roll.
func base_chance(tier: int, choice_id: String) -> float:
	var row: Dictionary = opponent_for(tier)
	return float(row.get(choice_id, 0.0))

func resolver_for(choice_id: String) -> String:
	return str(CAUGHT_RESOLVERS.get(choice_id, ""))

func is_deterministic(choice_id: String) -> bool:
	return choice_id in CAUGHT_DETERMINISTIC

## The authored effect row. Yield ignores the tier — it has exactly one outcome.
func effects_for(choice_id: String, tier_name: String) -> Dictionary:
	var by_choice: Dictionary = CAUGHT_EFFECTS.get(choice_id, {})
	if choice_id == "yield":
		return by_choice.get("deterministic", {})
	return by_choice.get(tier_name, {})

## Raw Heat before Deshawn and district scaling.
##
## Resolves the two shorthand forms FS-003 uses. `"tier+N"` is the tier number
## plus N — the form the document writes when the pattern is obvious ("Raw Heat:
## Tier +1") and enumerates when it is not ("Tier 1 +2, Tier 2 +3, Tier 3 +4").
## Both are the same rule, and both are read here rather than at a call site.
func raw_heat(choice_id: String, tier_name: String, boost_tier: int) -> float:
	var row: Dictionary = effects_for(choice_id, tier_name)
	var value: Variant = row.get("heat", 0.0)
	if value is float or value is int:
		return float(value)
	var spec := str(value)
	if spec == "run_light":
		# The one row FS-003 enumerates against the tier pattern rather than
		# with it: Tier 1 +1, Tier 2 +2, Tier 3 +2. A clean or messy escape from
		# a tier-3 room is no louder than from a tier-2 one.
		return 1.0 if boost_tier <= 1 else 2.0
	if spec.begins_with("tier+"):
		return float(clampi(boost_tier, 1, 3)) + float(spec.substr(5).to_int())
	return 0.0

## The injury band to roll, as `[min, max]`, or an empty array for none.
func injury_band(choice_id: String, tier_name: String, boost_tier: int) -> Array:
	var row: Dictionary = effects_for(choice_id, tier_name)
	var band_id := str(row.get("injury", ""))
	if band_id.is_empty():
		return []
	if CAUGHT_FIXED_INJURY.has(band_id):
		return (CAUGHT_FIXED_INJURY[band_id] as Array).duplicate()
	var opponent: Dictionary = opponent_for(boost_tier)
	match band_id:
		"fight_win":
			return (opponent.get("fight_win", []) as Array).duplicate()
		"fight_win_low":
			# FS-003 §5 Fight/Clean: "the lower half of the tier's
			# successful-fight injury band".
			#
			# INTERPRETATION, stated rather than buried: the band is halved at
			# its midpoint, rounded DOWN, and the low half is inclusive of both
			# ends — tier 1's 4-9 becomes 4-6. Rounding the midpoint up would
			# make "the lower half" of a 4-9 band reach 7, which is more than
			# half of it. The alternative readings differ by one point of
			# damage on a clean win and are noted here so the choice is on the
			# record rather than inferred from the code.
			var full: Array = opponent.get("fight_win", [])
			if full.size() < 2:
				return []
			var low: int = int(full[0])
			var high: int = int(full[1])
			return [low, int(floor(float(low + high) / 2.0))]
		"fight_loss":
			return (opponent.get("fight_loss", []) as Array).duplicate()
		"fight_loss_bad":
			var loss: Array = opponent.get("fight_loss", [])
			if loss.size() < 2:
				return []
			return [int(loss[0]) + CAUGHT_CATASTROPHIC_INJURY_BONUS,
				int(loss[1]) + CAUGHT_CATASTROPHIC_INJURY_BONUS]
	return []

## Whether this outcome ends in a booking.
##
## `pre_encounter_heat` is the Heat snapshot taken BEFORE any consequence Heat
## landed — TI-003 §14 is explicit that the gate reads the pre-encounter value,
## and reading the live meter would let the encounter's own Heat decide whether
## the encounter ends in an arrest.
func arrests(choice_id: String, tier_name: String, boost_tier: int,
		pre_encounter_heat: float) -> bool:
	var row: Dictionary = effects_for(choice_id, tier_name)
	var value: Variant = row.get("arrest", false)
	if value is bool:
		return value
	if str(value) == "conditional":
		return pre_encounter_heat > RUN_FAILURE_ARREST_HEAT \
			or clampi(boost_tier, 1, 3) >= RUN_FAILURE_ARREST_TIER
	return false

## District Pressure this outcome adds. Yield is its own authored row.
func pressure_gain(choice_id: String, tier_name: String) -> float:
	if choice_id == "yield":
		return YIELD_PRESSURE_GAIN
	return float(PRESSURE_BY_TIER.get(tier_name, 0.0))

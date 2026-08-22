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

# --- Arrest and Booking (TI-003 §13-14, FS-003 §7) -------------------------
#
# The severity table is the whole of the arrest economy: what a charge costs,
# how long it holds you, and how much Heat the city lets go of once the incident
# has a case number attached to it.
#
# Boost tier 3 deliberately shares tier 2's row. FS-003 §7 says why: "Tier 3
# Boost continues using the Boost 2 booking severity because the charge remains
# a high-level shoplifting/organized-theft incident rather than a Stick Tier 3
# robbery charge." A $1,000 bail for walking out of a warehouse club would price
# theft like armed robbery.

const SEVERITY_BOOST_T1 := "boost_t1"
const SEVERITY_BOOST_T2 := "boost_t2"
const SEVERITY_STICK_T1 := "stick_t1"
const SEVERITY_STICK_T2 := "stick_t2"
const SEVERITY_STICK_T3 := "stick_t3"
const SEVERITY_GENERIC := "generic"

## FS-003 §7 / TI-003 §13, transcribed. `relief` is a float because Heat is —
## an int here would be fine today (every row is whole) and would silently
## truncate the first fractional row anyone authors.
const ARREST_SEVERITIES := {
	SEVERITY_BOOST_T1: {"bail": 150, "processing": 1, "relief": 2.0, "label": "SHOPLIFTING"},
	SEVERITY_BOOST_T2: {"bail": 250, "processing": 1, "relief": 2.0, "label": "ORGANIZED THEFT"},
	SEVERITY_STICK_T1: {"bail": 350, "processing": 2, "relief": 3.0, "label": "ROBBERY"},
	SEVERITY_STICK_T2: {"bail": 600, "processing": 2, "relief": 4.0, "label": "ARMED ROBBERY"},
	SEVERITY_STICK_T3: {"bail": 1000, "processing": 3, "relief": 5.0, "label": "ORGANIZED ROBBERY"},
	SEVERITY_GENERIC: {"bail": 300, "processing": 2, "relief": 3.0, "label": "DISORDERLY"},
}

## Bail multiplier by the number of arrests ALREADY on the record. Index is the
## prior count; anything at or above the last index takes the last value, which
## is FS-003's "4+ -> 3.50x".
const PRIOR_BAIL_MULTIPLIERS: Array[float] = [1.00, 1.50, 2.00, 2.75, 3.50]

## FS-003 §7: "Processing gains +1 slot per 2 prior arrests."
const PRIORS_PER_EXTRA_SLOT := 2
## FS-003 §7: "Maximum total booking/serving time from one arrest is 4 time
## slots." TOTAL — the shortfall conversion below counts against this ceiling
## too, which is what keeps a broke player from being held for a week.
const MAX_BOOKING_SLOTS := 4
## FS-003 §7: "Every $150 of remaining shortfall, rounded up, adds +1 slot."
const SHORTFALL_DOLLARS_PER_SLOT := 150

## The three lanes. Names are stable IDs, not copy.
const BOOKING_FULL_BAIL := "full_bail"
const BOOKING_ALL_CASH := "all_cash"
const BOOKING_SERVE_TIME := "serve_time"
const BOOKING_CHOICES: Array[String] = [
	BOOKING_FULL_BAIL, BOOKING_ALL_CASH, BOOKING_SERVE_TIME,
]

## TI-003 §14's Stick arrest gate. A plain Failure books only when the player was
## ALREADY carrying more Heat than the tier tolerates; a Catastrophic books at
## every tier regardless.
##
## The direction is the point, and it is easy to get backwards: the BIGGER the
## job, the LESS existing Heat it takes to turn a blown attempt into an arrest.
## A fumbled pocket-pick at Heat 11 is a bad night; a fumbled tier-3 job at Heat 9
## is a case.
##
## FS-003.13 Task 3 raises every tier by 2. The authored 10/8/6 was written
## before District Pressure existed; once Pressure saturates, the projected
## success chance falls, failures multiply, and Heat sits above 6 for most of a
## working week — so the tier-3 gate was open essentially all the time and the
## aggressive profile booked 15 times in 29 days. The gate is supposed to ask
## "were you already hot when you tried this", not "have you been playing".
## 12/10/8 keeps the same shape against a Heat scale whose realistic working
## band moved up.
const STICK_FAILURE_ARREST_HEAT := {1: 12.0, 2: 10.0, 3: 8.0}

## FS-003.13 Task 3. Days after an arrest during which no arrest gate may fire.
##
## The fiction is the whole justification: the player was in booking hours ago,
## with the same precinct, and the same officers are not picking them up again
## on the way out of the parking lot. The mechanical job is spacing — before
## this, a bad week was one continuous booking period with no gaps in it, and a
## consequence that never stops is a tax rather than an escalation.
##
## Counted from the day the booking COMMITTED (the day the record was written),
## not from release: release time varies with the lane the player chose, and
## tying the cooldown to it would quietly reward serving over paying with extra
## immunity. `arrest_cooldown_until` turns that day into the stored deadline.
const ARREST_COOLDOWN_DAYS := 2

## The day the cooldown stops covering, given the day an arrest was booked.
func arrest_cooldown_until(booked_day: int) -> int:
	return booked_day + ARREST_COOLDOWN_DAYS

## Whether an arrest gate is suppressed today.
##
## `cooldown_until_day` is the stored deadline, or -1 for a run that has never
## been booked — which is why the sentinel is checked rather than assumed to be
## smaller than any real day. `today <= deadline` is inclusive: a booking on day
## 7 covers days 7, 8 and 9, and the player is exposed again on day 10.
func arrest_suppressed(today: int, cooldown_until_day: int) -> bool:
	if cooldown_until_day < 0:
		return false
	return today <= cooldown_until_day

## The one observation an arrest files, TI-003 §13 step 6.
##
## AUTHORED HERE, stated rather than inferred: FS-003 §7 says only "an arrest
## writes an Exposure observation through the existing propagation rules only
## where an authored observer/channel qualifies" and never names the row. This
## is that row.
##
##   - `heat_exposure` because that is exactly what an arrest is to the people
##     around you, and because it is the one category whose existing weights
##     already price "you brought police attention into my life" correctly
##     (Yalonda -3.0, Mina -1.5).
##   - `neighborhood` because an arrest is public and slow: it reaches the
##     household and the block over a day, not instantly and not through
##     Curtis's network ear. `heat_exposure` is not in
##     `CURTIS_NETWORK_CATEGORIES`, so routing it wider would still not reach
##     him — the channel choice is about Yalonda, Juan and Mina, and it is a day
##     late on purpose.
const ARREST_OBSERVATION := {
	"type": "heat_exposure", "event": "arrested", "channel": "neighborhood",
}

# --- arrest lookups ---------------------------------------------------------

func severity_row(severity_id: String) -> Dictionary:
	return ARREST_SEVERITIES.get(severity_id, ARREST_SEVERITIES[SEVERITY_GENERIC])

## Boost tiers 2 and 3 share one severity — see the section header.
func severity_for_boost(boost_tier: int) -> String:
	return SEVERITY_BOOST_T1 if clampi(boost_tier, 1, 3) <= 1 else SEVERITY_BOOST_T2

func severity_for_stick(stick_tier: int) -> String:
	match clampi(stick_tier, 1, 3):
		1: return SEVERITY_STICK_T1
		2: return SEVERITY_STICK_T2
	return SEVERITY_STICK_T3

func severity_for(family: String, tier: int) -> String:
	match family:
		"boost": return severity_for_boost(tier)
		"stick", "stickup": return severity_for_stick(tier)
	return SEVERITY_GENERIC

func base_bail(severity_id: String) -> int:
	return int(severity_row(severity_id).get("bail", 0))

func base_processing_slots(severity_id: String) -> int:
	return int(severity_row(severity_id).get("processing", 0))

func heat_relief(severity_id: String) -> float:
	return float(severity_row(severity_id).get("relief", 0.0))

func severity_label(severity_id: String) -> String:
	return str(severity_row(severity_id).get("label", ""))

func bail_multiplier(priors: int) -> float:
	var index: int = clampi(priors, 0, PRIOR_BAIL_MULTIPLIERS.size() - 1)
	return PRIOR_BAIL_MULTIPLIERS[index]

## The quote, rounded to a dollar. Priors are the count BEFORE this booking —
## your first arrest is priced at 1.00x, not 1.50x.
func bail_quote(severity_id: String, priors: int) -> int:
	return int(round(float(base_bail(severity_id)) * bail_multiplier(priors)))

## Processing time for a fully-paid bail: the severity's base plus the prior
## adjustment, capped.
func processing_slots(severity_id: String, priors: int) -> int:
	var extra: int = int(floor(float(maxi(0, priors)) / float(PRIORS_PER_EXTRA_SLOT)))
	return mini(base_processing_slots(severity_id) + extra, MAX_BOOKING_SLOTS)

## Time bought by money you did not have. `ceil(shortfall / 150)`.
func shortfall_slots(shortfall: int) -> int:
	if shortfall <= 0:
		return 0
	return int(ceil(float(shortfall) / float(SHORTFALL_DOLLARS_PER_SLOT)))

## Total slots held, which is what the player is actually deciding between.
##
## The cap is applied to the TOTAL rather than to the prior adjustment alone.
## FS-003 §7 states it twice — once under Post Available Cash and once under
## Serve — and it is the rule that keeps TI-003 regression #14 ("a broke player
## loses every legal Booking option") from being true in practice: serving is
## always available and can never cost more than four slots.
func total_booking_slots(severity_id: String, priors: int, shortfall: int) -> int:
	return mini(processing_slots(severity_id, priors) + shortfall_slots(shortfall),
		MAX_BOOKING_SLOTS)

## Whether a blown Stick books, TI-003 §14. `pre_source_heat` is the Heat the
## player was already carrying when they walked up — never the Heat this robbery
## just generated, or the robbery would decide its own arrest.
func stick_arrests(stick_tier: int, tier_name: String, pre_source_heat: float) -> bool:
	if tier_name == "catastrophic":
		return true
	if tier_name != "failure":
		return false
	var gate: float = float(STICK_FAILURE_ARREST_HEAT.get(clampi(stick_tier, 1, 3), 10.0))
	return pre_source_heat > gate

# --- District Pressure (TI-003 §8, FS-003 §6) ------------------------------
#
# Pressure answers one question: *how recognizable has this criminal pattern
# become in this part of the city?* It is not Global Heat and it never converts
# into it. Heat is how urgently police want you today; Pressure is whether the
# people on this block have started to recognise the routine.
#
# Per district, per criminal family, 0 to 9.

const FAMILY_MARKET := "market"
const FAMILY_BOOST := "boost"
const FAMILY_STICK := "stick"
const PRESSURE_FAMILIES: Array[String] = [FAMILY_MARKET, FAMILY_BOOST, FAMILY_STICK]

## FS-003 §6: "Each district/family score ranges from 0 to 9."
const PRESSURE_MAX := 9.0
const PRESSURE_MIN := 0.0

const BAND_QUIET := "QUIET"
const BAND_KNOWN := "KNOWN"
const BAND_WATCHED := "WATCHED"
const BAND_HOT := "HOT"

## TI-003 §8's band mapping, with FS-003 §6's difficulty steps already resolved
## into percentage points: "One difficulty step is 8 percentage points off the
## source action's success chance before its existing clamp. Maximum dynamic
## local penalty: 24 percentage points."
##
## Read HIGHEST FIRST by `pressure_band`, so the `HOT` row's `min` of 9.0 is
## reached only at the cap — FS-003 writes that row as `9` exactly, not `8+`.
const PRESSURE_BANDS: Array[Dictionary] = [
	{"min": 9.0, "band": BAND_HOT, "penalty": 0.24, "steps": 3},
	{"min": 6.0, "band": BAND_WATCHED, "penalty": 0.16, "steps": 2},
	{"min": 3.0, "band": BAND_KNOWN, "penalty": 0.08, "steps": 1},
	{"min": 0.0, "band": BAND_QUIET, "penalty": 0.00, "steps": 0},
]

## FS-003 §6: a clean initial Boost success adds +0.5 Boost pressure. A FAILED
## lift adds nothing here — it waits for the Caught encounter's resolved tier,
## which is what `PRESSURE_BY_TIER` above already covers.
const PRESSURE_BOOST_SUCCESS := 0.5

## FS-003 §6: "A completed criminal market sale adds +0.25 Market pressure,
## capped at +1 Market pressure per district per day from ordinary sales."
##
## Selling only. Buying product is not what makes a corner recognisable — the
## repeated handoff is.
const PRESSURE_MARKET_SALE := 0.25
const PRESSURE_MARKET_DAILY_CAP := 1.0

## FS-003 §6: "New local pressure bleeds once to adjacent current districts at
## 50% of the new gain on the next day-cross." The NEW GAIN, not the stored
## score — regression #17 in spirit: the whole score never copies outward again.
const PRESSURE_BLEED_FRACTION := 0.5

## FS-003 §6's active adjacency. Downtown and Industrial have no direct edge in
## the current three-district map, which is why this is authored rather than
## derived from "every other district".
const DISTRICT_ADJACENCY := {
	"north_star_lot": ["downtown", "airport_industrial"],
	"downtown": ["north_star_lot"],
	"airport_industrial": ["north_star_lot"],
}

## FS-003 §6's recovery rule, retuned by FS-003.13 Task 2.
##
## As authored, recovery was −1.0 per quiet day starting on the SECOND
## consecutive quiet day, against a single messy outcome worth +1.0. A player
## working one district daily therefore outran decay permanently: FS-003.12's
## aggressive profile spent 19 of 29 days at HOT, which makes HOT the resting
## state and QUIET the anomaly. A band that is always on is not a warning.
##
## Three levers move, and each answers a different half of that:
##
##   - the grace day is GONE. TI-003 regression #18 ("first quiet day decays
##     Pressure early") was written against the authored rule, and the rule is
##     what changed: laying off a district now shows up the next morning rather
##     than the morning after. The regression's real content — that a day with
##     a gain on it is not a quiet day — is unchanged and still enforced by
##     `last_gain_day`, which is the check that actually stops early decay.
##   - the ordinary rate is 1.5, so three quiet days clear a full band rather
##     than three days clearing one point of a nine-point scale.
##   - HOT decays FASTER than the rest of the scale, at 2.0. A district in
##     crisis is the one the player most needs a way out of, and a flat rate
##     makes the top of the scale the hardest place to leave. Four quiet days
##     now take a HOT district (9.0) to 3.0 — HOT to KNOWN — which is the
##     "counterplay produces visible results within a week" the tuning brief
##     asks for.
##
## Set to 0 rather than deleted: the grace mechanism stays expressed, so
## restoring a hold day is a constant change rather than a code change.
const PRESSURE_QUIET_GRACE_DAYS := 0
const PRESSURE_QUIET_RECOVERY := 1.5
## The accelerated rate, applied while the score is still in the band named by
## `PRESSURE_ACCELERATED_FROM_BAND` at the moment recovery is computed.
const PRESSURE_ACCELERATED_RECOVERY := 2.0
## Which band decays fast. Named as the band rather than as a score so it tracks
## `PRESSURE_BANDS` if the band edges ever move.
const PRESSURE_ACCELERATED_FROM_BAND := BAND_HOT

# --- Financial Pressure rollover (TI-003 §17, FS-003 §8) -------------------
#
# The GAIN side lives in `systems/wallet.gd` beside the spend that produces it —
# the wallet is the only thing that can see a transaction's dirty portion, and
# splitting the formula from the only caller that can evaluate it would buy
# nothing. What lives here is the ROLLOVER, which the day lifecycle owns.

## TI-003 §17, post-increment: `financial_pressure = max(0, financial_pressure - 1)`.
const FINANCIAL_PRESSURE_DECAY := 1
## Then, on what REMAINS: "if financial_pressure >= FOLD_AT: apply_direct(+1)".
##
## The order is load-bearing and both halves are on TI-003's regression list:
## #25 is folding before the decay, #26 is Exposure propagating morning Heat
## before the fold. Decay, then fold, then Exposure — see `day_lifecycle.gd`.
## Neither ordering moves here; only the threshold does.
##
## FS-003.13 Task 4 lowers it from 6 to 4. Against a decay of one point a day,
## a fold at 6 needed the meter to gain six points faster than it lost them, and
## the gain side only moved on a large formal payment. Four is reachable from
## two bails in a week, which is the scenario the mechanic was authored for:
## paying your way out of trouble with money that cannot explain itself.
const FINANCIAL_PRESSURE_FOLD_AT := 4
const FINANCIAL_PRESSURE_FOLD_HEAT := 1.0

# --- pressure lookups ------------------------------------------------------

## The band a score falls in. Walks highest-first, so `HOT` needs the full 9.
func pressure_band(score: float) -> String:
	for row in PRESSURE_BANDS:
		if score >= float((row as Dictionary)["min"]):
			return str((row as Dictionary)["band"])
	return BAND_QUIET

## Percentage points off a source action's success chance, BEFORE its clamp.
func pressure_penalty(score: float) -> float:
	for row in PRESSURE_BANDS:
		if score >= float((row as Dictionary)["min"]):
			return float((row as Dictionary)["penalty"])
	return 0.0

## Difficulty steps, for anything that wants the band's rank rather than its cost.
func pressure_steps(score: float) -> int:
	for row in PRESSURE_BANDS:
		if score >= float((row as Dictionary)["min"]):
			return int((row as Dictionary)["steps"])
	return 0

## Points a quiet day takes off a score, read from the score itself.
##
## Read BEFORE the subtraction, so a district sitting at 9.0 takes the full
## accelerated step down to 7.0 and only then rejoins the ordinary rate. Reading
## it after would make the accelerated rate unreachable at every score that is
## not exactly the band floor, which is the quiet way this tuning would have
## done nothing.
func quiet_recovery(score: float) -> float:
	if pressure_band(score) == PRESSURE_ACCELERATED_FROM_BAND:
		return PRESSURE_ACCELERATED_RECOVERY
	return PRESSURE_QUIET_RECOVERY

func adjacent_districts(district_id: String) -> Array:
	return (DISTRICT_ADJACENCY.get(district_id, []) as Array).duplicate()

# --- Retaliation (TI-003 §§15-16, FS-003 §9) -------------------------------
#
# The one delayed consequence in the first slice: people you robbed sending
# somebody after you, days later, in the district it happened in.
#
# It is deliberately NOT a second punishment roll bolted onto a bad result. A
# robbery that goes wrong has already cost what it cost. Retaliation is the
# separate fact that a register belongs to somebody, and that somebody heard.

const RETALIATION_DEFINITION := "retaliation_street_crew"

## TI-003 §15's window. Trigger on cause day + 2, expire at the end of + 5.
##
## The gap is the design: two days is long enough that the player has moved on,
## three more is short enough that leaving the district is real counterplay
## rather than a formality.
const RETALIATION_TRIGGER_DELAY := 2
const RETALIATION_EXPIRY_DELAY := 5
## FS-003 §10: "only one generic retaliation scene from this queue surfaces per
## day in the first slice."
const RETALIATION_DAILY_CAP := 1

# --- ambient signals (PX-003 §8, FS-003.13 Task 5) -------------------------
#
# Avoidance is the whole counterplay for a queued retaliation, and before this
# nothing told the player a threat was live. FS-003.12 measured the result:
# three profiles, zero expirations, because none of them had any reason to
# leave. A counterplay nobody can see is not a choice, it is a coin flip that
# happens to be weighted.
#
# What this adds is a SIGNAL, not information. PX-003 §8 is explicit that the
# expiry window stays hidden: the player learns that trouble is nearby and that
# it stopped when they stopped going back. They are never told when, or by whom,
# or how many days are left. Every line below is written to survive that
# constraint — none of them counts down, names the actor, or changes as the
# window closes, because a line that got more urgent WOULD be a countdown.

## The day offset the first ambient warning can land on, relative to the day the
## threat was scheduled. +1: the night it happened is not ambient, it is the
## thing that happened.
const RETALIATION_AMBIENT_FROM_DAY := 1
## At most one ambient warning reaches the feed per day, however many rows are
## live. Two people asking about you is one fact, not two.
const RETALIATION_AMBIENT_DAILY_CAP := 1

## The authored lines. Picked by seeded RNG keyed on the row and the day, so a
## reload shows the same line rather than rerolling the atmosphere.
const RETALIATION_AMBIENT_LINES: Array[String] = [
	"Two people asked about you near the strip today.",
	"Same car passed the lot twice.",
	"Somebody was describing you to the guy at the counter.",
	"A face you half-recognise has been on this block all week.",
	"Someone asked which building was yours. Nobody answered.",
]

## The one-time Phone callback on the first threat a run ever avoids into expiry.
##
## Once per RUN, not once per threat: it exists to teach that leaving works, and
## a lesson repeated every time it applies is a notification, not a lesson.
## `%s` takes the district's prose name.
const RETALIATION_EXPIRY_CALLBACK := "The people asking around %s stopped showing up."
## Who the callback comes from. Not a crew member: the callback fires whether or
## not anybody is recruited, and attributing it to Tone would claim a lookout the
## player may never have hired. The district itself is the honest sender, and it
## matches the area-scoped shape the phone's intel lines already use.
const RETALIATION_EXPIRY_CALLBACK_FROM := "Word around %s"

## TI-003 §15's qualifying Stick outcomes. Plain Failure schedules nothing —
## FS-003 §9 words it as "a successful or loud qualifying hit", and a plain
## failure is neither. You did not take their money and you did not make a scene.
const RETALIATION_QUALIFYING_TIERS: Array[String] = ["clean", "messy", "catastrophic"]

## TI-003 §15's schedule chances, by source target.
##
## `actor_id` is the dedupe half of §15's `(actor_id, cause_id)` key. TI-003
## names only Goodie's (`goodie`); the other three are AUTHORED HERE, derived
## from the target so they are stable, unique, and legible in a save. Naming
## them after the target is what makes "the same crew cannot come twice for the
## same night" true without a lookup table nobody maintains.
##
## A target absent from this table is TI-003's "Tier 1 default 0.00": ordinary
## street marks have nobody standing behind them.
const RETALIATION_SCHEDULE := {
	"spenard_fuel_till": {
		"chance": 0.60, "actor_id": "till_crew_spenard",
		"actor_label": "The people behind the Chevron till",
	},
	"downtown_fuel_till": {
		"chance": 0.60, "actor_id": "till_crew_downtown",
		"actor_label": "The people behind the Holiday register",
	},
	"rec_center_dice": {
		"chance": 0.60, "actor_id": "dice_crew",
		"actor_label": "The dice game's people",
	},
	"goodie_stash": {
		"chance": 1.00, "actor_id": "goodie",
		"actor_label": "Goodie's people",
	},
}

## TI-003 §16. **Talk is absent, and that is the definition rather than an
## omission**: these actors arrive to collect or to punish, and there is nobody
## to negotiate with. Fight, Run, or hand it over.
const RETALIATION_CHOICES: Array[String] = ["fight", "run", "yield"]
const RETALIATION_DETERMINISTIC: Array[String] = ["yield"]
const RETALIATION_RESOLVERS := {"fight": "confrontation", "run": "escape"}
const RETALIATION_BASE_CHANCE := {"fight": 0.35, "run": 0.50}

## TI-003 §16's three effect tables, transcribed.
##
## `health` is a FLAT loss, not a band — §16 gives one number per row, so nothing
## here rolls for damage. TI-003's key list reserves a `:injury` RNG key for this
## definition; it is deliberately unused, because rolling a band the design does
## not have would be inventing a value.
##
## `cash_pct` / `cash_cap` read the DIRTY bucket only (§16: "Cash loss reads the
## Dirty bucket only... Clean Cash remains untouched by this retaliation
## definition"). They take what you took.
const RETALIATION_EFFECTS := {
	"fight": {
		"clean":        {"health": 1, "cash_pct": 0.00, "cash_cap": 0,   "heat": 1.0, "pressure": 0.5},
		"messy":        {"health": 2, "cash_pct": 0.00, "cash_cap": 0,   "heat": 2.0, "pressure": 1.0},
		"failure":      {"health": 3, "cash_pct": 0.40, "cash_cap": 300, "heat": 1.0, "pressure": 1.0},
		"catastrophic": {"health": 4, "cash_pct": 0.60, "cash_cap": 500, "heat": 2.0, "pressure": 2.0},
	},
	"run": {
		"clean":        {"health": 0, "cash_pct": 0.00, "cash_cap": 0,   "heat": 0.0, "pressure": 0.5},
		"messy":        {"health": 1, "cash_pct": 0.00, "cash_cap": 0,   "heat": 1.0, "pressure": 0.5},
		"failure":      {"health": 2, "cash_pct": 0.40, "cash_cap": 300, "heat": 1.0, "pressure": 1.0},
		"catastrophic": {"health": 3, "cash_pct": 0.60, "cash_cap": 500, "heat": 2.0, "pressure": 1.0},
	},
	# The known price. Worse cash than a clean fight, better than a lost one, and
	# nobody rolls anything.
	"yield": {
		"deterministic": {"health": 2, "cash_pct": 0.50, "cash_cap": 400, "heat": 0.0, "pressure": 0.5},
	},
}

# --- retaliation lookups ---------------------------------------------------

func retaliation_row(target_id: String) -> Dictionary:
	return RETALIATION_SCHEDULE.get(target_id, {})

## The chance this target's people come looking, for this resolved tier.
##
## Zero for an unlisted target and zero for a plain Failure, which are two
## different reasons and both matter: an ordinary street mark has nobody behind
## them, and a fumbled attempt gave nobody a reason.
func retaliation_chance(target_id: String, tier_name: String) -> float:
	if not tier_name in RETALIATION_QUALIFYING_TIERS:
		return 0.0
	return float(retaliation_row(target_id).get("chance", 0.0))

func retaliation_actor_id(target_id: String) -> String:
	return str(retaliation_row(target_id).get("actor_id", ""))

func retaliation_actor_label(target_id: String) -> String:
	return str(retaliation_row(target_id).get("actor_label", "Somebody"))

func retaliation_is_deterministic(choice_id: String) -> bool:
	return choice_id in RETALIATION_DETERMINISTIC

func retaliation_resolver_for(choice_id: String) -> String:
	return str(RETALIATION_RESOLVERS.get(choice_id, ""))

func retaliation_base_chance(choice_id: String) -> float:
	return float(RETALIATION_BASE_CHANCE.get(choice_id, 0.0))

func retaliation_effects(choice_id: String, tier_name: String) -> Dictionary:
	var by_choice: Dictionary = RETALIATION_EFFECTS.get(choice_id, {})
	if choice_id == "yield":
		return by_choice.get("deterministic", {})
	return by_choice.get(tier_name, {})

## What this outcome takes, given what the player is actually holding.
##
## Reads the Dirty balance and nothing else. If the percentage lands above the
## cap the cap wins; if the player is carrying less dirty money than either, they
## lose what they have. Clean Cash is never reachable from here — TI-003
## regression #39.
func retaliation_cash_loss(choice_id: String, tier_name: String, dirty_balance: int) -> int:
	var row: Dictionary = retaliation_effects(choice_id, tier_name)
	var pct: float = float(row.get("cash_pct", 0.0))
	if pct <= 0.0 or dirty_balance <= 0:
		return 0
	var cap: int = int(row.get("cash_cap", 0))
	var wanted: int = int(round(float(dirty_balance) * pct))
	if cap > 0:
		wanted = mini(wanted, cap)
	return clampi(wanted, 0, dirty_balance)

# --- Player-facing presentation (TI-003 §19, PX-003 §§4-7) -----------------
#
# The numbers underneath stay underneath. What the player reads is a situation.
#
# This section is authored data like everything else in this file: the bands a
# probability is described with, and the risk categories a response carries, are
# design decisions rather than rendering details, and a screen that invented its
# own would be a second design document nobody reviewed.

## Qualitative odds bands, read highest-first.
##
## FS-003.11's brief: "Use qualitative labels derived from exact probability. Do
## NOT show raw percentages. The numbers exist underneath; the player reads
## situations."
##
## The bands are deliberately uneven. The gap between 70% and 60% changes what a
## player does; the gap between 20% and 10% does not — both are "this is going to
## hurt", and splitting them finely would imply a precision the player cannot
## act on. So the top of the range is described more finely than the bottom.
const ODDS_BANDS: Array[Dictionary] = [
	{"min": 0.75, "label": "STRONG CHANCE", "rank": 4},
	{"min": 0.55, "label": "FAIR CHANCE", "rank": 3},
	{"min": 0.35, "label": "RISKY", "rank": 2},
	{"min": 0.15, "label": "BAD ODDS", "rank": 1},
	{"min": 0.00, "label": "DESPERATE", "rank": 0},
]

## What a deterministic response reads as. Not an odds band: showing Yield as 0%
## would say "impossible" when it means the opposite.
const ODDS_CERTAIN := "CERTAIN"

## Arrest-risk categories a response can carry, as codes rather than copy.
##
## PX-003 §19 point 8: "Known arrest conditions are surfaced before commitment. A
## player should not discover a deterministic Heat/Tier booking gate only after
## choosing Run." And §11 keeps the exact threshold hidden — the player is told
## THAT this can book them, never at what number.
const ARREST_RISK_NONE := ""
## Any bad outcome ends in cuffs.
const ARREST_RISK_ON_LOSS := "on_loss"
## Only the worst outcome does.
const ARREST_RISK_WORST_ONLY := "worst_only"
## A failed escape books because of the Heat already on the meter.
const ARREST_RISK_HEAT := "heat"
## A failed escape books because of what this target is.
const ARREST_RISK_TARGET := "target"

# --- presentation lookups --------------------------------------------------

func odds_label(probability: float) -> String:
	for row in ODDS_BANDS:
		if probability >= float((row as Dictionary)["min"]):
			return str((row as Dictionary)["label"])
	return str((ODDS_BANDS[ODDS_BANDS.size() - 1] as Dictionary)["label"])

## 0 (worst) to 4 (best), for a screen that wants to colour the label without
## re-deriving the bands or looking at the raw probability itself.
func odds_rank(probability: float) -> int:
	for row in ODDS_BANDS:
		if probability >= float((row as Dictionary)["min"]):
			return int((row as Dictionary)["rank"])
	return 0

## Which arrest warning a Caught response carries, given the situation it is
## being offered in.
##
## Derived from the authored effect table rather than restated, so a balance edit
## to `CAUGHT_EFFECTS` moves the warning with it. A warning that had to be kept
## in sync by hand would eventually tell the player the wrong thing, which is
## worse than telling them nothing.
func caught_arrest_risk(choice_id: String, boost_tier: int,
		pre_encounter_heat: float) -> String:
	if is_deterministic(choice_id):
		return ARREST_RISK_NONE
	var arresting: Array = []
	for tier_name in ["clean", "messy", "failure", "catastrophic"]:
		if arrests(choice_id, str(tier_name), boost_tier, pre_encounter_heat):
			arresting.append(str(tier_name))
	if arresting.is_empty():
		return ARREST_RISK_NONE
	if not "failure" in arresting:
		return ARREST_RISK_WORST_ONLY
	if choice_id == "run":
		# Run/Failure is the one conditional row, and the player deserves to know
		# WHICH condition made it true — "this target" is something they chose
		# and can choose differently; "your Heat" is something they carry.
		if clampi(boost_tier, 1, 3) >= RUN_FAILURE_ARREST_TIER:
			return ARREST_RISK_TARGET
		return ARREST_RISK_HEAT
	return ARREST_RISK_ON_LOSS

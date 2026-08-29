extends RefCounted
## HeatSystem — the single runtime path for every Heat mutation.
##
## TI-003 §7. Five lines wrote `gs.heat` before this, and four of them fetched
## `crew.heat_multiplier()` themselves — two of those four by way of a
## `_apply_heat()` helper that existed IDENTICALLY, character for character, in
## both `stickup.gd` and `boost.gd`.
##
## Two copies of a scaling rule is the shape of a bug that has not happened yet.
## This file is the one copy.
##
## ## The pipeline, and the one thing that must not go through it
##
## TI-003 §7 declares the criminal gain pipeline:
##
##     raw Heat
##       x district/family multiplier
##       x current Deshawn multiplier
##       -> clamp 0..15
##
## and then, immediately after: "Relief bypasses district and Deshawn gain
## multipliers."
##
## That is not a detail. Deshawn reduces the heat your crimes generate; running
## relief through his multiplier would mean having him on the crew makes Lay Low
## work LESS well, which inverts his entire purpose. `apply_relief` therefore
## does not touch `_gain_multiplier()` at all — not "multiplies by 1.0 for
## relief", genuinely does not call it. TI-003's regression list has this at #15.
##
## ## Deshawn applies exactly once
##
## The acceptance criterion, and the real risk in this migration: if HeatSystem
## applies the multiplier AND a migrated caller still applies its own, Deshawn
## double-counts. So every caller migrated in this slice had its own
## `crew.heat_multiplier()` lookup DELETED, not left in place — the two
## `_apply_heat` helpers are gone, and `shark.gd` and `territory.gd` no longer
## fetch a multiplier at all. `apply_gain` is now the only site in the codebase
## that calls `heat_multiplier()`, which is what makes "once" checkable by
## grep as well as by test. TI-003's regression list has this at #21.
##
## ## Heat is fractional, and rounding it is a shipped bug
##
## `gs.heat` is a float on purpose. Boost tier 1 generates 0.5, and an earlier
## build's int-typed helper truncated that to 0 — the call site then rounded up
## to 1, so every tier-1 lift made DOUBLE canon's heat, on the surface a player
## touches earliest and most. FS-003.1 froze that with a named assertion and
## FS-001.8 fixed it. Nothing in this file rounds.
##
## ## The district/family table, live as of FS-003.9
##
## TI-003 §7 authors a district x family multiplier table. FS-003.3 shipped it
## as authored, pure, tested data that `apply_gain` deliberately did NOT consult,
## because applying it inside a refactor whose acceptance criterion was "current
## source outcomes preserve inherited totals" would have been a balance change
## smuggled into a no-op.
##
## FS-003.9 is where it belongs, beside District Pressure (§8), and this is where
## it was turned on. Every criminal Heat gain is now scaled by where it happened
## and what kind of crime it was: a robbery in Spenard is 1.3x, the same robbery
## downtown is 1.0x, and market work in Spenard is 0.8x. Criminal geography
## finally costs something.
##
## The numbers this moved are named in the FS-003.9 HANDOFF section rather than
## discovered by whoever next reads a Heat assertion and finds it changed.

## TI-003 §7 criminal families. The string a caller passes for `family`.
## Activity-feed colours. Same values every other system uses; declared here
## rather than reached for because a RefCounted has no shared base to hold them.
const GREEN := Color(0.451, 0.722, 0.404)
const AMBER := Color(0.882, 0.651, 0.227)
const RED := Color(0.827, 0.161, 0.125)

const FAMILY_MARKET := "market"
const FAMILY_BOOST := "boost"
const FAMILY_STICK := "stick"

## Heat that belongs to none of TI-003 §7's three families — holding corners is
## the standing example, and `territory.gd` passes it by name now rather than by
## passing `""` and hoping (86bbjxtbm).
##
## It scales by Deshawn and by nothing else. That has always been the BEHAVIOUR,
## and it was an accident: `district_multiplier()` looks the family up in the
## district's row and defaults a miss to 1.0, so an empty family missed every
## row and returned neutral. The day somebody gives that lookup a sensible
## default — the district's own average, say, which is the obvious thing to
## reach for — corner heat silently starts scaling by wherever the player
## happened to be standing at midnight. Nothing would have failed.
##
## So the exemption is a rule with a name and a guard in `_gain_multiplier()`
## rather than a property of a missing dictionary key.
const FAMILY_NONE := ""

## TI-003 §7's district/family multiplier table, verbatim.
##
## District ids are this port's, mapped from TI-003's names:
##   Spenard    -> north_star_lot
##   Downtown   -> downtown
##   Industrial -> airport_industrial
##
## A district or family absent from this table scales by 1.0. That is what
## carries shark enforcement and territory's nightly corner heat, neither of
## which TI-003 assigns a family — they keep exactly the scaling they have
## today, which is none.
const DISTRICT_FAMILY_MULTIPLIERS := {
	"north_star_lot": {FAMILY_MARKET: 0.8, FAMILY_BOOST: 0.9, FAMILY_STICK: 1.3},
	"downtown": {FAMILY_MARKET: 1.2, FAMILY_BOOST: 1.1, FAMILY_STICK: 1.0},
	"airport_industrial": {FAMILY_MARKET: 1.1, FAMILY_BOOST: 1.2, FAMILY_STICK: 1.2},
}

const NEUTRAL_MULTIPLIER := 1.0

## The four bands (batch 8), and the reason each boundary is where it is.
##
## Heat has run 0-15 since the port began with no vocabulary at all — no bands,
## no names, nothing that told the player which part of the scale they were on.
## District Pressure has had QUIET/KNOWN/WATCHED/HOT since FS-003.9 and Heat has
## had a bare float.
##
## **None of these numbers are new.** Every boundary is a threshold the build
## already acted on and never named:
##   4.0  the job interview penalty starts biting (jobs.gd:91)
##   8.0  Exposure starts telling the household (exposure.gd:145)
##  12.0  Exposure starts telling the network (exposure.gd:144)
## Naming them is the whole change: the band the player can feel and the band
## that costs them are now provably the same band, and a test can say so.
const BAND_COOL := "COOL"
const BAND_NOTICED := "NOTICED"
const BAND_WATCHED := "WATCHED"
const BAND_BURNING := "BURNING"

## Highest floor first — the same shape as `AttributesSystem.LABEL_TIERS`, and
## read the same way.
const BANDS := [
	{"floor": 12.0, "band": BAND_BURNING},
	{"floor": 8.0, "band": BAND_WATCHED},
	{"floor": 4.0, "band": BAND_NOTICED},
	{"floor": 0.0, "band": BAND_COOL},
]

const RULES := preload("res://data/consequence_rules.gd")

var gs: Node
var gm: Node

## LIVE as of FS-003.9. See the file header for why it was false until then, and
## the FS-003.9 section of HANDOFF.md for what flipping it changed.
##
## Kept as a variable rather than inlined so a test can turn it off and measure
## the unscaled pipeline directly — which is what proves the multiplier is being
## applied rather than baked into a number that happens to match.
var _district_scaling_enabled := true

## How many street stops this BOOT has settled, and what they took.
##
## Diagnostic only, and deliberately not persisted: it lives on the system
## handle, which is rebuilt on every boot including after a load, so it is a
## fact about this process rather than about the run. The economy instrument
## reads it as a delta across a profile — a counter that survived a save would
## make every profile after the first report the ones before it too.
##
## The alternative was having the instrument infer stops from a cash drop across
## a day boundary, which is indistinguishable from rent.
var stops_settled: int = 0
var stops_seized: int = 0

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

## No player action of its own — Heat is always a consequence.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The heat system takes no actions."}

# --- reads ------------------------------------------------------------------

func level() -> float:
	return float(gs.heat)

func ceiling() -> float:
	return float(gs.heat_max)

## Which band a Heat level falls in. Pure, so a screen can ask about a level it
## is projecting rather than only the one it is standing in.
func band_for(level_value: float) -> String:
	for row in BANDS:
		if level_value >= float(row["floor"]):
			return str(row["band"])
	return BAND_COOL

func band() -> String:
	return band_for(float(gs.heat))

## True when the day so far has generated Heat. The quiet-day decay rule reads
## this and nothing else.
func loud_today() -> bool:
	return float(gs.heat_gain_today) > 0.0

## TI-003 §7's authored table, as a pure lookup. Consulted by `apply_gain` only
## once FS-003.9 enables it; covered by tests now so the values are pinned.
func district_multiplier(district_id: String, family: String) -> float:
	var row: Variant = DISTRICT_FAMILY_MULTIPLIERS.get(district_id)
	if not (row is Dictionary):
		return NEUTRAL_MULTIPLIER
	return float((row as Dictionary).get(family, NEUTRAL_MULTIPLIER))

## Deshawn's reduction, read through Crew, which owns it (TI-003 §26: "Crew owns
## Deshawn's Heat multiplier"). Returns 1.0 when he is not on the crew, so this
## multiplies unconditionally.
##
## The ONLY call site of `heat_multiplier()` outside crew.gd itself. That is the
## "applies once" guarantee, and it is grep-checkable.
func crew_multiplier() -> float:
	var crew: Object = gm.system("crew") if gm != null else null
	if crew == null:
		return NEUTRAL_MULTIPLIER
	return float(crew.heat_multiplier())

# --- writes -----------------------------------------------------------------

## Heat a crime generated, scaled by who is on the crew.
##
## `raw_amount` is the heat before any scaling — the number the source's own
## table says the act is worth. Returns the delta actually applied, which is
## what every caller logs, and which is NOT `raw_amount` whenever Deshawn is
## working or the clamp bites.
##
## A non-positive raw amount applies nothing and returns 0.0. Gain is for gain;
## a negative "gain" is a caller reaching for `apply_relief` by the wrong name.
func apply_gain(raw_amount: float, family: String = "", district_id: String = "",
		_context: Dictionary = {}) -> float:
	if raw_amount <= 0.0:
		return 0.0
	var scaled: float = raw_amount * _gain_multiplier(family, district_id)
	return _commit(scaled)

## An authored Heat change that is not a crime's own output — TI-003 §7 names
## the Financial Pressure fold as the first caller (§17, FS-003.9's slice).
##
## Bypasses gain scaling in both directions: this is heat the world applied to
## you, not heat you generated, so Deshawn has nothing to damp. Takes a signed
## delta because "direct" covers both ways.
func apply_direct(delta: float, _context: Dictionary = {}) -> float:
	if delta == 0.0:
		return 0.0
	return _commit(delta)

## Heat coming off — Lay Low today, Booking and Recovery relief in later slices.
##
## Takes a POSITIVE amount and subtracts it, so no call site has to remember a
## sign. Bypasses every gain multiplier: see the file header for why running
## relief through Deshawn would invert him.
func apply_relief(amount: float, _context: Dictionary = {}) -> float:
	if amount <= 0.0:
		return 0.0
	return _commit(-amount)

## The one place `gs.heat` is written. Returns the delta that actually landed,
## which the clamp can make smaller than the one requested.
func _commit(delta: float) -> float:
	var before: float = float(gs.heat)
	gs.heat = clampf(before + delta, 0.0, float(gs.heat_max))
	var landed: float = float(gs.heat) - before
	# The quiet-day flag is stamped HERE, in the one place Heat is written, so
	# no future gain site can forget to raise it. It records the delta that
	# actually LANDED rather than the one requested: heat the clamp refused is
	# heat the world never saw, and a day at the ceiling should not be counted
	# loud on the strength of a gain that went nowhere.
	if landed > 0.0:
		gs.heat_gain_today = float(gs.heat_gain_today) + landed
	return landed

## The criminal gain pipeline's scaling half, TI-003 §7.
##
## Never called by `apply_direct` or `apply_relief`. That is the whole point of
## it being a separate function.
func _gain_multiplier(family: String, district_id: String) -> float:
	var mult: float = crew_multiplier()
	# No family, no district scaling — see `FAMILY_NONE`. Checked here rather
	# than left to the table's default so the exemption survives a future
	# default, and so this reads as the decision it is.
	if _district_scaling_enabled and family != FAMILY_NONE:
		mult *= district_multiplier(district_id, family)
	return mult


# --- the night (batch 8) -----------------------------------------------------

## The quiet-day rule. A day that generated no Heat sheds some; a day that
## generated any sheds nothing.
##
## Binary rather than proportional, and deliberately: the question the player is
## being asked is "can you afford a day off", and a rule that gave partial
## credit for a quiet afternoon would answer it with arithmetic instead of a
## decision. Same shape as District Pressure's quiet-day recovery, which has
## been the answer to the same question since FS-003.9.
##
## Returns the relief that landed, which is 0.0 on a loud day and on a run
## already at zero.
func settle_quiet_day() -> float:
	if loud_today():
		return 0.0
	if float(gs.heat) <= 0.0:
		return 0.0
	var shed: float = -_commit(-float(RULES.HEAT_QUIET_DECAY))
	if shed > 0.0:
		gs.log_activity("A day nobody had to hear about. Heat -%.2f." % shed, GREEN)
	return shed

## HEAT-D1 (0.3.0): the floor under the rule above. `settle_quiet_day` answers
## "did tonight generate anything" and sheds nothing the moment it did — which
## is correct for what IT measures, and is also why an every-day criminal
## profile (boost and stickup worked daily, at the parity economy profiles'
## own intensity) asymptoted at the ceiling with no way back down short of an
## arrest or a lucky street stop: a day that works the street is a day that
## generates SOMETHING, always, so the quiet-day rule never once fired for it
## across a measured 30-day run.
##
## This sheds a small amount EVERY night, loud or quiet, unconditionally — the
## property the ruling asks for ("Heat must asymptote below HOT's ceiling
## under sustained ordinary play") needs a floor under every night, not a
## bigger reward for the nights that were already the easy case. It runs
## ALONGSIDE `settle_quiet_day`, never instead of it: a quiet night sheds this
## amount PLUS its own (now larger) quiet bonus, so "a genuinely quiet day
## still sheds visibly more than an active one" keeps holding by construction
## rather than by coincidence.
##
## Returns the relief that landed, same contract as `settle_quiet_day`.
func settle_active_decay() -> float:
	if float(gs.heat) <= 0.0:
		return 0.0
	return -_commit(-float(RULES.HEAT_ACTIVE_DECAY))

## The street stop. One keyed roll a night, above the floor only.
##
## Takes DIRTY cash and only dirty cash — clean money is documented money, and a
## street stop is not a forfeiture hearing. Sheds Heat as it goes, because they
## have had their look and found what they found.
##
## No arrest. Arrest is owned by the two consequence chains that have booking
## stages and decision surfaces; giving Heat a third route into custody would
## mean a fourth chain kind, a stage table and a blocking encounter. That is a
## build, and the wrong first move for a number that until this batch did
## nothing at all at the top of its range.
func settle_street_stop(ended_day: int) -> Dictionary:
	var chance: float = float(RULES.heat_stop_chance(float(gs.heat)))
	if chance <= 0.0:
		return {}
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null:
		return {}
	# Day leads the key, per the v0.1.0 seeded-key audit: it is the component
	# that moves every time, and the district is the one that mostly does not.
	var key := "%d:heat_stop:%s" % [ended_day, str(gs.current_district_id)]
	if rng.seeded_random(gs.run_seed, key) >= chance:
		return {}

	var seized: int = int(RULES.heat_stop_seizure(int(gs.dirty_cash)))
	var wallet: Object = gm.system("wallet") if gm != null else null
	if seized > 0 and wallet != null:
		# ROUTINE drains dirty first, and the seizure is computed FROM dirty
		# cash, so it can never reach the clean pool. No new policy is needed
		# and inventing a DIRTY_ONLY one would be a fourth way to say this.
		wallet.spend(seized, wallet.ROUTINE_DIRTY_FIRST, {"source_id": "heat_stop"})
	var shed: float = -_commit(-float(RULES.HEAT_STOP_RELIEF))

	# Curtis reads a stop as exactly what it is. He is the lens that scores
	# heat_exposure hardest, and a search on the street is the most public
	# version of it there is.
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null:
		exposure.record_observation("curtis", {
			"type": "heat_exposure", "event": "stopped_and_searched",
			"source": "witnessed", "location": str(gs.current_district_id),
		})
	if seized > 0:
		gs.log_activity("Lights behind you on the way home. They took $%d and let you go."
			% seized, RED)
	else:
		gs.log_activity("Lights behind you on the way home. Nothing on you worth taking.",
			AMBER)
	stops_settled += 1
	stops_seized += seized
	return {"stopped": true, "seized": seized, "relief": shed, "chance": chance}

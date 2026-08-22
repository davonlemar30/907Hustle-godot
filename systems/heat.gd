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
const FAMILY_MARKET := "market"
const FAMILY_BOOST := "boost"
const FAMILY_STICK := "stick"

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

var gs: Node
var gm: Node

## LIVE as of FS-003.9. See the file header for why it was false until then, and
## the FS-003.9 section of HANDOFF.md for what flipping it changed.
##
## Kept as a variable rather than inlined so a test can turn it off and measure
## the unscaled pipeline directly — which is what proves the multiplier is being
## applied rather than baked into a number that happens to match.
var _district_scaling_enabled := true

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
	return float(gs.heat) - before

## The criminal gain pipeline's scaling half, TI-003 §7.
##
## Never called by `apply_direct` or `apply_relief`. That is the whole point of
## it being a separate function.
func _gain_multiplier(family: String, district_id: String) -> float:
	var mult: float = crew_multiplier()
	if _district_scaling_enabled:
		mult *= district_multiplier(district_id, family)
	return mult

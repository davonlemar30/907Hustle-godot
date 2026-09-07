extends RefCounted
## Recovery — patching yourself up, and going quiet for a night.
##
## Ported from the web build's `USE_FIRST_AID` / `HEAL` reducers
## (game-core.js:8778-8795), the `LAY_LOW` branch of advanceRun (5470-5474), and
## the `layLowPreview` / `treatmentCost` selectors (3801, 1294).
##
## Health has been a HUD stat since the first build with nothing in the game able
## to raise it. Stickup damage, sparring, and every future confrontation spend it
## and nothing gave it back. This is the other half of that.
##
## ## The shape of the ladder
##
## Three treatments, each revealed by how bad the damage actually is — canon's
## own subtitle says it: *"Essential care first; larger options appear when the
## damage justifies them."* You do not get shown the $290 option for a scrape.
##
## | treatment | restores | cost | appears at | time |
## |---|---|---|---|---|
## | First aid | 18 | $55 | always | **free** |
## | Clinic visit | 40 | $135 | health <= 82 | one slot |
## | No-Questions Doctor | 75 | $290 | health <= 55 | one slot |
##
## First aid costing no time is the load-bearing detail. It is the one thing you
## can do mid-crisis, which is what makes the expensive options a real decision
## rather than a formality.
##
## ## REST, and the quiet that used to be its own verb
##
## SO-D1/SO-D3 (1.6.0). Canon had a free rest at home (`SLEEP_HOME`,
## game-core.js:8764-8769) and the port dropped it, which is how the game
## arrived at 1.5.1 with health that only ever went down unless you paid. REST
## is that verb: **no money, one slot, +10 health.** It is the free road; the
## ladder above stays the fast one, and four times faster per slot.
##
## **Lay Low was folded into it.** Lay Low spent a slot, cost nothing, shed a
## flat 2.0 Heat and filed a `discretion` observation on Curtis's network — and
## touched health nowhere. Its fiction ("lights off, phone down") was already
## resting and its cost was already REST's cost, so carrying two do-nothing
## verbs was carrying one too many.
##
## What survived the fold is the part that was actually distinct: Lay Low was
## the only **on-demand, no-money, no-crew Heat sink** in the game — the one
## lever you can pull before a street stop rather than waiting for the night —
## and the only action that made going quiet something Curtis reads. So the
## **first REST of each day** still does both: it sheds `REST_QUIET_HEAT`
## through `apply_relief` (which bypasses the district and Deshawn multipliers
## on purpose — TI-003 regression #15; having Deshawn on the crew must not make
## going quiet work less well) and files Curtis's `quiet_day`. Later RESTs that
## day heal only.
##
## The once-a-day cap is batch 8's and is kept for batch 8's reason: four
## Lay Lows a day was 8.0 of shedding for free, which is more Heat than a day of
## play generates, and it meant Heat could always be ground off rather than
## carried. The HEALING has no such cap (owner default 2) — time is the cap, and
## four slots spent resting is a whole day not earning.
##
## `lay_low_day` keeps its name. It still means "the day the quiet was taken";
## renaming a persisted field is a schema change this build does not need.
##
## Canon's warning is on the screen, not in the code, and it is still the point:
## **debt, wages, markets and Curtis keep moving while the lights are off.**
## Resting is not a pause, it is a trade.
##
## ## Not ported, each named rather than stubbed
##
##   - **`treatmentCost`'s discount.** Canon shaves 10% off every treatment at
##     Street Read tier 3. There is no Street Read system, so `treatment_cost()`
##     exists and returns the full price — the one place the discount would go.
##   - **`HEAL_AT_BASE`.** The garage first-aid table needs the base system.
##   - **`stats.moneySpent.healing`.** Canon tracks lifetime spend by category
##     for the end-of-run summary; this build has no such summary yet.
##   - **`addStreetReadEntry`** on a heal (canon logs whether you went to a
##     clinic or a hospital) — Street Read again.

const GREEN := Color(0.451, 0.722, 0.404)
const BLUE := Color(0.373, 0.663, 0.847)

## The shared owners. Treatments spend; the day's first REST relieves.
func _wallet() -> Object:
	return gm.system("wallet")

func _heat() -> Object:
	return gm.system("heat")

## Canon's three treatments. `reveal_at` is the health at or below which canon
## surfaces the card; first aid has no gate.
const FIRST_AID := {"id": "first_aid", "name": "First aid", "amount": 18, "cost": 55,
	"copy": "Immediate care", "reveal_at": 100, "costs_time": false}
## `formal` is Recovery's own declaration for TI-003 §6's high-visibility spend
## policy. Only the clinic carries it: a clinic bills, and a bill is a record.
const CLINIC := {"id": "clinic", "name": "Clinic visit", "amount": 40, "cost": 135,
	"copy": "Larger treatment for a serious injury", "reveal_at": 82,
	"costs_time": true, "formal": true}
const DOCTOR := {"id": "doctor", "name": "No-Questions Doctor", "amount": 75, "cost": 290,
	"copy": "Private care unlocked through trust", "reveal_at": 55, "costs_time": true}

const TREATMENTS := [FIRST_AID, CLINIC, DOCTOR]

## SO-D1: what one slot of sleep is worth. Owner ruling 1, range 8-12.
const REST_HEALTH := 10
## SO-D2/SO-D5: the night, in three numbers.
##
## `settle_overnight()` is the ONE function that decides what a night gives
## back, so a later injury state (laid up, hospitalised, incapacity) has exactly
## one place to gate rather than a rule scattered across a lifecycle step.
##
## A night only heals a day that did no damage: keeping working while hurt is
## the choice the player is making, and the night is what they gave up to make
## it. Below the severe band it heals barely at all on its own -- serious injury
## stays dangerous -- but REST and the whole paid ladder still work at full
## strength there, so a broke player at 5 health is never soft-locked (SO-D5,
## owner ruling 3).
const OVERNIGHT_HEALTH := 3
const OVERNIGHT_SEVERE := 1
const SEVERE_AT := 30

## SO-D3: the quiet, inherited from Lay Low. Canon:
## `max(1, 2 + baseBonus - danger)`, both terms pinned at 0 without the base
## system, so the reduction is a flat 2. Once a day (`lay_low_day`).
const REST_QUIET_HEAT := 2

## Canon gates the No-Questions Doctor on `base.tracks.recovery >= 2 ||
## npc.mina.trust >= 3`. There is no base system, and `npc.mina.trust` is a
## separate counter this port never carried — what it DOES have is Mina's
## Exposure disposition, which is the same relationship measured a different
## way. Gating on her band reaching TRUSTED is a named divergence, taken because
## the alternative is porting a card no run could ever reach.
const DOCTOR_BAND := "trusted"

var gs: Node
var time_system: RefCounted
## Reached for the wallet and the heat system: treatments spend, the day's
## first REST relieves.
var gm: Node

func setup(game_state: Node, time: RefCounted, manager: Node) -> void:
	gs = game_state
	time_system = time
	gm = manager

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func can_handle(action: String) -> bool:
	return action in ["use_first_aid", "heal", "rest"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"use_first_aid":
			return _treat(FIRST_AID)
		"heal":
			return _heal(str(payload.get("treatment_id", "")))
		"rest":
			return _rest()
	return {"ok": false, "reason": "Unknown recovery action."}

# --- reads -----------------------------------------------------------------

func treatment_by_id(id: String) -> Dictionary:
	for t in TREATMENTS:
		if str(t["id"]) == id:
			return t
	return {}

## Canon treatmentCost: 10% off at Street Read tier 3, full price otherwise.
## There is no Street Read system, so this always returns full price — it exists
## so the discount has one place to land when that system arrives.
func treatment_cost(base_cost: int) -> int:
	return base_cost

## Canon reveals a card only once the damage justifies it. First aid is always
## there; the clinic waits for 82, the doctor for 55.
##
## The doctor is also dropped when the contact is not open, because canon shows
## the treatment card OR the locked card and never both
## (`doctorOpen ? treatment(...) : <div className="card locked">`). A first pass
## returned it regardless and the screen rendered both at once.
func visible_treatments() -> Array:
	var out: Array = []
	for t in TREATMENTS:
		if gs.health > int(t["reveal_at"]):
			continue
		if str(t["id"]) == "doctor" and not doctor_open():
			continue
		out.append(t)
	return out

## True when the private medical contact is open. Canon: Safehouse recovery
## track OR Mina's trust. See DOCTOR_BAND for why this reads her band.
func doctor_open() -> bool:
	var exposure: Node = _exposure()
	if exposure == null:
		return false
	return exposure.disposition("mina") >= _band_floor(DOCTOR_BAND)

func _band_floor(band: String) -> float:
	var exposure: Node = _exposure()
	if exposure == null:
		return 999.0
	for b in exposure.BAND_FLOORS:
		if str(b["id"]) == band:
			return float(b["floor"])
	return 999.0

## Why the button is dead, in canon's own terms: full health or not enough cash.
func treat_blocker(treatment: Dictionary) -> String:
	if gs.game_over:
		return "The run is over"
	if treatment.is_empty():
		return "No such treatment"
	if gs.health >= gs.health_max:
		return "Nothing to treat"
	var cost: int = treatment_cost(int(treatment["cost"]))
	if gs.cash < cost:
		return "Need $%d" % cost
	return ""

## Canon layLowPreview. The `min` against current Heat is presentation — the
## reducer clamps at 0 anyway — but it is what stops the card promising a drop
## of 2 to somebody sitting at 1. SO-D3: it also returns 0 once today's quiet
## has been spent, so a second REST's card does not promise Heat it will not
## shed.
##
## **Returns a float on purpose.** Heat became fractional in Phase 3e (Deshawn's
## 0.80 reduction needs it), and canon does not round this either. A first pass
## returned int and silently truncated a player at 1.6 into a promised drop of
## 1 — the parity fixture caught it, because it walks heats that are not whole.
func rest_quiet_preview() -> float:
	if not quiet_available():
		return 0.0
	return minf(gs.heat, float(REST_QUIET_HEAT))

## SO-D1: what one REST would put back, clamped by the ceiling. The card
## promises this and `_rest` delivers exactly it.
func rest_health_preview() -> int:
	return mini(int(gs.health_max) - int(gs.health), REST_HEALTH)

# --- actions ---------------------------------------------------------------

## Canon USE_FIRST_AID and HEAL are the same arithmetic; they differ in whether
## a slot is spent. Keeping them one function makes that the only difference,
## which is what canon's two reducers amount to.
func _treat(treatment: Dictionary) -> Dictionary:
	var blocked: String = treat_blocker(treatment)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked + "."}
	var cost: int = treatment_cost(int(treatment["cost"]))
	var amount: int = int(treatment["amount"])
	var before: int = gs.health
	# TI-003 §6 lists "formal Recovery spending explicitly declared by Recovery"
	# as high-visibility, and leaves the declaring to Recovery. The clinic is the
	# one treatment that generates a record somebody could read back; first aid
	# is supplies, and the No-Questions Doctor is named for not asking. So the
	# clinic pays clean-first and the other two are routine.
	var policy: String = _wallet().HIGH_VISIBILITY_CLEAN_FIRST if bool(treatment.get("formal", false)) \
		else _wallet().ROUTINE_DIRTY_FIRST
	_wallet().spend(cost, policy, {"source_id": "recovery_%s" % str(treatment["id"])})
	gs.health = clampi(gs.health + amount, 0, gs.health_max)
	var restored: int = gs.health - before
	if bool(treatment["costs_time"]):
		gs.log_activity("The clinic worker closes the curtain and repairs %d health for $%d."
			% [restored, cost], GREEN)
		time_system.handle("advance_time", {})
	else:
		gs.log_activity("Immediate first aid restores %d Health." % restored, GREEN)
	return {"ok": true, "restored": restored, "cost": cost}

func _heal(treatment_id: String) -> Dictionary:
	var treatment: Dictionary = treatment_by_id(treatment_id)
	if treatment.is_empty():
		return {"ok": false, "reason": "No such treatment."}
	if treatment_id == "doctor" and not doctor_open():
		return {"ok": false, "reason": "You have no private medical contact."}
	return _treat(treatment)

## SO-D1: why REST can be refused, or "" if it cannot.
##
## There has to be something to sleep off. At full health with no Heat there is
## nothing REST would do, and an action that runs and changes nothing is worse
## than one that says so. Heat above zero counts as something to sleep off even
## at full health, because the day's first REST is still the quiet one.
##
## Note what is NOT here: a once-a-day cap on resting (owner default 2 -- time
## is the cap), a district gate (owner default 4 -- canon's rest had none, and
## Home is a tab rather than a place), and any money.
func rest_blocker() -> String:
	if gs.game_over:
		return "The run is over"
	if int(gs.health) >= int(gs.health_max) and float(gs.heat) <= 0.0:
		return "Nothing to sleep off"
	return ""

## True when today's quiet is still unspent -- the first REST of a day sheds
## Heat and files Curtis's read, later ones only heal. Read by the Recovery
## screen so the card can preview both halves honestly.
func quiet_available() -> bool:
	return int(gs.lay_low_day) != int(gs.day)

## SO-D1/SO-D3: sleep it off.
##
## Every REST heals. The FIRST REST of a day is also the quiet one: it sheds
## Heat and Curtis notices. Both halves are reported so the caller can say what
## actually happened rather than guessing from the state afterwards.
func _rest() -> Dictionary:
	var blocked: String = rest_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked + "."}

	var before: int = int(gs.health)
	gs.health = clampi(int(gs.health) + REST_HEALTH, 0, int(gs.health_max))
	var restored: int = int(gs.health) - before

	# The quiet, once a day (batch 8's cap, kept). Relief and not a negative
	# gain: TI-003 §7 has relief bypass the district and Deshawn multipliers,
	# because having Deshawn on the crew must not make going quiet work less
	# well, which is what routing this through the gain pipeline would do.
	# `apply_relief` returns a signed delta; the copy wants the magnitude.
	var dropped: float = 0.0
	var went_quiet: bool = quiet_available()
	if went_quiet:
		dropped = -_heat().apply_relief(float(REST_QUIET_HEAT), {"source_id": "rest_quiet"})
		var exposure: Node = _exposure()
		if exposure != null:
			exposure.record_observation("curtis",
				{"type": "discretion", "event": "quiet_day", "source": "network"})
		gs.lay_low_day = int(gs.day)

	gs.log_activity(_rest_line(restored, went_quiet, dropped), BLUE)
	time_system.handle("advance_time", {})
	return {"ok": true, "restored": restored, "dropped": dropped, "quiet": went_quiet}

## VOX-D1, the Power register. "Lights off, phone down" was Lay Low's line and
## it stays, because it was always describing rest. The health is a fact, not a
## comfort -- nobody is tucked in.
func _rest_line(restored: int, went_quiet: bool, dropped: float) -> String:
	if went_quiet and restored > 0:
		return "Lights off, phone down. %d health back, and the heat drops %.1f." % [restored, dropped]
	if went_quiet:
		return "Lights off, phone down. The heat drops %.1f." % dropped
	if restored > 0:
		return "You lie down again. %d health back." % restored
	return "You lie down again. Nothing much changes."

# --- the night (SO-D2, SO-D5) ----------------------------------------------

## True when this run is hurt badly enough that the night barely helps.
##
## A number the overnight rule reads, and deliberately NOT a state: nothing
## latches, nothing has to be cleared, and a player crosses back out of it the
## moment their health does. The screens can read it too, if they ever want to.
func is_severe() -> bool:
	return int(gs.health) <= SEVERE_AT

## What tonight would give back, before it is given. Pure, so the suite can pin
## the table without driving a night.
func overnight_amount() -> int:
	if int(gs.damage_today) > 0:
		return 0
	if int(gs.health) >= int(gs.health_max):
		return 0
	return OVERNIGHT_SEVERE if is_severe() else OVERNIGHT_HEALTH

## DAY_START `recovery_overnight`, immediately after `heat_day_reset`.
##
## It runs second on purpose. It reads `damage_today` from the day that just
## ended and then clears it, so nothing between the day's reset and this step
## may deal damage -- which is why the position is second and why the lifecycle
## trace pin for it is literal.
##
## A night that healed writes one feed line. A night that did not writes none:
## "you did not heal" is not news, and a line every morning would be noise the
## player learns to skip past the mornings that matter.
func settle_overnight(_today: int) -> void:
	if gs.game_over:
		return
	var amount: int = overnight_amount()
	if amount > 0:
		var before: int = int(gs.health)
		gs.health = clampi(before + amount, 0, int(gs.health_max))
		var restored: int = int(gs.health) - before
		if restored > 0:
			gs.log_activity(_overnight_line(restored), GREEN)
	# Cleared whether or not anything healed: the day it described is over.
	gs.damage_today = 0

## VOX-D1. A night is a fact. The severe line says less on purpose -- somebody
## this hurt does not wake up feeling reported on.
func _overnight_line(restored: int) -> String:
	if is_severe():
		return "You sleep badly and wake up barely better. %d back." % restored
	return "A night nobody came looking. %d health back." % restored

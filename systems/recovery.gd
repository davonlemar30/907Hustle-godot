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
## ## Lay Low
##
## Canon drops Heat by `max(1, 2 + baseBonus - danger)` and files a `discretion`
## observation on Curtis's network — going quiet is itself something the
## neighborhood notices, and Curtis is the one who notices it. Both terms need
## the base system (`base.tracks.security`, `base.watched`), so the reduction is
## a flat 2 here and named below.
##
## Canon's warning is on the screen, not in the code, and it is the point of the
## action: **debt, wages, markets and Curtis keep moving while the lights are
## off.** Laying low is not a pause, it is a trade.
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

## Canon's three treatments. `reveal_at` is the health at or below which canon
## surfaces the card; first aid has no gate.
const FIRST_AID := {"id": "first_aid", "name": "First aid", "amount": 18, "cost": 55,
	"copy": "Immediate care", "reveal_at": 100, "costs_time": false}
const CLINIC := {"id": "clinic", "name": "Clinic visit", "amount": 40, "cost": 135,
	"copy": "Larger treatment for a serious injury", "reveal_at": 82, "costs_time": true}
const DOCTOR := {"id": "doctor", "name": "No-Questions Doctor", "amount": 75, "cost": 290,
	"copy": "Private care unlocked through trust", "reveal_at": 55, "costs_time": true}

const TREATMENTS := [FIRST_AID, CLINIC, DOCTOR]

## Canon: `max(1, 2 + baseBonus - danger)`, both terms pinned at 0 without the
## base system, so the reduction is a flat 2.
const LAY_LOW_HEAT := 2

## Canon gates the No-Questions Doctor on `base.tracks.recovery >= 2 ||
## npc.mina.trust >= 3`. There is no base system, and `npc.mina.trust` is a
## separate counter this port never carried — what it DOES have is Mina's
## Exposure disposition, which is the same relationship measured a different
## way. Gating on her band reaching TRUSTED is a named divergence, taken because
## the alternative is porting a card no run could ever reach.
const DOCTOR_BAND := "trusted"

var gs: Node
var time_system: RefCounted

func setup(game_state: Node, time: RefCounted) -> void:
	gs = game_state
	time_system = time

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func can_handle(action: String) -> bool:
	return action in ["use_first_aid", "heal", "lay_low"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"use_first_aid":
			return _treat(FIRST_AID)
		"heal":
			return _heal(str(payload.get("treatment_id", "")))
		"lay_low":
			return _lay_low()
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
## of 2 to somebody sitting at 1.
##
## **Returns a float on purpose.** Heat became fractional in Phase 3e (Deshawn's
## 0.80 reduction needs it), and canon does not round this either. A first pass
## returned int and silently truncated a player at 1.6 into a promised drop of
## 1 — the parity fixture caught it, because it walks heats that are not whole.
func lay_low_preview() -> float:
	return minf(gs.heat, float(LAY_LOW_HEAT))

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
	gs.cash -= cost
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

## Canon's LAY_LOW: Heat down, one slot gone, and Curtis hears about the quiet.
##
## The observation is the part that is easy to miss. Going quiet is not
## invisible — it is a `discretion` row on the network channel, and Curtis is
## the one lens that reads discretion as information about you.
func _lay_low() -> Dictionary:
	if gs.game_over:
		return {"ok": false, "reason": "The run is over."}
	var before: float = gs.heat
	gs.heat = clampf(gs.heat - float(LAY_LOW_HEAT), 0.0, float(gs.heat_max))
	var dropped: float = before - gs.heat
	var exposure: Node = _exposure()
	if exposure != null:
		exposure.record_observation("curtis",
			{"type": "discretion", "event": "quiet_day", "source": "network"})
	gs.log_activity("Lights off, phone down. Heat drops %.1f." % dropped, BLUE)
	time_system.handle("advance_time", {})
	return {"ok": true, "dropped": dropped}

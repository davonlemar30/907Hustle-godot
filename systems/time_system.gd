extends RefCounted
## Time system — slot advancement and day-cross.
##
## MORNING → AFTERNOON → EVENING → NIGHT → (day cross) → MORNING. A day-cross
## bumps the day, evolves the markets, and emits day_crossed so later systems
## (wages, territory income, events) can hook in.
##
## Markets move ONCE PER DAY, on the cross — canon's cadence. evolveMarkets is
## called from day-end settlement (game-core.js:6654), never per slot; prices
## hold steady through a day's four slots and the city re-prices overnight.
## The per-slot evolve this used to do read the nightly cadence as a bug and
## "fixed" it — the oracle says nightly was the design (found in Phase 5 while
## porting the canon walk).
##
## ## The day-cross settlement contract
##
## This file owns the CLOCK. It does not own the night — `day_lifecycle.gd` does,
## and that file's `SETTLE_ORDER` / `POST_SETTLE_ORDER` / `ROLLOVER_ORDER` /
## `DAY_START_ORDER` are the contract. The order used to be implicit, expressed
## as whichever order five `day_crossed.connect()` calls happened to run in
## during `GameManager._ready()`; FS-003.2 made it a declared list, and the
## parity suite asserts the whole sequence as a literal.
##
## Four ordering dependencies were audited as load-bearing. They are named here
## because this is where a reader arrives when they ask "what happens at
## midnight", and a contract nobody can find is a contract nobody keeps. Each is
## asserted in `_check_settlement_contract`.
##
##   1. **Crew settles BEFORE Territory.** A crew member who departs tonight for
##      unpaid wages does not reduce tonight's territory heat.
##
##      The EFFECT above is right; the reason this block used to give for it was
##      not. It said "territory income is computed off crew power", and
##      `systems/territory.gd` does not reference `crew_power` — or `crew` —
##      anywhere. Corner income is the block's authored `earning` and the
##      diminishing constant, full stop.
##
##      The real path is Deshawn: `crew.settle_night()` can mark a member
##      departed over unpaid wages, and `territory.settle_night()` applies its
##      holding heat through `HeatSystem.apply_gain()`, the one site that
##      consults `crew.heat_multiplier()`. A departed Deshawn multiplies by 1.0.
##      So the ordering decides what the night COSTS, not what it earns.
##      Reordering these two still changes gameplay. (D-5, 2026-08-23.)
##
##   2. **Exposure settles AFTER Jobs, Obligations and Shark.** An observation
##      those three produce on this cross can be delivered the same night, which
##      is why Exposure sits in ROLLOVER rather than in SETTLE.
##
##   3. **`day_crossed` listeners see POST-evolution markets.** This one
##      INVERTED, and it is the reason this block exists. The audit recorded
##      "any future listener sees pre-evolution markets"; FS-003.2 moved the
##      signal below `economy.evolve()` deliberately, because everything still
##      connected to it was written expecting the new day on the clock and the
##      board priced. A listener written against the old note would read
##      yesterday's prices. Asserted so the inversion cannot silently invert
##      back.
##
##   4. **`day_crossed` listeners see PRE-restoration phone state.** A line paid
##      for during the ending day comes back AFTER the whole night has run —
##      `restore_if_ready` is called from `handle()` below, once
##      `run_night_transition` has returned. Canon does the same, and the
##      absolute slot it is handed is the one from before the move.
##
## FS-002.2 was expected to replace the implicit order with named phases.
## FS-003.2 got there first, so that half of the audit is closed.

const SLOTS := ["MORNING", "AFTERNOON", "EVENING", "NIGHT"]

var gs: Node
var economy: RefCounted
var phone: RefCounted
## Owns the whole night sequence. This system owns the CLOCK; what happens when
## it rolls past NIGHT is a separate contract with a declared order.
var day_lifecycle: RefCounted

func setup(game_state: Node, economy_system: RefCounted, phone_system: RefCounted,
		lifecycle: RefCounted) -> void:
	gs = game_state
	economy = economy_system
	phone = phone_system
	day_lifecycle = lifecycle

## BR-D2: applications resolve on the clock, so the clock knows the jobs
## system. Attached after both exist (`GameManager._ready`), optional so a
## suite that builds a bare clock still runs. A WEAK reference: jobs holds
## the clock, and a strong reference back would be a RefCounted cycle that
## leaks both at exit -- CI's harness grep caught exactly that ("13 ObjectDB
## instances were leaked", "6 resources still in use") on the first push.
var _jobs_ref: WeakRef = null

func attach_jobs(jobs_system: RefCounted) -> void:
	_jobs_ref = weakref(jobs_system)

func _jobs() -> RefCounted:
	if _jobs_ref == null:
		return null
	var jobs_system: Variant = _jobs_ref.get_ref()
	return jobs_system if jobs_system is RefCounted else null

func can_handle(action: String) -> bool:
	return action == "advance_time"

func handle(action: String, _payload: Dictionary) -> Dictionary:
	if action != "advance_time":
		return {"ok": false, "reason": "Unknown time action."}
	# Canon advanceRun hands restorePhoneIfReady the absolute slot from BEFORE
	# the move, so a line paid for this slot cannot come back in the same slot.
	var previous_absolute: int = phone.now_slot_number()
	var next: int = gs.time_slots_today + 1
	if next >= SLOTS.size():
		# The whole night, in one declared sequence: settle against the ending
		# day, move the clock, walk the market, start the new day. The order
		# lives in day_lifecycle.gd where it can be read and tested, rather than
		# here as a run of statements that happen to be in the right order.
		day_lifecycle.run_night_transition(gs.day)
	else:
		gs.time_slots_today = next
		gs.time_slot = SLOTS[next]
	# Canon runs this on every advance, day-cross or not (game-core.js
	# advanceRun -> restorePhoneIfReady), after the clock has moved.
	phone.restore_if_ready(previous_absolute)
	# BR-D2: the clock moved; an application that has waited its slots is
	# answered, by text, from whoever runs the place.
	var jobs_system: RefCounted = _jobs()
	if jobs_system != null:
		jobs_system.resolve_applications()
	return {"ok": true}

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
	return {"ok": true}

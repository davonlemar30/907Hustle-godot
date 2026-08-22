extends RefCounted
## Phone — the inbox substrate, and the line that can die.
##
## Ported from the web build's phone half (game-core.js): pushPhoneMessage (735),
## restorePhoneIfReady (774), DISMISS_PHONE_MESSAGE (7897), CLEAR_PHONE_INBOX
## (7903), the PHONE_INTEL table (1171) and phoneIntel (1179). The bill clock —
## due day, grace, and the settlement that kills the line — already lives in
## `systems/obligations.gd` and stays there; this is the messaging side plus the
## restoration that a payment schedules.
##
## The one idea that makes the rest make sense: **a dead line does not lose
## messages, it holds them.** Anything sent while the phone is off goes to
## `phone_held_inbox` and stays there until service comes back, at which point
## the whole held stack is reversed and prepended to the live inbox — so the
## flush reads newest-first like everything else in the inbox.
##
## Restoration is DEFERRED on purpose. Canon does not switch the phone back on
## inside the payment; it stamps `reactivateAtSlot` with the current absolute
## slot and lets the next slot advance flip it (restorePhoneIfReady's strictly-
## greater comparison). Paying and then standing still leaves you still offline,
## which is the point: the carrier takes a beat.
##
## NOT ported, each named so the gap is legible:
##   - `read` is written on every message and never set true. Canon does not read
##     it either (v1.35 has no read-receipt UI); it is carried so a future unread
##     badge does not need a save migration.
##   - `action` descriptors are carried verbatim but only `job_offer` exists in
##     canon, and this build's jobs system has no application → offer pipeline
##     (jobs.gd hires directly). Nothing pushes one yet; the Phone screen renders
##     the buttons for any kind it can honour and ignores the rest.
##   - retireOfferMessages (game-core.js:745) — it exists to pull a text whose
##     Accept button has gone stale, and there are no offer texts to pull yet.
##   - resolveJobApplications, which restorePhoneIfReady calls after a flush, for
##     the same reason.

const SLOTS := ["MORNING", "AFTERNOON", "EVENING", "NIGHT"]

## Canon PHONE_INTEL interpolates `area.name` — the prose name, not the
## uppercase display form `districts[].name` carries for the top bar.
const AREA_PROSE_NAMES := {
	"north_star_lot": "Spenard",
	"downtown": "Downtown",
	"airport_industrial": "Ship Creek",
}

## The six lines PHONE_INTEL builds per area per slot (game-core.js:1171-1178).
## Only the first varies by part of day; canon still stores all four slots.
const INTEL_TEMPLATES := [
	"%s: %s foot traffic is starting to settle.",
	"%s: a bus driver says the next run is on time.",
	"%s: somebody is asking who has reliable hands today.",
	"%s: a warm counter is drawing a small crowd.",
	"%s: road crews left one lane tighter than usual.",
	"%s: the useful names are moving by text, not flyers.",
]

const GREEN := Color(0.451, 0.722, 0.404)

var gs: Node
var rng: Node

func setup(game_state: Node, rng_manager: Node) -> void:
	gs = game_state
	rng = rng_manager

func can_handle(action: String) -> bool:
	return action in ["dismiss_phone_message", "clear_phone_inbox"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"dismiss_phone_message":
			return _dismiss(str(payload.get("id", "")))
		"clear_phone_inbox":
			return _clear()
	return {"ok": false, "reason": "Unknown phone action."}

# --- clock -----------------------------------------------------------------

## Canon slotNumber (src/selectors.js:13) — the absolute slot index of a run.
func slot_number(day: int, slot_index: int) -> int:
	return (day - 1) * 4 + slot_index

func slot_index(slot_name: String) -> int:
	var i: int = SLOTS.find(slot_name.to_upper())
	return i if i >= 0 else 0

func now_slot_number() -> int:
	return slot_number(gs.day, slot_index(gs.time_slot))

## "DAY 3 · EVENING" — canon renders a message stamp as `DAY {day} · {SLOTS[slot]}`.
func stamp(message: Dictionary) -> String:
	var index: int = int(message.get("slot", 0))
	var name: String = SLOTS[index] if index >= 0 and index < SLOTS.size() else SLOTS[0]
	return "DAY %d · %s" % [int(message.get("day", 0)), name]

# --- messages --------------------------------------------------------------

## Canon pushPhoneMessage. The id is `day:slot:stringHash(from:text)` — the same
## sender saying the same thing in the same slot is the same message, which is
## what keeps a repeated push from stacking duplicates.
##
## `action` is optional and carried verbatim; an empty dictionary means none.
func push_message(from: String, text: String, action: Dictionary = {}) -> Dictionary:
	var index: int = slot_index(gs.time_slot)
	var item: Dictionary = {
		"id": "%d:%d:%d" % [gs.day, index, rng.string_hash("%s:%s" % [from, text])],
		"from": from,
		"text": text,
		"day": gs.day,
		"slot": index,
		"read": false,
	}
	if not action.is_empty():
		item["action"] = action.duplicate(true)
	# Live goes on top, held goes on the end. The flush reconciles the two.
	if gs.phone_active:
		gs.phone_inbox.push_front(item)
	else:
		gs.phone_held_inbox.append(item)
	return item

func _dismiss(id: String) -> Dictionary:
	if id.is_empty():
		return {"ok": false, "reason": "No message named."}
	var before: int = gs.phone_inbox.size()
	var kept: Array = []
	for m in gs.phone_inbox:
		if str(m.get("id", "")) != id:
			kept.append(m)
	if kept.size() == before:
		return {"ok": false, "reason": "That text is already gone."}
	gs.phone_inbox = kept
	return {"ok": true}

func _clear() -> Dictionary:
	if gs.phone_inbox.is_empty():
		return {"ok": false, "reason": "Nothing to clear."}
	gs.phone_inbox = []
	return {"ok": true}

# --- restoration -----------------------------------------------------------

## Canon restorePhoneIfReady, called on every slot advance with the absolute
## slot number from BEFORE the advance.
##
## The comparison is deliberately strict and takes the later of the two bounds:
## a payment made this slot stamps reactivateAtSlot = now, and `now <= max(...)`
## is still true at that moment, so nothing flips until the clock actually moves.
func restore_if_ready(previous_absolute: int) -> bool:
	if gs.phone_reactivate_at_slot < 0:
		return false
	if now_slot_number() <= maxi(previous_absolute, gs.phone_reactivate_at_slot):
		return false
	gs.phone_active = true
	gs.phone_reactivate_at_slot = -1
	if not gs.phone_held_inbox.is_empty():
		# Canon: [...heldInbox.reverse(), ...inbox]. Held is oldest-first, so
		# reversing it puts the newest held message at the very top.
		var flushed: Array = gs.phone_held_inbox.duplicate()
		flushed.reverse()
		flushed.append_array(gs.phone_inbox)
		gs.phone_inbox = flushed
		gs.phone_held_inbox = []
	gs.log_activity("The signal bars return. Held messages fill the screen.", GREEN)
	return true

# --- word around town ------------------------------------------------------

## Canon phoneIntel: the pool for where the player is standing and what part of
## day it is, falling back to Spenard so an unknown area never renders empty.
func intel() -> Array:
	var area: String = str(gs.current_district_id)
	if not AREA_PROSE_NAMES.has(area):
		area = "north_star_lot"
	var name: String = str(AREA_PROSE_NAMES[area])
	var part: String = gs.time_slot.to_lower()
	var lines: Array = []
	for i in range(INTEL_TEMPLATES.size()):
		var template: String = INTEL_TEMPLATES[i]
		lines.append(template % [name, part] if i == 0 else template % name)
	return lines

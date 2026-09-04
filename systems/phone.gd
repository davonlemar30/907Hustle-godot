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
	"mountain_view": "Mountain View",
}

## How many routes Word Around Town carries. Enough to see a choice, few enough
## that the section stays a rumour rather than a spreadsheet.
const INTEL_ROUTE_LIMIT := 3

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

const REPLIES := preload("res://data/phone_replies.gd")

func can_handle(action: String) -> bool:
	return action in ["dismiss_phone_message", "clear_phone_inbox", "phone_reply"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"dismiss_phone_message":
			return _dismiss(str(payload.get("id", "")))
		"clear_phone_inbox":
			return _clear()
		"phone_reply":
			return _reply(str(payload.get("id", "")), str(payload.get("option", "")))
	return {"ok": false, "reason": "Unknown phone action."}

# --- WS-D3: the player speaks ------------------------------------------------
#
# A text from a named NPC carries two answers (`data/phone_replies.gd`). The
# player picks one; the NPC hears it (an observation into their ledger, or a
# point of loyalty for crew), answers back once in their own voice, and the
# exchange is over. A text left on read for a full day is a ghost: it costs
# the people who notice, and the next text from them opens on it.

## Push a text from a named NPC, with the two replies its context or its
## sender earns. Falls back to a plain push for a sender nobody authored
## replies for ("Around town"), so every existing caller can move over one
## site at a time without changing what lands.
func push_text(from: String, text: String, context: String = "",
		extra_action: Dictionary = {}) -> Dictionary:
	var npc_id := REPLIES.npc_for(from)
	var replies: Dictionary = REPLIES.replies_for(npc_id, context)
	var opener := ""
	if not npc_id.is_empty():
		var history: Dictionary = gs.reply_history_for(npc_id)
		if bool(history.get("owed_ghost", false)):
			opener = str(REPLIES.GHOST_OPENERS.get(npc_id, ""))
			history["owed_ghost"] = false
			gs.phone_reply_history[npc_id] = history
	var action: Dictionary = extra_action.duplicate(true)
	# BR-D6: a text can carry its own two answers (a crew member's
	# proposal), and what saying yes does.
	if action.has("reply_override") and action["reply_override"] is Dictionary:
		var override: Dictionary = action["reply_override"]
		action.erase("reply_override")
		action["reply"] = {
			"npc": str(override.get("npc", npc_id)),
			"a": (override.get("a", {}) as Dictionary).duplicate(),
			"b": (override.get("b", {}) as Dictionary).duplicate(),
			"replied": "",
			"on_accept": (override.get("on_accept", {}) as Dictionary).duplicate(true),
		}
	elif not replies.is_empty():
		action["kind"] = str(action.get("kind", "reply"))
		action["reply"] = {
			"npc": npc_id,
			"a": (replies["a"] as Dictionary).duplicate(),
			"b": (replies["b"] as Dictionary).duplicate(),
			"replied": "",
		}
	return push_message(from, opener + text, action)

## The player answers. Validated against the live inbox -- a stale button
## from before a reload must be refused, not honoured against whatever text
## happens to carry that id now -- and answered exactly once.
func _reply(id: String, option: String) -> Dictionary:
	if not option in ["a", "b"]:
		return {"ok": false, "reason": "Pick an answer."}
	var message: Dictionary = {}
	for m in gs.phone_inbox:
		if str((m as Dictionary).get("id", "")) == id:
			message = m
	if message.is_empty():
		return {"ok": false, "reason": "That text is gone."}
	var action: Dictionary = message.get("action", {})
	var reply: Dictionary = action.get("reply", {})
	if reply.is_empty():
		return {"ok": false, "reason": "There is nothing to say to that."}
	if not str(reply.get("replied", "")).is_empty():
		return {"ok": false, "reason": "You already answered."}
	reply["replied"] = option
	action["reply"] = reply
	message["action"] = action
	var npc_id := str(reply.get("npc", ""))
	var chosen: Dictionary = reply[option]
	_hear(npc_id, "answered" if option == "a" else "distanced")
	# BR-D6: yes to a crew member's idea is the assignment. Refused (the
	# window closed, the member got busy), the reply stands and the member
	# says so instead of their yes line.
	var on_accept: Dictionary = reply.get("on_accept", {})
	# OG-D3: yes to Sonny's nephew is the car, if the money is there.
	if option == "a" and str(on_accept.get("kind", "")) == "buy_vehicle":
		var manager_node: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameManager")
		var travel: Object = manager_node.system("travel") if manager_node != null else null
		var bought: Dictionary = travel.buy_beater() if travel != null else {"ok": false}
		if not bool(bought.get("ok", false)):
			push_message(str(message.get("from", "")), "%s. come back when you got it" % str(bought.get("reason", "no")).to_lower().trim_suffix("."),
				{"kind": "reaction"})
			return {"ok": true, "npc": npc_id, "option": option, "bought": false}
	if option == "a" and not on_accept.is_empty() and str(on_accept.get("kind", "")) == "crew_assign":
		var manager: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameManager")
		var ops: Object = manager.system("crew_operations") if manager != null else null
		var assigned: Dictionary = ops.accept_idea(on_accept) if ops != null else {"ok": false}
		if not bool(assigned.get("ok", false)):
			push_message(str(message.get("from", "")), "too late. %s" % str(assigned.get("reason", "it passed.")).to_lower(),
				{"kind": "reaction"})
			return {"ok": true, "npc": npc_id, "option": option, "assigned": false}
	# The NPC answers back once, in their own voice, and carries no reply of
	# its own -- an exchange, not a tree.
	var reaction := str(chosen.get("reaction", ""))
	if not reaction.is_empty():
		push_message(str(message.get("from", "")), reaction, {"kind": "reaction"})
	return {"ok": true, "npc": npc_id, "option": option}

## What an answer does to the person who heard it. Named NPCs with a lens
## take an observation; crew take a point of loyalty either way; everybody
## takes the count into the history a future text reads.
func _hear(npc_id: String, how: String) -> void:
	var history: Dictionary = gs.reply_history_for(npc_id)
	history[how] = int(history.get(how, 0)) + 1
	history["last_day"] = int(gs.day)
	if how == "answered":
		history["owed_ghost"] = false
	gs.phone_reply_history[npc_id] = history
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null and exposure.NPC_LENSES.has(npc_id):
		var event := "answered_text"
		if how == "distanced":
			event = "kept_distance"
		elif how == "ghosted":
			event = "ghosted_text"
		if how != "ghosted" or REPLIES.cares_about_silence(npc_id):
			exposure.record_observation(npc_id, {"type": "loyalty", "event": event,
				"source": "direct", "location": str(gs.current_district_id)})
	elif gs.is_recruited(npc_id):
		var record: Dictionary = gs.crew_record(npc_id)
		if how == "answered":
			record["loyalty"] = int(record.get("loyalty", 0)) + 1
		elif how == "ghosted":
			record["loyalty"] = maxi(0, int(record.get("loyalty", 0)) - 1)
		gs.crew_records[npc_id] = record

## Day start: every text that carried a reply and sat a full day unanswered
## is a ghost. Marked so it cannot ghost twice, counted, and -- for the
## people who notice -- felt. Held texts (a dead line) are not ghosts: you
## cannot leave somebody on read on a phone that is off.
func settle_ghosts(today: int) -> void:
	for m in gs.phone_inbox:
		var message: Dictionary = m
		var action: Dictionary = message.get("action", {})
		var reply: Dictionary = action.get("reply", {})
		if reply.is_empty() or not str(reply.get("replied", "")).is_empty():
			continue
		if today - int(message.get("day", today)) < 2:
			continue
		reply["replied"] = "ghost"
		action["reply"] = reply
		message["action"] = action
		var npc_id := str(reply.get("npc", ""))
		_hear(npc_id, "ghosted")
		if REPLIES.cares_about_silence(npc_id):
			var history: Dictionary = gs.reply_history_for(npc_id)
			history["owed_ghost"] = true
			gs.phone_reply_history[npc_id] = history

## Whether a text is still waiting on the player.
static func awaits_reply(message: Dictionary) -> bool:
	var reply: Dictionary = (message.get("action", {}) as Dictionary).get("reply", {})
	return not reply.is_empty() and str(reply.get("replied", "")).is_empty()

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
	# Both halves hold PHONE_INBOX_MAX (see its GameState header for why this
	# caps where canon does not): the live inbox is newest-first so the cut
	# comes off the back, the held inbox is oldest-first so it comes off the
	# front — the oldest message is what drops either way.
	if gs.phone_active:
		gs.phone_inbox.push_front(item)
		if gs.phone_inbox.size() > gs.PHONE_INBOX_MAX:
			gs.phone_inbox.resize(gs.PHONE_INBOX_MAX)
	else:
		gs.phone_held_inbox.append(item)
		while gs.phone_held_inbox.size() > gs.PHONE_INBOX_MAX:
			gs.phone_held_inbox.pop_front()
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
		# The merge can briefly sum to as much as 2× the cap; settle it back.
		# Newest-first, so the resize drops the oldest of the combined stack.
		if gs.phone_inbox.size() > gs.PHONE_INBOX_MAX:
			gs.phone_inbox.resize(gs.PHONE_INBOX_MAX)
	gs.log_activity("The signal bars return. Held messages fill the screen.", GREEN)
	return true

# --- word around town ------------------------------------------------------

## Canon phoneIntel: the pool for where the player is standing and what part of
## day it is, falling back to Spenard so an unknown area never renders empty.
## What people are saying product is going for, somewhere other than here.
##
## The build's one profitable strategy is buying in one district and selling in
## another, and until v0.2.0 there was no surface anywhere that could see a
## price in a district the player was not standing in. The economy instrument
## had to read `gs.markets` directly to play the route.
##
## It lives on the PHONE, and behind the service check, because that is the
## honest fiction and because it gives the phone bill its first mechanical
## purchase. Losing the line has meant a quieter inbox and nothing else; now it
## means the city goes dark and you trade on what is in front of you.
##
## Only districts the run has actually discovered — `districts_unlocked`. Word
## does not reach you about places you have not heard of.
func market_intel() -> Array:
	if not gs.phone_active or gs.game_over:
		return []
	var manager: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameManager")
	if manager == null:
		return []
	var economy: Object = manager.system("economy")
	if economy == null:
		return []
	var routes: Array = economy.known_routes()
	var out: Array = []
	for entry in routes:
		if out.size() >= INTEL_ROUTE_LIMIT:
			break
		out.append(entry)
	return out

## One route as a line somebody would actually say.
func market_intel_line(route: Dictionary) -> String:
	var moving: String = ""
	match str(route.get("trend", "flat")):
		"up":
			moving = " and climbing"
		"down":
			moving = ", though it is sliding"
	return "%s is going for $%d in %s%s. That is $%d over what it costs here." % [
		str(route.get("product_name", "")).capitalize(),
		int(route.get("pays", 0)),
		str(route.get("name", "")).capitalize(),
		moving,
		int(route.get("edge", 0)),
	]

## Canon's PHONE_INTEL: the ambient half of Word Around Town, about the district
## the player is standing in. `market_intel()` above is the half with prices in
## it; this is the texture underneath.
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

extends "res://ui/screens/screen_base.gd"
## Home — binds every card from GameState in one pass (_bind_all).
##
## Chrome (header + HUD) comes from the base. This fills Tonight's Operation, the
## Market Snapshot, Turf & Crew (incl. the mini-map grid), the Activity Feed, and
## People & Events. Because the base connects refresh() to GameState.state_changed,
## a single notify_changed() re-renders the whole screen — the vertical slice
## (buy in Market -> GameState updates -> Home reflects cargo/cash/snapshot/feed).

const RED := Color(0.827, 0.161, 0.125, 1)
const DIM := Color(1, 1, 1, 0.06)

@onready var _gm: Node = get_node("/root/GameManager")

func _ready() -> void:
	super()
	_wire_taps()

## The operation card's three actions, all three of which are now real.
##
## They were not. `Move` was labelled MOVE PRODUCT and was canon's
## `explore_spenard` — Wander — reduced to `advance_time` plus a toast reading
## "Time passes." `Post` and `Lay` were `"— coming soon."` toasts. Batch 6b
## shipped Eli's operation and batch 8 capped Lay Low, so by the time this
## batch started, two of the three stubs had working systems behind them and
## nothing connected to either.
## The operation card's two contextual actions. Both were `"— coming soon."`
## toasts; batch 6b shipped Eli's operation and Lay Low has existed in Recovery
## since it was written, so both now go somewhere.
const OP_ACTIONS := {"Post": "POST ELI", "Lay": "LAY LOW"}

func _wire_taps() -> void:
	# Wander comes OFF the operation card, and that is the point of this batch.
	#
	# `Move` was labelled MOVE PRODUCT and was canon's `explore_spenard` — the
	# Wander reducer — spending a slot to print the weather. It also sat on a
	# card that `_bind_gates` HIDES whenever there is no operation, no rent
	# crunch and no shift, which is exactly a fresh run. HANDOFF filed that as an
	# open follow-up: "the build's only bare advance_time control in the UI lives
	# on the now-hidden operation card, so a fresh run must pass time through
	# Street travel, a Hustle action, or More -> Recovery -> Lay Low ... Filed
	# for the next UX pass."
	#
	# This is that pass. Wander is the one thing a player can always do, so it
	# gets a card that is always there, and the operation card keeps only the
	# two actions that are genuinely about tonight's operation.
	var stale := get_node_or_null("Shell/Scroll/Pad/Content/OpCard/V/Actions/Move") as Button
	if stale:
		stale.visible = false
	for node_name in OP_ACTIONS.keys():
		var b := get_node_or_null(
			"Shell/Scroll/Pad/Content/OpCard/V/Actions/" + str(node_name)) as Button
		if b == null:
			continue
		b.text = str(OP_ACTIONS[node_name])
		tap_connect(b, _on_post_eli if str(node_name) == "Post" else _on_lay_low)
	# Three intents, three buttons. One button was a lever; three is a question.
	for intent in EVENTS.INTENTS:
		var b := get_node_or_null("Shell/Scroll/Pad/Content/Wander/V/Go/%s"
			% str(intent).capitalize()) as Button
		if b:
			tap_connect(b, _on_wander.bind(str(intent)))
	make_tappable("Shell/Scroll/Pad/Content/Columns/Market", _on_market)
	make_tappable("Shell/Scroll/Pad/Content/Columns/Turf", _on_turf)
	make_tappable("Shell/Scroll/Pad/Content/People", _on_people)

## Canon's explore_spenard: cashCost 0, timeCost 1 (game-core.js:358-360).
##
## The cost was always right here. What was missing was everything the slot buys
## — see `systems/wander.gd`. The toast reports what the walk turned up; the
## feed carries the line itself, and a blocking encounter takes the player to
## the consequence screen on its own.
func _on_wander(intent: String) -> void:
	var sys: Object = _gm.system("wander")
	if sys == null:
		return
	var blocked: String = str(sys.blocker())
	if not blocked.is_empty():
		nav.show_toast(blocked + ".")
		return
	var before_day: int = gs.day
	if not _gm.dispatch("wander", {"intent": intent}):
		return
	# A wander that opened a blocking encounter has already navigated away, and
	# the toast is parented to the tree root rather than the screen — so it
	# survives the scene change and floats "You take a walk" over SOMEBODY STOPS
	# YOU. The encounter is its own announcement.
	var engine: Object = _gm.system("consequence")
	if engine != null and bool(engine.has_active()):
		return
	if gs.day > before_day:
		nav.show_toast("A new day. Day %d, %s in %s."
			% [gs.day, gs.time_slot.capitalize(), gs.current_district().get("name", "")])
	else:
		nav.show_toast("You take a walk. %s in %s."
			% [gs.time_slot.capitalize(), gs.current_district().get("name", "")])

## Eli, on the bag for the day. Batch 6b built the operation; this is the door
## the operation card always implied and never had.
func _on_post_eli() -> void:
	var ops: Object = _gm.system("crew_operations")
	if ops == null:
		return
	if not ops.is_discovered("run_the_bag"):
		nav.show_toast("Eli has not offered yet.")
		return
	var blocked: Variant = ops.assignment_blocker("run_the_bag")
	if blocked != null:
		nav.show_toast(str(blocked) + ".")
		return
	if _gm.dispatch("assign_crew_operation",
			{"crew_id": "eli", "operation_id": "run_the_bag"}):
		nav.show_toast("Eli has the bag today.")

## Lay Low has existed in `systems/recovery.gd` since it shipped and has only
## ever been reachable from a conditional row on the More menu. Batch 8 gave it
## a once-a-day cap; this gives it the button the Home card has been drawing
## for it the whole time.
func _on_lay_low() -> void:
	var recovery: Object = _gm.system("recovery")
	if recovery == null:
		return
	var blocked: String = str(recovery.lay_low_blocker())
	if not blocked.is_empty():
		nav.show_toast(blocked + ".")
		return
	if _gm.dispatch("lay_low", {}):
		nav.show_toast("Lights off, phone down.")

func _on_market() -> void:
	nav.go_to(nav.MARKET)

func _on_turf() -> void:
	nav.go_to(nav.TURF)

func _on_people() -> void:
	nav.go_to(nav.PEOPLE)

## Home is where the most surfaces are gated, so the gates run FIRST and every
## bind below them is free to fill a surface without asking whether it is there:
## filling a hidden node is harmless, and filling a locked one is what makes the
## lock legible — a greyed-out card with real numbers under it says "this is
## coming", where a greyed-out card of placeholder text says nothing.
const EVENTS := preload("res://data/wander_events.gd")
const ACCESS := preload("res://autoload/surface_visibility.gd")

func _bind_content() -> void:
	_bind_gates()
	_bind_all()

func _bind_gates() -> void:
	# LOCKED: earned surfaces. They stay in the layout, dimmed, with a hint.
	gate_surface(ACCESS.HOME_MARKET_SNAPSHOT, "Shell/Scroll/Pad/Content/Columns/Market")
	gate_surface(ACCESS.HOME_TURF_CREW, "Shell/Scroll/Pad/Content/Columns/Turf")
	# HIDDEN: nothing to show. The card leaves the layout and the ones below it
	# close the gap.
	gate_surface(ACCESS.HOME_TONIGHTS_OPERATION, "Shell/Scroll/Pad/Content/OpCard")
	gate_surface(ACCESS.HOME_TEXT_MESSAGES, "Shell/Scroll/Pad/Content/People")
	gate_surface(ACCESS.HOME_ACTIVITY_FEED, "Shell/Scroll/Pad/Content/Activity")

func _bind_all() -> void:
	_bind_wander()
	_bind_operation()
	_bind_snapshot()
	_bind_turf()
	_bind_activity()
	_bind_people()

## The Wander card. Always present, because going out is always available and a
## card that came and went would be the defect this batch exists to close.
##
## The subtitle is the ramp, said rather than numbered. `WanderSystem` owns the
## arithmetic — 30% base, +10% a miss, capped at 70% — and the player is told
## how the looking is going, which is the part that makes another walk feel
## worth a slot. Telling them 0.60 would be telling them to do arithmetic.
func _bind_wander() -> void:
	var sys: Object = _gm.system("wander")
	if sys == null:
		return
	_set_text("Shell/Scroll/Pad/Content/Wander/V/Head/T", "GO OUT AND LOOK")
	_set_text("Shell/Scroll/Pad/Content/Wander/V/Head/Where",
		gs.time_slot.capitalize())
	var blocked: String = str(sys.blocker())
	for intent in EVENTS.INTENTS:
		var b := get_node_or_null("Shell/Scroll/Pad/Content/Wander/V/Go/%s"
			% str(intent).capitalize()) as Button
		if b == null:
			continue
		var copy: Dictionary = EVENTS.INTENT_COPY[intent]
		b.text = str(copy["label"]) if blocked.is_empty() else blocked.to_upper()
		b.disabled = not blocked.is_empty()
		b.tooltip_text = str(copy["line"])
	_set_text("Shell/Scroll/Pad/Content/Wander/V/Sub", _wander_line(sys))

## What the card says under the button. Three states, and the middle one is the
## whole reason the ramp exists.
func _wander_line(sys: Object) -> String:
	if not str(sys.blocker()).is_empty():
		return "Not right now."
	if (sys.undiscovered() as Array).is_empty():
		return "%s, and you know it well enough by now. Still worth the walk." \
			% str(gs.current_district().get("name", "the block"))
	# The day's effort first, because it is the thing that changes what the next
	# tap is worth. Said rather than numbered, like the ramp.
	var walked: int = int(gs.wanders_today)
	if walked >= 3:
		return "You have walked this block enough for one day."
	if walked == 2:
		return "Twice already today. There is not much left out there."
	var misses: int = int(gs.wander_misses)
	if walked == 1:
		return "Once already today. Still worth a look."
	if misses <= 0:
		return "An hour on foot. You never know who is out."
	if misses < 3:
		return "Nothing the last time out. Somebody knows something."
	return "You have come back empty a few times now. That tends to change."

## The card's copy, chosen from the reason the access layer already decided.
##
## The ORDER changed in v0.1.0 and the reason is worth stating: this function
## used to both decide whether the card had content and pick the words for it.
## Deciding is now `SurfaceVisibility.operation_card_reason()`, because the same
## verdict has to drive whether the card is in the layout at all — a screen that
## keeps its own copy of the condition is a screen that can hide a card while
## still writing text into it.
##
## Delegation now outranks rent rather than sitting under it, which is what
## moving the decision made explicit: the access layer answers "operation" first
## because an operation that is OUT is the card's actual subject, and the rent
## clock is still carried by the HUD's DUE IN N DAYS either way.
func _operation_override() -> Dictionary:
	var access: Node = get_node_or_null("/root/SurfaceVisibility")
	match str(access.operation_card_reason()) if access != null else "":
		"operation":
			return _delegation_override()
		"rent":
			var ob: Object = _gm.system("obligations") if _gm else null
			var days: int = int(ob.days_until_rent()) if ob != null else 0
			var when := "today" if days <= 0 else ("tomorrow" if days == 1 else "in %d days" % days)
			return {"title": "RENT %s" % when.to_upper(),
					"body": "Yalonda wants $%d %s and you have $%d. Find the difference."
						% [gs.WEEKLY_RENT, when, gs.cash]}
		"shift":
			var job: Dictionary = gs.active_job()
			return {"title": "SHIFT: %s" % str(job.get("name", "")).to_upper(),
					"body": "They're expecting you this %s. Clean money, and it keeps the room."
						% gs.time_slot.capitalize()}
	return {}

## Pherris's card, read whole from `operation_summary()`.
##
## Nothing is derived here. "Is she out" and "what did last night come to" are
## fields on the summary, and the only decision this function makes is which of
## the two to show — out today outranks last night, because one of them is still
## happening.
func _delegation_override() -> Dictionary:
	var ops: Object = _gm.system("crew_operations") if _gm else null
	if ops == null:
		return {}
	for operation_id in ops.operation_ids():
		var summary: Dictionary = ops.operation_summary(str(operation_id))
		if not bool(summary.get("discovered", false)):
			continue
		if bool(summary.get("active_today", false)):
			return {"title": "PHERRIS · OUT TODAY",
					"body": _out_today_body(summary)}
		var last: Variant = summary.get("last_night")
		if last is Dictionary:
			var profit: int = int((last as Dictionary).get("profit_or_loss", 0))
			return {"title": "PHERRIS · $%d LAST NIGHT" % profit,
					"body": _last_night_body(last)}
	return {}

func _out_today_body(summary: Dictionary) -> String:
	var selection: Variant = summary.get("selection")
	var picked: int = int((selection as Dictionary).get("cycles_used", 0)) \
		if selection is Dictionary else 0
	var spent: int = int((selection as Dictionary).get("total_spent", 0)) \
		if selection is Dictionary else 0
	if picked <= 0:
		return "She has the day and the board had nothing on it worth your money."
	return "She has the day and $%d of yours, on %d listing%s. It settles tonight." \
		% [spent, picked, "" if picked == 1 else "s"]

func _last_night_body(last: Dictionary) -> String:
	var sold: int = int(last.get("settled_count", 0))
	var gross: int = int(last.get("gross", 0))
	var profit: int = int(last.get("profit_or_loss", 0))
	if sold <= 0:
		return "She worked the board and nothing closed. Your money is where you left it."
	return "She moved %d for $%d gross. %s $%d on the day." \
		% [sold, gross, "Cleared" if profit >= 0 else "Down", absi(profit)]

## The card, when there is a card. `_bind_gates` has already decided that; an
## empty override here means the node is hidden and this is writing into nothing.
##
## `gs.active_operation`'s scripted copy is no longer rendered. It was UI
## scaffold nothing ever wrote — a fixed line about Curtis probing Minnesota
## Off-Ramp that was false in every run it appeared in — and the surface gate is
## what finally lets it go: the card is either carrying a fact or it is not
## there. The three action buttons keep their authored labels from the scene.
func _bind_operation() -> void:
	var over: Dictionary = _operation_override()
	if over.is_empty():
		return
	_set_text("Shell/Scroll/Pad/Content/OpCard/V/Head/Title", str(over["title"]))
	_set_text("Shell/Scroll/Pad/Content/OpCard/V/Body", str(over["body"]))

func _bind_snapshot() -> void:
	var rows := ["R0", "R1", "R2"]
	for i in range(rows.size()):
		var id: String = gs.home_snapshot[i] if i < gs.home_snapshot.size() else ""
		var p: Dictionary = gs.product_by_id(id)
		if p.is_empty():
			continue
		var base: String = "Shell/Scroll/Pad/Content/Columns/Market/V/" + rows[i]
		var col: Color = p.color
		var ic := get_node_or_null(base + "/Ic") as TextureRect
		if ic:
			ic.self_modulate = col
		var nm := get_node_or_null(base + "/I/Nm") as Label
		if nm:
			nm.text = p.name
			nm.add_theme_color_override("font_color", col)
		_set_text(base + "/I/Sub", "Own %s · %s" % [p.get("owned", "0"), p.get("route", "")])
		var pr := get_node_or_null(base + "/P") as Label
		if pr:
			pr.text = "$%d" % p.price
			pr.add_theme_color_override("font_color", col)

func _bind_turf() -> void:
	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Blocks/N", str(gs.held_blocks.size()))

	var held_cells := {}
	var names := []
	for id in gs.held_blocks.keys():
		var b: Dictionary = gs.block_by_id(str(id))
		if b.is_empty():
			continue
		held_cells[int(b.get("cell", -1))] = true
		names.append("• " + str(b.get("name", "")))
	for i in range(gs.map_cells):
		var cell := get_node_or_null("Shell/Scroll/Pad/Content/Columns/Turf/V/Map/B%d" % i) as ColorRect
		if cell:
			cell.color = RED if held_cells.has(i) else DIM
	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/List", "\n".join(names))

	var soldiers: int = gs.soldiers_total()
	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Sold/N", str(soldiers))
	for i in range(6):
		var pip := get_node_or_null("Shell/Scroll/Pad/Content/Columns/Turf/V/Pips/P%d" % i) as TextureRect
		if pip:
			pip.self_modulate = RED if i < soldiers else PIP_DIM

	# Report what the corners are actually doing rather than a fixed line.
	var terr: Object = _gm.system("territory") if _gm else null
	if terr != null and not gs.held_blocks.is_empty():
		_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Eli", "$%d a night from %d held." % [int(terr.nightly_income()), gs.held_blocks.size()])
	else:
		_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Eli", "No corners held yet.")

func _bind_activity() -> void:
	var rows := ["A0", "A1", "A2"]
	for i in range(rows.size()):
		var e: Dictionary = gs.activity_log[i] if i < gs.activity_log.size() else {}
		if e.is_empty():
			continue
		var base: String = "Shell/Scroll/Pad/Content/Activity/V/" + rows[i]
		_set_text(base + "/T", e.get("text", ""))
		var m := get_node_or_null(base + "/M") as Label
		if m:
			m.text = e.get("time", "")
			if e.has("color"):
				m.add_theme_color_override("font_color", e.color)

## The real phone inbox, since Phase 6 — this card used to read a hardcoded
## `pending_messages` placeholder, which is retired. An empty inbox now says so
## instead of leaving the scene's editor-time preview text standing as a fact,
## and a dead line reports what it is holding.
func _bind_people() -> void:
	var base := "Shell/Scroll/Pad/Content/People/H/Txt/"
	var chat := get_node_or_null("Shell/Scroll/Pad/Content/People/H/Chat") as Button
	if gs.phone_inbox.is_empty():
		var held: int = gs.phone_held_inbox.size()
		if not gs.phone_active and held > 0:
			_set_text(base + "Name", "NO SERVICE")
			_set_text(base + "Msg", "%d held until the line comes back." % held)
		elif not gs.phone_active:
			_set_text(base + "Name", "NO SERVICE")
			_set_text(base + "Msg", "The line is dead. Pay the bill to hear from anyone.")
		else:
			_set_text(base + "Name", "NO TEXTS")
			_set_text(base + "Msg", "Nobody has needed you today.")
		_set_text(base + "Ago", "")
		if chat:
			chat.text = str(held)
		return
	var msg: Dictionary = gs.phone_inbox[0]
	_set_text(base + "Name", str(msg.get("from", "")).to_upper() + " TEXTED")
	_set_text(base + "Msg", str(msg.get("text", "")))
	_set_text(base + "Ago", _phone().stamp(msg))
	if chat:
		chat.text = str(gs.phone_inbox.size())

func _phone() -> RefCounted:
	return _gm.system("phone") as RefCounted

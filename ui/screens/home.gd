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

func _wire_taps() -> void:
	# The operation card's three actions are already Buttons in the scene; only
	# the first spends time for now, the other two are Phase 4 story beats.
	var move := get_node_or_null("Shell/Scroll/Pad/Content/OpCard/V/Actions/Move") as Button
	if move:
		tap_connect(move, _on_move_product)
	for spec in [["Post", "Posting Eli"], ["Lay", "Laying low"]]:
		var b := get_node_or_null("Shell/Scroll/Pad/Content/OpCard/V/Actions/" + spec[0]) as Button
		if b:
			tap_connect(b, _on_stub.bind(spec[1]))
	make_tappable("Shell/Scroll/Pad/Content/Columns/Market", _on_market)
	make_tappable("Shell/Scroll/Pad/Content/Columns/Turf", _on_turf)
	make_tappable("Shell/Scroll/Pad/Content/People", _on_people)

## Canon's explore_spenard: cashCost 0, timeCost 1 (game-core.js:358-360).
func _on_move_product() -> void:
	var before_day: int = gs.day
	if not _gm.dispatch("advance_time", {}):
		return
	if gs.day > before_day:
		nav.show_toast("A new day. Day %d, %s in %s." % [gs.day, gs.time_slot.capitalize(), gs.current_district().get("name", "")])
	else:
		nav.show_toast("Time passes. %s in %s." % [gs.time_slot.capitalize(), gs.current_district().get("name", "")])

func _on_stub(what: String) -> void:
	nav.show_toast("%s — coming soon." % what)

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
	_bind_operation()
	_bind_snapshot()
	_bind_turf()
	_bind_activity()
	_bind_people()

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

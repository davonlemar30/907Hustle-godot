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
		move.pressed.connect(_on_move_product)
	for spec in [["Post", "Posting Eli"], ["Lay", "Laying low"]]:
		var b := get_node_or_null("Shell/Scroll/Pad/Content/OpCard/V/Actions/" + spec[0]) as Button
		if b:
			b.pressed.connect(_on_stub.bind(spec[1]))
	make_tappable("Shell/Scroll/Pad/Content/Columns/Market", _on_market)

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

func _bind_content() -> void:
	_bind_all()

func _bind_all() -> void:
	_bind_operation()
	_bind_snapshot()
	_bind_turf()
	_bind_activity()
	_bind_people()

## Employment and the rent clock outrank the scripted operation copy: they are
## the things with a deadline attached.
func _operation_override() -> Dictionary:
	var ob: Object = _gm.system("obligations") if _gm else null
	if ob != null and gs.cash < gs.WEEKLY_RENT:
		var days: int = int(ob.days_until_rent())
		if days <= 2:
			var when := "today" if days <= 0 else ("tomorrow" if days == 1 else "in %d days" % days)
			return {"title": "RENT %s" % when.to_upper(),
					"body": "Yalonda wants $%d %s and you have $%d. Find the difference." % [gs.WEEKLY_RENT, when, gs.cash]}
	if not gs.active_job_id.is_empty():
		var job: Dictionary = gs.active_job()
		var sys: Object = _gm.system("jobs") if _gm else null
		var blocker: String = str(sys.shift_blocker()) if sys != null else ""
		if blocker.is_empty():
			return {"title": "SHIFT: %s" % str(job["name"]).to_upper(),
					"body": "They're expecting you this %s. Clean money, and it keeps the room." % gs.time_slot.capitalize()}
	return {}

func _bind_operation() -> void:
	var op: Dictionary = gs.active_operation
	var over: Dictionary = _operation_override()
	if not over.is_empty():
		_set_text("Shell/Scroll/Pad/Content/OpCard/V/Head/Title", str(over["title"]))
		_set_text("Shell/Scroll/Pad/Content/OpCard/V/Body", str(over["body"]))
		return
	_set_text("Shell/Scroll/Pad/Content/OpCard/V/Body", op.get("body", ""))
	var actions: Array = op.get("actions", [])
	var btns := ["Move", "Post", "Lay"]
	for i in range(min(btns.size(), actions.size())):
		var b := get_node_or_null("Shell/Scroll/Pad/Content/OpCard/V/Actions/" + btns[i]) as Button
		if b:
			b.text = str(actions[i])

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
	var held: Array = gs.held_blocks
	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Blocks/N", str(held.size()))

	var held_cells := {}
	var names := []
	for b in held:
		held_cells[int(b.get("cell", -1))] = true
		names.append("• " + str(b.get("name", "")))
	for i in range(gs.map_cells):
		var cell := get_node_or_null("Shell/Scroll/Pad/Content/Columns/Turf/V/Map/B%d" % i) as ColorRect
		if cell:
			cell.color = RED if held_cells.has(i) else DIM
	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/List", "\n".join(names))

	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Sold/N", str(gs.soldiers))
	for i in range(6):
		var pip := get_node_or_null("Shell/Scroll/Pad/Content/Columns/Turf/V/Pips/P%d" % i) as TextureRect
		if pip:
			pip.self_modulate = RED if i < gs.soldiers else PIP_DIM

	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Eli", gs.eli_report)

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

func _bind_people() -> void:
	if gs.pending_messages.is_empty():
		return
	var msg: Dictionary = gs.pending_messages[0]
	_set_text("Shell/Scroll/Pad/Content/People/H/Txt/Name", str(msg.get("name", "")) + " TEXTED")
	_set_text("Shell/Scroll/Pad/Content/People/H/Txt/Msg", str(msg.get("preview", "")))
	_set_text("Shell/Scroll/Pad/Content/People/H/Txt/Ago", str(msg.get("timestamp", "")))
	var chat := get_node_or_null("Shell/Scroll/Pad/Content/People/H/Chat") as Button
	if chat:
		chat.text = str(gs.pending_messages.size())

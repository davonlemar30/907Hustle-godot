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

func _bind_content() -> void:
	_bind_all()

func _bind_all() -> void:
	_bind_operation()
	_bind_snapshot()
	_bind_turf()
	_bind_activity()
	_bind_people()

func _bind_operation() -> void:
	var op: Dictionary = gs.active_operation
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

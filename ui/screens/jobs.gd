extends "res://ui/screens/screen_base.gd"
## Jobs — the legitimate income ladder.
##
## Chrome from the base. The two content areas (Current, Board) are built from
## GameState every refresh rather than laid out in the scene: the board's length
## depends on what the player has discovered, and the current-job card only
## exists while they are employed. Nothing here is baked into the .tscn.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const MUTED := Color(0.608, 0.608, 0.608)
const CREAM := Color(0.949, 0.941, 0.922)

@onready var _gm: Node = get_node("/root/GameManager")
@onready var _current: VBoxContainer = $Shell/Scroll/Pad/Content/Current
@onready var _board: VBoxContainer = $Shell/Scroll/Pad/Content/Board

## Which approach the WORK SHIFT button will use. UI-only, so it lives here and
## not in GameState.
var _approach: String = "work_hard"

func _ready() -> void:
	super()
	if _gm and not _gm.action_failed.is_connected(_on_action_failed):
		_gm.action_failed.connect(_on_action_failed)

func _bind_content() -> void:
	_build_current()
	_build_board()

func _on_action_failed(_action: String, reason: String) -> void:
	nav.show_toast(reason)

# --- current employment ----------------------------------------------------

func _build_current() -> void:
	for c in _current.get_children():
		c.queue_free()

	if gs.active_job_id.is_empty():
		_current.add_child(_note("No job. The board is below — day labour always takes walk-ins."))
		return

	var job: Dictionary = gs.active_job()
	var band: Dictionary = gs.job_pay_range(gs.active_job_id)
	var rec: Dictionary = gs.job_records.get(gs.active_job_id, {})
	var card := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	v.add_child(_label(str(job["name"]), "CardTitle", 15, CREAM))
	var rank: int = int(rec.get("rank", 0))
	var meta := "$%d–%d a shift  ·  %s" % [int(band["min"]), int(band["max"]), _slots_text(job)]
	# BR-D3: the rung has a name, and the next one says what it wants.
	var jobs_system: Object = _gm.system("jobs")
	var title := ""
	if jobs_system != null:
		title = str(jobs_system.MANAGERS.title_for(gs.active_job_id, rank))
	if not title.is_empty():
		meta += "  ·  %s" % title.to_upper()
	elif rank > 0:
		meta += "  ·  RANK %d" % rank
	v.add_child(_label(meta, "Muted", 11, MUTED))
	if jobs_system != null:
		var gaps: Array = jobs_system.promotion_gaps(gs.active_job_id)
		if not gaps.is_empty():
			v.add_child(_label("Next rung: %s." % ", ".join(gaps), "Muted", 11, MUTED, true))
	# WS-D4: who runs it, and what that gets you.
	var manager: Dictionary = _manager_for(gs.active_job_id)
	if not manager.is_empty():
		var who := str(manager.get("name", ""))
		var line := ("%s, %s. " % [who, str(manager.get("title", ""))]) if not who.is_empty() else ""
		line += str(manager.get("perk", ""))
		var shifts: int = int(rec.get("shifts", 0))
		if shifts > 0:
			line += "  ·  %d shift%s" % [shifts, "" if shifts == 1 else "s"]
		v.add_child(_label(line.strip_edges(), "Muted", 11, MUTED, true))

	# Attendance is only worth showing once it is a problem.
	var missed: int = int(gs.job_missed.get(gs.active_job_id, 0))
	if missed > 0:
		v.add_child(_label("MISSED %d/3 — a third gets you let go." % missed, "Muted", 11, RED))

	v.add_child(_spacer(4))
	v.add_child(_label("HOW YOU WORK IT", "Kicker", 10, MUTED))
	v.add_child(_approach_row())

	var blocker: String = _shift_blocker()
	var work := Button.new()
	work.custom_minimum_size = Vector2(0, 48)
	work.focus_mode = Control.FOCUS_NONE
	work.theme_type_variation = &"BtnPrimary"
	work.add_theme_font_size_override("font_size", 15)
	work.text = "WORK SHIFT" if blocker.is_empty() else blocker.to_upper()
	work.disabled = not blocker.is_empty()
	tap_connect(work, _on_work)
	v.add_child(work)

	var quit_btn := Button.new()
	quit_btn.custom_minimum_size = Vector2(0, 40)
	quit_btn.focus_mode = Control.FOCUS_NONE
	quit_btn.theme_type_variation = &"BtnSecondary"
	quit_btn.text = "QUIT"
	tap_connect(quit_btn, func() -> void: _gm.dispatch("quit_job", {}))
	v.add_child(quit_btn)

	_current.add_child(card)

## The four canon approaches, as a row of toggles.
func _approach_row() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for a in gs.job_approaches:
		var id: String = str(a["id"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = &"BtnPrimary" if id == _approach else &"BtnSecondary"
		b.add_theme_font_size_override("font_size", 11)
		b.text = str(a["label"])
		b.tooltip_text = str(a["desc"])
		tap_connect(b, _on_pick_approach.bind(id))
		grid.add_child(b)
	return grid

func _on_pick_approach(id: String) -> void:
	_approach = id
	var a: Dictionary = gs.approach_by_id(id)
	nav.show_toast("%s — %s" % [str(a.get("label", "")), str(a.get("desc", ""))])
	_build_current()

func _on_work() -> void:
	_gm.dispatch("work_shift", {"approach": _approach})

## Ask the jobs system directly so the button's label and the dispatch rejection
## can never disagree about why a shift is unavailable.
func _shift_blocker() -> String:
	var sys: Object = _gm.system("jobs")
	if sys == null:
		return ""
	return str(sys.shift_blocker())

# --- the board -------------------------------------------------------------

func _build_board() -> void:
	for c in _board.get_children():
		c.queue_free()
	for job in gs.jobs:
		var id: String = str(job["id"])
		if not id in gs.jobs_discovered:
			continue
		if id == gs.active_job_id:
			continue
		_board.add_child(_board_row(job))

func _board_row(job: Dictionary) -> Control:
	var card := _card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	h.add_child(left)
	left.add_child(_label(str(job["name"]), "CardTitle", 13, CREAM))
	var band: Array = job["pay"]
	var meta := "$%d–%d  ·  %s" % [int(band[0]), int(band[1]), _slots_text(job)]
	if bool(job.get("day_labor", false)):
		meta += "  ·  NO SCHEDULE"
	left.add_child(_label(meta, "Muted", 11, MUTED))
	var manager: Dictionary = _manager_for(str(job["id"]))
	var who := str(manager.get("name", ""))
	if not who.is_empty():
		left.add_child(_label("%s %s" % [who, str(manager.get("title", ""))], "Muted", 11, MUTED))

	var apply := Button.new()
	apply.custom_minimum_size = Vector2(88, 44)
	apply.focus_mode = Control.FOCUS_NONE
	apply.theme_type_variation = &"BtnSecondary"
	apply.add_theme_font_size_override("font_size", 12)
	apply.text = "APPLY"
	apply.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# BR-D2: the tap is a state. Applied reads on the card and the button
	# cannot be spammed; the answer comes by text. BR-D3: an interview
	# offer is a button of its own.
	var application: Dictionary = gs.job_applications.get(str(job["id"]), {})
	var status := str(application.get("status", ""))
	if status == "interview":
		apply.text = "INTERVIEW"
		apply.theme_type_variation = &"BtnPrimary"
		left.add_child(_label("%s wants to see you." % str(_manager_for(str(job["id"])).get("name", "They")),
			"Muted", 11, MUTED))
		tap_connect(apply, func() -> void: _gm.dispatch("start_interview", {"job_id": str(job["id"])}))
	elif status == "interviewed":
		apply.text = "WAITING"
		apply.disabled = true
		left.add_child(_label("They'll let you know.", "Muted", 11, MUTED))
	elif not application.is_empty():
		apply.text = "APPLIED"
		apply.disabled = true
		left.add_child(_label("Waiting to hear back.", "Muted", 11, MUTED))
	else:
		tap_connect(apply, func() -> void: _gm.dispatch("apply_job", {"job_id": str(job["id"])}))
	h.add_child(apply)
	return card

# --- small builders --------------------------------------------------------

func _manager_for(job_id: String) -> Dictionary:
	var sys: Object = _gm.system("jobs")
	if sys == null:
		return {}
	return sys.manager_for(job_id)

func _slots_text(job: Dictionary) -> String:
	var names := ["MORNING", "AFTERNOON", "EVENING", "NIGHT"]
	var out: Array = []
	for s in job.get("slots", []):
		out.append(names[int(s)])
	if out.size() == 4:
		return "ANY SHIFT"
	return " · ".join(out)

func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Card"
	# TOUCH-D3a: PanelContainer alone among Containers defaults to
	# MOUSE_FILTER_STOP, which swallowed a scroll drag starting on any card.
	# PASS lets the drag reach the ScrollContainer above; it does not make the
	# card itself tappable.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

func _label(text: String, variation: String, size: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(variation)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	# Same hazard as surface_base: a wrapping label squeezed by an expanding
	# sibling in an HBox collapses to one character per line.
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _note(text: String) -> Control:
	var card := _card()
	card.add_child(_label(text, "Muted", 12, MUTED, true))
	return card

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

extends RefCounted
## FlowSheets — content builders for the flow-sheet queue (0.1.2).
##
## A flow sheet is a `ModalSheet` shown from the flow itself rather than from
## a screen's own interaction (`market.gd`'s quantity sheet is the latter).
## `ScreenManager` queues plain-data specs (`{"kind": "discovery", ...}`,
## `{"kind": "intro"}`) and `screen_base.gd`'s drain resolves each one to
## content through the builder here, at SHOW time rather than enqueue time —
## copy that could go stale sitting in a queue never does, because nothing
## but the spec itself sits in the queue.
##
## Static, no `class_name` (the stale-cache gotcha), preloaded like
## `screen_base.gd`'s `LOCK_ICON`. Every builder returns a `VBoxContainer`
## whose dismiss `Button` is named "Dismiss" — the drain's whole contract
## with this file, so it can wire the press without knowing which builder
## ran.

const MUTED := Color(0.608, 0.608, 0.608)
const CREAM := Color(0.949, 0.941, 0.922)
## Home's People card uses this same portrait already (`home.tscn`'s "yalonda"
## ExtResource) -- one texture, preloaded here the way LOCK_ICON is.
const YALONDA_PORTRAIT := preload("res://assets/img/yalonda.webp")

## Yalonda's welcome, replacing the old Opening screen. Reads `gs` for the
## player's name and the real rent numbers; writes nothing -- the Opening
## screen's own rule, carried over.
static func build_intro(gs: Node) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	row.add_child(_portrait())

	var dialogue := _label(_intro_copy(gs), "Muted", 14, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT)
	dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dialogue)

	content.add_child(_spacer(4))
	content.add_child(_dismiss_button("GOT IT"))
	return content

## The avatar-styled portrait, `home.tscn`'s Avatar/Pic pattern (PanelContainer
## clipping a TextureRect, `SB_avatar`'s exact style) at a size that reads as a
## portrait rather than the Home card's small thumbnail.
## Default MOUSE_FILTER_STOP is left as-is: this only ever sits inside a
## ModalSheet's card (screen_base.gd's show_sheet/drain), never inside a
## ScrollContainer, so TOUCH-D1's pass-through rule does not apply to it.
static func _portrait() -> PanelContainer:
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(96, 128)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	avatar.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.235, 0.2, 0.216, 1)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.28, 0.26, 1)
	style.set_corner_radius_all(8)
	avatar.add_theme_stylebox_override("panel", style)

	var pic := TextureRect.new()
	pic.texture = YALONDA_PORTRAIT
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.add_child(pic)
	return avatar

## Her voice, the four beats `BUILD_0.1.2_PROMPT.md` names: who you are, the
## stakes, the direction, the warning. The due-day framing carries over
## `opening.gd::_rent_line()`'s three branches (today / tomorrow / N days out)
## into a sentence instead of a card label.
static func _intro_copy(gs: Node) -> String:
	var days: int = maxi(0, int(gs.rent_due_day) - int(gs.day))
	var due: String
	if days <= 0:
		due = "due today"
	elif days == 1:
		due = "due tomorrow"
	else:
		due = "due in %d days" % days
	# WS-D5 (0.8.0): four lines. She has said this before, to other people,
	# and she is not going to say it twice to you. The numbers go to your
	# phone, where she can point at them later.
	return ("So you're the one. %s. Your sister said you'd be coming.\n\n" \
		+ "The room is yours. First week's free because I like her. After " \
		+ "that it's $%d a week, %s, and I don't ask twice.\n\n" \
		+ "The Wash & Go on the corner is short a pair of hands. Lani runs " \
		+ "it. Tell her I sent you.\n\n" \
		+ "Eat something. Lock up when you come in.") \
		% [str(gs.street_name), int(gs.WEEKLY_RENT), due]

## One surface's unlock, celebrated. `card` is `SurfaceVisibility.card_for()`'s
## shape: `{title, line, icon}`, `icon` possibly "" — not every surface has one
## worth showing, and a card with nothing to illustrate just runs title-first.
static func build_discovery(card: Dictionary) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)

	var icon_path := str(card.get("icon", ""))
	if not icon_path.is_empty():
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(56, 56)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(icon)

	content.add_child(_label(str(card.get("title", "")), "CardTitle", 18, CREAM, true))
	content.add_child(_label(str(card.get("line", "")), "Muted", 14, CREAM, true))
	content.add_child(_spacer(4))
	content.add_child(_dismiss_button("LET'S GO"))
	return content

## WS-D4: the hire moment. Whoever runs the place says their two or three
## lines; the pay note under it is the one thing the board would have said.
static func build_hire(job: Dictionary, manager: Dictionary) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.add_child(_label("HIRED", "Kicker", 10, MUTED))
	content.add_child(_label(str(job.get("name", "")), "CardTitle", 18, CREAM, true))
	for line in (manager.get("hire", []) as Array):
		content.add_child(_label(str(line), "Muted", 14, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT))
	var perk := str(manager.get("perk", ""))
	if not perk.is_empty():
		content.add_child(_spacer(2))
		content.add_child(_label(perk, "Kicker", 11, MUTED, true))
	content.add_child(_spacer(4))
	content.add_child(_dismiss_button("FIRST SHIFT" if manager.has("name") and not str(manager.get("name", "")).is_empty() else "GET IN"))
	return content

## BR-D3: the interview. Three questions, two answers each, the manager
## reacting to every answer, then the door. The score rides the final
## Dismiss button into `finish_interview`; the drain wires that button to
## the sheet's exit like every other flow sheet.
static func build_interview(job: Dictionary, manager: Dictionary, gm: Node) -> VBoxContainer:
	var questions: Array = manager.get("questions", [])
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.add_child(_label("INTERVIEW", "Kicker", 10, MUTED))
	content.add_child(_label("%s, %s" % [str(manager.get("name", "")), str(manager.get("title", ""))],
		"CardTitle", 18, CREAM, true))
	var question := _label("", "Muted", 14, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(question)
	var reaction := _label("", "Muted", 13, MUTED, true, HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(reaction)
	var answers := VBoxContainer.new()
	answers.add_theme_constant_override("separation", 8)
	content.add_child(answers)
	var a := Button.new()
	var b := Button.new()
	for button in [a, b]:
		button.custom_minimum_size = Vector2(0, 48)
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"BtnSecondary"
		button.add_theme_font_size_override("font_size", 13)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answers.add_child(button)
	var done := _dismiss_button("LEAVE")
	done.visible = false
	content.add_child(done)
	var state := {"index": 0, "score": 0}
	var show := func() -> void:
		if int(state["index"]) >= questions.size():
			question.text = "\"That's all I need. I'll let you know.\""
			answers.visible = false
			done.visible = true
			return
		var row: Dictionary = questions[int(state["index"])]
		question.text = str(row.get("q", ""))
		a.text = str((row.get("a", {}) as Dictionary).get("text", ""))
		b.text = str((row.get("b", {}) as Dictionary).get("text", ""))
	var answer := func(option: String) -> void:
		if int(state["index"]) >= questions.size():
			return
		var row: Dictionary = questions[int(state["index"])]
		var picked: Dictionary = row.get(option, {})
		state["score"] = int(state["score"]) + int(picked.get("score", 0))
		reaction.text = str(picked.get("say", ""))
		state["index"] = int(state["index"]) + 1
		show.call()
	a.pressed.connect(answer.bind("a"))
	b.pressed.connect(answer.bind("b"))
	done.pressed.connect(func() -> void:
		if gm != null:
			gm.dispatch("finish_interview", {"job_id": str(job.get("id", "")), "score": int(state["score"])}))
	show.call()
	return content

## WS-D4: being let go. One line, what they did, and the door.
static func build_fired(job: Dictionary, manager: Dictionary) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.add_child(_label("LET GO", "Kicker", 10, MUTED))
	content.add_child(_label(str(job.get("name", "")), "CardTitle", 18, CREAM, true))
	content.add_child(_label(str(manager.get("fired", "")), "Muted", 14, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT))
	content.add_child(_spacer(4))
	content.add_child(_dismiss_button("OK"))
	return content

static func _label(text: String, variation: String, size: int, col: Color,
		should_wrap: bool = false,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(variation)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	if should_wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Named "Dismiss" by contract — see the file header.
static func _dismiss_button(text: String) -> Button:
	var b := Button.new()
	b.name = "Dismiss"
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = &"BtnPrimary"
	b.add_theme_font_size_override("font_size", 15)
	return b

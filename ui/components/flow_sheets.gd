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
const AMBER := Color(0.882, 0.651, 0.227)
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

## 1.1.0 (SA-D1): the second sheet of a run, the morning after Yalonda's.
## Juan, saying how a day goes -- four parts, one thing each, the phone, the
## rent, the block. He has never explained this to anybody and is not sure he
## is saying it right, which is why it is short. Like the intro it CHANGES
## NOTHING; it reads the run's real numbers so it cannot promise a rent the
## house will not charge.
static func build_first_morning(gs: Node) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var face := PORTRAITS.portrait_rect("juan", 96)
	if face != null:
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(face)

	var dialogue := _label(_first_morning_copy(gs), "Muted", 14, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT)
	dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dialogue)

	content.add_child(_spacer(4))
	content.add_child(_dismiss_button("BET"))
	return content

static func _first_morning_copy(gs: Node) -> String:
	return ("Juan. She said you got in late.\n\n" \
		+ "Day's four parts out here. Morning, afternoon, evening, night. " \
		+ "Everything you do takes one, then it's the next one. Four things " \
		+ "a day, that's it, so pick.\n\n" \
		+ "Phone buzzes when somebody wants something. Answer it or don't. " \
		+ "People notice either way. Rent's $%d on day %d. She meant that.\n\n" \
		+ "Wash & Go is on the corner if you want a check. Everything else " \
		+ "you find by walking. Walk the block.") \
		% [int(gs.WEEKLY_RENT), int(gs.rent_due_day)]

## TU-D1 (1.3.0): the day break. The playtest kept missing shifts because
## nothing divided one day from the next. This is the divider: the day,
## what the night did (the feed lines the settle wrote), and what today
## holds -- the shift, the bills. A read, never a write.
static func build_day_break(gs: Node, gm: Node) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.add_child(_label("DAY %d" % int(gs.day), "CardTitle", 22, CREAM, false, HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(_label(str(gs.current_district().get("name", "")).to_upper() + "  ·  MORNING", "Kicker", 10, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	var night: Array = day_break_night_lines(gs)
	if not night.is_empty():
		content.add_child(_spacer(2))
		content.add_child(_label("LAST NIGHT", "Kicker", 10, AMBER))
		for line in night:
			content.add_child(_label(str(line), "Muted", 12, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT))
	content.add_child(_spacer(2))
	content.add_child(_label("TODAY", "Kicker", 10, AMBER))
	for line in day_break_today_lines(gs, gm):
		content.add_child(_label(str(line), "Muted", 12, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT))
	content.add_child(_spacer(4))
	content.add_child(_dismiss_button("MORNING"))
	return content

## The feed lines the night wrote: entries stamped with the day that ended
## and the NIGHT slot, oldest first, at most five.
static func day_break_night_lines(gs: Node) -> Array:
	var out: Array = []
	for entry in gs.activity_log:
		var e: Dictionary = entry
		if int(e.get("day", -1)) == int(gs.day) - 1 and str(e.get("time", "")) == "NIGHT":
			out.push_front(str(e.get("text", "")))
	if out.size() > 5:
		out = out.slice(out.size() - 5)
	return out

## What today holds, in words: the shift and when it runs, the rent, the
## phone. Reads the run's real numbers.
static func day_break_today_lines(gs: Node, gm: Node) -> Array:
	var out: Array = []
	if not str(gs.active_job_id).is_empty():
		var job: Dictionary = gs.active_job()
		var names := ["morning", "afternoon", "evening", "night"]
		var when: Array = []
		for slot in (job.get("slots", []) as Array):
			when.append(names[clampi(int(slot), 0, 3)])
		var missed: int = int(gs.job_missed.get(gs.active_job_id, 0))
		var line := "Shift at %s. It runs %s." % [str(job.get("name", "work")), " or ".join(when) if when.size() <= 2 else "%s through %s" % [when[0], when[when.size() - 1]]]
		if missed > 0:
			line += " You have missed %d. Do not miss this one." % missed
		out.append(line)
	var rent_in: int = int(gs.rent_due_day) - int(gs.day)
	if int(gs.rent_arrears_day) >= 0:
		out.append("The rent is late. Yalonda knows.")
	elif rent_in == 0:
		out.append("Rent is due today: $%d. Pay it on the Phone." % int(gs.WEEKLY_RENT))
	elif rent_in > 0 and rent_in <= 3:
		out.append("Rent in %d day%s: $%d." % [rent_in, "" if rent_in == 1 else "s", int(gs.WEEKLY_RENT)])
	var phone_in: int = int(gs.phone_due_day) - int(gs.day)
	if not bool(gs.phone_active):
		out.append("The phone is off. The Phone Store turns it back on.")
	elif int(gs.phone_days_past_due) > 0:
		out.append("The phone bill is late. It goes quiet before it goes dead.")
	elif phone_in >= 0 and phone_in <= 2:
		out.append("Phone bill in %d day%s: $%d." % [phone_in, "" if phone_in == 1 else "s", int(gs.PHONE_BILL)])
	var obligations: Object = gm.system("obligations") if gm != null else null
	if obligations != null and out.size() == 1 and str(out[0]).begins_with("Shift"):
		pass
	if out.is_empty():
		out.append("Nothing owed today. Four parts, and they are yours.")
	return out

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
static func build_hire(job: Dictionary, manager: Dictionary, gm: Node = null) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.add_child(_label("HIRED", "Kicker", 10, MUTED))
	_add_face(content, str(manager.get("name", "")))
	content.add_child(_label(str(job.get("name", "")), "CardTitle", 18, CREAM, true))
	for line in (manager.get("hire", []) as Array):
		content.add_child(_label(str(line), "Muted", 14, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT))
	var perk := str(manager.get("perk", ""))
	if not perk.is_empty():
		content.add_child(_spacer(2))
		content.add_child(_label(perk, "Kicker", 11, MUTED, true))
	content.add_child(_spacer(4))
	var done := _dismiss_button("FIRST SHIFT" if manager.has("name") and not str(manager.get("name", "")).is_empty() else "GET IN")
	# TU-D5 (1.3.0): the word about money, when you have standing to have
	# it -- you came from a job, or you have done this before. Three ways:
	# take it, ask for more (charisma), name a number (intelligence, more,
	# and a miss costs a point with the manager). One word, then the door.
	var jobs_system: Object = gm.system("jobs") if gm != null else null
	var job_id := str(job.get("id", ""))
	if jobs_system != null and bool(jobs_system.negotiation_open(job_id)):
		content.add_child(_label("ABOUT THE MONEY", "Kicker", 10, AMBER))
		var reaction := _label("", "Muted", 13, MUTED, true, HORIZONTAL_ALIGNMENT_LEFT)
		var options := VBoxContainer.new()
		options.name = "Negotiate"
		options.add_theme_constant_override("separation", 8)
		content.add_child(options)
		content.add_child(reaction)
		var ask := func(mode: String) -> void:
			var before: Dictionary = gm.system("game_state_probe") if false else {}
			gm.dispatch("negotiate_pay", {"job_id": job_id, "mode": mode})
			var rec: Dictionary = (gm.get_node("/root/GameState") as Node).job_records.get(job_id, {})
			reaction.text = ("They went for it: %d percent over the board." % int(round(float(rec.get("raise", 0.0)) * 100.0))) \
				if float(rec.get("raise", 0.0)) > 0.0 else "That was the number. It still is."
			options.visible = false
			done.visible = true
		for entry in [["TAKE IT", ""], ["ASK FOR MORE", "ask"], ["NAME A NUMBER", "number"]]:
			var b := Button.new()
			b.text = str(entry[0])
			b.name = "Negotiate_" + str(entry[0]).replace(" ", "")
			b.custom_minimum_size = Vector2(0, 48)
			b.focus_mode = Control.FOCUS_NONE
			b.theme_type_variation = &"BtnSecondary"
			b.add_theme_font_size_override("font_size", 13)
			var mode := str(entry[1])
			if mode.is_empty():
				b.pressed.connect(func() -> void:
					options.visible = false
					done.visible = true)
			else:
				b.pressed.connect(ask.bind(mode))
			options.add_child(b)
		done.visible = false
	content.add_child(done)
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
	_add_face(content, str(manager.get("name", "")))
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

const PORTRAITS := preload("res://data/portraits.gd")

## OG-D3: a 96px face, centered, or nothing.
static func _add_face(content: VBoxContainer, name: String) -> void:
	var face := PORTRAITS.portrait_rect(name, 96)
	if face == null:
		return
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(face)

## OG-D3: a district's header banner, 120 tall, or nothing.
static func _add_header(content: VBoxContainer, district_id: String) -> void:
	var banner := PORTRAITS.header_rect(PORTRAITS.district_header(district_id), 120)
	if banner != null:
		content.add_child(banner)

## OG-D3: the ride. The transition between districts is a card: the mode,
## the line about the ride, the destination's banner, and the door.
static func build_ride(spec: Dictionary) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.add_child(_label(str(spec.get("kicker", "THE PEOPLE MOVER")), "Kicker", 10, MUTED))
	_add_header(content, str(spec.get("district_id", "")))
	content.add_child(_label(str(spec.get("title", "")), "CardTitle", 18, CREAM, true))
	content.add_child(_label(str(spec.get("line", "")), "Muted", 14, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT))
	var cost := str(spec.get("cost", ""))
	if not cost.is_empty():
		content.add_child(_label(cost, "Kicker", 11, MUTED))
	content.add_child(_spacer(4))
	content.add_child(_dismiss_button(str(spec.get("button", "STEP OFF"))))
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

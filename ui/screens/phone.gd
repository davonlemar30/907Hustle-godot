extends "res://ui/screens/surface_base.gd"
## Switchboard: responsive categories, sender list and conversation detail.
## Presentation only; replies, payments and offline rules stay in the systems.
const BLUE := Color(0.373, 0.663, 0.847)
const PORTRAITS := preload("res://data/portraits.gd")
const CYAN := Color(0.475, 0.733, 0.757)

func _obligations() -> Object:
	return _gm.system("obligations")

func _phone() -> Object:
	return _gm.system("phone")

## TU-D3 (1.3.0): the phone in your hand. The screen opens on a hub -- the
## owner's mockup: MESSAGES, BILLS, INVENTORY, OPPORTUNITIES, PEOPLE as
## cards, then the three most recent conversations -- and Messages is a
## contact list and a thread, grouped by the part of the day, with the
## unread line and your own replies on the right.
const CATEGORIES := {"hub": "PHONE", "texts": "MESSAGES", "contacts": "PEOPLE", "bills": "BILLS", "inventory": "INVENTORY", "log": "TODAY'S LOG", "intel": "WORD AROUND TOWN"}
var _category := "hub"
var _sender := ""
var _mobile_detail := false
var _wide := false
var _resize_pending := false
var _manage := false
var _query := ""
var _reply_only := false
var _thread_rows: Array[Control] = []
var _scroll_reset := false
var _thread_scroll: ScrollContainer
var _latest_target: Control
var _jump_generation := 0
var _empty_filter: Label
const PEOPLE := preload("res://ui/screens/people.gd")

func _ready() -> void:
	# TU-D1/D3: Home's text card asks for Messages by name.
	if nav != null and nav.has_meta("phone_category"):
		_category = str(nav.get_meta("phone_category"))
		nav.remove_meta("phone_category")
	super()
	resized.connect(_schedule_resize)

func _schedule_resize() -> void:
	if not _resize_pending and (size.x >= 960.0) != _wide:
		_resize_pending = true
		_resize_layout.call_deferred()

func _resize_layout() -> void:
	_resize_pending = false
	if is_inside_tree():
		refresh()

func _bind_content() -> void:
	var scroll := $Shell/Scroll as ScrollContainer
	var thread_position := _thread_scroll.scroll_vertical if is_instance_valid(_thread_scroll) else 0
	var previous := 0 if _scroll_reset else scroll.scroll_vertical
	_scroll_reset = false
	var focused := get_viewport().gui_get_focus_owner()
	var focus_key := str(focused.name) if focused != null and is_ancestor_of(focused) else ""
	super()
	if not focus_key.is_empty():
		var replacement := body.find_child(focus_key, true, false) as Control
		if replacement != null: replacement.grab_focus.call_deferred()
	scroll.set_deferred("scroll_vertical", previous)
	if is_instance_valid(_thread_scroll): _thread_scroll.set_deferred("scroll_vertical", thread_position)

func _build_body() -> void:
	var old_toolbar := get_node_or_null("Shell/PhoneToolbar")
	if old_toolbar != null:
		old_toolbar.get_parent().remove_child(old_toolbar)
		old_toolbar.free()
	_thread_scroll = null
	_latest_target = null
	_empty_filter = null
	_thread_rows.clear()
	_wide = size.x >= 960.0
	var offline: bool = not gs.phone_active
	_set_text("Shell/Scroll/Pad/Content/Title/H", "NO SERVICE" if offline else "PHONE")
	_set_text("Shell/Scroll/Pad/Content/Title/Sub", "SWITCHBOARD  /  " + ("Messages held until service returns" if offline else "Texts, people and word on the street"))
	$Shell/Scroll/Pad/Content/Title/Sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Shell/Scroll/Pad/Content/Gap.hide()
	$Shell/Scroll/Pad/Content/Title.visible = _wide
	$Shell/TopBar/HBox/Brand.custom_minimum_size.y = 66 if _wide else 36
	if offline:
		body.add_child(_offline_card())
	var root_body := body
	var layout: BoxContainer = HBoxContainer.new() if _wide else VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	root_body.add_child(layout)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 6)
	if _wide:
		rail.custom_minimum_size.x = 175
	if _wide:
		var rail_card := _switch_panel()
		layout.add_child(rail_card)
		rail_card.add_child(rail)
	else:
		# One native picker replaces two rows of oversized category buttons.
		var picker := OptionButton.new()
		picker.name = "PhoneSection"
		picker.custom_minimum_size.y = 44
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for key in CATEGORIES:
			picker.add_item(CATEGORIES[key])
		picker.fit_to_longest_item = false
		if _category == "texts" and _mobile_detail:
			picker.set_item_text(CATEGORIES.keys().find("texts"), "MESSAGES / " + _sender.to_upper())
		picker.select(CATEGORIES.keys().find(_category))
		picker.item_selected.connect(func(index: int) -> void: _choose_category.call_deferred(CATEGORIES.keys()[index]))
		var toolbar := HBoxContainer.new()
		toolbar.name = "PhoneToolbar"
		if _category == "texts" and _mobile_detail:
			var back := _switch_button("‹ INBOX", false, _back_to_messages)
			back.custom_minimum_size.x = 86
			toolbar.add_child(back)
		toolbar.add_child(picker)
		$Shell.add_child(toolbar)
		$Shell.move_child(toolbar, $Shell/Scroll.get_index())
	for key in CATEGORIES:
		var caption: String = CATEGORIES[key]
		if key == "texts":
			caption += "  ·  %d TO REPLY" % _reply_count() if _reply_count() > 0 else ""
		elif key == "bills":
			var due := 0
			for bill in _bills():
				if int(bill.get("severity", 0)) > 0:
					due += 1
			if due > 0:
				caption += "  ·  %d DUE" % due
		var tab := _switch_button(caption, key == _category, _choose_category.bind(key), 48)
		if not _wide:
			tab.custom_minimum_size.x = 155 if key == "intel" else 104
		tab.name = "Category_" + key
		rail.add_child(tab)
	if not _wide: rail.free()
	var pane := VBoxContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.add_theme_constant_override("separation", 12)
	layout.add_child(pane)
	body = pane
	match _category:
		"hub": _build_hub(offline)
		"texts": _build_switchboard(offline)
		"contacts": _build_contacts()
		"bills": _build_bills()
		"inventory": _build_inventory()
		"log": _build_log()
		"intel": _build_intel(offline)
	body = root_body

func _reply_count() -> int:
	if not gs.phone_active:
		return 0
	var count := 0
	for message in gs.phone_inbox:
		if _phone().awaits_reply(message):
			count += 1
	return count

func _switch_panel() -> PanelContainer:
	var panel := card()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.027, 0.94)
	style.border_color = Color(0.20, 0.20, 0.20)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _switch_button(text: String, primary: bool, handler: Callable, height: int = 44) -> Button:
	# Deferred callbacks keep refresh() from freeing the emitting control.
	var activate := func() -> void: handler.call_deferred()
	var control := button(text, primary, activate, height)
	control.name = "Action_%s" % text.sha256_text().left(12)
	control.focus_mode = Control.FOCUS_ALL
	if primary:
		var selected := StyleBoxFlat.new()
		selected.bg_color = Color(0.14, 0.045, 0.04, 0.97)
		selected.border_color = RED
		selected.set_border_width_all(1)
		selected.border_width_left = 3
		selected.set_content_margin_all(12)
		control.add_theme_stylebox_override("normal", selected)
		control.add_theme_color_override("font_color", CREAM)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.gui_input.connect(func(event: InputEvent) -> void:
		if not control.disabled and event is InputEventKey and event.is_action_pressed("ui_accept") and not event.is_echo():
			control.accept_event()
			activate.call())
	return control

func _choose_category(key: String) -> void:
	_category = key
	_manage = false
	_scroll_reset = true
	refresh()
	if key == "texts" and _mobile_detail: _jump_to_message.call_deferred()

func _choose_sender(sender: String) -> void:
	_sender = sender
	_category = "texts"
	_manage = false
	_scroll_reset = true
	_mobile_detail = true
	refresh()
	_jump_to_message.call_deferred()

func _back_to_messages() -> void:
	_category = "texts"
	_mobile_detail = false
	_manage = false
	_scroll_reset = true
	refresh()

func _build_switchboard(offline: bool) -> void:
	if offline:
		body.add_child(note("%d messages waiting for service." % gs.phone_held_inbox.size()))
		return
	if gs.phone_inbox.is_empty():
		_sender = ""
		_mobile_detail = false
		body.add_child(note("No messages yet. The street will find you."))
		return
	var senders: Array[String] = []
	for message in gs.phone_inbox:
		var sender := str(message.get("from", ""))
		if not senders.has(sender):
			senders.append(sender)
	if not senders.has(_sender):
		_sender = senders[0]
	var columns: BoxContainer = HBoxContainer.new() if _wide else VBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	if _wide or not _mobile_detail:
		var list := VBoxContainer.new()
		list.name = "Conversations"
		if _wide:
			list.custom_minimum_size.x = 240
		var list_card := _switch_panel()
		columns.add_child(list_card)
		_mount_pane(list_card, list)
		list.add_child(label("MESSAGES", "CardTitle", 20, CREAM))
		list.add_child(label("%d conversations · %s" % [senders.size(), "1 reply pending" if _reply_count() == 1 else "%d replies pending" % _reply_count()], "Muted", 12, MUTED, true))
		var search := LineEdit.new()
		search.name = "SearchConversations"
		search.placeholder_text = "Find a person or message"
		search.custom_minimum_size.y = 44
		search.text = _query
		search.text_changed.connect(_filter_query)
		list.add_child(search)
		var filters := HBoxContainer.new()
		for only in [false, true]:
			var filter := _switch_button("NEEDS REPLY" if only else "ALL", only == _reply_only, _set_reply_filter.bind(only))
			filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			filters.add_child(filter)
		list.add_child(filters)
		for sender in senders:
			var thread := _thread_row(sender)
			list.add_child(thread)
			_thread_rows.append(thread)
		_empty_filter = label("No conversations match. Try All or another search.", "Muted", 13, MUTED, true)
		list.add_child(_empty_filter)
		if gs.phone_inbox.size() > 1:
			list.add_child(_switch_button("MANAGE MESSAGES" if not _manage else "DONE", false, _toggle_manage))
			if _manage:
				list.add_child(note("Deleting removes message history, including any unanswered choices."))
				list.add_child(_switch_button("DELETE ALL %d MESSAGES" % gs.phone_inbox.size(), false, _confirm_clear))
		_apply_filter()
	# A single conversation can open immediately; a populated inbox starts at list.
	if _wide or _mobile_detail:
		var conversation := VBoxContainer.new()
		conversation.name = "Conversation"
		conversation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		conversation.add_theme_constant_override("separation", 12)
		var conversation_card := _switch_panel()
		conversation_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _wide: conversation_card.custom_minimum_size.y = 440
		columns.add_child(conversation_card)
		_mount_pane(conversation_card, conversation)
		var header := HBoxContainer.new()
		conversation.add_child(header)
		var face := PORTRAITS.portrait_rect(_sender, 48)
		if face != null: header.add_child(face)
		var title := label(_sender.to_upper(), "CardTitle", 24, CREAM, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var manage := _switch_button("DONE" if _manage else "MANAGE", false, _toggle_manage)
		manage.custom_minimum_size.x = 70
		header.add_child(manage)
		if _sender.to_lower().begins_with("yalonda"):
			for bill in _bills():
				if str(bill.get("id", "")) == "rent":
					conversation.add_child(label("RENT  ·  $%d  ·  %s  ·  %s" % [int(bill["amount"]), str(bill["due"]), str(bill["status"])], "Kicker", 12, AMBER, true))
		var messages: Array = gs.phone_inbox.duplicate()
		messages.reverse()
		var pending_target: Control
		var last_group := ""
		var unread_marked := false
		for message in messages:
			if str(message.get("from", "")) != _sender:
				continue
			# TU-D3: one divider per part of the day, and one UNREAD line
			# before the first thing still waiting on you.
			var group := str(_phone().stamp(message))
			if group != last_group:
				conversation.add_child(_divider(group, MUTED))
				last_group = group
			if not unread_marked and _phone().awaits_reply(message):
				conversation.add_child(_divider("UNREAD", RED))
				unread_marked = true
			var bubble := _message_card(message)
			conversation.add_child(bubble)
			_latest_target = bubble
			if pending_target == null and _phone().awaits_reply(message): pending_target = bubble
		if pending_target != null: _latest_target = pending_target
		if _manage:
			conversation.add_child(_switch_button("ARCHIVE THIS THREAD", false, _archive_thread.bind(_sender), 44))

func _mount_pane(panel: PanelContainer, content: VBoxContainer) -> void:
	if not _wide:
		panel.add_child(content)
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = maxf(300, size.y - 390)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	scroll.add_child(content)
	if content.name == "Conversation": _thread_scroll = scroll

func _jump_to_message() -> void:
	_jump_generation += 1
	var generation := _jump_generation
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _jump_generation or not is_instance_valid(_latest_target): return
	var scroll := _thread_scroll if is_instance_valid(_thread_scroll) else $Shell/Scroll as ScrollContainer
	scroll.ensure_control_visible(_latest_target)

func _sender_text(sender: String) -> String:
	var text := ""
	for message in gs.phone_inbox:
		if str(message.get("from", "")) == sender: text += " " + str(message.get("text", ""))
	return text

func _filter_query(query: String) -> void:
	_query = query
	_apply_filter()

func _set_reply_filter(only: bool) -> void:
	_reply_only = only
	refresh()

func _toggle_reply_filter() -> void:
	_reply_only = not _reply_only
	refresh()

func _apply_filter() -> void:
	var matches := 0
	for row in _thread_rows:
		row.visible = (_query.strip_edges().is_empty() or _query.strip_edges().to_lower() in str(row.get_meta("search"))) and (not _reply_only or int(row.get_meta("pending")) > 0)
		if row.visible: matches += 1
	if is_instance_valid(_empty_filter): _empty_filter.visible = matches == 0

func _toggle_manage() -> void:
	_manage = not _manage
	refresh()

func _confirm_clear() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete message history?"
	dialog.dialog_text = "Delete all %d messages, including unanswered choices? This cannot be undone." % gs.phone_inbox.size()
	dialog.confirmed.connect(func() -> void: _on_clear_inbox.call_deferred())
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(300, 180))

# Existing section builders retain their data and action contracts.
func _accordion(_key: String, title: String, meta: String, badge_colour: Color = MUTED) -> void:
	body.add_child(label(title.to_upper() + ("  ·  " + meta if not meta.is_empty() else ""), "CardTitle", 16, badge_colour))

func _on_toggle(key: String) -> void:
	_choose_category(key)

func _is_open(key: String) -> bool:
	return key == _category

# --- offline ---------------------------------------------------------------

## Canon's `card locked`: the one place that can restore service, and it is not
## on the phone. Paying here is the store surface, which works with a dead line.
func _offline_card() -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("SIGNAL UNAVAILABLE", "CardTitle", 13, RED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(label("%d DAYS PAST DUE" % gs.phone_days_past_due, "Mono", 11, RED))

	v.add_child(label(
		"Pay $%d at Night Owl to start restoration. Online payment requires active service and a laptop." % gs.PHONE_BILL,
		"Muted", 12, MUTED, true))

	var blocked: String = _obligations().pay_phone_blocker("store")
	var b := button(
		"PAY AT NIGHT OWL  ·  $%d" % gs.PHONE_BILL if blocked.is_empty() else blocked.to_upper(),
		blocked.is_empty(), _on_pay_phone.bind("store"), 46)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	# Canon's action-copy line. Service comes back on the NEXT action, not this
	# one — the deferred restoration, said out loud so it does not read as a bug.
	v.add_child(label("Free  ·  service restores after the next action", "Muted", 11, MUTED))
	return c

# --- texts -----------------------------------------------------------------

func _message_card(message: Dictionary) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	var incoming_margin := MarginContainer.new()
	incoming_margin.add_theme_constant_override("margin_right", 22)
	root.add_child(incoming_margin)
	var c := _switch_panel()
	incoming_margin.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var meta := HBoxContainer.new()
	v.add_child(meta)
	var who := _avatar(str(message.get("from", "")), 24)
	meta.add_child(who)
	var stamp := label(str(message.get("from", "")).to_upper(), "Kicker", 10, MUTED)
	stamp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(stamp)
	var dismiss := _switch_button("×", false, _on_dismiss.bind(str(message.get("id", ""))), 44)
	dismiss.custom_minimum_size = Vector2(44, 44)
	dismiss.visible = _manage
	dismiss.tooltip_text = "Delete this message"
	meta.add_child(dismiss)
	v.add_child(label(str(message.get("text", "")), "Muted", 16, CREAM, true))

	# Canon shows Accept / Turn it down when the offer behind the text is still
	# live. Nothing pushes a job_offer in this build yet (jobs.gd hires direct),
	# so this stays unreachable until the application pipeline lands.
	var action: Dictionary = message.get("action", {})
	# WS-D3: two answers, or the one you gave. The buttons are the tap
	# targets; what they say is the player's own voice.
	var reply: Dictionary = action.get("reply", {})
	if not reply.is_empty():
		var replied := str(reply.get("replied", ""))
		if replied == "a" or replied == "b":
			var outgoing := _switch_panel()
			outgoing.self_modulate = Color(0.75, 0.95, 1.0)
			var reply_box := VBoxContainer.new()
			outgoing.add_child(reply_box)
			reply_box.add_child(label("YOU", "Kicker", 10, CYAN))
			reply_box.add_child(label(str((reply[replied] as Dictionary).get("text", "")), "Muted", 16, CYAN, true))
			var sent := label("SENT  ✓", "Kicker", 10, CYAN)
			sent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			reply_box.add_child(sent)
			var outgoing_margin := MarginContainer.new()
			outgoing_margin.add_theme_constant_override("margin_left", 26)
			outgoing_margin.add_child(outgoing)
			root.add_child(outgoing_margin)
		elif replied == "ghost":
			v.add_child(label("left on read", "Kicker", 10, MUTED))
		else:
			v.add_child(label("YOUR REPLY", "Kicker", 11, AMBER))
			var id := str(message.get("id", ""))
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			for option in ["a", "b"]:
				var answer := _switch_button(str((reply[option] as Dictionary).get("text", "")), false,
					_on_reply.bind(id, option), 52)
				answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				answer.add_theme_font_size_override("font_size", 15)
				row.add_child(answer)
			root.add_child(row)
	if not action.is_empty() and str(action.get("kind", "")) == "job_offer":
		v.add_child(label("OFFER ATTACHED", "Kicker", 10, AMBER))
	elif not action.is_empty() and str(action.get("kind", "")) == "tip":
		v.add_child(label(_tip_stamp(action), "Kicker", 10, AMBER))
	elif not action.is_empty() and str(action.get("kind", "")) == "dre_debt":
		_bind_dre_debt_card(v)
	return root

## Reads `gs.dre_account` live rather than anything carried on the message —
## the same text sitting unread for three days has to show today's true
## number, not the number the day it arrived. Buttons disappear once
## `gs.debt` is actually zero (paid through this same card, most likely),
## which is what keeps a stale reminder from offering a dead action.
func _bind_dre_debt_card(v: VBoxContainer) -> void:
	v.add_child(label(_dre_debt_stamp(), "Kicker", 10, AMBER))
	if gs.debt <= 0:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var repay := button("PAY $%d" % gs.debt, true, _on_dre_repay, 40)
	repay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(repay)
	var status := str(gs.dre_account.get("status", "clear"))
	var extension_used: bool = bool(gs.dre_account.get("extension_used", false))
	if status in ["active", "due"] and not extension_used:
		var extend := button("ASK FOR 2 MORE DAYS", false, _on_dre_extension, 40)
		extend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(extend)

func _dre_debt_stamp() -> String:
	var status := str(gs.dre_account.get("status", "clear"))
	match status:
		"clear":
			return "SETTLED"
		"suspended":
			return "SUSPENDED"
		"overdue":
			return "OVERDUE"
		"due":
			return "DUE TODAY"
		_:
			return "DUE DAY %d" % int(gs.dre_account.get("due_day", gs.day))

func _on_dre_repay() -> void:
	_gm.dispatch("dre_repay", {})

func _on_dre_extension() -> void:
	_gm.dispatch("dre_request_extension", {})

## GOOD TONIGHT while a windowed tip's slots have not passed yet, GOOD TODAY
## for a standing feed's day (no window at all — Pherris and Eli read the
## board, they do not name a slot), EXPIRED once the day has turned or the
## window's last slot is behind the current one.
func _tip_stamp(action: Dictionary) -> String:
	var expires_day: int = int(action.get("expires_day", -1))
	if gs.day > expires_day:
		return "EXPIRED"
	var slots: Array = action.get("slots", [])
	if slots.is_empty():
		return "GOOD TODAY"
	var latest: int = -1
	for slot in slots:
		latest = maxi(latest, int(slot))
	if int(gs.time_slots_today) > latest:
		return "EXPIRED"
	return "GOOD TONIGHT"

func _on_dismiss(id: String) -> void:
	_gm.dispatch("dismiss_phone_message", {"id": id})

func _on_reply(id: String, option: String) -> void:
	_gm.dispatch("phone_reply", {"id": id, "option": option})

func _on_clear_inbox() -> void:
	_gm.dispatch("clear_phone_inbox", {})

# --- TU-D3: the hub, the rows, the thread furniture, the inventory ------------

## The avatar: the face when the game has it, two letters when it does not.
func _avatar(name: String, px: int) -> Control:
	var face := PORTRAITS.portrait_rect(name, px)
	if face != null:
		return face
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(px, px)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.13, 1)
	style.border_color = Color(0.25, 0.25, 0.26, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	box.add_theme_stylebox_override("panel", style)
	var initials := label(name.left(2).to_upper(), "CardTitle", maxi(10, px / 2), CREAM)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(initials)
	return box

## A conversation in the list: avatar, name, the last thing they said, when,
## and a red count of what is waiting on you.
func _thread_row(sender: String) -> Control:
	var latest: Dictionary = {}
	var pending := 0
	for message in gs.phone_inbox:
		if str(message.get("from", "")) == sender:
			if latest.is_empty(): latest = message
			if _phone().awaits_reply(message): pending += 1
	var preview := str(latest.get("text", "")).replace("\n", " ")
	if preview.length() > 60: preview = preview.left(57) + "..."
	var thread := HBoxContainer.new()
	thread.add_theme_constant_override("separation", 10)
	thread.add_child(_avatar(sender, 44))
	var item := _switch_button(sender.to_upper() + "\n" + preview, (_wide and sender == _sender), _choose_sender.bind(sender), 64)
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thread.add_child(item)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.add_child(label(_short_stamp(latest), "Mono", 10, MUTED))
	if pending > 0:
		var badge := label(str(pending), "Mono", 11, CREAM)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var badge_box := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = RED
		style.set_corner_radius_all(9)
		style.set_content_margin_all(3)
		badge_box.add_theme_stylebox_override("panel", style)
		badge_box.add_child(badge)
		badge_box.size_flags_horizontal = Control.SIZE_SHRINK_END
		side.add_child(badge_box)
	thread.add_child(side)
	thread.add_child(label("›", "Muted", 16, MUTED))
	thread.set_meta("search", (sender + " " + _sender_text(sender)).to_lower())
	thread.set_meta("pending", pending)
	return thread

## TODAY / YESTERDAY / DAY N, the way a phone says it.
func _short_stamp(message: Dictionary) -> String:
	var day: int = int(message.get("day", 0))
	if day == int(gs.day):
		return "TODAY"
	if day == int(gs.day) - 1:
		return "YESTERDAY"
	return "DAY %d" % day

func _divider(text: String, colour: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for side in [0, 1]:
		var line := ColorRect.new()
		line.color = Color(colour, 0.35)
		line.custom_minimum_size = Vector2(0, 1)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if side == 0:
			row.add_child(line)
		else:
			var l := label(text, "Kicker", 10, colour)
			row.add_child(l)
			row.add_child(line)
	return row

func _archive_thread(sender: String) -> void:
	for message in gs.phone_inbox.duplicate():
		if str(message.get("from", "")) == sender:
			_gm.dispatch("dismiss_phone_message", {"id": str(message.get("id", ""))})
	_mobile_detail = false
	_manage = false
	refresh()

## The hub. Five cards and the three most recent conversations.
func _build_hub(offline: bool) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	# MESSAGES
	var pending: int = _reply_count()
	var senders := 0
	var seen: Array = []
	for message in gs.phone_inbox:
		if not str(message.get("from", "")) in seen:
			seen.append(str(message.get("from", "")))
			senders += 1
	grid.add_child(_hub_card("MESSAGES", str(pending) if pending > 0 else str(senders),
		("TO ANSWER" if pending > 0 else ("THREADS" if senders > 0 else "NOTHING YET")) if not offline else "HELD",
		RED if pending > 0 else CYAN, _choose_category.bind("texts"), pending))
	# BILLS
	var rent_in: int = int(gs.rent_due_day) - int(gs.day)
	var bill_head := ""
	var bill_sub := ""
	var bill_col: Color = AMBER
	if int(gs.rent_arrears_day) >= 0 or rent_in < 0:
		bill_head = "RENT LATE"
		bill_sub = "PAY IT"
		bill_col = RED
	elif rent_in == 0:
		bill_head = "RENT DUE"
		bill_sub = "TODAY"
		bill_col = RED
	else:
		bill_head = "RENT DUE IN"
		bill_sub = "%d DAY%s" % [rent_in, "" if rent_in == 1 else "S"]
	var bills := _hub_card("BILLS", bill_head, bill_sub, bill_col, _choose_category.bind("bills"), 0)
	var obligations: Object = _obligations()
	if obligations != null and str(obligations.pay_rent_blocker()).is_empty():
		var pay := _switch_button("PAY EARLY  $%d" % int(gs.WEEKLY_RENT) if rent_in > 0 else "PAY RENT  $%d" % int(gs.WEEKLY_RENT), true, _on_pay_bill.bind("pay_rent", {}), 44)
		(bills.get_child(0) as VBoxContainer).add_child(pay)
	grid.add_child(bills)
	# INVENTORY
	var items: int = int(gs.cargo_used()) + (gs.hot_goods as Array).size()
	for pid in (gs.trunk as Dictionary).keys():
		items += int(gs.trunk[pid])
	grid.add_child(_hub_card("INVENTORY", str(items), "ITEM" if items == 1 else "ITEMS", CYAN, _choose_category.bind("inventory"), 0))
	# OPPORTUNITIES
	var lead: Dictionary = _latest_lead()
	if lead.is_empty():
		grid.add_child(_hub_card("OPPORTUNITIES", "QUIET", "Nothing on the wire.", MUTED, _choose_category.bind("intel"), 0))
	else:
		var lead_card := _hub_card("OPPORTUNITIES", "NEW LEAD", _lead_line(lead), RED, _choose_sender.bind(str(lead.get("from", ""))), 0)
		grid.add_child(lead_card)
	# PEOPLE
	grid.add_child(_hub_card("PEOPLE", str(_known_contacts()), "KNOWN", Color(0.6, 0.5, 0.85), _choose_category.bind("contacts"), 0))
	# RECENT
	var head := HBoxContainer.new()
	body.add_child(head)
	var title := label("RECENT MESSAGES", "CardTitle", 13, CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var all := _switch_button("VIEW ALL", false, _choose_category.bind("texts"), 44)
	all.custom_minimum_size.x = 90
	head.add_child(all)
	if offline:
		body.add_child(note("%d messages waiting for service." % gs.phone_held_inbox.size()))
		return
	if gs.phone_inbox.is_empty():
		body.add_child(note("No messages yet. The street will find you."))
		return
	var shown := 0
	for sender in seen:
		if shown >= 3:
			break
		body.add_child(_thread_row(str(sender)))
		shown += 1

func _hub_card(title: String, big: String, sub: String, colour: Color, handler: Callable, badge: int) -> Control:
	var c := _switch_panel()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 118)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := label(title, "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if badge > 0:
		head.add_child(label(str(badge), "Mono", 11, RED))
	var b := label(big, "CardTitle", 26 if big.length() <= 6 else 15, colour, true)
	v.add_child(b)
	v.add_child(label(sub, "Muted", 11, MUTED, true))
	var open := _switch_button("OPEN", false, handler, 44)
	open.name = "Open_" + title
	v.add_child(open)
	return c

## The newest text that is a lead: a tip, a crew idea, an offer.
func _latest_lead() -> Dictionary:
	for message in gs.phone_inbox:
		var action: Dictionary = message.get("action", {})
		if str(action.get("kind", "")) in ["tip", "crew_idea", "job_offer"]:
			return message
	return {}

func _lead_line(message: Dictionary) -> String:
	var text := str(message.get("text", "")).replace("\n", " ")
	if text.length() > 48:
		text = text.left(45) + "..."
	return "%s: %s" % [str(message.get("from", "")), text]

## What you are holding: cash by colour, product with what it sells for here,
## the trunk, what is under your coat, the kit.
func _build_inventory() -> void:
	body.add_child(label("WHAT YOU ARE HOLDING", "CardTitle", 20, CREAM))
	var economy: Object = _gm.system("economy")
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)
	v.add_child(label("CASH", "Kicker", 10, AMBER))
	v.add_child(label("$%d on you  ·  $%d clean, $%d dirty" % [int(gs.cash), int(gs.clean_cash), int(gs.dirty_cash)], "Muted", 12, CREAM, true))
	v.add_child(label("THE BAG  ·  %d of %d" % [int(gs.cargo_used()), int(gs.cargo_max)], "Kicker", 10, AMBER))
	if gs.inventory.is_empty():
		v.add_child(label("Nothing on you.", "Muted", 12, MUTED, true))
	for pid in gs.inventory.keys():
		var units: int = int(gs.inventory[pid])
		if units <= 0:
			continue
		var price: int = int(economy.sell_unit_price(str(gs.current_district_id), str(pid))) if economy != null else 0
		v.add_child(label("%s  ·  %d unit%s  ·  sells for $%d here" % [str(gs.product_by_id(str(pid)).get("name", str(pid))).capitalize(), units, "" if units == 1 else "s", price], "Muted", 12, CREAM, true))
	if gs.has_vehicle():
		v.add_child(label("THE TRUNK", "Kicker", 10, AMBER))
		if (gs.trunk as Dictionary).is_empty():
			v.add_child(label("Empty. The checkpoint cannot count what is not there.", "Muted", 12, MUTED, true))
		for pid in (gs.trunk as Dictionary).keys():
			v.add_child(label("%s  ·  %d unit%s" % [str(gs.product_by_id(str(pid)).get("name", str(pid))).capitalize(), int(gs.trunk[pid]), "" if int(gs.trunk[pid]) == 1 else "s"], "Muted", 12, CREAM, true))
	v.add_child(label("UNDER YOUR COAT", "Kicker", 10, AMBER))
	if (gs.hot_goods as Array).is_empty():
		v.add_child(label("Nothing that is not yours.", "Muted", 12, MUTED, true))
	for item in gs.hot_goods:
		v.add_child(label("%s  ·  worth about $%d to somebody who does not ask" % [str((item as Dictionary).get("name", "something")).capitalize(), int((item as Dictionary).get("value", 0))], "Muted", 12, CREAM, true))
	v.add_child(label("THE KIT", "Kicker", 10, AMBER))
	v.add_child(label("%s  ·  %s" % [str(gs.weapon_def().get("name", "Hands")), "the beater" if gs.has_vehicle() else "on foot"], "Muted", 12, CREAM, true))
	body.add_child(c)
	body.add_child(note("Sell product at the Market. Hot goods go on the 907List, where the buyer is sometimes a cop."))

# --- contacts --------------------------------------------------------------

func _build_contacts() -> void:
	body.add_child(label("PEOPLE YOU KNOW", "CardTitle", 20, CREAM))
	body.add_child(note("Relationships and what people remember about you. Message threads stay in Texts."))
	var exposure := get_node_or_null("/root/Exposure")
	if exposure == null: return
	for entry in exposure.everyone():
		var id := str(entry["id"])
		if not PEOPLE.has_met(gs, exposure, id): continue
		var row := HBoxContainer.new()
		var face := PORTRAITS.portrait_rect(id, 48)
		if face != null: row.add_child(face)
		var name := str(PEOPLE.NAMES.get(id, id.capitalize()))
		var open := _switch_button(name.to_upper() + "\n" + str(entry["label"]) + " · View relationship", false, _open_person.bind(id), 64)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(open)
		body.add_child(row)

func _open_person(id: String) -> void:
	nav.set_meta("people_focus", id)
	nav.go_to(nav.PEOPLE)

func _known_contacts() -> int:
	var exposure := get_node_or_null("/root/Exposure")
	if exposure == null: return 0
	var count := 0
	for entry in exposure.everyone():
		if PEOPLE.has_met(gs, exposure, str(entry["id"])): count += 1
	return count

func _on_open_people() -> void:
	nav.go_to(nav.PEOPLE)

# --- bills -----------------------------------------------------------------

## Canon phoneBills, row for row. `severity` 2 is red, 1 is amber, 0 is quiet;
## `paid` is the crew row's "nothing owed tonight" state.
func _bills() -> Array:
	var rows: Array = []
	var obligations: Object = _obligations()

	# Phone. Canon's status ladder reads the line's health before the calendar.
	var phone_row: Dictionary = {
		"id": "phone", "name": "Phone service", "amount": gs.PHONE_BILL,
		"where": "Pay at Night Owl or the Phone Store",
		"due": "Day %d" % gs.phone_due_day,
		"blocker": obligations.pay_phone_blocker("phone"),
		"action": "pay_phone_bill", "payload": {"surface": "phone"},
	}
	if not gs.phone_active:
		phone_row["status"] = "Service off"
		phone_row["severity"] = 2
	elif gs.phone_days_past_due > 0:
		phone_row["status"] = "Past due"
		phone_row["severity"] = 2
	elif gs.day >= gs.phone_due_day:
		phone_row["status"] = "Due today"
		phone_row["severity"] = 1
	else:
		phone_row.merge(_upcoming(gs.phone_due_day))
	rows.append(phone_row)

	# Rent. Canon hides this once the household has evicted you; here the third
	# warning ends the run, so the check can only ever be false.
	if not gs.game_over:
		var rent_row: Dictionary = {
			"id": "rent", "name": "Rent", "amount": gs.WEEKLY_RENT,
			"where": "Pay Yalonda", "due": "Day %d" % gs.rent_due_day,
			"blocker": obligations.pay_rent_blocker(),
			"action": "pay_rent", "payload": {},
		}
		if gs.day > gs.rent_due_day:
			rent_row["status"] = "Past due"
			rent_row["severity"] = 2
		elif gs.day == gs.rent_due_day:
			rent_row["status"] = "Due now"
			rent_row["severity"] = 2
		else:
			rent_row.merge(_upcoming(gs.rent_due_day))
		rows.append(rent_row)

	# Crew wages. Canon shows what is OWED, or what a clean night will cost if
	# nothing is. No pay action on this row — wages are paid per person.
	var recruited: Array = []
	var owed := 0
	var nightly := 0
	for member in gs.crew_roster:
		var id: String = str(member["id"])
		var record: Dictionary = gs.crew_record(id)
		if not bool(record.get("recruited", false)):
			continue
		recruited.append(id)
		owed += int(record.get("wage_due", 0))
		nightly += int(gs.crew_wage_for(id, int(record.get("tier", 1))))
	if not recruited.is_empty():
		var wage_row: Dictionary = {
			"id": "wages", "name": "Crew wages", "amount": owed if owed > 0 else nightly,
			"where": "Pay on the Crew screen", "due": "Daily",
		}
		if owed > 0:
			wage_row["status"] = "Unpaid"
			wage_row["severity"] = 2
		else:
			wage_row["status"] = "Paid up"
			wage_row["severity"] = 0
			wage_row["paid"] = true
		rows.append(wage_row)

	# Dre's note — live since PR A (0.1.2). The actual PAY/EXTEND buttons live
	# on his own text (`_bind_dre_debt_card`), not on a Finances row, so this
	# points there rather than at a screen the account has no presence on yet.
	if gs.debt > 0:
		var due_day: int = gs.day + gs.debt_due_days
		var debt_row: Dictionary = {
			"id": "debt", "name": "Debt to Dre", "amount": gs.debt,
			"where": "Pay via his text", "due": "Day %d" % due_day,
		}
		if gs.debt_due_days < 0:
			debt_row["status"] = "Overdue"
			debt_row["severity"] = 2
		elif gs.debt_due_days == 0:
			debt_row["status"] = "Due tonight"
			debt_row["severity"] = 2
		else:
			debt_row.merge(_upcoming(due_day))
		rows.append(debt_row)

	return rows

## Canon's `upcoming`: two days out is when a bill starts asking for attention.
func _upcoming(due_day: int) -> Dictionary:
	if due_day - gs.day <= 2:
		return {"status": "Due soon", "severity": 1}
	return {"status": "Upcoming", "severity": 0}

func _build_bills() -> void:
	var rows: Array = _bills()
	var due_soon := 0
	var any_bad := false
	for row in rows:
		if int(row.get("severity", 0)) > 0:
			due_soon += 1
		if int(row.get("severity", 0)) == 2:
			any_bad = true
	# Canon's badge: the count, coloured danger if anything is actually late.
	var meta: String = "%d DUE" % due_soon if due_soon > 0 else ""
	_accordion("bills", "Bills", meta, RED if any_bad else AMBER)
	if not _is_open("bills"):
		return
	if rows.is_empty():
		body.add_child(note("No bills yet."))
		return
	for row in rows:
		body.add_child(_bill_row(row))
	if due_soon == 0:
		body.add_child(note("Paid up. Nothing is due yet."))

func _bill_row(row: Dictionary) -> Control:
	var severity: int = int(row.get("severity", 0))
	var tint: Color = RED if severity == 2 else (AMBER if severity == 1 else MUTED)

	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	left.add_child(label(str(row["name"]).to_upper(), "CardTitle", 13, CREAM))
	var blocker: String = str(row.get("blocker", ""))
	# Canon swaps the "where" line for "Paid from cash on hand" once the row is
	# actually payable — the instruction stops being useful the moment it is.
	var has_action: bool = row.has("action")
	left.add_child(label(
		"Paid from cash on hand" if has_action and blocker.is_empty() else str(row["where"]),
		"Muted", 11, MUTED, true))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 1)
	head.add_child(right)
	var amount := label("$%d" % int(row["amount"]), "Mono", 14, tint)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(amount)
	var status := label("%s  ·  %s" % [str(row["due"]), str(row["status"])], "Muted", 10, tint)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(status)

	if has_action:
		var b := button("PAY $%d" % int(row["amount"]) if blocker.is_empty() else blocker.to_upper(),
			blocker.is_empty() and severity > 0,
			_on_pay_bill.bind(str(row["action"]), row.get("payload", {})), 40)
		b.disabled = not blocker.is_empty()
		v.add_child(b)
	return c

func _on_pay_bill(action: String, payload: Dictionary) -> void:
	_gm.dispatch(action, payload)

func _on_pay_phone(surface: String) -> void:
	if _gm.dispatch("pay_phone_bill", {"surface": surface}):
		nav.show_toast("Paid. The line comes back after your next move.")

# --- today's log -----------------------------------------------------------

## Canon filters the run log by a `Day N ·` stamp prefix. Ours carries the day
## as a field, so the filter is an equality rather than a string match — and a
## row from a save that predates the field is stamped -1 and never matches.
func _build_log() -> void:
	var today: Array = []
	for entry in gs.activity_log:
		if int(entry.get("day", -1)) == gs.day:
			today.append(entry)
	_accordion("log", "Today's Log", "%d TODAY" % today.size())
	if not _is_open("log"):
		return
	if today.is_empty():
		body.add_child(note("Nothing logged today."))
		return
	for entry in today:
		var c := card()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		c.add_child(v)
		var tone: Color = entry.get("color", MUTED)
		v.add_child(label(str(entry.get("text", "")), "Muted", 12, tone, true))
		v.add_child(label(str(entry.get("time", "")), "Mono", 10, MUTED))
		body.add_child(c)

# --- word around town ------------------------------------------------------

func _build_intel(offline: bool) -> void:
	_accordion("intel", "Word Around Town", "")
	if not _is_open("intel"):
		return
	if offline:
		body.add_child(note("Word comes back when service does."))
		return
	# Prices first, ambient second. The routes are the part somebody would
	# actually ring you about; the rest is texture, and texture goes under.
	var routes: Array = _phone().market_intel()
	if not routes.is_empty():
		body.add_child(section("WHAT IT IS GOING FOR"))
		for entry in routes:
			var route: Dictionary = entry
			var row := card()
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 3)
			row.add_child(v)
			v.add_child(label(_phone().market_intel_line(route), "Muted", 12, CREAM, true))
			v.add_child(label("%s  ·  +$%d A UNIT"
				% [str(route["name"]).to_upper(), int(route["edge"])], "Mono", 10, GREEN))
			body.add_child(row)
	var lines: Array = _phone().intel()
	if lines.is_empty() and routes.is_empty():
		body.add_child(note("Nothing on the wire yet."))
		return
	if not lines.is_empty() and not routes.is_empty():
		body.add_child(section("AROUND HERE"))
	for line in lines:
		var c := card()
		c.add_child(label(str(line), "Muted", 12, BLUE, true))
		body.add_child(c)

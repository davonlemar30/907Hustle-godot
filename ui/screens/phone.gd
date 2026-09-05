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

const CATEGORIES := {"texts": "TEXTS", "contacts": "CONTACTS", "bills": "BILLS", "log": "TODAY'S LOG", "intel": "WORD AROUND TOWN"}
var _category := "texts"
var _sender := ""
var _mobile_detail := false
var _wide := false
var _resize_pending := false

func _ready() -> void:
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
	var previous := scroll.scroll_vertical
	var focused := get_viewport().gui_get_focus_owner()
	var focus_key := str(focused.name) if focused != null and is_ancestor_of(focused) else ""
	super()
	if not focus_key.is_empty():
		var replacement := body.find_child(focus_key, true, false) as Control
		if replacement != null: replacement.grab_focus.call_deferred()
	scroll.set_deferred("scroll_vertical", previous)

func _build_body() -> void:
	_wide = size.x >= 960.0
	var offline: bool = not gs.phone_active
	_set_text("Shell/Scroll/Pad/Content/Title/H", "NO SERVICE" if offline else "PHONE")
	_set_text("Shell/Scroll/Pad/Content/Title/Sub", "SWITCHBOARD  /  " + ("Messages held until service returns" if offline else "Texts, people and word on the street"))
	$Shell/Scroll/Pad/Content/Title/Sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Shell/Scroll/Pad/Content/Gap.hide()
	if offline:
		body.add_child(_offline_card())
	var root_body := body
	var layout: BoxContainer = HBoxContainer.new() if _wide else VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	root_body.add_child(layout)
	var rail: Container = VBoxContainer.new() if _wide else HFlowContainer.new()
	rail.add_theme_constant_override("separation", 6)
	if _wide:
		rail.custom_minimum_size.x = 175
	if _wide:
		var rail_card := _switch_panel()
		layout.add_child(rail_card)
		rail_card.add_child(rail)
	else:
		layout.add_child(rail)
	for key in CATEGORIES:
		var caption: String = CATEGORIES[key]
		if key == "texts":
			caption += "  ·  %d" % _reply_count()
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
	var pane := VBoxContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.add_theme_constant_override("separation", 12)
	layout.add_child(pane)
	body = pane
	match _category:
		"texts": _build_switchboard(offline)
		"contacts": _build_contacts()
		"bills": _build_bills()
		"log": _build_log()
		"intel": _build_intel(offline)
	body = root_body
	var footer := label("%d NEEDS A REPLY" % _reply_count() if _reply_count() == 1 else "%d NEED REPLIES" % _reply_count(), "Kicker", 12, RED if _reply_count() else MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_body.add_child(footer)

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
		if event is InputEventKey and event.is_action_pressed("ui_accept") and not event.is_echo():
			control.accept_event()
			activate.call())
	return control

func _choose_category(key: String) -> void:
	_category = key
	refresh()

func _choose_sender(sender: String) -> void:
	_sender = sender
	_mobile_detail = true
	refresh()

func _back_to_messages() -> void:
	_mobile_detail = false
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
		list_card.add_child(list)
		list.add_child(label("ALL MESSAGES", "CardTitle", 16, CREAM))
		for sender in senders:
			var latest: Dictionary = {}
			var pending := 0
			for message in gs.phone_inbox:
				if str(message.get("from", "")) == sender:
					if latest.is_empty(): latest = message
					if _phone().awaits_reply(message): pending += 1
			var preview := str(latest.get("text", "")).replace("\n", " ")
			if preview.length() > 75: preview = preview.left(72) + "..."
			var caption := sender.to_upper() + ("  ·  REPLY" if pending else "") + "\n" + preview
			var item := _switch_button(caption, sender == _sender, _choose_sender.bind(sender), 96)
			item.alignment = HORIZONTAL_ALIGNMENT_LEFT
			list.add_child(item)
		if gs.phone_inbox.size() > 1:
			list.add_child(_switch_button("CLEAR ALL %d" % gs.phone_inbox.size(), false, _on_clear_inbox))
	# A single conversation can open immediately; a populated inbox starts at list.
	if _wide or _mobile_detail or senders.size() == 1:
		var conversation := VBoxContainer.new()
		conversation.name = "Conversation"
		conversation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		conversation.add_theme_constant_override("separation", 12)
		var conversation_card := _switch_panel()
		conversation_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _wide: conversation_card.custom_minimum_size.y = 440
		columns.add_child(conversation_card)
		conversation_card.add_child(conversation)
		if not _wide and _mobile_detail:
			conversation.add_child(_switch_button("‹ ALL MESSAGES", false, _back_to_messages))
		var header := HBoxContainer.new()
		conversation.add_child(header)
		var face := PORTRAITS.portrait_rect(_sender, 64)
		if face != null: header.add_child(face)
		var title := label(_sender.to_upper(), "CardTitle", 24, CREAM, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		if _sender.to_lower().begins_with("yalonda"):
			for bill in _bills():
				if str(bill.get("id", "")) == "rent":
					conversation.add_child(label("RENT  ·  $%d  ·  %s  ·  %s" % [int(bill["amount"]), str(bill["due"]), str(bill["status"])], "Kicker", 12, AMBER, true))
		var messages: Array = gs.phone_inbox.duplicate()
		messages.reverse()
		for message in messages:
			if str(message.get("from", "")) == _sender:
				conversation.add_child(_message_card(message))

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
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	# OG-D3: who is texting, when the game has their face.
	var face := PORTRAITS.portrait_rect(str(message.get("from", "")), 48)
	if face != null:
		face.free()
	var from := label(str(message.get("from", "")).to_upper(), "CardTitle", 16, CREAM, true)
	from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(from)
	v.add_child(label(_phone().stamp(message), "Mono", 11, MUTED))
	# Canon's dismiss glyph is U+00D7, which every theme font carries (checked
	# against the cmaps, not against how it looks in the editor).
	#
	# 44x44, the same tap-target floor every other screen is held to. It was
	# 34x28 until v0.1.0 -- a glyph sized to the glyph rather than to a thumb.
	var dismiss := _switch_button("×", false, _on_dismiss.bind(str(message.get("id", ""))), 44)
	dismiss.custom_minimum_size = Vector2(44, 44)
	head.add_child(dismiss)

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
			v.add_child(label("you: %s" % str((reply[replied] as Dictionary).get("text", "")),
				"Muted", 12, CYAN, true))
		elif replied == "ghost":
			v.add_child(label("left on read", "Kicker", 10, MUTED))
		else:
			var id := str(message.get("id", ""))
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			for option in ["a", "b"]:
				var answer := _switch_button(str((reply[option] as Dictionary).get("text", "")), false,
					_on_reply.bind(id, option), 52)
				answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				answer.add_theme_font_size_override("font_size", 15)
				row.add_child(answer)
			v.add_child(row)
	if not action.is_empty() and str(action.get("kind", "")) == "job_offer":
		v.add_child(label("OFFER ATTACHED", "Kicker", 10, AMBER))
	elif not action.is_empty() and str(action.get("kind", "")) == "tip":
		v.add_child(label(_tip_stamp(action), "Kicker", 10, AMBER))
	elif not action.is_empty() and str(action.get("kind", "")) == "dre_debt":
		_bind_dre_debt_card(v)
	return c

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

# --- contacts --------------------------------------------------------------

func _build_contacts() -> void:
	var known: int = _known_contacts()
	_accordion("contacts", "Contacts", "%d KNOWN" % known)
	if not _is_open("contacts"):
		return
	if known == 0:
		body.add_child(note("Nobody has a read on you yet."))
		return
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)
	v.add_child(label("WHO KNOWS YOU", "CardTitle", 13, CREAM))
	v.add_child(label("What each of them makes of you, and the evidence behind it.",
		"Muted", 12, MUTED, true))
	v.add_child(button("OPEN PEOPLE", false, _on_open_people, 40))
	body.add_child(c)

## Canon counts `personalContacts + knownSocialContacts` minus the household,
## both of which need the `state.contacts` ledger this build has not ported.
## The closest real number is who the run has actually dealt with — an NPC with
## at least one observation on their ledger.
func _known_contacts() -> int:
	var exposure: Node = get_node_or_null("/root/Exposure")
	if exposure == null:
		return 0
	var count := 0
	for entry in exposure.everyone():
		if int(entry.get("rows", 0)) > 0:
			count += 1
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

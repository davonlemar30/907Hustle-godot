extends Node
## Integration/layout probe: real phone data and reply dispatch, no mock system.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("SWITCHBOARD FAIL: " + message)

func _ready() -> void:
	var gs := get_node("/root/GameState")
	var gm := get_node("/root/GameManager")
	get_node("/root/SaveSystem")._suspended = true
	gs.reset_to_new_game()
	gs.street_name = "Switchboard"
	gs.phone_inbox = []
	var phone: Object = gm.system("phone")
	phone.push_message("Yalonda", "Keep the kitchen clean. We all live here.", {"reply": {"npc": "yalonda", "a": {"text": "Yes ma'am. I'll take care of it."}, "b": {"text": "Fine."}, "replied": "a"}})
	phone.push_message("Yalonda", "Good. Juan said you have been keeping busy.")
	var first: Dictionary = phone.push_message("Yalonda", "Rent is $150 a week. Due day 7. I don't do reminders.", {"reply": {"npc": "yalonda", "a": {"text": "Yes ma'am. Thank you for the room."}, "b": {"text": "Got it."}, "replied": ""}})
	phone.push_message("Reece", "You around today? Got something for you.")
	phone.push_message("Juan", "Someone at the wash and go asked me who you were. I told them you rent my room.")
	phone.push_message("Lani", "Take care of yourself.")
	var screen: Control = load("res://ui/screens/phone.tscn").instantiate()
	add_child(screen)
	screen._choose_sender("Yalonda")
	check(screen._reply_count() == 1, "actionable reply count")
	screen._back_to_messages()
	screen._filter_query("wash and go")
	var visible_threads := 0
	for row in screen._thread_rows:
		if row.visible: visible_threads += 1
	check(visible_threads == 1, "search matches message content")
	screen._filter_query("")
	screen._toggle_reply_filter()
	visible_threads = 0
	for row in screen._thread_rows:
		if row.visible: visible_threads += 1
	check(visible_threads == 1, "reply filter shows only actionable thread")
	screen._toggle_reply_filter()
	screen._choose_sender("Yalonda")
	for dimensions in [Vector2i(375, 812), Vector2i(1440, 900)]:
		get_window().size = dimensions
		await get_tree().process_frame
		await get_tree().process_frame
		screen.refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		for category in ["texts", "bills", "contacts", "log", "intel"]:
			screen._choose_category(category)
			await get_tree().process_frame
			await get_tree().process_frame
			check(screen.get_node("Shell").size.x <= screen.size.x + 1, "%s fits %s" % [category, dimensions])
			_check_width(screen.get_node("Shell/Scroll"), screen.size.x)
		screen._choose_category("texts")
		for frame in range(4): await get_tree().process_frame
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/refined-thread-%d.png" % dimensions.x)
		screen._back_to_messages()
		await get_tree().process_frame
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/refined-inbox-%d.png" % dimensions.x)
		screen._choose_sender("Yalonda")
	screen._on_reply(str(first["id"]), "b")
	check(screen._reply_count() == 0, "reply resolves through existing dispatch")
	check(screen._sender == "Yalonda", "selection survives dispatch")
	check(not gm.dispatch("phone_reply", {"id": first["id"], "option": "a"}), "duplicate reply rejected")
	gs.phone_active = false
	phone.push_message("Reece", "Held text")
	screen.refresh()
	check(screen._reply_count() == 0, "held messages not actionable")
	check(gs.phone_held_inbox.size() == 1, "held text preserved")
	gs.phone_active = true
	gs.phone_inbox = []
	screen.refresh()
	check(screen._sender == "", "empty inbox clears stale selection")
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(3.5).timeout
	screen.queue_free()
	await get_tree().process_frame
	var exposure := get_node("/root/Exposure")
	var people: Control = load("res://ui/screens/people.tscn").instantiate()
	add_child(people)
	check(people._met("yalonda", exposure), "household stays available")
	check(not people._met("dre", exposure), "Dre remains discovery gated")
	check(not "Relationship score:" in _labels(people), "evidence collapsed initially")
	people._toggle_evidence("yalonda")
	check("Relationship score:" in _labels(people), "evidence opens")
	for dimensions in [Vector2i(375, 812), Vector2i(1440, 900)]:
		get_window().size = dimensions
		await get_tree().process_frame
		await get_tree().process_frame
		people.refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		_check_width(people.get_node("Shell/Scroll"), people.size.x)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/refined-people-%d.png" % dimensions.x)
	print("SWITCHBOARD: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _check_width(node: Node, width: float) -> void:
	if node is Button and str(node.name).begins_with("Category_"):
		check(node.size.y <= 100, "category remains readable: " + str(node.name))
	if node is Control and node.is_visible_in_tree():
		check(node.get_global_rect().end.x <= width + 1, "control fits: " + str(node.get_path()))
	for child in node.get_children():
		_check_width(child, width)

func _labels(node: Node) -> String:
	var text: String = node.text if node is Label else ""
	for child in node.get_children(): text += " " + _labels(child)
	return text

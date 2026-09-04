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
	var first: Dictionary = phone.push_message("Yalonda", "Rent is $150 a week. Due day 7. I don't do reminders.", {"reply": {"npc": "yalonda", "a": {"text": "Yes ma'am. Thank you for the room."}, "b": {"text": "Got it."}, "replied": ""}})
	phone.push_message("Reece", "You around today? Got something for you.")
	var screen: Control = load("res://ui/screens/phone.tscn").instantiate()
	add_child(screen)
	screen._choose_sender("Yalonda")
	check(screen._reply_count() == 1, "actionable reply count")
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
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/switchboard-%d.png" % dimensions.x)
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
	print("SWITCHBOARD: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _check_width(node: Node, width: float) -> void:
	if node is Button and str(node.name).begins_with("Category_"):
		check(node.size.y <= 100, "category remains readable: " + str(node.name))
	if node is Control and node.is_visible_in_tree():
		check(node.get_global_rect().end.x <= width + 1, "control fits: " + str(node.get_path()))
	for child in node.get_children():
		_check_width(child, width)

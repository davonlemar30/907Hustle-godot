extends Node
## Instantiate every screen headless, bind it once, and prove its script loaded.
##
## A CI gate as of batch 12. It is the only thing in the build that would catch
## a screen that cannot render, which is why batch 15 taught it a second
## question.
##
## **Instantiating is not enough, and that was measured rather than reasoned
## about.** `opening.gd` shipped for one commit with a method named `_set` — the
## same name as `Object`'s virtual `_set(StringName, Variant) -> bool` and a
## different signature, which is a PARSE ERROR. Godot logs it, refuses to attach
## the script, and instantiates the scene anyway. This gate printed 24/24 for a
## screen that was, from the player's side, a static picture: no bindings, no
## handlers, no button.
##
## So a screen with a `script =` line in its .tscn must come back with a script
## ATTACHED. A scene deliberately without one is fine and is not asked.
##
## TOUCH-D5 added a second question, on the same refresh() this file already
## calls: does every screen still hold the touch-scroll property from D-11?
## Inside any ScrollContainer, no Control may sit at MOUSE_FILTER_STOP, and no
## BaseButton may be wired via `pressed` instead of `tap_connect`'s measured-tap
## `gui_input`. This walks the tree refresh() just built, so it reads exactly
## the state screen_base.gd's own normalize sweep produced -- the same state a
## live screen on a phone would be in, not a separately-constructed one the
## sweep never touched.
func _ready() -> void:
	var gs := get_node("/root/GameState")
	gs.street_name = "Smoke"
	gs.reset_to_new_game()
	gs.day = 9
	gs.cash = 5000
	var dir := DirAccess.open("res://ui/screens")
	var names: Array = []
	dir.list_dir_begin()
	var e: String = dir.get_next()
	while e != "":
		if e.ends_with(".tscn"):
			names.append(e)
		e = dir.get_next()
	dir.list_dir_end()
	names.sort()
	var ok := 0
	var touch_checks := 0
	var touch_failed := 0
	for n in names:
		var packed: PackedScene = load("res://ui/screens/%s" % n)
		if packed == null:
			printerr("LOAD FAILED: %s" % n)
			continue
		var inst: Node = packed.instantiate()
		# The scene file says whether a script is meant to be there; the instance
		# says whether one is. A parse error is exactly the case where those two
		# disagree, and it is silent everywhere else.
		if _declares_script(n) and inst.get_script() == null:
			printerr("SCRIPT FAILED: %s (the scene declares one and none attached)" % n)
			inst.free()
			continue
		add_child(inst)
		await get_tree().process_frame
		if inst.has_method("refresh"):
			inst.refresh()
		await get_tree().process_frame
		var touch_result := _check_scroll_transparency(inst, n)
		touch_checks += int(touch_result[0])
		for violation in touch_result[1]:
			printerr("TOUCH FAILED: %s" % violation)
			touch_failed += 1
		inst.queue_free()
		await get_tree().process_frame
		ok += 1
		print("screen ok: %s" % n)
	print("screen smoke: %d/%d instantiated" % [ok, names.size()])
	print("screen smoke: touch checks %d/%d passed" % [touch_checks - touch_failed, touch_checks])
	get_tree().quit.call_deferred(0)

## Nodes inside a ScrollContainer legitimately kept at MOUSE_FILTER_STOP, named
## rather than skipping a whole screen (TOUCH-D5). Empty today: ModalSheet's
## scrim/card and flow-sheet content are built at runtime as siblings of
## `Shell`, never actual ScrollContainer descendants, so nothing currently
## needs an exception -- add a node name here, not a screen skip, if one ever
## does.
const SCROLL_STOP_ALLOWLIST: Array[String] = []

## TOUCH-D5's structural gate. Walks every ScrollContainer in `inst` (already
## refreshed by the caller) and checks each descendant: a Control stuck at
## MOUSE_FILTER_STOP, or a BaseButton wired via `pressed` instead of
## `tap_connect`'s gui_input pattern, is a violation. Returns
## `[checks, violations]` -- the caller owns the ok/fail bookkeeping and print
## format for this suite, this only counts and describes.
func _check_scroll_transparency(inst: Node, screen_name: String) -> Array:
	var checks := 0
	var violations: Array[String] = []
	var scrolls: Array[Node] = inst.find_children("*", "ScrollContainer", true, false)
	for scroll in scrolls:
		var stack: Array[Node] = scroll.get_children()
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.append(child)
			if node.name in SCROLL_STOP_ALLOWLIST:
				continue
			if node is BaseButton:
				checks += 1
				if (node as BaseButton).pressed.get_connections().size() > 0:
					violations.append("%s %s wired via pressed, not tap_connect" \
						% [screen_name, (node as Node).get_path()])
				continue
			var control := node as Control
			if control == null:
				continue
			checks += 1
			if control.mouse_filter == Control.MOUSE_FILTER_STOP:
				violations.append("%s %s stuck at MOUSE_FILTER_STOP inside a scroll" \
					% [screen_name, (node as Node).get_path()])
	return [checks, violations]

## Does this .tscn ask for a script on its root node?
##
## Read off the file rather than off the loaded resource: a PackedScene whose
## script failed to parse comes back with that property already dropped, which
## is the whole reason the instance cannot be trusted to report it.
func _declares_script(scene_name: String) -> bool:
	var file := FileAccess.open("res://ui/screens/%s" % scene_name, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	return text.contains("script = ExtResource")

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
		inst.queue_free()
		await get_tree().process_frame
		ok += 1
		print("screen ok: %s" % n)
	print("screen smoke: %d/%d instantiated" % [ok, names.size()])
	get_tree().quit.call_deferred(0)

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

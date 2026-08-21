extends Node
## Throwaway harness: instantiate every screen headless and bind it once.
## Not part of the parity suite; run manually to confirm no screen errors.
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

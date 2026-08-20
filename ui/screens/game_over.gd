extends Control
## Game over — the run ended.
##
## Standalone like the title screen: no chrome, no HUD, no nav. There is nothing
## left to navigate to.
##
## Canon's only lose condition reachable in this build is eviction
## ("nowhere_to_go"): three household warnings, earned two missed rent weeks at a
## time. The heading is fixed to that because it is the only way to get here yet;
## when other endings land it should read from game_over_reason's kind.

@onready var gs: Node = get_node("/root/GameState")
@onready var nav: Node = get_node("/root/ScreenManager")

func _ready() -> void:
	$Pad/V/NewRun.pressed.connect(_on_new_run)
	$Pad/V/Reason.text = gs.game_over_reason
	_fill_stats()

func _fill_stats() -> void:
	var box: VBoxContainer = $Pad/V/Stats/SV
	for c in box.get_children():
		c.queue_free()
	var rows := [
		["DAYS SURVIVED", str(gs.day)],
		["CASH LEFT", "$%s" % _commas(gs.cash)],
		["HEAT", "%d/%d" % [gs.heat, gs.heat_max]],
		["HEALTH", "%d/%d" % [gs.health, gs.health_max]],
		["RENT WEEKS MISSED", str(gs.rent_missed)],
	]
	if not gs.street_name.is_empty():
		rows.push_front(["NAME", gs.street_name])
	for r in rows:
		box.add_child(_stat_row(str(r[0]), str(r[1])))

func _stat_row(key: String, value: String) -> Control:
	var h := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.theme_type_variation = &"Muted"
	k.add_theme_font_size_override("font_size", 11)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := Label.new()
	v.text = value
	v.theme_type_variation = &"Mono"
	v.add_theme_font_size_override("font_size", 13)
	h.add_child(v)
	return h

func _on_new_run() -> void:
	# Back to the title rather than straight into a run: naming the next one is
	# part of starting it.
	nav.go_to(nav.TITLE)

func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

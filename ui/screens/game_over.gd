extends Control
## The reckoning -- the run ended (One Good Run PR 4, OG-D4).
##
## Standalone like the title screen: no chrome, no HUD, no nav. One screen
## for both outcomes. What you built, what it cost, who remembers you. Win
## and loss differ in copy, not in shape, which is why it is built once.
## Everything shown comes from `systems/ending.gd::reckoning()`; this file
## has no opinions.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)
const MUTED := Color(0.608, 0.608, 0.608)
const CREAM := Color(0.949, 0.941, 0.922)

@onready var gs: Node = get_node("/root/GameState")
@onready var nav: Node = get_node("/root/ScreenManager")
@onready var gm: Node = get_node("/root/GameManager")

func _ready() -> void:
	$Pad/V/NewRun.pressed.connect(_on_new_run)
	_fill()

func _fill() -> void:
	var ending: Object = gm.system("ending") if gm != null else null
	var r: Dictionary = ending.reckoning() if ending != null else {}
	var won: bool = str(r.get("kind", "")) == "out"
	var kicker := get_node_or_null("Pad/V/Kicker") as Label
	if kicker != null:
		kicker.text = str(r.get("kicker", "THE RUN"))
		kicker.add_theme_color_override("font_color", GREEN if won else RED)
	var head := get_node_or_null("Pad/V/Head") as Label
	if head != null:
		head.text = str(r.get("head", "THE RUN ENDED"))
	var reason := get_node_or_null("Pad/V/Reason") as Label
	if reason != null:
		reason.text = str(r.get("reason", gs.game_over_reason))
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var new_run := get_node_or_null("Pad/V/NewRun") as Button
	if new_run != null:
		new_run.text = "ONE MORE RUN"

	var box: VBoxContainer = $Pad/V/Stats/SV
	for c in box.get_children():
		c.queue_free()
	var rows := [
		["DAYS", str(r.get("days", gs.day))],
		["EARNED", "$%s" % _commas(int(r.get("earned", 0)))],
		["CLEAN AT THE END", "$%s" % _commas(int(r.get("clean", gs.clean_cash)))],
		["THE NAME", str(r.get("rank", ""))],
	]
	if not gs.street_name.is_empty():
		rows.push_front(["NAME", gs.street_name])
	for row in rows:
		box.add_child(_stat_row(str(row[0]), str(row[1])))
	var corners: Array = r.get("corners", [])
	box.add_child(_stat_row("CORNERS", "%d held" % corners.size() if not corners.is_empty() else "none"))
	if not corners.is_empty():
		box.add_child(_line(", ".join(corners), MUTED))
	box.add_child(_spacer(6))
	box.add_child(_kicker("WHO REMEMBERS YOU"))
	for line in (r.get("people", []) as Array):
		box.add_child(_line(str(line), CREAM))
	var crew: Array = r.get("crew", [])
	if not crew.is_empty():
		box.add_child(_spacer(4))
		box.add_child(_kicker("THE CREW"))
		for line in crew:
			box.add_child(_line(str(line), CREAM))
	box.add_child(_spacer(6))
	box.add_child(_line("One good run. Try another." if won else "The city got this one. The next one knows more.", AMBER))

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

func _line(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"Muted"
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _kicker(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"Kicker"
	l.add_theme_font_size_override("font_size", 10)
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

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

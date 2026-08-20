extends Control
## Base for every top-level screen.
##
## Renders the whole screen from GameState in one pass — the shared chrome (top bar
## day/part/location/cash + 6-stat HUD) here, and each screen's own content via the
## `_bind_content()` hook. `refresh()` runs once on ready and again whenever GameState
## emits `state_changed`, so a single state update re-renders everything (the
## web-reducer pattern) with no per-field signal wiring.
##
## The values baked into each .tscn are just editor-time previews; at runtime
## GameState is the source of truth. Screens with content override `_bind_content()`.

## Unlit meter dot. Shared so every screen's meters read the same.
const PIP_DIM := Color(1, 1, 1, 0.12)

@onready var gs: Node = get_node("/root/GameState")
# Autoloads are reached by path, not by the compile-time global: the editor does
# not have a freshly-registered singleton until it reloads.
@onready var nav: Node = get_node("/root/ScreenManager")

func _ready() -> void:
	if gs and gs.has_signal("state_changed"):
		gs.state_changed.connect(refresh)
	_wire_nav()
	refresh()

## Connect the bottom nav once. Deliberately here and not in _bind_content(),
## which re-runs on every state change and would stack duplicate connections.
func _wire_nav() -> void:
	if nav == null:
		return
	for cell_key in nav.NAV_ROUTES.keys():
		# Explicit types throughout: NAV_ROUTES is an untyped Dictionary, so
		# anything drawn from it is a Variant and := cannot infer.
		var cell: String = cell_key
		var path: String = "HomeBtn" if cell == "Home" else "Shell/NavBar/NavRow/" + cell
		var button := get_node_or_null(path) as Button
		if button == null:
			continue
		var route: String = nav.NAV_ROUTES[cell]
		# Phone and More have no scene yet. Leave them inert rather than
		# routing into a load that fails.
		if route.is_empty():
			button.disabled = true
			continue
		# Re-entering the screen you are already on would rebuild it for no
		# reason, so skip the current scene's own route.
		if route == scene_file_path:
			continue
		button.pressed.connect(nav.go_to.bind(route))

## Re-render the entire screen from GameState.
func refresh() -> void:
	_fill_chrome()
	_bind_content()

## Screens override this to bind their own content. Base is a no-op.
func _bind_content() -> void:
	pass

func _fill_chrome() -> void:
	_set_text("Shell/TopBar/HBox/DayBox/V/Day", "DAY %d" % gs.day)
	_set_text("Shell/TopBar/HBox/DayBox/V/Part", gs.time_slot)
	_set_text("Shell/TopBar/HBox/Right/LocBox/V/L1", gs.current_district().get("name", "SPENARD"))
	_set_text("Shell/TopBar/HBox/Right/LocBox/V/L2", gs.city)
	_set_text("Shell/TopBar/HBox/Right/CashBox/V/C2", "$%s" % _commas(gs.cash))
	_set_text("Shell/Hud/HudRow/C0/V", "%d/%d" % [gs.heat, gs.heat_max])
	_set_text("Shell/Hud/HudRow/C1/V", "%d/%d" % [gs.health, gs.health_max])
	_set_text("Shell/Hud/HudRow/C2/V", "$%s" % _commas(gs.debt))
	# A fresh run owes nobody yet — canon only opens the note once Dre offers
	# it — so the countdown under the debt figure has nothing to count.
	var due := get_node_or_null("Shell/Hud/HudRow/C2/Due") as Label
	if due:
		due.visible = gs.debt > 0
		if gs.debt > 0:
			due.text = "DUE IN %d DAYS" % gs.debt_due_days
	_set_text("Shell/Hud/HudRow/C3/V", "%d/%d" % [gs.cargo_used(), gs.cargo_max])
	_set_text("Shell/Hud/HudRow/C4/V", str(gs.respect))
	_set_text("Shell/Hud/HudRow/C5/V", str(gs.crew_power))

func _set_text(path: String, text: String) -> void:
	var node := get_node_or_null(path) as Label
	if node:
		node.text = text

## Fill a meter row: `filled` of its dots take `tint`, the rest go dim.
##
## Meters used to be a string of U+25CF/U+25CB, which only ever worked in the editor:
## macOS lends a system font for glyphs the theme fonts lack, and the web export
## has no system fonts to lend. None of Anton, Barlow Condensed or Share Tech
## Mono carries U+25CF/U+25CB, so the browser drew tofu. The dots are TextureRects
## now, so nothing about them depends on font coverage.
func _set_pips(path: String, filled: int, total: int, tint: Color) -> void:
	var row := get_node_or_null(path)
	if row == null:
		return
	filled = clampi(filled, 0, total)
	for i in range(total):
		var dot := row.get_node_or_null("D%d" % i) as TextureRect
		if dot:
			dot.self_modulate = tint if i < filled else PIP_DIM

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

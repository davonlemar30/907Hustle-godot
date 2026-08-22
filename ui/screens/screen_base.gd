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
		# Every cell has a scene as of Phase 5b, but the branch stays: a nav
		# cell added ahead of its screen must be inert, never a failed load.
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
	# One place catches the end of the run, and one place catches a consequence
	# opening under whatever screen the player happened to be on. Every game
	# screen extends this, so whichever one is open when it lands is the one
	# that leaves.
	#
	# Priority is ScreenManager's (`blocking_route`), not repeated here: game
	# over outranks a consequence, and a screen that is already the blocking
	# destination must not route to itself.
	if nav != null:
		var blocking: String = nav.blocking_route()
		if not blocking.is_empty() and scene_file_path != blocking:
			nav.go_to(blocking)
			return
	_fill_chrome()
	_bind_content()

## How far a finger may travel and still count as a tap rather than a scroll.
const TAP_SLOP := 12.0

## Fire `handler` on a tap, while letting a drag reach the ScrollContainer above.
##
## **This is the only correct way to make something inside the scroll respond.**
## A control at MOUSE_FILTER_STOP swallows the press, so the ScrollContainer
## never sees the gesture start and the screen will not scroll from anywhere
## that control covers. MOUSE_FILTER_PASS lets us handle the event AND lets it
## continue up to the scroll.
##
## Because PASS means the gesture still reaches us on release, a plain
## `pressed` connection would fire at the end of a scroll drag. So presses are
## measured: a release more than TAP_SLOP from where the finger landed was a
## scroll, not a tap, and the handler does not run.
func tap_connect(target: Control, handler: Callable) -> void:
	if target == null:
		return
	target.mouse_filter = Control.MOUSE_FILTER_PASS
	if not target.gui_input.is_connected(_on_tap_gui_input):
		target.gui_input.connect(_on_tap_gui_input.bind(target, handler))

func _on_tap_gui_input(event: InputEvent, target: Control, handler: Callable) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		target.set_meta("tap_origin", mb.position)
		return
	if not target.has_meta("tap_origin"):
		return
	var origin: Vector2 = target.get_meta("tap_origin")
	target.remove_meta("tap_origin")
	if mb.position.distance_to(origin) <= TAP_SLOP:
		handler.call()

## Make a card tappable without restructuring the scene.
##
## The card itself becomes the target — no overlay Button. An earlier version
## added a flat Button covering the whole card, which is what broke scrolling:
## a full-card STOP control means a drag starting anywhere on a card never
## reaches the ScrollContainer, so the screen only scrolled from bare
## background. Market's small BUY/SELL buttons had hidden that from me.
##
## Returns the card, or null if the path is missing.
func make_tappable(path: String, handler: Callable) -> Control:
	var card := get_node_or_null(path) as Control
	if card == null:
		return null
	tap_connect(card, handler)
	return card

## Screens override this to bind their own content. Base is a no-op.
func _bind_content() -> void:
	pass

func _fill_chrome() -> void:
	_set_text("Shell/TopBar/HBox/DayBox/V/Day", "DAY %d" % gs.day)
	_set_text("Shell/TopBar/HBox/DayBox/V/Part", gs.time_slot)
	_set_text("Shell/TopBar/HBox/Right/LocBox/V/L1", gs.current_district().get("name", "SPENARD"))
	_set_text("Shell/TopBar/HBox/Right/LocBox/V/L2", gs.city)
	_set_text("Shell/TopBar/HBox/Right/CashBox/V/C2", "$%s" % _commas(gs.cash))
	_set_text("Shell/Hud/HudRow/C0/V", "%d/%d" % [gs.heat_shown(), gs.heat_max])
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

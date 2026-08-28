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

## Local Attention, TI-003 §19 and PX-003 §7.
##
## The colours live here rather than on any one surface because Boost, Stickup
## and Market all show the same four bands and they have to agree — a district
## reading WATCHED in amber on one screen and orange on another would read as
## two different facts.
##
## All four are legible on the near-black background the shell uses, and none of
## them is the only carrier of meaning: the band NAME is always shown beside the
## colour (PX-003 §16, "redundant labels alongside color").
const ATTENTION_TONES := {
	"QUIET": Color(0.608, 0.608, 0.608),
	"KNOWN": Color(0.882, 0.651, 0.227),
	"WATCHED": Color(1.0, 0.541, 0.192),
	"HOT": Color(0.827, 0.161, 0.125),
}

## PX-003 §7's situation copy per band. QUIET has none on purpose: "No persistent
## warning card is needed" — a line that fires when nothing is wrong teaches the
## player to stop reading it.
const ATTENTION_COPY := {
	"KNOWN": "People around here are starting to recognize this routine.",
	"WATCHED": "Too many similar moves in this district have people paying attention. The odds here are getting worse.",
	"HOT": "This routine is burned in this part of town. Working the same hustle here carries the district's heaviest local penalty.",
}

func attention_tone(band: String) -> Color:
	return ATTENTION_TONES.get(band, ATTENTION_TONES["QUIET"])

## The band for one criminal family where the player is standing, or "QUIET" when
## the engine is not available. Never the score — TI-003 §19 keeps that hidden.
func attention_band(family: String) -> String:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null:
		return "QUIET"
	var engine: Object = manager.system("consequence")
	if engine == null:
		return "QUIET"
	return str(engine.pressure_band(gs.current_district_id, family))

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
	_normalize_scroll_mouse_filters()
	_drain_flow_sheets.call_deferred()

## Show the next queued flow sheet, if this is a safe moment for one.
##
## Deferred from `refresh()` because the guards below read state (the current
## scene, the blocking route) that is not necessarily settled yet mid-refresh
## -- the same reason `go_to()` defers `_change()`.
##
## Guards, in order: this screen must actually be the live one (the
## `consequence.gd::_is_live()` pattern -- a headless test's root is never
## `current_scene`, so this is inert in every suite by construction); nothing
## may be blocking (a consequence chain defers every queued card until the
## player lands back somewhere ordinary); and no sheet may already be up.
## `spec.is_empty()` covers both "the queue is empty" and "the drain has
## nothing to show" the same way, since `take_next_flow_sheet()` returns {}
## for the former and this returns early on the latter.
func _drain_flow_sheets() -> void:
	# `is_inside_tree()` BEFORE `get_tree()`, not after: a suite that creates
	# and frees a screen within one frame (no frame pumped in between, as
	# parity's `_instantiate_screen`/`_free_screen` do thousands of times)
	# lets this deferred call fire against a node that is no longer in the
	# tree at all -- `get_tree()` on that node returns null, and chaining
	# `.current_scene` off it is a crash, not a false answer, per node.
	if nav == null or not is_inside_tree() or get_tree().current_scene != self:
		return
	if not nav.blocking_route().is_empty():
		return
	if nav.flow_sheet_active():
		return
	var spec: Dictionary = nav.take_next_flow_sheet()
	if spec.is_empty():
		return
	var content: Control = _build_flow_sheet_content(spec)
	if content == null:
		# An unknown or stale spec (e.g. `card_for` found nothing to say):
		# nothing to show, try the next one.
		_drain_flow_sheets.call_deferred()
		return
	var sheet: ModalSheet = show_sheet(content)
	# The "Dismiss" contract: every flow_sheets.gd builder names its button
	# this, so the drain can wire it without knowing which builder ran.
	var dismiss := content.get_node_or_null("Dismiss") as Button
	if dismiss != null:
		dismiss.pressed.connect(sheet.exit)
	nav.register_flow_sheet(sheet)
	sheet.dismissed.connect(_drain_flow_sheets, CONNECT_DEFERRED)

## Resolve one flow-sheet spec to content, or null when there is nothing to
## show. The one place a `spec["kind"]` is read -- `flow_sheets.gd` never sees
## the spec, only the copy this resolves it to.
func _build_flow_sheet_content(spec: Dictionary) -> Control:
	match str(spec.get("kind", "")):
		"discovery":
			var access: Node = get_node_or_null("/root/SurfaceVisibility")
			if access == null:
				return null
			var card: Dictionary = access.card_for(str(spec.get("surface_id", "")))
			return null if card.is_empty() else FlowSheets.build_discovery(card)
		"intro":
			return FlowSheets.build_intro(gs)
	return null

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
	if mb.position.distance_to(origin) > TAP_SLOP:
		return
	# A LOCKED surface swallows the tap and says nothing. Not a toast, not an
	# error — the lock and its hint are already the whole answer, and a screen
	# that also complains reads as a bug rather than as a gate.
	#
	# Enforced here rather than by disconnecting the handler because the
	# connection is made once in `_ready` while the gate is re-evaluated on
	# every refresh: connecting and disconnecting per refresh is how a surface
	# ends up either dead after it unlocks or wired twice.
	if bool(target.get_meta(LOCKED_META, false)):
		return
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

## TOUCH-D3b's backstop, run after every `_bind_content()`/`refresh()`: demote
## any Control still sitting at MOUSE_FILTER_STOP inside a ScrollContainer back
## to PASS. `card()`/`_card()` fix the panels those helpers build, but a
## `.tscn`-authored PanelContainer (Home's Wander/Actions/OpCard/Activity
## columns) never goes through them -- this is what catches those, and
## whatever the next screen author forgets to route through the helpers too.
##
## Never demotes a BaseButton, nor a Control with its own gui_input wiring:
## either one still sitting at STOP is a real finding for the structural gate
## in screen_smoke.gd, meant to be fixed by hand via tap_connect, not silently
## papered over here.
func _normalize_scroll_mouse_filters() -> void:
	var stack: Array[Node] = find_children("*", "ScrollContainer", true, false)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is BaseButton:
			continue
		var control := node as Control
		if control == null or control.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		if control.gui_input.get_connections().size() > 0:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_PASS

## Build and show a `ModalSheet` around `content`, parented to this screen.
##
## `market.gd`'s quantity sheet does this dance inline (PR 3); this is that
## dance, extracted so the flow-sheet drain does not have to invent its own
## copy of it. Market is left as it is for this PR -- adopting this helper
## there is a separate change, not a side effect of this one.
func show_sheet(content: Control) -> ModalSheet:
	var sheet := ModalSheet.new()
	sheet.setup(content)
	add_child(sheet)
	# Above Shell so it overlays the scroll content, below Atmosphere so
	# grain/vignette still shows on top of it (`modal_sheet.gd` header).
	var atmo := get_node_or_null("Atmosphere")
	if atmo != null:
		move_child(sheet, atmo.get_index())
	sheet.enter()
	return sheet

# --- surface gates (v0.1.0) -------------------------------------------------
#
# One renderer for both modes, so every gated surface on every screen looks and
# behaves the same. Screens name a surface and a node; `SurfaceVisibility` owns
# the condition and this owns the pixels.

## Padlock art rather than a glyph. U+1F512 is in none of the three theme fonts,
## which means it draws in the editor (macOS lends a system font) and as a tofu
## box in the browser — the exact failure the meter dots and the trend arrow
## were both converted away from, and the one `scripts/check_glyph_coverage.py`
## exists to catch.
const LOCK_ICON := preload("res://assets/icons/ui/icon-lock.svg")
## Content builders for the flow-sheet queue. No `class_name` on the callee
## (the stale-cache gotcha), so it is reached through this preload the same
## way LOCK_ICON is.
const FlowSheets := preload("res://ui/components/flow_sheets.gd")
## Name of the appended lock row, so a re-bind updates it instead of stacking
## another one under the card every time GameState changes.
const LOCK_BADGE := "SurfaceLockRow"
## Set on a gated node while its surface is locked; read by the tap handler.
const LOCKED_META := "surface_locked"

## Show, lock, or remove one surface. Returns the verdict, so a caller that
## wants to say more about a blocker has the numbers without asking twice.
##
## Idempotent by construction: it is called from `_bind_content()`, which runs on
## every state change, and each of the three states fully undoes the other two.
func apply_surface_gate(surface_id: String, node: Control) -> Dictionary:
	var access: Node = get_node_or_null("/root/SurfaceVisibility")
	if access == null or node == null:
		return {}
	var answer: Dictionary = access.verdict(surface_id)
	var state: String = str(answer.get("state", access.STATE_AVAILABLE))

	if state == access.STATE_HIDDEN:
		# Out of the layout, not merely invisible: `visible = false` makes a
		# Container skip the child entirely, so the surfaces below it close the
		# gap rather than leaving a hole where the feature will be.
		node.visible = false
		_clear_lock_badge(node)
		node.set_meta(LOCKED_META, false)
		return answer

	node.visible = true
	var locked: bool = state == access.STATE_LOCKED \
		or state == access.STATE_TEMPORARILY_BLOCKED
	node.set_meta(LOCKED_META, locked)
	if not locked:
		node.modulate.a = 1.0
		_clear_lock_badge(node)
		return answer

	node.modulate.a = float(_locked_opacity_pct()) / 100.0
	_show_lock_badge(node, str(answer.get("hint", "")))
	return answer

## 40, from the theme. A locked surface's opacity is a design token, not a
## number three screens each remember differently.
func _locked_opacity_pct() -> int:
	var pct: int = get_theme_constant("opacity_pct", "Locked")
	return pct if pct > 0 else 40

## Where the hint goes: the surface's own main column, so the line sits under
## the content it explains rather than beside it.
##
## A card is `PanelContainer > VBoxContainer` and resolves on the second rule; a
## row is `PanelContainer > HBoxContainer > [icon, column, status]` and resolves
## on the third, which picks the column that expands — the one carrying the
## title. A surface with no column at all is dimmed without a hint rather than
## having one wedged somewhere it does not belong.
func _lock_host(node: Control) -> Control:
	if node is VBoxContainer:
		return node
	if node.get_child_count() == 1 and node.get_child(0) is VBoxContainer:
		return node.get_child(0) as Control
	var queue: Array[Node] = [node]
	while not queue.is_empty():
		var current: Node = queue.pop_front()
		for child in current.get_children():
			if child is VBoxContainer \
					and (child as Control).size_flags_horizontal == Control.SIZE_EXPAND_FILL:
				return child as Control
			queue.append(child)
	return null

func _show_lock_badge(node: Control, hint: String) -> void:
	var host: Control = _lock_host(node)
	if host == null:
		return
	var row := host.get_node_or_null(LOCK_BADGE) as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = LOCK_BADGE
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.name = "Ico"
		icon.texture = LOCK_ICON
		icon.custom_minimum_size = Vector2(11, 11)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.self_modulate = Color(1, 1, 1, 0.6)
		row.add_child(icon)
		var text := Label.new()
		text.name = "Hint"
		text.theme_type_variation = &"LockHint"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
		host.add_child(row)
	var hint_label := row.get_node_or_null("Hint") as Label
	if hint_label:
		hint_label.text = hint
	row.visible = not hint.is_empty()

func _clear_lock_badge(node: Control) -> void:
	var host: Control = _lock_host(node)
	if host == null:
		return
	var row := host.get_node_or_null(LOCK_BADGE)
	if row != null:
		host.remove_child(row)
		row.queue_free()

## Show or remove a surface by path, for the common case where the caller has
## nothing else to say about it. Returns the node when it is still in play.
func gate_surface(surface_id: String, path: String) -> Control:
	var node := get_node_or_null(path) as Control
	if node == null:
		return null
	apply_surface_gate(surface_id, node)
	return node if node.visible else null

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

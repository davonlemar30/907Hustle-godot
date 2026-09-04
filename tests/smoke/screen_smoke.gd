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
	# BR-D1 (0.9.0): the stretch bug. A single long feed line on Home had no
	# wrap, so its minimum width pushed the whole shell past the viewport and
	# the web build rendered it centered with both edges cut off -- the bug
	# the owner reported for three builds. Every screen is instantiated over
	# state that carries the longest lines the game writes, and every visible
	# control has to sit inside the viewport's width.
	_stage_long_lines(gs)
	# The width sweep measures against the PHONE, not the headless window:
	# the design viewport is 375 wide, and a headless run opens wider than
	# that, which would let a control 700 wide pass.
	get_window().size = Vector2i(375, 812)
	await get_tree().process_frame
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
	var width_checks := 0
	var width_failed := 0
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
		await get_tree().process_frame
		var width_result := _check_width_fit(inst, n)
		width_checks += int(width_result[0])
		for violation in width_result[1]:
			printerr("WIDTH FAILED: %s" % violation)
			width_failed += 1
		inst.queue_free()
		await get_tree().process_frame
		ok += 1
		print("screen ok: %s" % n)
	print("screen smoke: %d/%d instantiated" % [ok, names.size()])
	print("screen smoke: touch checks %d/%d passed" % [touch_checks - touch_failed, touch_checks])
	print("screen smoke: width checks %d/%d passed" % [width_checks - width_failed, width_checks])
	if width_failed > 0:
		get_tree().quit.call_deferred(1)
	await _check_components(gs)
	await _check_panel_fit(gs)
	get_tree().quit.call_deferred(0)

# --- runtime components (0.6.0 PR A) -----------------------------------------
#
# Not every renderable thing in the build is a `.tscn` in `ui/screens`. Two are
# built entirely in code and parented at runtime, so the directory walk above
# has never been able to see them, and until 0.6.0 neither had any gate at all
# — `ModalSheet` shipped for two builds with nothing asserting it could even be
# constructed.
#
# 0.6.0 makes that gap load-bearing: an encounter is a `ModalSheet` wrapping
# `encounter_sheet.gd`'s content over a `health_bar.gd`, so a parse error or a
# bad `.new()` in any of the three is a chain the player cannot answer, on a
# screen with no navigation off it. This asks the same two questions the screen
# walk asks — does it construct, and does everything inside a ScrollContainer
# still hold the touch-scroll property — of the components instead.
#
# Built against a REAL live chain rather than a stub: the whole point of
# `encounter_sheet.gd` is that it resolves from the engine's summary calls, and
# a fake summary would prove those calls are never made wrong.

const ENCOUNTER_SHEET := preload("res://ui/components/encounter_sheet.gd")
const HEALTH_BAR := preload("res://ui/components/health_bar.gd")

func _check_components(gs: Node) -> void:
	var gm: Node = get_node("/root/GameManager")
	var engine: Object = gm.system("consequence")
	var checks := 0
	var failed := 0

	# The health bar on its own, first: it is the one component with no chain
	# behind it, so a failure here is unambiguously the component.
	var bar: Control = HEALTH_BAR.new().bind(gs)
	checks += 1
	if bar == null or bar.get_child_count() == 0:
		printerr("COMPONENT FAILED: health_bar built nothing")
		failed += 1
	else:
		add_child(bar)
		await get_tree().process_frame
	if bar != null:
		bar.queue_free()
		await get_tree().process_frame

	# A real wander chain, opened through the real engine, at each of the two
	# stages that ride a sheet.
	var opened: Dictionary = engine.open_chain(engine.KIND_WANDER, {
		"district_id": str(gs.current_district_id),
		"return_route": "HOME",
		"source": {"family": "wander", "action_id": "wander",
			"card_id": "smoke", "opponent": "Somebody", "shape": "confrontation",
			"target_id": "smoke", "target_name": "Somebody", "target_tier": 1,
			"source_rng_key": "smoke"},
		"decision": {
			"definition_id": "smoke",
			"allowed_choices": ["stand", "walk", "hand_over"],
			"deterministic_choices": ["hand_over"],
			"shown_probabilities": {"stand": 0.45, "walk": 0.6},
		},
	})
	checks += 1
	if not bool(opened.get("ok", false)):
		printerr("COMPONENT FAILED: could not open a probe chain")
		failed += 1
		print("screen smoke: component checks %d/%d passed" % [checks - failed, checks])
		return

	for stage in ["decision", "result"]:
		if stage == "result":
			(gs.active_consequence["decision"] as Dictionary)["result"] = {
				"choice_id": "walk", "tier": "messy", "cash": -20,
				"goods": 0, "health": -4, "heat": 0.0,
			}
			(gs.active_consequence["decision"] as Dictionary)["resolved_tier"] = "messy"
			(gs.active_consequence["decision"] as Dictionary)["committed_choice"] = "walk"
			engine.advance_stage(engine.STAGE_RESULT)
		var content: Control = ENCOUNTER_SHEET.build_sheet(engine, gs, Callable())
		checks += 1
		if content == null:
			printerr("COMPONENT FAILED: encounter_sheet built nothing at %s" % stage)
			failed += 1
			continue
		var sheet := ModalSheet.new()
		sheet.blocking = true
		sheet.setup(content)
		add_child(sheet)
		await get_tree().process_frame
		var result: Array = _check_scroll_transparency(sheet, "encounter_sheet:%s" % stage)
		checks += int(result[0])
		for violation in result[1]:
			printerr("TOUCH FAILED: %s" % violation)
			failed += 1
		sheet.queue_free()
		await get_tree().process_frame

	gs.active_consequence = {}
	print("screen smoke: component checks %d/%d passed" % [checks - failed, checks])
	if failed > 0:
		get_tree().quit.call_deferred(1)

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
## BR-D1: the longest lines the game writes, on every surface that shows
## them. A Week Zero ambient line is the one that broke Home.
const LONG_LINE := "Two women outside the laundromat, talking about somebody named Curtis the way people talk about weather. You do not know who that is yet, and you can tell from how they say it that you will."

func _stage_long_lines(gs: Node) -> void:
	for i in 3:
		gs.log_activity(LONG_LINE, Color(0.8, 0.8, 0.8))
	var gm: Node = get_node("/root/GameManager")
	var phone: Object = gm.system("phone")
	if phone != null:
		phone.push_text("Yalonda", LONG_LINE, "yalonda_rent")
		phone.push_message("Around town", LONG_LINE)

## Every visible control inside the viewport's width. The screen root is
## anchored full-rect; a child whose minimum width exceeds the viewport grows
## the shell instead of wrapping, and that is exactly the failure.
func _check_width_fit(inst: Node, screen_name: String) -> Array:
	var checks := 0
	var violations: Array = []
	var width: float = get_viewport().get_visible_rect().size.x
	var stack: Array = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			if not (child is Control):
				continue
			var control: Control = child
			if not control.is_visible_in_tree():
				continue
			checks += 1
			var rect: Rect2 = control.get_global_rect()
			if rect.position.x < -1.0 or rect.end.x > width + 1.0:
				violations.append("%s: %s spans %d..%d against a %d-wide viewport (min %s)"
					% [screen_name, inst.get_path_to(control), int(rect.position.x),
						int(rect.end.x), int(width), control.get_combined_minimum_size()])
	return [checks, violations]

func _declares_script(scene_name: String) -> bool:
	var file := FileAccess.open("res://ui/screens/%s" % scene_name, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	return text.contains("script = ExtResource")

# --- the panel fits (0.7.0 PR C, BB-D6) --------------------------------------
#
# Two things a screenshot of the sheet kept looking fine about and were not:
# the third road sat below the fold of a 375x812 phone, and "the street stays
# visible behind it" was a hundred-pixel slice. Both are numbers, so both are
# read here: the card's resting top against the viewport, and every road's
# button rect against the sheet's own visible scroll rect. Every authored
# street card is built against the REAL chain it opens -- the roads a card
# offers depend on what the player is carrying and who is on the crew, and a
# fixture would not know that.

const WANDER_EVENTS := preload("res://data/wander_events.gd")
## The fraction of the viewport, measured from the top, that must stay
## uncovered above the sheet on a decision.
const MIN_UNCOVERED := 0.35

func _check_panel_fit(gs: Node) -> void:
	var gm: Node = get_node("/root/GameManager")
	var engine: Object = gm.system("consequence")
	var wander: Object = gm.system("wander")
	var checks := 0
	var failed := 0
	var viewport_h: float = get_viewport().get_visible_rect().size.y
	for entry in WANDER_EVENTS.CARDS:
		var card: Dictionary = entry
		if str(card["kind"]) != WANDER_EVENTS.KIND_ENCOUNTER:
			continue
		var card_id := str(card["id"])
		gs.reset_to_new_game()
		gs.inventory = {"weed": 3}
		gs.active_consequence = {}
		wander._play_encounter(card, "smoke:panel:%s" % card_id)
		var content: Control = ENCOUNTER_SHEET.build_sheet(engine, gs, Callable())
		checks += 1
		if content == null:
			printerr("PANEL FAILED: %s built no decision sheet" % card_id)
			failed += 1
			gs.active_consequence = {}
			continue
		var sheet := ModalSheet.new()
		sheet.blocking = true
		sheet.setup(content)
		add_child(sheet)
		# Three frames: one to enter the tree, one for the theme to resolve
		# the labels' minimum sizes, one for the road buttons to grow to
		# their overlays (`encounter_sheet.gd::_choice_card`).
		for _frame in range(3):
			await get_tree().process_frame

		var card_rect: Rect2 = sheet._card.get_global_rect()
		var uncovered: float = card_rect.position.y / maxf(1.0, viewport_h)
		checks += 1
		if uncovered < MIN_UNCOVERED:
			printerr("PANEL FAILED: %s leaves %d%% of the street uncovered, need %d%%"
				% [card_id, int(round(uncovered * 100.0)), int(round(MIN_UNCOVERED * 100.0))])
			failed += 1

		var scrolls: Array = content.find_children("*", "ScrollContainer", true, false)
		checks += 1
		if scrolls.is_empty():
			printerr("PANEL FAILED: %s's sheet has no scroll container" % card_id)
			failed += 1
		else:
			var visible: Rect2 = (scrolls[0] as Control).get_global_rect()
			# What the card AUTHORS fits without scrolling. A road the
			# situation adds on top -- STASH IT while carrying, a crew call
			# while somebody is around -- is offered after the authored ones
			# and may sit a drag away: five roads with a line under each do
			# not fit above 35% of street, and the authored roads are the
			# ones the player is owed at a glance.
			var authored: Array = (card["encounter"] as Dictionary).get("choices", [])
			var roads := 0
			for node in content.find_children("*", "Button", true, false):
				var button: Button = node
				if not button.has_meta(ENCOUNTER_SHEET.ACTION_META):
					continue
				if str(button.get_meta(ENCOUNTER_SHEET.ACTION_META)) != ENCOUNTER_SHEET.ACTION_COMMIT:
					continue
				roads += 1
				if not str(button.get_meta(ENCOUNTER_SHEET.CHOICE_META)) in authored:
					continue
				var rect: Rect2 = button.get_global_rect()
				checks += 1
				if rect.position.y < visible.position.y - 0.5 \
						or rect.end.y > visible.end.y + 0.5:
					printerr("PANEL FAILED: %s's road '%s' is off the sheet without scrolling (%d-%d against %d-%d)"
						% [card_id, str(button.get_meta(ENCOUNTER_SHEET.CHOICE_META)),
							int(rect.position.y), int(rect.end.y),
							int(visible.position.y), int(visible.end.y)])
					failed += 1
			checks += 1
			if roads < 3:
				printerr("PANEL FAILED: %s offers %d roads; the triad is three" % [card_id, roads])
				failed += 1
		sheet.queue_free()
		await get_tree().process_frame
	gs.active_consequence = {}
	print("screen smoke: panel checks %d/%d passed" % [checks - failed, checks])
	if failed > 0:
		get_tree().quit.call_deferred(1)

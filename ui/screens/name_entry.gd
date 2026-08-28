extends Control
## Name entry — the second half of starting a run.
##
## Standalone like the title screen: no chrome, no HUD, no bottom nav, so it
## does not extend screen_base.gd.
##
## This is canon's START_RUN opening, not CHOOSE_BACKGROUND. The player wakes in
## Yalonda's spare room with $100 and nothing else — no job, no contacts, no
## reputation, no note from Dre. The established-week opening is a different
## screen the game does not have yet.

@onready var gs: Node = get_node("/root/GameState")
@onready var nav: Node = get_node("/root/ScreenManager")
## The action layer. This screen reads `gs` for the sanitiser that greys the
## button and dispatches for everything that writes — see `_on_begin`.
@onready var _gm: Node = get_node("/root/GameManager")

@onready var _name: LineEdit = $Pad/V/Name
@onready var _begin: Button = $Pad/V/Begin
@onready var _where: Label = $Pad/V/Info/IV/Where

func _ready() -> void:
	_begin.pressed.connect(_on_begin)
	# Enter on a hardware keyboard should start the run, same as the button.
	_name.text_submitted.connect(func(_t: String) -> void: _on_begin())
	_name.text_changed.connect(_on_text_changed)
	# Re-raise the keyboard when the field is tapped while it already has focus.
	# Godot only calls virtual_keyboard_show() on FOCUS_ENTER, so once the field
	# is focused a further tap does nothing — and a player who dismissed the
	# keyboard would have no way to get it back.
	_name.gui_input.connect(_on_name_gui_input)
	_bind_preview()
	_refresh_begin()
	# Deliberately NOT grab_focus() here. Mobile browsers only honour a focus
	# that happens inside a user gesture; focusing during _ready() falls outside
	# one, and worse, it leaves the field focused so the player's first tap never
	# fires FOCUS_ENTER and the keyboard never appears at all. Letting the tap do
	# the focusing is what makes this work on iOS Safari.

## The card previews where the run opens. Read from GameState rather than baked
## into the scene so it cannot drift from what Home will actually show.
func _bind_preview() -> void:
	var opening := _opening_district_name()
	_where.text = "%s   ·   DAY 1   ·   MORNING" % opening

func _opening_district_name() -> String:
	var d: Dictionary = gs.district_by_id("north_star_lot")
	return str(d.get("name", "SPENARD"))

func _on_name_gui_input(event: InputEvent) -> void:
	if not _name.has_focus():
		return  # FOCUS_ENTER is about to fire and will raise it anyway
	# Explicit type: event.pressed off an untyped InputEvent is a Variant, and
	# := cannot infer from it.
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(_name.text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, gs.STREET_NAME_MAX, _name.caret_column)

func _on_text_changed(_t: String) -> void:
	_refresh_begin()

## Canon returns the state unchanged when the sanitized name is empty
## (game-core.js:7421), so an all-punctuation entry is no more valid than a
## blank one. Disable rather than fail silently on press.
func _refresh_begin() -> void:
	_begin.disabled = gs.sanitize_street_name(_name.text).is_empty()

## Through dispatch, like every other write in the build (86bbjxtbm). This
## screen used to set `gs.street_name` and call `gs.reset_to_new_game()` itself
## — the one path in the game that bypassed the action layer, and the one where
## `is_dispatching()` therefore read false through the largest write there is.
## `systems/run_start.gd` owns it now; the name is sanitised there too, so this
## screen no longer holds the only copy of the rule.
func _on_begin() -> void:
	if not _gm.dispatch("start_run", {"street_name": _name.text}):
		return
	# Yalonda's welcome replaces the Opening screen (0.1.2). Enqueued before
	# go_to_game(), not that it matters here: start_run's reset just closed
	# every gate, so the dispatch announced nothing and the intro sheet is
	# alone in the queue. "Shown once per run" stays a property of the flow
	# rather than a flag somebody has to remember to clear -- naming yourself
	# happens once, and CONTINUE RUN on the title screen calls go_to_game()
	# directly and never enqueues it.
	nav.enqueue_flow_sheet({"kind": "intro"})
	nav.go_to_game()

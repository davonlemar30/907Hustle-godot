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

@onready var _name: LineEdit = $Pad/V/Name
@onready var _begin: Button = $Pad/V/Begin
@onready var _where: Label = $Pad/V/Info/IV/Where

func _ready() -> void:
	_begin.pressed.connect(_on_begin)
	# Enter on a hardware keyboard should start the run, same as the button.
	_name.text_submitted.connect(func(_t: String) -> void: _on_begin())
	_name.text_changed.connect(_on_text_changed)
	_bind_preview()
	_refresh_begin()
	_name.grab_focus()

## The card previews where the run opens. Read from GameState rather than baked
## into the scene so it cannot drift from what Home will actually show.
func _bind_preview() -> void:
	var opening := _opening_district_name()
	_where.text = "%s   ·   DAY 1   ·   MORNING" % opening

func _opening_district_name() -> String:
	var d: Dictionary = gs.district_by_id("north_star_lot")
	return str(d.get("name", "SPENARD"))

func _on_text_changed(_t: String) -> void:
	_refresh_begin()

## Canon returns the state unchanged when the sanitized name is empty
## (game-core.js:7421), so an all-punctuation entry is no more valid than a
## blank one. Disable rather than fail silently on press.
func _refresh_begin() -> void:
	_begin.disabled = gs.sanitize_street_name(_name.text).is_empty()

func _on_begin() -> void:
	var chosen: String = gs.sanitize_street_name(_name.text)
	if chosen.is_empty():
		return
	gs.street_name = chosen
	gs.reset_to_new_game()
	nav.go_to_game()

extends Control
## Title screen — the first thing the game shows.
##
## Standalone: deliberately does NOT extend screen_base.gd, which exists to fill
## the shared top bar and HUD. There is no chrome here and no bottom nav, which
## is why the nav's absence needs no logic — this scene simply has none.

# Autoloads by path, not by the compile-time global, so a freshly-registered
# singleton resolves even before the editor reloads.
@onready var gs: Node = get_node("/root/GameState")
@onready var nav: Node = get_node("/root/ScreenManager")

@onready var _new_run: Button = $Pad/V/NewRun
@onready var _continue: Button = $Pad/V/ContinueRun
@onready var _last_run: Label = $Pad/V/LastRun

func _ready() -> void:
	_new_run.pressed.connect(_on_new_run)
	_continue.pressed.connect(_on_continue)
	_refresh_save_state()

## CONTINUE RUN and the LAST RUN summary both describe a saved run. Save/load is
## Phase 4, so there is nothing to describe yet and both stay hidden rather than
## sitting there dead. When saves land, this is the one place that changes.
func _refresh_save_state() -> void:
	var has_save := _has_save()
	_continue.visible = has_save
	_last_run.visible = has_save
	if has_save:
		_last_run.text = _last_run_summary()

func _has_save() -> bool:
	return false

## Canon shows the same five fields in its save preview (game-core.js:2184):
## name, day, slot, district, cash.
func _last_run_summary() -> String:
	return "LAST RUN · DAY %d · %s · %s · $%d CASH" % [
		gs.day,
		gs.time_slot,
		gs.current_district().get("name", "SPENARD"),
		gs.cash,
	]

func _on_new_run() -> void:
	nav.go_to(nav.NAME_ENTRY)

func _on_continue() -> void:
	nav.go_to_game()

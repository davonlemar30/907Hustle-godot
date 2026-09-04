extends Control
## Title screen — the first thing the game shows.
##
## Standalone: deliberately does NOT extend screen_base.gd, which exists to fill
## the shared top bar and HUD. There is no chrome here and no bottom nav, which
## is why the nav's absence needs no logic — this scene simply has none.
##
## Save-aware since Phase 4. CONTINUE RUN and the LAST RUN preview mirror
## canon's TitleScreen (ui.built.js): the preview shows name / day / part /
## district / cash / debt, Load resumes the exact autosaved run, and New Game
## over a valid save asks first ("The current autosave will be replaced").
## The save itself is only overwritten when the new run actually begins —
## backing out at name entry keeps the old run, same as canon.
##
## 86bbexucb (0.3.0): the foreground UI (`Content`, in the scene) is capped at
## a 375-wide column and centred, so a desktop-width viewport still shows the
## mobile-proportioned layout — buttons at their authored width, not
## stretched edge to edge — instead of the raw anchor-fills-parent behaviour
## every Control here had before. The background (photo, scrim, snow) stays
## unconstrained and fills the full viewport regardless: only the things a
## human reads and taps needed the cap.

# Autoloads by path, not by the compile-time global, so a freshly-registered
# singleton resolves even before the editor reloads.
@onready var gs: Node = get_node("/root/GameState")
@onready var nav: Node = get_node("/root/ScreenManager")
@onready var saves: Node = get_node("/root/SaveSystem")

@onready var _new_run: Button = $Content/Pad/V/NewRun
@onready var _continue: Button = $Content/Pad/V/ContinueRun
@onready var _last_run: Label = $Content/Pad/V/LastRun
@onready var _confirm: VBoxContainer = $Content/Pad/V/Confirm
## The build stamp. Bottom-right, deliberately quiet: it exists so a playtest
## report can name the build it came from, not to be read during play.
@onready var _version: Label = $Content/VersionStamp

## The last inspect() result, so the buttons and the preview always describe
## the same read of the file.
var _save_info: Dictionary = {}

func _ready() -> void:
	# Plain `pressed` is correct here: the title has no ScrollContainer, so
	# there is no drag gesture to protect (see the scroll rule in HANDOFF.md).
	_new_run.pressed.connect(_on_new_run)
	_continue.pressed.connect(_on_continue)
	$Content/Pad/V/Confirm/StartNew.pressed.connect(_on_confirm_new)
	$Content/Pad/V/Confirm/KeepSave.pressed.connect(_on_cancel_new)
	# The scene's baked "v0.0.0" is an editor-time preview, the same convention
	# every other screen uses. Version.VERSION is the only real source.
	_version.text = get_node("/root/Version").display()
	_refresh_save_state()

func _refresh_save_state() -> void:
	_save_info = saves.inspect()
	var has_save := _has_save()
	_continue.visible = has_save
	_last_run.visible = has_save
	if has_save:
		_last_run.text = _last_run_summary()

func _has_save() -> bool:
	return bool(_save_info.get("valid", false))

## Canon's save-preview stack (ui.built.js TitleScreen): name on its own line,
## then "Saved run · Day X · Part", then "District · cash · debt".
func _last_run_summary() -> String:
	var p: Dictionary = _save_info.get("preview", {})
	# SA-D1 (1.1.0): the third line says who you were, not only where.
	return "%s\nSAVED RUN · DAY %d · %s\n%s · %s · $%d CASH · $%d DEBT" % [
		str(p.get("name", "")).to_upper(),
		int(p.get("day", 1)),
		str(p.get("part", "MORNING")),
		str(p.get("district", "SPENARD")),
		str(p.get("rank", "Nobody")).to_upper(),
		int(p.get("cash", 0)),
		int(p.get("debt", 0)),
	]

func _on_new_run() -> void:
	# Canon confirms before replacing a valid save (App.startNew). The save is
	# not touched here — the first autosave of the new run is what replaces it.
	if _has_save():
		_set_confirming(true)
		return
	nav.go_to(nav.NAME_ENTRY)

func _on_confirm_new() -> void:
	nav.go_to(nav.NAME_ENTRY)

func _on_cancel_new() -> void:
	_set_confirming(false)

func _set_confirming(on: bool) -> void:
	_confirm.visible = on
	_new_run.visible = not on
	_continue.visible = not on and _has_save()

func _on_continue() -> void:
	if saves.load_run():
		nav.go_to_game()
		return
	# The file was valid at inspect() but failed to load — canon's copy for an
	# unreadable save. Re-inspect so the dead button hides itself.
	nav.show_toast("The saved run could not be read. Start a new run to replace it.")
	_refresh_save_state()

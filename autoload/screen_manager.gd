extends Node
## ScreenManager — the one place that swaps top-level screens.
##
## Every screen is its own scene, so navigation is a whole-scene change rather
## than a swap inside a shared shell. Screens never call change_scene_to_file()
## directly; they go through here, the same way they never mutate GameState
## directly but dispatch through GameManager.
##
## Nav-bar visibility needs no logic: Title and NameEntry simply do not contain
## a NavBar, and the four game screens do. It is structural, not stateful.

## Canonical paths, so a typo in a screen script is a missing-constant error at
## parse time instead of a silent failed load at runtime.
const TITLE := "res://ui/screens/title.tscn"
const NAME_ENTRY := "res://ui/screens/name_entry.tscn"
const HOME := "res://ui/screens/home.tscn"
const STREET := "res://ui/screens/street.tscn"
const MARKET := "res://ui/screens/market.tscn"
const HUSTLE := "res://ui/screens/hustle.tscn"

## Screens the bottom nav can reach today. Phone and More have no scene yet, so
## the nav treats them as no-ops rather than routing into a broken load.
const NAV_ROUTES := {
	"Street": STREET,
	"Hustle": HUSTLE,
	"Home": HOME,
	"Phone": "",
	"More": "",
}

## Emitted after a successful screen change, with the path that was loaded.
signal screen_changed(path: String)

func go_to(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	# Deferred because a nav button is mid-signal when it calls this, and
	# freeing the scene that owns that button inside its own handler crashes.
	_change.call_deferred(scene_path)

## Enter the game proper. Named separately from go_to(HOME) because callers mean
## "start playing", and where that lands may stop being Home later.
func go_to_game() -> void:
	go_to(HOME)

func _change(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("ScreenManager: could not load %s (error %d)" % [scene_path, err])
		return
	screen_changed.emit(scene_path)

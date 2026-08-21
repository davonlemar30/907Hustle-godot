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
const JOBS := "res://ui/screens/jobs.tscn"
const STICKUP := "res://ui/screens/stickup.tscn"
const SHARK := "res://ui/screens/shark.tscn"
const LIST := "res://ui/screens/nine07list.tscn"
const BOOST := "res://ui/screens/boost.tscn"
const CREW := "res://ui/screens/crew.tscn"
const TURF := "res://ui/screens/turf.tscn"
const PEOPLE := "res://ui/screens/people.tscn"
const PHONE := "res://ui/screens/phone.tscn"
const MORE := "res://ui/screens/more.tscn"
const HELP := "res://ui/screens/help.tscn"
const GAME_OVER := "res://ui/screens/game_over.tscn"

## Every bottom-nav cell has a scene now. The empty-route branch in
## screen_base::_wire_nav() is kept for the next cell that does not.
const NAV_ROUTES := {
	"Street": STREET,
	"Hustle": HUSTLE,
	"Home": HOME,
	"Phone": PHONE,
	"More": MORE,
}

## Emitted after a successful screen change, with the path that was loaded.
signal screen_changed(path: String)

const TOAST := "res://ui/components/toast.tscn"

# One toast for the session. Parented to /root rather than the current scene so a
# message survives a screen change instead of being freed mid-fade.
var _toast: CanvasLayer

## Brief, non-blocking feedback. Safe to call from any screen at any time.
func show_toast(text: String) -> void:
	if _toast == null or not is_instance_valid(_toast):
		_toast = load(TOAST).instantiate()
		# Deferred: this is usually called from a button handler, and adding to
		# the tree while the tree is flushing input is not allowed.
		get_tree().root.add_child.call_deferred(_toast)
		await _toast.ready
	_toast.show_message(text)

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

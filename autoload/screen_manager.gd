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
const CHARACTER := "res://ui/screens/character.tscn"
const RECOVERY := "res://ui/screens/recovery.tscn"
const GAME_OVER := "res://ui/screens/game_over.tscn"
## The blocking consequence scene (TI-003 §18). Not in NAV_ROUTES: it is never
## somewhere the player chooses to go.
const CONSEQUENCE := "res://ui/screens/consequence.tscn"

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
	if not _toast.is_node_ready():
		await _toast.ready
	if is_instance_valid(_toast):
		_toast.show_message(text)

## The global screen priority, TI-003 §18:
##
##   1. game over
##   2. active blocking consequence
##   3. the ordinary screen that was asked for
##
## Enforced here rather than at each call site because "ordinary navigation
## cannot bypass it" has to hold for navigation nobody has written yet. A nav
## button, a deep link from a surface, a Continue on the title screen — they all
## come through `go_to`, so they all get the same answer.
##
## Deliberately NOT enforced for the two screens that are themselves the higher
## priority: routing to Game Over while a consequence is open must reach Game
## Over, or the run could never end mid-chain.
func blocking_route() -> String:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return ""
	if bool(gs.game_over):
		return GAME_OVER
	if not (gs.active_consequence as Dictionary).is_empty():
		return CONSEQUENCE
	return ""

## Where a request for `scene_path` actually lands once priority is applied.
## Pure, so the route guard is testable without changing scenes.
##
## Two guards, in order. The blocking priority above outranks everything,
## including a locked route — a consequence has to open whatever the player was
## reaching for. Under it sits the ACCESS guard: a destination whose surface the
## player has not earned is not somewhere `go_to` can land, and the request is
## refused by returning "" rather than by picking a substitute, because
## substituting a screen the player did not ask for is worse than doing nothing.
##
## This exists so the gate is on the DESTINATION rather than on each button. The
## Crew screen has three doors (More's row, Street's People row, and any deep
## link a later build adds); the design pass's Improvement 2 is that all three
## get the same answer, and they do because they all come through here.
func resolved_route(scene_path: String) -> String:
	if scene_path == GAME_OVER or scene_path == CONSEQUENCE:
		return scene_path
	var blocking: String = blocking_route()
	if not blocking.is_empty():
		return blocking
	var access: Node = get_node_or_null("/root/SurfaceVisibility")
	if access != null and not access.route_allowed(scene_path):
		return ""
	return scene_path

func go_to(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	var destination: String = resolved_route(scene_path)
	# A refused route is silent, the same as a tap on a locked card: the lock
	# and its hint have already said why, and a toast on top of them reads as a
	# malfunction rather than a rule.
	if destination.is_empty():
		return
	# Deferred because a nav button is mid-signal when it calls this, and
	# freeing the scene that owns that button inside its own handler crashes.
	_change.call_deferred(destination)

## Enter the game proper. Named separately from go_to(HOME) because callers mean
## "start playing", and where that lands may stop being Home later.
##
## This is the boot and CONTINUE RUN path, so it is also where a save loaded
## mid-chain re-enters the consequence — TI-003 §18 requires that to happen
## without an ordinary screen being exposed for an interactive frame, and
## routing here rather than to Home and correcting is what achieves it.
func go_to_game() -> void:
	go_to(HOME)

func _change(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("ScreenManager: could not load %s (error %d)" % [scene_path, err])
		return
	screen_changed.emit(scene_path)

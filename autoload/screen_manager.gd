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
## The two venue interiors (batch 7). Not in NAV_ROUTES — a venue is reached
## from the Street card that names it, never from the bottom bar.
const SPENARD_GYM := "res://ui/screens/spenard_gym.tscn"
const NIGHT_OWL := "res://ui/screens/night_owl.tscn"
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
##
## SQ-D2 (0.6.0) narrowed what reaches it: `booking` and `release` still take
## the whole screen, `decision` and `result` ride a ModalSheet over whatever
## screen the player was already on. See `blocking_route()`.
const CONSEQUENCE := "res://ui/screens/consequence.tscn"

## SQ-D2's stage split lives with the presentation that owns it, not here — see
## `ui/components/encounter_sheet.gd`. Preloaded rather than reached by
## `class_name` for the same reason `flow_sheets.gd` is: a UI component with a
## global type name is a stale editor cache waiting to happen.
const ENCOUNTER_SHEET := preload("res://ui/components/encounter_sheet.gd")
const HEALTH_BAR := preload("res://ui/components/health_bar.gd")

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

# --- flow sheets (0.1.2) -----------------------------------------------------
#
# A queue of plain-data specs -- {"kind": "discovery", "surface_id": "..."} or
# {"kind": "intro"} -- drained one at a time by whichever live game screen is
# current when it is safe to show one (`screen_base.gd::_drain_flow_sheets`).
# Specs are data, never nodes: copy resolves at SHOW time through
# `ui/components/flow_sheets.gd`, so a spec can sit queued across a screen
# change with nothing to free and nothing that can go stale.
#
# A toast (above) is fire-and-forget and asks nothing of its caller. A flow
# sheet has to wait its turn behind a consequence chain and only ever shows
# one at a time, which is what the queue and the active-sheet handle are for.

var _flow_queue: Array = []
var _active_flow_sheet: ModalSheet = null

func _ready() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("surfaces_announced"):
		gm.surfaces_announced.connect(_on_surfaces_announced)

## One discovery spec per surface that just opened, registry order (the same
## order `announce_since()` reported them in).
func _on_surfaces_announced(surface_ids: Array) -> void:
	for id in surface_ids:
		enqueue_flow_sheet({"kind": "discovery", "surface_id": str(id)})

func enqueue_flow_sheet(spec: Dictionary) -> void:
	_flow_queue.append(spec)

## Pop and return the front spec, or {} when the queue is empty.
func take_next_flow_sheet() -> Dictionary:
	if _flow_queue.is_empty():
		return {}
	return _flow_queue.pop_front()

func has_pending_flow_sheets() -> bool:
	return not _flow_queue.is_empty()

## Run-boundary reset. `_change()` below calls this on the way into TITLE or
## NAME_ENTRY, so a dead run's pending cards never pop over a fresh one.
##
## The health bar's animation memory (SQ-D5) is a run-scoped presentation fact
## and clears on the same boundary for the same reason: without this the first
## encounter of a NEW run would animate down from the dead run's last health.
func clear_flow_sheets() -> void:
	_flow_queue.clear()
	HEALTH_BAR.forget()

## Put a spec back at the FRONT of the queue.
##
## SQ-D4(a)'s loss-free half. A chain opening while an ordinary card is already
## on screen is a race the encounter must win outright — but the drain has
## already POPPED that card's spec by then, and winning by dropping it on the
## floor would cost the player a discovery they earned. The drain hands it back
## here instead, and it is the next thing shown once the chain is gone.
func requeue_flow_sheet(spec: Dictionary) -> void:
	if spec.is_empty():
		return
	_flow_queue.push_front(spec)

## Whether a sheet is up right now. `is_instance_valid` rather than a plain
## null check: a forced scene swap frees the sheet along with the screen that
## owned it, and a stale reference here would wedge the queue behind a sheet
## that no longer exists.
func flow_sheet_active() -> bool:
	return _active_flow_sheet != null and is_instance_valid(_active_flow_sheet)

## The drain calls this once it has actually shown a sheet. Stores the handle
## `flow_sheet_active()` reads, and clears it back out on `dismissed` so a
## sheet mid-exit-tween does not read as still blocking the next drain.
func register_flow_sheet(sheet: ModalSheet) -> void:
	_active_flow_sheet = sheet
	sheet.dismissed.connect(func(): _active_flow_sheet = null)

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
## SQ-D2 (0.6.0) is the one change to this ladder since it was written, and it
## is a change to rung 2 only: a live chain is blocking **only at the stages
## that still take the screen**. `decision` and `result` return "" and are
## presented as a ModalSheet over the ordinary screen instead
## (`screen_base.gd::_drain_flow_sheets`), which is what lets the street stay
## visible behind an encounter. Game over still outranks everything.
##
## This function has THREE readers and all three change behaviour together:
## `resolved_route()` below, the boot/CONTINUE path through `go_to_game()`, and
## the flow-sheet drain's own guard in `screen_base.gd`. That is deliberate —
## one place decides, so an encounter cannot be escapable by navigation while
## still deferring a discovery card, or any other half-applied combination.
func blocking_route() -> String:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return ""
	if bool(gs.game_over):
		return GAME_OVER
	var chain: Dictionary = gs.active_consequence
	if not chain.is_empty() and not ENCOUNTER_SHEET.stage_rides_sheet(
			str(chain.get("stage", ""))):
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
## without an ordinary screen being exposed for an interactive frame.
##
## How that requirement is met changed in 0.6.0 (SQ-D2/SQ-D4) and this
## doc-comment changed with it, because a comment describing a route that no
## longer exists is the same drift the build that wrote it exists to fix:
##
##   - **booking / release** still route straight to CONSEQUENCE from here,
##     through `resolved_route()`, exactly as before. Home is never built.
##   - **decision / result** now land on Home and have the encounter sheet
##     opened over them by `screen_base.gd::_drain_flow_sheets`. The drain is
##     `call_deferred` from `refresh()`, so there IS a frame in which Home is
##     the current scene — but it is not an INTERACTIVE one: `ModalSheet`'s
##     own `enter()` already awaits a frame before animating, the scrim is
##     parented at MOUSE_FILTER_STOP the moment `setup()` runs, and the drain
##     runs before input is processed for that frame. §18's requirement is
##     that a tap in that window cannot reach the screen underneath, and it
##     cannot.
func go_to_game() -> void:
	go_to(HOME)

func _change(scene_path: String) -> void:
	# Pending popups are a property of a run, not of the app. Routing back to
	# either boot screen means the run that queued them is gone or ending, so
	# a dead run's cards must not pop up over the one that replaces it.
	if scene_path == TITLE or scene_path == NAME_ENTRY:
		clear_flow_sheets()
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("ScreenManager: could not load %s (error %d)" % [scene_path, err])
		return
	screen_changed.emit(scene_path)

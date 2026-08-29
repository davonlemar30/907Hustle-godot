class_name ModalSheet
extends Control
## Reusable bottom-sheet motion shell: a scrim behind a card that slides up
## from the bottom edge. PR 3 (Market's quantity picker) is the first caller;
## PR 5 (encounter popups) is the second, which is why this carries no
## Market-specific knowledge at all.
##
## Usage: build a content Control, `setup(content)`, add this node as a child
## of the screen's root (above `Shell` so it overlays the scroll content,
## below any atmosphere overlay so grain/vignette still shows on top), then
## `enter()`. The caller never manages this node's lifetime beyond that —
## a scrim tap, a downward drag on the handle, or a direct `exit()` call all
## end the same way: `dismissed` fires, then this frees itself.
##
## ## `blocking` (SQ-D3, 0.6.0)
##
## An encounter rides this shell now, and a chain the player can swipe away is
## not a chain. `blocking` (default `false`, so Market's quantity picker and
## every flow sheet are byte-for-byte unaffected) removes both dismissal
## gestures: the scrim ignores taps, and the handle bar is not built AT ALL
## rather than built and ignored — a grab-bar that does nothing is a control
## that lies. A blocking sheet closes exactly one way, through a direct
## `exit()` from the owner once the chain resolves. There is no back-out,
## because the chassis guarantees every round offers an out and a chain with
## no answer is a chain with no out.

signal dismissed

const ENTRY_TIME := 0.18
const EXIT_TIME := 0.14
const SLIDE := 40.0
const SCRIM_ALPHA := 0.6
const HANDLE_HEIGHT := 20.0
const DRAG_DISMISS_DISTANCE := 60.0

var _scrim: ColorRect
var _card: PanelContainer
var _content: Control
var _body: VBoxContainer
var _exiting: bool = false
var _dragging: bool = false
var _drag_origin_y: float = 0.0

## SQ-D3. Set BEFORE `setup()` — the handle is a build-time decision, not a
## runtime one.
var blocking: bool = false

## Build the scrim + card around `content`. Does not animate or add itself
## anywhere — the caller parents this node, then calls `enter()`.
func setup(content: Control) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_content = content

	_scrim = ColorRect.new()
	_scrim.color = Color(0, 0, 0, 0)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_card = PanelContainer.new()
	_card.theme_type_variation = &"Card"
	# STOP, not the Container default of PASS: without this, a tap on the
	# card's own whitespace (between labels, not on a button) falls through
	# to the scrim underneath and dismisses the sheet the tap never meant to
	# close.
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.anchor_left = 0.0
	_card.anchor_right = 1.0
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	if not blocking:
		_body.add_child(_build_handle())
	_body.add_child(content)
	_card.add_child(_body)

	add_child(_card)

## Swap the card's content in place, keeping the sheet (and its scrim, and its
## entry animation) exactly where it is.
##
## A blocking encounter sheet is one sheet across a whole chain: commit a
## choice and the SAME sheet has to show the result, and a round that presents
## a new situation has to redraw without the card sliding out and back in. That
## is a content change, not a new sheet — re-entering would re-run the scrim
## fade over an already-dark screen and read as a flicker.
##
## `free()` rather than `queue_free()`, `surface_base::_bind_content`'s reason
## exactly: deferred freeing lets a second state change inside the same frame
## stack new content on top of content that is still parented.
func replace_content(content: Control) -> void:
	if _body == null or not is_instance_valid(_body):
		return
	if _content != null and is_instance_valid(_content):
		_body.remove_child(_content)
		_content.free()
	_content = content
	_body.add_child(content)
	_refit.call_deferred()

## Re-measure after a content swap. `enter()` pinned `offset_top` to the
## minimum size of the content it was built around; new content of a different
## height leaves the card either clipped or padded until this runs. Awaits a
## frame for the same reason `enter()` does — a minimum size is not real until
## the tree has resolved the new children against the theme.
func _refit() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(_card):
		return
	_card.offset_top = -_card.get_minimum_size().y
	_card.pivot_offset = _card.size * 0.5

## A small centered grab-bar. Purely a drag target for swipe-to-dismiss — the
## card's own tap-to-keep-open behavior already covers everything else on it.
func _build_handle() -> Control:
	var wrap := CenterContainer.new()
	wrap.custom_minimum_size = Vector2(0, HANDLE_HEIGHT)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.gui_input.connect(_on_handle_input)
	var bar := ColorRect.new()
	bar.color = Color(1, 1, 1, 0.25)
	bar.custom_minimum_size = Vector2(36, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bar)
	return wrap

## Slide + scale + fade in. Awaits one frame first: sizing the card to its
## content needs a real minimum-size measurement, which needs this node
## actually inside the SceneTree with a resolved theme — true only once the
## caller has parented it, never at the moment `setup()` itself runs.
func enter() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_card.offset_top = -_card.get_minimum_size().y
	# `position` is the rect's actual top-left corner, not an offset relative
	# to wherever the anchors would otherwise rest it — setting it to a bare
	# SLIDE/0 pair (rather than rest_y+SLIDE -> rest_y) pinned the card to the
	# TOP of the screen instead of sliding it up from just below the bottom
	# edge, the exact bug a screenshot alone did not catch (it still looked
	# like a bottom sheet at a glance) but a coordinate read did.
	var rest_y: float = _card.position.y
	_card.position.y = rest_y + SLIDE
	_card.scale = Vector2(0.96, 0.96)
	_card.pivot_offset = _card.size * 0.5
	_scrim.color.a = 0.0
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_scrim, "color:a", SCRIM_ALPHA, ENTRY_TIME)
	tw.parallel().tween_property(_card, "position:y", rest_y, ENTRY_TIME)
	tw.parallel().tween_property(_card, "scale", Vector2.ONE, ENTRY_TIME)

## Slide + fade out, then free. Guarded so a scrim tap racing a
## `state_changed`-triggered close (or any other double call) only ever
## plays the animation once.
func exit() -> void:
	if _exiting:
		return
	_exiting = true
	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_scrim, "color:a", 0.0, EXIT_TIME)
	tw.parallel().tween_property(_card, "position:y", _card.position.y + SLIDE, EXIT_TIME)
	tw.tween_callback(func():
		dismissed.emit()
		queue_free())

func _on_scrim_input(event: InputEvent) -> void:
	# SQ-D3: a blocking sheet still STOPS the tap (the screen underneath must
	# not receive it — that is half of what "blocking" means), it just does not
	# treat it as a dismissal.
	if blocking:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		exit()

## Same press/release measurement `screen_base.gd`'s tap handling uses (the
## same control keeps receiving motion/release after a press, even once the
## finger has moved off it) — inverted to look for a deliberate DOWNWARD
## travel rather than the absence of one.
func _on_handle_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_dragging = true
		_drag_origin_y = mb.position.y
		return
	if not _dragging:
		return
	_dragging = false
	if mb.position.y - _drag_origin_y > DRAG_DISMISS_DISTANCE:
		exit()

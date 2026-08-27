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
var _exiting: bool = false
var _dragging: bool = false
var _drag_origin_y: float = 0.0

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

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.add_child(_build_handle())
	body.add_child(content)
	_card.add_child(body)

	add_child(_card)

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

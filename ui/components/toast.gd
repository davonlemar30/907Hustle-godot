extends CanvasLayer
## Toast — brief, non-blocking feedback.
##
## One instance lives under /root for the whole session (see ScreenManager), so
## it survives scene changes and messages never queue up behind a screen swap.
## Sits at layer 100, above the atmosphere layer's 50, and every node in it is
## mouse_filter IGNORE: a toast must never eat a tap.

const FADE_IN := 0.16
const HOLD := 2.0
const FADE_OUT := 0.35

@onready var _panel: PanelContainer = $Anchor/Panel
@onready var _msg: Label = $Anchor/Panel/Msg

var _tween: Tween

func show_message(text: String) -> void:
	if text.is_empty():
		return
	_msg.text = text
	# A second toast replaces the first rather than stacking or being dropped —
	# a tap should always produce the feedback for that tap.
	if _tween and _tween.is_valid():
		_tween.kill()
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT)

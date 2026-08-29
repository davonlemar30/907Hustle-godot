extends VBoxContainer
## HealthBar — SQ-D5's strip: the one number that moves while you are looking
## at it.
##
## The owner's directive for 0.6.0 asks for a health bar visible during an
## encounter that MOVES as damage lands. Until now there was no bar anywhere in
## the build: `consequence.gd::_build_situation` rendered a text stakes strip
## ("HEALTH 80/100 · HEAT 5/15") and that was the whole of it. A number that
## changes between two renders reads as a different number; a bar that slides
## reads as a hit landing, which is the difference the directive is about.
##
## ## What it is
##
## A `ProgressBar` under a two-part header — the word HEALTH on the left, the
## exact `current/max` on the right. Both are always present: PX-003 §16's
## redundant-labels rule means the bar is never the only carrier, and the exact
## number is what the text strip used to give and must not lose.
##
## ## Why it animates from the LAST SHOWN value rather than from state
##
## Presentation, not state. The sheet is rebuilt from scratch on every
## `notify_changed` (that is `surface_base`'s clear-and-rebuild discipline and
## this component does not get to opt out of it), so a fresh instance has no
## idea what the previous one was showing. `_last_shown` is a STATIC on the
## script: session-lifetime, never persisted, never derived from — the exact
## opposite of a second source of truth, because nothing but this animation
## ever reads it. A reload starts it at "unknown" and the first bar snaps,
## which is correct: there was no hit to watch land.
##
## ## No `class_name`
##
## `flow_sheets.gd`'s rule, and `encounter_sheet.gd`'s: preloaded and `.new()`d
## by its one caller. `ModalSheet`'s `class_name` exists because `screen_base`
## and `ScreenManager` both need it as a TYPE in a signature; nothing needs this
## one as a type.

const CREAM := Color(0.949, 0.941, 0.922)
const MUTED := Color(0.608, 0.608, 0.608)
const GREEN := Color(0.451, 0.722, 0.404)
const AMBER := Color(0.882, 0.651, 0.227)
const RED := Color(0.827, 0.161, 0.125)

## Bands, high to low. The bar's fill takes the tone of the band the CURRENT
## value sits in, so a run at 20 health is red before anything else on screen
## says so. Thresholds are fractions of `health_max` rather than raw numbers so
## a build that ever moves the ceiling does not silently re-tune this.
const BAND_HEALTHY := 0.6
const BAND_HURT := 0.3

const BAR_HEIGHT := 10.0
## Long enough to read as motion, short enough that a player tapping through a
## three-round fight never waits on it. Matched to `ModalSheet.ENTRY_TIME`'s
## neighbourhood rather than picked fresh — one house rhythm, not two.
const DRAIN_TIME := 0.35

## The last value this component rendered, session-wide. See the header.
static var _last_shown: int = -1

var _bar: ProgressBar
var _readout: Label

## Build against live GameState and return self, so a caller can write
## `v.add_child(HEALTH_BAR.new().bind(gs))` in one line the way every other
## builder in `encounter_sheet.gd` reads.
func bind(gs: Node) -> Control:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var current: int = 0
	var maximum: int = 100
	if gs != null:
		current = clampi(int(gs.health), 0, int(gs.health_max))
		maximum = maxi(1, int(gs.health_max))

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var key := _label("HEALTH", "Kicker", 10, MUTED)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(key)
	_readout = _label("%d/%d" % [current, maximum], "Mono", 12, _tone(current, maximum))
	head.add_child(_readout)
	add_child(head)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = float(maximum)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", _track())
	_bar.add_theme_stylebox_override("fill", _fill(_tone(current, maximum)))
	add_child(_bar)

	# A first render, or a reload, has nothing to animate FROM. Snap, and say so
	# by starting the tween's own source at the destination.
	var from: int = current if _last_shown < 0 else clampi(_last_shown, 0, maximum)
	_bar.value = float(from)
	_last_shown = current
	if from != current:
		_animate_to(from, current, maximum)
	return self

## The delta, drawn. The readout counts with the bar rather than jumping ahead
## of it: two widgets showing the same number disagreeing for a third of a
## second is exactly the kind of thing that reads as a bug.
func _animate_to(from: int, to: int, maximum: int) -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(value: float) -> void:
		if not is_instance_valid(_bar):
			return
		_bar.value = value
		var shown: int = int(round(value))
		_readout.text = "%d/%d" % [shown, maximum]
		var tone: Color = _tone(shown, maximum)
		_readout.add_theme_color_override("font_color", tone)
		_bar.add_theme_stylebox_override("fill", _fill(tone)),
		float(from), float(to), DRAIN_TIME)

func _tone(current: int, maximum: int) -> Color:
	var fraction: float = float(current) / float(maxi(1, maximum))
	if fraction >= BAND_HEALTHY:
		return GREEN
	if fraction >= BAND_HURT:
		return AMBER
	return RED

func _track() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.10)
	s.set_corner_radius_all(5)
	return s

func _fill(tone: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = tone
	s.set_corner_radius_all(5)
	return s

func _label(text: String, variation: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(variation)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

## Run-boundary reset, called by `ScreenManager.clear_flow_sheets()` — the one
## place that already knows a run has ended. Without it, the first encounter of
## a NEW run would animate down from the dead run's last health value.
static func forget() -> void:
	_last_shown = -1

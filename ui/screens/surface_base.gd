extends "res://ui/screens/screen_base.gd"
## Shared plumbing for the Hustle surface screens (Stickup, Shark, ...).
##
## Each one is a list of state-shaped rows in a `Body` VBox, so they all need
## the same handful of builders and the same "rebuild from scratch on refresh"
## discipline. Putting them here keeps the surfaces themselves down to the part
## that is actually about the surface.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)
const MUTED := Color(0.608, 0.608, 0.608)
const CREAM := Color(0.949, 0.941, 0.922)

@onready var _gm: Node = get_node("/root/GameManager")
@onready var body: VBoxContainer = $Shell/Scroll/Pad/Content/Body

func _ready() -> void:
	super()
	if _gm and not _gm.action_failed.is_connected(_on_action_failed):
		_gm.action_failed.connect(_on_action_failed)

func _on_action_failed(_action: String, reason: String) -> void:
	nav.show_toast(reason)

## Surfaces override this instead of _bind_content, so the clear-and-rebuild is
## never forgotten.
func _build_body() -> void:
	pass

func _bind_content() -> void:
	# `remove_child` + `free`, not `queue_free`.
	#
	# `queue_free()` is the reflex and it is wrong for a clear-and-rebuild.
	# Freeing is DEFERRED to the end of the frame, so a second refresh inside the
	# same frame rebuilds on top of rows that are still parented: the menu reads
	# double, then quadruple. Measured at 4 -> 8 -> 16 rows across three
	# same-frame refreshes.
	#
	# In ordinary play a frame usually elapses between state changes, which is
	# why this has never been seen on a phone. It is still wrong: `notify_changed`
	# is emitted once per dispatch and nothing in the contract promises a frame
	# between two of them. It is also what makes these screens un-measurable —
	# the parity runner does its whole job inside one `_ready()` and never yields,
	# so every check that refreshes a surface twice was reading stacked rows.
	# `_free_screen` in that runner already documents this exact trap.
	for c in body.get_children():
		body.remove_child(c)
		c.free()
	_build_body()

# --- builders --------------------------------------------------------------

func card() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Card"
	# TOUCH-D3a: PanelContainer is the one Container subtype that defaults to
	# MOUSE_FILTER_STOP (every layout Container defaults to PASS), which is why
	# a drag starting on a card never reached the ScrollContainer above it.
	# PASS here does not make the card tappable -- see tap_connect/make_tappable
	# for that, an entirely separate opt-in.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

## `wrap` is opt-in: a wrapping label inside an HBox with an expanding sibling
## gets squeezed to its narrowest fit, which turns a short value like "$40-80"
## into one character per line. Only prose asks for it.
func label(text: String, variation: String, size: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(variation)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func note(text: String) -> Control:
	var c := card()
	c.add_child(label(text, "Muted", 12, MUTED))
	return c

## Buttons on these screens are full-width and sit inside the ScrollContainer,
## so they must not swallow a scroll drag. `pressed` is deliberately NOT used —
## see screen_base.tap_connect for why a measured tap is required here.
func button(text: String, primary: bool, handler: Callable, min_h: int = 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = &"BtnPrimary" if primary else &"BtnSecondary"
	b.add_theme_font_size_override("font_size", 13)
	tap_connect(b, handler)
	return b

func section(text: String) -> Label:
	return label(text, "Kicker", 10, MUTED)

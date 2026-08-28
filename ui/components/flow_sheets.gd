extends RefCounted
## FlowSheets — content builders for the flow-sheet queue (0.1.2).
##
## A flow sheet is a `ModalSheet` shown from the flow itself rather than from
## a screen's own interaction (`market.gd`'s quantity sheet is the latter).
## `ScreenManager` queues plain-data specs (`{"kind": "discovery", ...}`,
## `{"kind": "intro"}`) and `screen_base.gd`'s drain resolves each one to
## content through the builder here, at SHOW time rather than enqueue time —
## copy that could go stale sitting in a queue never does, because nothing
## but the spec itself sits in the queue.
##
## Static, no `class_name` (the stale-cache gotcha), preloaded like
## `screen_base.gd`'s `LOCK_ICON`. Every builder returns a `VBoxContainer`
## whose dismiss `Button` is named "Dismiss" — the drain's whole contract
## with this file, so it can wire the press without knowing which builder
## ran.

const MUTED := Color(0.608, 0.608, 0.608)
const CREAM := Color(0.949, 0.941, 0.922)

## One surface's unlock, celebrated. `card` is `SurfaceVisibility.card_for()`'s
## shape: `{title, line, icon}`, `icon` possibly "" — not every surface has one
## worth showing, and a card with nothing to illustrate just runs title-first.
static func build_discovery(card: Dictionary) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)

	var icon_path := str(card.get("icon", ""))
	if not icon_path.is_empty():
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(56, 56)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(icon)

	content.add_child(_label(str(card.get("title", "")), "CardTitle", 18, CREAM, true))
	content.add_child(_label(str(card.get("line", "")), "Muted", 14, CREAM, true))
	content.add_child(_spacer(4))
	content.add_child(_dismiss_button("LET'S GO"))
	return content

static func _label(text: String, variation: String, size: int, col: Color,
		should_wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(variation)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if should_wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Named "Dismiss" by contract — see the file header.
static func _dismiss_button(text: String) -> Button:
	var b := Button.new()
	b.name = "Dismiss"
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = &"BtnPrimary"
	b.add_theme_font_size_override("font_size", 15)
	return b

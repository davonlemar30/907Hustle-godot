extends "res://ui/screens/screen_base.gd"
## Hustle — the income hub.
##
## Chrome from the base; Today's Take, the six income surfaces, and the Curtis
## rival-pressure card are bound from GameState in _bind_content(). Auto-refreshes
## on GameState.state_changed via the base. No hardcoded values in the screen.

const SURFACE_ORDER := ["Jobs", "List", "Market", "Boost", "Stick", "Shark"]

# Street Market is the one surface that already exists as a screen. The rest
# are Phase 4 systems, so their rows say so instead of dead-ending.
const SURFACE_ROUTES := {
	"Jobs": "", "List": "", "Market": "res://ui/screens/market.tscn",
	"Boost": "", "Stick": "", "Shark": "",
}

func _ready() -> void:
	super()
	_wire_taps()

func _wire_taps() -> void:
	for i in range(min(SURFACE_ORDER.size(), gs.hustle_surfaces.size())):
		var row: String = SURFACE_ORDER[i]
		var label: String = str(gs.hustle_surfaces[i].get("label", row))
		make_tappable("Shell/Scroll/Pad/Content/Rows/" + row, _on_surface.bind(row, label))

func _on_surface(row: String, label: String) -> void:
	var route: String = SURFACE_ROUTES.get(row, "")
	if route.is_empty():
		nav.show_toast("%s — coming soon." % label)
		return
	nav.go_to(route)

func _bind_content() -> void:
	_bind_take()
	_bind_surfaces()
	_bind_curtis()

func _bind_take() -> void:
	_set_text("Shell/Scroll/Pad/Content/Take/V/Big", "$%s" % _commas(gs.todays_take))
	_set_text("Shell/Scroll/Pad/Content/Take/V/Chips/J/V/Val", "+$%d" % int(gs.income_sources.get("jobs", 0)))
	_set_text("Shell/Scroll/Pad/Content/Take/V/Chips/M/V/Val", "+$%d" % int(gs.income_sources.get("market", 0)))
	_set_text("Shell/Scroll/Pad/Content/Take/V/Chips/S/V/Val", "+$%d" % int(gs.income_sources.get("stick", 0)))

func _bind_surfaces() -> void:
	for i in range(min(SURFACE_ORDER.size(), gs.hustle_surfaces.size())):
		var s: Dictionary = gs.hustle_surfaces[i]
		var base: String = "Shell/Scroll/Pad/Content/Rows/" + SURFACE_ORDER[i] + "/H"
		var col: Color = s.color

		var ico := get_node_or_null(base + "/Ico") as TextureRect
		if ico:
			ico.self_modulate = col

		_set_text(base + "/Mid/Nm", s.label)
		_set_text(base + "/Mid/Desc", s.desc)

		var st := get_node_or_null(base + "/Right/St") as Label
		if st:
			st.text = s.status
			st.add_theme_color_override("font_color", col)

		_set_text(base + "/Right/St2", s.detail)

func _bind_curtis() -> void:
	_set_text("Shell/Scroll/Pad/Content/Rival/V/Head/A", "ATTENTION %d/%d" % [gs.curtis_attention, gs.curtis_attention_max])

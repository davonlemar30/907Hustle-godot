extends "res://ui/screens/screen_base.gd"
## Street screen — the exploration hub.
##
## The shared chrome (top bar + HUD) is filled by screen_base. This adds the
## Street-specific content — district cards, Spenard venues, and the contact
## count — all read from GameState. No canon values are hardcoded in the screen.

const RISK_MAX := 4
const POLICE_MAX := 3
const RIVAL_MAX := 3

func _bind_content() -> void:
	_fill_districts()
	_fill_venues()
	_fill_people()

func _fill_districts() -> void:
	for i in range(3):
		var d: Dictionary = gs.districts[i] if i < gs.districts.size() else {}
		if d.is_empty():
			continue
		var base := "Shell/Scroll/Pad/Content/Districts/Dist%d/V" % i
		var name_label := get_node_or_null(base + "/Top/Name") as Label
		if name_label:
			name_label.text = d.name
			name_label.add_theme_color_override("font_color", d.accent)
		_set_text(base + "/Top/Travel", d.travel)
		_set_text(base + "/Role", d.role)
		_set_text(base + "/Blurb", d.blurb)
		_set_text(base + "/Pips/Risk/P", _pips(d.risk, RISK_MAX))
		_set_text(base + "/Pips/Police/P", _pips(d.police, POLICE_MAX))
		_set_text(base + "/Pips/Rival/P", _pips(d.rival, RIVAL_MAX))

func _fill_venues() -> void:
	for i in range(4):
		var v: Dictionary = gs.spenard_venues[i] if i < gs.spenard_venues.size() else {}
		if v.is_empty():
			continue
		var base := "Shell/Scroll/Pad/Content/Venues/Ven%d/H" % i
		_set_text(base + "/Tag", v.tag)
		_set_text(base + "/Mid/Name", v.name)
		_set_text(base + "/Mid/Desc", v.desc)

func _fill_people() -> void:
	_set_text("Shell/Scroll/Pad/Content/People/H/Status", "%d PERSONAL CONTACTS  ›" % gs.personal_contacts)

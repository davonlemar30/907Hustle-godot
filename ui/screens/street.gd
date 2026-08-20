extends "res://ui/screens/screen_base.gd"
## Street screen — the exploration hub.
##
## The shared chrome (top bar + HUD) is filled by screen_base. This adds the
## Street-specific content — district cards, Spenard venues, and the contact
## count — all read from GameState. No canon values are hardcoded in the screen.

const RISK_MAX := 4
const POLICE_MAX := 3
const RIVAL_MAX := 3

# Lit-dot colours, matching the accents the cards were already drawn with.
const RISK_TINT := Color(0.882, 0.651, 0.227, 1)
const POLICE_TINT := Color(0.373, 0.663, 0.847, 1)
const RIVAL_TINT := Color(0.827, 0.161, 0.125, 1)

@onready var _gm: Node = get_node("/root/GameManager")

func _ready() -> void:
	super()
	_wire_taps()
	if _gm and not _gm.action_failed.is_connected(_on_action_failed):
		_gm.action_failed.connect(_on_action_failed)

## Connected once in _ready, never in _bind_content — that re-runs on every
## state change and would stack duplicate connections.
func _wire_taps() -> void:
	for i in range(3):
		var d: Dictionary = gs.districts[i] if i < gs.districts.size() else {}
		if d.is_empty():
			continue
		make_tappable("Shell/Scroll/Pad/Content/Districts/Dist%d" % i, _on_district.bind(str(d.id)))
	for i in range(4):
		var v: Dictionary = gs.spenard_venues[i] if i < gs.spenard_venues.size() else {}
		if v.is_empty():
			continue
		make_tappable("Shell/Scroll/Pad/Content/Venues/Ven%d" % i, _on_venue.bind(str(v.name)))
	make_tappable("Shell/Scroll/Pad/Content/People", _on_people)

func _on_district(district_id: String) -> void:
	if district_id == gs.current_district_id:
		nav.show_toast("You're already in %s." % gs.current_district().get("name", "this district"))
		return
	var target: Dictionary = gs.district_by_id(district_id)
	if _gm.dispatch("travel", {"district_id": district_id}):
		nav.show_toast("Traveled to %s. -$%d fare." % [target.get("name", "?"), gs.TravelFare])

func _on_venue(venue_name: String) -> void:
	nav.show_toast("%s — coming soon." % venue_name)

## The People row on Street is where crew lives — it is the same idea as the
## contacts list it sits under, and there is no other route to it yet.
func _on_people() -> void:
	nav.go_to(nav.CREW)

## Travel can fail for want of fare; say so rather than swallowing the tap.
func _on_action_failed(_action: String, reason: String) -> void:
	nav.show_toast(reason)

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
		_set_text(base + "/Top/Travel", gs.travel_label_for(str(d.id)))
		_set_text(base + "/Role", d.role)
		_set_text(base + "/Blurb", d.blurb)
		_set_pips(base + "/Pips/Risk/P", d.risk, RISK_MAX, RISK_TINT)
		_set_pips(base + "/Pips/Police/P", d.police, POLICE_MAX, POLICE_TINT)
		_set_pips(base + "/Pips/Rival/P", d.rival, RIVAL_MAX, RIVAL_TINT)

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
	var hired: int = gs.recruited_crew().size()
	if hired > 0:
		_set_text("Shell/Scroll/Pad/Content/People/H/Status", "%d ON THE CREW  ·  POWER %d  ›" % [hired, gs.crew_power])
	else:
		_set_text("Shell/Scroll/Pad/Content/People/H/Status", "%d PERSONAL CONTACTS  ›" % gs.personal_contacts)

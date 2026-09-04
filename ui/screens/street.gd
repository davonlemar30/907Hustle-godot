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
	for i in range(DISTRICT_SLOTS):
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

## Which venues have interiors, keyed by the name the card carries.
##
## Keyed on the display NAME rather than an index because that is what
## `_wire_taps` binds and what `spenard_venues` actually carries — the venue
## rows have no ids. A venue with no row here still toasts, which is the honest
## answer for the two that are not built: The Nile needs a gambling system this
## build does not have, and a Home interior would duplicate the Home nav tab.
## BR-D5: the scene carries four district cards (Dist0..Dist3).
const DISTRICT_SLOTS := 4

const VENUE_ROUTES := {
	"Spenard Gym": "res://ui/screens/spenard_gym.tscn",
	"Night Owl": "res://ui/screens/night_owl.tscn",
}

## Walking in. The `enter_venue` dispatch runs BEFORE the navigation, because
## first entry is a mutation — it is what puts the Night Owl's shift on the
## board — and a screen never mutates. Navigating first would render the
## interior from the state of not having entered it.
func _on_venue(venue_name: String) -> void:
	var route: Variant = VENUE_ROUTES.get(venue_name)
	if not (route is String):
		nav.show_toast("%s — coming soon." % venue_name)
		return
	_gm.dispatch("enter_venue", {"venue_id": _venue_id_for(venue_name)})
	nav.go_to(str(route))

## The venue rows carry no id, so one is derived from the name the same way a
## route is looked up by it. Kept next to VENUE_ROUTES so the two cannot drift.
func _venue_id_for(venue_name: String) -> String:
	return venue_name.to_lower().replace(" ", "_")

## The People row on Street is where crew lives — it is the same idea as the
## contacts list it sits under, and there is no other route to it yet.
func _on_people() -> void:
	nav.go_to(nav.CREW)

## Travel can fail for want of fare; say so rather than swallowing the tap.
func _on_action_failed(_action: String, reason: String) -> void:
	nav.show_toast(reason)

## Street's gates, keyed to the district each card is for.
##
## Spenard has no entry: home turf is never gated, and giving it a gate that
## always passes would be a row in the registry that can only ever be wrong.
const ACCESS := preload("res://autoload/surface_visibility.gd")
const DISTRICT_SURFACES := {
	"downtown": ACCESS.STREET_DOWNTOWN,
	"airport_industrial": ACCESS.STREET_SHIP_CREEK,
	"mountain_view": ACCESS.STREET_MOUNTAIN_VIEW,
}

func _bind_content() -> void:
	_fill_districts()
	_fill_venues()
	_fill_people()
	_bind_gates()

## Run AFTER the fills, not before. A locked card still shows the district's
## real name, risk and blurb underneath the dimming — the player is meant to see
## what they have not reached yet, which is the whole difference between LOCKED
## and HIDDEN — so the card is filled first and then dimmed.
func _bind_gates() -> void:
	for i in range(DISTRICT_SLOTS):
		var district: Dictionary = gs.districts[i] if i < gs.districts.size() else {}
		var surface_id: Variant = DISTRICT_SURFACES.get(str(district.get("id", "")))
		if surface_id == null:
			continue
		gate_surface(str(surface_id), "Shell/Scroll/Pad/Content/Districts/Dist%d" % i)
	# The People row is this screen's only door to the Crew screen, so it wears
	# the same gate the route does.
	gate_surface(ACCESS.MENU_CREW, "Shell/Scroll/Pad/Content/People")

func _fill_districts() -> void:
	for i in range(DISTRICT_SLOTS):
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

extends Control
## Street screen — the first consumer of gs.
##
## The screen's layout is static, but every game value (top bar, HUD, the three
## district cards, the Spenard venues, the contact count) is pulled from the
## GameState autoload in _ready(). No canon numbers are hardcoded in this screen.
## This is the pattern the other screens will be retrofitted onto.

const RISK_MAX := 4
const POLICE_MAX := 3
const RIVAL_MAX := 3

# Resolved at runtime (via /root) rather than the compile-time autoload global,
# so the script compiles even before the editor has reloaded the autoload list.
@onready var gs: Node = get_node("/root/GameState")

func _ready() -> void:
	_fill_topbar()
	_fill_hud()
	_fill_districts()
	_fill_venues()
	_fill_people()

func _fill_topbar() -> void:
	_set_text("Shell/TopBar/HBox/DayBox/V/Day", "DAY %d" % gs.day)
	_set_text("Shell/TopBar/HBox/DayBox/V/Part", gs.part)
	_set_text("Shell/TopBar/HBox/Right/LocBox/V/L1", gs.current_district().get("name", "SPENARD"))
	_set_text("Shell/TopBar/HBox/Right/LocBox/V/L2", gs.city)
	_set_text("Shell/TopBar/HBox/Right/CashBox/V/C2", "$%s" % _commas(gs.cash))

func _fill_hud() -> void:
	_set_text("Shell/Hud/HudRow/C0/V", "%d/%d" % [gs.heat, gs.heat_max])
	_set_text("Shell/Hud/HudRow/C1/V", "%d/%d" % [gs.health, gs.health_max])
	_set_text("Shell/Hud/HudRow/C2/V", "$%s" % _commas(gs.debt))
	_set_text("Shell/Hud/HudRow/C3/V", "%d/%d" % [gs.cargo, gs.cargo_max])
	_set_text("Shell/Hud/HudRow/C4/V", str(gs.respect))
	_set_text("Shell/Hud/HudRow/C5/V", str(gs.crew_power))

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

# --- helpers ---------------------------------------------------------------

func _set_text(path: String, text: String) -> void:
	var node := get_node_or_null(path) as Label
	if node:
		node.text = text

func _pips(filled: int, total: int) -> String:
	filled = clampi(filled, 0, total)
	return "●".repeat(filled) + "○".repeat(total - filled)

func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

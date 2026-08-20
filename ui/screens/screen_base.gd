extends Control
## Base for every top-level screen.
##
## Fills the shared chrome — the top bar (day/part/location/cash) and the 6-stat
## HUD — from the GameState autoload in _ready(), so no screen hardcodes cash, day,
## or stat strings. The values baked into each .tscn are just editor-time previews;
## at runtime GameState is the source of truth.
##
## Screens with extra content (e.g. Street) extend this, override _ready(), and
## call super() before doing their own fills. Also exposes the shared helpers
## (_set_text / _pips / _commas).

@onready var gs: Node = get_node("/root/GameState")

func _ready() -> void:
	_fill_chrome()

func _fill_chrome() -> void:
	_set_text("Shell/TopBar/HBox/DayBox/V/Day", "DAY %d" % gs.day)
	_set_text("Shell/TopBar/HBox/DayBox/V/Part", gs.part)
	_set_text("Shell/TopBar/HBox/Right/LocBox/V/L1", gs.current_district().get("name", "SPENARD"))
	_set_text("Shell/TopBar/HBox/Right/LocBox/V/L2", gs.city)
	_set_text("Shell/TopBar/HBox/Right/CashBox/V/C2", "$%s" % _commas(gs.cash))
	_set_text("Shell/Hud/HudRow/C0/V", "%d/%d" % [gs.heat, gs.heat_max])
	_set_text("Shell/Hud/HudRow/C1/V", "%d/%d" % [gs.health, gs.health_max])
	_set_text("Shell/Hud/HudRow/C2/V", "$%s" % _commas(gs.debt))
	_set_text("Shell/Hud/HudRow/C3/V", "%d/%d" % [gs.cargo, gs.cargo_max])
	_set_text("Shell/Hud/HudRow/C4/V", str(gs.respect))
	_set_text("Shell/Hud/HudRow/C5/V", str(gs.crew_power))

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

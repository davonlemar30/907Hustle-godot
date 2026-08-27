extends "res://ui/screens/screen_base.gd"
## Market — the Street Market.
##
## Chrome + the 8 product rows are bound from GameState (via _bind_content).
## BUY/SELL open a quantity sheet (PR 3) rather than dispatching straight off
## the tap; CONFIRM there dispatches through GameManager so a transaction
## mutates real state, and the reactive refresh re-renders the screen. Failed
## actions flash the cash label — and the sheet's total, if one is open.

const MUTED := Color(0.608, 0.608, 0.608)
const CREAM := Color(0.949, 0.941, 0.922)
const AMBER := Color(0.882, 0.651, 0.227)
const RED := Color(0.827, 0.161, 0.125)

@onready var _gm: Node = get_node("/root/GameManager")

# --- quantity sheet state (PR 3) --------------------------------------------
# UI-only, so it lives here rather than in GameState — see modal_sheet.gd's
# header for why the sheet itself carries none of it either.
var _sheet: ModalSheet = null
var _sheet_qty: int = 1
var _sheet_max_qty: int = 1
var _sheet_unit_price: int = 0
var _sheet_qty_label: Label = null
var _sheet_total_label: Label = null
var _sheet_minus_btn: Button = null
var _sheet_plus_btn: Button = null

func _ready() -> void:
	super()
	_connect_buttons()
	if _gm and not _gm.action_failed.is_connected(_on_action_failed):
		_gm.action_failed.connect(_on_action_failed)

func _bind_content() -> void:
	_fill_tabs()
	_fill_context()
	_fill_products()

## The district context strip: which part of town this board is, and what the
## neighbourhood makes of the trade.
##
## This was previously the one place on the screen that never bound at all — the
## blurb and all three pip meters were editor previews baked into the .tscn, so
## they read SPENARD's numbers wherever the player actually was. Non-negotiable
## rule 4 ("no hardcoded game values in .tscn files") had a hole in it here.
##
## The first meter is now **Local Attention** rather than the district's static
## risk score: FS-003.11 asks the Market surface to read District Pressure bands
## instead of the old static values, and Pressure is the one of the three that
## the player's own behaviour moves. Police and Rival stay what they always were
## — facts about the district, not about the player — and are bound live so they
## follow the selected board.
const ATTENTION_PIPS := 4
const POLICE_MAX := 3
const RIVAL_MAX := 3
const POLICE_TINT := Color(0.475, 0.733, 0.757, 1)
const RIVAL_TINT := Color(0.827, 0.161, 0.125, 1)

## The district strip above the board.
##
## These three labels used to be baked into the .tscn and never bound, which is
## the same rule-4 hole `_fill_context` closed one row below: the strip always
## read SPENARD in accent with the other two greyed, wherever the player was
## actually standing. Now the names come from `gs.districts` in districts order
## and the accent follows `current_district_id`, so renaming a district in one
## place renames it everywhere the player can see it.
const TAB_ACTIVE := Color(1, 0.29, 0.239, 1)
const TAB_IDLE := Color(0.522, 0.522, 0.522, 1)
const TAB_RULE_OFF := Color(0, 0, 0, 0)

func _fill_tabs() -> void:
	var tabs := get_node_or_null("Shell/Scroll/Pad/Content/Districts/V/Tabs")
	if tabs == null:
		return
	for i in range(mini(tabs.get_child_count(), gs.districts.size())):
		var district: Dictionary = gs.districts[i]
		var here: bool = str(district.get("id", "")) == gs.current_district_id
		var tab: Node = tabs.get_child(i)
		var name_label := tab.get_node_or_null("L") as Label
		if name_label:
			name_label.text = str(district.get("name", ""))
			name_label.add_theme_color_override("font_color",
				TAB_ACTIVE if here else TAB_IDLE)
		var rule := tab.get_node_or_null("Ind") as ColorRect
		if rule:
			rule.color = TAB_ACTIVE if here else TAB_RULE_OFF

func _fill_context() -> void:
	var district: Dictionary = gs.current_district()
	var base := "Shell/Scroll/Pad/Content/Districts/V/Ctx"
	_set_text(base + "/Blurb", str(district.get("blurb", "")))

	# TI-003 §19: qualitative only. The pips carry the BAND's difficulty steps
	# (QUIET 0 · KNOWN 1 · WATCHED 2 · HOT 3), never the raw score behind them —
	# four dots cannot leak a 0-to-9 number, which is the point of using them.
	var band: String = attention_band("market")
	var manager: Node = get_node_or_null("/root/GameManager")
	var steps: int = 0
	if manager != null:
		var engine: Object = manager.system("consequence")
		if engine != null:
			steps = preload("res://data/consequence_rules.gd").new().pressure_steps(
				engine.pressure_score(gs.current_district_id, "market"))
	_set_text(base + "/Risk/N", band)
	_set_pips(base + "/Risk/P", steps, ATTENTION_PIPS, attention_tone(band))
	_set_pips(base + "/Police/P", int(district.get("police", 0)), POLICE_MAX, POLICE_TINT)
	_set_pips(base + "/Rival/P", int(district.get("rival", 0)), RIVAL_MAX, RIVAL_TINT)

## What this product's row says about where to take it.
##
## Three states, and which one you get is the phone bill's business:
##
##   NO SERVICE   you know what this corner pays and nothing else. Word about
##                another part of town reaches you by phone or not at all, and
##                a dead line is a dead line. This is the first thing in the
##                build that the $75 actually buys.
##   A ROUTE      somewhere you know about pays more than it costs here.
##   NO ROUTE     the line works and nobody is paying over the odds today.
##
## Locked product rows keep their authored line: `meth` has no market yet and
## "NEEDS SHIP CREEK TURF" is a fact about the world rather than a price claim.
func _live_hint(product_id: String, product: Dictionary) -> Dictionary:
	var muted := Color(0.608, 0.608, 0.608)
	if bool(product.get("locked", false)):
		return {"text": str(product.get("hint", "")), "color": product.get("hint_color", muted),
			"arrow": false}
	if not bool(gs.phone_active):
		return {"text": "NO WORD — LINE IS DEAD", "color": muted, "arrow": false}
	var economy: Object = _gm.system("economy") if _gm else null
	var route: Dictionary = economy.best_route(product_id) if economy != null else {}
	if route.is_empty():
		# Two different silences, and telling them apart is the point of the
		# line. Before a first corner is held the player knows exactly one
		# district, so there is nowhere for word to come FROM — reporting that
		# as "nobody is paying over the odds" reads as a market conclusion when
		# it is a map problem, and it fired on all eight rows at once.
		if (gs.districts_unlocked as Array).size() <= 1:
			return {"text": "NO OTHER BOARD YOU KNOW OF", "color": muted, "arrow": false}
		return {"text": "NOBODY PAYING OVER THE ODDS", "color": muted, "arrow": false}
	var green := Color(0.451, 0.722, 0.404)
	return {
		"text": "SELL %s  +$%d" % [str(route["name"]), int(route["edge"])],
		"color": green,
		"arrow": str(route.get("trend", "flat")) == "up",
	}

func _connect_buttons() -> void:
	for i in range(gs.products.size()):
		var pid: String = gs.products[i].id
		var base := "Shell/Scroll/Pad/Content/Rows/R%d/H/Right/Btns" % i
		var buy := get_node_or_null(base + "/Buy") as Button
		if buy:
			tap_connect(buy, _on_buy.bind(pid))
		var sell := get_node_or_null(base + "/Sell") as Button
		if sell:
			tap_connect(sell, _on_sell.bind(pid))

func _on_buy(pid: String) -> void:
	_show_quantity_sheet(pid, "buy")

func _on_sell(pid: String) -> void:
	_show_quantity_sheet(pid, "sell")

func _on_action_failed(_action: String, _reason: String) -> void:
	var cash := get_node_or_null("Shell/TopBar/HBox/Right/CashBox/V/C2") as Label
	if not cash:
		return
	cash.add_theme_color_override("font_color", Color(1, 0.29, 0.239))
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(func(): cash.add_theme_color_override("font_color", Color(0.451, 0.722, 0.404)))

# --- quantity sheet (PR 3) ---------------------------------------------------
#
# economy.gd::_buy()/_sell() already validate everything (cash, cargo, supply,
# locked status) — this is UI convenience only, mirroring that same math so
# the stepper's cap matches what a CONFIRM will actually be allowed to do.
# The dispatch stays the authority; if state changed out from under a stale
# cap between opening the sheet and confirming, the dispatch refuses and the
# sheet flashes red rather than lying about what happened.

## Why `pid` cannot be bought/sold right now, or "" when it can. Same check
## order as economy.gd's own guards, so the reason a player sees here is never
## one economy.gd would not also give.
func _buy_blocker(prod: Dictionary, pid: String) -> String:
	if prod.is_empty():
		return "Unknown product."
	if bool(prod.get("locked", false)):
		return "%s is locked." % str(prod.get("name", ""))
	if _available(pid) <= 0:
		return "Nothing available to buy here."
	if gs.cash < int(prod.get("price", 0)):
		return "Not enough cash."
	if gs.cargo_used() >= gs.cargo_max:
		return "Cargo full."
	return ""

func _sell_blocker(prod: Dictionary, pid: String) -> String:
	if prod.is_empty():
		return "Unknown product."
	if int(gs.inventory.get(pid, 0)) <= 0:
		return "Nothing to sell."
	return ""

func _available(pid: String) -> int:
	var market: Dictionary = gs.markets.get(gs.current_district_id, {})
	if market.is_empty():
		return 0
	return int((market.get("availability", {}) as Dictionary).get(pid, 0))

func _affordable_units(unit_price: int) -> int:
	if unit_price <= 0:
		return 0
	return int(gs.cash / unit_price)

func _unit_price(pid: String, direction: String) -> int:
	if direction == "sell":
		var economy: Object = _gm.system("economy") if _gm else null
		return int(economy.sell_unit_price(gs.current_district_id, pid)) if economy != null else 0
	return int(gs.product_by_id(pid).get("price", 0))

func _show_quantity_sheet(pid: String, direction: String) -> void:
	if _sheet != null:
		return  # One sheet at a time.
	var prod: Dictionary = gs.product_by_id(pid)
	var blocker: String = _buy_blocker(prod, pid) if direction == "buy" else _sell_blocker(prod, pid)
	if not blocker.is_empty():
		nav.show_toast(blocker)
		return

	var unit_price: int = _unit_price(pid, direction)
	# The blocker check above already guarantees this is >= 1: buy's blocker
	# covers supply/cash/cargo (the same three terms this mins together), and
	# sell's covers inventory (which this reads directly for sell).
	var max_qty: int = _available_max(pid, direction, prod, unit_price)

	_sheet_qty = 1
	_sheet_max_qty = max_qty
	_sheet_unit_price = unit_price

	var content := _build_sheet_content(prod, pid, direction, unit_price, max_qty)

	var sheet := ModalSheet.new()
	sheet.setup(content)
	var atmo := get_node_or_null("Atmosphere")
	add_child(sheet)
	if atmo != null:
		move_child(sheet, atmo.get_index())
	sheet.enter()

	_sheet = sheet
	gs.state_changed.connect(sheet.exit)
	sheet.dismissed.connect(_on_sheet_dismissed)

## The real cap the stepper enforces: sell is just what's held; buy is the
## tightest of supply, what cash affords, and remaining cargo room.
func _available_max(pid: String, direction: String, prod: Dictionary, unit_price: int) -> int:
	if direction == "sell":
		return int(gs.inventory.get(pid, 0))
	var cargo_room: int = maxi(0, gs.cargo_max - gs.cargo_used())
	return mini(_available(pid), mini(_affordable_units(unit_price), cargo_room))

func _build_sheet_content(prod: Dictionary, pid: String, direction: String,
		unit_price: int, max_qty: int) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var col: Color = prod.get("color", CREAM)

	content.add_child(_sheet_label(str(prod.get("name", "")), "CardTitle", 16, col))
	content.add_child(_sheet_label(direction.to_upper(), "Kicker", 10, AMBER))
	content.add_child(_sheet_label("$%s each" % _commas(unit_price), "Muted", 12, MUTED))
	content.add_child(_sheet_spacer(2))

	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", 12)
	content.add_child(qty_row)

	_sheet_minus_btn = _step_button("-")
	qty_row.add_child(_sheet_minus_btn)

	_sheet_qty_label = _sheet_label("1", "MonoBig", 20, CREAM)
	_sheet_qty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_row.add_child(_sheet_qty_label)

	_sheet_plus_btn = _step_button("+")
	qty_row.add_child(_sheet_plus_btn)

	_sheet_minus_btn.pressed.connect(_on_qty_step.bind(-1))
	_sheet_plus_btn.pressed.connect(_on_qty_step.bind(1))

	var limit_text := "Available: %d" % max_qty if direction == "buy" else "Holding: %d" % max_qty
	content.add_child(_sheet_label(limit_text, "Muted", 11, MUTED))

	_sheet_total_label = _sheet_label("$%s" % _commas(unit_price), "MonoBig", 22, CREAM)
	content.add_child(_sheet_total_label)

	if direction == "buy":
		var afford: int = _affordable_units(unit_price)
		content.add_child(_sheet_label("You can afford %d" % afford, "Muted", 11, MUTED))

	var confirm := Button.new()
	confirm.text = "CONFIRM"
	confirm.custom_minimum_size = Vector2(0, 56)
	confirm.focus_mode = Control.FOCUS_NONE
	confirm.theme_type_variation = &"BtnPrimary"
	confirm.add_theme_font_size_override("font_size", 15)
	confirm.pressed.connect(_on_confirm.bind(pid, direction))
	content.add_child(confirm)

	_update_sheet_totals()
	return content

func _step_button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(48, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = &"BtnSecondary"
	return b

func _on_qty_step(delta: int) -> void:
	_sheet_qty = clampi(_sheet_qty + delta, 1, _sheet_max_qty)
	_update_sheet_totals()

func _update_sheet_totals() -> void:
	if _sheet_qty_label:
		_sheet_qty_label.text = str(_sheet_qty)
	if _sheet_total_label:
		_sheet_total_label.text = "$%s" % _commas(_sheet_unit_price * _sheet_qty)
	if _sheet_minus_btn:
		_sheet_minus_btn.disabled = _sheet_qty <= 1
	if _sheet_plus_btn:
		_sheet_plus_btn.disabled = _sheet_qty >= _sheet_max_qty

func _on_confirm(pid: String, direction: String) -> void:
	var action := "market_buy" if direction == "buy" else "market_sell"
	# A successful dispatch fires state_changed synchronously, which the
	# listener connected in _show_quantity_sheet already turns into
	# sheet.exit() — so success needs no exit() call here. A failure fires
	# action_failed instead (never state_changed), so the sheet simply never
	# hears anything and stays open by default; only the flash is this
	# handler's job.
	var ok: bool = _gm.dispatch(action, {"product_id": pid, "quantity": _sheet_qty})
	if not ok and _sheet_total_label:
		_flash_red(_sheet_total_label)

func _on_sheet_dismissed() -> void:
	if _sheet != null and gs.state_changed.is_connected(_sheet.exit):
		gs.state_changed.disconnect(_sheet.exit)
	_sheet = null
	_sheet_qty_label = null
	_sheet_total_label = null
	_sheet_minus_btn = null
	_sheet_plus_btn = null

func _flash_red(label: Label) -> void:
	label.add_theme_color_override("font_color", RED)
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(func(): label.remove_theme_color_override("font_color"))

func _sheet_label(text: String, variation: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(variation)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _sheet_spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _fill_products() -> void:
	for i in range(gs.products.size()):
		var p: Dictionary = gs.products[i]
		var base := "Shell/Scroll/Pad/Content/Rows/R%d" % i
		var col: Color = p.color

		var ico := get_node_or_null(base + "/H/Ico") as TextureRect
		if ico:
			ico.self_modulate = col

		var nm := get_node_or_null(base + "/H/Mid/Top/Nm") as Label
		if nm:
			nm.text = p.name
			nm.add_theme_color_override("font_color", col)

		_set_text(base + "/H/Mid/Top/Role", p.role)

		# The hint is an icon + a label. The trend arrow used to be a U+25B2 /
		# U+2197 baked into the string, which no theme font carries — it only
		# ever drew because the editor borrows a macOS system font, and the web
		# export has none to borrow. It is a TextureRect now.
		#
		# The TEXT is live as of v0.2.0. It used to be `p.hint`, an authored
		# string — "SELL SHIP CREEK  +$11" — baked into the product table and
		# true only on the day somebody wrote it. Prices walk every night, so
		# that line was a claim about a route the game had usually stopped
		# honouring. It reads the real board now.
		var hint: Dictionary = _live_hint(str(p.id), p)
		var t := get_node_or_null(base + "/H/Mid/Hint/T") as Label
		if t:
			t.text = str(hint["text"])
			t.add_theme_color_override("font_color", hint["color"])
		var trend := get_node_or_null(base + "/H/Mid/Hint/Ico") as TextureRect
		if trend:
			trend.visible = bool(hint["arrow"])
			trend.self_modulate = hint["color"]

		var pr := get_node_or_null(base + "/H/Right/P") as Label
		if pr:
			pr.text = "$%d" % p.price
			pr.add_theme_color_override("font_color", col)

		# What a sale here actually pays, when the corner is holding something
		# back. Shown only when it differs from the board price: a QUIET
		# district pays the board exactly, and a second identical number would
		# be noise on every row of a screen that is already dense.
		#
		# Read from `economy.sell_unit_price()` — the same function the sell
		# action credits from. A screen that computed its own would be a second
		# implementation of the price, and the day it drifted would be the day
		# the player was shown a number the game does not honour.
		var sell_label := get_node_or_null(base + "/H/Right/Sell") as Label
		if sell_label:
			var economy: Object = _gm.system("economy") if _gm else null
			var pays: int = int(economy.sell_unit_price(gs.current_district_id, str(p.id))) \
				if economy != null else int(p.price)
			sell_label.visible = pays < int(p.price)
			sell_label.text = "SELL $%d" % pays

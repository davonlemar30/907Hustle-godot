extends "res://ui/screens/screen_base.gd"
## Market — the Street Market.
##
## Chrome + the 8 product rows are bound from GameState (via _bind_content).
## BUY/SELL dispatch through GameManager so a transaction mutates real state; the
## reactive refresh then re-renders the screen. Failed actions flash the cash label.

@onready var _gm: Node = get_node("/root/GameManager")

func _ready() -> void:
	super()
	_connect_buttons()
	if _gm and not _gm.action_failed.is_connected(_on_action_failed):
		_gm.action_failed.connect(_on_action_failed)

func _bind_content() -> void:
	_fill_products()

func _connect_buttons() -> void:
	for i in range(gs.products.size()):
		var pid: String = gs.products[i].id
		var base := "Shell/Scroll/Pad/Content/Rows/R%d/H/Right/Btns" % i
		var buy := get_node_or_null(base + "/Buy") as Button
		if buy:
			buy.pressed.connect(_on_buy.bind(pid))
		var sell := get_node_or_null(base + "/Sell") as Button
		if sell:
			sell.pressed.connect(_on_sell.bind(pid))

func _on_buy(pid: String) -> void:
	_gm.dispatch("market_buy", {"product_id": pid, "quantity": 1})

func _on_sell(pid: String) -> void:
	_gm.dispatch("market_sell", {"product_id": pid, "quantity": 1})

func _on_action_failed(_action: String, _reason: String) -> void:
	var cash := get_node_or_null("Shell/TopBar/HBox/Right/CashBox/V/C2") as Label
	if not cash:
		return
	cash.add_theme_color_override("font_color", Color(1, 0.29, 0.239))
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(func(): cash.add_theme_color_override("font_color", Color(0.451, 0.722, 0.404)))

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
		var t := get_node_or_null(base + "/H/Mid/Hint/T") as Label
		if t:
			t.text = p.hint
			t.add_theme_color_override("font_color", p.hint_color)
		var trend := get_node_or_null(base + "/H/Mid/Hint/Ico") as TextureRect
		if trend:
			trend.visible = p.get("trend", "flat") == "up"
			trend.self_modulate = p.hint_color

		var pr := get_node_or_null(base + "/H/Right/P") as Label
		if pr:
			pr.text = "$%d" % p.price
			pr.add_theme_color_override("font_color", col)

extends "res://ui/screens/screen_base.gd"
## Market — the Street Market.
##
## Shared chrome comes from screen_base; the 8 product rows are filled from
## GameState.products (icon tint, name + color, role/owned, route hint, price).
## Buy/Sell and the locked-row treatment stay as authored — only data binds here.

func _bind_content() -> void:
	_fill_products()

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

		# Most rows carry a single Hint Label; the locked row wraps it as Hint/T.
		var hint_node := get_node_or_null(base + "/H/Mid/Hint")
		if hint_node is Label:
			hint_node.text = p.hint
			hint_node.add_theme_color_override("font_color", p.hint_color)
		else:
			var t := get_node_or_null(base + "/H/Mid/Hint/T") as Label
			if t:
				t.text = p.hint
				t.add_theme_color_override("font_color", p.hint_color)

		var pr := get_node_or_null(base + "/H/Right/P") as Label
		if pr:
			pr.text = "$%d" % p.price
			pr.add_theme_color_override("font_color", col)

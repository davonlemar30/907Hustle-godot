extends "res://ui/screens/surface_base.gd"
## 907List — the flip board.
##
## The tier decides what the board is willing to tell you, so the screen shows
## exactly the fields canon's tier allows and nothing more. At Scrapper that is
## title and price only, which is the whole reason a rough item is dangerous:
## four of the eighteen listings sell for less than they cost, and until Flipper
## there is no way to see which.

func _build_body() -> void:
	var sys: Object = _gm.system("list")
	if sys == null:
		return
	var tier: Dictionary = gs.market_tier()

	body.add_child(_status_card(sys, tier))

	if not gs.list_holdings.is_empty():
		body.add_child(section("HOLDING"))
		for i in range(gs.list_holdings.size()):
			body.add_child(_holding_row(sys, i, tier))

	body.add_child(section("ON THE BOARD TODAY"))
	for item in sys.todays_listings():
		body.add_child(_listing_row(sys, item, tier))

func _status_card(sys: Object, tier: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)
	v.add_child(label("%s  ·  %d/%d CARRIED" % [str(tier["name"]), gs.list_holdings.size(), int(tier["capacity"])], "CardTitle", 13, CREAM))
	v.add_child(label(str(tier["blurb"]), "Muted", 11, MUTED, true))
	var next_at: int = gs.FLIPPER_FLIP_REQUIREMENT if gs.list_tier == 1 else gs.BROKER_FLIP_REQUIREMENT
	if gs.list_tier < 3:
		v.add_child(label("%d clean flips  ·  %d more to move up" % [gs.list_flips, maxi(0, next_at - gs.list_flips)], "Muted", 11, AMBER))
	return c

func _listing_row(sys: Object, item: Dictionary, tier: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(item["name"]), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label("$%d" % int(item["buy"]), "Mono", 13, AMBER))

	# Only what this tier is allowed to show.
	var meta := str(item["category"]).to_upper()
	if bool(tier["shows_condition"]):
		meta += "  ·  " + str(item["condition"]).to_upper()
	v.add_child(label(meta, "Muted", 11, _condition_colour(item, tier)))

	var blocked: String = sys.buy_blocker(str(item["id"]))
	var b := button("BUY $%d" % int(item["buy"]) if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_buy.bind(str(item["id"])), 46)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

## A Scrapper gets no colour cue either — the tier hides the read, not just the
## word.
func _condition_colour(item: Dictionary, tier: Dictionary) -> Color:
	if not bool(tier["shows_condition"]):
		return MUTED
	match str(item["condition"]):
		"mint": return GREEN
		"good": return GREEN
		"fair": return AMBER
		"rough": return RED
	return MUTED

func _holding_row(sys: Object, index: int, tier: Dictionary) -> Control:
	var held: Dictionary = gs.list_holdings[index]
	var item: Dictionary = gs.listing_item_by_id(str(held["item_id"]))
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(item["name"]), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label("paid $%d" % int(item["buy"]), "Mono", 12, MUTED))

	# What it will fetch stays hidden until it is sold. Showing it would remove
	# the only decision on this screen.
	var blocked: String = sys.sell_blocker(index)
	var b := button("SELL" if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_sell.bind(index), 46)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

func _on_buy(item_id: String) -> void:
	if _gm.dispatch("list_buy", {"item_id": item_id}):
		nav.show_toast("Picked it up. %d/%d carried." % [gs.list_holdings.size(), int(gs.market_tier()["capacity"])])

func _on_sell(index: int) -> void:
	var before: int = gs.cash
	if _gm.dispatch("list_sell", {"index": index}):
		var delta: int = gs.cash - before
		nav.show_toast("Sold for $%d." % delta)

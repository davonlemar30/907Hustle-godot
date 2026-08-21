extends "res://ui/screens/surface_base.gd"
## 907List — the flip board.
##
## The tier decides what the board is willing to tell you, so the screen shows
## exactly the fields canon's tier allows and nothing more. At Scrapper that is
## title and price only, which is the whole reason a rough item is dangerous:
## four of the eighteen listings sell for less than they cost, and until Flipper
## there is no way to see which.
##
## ## Delegation (FS-001.8)
##
## Everything about Pherris on this screen is READ from `operation_summary()`
## and the adapter's own `preview()`. The screen decides nothing: not what she
## would buy, not what it would cost, not why she cannot go. Ask, then render.
##
## The one thing that needed care is the shared board. Consumption filters the
## POOL before generation — a taken listing is genuinely not on today's board,
## and the board reshuffles around it. Rendering only what remains would make
## items appear to evaporate, so what was taken today is shown separately,
## attributed, and unbuyable. The player sees a board that got smaller because
## somebody took something, which is what actually happened.

const OPERATION_ID := "907list_run_board"

func _build_body() -> void:
	var sys: Object = _gm.system("list")
	if sys == null:
		return
	var tier: Dictionary = gs.market_tier()

	body.add_child(_status_card(sys, tier))

	var ops: Object = _gm.system("crew_operations")
	if ops != null:
		var summary: Dictionary = ops.operation_summary(OPERATION_ID)
		# An operation nobody has thought of yet is not shown at all. The reveal
		# is the log line when it is discovered — advertising it beforehand
		# would spend that moment for nothing.
		if bool(summary["discovered"]):
			body.add_child(section("RUN THE BOARD"))
			body.add_child(_operation_card(ops, summary))

	if not gs.list_holdings.is_empty():
		body.add_child(section("HOLDING"))
		for i in range(gs.list_holdings.size()):
			body.add_child(_holding_row(sys, i, tier))

	body.add_child(section("ON THE BOARD TODAY"))
	var listed: Array = sys.todays_listings()
	for item in listed:
		body.add_child(_listing_row(sys, item, tier))
	if listed.is_empty():
		body.add_child(note("Nothing worth the trip today."))

	# What is gone, and who took it. Rendered from the consumption record rather
	# than the board, because the board no longer knows these existed.
	var gone: Array = _taken_today(sys, ops)
	if not gone.is_empty():
		body.add_child(section("ALREADY GONE TODAY"))
		for row in gone:
			body.add_child(_gone_row(row))

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

## Pherris, and what asking her would cost. Every number here comes from the
## adapter's `preview()`, which is the same function `select()` executes — so
## what is shown is what happens, not a second opinion about it.
func _operation_card(ops: Object, summary: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label("Pherris works the board", "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label("UP TO %d" % int(summary["requested_cap"]), "Mono", 12, MUTED))

	if bool(summary["assigned_today"]):
		v.add_child(_assigned_body(summary))
		return c

	var blocker: Variant = summary["blocker"]
	if blocker != null:
		# Canonical blocker data — the copy comes from the operations layer, so
		# the screen cannot invent a reason the system does not hold.
		v.add_child(label(_blocker_text(ops, blocker), "Muted", 11, AMBER, true))
		return c

	# What she brought back the LAST time she went. Once the day rolls over the
	# assignment is yesterday's, so the panel goes back to offering her — and
	# without this the night's result would exist only as two lines in the
	# activity feed, already scrolling away. The money arrived while the player
	# was asleep; they should be able to see what it was.
	var closed := _last_night_line(ops)
	if not closed.is_empty():
		v.add_child(label(closed, "Mono", 11, MUTED))

	v.add_child(label("She takes the day and works it alone. Her picks settle tonight; you keep the money and none of the practice.", "Muted", 11, MUTED, true))
	v.add_child(_preview_body(ops, summary))
	return c

## The last settled run, if there was one and it is not today's.
func _last_night_line(ops: Object) -> String:
	var last: Dictionary = ops.last_assignment("pherris")
	if last.is_empty() or int(last.get("day", -1)) >= gs.day:
		return ""
	if not bool(last.get("settled", false)):
		return ""
	var result: Variant = last.get("result")
	if not (result is Dictionary) or int((result as Dictionary)["settled_count"]) == 0:
		return ""
	var delta: int = int((result as Dictionary)["profit_or_loss"])
	return "LAST RUN  ·  %d moved for $%d  ·  %s$%d" % [
		int((result as Dictionary)["settled_count"]),
		int((result as Dictionary)["gross"]),
		"+" if delta >= 0 else "-", absi(delta)]

## What she is already out doing, and what came back.
func _assigned_body(summary: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var selection: Variant = summary["selection"]
	var picked: Array = (selection as Dictionary).get("purchased", []) if selection is Dictionary else []
	var spent: int = int((selection as Dictionary).get("total_spent", 0)) if selection is Dictionary else 0

	if bool(summary["assignment_settled"]):
		var result: Variant = summary["assignment_result"]
		if result is Dictionary:
			var gross: int = int((result as Dictionary)["gross"])
			var delta: int = int((result as Dictionary)["profit_or_loss"])
			v.add_child(label("SETTLED · %d moved for $%d" % [
				int((result as Dictionary)["settled_count"]), gross],
				"Mono", 12, GREEN if delta >= 0 else RED))
			v.add_child(label("She spent $%d and brought back $%d." % [spent, gross],
				"Muted", 11, MUTED, true))
		else:
			v.add_child(label("SETTLED", "Mono", 12, MUTED))
		return v

	if picked.is_empty():
		v.add_child(label("OUT TODAY · nothing worth taking", "Mono", 12, AMBER))
		v.add_child(label(_stop_text(str(summary["stop_reason"])), "Muted", 11, MUTED, true))
		return v

	v.add_child(label("OUT TODAY · %d picked up for $%d" % [picked.size(), spent],
		"Mono", 12, AMBER))
	for row in picked:
		var entry: Dictionary = row
		var item: Dictionary = gs.listing_item_by_id(str(entry["item_id"]))
		v.add_child(label("· %s  —  $%d" % [str(item.get("name", entry["item_id"])),
			int(entry["cost"])], "Muted", 11, MUTED))
	v.add_child(label("Settles tonight.", "Muted", 11, MUTED))
	return v

## The cost of the decision, before it is made. Cash exposure and the storage it
## needs, at every budget the board actually supports.
func _preview_body(ops: Object, summary: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var preview: Variant = summary["preview"]
	if not (preview is Dictionary):
		v.add_child(note("She cannot work a board that is not there."))
		return v
	var plan: Dictionary = preview

	v.add_child(label("STORAGE %d/%d free  ·  CASH $%d" % [
		int(plan["storage_free"]), int(plan["storage_capacity"]), int(plan["cash_on_hand"])],
		"Mono", 11, MUTED))

	if int(plan["cycles_used"]) == 0:
		v.add_child(label(_stop_text(str(plan["stop_reason"])), "Muted", 11, AMBER, true))
		return v

	# One button per budget the board supports, each showing the exact spend —
	# derived from real prices, so every option buys something.
	var options: Array = ops.spend_options(OPERATION_ID)
	for option in options:
		var entry: Dictionary = option
		var cycles: int = int(entry["cycles"])
		var spend: int = int(entry["spend"])
		var b := button("SEND HER FOR %d  ·  UP TO $%d" % [cycles, spend], cycles == options.size(),
			_on_assign.bind(spend), 46)
		v.add_child(b)
	v.add_child(label("Leaves you $%d if she spends it all." % [
		int(plan["cash_on_hand"]) - int((options[options.size() - 1] as Dictionary)["spend"])],
		"Muted", 11, MUTED))
	return v

## Why she cannot go, in the player's words. Keyed off the blocker CODE the
## operations layer produced, never re-derived from state here.
func _blocker_text(ops: Object, blocker: Variant) -> String:
	var code := str((blocker as Dictionary).get("blocker_code", ""))
	match code:
		"crew_active": return "Pherris is not on the crew."
		"crew_loyalty_min": return "She is not sure enough of you yet."
		"payroll_not_delinquent": return "Pay her what you owe first."
		"crew_unassigned_today": return "She already has the day."
		"planning_window_open": return "That is a morning decision. Tomorrow."
		"operation_undiscovered": return "You have not thought to ask."
	return "Not today."

## What stopped her, or would.
func _stop_text(code: String) -> String:
	match code:
		"capacity": return "Nowhere to put anything. Sell something first."
		"no_acceptable": return "Nothing on the board she would touch."
		"spend_limit": return "That is all the budget allows."
		"cash": return "Not enough on hand for the next one."
		"cycle_cap": return "That is a full day for her."
	return ""

## Listings taken today, and by whom. The board cannot answer this — consumption
## filters the pool before generation, so a taken item is simply not there.
func _taken_today(sys: Object, ops: Object) -> Array:
	var out: Array = []
	var hers: Array = []
	if ops != null:
		var last: Dictionary = ops.last_assignment("pherris")
		if int(last.get("day", -1)) == gs.day:
			var selection: Variant = last.get("selection")
			if selection is Dictionary:
				for row in (selection as Dictionary).get("purchased", []):
					hers.append(str((row as Dictionary)["item_id"]))
	for item_id in sys.taken_today():
		var item: Dictionary = gs.listing_item_by_id(str(item_id))
		if item.is_empty():
			continue
		out.append({"item": item, "by_pherris": str(item_id) in hers})
	return out

func _gone_row(row: Dictionary) -> Control:
	var item: Dictionary = row["item"]
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	c.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(item["name"]), "CardTitle", 13, MUTED)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label("$%d" % int(item["buy"]), "Mono", 12, MUTED))
	v.add_child(label("PHERRIS PICKED THIS UP" if bool(row["by_pherris"]) else "YOU PICKED THIS UP",
		"Muted", 11, AMBER if bool(row["by_pherris"]) else MUTED))
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

	# Hers is not the player's to sell, so the control is ABSENT rather than
	# disabled. A greyed-out SELL implies a thing you could do if something
	# changed; nothing changes this before tonight, and the system refuses it
	# outright. Same rule the Crew screen follows at the top of the rank ladder.
	if str(held.get("source", "player")) == "pherris":
		v.add_child(label("WITH PHERRIS  ·  SETTLES AT NIGHT", "Mono", 11, AMBER))
		return c

	# What it will fetch stays hidden until it is sold. Showing it would remove
	# the only decision on this screen.
	var blocked: String = sys.sell_blocker(index)
	var b := button("SELL" if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_sell.bind(index), 46)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

func _on_assign(spend_limit: int) -> void:
	var before: int = gs.cash
	if _gm.dispatch("assign_crew_operation", {
			"crew_id": "pherris", "operation_id": OPERATION_ID,
			"spend_limit": spend_limit}):
		var spent: int = before - gs.cash
		if spent > 0:
			nav.show_toast("Pherris is out with $%d of yours." % spent)
		else:
			nav.show_toast("She looked. Nothing worth taking today.")

func _on_buy(item_id: String) -> void:
	if _gm.dispatch("list_buy", {"item_id": item_id}):
		nav.show_toast("Picked it up. %d/%d carried." % [gs.list_holdings.size(), int(gs.market_tier()["capacity"])])

func _on_sell(index: int) -> void:
	var before: int = gs.cash
	if _gm.dispatch("list_sell", {"index": index}):
		var delta: int = gs.cash - before
		nav.show_toast("Sold for $%d." % delta)

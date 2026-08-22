extends "res://ui/screens/surface_base.gd"
## Boost — lifting stock from rooms that are watching, or aren't.
##
## Tier 2 targets each have a window slot worth +0.20, and the row says so
## outright. Canon only reveals a window after you have hit that target
## (ASK_BOOST_WINDOW); without a surface to learn it on, hiding it here would be
## a modifier the player can neither see nor act on.

func _build_body() -> void:
	var sys: Object = _gm.system("boost")
	if sys == null:
		return

	body.add_child(_status_card(sys))
	body.add_child(_attention_card("boost"))

	if gs.boost_merchandise > 0:
		body.add_child(section("SITTING ON MERCHANDISE"))
		body.add_child(_fence_card(sys))

	var targets: Array = sys.visible_targets()
	if targets.is_empty():
		body.add_child(note(_empty_line()))
		return

	body.add_child(section("ROOMS NEARBY"))
	for t in targets:
		body.add_child(_target_row(sys, t))

## What an empty board means HERE, which since batch 14 is two different things.
##
## The old line was "Nothing here you can work yet. Try another district." and it
## was the only line, which made it wrong on a fresh run in the most expensive
## way available: the player who has clocked nothing anywhere is told to spend a
## slot on a bus to a district where the board is also empty.
##
## So the reason is read rather than assumed, and it is read from the WANDER
## system's own pool — the same list that decides whether a DEAL walk can find
## anything, so the screen cannot promise a discovery the roll would refuse.
## A district with nothing left to clock is the one that genuinely wants a bus.
func _empty_line() -> String:
	var wander: Object = _gm.system("wander")
	var here: Array = wander.undiscovered_boost_targets() if wander != null else []
	if here.is_empty():
		return "Nothing here you can work yet. Try another district."
	return "You have not clocked anywhere around here. Walk the block and look for a deal."

## Local Attention, TI-003 §19 and PX-003 §7.
##
## Placed directly under the status card and above the target list, so the player
## reads how known they are here BEFORE they read what is worth taking. The band
## is the whole message: the raw Pressure score, the difficulty penalty it
## carries and the quiet-day counter all stay underneath, and the target rows
## below already show the final odds with the penalty inside them.
func _attention_card(family: String) -> Control:
	var band: String = attention_band(family)
	var tone: Color = attention_tone(band)
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(label("LOCAL ATTENTION: %s" % band, "CardTitle", 13, tone))
	var copy := str(ATTENTION_COPY.get(band, ""))
	if not copy.is_empty():
		v.add_child(label(copy, "Muted", 11, MUTED, true))
	c.add_child(v)
	return c

func _status_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)
	v.add_child(label("TIER %d  ·  TECHNIQUE %d" % [gs.boost_tier, gs.boost_technique], "CardTitle", 13, CREAM))
	if gs.boost_tier < 2:
		var need: int = gs.BOOST_TIER2_TECHNIQUE - gs.boost_technique
		v.add_child(label("%d more clean lifts opens the bigger rooms  ·  heat %d/%d" % [maxi(0, need), gs.heat_shown(), gs.heat_max], "Muted", 11, AMBER))
	else:
		v.add_child(label("Tier 3 needs a crew to field-assign  ·  heat %d/%d" % [gs.heat_shown(), gs.heat_max], "Muted", 11, MUTED))
	return c

func _fence_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)
	var rate: float = sys.fence_rate()
	var payout: int = int(round(float(gs.boost_merchandise) * rate))
	v.add_child(label("$%d in goods  ·  Slide pays %d%%  ·  $%d" % [gs.boost_merchandise, int(round(rate * 100.0)), payout], "CardTitle", 13, CREAM))
	v.add_child(button("MOVE IT TO SLIDE", true, _on_fence, 46))
	return c

func _target_row(sys: Object, t: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(t["name"]), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var band: Array = t["take"]
	head.add_child(label("$%d-%d" % [int(band[0]), int(band[1])], "Mono", 13, GREEN))

	v.add_child(label(str(t["desc"]), "Muted", 11, MUTED, true))

	var chance: float = sys.chance_for(t)
	var col: Color = GREEN if chance >= 0.6 else (AMBER if chance >= 0.4 else RED)
	var line := "%d%% odds  ·  tier %d" % [int(round(chance * 100.0)), int(t["tier"])]
	var window: int = int(t["window"])
	if window >= 0:
		var names := ["Morning", "Afternoon", "Evening", "Night"]
		line += "  ·  best %s" % names[window]
	v.add_child(label(line, "Muted", 11, col))

	var blocked: String = sys.blocker(str(t["id"]))
	var b := button("WALK IN" if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_boost.bind(str(t["id"])), 46)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

func _on_boost(target_id: String) -> void:
	var before: int = gs.cash
	var before_goods: int = gs.boost_merchandise
	if not _gm.dispatch("boost", {"target_id": target_id}):
		return
	if gs.cash > before:
		nav.show_toast("Out with $%d. Heat is %d/%d." % [gs.cash - before, gs.heat_shown(), gs.heat_max])
	elif gs.boost_merchandise > before_goods:
		nav.show_toast("$%d in goods for the fence." % (gs.boost_merchandise - before_goods))
	else:
		nav.show_toast("Empty handed. Heat is %d/%d." % [gs.heat_shown(), gs.heat_max])

func _on_fence() -> void:
	var before: int = gs.cash
	if _gm.dispatch("fence_goods", {}):
		nav.show_toast("Slide paid $%d." % (gs.cash - before))

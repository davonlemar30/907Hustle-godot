extends "res://ui/screens/surface_base.gd"
## Stickup — pick a mark, take the odds.
##
## The list is what is visible from where the player is standing, at or below
## their tier, so it changes with district and time of day. Each row shows the
## real chance and the real heat cost: the point of this surface is that the
## player can see exactly what they are trading.

func _build_body() -> void:
	var sys: Object = _gm.system("stickup")
	if sys == null:
		return

	body.add_child(_status_card())
	body.add_child(_attention_card("stick"))

	var targets: Array = sys.visible_targets()
	if targets.is_empty():
		body.add_child(note("Nothing here worth the risk. Try another district, or another time of day."))
		return

	body.add_child(section("MARKS NEARBY"))
	for t in targets:
		body.add_child(_target_row(sys, t))

## Local Attention for the Stick family. Same shape as Boost's, deliberately:
## PX-003 §7 wants one vocabulary the player learns once and reads everywhere,
## and the two surfaces differ only in which family they are asking about.
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

func _status_card() -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)
	var left: int = gs.STICK_DAILY_CAP - gs.stick_daily_count
	v.add_child(label("TIER %d  ·  %d/%d DONE TODAY" % [gs.stick_tier, gs.stick_daily_count, gs.STICK_DAILY_CAP], "CardTitle", 13, CREAM))
	var line := "%d left today" % left if left > 0 else "Done for today"
	v.add_child(label("%s  ·  %d/%d pulled off  ·  heat %d/%d" % [line, gs.stick_successes, gs.stick_attempts, gs.heat_shown(), gs.heat_max], "Muted", 11, MUTED if left > 0 else AMBER))
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
	var odds_col: Color = GREEN if chance >= 0.55 else (AMBER if chance >= 0.35 else RED)
	v.add_child(label("%d%% odds  ·  +%d heat if it lands  ·  tier %d" % [int(round(chance * 100.0)), int(t["heat"]), int(t["tier"])], "Muted", 11, odds_col))

	var blocked: String = sys.blocker(str(t["id"]))
	var b := button("RUN IT" if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_hit.bind(str(t["id"])), 46)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

func _on_hit(target_id: String) -> void:
	var before_cash: int = gs.cash
	var r: bool = _gm.dispatch("stickup", {"target_id": target_id})
	if not r:
		return
	# A tier 2-3 target opens the room instead of resolving here — the
	# consequence scene is about to take over, and a toast reading "it went
	# wrong" over a robbery that has not happened yet would be a lie.
	var engine: Object = _gm.system("consequence")
	if engine != null and engine.has_active():
		return
	# The dispatch already logged it; the toast is the immediate read.
	if gs.cash > before_cash:
		nav.show_toast("Took $%d. Heat is %d/%d." % [gs.cash - before_cash, gs.heat_shown(), gs.heat_max])
	else:
		nav.show_toast("It went wrong. Heat is %d/%d." % [gs.heat_shown(), gs.heat_max])

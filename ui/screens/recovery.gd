extends "res://ui/screens/surface_base.gd"
## Recovery — the health meter, the treatment ladder, and Lay Low.
##
## Ported from the web build's `Recovery` component (ui.built.js:15706). The
## rules live in `systems/recovery.gd`; this surfaces them.
##
## **The ladder reveals itself as the damage justifies it.** First aid is always
## there. The clinic appears at 82 health, the doctor at 55. That progressive
## disclosure is canon's subtitle and its design: a player at 95 health is never
## shown the $290 option, so the expensive card arriving is itself information
## about how bad things have got.
##
## The locked doctor card is ported too, and deliberately. Canon shows a "Private
## medical contact — Locked" card at 55 health rather than hiding the option, so
## the player learns the relationship is worth building BEFORE the night they
## need it. Hiding it would make the unlock a surprise instead of a goal. This is
## the same shape as the More screen's dropped rows and lands the other way for
## the same reason it did there: on a menu an unreachable row is a broken link;
## here it is a signpost.
##
## Lay Low's copy carries canon's warning, which is the whole trade: **debt,
## wages, markets and Curtis keep moving while the lights are off.**

func _recovery() -> Object:
	return _gm.system("recovery")

func _build_body() -> void:
	var sys: Object = _recovery()
	if sys == null:
		return

	body.add_child(_health_card())

	for treatment in sys.visible_treatments():
		body.add_child(_treatment_card(sys, treatment))

	# Canon shows the locked card at the doctor's reveal point, not before.
	if gs.health <= int(sys.DOCTOR["reveal_at"]) and not sys.doctor_open():
		body.add_child(_locked_doctor_card())

	body.add_child(_lay_low_card(sys))
	body.add_child(button("BACK TO MORE", false, _on_back, 44))

## Canon's health card: the number, and a meter that turns red under 40.
func _health_card() -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("HEALTH", "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var tint: Color = RED if gs.health < 40 else GREEN
	head.add_child(label("%d/%d" % [gs.health, gs.health_max], "Mono", 13, tint))

	# A ProgressBar rather than pips: this is a continuous 0-100 value, and the
	# pip row the meters elsewhere use would need 100 dots to say the same thing.
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = gs.health_max
	bar.value = gs.health
	bar.add_theme_stylebox_override("fill", _bar_style(tint))
	bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.08)))
	v.add_child(bar)
	return c

func _bar_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb

func _treatment_card(sys: Object, treatment: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	v.add_child(label(str(treatment["name"]).to_upper(), "CardTitle", 13, CREAM))
	v.add_child(label("%s  ·  restore up to %d Health" % [str(treatment["copy"]), int(treatment["amount"])],
		"Muted", 11, MUTED, true))

	var cost: int = sys.treatment_cost(int(treatment["cost"]))
	var blocked: String = sys.treat_blocker(treatment)
	var b := button("$%d" % cost if blocked.is_empty() else blocked.to_upper(),
		blocked.is_empty(), _on_treat.bind(str(treatment["id"])), 44)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	# Canon's action-copy line. Which of these costs a slot is the real choice
	# on this screen, so it is said on every card rather than inferred.
	v.add_child(label(
		"One part of day" if bool(treatment["costs_time"]) else "Free  ·  no time passes",
		"Muted", 10, MUTED))
	return c

## Canon's `card locked`. Shown so the relationship reads as a goal before it is
## a requirement.
func _locked_doctor_card() -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("PRIVATE MEDICAL CONTACT", "CardTitle", 13, MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(label("LOCKED", "Mono", 11, MUTED))

	v.add_child(label("Build a trusted medical relationship and the door opens.",
		"Muted", 11, MUTED, true))
	return c

func _lay_low_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("LAY LOW", "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(label("NEXT PART OF DAY", "Mono", 10, MUTED))

	v.add_child(label(
		"Expected immediate result: lower Heat by %s. Debt, wages, markets, and Curtis continue moving while the lights are off."
			% _heat_text(sys.lay_low_preview()), "Muted", 11, MUTED, true))
	# The blocker is the label, the same as every other card in the build.
	var blocked: String = str(sys.lay_low_blocker())
	var b := button("LAY LOW" if blocked.is_empty() else blocked.to_upper(),
		false, _on_lay_low, 44)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	v.add_child(label("Lowers Heat and advances time", "Muted", 10, MUTED))
	return c

## Heat is fractional, but "lower Heat by 2.0" reads worse than "by 2" and the
## whole-number case is the common one. One decimal only when there is one.
func _heat_text(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return "%.1f" % v

func _on_treat(treatment_id: String) -> void:
	var action: String = "use_first_aid" if treatment_id == "first_aid" else "heal"
	if _gm.dispatch(action, {"treatment_id": treatment_id}):
		nav.show_toast("Patched up. Health %d/%d." % [gs.health, gs.health_max])

func _on_lay_low() -> void:
	if _gm.dispatch("lay_low", {}):
		nav.show_toast("Quiet night. Heat %.1f." % gs.heat)

func _on_back() -> void:
	nav.go_to(nav.MORE)

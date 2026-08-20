extends "res://ui/screens/surface_base.gd"
## Crew — the roster and the wage ledger.
##
## The wage ledger is the point of the screen. A wage accrues every night
## whether or not it is paid, and an unpaid crew member is worth two points less
## power before they ever walk, so what is owed belongs next to what they are
## worth rather than buried.

func _build_body() -> void:
	var sys: Object = _gm.system("crew")
	if sys == null:
		return

	body.add_child(_status_card(sys))

	var hired: Array = gs.recruited_crew()
	if not hired.is_empty():
		body.add_child(section("ON THE CREW"))
		for person in hired:
			body.add_child(_member_row(sys, person, true))

	var available: Array = []
	for person in gs.crew_roster:
		if not gs.is_recruited(str(person["id"])) and str(gs.crew_record(str(person["id"])).get("status", "")) != "departed":
			available.append(person)
	if not available.is_empty():
		body.add_child(section("WILLING TO TALK"))
		for person in available:
			body.add_child(_member_row(sys, person, false))

func _status_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)
	var owed: int = 0
	for person in gs.recruited_crew():
		owed += int(gs.crew_record(str(person["id"])).get("wage_due", 0))
	v.add_child(label("%d/%d CREW  ·  POWER %d" % [gs.recruited_crew().size(), gs.CREW_CAPACITY, gs.crew_power], "CardTitle", 13, CREAM))
	if owed > 0:
		v.add_child(label("$%d owed in wages. Two nights is all the grace there is." % owed, "Muted", 11, RED))
	else:
		v.add_child(label("Wages square.", "Muted", 11, MUTED))
	# Only worth naming when somebody is actually providing it.
	var effects: Array = []
	if gs.is_recruited("deshawn"):
		effects.append("heat x%.2f" % sys.heat_multiplier())
	if gs.is_recruited("tone"):
		effects.append("defense x%.2f" % sys.defense_multiplier())
	if not effects.is_empty():
		v.add_child(label(" · ".join(effects).to_upper(), "Muted", 11, GREEN))
	return c

func _member_row(sys: Object, person: Dictionary, hired: bool) -> Control:
	var id: String = str(person["id"])
	var rec: Dictionary = gs.crew_record(id)
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(person["name"]), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label(str(person["role"]), "Mono", 10, MUTED))

	v.add_child(label(str(person["desc"]), "Muted", 11, MUTED, true))

	if not hired:
		v.add_child(label("POWER %d  ·  $%d to bring on  ·  $%d a night" % [int(person["power"]), int(person["cost"]), int(person["wage"])], "Muted", 11, AMBER))
		var blocked: String = sys.recruit_blocker(id)
		var b := button("BRING ON  $%d" % int(person["cost"]) if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_recruit.bind(id), 46)
		b.disabled = not blocked.is_empty()
		v.add_child(b)
		return c

	var tier: int = int(rec.get("tier", 1))
	var loyalty: int = int(rec.get("loyalty", 0))
	var due: int = int(rec.get("wage_due", 0))
	v.add_child(label("TIER %d  ·  LOYALTY %d/%d  ·  $%d a night" % [tier, loyalty, gs.CREW_LOYALTY_MAX, gs.crew_wage_for(id, tier)], "Muted", 11, MUTED))
	if due > 0:
		v.add_child(label("$%d OWED" % due, "Mono", 12, RED))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var pay_blocked: String = sys.pay_blocker(id)
	var pay := button("PAY $%d" % due if pay_blocked.is_empty() else pay_blocked.to_upper(), pay_blocked.is_empty(), _on_pay.bind(id))
	pay.disabled = not pay_blocked.is_empty()
	pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pay)

	var promo_blocked: String = sys.promote_blocker(id)
	var promo := button("PROMOTE" if promo_blocked.is_empty() else promo_blocked.to_upper(), false, _on_promote.bind(id))
	promo.disabled = not promo_blocked.is_empty()
	promo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(promo)
	v.add_child(row)
	return c

func _on_recruit(id: String) -> void:
	if _gm.dispatch("recruit_crew", {"crew_id": id}):
		nav.show_toast("%s is with you. Power %d." % [str(gs.crew_member_by_id(id)["name"]).split(" ")[0], gs.crew_power])

func _on_pay(id: String) -> void:
	var before: int = gs.cash
	if _gm.dispatch("pay_crew", {"crew_id": id}):
		nav.show_toast("Paid $%d. Power %d." % [before - gs.cash, gs.crew_power])

func _on_promote(id: String) -> void:
	if _gm.dispatch("promote_crew", {"crew_id": id}):
		nav.show_toast("Moved up. The wage moves too.")

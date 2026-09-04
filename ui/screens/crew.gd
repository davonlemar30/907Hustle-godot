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
	v.add_child(label("%d/%d CREW  ·  POWER %d" % [gs.recruited_crew().size(), gs.crew_capacity(), gs.crew_power], "CardTitle", 13, CREAM))
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
	# The rank name, never the tier number — the player is told what somebody is,
	# the same way attribute labels work.
	v.add_child(label("%s  ·  LOYALTY %d/%d  ·  $%d a night"
		% [gs.rank_label(tier), loyalty, gs.CREW_LOYALTY_MAX, gs.crew_wage_for(id, tier)],
		"Muted", 11, MUTED))
	if due > 0:
		v.add_child(label("$%d OWED" % due, "Mono", 12, RED))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var pay_blocked: String = sys.pay_blocker(id)
	var pay := button("PAY $%d" % due if pay_blocked.is_empty() else pay_blocked.to_upper(), pay_blocked.is_empty(), _on_pay.bind(id))
	pay.disabled = not pay_blocked.is_empty()
	pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pay)

	# Promotion is offered only where an authored next rank exists. Ranks 4-6
	# have labels but no requirements, so at the top of the authored ladder the
	# control is HIDDEN rather than disabled: a greyed-out PROMOTE reading
	# "NOWHERE HIGHER TO GO" tells the player there is a ladder they cannot
	# climb, which is a promise this build does not keep. Pay then fills the row.
	# What they are doing today, if anything. Read from the operations layer —
	# the screen does not know what an operation is, only how to show one.
	var ops: Object = _gm.system("crew_operations")
	if ops != null:
		var duty := _duty_line(ops, id)
		if not duty.is_empty():
			v.add_child(label(duty, "Mono", 11, AMBER))
		# BR-D6: the missions. One button per operation this member knows,
		# named; the ones that take a district offer the districts you know.
		for operation_id in ops.operation_ids():
			var summary: Dictionary = ops.operation_summary(str(operation_id))
			if str(summary["crew_id"]) != id or not bool(summary["discovered"]):
				continue
			var name := str(ops.OPERATION_LABELS.get(str(operation_id), str(operation_id).to_upper()))
			var available: bool = bool(summary["available"])
			if str(operation_id) in ops.OPERATION_TAKES_DISTRICT:
				var picks := HBoxContainer.new()
				picks.add_theme_constant_override("separation", 4)
				for district_id in (gs.districts_unlocked as Array):
					var district: Dictionary = gs.district_by_id(str(district_id))
					var b := button("%s %s" % [name, str(district.get("name", district_id)).left(8)], false,
						_on_mission.bind(id, str(operation_id), str(district_id)), 44)
					b.add_theme_font_size_override("font_size", 10)
					b.clip_text = true
					b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					b.disabled = not available
					picks.add_child(b)
				v.add_child(picks)
			else:
				var b := button(name, false, _on_mission.bind(id, str(operation_id), ""), 44)
				b.add_theme_font_size_override("font_size", 11)
				b.disabled = not available
				v.add_child(b)

	var promo_blocked: String = sys.promote_blocker(id)
	if not sys.at_top_rank(id):
		var promo := button("PROMOTE" if promo_blocked.is_empty() else promo_blocked.to_upper(), false, _on_promote.bind(id))
		promo.disabled = not promo_blocked.is_empty()
		promo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(promo)
	v.add_child(row)
	return c

## One line on where this crew member's day went, or is going. Empty for
## somebody with nothing to do — a row that says "not assigned" every day for
## three of four people is noise, and this screen is already dense.
func _duty_line(ops: Object, id: String) -> String:
	var assignment: Dictionary = ops.assignment_for(id)
	if assignment.is_empty():
		# Nothing today. Say so only if there is something they COULD be doing,
		# so the absence reads as an available choice rather than a blank.
		for operation_id in ops.operation_ids():
			var summary: Dictionary = ops.operation_summary(str(operation_id))
			if str(summary["crew_id"]) != id or not bool(summary["discovered"]):
				continue
			if bool(summary["available"]):
				return "FREE TODAY  ·  could work the board"
			var blocker: Variant = summary["blocker"]
			if blocker is Dictionary:
				return "NOT TODAY  ·  %s" % _blocker_short(
					str((blocker as Dictionary).get("blocker_code", "")))
		return ""
	if bool(assignment.get("settled", false)):
		return "WORKED THE BOARD  ·  settled"
	var selection: Variant = assignment.get("selection")
	var picked: int = 0
	if selection is Dictionary:
		picked = (( selection as Dictionary).get("purchased", []) as Array).size()
	return "OUT TODAY  ·  %d picked up, settles tonight" % picked

## The blocker code in a few words. Codes come from the operations layer; only
## the wording is the screen's.
func _blocker_short(code: String) -> String:
	match code:
		"crew_loyalty_min": return "not sure enough of you"
		"payroll_not_delinquent": return "owed wages"
		"crew_unassigned_today": return "already busy"
		"planning_window_open": return "morning decision"
		"crew_active": return "not on the crew"
	return "not available"

func _on_mission(crew_id: String, operation_id: String, district_id: String) -> void:
	var payload := {"crew_id": crew_id, "operation_id": operation_id}
	if not district_id.is_empty():
		payload["params"] = {"district_id": district_id}
	if _gm.dispatch("assign_crew_operation", payload):
		refresh()

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

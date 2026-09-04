extends "res://ui/screens/surface_base.gd"
## Night Owl — Mina's counter, from the front.
##
## Three things live here, and all three already existed:
##
## - **The shift.** `night_owl` has been in `gs.jobs` since the port began, paid
##   [55, 75], slotted EVENING-only, with `jobs.gd` carving Mina out of firing
##   because canon has her stop scheduling you rather than fire you. It was
##   never reachable: `jobs_discovered` seeds five ids and nothing in the build
##   ever appended a sixth. Walking in is how you hear about it.
## - **The phone bill.** `obligations.pay_phone_bill` has always taken a `store`
##   channel, and the Phone screen's own copy has always read "Pay $X at Night
##   Owl". The counter it named did not exist. Now it does.
## - **A night.** `night_owl_social` is a Charisma growth source, and Mina is the
##   one lens in the game that reads discretion as information about you.
##
## The screen writes nothing. Every one of those is a dispatch.

func _venues() -> Object:
	return _gm.system("venues")

func _obligations() -> Object:
	return _gm.system("obligations")

## OG-D3: the interior, when the game has it.
func _bind_interior() -> void:
	var bg := get_node_or_null("BGPhoto") as TextureRect
	if bg == null:
		return
	var interior: Texture2D = preload("res://data/portraits.gd").venue_image("night_owl")
	if interior != null:
		bg.texture = interior

func _build_body() -> void:
	_bind_interior()
	var sys: Object = _venues()
	if sys == null:
		return

	body.add_child(_counter_card(sys))
	body.add_child(_shift_card())
	body.add_child(_bill_card())
	body.add_child(_night_card(sys))
	body.add_child(button("BACK TO THE STREET", false, _on_back, 44))

func _counter_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	v.add_child(label("THE COUNTER", "CardTitle", 13, CREAM))
	if sys.has_entered(sys.NIGHT_OWL):
		# SA-D3: her read of you, off her ledger.
		v.add_child(label(str(sys.counter_line()), "Muted", 11, MUTED, true))
	else:
		v.add_child(label(
			"Coffee, a counter, and the only person in Spenard who has never "
			+ "asked you a question you did not want.", "Muted", 11, MUTED, true))
	return c

## The shift. Rendered as a signpost rather than an action: hiring runs through
## the Jobs surface, and duplicating it here would be a second door onto one
## door. What this card does is tell the player the job exists — which, before
## this screen, nothing in the game ever did.
func _shift_card() -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("THE EVENING SHIFT", "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var known: bool = "night_owl" in gs.jobs_discovered
	head.add_child(label("OPEN" if known else "—", "Mono", 13,
		GREEN if known else MUTED))

	if known:
		v.add_child(label(
			"Mina is short evenings. It is counter work and it pays like counter "
			+ "work, but nobody who sees you here sees anything else.",
			"Muted", 11, MUTED, true))
		if str(gs.active_job_id) == "night_owl":
			v.add_child(label("You are already on the schedule.", "Muted", 11, GREEN, true))
		else:
			v.add_child(button("APPLY THROUGH JOBS", false, _on_jobs, 44))
	else:
		v.add_child(label("Nothing on the board tonight.", "Muted", 11, MUTED, true))
	return c

func _bill_card() -> Control:
	var obligations: Object = _obligations()
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("PHONE BILL", "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(label("$%d" % int(gs.PHONE_BILL), "Mono", 13, CREAM))

	v.add_child(label(
		"The card reader by the register takes it in cash. No account, no laptop, "
		+ "no questions about where the cash came from.", "Muted", 11, MUTED, true))
	if obligations == null:
		return c
	var blocked: String = str(obligations.pay_phone_blocker("store"))
	var b := button("PAY AT THE COUNTER" if blocked.is_empty() else blocked.to_upper(),
		blocked.is_empty(), _on_pay_bill, 44)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

func _night_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("STAY A WHILE", "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var price: int = int(sys.night_owl_price())
	head.add_child(label("$%d" % price if price > 0 else "ON HER", "Mono", 13, CREAM))

	var done: int = int(sys.sessions(sys.NIGHT_OWL_GROWTH))
	v.add_child(label(
		"An evening at the end of the counter being nobody in particular. It is "
		+ "the cheapest way in this town to be seen not doing anything.",
		"Muted", 11, MUTED, true))
	v.add_child(label("One slot  ·  %s"
		% ("first time" if done == 0 else "%d nights" % done), "Muted", 11, MUTED, true))

	var blocked: String = str(sys.social_blocker())
	var b := button("STAY" if blocked.is_empty() else blocked.to_upper(),
		blocked.is_empty(), _on_night, 44)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

func _on_jobs() -> void:
	nav.go_to(nav.JOBS)

func _on_pay_bill() -> void:
	if _gm.dispatch("pay_phone_bill", {"channel": "store"}):
		nav.show_toast("Paid at the counter.")

func _on_night() -> void:
	if _gm.dispatch("night_owl_social", {}):
		nav.show_toast("A quiet night.")

func _on_back() -> void:
	nav.go_to(nav.STREET)

extends "res://ui/screens/surface_base.gd"
## Spenard Gym — the door onto three growth sources that have existed, rated and
## mapped to Combat since the port began with nothing able to reach them.
##
## `bag_work`, `cardio` and `sparring` are rows in `AttributesSystem`'s authored
## growth table. Until this screen, `list_flip` was the only one of nine with a
## caller, and the file said so in its own header. Three of the eight silent ones
## are now audible.
##
## **The player is never shown a number, and that is canon's rule, not a
## shortcut.** `improve()` banks progress behind a debug flag; what the player
## gets is a label — Green, Capable, Solid, Dangerous, Elite — and the sentence
## that arrives in the activity feed when it changes. So this screen shows the
## label, what each session costs, and how many of that session are behind them.
## What it never shows is the fraction of a point they are buying.
##
## The streak card is the exception worth making: canon's `gymStreakBonus` is a
## mechanical promise (three days running is +1 effective Combat on the next
## check), and a promise the player cannot see the terms of is not a promise.

func _venues() -> Object:
	return _gm.system("venues")

func _attributes() -> Object:
	return _gm.system("attributes")

## OG-D3: the interior, when the game has it.
func _bind_interior() -> void:
	var bg := get_node_or_null("BGPhoto") as TextureRect
	if bg == null:
		return
	var interior: Texture2D = preload("res://data/portraits.gd").venue_image("spenard_gym")
	if interior != null:
		bg.texture = interior

func _build_body() -> void:
	_bind_interior()
	var sys: Object = _venues()
	var attributes: Object = _attributes()
	if sys == null or attributes == null:
		return

	body.add_child(_standing_card(attributes))
	body.add_child(_streak_card(sys))
	body.add_child(section("WHAT THERE IS TO DO"))
	for activity in sys.GYM_ACTIVITIES:
		body.add_child(_activity_card(sys, activity))
	body.add_child(note(
		"The first few sessions of anything are worth the most. After that the "
		+ "room can only take you so far."))
	body.add_child(button("BACK TO THE STREET", false, _on_back, 44))

## Where Combat currently reads, and where it reads to a check right now — which
## are different numbers while a streak is running, and the whole point of
## saying both.
func _standing_card(attributes: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("COMBAT", "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var stored: int = int(attributes.value("combat"))
	var live: int = int(attributes.effective("combat"))
	head.add_child(label(str(attributes.label(live)), "Mono", 13,
		GREEN if live > stored else CREAM))

	if live > stored:
		v.add_child(label(
			"Reading a step above where you actually are, while the run holds.",
			"Muted", 11, GREEN, true))
	else:
		v.add_child(label(
			"Robbery, confrontation, escape, and every physical outcome.",
			"Muted", 11, MUTED, true))
	return c

func _streak_card(sys: Object) -> Control:
	var state: Dictionary = sys.gym_streak_state()
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("DAYS RUNNING", "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(label("%d" % int(state["days"]), "Mono", 13,
		GREEN if bool(state["live"]) else MUTED))

	if bool(state["live"]):
		v.add_child(label(
			"Three days running. You are carrying it into everything else.",
			"Muted", 11, GREEN, true))
	elif int(state["to_bonus"]) == 1:
		v.add_child(label("One more day and it starts to show.", "Muted", 11, AMBER, true))
	else:
		v.add_child(label(
			"Three days in a row is worth more than the three days are.",
			"Muted", 11, MUTED, true))
	if bool(state["trained_today"]):
		v.add_child(label("Today is already counted.", "Muted", 11, MUTED, true))
	return c

func _activity_card(sys: Object, activity: Dictionary) -> Control:
	var id := str(activity["id"])
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var nm := label(str(activity["name"]), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label("$%d" % int(activity["cost"]), "Mono", 13, CREAM))

	v.add_child(label(str(activity["desc"]), "Muted", 11, MUTED, true))

	var done: int = int(sys.sessions(id))
	var cost_line := "One slot"
	if int(activity["health"]) > 0:
		cost_line += "  ·  -%d health" % int(activity["health"])
	cost_line += "  ·  %s" % ("first time" if done == 0 else "%d done" % done)
	v.add_child(label(cost_line, "Muted", 11, MUTED, true))

	var blocked: String = str(sys.train_blocker(id))
	var b := button("DO IT" if blocked.is_empty() else blocked.to_upper(),
		blocked.is_empty(), _on_train.bind(id), 44)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

func _on_train(activity_id: String) -> void:
	if _gm.dispatch("gym_train", {"activity_id": activity_id}):
		nav.show_toast("You put the work in.")

func _on_back() -> void:
	nav.go_to(nav.STREET)

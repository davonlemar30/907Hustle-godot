extends "res://ui/screens/surface_base.gd"
## Character — what you brought in, and what the neighborhood currently sees.
##
## Ported from the web build's `Character` component (ui.built.js:15718). Four
## sections in canon's order: the identity card, Attributes, Record, and Recent
## reputation.
##
## **The player is never shown the number.** Canon is emphatic about this and it
## is the reason the screen exists at all: an attribute is a label — Green,
## Capable, Solid, Dangerous, Elite — and the line under the list says so out
## loud ("Nobody in Spenard reads you as a number"). Showing 3/12 here would
## turn a character sheet into a stat block and undo the whole design. The raw
## value lives behind canon's debug flag and nowhere else.
##
## Street Identity is cosmetic by canon's own rule: it never gates content,
## never modifies a roll, never touches disposition. It is derived on read from
## your strongest attribute crossed with what you have actually been seen doing
## in the last seven days, and it is recomputed every time this screen binds —
## `systems/attributes.gd::identity_profile()` is pure and writes nothing.
##
## What canon shows here that this build cannot, each named rather than faked:
##
##   - **Prior arrests.** Canon's `arrestRecord` reads an arrest/jail system this
##     build has never had. The card ships with canon's own no-record copy,
##     which is the true state of every run here: nothing on paper. It becomes
##     live the day an arrest system lands, with no change to this screen.
##   - **Recent reputation.** Canon lists the last five entries of
##     `player.behavior.history`, written by `recordBehavior` — a ledger of the
##     player's own choices, separate from the Exposure observations that other
##     characters carry. Not ported; the section shows canon's empty-state line.
##     **This is not the same thing as the People screen**, which is what each
##     character makes of you. This would be what you have done.
##   - **Legacy background / "Formerly".** Both are save-compatibility cards for
##     runs that predate systems this port never had. There is nothing they
##     could describe.
##
## Attribute purposes and labels come from `systems/attributes.gd`, so this
## screen holds no attribute copy of its own.

func _attributes() -> Object:
	return _gm.system("attributes")

func _build_body() -> void:
	var attrs: Object = _attributes()
	if attrs == null:
		return

	body.add_child(_identity_card(attrs))

	body.add_child(section("ATTRIBUTES"))
	for entry in attrs.TABLE:
		body.add_child(_attribute_row(attrs, entry))
	# Canon's line, verbatim. It is the screen's thesis.
	body.add_child(label(
		"Nobody in Spenard reads you as a number. Training, work, and the nights you survive move these on their own.",
		"Muted", 11, MUTED, true))

	body.add_child(section("RECORD"))
	body.add_child(_record_card())

	body.add_child(section("RECENT REPUTATION"))
	body.add_child(note("No choice has traveled far enough to become a story yet."))

	body.add_child(button("BACK TO MORE", false, _on_back, 44))

## Canon's header card: the run's street name, the identity label as its small
## text, and the description underneath.
func _identity_card(attrs: Object) -> Control:
	var profile: Dictionary = attrs.identity_profile()
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var name_text: String = gs.street_name if not gs.street_name.is_empty() else "NO NAME"
	var nm := label(name_text.to_upper(), "CardTitle", 15, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label(str(profile["label"]).to_upper(), "Mono", 11, AMBER))

	v.add_child(label(str(profile["description"]), "Muted", 12, MUTED, true))
	return c

## One attribute: its name, its LABEL (never its value), and what it is for.
func _attribute_row(attrs: Object, entry: Dictionary) -> Control:
	var id: String = str(entry["id"])
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var nm := label(str(entry["label"]).to_upper(), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label(attrs.label_for(id).to_upper(), "Mono", 11, _tier_colour(attrs.value(id))))

	v.add_child(label(str(entry["purpose"]), "Muted", 11, MUTED, true))
	return c

## Warmer as the label climbs. The colour carries the tier, not a number — same
## contract as the label itself.
func _tier_colour(v: int) -> Color:
	if v >= 8:
		return GREEN
	if v >= 6:
		return Color(0.62, 0.5, 0.85)
	if v >= 4:
		return Color(0.475, 0.733, 0.757)
	if v >= 2:
		return AMBER
	return MUTED

## Canon's Record card. No arrest system exists here, so this is always the
## no-record branch — and canon's no-record copy is the interesting half
## anyway, because it explains what getting booked would cost.
func _record_card() -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("PRIOR ARRESTS", "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(label("0", "Mono", 12, MUTED))

	v.add_child(label(
		"Nothing on paper. Getting booked clears street Heat and replaces it with a file that never closes.",
		"Muted", 11, MUTED, true))
	return c

func _on_back() -> void:
	nav.go_to(nav.MORE)

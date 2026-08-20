extends "res://ui/screens/surface_base.gd"
## People — the read each character has on you.
##
## One number per person, and the evidence behind it. The evidence matters as
## much as the score: two characters looking at the same ledger will disagree,
## because a lens is how one person reads what everyone can see. Showing the
## rows is what makes that legible rather than mysterious.
##
## Curtis reads backwards and the screen says so. On a rival's lens a high score
## means "no problem to me", so his bands run the other way: NEUTRAL is
## invisible, HOSTILE is the confrontation.

const NAMES := {
	"yalonda": "Yalonda", "juan": "Juan", "mina": "Mina",
	"curtis": "Curtis Foyer", "dre": "Dre Smooth",
}
const ROLES := {
	"yalonda": "THE ROOM YOU RENT", "juan": "HOUSEHOLD",
	"mina": "NIGHT OWL COUNTER", "curtis": "RIVAL", "dre": "THE NOTE",
}

func _build_body() -> void:
	var E: Node = get_node_or_null("/root/Exposure")
	if E == null:
		return
	for entry in E.everyone():
		body.add_child(_person_row(E, entry))

func _band_colour(band: String, inverted: bool) -> Color:
	# On an inverted lens the good end is the quiet end, so the colours flip too.
	if inverted:
		match band:
			"bonded", "trusted", "warm", "neutral": return GREEN
			"cold": return AMBER
		return RED
	match band:
		"bonded", "trusted": return GREEN
		"warm", "neutral": return MUTED
		"cold": return AMBER
	return RED

func _person_row(E: Node, entry: Dictionary) -> Control:
	var id: String = str(entry["id"])
	var inverted: bool = E.is_inverted(id)
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(NAMES.get(id, id)), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label(str(entry["label"]), "Mono", 12, _band_colour(str(entry["band"]), inverted)))

	v.add_child(label("%s  ·  %+.2f" % [str(ROLES.get(id, "")), float(entry["score"])], "Muted", 11, MUTED))

	if inverted:
		v.add_child(label("Reads backwards — for him, quiet is good.", "Muted", 10, MUTED, true))

	var rows: Array = E._ledger(id)
	if rows.is_empty():
		v.add_child(label("Knows nothing about you yet.", "Muted", 11, MUTED, true))
		return c

	# The evidence, newest first, so the score is never just an assertion.
	var shown: int = 0
	for i in range(rows.size() - 1, -1, -1):
		if shown >= 4:
			break
		var row: Dictionary = rows[i]
		var what: String = str(row["event"]) if not str(row["event"]).is_empty() else str(row["type"])
		var times: String = "" if int(row["count"]) <= 1 else " x%d" % int(row["count"])
		v.add_child(label("· %s%s  (%s)" % [what.replace("_", " "), times, str(row["source"])], "Muted", 10, MUTED, true))
		shown += 1
	if rows.size() > 4:
		v.add_child(label("· and %d more" % (rows.size() - 4), "Muted", 10, MUTED))
	return c

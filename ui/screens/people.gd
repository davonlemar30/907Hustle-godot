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

## Dre Lending & Loan-Shark Progression, PR B + C + D (First Money,
## DRE-ARC-02; A Reminder, DRE-ARC-03; restitution). The rest of this screen
## is read-only evidence — this is the one card that can act, because Dre is
## the one relationship on it with a real account behind it rather than just
## a disposition score. Read-only itself where Phone already has the live
## PAY/ASK FOR 2 MORE DAYS buttons (`_bind_dre_debt_card` on his own texts)
## — this card states the account and offers what has no text to live on
## yet: SEEK HIM OUT, BORROW, the two collection roads, and penance.
##
## The offer checks below are independent `if`s, not an `if`/`elif` chain —
## First Money and A Reminder are mutually exclusive by their own
## requirements (see `opportunities.gd`'s comment on `accept()`), but
## `dre_pending_penance` is not tied to either, so a returning player could
## in principle see A Reminder's offer and an outstanding penance in the
## same render.
func _bind_dre_extras(v: VBoxContainer) -> void:
	if not gs.dre_intro_offered:
		return
	if not gs.dre_introduced:
		v.add_child(label("Juan mentioned him. Word is he's easy to find in Spenard.",
			"Muted", 11, MUTED, true))
		var seek := button("SEEK HIM OUT", true, _on_seek_dre, 40)
		v.add_child(seek)
		return
	var status := str(gs.dre_account.get("status", "clear"))
	var status_line := "Clear what you owe before asking again." if status != "clear" \
		else "He'll put up money if you need it."
	v.add_child(label(status_line, "Muted", 11, MUTED, true))
	if gs.debt > 0:
		v.add_child(label("Debt to Dre: $%d, due Day %d" \
				% [gs.debt, gs.day + gs.debt_due_days],
			"Mono", 10, AMBER))
	if _offer_exists("dre_first_money"):
		# Numbers read off the lender itself, not restated here — the same
		# rule every other figure on this card already follows.
		var dre_system: Object = _gm.system("dre")
		if dre_system != null:
			var principal: int = int(dre_system.FIRST_LOAN_PRINCIPAL)
			var total: int = principal + int(dre_system.FIRST_LOAN_INTEREST)
			v.add_child(label("First offer: $%d now, $%d back in %d days." \
					% [principal, total, int(dre_system.FIRST_LOAN_TERM_DAYS)],
				"Muted", 11, MUTED, true))
			v.add_child(button("BORROW $%d" % principal, true, _on_borrow_dre, 40))
	if _offer_exists("dre_a_reminder"):
		v.add_child(label("Dontae Wells owes Dre. He'd like it handled.",
			"Muted", 11, MUTED, true))
		v.add_child(button("TALK IT LOOSE", true, _on_collect_negotiate, 40))
		v.add_child(button("GO COLLECT", true, _on_collect_hard, 40))
	if gs.dre_pending_penance:
		v.add_child(label("The money's square. He still wants to hear it from you.",
			"Muted", 11, MUTED, true))
		v.add_child(button("MAKE IT RIGHT", true, _on_do_penance, 40))

func _offer_exists(definition_id: String) -> bool:
	for entry in gs.opportunity_offers:
		if str((entry as Dictionary).get("definition_id", "")) == definition_id:
			return true
	return false

func _on_seek_dre() -> void:
	_gm.dispatch("dre_seek_out", {})

func _on_collect_negotiate() -> void:
	_gm.dispatch("dre_collect_negotiate", {})

func _on_collect_hard() -> void:
	_gm.dispatch("dre_collect_hard", {})

func _on_do_penance() -> void:
	_gm.dispatch("dre_do_penance", {})

func _on_borrow_dre() -> void:
	_gm.dispatch("dre_borrow", {})

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

	if id == "dre":
		_bind_dre_extras(v)

	# `ledger_of` is the public READ. PR #40 split the private accessor into
	# `_ledger_for_write` as part of making Exposure read-only during
	# observation, and this call site kept the old name — so every NPC row on
	# this screen has been erroring since. Reading is what it wants.
	var rows: Array = E.ledger_of(id)
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

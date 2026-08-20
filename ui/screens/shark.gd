extends "res://ui/screens/surface_base.gd"
## Shark — lend money, wait, find out.
##
## Two halves: notes already out (with whatever decision a default is waiting
## on), and the borrowers who will take a new one. The odds shown are the real
## default probability, because the whole surface is a bet the player should be
## able to price.

## Canon terms: shorter is dearer. Order matters — this drives the picker.
const TERMS := [2, 4, 7]

## Which term the next note uses. UI-only.
var _term: int = 4

func _build_body() -> void:
	var sys: Object = _gm.system("shark")
	if sys == null:
		return

	var open_notes: Array = []
	for l in gs.shark_loans:
		if str(l["status"]) in ["active", "extended", "defaulted"]:
			open_notes.append(l)

	if not open_notes.is_empty():
		body.add_child(section("NOTES OUT"))
		for l in open_notes:
			body.add_child(_note_row(sys, l))

	body.add_child(section("TERM"))
	body.add_child(_term_row())

	body.add_child(section("WHO'S ASKING"))
	for b in gs.shark_borrowers:
		body.add_child(_borrower_row(sys, b))

func _term_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for t in TERMS:
		var rate: float = float(gs.SHARK_TERMS[t]) * 100.0
		var b := button("%dD · %d%%" % [t, int(rate)], t == _term, _on_pick_term.bind(t))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	return h

func _on_pick_term(t: int) -> void:
	_term = t
	_bind_content()

func _borrower_row(sys: Object, b: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(b["name"]), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var risk_col: Color = GREEN if float(b["risk"]) < 0.15 else (AMBER if float(b["risk"]) < 0.30 else RED)
	head.add_child(label(str(b["risk_label"]), "Mono", 11, risk_col))

	v.add_child(label(str(b["desc"]), "Muted", 11, MUTED, true))

	var amount: int = int(b["max"])
	# Preview the actual odds and return for the amount and term on offer.
	var preview := {"borrower_id": str(b["id"]), "amount": amount, "term": _term}
	var p: float = sys.default_probability(preview)
	var interest: int = int(round(float(amount) * float(gs.SHARK_TERMS[_term])))
	var dre: int = int(round(float(interest) * gs.SHARK_DRE_CUT))
	v.add_child(label("$%d for %dd  ·  back $%d  ·  %d%% chance they don't" % [amount, _term, amount + interest - dre, int(round(p * 100.0))], "Muted", 11, MUTED))

	var blocked: String = sys.fund_blocker(str(b["id"]), amount)
	var btn := button("LEND $%d" % amount if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_fund.bind(str(b["id"]), amount), 46)
	btn.disabled = not blocked.is_empty()
	v.add_child(btn)
	return c

func _on_fund(borrower_id: String, amount: int) -> void:
	if _gm.dispatch("fund_shark", {"borrower_id": borrower_id, "amount": amount, "term": _term}):
		nav.show_toast("$%d out for %d days." % [amount, _term])

func _note_row(sys: Object, l: Dictionary) -> Control:
	var b: Dictionary = gs.borrower_by_id(str(l["borrower_id"]))
	var status: String = str(l["status"])
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(b["name"]), "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label("$%d" % int(l["amount"]), "Mono", 13, AMBER))

	if status == "defaulted":
		v.add_child(label("MISSED THE DEADLINE — the note needs a decision.", "Muted", 11, RED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for spec in [["ENFORCE", "enforce_shark", true], ["EXTEND", "extend_shark", false], ["FORGIVE", "forgive_shark", false]]:
			var btn := button(str(spec[0]), bool(spec[2]), _on_resolve.bind(str(spec[1]), int(l["id"])))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(btn)
		v.add_child(row)
	else:
		var days: int = int(l["due_day"]) - gs.day
		var when := "due today" if days <= 0 else ("due tomorrow" if days == 1 else "due in %d days" % days)
		var interest: int = sys.interest_for(l)
		v.add_child(label("%s  ·  %s  ·  $%d interest riding on it" % [status.to_upper(), when, interest], "Muted", 11, MUTED))
	return c

func _on_resolve(action: String, loan_id: int) -> void:
	var before: int = gs.cash
	if _gm.dispatch(action, {"loan_id": loan_id}):
		if gs.cash > before:
			nav.show_toast("Collected $%d." % (gs.cash - before))
		else:
			nav.show_toast("Handled.")

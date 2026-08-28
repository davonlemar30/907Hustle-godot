extends "res://ui/screens/surface_base.gd"
## THE BOOK — lend money, wait, find out. Renamed from "Shark" (DRE-D10);
## the file/scene names stay as-is, the same "code identifiers don't chase
## player-facing copy" call every other relabel in this build makes.
##
## Three parts, top to bottom: what the player owes DRE (a read-only summary
## — Phone owns the actual repay/extension actions, DRE-D2), notes already
## out (with whatever decision a default is waiting on), and the borrowers
## who will take a new one — locked behind earned access or Dre's one
## sponsorship exception (PR E, DRE-ARC-04) until then. The odds shown on a
## fundable row are the real default probability, because the whole surface
## is a bet the player should be able to price.

## Canon terms: shorter is dearer. Order matters — this drives the picker.
const TERMS := [2, 4, 7]

## Which term the next note uses. UI-only.
var _term: int = 4

func _build_body() -> void:
	var sys: Object = _gm.system("shark")
	if sys == null:
		return

	# Design doc §15.2 / DRE-D10: two separate sections, never merged into
	# one "notes" total. This is the half that is not the Book at all — see
	# `_dre_debt_card()`.
	body.add_child(section("DEBT TO DRE — YOU OWE"))
	body.add_child(_dre_debt_card())

	var open_notes: Array = []
	for l in gs.shark_loans:
		if str(l["status"]) in ["active", "extended", "defaulted"]:
			open_notes.append(l)

	body.add_child(section("THE BOOK — THEY OWE YOU"))
	if not open_notes.is_empty():
		for l in open_notes:
			body.add_child(_note_row(sys, l))

	body.add_child(section("TERM"))
	body.add_child(_term_row())

	body.add_child(section("WHO'S ASKING"))
	for b in gs.shark_borrowers:
		if sys.is_locked(str(b["id"])):
			body.add_child(_locked_borrower_row(b))
		else:
			body.add_child(_borrower_row(sys, b))

## Design doc §15.2 / DRE-D10's other half. Read-only on purpose: Phone
## already owns repay and extension-request (`phone.gd::_bind_dre_debt_card`,
## DRE-D2 — cash transfers, no slot), so this states the number rather than
## opening a second door to pay it.
func _dre_debt_card() -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	if gs.debt <= 0:
		v.add_child(label("Clear. Dre's not owed anything right now.", "Muted", 11, MUTED))
		return c

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label("Dre", "CardTitle", 13, CREAM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label("$%d" % gs.debt, "Mono", 13, AMBER))

	var status := str(gs.dre_account.get("status", "clear"))
	if status == "suspended":
		v.add_child(label("SUSPENDED — clear it before he lets you run a book.", "Muted", 11, RED))
	elif gs.debt_due_days < 0:
		var days_over: int = -gs.debt_due_days
		v.add_child(label("OVERDUE by %d day%s" % [days_over, "" if days_over == 1 else "s"], "Muted", 11, RED))
	elif gs.debt_due_days == 0:
		v.add_child(label("Due tonight.", "Muted", 11, AMBER))
	else:
		v.add_child(label("Due in %d day%s." % [gs.debt_due_days, "" if gs.debt_due_days == 1 else "s"], "Muted", 11, MUTED))
	return c

## Canon's "card locked" pattern (see ui/screens/recovery.gd's own doctor
## card) — the relationship reads as a goal before it is a requirement. Name
## and blurb still show; odds, amount, and the LEND button do not, since
## none of them mean anything until the tier opens or Dre vouches.
func _locked_borrower_row(b: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(b["name"]), "CardTitle", 13, MUTED)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(label("LOCKED", "Mono", 11, MUTED))

	v.add_child(label(str(b["desc"]), "Muted", 11, MUTED, true))
	v.add_child(label("Dre hasn't opened the Book to you yet.", "Muted", 11, MUTED))
	return c

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

extends "res://ui/screens/surface_base.gd"
## Phone — texts, contacts, bills, and word around town.
##
## Ported from the web build's `PhoneScreen` (ui.built.js:15734) and its
## `phoneBills` helper (15742). Canon's six sections, in canon's order: the
## offline card, Texts, Contacts, Bills, Today's Log, Word Around Town. The
## substrate they read — the inbox, the held inbox, the bill clock — is
## `systems/phone.gd` and `systems/obligations.gd`; this screen surfaces it and
## reimplements none of it.
##
## **The phone stays available even when the network does not.** That is canon's
## own subtitle for the offline state and it is the design: losing service does
## not lose you the screen, it changes what the screen can tell you. Texts are
## held rather than dropped, Word Around Town goes quiet, the Bills row points
## at the Phone Store instead of offering to pay, and the header renames itself
## "No Service". Every section has an offline voice.
##
## Sections are accordions, as canon's are, and only Texts starts expanded
## (`defaultExpanded: true` on that one alone). Expansion is UI state kept on the
## script rather than in GameState — it is not part of the run and has no
## business in a save — and it survives `_bind_content()`'s clear-and-rebuild
## because it lives outside the node tree.
##
## Divergences, each with its reason:
##   - **Contacts links out instead of embedding.** Canon renders the whole
##     `SocialContacts` component here. This build has no `state.contacts`
##     ledger (relationship levels, call/text/visit availability) and does have
##     a People screen showing what each character makes of you, so the section
##     routes there. The count is the number of people the run has actually
##     formed a read on, not canon's `personalContacts + knownSocialContacts`,
##     which needs the ledger.
##   - **"Pay in People > Crew"** became "Pay on the Crew screen": canon's arrow
##     is U+2192, which no theme font carries, and this is a place where a
##     sentence beats an icon.
##   - **The rent row's eviction gate is unreachable.** Canon hides it when
##     `people.household.evicted`; here the third household warning ends the run
##     outright, so there is no evicted-and-still-playing state to hide it in.
##     Ported anyway, as a `game_over` check, so it stays correct if that
##     changes.
##   - **The debt row is wired but dormant.** Canon reads `state.lender` (Dre's
##     note); no lender system is ported, and `GameState.debt` is 0 on every run
##     the build can currently start. Gating on `debt > 0` means it shows
##     nothing today rather than a fabricated bill, and lights up the day the
##     lender lands.
##
## Not ported: the `job_offer` answer buttons on a text. The descriptor is
## carried through the substrate, but `jobs.gd` hires directly and has no
## application -> offer pipeline, so no message ever arrives with one. The
## branch is here and named rather than silently absent.

const BLUE := Color(0.373, 0.663, 0.847)

## Canon: `defaultExpanded: true` on Texts, nothing else.
var _open: Dictionary = {
	"texts": true, "contacts": false, "bills": false, "log": false, "intel": false,
}

func _obligations() -> Object:
	return _gm.system("obligations")

func _phone() -> Object:
	return _gm.system("phone")

func _build_body() -> void:
	var offline: bool = not gs.phone_active
	# Canon renames the whole page when the line is dead.
	_set_text("Shell/Scroll/Pad/Content/Title/H", "NO SERVICE" if offline else "PHONE")
	_set_text("Shell/Scroll/Pad/Content/Title/Sub",
		"The phone stays available even when the network does not" if offline
		else "Texts, contacts, bills, and word around town")

	if offline:
		body.add_child(_offline_card())
	_build_texts(offline)
	_build_contacts()
	_build_bills()
	_build_log()
	_build_intel(offline)

# --- accordion -------------------------------------------------------------

## A tappable header row. `meta` is canon's right-aligned count; `badge_colour`
## carries canon's danger/warning variants on the Bills badge.
func _accordion(key: String, title: String, meta: String, badge_colour: Color = MUTED) -> void:
	var c := card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	c.add_child(h)

	var t := label(title.to_upper(), "CardTitle", 13, CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if not meta.is_empty():
		h.add_child(label(meta, "Muted", 11, badge_colour))
	# The chevron is the only affordance saying these open. Both characters are
	# from the five every theme font carries — a rotating icon would read better
	# but no safe glyph points down, and "–" is a standard collapse affordance.
	h.add_child(label("›" if not _open.get(key, false) else "–", "Muted", 13, MUTED))

	tap_connect(c, _on_toggle.bind(key))
	body.add_child(c)

func _on_toggle(key: String) -> void:
	_open[key] = not _open.get(key, false)
	_bind_content()

func _is_open(key: String) -> bool:
	return bool(_open.get(key, false))

# --- offline ---------------------------------------------------------------

## Canon's `card locked`: the one place that can restore service, and it is not
## on the phone. Paying here is the store surface, which works with a dead line.
func _offline_card() -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := label("SIGNAL UNAVAILABLE", "CardTitle", 13, RED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(label("%d DAYS PAST DUE" % gs.phone_days_past_due, "Mono", 11, RED))

	v.add_child(label(
		"Pay $%d at Night Owl to start restoration. Online payment requires active service and a laptop." % gs.PHONE_BILL,
		"Muted", 12, MUTED, true))

	var blocked: String = _obligations().pay_phone_blocker("store")
	var b := button(
		"PAY AT NIGHT OWL  ·  $%d" % gs.PHONE_BILL if blocked.is_empty() else blocked.to_upper(),
		blocked.is_empty(), _on_pay_phone.bind("store"), 46)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	# Canon's action-copy line. Service comes back on the NEXT action, not this
	# one — the deferred restoration, said out loud so it does not read as a bug.
	v.add_child(label("Free  ·  service restores after the next action", "Muted", 11, MUTED))
	return c

# --- texts -----------------------------------------------------------------

func _build_texts(offline: bool) -> void:
	var held: int = gs.phone_held_inbox.size()
	var live: int = gs.phone_inbox.size()
	var meta: String = "%d HELD" % held if offline else ("%d TEXT" % live if live == 1 else "%d TEXTS" % live)
	_accordion("texts", "Texts", meta, AMBER if (offline and held > 0) else MUTED)
	if not _is_open("texts"):
		return

	if offline:
		body.add_child(note("%d message is waiting for service." % held if held == 1
			else "%d messages are waiting for service." % held))
		return
	if live == 0:
		body.add_child(note("No messages yet."))
		return
	# Canon only offers Clear all when there is more than one to clear.
	if live > 1:
		body.add_child(button("CLEAR ALL %d" % live, false, _on_clear_inbox, 40))
	for message in gs.phone_inbox:
		body.add_child(_message_card(message))

func _message_card(message: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var from := label(str(message.get("from", "")).to_upper(), "CardTitle", 13, CREAM)
	from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(from)
	head.add_child(label(_phone().stamp(message), "Mono", 10, MUTED))
	# Canon's dismiss glyph is U+00D7, which every theme font carries (checked
	# against the cmaps, not against how it looks in the editor).
	var dismiss := button("×", false, _on_dismiss.bind(str(message.get("id", ""))), 28)
	dismiss.custom_minimum_size = Vector2(34, 28)
	head.add_child(dismiss)

	v.add_child(label(str(message.get("text", "")), "Muted", 12, CREAM, true))

	# Canon shows Accept / Turn it down when the offer behind the text is still
	# live. Nothing pushes a job_offer in this build yet (jobs.gd hires direct),
	# so this stays unreachable until the application pipeline lands.
	var action: Dictionary = message.get("action", {})
	if not action.is_empty() and str(action.get("kind", "")) == "job_offer":
		v.add_child(label("OFFER ATTACHED", "Kicker", 10, AMBER))
	return c

func _on_dismiss(id: String) -> void:
	_gm.dispatch("dismiss_phone_message", {"id": id})

func _on_clear_inbox() -> void:
	_gm.dispatch("clear_phone_inbox", {})

# --- contacts --------------------------------------------------------------

func _build_contacts() -> void:
	var known: int = _known_contacts()
	_accordion("contacts", "Contacts", "%d KNOWN" % known)
	if not _is_open("contacts"):
		return
	if known == 0:
		body.add_child(note("Nobody has a read on you yet."))
		return
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)
	v.add_child(label("WHO KNOWS YOU", "CardTitle", 13, CREAM))
	v.add_child(label("What each of them makes of you, and the evidence behind it.",
		"Muted", 12, MUTED, true))
	v.add_child(button("OPEN PEOPLE", false, _on_open_people, 40))
	body.add_child(c)

## Canon counts `personalContacts + knownSocialContacts` minus the household,
## both of which need the `state.contacts` ledger this build has not ported.
## The closest real number is who the run has actually dealt with — an NPC with
## at least one observation on their ledger.
func _known_contacts() -> int:
	var exposure: Node = get_node_or_null("/root/Exposure")
	if exposure == null:
		return 0
	var count := 0
	for entry in exposure.everyone():
		if int(entry.get("rows", 0)) > 0:
			count += 1
	return count

func _on_open_people() -> void:
	nav.go_to(nav.PEOPLE)

# --- bills -----------------------------------------------------------------

## Canon phoneBills, row for row. `severity` 2 is red, 1 is amber, 0 is quiet;
## `paid` is the crew row's "nothing owed tonight" state.
func _bills() -> Array:
	var rows: Array = []
	var obligations: Object = _obligations()

	# Phone. Canon's status ladder reads the line's health before the calendar.
	var phone_row: Dictionary = {
		"id": "phone", "name": "Phone service", "amount": gs.PHONE_BILL,
		"where": "Pay at Night Owl or the Phone Store",
		"due": "Day %d" % gs.phone_due_day,
		"blocker": obligations.pay_phone_blocker("phone"),
		"action": "pay_phone_bill", "payload": {"surface": "phone"},
	}
	if not gs.phone_active:
		phone_row["status"] = "Service off"
		phone_row["severity"] = 2
	elif gs.phone_days_past_due > 0:
		phone_row["status"] = "Past due"
		phone_row["severity"] = 2
	elif gs.day >= gs.phone_due_day:
		phone_row["status"] = "Due today"
		phone_row["severity"] = 1
	else:
		phone_row.merge(_upcoming(gs.phone_due_day))
	rows.append(phone_row)

	# Rent. Canon hides this once the household has evicted you; here the third
	# warning ends the run, so the check can only ever be false.
	if not gs.game_over:
		var rent_row: Dictionary = {
			"id": "rent", "name": "Rent", "amount": gs.WEEKLY_RENT,
			"where": "Pay Yalonda", "due": "Day %d" % gs.rent_due_day,
			"blocker": obligations.pay_rent_blocker(),
			"action": "pay_rent", "payload": {},
		}
		if gs.day > gs.rent_due_day:
			rent_row["status"] = "Past due"
			rent_row["severity"] = 2
		elif gs.day == gs.rent_due_day:
			rent_row["status"] = "Due now"
			rent_row["severity"] = 2
		else:
			rent_row.merge(_upcoming(gs.rent_due_day))
		rows.append(rent_row)

	# Crew wages. Canon shows what is OWED, or what a clean night will cost if
	# nothing is. No pay action on this row — wages are paid per person.
	var recruited: Array = []
	var owed := 0
	var nightly := 0
	for member in gs.crew_roster:
		var id: String = str(member["id"])
		var record: Dictionary = gs.crew_record(id)
		if not bool(record.get("recruited", false)):
			continue
		recruited.append(id)
		owed += int(record.get("wage_due", 0))
		nightly += int(gs.crew_wage_for(id, int(record.get("tier", 1))))
	if not recruited.is_empty():
		var wage_row: Dictionary = {
			"id": "wages", "name": "Crew wages", "amount": owed if owed > 0 else nightly,
			"where": "Pay on the Crew screen", "due": "Daily",
		}
		if owed > 0:
			wage_row["status"] = "Unpaid"
			wage_row["severity"] = 2
		else:
			wage_row["status"] = "Paid up"
			wage_row["severity"] = 0
			wage_row["paid"] = true
		rows.append(wage_row)

	# Dre's note. Dormant until a lender system exists — see the file header.
	if gs.debt > 0:
		var due_day: int = gs.day + gs.debt_due_days
		var debt_row: Dictionary = {
			"id": "debt", "name": "Debt to Dre", "amount": gs.debt,
			"where": "Pay in Finances", "due": "Day %d" % due_day,
		}
		if gs.debt_due_days < 0:
			debt_row["status"] = "Overdue"
			debt_row["severity"] = 2
		elif gs.debt_due_days == 0:
			debt_row["status"] = "Due tonight"
			debt_row["severity"] = 2
		else:
			debt_row.merge(_upcoming(due_day))
		rows.append(debt_row)

	return rows

## Canon's `upcoming`: two days out is when a bill starts asking for attention.
func _upcoming(due_day: int) -> Dictionary:
	if due_day - gs.day <= 2:
		return {"status": "Due soon", "severity": 1}
	return {"status": "Upcoming", "severity": 0}

func _build_bills() -> void:
	var rows: Array = _bills()
	var due_soon := 0
	var any_bad := false
	for row in rows:
		if int(row.get("severity", 0)) > 0:
			due_soon += 1
		if int(row.get("severity", 0)) == 2:
			any_bad = true
	# Canon's badge: the count, coloured danger if anything is actually late.
	var meta: String = "%d DUE" % due_soon if due_soon > 0 else ""
	_accordion("bills", "Bills", meta, RED if any_bad else AMBER)
	if not _is_open("bills"):
		return
	if rows.is_empty():
		body.add_child(note("No bills yet."))
		return
	for row in rows:
		body.add_child(_bill_row(row))
	if due_soon == 0:
		body.add_child(note("Paid up. Nothing is due yet."))

func _bill_row(row: Dictionary) -> Control:
	var severity: int = int(row.get("severity", 0))
	var tint: Color = RED if severity == 2 else (AMBER if severity == 1 else MUTED)

	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	left.add_child(label(str(row["name"]).to_upper(), "CardTitle", 13, CREAM))
	var blocker: String = str(row.get("blocker", ""))
	# Canon swaps the "where" line for "Paid from cash on hand" once the row is
	# actually payable — the instruction stops being useful the moment it is.
	var has_action: bool = row.has("action")
	left.add_child(label(
		"Paid from cash on hand" if has_action and blocker.is_empty() else str(row["where"]),
		"Muted", 11, MUTED, true))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 1)
	head.add_child(right)
	var amount := label("$%d" % int(row["amount"]), "Mono", 14, tint)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(amount)
	var status := label("%s  ·  %s" % [str(row["due"]), str(row["status"])], "Muted", 10, tint)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(status)

	if has_action:
		var b := button("PAY $%d" % int(row["amount"]) if blocker.is_empty() else blocker.to_upper(),
			blocker.is_empty() and severity > 0,
			_on_pay_bill.bind(str(row["action"]), row.get("payload", {})), 40)
		b.disabled = not blocker.is_empty()
		v.add_child(b)
	return c

func _on_pay_bill(action: String, payload: Dictionary) -> void:
	_gm.dispatch(action, payload)

func _on_pay_phone(surface: String) -> void:
	if _gm.dispatch("pay_phone_bill", {"surface": surface}):
		nav.show_toast("Paid. The line comes back after your next move.")

# --- today's log -----------------------------------------------------------

## Canon filters the run log by a `Day N ·` stamp prefix. Ours carries the day
## as a field, so the filter is an equality rather than a string match — and a
## row from a save that predates the field is stamped -1 and never matches.
func _build_log() -> void:
	var today: Array = []
	for entry in gs.activity_log:
		if int(entry.get("day", -1)) == gs.day:
			today.append(entry)
	_accordion("log", "Today's Log", "%d TODAY" % today.size())
	if not _is_open("log"):
		return
	if today.is_empty():
		body.add_child(note("Nothing logged today."))
		return
	for entry in today:
		var c := card()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		c.add_child(v)
		var tone: Color = entry.get("color", MUTED)
		v.add_child(label(str(entry.get("text", "")), "Muted", 12, tone, true))
		v.add_child(label(str(entry.get("time", "")), "Mono", 10, MUTED))
		body.add_child(c)

# --- word around town ------------------------------------------------------

func _build_intel(offline: bool) -> void:
	_accordion("intel", "Word Around Town", "")
	if not _is_open("intel"):
		return
	if offline:
		body.add_child(note("Word comes back when service does."))
		return
	var lines: Array = _phone().intel()
	if lines.is_empty():
		body.add_child(note("Nothing on the wire yet."))
		return
	for line in lines:
		var c := card()
		c.add_child(label(str(line), "Muted", 12, BLUE, true))
		body.add_child(c)

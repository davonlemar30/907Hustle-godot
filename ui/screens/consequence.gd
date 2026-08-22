extends "res://ui/screens/surface_base.gd"
## The blocking consequence scene — TI-003 §18.
##
## The one screen the player does not choose to be on. It has the standard
## TopBar and six-stat HUD so the run still reads normally, and **no bottom
## navigation**, because there is nowhere else to be until this resolves.
##
## ## It renders projections, never state
##
## Every value on this screen comes from `ConsequenceEngine`'s four summary
## calls. The scene never reads `gs.active_consequence` and never writes
## anything — it dispatches stable IDs and re-renders from whatever comes back.
##
## That is not ceremony. The chain is persisted, so what the player is looking at
## has to be reconstructible from the save alone; a screen that computed anything
## itself would be a second source of truth that a reload could not restore.
##
## ## Committed buttons stay committed after a reload
##
## TI-003 §18's sharpest requirement, and the reason `disabled` comes from
## `choice_summaries()` rather than from a `_pressed` handler. A flag set on
## click lives in the scene; the scene dies on reload. The commit lives in the
## chain, and the chain is in the save.
##
## ## Four stages, one scene
##
## `decision` → `result` → `booking` → `release`. Separate scenes would duplicate
## the chrome four times and would make the stage a navigation fact rather than a
## state fact — and stage IS state, because it has to survive a reload.

const CYAN := Color(0.475, 0.733, 0.757)

@onready var _engine: Object = _gm.system("consequence")

func _ready() -> void:
	super()

## The scene is only ever open because something is blocking. If that stops
## being true — the chain cleared, the run ended — `screen_base.refresh()`
## routes away on the next state change, so there is nothing to do here but
## render an empty state for the frame in between.
func _build_body() -> void:
	if _engine == null:
		body.add_child(label("The moment has passed.", "Muted", 13, MUTED, true))
		return
	var summary: Dictionary = _engine.active_summary()
	if summary.is_empty():
		body.add_child(label("The moment has passed.", "Muted", 13, MUTED, true))
		return

	_build_situation(summary)
	match str(summary.get("stage", "")):
		_engine.STAGE_DECISION:
			_build_decision()
		_engine.STAGE_RESULT:
			_build_result()
		_engine.STAGE_BOOKING:
			_build_booking()
		_engine.STAGE_RELEASE:
			_build_release()

## Where you are and what it is about. Shared by all four stages so the player
## never loses the thread between a decision and its result.
func _build_situation(summary: Dictionary) -> void:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(label(_situation_heading(summary), "CardTitle", 15, CREAM))

	var target := str(summary.get("source_target_id", ""))
	if not target.is_empty():
		v.add_child(label(target.capitalize().replace("_", " "), "Muted", 12, MUTED))

	# The take that is currently in dispute. Shown because it is the thing the
	# player is about to gamble on keeping, and hidden at zero rather than shown
	# as "$0", which would read as a loss that has already happened.
	var contested: int = int(summary.get("contested_take", 0))
	if contested > 0:
		v.add_child(label("$%d in your hands." % contested, "Mono", 13, AMBER))

	c.add_child(v)
	body.add_child(c)

func _situation_heading(summary: Dictionary) -> String:
	match str(summary.get("chain_kind", "")):
		_engine.KIND_BOOST_CAUGHT:
			return "Somebody has you."
		_engine.KIND_STICK_BOOKING:
			return "They are booking you."
		_engine.KIND_RETALIATION:
			return "They came looking."
	return "This is happening now."

## The response buttons. Odds come from the chain, which recorded them when the
## decision opened — so a reload shows the same numbers the player decided on,
## rather than re-deriving odds against state that has since moved.
func _build_decision() -> void:
	var rows: Array = _engine.choice_summaries()
	if rows.is_empty():
		body.add_child(label("No way out of this one.", "Muted", 13, MUTED, true))
		return
	body.add_child(label("HOW DO YOU PLAY IT", "Muted", 11, MUTED))
	for entry in rows:
		var row: Dictionary = entry
		var c := card()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var name_label := label(str(row["label"]), "CardTitle", 14, CREAM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		head.add_child(label(_odds_text(row), "Mono", 13, _odds_tone(row)))
		v.add_child(head)

		var button := Button.new()
		button.theme_type_variation = &"BtnPrimary"
		button.text = "COMMITTED" if bool(row["committed"]) else str(row["label"]).to_upper()
		# Persisted, not clicked. See the file header.
		button.disabled = bool(row["disabled"])
		if not button.disabled:
			button.pressed.connect(_commit.bind(str(row["choice_id"])))
		v.add_child(button)
		c.add_child(v)
		body.add_child(c)

## A deterministic response has no odds. Showing 0% would read as impossible
## when it means the opposite — the outcome is known before you pick it.
func _odds_text(row: Dictionary) -> String:
	if bool(row.get("deterministic", false)):
		return "CERTAIN"
	if not bool(row.get("has_odds", false)):
		return "—"
	return "%d%%" % int(round(float(row["success_probability"]) * 100.0))

func _odds_tone(row: Dictionary) -> Color:
	if bool(row.get("deterministic", false)):
		return CYAN
	if not bool(row.get("has_odds", false)):
		return MUTED
	var p: float = float(row["success_probability"])
	if p >= 0.6:
		return GREEN
	return AMBER if p >= 0.35 else RED

func _commit(choice_id: String) -> void:
	var summary: Dictionary = _engine.active_summary()
	# Stable IDs, both of them. The engine revalidates against the live chain, so
	# a button rendered before a reload is refused rather than honoured against
	# whatever is open now.
	_gm.dispatch("resolve_consequence_choice", {
		"consequence_id": str(summary.get("consequence_id", "")),
		"cause_id": str(summary.get("cause_id", "")),
		"choice_id": choice_id,
	})

## What it cost. The authored effect rows are FS-003.7's; this renders whatever
## the chain recorded, so it needs no edit when they arrive.
func _build_result() -> void:
	var result: Dictionary = _engine.result_summary()
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var tier := str(result.get("resolved_tier", ""))
	v.add_child(label("YOU PLAYED IT %s" % str(result.get("committed_choice", "")).to_upper(),
		"Muted", 11, MUTED))
	if not tier.is_empty():
		v.add_child(label(tier.capitalize(), "CardTitle", 15, _tier_tone(tier)))
	for line in _effect_lines(result.get("result", {})):
		v.add_child(label(str(line), "Muted", 12, MUTED, true))
	c.add_child(v)
	body.add_child(c)
	# An arrested result hands off to Booking rather than back to the street, and
	# the button says which — PX-003 §5 labels it `BOOKING`.
	body.add_child(_continue_button(
		"BOOKING" if bool((result.get("result", {}) as Dictionary).get("arrested", false))
			else "CONTINUE"))

func _tier_tone(tier: String) -> Color:
	match tier:
		"clean": return GREEN
		"messy": return AMBER
		"catastrophic": return RED
	return MUTED

## Exact deltas, one line each. TI-003 §18: "Result stage shows narrative plus
## exact changes to Cash, goods, Health, Heat, bans, and arrest state."
##
## Driven off a declared table rather than a chain of ifs so a later slice adds
## a row by adding a row.
const RESULT_ROWS := [
	{"key": "cash", "label": "Cash", "money": true},
	{"key": "goods", "label": "Merchandise", "money": true},
	{"key": "health", "label": "Health", "money": false},
	{"key": "heat", "label": "Heat", "money": false},
]

func _effect_lines(result: Dictionary) -> Array:
	var lines: Array = []
	for spec in RESULT_ROWS:
		var row: Dictionary = spec
		var key := str(row["label"])
		if not result.has(row["key"]):
			continue
		var value: float = float(result[row["key"]])
		if is_zero_approx(value):
			continue
		var sign_text := "+" if value > 0.0 else "−"
		var magnitude: String = ("$%d" % int(abs(value))) if bool(row["money"]) \
			else ("%.1f" % absf(value))
		lines.append("%s %s%s" % [key, sign_text, magnitude])
	if bool(result.get("banned", false)):
		lines.append("You are not welcome back there.")
	if bool(result.get("arrested", false)):
		lines.append("You are under arrest.")
	if lines.is_empty():
		lines.append("Nothing you can point at. This time.")
	return lines

## The cash-versus-time decision. PX-003 §6: the player reads the quote, their
## own cash, their prior count, and the exact time each lane costs BEFORE
## committing — the $150 shortfall conversion stays underneath.
const BOOKING_LABELS := {
	"full_bail": "POST FULL BAIL",
	"all_cash": "PUT UP WHAT YOU HAVE",
	"serve_time": "SERVE IT",
}

func _build_booking() -> void:
	var booking: Dictionary = _engine.booking_summary()
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(label("BOOKING", "Muted", 11, MUTED))
	if booking.is_empty():
		v.add_child(label("They are still writing it up.", "Muted", 12, MUTED))
		c.add_child(v)
		body.add_child(c)
		return

	v.add_child(label("YOU'RE IN", "CardTitle", 15, CREAM))
	v.add_child(label(_booking_context(booking), "Muted", 11, MUTED))
	v.add_child(label("The move is over. Now the choice is how much cash you are "
		+ "willing to trade for time.", "Muted", 12, MUTED, true))
	v.add_child(_quote_row("Bail", "$%d" % int(booking.get("bail_quote", 0)), CREAM))
	v.add_child(_quote_row("Cash", "$%d" % int(booking.get("cash_on_hand", 0)), CREAM))
	v.add_child(_quote_row("Priors", str(int(booking.get("priors_at_quote", 0))), MUTED))
	c.add_child(v)
	body.add_child(c)

	# The first booking carries PX-003 §6's one-time reminder that the world does
	# not pause. Later ones do not repeat it.
	if int(booking.get("priors_at_quote", 0)) == 0:
		body.add_child(note("Time keeps moving while you're in. Anything scheduled "
			+ "during those slots still settles."))

	body.add_child(label("HOW YOU GET OUT", "Muted", 11, MUTED))
	for entry in (booking.get("choices", []) as Array):
		var row: Dictionary = entry
		if not bool(row.get("available", false)) and not bool(row.get("committed", false)):
			continue
		body.add_child(_booking_row(row))

func _booking_context(booking: Dictionary) -> String:
	var family := str(booking.get("source_family", "")).to_upper()
	var severity := str(booking.get("severity_label", "")).to_upper()
	return "%s · %s · PRIOR RECORD %d" % [family, severity,
		int(booking.get("priors_at_quote", 0))]

func _booking_row(row: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var choice_id := str(row["choice_id"])
	v.add_child(label(str(BOOKING_LABELS.get(choice_id, choice_id.to_upper())),
		"CardTitle", 14, CREAM))
	v.add_child(label(_booking_terms(row), "Mono", 12,
		GREEN if int(row["cash_cost"]) == 0 else AMBER))
	v.add_child(label("Out DAY %d · %s" % [int(row["release_day"]),
		str(row["release_slot_name"])], "Muted", 11, MUTED))
	var b := Button.new()
	b.theme_type_variation = &"BtnPrimary"
	b.custom_minimum_size = Vector2(0, 46)
	b.text = "COMMITTED" if bool(row["committed"]) else str(
		BOOKING_LABELS.get(choice_id, choice_id.to_upper()))
	b.disabled = bool(row["disabled"])
	if not b.disabled:
		b.pressed.connect(_commit_booking.bind(choice_id))
	v.add_child(b)
	c.add_child(v)
	return c

func _booking_terms(row: Dictionary) -> String:
	var cost: int = int(row["cash_cost"])
	var slots: int = int(row["slots"])
	var money: String = "Pay $0" if cost <= 0 else "Pay $%d" % cost
	return "%s · %d slot%s" % [money, slots, "" if slots == 1 else "s"]

func _commit_booking(choice_id: String) -> void:
	var summary: Dictionary = _engine.active_summary()
	_gm.dispatch("resolve_booking_choice", {
		"consequence_id": str(summary.get("consequence_id", "")),
		"cause_id": str(summary.get("cause_id", "")),
		"choice_id": choice_id,
	})

func _quote_row(key: String, value: String, tone: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var k := label(key, "Muted", 12, MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(label(value, "Mono", 13, tone))
	return h

## The receipt, and the way out. PX-003 §6: one concise summary, and the systems
## that owned whatever happened during those slots keep their own presentation —
## this does not re-narrate a bill or a wage.
func _build_release() -> void:
	var booking: Dictionary = _engine.booking_summary()
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(label("RELEASED", "Muted", 11, MUTED))
	v.add_child(label("YOU'RE OUT", "CardTitle", 15, CREAM))
	if not booking.is_empty():
		var paid: int = int(booking.get("paid", 0))
		v.add_child(label("Paid $%d." % paid if paid > 0 else "You served it.",
			"Mono", 13, CREAM))
		var slots: int = int(booking.get("slots_served", 0)) \
			+ int(booking.get("source_slots_settled", 0))
		v.add_child(_quote_row("Time gone", "%d slot%s" % [slots,
			"" if slots == 1 else "s"], MUTED))
		var relief: float = float(booking.get("heat_relief_applied", 0.0))
		if relief > 0.0:
			v.add_child(_quote_row("Heat", "−%.1f" % relief, GREEN))
		v.add_child(_quote_row("Priors", str(int(booking.get("priors_after", 0))), AMBER))
		# PX-003 §9: a loud payment gets a traceable receipt. The Financial
		# Pressure score itself stays hidden — this is the situation, not the
		# meter.
		if int(booking.get("financial_pressure_gain", 0)) > 0:
			v.add_child(label("That payment was loud. Too much street money moved "
				+ "through a formal bill at once.", "Muted", 11, AMBER, true))
	c.add_child(v)
	body.add_child(c)
	body.add_child(_continue_button("BACK TO THE STREET"))

## Continue is the terminal handoff. The dispatch behind it — settling the source
## slot once and clearing the chain — is FS-003.7's; the control exists now so
## the stage scaffolding is complete and testable.
func _continue_button(text: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"BtnPrimary"
	b.text = text
	b.pressed.connect(_continue)
	return b

func _continue() -> void:
	var summary: Dictionary = _engine.active_summary()
	_gm.dispatch("consequence_continue", {
		"consequence_id": str(summary.get("consequence_id", "")),
		"cause_id": str(summary.get("cause_id", "")),
	})

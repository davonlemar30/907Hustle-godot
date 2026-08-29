extends "res://ui/screens/surface_base.gd"
## The blocking consequence scene — TI-003 §18, PX-003 §§3-6.
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
## ## Numbers underneath, situations on top
##
## PX-003's closing line, and the rule this scene is arranged around. The player
## is told what is happening and what each answer risks; they are not shown the
## probability that produced the label, the Pressure score, or the Heat number
## an arrest gate is comparing against. Afterwards they ARE shown exact deltas,
## because what already happened is knowable and hiding it would be coy rather
## than tense.
##
## What that means concretely, and what each rule protects:
##
##   - odds render as bands ("STRONG CHANCE", "DESPERATE"), never as `62%`
##   - arrest warnings say THAT a response can book you, never at what threshold
##   - result deltas are exact, signed, and carry their sign in text as well as
##     in colour
##
## ## Four stages, one scene — and, since 0.6.0, two presentations
##
## `decision` → `result` → `booking` → `release`. Separate scenes would duplicate
## the chrome four times and would make the stage a navigation fact rather than a
## state fact — and stage IS state, because it has to survive a reload.
##
## SQ-D2 changed which of those four normally REACH this scene, not what any of
## them renders. `booking` and `release` still take the whole screen and are the
## ordinary way here; `decision` and `result` ride a `ModalSheet` over whatever
## screen the player was on (`screen_base.gd::_drain_flow_sheets`). This scene
## still builds all four, and a decision reached here directly — a harness, a
## deep link, a future stage split that moves one back — renders exactly what it
## always did, because SQ-D1 put the situation/decision/result builders in
## `ui/components/encounter_sheet.gd` and BOTH presentations call them. There is
## no second copy to drift.
##
## ## Leaving
##
## Every terminal stage ends in exactly one control, and pressing it clears the
## chain. At that moment this scene is showing a consequence that no longer
## exists and has no bottom nav to escape through, so `refresh()` routes out
## rather than rendering an empty state. The destination is the chain's own
## `return_route`, which is why a blown Boost puts the player back on Boost
## rather than generically at Home.

const CYAN := Color(0.475, 0.733, 0.757)
const ORANGE := Color(1.0, 0.29, 0.239)

@onready var _engine: Object = _gm.system("consequence")

## Where Continue lands once the chain is gone. Captured while the chain still
## exists, because by the time the player is leaving there is nothing to ask.
var _return_path: String = ""

func _ready() -> void:
	super()

## The chain's `return_route`, as a scene path.
##
## Sources name where they came from ("BOOST", "STICKUP") so the player lands
## back on the surface they were using rather than generically at Home — losing
## your place is a small cost the game has no reason to charge.
func _route_for(name: String) -> String:
	match name:
		"BOOST": return nav.BOOST
		"STICKUP": return nav.STICKUP
		"MARKET": return nav.MARKET
		"STREET": return nav.STREET
	return nav.HOME

## Where Continue actually lands, once the route gate has had its say.
##
## The return route is a SOURCE's idea of where the player was, and batch 15 put
## five of those surfaces behind route gates. Every one of those gates is
## monotonic, so a surface the player was standing on cannot have re-closed
## underneath them — but "cannot happen today" is not the same as "cannot
## happen", and the failure mode is the worst one available: `go_to("")` is
## silent, so a refused return leaves the player on a dead consequence screen
## with no navigation at all.
##
## So the refusal is checked here rather than trusted. Home is never gated.
func _landing() -> String:
	if not _return_path.is_empty() and not str(nav.resolved_route(_return_path)).is_empty():
		return _return_path
	return nav.HOME

## The chain cleared while this scene was open, which is what Continue does.
##
## `screen_base.refresh()` would render an empty state here and leave the player
## on a screen with no navigation. So this stage is caught before the base gets
## a chance: the run is not blocked any more, and there is somewhere to be.
## `_is_live` guards a case only a harness produces: this scene instantiated
## alongside others rather than AS the current scene. Changing scenes from
## something that is not the screen the player is on would swap the whole tree
## out from under whoever built it.
func refresh() -> void:
	if _is_live() and _engine != null and not gs.game_over and not _engine.has_active():
		nav.go_to(_landing())
		return
	super()

func _is_live() -> bool:
	if nav == null or not is_inside_tree():
		return false
	return get_tree().current_scene == self

func _build_body() -> void:
	if _engine == null:
		body.add_child(label("The moment has passed.", "Muted", 13, MUTED, true))
		return
	var summary: Dictionary = _engine.active_summary()
	if summary.is_empty():
		body.add_child(label("The moment has passed.", "Muted", 13, MUTED, true))
		return
	_return_path = _route_for(str(summary.get("return_route", "")))

	_build_situation(summary)
	match str(summary.get("stage", "")):
		_engine.STAGE_DECISION:
			_build_decision(summary)
		_engine.STAGE_RESULT:
			_build_result(summary)
		_engine.STAGE_BOOKING:
			_build_booking()
		_engine.STAGE_RELEASE:
			_build_release()

# --- the situation, the decision and the result (SQ-D1) ----------------------
#
# All three moved to `ui/components/encounter_sheet.gd` in 0.6.0 and are called
# from there by BOTH presentations. What used to be ~440 lines of builders here
# is now three delegations, and the copy tables, the odds bands, the arrest
# warnings and the delta rows have exactly one owner again.
#
# The builders return Arrays of Controls rather than adding to a parent
# themselves: this screen drops them into its `Body` VBox, and the sheet packs
# the same Controls into a ScrollContainer inside a ModalSheet card. Neither
# knows anything about the other's container, which is the whole reason the
# split is safe.
#
# `ENCOUNTER_SHEET` and `_wire_encounter_button` are both INHERITED from
# `screen_base.gd` and not redeclared here. That is the point: a choice
# committed from the sheet and a choice committed from this screen go through
# one dispatcher, so "committed" cannot come to mean two slightly different
# things depending on which pixels the player tapped.

func _build_situation(summary: Dictionary) -> void:
	for control in ENCOUNTER_SHEET.build_situation(_engine, gs, summary):
		body.add_child(control)

func _build_decision(summary: Dictionary) -> void:
	for control in ENCOUNTER_SHEET.build_decision(_engine, summary,
		_wire_encounter_button):
		body.add_child(control)

func _build_result(summary: Dictionary) -> void:
	for control in ENCOUNTER_SHEET.build_result(_engine, gs, summary,
		_wire_encounter_button):
		body.add_child(control)

# --- booking ----------------------------------------------------------------

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
	v.add_child(label("BOOKING", "Kicker", 10, ORANGE))
	if booking.is_empty():
		v.add_child(label("They are still writing it up.", "Muted", 12, MUTED))
		c.add_child(v)
		body.add_child(c)
		return

	v.add_child(label(_booking_context(booking), "Muted", 11, MUTED))
	v.add_child(_quote_row("Bail", "$%d" % int(booking.get("bail_quote", 0)), CREAM))
	v.add_child(_quote_row("Cash", "$%d" % int(booking.get("cash_on_hand", 0)), CREAM))
	v.add_child(_quote_row("Priors", str(int(booking.get("priors_at_quote", 0))), MUTED))
	c.add_child(v)
	body.add_child(c)

	# PX-003 §6's one-time onboarding line, on the first booking only.
	if int(booking.get("priors_at_quote", 0)) == 0:
		body.add_child(note("Time keeps moving while you're in. Anything scheduled "
			+ "during those slots still settles."))

	body.add_child(section("HOW YOU GET OUT"))
	for entry in (booking.get("choices", []) as Array):
		var row: Dictionary = entry
		if not bool(row.get("available", false)) and not bool(row.get("committed", false)):
			continue
		body.add_child(_booking_row(row))

func _booking_context(booking: Dictionary) -> String:
	var family := str(booking.get("source_family", "")).to_upper()
	var severity := str(booking.get("severity_label", "")).to_upper()
	return "%s  ·  %s  ·  PRIOR RECORD %d" % [family, severity,
		int(booking.get("priors_at_quote", 0))]

func _booking_row(row: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var choice_id := str(row["choice_id"])
	var title := str(BOOKING_LABELS.get(choice_id, choice_id.to_upper()))
	v.add_child(label(title, "CardTitle", 14, CREAM))
	v.add_child(label(_booking_terms(row), "Mono", 12,
		GREEN if int(row["cash_cost"]) == 0 else AMBER))
	v.add_child(label("Out DAY %d · %s" % [int(row["release_day"]),
		str(row["release_slot_name"])], "Muted", 11, MUTED))
	if bool(row["committed"]):
		v.add_child(label("LOCKED IN", "Mono", 11, CYAN))
	if bool(row["disabled"]):
		var inert := Button.new()
		inert.theme_type_variation = &"BtnSecondary"
		inert.text = "COMMITTED" if bool(row["committed"]) else "—"
		inert.disabled = true
		inert.custom_minimum_size = Vector2(0, 46)
		inert.modulate = Color(1, 1, 1, 0.85 if bool(row["committed"]) else 0.45)
		v.add_child(inert)
	else:
		v.add_child(button(title, true, _commit_booking.bind(choice_id), 46))
	c.add_child(v)
	return c

func _booking_terms(row: Dictionary) -> String:
	var cost: int = int(row["cash_cost"])
	var slots: int = int(row["slots"])
	var money: String = "Pay $0" if cost <= 0 else "Pay $%d" % cost
	var after: String = "" if cost <= 0 else "  ·  $%d left" % int(row["cash_after"])
	return "%s  ·  %d slot%s%s" % [money, slots, "" if slots == 1 else "s", after]

func _quote_row(key: String, value: String, tone: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var k := label(key, "Muted", 12, MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(label(value, "Mono", 13, tone))
	return h

func _commit_booking(choice_id: String) -> void:
	var summary: Dictionary = _engine.active_summary()
	_gm.dispatch("resolve_booking_choice", {
		"consequence_id": str(summary.get("consequence_id", "")),
		"cause_id": str(summary.get("cause_id", "")),
		"choice_id": choice_id,
	})

# --- release ----------------------------------------------------------------

## PX-003 §6: one concise summary. The systems that owned whatever happened
## during those slots keep their own presentation — this does not re-narrate a
## bill, a wage or a market move.
func _build_release() -> void:
	var booking: Dictionary = _engine.booking_summary()
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(label("YOU'RE OUT", "CardTitle", 15, CREAM))
	if not booking.is_empty():
		var paid: int = int(booking.get("paid", 0))
		v.add_child(label("You posted it and walked." if paid > 0 else "You served it out.",
			"Muted", 12, MUTED, true))
		v.add_child(_quote_row("DAY %d" % int(gs.day), gs.time_slot, CREAM))
		if paid > 0:
			v.add_child(_quote_row("Paid", "−$%d" % paid, ORANGE))
		var slots: int = int(booking.get("slots_served", 0)) \
			+ int(booking.get("source_slots_settled", 0))
		v.add_child(_quote_row("Time gone", "%d slot%s" % [slots,
			"" if slots == 1 else "s"], ORANGE))
		var relief: float = float(booking.get("heat_relief_applied", 0.0))
		if relief > 0.0:
			v.add_child(_quote_row("Heat", "−%.1f" % relief, GREEN))
		v.add_child(_quote_row("Priors", "%d" % int(booking.get("priors_after", 0)), ORANGE))
	c.add_child(v)
	body.add_child(c)

	# PX-003 §9: a loud payment gets a traceable receipt. The Financial Pressure
	# score itself stays hidden — this is the situation, not the meter.
	if int(booking.get("financial_pressure_gain", 0)) > 0:
		body.add_child(note("That payment was loud. Too much street money moved "
			+ "through a formal bill at once, and that kind of paper trail draws "
			+ "attention for a while."))
	body.add_child(_continue_button("BACK TO THE STREET"))

# --- the way out ------------------------------------------------------------

## Continue is the terminal handoff: it settles whatever time the chain still
## owes, clears the chain, and this scene's `refresh()` takes the player back to
## the surface the chain named.
func _continue_button(text: String) -> Button:
	return button(text, true, _continue, 46)

func _continue() -> void:
	var summary: Dictionary = _engine.active_summary()
	_gm.dispatch("consequence_continue", {
		"consequence_id": str(summary.get("consequence_id", "")),
		"cause_id": str(summary.get("cause_id", "")),
	})

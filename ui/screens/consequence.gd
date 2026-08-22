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
## ## Four stages, one scene
##
## `decision` → `result` → `booking` → `release`. Separate scenes would duplicate
## the chrome four times and would make the stage a navigation fact rather than a
## state fact — and stage IS state, because it has to survive a reload.
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

const RULES := preload("res://data/consequence_rules.gd")

@onready var _engine: Object = _gm.system("consequence")

## Where Continue lands once the chain is gone. Captured while the chain still
## exists, because by the time the player is leaving there is nothing to ask.
var _return_path: String = ""

func _ready() -> void:
	super()

func _rules() -> RefCounted:
	return RULES.new()

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

# --- the situation ----------------------------------------------------------

## PX-003 §3 C-F: kicker, title, cause line, body, stakes. Shared by all four
## stages so the player never loses the thread between a decision and its result.
func _build_situation(summary: Dictionary) -> void:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(label("CONSEQUENCE", "Kicker", 10, ORANGE))
	v.add_child(label(_title(summary), "CardTitle", 17, CREAM))
	var context := _context_line(summary)
	if not context.is_empty():
		v.add_child(label(context, "Muted", 11, MUTED))
	v.add_child(label(_situation_body(summary), "Muted", 13, MUTED, true))

	# The stakes strip. Only values that change the CURRENT decision: the take
	# in dispute, and the two meters a bad answer moves.
	var stakes: Array = []
	var contested: int = int(summary.get("contested_take", 0))
	if contested > 0:
		stakes.append("TAKE $%d" % contested)
	stakes.append("HEALTH %d/%d" % [int(gs.health), int(gs.health_max)])
	stakes.append("HEAT %d/%d" % [gs.heat_shown(), int(gs.heat_max)])
	v.add_child(label("  ·  ".join(stakes), "Mono", 12, AMBER))
	c.add_child(v)
	body.add_child(c)

func _title(summary: Dictionary) -> String:
	match str(summary.get("chain_kind", "")):
		_engine.KIND_BOOST_CAUGHT:
			return "CAUGHT"
		_engine.KIND_STICK_BOOKING:
			return "YOU'RE IN"
		_engine.KIND_RETALIATION:
			return "THEY WERE WAITING"
		_engine.KIND_WANDER:
			return "SOMEBODY STOPS YOU"
	return "THIS IS HAPPENING NOW"

## PX-003 §3 D: connects the current problem to the action that made it, without
## ever exposing a Cause ID.
func _context_line(summary: Dictionary) -> String:
	var parts: Array = []
	match str(summary.get("chain_kind", "")):
		_engine.KIND_BOOST_CAUGHT:
			parts.append("BOOST")
			var opponent := str(summary.get("source_opponent", ""))
			if not opponent.is_empty():
				parts.append(opponent.to_upper())
		_engine.KIND_STICK_BOOKING:
			parts.append("STICK UP")
		_engine.KIND_RETALIATION:
			parts.append(str(summary.get("source_target_name", "SOMEBODY")).to_upper())
		_engine.KIND_WANDER:
			parts.append("ON FOOT")
			var who := str(summary.get("source_opponent", ""))
			if not who.is_empty():
				parts.append(who.to_upper())
	var district := str(summary.get("district_id", ""))
	if not district.is_empty():
		parts.append(str(gs.district_by_id(district).get("name", "")).to_upper())
	return "  ·  ".join(parts)

## PX-003 §4: one or two short sentences naming what is happening in the world.
## The opponent's own tier decides the line, because a clerk and an armed guard
## are not the same situation.
func _situation_body(summary: Dictionary) -> String:
	match str(summary.get("chain_kind", "")):
		_engine.KIND_BOOST_CAUGHT:
			match int(summary.get("source_target_tier", 1)):
				1: return "The clerk caught the move before you made the door. The take is still in play."
				2: return "Store security cuts you off at the exit. You still have the merchandise."
			return "The guard sees the lift and closes the distance before you clear the room."
		_engine.KIND_STICK_BOOKING:
			return "The move is over. Now the choice is how much cash you are willing to trade for time."
		_engine.KIND_RETALIATION:
			return "%s tracked it back to you. They found you before the neighborhood forgot." \
				% str(summary.get("source_target_name", "Somebody"))
		_engine.KIND_WANDER:
			# Wander's own cards carry their opening line into the feed already,
			# so this is the body of the moment rather than a second retelling
			# of how it started.
			return "You went out to see what was around. This is what was around."
	return "Somebody is waiting on an answer."

# --- decision ---------------------------------------------------------------

## PX-003 §4's response lanes. One card each: the name, what it is for, the
## qualitative odds, the arrest warning where one applies, and one full-width
## action.
##
## Order is the order the chain declares, which is stable across encounters —
## PX-003 §16 asks for "stable vertical ordering for Fight, Run, Talk, Yield" so
## the vocabulary becomes something the player learns rather than re-reads.
const CHOICE_COPY := {
	"fight": "Highest upside. Win and you leave with it. Losing costs blood.",
	"run": "Keep it if you get clear. A bad escape costs the take and worse.",
	"talk": "Hand it back and try to keep this from turning physical.",
	"yield": "Give it back and stop the escalation here.",
}

## PX-003 §4 and §19 point 8. Says THAT a response can book you; never at what
## number, and never which tier.
const ARREST_WARNINGS := {
	"on_loss": "IF THIS GOES WRONG, THEY BOOK YOU",
	"worst_only": "THE WORST OUTCOME HERE ENDS IN CUFFS",
	"heat": "HIGH HEAT: A FAILED RUN CAN BOOK YOU",
	"target": "THIS TARGET CAN TURN A FAILED RUN INTO BOOKING",
}

func _build_decision(_summary: Dictionary) -> void:
	var rows: Array = _engine.choice_summaries()
	if rows.is_empty():
		body.add_child(label("No way out of this one.", "Muted", 13, MUTED, true))
		return
	body.add_child(section("HOW DO YOU PLAY IT"))
	for entry in rows:
		body.add_child(_choice_card(entry))

func _choice_card(row: Dictionary) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var choice_id := str(row["choice_id"])
	var committed: bool = bool(row["committed"])

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var name_label := label(str(row["label"]).to_upper(), "CardTitle", 14,
		CREAM if not bool(row["disabled"]) or committed else MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(label(_odds_text(row), "Mono", 12, _odds_tone(row)))
	v.add_child(head)

	# Through the engine's adapter seam, so a chain kind with its own vocabulary
	# says its own words. `CHOICE_COPY` below is the default and still covers
	# the three original kinds; a blank here was a shipped defect for Wander,
	# whose five choice ids are in none of them.
	v.add_child(label(_engine.choice_description(choice_id,
		str(CHOICE_COPY.get(choice_id, ""))), "Muted", 11, MUTED, true))

	# Yield's whole value is certainty, so it states its guaranteed price rather
	# than an odds band (PX-003 §4: "Yield has no probability treatment").
	if bool(row.get("deterministic", false)):
		v.add_child(label("Guaranteed: no injury, no Heat, no arrest.", "Muted", 11, CYAN, true))

	var warning := str(ARREST_WARNINGS.get(str(row.get("arrest_risk", "")), ""))
	if not warning.is_empty():
		v.add_child(label(warning, "Mono", 11, ORANGE, true))

	# PX-003 §15 and §16: the committed choice stays visibly selected and every
	# lane goes inert. The lock is a LABEL as well as a state, because a dimmed
	# button and a disabled button look the same and mean different things.
	if committed:
		v.add_child(label("LOCKED IN", "Mono", 11, CYAN))
	if bool(row["disabled"]):
		var inert := Button.new()
		inert.theme_type_variation = &"BtnSecondary"
		inert.text = "COMMITTED" if committed else "—"
		inert.disabled = true
		inert.custom_minimum_size = Vector2(0, 46)
		inert.modulate = Color(1, 1, 1, 0.85 if committed else 0.45)
		v.add_child(inert)
	else:
		v.add_child(button(str(row["label"]).to_upper(), true,
			_commit.bind(choice_id), 46))
	c.add_child(v)
	return c

## Qualitative, always. FS-003.11's brief is explicit that raw percentages do not
## reach the player: the projection API produces an exact probability, and the
## authored bands in `consequence_rules.gd` turn it into something a person can
## act on.
##
## This is a DIVERGENCE from PX-003 §4, which sketches `[chance]%` on the
## response cards. It is deliberate and is recorded in HANDOFF.md and the design
## log rather than silently chosen.
func _odds_text(row: Dictionary) -> String:
	if bool(row.get("deterministic", false)):
		return _rules().ODDS_CERTAIN
	if not bool(row.get("has_odds", false)):
		return "—"
	return _rules().odds_label(float(row["success_probability"]))

func _odds_tone(row: Dictionary) -> Color:
	if bool(row.get("deterministic", false)):
		return CYAN
	if not bool(row.get("has_odds", false)):
		return MUTED
	match _rules().odds_rank(float(row["success_probability"])):
		4, 3: return GREEN
		2: return AMBER
	return RED

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

# --- result -----------------------------------------------------------------

## PX-003 §5: the lived result first, the resolver tier never. "You kept the
## take" is what happened; "messy" is internal vocabulary.
func _build_result(summary: Dictionary) -> void:
	var result: Dictionary = _engine.result_summary()
	var effects: Dictionary = result.get("result", {})
	var tier := str(result.get("resolved_tier", ""))
	var choice := str(result.get("committed_choice", ""))
	var arrested: bool = bool(effects.get("arrested", false))

	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(label(_result_headline(summary, choice, tier, effects),
		"CardTitle", 15, _tier_tone(tier)))
	v.add_child(label(_result_body(summary, choice, tier, effects), "Muted", 12, MUTED, true))
	c.add_child(v)
	body.add_child(c)

	# The deltas, one row each, exact and signed.
	var deltas: Array = _delta_rows(effects)
	if not deltas.is_empty():
		var d := card()
		var dv := VBoxContainer.new()
		dv.add_theme_constant_override("separation", 4)
		dv.add_child(label("WHAT IT COST", "Kicker", 10, MUTED))
		for entry in deltas:
			dv.add_child(_delta_row(entry))
		d.add_child(dv)
		body.add_child(d)

	if arrested:
		body.add_child(note("The store is done with you and police take over from here."))
	body.add_child(_continue_button("BOOKING" if arrested else "CONTINUE"))

func _result_headline(summary: Dictionary, choice: String, tier: String,
		effects: Dictionary) -> String:
	if str(summary.get("chain_kind", "")) == _engine.KIND_RETALIATION:
		if int(effects.get("cash", 0)) < 0:
			return "THEY GOT PAID"
		if tier in ["clean", "messy"]:
			return "YOU HELD ONTO IT"
		return "THEY FOUND NOTHING"
	if choice == "yield":
		return "YOU GAVE IT BACK"
	var kept: bool = int(effects.get("cash", 0)) + int(effects.get("goods", 0)) > 0
	if bool(effects.get("arrested", false)):
		return "IT ENDS IN CUFFS"
	if kept and int(effects.get("health", 0)) < 0:
		return "YOU KEPT IT. YOU PAID FOR IT."
	if kept:
		return "YOU KEPT THE TAKE"
	if tier in ["clean", "messy"]:
		return "YOU TALKED IT DOWN"
	return "YOU DIDN'T GET FAR"

func _result_body(summary: Dictionary, choice: String, tier: String,
		effects: Dictionary) -> String:
	if str(summary.get("chain_kind", "")) == _engine.KIND_RETALIATION:
		if int(effects.get("cash", 0)) < 0:
			return "They take what they came for and go."
		return "They leave without what they came for. That is not the end of it."
	if choice == "yield":
		return "You lose the take and stop the situation from climbing any higher."
	if bool(effects.get("banned", false)) and not bool(effects.get("arrested", false)):
		return "The merchandise goes back. The store is finished dealing with you."
	if tier in ["clean", "messy"]:
		return "You get through them and make the exit."
	return "The take is gone and the room remembers your face."

func _tier_tone(tier: String) -> Color:
	match tier:
		"clean": return GREEN
		"messy": return AMBER
		"catastrophic": return RED
		"deterministic": return CYAN
	return MUTED

## Exact deltas, one line each. TI-003 §18: "Result stage shows narrative plus
## exact changes to Cash, goods, Health, Heat, bans, and arrest state."
##
## Driven off a declared table rather than a chain of ifs so a later slice adds a
## row by adding a row. `money` decides the format; `good` decides which
## direction of the value counts as good news, because +2.0 Heat and +$45 are
## opposite kinds of news and colour alone must never be what says so.
const RESULT_ROWS := [
	{"key": "cash", "label": "Cash", "money": true, "good": 1},
	{"key": "goods", "label": "Merchandise", "money": true, "good": 1},
	{"key": "health", "label": "Health", "money": false, "good": 1},
	{"key": "heat", "label": "Heat", "money": false, "good": -1},
	{"key": "pressure", "label": "Local attention", "money": false, "good": -1},
]

func _delta_rows(effects: Dictionary) -> Array:
	var rows: Array = []
	for spec in RESULT_ROWS:
		var row: Dictionary = spec
		if not effects.has(row["key"]):
			continue
		var value: float = float(effects[row["key"]])
		if is_zero_approx(value):
			continue
		rows.append({
			"label": str(row["label"]),
			# PX-003 §16: "redundant labels alongside color". The sign is in the
			# TEXT, so the row reads correctly with no colour perception at all.
			"text": ("+" if value > 0.0 else "−") + (("$%d" % int(abs(value)))
				if bool(row["money"]) else ("%.1f" % absf(value))),
			"good": (value > 0.0) == (int(row["good"]) > 0),
		})
	if bool(effects.get("banned", false)):
		rows.append({"label": "Store access", "text": "BLOCKED", "good": false})
	return rows

func _delta_row(entry: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var k := label(str(entry["label"]), "Muted", 12, MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(label(str(entry["text"]), "Mono", 13,
		GREEN if bool(entry["good"]) else ORANGE))
	return h

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

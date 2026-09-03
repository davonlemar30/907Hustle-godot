extends RefCounted
## EncounterSheet — the one builder for what a consequence chain looks like.
##
## SQ-D1. Until 0.6.0 every chain rendered through `ui/screens/consequence.gd`
## and nowhere else, so "what a chain looks like" and "the screen a chain takes
## over" were the same fact. SQ-D2 splits them: `decision` and `result` now ride
## a `ModalSheet` over whatever screen the player was on, and `booking` and
## `release` keep the full-screen scene. Two presentations of one chain is two
## places to drift, so the situation/decision/result builders were lifted out of
## the screen and put here, and BOTH callers consume them. The screen is now a
## thin caller; nothing about what it renders moved.
##
## ## The `flow_sheets.gd` pattern, deliberately
##
## Static builders, no `class_name` (the stale-cache gotcha), preloaded by each
## caller. Everything is resolved at BUILD time from the engine's summary calls
## — `active_summary()`, `choice_summaries()`, `result_summary()`,
## `loop_summary()` — and never from `gs.active_consequence`. That is the same
## rule `consequence.gd` was written under and it is what makes SQ-D4 free: a
## reload rebuilds these pixels from the persisted chain because the pixels were
## never anything but a projection of it.
##
## ## Buttons are wired by the caller, not here
##
## Both callers put this content inside a ScrollContainer, so neither may use
## `pressed` (TOUCH-D3a/TOUCH-D5: a `pressed` connection fires at the end of a
## scroll drag, and a STOP control swallows the gesture the scroll needed). Each
## builder therefore takes a `wire: Callable` of the shape
## `wire(button: Button, action: String, choice_id: String)` — the caller reads
## the action and binds whatever handler it means on ITS side, through
## `screen_base.tap_connect`. The screen and the sheet pass the SAME method
## today; the seam exists so a harness can build this content with no dispatch
## behind it at all, which is how the smoke suite covers it.
##
## ## SQ-D12: the odds do not reach the player at all
##
## Owner ruling, 2026-08-29, taken against a shipped screenshot: **"all of these
## hints can be removed. Dang give the player some mystery."** Every response
## lane used to carry a qualitative band — STRONG CHANCE / FAIR CHANCE / RISKY /
## BAD ODDS / DESPERATE — beside its name. They are gone.
##
## This NARROWS a standing position rather than contradicting one. FS-003.11 and
## PX-003 §4 ruled that raw percentages must never reach the player and that
## bands were how odds would reach them instead; the first half is untouched and
## the second is now "they do not reach them." The lane is its name and what it
## is for, and the player finds out the rest by doing it.
##
## **What deliberately stayed**, because neither is an odds hint:
##
##   - the **arrest warnings** (PX-003 §19 point 8). They say THAT a road can
##     book you, never at what threshold — a category of risk, not a number.
##     Withholding those would be hiding a rule rather than a probability.
##   - the **guarantee line** under a deterministic road. That is a PRICE, and a
##     price is knowable before you pay it. It is also load-bearing: SQ-D6 made
##     the guaranteed out structural rather than cheap, and one card
##     (`wander_warrant_check`) makes it the WORST road on purpose.
##
## The projection API is untouched. `choice_summaries()` still returns
## `success_probability` and `has_odds`, `consequence_rules.gd` still authors
## `ODDS_BANDS`, and the parity suite still pins every band boundary. Nothing
## renders any of it. That is a deliberate keep rather than an oversight: the
## mapping is authored, oracle-adjacent and fixture-covered, and a later build
## that wants a difficulty setting or a read-the-room perk has the table sitting
## ready. `consequence_rules.gd`'s own header says so at the table.
##
## ## Colours and builders are duplicated from `surface_base.gd`, on purpose
##
## `surface_base.gd` is a Control script — a screen's base class. This file is a
## RefCounted with no node of its own, so it cannot inherit those helpers, and
## making it a Control just to borrow five functions would put a node in the
## tree that renders nothing. The values are asserted equal to the screen's in
## the confrontation suite, the same discipline `wander_events.gd`'s duplicated
## STASH IT label already ships under.

const CONF_SCRIPTS := preload("res://data/confrontation_scripts.gd")
const HEALTH_BAR := preload("res://ui/components/health_bar.gd")

const CYAN := Color(0.475, 0.733, 0.757)
const ORANGE := Color(1.0, 0.29, 0.239)
const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)
const MUTED := Color(0.608, 0.608, 0.608)
const CREAM := Color(0.949, 0.941, 0.922)

# --- SQ-D2: which stages ride the sheet --------------------------------------
#
# The one owner of the split, read by `ScreenManager.blocking_route()` (and so
# by `resolved_route()`, the boot/CONTINUE path, and the flow-sheet drain's own
# guard — all three of blocking_route's readers) and by
# `screen_base.gd::_drain_flow_sheets`. A presentation policy, so it lives with
# the presentation rather than in the engine: the ENGINE's stages are a state
# machine and have no opinion about pixels.
#
# Decision and result are the street answering back — the player is mid-walk and
# the street should stay visible behind it. Booking and release are not: an
# arrest genuinely IS a takeover, the booking terms are long-form, and release is
# where a run's shape changes.

const SHEET_STAGES: Array[String] = ["decision", "result"]

static func stage_rides_sheet(stage: String) -> bool:
	return stage in SHEET_STAGES

# --- the whole sheet ---------------------------------------------------------

## Everything a decision- or result-stage chain renders, packed for a
## `ModalSheet`. Returns null when there is nothing live to show, which is the
## drain's signal that this is not a moment for an encounter sheet after all.
##
## The ScrollContainer is not decoration: a three-choice decision with a round
## log is taller than the 375x812 viewport leaves under a bottom sheet, and a
## card that overflows a phone screen has its last choice off the bottom edge
## with nothing to say so.
static func build_sheet(engine: Object, gs: Node, wire: Callable) -> Control:
	if engine == null or not engine.has_active():
		return null
	var summary: Dictionary = engine.active_summary()
	if summary.is_empty():
		return null
	var stage := str(summary.get("stage", ""))
	if not stage_rides_sheet(stage):
		return null

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	for control in build_situation(engine, gs, summary):
		inner.add_child(control)
	match stage:
		"decision":
			for control in build_decision(engine, summary, wire):
				inner.add_child(control)
		"result":
			for control in build_result(engine, gs, summary, wire):
				inner.add_child(control)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 62% of the viewport: tall enough that a three-lane decision reads without
	# scrolling at all on most cards, short enough that the street behind the
	# sheet is never fully covered — SQ-D1's whole point is that it stays
	# visible.
	scroll.custom_minimum_size = Vector2(0, mini(SHEET_MAX_HEIGHT,
		int(_viewport_height(gs) * SHEET_HEIGHT_FRACTION)))
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 14)
	pad.add_child(scroll)
	return pad

const SHEET_HEIGHT_FRACTION := 0.62
const SHEET_MAX_HEIGHT := 560

## The viewport's height, or the design height when there is no tree to ask
## (every headless suite). 812 is the design target this whole build is drawn
## against, so the fallback is the real number rather than a guess.
static func _viewport_height(gs: Node) -> float:
	if gs != null and gs.is_inside_tree():
		var rect: Rect2 = gs.get_viewport().get_visible_rect()
		if rect.size.y > 0.0:
			return rect.size.y
	return 812.0

# --- the situation ----------------------------------------------------------

## PX-003 §3 C-F: kicker, title, cause line, body, stakes. Shared by all four
## stages so the player never loses the thread between a decision and its result.
##
## SQ-D5: HEALTH has graduated out of the text stakes strip into
## `health_bar.gd`. The strip keeps STAGE/#LEFT/BANKED/HEAT — the numbers a
## player reads once — and the bar carries the one number that MOVES while they
## are looking at it.
static func build_situation(engine: Object, gs: Node, summary: Dictionary) -> Array:
	var out: Array = []
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	# BB-D2 (0.7.0): the WHO is the headline. The kind's own phrase (SOMEBODY
	# STOPS YOU, CAUGHT, CHECKPOINT) moves up into the kicker, where the word
	# CONSEQUENCE used to sit -- the engine's name for itself, which the player
	# was never meant to read.
	v.add_child(_label(kicker_for(engine, summary), "Kicker", 10, ORANGE))
	v.add_child(_label(headline_for(engine, summary), "CardTitle", 17, CREAM))
	var context := context_line(engine, gs, summary)
	if not context.is_empty():
		v.add_child(_label(context, "Muted", 11, MUTED))
	v.add_child(_label(situation_body(engine, summary), "Muted", 13, MUTED, true))

	# SQ-D5's bar, on every stage. Ahead of the strip because it is the thing
	# the player is watching when a round lands.
	v.add_child(HEALTH_BAR.new().bind(gs))

	# The stakes strip. Only values that change the CURRENT decision: the take
	# in dispute, and the meter a bad answer moves.
	#
	# A loop chain swaps the static take for the live pair that IS its
	# decision — what is already banked against what is still on the table —
	# plus the round counter and the #LEFT chip, which are the chassis's two
	# promises: this ends, and they are people.
	var stakes: Array = []
	var loop: Dictionary = engine.loop_summary()
	var contested: int = int(summary.get("contested_take", 0))
	if not loop.is_empty():
		stakes.append("STAGE %d/%d" % [int(loop.get("stage", 0)) + 1,
			maxi(1, int(loop.get("stage_count", 1)))])
		stakes.append("%s %d" % [str(loop.get("left_label", "LEFT")),
			int(loop.get("left", 0))])
		# BB-D5 (0.7.0): money only when it is money. A street fight banks
		# health, not dollars, and printed BANKED $0 through three rounds of it.
		if bool(loop.get("banks_cash", false)):
			stakes.append("BANKED $%d" % int(loop.get("banked", 0)))
	elif contested > 0:
		stakes.append("TAKE $%d" % contested)
	stakes.append("HEAT %d/%d" % [gs.heat_shown(), int(gs.heat_max)])
	# `wrap`: a loop chain's strip ("STAGE 2/5  ·  IN YOUR WAY 3  ·  BANKED
	# $340  ·  HEAT 5/15") routinely exceeds the card's width at this font
	# size. Unwrapped, a Label reports its full unbroken text as its minimum
	# size, which drags every ancestor up to Shell wider than the viewport —
	# the strip does not clip, the whole screen shifts.
	v.add_child(_label("  ·  ".join(stakes), "Mono", 12, AMBER, not loop.is_empty()))
	c.add_child(v)
	out.append(c)

	# The round log — the last few beats, oldest first, so the moment carries
	# its own short memory of how it got here. Decision stage only: the result
	# stage already tells the ending its own way.
	if not loop.is_empty() and str(summary.get("stage", "")) == "decision":
		var log_lines: Array = loop.get("log", [])
		if not log_lines.is_empty():
			var lc := _card()
			var lv := VBoxContainer.new()
			lv.add_theme_constant_override("separation", 3)
			lv.add_child(_label("SO FAR", "Kicker", 10, MUTED))
			for line in log_lines:
				lv.add_child(_label(str(line), "Muted", 11, MUTED, true))
			lc.add_child(lv)
			out.append(lc)
	return out

## BB-D2: who is in front of you, or "" when the chain has nobody named.
static func opponent_for(summary: Dictionary) -> String:
	var who := str(summary.get("source_opponent", ""))
	if who.is_empty():
		who = str(summary.get("source_target_name", ""))
	return who

## The kicker: the kind's own phrase when there is somebody to headline,
## otherwise a plain marker so the title below can carry the phrase itself.
static func kicker_for(engine: Object, summary: Dictionary) -> String:
	if opponent_for(summary).is_empty():
		return "RIGHT NOW"
	return title_for(engine, summary)

## The title: the opponent, in caps, or the kind's phrase when nobody is named.
static func headline_for(engine: Object, summary: Dictionary) -> String:
	var who := opponent_for(summary)
	if who.is_empty():
		return title_for(engine, summary)
	return who.to_upper()

static func title_for(engine: Object, summary: Dictionary) -> String:
	match str(summary.get("chain_kind", "")):
		engine.KIND_BOOST_CAUGHT:
			return "CAUGHT"
		engine.KIND_STICK_BOOKING:
			return "YOU'RE IN"
		engine.KIND_STICK_CAUGHT:
			return "CAUGHT"
		engine.KIND_RETALIATION:
			return "THEY WERE WAITING"
		engine.KIND_WANDER:
			return "SOMEBODY STOPS YOU"
		engine.KIND_TRAVEL_STOP:
			return "CHECKPOINT"
		engine.KIND_CONFRONTATION:
			# The room's own authored name — "THE GAME", "THE NIGHT TILL" —
			# because a confrontation is a place the player chose to walk into,
			# not a thing that happened to them.
			var loop: Dictionary = engine.loop_summary()
			var sheet := str(loop.get("sheet_title", ""))
			return sheet if not sheet.is_empty() else "THIS IS HAPPENING NOW"
	return "THIS IS HAPPENING NOW"

## PX-003 §3 D: connects the current problem to the action that made it, without
## ever exposing a Cause ID.
static func context_line(engine: Object, gs: Node, summary: Dictionary) -> String:
	var parts: Array = []
	match str(summary.get("chain_kind", "")):
		engine.KIND_BOOST_CAUGHT:
			parts.append("BOOST")
			var opponent := str(summary.get("source_opponent", ""))
			if not opponent.is_empty():
				parts.append(opponent.to_upper())
		engine.KIND_STICK_BOOKING:
			parts.append("STICK UP")
		engine.KIND_STICK_CAUGHT:
			parts.append("STICK UP")
			parts.append(str(summary.get("source_target_name", "")).to_upper())
		engine.KIND_RETALIATION:
			parts.append(str(summary.get("source_target_name", "SOMEBODY")).to_upper())
		engine.KIND_WANDER:
			parts.append("ON FOOT")
			var who := str(summary.get("source_opponent", ""))
			if not who.is_empty():
				parts.append(who.to_upper())
		engine.KIND_TRAVEL_STOP:
			# No target-name append here: `source_target_name` is the
			# destination's own display name, which the universal district
			# suffix below already supplies (the chain's `district_id` IS the
			# destination) -- appending it twice would just repeat the word.
			parts.append("EN ROUTE")
		engine.KIND_CONFRONTATION:
			# Named by family so the Lift and the corner scripts inherit this
			# line the day they arrive on the same kind.
			var family := str(summary.get("source_family", ""))
			parts.append("STICK UP" if family == "stick" else family.to_upper())
			parts.append(str(summary.get("source_target_name", "")).to_upper())
	var district := str(summary.get("district_id", ""))
	if not district.is_empty():
		parts.append(str(gs.district_by_id(district).get("name", "")).to_upper())
	# BB-D2: whoever is now the headline does not repeat one line under it.
	var head := headline_for(engine, summary)
	var kept: Array = []
	for part in parts:
		if str(part).to_upper() != head:
			kept.append(part)
	return "  ·  ".join(kept)

## PX-003 §4: one or two short sentences naming what is happening in the world.
## The opponent's own tier decides the line, because a clerk and an armed guard
## are not the same situation.
static func situation_body(engine: Object, summary: Dictionary) -> String:
	# A live beat outranks the kind's own standing line, on EVERY kind.
	#
	# This used to be inside the KIND_CONFRONTATION arm below, which was
	# correct while the confrontation chain was the only one that ran a room.
	# The wander shakedown's room (SQ-D7) is the second, and it rendered all
	# three of its authored beats under "You went out to see what was around"
	# — the card's standing opener, still true and no longer what is
	# happening. Found on the real build: the STAGE 3/3 chip and the round log
	# were both correct on screen while the situation above them was not.
	#
	# Hoisted rather than duplicated into a second arm, because "the situation
	# IS the current beat" is what the round rule means on screen and it is not
	# a fact about any one chain kind.
	var beat := str(engine.loop_summary().get("beat", ""))
	if not beat.is_empty():
		return beat
	match str(summary.get("chain_kind", "")):
		engine.KIND_BOOST_CAUGHT:
			match int(summary.get("source_target_tier", 1)):
				1: return "The clerk caught the move before you made the door. The take is still in play."
				2: return "Store security cuts you off at the exit. You still have the merchandise."
			return "The guard sees the lift and closes the distance before you clear the room."
		engine.KIND_STICK_BOOKING:
			return "The move is over. Now the choice is how much cash you are willing to trade for time."
		engine.KIND_STICK_CAUGHT:
			return "Blue and reds behind you before you're two blocks clear. The robbery already happened — this is what it costs."
		engine.KIND_RETALIATION:
			return "%s tracked it back to you. They found you before the neighborhood forgot." \
				% str(summary.get("source_target_name", "Somebody"))
		engine.KIND_WANDER:
			# BB-D2 (0.7.0): the card's own line IS the moment. It used to go
			# only to the activity feed -- which is behind the sheet, where the
			# player cannot read it -- while every one of twelve cards opened
			# on the same standing sentence. A card with no opener is an
			# authoring bug the confrontation suite catches; the engine's own
			# last line below is what it would show meanwhile.
			var opener := str(summary.get("source_opener", ""))
			if not opener.is_empty():
				return opener
		engine.KIND_TRAVEL_STOP:
			return "Lights come up behind you before you clear the line. This is the toll for moving while they're watching."
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
}

static func build_decision(engine: Object, _summary: Dictionary, wire: Callable) -> Array:
	var out: Array = []
	var rows: Array = engine.choice_summaries()
	if rows.is_empty():
		out.append(_label("No way out of this one.", "Muted", 13, MUTED, true))
		return out
	out.append(_section("HOW DO YOU PLAY IT"))
	for entry in rows:
		out.append(_choice_card(engine, entry, wire))
	return out

static func _choice_card(engine: Object, row: Dictionary, wire: Callable) -> Control:
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var choice_id := str(row["choice_id"])
	var committed: bool = bool(row["committed"])

	# SQ-D12: no odds chip. The lane is its name and what it is for, and the
	# player finds out the rest by doing it.
	v.add_child(_label(str(row["label"]).to_upper(), "CardTitle", 14,
		CREAM if not bool(row["disabled"]) or committed else MUTED))

	# Through the engine's adapter seam, so a chain kind with its own vocabulary
	# says its own words. `CHOICE_COPY` above is the default and still covers
	# the three original kinds.
	v.add_child(_label(engine.choice_description(choice_id,
		str(CHOICE_COPY.get(choice_id, ""))), "Muted", 11, MUTED, true))

	# The one thing that survives SQ-D12, and the reason it survives: a
	# guaranteed road is not a probability the player is being denied, it is a
	# PRICE, and a price is knowable before you pay it. PX-003 §4 already said
	# "Yield has no probability treatment" — that was true when there were odds
	# to withhold and it is still true now that there are none.
	if bool(row.get("deterministic", false)):
		v.add_child(_label(engine.choice_guarantee(choice_id,
			"Guaranteed: no injury, no Heat, no arrest."), "Muted", 11, CYAN, true))

	var warning := str(ARREST_WARNINGS.get(str(row.get("arrest_risk", "")), ""))
	if not warning.is_empty():
		v.add_child(_label(warning, "Mono", 11, ORANGE, true))

	# PX-003 §15 and §16: the committed choice stays visibly selected and every
	# lane goes inert. The lock is a LABEL as well as a state, because a dimmed
	# button and a disabled button look the same and mean different things.
	if committed:
		v.add_child(_label("LOCKED IN", "Mono", 11, CYAN))
	if bool(row["disabled"]):
		var inert := Button.new()
		inert.theme_type_variation = &"BtnSecondary"
		# Three reasons a lane can be inert, and only one is silent: locked in
		# is its own label above, some OTHER lane being committed says nothing
		# about THIS one so a dash is honest, and a choice blocked on its own
		# terms (a bribe short of its price) says so rather than pretending to
		# be the same case as a plain "not what you picked".
		var blocked_reason := str(row.get("blocked_reason", ""))
		if committed:
			inert.text = "COMMITTED"
		elif not blocked_reason.is_empty():
			inert.text = blocked_reason
		else:
			inert.text = "—"
		inert.disabled = true
		inert.custom_minimum_size = Vector2(0, 46)
		inert.modulate = Color(1, 1, 1, 0.85 if committed else 0.45)
		v.add_child(inert)
	else:
		v.add_child(_action_button(str(row["label"]).to_upper(),
			ACTION_COMMIT, choice_id, wire))
	c.add_child(v)
	return c

# --- result -----------------------------------------------------------------

## PX-003 §5: the lived result first, the resolver tier never. "You kept the
## take" is what happened; "messy" is internal vocabulary.
static func build_result(engine: Object, _gs: Node, summary: Dictionary,
		wire: Callable) -> Array:
	var out: Array = []
	var result: Dictionary = engine.result_summary()
	var effects: Dictionary = result.get("result", {})
	var tier := str(result.get("resolved_tier", ""))
	var choice := str(result.get("committed_choice", ""))
	var arrested: bool = bool(effects.get("arrested", false))

	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_label(result_headline(engine, summary, choice, tier, effects),
		"CardTitle", 15, tier_tone(tier)))
	v.add_child(_label(result_body(engine, summary, choice, tier, effects),
		"Muted", 12, MUTED, true))
	c.add_child(v)
	out.append(c)

	# The deltas, one row each, exact and signed.
	var deltas: Array = delta_rows(effects)
	if not deltas.is_empty():
		var d := _card()
		var dv := VBoxContainer.new()
		dv.add_theme_constant_override("separation", 4)
		dv.add_child(_label("WHAT IT COST", "Kicker", 10, MUTED))
		for entry in deltas:
			dv.add_child(_delta_row(entry))
		d.add_child(dv)
		out.append(d)

	if arrested:
		out.append(_note("The store is done with you and police take over from here."
			if str(summary.get("chain_kind", "")) == engine.KIND_BOOST_CAUGHT
			else "Police take over from here."))
	out.append(_action_button("BOOKING" if arrested else "CONTINUE",
		ACTION_CONTINUE, "", wire))
	return out

## BB-D1 (0.7.0): the adapter that resolved the chain is asked FIRST. What
## follows is the fallback ladder, and the only chain that should ever reach
## its bottom rungs is Boost's own caught encounter -- the vocabulary those
## rungs were written in. The confrontation suite renders every road of every
## authored card and script and refuses to pass if any other chain kind lands
## on them.
static func result_headline(engine: Object, summary: Dictionary, choice: String,
		tier: String, effects: Dictionary) -> String:
	var said := str(engine.result_headline(""))
	if not said.is_empty():
		return said
	if str(summary.get("chain_kind", "")) == engine.KIND_RETALIATION:
		if int(effects.get("cash", 0)) < 0:
			return "THEY GOT PAID"
		if tier in ["clean", "messy"]:
			return "YOU HELD ONTO IT"
		return "THEY FOUND NOTHING"
	if str(summary.get("chain_kind", "")) == engine.KIND_STICK_CAUGHT:
		if bool(effects.get("arrested", false)):
			return "IT ENDS IN CUFFS"
		if tier in ["clean", "messy"]:
			return "YOU GOT CLEAR"
		return "THEY DIDN'T BUY IT"
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

static func result_body(engine: Object, summary: Dictionary, choice: String,
		tier: String, effects: Dictionary) -> String:
	var said := str(engine.result_body(""))
	if not said.is_empty():
		return said
	if str(summary.get("chain_kind", "")) == engine.KIND_RETALIATION:
		if int(effects.get("cash", 0)) < 0:
			return "They take what they came for and go."
		return "They leave without what they came for. That is not the end of it."
	if str(summary.get("chain_kind", "")) == engine.KIND_STICK_CAUGHT:
		if bool(effects.get("arrested", false)):
			return "The responding officer isn't interested in a conversation. Whatever happens next goes through the book."
		if tier in ["clean", "messy"]:
			return "You get clear of it. The robbery already happened; this part didn't."
		return "It doesn't end here, but it doesn't end in cuffs either — not this time."
	if choice == "yield":
		return "You lose the take and stop the situation from climbing any higher."
	if bool(effects.get("banned", false)) and not bool(effects.get("arrested", false)):
		return "The merchandise goes back. The store is finished dealing with you."
	if tier in ["clean", "messy"]:
		return "You get through them and make the exit."
	return "The take is gone and the room remembers your face."

static func tier_tone(tier: String) -> Color:
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

static func delta_rows(effects: Dictionary) -> Array:
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

static func _delta_row(entry: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var k := _label(str(entry["label"]), "Muted", 12, MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(_label(str(entry["text"]), "Mono", 13,
		GREEN if bool(entry["good"]) else ORANGE))
	return h

# --- the buttons this file builds --------------------------------------------
#
# Two actions and no more. `ACTION_COMMIT` carries the choice id it commits;
# `ACTION_CONTINUE` carries none. Both ride node metadata rather than the button
# text, because the text is authored copy and a caller matching on it would
# break the day somebody rewrites a label.

const ACTION_META := "encounter_action"
const CHOICE_META := "encounter_choice"
const ACTION_COMMIT := "commit"
const ACTION_CONTINUE := "continue"

static func _action_button(text: String, action: String, choice_id: String,
		wire: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = &"BtnPrimary"
	b.add_theme_font_size_override("font_size", 13)
	b.set_meta(ACTION_META, action)
	b.set_meta(CHOICE_META, choice_id)
	if wire.is_valid():
		wire.call(b, action, choice_id)
	return b

# --- builders (see the header on why these are not inherited) ----------------

static func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Card"
	# TOUCH-D3a: PanelContainer is the one Container subtype that defaults to
	# MOUSE_FILTER_STOP, which is what stops a drag starting on a card from
	# reaching the ScrollContainer above it.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

static func _label(text: String, variation: String, size: int, col: Color,
		wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(variation)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func _section(text: String) -> Label:
	return _label(text, "Kicker", 10, MUTED)

static func _note(text: String) -> Control:
	var c := _card()
	c.add_child(_label(text, "Muted", 12, MUTED, true))
	return c

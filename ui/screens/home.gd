extends "res://ui/screens/screen_base.gd"
## Home — binds every card from GameState in one pass (_bind_all).
##
## Chrome (header + HUD) comes from the base. This fills Tonight's Operation, the
## Market Snapshot, Turf & Crew (incl. the mini-map grid), the Activity Feed, and
## People & Events. Because the base connects refresh() to GameState.state_changed,
## a single notify_changed() re-renders the whole screen — the vertical slice
## (buy in Market -> GameState updates -> Home reflects cargo/cash/snapshot/feed).

const RED := Color(0.827, 0.161, 0.125, 1)
const DIM := Color(1, 1, 1, 0.06)

@onready var _gm: Node = get_node("/root/GameManager")

func _ready() -> void:
	super()
	_wire_taps()

## Home's two standing actions, and where they now live.
##
## Both spent this batch on the OPERATION card, and both were therefore
## unreachable on exactly the run that needs them most. `_bind_gates` hides that
## card whenever there is no operation out, no rent crunch and no workable
## shift — which is a fresh run in its entirety — so POST ELI and LAY LOW were
## drawn on a node that had already left the layout.
##
## They have their own card now, directly under Wander, on their own condition:
## `SurfaceVisibility.home_actions()` answers which of them EXIST, and the card
## is hidden until at least one does. The operation card keeps only what it was
## always actually for — the rent warning, the shift reminder and the delegation
## report — and carries no buttons at all.
##
## Keyed by node name, valued by [label, handler-name, action id]. The action id
## is the one `home_actions()` returns, so the screen renders exactly the
## buttons the access layer said were there rather than deciding again.
const ACTIONS := {
	"Post": {"id": "post_eli", "label": "POST ELI"},
	"Lay": {"id": "lay_low", "label": "LAY LOW"},
}

func _wire_taps() -> void:
	# The operation card is now purely informational, and this is the last step
	# of emptying it. Every control it ever carried has moved to a card that is
	# there when the control is usable:
	#
	#   MOVE PRODUCT -> the Wander card (batch 13). It was canon's
	#                   `explore_spenard` spending a slot to print the weather.
	#   POST ELI     -> the Actions card (batch 14).
	#   LAY LOW      -> the Actions card (batch 14).
	#
	# All three sat on a node `_bind_gates` HIDES whenever there is no operation,
	# no rent crunch and no shift — which is a fresh run in its entirety. HANDOFF
	# filed the first as an open follow-up ("the build's only bare advance_time
	# control in the UI lives on the now-hidden operation card ... Filed for the
	# next UX pass"); batch 13 took that one and this takes the other two.
	#
	# The row is hidden rather than deleted from the scene: the .tscn is the
	# editor-time preview of a card that still exists, and a screen that
	# tolerates a node being absent (`get_node_or_null`) should equally tolerate
	# it being present.
	var stale_row := get_node_or_null(
		"Shell/Scroll/Pad/Content/OpCard/V/Actions") as Control
	if stale_row:
		stale_row.visible = false
	for node_name in ACTIONS.keys():
		var b := get_node_or_null(
			"Shell/Scroll/Pad/Content/Actions/V/Row/" + str(node_name)) as Button
		if b == null:
			continue
		b.text = str((ACTIONS[node_name] as Dictionary)["label"])
		tap_connect(b, _on_post_eli if str(node_name) == "Post" else _on_lay_low)
	# One button, dispatching READ — the intent wander.gd now treats as
	# "explore everything" rather than one of three equal choices (PR 5). A
	# second, conditional button is pure navigation to the Jobs screen, shown
	# only once there is a job to go back to.
	var walk_btn := get_node_or_null("Shell/Scroll/Pad/Content/Wander/V/Go/Read") as Button
	if walk_btn:
		tap_connect(walk_btn, _on_wander.bind(EVENTS.INTENT_READ))
	var work_btn := get_node_or_null("Shell/Scroll/Pad/Content/Wander/V/Go/GoToWork") as Button
	if work_btn:
		tap_connect(work_btn, _on_go_to_work)
	make_tappable("Shell/Scroll/Pad/Content/Columns/Market", _on_market)
	make_tappable("Shell/Scroll/Pad/Content/Columns/Turf", _on_turf)
	make_tappable("Shell/Scroll/Pad/Content/People", _on_people)

## Canon's explore_spenard: cashCost 0, timeCost 1 (game-core.js:358-360).
##
## The cost was always right here. What was missing was everything the slot buys
## — see `systems/wander.gd`. The toast reports what the walk turned up; the
## feed carries the line itself, and a blocking encounter takes the player to
## the consequence screen on its own.
func _on_wander(intent: String) -> void:
	var sys: Object = _gm.system("wander")
	if sys == null:
		return
	var blocked: String = str(sys.blocker())
	if not blocked.is_empty():
		nav.show_toast(blocked + ".")
		return
	var before_day: int = gs.day
	if not _gm.dispatch("wander", {"intent": intent}):
		return
	# A wander that opened a blocking encounter has already navigated away, and
	# the toast is parented to the tree root rather than the screen — so it
	# survives the scene change and floats "You take a walk" over SOMEBODY STOPS
	# YOU. The encounter is its own announcement.
	var engine: Object = _gm.system("consequence")
	if engine != null and bool(engine.has_active()):
		return
	# Same reasoning as the encounter case just above: a walk that opened a
	# surface is about to show its discovery card, carrying the exact
	# sentence `activity_log[0]` would put in this toast. Let the card say it
	# once instead of a toast (layer 100) floating the same line over it.
	if nav.has_pending_flow_sheets():
		return
	nav.show_toast(_wander_toast(before_day))

## What the walk turned up, said to the player directly.
##
## Wander wrote to the activity feed and nothing else, and the toast said "You
## take a walk." — so the one surface that reports the outcome of the action was
## a card further down the screen the player had to think to go and read. A
## mechanic that produces eleven different results and announces all of them
## identically is a mechanic the player learns nothing from.
##
## The line comes off the FEED rather than off the dispatch return, and that is
## the deliberate part: `handle()` reports a `kind` and a `card_id`, which are
## the shape of what happened, while the feed row is the SENTENCE about it —
## already written, already toned, already the words the player would have read.
## Translating a kind back into copy here would be a second author for the same
## event, one toast out of date the first time a card is reworded.
##
## `activity_log[0]` is the newest row (`log_activity` push_fronts) and every
## wander path writes at least one — discovery, opportunity, encounter, read,
## ambient, and the breadcrumb that exists precisely so a walk is never silent.
## For a read or a cashed opportunity that newest row is the PAYLOAD line rather
## than the card's flavour ("Spenard is watched about boost work.", "Picked up
## $32."), which is the better of the two to be handed on a two-second toast.
##
## The day-crossing line is APPENDED rather than shown after it. There is one
## toast node for the whole session and a second message replaces the first
## (`ui/components/toast.gd`), so two calls would show the day and swallow the
## walk — the exact line this function exists to surface.
func _wander_toast(before_day: int) -> String:
	var latest: Dictionary = gs.activity_log[0] if not gs.activity_log.is_empty() else {}
	var line: String = str(latest.get("text", ""))
	# The row has to be from the walk that just happened. The card writes BEFORE
	# the slot advances, so it carries the day the walk started on — comparing
	# against `gs.day` instead would fail on every day crossing, which is the
	# one moment the player most wants both facts.
	if line.is_empty() or int(latest.get("day", -1)) != before_day:
		line = "You take a walk. %s in %s." \
			% [gs.time_slot.capitalize(), gs.current_district().get("name", "")]
	if gs.day > before_day:
		line += "\nA new day. Day %d." % gs.day
	return line

## The "look for a deal, then go to work if employed" playtest finding
## (PR 5). Existing screen, existing flow — the Jobs screen already handles
## the approach choice and the shift itself; this is just the door to it.
func _on_go_to_work() -> void:
	nav.go_to(nav.JOBS)

## Eli, on the bag for the day. Batch 6b built the operation; this is the door
## the operation card always implied and never had.
func _on_post_eli() -> void:
	var ops: Object = _gm.system("crew_operations")
	if ops == null:
		return
	if not ops.is_discovered("run_the_bag"):
		nav.show_toast("Eli has not offered yet.")
		return
	var blocked: Variant = ops.assignment_blocker("run_the_bag")
	if blocked != null:
		nav.show_toast(str(blocked) + ".")
		return
	if _gm.dispatch("assign_crew_operation",
			{"crew_id": "eli", "operation_id": "run_the_bag"}):
		nav.show_toast("Eli has the bag today.")

## Lay Low has existed in `systems/recovery.gd` since it shipped and has only
## ever been reachable from a conditional row on the More menu. Batch 8 gave it
## a once-a-day cap; this gives it the button the Home card has been drawing
## for it the whole time.
func _on_lay_low() -> void:
	var recovery: Object = _gm.system("recovery")
	if recovery == null:
		return
	var blocked: String = str(recovery.lay_low_blocker())
	if not blocked.is_empty():
		nav.show_toast(blocked + ".")
		return
	if _gm.dispatch("lay_low", {}):
		nav.show_toast("Lights off, phone down.")

func _on_market() -> void:
	nav.go_to(nav.MARKET)

func _on_turf() -> void:
	nav.go_to(nav.TURF)

func _on_people() -> void:
	nav.go_to(nav.PEOPLE)

## Home is where the most surfaces are gated, so the gates run FIRST and every
## bind below them is free to fill a surface without asking whether it is there:
## filling a hidden node is harmless, and filling a locked one is what makes the
## lock legible — a greyed-out card with real numbers under it says "this is
## coming", where a greyed-out card of placeholder text says nothing.
const EVENTS := preload("res://data/wander_events.gd")
const ACCESS := preload("res://autoload/surface_visibility.gd")

func _bind_content() -> void:
	_bind_gates()
	_bind_all()

func _bind_gates() -> void:
	# LOCKED: earned surfaces. They stay in the layout, dimmed, with a hint.
	gate_surface(ACCESS.HOME_TURF_CREW, "Shell/Scroll/Pad/Content/Columns/Turf")
	# HIDDEN: nothing to show. The card leaves the layout and the ones below it
	# close the gap. The Market Snapshot moved into this half in batch 14 — see
	# `SurfaceVisibility.GATES` for why a padlock was the wrong shape for it.
	gate_surface(ACCESS.HOME_MARKET_SNAPSHOT, "Shell/Scroll/Pad/Content/Columns/Market")
	gate_surface(ACCESS.HOME_ACTIONS, "Shell/Scroll/Pad/Content/Actions")
	gate_surface(ACCESS.HOME_TONIGHTS_OPERATION, "Shell/Scroll/Pad/Content/OpCard")
	gate_surface(ACCESS.HOME_TEXT_MESSAGES, "Shell/Scroll/Pad/Content/People")
	gate_surface(ACCESS.HOME_ACTIVITY_FEED, "Shell/Scroll/Pad/Content/Activity")

func _bind_all() -> void:
	_bind_wander()
	_bind_actions()
	_bind_operation()
	_bind_snapshot()
	_bind_turf()
	_bind_activity()
	_bind_people()

## The Wander card. Always present, because going out is always available and a
## card that came and went would be the defect this batch exists to close.
##
## The subtitle is the ramp, said rather than numbered. `WanderSystem` owns the
## arithmetic — 30% base, +10% a miss, capped at 70% — and the player is told
## how the looking is going, which is the part that makes another walk feel
## worth a slot. Telling them 0.60 would be telling them to do arithmetic.
func _bind_wander() -> void:
	var sys: Object = _gm.system("wander")
	if sys == null:
		return
	_set_text("Shell/Scroll/Pad/Content/Wander/V/Head/T", "GO OUT AND LOOK")
	_set_text("Shell/Scroll/Pad/Content/Wander/V/Head/Where",
		gs.time_slot.capitalize())
	var blocked: String = str(sys.blocker())
	var walk_btn := get_node_or_null("Shell/Scroll/Pad/Content/Wander/V/Go/Read") as Button
	if walk_btn:
		walk_btn.text = "WALK AROUND" if blocked.is_empty() else blocked.to_upper()
		walk_btn.disabled = not blocked.is_empty()
		walk_btn.tooltip_text = "Work, a deal, or just what's going on. You don't pick which."
	# Pure navigation, so no blocker check of its own — a consequence in front
	# of the player redirects any nav.go_to() the same way it always has.
	var work_btn := get_node_or_null("Shell/Scroll/Pad/Content/Wander/V/Go/GoToWork") as Button
	if work_btn:
		work_btn.visible = not str(gs.active_job_id).is_empty()
	_set_text("Shell/Scroll/Pad/Content/Wander/V/Sub", _wander_line(sys))

## What the card says under the button. Three states, and the middle one is the
## whole reason the ramp exists.
func _wander_line(sys: Object) -> String:
	if not str(sys.blocker()).is_empty():
		return "Not right now."
	# "Nothing left to find" is now a question about TWO pools, not one. Batch 14
	# gave DEAL its own — the boost targets you have not clocked here — so a
	# player who has found every job but no shops has plenty left out there, and
	# telling them the block is exhausted would be false in the one direction
	# that costs them a mechanic.
	if (sys.undiscovered() as Array).is_empty() \
			and (sys.undiscovered_boost_targets() as Array).is_empty():
		return "%s, and you know it well enough by now. Still worth the walk." \
			% str(gs.current_district().get("name", "the block"))
	# The day's effort first, because it is the thing that changes what the next
	# tap is worth. Said rather than numbered, like the ramp.
	var walked: int = int(gs.wanders_today)
	if walked >= 3:
		return "You have walked this block enough for one day."
	if walked == 2:
		return "Twice already today. There is not much left out there."
	var misses: int = int(gs.wander_misses)
	if walked == 1:
		return "Once already today. Still worth a look."
	if misses <= 0:
		return "An hour on foot. You never know who is out."
	if misses < 3:
		return "Nothing the last time out. Somebody knows something."
	return "You have come back empty a few times now. That tends to change."

## The Actions card: POST ELI and LAY LOW, each shown only when it exists.
##
## The available list comes from `SurfaceVisibility.home_actions()` — the SAME
## call whose size decides whether the card is in the layout at all. That is the
## rule the operation card is written to and the reason it is written that way:
## a screen that keeps its own copy of the condition is a screen that can hide a
## card while still filling it, or fill a card with buttons that do nothing.
##
## A button whose action is not on the list is hidden rather than disabled. A
## disabled LAY LOW on a run at full health with no Heat is a control explaining
## a mechanic the player has no reason to have heard of; there being nothing
## there says the same thing without the explanation.
func _bind_actions() -> void:
	var access: Node = get_node_or_null("/root/SurfaceVisibility")
	var available: Array = access.home_actions() if access != null else []
	_set_text("Shell/Scroll/Pad/Content/Actions/V/Head/T", "WHAT ELSE")
	_set_text("Shell/Scroll/Pad/Content/Actions/V/Sub", _actions_line(available))
	for node_name in ACTIONS.keys():
		var b := get_node_or_null(
			"Shell/Scroll/Pad/Content/Actions/V/Row/" + str(node_name)) as Button
		if b == null:
			continue
		b.visible = str((ACTIONS[node_name] as Dictionary)["id"]) in available

## One line under the two buttons, naming what is actually on offer.
##
## Written from the same list the buttons are, so it cannot describe a door that
## is not there. The blockers stay on the handlers: this says what EXISTS, and
## tapping says whether it can happen right now and why not.
func _actions_line(available: Array) -> String:
	var has_eli: bool = "post_eli" in available
	var has_lay: bool = "lay_low" in available
	if has_eli and has_lay:
		return "Somebody to send, or a day to lose on purpose."
	if has_eli:
		return "Eli will take the bag if you want the day covered."
	if has_lay:
		return "A day off the street costs a slot and buys quiet."
	return ""

## The card's copy, chosen from the reason the access layer already decided.
##
## The ORDER changed in v0.1.0 and the reason is worth stating: this function
## used to both decide whether the card had content and pick the words for it.
## Deciding is now `SurfaceVisibility.operation_card_reason()`, because the same
## verdict has to drive whether the card is in the layout at all — a screen that
## keeps its own copy of the condition is a screen that can hide a card while
## still writing text into it.
##
## Delegation now outranks rent rather than sitting under it, which is what
## moving the decision made explicit: the access layer answers "operation" first
## because an operation that is OUT is the card's actual subject, and the rent
## clock is still carried by the HUD's DUE IN N DAYS either way.
func _operation_override() -> Dictionary:
	var access: Node = get_node_or_null("/root/SurfaceVisibility")
	match str(access.operation_card_reason()) if access != null else "":
		"operation":
			return _delegation_override()
		"rent":
			var ob: Object = _gm.system("obligations") if _gm else null
			var days: int = int(ob.days_until_rent()) if ob != null else 0
			var when := "today" if days <= 0 else ("tomorrow" if days == 1 else "in %d days" % days)
			return {"title": "RENT %s" % when.to_upper(),
					"body": "Yalonda wants $%d %s and you have $%d. Find the difference."
						% [gs.WEEKLY_RENT, when, gs.cash]}
		"shift":
			var job: Dictionary = gs.active_job()
			return {"title": "SHIFT: %s" % str(job.get("name", "")).to_upper(),
					"body": "They're expecting you this %s. Clean money, and it keeps the room."
						% gs.time_slot.capitalize()}
	return {}

## Pherris's card, read whole from `operation_summary()`.
##
## Nothing is derived here. "Is she out" and "what did last night come to" are
## fields on the summary, and the only decision this function makes is which of
## the two to show — out today outranks last night, because one of them is still
## happening.
func _delegation_override() -> Dictionary:
	var ops: Object = _gm.system("crew_operations") if _gm else null
	if ops == null:
		return {}
	for operation_id in ops.operation_ids():
		var summary: Dictionary = ops.operation_summary(str(operation_id))
		if not bool(summary.get("discovered", false)):
			continue
		if bool(summary.get("active_today", false)):
			return {"title": "PHERRIS · OUT TODAY",
					"body": _out_today_body(summary)}
		var last: Variant = summary.get("last_night")
		if last is Dictionary:
			var profit: int = int((last as Dictionary).get("profit_or_loss", 0))
			return {"title": "PHERRIS · $%d LAST NIGHT" % profit,
					"body": _last_night_body(last)}
	return {}

func _out_today_body(summary: Dictionary) -> String:
	var selection: Variant = summary.get("selection")
	var picked: int = int((selection as Dictionary).get("cycles_used", 0)) \
		if selection is Dictionary else 0
	var spent: int = int((selection as Dictionary).get("total_spent", 0)) \
		if selection is Dictionary else 0
	if picked <= 0:
		return "She has the day and the board had nothing on it worth your money."
	return "She has the day and $%d of yours, on %d listing%s. It settles tonight." \
		% [spent, picked, "" if picked == 1 else "s"]

func _last_night_body(last: Dictionary) -> String:
	var sold: int = int(last.get("settled_count", 0))
	var gross: int = int(last.get("gross", 0))
	var profit: int = int(last.get("profit_or_loss", 0))
	if sold <= 0:
		return "She worked the board and nothing closed. Your money is where you left it."
	return "She moved %d for $%d gross. %s $%d on the day." \
		% [sold, gross, "Cleared" if profit >= 0 else "Down", absi(profit)]

## The card, when there is a card. `_bind_gates` has already decided that; an
## empty override here means the node is hidden and this is writing into nothing.
##
## `gs.active_operation`'s scripted copy is no longer rendered. It was UI
## scaffold nothing ever wrote — a fixed line about Curtis probing Minnesota
## Off-Ramp that was false in every run it appeared in — and the surface gate is
## what finally lets it go: the card is either carrying a fact or it is not
## there. The three action buttons keep their authored labels from the scene.
func _bind_operation() -> void:
	var over: Dictionary = _operation_override()
	if over.is_empty():
		return
	_set_text("Shell/Scroll/Pad/Content/OpCard/V/Head/Title", str(over["title"]))
	_set_text("Shell/Scroll/Pad/Content/OpCard/V/Body", str(over["body"]))

func _bind_snapshot() -> void:
	var rows := ["R0", "R1", "R2"]
	for i in range(rows.size()):
		var id: String = gs.home_snapshot[i] if i < gs.home_snapshot.size() else ""
		var p: Dictionary = gs.product_by_id(id)
		if p.is_empty():
			continue
		var base: String = "Shell/Scroll/Pad/Content/Columns/Market/V/" + rows[i]
		var col: Color = p.color
		var ic := get_node_or_null(base + "/Ic") as TextureRect
		if ic:
			ic.self_modulate = col
		var nm := get_node_or_null(base + "/I/Nm") as Label
		if nm:
			nm.text = p.name
			nm.add_theme_color_override("font_color", col)
		_set_text(base + "/I/Sub", "Own %s · %s" % [p.get("owned", "0"), p.get("route", "")])
		var pr := get_node_or_null(base + "/P") as Label
		if pr:
			pr.text = "$%d" % p.price
			pr.add_theme_color_override("font_color", col)

func _bind_turf() -> void:
	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Blocks/N", str(gs.territory_nodes.size()))

	var held_cells := {}
	var names := []
	for id in gs.territory_nodes.keys():
		var b: Dictionary = gs.block_by_id(str(id))
		if b.is_empty():
			continue
		held_cells[int(b.get("cell", -1))] = true
		names.append("• " + str(b.get("name", "")))
	for i in range(gs.map_cells):
		var cell := get_node_or_null("Shell/Scroll/Pad/Content/Columns/Turf/V/Map/B%d" % i) as ColorRect
		if cell:
			cell.color = RED if held_cells.has(i) else DIM
	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/List", "\n".join(names))

	var soldiers: int = gs.soldiers_total()
	_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Sold/N", str(soldiers))
	for i in range(6):
		var pip := get_node_or_null("Shell/Scroll/Pad/Content/Columns/Turf/V/Pips/P%d" % i) as TextureRect
		if pip:
			pip.self_modulate = RED if i < soldiers else PIP_DIM

	# Report what the corners are actually doing rather than a fixed line.
	var terr: Object = _gm.system("territory") if _gm else null
	if terr != null and not gs.territory_nodes.is_empty():
		_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Eli", "$%d a night from %d held." % [int(terr.nightly_income()), gs.territory_nodes.size()])
	else:
		_set_text("Shell/Scroll/Pad/Content/Columns/Turf/V/Eli", "No corners held yet.")

func _bind_activity() -> void:
	var rows := ["A0", "A1", "A2"]
	for i in range(rows.size()):
		var e: Dictionary = gs.activity_log[i] if i < gs.activity_log.size() else {}
		if e.is_empty():
			continue
		var base: String = "Shell/Scroll/Pad/Content/Activity/V/" + rows[i]
		_set_text(base + "/T", e.get("text", ""))
		var m := get_node_or_null(base + "/M") as Label
		if m:
			m.text = e.get("time", "")
			if e.has("color"):
				m.add_theme_color_override("font_color", e.color)

## The real phone inbox, since Phase 6 — this card used to read a hardcoded
## `pending_messages` placeholder, which is retired. An empty inbox now says so
## instead of leaving the scene's editor-time preview text standing as a fact,
## and a dead line reports what it is holding.
func _bind_people() -> void:
	var base := "Shell/Scroll/Pad/Content/People/H/Txt/"
	var chat := get_node_or_null("Shell/Scroll/Pad/Content/People/H/Chat") as Button
	if gs.phone_inbox.is_empty():
		var held: int = gs.phone_held_inbox.size()
		if not gs.phone_active and held > 0:
			_set_text(base + "Name", "NO SERVICE")
			_set_text(base + "Msg", "%d held until the line comes back." % held)
		elif not gs.phone_active:
			_set_text(base + "Name", "NO SERVICE")
			_set_text(base + "Msg", "The line is dead. Pay the bill to hear from anyone.")
		else:
			_set_text(base + "Name", "NO TEXTS")
			_set_text(base + "Msg", "Nobody has needed you today.")
		_set_text(base + "Ago", "")
		if chat:
			chat.text = str(held)
		return
	var msg: Dictionary = gs.phone_inbox[0]
	_set_text(base + "Name", str(msg.get("from", "")).to_upper() + " TEXTED")
	_set_text(base + "Msg", str(msg.get("text", "")))
	_set_text(base + "Ago", _phone().stamp(msg))
	if chat:
		chat.text = str(gs.phone_inbox.size())

func _phone() -> RefCounted:
	return _gm.system("phone") as RefCounted

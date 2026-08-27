extends RefCounted
## DayLifecycle — the explicit ordering contract for night settlement.
##
## TI-003 §9. Before this, the order in which crew, territory, shark, jobs and
## obligations settled was whatever order their `day_crossed.connect()` calls
## happened to run in during GameManager's `_ready()`. That is an ordering
## contract expressed as a side effect of construction order — invisible,
## untestable, and silently rewritten by moving a line in an unrelated file.
##
## Now it is a list. Reordering a phase is a deliberate edit that breaks an
## ordering test, which is the contract FS-003.3 through .12 inherit.
##
## ## The sequence
##
##   1. PRE_SETTLE  — `day_ending(ended_day)`, clock still reads the old day
##   2. SETTLE      — `SETTLE_ORDER`: crew, territory, shark, jobs, obligations.
##                    Jobs and obligations run LAST. `HANDOFF.md` documented the
##                    reverse for four batches; see D-5 below and the ruling in
##                    `docs/DECISIONS.md`. The code is the contract.
##   3. POST_SETTLE — `POST_SETTLE_ORDER`, then hooks
##   4. INCREMENT   — day += 1, slot back to MORNING
##   5. ROLLOVER    — TI-003 §9's post-increment lifecycle, in `ROLLOVER_ORDER`
##   6. MARKET      — economy.evolve(), then `day_crossed` for legacy listeners
##   7. DAY_START   — `DAY_START_ORDER`, then hooks
##
## The header used to describe three DAY_START steps where the constant has
## five, and did not mention that `heat_day_reset` runs FIRST — which is the one
## position in that list a reader has to know, because every step below it can
## generate Heat and clearing the flag after them would hand the new day a decay
## it had already spent. Naming the constant instead of paraphrasing it is the
## fix: a paraphrase of a list is a second copy of the list.
##
## ## Why Exposure and Curtis moved off `day_crossed`
##
## TI-003 §2: "DayLifecycle calls explicit rollover methods on Exposure and
## Curtis in a fixed order while their scoring math remains intact."
##
## Both used to hang off the `day_crossed` signal, which put them at whatever
## position in the handler list their `connect()` call happened to occupy — the
## exact problem this file exists to remove, surviving in the two places it
## mattered most. It mattered because TI-003 §17 requires the Financial Pressure
## fold to land BEFORE Exposure propagates the morning's Heat, and a signal
## cannot express "before".
##
## Their MATH is untouched. `Exposure.rollover()` and `Curtis.rollover()` are the
## same functions the signal used to reach, called by name from a declared list.
##
## ## Why the hooks are Callables and not signals
##
## Signals have exactly the ordering problem this file exists to remove: the
## order handlers run in is the order they connected, which nothing declares and
## nothing tests. `post_settle_hooks` and `day_start_hooks` are Arrays of
## Callables and run in index order, which is both declared and testable.
##
## ## What settlement receives, and why it is a parameter
##
## Every settler takes `ended_day` explicitly. Canon does the same and says why
## — `applyAttendance(state, oldDay)` carries the comment *"so the rung does not
## depend on sitting above the `run.day = oldDay + 1` line further down."*
## Jobs and obligations used to derive `gs.day - 1`; that arithmetic is gone.
##
## ## A divergence this build preserved, and has now corrected
##
## Canon's `confirmDayEnd` settles crew and shark ABOVE the increment, so both
## see the ending day. This port historically settled them below it, so both saw
## the NEW day — and when FS-003.2 built this seam and moved them above the
## increment, `crew.settle_night` / `shark.settle_night` kept computing against
## `ended_day + 1` so their behaviour did not change inside a refactor that
## claimed to change nothing.
##
## That was deliberate, and it was filed with the note "when it is corrected,
## those two lines are the whole change". It was, and they were. Both now use
## `ended_day` directly. Wages stamp `wage_missed_since` with the night the wage
## was actually missed, and a note due on day 7 resolves on the night that ends
## day 7 rather than the night that ends day 6 — the player gets the whole due
## day to pay it, which is the rule obligations already applied to rent.

const PRE_SETTLE := "PRE_SETTLE"
const SETTLE := "SETTLE"
const POST_SETTLE := "POST_SETTLE"
const INCREMENT := "INCREMENT"
const ROLLOVER := "ROLLOVER"
const MARKET := "MARKET"
const DAY_START := "DAY_START"

## TI-003 §9's post-increment lifecycle, as a list rather than as six statements
## whose order nobody wrote down.
##
## Two of these six orderings are on TI-003's regression list by themselves:
##
##   #25  Financial Pressure folds into Heat before daily decay
##   #26  Exposure propagates Heat before the Financial Pressure fold
##
## Both are ordering bugs that produce plausible numbers. Folding before the
## decay charges the player for pressure they no longer have; Exposure running
## before the fold means the morning's broadcast is measured against yesterday's
## Heat, and the +1 the fold just applied reaches the block a day late. Neither
## crashes, neither is visible in a single run, and both are one moved line away
## at all times. So the order is a constant a test reads.
##
## Bleed before recovery for the same reason it is written that way in §9: a
## bleed landing this morning is a GAIN, and a family that gained today is not
## having a quiet day. Recovering first would decay a district that is about to
## be handed more Pressure.
##
## Batch 8 adds two Heat steps, and both positions are load-bearing:
##
##   `heat_stop` runs AFTER `financial_fold`, so the night is rolled against the
##   Heat the player actually ends the day carrying — including the +1.0 the
##   fold just applied. Rolling before it would let a player fold themselves
##   over the stop floor and not be stopped for it until tomorrow.
##
##   `heat_decay` runs after the stop and BEFORE `exposure`. After the stop
##   because a quiet day is still a quiet day when somebody else searches you —
##   the flag it reads counts GAINS, and a stop is relief. Before Exposure
##   because §26 has the broadcast measured against the settled morning figure,
##   and the decay is part of settling it.
const ROLLOVER_ORDER: Array[String] = [
	"pressure_bleed",
	"pressure_recovery",
	"financial_decay",
	"financial_fold",
	"heat_stop",
	"heat_decay",
	"exposure",
	"curtis",
]

## v0.1.0's POST_SETTLE work, declared for the same reason the two lists below
## and above it are: a step whose position nobody wrote down is a step nobody
## can test.
##
## One entry so far. `pressure_clean_recovery` pays back the Pressure the day's
## CLEAN outcomes earned, and it belongs HERE rather than in `ROLLOVER_ORDER`
## because it settles the day that just happened: every gain from those same
## actions has already landed, and the clock has not moved, so the recovery
## nets against the day it was earned on rather than against tomorrow.
##
## It must also stay ABOVE `ROLLOVER:pressure_recovery`, which is the quiet-day
## rule. The two are independent — one reads the day's outcomes, the other reads
## `last_gain_day` — and a day with a clean outcome on it is a day with a GAIN
## on it, so the quiet rule correctly declines to fire on top of this.
const POST_SETTLE_ORDER: Array[String] = [
	"pressure_clean_recovery",
]

## TI-003 §9 step 6's day-start lifecycle. Expiry before activation, and the
## order is not arbitrary: a row that ran out overnight must be gone before
## anything asks what is eligible, or the day's one delayed slot could be spent
## on an encounter that had already expired.
##
## FS-003.13 appends a third step and reorders nothing. `retaliation_ambient`
## runs LAST for the same reason expiry runs first: a threat that already expired
## must not whisper, and a threat that just walked through the door in person is
## not something the feed then hints at. Both are questions about what is still
## PENDING, and both are answered correctly only once the other two steps have
## finished moving rows out of that state.
##
## Declared here rather than registered as a `day_start_hook` because these are
## the lifecycle's own work, not somebody else's. The hooks stay empty and
## available, and `clear_hooks()` cannot remove the game.
## FS-002.2 appends `stickup_day_reset` and reorders nothing.
##
## `stickup.gd` was still resetting its two-a-day cap from an undeclared
## `gs.day_crossed.connect(_on_day_crossed)` — the exact pattern this file
## exists to abolish, surviving in one of the two places the ordering contract
## names. It is a declared step now.
##
## It sits beside `heat_day_reset` because it is the same KIND of fact: what has
## already happened today, cleared as today begins. It does not ride INSIDE that
## step, because that step is Heat's own bookkeeping and this counter is Stick's
## — the lifecycle calls the owner rather than reaching into its state.
##
## The move is also a move LATER, from MARKET (where `day_crossed` fires) to
## DAY_START. Nothing between those two positions reads `stick_daily_count`.
##
## The other survivor of the signal pattern is phone restoration
## (`time_system.gd:93`), which runs outside `run_night_transition` entirely.
## Documented, deliberately NOT moved: it is outside FS-002.2's scope and moving
## it changes when a paid-for line comes back.
const DAY_START_ORDER: Array[String] = [
	"heat_day_reset",
	"stickup_day_reset",
	"expire_retaliation",
	"surface_delayed",
	"retaliation_ambient",
]

## The settlement order, declared. Each entry is the system name as registered
## in GameManager; each of those systems exposes `settle_night(ended_day: int)`.
##
## ## D-5: the order is right and its stated reason was wrong
##
## Crew first, then territory. That has been the shipped order since FS-003.2
## and it stays. **The reason written next to it was false in three files**, and
## the 2026-08-23 studio pass caught it: "territory income is computed off crew
## power". It is not. `systems/territory.gd` does not reference `crew_power` —
## or `crew` — anywhere. Corner income is `b["earning"]` and the diminishing
## constant, and nothing else.
##
## The real dependency is HEAT, and it runs through Deshawn:
##
##   `crew.settle_night()` can set a member's `status` to "departed" when
##   loyalty bottoms out over unpaid wages. `territory.settle_night()` applies
##   its holding heat through `HeatSystem.apply_gain()`, which is the ONE site
##   that consults `crew.heat_multiplier()` (`heat.gd:199-203`), and that
##   multiplier returns 1.0 for a Deshawn who is no longer recruited.
##
## So a Deshawn who departs tonight for unpaid wages does NOT damp tonight's
## corner heat — which is the behaviour the audit described correctly and
## explained wrongly. Swapping these two is still a gameplay change; it is a
## change to what the night COSTS, not to what it earns.
##
## Obligations last because rent and the phone bill are what end a run, and
## everything that could still pay them has had its turn.
const SETTLE_ORDER: Array[String] = [
	"crew", "territory", "shark", "jobs", "obligations",
]

var gs: Node
var gm: Node
var economy: RefCounted

## Ran in index order after SETTLE, before the clock moves. Empty this build.
var post_settle_hooks: Array[Callable] = []
## Ran in index order at the end, on the new day. Empty this build.
var day_start_hooks: Array[Callable] = []

## Every phase name in order, appended as it runs. Read by the ordering tests;
## nothing in the game depends on it.
var trace: Array[String] = []
## When true, `trace` is filled. Off in play — this is a test instrument, and a
## growing array on a hot path is not something to ship on by default.
var tracing := false

## Register through these, never by assigning an array literal.
##
## FS-003.2 shipped these two as bare typed properties and its own tests
## assigned `lifecycle.post_settle_hooks = [probe]` to them. An untyped `Array`
## literal does not convert to `Array[Callable]`, so every one of those
## assignments raised at runtime and aborted the enclosing check — silently,
## because an aborted check is a check that never counted rather than one that
## failed. The suite went green having never once proven a hook runs.
##
## The typing is right and stays. The trap was the assignment, so registration
## is a method now: `append` on a typed array accepts a Callable, and no caller
## has to know why the literal form does not.
func add_post_settle_hook(hook: Callable) -> void:
	post_settle_hooks.append(hook)

func add_day_start_hook(hook: Callable) -> void:
	day_start_hooks.append(hook)

func clear_hooks() -> void:
	post_settle_hooks.clear()
	day_start_hooks.clear()

func setup(game_state: Node, manager: Node, economy_system: RefCounted) -> void:
	gs = game_state
	gm = manager
	economy = economy_system

## No actions of its own — the night is a consequence of `advance_time`, never
## something the player dispatches.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The day lifecycle takes no actions."}

func _mark(phase: String) -> void:
	if tracing:
		trace.append(phase)

## The whole night, in declared order.
##
## Called from `time_system` when the clock rolls past NIGHT, which happens
## inside the `advance_time` dispatch — so the dispatch-ownership guard on
## Exposure and Curtis sees a live dispatch and settlement writes are legal, and
## the single `notify_changed()` at the end of that dispatch covers all of it.
func run_night_transition(ended_day: int) -> void:
	if tracing:
		trace.clear()

	# 1. PRE_SETTLE — the clock still reads the day that is finishing.
	_mark(PRE_SETTLE)
	gs.day_ending.emit(ended_day)

	# 2. SETTLE — in the order declared above, not the order things connected.
	for system_name in SETTLE_ORDER:
		var system: Object = gm.system(system_name)
		if system == null or not system.has_method("settle_night"):
			continue
		_mark("%s:%s" % [SETTLE, system_name])
		system.settle_night(ended_day)

	# 3. POST_SETTLE — everything owed has been settled; the day has not moved.
	_mark(POST_SETTLE)
	for step in POST_SETTLE_ORDER:
		_mark("%s:%s" % [POST_SETTLE, step])
		_run_post_settle_step(step, ended_day)
	for hook in post_settle_hooks:
		if hook.is_valid():
			hook.call(ended_day)

	# 4. INCREMENT — and only now does the clock move.
	_mark(INCREMENT)
	gs.day = ended_day + 1
	gs.time_slots_today = 0
	gs.time_slot = TimeSystem_SLOT_MORNING

	# 5. ROLLOVER — TI-003 §9's post-increment lifecycle, in declared order.
	for step in ROLLOVER_ORDER:
		_mark("%s:%s" % [ROLLOVER, step])
		_run_rollover_step(step, gs.day)

	# 6. MARKET — the overnight walk, then the legacy signal.
	#
	# `day_crossed` fires here rather than in SETTLE because everything still
	# connected to it was written expecting the NEW day on the clock. Anything
	# not yet migrated therefore keeps working unchanged, and runs after the
	# declared order — which is the right place for something the contract does
	# not yet know about.
	_mark("%s:evolve" % MARKET)
	economy.evolve()
	_mark("%s:day_crossed" % MARKET)
	gs.day_crossed.emit()

	# 7. DAY_START — the new day is on the clock and the board is priced.
	_mark(DAY_START)
	for step in DAY_START_ORDER:
		_mark("%s:%s" % [DAY_START, step])
		_run_day_start_step(step, gs.day)
	for hook in day_start_hooks:
		if hook.is_valid():
			hook.call(gs.day)

## One POST_SETTLE step, by name. Same `match`-not-Dictionary shape and same
## null-guarding as `_run_rollover_step`, and for the same reasons.
func _run_post_settle_step(step: String, ended_day: int) -> void:
	match step:
		"pressure_clean_recovery":
			var engine: Object = gm.system("consequence") if gm != null else null
			if engine != null:
				engine.apply_clean_recovery(ended_day)

## One rollover step, by name.
##
## A `match` rather than a Dictionary of Callables so the list above and the work
## below cannot drift: a name with no arm here is a silent no-op, and the
## ordering test asserts every name in `ROLLOVER_ORDER` produced a trace entry.
##
## Every step is null-guarded. The lifecycle has to survive a build where a
## system is not registered — the ordering tests drive it directly — and a
## missing owner must read as "that step did nothing" rather than crash the
## whole night.
func _run_rollover_step(step: String, today: int) -> void:
	match step:
		"pressure_bleed":
			var engine: Object = gm.system("consequence") if gm != null else null
			if engine != null:
				engine.apply_pressure_bleed(today)
		"pressure_recovery":
			var engine: Object = gm.system("consequence") if gm != null else null
			if engine != null:
				engine.apply_pressure_recovery(today)
		"financial_decay":
			var engine: Object = gm.system("consequence") if gm != null else null
			if engine != null:
				engine.decay_financial_pressure()
		"financial_fold":
			var engine: Object = gm.system("consequence") if gm != null else null
			if engine != null:
				engine.fold_financial_pressure()
		"heat_stop":
			var heat: Object = gm.system("heat") if gm != null else null
			if heat != null:
				heat.settle_street_stop(today)
		"heat_decay":
			var heat: Object = gm.system("heat") if gm != null else null
			if heat != null:
				heat.settle_quiet_day()
		"exposure":
			var exposure: Node = _autoload("Exposure")
			if exposure != null:
				exposure.rollover()
		"curtis":
			var curtis: Node = _autoload("Curtis")
			if curtis != null:
				curtis.rollover()

## One day-start step, by name. Same shape and same null-guarding as
## `_run_rollover_step`.
func _run_day_start_step(step: String, today: int) -> void:
	# Handled before the engine guard below, because this one does not need the
	# engine and a build without it must still start the day with a clean
	# quiet-day flag. Otherwise a run whose consequence system failed to
	# register would carry yesterday's noise forever and never decay again.
	if step == "stickup_day_reset":
		# Null-guarded like every other step: the ordering tests drive this
		# lifecycle directly, and a missing owner has to read as "that step did
		# nothing" rather than crash the whole night.
		var stick: Object = gm.system("stickup") if gm != null else null
		if stick != null:
			stick.day_reset(today)
		return
	if step == "heat_day_reset":
		gs.heat_gain_today = 0.0
		# The day's walk count rides the same step. Both are "what has already
		# happened today", both are read by a falloff, and giving the second one
		# its own step would put a name in the declared order that does nothing
		# the first does not already do at the same moment.
		gs.wanders_today = 0
		# Today's Take rides the same step for the same reason: it is also
		# "what has already happened today," cleared as today begins.
		gs.todays_earnings = {}
		return
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return
	match step:
		"expire_retaliation":
			engine.expire_stale(today)
		"surface_delayed":
			# The district the player is actually standing in. A retaliation
			# waits for presence and does not travel (TI-003 regression #29).
			engine.try_surface_delayed(today, str(gs.current_district_id))
		"retaliation_ambient":
			# PX-003 §8's ambient signal. Reads the same presence gate; writes to
			# the activity feed and nowhere else.
			engine.push_retaliation_ambient(today)

func _autoload(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/%s" % node_name)

## MORNING, without reaching into TimeSystem for a constant it owns. Duplicated
## as a literal rather than imported: this file must stay constructible without
## a live TimeSystem so the ordering tests can drive it directly.
const TimeSystem_SLOT_MORNING := "MORNING"

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
##   2. SETTLE      — crew · territory · shark · jobs · obligations, in that order
##   3. POST_SETTLE — hooks
##   4. INCREMENT   — day += 1, slot back to MORNING
##   5. ROLLOVER    — TI-003 §9's post-increment lifecycle, in `ROLLOVER_ORDER`
##   6. MARKET      — economy.evolve(), then `day_crossed` for legacy listeners
##   7. DAY_START   — hooks (retaliation expiry and activation)
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
## ## A divergence this build preserves rather than corrects
##
## Canon's `confirmDayEnd` settles crew and shark ABOVE the increment, so both
## see the ending day. This port has always settled them below it, so both see
## the NEW day — and `crew.settle_night` / `shark.settle_night` therefore still
## compute against `ended_day + 1` to keep their behaviour identical.
##
## That is deliberate. This build creates the seam; moving when wages bite or a
## note comes due is a timing change with real consequences for a run, and it
## belongs in its own slice rather than riding along inside a refactor that
## claims to change nothing. The `+ 1` is commented at both call sites and
## filed. When it is corrected, those two lines are the whole change.

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
const ROLLOVER_ORDER: Array[String] = [
	"pressure_bleed",
	"pressure_recovery",
	"financial_decay",
	"financial_fold",
	"exposure",
	"curtis",
]

## TI-003 §9 step 6's day-start lifecycle. Expiry before activation, and the
## order is not arbitrary: a row that ran out overnight must be gone before
## anything asks what is eligible, or the day's one delayed slot could be spent
## on an encounter that had already expired.
##
## Declared here rather than registered as a `day_start_hook` because these are
## the lifecycle's own work, not somebody else's. The hooks stay empty and
## available, and `clear_hooks()` cannot remove the game.
const DAY_START_ORDER: Array[String] = [
	"expire_retaliation",
	"surface_delayed",
]

## The settlement order, declared. Each entry is the system name as registered
## in GameManager; each of those systems exposes `settle_night(ended_day: int)`.
##
## Crew first because canon settles wages before anything reads whether they
## were paid — an unpaid crew is worth less power, and territory income is
## computed off that. Obligations last because rent and the phone bill are what
## end a run, and everything that could still pay them has had its turn.
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

func _autoload(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/%s" % node_name)

## MORNING, without reaching into TimeSystem for a constant it owns. Duplicated
## as a literal rather than imported: this file must stay constructible without
## a live TimeSystem so the ordering tests can drive it directly.
const TimeSystem_SLOT_MORNING := "MORNING"

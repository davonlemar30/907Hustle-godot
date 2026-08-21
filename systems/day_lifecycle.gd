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
##   3. POST_SETTLE — hooks (TI-003: Pressure rollover, retaliation activation)
##   4. INCREMENT   — day += 1, slot back to MORNING
##   5. MARKET      — economy.evolve(), then `day_crossed` for legacy listeners
##   6. DAY_START   — hooks (TI-003: Financial Pressure decay, Exposure delivery)
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
const MARKET := "MARKET"
const DAY_START := "DAY_START"

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

	# 5. MARKET — the overnight walk, then the legacy signal.
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

	# 6. DAY_START — the new day is on the clock and the board is priced.
	_mark(DAY_START)
	for hook in day_start_hooks:
		if hook.is_valid():
			hook.call(gs.day)

## MORNING, without reaching into TimeSystem for a constant it owns. Duplicated
## as a literal rather than imported: this file must stay constructible without
## a live TimeSystem so the ordering tests can drive it directly.
const TimeSystem_SLOT_MORNING := "MORNING"

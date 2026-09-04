extends Node
## GameManager — the action layer between UI and GameState.
##
## UI never mutates GameState directly; it calls dispatch(action, payload).
## Registered systems handle actions and mutate GameState; on success GameManager
## fires exactly one GameState.notify_changed(). On failure it emits action_failed
## (insufficient cash, full cargo, etc.) and leaves state untouched.

signal action_failed(action: String, reason: String)
## Fired after a successful dispatch that opened one or more gates, with the
## surface ids `announcer.gd::announce_since()` just spoke about (registry
## order). Emitted before `notify_changed()`, so `ScreenManager`'s queue is
## populated before any screen's refresh runs. Not fired when nothing opened.
signal surfaces_announced(surface_ids: Array)

var _systems: Array = []
## Direct registry for collaborator lookups. Dispatch keeps `_systems` because
## its order is the routing contract, but `system()` sits on 200+ static call
## sites and should not rescan every registered system each time the build adds
## another feature.
var _systems_by_name: Dictionary = {}
var _gs: Node
var _dispatch_depth: int = 0

func _ready() -> void:
	_gs = get_node("/root/GameState")
	var rng := get_node("/root/RngManager")

	# Attributes is constructed first: stickup, boost, shark and 907List all
	# read it, and none of them can be built without it.
	var attributes = preload("res://systems/attributes.gd").new()
	attributes.setup(_gs)
	register_system("attributes", attributes)

	# The run's first instant. No collaborators at all, so it is built early and
	# its position says nothing — see systems/run_start.gd for why it is a
	# system rather than two lines on the naming screen.
	var run_start = preload("res://systems/run_start.gd").new()
	run_start.setup(_gs)
	register_system("run", run_start)

	# The outcome resolver is pure — no GameState handle at all — and every
	# risky surface reaches it, so it is built alongside attributes rather than
	# next to any one of its callers.
	var outcome_resolver = preload("res://systems/outcome_resolver.gd").new()
	outcome_resolver.setup(rng)
	register_system("outcome_resolver", outcome_resolver)

	# The requirement evaluator is pure — no GameState, no autoloads, all input
	# through its parameters — so it is built here with nothing to wire. Nothing
	# queries it yet; FS-001.6 is the caller.
	var requirements = preload("res://systems/requirements.gd").new()
	register_system("requirements", requirements)

	# Wallet and Heat are the shared mutation owners (TI-003 §§6-7), so they are
	# constructed before every system that moves money or generates heat —
	# which is most of them. Neither handles an action; both are reached through
	# `system()` at call time.
	var wallet = preload("res://systems/wallet.gd").new()
	wallet.setup(_gs)
	register_system("wallet", wallet)

	# Heat takes the manager rather than Crew directly: it reads Deshawn's
	# multiplier through `system("crew")` at call time, and crew is constructed
	# well below this line.
	var heat = preload("res://systems/heat.gd").new()
	heat.setup(_gs, self)
	register_system("heat", heat)

	var economy = preload("res://systems/economy.gd").new()
	economy.setup(_gs, rng, self)
	register_system("economy", economy)

	# Phone is constructed before time because every slot advance asks it
	# whether a paid-for line comes back on (canon advanceRun).
	var phone = preload("res://systems/phone.gd").new()
	phone.setup(_gs, rng)
	register_system("phone", phone)

	# The night sequence, constructed before time because time delegates to it.
	# It reaches its settlers through `system()` at call time rather than by
	# construction order, so it does not care that most of them are built below.
	var day_lifecycle = preload("res://systems/day_lifecycle.gd").new()
	day_lifecycle.setup(_gs, self, economy)
	register_system("day_lifecycle", day_lifecycle)

	var time = preload("res://systems/time_system.gd").new()
	time.setup(_gs, economy, phone, day_lifecycle)
	register_system("time", time)

	var recovery = preload("res://systems/recovery.gd").new()
	recovery.setup(_gs, time, self)
	register_system("recovery", recovery)

	var travel = preload("res://systems/travel.gd").new()
	travel.setup(_gs, time, self)
	register_system("travel", travel)

	# Jobs and obligations both hang off day_crossed, which time_system emits.
	var jobs = preload("res://systems/jobs.gd").new()
	jobs.setup(_gs, rng, time, self, attributes)
	time.attach_jobs(jobs)
	register_system("jobs", jobs)

	var obligations = preload("res://systems/obligations.gd").new()
	obligations.setup(_gs, phone, self)
	register_system("obligations", obligations)

	var stickup = preload("res://systems/stickup.gd").new()
	stickup.setup(_gs, rng, time, self, attributes)
	register_system("stickup", stickup)

	var shark = preload("res://systems/shark.gd").new()
	shark.setup(_gs, rng, self, attributes)
	register_system("shark", shark)

	# Dre Lending & Loan-Shark Progression, PR A. Registered right after
	# shark, matching where "dre" sits in DayLifecycle.SETTLE_ORDER — Dre is
	# the gatekeeper TO the shark hustle, so it is built beside the system it
	# will eventually gate rather than off in an unrelated part of this list.
	var dre_lender = preload("res://systems/dre_lender.gd").new()
	dre_lender.setup(_gs, self, time)
	register_system("dre", dre_lender)

	# Street Opportunity and Mission System, PR C. Registered right after Dre,
	# its only consumer this build. `dispatch()` below calls its `reconcile()`
	# on every successful action, not just the ones it itself handles — that
	# is the one seam this system needs; see its own header.
	var opportunities = preload("res://systems/opportunities.gd").new()
	opportunities.setup(_gs, self)
	register_system("opportunities", opportunities)

	# PR D: DRE-ARC-03 and the player-default collection response, both
	# through the confrontation/consequence chassis. Registered as a system
	# (for its two player-dispatched actions) AND, below alongside the other
	# source adapters, as consequence_engine's adapter for "dre_collection".
	var dre_collector = preload("res://systems/dre_collector.gd").new()
	dre_collector.setup(_gs, self, rng, attributes)
	register_system("dre_collector", dre_collector)

	# 0.5.0 PR D (DOOR-D1/D2): reaches Dre, shark (the Book) and obligations
	# (rent) through `system()` at call time, same as everything else here —
	# constructed after all three exist so nothing it calls on day one could
	# ever be null.
	var doorstep = preload("res://systems/doorstep.gd").new()
	doorstep.setup(_gs, self)
	register_system("doorstep", doorstep)

	# SQ-D10 (0.6.0 PR D): the corner. Wires `MARKET_SCRIPTS`, authored since
	# the loop was written and consumed by nothing until now. Dispatches no
	# action of its own -- it is a trigger site plus a chain adapter.
	var corner = preload("res://systems/corner.gd").new()
	corner.setup(_gs, self)
	register_system("corner", corner)
	# DOOR-D2: runs after every `DAY_START_ORDER` step, so a chain it opens
	# cannot land ahead of anything else the day already decided -- see
	# `DayLifecycle`'s own "7. DAY_START -- DAY_START_ORDER, then hooks".
	day_lifecycle.add_day_start_hook(doorstep.try_force_visit)

	var nine07list = preload("res://systems/nine07list.gd").new()
	nine07list.setup(_gs, rng, time, attributes, self)
	register_system("list", nine07list)

	var boost = preload("res://systems/boost.gd").new()
	boost.setup(_gs, rng, time, self, attributes)
	register_system("boost", boost)

	# Crew is registered after the surfaces that consult it, but registration
	# order only decides dispatch routing, not construction — the surfaces look
	# it up through system() at call time.
	var crew = preload("res://systems/crew.gd").new()
	crew.setup(_gs, self)
	register_system("crew", crew)

	# Crew Operations sits between crew and territory: it reads crew records and
	# the requirement evaluator, and nothing reads it yet.
	var crew_operations = preload("res://systems/crew_operations.gd").new()
	crew_operations.setup(_gs, self, requirements)
	register_system("crew_operations", crew_operations)

	# The 907List domain adapter. Built after both halves it bridges: it needs
	# the list system for the board and the shared settlement path, and the
	# coordinator to register itself with. Registration is runtime, so this
	# happens on every boot including after a load.
	var list_adapter = preload("res://systems/list_adapter.gd").new()
	list_adapter.setup(_gs, self, nine07list, crew_operations)
	register_system("list_adapter", list_adapter)

	# The other two domain adapters (batch 6b). Same runtime registration as the
	# 907List one and for the same reason: an adapter is a handle, and a handle
	# never goes in a save.
	var runner_adapter = preload("res://systems/runner_adapter.gd").new()
	runner_adapter.setup(_gs, self, crew_operations)
	register_system("runner_adapter", runner_adapter)

	var fixer_adapter = preload("res://systems/fixer_adapter.gd").new()
	fixer_adapter.setup(_gs, self, crew_operations)
	register_system("fixer_adapter", fixer_adapter)
	# BR-D6 (0.9.0 PR 5): two more operations on the same substrate.
	var scout_adapter = preload("res://systems/scout_adapter.gd").new()
	scout_adapter.setup(_gs, self, crew_operations)
	register_system("scout_adapter", scout_adapter)
	var enforcer_adapter = preload("res://systems/enforcer_adapter.gd").new()
	enforcer_adapter.setup(_gs, self, crew_operations)
	register_system("enforcer_adapter", enforcer_adapter)

	# The venue interiors. Built after time because both of its actions spend a
	# slot, and after attributes because both of them train one — though it
	# reaches attributes through `system()` at call time like everything else.
	var venues = preload("res://systems/venues.gd").new()
	venues.setup(_gs, self, time)
	register_system("venues", venues)

	# Wander. Built after time (it spends a slot) and after requirements (every
	# card is gated through the one evaluator), though like everything else it
	# reaches its collaborators through `system()` at call time.
	var wander = preload("res://systems/wander.gd").new()
	wander.setup(_gs, self, rng, time, requirements)
	register_system("wander", wander)

	var territory = preload("res://systems/territory.gd").new()
	territory.setup(_gs, self)
	register_system("territory", territory)

	# The arrest owner. Built before the consequence engine because the engine
	# asks it for booking projections, and after the surfaces whose gates feed it
	# — though both reach each other through `system()` at call time, so this
	# ordering is documentation rather than a dependency.
	var arrest = preload("res://systems/arrest.gd").new()
	arrest.setup(_gs, self)
	register_system("arrest", arrest)

	# The delayed answer. Built before the engine because the engine registers it
	# as a resolver, and after Stick because Stick asks it to schedule.
	var retaliation = preload("res://systems/retaliation.gd").new()
	retaliation.setup(_gs, self, rng)
	register_system("retaliation", retaliation)

	# The consequence layer, last: it reaches its source adapters through a
	# runtime registry, so every system it can drive has to exist first.
	#
	# Registration happens on every boot INCLUDING after a load, which is what
	# lets a chain reloaded from a save find its source again — the save carries
	# `action_id`, a String, and this is what turns it back into a system.
	# Nothing here is ever serialised (TI-003 §1, §26).
	# The announcer. Built late because it asks the access layer about every
	# gate in the build and the access layer asks GameManager about some of
	# them, but like everything else it resolves its collaborators at call time.
	var announcer = preload("res://systems/announcer.gd").new()
	announcer.setup(_gs, self)
	register_system("announcer", announcer)

	# Word of Mouth (0.1.2). Built the same way and for the same reason: it
	# reaches economy, the consequence engine and the phone at call time
	# rather than at construction, so registration order in front of it does
	# not matter.
	var tips = preload("res://systems/tips.gd").new()
	tips.setup(_gs, self, rng)
	register_system("tips", tips)

	var consequence_engine = preload("res://systems/consequence_engine.gd").new()
	consequence_engine.setup(_gs, self)
	consequence_engine.register_source_adapter("boost", boost)
	consequence_engine.register_source_adapter("stickup", stickup)
	# A delayed consequence resolves itself: the robbery that caused it is two
	# days gone and its tables have nothing to say about what happens now.
	consequence_engine.register_source_adapter("retaliation", retaliation)
	# The fourth kind (batch 10). A wander encounter resolves itself, the same
	# as a retaliation does and for the same reason: the walk that produced it
	# is over, and there is no source system holding a table about it.
	consequence_engine.register_source_adapter("wander", wander)
	# PR D: both of dre_collector's chains (DRE-ARC-03's "hard" road and the
	# player-default ultimatum) open with source.action_id == "dre_collection"
	# — one adapter serving two authored encounters, told apart inside
	# resolve_consequence() by chain.source.kind, not by two separate keys
	# here.
	consequence_engine.register_source_adapter("dre_collection", dre_collector)
	# 0.5.0 PR D (DOOR-D1/D2): the doorstep's own forced Book/rent decisions
	# and all three families' enforcement rooms open with
	# source.action_id == "doorstep" -- Dre's own COLLECTION stage stays
	# `dre_collection`'s chain (doorstep.gd only triggers it, never resolves
	# it), told apart from doorstep's own book/rent/enforcement chains the
	# same way dre_collector's two encounters already are: by
	# chain.source.kind, not by a second action_id.
	consequence_engine.register_source_adapter("doorstep", doorstep)
	# Both corner scripts share one adapter -- see `systems/corner.gd`'s header
	# on why two action ids would be two places for the round rules to drift.
	consequence_engine.register_source_adapter("corner", corner)
	# SQ-D10 (0.6.0 PR E): the 907List meetup scene. The list system already
	# owns the meet and its outcome roll, so it owns the sheet that roll opens
	# -- a separate adapter would put the scene's exit table somewhere the
	# payout it is deciding about does not live.
	consequence_engine.register_source_adapter("list_meetup", nine07list)
	# The seventh kind (0.5.0 PR C, STR-D4): a checkpoint resolves itself the
	# same way a wander encounter does -- the trip that produced it is over,
	# and there is no source system holding a table about it.
	consequence_engine.register_source_adapter("travel", travel)
	register_system("consequence", consequence_engine)

func register_system(sys_name: String, instance: Object) -> void:
	if _systems_by_name.has(sys_name):
		push_error("GameManager: duplicate system registration '%s'." % sys_name)
		return
	_systems.append({"name": sys_name, "node": instance})
	_systems_by_name[sys_name] = instance

## Read-only handle on a system, for screens that need to ask it a question
## (e.g. "why can't I work right now?"). Mutations still go through dispatch.
func system(sys_name: String) -> Object:
	return _systems_by_name.get(sys_name, null)

## True while an action and all of its synchronous side effects are running.
## Persisted mutators on the Exposure/Curtis autoloads use this as their
## development-time ownership guard.
func is_dispatching() -> bool:
	return _dispatch_depth > 0

## Route an action to the first system that handles it. Returns true on success.
func dispatch(action: String, payload: Dictionary = {}) -> bool:
	for entry in _systems:
		var sys = entry["node"]
		if sys.can_handle(action):
			_dispatch_depth += 1
			# The before-picture for the announcer, taken BEFORE the handler so
			# it spans everything the action causes. See `systems/announcer.gd`
			# for why a transition is measured across a dispatch rather than
			# recorded in a persisted flag.
			var announcer: Object = system("announcer")
			var gates_before: Dictionary = announcer.snapshot() if announcer != null else {}
			var result: Dictionary = sys.handle(action, payload)
			if result.get("ok", false):
				# Discovery first: an action may have just qualified an operation
				# (a tenth clean flip reaching Broker tier, a wage paid), and the
				# player should see it on the same refresh that caused it.
				#
				# This writes state directly and dispatches nothing — a nested
				# dispatch here would fire a second notify_changed() inside this
				# one's stack, and the reactive contract is one refresh per action.
				var crew_ops: Object = system("crew_operations")
				if crew_ops != null:
					crew_ops.reconcile()
				# Street Opportunity and Mission System, PR C: the declared
				# reconciliation point (design doc section 19.3 / addendum
				# "two properties that must survive" item 2). Same reasoning
				# as crew_ops immediately above — writes state directly,
				# dispatches nothing, and runs before the invariant reconcile
				# so a completed milestone's access latch is set before
				# autosave and before the announcer looks for opened gates.
				var opportunities: Object = system("opportunities")
				if opportunities != null:
					opportunities.reconcile(action, payload, result)
				# Persistent latches must settle before state_changed. SaveSystem
				# autosaves from that signal, before a screen gets to refresh.
				_gs.reconcile_persistent_invariants()
				# And THEN say what opened — after every reconcile that can open
				# a gate and before the refresh that renders the feed, so the
				# line the player reads about a surface arriving is on the same
				# render as the surface.
				if announcer != null:
					var spoken: Array = announcer.announce_since(gates_before)
					if not spoken.is_empty():
						surfaces_announced.emit(spoken)
				_gs.notify_changed()
				_dispatch_depth = maxi(0, _dispatch_depth - 1)
				return true
			_dispatch_depth = maxi(0, _dispatch_depth - 1)
			action_failed.emit(action, result.get("reason", "Action failed."))
			return false
	action_failed.emit(action, "No handler for '%s'." % action)
	return false

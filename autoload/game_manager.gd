extends Node
## GameManager — the action layer between UI and GameState.
##
## UI never mutates GameState directly; it calls dispatch(action, payload).
## Registered systems handle actions and mutate GameState; on success GameManager
## fires exactly one GameState.notify_changed(). On failure it emits action_failed
## (insufficient cash, full cargo, etc.) and leaves state untouched.

signal action_failed(action: String, reason: String)

var _systems: Array = []
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

	var economy = preload("res://systems/economy.gd").new()
	economy.setup(_gs, rng)
	register_system("economy", economy)

	# Phone is constructed before time because every slot advance asks it
	# whether a paid-for line comes back on (canon advanceRun).
	var phone = preload("res://systems/phone.gd").new()
	phone.setup(_gs, rng)
	register_system("phone", phone)

	var time = preload("res://systems/time_system.gd").new()
	time.setup(_gs, economy, phone)
	register_system("time", time)

	var recovery = preload("res://systems/recovery.gd").new()
	recovery.setup(_gs, time)
	register_system("recovery", recovery)

	var travel = preload("res://systems/travel.gd").new()
	travel.setup(_gs, time)
	register_system("travel", travel)

	# Jobs and obligations both hang off day_crossed, which time_system emits.
	var jobs = preload("res://systems/jobs.gd").new()
	jobs.setup(_gs, rng, time, self, attributes)
	register_system("jobs", jobs)

	var obligations = preload("res://systems/obligations.gd").new()
	obligations.setup(_gs, phone)
	register_system("obligations", obligations)

	var stickup = preload("res://systems/stickup.gd").new()
	stickup.setup(_gs, rng, time, self, attributes)
	register_system("stickup", stickup)

	var shark = preload("res://systems/shark.gd").new()
	shark.setup(_gs, rng, self, attributes)
	register_system("shark", shark)

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
	crew.setup(_gs)
	register_system("crew", crew)

	# Crew Operations sits between crew and territory: it reads crew records and
	# the requirement evaluator, and nothing reads it yet.
	var crew_operations = preload("res://systems/crew_operations.gd").new()
	crew_operations.setup(_gs, self, requirements)
	register_system("crew_operations", crew_operations)

	var territory = preload("res://systems/territory.gd").new()
	territory.setup(_gs, self)
	register_system("territory", territory)

func register_system(sys_name: String, instance: Object) -> void:
	_systems.append({"name": sys_name, "node": instance})

## Read-only handle on a system, for screens that need to ask it a question
## (e.g. "why can't I work right now?"). Mutations still go through dispatch.
func system(sys_name: String) -> Object:
	for entry in _systems:
		if entry["name"] == sys_name:
			return entry["node"]
	return null

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
				# Persistent latches must settle before state_changed. SaveSystem
				# autosaves from that signal, before a screen gets to refresh.
				_gs.reconcile_persistent_invariants()
				_gs.notify_changed()
				_dispatch_depth = maxi(0, _dispatch_depth - 1)
				return true
			_dispatch_depth = maxi(0, _dispatch_depth - 1)
			action_failed.emit(action, result.get("reason", "Action failed."))
			return false
	action_failed.emit(action, "No handler for '%s'." % action)
	return false

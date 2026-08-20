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

func _ready() -> void:
	_gs = get_node("/root/GameState")
	var rng := get_node("/root/RngManager")

	var economy = preload("res://systems/economy.gd").new()
	economy.setup(_gs, rng)
	register_system("economy", economy)

	var time = preload("res://systems/time_system.gd").new()
	time.setup(_gs, economy)
	register_system("time", time)

func register_system(sys_name: String, instance: Object) -> void:
	_systems.append({"name": sys_name, "node": instance})

## Route an action to the first system that handles it. Returns true on success.
func dispatch(action: String, payload: Dictionary = {}) -> bool:
	for entry in _systems:
		var sys = entry["node"]
		if sys.can_handle(action):
			var result: Dictionary = sys.handle(action, payload)
			if result.get("ok", false):
				_gs.notify_changed()
				return true
			action_failed.emit(action, result.get("reason", "Action failed."))
			return false
	action_failed.emit(action, "No handler for '%s'." % action)
	return false

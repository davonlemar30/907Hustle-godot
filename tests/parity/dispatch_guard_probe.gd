extends SceneTree
## Negative guard probe. Run directly; the three assertion messages are expected.
## The important result is that none of the guarded mutators changes persisted
## state when called without GameManager.dispatch().

func _init() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var gs: Node = root.get_node("GameState")
	var exposure: Node = root.get_node("Exposure")
	var curtis: Node = root.get_node("Curtis")
	var before_ledgers: Dictionary = gs.npc_ledgers.duplicate(true)
	var before_awareness: int = gs.curtis_awareness

	exposure.record_observation("yalonda", {
		"type": "financial", "event": "guard_probe", "source": "probe",
	})
	exposure.broadcast_observation({
		"type": "violence", "event": "guard_probe", "channel": "direct",
	})
	curtis.raise_awareness(1)

	var blocked: bool = gs.npc_ledgers == before_ledgers \
		and gs.curtis_awareness == before_awareness
	print("dispatch guard probe: %s" % ("PASS" if blocked else "FAIL"))
	quit(0 if blocked else 1)

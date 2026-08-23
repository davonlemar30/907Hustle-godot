extends RefCounted
## RunStart — the one action that begins a run.
##
## ## Why this exists at all
##
## The standing rule is that UI never mutates GameState: a screen calls
## `GameManager.dispatch()`, a system in `systems/` does the writing, and the
## dispatch fires exactly one `notify_changed()` and one autosave. That rule had
## exactly one hole in it, and it was on the first screen of the game —
## `name_entry.gd` wrote `gs.street_name` and called `gs.reset_to_new_game()`
## itself (86bbjxtbm).
##
## The hole mattered more than its size suggests. `GameManager.is_dispatching()`
## is the development-time ownership guard that the Exposure and Curtis
## persisted mutators check, and it was INERT on this path: starting a run is a
## write to nearly every field in GameState, and it happened with the guard
## reading false the whole way. A guard that is off during the largest write in
## the build is not a guard, it is a decoration.
##
## ## What routing it through dispatch buys, beyond the rule
##
## A new run is now autosaved when it starts. `SaveSystem` autosaves off
## `state_changed`, `reset_to_new_game()` does not emit it, and nothing else on
## the naming path did either — so a fresh run existed only in memory until the
## player took their first action. Quitting between the opening screen and the
## first tap lost the name and the run. That was never a designed behaviour;
## it was the same missing dispatch.
##
## ## Why a system of its own rather than an arm on an existing one
##
## Every other system owns a domain and this one owns the run's first instant,
## which is nobody else's domain. Hanging it off `time` or `wallet` would put
## "the run begins" inside a file whose subject is something else, and the next
## person looking for where a run starts would not find it there.
##
## Not ported and deliberately absent: difficulty, seed selection and any other
## start-of-run option. `reset_to_new_game()` is the whole of the work today and
## this is a seam, not a feature.

var gs: Node

func setup(game_state: Node) -> void:
	gs = game_state

func can_handle(action: String) -> bool:
	return action == "start_run"

func handle(action: String, payload: Dictionary) -> Dictionary:
	if action != "start_run":
		return {"ok": false, "reason": "Unknown run action."}
	return _start(str(payload.get("street_name", "")))

## Sanitises through GameState's own rule rather than trusting the caller.
##
## Canon returns the state unchanged when the sanitized name is empty
## (game-core.js:7421), so an all-punctuation entry is no more valid than a
## blank one, and this refuses rather than starting a nameless run. The screen
## disables its button on the same rule; this is the guard that holds when
## something dispatches directly.
func _start(raw_name: String) -> Dictionary:
	var chosen: String = gs.sanitize_street_name(raw_name)
	if chosen.is_empty():
		return {"ok": false, "reason": "Pick a name first."}
	gs.street_name = chosen
	gs.reset_to_new_game()
	return {"ok": true}

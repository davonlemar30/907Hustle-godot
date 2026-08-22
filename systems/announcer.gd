extends RefCounted
## Announcer — the build telling the player a door just opened.
##
## ## Why this exists
##
## Batch 14 put five of the Hustle hub's six income rows behind gates and hid
## them until they were earned. That is the right shape and it created a defect
## on its way in: a HIDDEN surface has no padlock and no hint, so a row that
## arrives on the third walk or on day 5 arrives SILENTLY. A player who wanders
## once and does not happen to reopen the Hustle screen never learns that Street
## Market exists.
##
## Hiding a surface until it is earned is only better than showing it broken if
## the game says something when it arrives. This is that sentence.
##
## ## How the transition is detected, and why not with a flag
##
## By DIFFING A SNAPSHOT across one dispatch, never by persisting an
## `announced` set.
##
## `SurfaceVisibility` is built on the rule that nothing derived is stored: every
## verdict is computed from the run's own facts, which is what makes "unlocks
## survive save/load" true by construction rather than by a migration. A stored
## "already told them" flag would be the first thing in the access layer that
## could contradict the run — a save repaired in one direction and a fact in the
## other, and no way to tell which was right.
##
## A transition is only meaningful inside the action that caused it, so that is
## where it is measured. `GameManager.dispatch()` takes a snapshot before the
## handler runs and hands it back here afterwards, once every reconcile that can
## open a gate has settled.
##
## This also gets three awkward cases right for free rather than by special
## handling:
##
##   * **Loading a save announces nothing.** A load is not a dispatch, so no
##     snapshot spans it. A run reloaded on day 20 is told nothing, which is
##     correct — nothing opened, the player earned all of it days ago.
##   * **A new run announces nothing.** `reset_to_new_game()` closes every gate,
##     and a closed gate cannot have just opened.
##   * **No schema change.** There is no field to add, no manifest entry and no
##     migration arm, which is the whole argument for not storing it.
##
## ## What it does not do
##
## It never decides WHETHER a surface is open — `SurfaceVisibility` owns that,
## and this asks. It never dispatches.
##
## **The activity feed, and only the feed.** `WanderSystem` writes a discovery
## to the feed AND to the phone's Word Around Town, and copying that here would
## be a category error: Word Around Town carries what PEOPLE SAY, and "Street
## Market is on the board" is not something anybody says. The feed is the
## build's own voice and a surface arriving is the build's own news.
##
## One line lands somewhere else for free, and it is the best thing about the
## timing. Batch 14's wander toast reads `activity_log[0]`, so on the walk that
## opens a surface the toast IS the announcement — the player wanders once and
## is told, on the screen they are standing on, that Street Market exists. That
## displaces the walk's own flavour line for that one walk, which is the right
## trade: a door opening outranks a bit of texture.

const GREEN := Color(0.451, 0.722, 0.404)

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

## No actions of its own. Registered in GameManager so callers reach it the same
## way as any system; `dispatch()` calls it directly rather than through an
## action, because it runs on EVERY successful action rather than being one.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The announcer takes no actions."}

## The before-picture. Empty when the access layer is not up, which makes
## `announce_since` a no-op rather than an announcement of everything.
func snapshot() -> Dictionary:
	var access: Node = _access()
	return access.unlocked_snapshot() if access != null else {}

## Say, once, what opened since `before` was taken. Returns the surface ids it
## spoke about, so a caller can assert on them.
##
## A surface missing from `before` is NOT treated as newly opened. That is the
## conservative direction and it is the one that matters: an empty snapshot
## means the access layer was unavailable when the action started, and the
## alternative reading would announce the entire ladder on the next dispatch.
func announce_since(before: Dictionary) -> Array:
	var access: Node = _access()
	if access == null or gs == null or before.is_empty():
		return []
	var lines: Dictionary = access.announceable()
	var spoken: Array = []
	# Registry order, so two surfaces opening on the same action are always
	# reported in the same order. Two gates CAN open at once — day 3 opens
	# 907List while a walk on the same slot could open Boost — and the player
	# reading them in a different order on a replay of the same seed would be a
	# presentation difference with no cause behind it.
	for surface_id in lines:
		var id := str(surface_id)
		if not before.has(id) or bool(before[id]):
			continue
		if not bool(access.is_unlocked(id)):
			continue
		gs.log_activity(str(lines[id]), GREEN)
		spoken.append(id)
	return spoken

func _access() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/SurfaceVisibility")

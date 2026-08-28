extends RefCounted
## Tips — Word of Mouth slice 1 (0.1.2).
##
## The day-start step that decides whether today's crew has anything to say,
## and says it on the phone if so. One seeded budget roll a day
## (`push_tip`, called from `day_lifecycle.gd`'s `"tips"` step) decides
## whether ANYTHING fires; if it does, one of three generators is drawn,
## seeded the same way `wander.gd` draws between its own pools.
##
## ## The thesis (Word of Mouth design doc)
##
## A tip is a claim about a fact the simulation already tracks, never a second
## roll wearing a name. Two standing feeds (Pherris' route, Eli's corridor)
## report live state and change nothing; one one-shot window (Tone's fat
## night) writes a real payload that `ConfrontationLoop.tip_modifiers_for()`
## already reads defensively — that seam shipped a build early so this field
## could arrive as data.
##
## ## Where this build's own prompt drifted from the ticket, and why this
## ## follows the ticket
##
## Two corrections, made against `86bbnzegb` / `86bbnk61z` and the linked
## design doc, both cross-checked against the running code before being
## treated as authoritative over the prompt that asked for this PR:
##
##   - **Eli reads carry-stop pressure, not market availability.** Both
##     tickets and the design doc say "which corridor is dry/safe today
##     (reads carry-stop pressure)" — `consequence_engine.pressure_score()`,
##     the same read `economy.resolve_carry()` already prices a trip against.
##     `TIP_MODIFIERS.corridor_clear` (the mechanical version of this, an
##     actual relief on the roll) is listed in that table already but is
##     explicitly Slice 2 ("corridor safety details") in the design doc's own
##     Build Order — this slice's Eli tip is a standing-feed READ, same lane
##     as Pherris' route push, and writes no payload.
##   - **No `phone_active` requirement on the standing feeds.** Both tickets'
##     Architecture sections list "dead phone line holds tips in
##     phone_held_inbox" as an explicit, existing behaviour — which only
##     means something if a tip CAN be generated while the line is dead.
##     `phone.push_message()` already routes to the held inbox on its own; a
##     generator that skipped itself for a dead line would make that whole
##     clause dead code.
##
## Left as the build prompt specified: Tone's fat-night window has no hard
## recruited-gate on whether it CAN fire — only on which voice tells it. An
## unrecruited Tone still gets an "Around town" line, the same anonymous
## sender `wander.gd`'s own discoveries already push under, rather than the
## whole window going dark because nobody named it. Recorded here because the
## ticket's one-line "Gated on Tone recruited" reads the other way and this is
## the more fully specified of the two designs, not a silent judgment call.

const RULES := preload("res://data/consequence_rules.gd")
const SCRIPTS := preload("res://data/confrontation_scripts.gd")
const TIP_EVENTS := preload("res://data/tip_events.gd")

const AMBIENT_SENDER := "Around town"

## One pair per T2/T3 stick target — the only ones a "fat night" ever names.
## `tone` is Tone's own voice (complete sentences, counted, terse, the design
## doc's register); `ambient` is the same news secondhand, the way
## `wander.gd` already writes an unattributed find. Adapted per target from
## each target's own authored `desc` in `game_state.gd`, not invented.
const FAT_NIGHT_COPY := {
	"spenard_fuel_till": {
		"tone": "The Chevron on Spenard is running light after midnight. One clerk, and the till's been fattening since open.",
		"ambient": "heard the till at the Spenard Chevron gets heavy after midnight. one clerk, and nobody's watching it.",
	},
	"downtown_fuel_till": {
		"tone": "The Holiday on C Street is one clerk tonight, no partition. Register's been sitting open all shift.",
		"ambient": "word is the Holiday register on C Street is wide open tonight. one clerk, no glass between you.",
	},
	"rec_center_dice": {
		"tone": "The dice game behind the rec center is heavy tonight. Folding-table money since noon. No cameras on that side.",
		"ambient": "heard the game behind the rec center is fat tonight. money on the table since noon.",
	},
	"goodie_stash": {
		"tone": "Goodie's spot is sitting unguarded tonight, first time in a while. Whatever he's got is just sitting there.",
		"ambient": "word is Goodie's stash spot is wide open tonight. nobody's minding it.",
	},
}

var gs: Node
var gm: Node
var rng: Node

func setup(game_state: Node, manager: Node, rng_manager: Node) -> void:
	gs = game_state
	gm = manager
	rng = rng_manager

## No actions of its own — registered so callers reach it like any system;
## `day_lifecycle.gd` calls `push_tip` directly, the same way it calls the
## consequence engine's own ambient pushes.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "Tips take no actions."}

## The one entry point, called once from the `"tips"` `DAY_START_ORDER` step.
##
## Every seeded key below is built whole, suffix and all, at its own call
## site — never through a shared `"tips:%d" % today` prefix threaded between
## functions. The parity suite's key audit (`86bbjxtjb`'s trailing-counter
## finding) flags exactly that shape: a key ending in a varying integer
## hashes into a clustered band, and a shared prefix is one un-suffixed use
## away from being handed to a seeded draw bare.
func push_tip(today: int) -> void:
	if not _roll_budget(today):
		return
	var pool := eligible_generators()
	if pool.is_empty():
		return
	var pick: int = int(rng.seeded_int_range(gs.run_seed, "tips:%d:pick" % today,
		0, pool.size() - 1))
	match str(pool[pick]):
		"pherris":
			_generate_pherris(today)
		"eli":
			_generate_eli(today)
		"fat_night":
			_generate_fat_night(today)

# --- the budget roll -----------------------------------------------------

## Wander's own ramp, renamed: base chance, +per-miss, capped, reset on a
## fire. Returns true on a fire. `tip_misses` is the persisted counter this
## reads and writes — see `game_state.gd` for why it is a field of its own
## rather than reusing `wander_misses`.
func _roll_budget(today: int) -> bool:
	var chance: float = minf(TIP_EVENTS.BUDGET_CAP,
		TIP_EVENTS.BUDGET_BASE
			+ TIP_EVENTS.BUDGET_PER_MISS * float(maxi(0, int(gs.tip_misses))))
	if float(rng.seeded_random(gs.run_seed, "tips:%d:budget" % today)) < chance:
		gs.tip_misses = 0
		return true
	gs.tip_misses = mini(int(gs.tip_misses) + 1, int(TIP_EVENTS.miss_ceiling()))
	return false

# --- eligibility -------------------------------------------------------------
#
# Public and side-effect-free, same as `stickup.gd::visible_targets()` or
# `economy.gd::known_routes()` — a read anyone (a screen, a debug view, this
# system's own suite) can ask without rolling the budget or writing anything.

func eligible_generators() -> Array:
	var out: Array = []
	if pherris_eligible():
		out.append("pherris")
	if eli_eligible():
		out.append("eli")
	if not fat_night_targets().is_empty():
		out.append("fat_night")
	return out

func pherris_eligible() -> bool:
	if not gs.is_recruited("pherris"):
		return false
	if int(gs.crew_record("pherris").get("tier", 0)) < 1:
		return false
	var economy: Object = gm.system("economy") if gm != null else null
	return economy != null and not (economy.known_routes() as Array).is_empty()

## A corridor read needs two corridors — with one district unlocked there is
## nowhere else to name as the safer one.
func eli_eligible() -> bool:
	return gs.is_recruited("eli") and (gs.districts_unlocked as Array).size() >= 2

## T2/T3 only — a "fat" night is the two biggest paydays on the board, never
## the five ordinary marks. Filtered to targets the tier ladder has actually
## opened and the district ladder has actually reached, same shape
## `stickup.gd::visible_targets()` uses minus its current-district
## restriction: a tip can name a corner you are not standing in.
func fat_night_targets() -> Array:
	if not _stickup_unlocked():
		return []
	var out: Array = []
	for entry in (gs.stick_targets as Array):
		var target: Dictionary = entry
		var tier: int = int(target.get("tier", 1))
		if tier < 2 or tier > int(gs.stick_tier):
			continue
		if not str(target.get("area", "")) in (gs.districts_unlocked as Array):
			continue
		out.append(target)
	return out

func _stickup_unlocked() -> bool:
	var access: Node = _access()
	return access != null and bool(access.is_unlocked(str(access.HUSTLE_STICKUP)))

## `SurfaceVisibility` is an autoload with no tree of its own to reach it
## from — `announcer.gd` solves the same problem the same way.
func _access() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/SurfaceVisibility")

# --- generators --------------------------------------------------------------

## Pherris' morning route push. Her signature double — two texts, same
## payload, because that is how she actually types rather than because the
## information needs two messages.
func _generate_pherris(today: int) -> void:
	var economy: Object = gm.system("economy") if gm != null else null
	if economy == null:
		return
	var routes: Array = economy.known_routes()
	if routes.is_empty():
		return
	var phone: Object = gm.system("phone") if gm != null else null
	if phone == null:
		return
	var route: Dictionary = routes[0]
	var line: String = "%s going %d %s. they're %d where you stand. that's the trip paid twice before lunch" % [
		str(route.get("product_name", "")).to_lower(),
		int(route.get("pays", 0)),
		str(route.get("name", "")).to_lower(),
		int(route.get("cost", 0)),
	]
	var action := {"kind": "tip", "expires_day": today, "slots": []}
	phone.push_message("Pherris", line, action)
	phone.push_message("Pherris", "board walks tonight. move or don't", action)

## Eli's corridor read: the unlocked district with the lowest carry-stop
## pressure right now. Informational only in this slice — see the header for
## why this is not `TIP_MODIFIERS.corridor_clear`.
func _generate_eli(today: int) -> void:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return
	var phone: Object = gm.system("phone") if gm != null else null
	if phone == null:
		return
	var best_id := ""
	var best_score := INF
	for entry in (gs.districts_unlocked as Array):
		var district_id := str(entry)
		var score: float = float(engine.pressure_score(district_id, RULES.FAMILY_MARKET))
		if score < best_score:
			best_score = score
			best_id = district_id
	if best_id.is_empty():
		return
	var text: String = "%s is quiet right now. nobody's watching that road today. if you're carrying, that's the way through" \
		% _district_name(best_id).to_lower()
	phone.push_message("Eli", text, {"kind": "tip", "expires_day": today, "slots": []})

## Tone's fat night: names a T2/T3 target, writes the payload the stickup
## room reads through `ConfrontationLoop.tip_modifiers_for()`, and texts it in
## whichever voice is actually on the crew. The payload and the text commit
## together — no world state changes on a target this build has no copy for.
func _generate_fat_night(today: int) -> void:
	var targets := fat_night_targets()
	if targets.is_empty():
		return
	var pick: int = int(rng.seeded_int_range(gs.run_seed, "tips:%d:fat_night_target" % today,
		0, targets.size() - 1))
	var target: Dictionary = targets[pick]
	var target_id := str(target.get("id", ""))
	var copy: Dictionary = FAT_NIGHT_COPY.get(target_id, {})
	var sender := AMBIENT_SENDER
	var text: String = str(copy.get("ambient", ""))
	if gs.is_recruited("tone"):
		sender = "Tone"
		text = str(copy.get("tone", ""))
	if text.is_empty():
		return
	var phone: Object = gm.system("phone") if gm != null else null
	if phone == null:
		return
	var tier: int = int(target.get("tier", 2))
	var by_tier: Dictionary = SCRIPTS.TIP_MODIFIERS["fat_night"]["take_multiplier"]
	var multiplier: float = float(by_tier.get(tier, 2.0))
	var raw_slots: Array = target.get("slots", [])
	var slots: Array = (raw_slots if not raw_slots.is_empty() else [2, 3]).duplicate()
	gs.tip_effects.append({
		"type": "fat_night", "target_id": target_id, "day": today,
		"slots": slots.duplicate(), "multiplier": multiplier,
	})
	phone.push_message(sender, text, {"kind": "tip", "expires_day": today, "slots": slots})

func _district_name(district_id: String) -> String:
	for entry in (gs.districts as Array):
		var district: Dictionary = entry
		if str(district.get("id", "")) == district_id:
			return str(district.get("name", district_id))
	return district_id

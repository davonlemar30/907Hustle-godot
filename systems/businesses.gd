extends RefCounted
## Businesses — the second axis over the board. HSS-D1..D3, D5, D8 (1.5.0).
##
## ## What this is
##
## Territory is ground. A corner pays in twenties because you are standing on
## it, and nothing on that ground has a name, a face, or a reason to pay you
## other than that. A business is a **person with a till and a ledger** on the
## same board: the Wash & Go on the Wash & Go Lot is Lani, and whether Lani
## pays you is a different question from whether the lot is yours.
##
## The two axes do not settle each other. `territory_nodes` says whose ground
## it is. `gs.businesses` says who the business on it answers to. A player can
## hold the lot and have no arrangement, or have an arrangement on a lot that
## is Curtis's — and both of those are states the board has to be able to say
## out loud.
##
## ## What ships here, and what does not
##
## This file owns discovery, the owners' seeded history, the nightly
## settlement and the reads Turf renders. It owns **no verb**: ASK, LEAN and
## TAKE arrive with the requirement types and the confrontation chain, and
## until they do nothing in the game moves a business off its authored
## starting allegiance. A test can place an arrangement in the row and this
## file will pay it, which is exactly how the settlement is proved before the
## verbs that produce it exist.
##
## It owns **no capability**. What a laundromat does for the organization is
## P7. The take is dirty on purpose (see `settle_night`): the whole reason
## laundering is a want in 1.6.0 is that this money is not clean, and a
## laundromat that paid clean here would ship P7's capability by accident.
##
## ## Discovery, and why presence means known
##
## A row is created the first time a producer fires for it and never before,
## so an absent key reads as "the player has not met this place". Every
## producer is a latch the game already had:
##
##   - the linked Boost target has been clocked  (the Chevron)
##   - the linked job is on the board or being worked  (the Wash & Go)
##   - the node's district is visible on Turf  (the Motel Row)
##   - a morning the beater will not start, or a walk after day five  (the garage)
##
## Because every one of those is a latch a **v34 save already carries**, a save
## from before this feature loads with `{}` and discovers its businesses from
## its own history on the first read. Nothing is reconstructed and nothing is
## guessed: `refresh_discovery()` is idempotent and is the only road onto the
## board.

const DEFS := preload("res://data/business_definitions.gd")

const GREEN := Color(0.451, 0.722, 0.404)
const AMBER := Color(0.882, 0.651, 0.227)

## HSS-D2: the garage's ambient meeting is available from this day, for a
## player whose beater has never died on them. Both producers ship, once
## each — a player with a car meets Vic the morning it will not turn over, and
## a player without one meets him on foot.
const GARAGE_WALK_DAY := 5

## What the wallet calls this money, and what the ending sums it under. A new
## source is a new key and nothing else — `record_earning` is free-keyed and
## `ending.gd` sums every key it finds.
const EARNING_SOURCE := "businesses"
const WALLET_SOURCE_ID := "business_take"

## HSS-D4: the lean's odds, in the `contest_chance` shape -- your crew and your
## kit against whoever the owner has. A business is not a corner Curtis
## garrisons, so the base is friendlier than `CONTEST_BASE` and the other side
## does not grow; what grows is the owner's willingness to say no, which is why
## a business already under pressure is harder to lean on again.
const LEAN_BASE := 0.55
const LEAN_PER_CREW := 0.08
const LEAN_PER_SOLDIER := 0.03
const LEAN_PER_BAND := 0.10
const LEAN_MIN := 0.10
const LEAN_MAX := 0.85
## What a lean costs when it goes wrong, in the shape a contest loss already
## takes (`territory.gd`'s CONTEST_LOSS_*).
const LEAN_LOSS_HEALTH := 6
const LEAN_LOSS_AWARENESS := 1
## HSS-D6: District Pressure per lean, under the shipped `stick` family.
##
## The family is `stick`, not a new one and not FAMILY_NONE. A lean is a
## robbery in slow motion and the police read it that way -- the same people
## who answer a till going out the door answer a shop owner who has stopped
## saying why her window is broken. `stick` is also the family whose district
## read already exists, so this adds pressure the map already knows how to
## show. The owner's alternative was no District Pressure at all, which would
## have made the squeeze free in the one currency the city uses to answer it.
const LEAN_PRESSURE_FAMILY := "stick"
const LEAN_PRESSURE := 1.0
const LEAN_PRESSURE_DAILY_CAP := 2.0

## HSS-D7: the break. At BREAKING, one seeded roll a night over the row's own
## `break_weights`.
##
## **The DAY goes first in the key, and that is not a style preference.**
## `rng_manager.gd`'s own header states the contract: FNV-1a's high bits barely
## move when a small counter is appended to the tail, and `seeded_random` reads
## exactly those high bits. Keyed as `business_break:<id>:<day>` the nightly
## rolls clustered hard -- a live run produced 0.356, 0.360, 0.333, 0.337,
## 0.340, 0.344 on six consecutive nights, which is the same break outcome six
## times running rather than a roll. `seeded_shuffle` puts its varying index at
## the front for this reason and calls it part of the parity contract; this
## does the same.
const BREAK_KEY := "%d:business_break:%s"
## What each outcome does, in the currencies the game already has.
const BREAK_CLOSE_HEAT := 0.0
const BREAK_POLICE_HEAT := 3.0
const BREAK_POLICE_PRESSURE := 1.0
const BREAK_POLICE_PRESSURE_CAP := 1.0
const BREAK_CURTIS_AWARENESS := 1
## An owner who fought you off once is harder to lean on again, and that is
## what "contested odds" means on a row that has already resisted.
const LEAN_AFTER_RESIST := 0.25

## HSS-D4: TAKE. A lean at one of Curtis's, on his odds rather than hers --
## the same shape `territory.contest_chance` uses, because it is the same
## fight: your crew and your kit against whoever he left standing in there.
const TAKE_BASE := 0.35
const TAKE_PER_CREW := 0.08
const TAKE_PER_SOLDIER := 0.04
const TAKE_AWARENESS := 0.02
const TAKE_MIN := 0.10
const TAKE_MAX := 0.85
## A win is loud. Priced at Territory's own number rather than a second one.
const TAKE_WIN_AWARENESS := 2
const TAKE_LOSS_AWARENESS := 3
const TAKE_LOSS_HEALTH := 8

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

## HSS-D4: two ways in. ASK costs a relationship and pays the base; LEAN costs
## everything else and pays a little more. There is no third verb for the crew
## -- the lean's odds already read them, the way a contest's do.
func can_handle(action: String) -> bool:
	return action in ["business_ask", "business_lean", "business_walk_away",
		"business_take"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	var id: String = str(payload.get("business_id", ""))
	match action:
		"business_ask":
			return _ask(id)
		"business_lean":
			return _lean(id)
		"business_walk_away":
			return _walk_away(id)
		"business_take":
			return _take(id)
	return {"ok": false, "reason": "Unknown business action."}

func _wallet() -> Object:
	return gm.system("wallet")

## HSS-D6: a business's heat is its own line. It goes through `apply_gain` with
## no family -- protection money is not one of TI-003 §7's three -- and it is
## deliberately NOT folded into `territory.nightly_heat()`, which Turf's
## district card reads and would otherwise count twice.
func _heat() -> Object:
	return gm.system("heat")

func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

# --- discovery --------------------------------------------------------------

## Every producer, evaluated against the state as it stands. Idempotent and
## cheap: four rows, each a handful of membership tests, and a row that already
## exists is never touched. Called from the latches that fire it and from every
## read below, so no screen can render a board that is one latch out of date.
func refresh_discovery() -> void:
	if gs == null:
		return
	for definition in DEFS.BUSINESSES:
		var id := str(definition["id"])
		if gs.businesses.has(id):
			continue
		if not _discovered(definition):
			continue
		_create_row(definition)
	_seed_pending_history()

## Has any producer fired for this business yet?
func _discovered(definition: Dictionary) -> bool:
	var links: Dictionary = definition.get("links", {})

	# The Boost latch. `boost_targets_discovered` is one-way and persists by
	# the shipped target id, so a save that clocked the Chevron in 0.4.0
	# already knows the place this row describes.
	var boost_id := str(links.get("boost", ""))
	if not boost_id.is_empty() and boost_id in gs.boost_targets_discovered:
		return true

	# The job latch. Discovered OR held — a player who has been hired at the
	# Wash & Go knows it whether or not the discovery array remembers how.
	var job_id := str(links.get("job", ""))
	if not job_id.is_empty():
		if job_id in gs.jobs_discovered or str(gs.active_job_id) == job_id:
			return true
		if gs.job_records.has(job_id):
			return true

	# The board latch, for a row that stands on a node: the district is one
	# the player can see on Turf. His people are on the Motel Row before the
	# player ever looks at it, so the Motel is known — and his — on day one.
	var node_id := str(definition.get("node_id", ""))
	if not node_id.is_empty() and str(definition["district"]) in gs.districts_unlocked:
		return true

	# The garage. Off the board and off every other latch, so it gets the two
	# meetings HSS-D2 authorises: the morning the beater will not start, and
	# an ordinary walk once the run is old enough to have one.
	if str(definition["id"]) == "arctic_auto":
		if bool(gs.beater_dead_today):
			return true
		if int(gs.day) >= GARAGE_WALK_DAY and str(definition["district"]) == str(gs.current_district_id):
			return true

	return false

## The row, at the authored starting allegiance. `history_seeded` is false so
## the owner's ledger is written once, on the next tick that can write it.
func _create_row(definition: Dictionary) -> void:
	gs.businesses[str(definition["id"])] = {
		"allegiance": str(definition["starting_allegiance"]),
		"pressure": 0,
		"since_day": int(gs.day),
		"closed_until": -1,
		"last_kind": "",
		"history_seeded": false,
		# HSS-D8: whether the CURRENT unbacked stretch has already been
		# written to the owner's ledger. Once per stretch, not once per
		# night -- she notices that nobody came, she does not re-notice it
		# every morning.
		"let_down": false,
	}

# --- the owners' seeded history ---------------------------------------------

## HSS-D3. A business the player already has a history with gets that history
## written onto its owner's ledger **once**, the first time the row exists, so
## the woman at the counter is not meeting a stranger she has already watched
## get banned from the gas station across the street.
##
## `record_observation` refuses outside a `GameManager.dispatch()` and drops
## the write silently if it is called anyway (`exposure.gd`'s
## `_require_dispatch`). Discovery can fire from a screen build, which is not
## a dispatch — so the seed is a **pending** step keyed off `history_seeded`
## rather than something `_create_row` does inline. It runs on the first tick
## that can run it, and the flag makes it exactly-once across a reload.
func _seed_pending_history() -> void:
	if gm == null or not gm.is_dispatching():
		return
	var E: Node = _exposure()
	if E == null:
		return
	for id in DEFS.ids():
		var row: Variant = gs.businesses.get(id)
		if not (row is Dictionary):
			continue
		if bool((row as Dictionary).get("history_seeded", false)):
			continue
		_seed_history(E, str(id))
		(row as Dictionary)["history_seeded"] = true

## One observation per linked record the save actually carries.
##
## **What is read, and what is not.** `boost_store_bans` and
## `boost_bribes_used` both persist by the shipped Boost target id, so both are
## real per-place history and both are read here. `boost_bribes_used` is READ
## ONLY — it is 0.1.2's once-per-store latch for a paid walk and writing it, or
## letting anything here consume it, would change that rule.
##
## There is deliberately no stickup arm. The build prompt names "a stickup
## record against the linked target" as a candidate source, and the repo does
## not have one: `consequence_history` is keyed by an allocated sequence id
## (`consequence:%08d`), not by target, and no per-target stickup latch is
## persisted anywhere in `GameState`. Inventing one to satisfy the seed would
## be a schema change this build does not have, so the job record stands in as
## the third source — and it is the better one anyway, because being hired
## somewhere is a thing the owner was actually present for.
func _seed_history(E: Node, id: String) -> void:
	var definition: Dictionary = DEFS.by_id(id)
	if definition.is_empty():
		return
	var owner_id := str(definition["owner_id"])
	var links: Dictionary = definition.get("links", {})
	var boost_id := str(links.get("boost", ""))
	var job_id := str(links.get("job", ""))

	if not boost_id.is_empty() and boost_id in gs.boost_store_bans:
		# She watched somebody get walked out and told not to come back.
		E.record_observation(owner_id, {"type": "heat_exposure", "event": "banned_here",
			"location": id, "source": "witnessed"})
	if not boost_id.is_empty() and boost_id in gs.boost_bribes_used:
		# And she watched it get settled at the counter instead. On a civilian
		# lens that reads as somebody who pays rather than somebody who runs.
		E.record_observation(owner_id, {"type": "financial", "event": "settled_here",
			"location": id, "source": "witnessed"})
	if not job_id.is_empty() and gs.job_records.has(job_id):
		# She hired you. Whatever else is true, she knows your face.
		E.record_observation(owner_id, {"type": "presence", "event": "worked_here",
			"location": id, "source": "witnessed"})

# --- reads ------------------------------------------------------------------

## Every business the player knows about, in authored order. The one road onto
## the board: this refreshes discovery first, so a caller can never render a
## list that is a latch behind the state.
func known_ids() -> Array[String]:
	refresh_discovery()
	var out: Array[String] = []
	for id in DEFS.ids():
		if gs.businesses.has(id):
			out.append(id)
	return out

## The known businesses in one district, in authored order. What Turf renders
## under the district card.
func known_in(district_id: String) -> Array:
	var out: Array = []
	for id in known_ids():
		var definition: Dictionary = DEFS.by_id(id)
		if str(definition.get("district", "")) == district_id:
			out.append(definition)
	return out

func knows(id: String) -> bool:
	refresh_discovery()
	return gs.businesses.has(id)

## The live row, or `{}` for a business the player has not met. Callers treat
## an empty return as "no such business", the `territory_definitions.gd` rule.
func row_of(id: String) -> Dictionary:
	var row: Variant = gs.businesses.get(id)
	return row if row is Dictionary else {}

func allegiance_of(id: String) -> String:
	var row: Dictionary = row_of(id)
	if row.is_empty():
		return DEFS.ALLEGIANCE_NONE
	return str(row.get("allegiance", DEFS.ALLEGIANCE_NONE))

func pressure_of(id: String) -> int:
	var row: Dictionary = row_of(id)
	if row.is_empty():
		return 0
	return clampi(int(row.get("pressure", 0)), 0, int(DEFS.MAX_PRESSURE))

func is_yours(id: String) -> bool:
	return allegiance_of(id) == DEFS.ALLEGIANCE_YOURS

func is_his(id: String) -> bool:
	return allegiance_of(id) == DEFS.ALLEGIANCE_CURTIS

## Shut, and for how much longer. A closed business pays nothing and refuses
## every verb with the closure named (HSS-D7).
func is_closed(id: String) -> bool:
	return closed_nights_left(id) > 0

func closed_nights_left(id: String) -> int:
	var row: Dictionary = row_of(id)
	if row.is_empty():
		return 0
	return maxi(0, int(row.get("closed_until", -1)) - int(gs.day))

## HSS-D8: the promise. An arrangement is what the player is selling, and the
## product is that somebody is around. Backed means:
##
##   - **on a node** — the node is yours AND somebody is standing on it, either
##     a posted soldier or a hold (Tone on the district, or the player on the
##     corner for a slot). Holding a corner nobody is on does not back a
##     promise, for the same reason an unstaffed corner is a pure liability.
##   - **off the board** — you hold at least one block anywhere in the
##     district. There is no node under Arctic Auto to staff, so the read is
##     "are you a presence around here at all".
func is_backed(id: String) -> bool:
	var definition: Dictionary = DEFS.by_id(id)
	if definition.is_empty():
		return false
	var territory: Object = gm.system("territory") if gm != null else null
	if territory == null:
		return false
	var node_id := str(definition.get("node_id", ""))
	var district := str(definition["district"])
	if node_id.is_empty():
		return int(territory.held_in(district)) > 0
	if not gs.holds_block(node_id):
		return false
	var soldiers: int = int((gs.territory_nodes.get(node_id, {}) as Dictionary).get("soldiers", 0))
	return soldiers > 0 or bool(territory.is_held_down(node_id))

## What this business pays tonight, all in: the band multiplier over the
## authored base, halved when nobody is backing the promise. Zero for a
## business that is not yours, or is shut.
func take_tonight(id: String) -> int:
	if not is_yours(id) or is_closed(id):
		return 0
	var take: int = int(DEFS.take_at(id, pressure_of(id)))
	if not is_backed(id):
		# Floored, for the same reason `take_at` floors -- see its header. Half
		# of an odd take is half a dollar, and half a dollar rounds her way.
		take = floori(float(take) * float(DEFS.UNBACKED_SHARE))
	return maxi(0, take)

## Everything every arrangement pays tonight. What the Turf status line reads.
func nightly_take() -> int:
	var total := 0
	for id in known_ids():
		total += take_tonight(id)
	return total

# --- the gates, the facts, and the two ways in ------------------------------

## HSS-D4: the facts this system hands the shared evaluator. Built here rather
## than reached for inside `requirements.gd`, which reads nothing but the
## dictionary it is given -- the same contract `crew_operations._facts()` and
## `opportunities._facts()` keep.
##
## `band_order` comes off Exposure's own `BAND_FLOORS` (best first) plus the
## fall-through band, so "warmer than neutral" means whatever Exposure says it
## means and this file never authors a second ordering.
func _facts() -> Dictionary:
	var E: Node = _exposure()
	var allegiances: Dictionary = {}
	for id in gs.businesses.keys():
		allegiances[str(id)] = allegiance_of(str(id))
	var bands: Dictionary = {}
	var order: Array = []
	if E != null:
		for owner_id in DEFS.owner_ids():
			bands[str(owner_id)] = str(E.band_of(str(owner_id)))
		for row in E.BAND_FLOORS:
			order.append(str((row as Dictionary)["id"]))
		order.append("hostile")
	return {
		"business_allegiances": allegiances,
		"npc_bands": bands,
		"band_order": order,
		"crew_count": gs.recruited_crew().size(),
		"current_day": int(gs.day),
	}

func _requirements() -> Object:
	return gm.system("requirements")

## ASK: she has to be warm on you, and it has to be nobody's yet.
func ask_requirements(id: String) -> Array:
	var definition: Dictionary = DEFS.by_id(id)
	if definition.is_empty():
		return []
	return [
		{"type": "npc_band_min", "npc_id": str(definition["owner_id"]), "min_band": "warm"},
		{"type": "business_allegiance", "business_id": id,
			"allowed": [DEFS.ALLEGIANCE_NONE]},
	]

## LEAN: you have to have somebody, and it has to be nobody's or already yours.
## Curtis's is a different verb (TAKE) and a different ruling.
func lean_requirements(id: String) -> Array:
	return [
		{"type": "crew_count_min", "min": 1},
		{"type": "business_allegiance", "business_id": id,
			"allowed": [DEFS.ALLEGIANCE_NONE, DEFS.ALLEGIANCE_YOURS]},
	]

## The first failing gate, in words, or "". Everything the player is refused
## with comes through here, so a verb and its blocker can never disagree.
func _first_blocker(id: String, requirements: Array) -> String:
	var evaluator: Object = _requirements()
	if evaluator == null:
		return "Not now."
	var facts: Dictionary = _facts()
	for requirement in requirements:
		var result: Dictionary = evaluator.evaluate_requirement(requirement, facts)
		if bool(result.get("ok", false)):
			continue
		return _blocker_words(id, requirement as Dictionary, result)
	return ""

## The gate's reason, in the register. `requirements.gd` answers in codes and
## numbers on purpose; turning those into a sentence is the caller's job, and
## this is the caller.
func _blocker_words(id: String, requirement: Dictionary, result: Dictionary) -> String:
	var definition: Dictionary = DEFS.by_id(id)
	var owner_id := str(definition.get("owner_id", ""))
	var who := str(OWNER_NAMES.get(owner_id, owner_id.capitalize()))
	match str(requirement.get("type", "")):
		"npc_band_min":
			return "%s has to want you there first. Right now she reads you %s." \
				% [who, str(result.get("current", "neutral")).to_upper()]
		"business_allegiance":
			match allegiance_of(id):
				DEFS.ALLEGIANCE_YOURS:
					return "You already have an arrangement here."
				DEFS.ALLEGIANCE_CURTIS:
					return "Curtis's people are in it. That is a different conversation."
			return "Not this one."
		"crew_count_min":
			return "You would be walking in there alone."
	return "Not now."

## The owners' names, for the blockers and the feed. The screens carry their
## own copies for their own layouts; this is the one the SYSTEM speaks with.
const OWNER_NAMES := {
	"lani": "Lani", "marcus": "Marcus", "bev": "Bev", "vic": "Vic",
}

## Every reason a verb can be refused that is not a requirement row: the place
## is shut, the run is over, there is no such business. Checked ahead of the
## gates because "her doors are locked" is the earlier and more honest refusal
## -- the same ordering `boost.gd` uses for "you don't know that place".
func _hard_blocker(id: String) -> String:
	if gs.game_over:
		return "The run is over."
	if DEFS.by_id(id).is_empty():
		return "No such place."
	if not knows(id):
		return "You don't know that place."
	if is_closed(id):
		var left: int = closed_nights_left(id)
		return "Shut. %d more night%s." % [left, "" if left == 1 else "s"]
	return ""

func ask_blocker(id: String) -> String:
	var hard := _hard_blocker(id)
	if not hard.is_empty():
		return hard
	return _first_blocker(id, ask_requirements(id))

func lean_blocker(id: String) -> String:
	var hard := _hard_blocker(id)
	if not hard.is_empty():
		return hard
	return _first_blocker(id, lean_requirements(id))

## HSS-D4: ASK. She was going to say yes, so there is no room and no roll --
## the arrangement opens at STEADY and it costs a part of the day.
func _ask(id: String) -> Dictionary:
	var blocked := ask_blocker(id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var time_system: Object = gm.system("time")
	if time_system != null and time_system.has_method("can_spend_slot") \
			and not bool(time_system.can_spend_slot()):
		return {"ok": false, "reason": "The day is gone."}
	_open_arrangement(id, 0, "asked")
	if time_system != null:
		time_system.handle("advance_time", {})
	return {"ok": true}

## HSS-D4: LEAN. A room, in the shape a contest takes, with the owner's people
## on the other side of it.
func _lean(id: String) -> Dictionary:
	var blocked := lean_blocker(id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var engine: Object = gm.system("consequence")
	if engine == null:
		return {"ok": false, "reason": "Not now."}
	var definition: Dictionary = DEFS.by_id(id)
	var place := str(definition["name"])
	gs.log_activity("You go and stand in %s until the counter is yours." % place, AMBER)
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": str(definition["district"]),
		"return_route": "TURF",
		"source": {"family": "businesses", "kind": "business_lean", "action_id": "businesses",
			"target_id": id, "target_name": place,
			"opponent": _opponent_label(id)},
		"decision": {
			"allowed_choices": ["lean_on", "walk_away"],
			"deterministic_choices": ["walk_away"],
			"shown_probabilities": {"lean_on": lean_chance(id)},
		},
	})
	return {"ok": true}

## Who is on the other side. An owner alone reads differently from an owner who
## has already decided once that she is not paying.
func _opponent_label(id: String) -> String:
	var definition: Dictionary = DEFS.by_id(id)
	var who := str(OWNER_NAMES.get(str(definition.get("owner_id", "")), "The owner"))
	if pressure_of(id) > 0:
		return "%s and whoever she called" % who
	return "%s, behind her own counter" % who

## HSS-D4: the odds, in the `contest_chance` shape. Your crew and your kit
## against the room -- and against how many times you have already done this,
## because an owner who has been leaned on twice has had time to decide.
func lean_chance(id: String) -> float:
	var chance: float = LEAN_BASE
	chance += LEAN_PER_CREW * float(gs.recruited_crew().size())
	chance += LEAN_PER_SOLDIER * float(gs.soldiers_idle)
	chance += float(gs.weapon_def().get("fight_bonus", 0.0))
	chance -= LEAN_PER_BAND * float(pressure_of(id))
	# HSS-D7: an owner who fought you off once has decided something about you,
	# and the next conversation starts from there. This is what "the next lean
	# shows contested odds" means on a row that has already resisted.
	if str(row_of(id).get("last_kind", "")) == "resist":
		chance -= LEAN_AFTER_RESIST
	return clampf(chance, LEAN_MIN, LEAN_MAX)

## The engine's seam. `record_receipt` guards every effect so a chain resolved
## across a reload cannot pay twice or move two bands.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var decision: Dictionary = chain.get("decision", {})
	var source: Dictionary = chain.get("source", {})
	var id := str(source.get("target_id", ""))
	var cause_id := str(chain.get("cause_id", ""))
	var definition: Dictionary = DEFS.by_id(id)
	var place := str(definition.get("name", id))
	var tier := "deterministic"
	var health := 0

	if choice_id == "take_it":
		# HSS-D4: TAKE. His odds, his people, and a night he comes back for it.
		var resolver: Object = gm.system("outcome_resolver")
		var attributes: Object = gm.system("attributes")
		var key := "%d:%d:business_take:%s" % [gs.day, gs.time_slots_today, id]
		tier = "failure"
		if resolver != null:
			tier = str((resolver.resolve_action("confrontation", take_chance(id),
				int(attributes.effective("combat")) if attributes != null else 1,
				gs.run_seed, key) as Dictionary)["tier"])
		if tier in ["clean", "messy"]:
			if engine.record_receipt(cause_id, "business_take:won"):
				_take_won(id, cause_id)
			if tier == "messy":
				health = TAKE_LOSS_HEALTH / 2
		else:
			if engine.record_receipt(cause_id, "business_take:lost"):
				_take_lost(id)
			health = TAKE_LOSS_HEALTH if tier == "failure" else TAKE_LOSS_HEALTH * 2
	elif choice_id == "back_off":
		var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
		if curtis != null and engine.record_receipt(cause_id, "business_take:walked"):
			curtis.raise_awareness(1)
		gs.log_activity("You look at %s for a while and walk. His people watch you do it." % place, AMBER)
	elif choice_id == "lean_on":
		var resolver: Object = gm.system("outcome_resolver")
		var attributes: Object = gm.system("attributes")
		var key := "%d:%d:business_lean:%s" % [gs.day, gs.time_slots_today, id]
		tier = "failure"
		if resolver != null:
			tier = str((resolver.resolve_action("confrontation", lean_chance(id),
				int(attributes.effective("combat")) if attributes != null else 1,
				gs.run_seed, key) as Dictionary)["tier"])
		if tier in ["clean", "messy"]:
			if engine.record_receipt(cause_id, "business_lean:won"):
				_lean_won(id)
			if tier == "messy":
				health = LEAN_LOSS_HEALTH / 2
		else:
			if engine.record_receipt(cause_id, "business_lean:lost"):
				_lean_lost(id)
			health = LEAN_LOSS_HEALTH if tier == "failure" else LEAN_LOSS_HEALTH * 2
		# The costs land on the ATTEMPT, not on the win. Standing in somebody's
		# shop until the counter is yours is the thing the block saw, and it saw
		# it whether or not she agreed.
		if engine.record_receipt(cause_id, "business_lean:costs"):
			_lean_costs(id)
	else:
		gs.log_activity("You look at %s for a while and leave it alone." % place, AMBER)

	if health > 0:
		var crew: Object = gm.system("crew")
		if crew != null:
			health = int(crew.absorbed_damage(health))
		gs.health = clampi(gs.health - health, 1, gs.health_max)

	decision["resolved_tier"] = tier
	decision["result"] = {"choice_id": choice_id, "tier": tier, "arrested": false,
		"banned": false, "cash": 0, "goods": 0, "health": -health, "heat": 0.0,
		"pressure": 0, "take_disposition": "keep"}
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": tier, "arrested": false}

## A lean that landed: an arrangement opens at LEANED ON, or one that is
## already open moves up a band.
func _lean_won(id: String) -> void:
	if is_yours(id):
		_raise_pressure(id)
	else:
		_open_arrangement(id, 1, "leaned")

## A lean that did not. She said no out loud, and her ledger remembers that she
## was the one who said it.
func _lean_lost(id: String) -> void:
	var definition: Dictionary = DEFS.by_id(id)
	var E: Node = _exposure()
	if E != null:
		E.record_observation(str(definition["owner_id"]), {"type": "defiance",
			"event": "resisted", "location": id, "source": "witnessed"})
	gs.log_activity("%s does not pay. Everybody in there watches her not pay."
		% str(definition.get("name", id)), RED)

## HSS-D6: pressure costs before it breaks. Three costs, every lean, whether or
## not it worked: her ledger, the district's pressure, and his attention.
func _lean_costs(id: String) -> void:
	var definition: Dictionary = DEFS.by_id(id)
	var E: Node = _exposure()
	if E != null:
		E.record_observation(str(definition["owner_id"]), {"type": "violence",
			"event": "leaned_on", "location": id, "source": "witnessed"})
	var engine: Object = gm.system("consequence")
	if engine != null:
		engine.add_capped_pressure(str(definition["district"]), LEAN_PRESSURE_FAMILY,
			LEAN_PRESSURE, LEAN_PRESSURE_DAILY_CAP)
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis != null:
		curtis.mark_criminal_activity()

# --- the bands --------------------------------------------------------------

## An arrangement opens. `since_day` is the day the band last moved, which is
## what the decay counts from.
func _open_arrangement(id: String, pressure: int, how: String) -> void:
	refresh_discovery()
	if not gs.businesses.has(id):
		var definition: Dictionary = DEFS.by_id(id)
		if definition.is_empty():
			return
		_create_row(definition)
	var row: Dictionary = gs.businesses[id]
	row["allegiance"] = DEFS.ALLEGIANCE_YOURS
	row["pressure"] = clampi(pressure, 0, int(DEFS.MAX_PRESSURE))
	row["since_day"] = int(gs.day)
	row["let_down"] = false
	var definition: Dictionary = DEFS.by_id(id)
	var place := str(definition["name"])
	if how == "asked":
		gs.log_activity("%s is on your side of the street. Nobody had to be told twice."
			% place, GREEN)
	else:
		gs.log_activity("%s pays now. It did not take long." % place, GREEN)
	_say_on_change(id, "opened")

func _raise_pressure(id: String) -> void:
	var row: Dictionary = gs.businesses.get(id, {})
	if row.is_empty():
		return
	var before: int = pressure_of(id)
	var after: int = clampi(before + 1, 0, int(DEFS.MAX_PRESSURE))
	row["pressure"] = after
	row["since_day"] = int(gs.day)
	if after == before:
		gs.log_activity("There is nothing left to squeeze out of %s."
			% str(DEFS.by_id(id)["name"]), AMBER)
		return
	gs.log_activity("%s goes up. %s now." % [str(DEFS.by_id(id)["name"]),
		DEFS.band_word(after)], AMBER)
	_say_on_change(id, "squeezed")

## HSS-D5: a band decays after four nights with no lean. A leaned business can
## come back to STEADY; its owner's ledger does not.
func _decay(id: String) -> void:
	var row: Dictionary = gs.businesses.get(id, {})
	if row.is_empty() or int(row.get("pressure", 0)) <= 0:
		return
	if int(gs.day) - int(row.get("since_day", int(gs.day))) < int(DEFS.DECAY_NIGHTS):
		return
	row["pressure"] = maxi(0, int(row["pressure"]) - 1)
	row["since_day"] = int(gs.day)
	gs.log_activity("%s settles back to %s. Nobody has been by in a while."
		% [str(DEFS.by_id(id)["name"]), DEFS.band_word(int(row["pressure"]))], MUTED_LOG)

const MUTED_LOG := Color(0.6, 0.6, 0.6)
const RED := Color(0.827, 0.161, 0.125)

# --- the promise, and the phone ---------------------------------------------

## HSS-D8: the ledger half of the backing rule. The pay half is in
## `take_tonight`; this is what she thinks about it, written once per unbacked
## stretch and cleared the night somebody turns up again.
func _judge_the_promise(id: String) -> void:
	var row: Dictionary = gs.businesses.get(id, {})
	if row.is_empty() or not is_yours(id) or is_closed(id):
		return
	if is_backed(id):
		row["let_down"] = false
		return
	if bool(row.get("let_down", false)):
		return
	row["let_down"] = true
	var definition: Dictionary = DEFS.by_id(id)
	var E: Node = _exposure()
	if E != null:
		E.record_observation(str(definition["owner_id"]), {"type": "loyalty",
			"event": "let_them_down", "location": id, "source": "witnessed"})
	_say_on_change(id, "unbacked")

## HSS-D9 and the RM-D9 cadence: the phone speaks ONLY on change. A steady
## arrangement is silent -- the feed reports every night, and that is where a
## player who wants the nightly number reads it.
func _say_on_change(id: String, what: String) -> void:
	var phone: Object = gm.system("phone") if gm != null else null
	if phone == null:
		return
	var definition: Dictionary = DEFS.by_id(id)
	var owner_id := str(definition.get("owner_id", ""))
	var who := str(OWNER_NAMES.get(owner_id, "Somebody"))
	var text := ""
	match what:
		"opened":
			text = _voice(owner_id, "opened")
		"squeezed":
			text = _voice(owner_id, "squeezed")
		"unbacked":
			text = _voice(owner_id, "unbacked")
		"first_paid":
			text = _voice(owner_id, "first_paid")
		"closed", "police", "flipped", "resisted":
			text = _voice(owner_id, what)
	if text.is_empty():
		return
	phone.push_text(who, text, "business:%s" % id)

## Each owner in her own voice. Lani calls you baby; Marcus does not use ten
## words; Bev has run a motel on his row for years and is not impressed by
## anybody; Vic talks like a man with his hands full.
func _voice(owner_id: String, what: String) -> String:
	var lines: Dictionary = OWNER_VOICE.get(owner_id, {})
	return str(lines.get(what, ""))

const OWNER_VOICE := {
	"lani": {
		"opened": "ok baby. same as we said. come by friday, i'll have it ready",
		"squeezed": "that's more than we said, baby. i heard you the first time",
		"unbacked": "nobody's been by in a minute. that's all i'm saying",
		"first_paid": "it's counted. don't make me hold it all week",
		"closed": "i'm closed a few days baby. don't come by, there's nothing to come by for",
		"police": "a car sat on my lot this morning. somebody called them and it wasn't me",
		"flipped": "somebody else came and asked nicer. that's all i'm going to say",
		"resisted": "no. i'm done. you can tell whoever you want i said it",
	},
	"marcus": {
		"opened": "fine. fridays.",
		"squeezed": "you moved the number.",
		"unbacked": "nobody came.",
		"first_paid": "it's ready.",
		"closed": "shut til friday.",
		"police": "they took a report.",
		"flipped": "i pay somebody else now.",
		"resisted": "no more.",
	},
	"bev": {
		"opened": "you and everybody else. it'll be at the desk.",
		"squeezed": "you're going to price yourself out of a motel.",
		"unbacked": "i've had two nights nobody covered. you know that.",
		"first_paid": "front desk. ask for the envelope, don't say my name.",
		"closed": "no vacancy, and no envelope. i'll call you when the doors open",
		"police": "there was a cruiser in my lot at six in the morning. thanks for that",
		"flipped": "curtis's people never stopped coming. so.",
		"resisted": "i ran this row before you and i'll run it after. we're done",
	},
	"vic": {
		"opened": "yeah alright. i'm under a truck til six, leave it with the kid",
		"squeezed": "you keep coming back and it keeps costing me the same shop",
		"unbacked": "had a window go out tuesday. wasn't anybody around",
		"first_paid": "it's in the drawer, come get it",
		"closed": "shops shut. tell whoever asks it's a parts thing",
		"police": "cops came out about the window. wrote it all down this time",
		"flipped": "somebody else is covering me now. it wasn't personal",
		"resisted": "got six guys here with wrenches. don't come back",
	},
}

# --- settlement -------------------------------------------------------------

## HSS-D5 and HSS-D8. Runs at `SETTLE:businesses`, **after** `SETTLE:territory`
## — the night's probes have to have landed before the promise is judged, or a
## corner Curtis took back tonight would still read as backing this morning.
##
## The money is DIRTY. That is the point: protection money is protection money,
## and the reason laundering is a want in 1.6.0 is that this key never gets
## cleaned on the way in. `wallet.gd`'s header carries the warning about
## reclassification for exactly this kind of caller.
##
## One feed line for every business, not one per business. A player with four
## arrangements should read one sentence about the night, the way the corners
## report one sentence about the corners.
func settle_night(_ended_day: int) -> void:
	if gs.game_over:
		return
	refresh_discovery()

	# 1. The promise, judged first. `is_backed` reads the board Territory just
	#    finished settling, so a corner Curtis took back tonight is already gone
	#    by the time this asks whether anybody was standing on it.
	for id in known_ids():
		_judge_the_promise(id)

	# 2. What everybody pays, and the heat the loud ones bring with them.
	var total := 0
	var paid := 0
	for id in known_ids():
		var take: int = take_tonight(id)
		if take <= 0:
			continue
		total += take
		paid += 1
		# HSS-D6: nothing below the squeeze. A business's heat is its OWN line
		# through `apply_gain` and is deliberately not folded into Territory's
		# `nightly_heat()` -- Turf's district card reads that one, and folding
		# it in would make the card count this twice.
		var raw: float = float(DEFS.heat_at(id, pressure_of(id)))
		if raw > 0.0:
			var district := str(DEFS.by_id(id)["district"])
			_heat().apply_gain(raw, _heat().FAMILY_NONE, district,
				{"source_id": "business_pressure"})

	# 3. HSS-D7: the break. Rolled AFTER the night is paid, so a business that
	#    shuts its doors tonight still paid for the day it worked, and before the
	#    decay, because an outcome that moves the band is not a quiet night.
	for id in known_ids():
		_roll_the_break(id)

	# 4. The bands cool off. AFTER the night is paid, so a band the player held
	#    all day still pays what it was worth today and settles back tomorrow.
	for id in known_ids():
		_decay(id)

	if total <= 0:
		return

	# HSS-D9: the phone speaks on change, and the first money off an
	# arrangement is a change. Every night after it is the feed's job.
	var first: bool = int(gs.run_earnings.get(EARNING_SOURCE, 0)) <= 0

	_wallet().credit(total, _wallet().DIRTY, {"source_id": WALLET_SOURCE_ID})
	gs.record_earning(EARNING_SOURCE, total)
	gs.log_activity(_settlement_line(total, paid), GREEN)

	if first:
		for id in known_ids():
			if take_tonight(id) > 0:
				_say_on_change(id, "first_paid")
				break

## The Power register: a payment is a fact. Nobody is grateful and nobody begs.
func _settlement_line(total: int, paid: int) -> String:
	if paid == 1:
		return "$%d comes in off the arrangement. It is counted before you are awake." % total
	return "$%d comes in off %d arrangements. Nobody had to be reminded." % [total, paid]

# --- the room's words (BB-D1's adapter seam) --------------------------------

func choice_label(choice_id: String) -> String:
	return {"lean_on": "LEAN ON HER", "walk_away": "LEAVE IT"}.get(choice_id,
		choice_id.capitalize())

func choice_copy(choice_id: String) -> String:
	return {
		"lean_on": "Make the number the number. Your people, her counter, everybody watching.",
		"walk_away": "Buy a coffee and go. Nothing said, nothing owed.",
	}.get(choice_id, "")

func choice_guarantee(choice_id: String) -> String:
	if choice_id == "walk_away":
		return "Guaranteed: nobody is touched, and nobody starts paying."
	return ""

func result_headline(choice_id: String, tier: String, _effects: Dictionary) -> String:
	if choice_id == "walk_away":
		return "YOU LEAVE IT"
	match tier:
		"clean": return "SHE PAYS"
		"messy": return "SHE PAYS, EVENTUALLY"
		"failure": return "SHE DOES NOT"
	return "SHE SAYS NO"

func result_body(choice_id: String, tier: String, _effects: Dictionary) -> String:
	if choice_id == "walk_away":
		return "You buy something you do not want and leave. She rings it up without looking at you, and that is the whole transaction."
	match tier:
		"clean": return "It takes one conversation. She names a day, you name a number, and the number is yours. Nobody raised their voice and everybody in there heard it."
		"messy": return "It takes longer than it should and somebody says something they cannot take back. She pays. She will remember which part of it was the pay and which part was the rest."
		"failure": return "She says no in front of her own customers, and saying it out loud makes it easier for her to say again."
	return "It goes wrong in the room and worse on the way out. She has your face and a reason, and the block has a story about a shop that did not pay."

# --- HSS-D8: the hand-offs the board makes ----------------------------------

## The player's own walk-off. Abandoning the ground under a business ends the
## arrangement and gives it to NOBODY -- that is the difference between walking
## away and being pushed off, and PR 3's probe hand-off is the other half.
func on_node_abandoned(node_id: String) -> void:
	var definition: Dictionary = DEFS.on_node(node_id)
	if definition.is_empty():
		return
	var id := str(definition["id"])
	if not is_yours(id):
		return
	var row: Dictionary = gs.businesses[id]
	row["allegiance"] = DEFS.ALLEGIANCE_NONE
	row["pressure"] = 0
	row["since_day"] = int(gs.day)
	row["let_down"] = false
	gs.log_activity("You walk off the lot, and %s stops paying anybody."
		% str(definition["name"]), AMBER)

## HSS-D10: `wt_protection`'s seam. She asked, so the arrangement opens at the
## base with no band gate and no room -- the card's own day-20 / one-crew
## requirements are the gate, and they are the right one. Once, because the
## card is `once`; a business that is already yours or already his is left
## exactly as it stands.
func open_from_event(id: String) -> void:
	var definition: Dictionary = DEFS.by_id(id)
	if definition.is_empty():
		return
	refresh_discovery()
	if is_yours(id) or is_his(id) or is_closed(id):
		return
	_open_arrangement(id, 0, "asked")

## The player ending it. Free, immediate, and it gives the business to nobody --
## the same outcome as walking off the ground under it, reached from the row
## instead of from the board.
func _walk_away(id: String) -> Dictionary:
	if not is_yours(id):
		return {"ok": false, "reason": "You have no arrangement there."}
	var row: Dictionary = gs.businesses[id]
	row["allegiance"] = DEFS.ALLEGIANCE_NONE
	row["pressure"] = 0
	row["since_day"] = int(gs.day)
	row["let_down"] = false
	gs.log_activity("You stop coming by %s. Nobody says anything about it."
		% str(DEFS.by_id(id)["name"]), AMBER)
	return {"ok": true}

## HSS-D4 and HS-D4's rule: the odds in words, never a number.
func odds_word(id: String) -> String:
	var chance: float = lean_chance(id)
	if chance >= 0.70:
		return "she folds"
	if chance >= 0.55:
		return "she probably folds"
	if chance >= 0.40:
		return "even money"
	if chance >= 0.25:
		return "she probably does not"
	return "she will not"

# --- HSS-D4: TAKE, the third way in -----------------------------------------

## Taking one off Curtis. Gated on a crew and on the business actually being
## his; the room is the same chain the lean opens, with his people on the other
## side of it and his odds on the button.
func take_requirements(id: String) -> Array:
	return [
		{"type": "crew_count_min", "min": 1},
		{"type": "business_allegiance", "business_id": id,
			"allowed": [DEFS.ALLEGIANCE_CURTIS]},
	]

func take_blocker(id: String) -> String:
	var hard := _hard_blocker(id)
	if not hard.is_empty():
		return hard
	return _first_blocker(id, take_requirements(id))

## HSS-D4: his odds, not hers. Reads the crew, the soldiers and the kit the way
## `territory.contest_chance` does, and falls off as he notices you more.
func take_chance(id: String) -> float:
	var chance: float = TAKE_BASE
	chance += TAKE_PER_CREW * float(gs.recruited_crew().size())
	chance += TAKE_PER_SOLDIER * float(gs.soldiers_idle)
	chance += float(gs.weapon_def().get("fight_bonus", 0.0))
	chance -= TAKE_AWARENESS * float(gs.curtis_awareness)
	return clampf(chance, TAKE_MIN, TAKE_MAX)

func take_odds_word(id: String) -> String:
	var chance: float = take_chance(id)
	if chance >= 0.70:
		return "they fold"
	if chance >= 0.55:
		return "they probably fold"
	if chance >= 0.40:
		return "even money"
	if chance >= 0.25:
		return "they probably do not"
	return "they will not"

func _take(id: String) -> Dictionary:
	var blocked := take_blocker(id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var engine: Object = gm.system("consequence")
	if engine == null:
		return {"ok": false, "reason": "Not now."}
	var definition: Dictionary = DEFS.by_id(id)
	var place := str(definition["name"])
	gs.log_activity("%s pays Curtis. His people are in there tonight, and they were told you might come."
		% place, AMBER)
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": str(definition["district"]),
		"return_route": "TURF",
		"source": {"family": "businesses", "kind": "business_take", "action_id": "businesses",
			"target_id": id, "target_name": place,
			"opponent": "Curtis's people at %s" % place},
		"decision": {
			"allowed_choices": ["take_it", "back_off"],
			"deterministic_choices": ["back_off"],
			"shown_probabilities": {"take_it": take_chance(id)},
		},
	})
	return {"ok": true}

## A take that landed: the business is yours at LEANED ON -- you did not ask --
## Curtis knows, and his people are coming back for it.
func _take_won(id: String, cause_id: String) -> void:
	_open_arrangement(id, 1, "leaned")
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis != null:
		curtis.raise_awareness(TAKE_WIN_AWARENESS)
	# HSS-D4: he comes back for it, through the shipped queue. The business is
	# the TARGET -- `consequence_rules.gd` carries its row, keyed by the
	# business id, next to the tills and the dice game. No new tier.
	var retaliation: Object = gm.system("retaliation")
	if retaliation != null and not cause_id.is_empty():
		retaliation.schedule(id, "clean", cause_id, str(DEFS.by_id(id)["district"]))

func _take_lost(id: String) -> void:
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis != null:
		curtis.raise_awareness(TAKE_LOSS_AWARENESS)
	gs.log_activity("You do not take %s off him. His people make sure you remember trying."
		% str(DEFS.by_id(id)["name"]), RED)

# --- HSS-D7: breaking -------------------------------------------------------

## One seeded roll a night at BREAKING, over the row's own authored weights.
##
## This is the tooth under the top band. Without it BREAKING pays 1.3x for
## nothing but heat, and the owner's rule -- that the highest band is a
## business being pushed toward failure and never a tier worth keeping -- is a
## sentence rather than a mechanic.
func _roll_the_break(id: String) -> void:
	var definition: Dictionary = DEFS.by_id(id)
	if definition.is_empty():
		return
	_roll_the_break_with(id, definition.get("break_weights", {}))

## The same roll against a GIVEN table. The authored weights are the caller's
## argument rather than something this function reaches for, which is what lets
## the suite force one outcome at a time (`{x: 1, others: 0}`) and assert all
## four -- the definitions are `const` and cannot be mutated for a fixture.
func _roll_the_break_with(id: String, weights: Dictionary) -> void:
	if not is_yours(id) or is_closed(id):
		return
	if pressure_of(id) < int(DEFS.MAX_PRESSURE):
		return
	var rng: Node = Engine.get_main_loop().root.get_node_or_null("/root/RngManager")
	if rng == null:
		return
	var definition: Dictionary = DEFS.by_id(id)
	var kind := _weighted_break(rng, id, weights)
	if kind.is_empty():
		return
	var row: Dictionary = gs.businesses[id]
	row["last_kind"] = kind
	var place := str(definition["name"])
	match kind:
		"close":
			# She shuts the doors. Pays nothing while they are shut, and opens
			# again angry rather than steady.
			row["closed_until"] = int(gs.day) + int(DEFS.CLOSURE_NIGHTS)
			row["pressure"] = int(DEFS.CLOSURE_REOPEN_PRESSURE)
			row["since_day"] = int(gs.day)
			gs.log_activity("%s is dark. A sheet of paper on the glass and no date on it. Nothing comes off it for %d nights."
				% [place, int(DEFS.CLOSURE_NIGHTS)], RED)
			_say_on_change(id, "closed")
		"police":
			var district := str(definition["district"])
			_heat().apply_gain(BREAK_POLICE_HEAT, _heat().FAMILY_NONE, district,
				{"source_id": "business_break_police"})
			var engine: Object = gm.system("consequence")
			if engine != null:
				engine.add_capped_pressure(district, LEAN_PRESSURE_FAMILY,
					BREAK_POLICE_PRESSURE, BREAK_POLICE_PRESSURE_CAP)
			row["pressure"] = 2
			row["since_day"] = int(gs.day)
			gs.log_activity("Somebody at %s finally called it in. There is a cruiser on the lot in the morning and a report with a date on it."
				% place, RED)
			_say_on_change(id, "police")
		"curtis":
			# She found somebody else to pay. That somebody has been in the
			# neighbourhood the whole time.
			row["allegiance"] = DEFS.ALLEGIANCE_CURTIS
			row["pressure"] = 0
			row["since_day"] = int(gs.day)
			row["let_down"] = false
			var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
			if curtis != null:
				curtis.raise_awareness(BREAK_CURTIS_AWARENESS)
			gs.log_activity("%s pays Curtis now. She did not tell you, and she did not have to."
				% place, RED)
			_say_on_change(id, "flipped")
		"resist":
			row["allegiance"] = DEFS.ALLEGIANCE_NONE
			row["pressure"] = 0
			row["since_day"] = int(gs.day)
			row["let_down"] = false
			var E: Node = _exposure()
			if E != null:
				E.record_observation(str(definition["owner_id"]), {"type": "defiance",
					"event": "hostile", "location": id, "source": "witnessed"})
			gs.log_activity("%s stops paying. Not quietly, and not only to you."
				% place, RED)
			_say_on_change(id, "resisted")

## The roll itself, seeded on the business and the night so a reload cannot
## reroll it. Weights are relative and need not sum to one; a row with no
## weights, or with nothing but zeroes, breaks in no direction at all.
func _weighted_break(rng: Node, id: String, weights: Dictionary) -> String:
	var total := 0.0
	for kind in DEFS.BREAK_KINDS:
		total += maxf(0.0, float(weights.get(kind, 0.0)))
	if total <= 0.0:
		return ""
	var roll: float = rng.seeded_random(gs.run_seed, BREAK_KEY % [int(gs.day), id]) * total
	var running := 0.0
	for kind in DEFS.BREAK_KINDS:
		running += maxf(0.0, float(weights.get(kind, 0.0)))
		if roll < running:
			return str(kind)
	return str(DEFS.BREAK_KINDS[DEFS.BREAK_KINDS.size() - 1])

# --- HSS-D8: his side of the hand-offs --------------------------------------

## A node lost to a PROBE hands the business standing on it to Curtis. Called
## only from `territory._lose_block`, and only on the probe reason -- abandoning
## the same corner calls `on_node_abandoned` instead and gives it to nobody.
func on_node_lost_to_curtis(node_id: String) -> void:
	var definition: Dictionary = DEFS.on_node(node_id)
	if definition.is_empty():
		return
	var id := str(definition["id"])
	refresh_discovery()
	if not gs.businesses.has(id) or is_his(id):
		return
	var row: Dictionary = gs.businesses[id]
	row["allegiance"] = DEFS.ALLEGIANCE_CURTIS
	row["pressure"] = 0
	row["since_day"] = int(gs.day)
	row["let_down"] = false
	gs.log_activity("His people took the lot, and %s came with it."
		% str(definition["name"]), RED)

## HSS-D8 and the owner's ruling of 2026-09-06: D-30's dismantle gate is
## untouched, and when he is out of a district every business of his there goes
## NEUTRAL -- not yours. Nobody inherits an arrangement; the door is simply open
## again. Called from `territory._dismantle`.
func on_district_dismantled(district_id: String) -> void:
	for definition in DEFS.in_district(district_id):
		var id := str((definition as Dictionary)["id"])
		if not gs.businesses.has(id) or not is_his(id):
			continue
		var row: Dictionary = gs.businesses[id]
		row["allegiance"] = DEFS.ALLEGIANCE_NONE
		row["pressure"] = 0
		row["since_day"] = int(gs.day)
		row["let_down"] = false
		gs.log_activity("%s does not pay anybody this morning. The people it used to pay are not in %s any more."
			% [str((definition as Dictionary)["name"]),
				str(gs.district_by_id(district_id).get("name", district_id))], GREEN)

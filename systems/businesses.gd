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

var gs: Node
var gm: Node

func setup(game_state: Node, manager: Node) -> void:
	gs = game_state
	gm = manager

## No verb ships in this slice. The pair exists because a registered system is
## a `can_handle`/`handle` pair plus a `settle_night`, and the settlement is
## the whole point of registering — ASK, LEAN and TAKE land on these two
## functions next, and registering the system now means they need no new
## wiring when they do.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "Unknown business action."}

func _wallet() -> Object:
	return gm.system("wallet")

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
		take = int(round(float(take) * float(DEFS.UNBACKED_SHARE)))
	return maxi(0, take)

## Everything every arrangement pays tonight. What the Turf status line reads.
func nightly_take() -> int:
	var total := 0
	for id in known_ids():
		total += take_tonight(id)
	return total

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

	var total := 0
	var paid := 0
	for id in known_ids():
		var take: int = take_tonight(id)
		if take <= 0:
			continue
		total += take
		paid += 1

	if total <= 0:
		return

	_wallet().credit(total, _wallet().DIRTY, {"source_id": WALLET_SOURCE_ID})
	gs.record_earning(EARNING_SOURCE, total)
	gs.log_activity(_settlement_line(total, paid), GREEN)

## The Power register: a payment is a fact. Nobody is grateful and nobody begs.
func _settlement_line(total: int, paid: int) -> String:
	if paid == 1:
		return "$%d comes in off the arrangement. It is counted before you are awake." % total
	return "$%d comes in off %d arrangements. Nobody had to be reminded." % [total, paid]

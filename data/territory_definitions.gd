extends RefCounted
## The canonical Territory board — FS-002.3 (`86bbj1jpm`).
##
## ## What this replaces
##
## `GameState.spenard_blocks`, deleted whole in this slice rather than
## deprecated alongside it — the standing rule for this migration is that a
## retired truth does not get to survive next to the thing that replaced it, or
## the migration has created a third truth while retiring the second.
##
## Same six ids, same `earning` / `heat_exposure` / `claim_cost` / `cell` /
## `name` values as `spenard_blocks` carried — FS-002.3 is a state-shape
## migration, not a balance pass, and the FS-002 "constants unchanged" freeze
## holds until PR 4 adds the one missing rule (Territory's operating cost) it
## exists to add. `patrol` is dropped: authored on every row, read by nothing,
## dead since the field was ported.
##
## ## What is new: `starting_owner`
##
## `spenard_rec_lot` and `wash_and_go_lot` start neutral — open to the ordinary
## `claim_block` flow, exactly as every corner has been since Phase 3e. The
## other four start Curtis-secure: `minnesota_offramp`,
## `service_road_chokepoint`, `fourth_ave_strip`, `northern_lights_motels`.
##
## **`starting_owner` is classification data, not a gameplay gate, in this
## slice.** Contested takeovers are FS-002.4/.5 (Build 18b) — `territory.gd`'s
## own header has always listed "Curtis pressure and contested takeovers" under
## "Not ported". Gating `claim_block` on ownership now, before the mechanic
## that would make a Curtis-secure corner mean something different to claim,
## would lock four of six corners on every fresh run with nothing behind the
## lock — a real gameplay change hiding inside a "canonical state" PR, and
## exactly the kind of smuggled balance change rule 8 and the FS-002 freeze
## both forbid. `claim_block` reads `starting_owner` from nowhere and behaves
## identically on all six nodes until FS-002.4 gives it a reason not to.
##
## What `starting_owner` DOES drive, today: the v16 migration
## (`autoload/save_system.gd`), which needs to know — for a save that already
## held one of the four Curtis-secure nodes before this file existed — that the
## capture already happened, off camera, and must not be undone. See
## `territory_fronts` on `GameState` and the v15 → v16 arm.
##
## This is a scope call the ticket's own ClickUp comment may specify
## differently — that comment could not be read in this session (the connector
## is unauthenticated) — and it is recorded as such in `docs/DECISIONS.md`
## rather than silently assumed.

const OWNER_NEUTRAL := "neutral"
const OWNER_CURTIS := "curtis"

## The authored board. Order matches `spenard_blocks`' cheapest-to-dearest
## ordering, which several fixtures (`tests/parity/parity_runner.gd`,
## `tests/territory/territory_runner.gd`) rely on by position.
const NODES: Array[Dictionary] = [
	{"id": "spenard_rec_lot", "cell": 1, "name": "Spenard Rec Center Lot",
		"earning": 45, "heat_exposure": 1, "claim_cost": 180,
		"starting_owner": OWNER_NEUTRAL},
	{"id": "wash_and_go_lot", "cell": 2, "name": "Wash & Go Lot",
		"earning": 55, "heat_exposure": 1, "claim_cost": 220,
		"starting_owner": OWNER_NEUTRAL},
	{"id": "minnesota_offramp", "cell": 5, "name": "Minnesota Off-Ramp",
		"earning": 65, "heat_exposure": 2, "claim_cost": 260,
		"starting_owner": OWNER_CURTIS},
	{"id": "service_road_chokepoint", "cell": 6, "name": "Service Road Chokepoint",
		"earning": 70, "heat_exposure": 2, "claim_cost": 300,
		"starting_owner": OWNER_CURTIS},
	{"id": "fourth_ave_strip", "cell": 9, "name": "Fourth Avenue Strip",
		"earning": 80, "heat_exposure": 2, "claim_cost": 320,
		"starting_owner": OWNER_CURTIS},
	{"id": "northern_lights_motels", "cell": 10, "name": "Northern Lights Motel Row",
		"earning": 100, "heat_exposure": 3, "claim_cost": 400,
		"starting_owner": OWNER_CURTIS},
]

## The authored row for an id, or `{}` for one the table does not carry.
##
## An empty result is a real, expected case — not just for a hand-corrupted
## save. `held_blocks`/`territory_nodes` has never been validated against this
## table on write, so an id that outlived a rename or a fixture typo can sit in
## a live save (86bbjxtab). Every caller must treat `{}` as "no such node", not
## as a bug.
static func by_id(id: String) -> Dictionary:
	for node in NODES:
		if str(node.get("id", "")) == id:
			return node
	return {}

static func has_id(id: String) -> bool:
	return not by_id(id).is_empty()

static func ids() -> Array[String]:
	var out: Array[String] = []
	for node in NODES:
		out.append(str(node["id"]))
	return out

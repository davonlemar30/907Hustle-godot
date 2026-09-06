extends RefCounted
## The authored businesses — HSS-D1 (1.5.0), "one place, many doors".
##
## ## The problem this file exists to solve
##
## Every Spenard establishment in this game already exists under three or four
## shipped ids, and nothing joins them. The Wash & Go is the job `wash_go`, the
## stickup target `washgo_regular`, the territory node `wash_and_go_lot` and
## the job manager `lani`. The Spenard Chevron is the Boost target
## `spenard_fuel`, the stickup target `spenard_fuel_till` and the night manager
## `marcus`. A save already carries a history with these places — a ban here, a
## bribe there, a till taken at two in the morning — and no row in the game
## reads that history as one place.
##
## A business row is **the one new identity**, and `links` is **the one join**.
## Nothing shipped is renamed, aliased in place, or migrated: the job keeps its
## id, the Boost target keeps its id, the node keeps its id, and a reader who
## wants a place's history goes through `links` to find it. That rule is the
## whole reason this file is data and not a refactor.
##
## ## Ground and allegiance are different questions
##
## Territory is a board of ground. A business is a **second axis over the same
## board** (ORG-A7): whether the Wash & Go Lot is yours and whether Lani pays
## you are two questions, and the answer to one does not settle the other. A
## row is authored either **against a node** (`node_id` names a territory
## block) or **against a district** (`node_id` is `""` and the business stands
## off the board entirely). Both shapes ship in the first set on purpose —
## Arctic Auto & Tire exists to prove the off-board shape works before a later
## district needs it.
##
## ORG-Q3 is ruled (2026-09-06): a venue node keeps its own `earning` as the
## door. The business behind it pays separately, for protection, and does not
## replace anything the node already earns.
##
## ## What is deliberately not here
##
## No capability. What a laundromat or a garage *does* for the organization —
## laundering, the mechanic, the motel's beds, the bar's buyers — is P7 and
## ships with ownership in 1.6.0. `kind` is authored now because P7 reads it;
## it drives nothing in 1.5.0 but the word on the row.
##
## No buy-in and no price: ownership is the seed of every capability and moves
## with them. No business outside Spenard — the shape carries `district`, so
## Downtown and Mountain View are rows rather than code, and none is authored
## here. The Night Owl stays out: Mina's counter is a ROMANTIC ledger and the
## player's own shift, and a business row there needs its own ruling.
##
## `by_id()` returns `{}` for an unknown id and every caller treats that as
## "no such business" — the `territory_definitions.gd` rule, carried forward.

## Who a business answers to. `OWNER_NEUTRAL` is an owner who pays nobody;
## `ALLEGIANCE_YOURS` is an arrangement; `ALLEGIANCE_CURTIS` is his.
const ALLEGIANCE_NONE := "none"
const ALLEGIANCE_YOURS := "yours"
const ALLEGIANCE_CURTIS := "curtis"

const ALLEGIANCES: Array[String] = [ALLEGIANCE_NONE, ALLEGIANCE_YOURS, ALLEGIANCE_CURTIS]

## HSS-D5: the pressure bands, in words. Four, not six — a business you have no
## arrangement with has no band at all; it has an owner with a disposition, and
## that is already a word on People.
const BAND_WORDS: Array[String] = ["STEADY", "LEANED ON", "SQUEEZED", "BREAKING"]
const MAX_PRESSURE := 3

## HSS-D5: what each band multiplies the base take by. The top two are equal on
## purpose — the squeeze buys nothing past band 2 except every cost that comes
## with it, which is what makes band 3 a business being pushed toward failure
## rather than a tier worth keeping. Bounded by the owner's rule at 1.35.
const BAND_MULTIPLIERS: Array[float] = [1.0, 1.15, 1.3, 1.3]

## HSS-D5: a band decays after this many nights with no lean. A leaned business
## can come back to STEADY. Its owner's ledger does not.
const DECAY_NIGHTS := 4

## HSS-D7: a closed business is shut for this many nights, pays nothing, and
## reopens at LEANED ON rather than at STEADY — she reopens angry.
const CLOSURE_NIGHTS := 3
const CLOSURE_REOPEN_PRESSURE := 1

## HSS-D7: the four ways a business at BREAKING comes apart, in a fixed order
## so the weighted roll is deterministic across payloads -- Dictionary
## iteration order is not promised, and a seeded roll that depends on it is not
## seeded at all.
const BREAK_KINDS: Array[String] = ["close", "police", "curtis", "resist"]

## HSS-D8: an arrangement nobody is backing pays this share. The promise is the
## product; an unbacked promise is half a product.
const UNBACKED_SHARE := 0.5

## The default heat a business lands per night, by band. Nothing below the
## squeeze: an arrangement at STEADY or LEANED ON is a quiet transaction, and
## the police have no reason to look at it. A row may override this.
const DEFAULT_HEAT_BY_BAND: Array[float] = [0.0, 0.0, 0.5, 1.0]

## The first playable set — four Spenard businesses, the owner's hybrid ruling
## (ORG-Q10). Two are places the player already knows under other ids; two are
## authored here for what they are worth later. Named next candidates, NOT in
## this build: Northern Value, Northern Lights Pharmacy, the Night Owl.
##
## `base_take` is a starting target, tuned by the driven table in PR 2 and
## movable +/-25% after it. `break_weights` are relative weights over HSS-D7's
## four outcomes, picked per place: a laundromat with a lease shuts her doors,
## a franchise station calls the police because head office says to, the motel
## on Curtis's row goes to Curtis, and a garage full of men with wrenches
## fights back.
const BUSINESSES: Array[Dictionary] = [
	{
		"id": "wash_and_go", "district": "north_star_lot", "node_id": "wash_and_go_lot",
		"name": "Wash & Go", "kind": "laundromat", "owner_id": "lani",
		"base_take": 35, "starting_allegiance": ALLEGIANCE_NONE,
		"heat_by_band": DEFAULT_HEAT_BY_BAND,
		"break_weights": {"close": 0.40, "police": 0.20, "curtis": 0.15, "resist": 0.25},
		# The job the player can already work, the regular who gets taken off
		# outside, the lot it stands on, the woman who runs it, and the
		# authored moment where she asks (HSS-D10).
		"links": {"job": "wash_go", "stickup": "washgo_regular", "manager": "lani",
			"event": "wt_protection", "boost": ""},
	},
	{
		"id": "spenard_chevron", "district": "north_star_lot", "node_id": "",
		"name": "Spenard Chevron", "kind": "station", "owner_id": "marcus",
		"base_take": 40, "starting_allegiance": ALLEGIANCE_NONE,
		"heat_by_band": DEFAULT_HEAT_BY_BAND,
		"break_weights": {"close": 0.25, "police": 0.40, "curtis": 0.15, "resist": 0.20},
		# Ordinary protection income at a place with a Boost history: the
		# shelves the player has walked, the till at two in the morning, and
		# the night manager who has watched both.
		"links": {"job": "", "stickup": "spenard_fuel_till", "manager": "marcus",
			"event": "", "boost": "spenard_fuel"},
	},
	{
		"id": "northern_lights_motel", "district": "north_star_lot",
		"node_id": "northern_lights_motels",
		"name": "Northern Lights Motel", "kind": "motel", "owner_id": "bev",
		"base_take": 90, "starting_allegiance": ALLEGIANCE_CURTIS,
		"heat_by_band": DEFAULT_HEAT_BY_BAND,
		"break_weights": {"close": 0.20, "police": 0.15, "curtis": 0.45, "resist": 0.20},
		# The higher-risk property, and the one you take off him. His people
		# are on the Motel Row before the player ever looks at it, which is
		# why Bev starts on his side and not on nobody's.
		"links": {"job": "", "stickup": "", "manager": "", "event": "", "boost": ""},
	},
	{
		"id": "arctic_auto", "district": "north_star_lot", "node_id": "",
		"name": "Arctic Auto & Tire", "kind": "garage", "owner_id": "vic",
		"base_take": 50, "starting_allegiance": ALLEGIANCE_NONE,
		"heat_by_band": DEFAULT_HEAT_BY_BAND,
		"break_weights": {"close": 0.25, "police": 0.15, "curtis": 0.15, "resist": 0.45},
		# Stands off the board: there is no territory node under it and there
		# does not need to be. The mechanic seam in 1.6.0.
		"links": {"job": "", "stickup": "", "manager": "", "event": "", "boost": ""},
	},
]

static func by_id(id: String) -> Dictionary:
	for b in BUSINESSES:
		if str(b["id"]) == id:
			return b
	return {}

static func has_id(id: String) -> bool:
	return not by_id(id).is_empty()

static func ids() -> Array[String]:
	var out: Array[String] = []
	for b in BUSINESSES:
		out.append(str(b["id"]))
	return out

## Every business authored in a district, in authored order.
static func in_district(district_id: String) -> Array:
	var out: Array = []
	for b in BUSINESSES:
		if str(b["district"]) == district_id:
			out.append(b)
	return out

## The business standing on a territory node, or `{}`. Off-board rows carry
## `node_id == ""` and are never returned here, which is what keeps an empty
## `node_id` from matching an empty query.
static func on_node(node_id: String) -> Dictionary:
	if node_id.is_empty():
		return {}
	for b in BUSINESSES:
		if str(b["node_id"]) == node_id:
			return b
	return {}

## The business whose owner this is, or `{}`. One owner, one business, in this
## set; a second business for the same person would need a ruling about what
## her ledger means when one of them is leaned on and the other is not.
static func by_owner(owner_id: String) -> Dictionary:
	if owner_id.is_empty():
		return {}
	for b in BUSINESSES:
		if str(b["owner_id"]) == owner_id:
			return b
	return {}

static func owner_ids() -> Array[String]:
	var out: Array[String] = []
	for b in BUSINESSES:
		out.append(str(b["owner_id"]))
	return out

## The band word for a pressure level, clamped. Callers render this; nothing
## in the game reads the integer to a player.
static func band_word(pressure: int) -> String:
	return BAND_WORDS[clampi(pressure, 0, MAX_PRESSURE)]

static func band_multiplier(pressure: int) -> float:
	return BAND_MULTIPLIERS[clampi(pressure, 0, MAX_PRESSURE)]

## What one night at this band is worth before backing is applied. Rounded the
## way every other nightly payout in this game rounds — no fractional dollar
## has ever left the wallet and this does not start.
static func take_at(id: String, pressure: int) -> int:
	var b: Dictionary = by_id(id)
	if b.is_empty():
		return 0
	# **Rounded DOWN, and that is a ruling rather than a taste.** HSS-D5 bounds
	# the squeeze at `EV(2) <= 1.3 x EV(0)`, and rounding to NEAREST breaches
	# that bound on any base take whose 1.3x lands on a half dollar: $35 x 1.3
	# is 45.5, which rounds to 46 and pays 1.314x -- over the bound, on the very
	# first row authored, caught by the driven table in parity. Flooring makes
	# the bound hold for EVERY base take rather than for the ones somebody
	# happened to check; a ruling a rounding mode can breach is not a ruling.
	# It is also the right direction in the register: she pays the number, and
	# the number does not round in the collector's favour.
	return floori(float(b["base_take"]) * band_multiplier(pressure))

static func heat_at(id: String, pressure: int) -> float:
	var b: Dictionary = by_id(id)
	if b.is_empty():
		return 0.0
	var by_band: Array = b.get("heat_by_band", DEFAULT_HEAT_BY_BAND)
	if by_band.is_empty():
		return 0.0
	return float(by_band[clampi(pressure, 0, by_band.size() - 1)])

extends RefCounted
## 907List — buy low from strangers, sell for what it is actually worth.
##
## Ported from src/data/market.js (LISTING_ITEMS, MARKET_TIERS) and the
## BUY_907LIST / SELL_907LIST reducers.
##
## The mechanic is information, not arithmetic. Every item has a hidden
## `true_value` band, and four of the eighteen are traps that sell for less than
## they cost. A Scrapper's board shows only title and price, so condition is a
## guess; Flipper shows condition, which is what turns the guess into a read.
## That is why the tier matters more than the capacity does.
##
## Not ported, each its own feature: seller reliability, named buyer requests,
## bulk lots, specialist category tags, the carried-value robbery risk that
## prices moving stock between districts.
##
## ## Opportunity ownership (FS-001.2)
##
## A listing is a single opportunity, not a shelf. Canon tracks
## `nineZeroSevenList.taken` — `{day, ids}` — and filters the board pool by it,
## so the same item cannot be bought twice off one day's board no matter how
## many times the screen is reopened. Before this, the port had no such notion:
## a listing could be rebought until the money or the capacity ran out.
##
## Two details worth keeping straight:
##
##   - **The filter runs on the POOL, before generation, not on the output.**
##     That is canon (`listingSlate`), and it means buying an item does not
##     merely subtract a row — the board is regenerated from a smaller pool and
##     its remaining composition changes. Deterministic still holds in the sense
##     that matters: the same seed, day and consumption set always produce the
##     same board. It is a function of state, not invariant under consumption.
##   - **The day reset is lazy**, keyed on `list_taken.day` rather than a
##     day_crossed handler. See the field's own note in game_state.gd.
##
## Canon also excludes items currently HELD from the pool. That is deliberately
## not ported here — it is a separate behaviour from same-day consumption, it
## would change board composition for every existing save, and no acceptance
## criterion in this build asks for it. Named so the gap is legible.
##
## ## The meetup (Build 5e)
##
## A sale is a handoff in a parking lot, and canon resolves how visible it was
## on the `market_meetup` shape at a flat 0.75 — an Intelligence read of picking
## the hour and the lot.
##
## The thing to understand about this one: **the tier has no mechanical
## consequence.** Canon is explicit that the robbery roll is left alone so the
## risk number the page shows stays honest, and the money is already settled by
## the time the tier is picked. What the tier decides is the Exposure footprint
## and nothing else — a clean meetup writes no row at all, a messy one puts
## `presence / met_a_stranger` on the block, and a catastrophe would write
## `violence / robbery_victim`. That last tier is reachable here but toothless
## until the carried-value robbery lands, which is the feature that gives it
## teeth in canon.

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

## Canon PROFITABLE_FLIP_MARGIN (game-core.js:354). Clearing 30% is the line
## between reading the board and getting lucky.
const PROFITABLE_FLIP_MARGIN := 1.3

## Canon's flat meetup chance. Not a balance number this build chose — it is the
## constant canon passes at the call site, frozen with the rest of the port.
const MEETUP_CHANCE := 0.75

## SQ-D10 (0.6.0 PR E): the buyer's friend. The authored script and the shared
## loop chassis -- this file does not restate either.
const SCRIPTS := preload("res://data/confrontation_scripts.gd")
const LOOP := preload("res://systems/confrontation_loop.gd")

## Who is executing a settlement. See `settle_holding` for what differs.
const PERSONAL := "personal"
const DELEGATED := "delegated"
## The `source` stamp a delegated pickup carries. Personal holdings carry
## "player" (stamped for existing saves by the v6 → v7 migration).
const SOURCE_PLAYER := "player"
const SOURCE_PHERRIS := "pherris"

var gs: Node
var rng: Node
var time_system: RefCounted
var attributes: RefCounted
var gm: Node

func setup(game_state: Node, rng_manager: Node, time: RefCounted,
		attribute_system: RefCounted, manager: Node) -> void:
	gs = game_state
	rng = rng_manager
	time_system = time
	attributes = attribute_system
	gm = manager

func can_handle(action: String) -> bool:
	return action in ["list_buy", "list_sell"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"list_buy":
			return _buy(str(payload.get("item_id", "")))
		"list_sell":
			return _sell(int(payload.get("index", -1)))
	return {"ok": false, "reason": "Unknown 907List action."}

## The listing ids already taken TODAY.
##
## Reads defensively rather than trusting the field: canon normalizes the same
## way (`list.taken` guarded on `Array.isArray`), and a hand-edited or malformed
## save must degrade to "nothing taken" rather than crash the board. A stale day
## reads as empty, which is the lazy reset doing its job.
func taken_today() -> Array:
	var raw: Variant = gs.list_taken
	if not (raw is Dictionary):
		return []
	var taken: Dictionary = raw
	if int(taken.get("day", -1)) != gs.day:
		return []
	var ids: Variant = taken.get("ids", [])
	if not (ids is Array):
		return []
	var out: Array = []
	for id in (ids as Array):
		# Canon drops ids no listing table knows, so a renamed item in an old
		# save cannot permanently suppress a slot on the board.
		if not gs.listing_item_by_id(str(id)).is_empty():
			out.append(str(id))
	return out

## Canon markListingTaken. Rolls the day over lazily, then records the id once.
func _mark_taken(item_id: String) -> void:
	var raw: Variant = gs.list_taken
	if not (raw is Dictionary) or int((raw as Dictionary).get("day", -1)) != gs.day:
		gs.list_taken = {"day": gs.day, "ids": []}
	var ids: Variant = gs.list_taken.get("ids", [])
	if not (ids is Array):
		gs.list_taken["ids"] = []
		ids = gs.list_taken["ids"]
	if not item_id in (ids as Array):
		(ids as Array).append(item_id)

## Today's board. Seeded on the day, so it is stable while the day lasts and
## different tomorrow. Items above the player's tier never appear, and neither
## do the ones already taken today — see the header on why that filter runs on
## the pool rather than the result.
func todays_listings() -> Array:
	var tier: Dictionary = gs.market_tier()
	var consumed: Array = taken_today()
	var eligible: Array = []
	for i in gs.listing_items:
		if int(i["tier"]) <= gs.list_tier:
			if str(i["id"]) in consumed:
				continue
			eligible.append(i)
	if eligible.is_empty():
		return []
	var want: int = int(tier["listings"])
	# v0.1.0 seeded-key audit: day and tier lead the key (see realised_value).
	# seeded_shuffle prefixes its own swap index, so the hashed string reads
	# "<index>:<day>:<tier>:907list" -- everything that varies, up front.
	var key := "%d:%d:907list" % [gs.day, int(gs.list_tier)]
	var order: Array = rng.seeded_shuffle(gs.run_seed, key, eligible)
	return order.slice(0, mini(want, order.size()))

func capacity() -> int:
	return int(gs.market_tier()["capacity"])

func buy_blocker(item_id: String) -> String:
	if gs.game_over:
		return "The run is over."
	var item: Dictionary = gs.listing_item_by_id(item_id)
	if item.is_empty():
		return "No such listing."
	if gs.list_holdings.size() >= capacity():
		return "No room. %d is all you can carry." % capacity()
	if gs.cash < int(item["buy"]):
		return "You don't have $%d." % int(item["buy"])
	# Opportunity ownership. Deliberately checked LAST: the money and capacity
	# reasons are ones the player can act on, and this one they cannot, so it
	# should never mask a more useful message.
	#
	# Silent at the state layer by design — the board does not offer a consumed
	# listing, so reaching this is a stale tap or a replayed action, not a
	# choice the player made. The guard exists because "the UI does not offer
	# it" is not the same guarantee as "the system will not do it".
	if not _offered_today(item_id):
		return "That one is gone."
	return ""

## Is this listing actually on today's board? Consumption is the reason it
## usually is not, but this also rejects an id that is off-tier or simply never
## generated today — which is the real contract: a buy validates against the
## board that exists, not against the item table.
func _offered_today(item_id: String) -> bool:
	for listing in todays_listings():
		if str(listing["id"]) == item_id:
			return true
	return false

func _buy(item_id: String) -> Dictionary:
	var blocked := buy_blocker(item_id)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var item: Dictionary = gs.listing_item_by_id(item_id)
	var wallet: Object = gm.system("wallet")
	wallet.spend(int(item["buy"]), wallet.ROUTINE_DIRTY_FIRST,
		{"source_id": "list_buy_%s" % item_id})
	gs.list_holdings.append({
		"item_id": item_id, "bought_day": gs.day, "source": SOURCE_PLAYER})
	# The opportunity is spent whether or not the flip ever pays off.
	_mark_taken(item_id)
	gs.log_activity("%s, $%d, in a parking lot with the engine running." % [str(item["name"]), int(item["buy"])], AMBER)
	return {"ok": true}

## What a held item will actually fetch. Seeded on the holding so the number is
## fixed from the moment it is bought — the player is discovering a value that
## already existed, not rolling for one at the till.
func realised_value(holding: Dictionary) -> int:
	var item: Dictionary = gs.listing_item_by_id(str(holding["item_id"]))
	if item.is_empty():
		return 0
	var band: Array = item["true_value"]
	# v0.1.0 seeded-key audit: the varying components lead the key.
	#
	# FNV-1a's final rounds barely move the high bits, and `seeded_random` reads
	# the hash as `hash / 2^32` -- the high bits. A small counter appended to the
	# TAIL of a key therefore moves the roll by about `delta / 256`: eight
	# consecutive values spanned 2.7% of the band instead of covering it. The fix
	# is the one `RngManager.seeded_shuffle` already uses -- put the varying
	# component FIRST, so every remaining round diffuses it.
	var key := "%d:907list:value:%s" % [int(holding["bought_day"]), str(holding["item_id"])]
	return rng.seeded_int_range(gs.run_seed, key, int(band[0]), int(band[1]))

func sell_blocker(index: int) -> String:
	if gs.game_over:
		return "The run is over."
	if index < 0 or index >= gs.list_holdings.size():
		return "Nothing there."
	var held: Dictionary = gs.list_holdings[index]
	# Checked BEFORE the delay: a delegated pickup is never the player's to sell,
	# at any age. Pherris made the buy and Pherris closes it — selling it out
	# from under her would hand the player her cycle for free, and would credit
	# the flip to their standing.
	if str(held.get("source", SOURCE_PLAYER)) == SOURCE_PHERRIS:
		return "That's Pherris's pickup. It settles tonight."
	var delay: int = int(gs.market_tier()["sell_delay"])
	if gs.day - int(held["bought_day"]) < delay:
		return "The meet is tomorrow."
	return ""

func _sell(index: int) -> Dictionary:
	var blocked := sell_blocker(index)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	return settle_holding(index, PERSONAL)

## Turn one held item into money. **The single settlement path**, used by the
## player selling at the counter and by Pherris settling a delegated pickup at
## night. Returns `{ok, got, delta, tier}`.
##
## ## What the two modes share, and why
##
## The MONEY is identical: `realised_value` keys on the item and the day it was
## bought, so the same object fetches the same price whoever is holding it. So
## is the CONSEQUENCE — the `financial / 907list_profit` rows and the
## `market_meetup` outcome fire the same way in both modes.
##
## That last part is the one worth defending. It would be easy to treat a
## delegated sale as quieter because the player was not there, but the money
## still moved and the block still counts it — canon's rule is that what reaches
## Curtis is decided by the VALUE through his volume filter, not by whose hands
## carried it. Making delegation launder visibility would turn a crew member
## into a way to hide income, which is a different game.
##
## ## What only the player gets, and why
##
## Time, Intelligence, and tier progression. All three are the player's own
## experience of the trade:
##
##   - **A slot** is spent by the person who went to the meet. Pherris going
##     costs her day, not yours — that is the entire point of delegating.
##   - **Intelligence** trains on reading value well. Pherris reading it well
##     teaches you nothing.
##   - **`list_flips`** is the count that earns Broker standing, which is *your*
##     reputation on the board. Her flips are not your reputation.
##
## Those three are the leak this build must not spring: delegation that fed
## progression would make the crew member strictly better than doing it
## yourself, and the tier ladder would climb while the player learned nothing.
func settle_holding(index: int, execution_mode: String) -> Dictionary:
	if index < 0 or index >= gs.list_holdings.size():
		return {"ok": false, "reason": "Nothing there."}
	var delegated: bool = execution_mode == DELEGATED
	var held: Dictionary = gs.list_holdings[index]
	var item: Dictionary = gs.listing_item_by_id(str(held["item_id"]))
	var got: int = realised_value(held)
	var paid: int = int(item["buy"])

	# TI-003 §6 Clean. Canon agrees: `recordMarketFlip` is the other of the two
	# `addCleanCash` call sites in the whole build (game-core.js:3160). A resale
	# on a public listings board is legitimate income even when the seller is not.
	var wallet: Object = gm.system("wallet")
	wallet.credit(got, wallet.CLEAN, {"source_id": "list_sell"})
	gs.record_earning("list", got)
	gs.list_holdings.remove_at(index)

	if not delegated:
		# Canon counts a clean flip, not a sale — a loss does not advance the
		# tier. Her flips are not the player's standing, so this is skipped
		# whole rather than counted and discounted.
		if got > paid:
			gs.list_flips += 1
		_update_tier()

		# Canon (game-core.js:3164): a flip that clears 30% was a good READ, not
		# a lucky one, and reading value is exactly what Intelligence is for.
		# Breaking even teaches nothing, which is why the gate is a margin and
		# not a sale. `list_flips - 1` is canon's session count: how many came
		# before this one, which is what makes the first flips the valuable ones.
		if paid > 0 and float(got) > float(paid) * PROFITABLE_FLIP_MARGIN:
			attributes.train("list_flip", maxi(0, gs.list_flips - 1))

	# Canon recordMarketFlip: the money itself is news, on both channels that
	# trade in it.
	#
	# `value` carries the payout because that is what Curtis's network filter
	# reads — a big 907List day is exactly how a flip is meant to reach him, and
	# a $40 space heater is exactly how it is meant not to. Without the filter
	# (see Exposure.clears_curtis_filter) this observation would raise his
	# awareness on every trivial flip, which is the opposite of canon's design
	# for his attention.
	#
	# Household AND network: until canon's v1.19 the only financial channel was
	# the one the player lives on, so the people who trade in money for a living
	# could never hear about the money. Tracked rather than raw, so a network
	# arrival credits awareness the one way it is supposed to.
	#
	# No Heat. A flip is legitimate commerce as far as anyone watching is
	# concerned; what it costs is visibility, not police attention.
	#
	# Identical in both modes — see the header on why delegation must not
	# launder visibility.
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis != null:
		for channel in ["household", "network"]:
			curtis.broadcast_tracked({
				"type": "financial", "event": "907list_profit",
				"location": gs.current_district_id, "value": got, "channel": channel,
			})

	# How visible the handoff was. Canon keys this on the day, the slot and a
	# nonce; the held item is this build's nonce, which is unique per holding.
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	var tier: String = ""
	if resolver != null:
		var key := "meetup:%d:%d:%s" % [gs.day, gs.time_slots_today, str(held["item_id"])]
		var outcome: Dictionary = resolver.resolve_action("market_meetup", MEETUP_CHANCE,
			attributes.effective("intelligence"), gs.run_seed, key)
		tier = str(outcome["tier"])
		resolver.broadcast_outcome("market_meetup", tier, gs.current_district_id, got)

	var delta: int = got - paid
	if delegated:
		if delta >= 0:
			gs.log_activity("Pherris moved %s for $%d (+$%d)." % [str(item["name"]), got, delta], GREEN)
		else:
			gs.log_activity("Pherris moved %s for $%d. Down $%d." % [str(item["name"]), got, -delta], RED)
	elif delta >= 0:
		gs.log_activity("%s gone for $%d. Up $%d. Easy money never is, but this was close." % [str(item["name"]), got, delta], GREEN)
	else:
		gs.log_activity("%s gone for $%d. Down $%d. You overpaid and you knew it when you did." % [str(item["name"]), got, -delta], RED)
	# The only tier the player is ever told about: somebody clocked the handoff.
	# The rest of the spread is silent by design — see the header.
	if tier == "messy":
		gs.log_activity("A car sat across the lot the whole meet with nobody getting out.", AMBER)

	if not delegated:
		# A meet is a slot — for whoever went to it. Pherris going costs her day,
		# which is the whole point of asking her.
		time_system.handle("advance_time", {})

	# SQ-D10: the buyer's friend. Opened AFTER the slot is spent and after the
	# money is credited, because both of those already happened -- the sheet's
	# whole question is whether the money STAYS.
	var scene_opened: bool = _try_open_meetup_scene(held, item, tier, got, delegated)
	return {"ok": true, "got": got, "delta": delta, "tier": tier,
		"scene": scene_opened}

# --- SQ-D10: the buyer's friend (MEETUP_SCRIPT) -------------------------------
#
# `MEETUP_SCRIPT` has been authored in `data/confrontation_scripts.gd` since
# the loop was written, named in that file's own header as "the one 907List
# entry, on the catastrophic meetup tier", and consumed by nothing. This is it.
#
# ## The narrow trigger, and why each half of it is there
#
#   - **`catastrophic` only.** The meetup's outcome tier already exists and,
#     until now, decided nothing but an Exposure footprint -- this file's own
#     header says so in as many words ("the tier has no mechanical
#     consequence... that last tier is reachable here but toothless"). The
#     scene is what gives the worst tier teeth, and it is the only tier that
#     gets them: a messy meet is somebody noticing, not somebody bringing
#     a friend.
#   - **`value_floor` (150).** Nobody brings somebody to a $40 space heater.
#     The authored floor is read, never restated.
#   - **`suppress_meetup_scene`.** Pherris's `buyer_confirmed` tip, honoured
#     through `ConfrontationLoop.tip_modifiers_for` -- the one place a tip
#     payload is interpreted. Still a no-op until the tip system lands.
#
# ## Commercial, not criminal
#
# The ruling's own words, and the exit table below holds them: nobody swings
# first, injury lands only on a catastrophic exit, and the guaranteed out is a
# TRANSACTION rather than a surrender -- refund the money, take the item back,
# sell it tomorrow to somebody with fewer friends. That is what keeps this a
# 907List scene: the worst ORDINARY outcome is a reversed deal, not a hospital
# bill. It is also why this is the one room in the build whose guaranteed out
# hands the player back an asset instead of taking one.

const MEETUP_SCRIPT_ID := "meetup"

func _try_open_meetup_scene(held: Dictionary, item: Dictionary, tier: String,
		got: int, delegated: bool) -> bool:
	if tier != "catastrophic":
		return false
	if delegated:
		# Pherris went. Her meet, her friend's friend -- and the player is not
		# there to answer a sheet about a room they were not in.
		return false
	var script: Dictionary = SCRIPTS.MEETUP_SCRIPT
	if got < int(script["value_floor"]):
		return false
	var mods: Dictionary = LOOP.tip_modifiers_for(gs, str(held["item_id"]), 1)
	if bool(mods.get("suppress_meetup_scene", false)):
		gs.log_activity("Pherris vouched. The buyer shows on time with exact change. That's what a name is for.", GREEN)
		return false
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null or engine.has_active():
		return false

	var loop: Dictionary = {
		"script_id": MEETUP_SCRIPT_ID,
		"beat_index": 0,
		"round": 1,
		"log": [],
		"burned": [],
		"sheet_title": str(script["sheet_title"]),
		"stage": 0,
		"stage_count": int(script["cap"]),
		"left_label": "IN THE LOT",
		"left": 2,
		# The money is already in the wallet. BANKED says exactly that, which
		# is the whole framing of the scene.
		"banked": got,
	}
	var stub: Dictionary = {"decision": {}}
	_present_meetup(stub, loop, 0)
	engine.open_chain(engine.KIND_CONFRONTATION, {
		"district_id": str(gs.current_district_id),
		"return_route": "HOME",
		"source": {
			"family": "list", "action_id": "list_meetup", "kind": MEETUP_SCRIPT_ID,
			"target_id": str(held["item_id"]),
			"target_name": str(script["opponent"]),
			"opponent": str(script["opponent"]),
			"source_rng_key": "meetup:%d:%d:%s" % [gs.day, gs.time_slots_today,
				str(held["item_id"])],
			"payout": got, "contested_take": got,
			"item_id": str(held["item_id"]), "held": held.duplicate(true),
		},
		"decision": stub["decision"],
	})
	gs.log_activity("The buyer brought a friend. Nobody brings a friend to buy a camera.", AMBER)
	return true

## One authored beat onto the table. The script authors two; the second is
## reached when a rolled road takes a plain `failure`, the chassis's Q6 rule.
func _present_meetup(chain: Dictionary, loop: Dictionary, index: int) -> void:
	var script: Dictionary = SCRIPTS.MEETUP_SCRIPT
	var beats: Array = script["beats"]
	var actions: Dictionary = script["actions"]
	loop["beat_index"] = index
	loop["stage"] = index
	loop["beat"] = str(beats[clampi(index, 0, beats.size() - 1)])
	LOOP.append_log(loop, "The recount is happening." if index == 0
		else "The friend is between you and the lot.")

	var offered: Array = LOOP.without_burned(loop, actions.keys())
	var deterministic: Array = []
	var shown: Dictionary = {}
	for choice_id in offered:
		var action: Dictionary = actions[str(choice_id)]
		if bool(action.get("deterministic", false)):
			deterministic.append(str(choice_id))
		else:
			shown[str(choice_id)] = float(action["base"])
	LOOP.present_round(chain, loop, offered, deterministic, shown)
	var decision: Dictionary = chain.get("decision", {})
	decision["definition_id"] = MEETUP_SCRIPT_ID
	loop["round"] = index + 1
	decision["loop"] = loop
	chain["decision"] = decision

## The engine's one adapter method, registered under `list_meetup`.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var loop: Dictionary = LOOP.loop_of(chain)
	var script: Dictionary = SCRIPTS.MEETUP_SCRIPT
	var action: Dictionary = (script["actions"] as Dictionary).get(choice_id, {})
	var index: int = int(loop.get("beat_index", 0))

	if bool(action.get("deterministic", false)):
		return _exit_meetup(chain, loop, choice_id, "deterministic")

	var resolver: Object = gm.system("outcome_resolver")
	var tier := "failure"
	if resolver != null:
		tier = str((resolver.resolve_action(str(action["shape"]),
			float(action["base"]),
			attributes.effective(str(action["attribute"])), gs.run_seed,
			"%d:%s:%s:meetup" % [index,
				str((chain.get("source", {}) as Dictionary).get("source_rng_key", "")),
				choice_id]) as Dictionary)["tier"])

	if tier == "failure" and index + 1 < mini(int(script["cap"]),
			(script["beats"] as Array).size()):
		LOOP.burn(loop, choice_id)
		# BB-D4 (0.7.0): the round ends in a result; CONTINUE presents the
		# next beat through `present_next_round`.
		return LOOP.present_interim(gm.system("consequence"), gs, chain, loop,
			choice_id, tier, "escalate", {}, index + 1)
	return _exit_meetup(chain, loop, choice_id, tier)

## BB-D4: the next authored beat, from the loop's own note.
func present_next_round(chain: Dictionary) -> Dictionary:
	var loop: Dictionary = LOOP.loop_of(chain)
	var pending: Variant = LOOP.take_pending(loop)
	if loop.is_empty() or pending == null:
		return {"ok": false, "reason": "Nothing to move on to."}
	_present_meetup(chain, loop, int(pending))
	gs.active_consequence = chain
	return {"ok": true, "tier": "continued"}

## Every exit. The money is already in the wallet, so what an exit does is
## decide how much of it LEAVES again — clean, because that is where a 907List
## resale was credited (`settle_holding` above, TI-003 §6 Clean).
func _exit_meetup(chain: Dictionary, loop: Dictionary, choice_id: String,
		tier: String) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var decision: Dictionary = chain.get("decision", {})
	var source: Dictionary = chain.get("source", {})
	var payout: int = int(source.get("payout", 0))
	var wallet: Object = gm.system("wallet")

	var lost := 0
	var hurt := 0
	var resolution := SCRIPTS.RESOLUTION_WON
	var line := ""
	var restore_holding := false

	match choice_id:
		"refund_him":
			# The transaction out. Commercial to the last: the money goes back,
			# the item comes back, and it is tomorrow's problem instead.
			resolution = SCRIPTS.RESOLUTION_SURRENDERED
			lost = payout
			restore_holding = true
			line = "You count it back into his hand and take the box. Somebody with fewer friends will want it."
		"read_it":
			if tier in ["clean", "messy"]:
				line = "You see it a beat before it starts and you are already moving. Everything leaves with you."
			elif tier == "failure":
				resolution = SCRIPTS.RESOLUTION_ESCAPED
				lost = int(round(float(payout) * 0.5))
				line = "You get out of the lot with most of it and none of the argument."
			else:
				resolution = SCRIPTS.RESOLUTION_BEATEN
				lost = payout
				hurt = 8
				line = "You read it wrong, and the friend was the point."
		_:
			if tier in ["clean", "messy"]:
				line = "Receipts, handshakes, everybody's day continues. The money is yours."
			elif tier == "failure":
				resolution = SCRIPTS.RESOLUTION_ESCAPED
				lost = int(round(float(payout) * 0.5))
				line = "The price changes hands one more time than it should have. You keep half of it."
			else:
				resolution = SCRIPTS.RESOLUTION_BEATEN
				lost = payout
				hurt = 6
				line = "Nobody was ever buying a camera. It stops being a conversation."

	if lost > 0 and wallet != null:
		# CLEAN, out of the same balance `settle_holding` credited it to
		# (TI-003 §6: a resale on a public listings board is legitimate
		# income even when the seller is not).
		#
		# Capped at the clean balance FIRST, then spent clean-first. The cap is
		# what keeps this honest in both directions: a refund cannot overdraw,
		# a player who has already spent the money cannot lose more of it than
		# they still have, and because the amount can never exceed the clean
		# pool, `HIGH_VISIBILITY_CLEAN_FIRST` never touches dirty cash and so
		# never generates Financial Pressure. That matters -- handing money
		# back in a parking lot is not a formal bill, and TI-003 regression #24
		# is routine spending creating Pressure.
		lost = mini(lost, int(wallet.clean_balance()))
		if lost > 0:
			wallet.spend(lost, wallet.HIGH_VISIBILITY_CLEAN_FIRST,
				{"source_id": "list_meetup:%s" % choice_id})
	if restore_holding:
		gs.list_holdings.append((source.get("held", {}) as Dictionary).duplicate(true))
	if hurt > 0:
		var crew: Object = gm.system("crew") if gm != null else null
		if crew != null:
			hurt = int(crew.absorbed_damage(hurt))
		gs.health = clampi(int(gs.health) - hurt, 0, int(gs.health_max))

	gs.log_activity(line, GREEN if lost == 0 else AMBER)
	LOOP.append_log(loop, line)

	decision["resolved_tier"] = tier
	decision["result"] = {
		"choice_id": choice_id, "tier": tier, "resolution": resolution,
		"arrested": false, "banned": false,
		"cash": -lost, "goods": 0, "health": -hurt, "heat": 0.0, "pressure": 0,
		"take_disposition": "keep" if lost == 0 else "lose",
		"room_log": (loop.get("log", []) as Array).duplicate(),
	}
	decision["loop"] = loop
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": tier, "arrested": false}

## BB-D1 (0.7.0): the meetup's own endings, keyed by road then by the
## resolution `_exit_meetup` recorded. Commercial to the last line: the worst
## ordinary outcome here is a reversed deal, and the copy never forgets it.
const MEETUP_RESULT_COPY := {
	"refund_him": {
		"surrendered": ["YOU GIVE IT BACK", "You count it back into his hand and take the box. Somebody with fewer friends will want it tomorrow."],
	},
	"read_it": {
		"escalate": ["YOU MISSED IT", "The friend is between you and the lot now, and the buyer has stopped looking at you."],
		"won": ["YOU SAW IT COMING", "A beat before it started, you were already moving. Everything leaves with you."],
		"escaped": ["MOST OF IT", "You get out of the lot with most of the money and none of the argument."],
		"beaten": ["THE FRIEND WAS THE POINT", "You read it wrong. The money stays in the lot, and so does some of you."],
	},
	"stay_commercial": {
		"escalate": ["IT STOPS BEING COMMERCIAL", "The buyer is not talking about the price anymore. His friend is."],
		"won": ["EVERYBODY'S DAY CONTINUES", "Receipts, handshakes, nobody raises a voice. The money is yours."],
		"escaped": ["THE PRICE CHANGES HANDS TWICE", "One more time than it should have. You keep half of it and all of the lot."],
		"beaten": ["NOBODY WAS BUYING A CAMERA", "It stops being a conversation. The money goes back across the lot the hard way."],
	},
}

func _meetup_result_row(choice_id: String, effects: Dictionary) -> Array:
	var key := "escalate" if bool(effects.get("interim", false)) \
		else str(effects.get("resolution", ""))
	return ((MEETUP_RESULT_COPY.get(choice_id, {}) as Dictionary).get(key, []) as Array)

func result_headline(choice_id: String, _tier: String, effects: Dictionary) -> String:
	var row: Array = _meetup_result_row(choice_id, effects)
	return str(row[0]) if row.size() == 2 else ""

func result_body(choice_id: String, _tier: String, effects: Dictionary) -> String:
	var row: Array = _meetup_result_row(choice_id, effects)
	return str(row[1]) if row.size() == 2 else ""

func choice_label(choice_id: String) -> String:
	return str((SCRIPTS.MEETUP_SCRIPT["actions"] as Dictionary)
		.get(choice_id, {}).get("label", ""))

func choice_copy(choice_id: String) -> String:
	return str((SCRIPTS.MEETUP_SCRIPT["actions"] as Dictionary)
		.get(choice_id, {}).get("copy", ""))

## ENC-D6's seam. The screen's fallback ("no injury, no Heat, no arrest") is
## true here as far as it goes and still says nothing about the part that
## matters: this out costs the whole payout and hands the item back.
func choice_guarantee(choice_id: String) -> String:
	if choice_id == "refund_him":
		return "Guaranteed: nobody is hurt. The money goes back and the item is yours again."
	return ""

func _update_tier() -> void:
	var was: int = gs.list_tier
	# OG-D2: the board's tiers want a name as well as the flips -- a Broker
	# is somebody people answer, not somebody who has flipped ten things.
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	var known: bool = exposure == null or exposure.has_rank("known")
	var player: bool = exposure == null or exposure.has_rank("player")
	if gs.list_flips >= gs.BROKER_FLIP_REQUIREMENT and player:
		gs.list_tier = 3
	elif gs.list_flips >= gs.FLIPPER_FLIP_REQUIREMENT and known:
		gs.list_tier = maxi(gs.list_tier, 2)
	if gs.list_tier > was:
		gs.log_activity("The board opens up. People answer your listings now. You're a %s." % str(gs.market_tier()["name"]).capitalize(), GREEN)

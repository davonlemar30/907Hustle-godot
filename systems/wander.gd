extends RefCounted
## Wander — going out and looking, and what looking finds.
##
## ## What this restores
##
## The Home screen's operation card has carried a button labelled MOVE PRODUCT
## since the port began, and the function behind it says what it actually is:
##
##     ## Canon's explore_spenard: cashCost 0, timeCost 1 (game-core.js:358-360).
##     func _on_move_product() -> void:
##         if not _gm.dispatch("advance_time", {}):
##             return
##         nav.show_toast("Time passes. ...")
##
## That is Wander's own reducer, correctly priced, wired to nothing. The button
## spent the slot and printed the weather. Everything the slot was supposed to
## buy is in this file.
##
## ## The oracle
##
## Web changelog v1.3 (PR #59), verbatim:
##
##     Seeded job discovery system: Wash & Go (guaranteed first wander), Night
##     Owl, Delivery, Ship Creek Freight with ramped probability (30% base, +10%
##     per miss, cap 70%, one discovery per wander)
##     Narrative breadcrumbs on missed discovery rolls
##
##     Flat probability rejected in favor of ramped rolls with breadcrumbs to
##     prevent long droughts while keeping neighborhoods explorable indefinitely
##
## ## The shape, and the one place it improves on the oracle
##
## A wander is one slot and no money. It always produces something:
##
##   1. Curtis's people, if they are looking. `maybe_watcher_encounter` has had
##      `"wander"` in its reason list since it was written and has never once
##      been passed it — travel was the only caller. That is fixed by existing.
##   2. The DISCOVERY roll, ramped exactly as the oracle specifies.
##   3. On a hit: the thing goes on your map and the ramp resets.
##   4. On a miss: the ramp climbs, and a CARD is drawn from the eligible pool.
##
## Step 4 is the improvement. The oracle answers a missed roll with a breadcrumb
## and nothing else, which is honest but thin — three-quarters of early wanders
## are a line of text. Here the breadcrumb is the FALLBACK, reached only when no
## card is eligible, and a miss usually still hands the player something that
## happened. The ramp is untouched, so the pacing the oracle tuned is intact.
##
## Two smaller departures, both because this build has something the web one did
## not. Wander works in all three districts rather than only Spenard, with cards
## scoped by district — the port has a city and travel already costs a slot.
## And a card may gate on Heat band (batch 8), so walking around at BURNING is a
## different walk.
##
## ## What it does not own
##
## Money moves through Wallet. Heat moves through Heat. A slot moves through
## TimeSystem. A blocking encounter is the consequence engine's, opened as a
## fourth chain kind and rendered by the screen that already renders the other
## three — the web build made the same call and wrote down why: "reusing
## EncounterModal — no new UI shell."

const EVENTS := preload("res://data/wander_events.gd")

const GREEN := Color(0.451, 0.722, 0.404)
const AMBER := Color(0.882, 0.651, 0.227)
const BLUE := Color(0.373, 0.663, 0.847)
const MUTED := Color(0.6, 0.6, 0.6)

## How many card ids the "not that one again" window holds.
const RECENT_WINDOW := 3

var gs: Node
var gm: Node
var rng: Node
var time_system: RefCounted
var requirements: RefCounted

func setup(game_state: Node, manager: Node, rng_manager: Node,
		time_sys: RefCounted, requirement_system: RefCounted) -> void:
	gs = game_state
	gm = manager
	rng = rng_manager
	time_system = time_sys
	requirements = requirement_system

func can_handle(action: String) -> bool:
	return action == "wander"

func handle(action: String, _payload: Dictionary) -> Dictionary:
	if action != "wander":
		return {"ok": false, "reason": "Unknown wander action."}
	return _wander()

# --- reads -------------------------------------------------------------------

## Why you cannot go out right now, or "" if you can.
##
## Deliberately short. Wander is the cheapest thing on the screen and the one a
## player reaches for when nothing else is available; a long list of conditions
## on it would defeat the point of having it.
func blocker() -> String:
	if gs.game_over:
		return "The run is over"
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine != null and bool(engine.has_active()):
		return "Deal with what is in front of you"
	return ""

## The ramped discovery chance, exactly as the oracle specifies it. Public so
## the screen can tell the player it is getting warmer without inventing its own
## copy of the arithmetic.
func discovery_chance() -> float:
	return minf(float(EVENTS.DISCOVERY_CAP),
		float(EVENTS.DISCOVERY_BASE)
			+ float(EVENTS.DISCOVERY_PER_MISS) * float(maxi(0, int(gs.wander_misses))))

## What is still out there to find, in offer order. Empty once the map is full,
## which is what turns the discovery roll off rather than rolling for nothing.
func undiscovered() -> Array:
	var out: Array = []
	for job_id in EVENTS.DISCOVERY_JOBS:
		if not str(job_id) in gs.jobs_discovered:
			out.append(str(job_id))
	return out

## The facts a card's requirements are evaluated against.
##
## **This is the seam FS-001.5 proved is dangerous** — the evaluator is pure and
## reads what it is handed, so every fact a card can name has to be minted here
## or nowhere. Named for what a card asks about rather than for the field that
## backs it.
func facts() -> Dictionary:
	var heat: Object = gm.system("heat") if gm != null else null
	var band: String = str(heat.band()) if heat != null else ""
	return {
		"current_day": gs.day,
		"time_slots_today": gs.time_slots_today,
		"crew_count": gs.recruited_crew().size(),
		"list_flips": gs.list_flips,
		"job_contacts": gs.job_contacts,
		"districts_unlocked": gs.districts_unlocked,
		# Populations, for `collection_non_empty`.
		"inventory": gs.cargo_used(),
		"crew_records": gs.recruited_crew().size(),
		# Named booleans, for `fact_true`.
		"phone_active": bool(gs.phone_active),
		"heat_watched": band == "WATCHED" or band == "BURNING",
		"heat_burning": band == "BURNING",
		"carrying_dirty": int(gs.dirty_cash) > 0,
	}

## Every card that could come up right now: right district, right time of day,
## requirements met, not spent, not one of the last few seen.
func eligible_cards() -> Array:
	var out: Array = []
	var district := str(gs.current_district_id)
	var slot: int = int(gs.time_slots_today)
	var live: Dictionary = facts()
	for card in EVENTS.CARDS:
		var districts: Array = card["districts"]
		if not districts.is_empty() and not district in districts:
			continue
		var slots: Array = card["slots"]
		if not slots.is_empty() and not slot in slots:
			continue
		var card_id := str(card["id"])
		if bool(card.get("once", false)) and int(gs.wander_seen.get(card_id, 0)) > 0:
			continue
		if card_id in gs.wander_recent:
			continue
		if not bool(requirements.evaluate_requirements(card["requirements"], live)["ok"]):
			continue
		out.append(card)
	return out

# --- the action --------------------------------------------------------------

func _wander() -> Dictionary:
	var blocked: String = blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked + "."}

	gs.wander_count = int(gs.wander_count) + 1
	var report: Dictionary = {"ok": true, "kind": "", "card_id": ""}

	# Curtis's people first. They are not an event that competes with the draw —
	# they are the texture of being out at all, and the hook has been waiting for
	# a caller named "wander" since the day it was written.
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis != null:
		report["watcher"] = str(curtis.maybe_watcher_encounter("wander"))

	# A retaliation that is due and waiting for the player to BE somewhere finds
	# them on a wander, the same as it does on travel.
	#
	# Travel and day-start were the only two callers, which made walking the
	# block the one way to move around the neighbourhood that nobody waiting for
	# you could take advantage of. The presence gate is the engine's; this only
	# gives it the same chance to fire that a bus ride already had. If it opens
	# a chain, the walk is over — the blocking encounter IS the outcome, and
	# drawing a card on top of it would be two things happening at once.
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine != null:
		engine.try_surface_delayed(int(gs.day), str(gs.current_district_id))
		if bool(engine.has_active()):
			time_system.handle("advance_time", {})
			return {"ok": true, "kind": "surfaced", "card_id": ""}

	# The ramped roll. Day and slot lead the key, per the v0.1.0 seeded-key
	# audit: they are what moves between two wanders, and the district mostly is
	# not. The wander counter is in there too, so two walks taken in the SAME
	# slot cannot resolve identically.
	#
	# Belt-and-braces as things stand, and recorded that way rather than
	# claimed: the recency filter already stops a card repeating, and removing
	# this component leaves the whole parity suite green. It is kept because it
	# is correct and free, and it would start to matter the day the filter
	# changed. The batch-10 sabotage log says the same thing.
	var key := "%d:%d:%d:wander:%s" % [gs.day, gs.time_slots_today,
		int(gs.wander_count), str(gs.current_district_id)]
	var open: Array = undiscovered()
	if not open.is_empty() and rng.seeded_random(gs.run_seed, key) < discovery_chance():
		# WHICH one is seeded too. Taking `open[0]` made the order of a constant
		# array into the order of the game: every run in the port's history
		# would have found the warehouse before the freight yard.
		var pick: int = rng.seeded_int_range(gs.run_seed, key + ":find",
			0, open.size() - 1)
		report = _discover(str(open[pick]))
	else:
		if not open.is_empty():
			# Capped where the ramp itself stops mattering. Past the ceiling the
			# extra misses buy nothing, and letting the counter run free put the
			# live path and the load-time validator into disagreement — a save
			# at five misses came back clamped, with a repair reported against a
			# run that had done nothing wrong.
			gs.wander_misses = mini(int(gs.wander_misses) + 1,
				int(EVENTS.miss_ceiling()))
		report = _draw_card(key)

	# The slot, last, so everything above resolved against the day it happened
	# on rather than against the one it rolls into.
	time_system.handle("advance_time", {})
	return report

## Something goes on the map. The ramp resets, because it measures a drought and
## the drought is over.
func _discover(job_id: String) -> Dictionary:
	gs.jobs_discovered.append(job_id)
	gs.wander_misses = 0
	var name := job_id
	for job in gs.jobs:
		if str(job["id"]) == job_id:
			name = str(job["name"])
	gs.log_activity("Word of work: %s. Somebody will vouch if you turn up." % name, GREEN)
	var phone: Object = gm.system("phone") if gm != null else null
	if phone != null:
		phone.push_message("Around town",
			"they're taking people on at %s. go early and ask for the shift." % name)
	return {"ok": true, "kind": "discovery", "card_id": "", "discovered": job_id}

## One card from the eligible pool, weighted, or a breadcrumb when the pool is
## empty. A wander is never nothing.
func _draw_card(key: String) -> Dictionary:
	var pool: Array = eligible_cards()
	if pool.is_empty():
		return _breadcrumb()

	var total: int = 0
	for card in pool:
		total += maxi(1, int(card["weight"]))
	var roll: int = rng.seeded_int_range(gs.run_seed, key + ":card", 0, total - 1)
	var picked: Dictionary = pool[0]
	var running: int = 0
	for card in pool:
		running += maxi(1, int(card["weight"]))
		if roll < running:
			picked = card
			break

	var card_id := str(picked["id"])
	gs.wander_seen[card_id] = int(gs.wander_seen.get(card_id, 0)) + 1
	gs.wander_recent.append(card_id)
	while gs.wander_recent.size() > RECENT_WINDOW:
		gs.wander_recent.pop_front()

	match str(picked["kind"]):
		EVENTS.KIND_OPPORTUNITY:
			return _play_opportunity(picked, key)
		EVENTS.KIND_ENCOUNTER:
			return _play_encounter(picked, key)
		_:
			return _play_ambient(picked)

func _breadcrumb() -> Dictionary:
	var lines: Array = EVENTS.BREADCRUMBS
	var index: int = mini(int(gs.wander_misses), lines.size() - 1)
	gs.log_activity(str(lines[maxi(0, index)]), MUTED)
	return {"ok": true, "kind": "breadcrumb", "card_id": ""}

func _play_ambient(card: Dictionary) -> Dictionary:
	gs.log_activity(str(card["line"]), MUTED)
	var spec: Variant = card.get("observation")
	if spec is Dictionary:
		var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
		if exposure != null:
			var row: Dictionary = (spec as Dictionary).duplicate()
			var npc := str(row.get("npc", ""))
			row.erase("npc")
			row["location"] = str(gs.current_district_id)
			exposure.record_observation(npc, row)
	return {"ok": true, "kind": "ambient", "card_id": str(card["id"])}

func _play_opportunity(card: Dictionary, key: String) -> Dictionary:
	gs.log_activity(str(card["line"]), BLUE)
	var grant: Dictionary = card.get("grant", {})
	var report: Dictionary = {"ok": true, "kind": "opportunity", "card_id": str(card["id"])}

	if grant.has("cash"):
		var band: Array = grant["cash"]
		var amount: int = rng.seeded_int_range(gs.run_seed, key + ":cash",
			int(band[0]), int(band[1]))
		var wallet: Object = gm.system("wallet") if gm != null else null
		if wallet != null:
			# Found money is nobody's payroll. It goes in dirty, which is what
			# the wallet calls money with no story attached to it.
			wallet.credit(amount, wallet.DIRTY, {"source_id": "wander_found"})
		gs.log_activity("Picked up $%d." % amount, GREEN)
		report["cash"] = amount

	if bool(grant.get("intel", false)):
		# A price somebody said out loud. Handed to the phone rather than
		# printed here, because Word Around Town is where a price the player is
		# not standing in front of already lives (batch 5).
		var phone: Object = gm.system("phone") if gm != null else null
		if phone != null:
			# `market_intel()` is the same read Word Around Town renders, so an
			# overheard price is the SAME price the phone would have shown —
			# what the card buys is hearing it a day early, not a second table.
			var routes: Array = phone.market_intel()
			if not routes.is_empty():
				var line: String = str(phone.market_intel_line(routes[0]))
				if not line.is_empty():
					phone.push_message("Around town", line)
					report["intel"] = line
	return report

## A card that is a person standing in front of you. Opens a real chain.
func _play_encounter(card: Dictionary, key: String) -> Dictionary:
	var engine: Object = gm.system("consequence") if gm != null else null
	var spec: Dictionary = card.get("encounter", {})
	if engine == null or spec.is_empty():
		return _play_ambient(card)

	var attributes: Object = gm.system("attributes") if gm != null else null
	var shown: Dictionary = {}
	var inputs: Dictionary = {}
	var attribute := _attribute_for(str(spec["shape"]))
	for choice_id in (spec["choices"] as Array):
		var base: Variant = (spec["base"] as Dictionary).get(str(choice_id))
		if base == null:
			continue
		shown[str(choice_id)] = float(base)
		inputs[str(choice_id)] = {
			"attribute": attribute,
			"raw": int(attributes.effective(attribute)) if attributes != null else 1,
		}

	gs.log_activity(str(card["line"]), AMBER)
	var opened: Dictionary = engine.open_chain(engine.KIND_WANDER, {
		"district_id": str(gs.current_district_id),
		"return_route": "HOME",
		"source": {
			"family": "wander",
			"action_id": "wander",
			"card_id": str(card["id"]),
			"opponent": str(spec.get("opponent", "")),
			"shape": str(spec["shape"]),
			"target_id": str(card["id"]),
			"target_name": str(spec.get("opponent", "")),
			"target_tier": 1,
			"contested_take": 0,
			"source_day": int(gs.day),
			"source_slot": int(gs.time_slots_today),
			"source_rng_key": key,
			"pre_encounter_heat": float(gs.heat),
		},
		"decision": {
			"definition_id": str(spec["definition_id"]),
			"allowed_choices": (spec["choices"] as Array).duplicate(),
			"deterministic_choices": (spec.get("deterministic", []) as Array).duplicate(),
			"resolver_inputs": inputs,
			"shown_probabilities": shown,
			"arrest_risks": {},
		},
	})
	return {"ok": true, "kind": "encounter", "card_id": str(card["id"]),
		"opened": bool(opened.get("ok", false))}

func _attribute_for(shape: String) -> String:
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	if resolver == null:
		return "combat"
	var mapped: String = str(resolver.ACTION_ATTRIBUTE_MAP.get(shape, "combat"))
	return mapped if not mapped.is_empty() else "combat"

# --- the chain's source adapter ----------------------------------------------

## The button, and the line under it. Asked by the consequence engine through
## its adapter-copy seam; an empty return falls back to what the engine would
## have said, which is how a choice this file has no opinion about still reads.
func choice_label(choice_id: String) -> String:
	return str(EVENTS.CHOICE_LABELS.get(choice_id, ""))

func choice_copy(choice_id: String) -> String:
	return str(EVENTS.CHOICE_COPY.get(choice_id, ""))


## What the choice does. The engine calls exactly this one method on a source
## adapter, which is the whole cost of a fourth chain kind.
##
## Nothing here books an arrest. A wander encounter is somebody on a corner, not
## a crime the player committed, and the two chains that DO reach custody both
## open off an action the player chose to take. Losing the bag is the worst of
## it, and that is bad enough at the moment it happens.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var source: Dictionary = chain.get("source", {})
	var decision: Dictionary = chain.get("decision", {})
	var shape := str(source.get("shape", "confrontation"))
	var deterministic: Array = decision.get("deterministic_choices", [])

	var tier := "deterministic"
	if not choice_id in deterministic:
		var resolver: Object = gm.system("outcome_resolver") if gm != null else null
		var attributes: Object = gm.system("attributes") if gm != null else null
		var chance: float = float((decision.get("shown_probabilities", {}) as Dictionary)
			.get(choice_id, 0.5))
		var attribute := _attribute_for(shape)
		tier = "failure"
		if resolver != null:
			tier = str((resolver.resolve_action(shape, chance,
				int(attributes.effective(attribute)) if attributes != null else 1,
				gs.run_seed, "%s:%s" % [str(source.get("source_rng_key", "")), choice_id]
				) as Dictionary)["tier"])

	var lost: int = 0
	var hurt: int = 0
	match tier:
		"deterministic":
			# Handing it back. No roll, and the known loss is the whole content
			# of the option being on the card.
			lost = _lose_cargo(1.0)
			gs.log_activity("You give it up and keep walking. %d units gone." % lost, AMBER)
		"clean":
			gs.log_activity("It comes to nothing. They decide you are not worth it.", GREEN)
		"messy":
			hurt = 4
			gs.log_activity("It gets loud before it gets finished. You walk away sore.", AMBER)
		"failure":
			lost = _lose_cargo(0.5)
			gs.log_activity("It does not go your way. %d units gone." % lost, AMBER)
		_:
			lost = _lose_cargo(1.0)
			hurt = 12
			gs.log_activity("It goes badly. %d units gone and you are wearing it." % lost, AMBER)

	if hurt > 0:
		# Through Tone, like both of the build's other damage sites.
		var crew: Object = gm.system("crew") if gm != null else null
		if crew != null:
			hurt = int(crew.absorbed_damage(hurt))
		gs.health = clampi(gs.health - hurt, 0, gs.health_max)

	# The result block, in the shape every other chain writes, then the stage.
	#
	# **No arrest, structurally.** The two chains that reach custody both open
	# off a crime the player chose to commit; this one opens because they went
	# for a walk. Nothing here can reach ArrestSystem, and that absence is the
	# design rather than an omission.
	var result := {
		"choice_id": choice_id,
		"tier": tier,
		"arrested": false,
		"banned": false,
		"cash": 0,
		"goods": -lost,
		"health": -hurt,
		"heat": 0.0,
		"pressure": 0,
		"take_disposition": "lose" if lost > 0 else "keep",
	}
	decision["resolved_tier"] = tier
	decision["result"] = result
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": tier, "arrested": false}

## Take a fraction of what is being carried, rounded up so a bag with anything
## in it always loses something.
func _lose_cargo(fraction: float) -> int:
	var taken: int = 0
	for product_id in gs.inventory.keys():
		var held: int = int(gs.inventory[product_id])
		if held <= 0:
			continue
		var lose: int = held if fraction >= 1.0 else maxi(1, int(ceil(float(held) * fraction)))
		lose = mini(lose, held)
		gs.inventory[product_id] = held - lose
		taken += lose
	for product_id in gs.inventory.keys():
		if int(gs.inventory[product_id]) <= 0:
			gs.inventory.erase(product_id)
	return taken

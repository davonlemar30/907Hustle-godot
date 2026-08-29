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
## The shared multi-round chassis (0.5.0 PR B) — `loop_of`/`has_loop`/
## `append_log`/`present_round`, the same helpers Stickup's own rooms use.
const LOOP := preload("res://systems/confrontation_loop.gd")
## `STASH_IT`'s own authored row (0.5.0 PR B) — see `data/wander_events.gd`'s
## own header on why this file reads it rather than `EVENTS` re-exporting it.
const SCRIPTS := preload("res://data/confrontation_scripts.gd")

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

func handle(action: String, payload: Dictionary) -> Dictionary:
	if action != "wander":
		return {"ok": false, "reason": "Unknown wander action."}
	# An unnamed wander is a READ, because that is the one intent that is always
	# worth something — discovery runs out and deals need capital, but there is
	# always something going on you do not know about.
	var intent := str(payload.get("intent", EVENTS.INTENT_READ))
	if not intent in EVENTS.INTENTS:
		return {"ok": false, "reason": "Nobody wanders like that."}
	return _wander(intent)

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

## The same read for Boost, and the reason DEAL is now worth walking for.
##
## WORK had a discovery pool and DEAL did not, which made the intents unequal in
## a way the copy never admitted: one of them could put something permanent on
## your map and the other could only draw a card. This is DEAL's pool.
##
## Three filters, and each one is the same argument the job pool makes silently.
## DISTRICT, because you find what is in front of you. ALREADY-CLOCKED, because
## the pool is what is left. And TIER — you do not notice the unlatched dock door
## at Ship Creek Yards while you are still learning which corner shop watches the
## lot, so a target above your current tier is not yet a thing you would see.
##
## That last one is what makes the pool REFILL rather than merely drain: climbing
## the Boost ladder puts new targets into the discovery pool, so tier progress and
## walking the block feed each other instead of racing.
func undiscovered_boost_targets() -> Array:
	var district := str(gs.current_district_id)
	var out: Array = []
	for target in gs.boost_targets:
		if str(target["area"]) != district:
			continue
		if str(target["id"]) in gs.boost_targets_discovered:
			continue
		if int(target["tier"]) > int(gs.boost_tier):
			continue
		out.append(str(target["id"]))
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
		"heat_noticed": band != "" and band != "COOL",
		"heat_watched": band == "WATCHED" or band == "BURNING",
		"curtis_visible": str(gs.curtis_phase) != "invisible",
		"heat_burning": band == "BURNING",
		"carrying_dirty": int(gs.dirty_cash) > 0,
		# 0.5.0 PR B: gates `wander_curtis_tax` — his own people only start
		# collecting once he is actually watching, the same phase floor
		# `_read_curtis()` already treats as worth telling the player about.
		"curtis_watching_or_worse": str(gs.curtis_phase) in ["watching", "approaching"],
		# So a future card can gate on whether the corner is even known yet
		# (PR 4) — a card about somebody asking product prices makes no
		# sense before the player knows where the corner is.
		"market_discovered": bool(gs.market_discovered),
	}

## Every card that could come up right now: right district, right time of day,
## requirements met, not spent, not one of the last few seen.
##
## STR-D1 (0.5.0 PR A): `KIND_ENCOUNTER` cards are excluded here — they fold
## into the interruption gate below and are no longer ordinary pool citizens.
## `eligible_encounters()` is their own filter, sharing every OTHER rule this
## function already enforces (district, slot, once, recency, requirements) so
## a gated encounter is held to exactly the same authoring discipline as
## everything else in the deck.
func eligible_cards() -> Array:
	var out: Array = []
	var district := str(gs.current_district_id)
	var slot: int = int(gs.time_slots_today)
	var live: Dictionary = facts()
	for card in EVENTS.CARDS:
		if str(card["kind"]) == EVENTS.KIND_ENCOUNTER:
			continue
		var districts: Array = card["districts"]
		if not districts.is_empty() and not district in districts:
			continue
		var slots: Array = card["slots"]
		if not slots.is_empty() and not slot in slots:
			continue
		var card_id := str(card["id"])
		if bool(card.get("once", false)) and int(gs.wander_seen.get(card_id, 0)) > 0:
			continue
		# The recency window does not apply to a READ.
		#
		# It exists so the same BEAT does not land twice running, and a read is
		# not a beat — it is a report of what is true right now. Hearing that the
		# corner is still watched two walks in a row is the fact still being
		# true, not the game repeating itself. Suppressing it also emptied the
		# pool: four of the five reads are gated, so early on `read_the_corner`
		# is the only one eligible, and one recency hit turned a READ walk into
		# ambient flavour — which is the opposite of what the intent is for.
		if str(card["kind"]) != EVENTS.KIND_READ and card_id in gs.wander_recent:
			continue
		if not bool(requirements.evaluate_requirements(card["requirements"], live)["ok"]):
			continue
		out.append(card)
	return out

## The encounter-only pool the gate picks from, held to the exact same
## district/slot/once/recency/requirements discipline `eligible_cards()`
## enforces for everything else — POOL-D1's own requirement is that a staged
## card declares through `requirements.gd` like any other, not through a
## second eligibility idea invented for encounters specifically.
func eligible_encounters() -> Array:
	var out: Array = []
	var district := str(gs.current_district_id)
	var slot: int = int(gs.time_slots_today)
	var live: Dictionary = facts()
	for card in EVENTS.CARDS:
		if str(card["kind"]) != EVENTS.KIND_ENCOUNTER:
			continue
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

# --- STR-D1/D2: the interruption gate (0.5.0 PR A) --------------------------

## Any debt a player is carrying past its own due point — Dre's account, a
## defaulted Book note, or rent gone unpaid at least once. Reads `gs.debt_
## due_days` rather than `dre_account["status"]` directly: the negative-means-
## overdue sign convention is already the one every existing reader (the HUD,
## Finances, Phone's obligations list) depends on, so this is the same fact
## through the same seam rather than a second way to ask Dre's own account
## whether it is late.
func _has_overdue_debt() -> bool:
	if int(gs.debt_due_days) < 0:
		return true
	if int(gs.rent_missed) >= 1:
		return true
	for entry in gs.shark_loans:
		if str((entry as Dictionary).get("status", "")) == "defaulted":
			return true
	return false

## Total attention steps: how loudly the street already knows this player,
## right now, in this district. Each of Heat, District Pressure, and Curtis
## contributes 0-3 off that system's OWN existing band vocabulary — nothing
## here invents a second scale for any of them — and any overdue debt adds a
## flat `GATE_OVERDUE_STEPS`, per STR-D2's own framing of the three
## conditions (elevated Heat, HOT pressure, overdue debt) as independent
## alternatives rather than one blended score.
##
## Public (0.5.0 PR C): Travel's own checkpoint gate reads this exact
## formula rather than a second one — STR-D4 asks for "the same interruption
## machinery," not a travel-flavored reinvention of it. Wander stays the
## formula's one author; Travel calls it the same way it already calls
## Heat's own `band()`.
func attention_steps() -> int:
	var steps := 0
	var heat: Object = gm.system("heat") if gm != null else null
	if heat != null:
		match str(heat.band()):
			heat.BAND_NOTICED:
				steps += 1
			heat.BAND_WATCHED:
				steps += 2
			heat.BAND_BURNING:
				steps += 3
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine != null:
		var summary: Dictionary = engine.local_attention_summary(str(gs.current_district_id))
		var loudest: String = str(summary.get("loudest_family", ""))
		if not loudest.is_empty():
			var families: Dictionary = summary.get("families", {})
			steps += int((families.get(loudest, {}) as Dictionary).get("steps", 0))
	match str(gs.curtis_phase):
		"ambient":
			steps += 1
		"watching":
			steps += 2
		"approaching":
			steps += 3
	if _has_overdue_debt():
		steps += EVENTS.GATE_OVERDUE_STEPS
	return steps

## Roll the gate for this walk. Returns `{}` if the street stays quiet —
## either nothing eligible exists to fire at all, or something was eligible
## and the roll missed — or `{"card": <picked>, "key": <the roll's own
## seeded key>}` if it opened, the key handed back so the caller opens the
## chain on the SAME draw rather than reconstructing it a second time.
##
## The quiet streak is read and written here, and nowhere else: this is the
## one place per walk that knows whether the gate just opened. An empty pool
## STILL counts as a quiet walk for the streak's own purposes — the player
## experienced an uneventful walk either way, and the streak measures that
## experience, not which internal reason produced it. A hot player standing
## somewhere with genuinely nothing eligible gets no encounter regardless of
## how loud the cap says they should be — the guarantee cannot force a card
## that does not exist — but the walk still banks toward forcing one open
## the moment something becomes eligible again, rather than the wait
## resetting for free every time the pool happens to run dry.
func _roll_gate() -> Dictionary:
	var steps: int = attention_steps()
	var cap: int = EVENTS.quiet_streak_cap(steps)
	var forced: bool = cap >= 0 and int(gs.wander_quiet_streak) >= cap
	var pool: Array = eligible_encounters()
	if pool.is_empty():
		gs.wander_quiet_streak = int(gs.wander_quiet_streak) + 1
		return {}
	var key := "%d:%d:%d:wander:%s:gate" % [gs.day, gs.time_slots_today,
		int(gs.wander_count), str(gs.current_district_id)]
	var opened: bool = forced \
		or rng.seeded_random(gs.run_seed, key) < EVENTS.gate_chance(steps)
	if not opened:
		gs.wander_quiet_streak = int(gs.wander_quiet_streak) + 1
		return {}
	gs.wander_quiet_streak = 0
	return {"card": _pick_encounter(pool, key), "key": key}

## WHICH encounter, once the gate is open — weighted toward whatever kind of
## trouble actually caused it (PR A item 2). Overdue debt outweighs every
## other reason a script can be tagged for, since STR-D2 names it as its own
## trigger rather than a component of one blended score; short of that, a
## script tagged for the loudest live signal (Pressure's recognition scripts,
## or Heat's) gets the same boost. A card with no `gate_bias` tag is neutral
## everywhere — today's two legacy cards carry none, so this reduces to a
## plain weighted pick until PR B's roster gives it something to prefer.
func _pick_encounter(pool: Array, key: String) -> Dictionary:
	var overdue: bool = _has_overdue_debt()
	var loudest_family := ""
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine != null:
		loudest_family = str(engine.local_attention_summary(
			str(gs.current_district_id)).get("loudest_family", ""))
	var weights: Array[int] = []
	var total := 0
	for card in pool:
		var w: float = float(maxi(1, int((card as Dictionary)["weight"])))
		var bias := str((card as Dictionary).get("gate_bias", ""))
		if overdue and bias == "debt":
			w *= EVENTS.GATE_BIAS_MATCH
		elif not loudest_family.is_empty() and bias == loudest_family:
			w *= EVENTS.GATE_BIAS_MATCH
		var scaled: int = maxi(1, int(round(w)))
		weights.append(scaled)
		total += scaled
	var roll: int = rng.seeded_int_range(gs.run_seed, key + ":pick", 0, total - 1)
	var picked: Dictionary = pool[0]
	var running := 0
	for index in pool.size():
		running += weights[index]
		if roll < running:
			picked = pool[index]
			break
	return picked

# --- the action --------------------------------------------------------------

## What this walk is worth, given how many are already behind it today.
func effort() -> float:
	return float(EVENTS.effort_for(int(gs.wanders_today)))

func _wander(intent: String) -> Dictionary:
	var blocked: String = blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked + "."}

	# The day's effort is read BEFORE this walk is counted, so the first walk of
	# a day is the first walk rather than the second.
	var spent: float = effort()
	gs.wander_count = int(gs.wander_count) + 1
	gs.wanders_today = int(gs.wanders_today) + 1
	var report: Dictionary = {"ok": true, "kind": "", "card_id": "", "intent": intent}

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

	# STR-D1: the interruption gate, rolled before anything else gets a turn.
	# If it opens, the walk IS the encounter — nothing below this fires, the
	# same "the blocking encounter is the outcome" rule the retaliation check
	# above already follows.
	var gate: Dictionary = _roll_gate()
	if not (gate.get("card", {}) as Dictionary).is_empty():
		report = _play_encounter(gate["card"], str(gate["key"]))
		report["intent"] = intent
		report["effort"] = spent
		time_system.handle("advance_time", {})
		return report

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
	# A walk that went looking for work finds work — and so, as of PR 5, does
	# a walk that went looking for nothing in particular. The Home screen
	# collapsed to one WALK AROUND button that always dispatches READ, so
	# READ is now the "explore everything" intent rather than one of three
	# equal choices: it draws from BOTH sub-pools below on top of its own
	# full-weight card pool. WORK and DEAL still exist — a future caller can
	# dispatch either directly, and the parity profiles do — and each still
	# answers to ONLY its own pool, never the other's: what changed is which
	# intents can reach a pool at all, not which pool a given intent reaches.
	var open: Array = undiscovered() \
		if intent in [EVENTS.INTENT_WORK, EVENTS.INTENT_READ] else []
	# The DEAL pool, on its own key. Batch 14.
	#
	# It is the same roll — same ramp, same effort scaling, same one-find-per-walk
	# rule — reached by a different intent and answered from a different pool.
	# Still not a WORK/DEAL mixed draw: WORK finding a boost target would make
	# the choice between them cosmetic, which is the exact defect batch 13
	# removed from Wander in the first place. READ reaching both (PR 5) is a
	# different claim — READ was never one of the two named choices, it is
	# the button that stopped asking the player to choose at all.
	#
	# Keyed `:deal` rather than off the bare `key`, so the two intents cannot
	# resolve off the same draw. Sharing the key would mean a run that spent walk
	# five looking for work and a run that spent walk five looking for a deal both
	# hit or both missed, which is one stream pretending to be two.
	var open_targets: Array = undiscovered_boost_targets() \
		if intent in [EVENTS.INTENT_DEAL, EVENTS.INTENT_READ] else []
	if not open.is_empty() \
			and rng.seeded_random(gs.run_seed, key) < discovery_chance() * spent:
		# WHICH one is seeded too. Taking `open[0]` made the order of a constant
		# array into the order of the game: every run in the port's history
		# would have found the warehouse before the freight yard.
		var pick: int = rng.seeded_int_range(gs.run_seed, key + ":find",
			0, open.size() - 1)
		report = _discover(str(open[pick]))
	elif not open_targets.is_empty() \
			and rng.seeded_random(gs.run_seed, key + ":deal") < discovery_chance() * spent:
		var picked_target: int = rng.seeded_int_range(gs.run_seed, key + ":deal_find",
			0, open_targets.size() - 1)
		report = _discover_boost_target(str(open_targets[picked_target]))
	# Market discovery: fires on any intent, same ramp, its own key. Finding
	# the corner is not something you go looking for specifically — it is
	# something that happens while you are out for any reason at all, which
	# is why this excludes NO intent, where WORK/DEAL (even after PR 5 added
	# READ to both) still each exclude the other's named intent. Playtest
	# finding: Market unlocked deterministically on the FIRST wander of every
	# run, which read as scripted rather than found. Only rolls while
	# unfound — a one-way latch, same as `boost_targets_discovered`.
	elif not gs.market_discovered \
			and rng.seeded_random(gs.run_seed, key + ":market") < discovery_chance() * spent:
		report = _discover_market()
	else:
		if not open.is_empty() or not open_targets.is_empty() or not gs.market_discovered:
			# Capped where the ramp itself stops mattering. Past the ceiling the
			# extra misses buy nothing, and letting the counter run free put the
			# live path and the load-time validator into disagreement — a save
			# at five misses came back clamped, with a repair reported against a
			# run that had done nothing wrong.
			#
			# A missed DEAL roll climbs the SAME ramp a missed WORK roll does,
			# and that is the point rather than an oversight: the ramp measures
			# a drought of finding things, and a player who has come back with
			# nothing four walks running has had the same drought whichever way
			# they were looking. One counter, so "getting warmer" means one
			# thing. A missed MARKET roll is the third voice saying the same
			# thing — the OR now covers all three pools, because a walk that
			# only had the market left to find and did not find it is still a
			# walk that came back with nothing.
			gs.wander_misses = mini(int(gs.wander_misses) + 1,
				int(EVENTS.miss_ceiling()))
		report = _draw_card(key, intent, spent)
	report["intent"] = intent
	report["effort"] = spent

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

## A place goes on the map. The job version's twin, and it resets the same ramp
## for the same reason — the drought is over, whatever ended it.
##
## The phone line is lower-case and second-hand on purpose. A job discovery is
## somebody telling you where to turn up; this is somebody mentioning a shop got
## done, which is the most anybody would ever say out loud about it.
func _discover_boost_target(target_id: String) -> Dictionary:
	gs.boost_targets_discovered.append(target_id)
	gs.wander_misses = 0
	var target: Dictionary = gs.boost_target_by_id(target_id)
	var place: String = str(target.get("name", target_id))
	gs.log_activity("You clock a spot: %s. Worth remembering." % place, GREEN)
	var phone: Object = gm.system("phone") if gm != null else null
	if phone != null:
		phone.push_message("Around town",
			"heard somebody got into %s clean. might be worth a look." % place.to_lower())
	return {"ok": true, "kind": "discovery", "card_id": "",
		"discovered_boost": target_id}

## The player finds the corner. Same shape as `_discover` and
## `_discover_boost_target` — the ramp resets because the drought is over,
## whatever ended it, and the find goes on the map for good.
func _discover_market() -> Dictionary:
	gs.market_discovered = true
	gs.wander_misses = 0
	gs.log_activity("You see where the handoffs happen. Street Market is on the board.", GREEN)
	var phone: Object = gm.system("phone") if gm != null else null
	if phone != null:
		phone.push_message("Around town",
			"the corner off spenard road. everybody knows where it is once you know where it is.")
	return {"ok": true, "kind": "discovery", "card_id": "", "discovered_market": true}

## One card from the eligible pool, weighted, or a breadcrumb when the pool is
## empty. A wander is never nothing.
func _draw_card(key: String, intent: String, spent: float) -> Dictionary:
	var pool: Array = eligible_cards()
	if pool.is_empty():
		return _breadcrumb()

	# Weights are scaled by whether the card is what you went out for. A miss is
	# damped, not excluded — an intent steers the walk, it does not put blinkers
	# on it, and getting jumped while looking for work is exactly the kind of
	# thing that should still be able to happen.
	var weights: Array[int] = []
	var total: int = 0
	for card in pool:
		var w: float = float(maxi(1, int(card["weight"])))
		w *= EVENTS.INTENT_MATCH if intent in (card["intents"] as Array) else EVENTS.INTENT_MISS
		var scaled: int = maxi(1, int(round(w)))
		weights.append(scaled)
		total += scaled
	var roll: int = rng.seeded_int_range(gs.run_seed, key + ":card", 0, total - 1)
	var picked: Dictionary = pool[0]
	var running: int = 0
	for index in pool.size():
		running += weights[index]
		if roll < running:
			picked = pool[index]
			break

	var card_id := str(picked["id"])
	gs.wander_seen[card_id] = int(gs.wander_seen.get(card_id, 0)) + 1
	gs.wander_recent.append(card_id)
	while gs.wander_recent.size() > RECENT_WINDOW:
		gs.wander_recent.pop_front()

	match str(picked["kind"]):
		EVENTS.KIND_OPPORTUNITY:
			return _play_opportunity(picked, key, spent)
		EVENTS.KIND_ENCOUNTER:
			return _play_encounter(picked, key)
		EVENTS.KIND_READ:
			return _play_read(picked)
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

func _play_opportunity(card: Dictionary, key: String, spent: float) -> Dictionary:
	gs.log_activity(str(card["line"]), BLUE)
	var grant: Dictionary = card.get("grant", {})
	var report: Dictionary = {"ok": true, "kind": "opportunity", "card_id": str(card["id"])}

	if grant.has("cash"):
		var band: Array = grant["cash"]
		# Scaled by the day's effort: the third walk turns up loose change, not
		# the same folded bills as the first.
		var amount: int = maxi(1, int(round(float(rng.seeded_int_range(
			gs.run_seed, key + ":cash", int(band[0]), int(band[1]))) * spent)))
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
## Choice ids whose resolution shape differs from their own card's overall
## `shape` — 0.5.0 PR B's one exception, `stash_it`, which rolls Intelligence
## on a card whose main verbs (`talk`/`keep_walking`) roll Charisma. Named
## directly by ATTRIBUTE rather than by a second `outcome_resolver` shape:
## `OUTCOME_SHAPES`/`ACTION_ATTRIBUTE_MAP` are oracle-parity tables, checked
## byte-for-byte against fixtures recorded off the web build, and a shape
## this Godot-only port invents has no oracle entry to check against —
## `_stash_it_tier()` already rolls its own chance directly for the same
## reason. This override exists purely so the confirmation screen LABELS the
## roll correctly; it never reaches the resolver at all. Keyed by card id so
## a future card reusing the same choice id under a different attribute is
## never ambiguous.
const CHOICE_ATTRIBUTE_OVERRIDES := {
	"wander_stopped_on_foot": {"stash_it": "intelligence"},
}

func _attribute_for_choice(card_id: String, encounter_shape: String, choice_id: String) -> String:
	var overrides: Dictionary = CHOICE_ATTRIBUTE_OVERRIDES.get(card_id, {})
	if overrides.has(choice_id):
		return str(overrides[choice_id])
	return _attribute_for(encounter_shape)

## Choices offered beyond a card's own static list, added only when their own
## condition holds. `stash_it` is `SCRIPTS.STASH_IT`'s own authored condition
## (Q4: "added... when inventory > 0") reactivated here rather than baked
## into `wander_stopped_on_foot`'s static `choices` — an empty-handed stop
## must read as the two-choice encounter it always was.
func _conditional_choices(card_id: String) -> Array:
	if card_id == "wander_stopped_on_foot" and int(gs.cargo_used()) > 0:
		return ["stash_it"]
	return []

# --- SQ-D9: crew calls as chassis actions ------------------------------------
#
# `CREW_CALLS` has been authored in `data/confrontation_scripts.gd` since the
# loop was written and nothing has ever consumed it. It is not a wander feature
# and this is not the file that owns it: the rules (who, what resolution, what
# it costs) stay in the script table, and this reads them the same way it reads
# an authored `effects` row.
#
# Availability is the existing language, not a new one: recruited AND active
# (`gs.is_recruited`, which folds both), loyalty above zero, and unassigned
# today -- `crew_unassigned_today` is already how `systems/requirements.gd`
# spells "they are around", and this asks the same question of the same field.
#
# Once per loop, and calling burns no verb: Tone is not your swing. Both of
# those are enforced in `_crew_call_available` and `_resolve_crew_call` rather
# than by the card, because they are chassis rules and a card that forgot one
# would be a card that quietly broke the chassis.

## Which calls this card admits AND could actually place right now, in
## `CREW_CALLS` declaration order so the buttons never reshuffle.
func _crew_calls_for(card: Dictionary, loop: Dictionary) -> Array:
	if not EVENTS.admits_crew(card):
		return []
	if bool(loop.get("crew_called", false)):
		return []
	var out: Array = []
	for call_id in SCRIPTS.CREW_CALLS.keys():
		if _crew_call_available(str(call_id)):
			out.append(str(call_id))
	return out

func _crew_call_available(call_id: String) -> bool:
	var call: Dictionary = SCRIPTS.CREW_CALLS.get(call_id, {})
	if call.is_empty():
		return false
	var crew_id := str(call.get("crew_id", ""))
	if not gs.is_recruited(crew_id):
		return false
	if int((gs.crew_record(crew_id) as Dictionary).get("loyalty", 0)) <= 0:
		return false
	var entry: Variant = gs.crew_assignments.get(crew_id)
	if entry is Dictionary and int((entry as Dictionary).get("day", -1)) == int(gs.day):
		return false
	return true

## A call, resolved. Ends the encounter on the call's own authored resolution:
## Tone ends it won, Deshawn ends it surrendered with the stakes returned --
## which for a wander encounter means nothing is taken at all, because what was
## on the table was what the player was carrying.
##
## Costs a point of loyalty and whatever Heat the call authors. The loyalty
## cost is what stops this being a free out on every card that admits it: a
## crew member you call twice a week is a crew member who stops answering.
func _resolve_crew_call(chain: Dictionary, call_id: String) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var call: Dictionary = SCRIPTS.CREW_CALLS.get(call_id, {})
	var decision: Dictionary = chain.get("decision", {})
	var crew_id := str(call.get("crew_id", ""))

	var record: Dictionary = gs.crew_record(crew_id)
	record["loyalty"] = maxi(0, int(record.get("loyalty", 0))
		- int(call.get("loyalty_cost", 1)))
	gs.crew_records[crew_id] = record

	var heat_gain: float = 0.0
	if float(call.get("heat", 0.0)) > 0.0:
		heat_gain = LOOP.apply_heat(gs, gm, float(call["heat"]), "wander_encounter")

	var resolution := str(call.get("resolution", SCRIPTS.RESOLUTION_WON))
	if resolution == SCRIPTS.RESOLUTION_WON:
		gs.log_activity("Tone gets there before it goes anywhere. Nobody argues with that.", GREEN)
	else:
		gs.log_activity("Deshawn talks it down to nothing. Everybody walks.", GREEN)

	# The loop is over however it was called, so the call is stamped on it —
	# a reload mid-chain must not offer a call that has already been spent.
	var loop: Dictionary = LOOP.loop_of(chain)
	if not loop.is_empty():
		loop["crew_called"] = true
		LOOP.append_log(loop, "You made a call. It ended there.")
		decision["loop"] = loop

	var result := {
		"choice_id": call_id, "tier": "deterministic", "resolution": resolution,
		"arrested": false, "banned": false,
		"cash": 0, "goods": 0, "health": 0, "heat": heat_gain, "pressure": 0,
		"take_disposition": "keep",
	}
	decision["resolved_tier"] = "deterministic"
	decision["result"] = result
	chain["decision"] = decision
	_record_encounter_observation(chain, call_id, "deterministic")
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": "deterministic", "arrested": false}

# --- SQ-D8: every encounter writes an observation ----------------------------

## One observation per RESOLVED encounter, at the district it happened in,
## keyed by the road taken and the tier reached.
##
## Receipted on the chain's own cause (`boost.gd`'s `boost_caught:observation`
## precedent), so a save reloaded at the result stage and continued cannot
## write the same row twice. The receipt is claimed even when the row turns out
## empty: "this chain already had its chance to observe" is the fact being
## recorded, and re-asking on the next reload would be the bug.
##
## A crew call writes one too. Somebody watched Tone end it, and that is
## exactly the kind of thing a THREAT lens keeps.
func _record_encounter_observation(chain: Dictionary, choice_id: String,
		tier: String) -> void:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return
	var cause_id := str(chain.get("cause_id", ""))
	if cause_id.is_empty() or not engine.record_receipt(cause_id,
			"wander_encounter:observation"):
		return
	var card_id := str((chain.get("source", {}) as Dictionary).get("card_id", ""))
	var card: Dictionary = EVENTS.card_by_id(card_id)
	var row: Dictionary = EVENTS.observation_for(card, choice_id, tier)
	if row.is_empty():
		return
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure == null:
		return
	var npc := str(row.get("npc", EVENTS.OBSERVATION_NPC))
	row.erase("npc")
	# The district the chain OPENED in, not wherever the player is standing by
	# the time they answered — a chain can outlive a travel across a reload.
	row["location"] = str(chain.get("district_id", gs.current_district_id))
	exposure.record_observation(npc, row)

func _play_encounter(card: Dictionary, key: String) -> Dictionary:
	var engine: Object = gm.system("consequence") if gm != null else null
	var spec: Dictionary = card.get("encounter", {})
	if engine == null or spec.is_empty():
		return _play_ambient(card)

	var card_id := str(card["id"])
	var encounter_shape := str(spec["shape"])
	var attributes: Object = gm.system("attributes") if gm != null else null
	var choices: Array = (spec["choices"] as Array).duplicate()
	for extra in _conditional_choices(card_id):
		if not extra in choices:
			choices.append(extra)
	# SQ-D9. Appended after the card's own roads so the triad keeps its
	# authored vertical order and a call reads as the extra thing it is.
	var crew_calls: Array = _crew_calls_for(card, {})
	for call_id in crew_calls:
		if not call_id in choices:
			choices.append(str(call_id))
	var base_table: Dictionary = spec.get("base", {})
	if card_id == "wander_stopped_on_foot" and "stash_it" in choices:
		base_table = base_table.duplicate()
		base_table["stash_it"] = SCRIPTS.STASH_IT["base"]

	var shown: Dictionary = {}
	var inputs: Dictionary = {}
	for choice_id in choices:
		var base: Variant = base_table.get(str(choice_id))
		if base == null:
			continue
		var attribute := _attribute_for_choice(card_id, encounter_shape, str(choice_id))
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
			"card_id": card_id,
			"opponent": str(spec.get("opponent", "")),
			"shape": encounter_shape,
			"target_id": card_id,
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
			"allowed_choices": choices,
			# A crew call is deterministic by construction -- it does not roll,
			# it ends the encounter on the authored resolution -- so it joins
			# the card's own guaranteed out rather than needing odds.
			"deterministic_choices": (spec.get("deterministic", []) as Array)
				.duplicate() + crew_calls,
			"resolver_inputs": inputs,
			"shown_probabilities": shown,
			"arrest_risks": {},
		},
	})
	return {"ok": true, "kind": "encounter", "card_id": card_id,
		"opened": bool(opened.get("ok", false))}

func _attribute_for(shape: String) -> String:
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	if resolver == null:
		return "combat"
	var mapped: String = str(resolver.ACTION_ATTRIBUTE_MAP.get(shape, "combat"))
	return mapped if not mapped.is_empty() else "combat"

## A card whose payload is a fact.
##
## Every branch reports LIVE state through the read API that owns it, and writes
## nothing. That is what makes READ safe to author freely: a report cannot
## desync from the thing it reports, because it is the thing it reports.
##
## The build hides a great deal — which families a corner is hot for, whether
## Curtis's people have started looking, what a product fetches somewhere you
## are not standing — and had no surface that told the player any of it. This is
## that surface, and it is the reason Wander still has a job after the last job
## has been found.
func _play_read(card: Dictionary) -> Dictionary:
	gs.log_activity(str(card["line"]), MUTED)
	var told: Array = []
	match str(card.get("read", "")):
		"pressure":
			told = _read_pressure()
		"heat":
			told = _read_heat()
		"curtis":
			told = _read_curtis()
		"prices":
			told = _read_prices()
		"crew":
			told = _read_crew()
	if told.is_empty():
		# Nothing to say is still an hour spent. Never silent.
		gs.log_activity("Quiet, as far as you can tell.", MUTED)
	for line in told:
		gs.log_activity(str(line), BLUE)
	return {"ok": true, "kind": "read", "card_id": str(card["id"]), "told": told}

## Which families this corner is hot for. The band vocabulary is the engine's,
## and no screen shows it for the district you are standing in.
func _read_pressure() -> Array:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return []
	var rules: RefCounted = preload("res://data/consequence_rules.gd").new()
	var district := str(gs.current_district_id)
	var name := str(gs.current_district().get("name", "here"))
	var out: Array = []
	for family in rules.PRESSURE_FAMILIES:
		var band := str(engine.pressure_band(district, str(family)))
		if band == "QUIET":
			continue
		out.append("%s is %s about %s work." % [name, band.to_lower(), str(family)])
	if out.is_empty():
		out.append("%s is not thinking about you." % name)
	return out

## The Heat band, named. Batch 8 gave Heat four bands and nothing renders them.
func _read_heat() -> Array:
	var heat: Object = gm.system("heat") if gm != null else null
	if heat == null:
		return []
	var band := str(heat.band())
	match band:
		"BURNING":
			return ["You are getting looked at everywhere, and you can feel it."]
		"WATCHED":
			return ["People clock you before you clock them. That is new."]
		"NOTICED":
			return ["A couple of faces know yours now."]
	return ["Nobody has any reason to remember you."]

## Whether Curtis's people have started looking. Phase is persisted, drives the
## watcher encounters, and appears on no screen.
func _read_curtis() -> Array:
	var curtis: Node = Engine.get_main_loop().root.get_node_or_null("/root/Curtis")
	if curtis == null:
		return []
	match str(gs.curtis_phase):
		"approaching":
			return ["Somebody has been asking about you by name. They are not shy about it."]
		"watching":
			return ["The same faces keep turning up where you are. That is not weather."]
	return []

## What a product fetches somewhere you are not standing. The same read Word
## Around Town renders — what the walk buys is hearing it without the phone.
func _read_prices() -> Array:
	var phone: Object = gm.system("phone") if gm != null else null
	if phone == null:
		return []
	var routes: Array = phone.market_intel()
	var out: Array = []
	for route in routes:
		var line := str(phone.market_intel_line(route as Dictionary))
		if not line.is_empty():
			out.append(line)
		if out.size() >= 2:
			break
	return out

## Who on the crew is close to offering you something. `operation_summary`
## already answers it and nothing asks.
func _read_crew() -> Array:
	var ops: Object = gm.system("crew_operations") if gm != null else null
	if ops == null:
		return []
	var out: Array = []
	for operation_id in ops.operation_ids():
		var summary: Dictionary = ops.operation_summary(str(operation_id))
		if not bool(summary.get("discovered", false)):
			continue
		if bool(summary.get("assigned_today", false)):
			continue
		if not bool(summary.get("available", false)):
			continue
		out.append("%s has a day free, if you want it spent."
			% str(summary.get("crew_name", summary.get("crew_id", "Somebody"))).capitalize())
	return out

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
##
## STR-D3 (0.5.0 PR B): reads the card's own `effects` table generically
## instead of one tier→outcome match applied to every encounter alike — see
## `data/wander_events.gd`'s own header on that table for why. A card with no
## `effects` table (there is none left, but a future author could still omit
## one) falls back to the original PR-A-era match, so an incomplete card
## degrades rather than crashes.
func resolve_consequence(chain: Dictionary, choice_id: String) -> Dictionary:
	var engine: Object = gm.system("consequence") if gm != null else null
	if engine == null:
		return {"ok": false, "reason": "Nothing to answer to."}
	var source: Dictionary = chain.get("source", {})
	var card_id := str(source.get("card_id", ""))

	# SQ-D9: a crew call ends the encounter wherever it was placed — at the
	# door or mid-room — so it is answered before either of the branches below.
	if SCRIPTS.CREW_CALLS.has(choice_id):
		return _resolve_crew_call(chain, choice_id)

	# The room (STR-D5, rewritten to authored beats by SQ-D7): once
	# `decision.loop` exists, every further commit on this chain is a round of
	# it, never a fresh resolution — the same branch stickup.gd's own
	# `resolve_consequence` takes for its rooms.
	if LOOP.has_loop(chain):
		return _room_round(chain, choice_id)

	var decision: Dictionary = chain.get("decision", {})
	var encounter_shape := str(source.get("shape", "confrontation"))
	var deterministic: Array = decision.get("deterministic_choices", [])

	var tier := "deterministic"
	if not choice_id in deterministic:
		if choice_id == "stash_it":
			# Not the shared outcome-resolver seam: `OUTCOME_SHAPES` and
			# `ACTION_ATTRIBUTE_MAP` are oracle-parity tables, checked
			# byte-for-byte against fixtures recorded off the web build — a
			# shape this Godot-only port invents has no oracle entry and
			# never should. STASH_IT was authored as a two-outcome roll
			# anyway (`base`/`heat_on_failure`, no tiers at all), so it gets
			# its own direct chance roll instead of borrowing infrastructure
			# built for a table it cannot honestly belong to.
			tier = _stash_it_tier(chain, choice_id)
		else:
			var resolver: Object = gm.system("outcome_resolver") if gm != null else null
			var attributes: Object = gm.system("attributes") if gm != null else null
			var chance: float = float((decision.get("shown_probabilities", {}) as Dictionary)
				.get(choice_id, 0.5))
			var attribute := _attribute_for(encounter_shape)
			tier = "failure"
			if resolver != null:
				tier = str((resolver.resolve_action(encounter_shape, chance,
					int(attributes.effective(attribute)) if attributes != null else 1,
					gs.run_seed, "%s:%s" % [str(source.get("source_rng_key", "")), choice_id]
					) as Dictionary)["tier"])

	var effects: Dictionary = EVENTS.card_by_id(card_id).get("encounter", {}) \
		.get("effects", {}).get(choice_id, {}).get(tier, {})
	if effects.is_empty():
		return _resolve_legacy(chain, choice_id, tier)
	if bool(effects.get("escalate", false)):
		return _open_shakedown_room(chain, choice_id)

	var applied: Dictionary = LOOP.apply_effects(gs, gm, effects, choice_id, "wander_encounter")
	_feed_line_for(choice_id, tier)
	# SQ-D8. On RESOLUTION, which is here — an escalating road has not resolved
	# anything yet and the room writes its own when it finally ends.
	_record_encounter_observation(chain, choice_id, tier)

	var result := {
		"choice_id": choice_id,
		"tier": tier,
		"arrested": false,
		"banned": false,
		"cash": -int(applied["cash"]),
		"goods": -int(applied["goods"]),
		"health": -int(applied["health"]),
		"heat": float(applied["heat"]),
		"pressure": 0,
		"take_disposition": "lose" if (int(applied["goods"]) > 0 or int(applied["cash"]) > 0) else "keep",
	}
	decision["resolved_tier"] = tier
	decision["result"] = result
	chain["decision"] = decision
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": tier, "arrested": false}

## STASH_IT's own roll: `SCRIPTS.STASH_IT["base"]` (0.55) adjusted by
## Intelligence the same shape-independent way `outcome_resolver` already
## reads attributes, degrees-of-success excluded on purpose — the authored
## row names exactly two outcomes ("success hides... failure worsens it"),
## so this returns "clean" or "failure" and never "messy"/"catastrophic".
## `wander_stopped_on_foot`'s own `effects["stash_it"]` table only ever
## authors those two keys for exactly this reason.
func _stash_it_tier(chain: Dictionary, choice_id: String) -> String:
	var source: Dictionary = chain.get("source", {})
	var attributes: Object = gm.system("attributes") if gm != null else null
	var raw: int = int(attributes.effective("intelligence")) if attributes != null else 1
	# The same +/-0.10-per-point-off-center shape `chance_for`-style reads use
	# elsewhere would invent a curve STASH_IT's own header never asked for;
	# its one authored number is a flat base, nudged a little by attribute
	# rather than swung hard by it — a small, deliberate divergence from a
	# roll built for combat/charisma odds, named here rather than silently
	# reusing a formula tuned for a different kind of check.
	var chance: float = clampf(float(SCRIPTS.STASH_IT["base"])
		+ (float(raw) - 2.0) * 0.05, 0.10, 0.90)
	var roll: float = rng.seeded_random(gs.run_seed,
		"%s:%s" % [str(source.get("source_rng_key", "")), choice_id])
	return "clean" if roll < chance else "failure"

func _feed_line_for(choice_id: String, tier: String) -> void:
	match tier:
		"deterministic":
			gs.log_activity("You give it up and keep walking.", AMBER)
		"clean":
			gs.log_activity("It comes to nothing. They decide you are not worth it.", GREEN)
		"messy":
			gs.log_activity("It gets loud before it gets finished. You walk away sore.", AMBER)
		"failure":
			gs.log_activity("It does not go your way.", AMBER)
		_:
			gs.log_activity("It goes badly, and you are carrying less than you were.", AMBER)
	if choice_id == "stash_it" and tier in ["failure", "catastrophic"]:
		gs.log_activity("They watched you try. That is its own kind of trouble.", AMBER)

## PR-A-era fallback, unchanged, for a card that ships with no `effects`
## table of its own — see `resolve_consequence`'s own header.
func _resolve_legacy(chain: Dictionary, choice_id: String, tier: String) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var decision: Dictionary = chain.get("decision", {})
	var lost: int = 0
	var hurt: int = 0
	match tier:
		"deterministic":
			lost = LOOP.lose_cargo(gs, 1.0)
		"messy":
			hurt = 4
		"failure":
			lost = LOOP.lose_cargo(gs, 0.5)
		"clean":
			pass
		_:
			lost = LOOP.lose_cargo(gs, 1.0)
			hurt = 12
	if hurt > 0:
		var crew: Object = gm.system("crew") if gm != null else null
		if crew != null:
			hurt = int(crew.absorbed_damage(hurt))
		gs.health = clampi(gs.health - hurt, 0, gs.health_max)
	var result := {
		"choice_id": choice_id, "tier": tier, "arrested": false, "banned": false,
		"cash": 0, "goods": -lost, "health": -hurt, "heat": 0.0, "pressure": 0,
		"take_disposition": "lose" if lost > 0 else "keep",
	}
	decision["resolved_tier"] = tier
	decision["result"] = result
	chain["decision"] = decision
	_record_encounter_observation(chain, choice_id, tier)
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": tier, "arrested": false}

# --- the room (STR-D5, rewritten to authored beats by SQ-D7) -----------------
#
# 0.5.0 shipped this as one verb (KEEP FIGHTING) re-rolled at
# `base + (-0.10 x round)` with generic per-round log copy. That is a re-roll
# at worse odds, not a new situation, and the chassis's own round rule forbids
# it in as many words: "each stage is a NEW SITUATION... never a re-roll of the
# last one" (`data/confrontation_scripts.gd`'s header). Two of the four 0.5.0
# cards broke a rule the file that states it also owns; this closes one of
# them.
#
# What the room is now: an index into the card's authored `room.beats`. Each
# beat is its own situation with its own copy, its own offered roads, its own
# numbers and its own exit table -- exactly the shape `STICK_SCRIPTS` and
# `LIFT_BEATS` already have, which is why nothing new was invented to hold it.
# The chassis half is still `ConfrontationLoop`'s shared helpers (`loop_of`,
# `has_loop`, `append_log`, `burn`, `without_burned`, `present_round`) and the
# room is still not a system.
#
# What is deliberately NOT here: escalating odds as a mechanic of their own.
# The beats' own `base` tables already worsen (0.52 -> 0.38 on SWING), because
# a fight you are still in after two rounds IS going worse -- but that lives in
# the authored numbers where an author can read it, not in a constant applied
# to a number that never changed.

## The card's own room block, or {} for a card with no room.
func _room_of(card_id: String) -> Dictionary:
	return EVENTS.card_by_id(card_id).get("encounter", {}).get("room", {})

func _beat_at(card_id: String, index: int) -> Dictionary:
	var beats: Array = _room_of(card_id).get("beats", [])
	if beats.is_empty():
		return {}
	return beats[clampi(index, 0, beats.size() - 1)]

## Open the room on its FIRST authored beat. Reached from a card-level road
## whose authored effects row says `escalate: true` -- the fight did not end
## where it started.
func _open_shakedown_room(chain: Dictionary, choice_id: String) -> Dictionary:
	var source: Dictionary = chain.get("source", {})
	var card_id := str(source.get("card_id", ""))
	var room: Dictionary = _room_of(card_id)
	if room.is_empty():
		# A card that escalates without authoring a room is an authoring bug,
		# not a crash: resolve it as the worst ordinary outcome of the road
		# that escalated rather than leaving a chain with no next round.
		return _resolve_legacy(chain, choice_id, "failure")

	var loop: Dictionary = {
		"round": 1,
		"beat_index": 0,
		"log": [],
		"banked_health": 0,
		"burned": [],
		"crew_called": false,
		# The shared stakes-strip chrome renders STAGE/#LEFT/BANKED for ANY
		# non-empty loop. There is no cash riding on a fistfight, so BANKED
		# stays honestly $0; #LEFT counts BODIES here (the beats author it),
		# which is the chassis's own "they are people" promise.
		"stage": 0,
		"stage_count": int(room.get("cap", 3)),
		"left_label": str(room.get("left_label", "IN YOUR WAY")),
		"left": 0,
		"banked": 0,
	}
	gs.log_activity("They do not scatter. This is a fight now.", AMBER)
	return _present_beat(chain, loop, 0)

## Put one authored beat on the table. The ONE place a beat becomes a round,
## so the situation copy, the offered roads, the shown odds and the #LEFT chip
## cannot come from different beats.
func _present_beat(chain: Dictionary, loop: Dictionary, index: int) -> Dictionary:
	var source: Dictionary = chain.get("source", {})
	var card_id := str(source.get("card_id", ""))
	var beat: Dictionary = _beat_at(card_id, index)
	var cap: int = int(_room_of(card_id).get("cap", 3))

	loop["beat_index"] = index
	loop["stage"] = index
	loop["left"] = int(beat.get("left", 0))
	# The situation IS the beat. `consequence_engine.loop_summary()` hands this
	# to the sheet, which is what makes "each round is a new situation" a thing
	# the player reads rather than a thing the code believes.
	loop["beat"] = str(beat.get("beat", ""))
	LOOP.append_log(loop, str(beat.get("log", "")))

	# Burned verbs come off the offer; the deterministic out never burns, so it
	# survives this by construction rather than by exemption.
	var offered: Array = LOOP.without_burned(loop, beat.get("choices", []))
	for call_id in _crew_calls_for(EVENTS.card_by_id(card_id), loop):
		if not call_id in offered:
			offered.append(str(call_id))
	var deterministic: Array = (beat.get("deterministic", []) as Array).duplicate()
	for call_id in offered:
		if SCRIPTS.CREW_CALLS.has(call_id) and not call_id in deterministic:
			deterministic.append(call_id)

	var shown: Dictionary = {}
	for choice_id in offered:
		var base: Variant = (beat.get("base", {}) as Dictionary).get(str(choice_id))
		if base != null:
			shown[str(choice_id)] = float(base)

	LOOP.present_round(chain, loop, offered, deterministic, shown)
	# `present_round` bumps `decision.round`; the loop's own round counter
	# tracks beats, and the two are the same number here only because this room
	# advances exactly one beat per round. Kept separate anyway: a room that
	# ever repeats a beat would make them differ, and the commit receipt reads
	# the decision's.
	loop["round"] = index + 1
	var decision: Dictionary = chain.get("decision", {})
	decision["loop"] = loop
	chain["decision"] = decision
	gs.active_consequence = chain
	return {"ok": true, "tier": "escalated", "arrested": false,
		"beat": index, "cap": cap}

## One committed answer inside the room.
func _room_round(chain: Dictionary, choice_id: String) -> Dictionary:
	var source: Dictionary = chain.get("source", {})
	var card_id := str(source.get("card_id", ""))
	var loop: Dictionary = LOOP.loop_of(chain)
	var index: int = int(loop.get("beat_index", 0))
	var beat: Dictionary = _beat_at(card_id, index)
	var room: Dictionary = _room_of(card_id)
	var cap: int = int(room.get("cap", 3))
	var beats: Array = room.get("beats", [])

	var deterministic: Array = beat.get("deterministic", [])
	var tier := "deterministic"
	if not choice_id in deterministic:
		var resolver: Object = gm.system("outcome_resolver")
		var attributes: Object = gm.system("attributes")
		var role := str((beat.get("roles", {}) as Dictionary).get(choice_id, EVENTS.ROLE_FIGHT))
		# Role decides the roll, not the label: the fight road is Combat on the
		# `confrontation` shape, the run road is Combat on `escape` (mid-fight
		# the problem is the grip, not the map — the same call Stickup's own
		# fork made and recorded). Neither invents a shape the oracle does not
		# already carry (SQ-D11).
		var shape := "escape" if role == EVENTS.ROLE_RUN else "confrontation"
		var chance: float = float((beat.get("base", {}) as Dictionary).get(choice_id, 0.45))
		tier = "failure"
		if resolver != null:
			# Keyed on the BEAT rather than a round counter, varying component
			# first (house style), so two beats offering the same verb never
			# share a roll and a reload re-derives the same one.
			tier = str((resolver.resolve_action(shape, chance,
				int(attributes.effective("combat")) if attributes != null else 1,
				gs.run_seed, "%d:%s:%s:room" % [index,
					str(source.get("source_rng_key", "")), choice_id]
				) as Dictionary)["tier"])

	var effects: Dictionary = (beat.get("effects", {}) as Dictionary) \
		.get(choice_id, {}).get(tier, {})

	if bool(effects.get("escalate", false)):
		# The chassis's verb-burn rule (Q6): a rolled verb that resolves plain
		# `failure` is spent for the rest of the encounter. A `messy` that
		# escalates does not burn — the verb still works, the fight just did
		# not end.
		if tier == "failure":
			LOOP.burn(loop, choice_id)
			LOOP.append_log(loop, "%s does not work twice." % str(
				EVENTS.CHOICE_LABELS.get(choice_id, choice_id)).capitalize())
		loop["banked_health"] = int(loop.get("banked_health", 0)) \
			+ int(beat.get("banked", 0))
		var next_index: int = index + 1
		# The cap, and the end of the authored beats, are the same wall: a room
		# that runs out of situations to author is a room that is over.
		if next_index >= mini(cap, beats.size()):
			return _room_exit(chain, loop, "messy", choice_id,
				{"health": int(loop.get("banked_health", 0)) + 4,
					"cash_fraction": 0.5, "goods_fraction": 0.5},
				"Nobody wins outright. You both just stop.")
		return _present_beat(chain, loop, next_index)

	if effects.is_empty():
		# An unauthored (choice, tier) pair. Ends the room rather than silently
		# doing nothing, at the worst road's price, and the suite's own
		# authored-table arm is what stops this ever being reached in shipped
		# content.
		effects = {"health": int(loop.get("banked_health", 0)) + 10,
			"cash_fraction": 1.0, "goods_fraction": 1.0}

	var costed: Dictionary = effects.duplicate()
	costed["health"] = int(costed.get("health", 0)) + int(loop.get("banked_health", 0))
	return _room_exit(chain, loop, tier, choice_id, costed,
		_room_exit_line(tier, choice_id))

func _room_exit_line(tier: String, choice_id: String) -> String:
	if tier == "deterministic":
		return "You give it up mid-fight. Whatever was in hand is gone."
	match tier:
		"clean":
			return "It finally breaks your way. You keep what you had left."
		"messy":
			return "You get out of it. Not clean, and not for free."
		"failure":
			return "It does not break your way."
	return "It goes badly, all the way through."

## The room's exit, on every road. Cash and cargo route through
## `LOOP.apply_effects` — a room is still a wander encounter underneath, and
## STR-D3's rule does not stop applying because it took three rounds.
func _room_exit(chain: Dictionary, loop: Dictionary, exit_tier: String,
		choice_id: String, effects: Dictionary, line: String) -> Dictionary:
	var engine: Object = gm.system("consequence")
	var decision: Dictionary = chain.get("decision", {})
	gs.log_activity(line, GREEN if exit_tier == "clean" else AMBER)
	LOOP.append_log(loop, line)

	var applied: Dictionary = LOOP.apply_effects(gs, gm, effects, choice_id,
		"wander_encounter")
	var result := {
		"choice_id": choice_id, "tier": exit_tier, "arrested": false, "banned": false,
		"cash": -int(applied["cash"]), "goods": -int(applied["goods"]),
		"health": -int(applied["health"]), "heat": float(applied["heat"]), "pressure": 0,
		"take_disposition": "lose" if (int(applied["goods"]) > 0 or int(applied["cash"]) > 0) else "keep",
		"room_log": (loop.get("log", []) as Array).duplicate(),
	}
	decision["resolved_tier"] = exit_tier
	decision["result"] = result
	decision["loop"] = loop
	chain["decision"] = decision
	_record_encounter_observation(chain, choice_id, exit_tier)
	engine.advance_stage(engine.STAGE_RESULT)
	return {"ok": true, "tier": exit_tier, "arrested": false}

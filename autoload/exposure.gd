extends Node
## Exposure — what each person knows about you, and what they make of it.
##
## Port of src/exposure/engine.js plus the data in src/data/observations.js,
## npc-lenses.js, propagation.js and disposition-bands.js.
##
## The idea in one paragraph: a typed observation is the ONLY thing an NPC ever
## knows about the player. Observations land in a per-NPC ledger keyed by
## category + event + location, so the same thing seen twice increments a count
## instead of growing the ledger. A lens turns that ledger into one number by
## weighting each row, and every character weights the same evidence differently.
## Mina reads discretion, Dre reads whether you follow through, Curtis reads
## whether you are a problem.
##
## Two things about this that are easy to get wrong, both deliberate in canon:
##
##   THREAT is inverted. For a rival a HIGH score means "no problem to me", so
##   everything that makes you worth noticing drives Curtis's number DOWN. He
##   reads Neutral as invisible and Hostile as confrontation.
##
##   `territory` weighs zero in all four archetypes. Every other category is
##   evidence about the player; a warning that Curtis's people are working Motel
##   Row is evidence about *Curtis*. It rides the neighborhood channel because
##   that is how the player would hear it, and it must never move a number —
##   otherwise being warned a lot would quietly make Mina like you.
##
## Not ported yet, and named so the gap is legible:
##   - presence gating (NPC_PRESENCE_SLOTS / NPC_PRESENCE_AREAS): whether an NPC
##     was physically somewhere to witness a thing. Everything is deliverable.
##   - slot-level presence gating for the Curtis filter's siblings. The filter
##     itself IS ported as of FS-001.2 (see clears_curtis_filter).
##   - slot-level delivery. The queue works in whole days, which is the
##     granularity the rest of this build runs on.

# --- vocabulary ------------------------------------------------------------

const CATEGORIES := [
	"presence", "honesty", "violence", "financial", "heat_exposure", "loyalty",
	"betrayal", "discretion", "growth", "submission", "defiance", "territory",
]

## Canon MAX_LEDGER_ROWS. The key space is bounded already; this guards against
## a caller inventing unique context strings in a loop.
const MAX_LEDGER_ROWS := 120
## Canon MAX_EFFECTIVE_COUNT — the ceiling on the logarithmic curve.
const MAX_EFFECTIVE_COUNT := 4.0
## Canon ESCALATING_EVENT. Negative weight plus linear growth means each
## additional miss hurts more than the last.
const ESCALATING_EVENT := "missed_obligation"

# --- lenses ----------------------------------------------------------------

const CIVILIAN := {
	"presence": 1.0, "honesty": 1.5, "violence": -3.0, "financial": 1.5,
	"heat_exposure": -2.5, "loyalty": 1.5, "betrayal": -4.0, "discretion": 1.0,
	"growth": 1.0, "submission": 0.5, "defiance": -1.0, "territory": 0.0,
}
const STREET := {
	"presence": 0.6, "honesty": 1.0, "violence": -0.5, "financial": 2.0,
	"heat_exposure": -1.0, "loyalty": 2.0, "betrayal": -4.0, "discretion": 1.0,
	"growth": 1.5, "submission": 0.0, "defiance": -0.5, "territory": 0.0,
}
const ROMANTIC := {
	"presence": 1.5, "honesty": 2.5, "violence": -2.0, "financial": 0.3,
	"heat_exposure": -1.5, "loyalty": 2.0, "betrayal": -6.0, "discretion": 2.0,
	"growth": 1.0, "submission": 0.0, "defiance": -0.5, "territory": 0.0,
}
## Inverted on purpose — see the header.
const THREAT := {
	"presence": -0.3, "honesty": 0.5, "violence": -2.5, "financial": -1.5,
	"heat_exposure": -1.5, "loyalty": 1.0, "betrayal": -3.0, "discretion": 1.5,
	"growth": -2.0, "submission": 2.0, "defiance": -2.5, "territory": 0.0,
}

## Events that mean "you cost me something", priced once for everybody rather
## than inherited from their category. Canon is explicit that this is not a
## generic "negative things go in the defiance bucket" rule — STREET scores
## `defiance` POSITIVELY because Dre respects nerve, so walking a debt to him has
## to be priced as an event or it would score as a credit.
##
## Missing this is a real trap: `missed_obligation` is category `financial`,
## which CIVILIAN weights at +1.5, so without this table missing rent made
## Yalonda like you more, and the escalating count made it worse the longer you
## went without paying.
const SHARED_EVENT_WEIGHTS := {
	"missed_obligation": -2.5,
	"let_them_down": -2.0,
	"walked_a_debt": -3.0,
	"botched_mission": -2.0,
	"refused_work": -1.5,
}

## Archetypes whose score runs backwards. Content gating for these reads "at
## most Neutral" rather than "at least Warm".
const INVERTED_ARCHETYPES := ["THREAT"]

## An NPC picks an archetype and overrides a handful of entries. That is the
## whole authoring cost of a new character, which is the point.
const NPC_LENSES := {
	"yalonda": {"archetype": "CIVILIAN", "weights": {"heat_exposure": -3.0, "presence": 1.5}, "event_weights": {"rent_paid": 3.0}, "source_multipliers": {}},
	"juan": {"archetype": "CIVILIAN", "weights": {"violence": -1.0, "growth": 2.0, "discretion": 1.5}, "event_weights": {}, "source_multipliers": {}},
	"mina": {"archetype": "ROMANTIC", "weights": {"violence": -4.0, "discretion": 4.0}, "event_weights": {}, "source_multipliers": {"network": 2.0}},
	"curtis": {"archetype": "THREAT", "weights": {"growth": -3.0}, "event_weights": {}, "source_multipliers": {}},
	"dre": {"archetype": "STREET", "weights": {"financial": 4.0, "honesty": 2.0}, "event_weights": {}, "source_multipliers": {}},
}

# --- channels --------------------------------------------------------------

## `days` is how long the news takes to arrive. Canon also carries slot-level
## timing and presence rules; see the header for what is not ported.
const CHANNELS := {
	"direct": {"days": 0, "source": "witnessed"},
	"household": {"days": 0, "source": "household"},
	"neighborhood": {"days": 1, "source": "neighborhood"},
	"network": {"days": 1, "source": "network"},
	"reputation": {"days": 7, "source": "reputation"},
}

## Who listens on what. Yalonda and Juan share a roof with the player, so the
## household channel is theirs alone. Curtis is the only one wired to the
## network; Mina is on it because the block talks to her across a counter.
const NPC_CHANNELS := {
	"yalonda": ["direct", "household", "neighborhood"],
	"juan": ["direct", "household", "neighborhood"],
	"mina": ["direct", "neighborhood", "network"],
	"curtis": ["direct", "network", "reputation"],
	"dre": ["direct", "network"],
}

## Canon CURTIS_NETWORK_CATEGORIES. **Curtis hears through a filter, not a
## firehose.** Only these categories clear it; anything else stays below his
## radar no matter how often it happens, and the whole design of his attention
## depends on that staying true. Territory claims and named reports arrive as
## `defiance`, which is why that one is on the list.
const CURTIS_NETWORK_CATEGORIES := ["violence", "defiance", "growth"]

## Canon CURTIS_VOLUME_THRESHOLD. Volume, not category, is the other way onto
## his radar: a `financial` observation reaches him only when it was a big
## enough day to be worth a phone call.
const CURTIS_VOLUME_THRESHOLD := 200.0

## Canon HEAT_CHANNEL_THRESHOLDS — carrying enough heat becomes news by itself.
const HEAT_CHANNEL_THRESHOLDS := [
	{"above": 12.0, "channel": "network"},
	{"above": 10.0, "channel": "neighborhood"},
	{"above": 8.0, "channel": "household"},
]

# --- bands -----------------------------------------------------------------

const BAND_FLOORS := [
	{"id": "bonded", "floor": 9.0},
	{"id": "trusted", "floor": 6.0},
	{"id": "warm", "floor": 3.0},
	{"id": "neutral", "floor": 0.0},
	{"id": "cold", "floor": -5.0},
]
const BAND_LABELS := {
	"bonded": "BONDED", "trusted": "TRUSTED", "warm": "WARM",
	"neutral": "NEUTRAL", "cold": "COLD", "hostile": "HOSTILE",
}

var gs: Node
var game_manager: Node

func _ready() -> void:
	gs = get_node("/root/GameState")
	game_manager = get_node("/root/GameManager")
	# NOT connected to `day_crossed`. TI-003 §2 and §9 put this rollover at a
	# declared position in DayLifecycle's post-increment sequence — specifically
	# AFTER the Financial Pressure fold, so the morning's Heat broadcast is
	# measured against the Heat the fold just applied (regression #26). A signal
	# connection cannot express "after".

func _require_dispatch(method_name: String) -> bool:
	var active: bool = game_manager != null and game_manager.is_dispatching()
	if not active:
		push_warning("Exposure.%s() refused outside GameManager.dispatch()." % method_name)
	return active

# --- recording -------------------------------------------------------------

## Public read of one NPC's ledger. Canon's `ledgerOf` (src/exposure/engine.js),
## which the attributes system calls directly to derive Street Identity — the
## same reach-across canon makes, for the same reason: identity is a read of
## what the neighborhood has actually seen.
func ledger_of(npc_id: String) -> Array:
	return gs.npc_ledgers.get(npc_id, [])

func npc_ids() -> Array:
	return NPC_LENSES.keys()

## Write-side accessor. Reads use ledger_of() so asking for disposition or
## rendering People cannot create persistent empty ledgers as a side effect.
func _ledger_for_write(npc_id: String) -> Array:
	if not gs.npc_ledgers.has(npc_id):
		gs.npc_ledgers[npc_id] = []
	return gs.npc_ledgers[npc_id]

func _key(spec: Dictionary) -> String:
	return "%s|%s|%s" % [str(spec.get("type", "")), str(spec.get("event", "")), str(spec.get("location", ""))]

## Something this NPC learns first-hand, right now. No gating: if the code says
## Mina was told, Mina was told.
func record_observation(npc_id: String, spec: Dictionary) -> void:
	if not _require_dispatch("record_observation"):
		return
	if not NPC_LENSES.has(npc_id):
		return
	var type_name: String = str(spec.get("type", ""))
	if not type_name in CATEGORIES:
		push_warning("Exposure: unknown observation category '%s'" % type_name)
		return
	var ledger: Array = _ledger_for_write(npc_id)
	var key := _key(spec)
	for row in ledger:
		if str(row["key"]) == key:
			row["count"] = int(row["count"]) + int(spec.get("count", 1))
			return
	if ledger.size() >= MAX_LEDGER_ROWS:
		return
	ledger.append({
		"key": key,
		"type": type_name,
		"event": str(spec.get("event", "")),
		"location": str(spec.get("location", "")),
		"source": str(spec.get("source", "witnessed")),
		"count": int(spec.get("count", 1)),
		"day": gs.day,
	})

## Something the world learns. Routed to whoever listens on that channel, and
## delayed by however long the channel takes to carry it.
##
## Returns the NPCs it reached — including ones it only queued for. Canon's
## broadcastTracked needs that to decide whether a thing genuinely landed on
## Curtis, which is the only way ambient awareness rises.
func broadcast_observation(spec: Dictionary) -> Array:
	if not _require_dispatch("broadcast_observation"):
		return []
	var reached: Array = []
	var channel: String = str(spec.get("channel", "neighborhood"))
	if not CHANNELS.has(channel):
		return reached
	var def: Dictionary = CHANNELS[channel]
	var delay: int = int(def["days"])
	for npc_id in NPC_LENSES.keys():
		if not channel in NPC_CHANNELS.get(npc_id, []):
			continue
		# Canon `receives()`: Curtis's network ear is filtered. Everything else
		# about who hears what is channel membership; this is the one per-NPC
		# gate, and it has to sit inside the loop because it is about Curtis
		# specifically rather than about the observation.
		if npc_id == "curtis" and channel == "network" and not clears_curtis_filter(spec):
			continue
		var delivered := spec.duplicate()
		delivered["source"] = str(def["source"])
		reached.append(str(npc_id))
		if delay <= 0:
			record_observation(str(npc_id), delivered)
		else:
			gs.observation_queue.append({
				"npc_id": str(npc_id),
				"spec": delivered,
				"deliver_on_day": gs.day + delay,
			})
	return reached

## Canon clearsCurtisFilter — his sensitivity threshold. True when an
## observation is loud enough to reach him through the network at all.
##
## The `financial` arm is the one that matters for money surfaces: a big 907List
## day is exactly how a flip is meant to reach him, and a $40 space heater is
## exactly how it is meant not to. Absolute value on purpose — canon uses
## `Math.abs`, so a large LOSS is as audible as a large gain.
##
## Ported in FS-001.2 because the completed-flip financial observation is
## meaningless without it: unfiltered, every trivial flip would raise his
## awareness through the network channel, which is the opposite of canon's
## design for his attention.
func clears_curtis_filter(spec: Dictionary) -> bool:
	var type_name: String = str(spec.get("type", ""))
	if type_name in CURTIS_NETWORK_CATEGORIES:
		return true
	if type_name == "financial":
		return absf(float(spec.get("value", 0.0))) >= CURTIS_VOLUME_THRESHOLD
	return false

# --- scoring ---------------------------------------------------------------

## Canon effectiveCount. Logarithmic by default — the first three repetitions
## carry the weight and by eight the behaviour is ambient. Two opt out, and they
## are not the same rule twice: betrayal never fades, and a missed obligation
## escalates because its weight is negative and linear growth makes each miss
## hurt more than the last. Neither is clamped; that is the point of both.
func effective_count(row: Dictionary) -> float:
	var count: float = maxf(1.0, float(row.get("count", 1)))
	if str(row.get("type", "")) == "betrayal":
		return count
	if str(row.get("event", "")) == ESCALATING_EVENT:
		return count
	return minf(MAX_EFFECTIVE_COUNT, log(count + 1.0) / log(2.0))

func _lens(npc_id: String) -> Dictionary:
	var spec: Dictionary = NPC_LENSES.get(npc_id, {})
	if spec.is_empty():
		return {}
	var base: Dictionary = {"CIVILIAN": CIVILIAN, "STREET": STREET, "ROMANTIC": ROMANTIC, "THREAT": THREAT}.get(str(spec["archetype"]), CIVILIAN)
	var weights: Dictionary = base.duplicate()
	for k in spec.get("weights", {}).keys():
		weights[k] = spec["weights"][k]
	return {
		"weights": weights,
		"event_weights": spec.get("event_weights", {}),
		"source_multipliers": spec.get("source_multipliers", {}),
	}

## Canon rowWeight: base x sourceMultiplier x effectiveCount.
##
## Resolution order for the base, most specific first:
##   1. this NPC's own event weight  (Yalonda prices rent_paid at 3.0)
##   2. the shared event weight      (missed_obligation is -2.5 for everyone)
##   3. the category weight
func _row_weight(lens: Dictionary, row: Dictionary) -> float:
	var event: String = str(row.get("event", ""))
	var base: float
	if not event.is_empty() and lens["event_weights"].has(event):
		base = float(lens["event_weights"][event])
	elif not event.is_empty() and SHARED_EVENT_WEIGHTS.has(event):
		base = float(SHARED_EVENT_WEIGHTS[event])
	else:
		base = float(lens["weights"].get(str(row.get("type", "")), 0.0))
	var mult: float = float(lens["source_multipliers"].get(str(row.get("source", "")), 1.0))
	return base * mult * effective_count(row)

## Rounded to two places so a float tail can never flip a band boundary
## differently on two machines. Band floors are whole numbers.
func disposition(npc_id: String) -> float:
	var lens: Dictionary = _lens(npc_id)
	if lens.is_empty():
		return 0.0
	var score: float = 0.0
	for row in ledger_of(npc_id):
		score += _row_weight(lens, row)
	return snappedf(score, 0.01)

func band_for(score: float) -> String:
	for b in BAND_FLOORS:
		if score >= float(b["floor"]):
			return str(b["id"])
	return "hostile"

func band_of(npc_id: String) -> String:
	return band_for(disposition(npc_id))

## True when this NPC's score runs backwards, so callers can flip their reading.
func is_inverted(npc_id: String) -> bool:
	var spec: Dictionary = NPC_LENSES.get(npc_id, {})
	return str(spec.get("archetype", "")) in INVERTED_ARCHETYPES

func band_label(npc_id: String) -> String:
	return str(BAND_LABELS.get(band_of(npc_id), "NEUTRAL"))

## Every NPC with a lens, with their current read. For the contacts screen.
func everyone() -> Array:
	var out: Array = []
	for npc_id in NPC_LENSES.keys():
		var score: float = disposition(str(npc_id))
		out.append({
			"id": str(npc_id),
			"score": score,
			"band": band_for(score),
			"label": str(BAND_LABELS.get(band_for(score), "NEUTRAL")),
			"rows": ledger_of(str(npc_id)).size(),
		})
	return out

# --- the day tick ----------------------------------------------------------

## Canon propagateHeat: carrying enough heat is news by itself, and how far it
## travels depends on how much.
func propagate_heat() -> void:
	# Guarded even though every write it makes goes through
	# `broadcast_observation`, which is guarded too. Two reasons: the warning
	# names the function the caller actually called, which is the one they have
	# to move; and a future edit that writes a ledger row directly from here
	# would otherwise slip past a guard that only ever covered the old shape.
	if not _require_dispatch("propagate_heat"):
		return
	for t in HEAT_CHANNEL_THRESHOLDS:
		if gs.heat > float(t["above"]):
			broadcast_observation({
				"type": "heat_exposure",
				"event": "carrying_heat",
				"channel": str(t["channel"]),
			})
			return

## The day tick, called by name from `DayLifecycle.ROLLOVER_ORDER`.
##
## Propagate first, then deliver: a queued observation arriving this morning is
## news from a previous day, and letting it land before the Heat broadcast would
## reorder two things the player experiences as one morning.
func rollover() -> void:
	# `gs.observation_queue` is rewritten below — a direct persisted write, and
	# the last one in this file that was not covered.
	if not _require_dispatch("rollover"):
		return
	if gs.game_over:
		return
	propagate_heat()
	var still_waiting: Array = []
	for item in gs.observation_queue:
		if gs.day >= int(item["deliver_on_day"]):
			record_observation(str(item["npc_id"]), item["spec"])
		else:
			still_waiting.append(item)
	gs.observation_queue = still_waiting

extends Node
## Curtis — his people, and how hard they are looking.
##
## Port of src/data/curtis-awareness.js plus raiseCurtisAwareness /
## refreshAwarenessPhase / broadcastTracked / maybeWatcherEncounter and the
## quiet-streak decay in game-core.js.
##
## **This is not Curtis's disposition.** Three different things track Curtis and
## canon keeps them apart on purpose:
##   - his ledger in Exposure is what he FEELS about you (THREAT lens, inverted)
##   - awareness here is how hard his PEOPLE are looking
##   - district awareness (not ported) is police difficulty
##
## Before Curtis appears as a character his people exist as unnamed watchers the
## player bumps into around Spenard. Awareness rises only when something
## genuinely reaches him over the network channel — see `broadcast_tracked`.
## That is the join between the exposure substrate and this.
##
## **Phase floors ratchet.** Once a phase is reached the level can decay but
## never below that phase's threshold: once Curtis notices you, he does not
## fully forget.
##
## Not ported: The Nile staying dark (nothing inside it raises awareness, which
## matches the propagation rule that its broadcasts never ride network) — there
## is no Nile yet. Also the market-transaction bump and Goodie's warning line.

## Phase floors, highest first.
const PHASES := [
	{"id": "approaching", "at": 11},
	{"id": "watching", "at": 7},
	{"id": "ambient", "at": 3},
	{"id": "invisible", "at": 0},
]

const PHASE_LABELS := {
	"invisible": "INVISIBLE", "ambient": "AMBIENT",
	"watching": "WATCHING", "approaching": "APPROACHING",
}

## Ambient watcher copy per phase. UI texture, NOT observations — nothing here
## touches a ledger. Cycled without repeating a line within the last three.
const WATCHER_LINES := {
	"ambient": [
		"A kid at the coffee shop watches you from the window. When you look back, he's on his phone.",
		"Same sedan you saw yesterday. Different driver. Engine running.",
		"The guy at the laundromat isn't doing laundry. He's been here twenty minutes with no basket.",
		"Someone at Night Owl asked Cal about you. Cal told you later. Didn't say who.",
	],
	"watching": [
		"A man you don't know nodded at you outside The Nile. Like he expected you.",
		"Word Around Town: 'somebody with money is paying for information about new faces.'",
		"Your phone buzzed. Unknown number, no message. Then a text from Juan: 'Be careful out there.'",
		"The Night Owl regular who asks too many questions wasn't there tonight. First time in weeks.",
	],
	"approaching": [
		"A woman you've never met called you by name outside the apartment building. Smiled and walked away.",
		"Goodie pulled you aside: \"Curtis knows your name. That's not the same as knowing you, but it's close.\"",
		"A man in a black Carhartt was standing outside the gym when you left. He didn't follow you. He didn't need to.",
	],
}

## One Word Around Town message per phase reached, ever. Not daily spam.
const PHASE_MESSAGES := {
	"watching": "Word Around Town: somebody's been asking about you at Night Owl. Paying for answers, not gossip.",
	"approaching": "Word Around Town: Curtis's people stopped asking questions about you. That means they think they have the answers.",
}

const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node
var rng: Node
var exposure: Node
var game_manager: Node

func _ready() -> void:
	gs = get_node("/root/GameState")
	rng = get_node("/root/RngManager")
	exposure = get_node("/root/Exposure")
	game_manager = get_node("/root/GameManager")
	# NOT connected to `day_crossed` — see `rollover()` below and TI-003 §2.

func _require_dispatch(method_name: String) -> bool:
	var active: bool = game_manager != null and game_manager.is_dispatching()
	assert(active, "Curtis.%s() must be called from GameManager.dispatch()." % method_name)
	return active

# --- phase -----------------------------------------------------------------

func phase_for_level(level: int) -> String:
	for p in PHASES:
		if level >= int(p["at"]):
			return str(p["id"])
	return "invisible"

func phase_floor(phase_id: String) -> int:
	for p in PHASES:
		if str(p["id"]) == phase_id:
			return int(p["at"])
	return 0

func phase_label() -> String:
	return str(PHASE_LABELS.get(gs.curtis_phase, "INVISIBLE"))

func _refresh_phase() -> void:
	var phase := phase_for_level(gs.curtis_awareness)
	if phase == gs.curtis_phase:
		return
	gs.curtis_phase = phase
	var floor_at := phase_floor(phase)
	if floor_at > gs.curtis_floor:
		gs.curtis_floor = floor_at
	# One message per phase reached, ever.
	if PHASE_MESSAGES.has(phase) and not phase in gs.curtis_phase_messages_sent:
		gs.curtis_phase_messages_sent.append(phase)
		gs.log_activity(str(PHASE_MESSAGES[phase]), RED)

func raise_awareness(amount: int) -> void:
	if not _require_dispatch("raise_awareness"):
		return
	if amount <= 0:
		return
	gs.curtis_awareness = clampi(gs.curtis_awareness + amount, 0, gs.AWARENESS_MAX)
	_refresh_phase()

## Something loud happened today. Canon tracks this to decide whether the quiet
## streak resets, which is what gates decay.
func mark_criminal_activity() -> void:
	if not _require_dispatch("mark_criminal_activity"):
		return
	gs.curtis_last_criminal_day = gs.day

# --- the join with Exposure ------------------------------------------------

## Canon broadcastTracked: broadcast, and when it GENUINELY lands on Curtis
## through the network channel, count it against ambient visibility. A thing
## Curtis never hears about does not make his people look harder.
func broadcast_tracked(spec: Dictionary) -> Array:
	if not _require_dispatch("broadcast_tracked"):
		return []
	var reached: Array = exposure.broadcast_observation(spec)
	if str(spec.get("channel", "")) == "network" and "curtis" in reached:
		raise_awareness(1)
	return reached

# --- watchers --------------------------------------------------------------

## Canon watcherChance: 0.3 + level * 0.04, capped at 0.7.
func watcher_chance() -> float:
	return minf(0.7, 0.3 + float(gs.curtis_awareness) * 0.04)

## Ambient, non-blocking flavour while moving through Spenard once his people
## are looking. At most one a day.
##
## Rolled off the hash rather than a stream, so a run that never qualifies keeps
## its exact event sequence. These are texture, not observations: no ledger row,
## nothing to resolve.
func maybe_watcher_encounter(reason: String) -> String:
	if gs.curtis_phase == "invisible":
		return ""
	# Watchers appear during ordinary movement, not during the crime itself,
	# which is what makes them unsettling.
	if not reason in ["travel", "wander"]:
		return ""
	if gs.current_district_id != "north_star_lot":
		return ""
	if gs.curtis_last_watcher_day == gs.day:
		return ""
	var roll: float = rng.seeded_unit_10k(gs.run_seed, "curtis:watcher:%d:%d" % [gs.day, gs.time_slots_today])
	if roll >= watcher_chance():
		return ""

	var pool: Array = WATCHER_LINES.get(gs.curtis_phase, WATCHER_LINES["ambient"])
	var fresh: Array = []
	for line in pool:
		if not line in gs.curtis_recent_watcher_lines:
			fresh.append(line)
	var candidates: Array = fresh if not fresh.is_empty() else pool
	var idx: int = rng.string_hash("%s:curtis:watcher:line:%d" % [gs.run_seed, gs.curtis_watchers_seen]) % candidates.size()
	var line: String = str(candidates[idx])

	gs.curtis_watchers_seen += 1
	gs.curtis_last_watcher_day = gs.day
	gs.curtis_recent_watcher_lines.append(line)
	if gs.curtis_recent_watcher_lines.size() > 3:
		gs.curtis_recent_watcher_lines = gs.curtis_recent_watcher_lines.slice(-3)
	gs.log_activity(line, AMBER)
	return line

# --- decay -----------------------------------------------------------------

## Curtis's people lose interest slowly. A day with no criminal activity extends
## the quiet streak; from the second consecutive quiet day on, awareness bleeds
## one point a day — but never below the floor of a phase already reached.
## Quiet-streak recovery and the phase refresh, called by name from
## `DayLifecycle.ROLLOVER_ORDER` rather than off the `day_crossed` signal.
##
## Runs last in that sequence, after Exposure has delivered whatever the night
## carried — so a phase refreshed this morning is refreshed against the awareness
## the morning actually produced.
func rollover() -> void:
	if gs.game_over:
		return
	var ended_day: int = gs.day - 1
	if gs.curtis_last_criminal_day == ended_day:
		gs.curtis_quiet_streak = 0
		return
	gs.curtis_quiet_streak += 1
	if gs.curtis_quiet_streak >= 2 and gs.curtis_awareness > gs.curtis_floor:
		gs.curtis_awareness = maxi(gs.curtis_floor, gs.curtis_awareness - 1)
		_refresh_phase()

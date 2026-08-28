extends RefCounted
## Confrontation scripts — the authored half of the resolution loop.
##
## "Squared Up" is this feature's DESIGN name and appears nowhere the player can
## read (Q8 of the build brief, resolved): the code name is `confrontation`, the
## sheet header is the opponent, and the activity log says what happened in
## plain words. Same rule as the outcome tiers — internal vocabulary stays
## internal.
##
## ## What a script is
##
## The loop chassis (rounds, burned verbs, one guaranteed out per round, the
## five resolution states) is machinery and lives in `systems/`. A SCRIPT is
## everything authored about one confrontation: who is in front of you, what
## each stage IS, which verbs it offers, and what the numbers around those
## verbs are. The chassis never forks per path; the scripts do. This file is
## every script, pure data plus lookups, in the `consequence_rules.gd` shape.
##
## ## The round rule, which every beat below obeys
##
## Each stage is a NEW SITUATION — the till then the drawer, the table then the
## pot then the door — never a re-roll of the last one. A script whose stages
## read the same is a script with too many stages. That is why tier-1 stickup
## targets have NO script at all: a mark is one beat, and one beat is a single
## roll, which the surface already does perfectly well without a sheet.
##
## ## Stickup: what is wired this slice
##
## Tier 2 and tier 3 stick targets open the loop (the robbery IS the loop —
## the REPLACE ruling). Tier 1 deliberately keeps the shipped single-roll path
## byte-for-byte: its parity probe (`washgo_regular`) stays green untouched,
## and the daily texture stays fast. The take is rolled ONCE at entry on the
## same `:take` key the single roll has always used, then partitioned across
## stages — the band is the budget, so the loop adds agency and variance,
## never income. Full-commit expected value equals the authored band; leaving
## early lands under it.
##
## ## Authored and NOT yet wired (each named so the gap is legible)
##
##   - LIFT_BEATS / LIFT_ESCALATION / BRIBE — the Lift's caught-loop and its
##     bribe valve. Wiring touches the boost_caught chain, whose per-tier flow
##     is pinned by the parity suite, so it ships as its own slice with its own
##     test updates rather than riding this one.
##   - MARKET_SCRIPTS and STASH_IT — corner scripts; triggers live in the sell
##     path and Post Up.
##   - MEETUP_SCRIPT — the one 907List entry, on the catastrophic meetup tier.
##   - TIP_MODIFIERS — read defensively (see `tip_modifiers_for` in
##     `systems/confrontation_loop.gd`); rows arrive when the phone-tip system
##     lands and modify entry parameters only, never exit tables.
##   - CREW_CALLS — Tone/Deshawn as loop actions. No stickup script admits
##     them (Tone does not start things — his own bio's terms), so nothing
##     here consumes the rules yet.

# --- resolution states -------------------------------------------------------
#
# The five, fixed across every script. Exit tables translate these into path
# consequences; nothing player-facing ever prints them.

const RESOLUTION_WON := "won"
const RESOLUTION_ESCAPED := "escaped"
const RESOLUTION_BEATEN := "beaten"
const RESOLUTION_SURRENDERED := "surrendered"
const RESOLUTION_BRIBED := "bribed"

# --- verb removal (Q6, resolved) ---------------------------------------------
#
# A rolled verb that resolves plain `failure` is BURNED for the rest of the
# encounter — this encounter only, nothing persists past the sheet. It applies
# on every path. Deterministic outs never burn, and crew calls are once-per-loop
# by their own rule, separate from burning (calling Tone does not consume SWING;
# he is not your swing). Success tiers and `catastrophic` both exit the loop,
# so burning only ever happens on the tier that escalates. When every rolled
# verb is burned, the round offers only the outs — the loop never auto-resolves;
# `beaten` is reached through catastrophic or the round cap, never by fiat.

const VERB_BURN_SCOPE := "encounter"
const ROUND_CAP := 3

# --- stickup rooms -----------------------------------------------------------

## Stage chance deltas against `chance_for()`, applied INSIDE its existing
## [0.15, 0.90] clamp: the first stage rides surprise, the last one fights the
## room organising itself against you. Resistance 3 starts that decay a stage
## early (`stage_mods` override on `goodie_stash`).
const STICK_STAGE_MODS: Array[float] = [0.05, 0.0, -0.07]

## Take partition by tier: how the ONE entry-time take roll splits across
## stages. The last fraction absorbs rounding so the parts always sum to the
## whole (`stage_pots`).
const STICK_PARTITION := {
	2: [0.40, 0.60],
	3: [0.35, 0.35, 0.30],
}

## The exit fork's numbers. A failed stage becomes a fork, not a terminal row:
## DROP IT AND RUN is the guaranteed out (banked returned, no injury), RUN WITH
## IT rolls `escape` — Combat, because mid-robbery the problem is the grip, not
## the map (the escape ruling, recorded in the build log).
const STICK_FORK_RUN_BASE := 0.50

## TALK's base chance where a script allows it (crowd rooms only). Resolves on
## the existing `negotiation` shape — Charisma.
const STICK_TALK_BASE := 0.52

## WATCH THE ROOM: deterministic. Forfeits the current stage's pot, and buys
## the next stage `WATCH_BONUS` on its chance and half its injury band. The
## patient read, priced in money.
const WATCH_BONUS := 0.08

## What leaving early costs in noise: exit heat is the target's authored heat
## scaled by the fraction of the realised take actually banked, floored at 1.0
## — the "clean take is half the heat" rule generalised to partial takes.
const STICK_HEAT_FLOOR := 1.0

## A partial job counts toward rep only when it mostly came off.
const STICK_REP_FRACTION := 0.5

## Per-target scripts. Only tier 2 and 3 targets appear; a target with no entry
## here resolves on the shipped single roll (`has_room` is the gate).
##
## `left` is what the #LEFT chip counts and it means one thing per script —
## people still in your way. Nobody dies in these sheets: the count going down
## is somebody stepping off. `left_label` is the chip's noun so the UI never
## has to guess. Beat text goes through the sheet; `bank_log` lines land in the
## round log with the stage's banked amount.
const STICK_SCRIPTS := {
	"spenard_fuel_till": {
		"sheet_title": "THE NIGHT TILL",
		"opponent": "The night clerk",
		"left": 1, "left_label": "WATCHING",
		"talk": false,
		"stage_mods": [0.05, 0.0],
		"beats": [
			{
				"enter": "One clerk, no partition, and a till that has been fattening since dark. He has already decided not to be a hero. The drawer is the question.",
				"bank_log": "The tray gives it up. $%d banked.",
			},
			{
				"enter": "There is a second drawer under the register — there always is. His eyes keep going to the window, which means somebody he knows is due.",
				"bank_log": "The drawer under, too. $%d banked.",
			},
		],
	},
	"downtown_fuel_till": {
		"sheet_title": "THE REGISTER",
		"opponent": "The register clerk",
		"left": 1, "left_label": "WATCHING",
		"talk": false,
		"stage_mods": [0.05, 0.0],
		"beats": [
			{
				"enter": "The register sits open between customers, the clerk mid-count. C Street is bright outside and empty inside, which cuts both ways.",
				"bank_log": "The register empties clean. $%d banked.",
			},
			{
				"enter": "The back till is under the cigarette rack. He is slower now, deliberately. Somebody taught him that stalling is a plan.",
				"bank_log": "The back till as well. $%d banked.",
			},
		],
	},
	"rec_center_dice": {
		"sheet_title": "THE GAME",
		"opponent": "The dice game",
		"left": 3, "left_label": "IN YOUR WAY",
		"talk": true,
		"stage_mods": [0.05, 0.0, -0.07],
		"beats": [
			{
				"enter": "Folding-table money behind the rec center, three players deep, nobody's phone out yet. The pot is sitting where pots sit.",
				"bank_log": "You put the loudest one against the wall. $%d banked.",
			},
			{
				"enter": "The pot is split across the table and the big one is doing math on you, not the dice. Somebody's phone is out now.",
				"bank_log": "The split comes across the table. $%d banked.",
			},
			{
				"enter": "Between you and the gap in the fence: one man, and everything he is rethinking. The rest is already in your jacket.",
				"bank_log": "The last of it. $%d banked.",
			},
		],
	},
	"goodie_stash": {
		"sheet_title": "THE SPOT",
		"opponent": "Goodie's spot",
		"left": 2, "left_label": "IN YOUR WAY",
		"talk": false,
		# Resistance 3: the response clock starts a stage early. This is the
		# one script whose decay arrives at stage two.
		"stage_mods": [0.05, -0.07, -0.07],
		"beats": [
			{
				"enter": "Everybody knows Goodie keeps a spot. The kid watching it has clocked you, and the day's loose count is right there in the milk crate.",
				"bank_log": "The crate gives up the loose count. $%d banked.",
			},
			{
				"enter": "The wrapped stack is behind the cinder block where wrapped stacks live. The kid is gone, which is worse than the kid being here.",
				"bank_log": "The stack, wrapped and heavy. $%d banked.",
			},
			{
				"enter": "The real bag is deeper in, and the walk out of a stash spot is the longest walk in Spenard. Somebody is coming — you can feel it in the lot.",
				"bank_log": "The bag itself. $%d banked.",
			},
		],
	},
}

## The loop's action copy, all scripts. Labels are the buttons; copy is the line
## under them. Reached through the engine's adapter seam (`choice_label` /
## `choice_copy` on the stickup system), the same seam Wander's vocabulary uses.
const STICK_CHOICE_LABELS := {
	"press": "PRESS",
	"talk": "TALK",
	"watch": "WATCH THE ROOM",
	"take_and_go": "TAKE AND GO",
	"walk": "WALK",
	"drop_and_run": "DROP IT AND RUN",
	"run_with_it": "RUN WITH IT",
}

const STICK_CHOICE_COPY := {
	"press": "Keep the room yours. Sweep the next stack.",
	"talk": "Nobody here is a hero. Say it like it is already true.",
	"watch": "Count hands, not money. This stack stays — the next move comes cheaper.",
	"take_and_go": "What is banked walks out with you. The rest stays.",
	"walk": "Not tonight. Costs nothing, counts as nothing.",
	"drop_and_run": "The money hits the ground and buys you the door.",
	"run_with_it": "Keep what is banked. Outrun what is coming.",
}

## Fork beat, shared shape across scripts — the stage that went wrong names
## itself in the log; this is the situation the fork renders over.
const STICK_FORK_BEAT := "It slips. The room is not yours any more, and what is in your jacket is the question now."

## Result-stage headlines by resolution state, confrontation chains only.
const STICK_RESULT_HEADLINES := {
	RESOLUTION_WON: "YOU RAN THE ROOM",
	RESOLUTION_ESCAPED: "YOU GOT OUT WITH IT",
	RESOLUTION_SURRENDERED: "YOU DROPPED IT AND WALKED",
	RESOLUTION_BEATEN: "IT CAME APART",
}

const STICK_RESULT_BODIES := {
	RESOLUTION_WON: "Every stack that was on the table left with you. The room will tell the story its own way.",
	RESOLUTION_ESCAPED: "You left money sitting, and left. Half a take you keep beats a whole one you answer for.",
	RESOLUTION_SURRENDERED: "They watched the money hit the ground instead of watching you. It bought the door.",
	RESOLUTION_BEATEN: "The room closed before the door did. What was banked stayed behind, and so did some skin.",
}

# --- lookups -----------------------------------------------------------------

## Does this target open the loop? Tier 1 never does — that absence is the
## REPLACE ruling's boundary, and the tier-1 parity probe depends on it.
func has_room(target: Dictionary) -> bool:
	return int(target.get("tier", 1)) >= 2 \
		and STICK_SCRIPTS.has(str(target.get("id", "")))

func script_for(target_id: String) -> Dictionary:
	return STICK_SCRIPTS.get(target_id, {})

func stage_count(script: Dictionary) -> int:
	return (script.get("beats", []) as Array).size()

func stage_mod(script: Dictionary, stage: int) -> float:
	var mods: Array = script.get("stage_mods", STICK_STAGE_MODS)
	if stage < 0 or stage >= mods.size():
		return 0.0
	return float(mods[stage])

func beat(script: Dictionary, stage: int) -> Dictionary:
	var beats: Array = script.get("beats", [])
	if stage < 0 or stage >= beats.size():
		return {}
	return beats[stage]

## Split one realised take across stages. Floor per stage, remainder onto the
## last, so the parts sum to the whole exactly — the band stays the budget.
func stage_pots(take: int, tier: int) -> Array:
	var fractions: Array = STICK_PARTITION.get(tier, [1.0])
	var pots: Array = []
	var assigned: int = 0
	for i in range(fractions.size()):
		if i == fractions.size() - 1:
			pots.append(take - assigned)
		else:
			var pot: int = int(floor(float(take) * float(fractions[i])))
			pots.append(pot)
			assigned += pot
	return pots

func choice_label(choice_id: String) -> String:
	return str(STICK_CHOICE_LABELS.get(choice_id, ""))

func choice_copy(choice_id: String) -> String:
	return str(STICK_CHOICE_COPY.get(choice_id, ""))

# =============================================================================
# AUTHORED, NOT YET WIRED — the remaining scripts, resolved per the build brief
# so the next slices author nothing, only plumb. Nothing below is read by live
# code this slice; the confrontation test suite asserts shape so a drive-by
# edit cannot quietly break a table a later slice trusts.
# =============================================================================

# --- the Lift (Q1 + Q3, resolved) --------------------------------------------
#
# The caught chain grows rounds ON PLAIN FAILURE ONLY: any success tier and any
# catastrophic still exits round one exactly as shipped, through the unedited
# CAUGHT_EFFECTS rows. A failure tier burns the verb, degrades what remains by
# VERB_PENALTY, prices the second chance at HEAT_PER_ROUND, and re-renders the
# next beat. Round cap 3 resolves through the last failed verb's failure row.
#
# BRIBE (Q1): deterministic, tiers 1-2 only — the Armed Guard not taking money
# is the tier-3 tell. It costs 2.0x the contested take, floored per tier, and
# the goods go back: strictly worse money than yield, and what it buys is the
# DOOR (no ban). It still counts as caught everywhere it matters — District
# Pressure 1.0 (yield's authored precedent), 0.5 raw Heat, and the negotiation
# messy observation footprint, so Exposure's visibility model keeps seeing the
# event. ONCE PER STORE PER RUN (`boost_bribes_used`): a bribe that worked
# becomes extortion if repeated, and the cap is what preserves the intended
# 3-4 bans-per-run attrition — each store gets one extra life, never infinite
# protection. boost_finder moving off 7% is expected and must be measured, not
# assumed.

const LIFT_ESCALATION := {
	"verb_penalty": -0.10,
	"heat_per_round": 0.5,
	"round_cap": ROUND_CAP,
}

const LIFT_BRIBE := {
	"multiplier": 2.0,
	"floors": {1: 40, 2: 90},
	"tiers": [1, 2],
	"per_store_limit": 1,
	"pressure": 1.0,
	"heat": 0.5,
	"observation_shape": "negotiation",
	"observation_tier": "messy",
}

const LIFT_BEATS := {
	1: [
		"The clerk caught the move before you made the door. It is a small store and both of you know it.",
		"He is between you and the door now, the phone half out of his pocket. This is the part he practised in his head.",
		"Out front, and he followed you out. Small stores make people brave.",
	],
	2: [
		"Security's hand is on the basket and the clerk is already on the phone. The racks are dense enough to lose him in — maybe.",
		"He is between you and the door now. The back hallway is unlocked. The front is not, any more.",
		"The lot. Bright, flat, and longer than it looked from inside.",
	],
	3: [
		"The guard sees the lift and closes the distance before you clear the racks. He is armed and bored, which is the bad combination.",
		"Between the racks now, and he is not chasing — he is herding.",
		"The fence line is a long way from the dock gate, and he knows exactly how long.",
	],
}

## The two choices this file adds beyond the shared caught table (BRIBE,
## HAND IT BACK). `fight`/`run`/`talk`/`yield` are unlisted on purpose --
## boost.gd's adapter methods fall back to the engine's own
## `choice_id.capitalize()` for them, unchanged from before this file existed.
const LIFT_CHOICE_LABELS := {
	"bribe": "SETTLE IT",
	"hand_it_back": "HAND IT BACK",
}

const LIFT_CHOICE_COPY := {
	"bribe": "Money for the walk. You keep the door.",
	"hand_it_back": "Give up what's in your hands. No ban -- the door's still yours next time.",
}

# --- market corner scripts (Q4, resolved) ------------------------------------
#
# `corner_stiff`: trigger on a market sell in a district whose Market Pressure
# band is VISIBLE or worse, low seeded chance, once a day. Small stakes, cap 2.
# `corner_push`: trigger on Post Up in Spenard at Curtis phase `watching`+,
# queued through the engine, rare. What makes it Curtis and not a shakedown is
# POLITICAL, and mechanically real: STAND ON IT writes a `defiance` observation
# to his ledger, STEP OFF writes `submission` — his THREAT lens prices both,
# so the choice moves how he reads you, not just the day's cash.

const MARKET_SCRIPTS := {
	"corner_stiff": {
		"sheet_title": "SHORT COUNT",
		"opponent": "The buyer",
		"cap": 2,
		"actions": {
			"count_again": {"label": "COUNT IT AGAIN", "attribute": "intelligence",
				"shape": "negotiation", "base": 0.60,
				"copy": "Catch it before he is gone. Numbers do not get embarrassed."},
			"press_him": {"label": "PRESS HIM", "attribute": "combat",
				"shape": "confrontation", "base": 0.50,
				"copy": "Full price, plus he remembers. Costs blood if he minds."},
			"let_it_ride": {"label": "LET IT RIDE", "deterministic": true,
				"copy": "Eat the short and keep the corner quiet. Sometimes thirty dollars is the play."},
		},
	},
	"corner_push": {
		"sheet_title": "THE CORNER",
		"opponent": "Two of Curtis's people",
		"cap": 2,
		"actions": {
			"stand_on_it": {"label": "STAND ON IT", "attribute": "combat",
				"shape": "confrontation", "base": 0.44,
				"copy": "The corner is yours if you are still on it after.",
				"observation": {"type": "defiance", "event": "held_the_corner"}},
			"call_tone": {"label": "CALL TONE", "crew": "tone", "deterministic": true,
				"copy": "He ends it by standing there. Costs a favor."},
			"step_off": {"label": "STEP OFF", "deterministic": true,
				"copy": "Live to sell somewhere else. The block remembers who moved.",
				"observation": {"type": "submission", "event": "ceded_the_corner"}},
		},
	},
}

## STASH IT (Q4 tail): one action added to the existing police-stop script when
## inventory > 0. Intelligence roll, once per stop, and it IS the round's
## action: success hides the carried product before the search (exempt from
## this stop's seizure only), failure worsens it — they watched you do it
## (+0.5 raw Heat on top of the stop's own costs).
const STASH_IT := {
	"label": "STASH IT", "attribute": "intelligence", "shape": "escape_route",
	"base": 0.55, "heat_on_failure": 0.5,
	"copy": "Product goes somewhere that is not on you. Fast hands, faster story.",
}

# --- the 907List scene (Q5, resolved) ----------------------------------------
#
# ONE scene, narrow trigger: the meetup outcome shape rolled `catastrophic`
# AND the payout was real money (>= `value_floor`), or a trap-tip meet. The
# cash is already credited when this opens — what the sheet decides is whether
# you keep it. Commercial, not criminal: nobody swings first, injury only on a
# catastrophic exit, and the guaranteed out is a TRANSACTION — refund the
# money, take the item back, sell it tomorrow. That is what keeps it a 907List
# scene: the worst ordinary outcome is a reversed deal, not a hospital bill.

const MEETUP_SCRIPT := {
	"sheet_title": "THE BUYER'S FRIEND",
	"opponent": "The buyer's friend",
	"value_floor": 150,
	"cap": 2,
	"beats": [
		"The buyer brought somebody, and nobody brings somebody to buy a camera. The recount is happening whether you agree to it or not.",
		"The friend is between you and the lot now, and the buyer has stopped making eye contact. The price is about to change hands again.",
	],
	"actions": {
		"read_it": {"label": "READ IT", "attribute": "intelligence",
			"shape": "escape_route", "base": 0.58,
			"copy": "Clock the play before it starts. Leave with everything."},
		"stay_commercial": {"label": "STAY COMMERCIAL", "attribute": "charisma",
			"shape": "negotiation", "base": 0.52,
			"copy": "Receipts, handshakes, everybody's day continues."},
		"refund_him": {"label": "GIVE IT BACK", "deterministic": true,
			"copy": "Refund the money, take the item back, sell it to somebody with fewer friends."},
	},
}

# --- tips → loop parameters (Q7, resolved) -----------------------------------
#
# A tip may move entry parameters — the pot, the odds decay, a body, the free
# out — NEVER an exit table. What a resolution costs is pinned; what a tip
# buys is a better (or worse) room. Read at loop entry through
# `tip_modifiers_for`, which degrades to no-ops until the tip system lands.

const TIP_MODIFIERS := {
	"fat_night": {
		# Tone / the network edge, stickup: the named target's realised take is
		# multiplied before partition, and the last stage's decay is removed —
		# the room is drinking; it never organises.
		"path": "stick", "take_multiplier": {2: 2.0, 3: 2.5},
		"remove_final_decay": true,
	},
	"lift_window": {
		# Pherris/Deshawn, the Lift: the tier-2 window term, told instead of
		# shown. Round-1 rolled verbs only.
		"path": "lift", "round_one_bonus": 0.20,
	},
	"trap": {
		# The unknown number, any path: the script opens pre-escalated. One
		# more body, and round 1 has no FREE out — the priced outs (surrender
		# the goods, the refund, the bribe) remain, which is how the chassis
		# rule survives: an out always exists, not a free one.
		"path": "any", "extra_left": 1, "no_free_out_round_one": true,
	},
	"buyer_confirmed": {
		# Pherris, 907List: a vouched buyer cannot be the buyer's friend. The
		# meetup scene's TRIGGER is suppressed for the tipped item — the
		# outcome shape's roll itself is untouched.
		"path": "list", "suppress_meetup_scene": true,
	},
	"corridor_clear": {
		# Eli, routes: entry-rate relief on carry stops from the named origin,
		# same (1 - relief) shape his assignment already applies. Not an
		# in-loop modifier; listed so the table is complete in one place.
		"path": "carry", "stop_relief": 0.30,
	},
}

# --- crew calls (locked ruling, parameters resolved) -------------------------
#
# Chassis features, script-gated. A script declares which calls it admits;
# no stickup script admits any (you started this — Tone's terms are that he is
# told when something has already started, not aimed at something you are
# starting). Availability: recruited, active, loyalty > 0, and unassigned
# today — `crew_unassigned_today` is already the requirement language for
# presence. Once per loop. Calling does not burn any verb.

const CREW_CALLS := {
	"call_tone": {
		"crew_id": "tone", "resolution": RESOLUTION_WON,
		"loyalty_cost": 1, "heat": 0.5,
		"copy": "He ends it by standing there. Costs a favor.",
	},
	"let_deshawn_talk": {
		"crew_id": "deshawn", "resolution": RESOLUTION_SURRENDERED,
		"loyalty_cost": 1, "heat": 0.0, "stakes_returned": true,
		"copy": "His voice, not yours. Everybody walks.",
	},
}

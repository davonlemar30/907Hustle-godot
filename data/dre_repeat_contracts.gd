extends RefCounted
## Dre's repeatable contracts — Repeat Business (0.4.0 PR B/C). Design doc:
## `docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` §22 (DRE-D12).
## Rulings: `docs/DECISIONS.md`, D-17 (REP-D1..D5), D-18 (PR C's catalogue).
##
## Sibling to `data/dre_contracts.gd` per REP-D2's own wording ("or one
## sibling catalogue file") — kept separate because these definitions are
## `repeatable: true` and the arc's own definitions are not; a reader asking
## "what's the authored one-time chain" should never have to skip past
## generated-content rows to find it.
##
## `dre_repeat_collection` rides `systems/dre_collector.gd`'s existing
## encounter END TO END — the same two dispatch actions
## (`dre_collect_negotiate`/`dre_collect_hard`), the same chance/effect
## tables (`data/confrontation_scripts.gd`'s `DRE_COLLECTION_PRESS_*`/
## `DRE_COLLECTION_NEGOTIATE_*`), the same resolution code. `dre_collector.gd`
## no longer hardcodes `dre_a_reminder`/`DRE_COLLECTION_TARGET`: it asks
## `Opportunities` which collection-shaped instance is currently live
## (`resolves_via: "dre_collector"`, a marker this definition and the
## authored `dre_a_reminder` both now carry) and reads the target's name from
## the instance's own `source_context` — the umbrella's own "named target or
## borrower" field (design doc §9.3), populated here at generation time and
## empty on the authored one-time arc (which keeps reading
## `DRE_COLLECTION_TARGET` as its fallback, unchanged).
##
## What's authored data versus what's per-instance variance (REP-D2): the
## chance tables, injury bands, and Heat costs stay exactly as authored for
## the one true borrower (REP-D4 — this is content, not new mechanics). Only
## the borrower's name/flavor (per-pool, seeded pick) and the fee band
## (seeded roll per tier) vary per generated instance, carried on
## `source_context` as `target_id`/`target_name`/`target_desc`/`fee_clean`/
## `fee_messy`. `systems/opportunities.gd::_generate_repeatables()` is the
## generator; this file authors only what it generates FROM.
##
## ## PR C — the catalogue (D-18)
##
## `dre_repeat_collection_leaned_on` is the second collection variant the
## build prompt asks for: same machinery as the base collection (same
## dispatch actions, same chance tables, same `dre_collector.gd` resolution —
## nothing about "riding the existing encounter" changes per template), a
## different borrower pool and a higher fee band, gated on having attempted
## at least one repeatable already (`repeatable_attempts_min` — REP-D4's own
## "reads back" restated as a requirement rather than an effect: Dre offers
## the harder work once you have shown up for the easier kind, not before).
##
## `dre_repeat_premium` is the "higher-tier" ask. Mechanical tiers stop at 4
## (Junior Lender) — there is no tier 5 to gate on — so "higher-tier" is read
## as the design doc's own §12.3 difficulty progression instead: demonstrated
## capability (attempts, not wins — see below) rather than a new mechanical
## rung. Gated at `repeatable_attempts_min: 3`, a real bar above the leaned-on
## variant's 1. Disclosed rather than silently assumed: `count` on a
## repeatable's history row increments on ANY resolution (`resolve()` and
## `fail()` both call `_write_history`), so this gates on proven WORK, not
## proven SUCCESS — the closest fact derivable from existing state (D-17's
## REP-D3 discipline) without adding a persisted win counter no other reader
## of `opportunity_history` has ever needed.
##
## `dre_repeat_errand` is the one template that does NOT ride
## `dre_collector.gd` — the "delivery/errand-shaped contract observing
## existing movement" the build prompt asks for. It observes a successful
## `travel` dispatch to a named district within the window, the same
## no-separate-accept shape `score_slide_special` (0.4.0 PR A,
## `data/score_contracts.gd`) established for `boost`: there is no
## meaningful gap between "the player commits to the errand" and "the player
## makes the trip," so `systems/opportunities.gd` gains one more bespoke
## `reconcile()` branch rather than a new dispatch action. Its own outcome
## variation (REP-D4) is binary rather than tiered — `travel` has no
## clean/messy/failure shape to key off, only arrived-in-time or not — so the
## variation is resolve-vs-fail (a paid, observed delivery vs an expired one
## that never happened), the same asymmetry the collection templates already
## carry between `resolve()` and `fail()`.

## Two separate pools -- the leaned-on variant's own borrowers are named
## distinctly from the base collection's (`reggie_voss`/`katrina_bell`/
## `omar_deng`) and from `dre_repeat_premium`'s, so a player who has met one
## debtor is never told a different amount is now owed by the same name.
const BORROWER_POOL := [
	{"id": "reggie_voss", "name": "Reggie Voss",
		"desc": "Behind on a favor Dre did him in the spring. Works the loading docks."},
	{"id": "katrina_bell", "name": "Katrina Bell",
		"desc": "Took a bridge loan through Dre and let it run past the date."},
	{"id": "omar_deng", "name": "Omar Deng",
		"desc": "Vouched for by somebody who no longer answers for him."},
]

const LEANED_ON_BORROWER_POOL := [
	{"id": "victor_hale", "name": "Victor Hale",
		"desc": "Owes enough that talking it loose stopped being an option a while ago."},
	{"id": "dana_okafor", "name": "Dana Okafor",
		"desc": "Missed the second extension Dre never should have offered."},
]

const PREMIUM_BORROWER_POOL := [
	{"id": "sal_petrov", "name": "Sal Petrov",
		"desc": "The kind of number Dre only sends someone he trusts after."},
]

## Seeded per instance, clean/messy only — WALK and failure/catastrophic pay
## nothing, same as the authored one-time fees. `FEE_BAND` sits close to
## `DRE_COLLECTION_PRESS_FEE`/`DRE_COLLECTION_NEGOTIATE_FEE`'s own $80/$60
## clean and $50/$40 messy so the base repeatable neither starves nor dwarfs
## the content it rides; `LEANED_ON_FEE_BAND`/`PREMIUM_FEE_BAND` step up from
## there, the "different stakes" the build prompt asks the second variant
## for, and the premium tier's own reason to exist at all.
const FEE_BAND := {"clean": [60, 100], "messy": [35, 65]}
const LEANED_ON_FEE_BAND := {"clean": [110, 160], "messy": [60, 95]}
const PREMIUM_FEE_BAND := {"clean": [180, 260], "messy": [100, 150]}

## The errand's own seeded variance: which district, and the flat bonus for
## making the trip. Never `north_star_lot` — asking the player to "deliver"
## to their own home turf is not an errand, and every run starts there
## already unlocked, so it would trivially win every seeded pick otherwise.
const ERRAND_DISTRICT_POOL := ["downtown", "airport_industrial"]
const ERRAND_FEE := 70

const DEFINITIONS := {
	"dre_repeat_collection": {
		"id": "dre_repeat_collection",
		"kind": "contract",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": true,
		# DRE-D12 / REP-D1: only after the authored arc's own capstone. Reusing
		# the tier fact `dre_a_reminder` already reads, at the arc's true exit
		# rather than a new fact.
		"requirements": [
			{"type": "dre_access_tier_min", "min": 4},
		],
		"resolves_via": "dre_collector",
		# Documentation only, the same reduced role `dre_a_reminder`'s own
		# `objectives` plays -- both resolution roads call
		# `Opportunities.accept()/resolve()/fail()` directly from
		# `dre_collector.gd`, never through the generic action-result matcher
		# (see that file's header on why: `resolve_consequence_choice` is an
		# action name shared by every confrontation in the game).
		"objectives": [
			{"class": "action_result", "action": "dre_collect_negotiate"},
		],
		# REP-D2's own authored window -- one day longer than the arc's
		# authored collection has (that one carries no deadline at all,
		# since its own disposition/tier gate is the only pacing it needs);
		# a repeatable needs a real window or it would sit on the board
		# forever, silently eating one of the 3 accepted-commitment slots.
		"deadline": {"window_days": 4},
		"completion_mode": "auto",
		# Empty on purpose, same reasoning as `dre_a_reminder`'s own
		# non-empty row does NOT apply here: THAT row promotes Junior Lender
		# once, off the one arc-defining collection. This one runs after
		# Junior Lender already exists -- there is no further tier to grant,
		# and `dre_collector.gd` already pays its own fee/Heat/injury
		# directly, WITH its own tier-keyed Exposure calls (collected_hard/
		# botched_mission/refused_work) already providing real outcome
		# variation for any `resolves_via: "dre_collector"` instance
		# regardless of definition id. An opportunity-level effect here would
		# be a second authority paying for or observing the same collection
		# twice.
		"completion_effects": [],
		"presentation": {
			"title": "Collect for Dre",
		},
	},
	"dre_repeat_collection_leaned_on": {
		"id": "dre_repeat_collection_leaned_on",
		"kind": "contract",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": true,
		"requirements": [
			{"type": "dre_access_tier_min", "min": 4},
			{"type": "repeatable_attempts_min", "min": 1},
		],
		"resolves_via": "dre_collector",
		"objectives": [
			{"class": "action_result", "action": "dre_collect_negotiate"},
		],
		"deadline": {"window_days": 4},
		"completion_mode": "auto",
		"completion_effects": [],
		"presentation": {
			"title": "Lean on Someone for Dre",
		},
	},
	"dre_repeat_premium": {
		"id": "dre_repeat_premium",
		"kind": "contract",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": true,
		"requirements": [
			{"type": "dre_access_tier_min", "min": 4},
			{"type": "repeatable_attempts_min", "min": 3},
		],
		"resolves_via": "dre_collector",
		"objectives": [
			{"class": "action_result", "action": "dre_collect_negotiate"},
		],
		"deadline": {"window_days": 4},
		"completion_mode": "auto",
		"completion_effects": [],
		"presentation": {
			"title": "The One Dre Only Sends You For",
		},
	},
	"dre_repeat_errand": {
		"id": "dre_repeat_errand",
		"kind": "contract",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": true,
		"requirements": [
			{"type": "dre_access_tier_min", "min": 4},
		],
		# Documentation only -- see this file's own header and
		# `systems/opportunities.gd`'s `_resolves_repeat_errand()` on why
		# resolution runs through a bespoke `reconcile()` branch instead,
		# the same shape `score_slide_special` established.
		"objectives": [
			{"class": "action_result", "action": "travel"},
		],
		"deadline": {"window_days": 3},
		"completion_mode": "auto",
		"completion_effects": [
			{"type": "exposure_observation", "npc_id": "dre",
				"spec": {"type": "financial", "event": "ran_an_errand", "source": "direct"}},
			{"type": "wallet_credit", "amount": ERRAND_FEE, "provenance": "dirty",
				"source_id": "dre_repeat_errand"},
		],
		"presentation": {
			"title": "Run Something Across Town",
		},
	},
}

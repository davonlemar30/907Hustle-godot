extends RefCounted
## Dre's repeatable contracts — Repeat Business (0.4.0 PR B). Design doc:
## `docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` §22 (DRE-D12).
## Rulings: `docs/DECISIONS.md`, D-17 (REP-D1..D5).
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
## the borrower's name/flavor (`BORROWER_POOL`, seeded pick) and the fee band
## (`FEE_BAND`, seeded roll per tier) vary per generated instance, carried on
## `source_context` as `target_id`/`target_name`/`target_desc`/`fee_clean`/
## `fee_messy`. `systems/opportunities.gd::_generate_repeatables()` is the
## generator; this file authors only what it generates FROM.

## Distinct from `data/confrontation_scripts.gd`'s `DRE_COLLECTION_TARGET`
## (Dontae Wells, the one-time A Reminder) and from `GameState.shark_
## borrowers` (the Book's own catalogue, a different lending surface
## entirely) — new names, so nobody reads two different debts as the same
## person.
const BORROWER_POOL := [
	{"id": "reggie_voss", "name": "Reggie Voss",
		"desc": "Behind on a favor Dre did him in the spring. Works the loading docks."},
	{"id": "katrina_bell", "name": "Katrina Bell",
		"desc": "Took a bridge loan through Dre and let it run past the date."},
	{"id": "omar_deng", "name": "Omar Deng",
		"desc": "Vouched for by somebody who no longer answers for him."},
]

## Seeded per instance, clean/messy only — WALK and failure/catastrophic pay
## nothing, same as the authored one-time fees. Bands sit close to
## `DRE_COLLECTION_PRESS_FEE`/`DRE_COLLECTION_NEGOTIATE_FEE`'s own $80/$60
## clean and $50/$40 messy so a repeatable neither starves nor dwarfs the
## content it rides.
const FEE_BAND := {"clean": [60, 100], "messy": [35, 65]}

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
		# directly. An opportunity-level reward here would be a second
		# authority paying for the same collection twice.
		"completion_effects": [],
		"presentation": {
			"title": "Collect for Dre",
		},
	},
}

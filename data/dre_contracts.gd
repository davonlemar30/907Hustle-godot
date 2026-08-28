extends RefCounted
## Dre's authored contract/mission definitions — Street Opportunity and
## Mission System substrate (`systems/opportunities.gd`), content per
## `docs/DRE_LENDING_AND_LOAN_SHARK_SYSTEM_DESIGN.md` section 13.2
## (DRE-ARC-01/02). A definition is immutable authored data; the instance it
## produces holds only what differs for this run (umbrella section 9.1/9.2).
##
## `dre_the_introduction` (DRE-ARC-01) is listed for completeness and for any
## future presentation that reads history by definition id, but
## `opportunities.gd` never creates a live instance for it — see that file's
## header for why: `dre_lender._seek_out()` is the one authority for what it
## does, and this definition exists only so its `objectives`/`id` are data
## `opportunities.gd` can read generically, the same as any other.
##
## `dre_first_money` (DRE-ARC-02) is real content: offered the moment
## DRE-ARC-01 completes, accepted by dispatching `dre_borrow` (the loan
## itself IS the acceptance — OPP-D3), resolved by `dre_repay` on time or
## late. Numbers are canon-provisional — see `systems/dre_lender.gd`'s own
## header; nothing here should be read as balance-final either.

const DEFINITIONS := {
	"dre_the_introduction": {
		"id": "dre_the_introduction",
		"kind": "mission",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": false,
		"requirements": [],
		"objectives": [
			{"class": "action_result", "action": "dre_seek_out"},
		],
		"completion_mode": "auto",
		# Empty on purpose — `dre_lender._seek_out()` already sets
		# `dre_introduced` and raises the tier. A completion effect here
		# would be a second authority writing the same fact.
		"completion_effects": [],
		"presentation": {
			"title": "The Introduction",
		},
	},
	"dre_first_money": {
		"id": "dre_first_money",
		"kind": "mission",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": false,
		# Both types already exist (PR B) — no new requirement type for PR C.
		"requirements": [
			{"type": "dre_access_tier_min", "min": 1},
			{"type": "dre_account_clear"},
		],
		"objectives": [
			{"class": "action_result", "action": "dre_repay"},
		],
		"completion_mode": "auto",
		"completion_effects": [
			{"type": "access_milestone", "field": "dre_access_tier", "min": 2},
		],
		"presentation": {
			"title": "First Money",
			"offered_body": "Dre's first offer. The flat rate — no discount for being new, no penalty either.",
		},
	},
}

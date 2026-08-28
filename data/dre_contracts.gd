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
##
## `dre_a_reminder` (DRE-ARC-03, PR D) has two resolution roads and neither
## goes through the generic `action_result` matcher — `dre_collect_negotiate`
## resolves in one dispatch that can succeed OR fail, and `dre_collect_hard`
## only ever ACCEPTS the offer (opening a confrontation chain); the outcome
## arrives later, on `resolve_consequence_choice`, an action name shared by
## every confrontation in the game. Routing either through the generic
## action-name matcher risks a completely unrelated chain (a Stickup room,
## say) resolving THIS instance. `systems/dre_collector.gd` calls
## `Opportunities.accept/resolve/fail` directly instead, from the one place
## that genuinely knows which chain is which. `objectives` below is
## documentation for that reason, the same reduced role
## `dre_the_introduction`'s own objective plays.
##
## `dre_penance` is the small follow-up once a suspension clears by
## payment (`dre_pending_penance`, game_state.gd) — real content, resolved
## through the generic matcher like `dre_first_money`, because
## `dre_do_penance` is a name nothing else in the game dispatches.

const DEFINITIONS := {
	"dre_the_introduction": {
		"id": "dre_the_introduction",
		"kind": "mission",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": false,
		"requirements": [],
		# Never offered as a real instance — `opportunities._maybe_offer`
		# checks this before evaluating `requirements` at all. An empty
		# `requirements` array would otherwise pass trivially and mint an
		# offer for a definition this system deliberately never tracks as
		# one; see this file's own header on why.
		"offerable": false,
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
	"dre_a_reminder": {
		"id": "dre_a_reminder",
		"kind": "contract",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": false,
		"requirements": [
			{"type": "dre_access_tier_min", "min": 2},
			{"type": "dre_account_clear"},
			{"type": "dre_disposition_min", "min": 0},
		],
		# Documentation only — see this file's own header on why neither
		# resolution road uses the generic matcher.
		"objectives": [
			{"class": "action_result", "action": "dre_collect_negotiate"},
		],
		"completion_mode": "auto",
		"completion_effects": [
			{"type": "access_milestone", "field": "dre_access_tier", "min": 3},
		],
		"presentation": {
			"title": "A Reminder",
			"offered_body": "Dontae Wells owes Dre. Dre would like it handled — talked loose, or taken.",
		},
	},
	"dre_penance": {
		"id": "dre_penance",
		"kind": "mission",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": false,
		"requirements": [
			{"type": "fact_true", "fact": "dre_pending_penance"},
		],
		"objectives": [
			{"class": "action_result", "action": "dre_do_penance"},
		],
		"completion_mode": "auto",
		# No access_milestone -- restitution already cleared the account
		# (D-4/D-7) the moment payment landed. This completion effect is the
		# relationship repair itself, not a second gate on top of it.
		"completion_effects": [
			{"type": "exposure_observation", "npc_id": "dre",
				"spec": {"type": "honesty", "event": "made_it_right", "source": "direct"}},
		],
		"presentation": {
			"title": "Making It Right",
			"offered_body": "The money's square. Dre still wants to hear it from you.",
		},
	},
}

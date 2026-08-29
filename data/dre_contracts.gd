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
##
## `dre_book_sponsorship` (DRE-ARC-04, PR E) is the last milestone: Dre
## sponsors Priya Osei (`GameState.shark_borrowers`, the one row whose
## `introduction_key` matches this definition's own id) as one fundable
## exception before Junior Lender itself opens the Book. Accepted by
## dispatching `fund_shark` against her specifically — the loan IS the
## acceptance, same as First Money's `dre_borrow` — and resolved when
## THAT loan reaches a terminal state (repaid, or defaulted then enforced
## or forgiven; extending leaves it open). None of that goes through the
## generic matcher: `fund_shark`/`enforce_shark`/`forgive_shark` are
## action names shared by every Book loan a player will ever touch, not
## just the sponsored one, so `systems/shark.gd` calls
## `Opportunities.accept/resolve/fail` directly, keyed off the loan's own
## `borrower_id` matching the catalogue row's `introduction_key` — no
## `source_context` needed, since the sponsored borrower is authored, not
## chosen at offer time.
##
## Voice rule: Dre never has to raise his voice. His copy treats money as the
## visible part of a deal and reputation as the part that actually comes due.
## Threats stay implicit, terms stay exact, and every line fits the phone-first
## surfaces that present these offers.

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
			"offered_body": "Dre's first offer. Same terms as everybody else. " \
				+ "The money tests your need; the repayment tests your word.",
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
			"offered_body": "Dontae Wells has Dre's money. Bring it home. " \
				+ "How you move him is the part Dre is measuring.",
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
			"offered_body": "The debt is paid. The disrespect isn't. " \
				+ "Dre wants one last conversation.",
		},
	},
	"dre_book_sponsorship": {
		"id": "dre_book_sponsorship",
		"kind": "mission",
		"giver_id": "dre",
		"family": "dre_credit",
		"repeatable": false,
		"requirements": [
			{"type": "dre_access_tier_min", "min": 3},
			# Deliberately wider than dre_account_clear -- design doc: "Collector
			# + not suspended." A player mid-loan with Dre still qualifies.
			{"type": "dre_account_not_suspended"},
		],
		# Documentation only, and NOT the real dispatch action on purpose --
		# see this file's own header. `fund_shark`/`enforce_shark` are real,
		# frequently-dispatched action names shared by every Book loan; if
		# this named one of them, `opportunities._advance_action_result_
		# objectives` (the generic matcher, unconditional on every dispatch)
		# would find this instance still ACTIVE the moment `fund_shark`
		# accepts it and resolve it on the spot, with an empty result,
		# before Priya's loan has settled at all -- caught by
		# `dre_runner.gd`'s own full-arc test. A name nothing ever
		# dispatches means the generic scan can never match it, so only
		# `systems/shark.gd`'s bespoke accept/resolve calls (matching the
		# resolving loan's own borrower_id against GameState.shark_
		# borrowers' introduction_key) ever touch this instance.
		"objectives": [
			{"class": "action_result", "action": "dre_book_sponsorship_resolved"},
		],
		"completion_mode": "auto",
		"completion_effects": [
			{"type": "access_milestone", "field": "dre_access_tier", "min": 4},
		],
		"presentation": {
			"title": "Your First Name in the Book",
			"offered_body": "Dre is putting his name behind Priya Osei — and yours " \
				+ "beside it. Fund her, see the note through, and earn your place in the Book.",
		},
	},
}

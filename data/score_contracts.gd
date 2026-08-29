extends RefCounted
## Score contracts — the first non-Dre content on the Street Opportunity
## substrate (`systems/opportunities.gd`). SCR-D1..D3, `docs/DECISIONS.md`
## D-16: this build's whole job is proving the substrate generalizes to a
## second, non-lending consumer before OPP-D8 lets a generator start
## mass-producing instances on it.
##
## `score_slide_special` is authored in exactly the shape SCR-D1 allows: it
## OBSERVES an existing successful `boost` at a named target and adds an
## authored bonus on top. It does not own the lift's payout, Heat, technique,
## bans, or the caught path at all — those stay entirely `systems/boost.gd`'s,
## untouched by this file and by `opportunities.gd`'s own resolution of this
## definition. A blown/caught attempt at the named target simply does not
## resolve this Score; only the window closing (the authored `deadline`
## below) can fail it, per SCR-D1's own words: "a blown lift inside the
## window does NOT fail the contract — the window does."
##
## No separate accept step. OPP-D3's "the domain action that begins the work
## doubles as acceptance" applies here even more directly than it does for
## Dre: there is no meaningful gap between "the player commits to this job"
## and "the player pulls it" the way there is between meeting Dre and later
## repaying him. `opportunities.gd`'s `reconcile()` gains one bespoke branch,
## the same shape as `dre_seek_out`/`dre_borrow`'s own: a successful `boost`
## at the named target, while this offer is still live, calls `accept()` then
## `resolve()` back to back in the same pass. `objectives` below is
## documentation only, the same reduced role it plays on `dre_a_reminder` and
## `dre_book_sponsorship` — this content does not go through the generic
## action-result matcher (that matcher only ever scans `active_opportunities`,
## and this instance is designed to resolve straight from `opportunity_offers`
## with nothing in between).
##
## The target is `northern_value` (tier 2, `autoload/game_state.gd`'s
## `boost_targets`) — an existing authored target, not a new one; this build
## adds no new Boost content, only a bonus riding an existing one. Tier 2
## still pays direct cash (`boost.gd::_run()` only routes tier 3 to
## merchandise/the fence), so the bonus is a plain `wallet_credit`, no
## fencing step of its own. "Slide" is Boost's own fence, already in the
## game as flavor copy (`_fence_card()`, `boost.gd::_fence()`) but never a
## tracked NPC — no Exposure lens, no channel, no disposition. That stays
## true here: this definition's `giver_id` is presentational only, and
## `completion_effects` below carries no `exposure_observation`, because
## there is no relationship ledger for Slide to write one into.
##
## A first draft of this file named a target, `spenard_fuel_till`, that does
## not exist in `boost_targets` at all — a real bug, caught live rather than
## in a headless suite (`gs.boost_target_by_id()` returned `{}`, and every
## dispatch refused with "No such place." before ever reaching a roll). The
## suite's own coverage never would have caught it either: it drives
## `opportunities.reconcile()` directly with a synthetic result dict, which
## has no way to know whether the target name it was handed is real. Only
## the live `game_eval` drive, dispatching `boost` for real, surfaced it.

const DEFINITIONS := {
	"score_slide_special": {
		"id": "score_slide_special",
		"kind": "score",
		"giver_id": "slide",
		"family": "boost_score",
		"repeatable": false,
		# `boost_target_discovered` is a new requirements.gd type (SCR-D1's
		# "the named target discovered") -- the same DEAL-walk latch the
		# Boost screen itself reads to decide whether the target's row shows
		# at all, so this offer can never appear ahead of the target it is
		# about.
		"requirements": [
			{"type": "boost_target_discovered", "target_id": "northern_value"},
		],
		# Documentation only -- see this file's own header on why resolution
		# runs through a bespoke `reconcile()` branch instead.
		"objectives": [
			{"class": "action_result", "action": "boost", "target_id": "northern_value"},
		],
		# SCR-D1's window: 3 days from the offer appearing, not from any
		# acceptance moment -- there is no accept moment separate from the
		# resolving `boost` dispatch itself (see this file's own header).
		# `opportunities._new_instance()` reads this into the instance's own
		# `deadline_day` the moment the offer is minted; `_expire_overdue()`
		# (called from `settle_night()`, the declared lifecycle point every
		# other opportunity check already uses) is the first real caller of
		# the deadline half of the umbrella's own shape (section 9.2) --
		# deferred by OPP-D11 until a PR actually needed it.
		"deadline": {"window_days": 3},
		"completion_mode": "auto",
		# The authored premium on top of the lift's own take -- Boost's
		# payout, Heat, and technique growth are untouched and already
		# settled by the time this fires (`resolve()` runs from
		# `reconcile()`, strictly after the dispatch that already paid out).
		# $50 against `northern_value`'s own $60-150 band: a real bump
		# without coming close to making the bonus bigger than the job it
		# rides.
		"completion_effects": [
			{"type": "wallet_credit", "amount": 50, "provenance": "dirty",
				"source_id": "score_slide_special"},
		],
		"presentation": {
			"title": "Slide's Special",
			"offered_body": "Slide's after specific stock out of that thrift barn -- pull it clean inside the window and there's extra in it for you.",
		},
	},
}

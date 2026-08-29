extends RefCounted
## Requirements — the shared eligibility evaluator.
##
## Port of the web build's `src/systems/requirements.js` (FS-001 Phase 7,
## Slice 1). One job: answer "can this happen yet, and if not, what is the
## reason" in a form a UI can translate later without re-deriving eligibility.
##
## ## Why it is shaped like this
##
## A requirement record is SEMANTIC — `{type: "crew_loyalty_min", crew_id:
## "pherris", min: 6}` — and the answer is STRUCTURED:
##
##   {ok, blocker_code, blocker_copy_key, current, required}
##
## `current` and `required` come back on the blocker itself, so a caller can say
## "Needs loyalty 6, has 4" without knowing what a loyalty is. `blocker_copy_key`
## is the translation hook: presentation swaps copy without touching this file.
##
## ## Purity is the whole point
##
## **This reads ONLY from the `facts` dictionary.** No GameState, no autoloads,
## no `Engine.get_main_loop()`. It cannot be tested wrong because it cannot see
## anything a test does not hand it, and it can be reused by any system that
## needs to ask the same question. It has no `setup()` for the same reason.
##
## ## Who queries it
##
## FS-001.6 (Named Crew Operations) was the first caller. v0.1.0 added the
## second: `autoload/surface_visibility.gd` authors every progression gate as a
## requirement record and evaluates it here, which is why the type table below
## grew a block of fact-reading types. There is deliberately no second
## eligibility engine anywhere in the build — one gate language, one evaluator.
##
## It shipped one slice ahead of that first caller, deliberately — unlike the
## resolver Attributes deferred in Phase 5c, this is a small pure function table
## with exhaustive fixtures rather than a large untested branch, so the cost of
## landing it early was close to zero and the benefit was that FS-001.6 did not
## have to invent an eligibility contract while it was also inventing
## delegation. v0.1.0 is the payoff: the gate system needed no engine of its own.
##
## ## Two deliberate divergences from the oracle, both mechanical
##
## **1. Fact keys are snake_case here, camelCase there.** The oracle reads
## `facts.currentDay`, `facts.hustleTiers`, `facts.timeSlotsToday`,
## `crew.recruitedDay`, `crew.wageMissedSince`. This build's crew records
## already carry `recruited_day` and `wage_missed_since` on GameState, and the
## whole codebase is snake_case, so translating at the boundary would mean every
## future caller hand-mapping field names it already has. The OUTPUT shape is
## byte-identical to the oracle, including its snake_case `blocker_code` /
## `blocker_copy_key` — that half is a contract, not a convention.
##
## **2. A negative `wage_missed_since` reads as "no missed wage".** Canon uses
## `null` for that; this build's crew records use `-1`. Accepting both is a
## strict superset — canon's day numbers start at 1 and it never writes a
## negative, so the two agree on every input canon can produce. Without this a
## caller handing `crew_records` straight through would compute
## `current_day - (-1)` days delinquent and silently block everything.

## Canon's fallback grace when `facts.wage_grace_days` is absent. Duplicated as
## a literal rather than read off GameState: this file stays resolvable without
## an autoload, which is what lets the parity runner drive it in isolation.
const DEFAULT_WAGE_GRACE_DAYS := 2

## No actions of its own — this is a utility other systems call, never dispatch
## to. Registered in GameManager so callers reach it the same way as any system.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "Requirements takes no actions."}

# --- internals -------------------------------------------------------------

## Canon's `Number(x) || 0`: a non-numeric, null, or non-finite value is 0.
static func _num(value: Variant) -> float:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			var f := float(value)
			return f if is_finite(f) else 0.0
		TYPE_BOOL:
			return 1.0 if value else 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(value).strip_edges()
			# JS Number("") is 0; Number("abc") is NaN, which `|| 0` makes 0.
			if s.is_empty():
				return 0.0
			return s.to_float() if (s.is_valid_float() or s.is_valid_int()) else 0.0
		_:
			return 0.0

func _crew_record(facts: Dictionary, crew_id: Variant) -> Variant:
	var crew: Variant = facts.get("crew")
	if not (crew is Dictionary):
		return null
	var record: Variant = (crew as Dictionary).get(str(crew_id))
	return record if record is Dictionary else null

func _proofs(crew: Variant) -> Dictionary:
	if not (crew is Dictionary):
		return {}
	var proofs: Variant = (crew as Dictionary).get("proofs", {})
	return proofs if proofs is Dictionary else {}

## Canon's `result()`. On success both blocker fields are null; `current` and
## `required` still report, because a caller often wants the numbers either way.
##
## The blocker code falls back through the record's own override to the
## requirement type, which is what makes `requirements.<type>` a usable default
## copy key for every gate that has not earned bespoke wording yet.
func _result(requirement: Dictionary, ok: bool, current: Variant, required: Variant) -> Dictionary:
	var type_name: String = str(requirement.get("type", ""))
	var code: Variant = null
	var copy_key: Variant = null
	if not ok:
		var override_code: String = str(requirement.get("blocker_code", ""))
		code = override_code if not override_code.is_empty() else type_name
		var override_copy: String = str(requirement.get("blocker_copy_key", ""))
		copy_key = override_copy if not override_copy.is_empty() else "requirements.%s" % type_name
	return {
		"ok": ok,
		"blocker_code": code,
		"blocker_copy_key": copy_key,
		"current": current,
		"required": required,
	}

# --- the evaluator ---------------------------------------------------------

## One requirement against one set of facts.
##
## **Unknown types fail CLOSED.** A typo in a requirement record must never read
## as "no gate here" — an unrecognised gate is an impassable one, which is the
## only safe direction for a system whose whole job is deciding what is allowed.
func evaluate_requirement(requirement: Variant, facts: Dictionary = {}) -> Dictionary:
	if not (requirement is Dictionary) or (requirement as Dictionary).is_empty():
		return {
			"ok": false,
			"blocker_code": "invalid_requirement",
			"blocker_copy_key": "requirements.invalid_requirement",
			"current": null,
			"required": "requirement_record",
		}
	var req: Dictionary = requirement
	var crew: Variant = _crew_record(facts, req.get("crew_id"))
	var min_value: float = _num(req.get("min"))
	var current_day: float = _num(facts.get("current_day"))

	match str(req.get("type", "")):
		"crew_active":
			var active: bool = crew is Dictionary \
				and bool((crew as Dictionary).get("recruited", false)) \
				and str((crew as Dictionary).get("status", "")) == "active"
			return _result(req, active, active, true)

		"crew_loyalty_min":
			var loyalty: float = _num((crew as Dictionary).get("loyalty")) if crew is Dictionary else 0.0
			return _result(req, loyalty >= min_value, loyalty, min_value)

		"crew_rank_min":
			var rank: float = _num((crew as Dictionary).get("tier")) if crew is Dictionary else 0.0
			return _result(req, rank >= min_value, rank, min_value)

		"crew_tenure_days_min":
			# A record with no recruited day reports INFINITE tenure and passes.
			# That is canon (`Number.POSITIVE_INFINITY`) and it is the right
			# direction: tenure gates exist to make somebody wait, and there is
			# nobody to make wait if the record does not know when they arrived.
			var recruited_day: Variant = (crew as Dictionary).get("recruited_day") if crew is Dictionary else null
			var tenure: float = INF
			if recruited_day != null:
				tenure = maxf(0.0, current_day - _num(recruited_day))
			return _result(req, tenure >= min_value, tenure, min_value)

		"hustle_tier_min":
			var tiers: Variant = facts.get("hustle_tiers")
			var tier: float = 0.0
			if tiers is Dictionary:
				tier = _num((tiers as Dictionary).get(str(req.get("hustle_id"))))
			return _result(req, tier >= min_value, tier, min_value)

		"payroll_not_delinquent":
			# No record, or nothing outstanding, is not a blocker — and canon
			# reports `required` as a STRING here rather than a number, because
			# there is no threshold to compare against when nothing is owed.
			var missed_since: Variant = (crew as Dictionary).get("wage_missed_since") if crew is Dictionary else null
			if crew == null or missed_since == null or _num(missed_since) < 0.0:
				return _result(req, true, 0, "within_grace")
			var grace: float = DEFAULT_WAGE_GRACE_DAYS
			var supplied: Variant = facts.get("wage_grace_days")
			if supplied is int or supplied is float:
				if is_finite(float(supplied)):
					grace = float(supplied)
			var missed_days: float = maxf(0.0, current_day - _num(missed_since))
			return _result(req, missed_days <= grace, missed_days, grace)

		"crew_unassigned_today":
			var assignments: Variant = facts.get("assignments")
			var assigned_today := false
			if assignments is Dictionary:
				var entry: Variant = (assignments as Dictionary).get(str(req.get("crew_id")))
				assigned_today = entry is Dictionary \
					and _num((entry as Dictionary).get("day")) == current_day
			# `current` is whether they ARE assigned; `required` is false.
			return _result(req, not assigned_today, assigned_today, false)

		"planning_window_open":
			var slot: float = _num(facts.get("time_slots_today"))
			return _result(req, slot == 0.0, slot, 0)

		"proof_flag":
			var flag: bool = bool(_proofs(crew).get(str(req.get("key")), false))
			return _result(req, flag, flag, true)

		"proof_counter_min":
			var count: float = _num(_proofs(crew).get(str(req.get("key"))))
			return _result(req, count >= min_value, count, min_value)

		# --- v0.1.0 surface-visibility types --------------------------------
		#
		# Added for the progression gates, and added HERE rather than in a
		# second evaluator beside this one: the access layer authors semantic
		# requirement records and this file is the one thing that reads them.
		# Every type below resolves against a fact that already exists on
		# GameState, which is the standing condition for a new type landing at
		# all — a gate whose fact has not been built yet stays unbuilt.
		#
		# They read facts rather than crew records, so `crew` and `crew_id` go
		# unused; the shape of the answer is identical either way.

		"crew_count_min":
			# Recruited and active, counted by the adapter. Not `crew.size()`:
			# a record exists for anybody ever considered, and a crew member
			# who quit is not a crew member.
			var recruited: float = _num(facts.get("crew_count"))
			return _result(req, recruited >= min_value, recruited, min_value)

		"district_discovered":
			# Membership, not a threshold. `current` reports the boolean so a
			# caller can render "not yet" without knowing what a district is.
			var known: Variant = facts.get("districts_unlocked")
			var district_id := str(req.get("district_id", ""))
			var found: bool = known is Array \
				and district_id in (known as Array)
			return _result(req, found, found, true)

		"list_flips_min":
			# Completed 907List flips — the build's "has traded at all" fact.
			var flips: float = _num(facts.get("list_flips"))
			return _result(req, flips >= min_value, flips, min_value)

		"job_contacts_min":
			var contacts: float = _num(facts.get("job_contacts"))
			return _result(req, contacts >= min_value, contacts, min_value)

		"collection_non_empty":
			# One type for every "is there anything to show" gate, keyed on a
			# named count the adapter supplies. A population check is not a
			# progression fact and does not deserve a semantic type each.
			var size: float = _num(facts.get(str(req.get("collection", ""))))
			return _result(req, size > 0.0, size, 1)

		"fact_true":
			# The narrow escape hatch: a named boolean fact, for a surface whose
			# condition is a live flag rather than a count. Absent reads FALSE,
			# which is the closed direction.
			var flag: bool = bool(facts.get(str(req.get("fact", "")), false))
			return _result(req, flag, flag, true)

		"boost_target_discovered":
			# 0.4.0 PR A (SCR-D1): a Score naming a specific Boost target reads
			# the same DISCOVERY latch the Boost screen itself reads (batch
			# 14's DEAL axis) -- absent reads FALSE, same closed direction as
			# every other type here.
			var discovered: Variant = facts.get("boost_targets_discovered")
			var found: bool = discovered is Array \
				and str(req.get("target_id", "")) in (discovered as Array)
			return _result(req, found, found, true)

		# --- batch 14 elapsed-progress types --------------------------------
		#
		# Two thresholds on facts the run has always carried and no gate has
		# ever read: how many days have passed, and how many walks have been
		# taken. They are here rather than expressed as `collection_non_empty`
		# on a count, because a threshold is not a population check — "three
		# walks in" and "there is at least one of these" are different
		# questions, and a gate that says `min: 3` should read as one.

		"day_min":
			# `current_day` is already minted above, off the same fact every
			# tenure gate reads. Reading it a second time here would be a
			# second opinion about what day it is.
			return _result(req, current_day >= min_value, current_day, min_value)

		"wander_count_min":
			# Walks taken this RUN, not today. The day counter measures patience
			# and this one measures effort, which is why the Hustle ladder gates
			# some surfaces on one and some on the other.
			var walks: float = _num(facts.get("wander_count"))
			return _result(req, walks >= min_value, walks, min_value)

		# --- Dre Lending & Loan-Shark Progression, PR B --------------------
		#
		# `dre_access_tier` is a milestone latch (0 Unknown through 5 Operator,
		# design doc §7) and only ever moves forward in normal play, which is
		# what makes it safe as a ROUTE gate: `HUSTLE_SHARK` reads
		# `dre_access_tier_min` alone, deliberately never combined with
		# `dre_account_clear` on the same gate. A suspended account's status
		# is not monotonic — combining the two would re-close a route the
		# player already earned the moment Dre suspends them, exactly the
		# failure `surface_visibility.gd`'s own `ROUTE_GATES` header warns
		# against. `dre_account_clear` exists for narrower, non-route checks
		# (an offer's own availability) that are allowed to move backward.

		"dre_access_tier_min":
			var tier: float = _num(facts.get("dre_access_tier"))
			return _result(req, tier >= min_value, tier, min_value)

		"dre_account_clear":
			var status: String = str(facts.get("dre_account_status", "clear"))
			var clear: bool = status == "clear"
			return _result(req, clear, status, "clear")

		# PR E (DRE-ARC-04): "Collector + not suspended" is deliberately
		# wider than `dre_account_clear` -- the design doc's own words. An
		# active/due/extended/overdue account still passes; only a
		# suspended one blocks. Same monotonic-safe carve-out as
		# `dre_account_clear` above: gates an offer, never a route.
		"dre_account_not_suspended":
			var account_status: String = str(facts.get("dre_account_status", "clear"))
			var ok: bool = account_status != "suspended"
			return _result(req, ok, account_status, "not suspended")

		# PR D (DRE-ARC-03): "acceptable Dre disposition" gating a collection
		# offer -- monotonic-safe like `dre_access_tier_min` in the sense that
		# it gates an OFFER, not a route (same carve-out `dre_account_clear`
		# already has). An absent fact reads as 0.0 (neutral floor), the same
		# permissive default a fresh run with no Dre history should get.
		"dre_disposition_min":
			var disposition: float = _num(facts.get("dre_disposition"))
			return _result(req, disposition >= min_value, disposition, min_value)

	return {
		"ok": false,
		"blocker_code": "unsupported_requirement",
		"blocker_copy_key": "requirements.unsupported_requirement",
		"current": req.get("type") if req.has("type") else null,
		"required": "supported_requirement_type",
	}

## Every requirement in order, stopping at the first failure.
##
## **Short-circuiting is a feature, not an optimisation.** The player is shown
## one reason, and it must be the same reason every time for the same state —
## so the ORDER of the requirements array is the authored priority of the
## blockers, and evaluation must not keep going and pick a different one.
##
## An empty or missing list passes: no gates means no blockers.
func evaluate_requirements(requirements: Variant, facts: Dictionary = {}) -> Dictionary:
	if requirements is Array:
		for requirement in (requirements as Array):
			var evaluated: Dictionary = evaluate_requirement(requirement, facts)
			if not bool(evaluated["ok"]):
				return evaluated
	return {
		"ok": true,
		"blocker_code": null,
		"blocker_copy_key": null,
		"current": null,
		"required": null,
	}

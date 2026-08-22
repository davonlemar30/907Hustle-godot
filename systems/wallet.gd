extends RefCounted
## WalletSystem — the single runtime path for every Cash mutation.
##
## TI-003 §6. Before this, twenty-one lines across eleven systems wrote
## `gs.cash` directly. Cash was therefore a field anyone could move, which is
## fine while money is only a number and stops being fine the moment money has
## PROVENANCE — the moment the game needs to know whether the $400 you just put
## toward rent came from a job or from a stickup.
##
## ## One visible total, two buckets underneath
##
## Canon is explicit that this is a bookkeeping layer, not a second currency
## (game-core.js:596-606):
##
##     "Dirty/clean cash is a bookkeeping layer on top of the single pervasive
##      player.cash pool every existing reducer already reads/writes directly."
##
## So `gs.cash` remains the one number the HUD shows and the one number every
## blocker checks. `gs.dirty_cash` and `gs.clean_cash` ride underneath it, and
## the invariant canon names as core holds:
##
##     cash == dirty_cash + clean_cash
##
## ## Why `reconcile()` exists when every writer is migrated
##
## Canon does NOT migrate its ~35 call sites. It reconciles lazily instead, and
## says why: folding drift into the buckets "keeps `cash === dirtyCash +
## cleanCash` true without touching a single existing reducer."
##
## This port DOES migrate its writers — that is what this slice is for — so
## reconcile is not load-bearing for any shipped path. It is kept anyway, for
## two reasons that are not hypothetical:
##
##   1. The buckets are not persisted until FS-003.4. Until then every load
##      arrives with a real `cash` and two zeroed buckets, and something has to
##      classify that. `reconcile()` is that something.
##   2. A future direct writer is a bug the audit catches at test time, not at
##      runtime. Reconcile means such a bug costs a misclassified dollar rather
##      than a broken invariant.
##
## Canon's drift rule is followed exactly: untracked income defaults to dirty,
## untracked spending drains dirty first.
##
## ## The legacy-classification divergence, stated plainly
##
## Canon migrates its own pre-split saves the OTHER WAY from this port
## (game-core.js:2060-2066):
##
##     "Pre-v1.0 saves have no dirty/clean split. Treat all existing wealth as
##      unlaundered street money: nothing in pre-v1.0 gameplay ever laundered
##      anything, so this is the narratively honest default."
##
##     state.player.dirtyCash = value.player?.cash ?? 0;
##     state.player.cleanCash = 0;
##
## TI-003 §20 and §26 rule the opposite for this port: "Old Godot saves enter
## with prior aggregate Cash classified Clean." That is a deliberate, approved
## divergence — it declines to retroactively hand every existing save the
## Financial Pressure that dirty money now carries — and it is followed here,
## not canon. `classify_legacy_total()` is the one place it happens, so the
## decision is a single function rather than a rule scattered across a
## migration arm.
##
## ## A window this slice leaves open, on purpose
##
## The buckets are NOT persisted until FS-003.4, so a save/load round trip
## reclassifies the whole balance as clean. In provenance terms that is a
## laundromat: save, reload, and every dirty dollar comes back clean.
##
## It is shipped rather than worked around because nothing reads provenance to
## make a decision yet — Financial Pressure accumulates but is not consumed
## until FS-003.9, and no other system asks which bucket a dollar came from. The
## exploit is therefore unobservable in play, and the alternative was persisting
## two fields in a slice whose scope explicitly excludes the schema bump that
## FS-003.4 owns. Named here rather than discovered later.
##
## ## What this slice deliberately does NOT do
##
## No behaviour changes. Every migrated caller moves the same number in the
## same direction it moved before, and the parity suite is the proof. The
## provenance the buckets now carry is new INFORMATION, not a new RULE — nothing
## reads it to make a decision yet.

## Provenance of incoming money. Canon's two `add*Cash` entry points.
const DIRTY := "dirty"
const CLEAN := "clean"

## Spend policies, TI-003 §6.
##
## ROUTINE preserves the frozen source rule and is what canon's `spendCash`
## does: drain dirty first, then clean. It is the default because it is what
## every existing spend already did implicitly — there was only one pool.
const ROUTINE_DIRTY_FIRST := "routine_dirty_first"
## HIGH_VISIBILITY spends clean first. It is the policy for money that leaves a
## record somebody can read back: rent, the phone bill, bail, and the formal
## end of Recovery. Spending dirty money here is what Financial Pressure
## measures.
const HIGH_VISIBILITY_CLEAN_FIRST := "high_visibility_clean_first"

## TI-003 §6. Dirty cash spent in the open above this much in one transaction
## starts generating Financial Pressure.
##
## FS-003.13 Task 4 halves the free band and raises the rate. The authored
## $400 / 0.01 pair meant a single transaction had to move more than $450 of
## street money to register even one point, against a decay of one point a day —
## so the meter could only climb on a day the player paid a large bail, and
## FS-003.12 measured two of three profiles never reaching the fold at all. A
## mechanic that never fires is not a mechanic.
##
## $200 / 0.015 keeps the shape (a free band, then a linear rate) and moves the
## activation point to where the run actually spends: a $500 bail is now 5
## points rather than 1, and two of them inside a week clear the fold.
##
## Small routine dirty spending stays invisible, which is the half of TI-003 §6
## that must not move — see the free-band checks in the parity suite.
const FINANCIAL_PRESSURE_FREE_DIRTY := 200
## Pressure per dollar of dirty spend above the free band.
const FINANCIAL_PRESSURE_PER_DOLLAR := 0.015
## TI-003 §6: "Financial Pressure caps at 10."
const FINANCIAL_PRESSURE_MAX := 10

var gs: Node

func setup(game_state: Node) -> void:
	gs = game_state

## No player action of its own. Cash moves as a consequence of doing something
## else, never as the thing itself.
func can_handle(_action: String) -> bool:
	return false

func handle(_action: String, _payload: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "The wallet takes no actions."}

# --- reads ------------------------------------------------------------------

## The one number the HUD shows. A function as well as a field read so callers
## that want the wallet's opinion rather than GameState's have one.
func balance() -> int:
	return int(gs.cash)

func dirty_balance() -> int:
	return int(gs.dirty_cash)

func clean_balance() -> int:
	return int(gs.clean_cash)

## Whether a spend of this size can happen at all. Reads the visible total, not
## a bucket — a player with $500 can pay $500 of rent regardless of where it
## came from. The policy decides WHICH dollars move, never WHETHER they can.
func can_spend(amount: int) -> bool:
	var value: int = maxi(0, amount)
	return value <= int(gs.cash)

## True when the buckets and the visible total agree. The invariant, as a
## question — the audit asks it after every mutating check.
func is_balanced() -> bool:
	return int(gs.cash) == int(gs.dirty_cash) + int(gs.clean_cash)

# --- writes -----------------------------------------------------------------

## Money in, with its provenance declared at the call site.
##
## `context` is carried through to the transaction result and is not persisted.
## It exists so a caller can say WHY without the wallet needing to know about
## stickups, and so a later slice's receipts have something to quote.
func credit(amount: int, provenance: String, context: Dictionary = {}) -> Dictionary:
	reconcile()
	# Canon: `Math.max(0, Math.round(...))`. A negative credit is not a spend
	# spelled differently, it is a caller bug, and it stays a no-op here rather
	# than quietly draining a bucket.
	var value: int = maxi(0, amount)
	if value == 0:
		return _transaction(true, 0, 0, 0, provenance, context)

	gs.cash += value
	if provenance == CLEAN:
		gs.clean_cash += value
		return _transaction(true, value, 0, value, provenance, context)
	# Canon's default for anything not explicitly clean. Named rather than
	# assumed: an unrecognised provenance string lands here on purpose, because
	# money the game cannot vouch for is exactly what dirty means.
	gs.dirty_cash += value
	return _transaction(true, value, value, 0, DIRTY, context)

## Money out, under a declared policy.
##
## Returns `ok = false` and moves nothing when the player cannot cover it, which
## is canon's contract — `spendCash` returns a boolean and the caller decides.
## Every migrated call site already checked affordability through its own
## blocker before reaching here, so a false return means a blocker was missed
## rather than a player was refused.
func spend(amount: int, policy: String = ROUTINE_DIRTY_FIRST, context: Dictionary = {}) -> Dictionary:
	reconcile()
	var value: int = maxi(0, amount)
	if value == 0:
		return _transaction(true, 0, 0, 0, policy, context)
	if value > int(gs.cash):
		var refused := _transaction(false, 0, 0, 0, policy, context)
		refused["reason"] = "Not enough cash."
		return refused

	gs.cash -= value
	var dirty_used: int = 0
	var clean_used: int = 0
	if policy == HIGH_VISIBILITY_CLEAN_FIRST:
		clean_used = mini(int(gs.clean_cash), value)
		dirty_used = value - clean_used
	else:
		# ROUTINE, and anything unrecognised. Canon's `spendCash`: dirty first.
		# Defaulting an unknown policy to routine keeps a typo from silently
		# turning an ordinary purchase into a laundering signal.
		dirty_used = mini(int(gs.dirty_cash), value)
		clean_used = value - dirty_used

	gs.dirty_cash = maxi(0, int(gs.dirty_cash) - dirty_used)
	gs.clean_cash = maxi(0, int(gs.clean_cash) - clean_used)

	var tx := _transaction(true, value, dirty_used, clean_used, policy, context)
	# TI-003 §6. Only high-visibility spending generates Pressure: routine
	# spending creating it is regression #24 on TI-003's own list.
	if policy == HIGH_VISIBILITY_CLEAN_FIRST:
		tx["financial_pressure_gain"] = _apply_financial_pressure(dirty_used)
	return tx

## Dirty money spent where it can be read back.
##
## TI-003 §6, at FS-003.13's constants:
##
##     financial_pressure_gain = round((dirty_used - FREE_DIRTY) * PER_DOLLAR)
##
## The rollover that decays this and folds it into Heat is §17, which is
## FS-003.9's slice. This is the gain side only — the number moves, and nothing
## reads it yet.
func _apply_financial_pressure(dirty_used: int) -> int:
	if dirty_used <= FINANCIAL_PRESSURE_FREE_DIRTY:
		return 0
	var over: int = dirty_used - FINANCIAL_PRESSURE_FREE_DIRTY
	var gain: int = int(round(float(over) * FINANCIAL_PRESSURE_PER_DOLLAR))
	if gain <= 0:
		return 0
	gs.financial_pressure = clampi(
		int(gs.financial_pressure) + gain, 0, FINANCIAL_PRESSURE_MAX)
	return gain

## Fold any drift between the visible total and the buckets back into the
## buckets. Canon's `reconcileCash`, rule for rule.
##
## Canon calls this at the top of every player-facing action. This port calls it
## at the top of every wallet mutation, which is the same moment for every path
## that goes through the wallet and strictly more often for the ones that do
## not. Cheap, and it means no caller has to remember.
func reconcile() -> void:
	var known: int = int(gs.dirty_cash) + int(gs.clean_cash)
	var drift: int = int(gs.cash) - known
	if drift == 0:
		return
	if drift > 0:
		# Canon: "untracked income defaults to dirty".
		gs.dirty_cash = int(gs.dirty_cash) + drift
		return
	# Canon: "untracked spending is assumed dirty-first".
	var deficit: int = -drift
	var from_dirty: int = mini(int(gs.dirty_cash), deficit)
	gs.dirty_cash = int(gs.dirty_cash) - from_dirty
	deficit -= from_dirty
	if deficit > 0:
		gs.clean_cash = maxi(0, int(gs.clean_cash) - deficit)
	# Canon folds Financial Pressure in here too. This port does not: canon's
	# reconcile is its ONLY view of spending, because canon never migrated its
	# writers. This port's spends declare their own policy at the call site, so
	# charging Pressure here as well would double-charge every high-visibility
	# spend and charge every routine one. Reconcile classifies; it does not
	# judge.

## Classify a total that predates the split.
##
## TI-003 §20 step 2-3 and §26: "Old Godot saves enter with prior aggregate Cash
## classified Clean." Canon rules the opposite for its own pre-v1.0 saves — see
## the file header. This port follows TI-003.
##
## Called on load until FS-003.4 persists the buckets, and by that slice's
## migration arm afterwards. One function so the divergence has one home.
func classify_legacy_total() -> void:
	gs.clean_cash = maxi(0, int(gs.cash))
	gs.dirty_cash = 0

func _transaction(ok: bool, amount: int, dirty_used: int, clean_used: int,
		label: String, context: Dictionary) -> Dictionary:
	return {
		"ok": ok,
		"amount": amount,
		"dirty_used": dirty_used,
		"clean_used": clean_used,
		"balance_after": int(gs.cash),
		"dirty_after": int(gs.dirty_cash),
		"clean_after": int(gs.clean_cash),
		"financial_pressure_gain": 0,
		"visibility": label,
		"source_id": str(context.get("source_id", "")),
		"context": context,
	}

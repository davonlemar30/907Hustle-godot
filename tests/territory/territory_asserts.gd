extends RefCounted
## The shared assert helper for `tests/territory/` (`86bbjxtjb`).
##
## ## Why FS-002's coverage does not go in `parity_runner.gd`
##
## That file is 20,288 lines and about ten minutes a run. FS-002 has twelve
## slices of coverage to add to it. A suite you cannot afford to run while you
## are working is a suite you run once, at the end, when it is most expensive to
## be wrong — and the parity runner has earned its length honestly, replaying
## recorded oracle truth. Territory's rules are not oracle truth; they are this
## port's own, and they belong somewhere that answers in seconds.
##
## So this is a second harness, not a fork of the first. It shares the shape
## (`_check` / count / PASS line / exit code) so CI treats it identically and
## nobody has to learn a second vocabulary.
##
## ## What is in here rather than in the runner
##
## Everything that more than one slice will need. FS-002 runs from .1 to .12 and
## the four things below are already needed twice each:
##
##   - `market_cursor_unchanged()`, because rule 2 demands a market-RNG
##     non-drift proof from every slice that touches Territory randomness and
##     there was no shared tool for it. Writing that assertion by hand in twelve
##     places is twelve chances to compare the wrong field.
##   - `soldiers_conserved()`, the accounting invariant.
##   - `capacity_respected()`, the rule `86bbjxtb6` broke.
##   - `near()`, because income is computed in floats and rounded at the edge.
##
## ## The failure messages carry the numbers
##
## `_check("income is right", a == b)` tells you a check failed and nothing
## else, which is a bad trade for one saved line. Every assertion here reports
## what it got and what it wanted, because the first thing anybody does with a
## red suite is go looking for exactly that.

var checks: int = 0
var failures: Array[String] = []

## The plain form. Prefer one of the typed assertions below where one fits —
## they print the values and this cannot.
func check(label: String, condition: bool) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
	return condition

func eq_int(label: String, actual: int, expected: int) -> bool:
	return check("%s (got %d, wanted %d)" % [label, actual, expected], actual == expected)

func eq_str(label: String, actual: String, expected: String) -> bool:
	return check("%s (got '%s', wanted '%s')" % [label, actual, expected], actual == expected)

func eq_bool(label: String, actual: bool, expected: bool) -> bool:
	return check("%s (got %s, wanted %s)" % [label, actual, expected], actual == expected)

## Floats compared with a tolerance, because Territory income is a float sum
## rounded at the edge and heat is fractional by design (see systems/heat.gd on
## why nothing in that file rounds).
func near(label: String, actual: float, expected: float, tolerance: float = 0.0001) -> bool:
	return check("%s (got %f, wanted %f +/- %f)" % [label, actual, expected, tolerance],
		absf(actual - expected) <= tolerance)

## Rule 2, as a function: "Territory randomness must not advance the market
## xorshift stream — prove it with a fixture, every time."
##
## `gs.rng_state` IS that stream's cursor: `economy.evolve()` opens a stream on
## it, walks every area, and writes the cursor back (`economy.gd:490,498`). A
## Territory action that drew from the same stream would move it, every
## subsequent market price in the run would shift, and NOTHING else in the build
## would report it — the prices would still look like prices.
##
## Takes the body as a Callable rather than returning a snapshot to compare
## later, so the "before" and the "after" cannot drift apart in the caller and a
## check cannot forget its own second half.
func market_cursor_unchanged(label: String, gs: Node, body: Callable) -> bool:
	var before: int = int(gs.rng_state)
	body.call()
	var after: int = int(gs.rng_state)
	return check("%s — market cursor moved (%d -> %d)" % [label, before, after],
		before == after)

## Soldier conservation: `soldiers_idle + sum(posted)` is the whole roster, and
## no Territory action may mint or lose one.
##
## `gs.soldiers_total()` computes exactly that sum, so this asserts the TOTAL
## against a number the caller carried across the transition rather than
## re-deriving it from the same function on both sides — which would pass no
## matter what the transition did.
func soldiers_conserved(label: String, gs: Node, expected_total: int) -> bool:
	var posted: int = 0
	for rec in gs.territory_nodes.values():
		posted += int((rec as Dictionary).get("soldiers", 0))
	var idle: int = int(gs.soldiers_idle)
	checks += 1
	if idle + posted == expected_total and gs.soldiers_total() == expected_total:
		return true
	failures.append("%s — idle %d + posted %d = %d, wanted %d (soldiers_total() says %d)"
		% [label, idle, posted, idle + posted, expected_total, gs.soldiers_total()])
	return false

## The rule `86bbjxtb6` broke: the roster never exceeds the cap the held corners
## pay for. Every path that RAISES the count checked this; the one that LOWERS
## the cap did not.
func capacity_respected(label: String, gs: Node) -> bool:
	return check("%s — %d soldiers under a capacity of %d"
		% [label, gs.soldiers_total(), gs.soldier_capacity()],
		gs.soldiers_total() <= gs.soldier_capacity())

## Neither posted nor idle counts may go negative. Cheap, and it catches the
## whole class of "returned the soldier twice" arithmetic that conservation
## alone can miss when two errors cancel.
func no_negative_soldiers(label: String, gs: Node) -> bool:
	var ok: bool = int(gs.soldiers_idle) >= 0
	for id in gs.territory_nodes.keys():
		if int((gs.territory_nodes[id] as Dictionary).get("soldiers", 0)) < 0:
			ok = false
	return check("%s — no negative soldier count anywhere" % label, ok)

## The PASS line and the exit code, in the shape the other two harnesses use so
## CI can gate this one with the same `grep -q "^<name>: PASS"`.
func report(suite_name: String, tree: SceneTree) -> void:
	if failures.is_empty():
		print("%s: PASS — %d checks, 0 failures" % [suite_name, checks])
		tree.quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("%s: FAIL — %d checks, %d failures" % [suite_name, checks, failures.size()])
	tree.quit(1)

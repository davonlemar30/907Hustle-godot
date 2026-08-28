extends RefCounted
## Word of Mouth's ramp numbers (0.1.2), split out from `systems/tips.gd` for
## the same reason `wander_events.gd` is split from `systems/wander.gd`: the
## save validator needs the cap to clamp a corrupt `tip_misses` and a
## RefCounted with no tree is the cheap way to hand it that number without
## also handing it a `gs`/`gm` dependency it does not need.
##
## The shape is `wander_misses`'s ramp, renamed. Same argument, applied to a
## text instead of a walk: a budget roll that just fired has nothing left to
## prove, and a budget roll on its third miss in a row is a drought the player
## has already felt.

const BUDGET_BASE := 0.45
const BUDGET_PER_MISS := 0.15
const BUDGET_CAP := 0.85

static func miss_ceiling() -> int:
	return int(ceil((BUDGET_CAP - BUDGET_BASE) / BUDGET_PER_MISS))

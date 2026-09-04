extends RefCounted
## Market causes -- why the board moved (The World Speaks, PR 5, WS-D5).
##
## The overnight walk is a random walk and stays one. What changes is that
## when the board the player is standing on moves hard, the feed says why,
## in a line that sounds like somebody on the block heard something. The
## line is flavor over a number the walk already rolled; it never moves a
## price. One line a day at most, only for the biggest mover in the
## player's own district, only when the move was big enough to notice.
##
## Lines are keyed by direction, then by product family, then general.
## Anchorage-specific where it can be: the PFD in October, the slope
## schedule, a bust on Muldoon, the ferry, the weather.

const MOVE_THRESHOLD := 0.15

const UP := {
	"weed": [
		"Weed is up. Somebody's grow on the Hillside got raided and half of Spenard is dry.",
		"Weed is up. The dispensaries raised prices and the street followed like it always does.",
		"Weed is up. A guy who supplied three blocks moved to Wasilla with no notice.",
	],
	"pills": [
		"Pills are up. A pharmacy on Northern Lights tightened up and the whole east side is asking around.",
		"Pills are up. Somebody's plug went to jail in Fairbanks. Word got here before he did.",
	],
	"cocaine": [
		"Coke is up. A package didn't make the flight from Seattle and everybody who had some knows it.",
		"Coke is up. Slope schedule turned over and a few hundred men with a paycheck just landed at Ted Stevens.",
	],
	"molly": [
		"Molly is up. There's a show at the Egan this weekend and the kids are paying whatever.",
	],
	"lean": [
		"Lean is up. The cough syrup got moved behind the counter at every Fred Meyer in town.",
	],
	"shrooms": [
		"Shrooms are up. Somebody's whole harvest went bad in a closet on Fireweed.",
	],
	"_": [
		"Prices are up. PFD checks hit this week and everybody is spending it like it's owed.",
		"Prices are up. Cops swept Mountain View and the people who buy there are buying here now.",
		"Prices are up. It's been forty below for a week and nobody wants to go anywhere to get anything.",
	],
}

const DOWN := {
	"weed": [
		"Weed is down. Somebody got greedy and flooded Spenard with outdoor from the Valley.",
		"Weed is down. A new dispensary opened on Spenard Road and undercut the corner by half.",
	],
	"pills": [
		"Pills are down. A guy's grandmother passed and left a medicine cabinet nobody is asking questions about.",
	],
	"cocaine": [
		"Coke is down. Two people are competing for the same block and neither one is smart enough to stop.",
	],
	"molly": [
		"Molly is down. The show got cancelled and a kid is stuck holding a hundred pills.",
	],
	"lean": [
		"Lean is down. Somebody bought too much and needs it gone before rent.",
	],
	"shrooms": [
		"Shrooms are down. It rained for a week and the woods behind the university did their thing.",
	],
	"_": [
		"Prices are down. Everybody spent the PFD in a week and now nobody has money for anything.",
		"Prices are down. Word is somebody big is moving weight through Muldoon and undercutting the whole city.",
		"Prices are down. Nobody's buying. Nobody's saying why. Nobody has to.",
	],
}

static func line_for(product_id: String, direction: String, seed: int) -> String:
	var table: Dictionary = UP if direction == "up" else DOWN
	var lines: Array = table.get(product_id, [])
	# The general lines are mixed in, so a product with one line of its own
	# still reads three different ways across a run.
	lines = lines + (table.get("_", []) as Array)
	if lines.is_empty():
		return ""
	return str(lines[absi(seed) % lines.size()])

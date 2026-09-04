extends "res://ui/screens/surface_base.gd"
## How to Play — the four-part rhythm of One Good Run.
##
## Straight port of the web build's `Help` component (ui.built.js:15716): four
## cards, no state, no actions. The copy is canon's verbatim — this screen is
## the game explaining its own contract to the player, and paraphrasing it would
## be a rules change written as an edit.
##
## Canon gates the "Market visits" card on `state.market.visible`, which hides
## trading from a run that has not discovered it yet. This build has no such
## gate — the Street Market is on the Hustle hub from Day 1 — so the card always
## shows. Named rather than dropped: if market discovery is ever ported, this is
## where the gate goes back.
##
## Two lines describe systems that do not exist here yet, and they are kept
## because they are canon's description of the game, not of this port:
##   - "Week Zero establishes your life in Spenard" — no Week Zero script.
##   - "when you decide to call the final score" — no voluntary-exit action;
##     this build's run ends on eviction only.
## SA-D1 (1.1.0): rewritten to the game that exists. The canon cards described
## Week Zero and locked market prices, neither of which this build has, and a
## help screen that is wrong about the game is worse than none.

## Canon's four cards, in canon's order, with canon's headings.
const CARDS := [
	{
		"heading": "THE DAY",
		"body": "Four parts: morning, afternoon, evening, night. Everything you do takes one. Looking at a screen costs nothing. Walking the block, working a shift, riding to another district, sitting with somebody -- each one is a part of the day gone.",
	},
	{
		"heading": "THE HOUSE",
		"body": "Rent is weekly and Yalonda does not do reminders past the first. Three days late is a warning; the third warning is the door. The phone bill goes quiet before it cuts you off. Both are on the Phone under Bills.",
	},
	{
		"heading": "THE NAME",
		"body": "Nobody, New Face, Known, Player, Connected, Boss. It is not a number you fill. It is what the people you have met have written down about you, added up. Crew needs Known. A corner needs Player. The way out needs Boss.",
	},
	{
		"heading": "HOW IT ENDS",
		"body": "The way out: clean money, priced by what you built, once you are Boss. The three ways it ends on you: the third house warning, the third serious booking, or Curtis at the door three mornings after his people first parked outside. Every one of them says so before it happens.",
	},
]

func _build_body() -> void:
	for entry in CARDS:
		body.add_child(_card(str(entry["heading"]), str(entry["body"])))
	body.add_child(button("BACK TO MORE", false, _on_back, 44))

func _card(heading: String, text: String) -> Control:
	# Built on surface_base.gd's card(), so TOUCH-D3a's PASS fix already
	# applies here -- nothing to change in this file.
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	v.add_child(label(heading, "CardTitle", 13, CREAM))
	v.add_child(label(text, "Muted", 12, MUTED, true))
	return c

func _on_back() -> void:
	nav.go_to(nav.MORE)

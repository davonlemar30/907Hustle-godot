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
## Both are true of 907Hustle and will be true of this build. Rewriting them to
## match today's feature set would make the screen wrong twice: wrong now about
## the game, and wrong later about itself.

## Canon's four cards, in canon's order, with canon's headings.
const CARDS := [
	{
		"heading": "YOUR RUN",
		"body": "Each day contains Morning, Afternoon, Evening, and Night. Week Zero establishes your life in Spenard. After that the run is open: it ends when you cannot pay what you owe, when your health or Heat runs out, or when you decide to call the final score.",
	},
	{
		"heading": "MARKET VISITS",
		"body": "Buy and sell several times at locked prices. Walking away after a trade uses one part of day. Looking costs nothing.",
	},
	{
		"heading": "MAJOR ACTIONS",
		"body": "Travel, recovery, meetings, debt payments, and operations advance to the next part of day. Resolve an event choice without paying a second time cost.",
	},
	{
		"heading": "THE PRESSURE PHASE",
		"body": "Protect working capital, manage Heat and Health, build relationships, and decide whether territory or a clean exit is worth the risk.",
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

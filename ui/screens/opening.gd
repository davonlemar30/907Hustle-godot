extends Control
## The opening — one screen between naming yourself and the first morning.
##
## Standalone like Title and Name Entry: no chrome, no HUD, no bottom nav, so it
## does not extend `screen_base.gd`.
##
## ## Why it exists now rather than earlier
##
## It was filed as a playtest finding months ago and it was a nice-to-have then.
## Batch 14 made it load-bearing. Before that batch a fresh Home carried six
## income surfaces, a market snapshot and a turf card — too much, badly ordered,
## but it did at least announce that the game had things in it. After it, Day 1
## is a Wander card and a locked Jobs row, which is the right shape and says
## almost nothing about itself.
##
## So this screen has exactly three jobs, and they are the three questions a
## player has after pressing BEGIN THE RUN:
##
##   WHERE AM I    the room, the district, the morning
##   WHAT IS COMING the rent, on a date, with the number on it
##   WHAT DO I DO  go outside. It is the only thing on the screen, and after
##                 batch 14 it is very nearly the only thing in the game
##
## ## Everything is read, nothing is written
##
## Every number below comes off GameState — the rent, the day it lands, what is
## in the pocket, where the run opens. The scene carries layout and no values,
## which is the standing rule for .tscn files in this build, and it means the
## screen cannot promise a rent the obligations system will not charge.
##
## It also writes NOTHING. `reset_to_new_game()` has already run by the time
## this is shown, and a screen that mutated the run it is introducing would be
## the one thing able to make a fresh run not fresh.
##
## ## Shown once, structurally
##
## There is no "seen the intro" flag and there is deliberately no need for one:
## the only route here is `name_entry.gd::_on_begin()`, and naming yourself is
## something you do once per run. CONTINUE RUN on the title screen goes straight
## to `go_to_game()` and never passes through here, which is correct — a player
## resuming day 12 does not need to be told where they woke up on day 1.

@onready var gs: Node = get_node("/root/GameState")
@onready var nav: Node = get_node("/root/ScreenManager")

func _ready() -> void:
	var go := $Pad/V/Go as Button
	if go != null:
		go.pressed.connect(_on_go)
	_bind()

func _bind() -> void:
	_write("Pad/V/Head", gs.street_name.to_upper())
	_write("Pad/V/Sub", "%s   ·   DAY %d   ·   %s"
		% [str(gs.current_district().get("name", "SPENARD")), int(gs.day),
			str(gs.time_slot).capitalize()])

	# Three beats, in the order the questions arrive. The labels are authored;
	# every number in them is read.
	_write("Pad/V/Beats/B1/K", "THE ROOM")
	_write("Pad/V/Beats/B1/T",
		"Yalonda's spare room, and $%d in your pocket. No job, nobody who owes you anything."
			% int(gs.cash))

	_write("Pad/V/Beats/B2/K", "THE CLOCK")
	_write("Pad/V/Beats/B2/T", _rent_line())

	_write("Pad/V/Beats/B3/K", "TODAY")
	_write("Pad/V/Beats/B3/T",
		"Nobody has told you about anything yet. Go outside and walk the block — "
		+ "what you find is what opens up.")

	var go := $Pad/V/Go as Button
	if go != null:
		go.text = ">>  STEP OUTSIDE"

## The rent, said the way a person would say it, with the real number and the
## real number of days off GameState.
func _rent_line() -> String:
	var days: int = maxi(0, int(gs.rent_due_day) - int(gs.day))
	if days <= 0:
		return "Rent is $%d and it is due today." % int(gs.WEEKLY_RENT)
	if days == 1:
		return "Rent is $%d and Yalonda wants it tomorrow." % int(gs.WEEKLY_RENT)
	return "Rent is $%d and Yalonda wants it in %d days. She has been patient. That is not the same as generous." \
		% [int(gs.WEEKLY_RENT), days]

## Named `_write` rather than `_set`: `Object` already declares a virtual
## `_set(StringName, Variant) -> bool`, and a same-named method with a different
## signature is a PARSE ERROR, not an override. The script simply does not load,
## and the scene still instantiates — with no script on it, which is why the
## screen-smoke gate reported 24/24 while this file was broken.
func _write(path: String, text: String) -> void:
	var node := get_node_or_null(path) as Label
	if node != null:
		node.text = text

func _on_go() -> void:
	nav.go_to_game()

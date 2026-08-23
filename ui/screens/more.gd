extends "res://ui/screens/surface_base.gd"
## More — the menu that holds everything the four other tabs do not.
##
## Ported from the web build's `More` root (ui.built.js:15809). Canon's shape is
## a list of `MenuRow`s (14908): title, description, a right-aligned status, and
## a `›`. The menu is also how a player learns what the game still has, which is
## why canon disables an unreachable row rather than hiding it.
##
## **This screen is a signpost, not a system.** Every row leads somewhere that
## already exists; nothing here computes anything the destination does not
## already own. The statuses are one-line reads of live state so the menu can be
## scanned instead of walked.
##
## All six of canon's rows ship as of Phase 5d. Recovery is conditional, exactly
## as canon has it:
##
##   - ~~Recovery~~ — **shipped in Phase 5d**. It keeps canon's availability gate
##     rather than showing always: the row appears once health has dropped or
##     Heat has risen above 1, and then stays for the rest of the run
##     (`features.recovery.available`, latched by `recovery_introduced`).
##   - ~~Character~~ — **shipped in Phase 5c part 2**, once attributes were real
##     enough for it to say anything. Its arrest record and reputation history
##     are still absent, and the screen names both.
##
## Routing divergences, each because canon's destination is a page this build
## does not have:
##
##   1. **Finances → Shark.** Canon's Finances page is cash, debt, Shark notes
##      and financial risk, and it opens the Safehouse. No lender system, no
##      safehouse; the Shark screen is where this build's money decisions
##      actually live, and cash/debt are already in the HUD on every screen.
##   2. **Operations → Turf.** Canon's Operations is a sub-menu — safehouse,
##      territory, soldiers, gear, and Rob. Territory and soldiers are Turf;
##      Rob is Stickup and is already on the Hustle hub; safehouse and gear do
##      not exist. Turf is the only one of the five with no other entrance.
##   3. **Operations is never locked.** Canon gates it on `state.base.controlled`
##      — leasing North Star Garage for a deposit — and there is no base system
##      to lease. Gating on nothing and calling it locked would be a lie, so the
##      row is simply open. Canon's hint reads "Lease North Star Garage to
##      unlock Operations." — put it back with the gate.
##   4. **Crew shows LOCKED before the first hire.** Canon reveals the row once
##      any crew member is introduced OR recruited, and "introduced" is not
##      tracked here. v0.1.0 splits the difference the way the progression-gate
##      pass asks: the row is always present, so the player can see the screen
##      exists, and it is locked with "Recruit your first crew member" until it
##      would say anything. Hiding it outright is the option both canon and the
##      design pass reject — an empty crew panel teaches nothing, but a missing
##      one teaches less.
##
## Canon's MenuRow also has a `disabled` state, rendering the row greyed with
## the feature's hint under it. v0.1.0 is when the first gated row arrived, and
## it is NOT reimplemented here: `screen_base.apply_surface_gate()` renders that
## state for every gated surface in the build, and Crew opting into it is one
## call rather than a second greying rule that only More knows about.
##
## What is deliberately NOT here: a People row. Canon's More does not have one,
## People is already reachable from Street and from the Phone's Contacts
## section, and using it to paper over the missing Character row would be
## inventing IA rather than porting it.

func _build_body() -> void:
	# Finances IS the Shark screen — see note 1 above — so it carries the Shark
	# gate. Batch 14 hid the Hustle hub's Shark row until day 5 and left this
	# door open, which is exactly the disagreement the design pass's second
	# improvement exists to forbid: two entrances to one surface answering
	# differently. One registry entry, both doors.
	var finance_row: Control = _menu_row(
		"Finances",
		_finance_summary(),
		"Cash, debt, Shark notes, and financial risk." if gs.debt > 0 else "Cash and financial risk.",
		nav.SHARK)
	body.add_child(finance_row)
	apply_surface_gate(ACCESS.HUSTLE_SHARK, finance_row)

	body.add_child(_menu_row(
		"Operations",
		_ops_summary(),
		"Territory, soldiers, and the corners you hold.",
		nav.TURF))

	# The Crew row carries the same gate as the Crew route and as Street's
	# People row, from the same registry entry — three doors, one verdict.
	#
	# **This row never rendered.** `_menu_row` BUILDS a card and returns it; it
	# is `body.add_child()` at every other call site that puts one on the screen.
	# This one passed the card straight into `apply_surface_gate`, which gated an
	# orphan — so from v0.1.0 until batch 15 the More menu had no Crew row at
	# all, locked or otherwise, and the paragraph above arguing that it should be
	# LOCKED rather than hidden was describing something nobody could see.
	#
	# Parented FIRST and gated second, which is the order every other gated
	# surface in the build uses and the order that makes the mistake impossible:
	# a row is on the screen, and then a gate decides how it looks.
	var crew_row: Control = _menu_row(
		"Crew",
		"%d/%d active" % [gs.recruited_crew().size(), gs.crew_capacity()],
		"Wages, loyalty, tiers, and who answers when it gets loud.",
		nav.CREW)
	body.add_child(crew_row)
	apply_surface_gate(ACCESS.MENU_CREW, crew_row)

	# Canon shows Recovery only once it is relevant, and then keeps showing it.
	if _recovery_available():
		body.add_child(_menu_row(
			"Recovery",
			"Health %d" % gs.health,
			"Treat injuries or lay low to reduce Heat.",
			nav.RECOVERY))

	body.add_child(_menu_row(
		"Character",
		_identity_label(),
		"Rank, what you are good at, and what the block remembers.",
		nav.CHARACTER))

	body.add_child(_menu_row(
		"Help",
		"Available",
		"Time, trading, major actions, and how a run ends.",
		nav.HELP))

## Canon's opsSummary is `${blocks} blocks · ${soldiers} soldiers`, unpluralised
## — it renders "1 blocks". Canon pluralises elsewhere (the Phone's text count
## does), so this is an inconsistency rather than a house style, and at this
## size the status reads as a stat line where "1 BLOCKS" looks like a defect.
## Pluralised here, and recorded rather than silently corrected.
func _ops_summary() -> String:
	var blocks: int = gs.territory_nodes.size()
	var soldiers: int = gs.soldiers_total()
	return "%d %s · %d %s" % [
		blocks, "block" if blocks == 1 else "blocks",
		soldiers, "soldier" if soldiers == 1 else "soldiers",
	]

## Canon's financeSummary. `cleanCash` is not ported — this build has one cash
## pool, not a clean/dirty split — so the no-debt case reads plain cash.
func _finance_summary() -> String:
	if gs.debt <= 0:
		return "$%s" % _commas(gs.cash)
	if gs.debt_due_days <= 0:
		return "Debt due"
	return "Debt Day %d" % (gs.day + gs.debt_due_days)

## Canon features.recovery.available: `health < 100 || heat > 1 ||
## flags.recoveryIntroduced`. The latch is the interesting third: once Recovery
## has mattered it stays on the menu, so healing back to 100 does not take away
## the screen you just used. GameState reconciles the latch before notification;
## this presentation selector remains a read and cannot mutate after autosave.
func _recovery_available() -> bool:
	return gs.recovery_available()

## Canon's More shows the Street Identity as this row's status, which is the
## only place in the build it appears outside the Character screen itself.
func _identity_label() -> String:
	var attrs: Object = _gm.system("attributes")
	return "New Face" if attrs == null else str(attrs.street_identity())

const ACCESS := preload("res://autoload/surface_visibility.gd")

## Canon's MenuRow: title and description on the left, status and a chevron on
## the right.
func _menu_row(title: String, status: String, description: String, route: String) -> Control:
	var c := card()
	# A column inside the card, so a gated row has somewhere to put its lock
	# hint that is under the row rather than beside the chevron.
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(label(title.to_upper(), "CardTitle", 14, CREAM))
	left.add_child(label(description, "Muted", 11, MUTED, true))

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	right.add_child(label(status.to_upper(), "Mono", 11, AMBER))
	right.add_child(label("›", "Muted", 14, MUTED))

	tap_connect(c, _on_open.bind(route))
	return c

func _on_open(route: String) -> void:
	nav.go_to(route)

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
## Canon has six rows. This build ships four, and the two it drops are dropped
## rather than stubbed:
##
##   - **Recovery** (canon: treat injuries, lay low to shed Heat) — there is no
##     recovery system. Canon itself hides this row until the feature is
##     relevant (`features.recovery.available`), so an absent row is the shape
##     canon already uses for it.
##   - **Character** (canon: street identity, attributes, arrest record, recent
##     reputation) — needs `streetIdentity`, `attributeLabels`, `arrestRecord`
##     and the behavior history, none of which are ported. Attributes are still
##     pinned at canon's neutral defaults across every system, so a Character
##     screen today would be five rows of "1" and an empty record.
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
##   4. **Crew always shows.** Canon reveals the row once any crew member is
##      introduced OR recruited; "introduced" is not tracked here. Gating on
##      recruited alone would hide the entry precisely when the player has no
##      crew and most needs to find the screen, so it shows with a 0/2 status.
##
## Canon's MenuRow also has a `disabled` state, which renders the row greyed
## with the feature's hint in place of its description. It is NOT ported,
## because no row in this build has a gate it can fail — every destination here
## exists and is always reachable. Adding it back when the first gated row
## arrives is four lines; shipping an untested branch with no caller is worse
## than shipping neither.
##
## What is deliberately NOT here: a People row. Canon's More does not have one,
## People is already reachable from Street and from the Phone's Contacts
## section, and using it to paper over the missing Character row would be
## inventing IA rather than porting it.

func _build_body() -> void:
	body.add_child(_menu_row(
		"Finances",
		_finance_summary(),
		"Cash, debt, Shark notes, and financial risk." if gs.debt > 0 else "Cash and financial risk.",
		nav.SHARK))

	body.add_child(_menu_row(
		"Operations",
		_ops_summary(),
		"Territory, soldiers, and the corners you hold.",
		nav.TURF))

	body.add_child(_menu_row(
		"Crew",
		"%d/%d active" % [gs.recruited_crew().size(), gs.CREW_CAPACITY],
		"Wages, loyalty, tiers, and who answers when it gets loud.",
		nav.CREW))

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
	var blocks: int = gs.held_blocks.size()
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

## Canon's MenuRow: title and description on the left, status and a chevron on
## the right.
func _menu_row(title: String, status: String, description: String, route: String) -> Control:
	var c := card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	c.add_child(h)

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

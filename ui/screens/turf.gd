extends "res://ui/screens/surface_base.gd"
## Turf — the block map.
##
## Each row states the trade plainly, because the trade is the game here: a
## corner earns per soldier with diminishing returns, and costs heat every night
## just for being yours. A block you cannot staff is a pure liability, and the
## screen should make that obvious before the player buys one.

## FS-002.3: the authored board, off the canonical data file rather than
## `gs.spenard_blocks` (deleted).
const TERRITORY_DEFS := preload("res://data/territory_definitions.gd")

## BR-D4: which district's board is showing. UI-only; defaults to where the
## player is standing, because that is the board they can act on.
var _district: String = ""

func _build_body() -> void:
	var sys: Object = _gm.system("territory")
	if sys == null:
		return
	if _district.is_empty() or gs.district_by_id(_district).is_empty():
		_district = str(gs.current_district_id)

	body.add_child(_status_card(sys))
	body.add_child(_district_tabs(sys))
	var district: Dictionary = gs.district_by_id(_district)
	body.add_child(section("%s %s" % [str(district.get("name", _district)).to_upper(),
		TERRITORY_DEFS.kind_label(_district)]))
	body.add_child(_district_card(sys))
	for b in TERRITORY_DEFS.nodes_in(_district):
		body.add_child(_block_row(sys, b))

	# A corner you hold that the authored table does not carry (86bbjxtab).
	# The loop above walks the TABLE, so a held id with no definition rendered
	# nowhere: it counted in "6 HELD", it charged heat every night, and it had
	# no row and therefore no GIVE IT UP button. Invisible and unabandonable is
	# the worst pair of properties a liability can have.
	var orphans: Array = []
	for id in gs.territory_nodes.keys():
		if gs.block_by_id(str(id)).is_empty():
			orphans.append(str(id))
	if not orphans.is_empty():
		orphans.sort()
		body.add_child(section("UNRECOGNISED"))
		for id in orphans:
			body.add_child(_orphan_row(str(id)))

## A held id with no definition. Earns nothing (`block_income` returns 0 for it)
## and can only be given up, which is the one thing the player needs to do with
## it. Deliberately plain: this is a fault state, not a feature.
func _orphan_row(id: String) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)
	v.add_child(label(id, "CardTitle", 13, RED))
	var n: int = int((gs.territory_nodes[id] as Dictionary).get("soldiers", 0))
	v.add_child(label("%d posted  ·  earning nothing  ·  this corner is not on the map any more"
		% n, "Muted", 11, RED, true))
	v.add_child(button("GIVE IT UP", false, _on_abandon.bind(id), 40))
	return c

## BR-D4: one tab per district with a board. A locked district's tab still
## shows, greyed, with what opens it -- the answer to "is this Spenard only?"
## is a row of three names.
func _district_tabs(sys: Object) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for entry in TERRITORY_DEFS.DISTRICT_ORDER:
		var id := str(entry)
		var district: Dictionary = gs.district_by_id(id)
		var held: int = sys.held_in(id)
		var total: int = (TERRITORY_DEFS.nodes_in(id) as Array).size()
		var b := button("%s %d/%d" % [str(district.get("name", id)), held, total], id == _district,
			_on_pick_district.bind(id), 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		if not str(sys.district_blocker(id)).is_empty():
			b.modulate = Color(1, 1, 1, 0.55)
		row.add_child(b)
	return row

func _on_pick_district(id: String) -> void:
	_district = id
	refresh()

## BR-D4: the district's own line -- held, posted, what it makes, what it
## costs, and what kind of place it is.
func _district_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)
	var blocker := str(sys.district_blocker(_district))
	if not blocker.is_empty():
		v.add_child(label("LOCKED", "Kicker", 10, RED))
		v.add_child(label(blocker, "Muted", 11, MUTED, true))
		return c
	var total: int = (TERRITORY_DEFS.nodes_in(_district) as Array).size()
	v.add_child(label("%d of %d held  ·  %d posted here" % [sys.held_in(_district), total,
		sys.posted_in(_district)], "CardTitle", 13, CREAM))
	var income: int = sys.income_in(_district)
	if income > 0 or sys.held_in(_district) > 0:
		v.add_child(label("$%d a night from here  ·  +%.1f heat a night here" % [income,
			sys.heat_in(_district)], "Muted", 11, GREEN if income > 0 else RED))
	match _district:
		"north_star_lot":
			v.add_child(label("Street corners. Where it starts. Cheap to take, cheap to hold.", "Muted", 11, MUTED, true))
		"downtown":
			v.add_child(label("Venues, not corners. More money a night, more police, and Curtis can see you from here.", "Muted", 11, MUTED, true))
		"airport_industrial":
			v.add_child(label("Warehouse lots. Not income -- supply. Every lot you hold cuts every buy you make, anywhere. Holding: -%d%% on buys." % int(round(float(sys.supply_discount()) * 100.0)), "Muted", 11, MUTED, true))
	if gs.current_district_id != _district:
		v.add_child(label("You claim from where you stand. Travel there to take one.", "Muted", 11, AMBER, true))
	return c

func _status_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)
	v.add_child(label("%d HELD  ·  %d/%d SOLDIERS  ·  %d FREE" % [
		gs.territory_nodes.size(), gs.soldiers_total(), gs.soldier_capacity(), gs.soldiers_idle
	], "CardTitle", 13, CREAM))

	var income: int = sys.nightly_income()
	var heat: float = sys.nightly_heat()
	if not gs.territory_nodes.is_empty():
		v.add_child(label("$%d a night  ·  +%.1f heat a night" % [income, heat], "Muted", 11, GREEN if income > 0 else RED))
	else:
		v.add_child(label("Nothing held. A corner needs a soldier free to stand on it.", "Muted", 11, MUTED, true))

	# D-1 (Batch 18 PR 4): payroll, shown whenever there is a roster to pay —
	# not gated on holding a corner, since an idle soldier draws it too.
	if gs.soldiers_total() > 0:
		v.add_child(label("-$%d a night in soldier upkeep ($%d/soldier)"
			% [sys.nightly_upkeep(), int(gs.SOLDIER_UPKEEP_PER_NIGHT)], "Muted", 11, RED))

	var blocked: String = sys.recruit_soldier_blocker()
	var b := button("HIRE A SOLDIER  $%d up front + $%d/night" \
			% [gs.SOLDIER_RECRUIT_COST, int(gs.SOLDIER_UPKEEP_PER_NIGHT)] \
		if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_hire, 46)
	b.disabled = not blocked.is_empty()
	v.add_child(b)
	return c

func _block_row(sys: Object, b: Dictionary) -> Control:
	var id: String = str(b["id"])
	var held: bool = gs.holds_block(id)
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var nm := label(str(b["name"]), "CardTitle", 13, CREAM if held else MUTED)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	# BR-D4: whose it is, at a glance. Yours, Curtis's, or open.
	var owner := "YOURS" if held else ("CURTIS'S" if str(b.get("starting_owner", "")) == TERRITORY_DEFS.OWNER_CURTIS else "OPEN")
	head.add_child(label(owner, "Kicker", 10, GREEN if held else (RED if owner == "CURTIS'S" else MUTED)))
	head.add_child(label("HELD" if held else "$%d" % int(b["claim_cost"]), "Mono", 12, GREEN if held else AMBER))
	if float(b.get("supply_discount", 0.0)) > 0.0:
		v.add_child(label("Supply: -%d%% on every buy, anywhere, once yours." % int(round(float(b["supply_discount"]) * 100.0)),
			"Muted", 11, MUTED, true))

	if held:
		var rec: Dictionary = gs.territory_nodes[id]
		var n: int = int(rec.get("soldiers", 0))
		var earns: int = sys.block_income(id)
		var col: Color = GREEN if n > 0 else RED
		v.add_child(label("%d posted  ·  $%d a night  ·  +%d heat a night" % [n, earns, int(b["heat_exposure"])], "Muted", 11, col))
		if n == 0:
			v.add_child(label("EMPTY — earning nothing, still costing heat.", "Muted", 11, RED))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var post_blocked: String = sys.post_blocker(id)
		var post := button("POST +1" if post_blocked.is_empty() else post_blocked.to_upper(), post_blocked.is_empty(), _on_post.bind(id))
		post.disabled = not post_blocked.is_empty()
		post.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(post)
		var pull := button("PULL", false, _on_pull.bind(id))
		pull.disabled = n <= 0
		pull.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pull)
		v.add_child(row)
		v.add_child(button("GIVE IT UP", false, _on_abandon.bind(id), 40))
	else:
		v.add_child(label("$%d per soldier a night  ·  +%d heat a night once yours" % [int(b["earning"]), int(b["heat_exposure"])], "Muted", 11, MUTED))
		var blocked: String = sys.claim_blocker(id)
		var btn := button("CLAIM  $%d" % int(b["claim_cost"]) if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_claim.bind(id), 46)
		btn.disabled = not blocked.is_empty()
		v.add_child(btn)
	return c

func _on_hire() -> void:
	if _gm.dispatch("recruit_soldier", {}):
		nav.show_toast("On the payroll. %d free." % gs.soldiers_idle)

func _on_claim(id: String) -> void:
	if _gm.dispatch("claim_block", {"block_id": id}):
		nav.show_toast("%s is yours." % str(gs.block_by_id(id)["name"]))

func _on_abandon(id: String) -> void:
	if _gm.dispatch("abandon_block", {"block_id": id}):
		nav.show_toast("Gone. The soldiers came back.")

func _on_post(id: String) -> void:
	_gm.dispatch("post_soldier", {"block_id": id})

func _on_pull(id: String) -> void:
	_gm.dispatch("pull_soldier", {"block_id": id})

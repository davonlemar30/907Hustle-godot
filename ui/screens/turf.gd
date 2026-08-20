extends "res://ui/screens/surface_base.gd"
## Turf — the block map.
##
## Each row states the trade plainly, because the trade is the game here: a
## corner earns per soldier with diminishing returns, and costs heat every night
## just for being yours. A block you cannot staff is a pure liability, and the
## screen should make that obvious before the player buys one.

func _build_body() -> void:
	var sys: Object = _gm.system("territory")
	if sys == null:
		return

	body.add_child(_status_card(sys))
	body.add_child(section("SPENARD BLOCKS"))
	for b in gs.spenard_blocks:
		body.add_child(_block_row(sys, b))

func _status_card(sys: Object) -> Control:
	var c := card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	c.add_child(v)
	v.add_child(label("%d HELD  ·  %d/%d SOLDIERS  ·  %d FREE" % [
		gs.held_blocks.size(), gs.soldiers_total(), gs.soldier_capacity(), gs.soldiers_idle
	], "CardTitle", 13, CREAM))

	var income: int = sys.nightly_income()
	var heat: float = sys.nightly_heat()
	if not gs.held_blocks.is_empty():
		v.add_child(label("$%d a night  ·  +%.1f heat a night" % [income, heat], "Muted", 11, GREEN if income > 0 else RED))
	else:
		v.add_child(label("Nothing held. A corner needs a soldier free to stand on it.", "Muted", 11, MUTED, true))

	var blocked: String = sys.recruit_soldier_blocker()
	var b := button("HIRE A SOLDIER  $%d" % gs.SOLDIER_RECRUIT_COST if blocked.is_empty() else blocked.to_upper(), blocked.is_empty(), _on_hire, 46)
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
	head.add_child(label("HELD" if held else "$%d" % int(b["claim_cost"]), "Mono", 12, GREEN if held else AMBER))

	if held:
		var rec: Dictionary = gs.held_blocks[id]
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

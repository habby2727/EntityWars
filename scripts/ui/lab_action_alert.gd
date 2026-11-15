extends RefCounted

static func available(id: String, state: Dictionary, db: StaticDB, now: int, pending: bool) -> bool:
	if pending:
		return false
	var lab: Dictionary = state.get("lab", {})
	var hq := int(lab.get("hqLevel", 1))
	var buildings: Dictionary = lab.get("buildings", {})
	var level := hq if id == "lab_th" else int(buildings.get(id, {}).get("level", 0))
	if not HqRules.is_unlocked(id, hq):
		return false
	var data: Dictionary = db.get_building(id)
	var resolver := CostResolver.new({id: data}, {"hq_cost_mult": db.get_balance("hq_cost_mult", CostResolver.DEFAULT_HQ_COST_MULT)})
	var cost: Dictionary = resolver.resolve_upgrade_cost(id, level, hq, str(lab.get("hqPath", "Scientific"))).get("cost", {})
	var affordable := not cost.is_empty()
	var wallet: Dictionary = state.get("wallet", {})
	for resource in cost:
		if int(wallet.get(resource, 0)) < int(cost[resource]):
			affordable = false
	if HqRules.can_upgrade(id, level, hq) and affordable:
		return true
	var runtime: Dictionary = lab.get("runtime", {})
	if id == "essence_reactor" and level > 0:
		if float(buildings.get(id, {}).get("runtime", {}).get("stored_output", 0)) >= 1.0:
			return true
		var charge: Dictionary = runtime.get("reactor_overcharge", {})
		var last := int(charge.get("last_used_at", 0))
		return int(charge.get("progress", 0)) >= int(db.get_balance("reactor_overcharge_threshold", 300)) and (last == 0 or now >= last + int(db.get_balance("reactor_overcharge_cooldown_seconds", 10800)) * 1000)
	if id == "ultrahit_tower":
		var spell: Variant = state.get("spell_progress", {}).get("active_research")
		return spell is Dictionary and not spell.is_empty() and int(spell.get("completes_at", 0)) > 0 and now >= int(spell.completes_at)
	if id == "arcane_archives":
		var research: Dictionary = runtime.get("research", {})
		return not str(research.get("active_id", "")).is_empty() and int(research.get("completes_at", 0)) > 0 and now >= int(research.completes_at)
	if id == "sync_nexus":
		var project: Variant = runtime.get("sync_project")
		return project is Dictionary and not project.is_empty() and int(project.get("completes_at", 0)) > 0 and now >= int(project.completes_at)
	if id == "world_gate":
		for session in state.get("world", {}).get("sessions", {}).values():
			for amount in session.get("pending_loot", {}).values():
				if int(amount) > 0:
					return true
	return false

static func badge(parent: Control) -> Label:
	var label := Label.new()
	label.name = "ActionBadge"
	label.text = "!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -22
	label.offset_right = -2
	label.offset_top = 2
	label.offset_bottom = 22
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.BLACK)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffdb38")
	style.set_corner_radius_all(10)
	label.add_theme_stylebox_override("normal", style)
	parent.add_child(label)
	return label

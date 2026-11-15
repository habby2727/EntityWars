extends RefCounted

static func available(id: String, state: Dictionary, db: StaticDB, now: int, pending: bool) -> bool:
	if pending or id == "essence_reactor":
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
	if id != "essence_reactor" and HqRules.can_upgrade(id, level, hq) and affordable:
		return true
	var runtime: Dictionary = lab.get("runtime", {})
	if id == "essence_reactor" and level > 0:
		var storage: Dictionary = buildings.get("storage_vault", {})
		var capacity := Capacity.compute_total_capacity(int(storage.get("level", 0)), str(storage.get("route", "")), str(lab.get("hqPath", "Scientific")), db.balance)
		var extra: Dictionary = runtime.get("boosts", {}).get("extra_storage", {})
		if int(extra.get("started_at", 0)) <= now and now < int(extra.get("expires_at", 0)):
			capacity = int(floor(capacity * float(ExperimentCatalog.get_by_id("extra_storage").get("effect", {}).get("capacity_mult", 1.15))))
		if capacity > 0 and _reactor_stored(lab, db, now) >= capacity:
			return true
		return false
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

static func _reactor_stored(lab: Dictionary, db: StaticDB, now: int) -> float:
	var buildings: Dictionary = lab.get("buildings", {})
	var reactor: Dictionary = buildings.get("essence_reactor", {})
	var state: Dictionary = reactor.get("runtime", {})
	var stored := maxf(0.0, float(state.get("stored_output", 0)))
	var start := mini(now, int(state.get("last_tick", now)))
	var cap_ms := int(float(db.get_balance("offline_cap_hours", 12)) * 3600000.0)
	if cap_ms > 0:
		start = maxi(start, now - cap_ms)
	var runtime: Dictionary = lab.get("runtime", {})
	var boosts: Dictionary = runtime.get("boosts", {})
	var directive: Dictionary = runtime.get("directive", {})
	var boundaries: Array[int] = [start, now]
	for interval in [directive, boosts.get("volatile_overclock", {}), boosts.get("essence_turbo", {})]:
		for point in [int(interval.get("started_at", interval.get("starts_at", 0))), int(interval.get("expires_at", interval.get("ends_at", 0)))]:
			if point > start and point < now:
				boundaries.append(point)
	boundaries.sort()
	var engine := ProductionEngine.new()
	var balance := ProductionEngine.balance_for_server(db.balance)
	var storage: Dictionary = buildings.get("storage_vault", {})
	for i in range(1, boundaries.size()):
		var midpoint := int((boundaries[i - 1] + boundaries[i]) / 2.0)
		var multiplier := 1.0
		for id in ["volatile_overclock", "essence_turbo"]:
			var boost: Dictionary = boosts.get(id, {})
			if int(boost.get("started_at", 0)) <= midpoint and midpoint < int(boost.get("expires_at", 0)):
				multiplier = maxf(multiplier, float(ExperimentCatalog.get_by_id(id).get("effect", {}).get("reactor_output_mult", 1.0)))
		if str(directive.get("id", "")) == "production" and int(directive.get("starts_at", 0)) <= midpoint and midpoint < int(directive.get("ends_at", 0)):
			multiplier *= float(db.get_balance("hq_directive_production_mult", 1.1))
		balance["_reactor_extra_multiplier"] = multiplier
		var route := str(reactor.get("route", "stable"))
		var rate := engine._compute_output_rate(int(reactor.get("level", 0)), "stable" if route.is_empty() else route, str(storage.get("route", "")), str(lab.get("hqPath", "Scientific")), balance)
		stored += rate * float(boundaries[i] - boundaries[i - 1]) / 1000.0
	return stored

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

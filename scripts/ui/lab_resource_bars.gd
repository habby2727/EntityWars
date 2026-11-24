extends RefCounted

const COLORS := {"essence": "46c77a", "core": "f29b42", "arcane_shard": "a56df2", "time_crystal": "45c9e8"}

static func build(container: Container, catalog: AssetCatalog, compact: bool = false, icon_gap: int = 5, large_numbers: bool = false) -> Dictionary:
	var rows := {}
	var icon_size := 32.0 if compact else 60.0
	var bar_width := 150.0 if compact else 220.0
	var bar_height := 24.0 if compact else 32.0
	var text_size := 14 if compact else 18
	if large_numbers:
		icon_size = 40.0
		bar_width = 225.0
		bar_height = 40.0
		text_size *= 2
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for id in StaticDB.REQUIRED_RESOURCE_IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", icon_gap)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = catalog.get_tex(id)
		if icon_gap < 0:
			icon.z_index = 1
		row.add_child(icon)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(bar_width, bar_height)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.step = 0.000001
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0, 0, 0, 0.7)
		background.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("background", background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(COLORS[id])
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var clip := Control.new()
		clip.position = Vector2(2, 2)
		clip.size = Vector2(0, bar_height - 4.0)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(clip)
		var shine := ColorRect.new()
		shine.size = Vector2(18, bar_height - 4.0)
		shine.color = Color(1, 1, 1, 0.18)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(shine)
		var tween := shine.create_tween().set_loops()
		tween.tween_property(shine, "position:x", bar_width, 2.4).from(-18.0)
		tween.tween_interval(1.0)
		var label := Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", text_size)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5 if large_numbers else 3)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(label)
		container.add_child(row)
		rows[id] = {"row": row, "icon": icon, "bar": bar, "label": label, "clip": clip, "large_numbers": large_numbers}
	return rows

static func update(rows: Dictionary, state: Dictionary, debug_mode: bool = false, balance: Dictionary = {}) -> void:
	var wallet: Dictionary = state.get("wallet", {}) if state.get("wallet", {}) is Dictionary else {}
	var caps: Dictionary = state.get("wallet_capacities", {}) if state.get("wallet_capacities", {}) is Dictionary else {}
	if debug_mode:
		var lab: Dictionary = state.get("lab", {}) if state.get("lab", {}) is Dictionary else {}
		var buildings: Dictionary = lab.get("buildings", {}) if lab.get("buildings", {}) is Dictionary else {}
		var storage: Dictionary = buildings.get("storage_vault", {}) if buildings.get("storage_vault", {}) is Dictionary else {}
		var reactor_capacity := Capacity.compute_total_capacity(int(storage.get("level", 0)), str(storage.get("route", "")), str(lab.get("hqPath", "Scientific")), balance)
		var multiplier: Variant = balance.get("wallet_storage_capacity_mult", 1.25)
		if not (multiplier is int or multiplier is float) or not is_finite(float(multiplier)):
			multiplier = 1.25
		var base := int(floor(reactor_capacity * maxf(0.0, float(multiplier))))
		caps = {"essence": maxi(1, base), "core": maxi(1, int(floor(base * 0.10))), "arcane_shard": maxi(1, int(floor(base * 0.05))), "time_crystal": maxi(1, int(floor(base * 0.02)))}
	for id in rows:
		var data: Dictionary = rows[id]
		var amount := int(wallet.get(id, 0))
		var cap := int(caps.get(id, 0))
		var bar: ProgressBar = data.bar
		var label: Label = data.label
		var clip: Control = data.clip
		label.text = "%d / %d" % [amount, cap] if cap > 0 else "%d / ?" % amount
		if bool(data.get("large_numbers", false)):
			bar.custom_minimum_size.x = maxf(225.0, label.get_combined_minimum_size().x + 8.0)
		bar.max_value = maxi(1, cap)
		var width := maxf(bar.size.x, bar.custom_minimum_size.x)
		var ratio := clampf(float(amount) / float(cap), 0.0, 1.0) if cap > 0 else 0.0
		if amount > 0:
			ratio = maxf(ratio, 2.0 / width)
		bar.value = ratio * bar.max_value
		clip.size.x = maxf(0.0, width - 4.0) * ratio

static func wallet_capacities(level: int, route: String, hq_path: String, balance: Dictionary) -> Dictionary:
	var capacity := Capacity.compute_total_capacity(level, route, hq_path, balance)
	var multiplier: Variant = balance.get("wallet_storage_capacity_mult", 1.25)
	if not (multiplier is int or multiplier is float) or not is_finite(float(multiplier)):
		multiplier = 1.25
	var base := int(floor(capacity * maxf(0.0, float(multiplier))))
	return {"essence": maxi(1, base), "core": maxi(1, int(floor(base * 0.10))), "arcane_shard": maxi(1, int(floor(base * 0.05))), "time_crystal": maxi(1, int(floor(base * 0.02)))}

static func vault_details(state: Dictionary, balance: Dictionary, level: int, max_level: int, route: String, hq_path: String) -> String:
	var current := wallet_capacities(level, route, hq_path, balance)
	var authoritative: Variant = state.get("wallet_capacities", {})
	if authoritative is Dictionary:
		for id in current:
			if authoritative.has(id):
				current[id] = authoritative[id]
	var next := wallet_capacities(level + 1, route, hq_path, balance)
	var lines := ["Resource | Current capacity | Next-level capacity"]
	for pair in [["Essence", "essence"], ["Core", "core"], ["Arcane Shard", "arcane_shard"], ["Time Crystal", "time_crystal"]]:
		lines.append("%s | %s | %s" % [pair[0], current[pair[1]], str(next[pair[1]]) if level < max_level else "MAX"])
	var reactor := Capacity.compute_total_capacity(level, route, hq_path, balance)
	var reactor_next := str(Capacity.compute_total_capacity(level + 1, route, hq_path, balance)) if level < max_level else "MAX"
	lines.append("Reactor pending-production capacity: %s | %s" % [reactor, reactor_next])
	return "\n".join(lines)

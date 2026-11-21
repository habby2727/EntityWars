extends RefCounted

static func result_popup(owner: Node, title: String, continue_text: String = "CONTINUE", on_close: Callable = Callable()) -> VBoxContainer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	owner.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b20")
	style.border_color = Color("bfa45b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	style.shadow_color = Color(0.15, 0.75, 0.8, 0.35)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	var heading := Label.new()
	heading.text = "*  " + title + "  *"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 27)
	heading.add_theme_color_override("font_color", Color("e7d293"))
	top.add_child(heading)
	var close := Button.new()
	close.text = "X"
	close.tooltip_text = "Close"
	close.pressed.connect(on_close if on_close.is_valid() else layer.queue_free)
	top.add_child(close)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)
	var button := Button.new()
	button.text = continue_text
	button.custom_minimum_size.y = 42
	button.pressed.connect(on_close if on_close.is_valid() else layer.queue_free)
	content.add_child(button)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	panel.pivot_offset = Vector2(220, 80)
	var intro := owner.create_tween().set_parallel(true)
	intro.tween_property(panel, "modulate:a", 1.0, 0.25)
	intro.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var glow := owner.create_tween().set_loops()
	glow.tween_property(style, "border_color", Color("69d7e8"), 1.2)
	glow.tween_property(style, "border_color", Color("bfa45b"), 1.2)
	glow.bind_node(layer)
	return body


static func reward_rows(owner: Node, body: VBoxContainer, grants: Dictionary, possible: Dictionary = {}, global_status: Dictionary = {}) -> void:
	var catalog := AssetCatalog.new()
	for resource in grants:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		body.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(80, 80)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if catalog.has(str(resource)):
			icon.texture = catalog.get_tex(str(resource))
		row.add_child(icon)
		var label := Label.new()
		var prefix := "Potential: " if global_status.get("reward_status") == "WAITING" else "+"
		label.text = "%s%s  %s" % [prefix, str(grants[resource]), _resource_name(str(resource)).replace("_", " ").capitalize()]
		if possible.has(resource):
			label.text += "\nPossible drop (%s%% chance)" % str(snappedf(float(possible[resource]) * 100.0, 0.1))
		elif global_status.get("reward_status") == "WAITING":
			label.text += "\nGuaranteed on completion"
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color("d9f7f4"))
		row.add_child(label)
		icon.pivot_offset = Vector2(40, 40)
		var pulse := owner.create_tween().set_loops()
		pulse.tween_property(icon, "scale", Vector2(1.08, 1.08), 0.8).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(icon, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
		pulse.bind_node(icon)
	catalog.free()

static func _resource_name(id: String) -> String:
	var file := FileAccess.open("res://data/static/resources.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			for resource in parsed.get("resources", []):
				if resource is Dictionary and str(resource.get("id", "")) == id:
					return str(resource.get("display_name", id))
	return id

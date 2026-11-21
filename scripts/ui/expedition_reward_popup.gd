extends CanvasLayer

signal acknowledged

func show_reward(title: String, texture: Texture2D, detail: String) -> void:
	layer = 100
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b20")
	style.border_color = Color("bfa45b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	style.shadow_color = Color(0.15, 0.75, 0.8, 0.35)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("e7d293"))
	box.add_child(heading)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(240, 240)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = texture
	box.add_child(portrait)
	var label := Label.new()
	label.name = "RewardDetail"
	label.text = detail
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("d9f7f4"))
	box.add_child(label)
	var close := Button.new()
	close.text = tr("EXPEDITION_CONTINUE")
	close.custom_minimum_size.y = 48
	preload("res://scripts/ui/menu_art.gd").button(close)
	close.pressed.connect(func(): acknowledged.emit())
	box.add_child(close)
	panel.modulate.a = 0
	panel.scale = Vector2(0.94, 0.94)
	panel.pivot_offset = Vector2(230, 100)
	var intro := create_tween().set_parallel(true)
	intro.tween_property(panel, "modulate:a", 1.0, 0.25)
	intro.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var glow := create_tween().set_loops()
	glow.tween_property(style, "border_color", Color("69d7e8"), 1.2)
	glow.tween_property(style, "border_color", Color("bfa45b"), 1.2)
	glow.bind_node(self)

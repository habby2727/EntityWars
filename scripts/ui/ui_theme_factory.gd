extends Node
class_name UIThemeFactory

static var _catalog: AssetCatalog = null

static func _get_catalog() -> AssetCatalog:
	if _catalog == null:
		_catalog = AssetCatalog.new()
	return _catalog

static func build_theme() -> Theme:
	var theme := Theme.new()
	var catalog := _get_catalog()

	var panel_id := catalog.find_id_contains("lab_panel")
	if panel_id == "":
		panel_id = catalog.find_id_contains("panel_ui")
	var panel_tex: Texture2D = catalog.get_tex(panel_id) if panel_id != "" else null
	if panel_tex != null:
		var panel_style := StyleBoxTexture.new()
		panel_style.texture = panel_tex
		_configure_stylebox(panel_style)
		theme.set_stylebox("panel", "Panel", panel_style)
		theme.set_stylebox("panel", "PanelContainer", panel_style)

	var base_id := catalog.find_id_contains("button_base")
	var hover_id := catalog.find_id_contains("button_hover")
	var base_tex: Texture2D = catalog.get_tex(base_id) if base_id != "" else null
	var hover_tex: Texture2D = catalog.get_tex(hover_id) if hover_id != "" else null
	if base_tex != null:
		theme.set_stylebox("normal", "Button", _make_stylebox(base_tex))
		if hover_tex == null:
			theme.set_stylebox("pressed", "Button", _make_stylebox(base_tex))
	if hover_tex != null:
		theme.set_stylebox("hover", "Button", _make_stylebox(hover_tex))
		theme.set_stylebox("pressed", "Button", _make_stylebox(hover_tex))

	return theme

static func apply_theme_to(root: Control) -> void:
	if root == null:
		return
	var theme := build_theme()
	_apply_theme_recursive(root, theme)

static func apply_theme_scaled(root: Control, scale: float) -> void:
	if root == null:
		return
	var theme := build_theme()
	_scale_theme_fonts(theme, scale)
	_apply_theme_recursive(root, theme)

static func _scale_theme_fonts(theme: Theme, scale: float) -> void:
	if theme == null:
		return
	var s = clamp(scale, 0.85, 1.5)
	var base = int(round(16.0 * s))
	var small = int(round(14.0 * s))
	theme.set_font_size("font_size", "Label", base)
	theme.set_font_size("font_size", "Button", base)
	theme.set_font_size("font_size", "OptionButton", base)
	theme.set_font_size("font_size", "LineEdit", base)
	theme.set_font_size("font_size", "RichTextLabel", base)
	theme.set_font_size("font_size", "TabContainer", small)

static func make_icon_slot() -> Control:
	var catalog := _get_catalog()
	var frame := TextureRect.new()
	var frame_id := catalog.find_id_contains("icon_slot_frame")
	frame.texture = catalog.get_tex(frame_id) if frame_id != "" else null
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	return frame

static func _make_stylebox(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	_configure_stylebox(sb)
	return sb

static func _configure_stylebox(sb: StyleBoxTexture) -> void:
	if sb == null:
		return
	sb.draw_center = true
	# Avoid stretching by tiling when possible.
	if sb.has_method("set_axis_stretch_horizontal"):
		sb.set_axis_stretch_horizontal(StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
		sb.set_axis_stretch_vertical(StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
	else:
		sb.set("axis_stretch_horizontal", 1)
		sb.set("axis_stretch_vertical", 1)

static func _apply_theme_recursive(node: Node, theme: Theme) -> void:
	if node is Control:
		node.theme = theme
		_apply_aspect_hint(node)
	for child in node.get_children():
		if child is Node:
			_apply_theme_recursive(child, theme)

static func _apply_aspect_hint(node: Control) -> void:
	if node == null:
		return
	if node.custom_minimum_size != Vector2.ZERO:
		return
	var tex: Texture2D = null
	if node is Button:
		var sb_btn = node.get_theme_stylebox("normal", "Button")
		if sb_btn is StyleBoxTexture:
			tex = sb_btn.texture
	elif node is Panel:
		var sb_panel = node.get_theme_stylebox("panel", "Panel")
		if sb_panel is StyleBoxTexture:
			tex = sb_panel.texture
	elif node is PanelContainer:
		var sb_container = node.get_theme_stylebox("panel", "PanelContainer")
		if sb_container is StyleBoxTexture:
			tex = sb_container.texture
	if tex == null:
		return
	var tex_w = float(tex.get_width())
	var tex_h = float(tex.get_height())
	if tex_w <= 0.0 or tex_h <= 0.0:
		return
	var ratio = tex_w / tex_h
	var min_size = node.get_combined_minimum_size()
	if min_size.x <= 0.0 or min_size.y <= 0.0:
		return
	var target_w = min_size.x
	var target_h = min_size.y
	var target_h_from_w = target_w / ratio
	if target_h_from_w < target_h:
		target_h_from_w = target_h
		target_w = target_h_from_w * ratio
		target_h = target_h_from_w
	else:
		target_h = target_h_from_w
	node.custom_minimum_size = Vector2(target_w, target_h)

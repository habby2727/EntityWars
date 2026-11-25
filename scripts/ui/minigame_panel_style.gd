extends RefCounted

# Draw the room panels and controls with Godot styles, without image assets.
static func _box(color: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box

static func panel(control: Control) -> void:
	control.set_meta("minigame_native_typography", true)
	var style := _box(Color(0.025, 0.045, 0.065, 0.91), Color(0.48, 0.68, 0.75, 0.65), 14)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	control.add_theme_stylebox_override("panel", style)
	control.theme = readable_theme()

static func readable_theme() -> Theme:
	var local_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial", "Noto Sans", "sans-serif"])
	local_theme.default_font = font
	for type in ["Label", "Button", "CheckBox", "LineEdit"]:
		local_theme.set_font("font", type, font)
	local_theme.default_font_size = 20
	return local_theme

static func button(control: Button, primary: bool = false) -> void:
	var normal := Color(0.10, 0.30, 0.38, 0.96) if primary else Color(0.10, 0.16, 0.20, 0.90)
	var border := Color(0.42, 0.72, 0.78, 0.8) if primary else Color(0.41, 0.56, 0.60, 0.65)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := normal
		if state == "hover": color = normal.lightened(0.17)
		elif state == "pressed": color = normal.darkened(0.18)
		elif state == "disabled": color = Color(0.12, 0.14, 0.16, 0.7)
		var style := _box(color, border if state != "disabled" else Color(0.28, 0.32, 0.34, 0.5), 8)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		control.add_theme_stylebox_override(state, style)
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.add_theme_color_override("font_color", Color("eaf5f5"))
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	control.add_theme_color_override("font_pressed_color", Color.WHITE)
	control.add_theme_color_override("font_disabled_color", Color(0.60, 0.66, 0.68))

extends RefCounted

const DIR := "res://assets/ui/new-elements/"
const BETTER_DIR := DIR + "betterui/"
static var _button_textures := {}

static func _button_frame(file: String) -> StyleBoxTexture:
	# Keep old callers compatible while sharing the new cached artwork.
	var name := "boton_largo.png" if file == "boton_largo.png" else "boton_corto.png"
	if not _button_textures.has(name):
		var texture: Texture2D = load(BETTER_DIR + name)
		var image := texture.get_image()
		var width := 320 if name == "boton_largo.png" else 200
		image.resize(width, maxi(1, roundi(float(image.get_height()) * width / image.get_width())), Image.INTERPOLATE_LANCZOS)
		_button_textures[name] = ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = _button_textures[name]
	style.texture_margin_left = 30
	style.texture_margin_top = 14
	style.texture_margin_right = 30
	style.texture_margin_bottom = 14
	style.content_margin_left = 16
	style.content_margin_top = 7
	style.content_margin_right = 16
	style.content_margin_bottom = 7
	return style

static func frame(file: String, padding: Vector4 = Vector4.ZERO) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(BETTER_DIR + file)
	if OS.has_feature("android") and style.texture != null:
		style.texture_margin_left = minf(60.0, style.texture.get_width() * 0.2)
		style.texture_margin_right = style.texture_margin_left
		style.texture_margin_top = minf(60.0, style.texture.get_height() * 0.2)
		style.texture_margin_bottom = style.texture_margin_top
	style.content_margin_left = padding.x
	style.content_margin_top = padding.y
	style.content_margin_right = padding.z
	style.content_margin_bottom = padding.w
	return style

static func refresh_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var caption := button.tr(button.text).strip_edges()
	var file := "boton_largo.png" if " " in caption or "\n" in caption or caption.length() > 14 else "boton_corto.png"
	if button.get_meta("betterui_button", "") == file:
		return
	button.set_meta("betterui_button", file)
	var normal := _button_frame(file)
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.2, 1.2, 1.15)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.78, 0.9, 0.9)
	var disabled := normal.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(0.5, 0.5, 0.5, 0.75)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func button(button: Button) -> void:
	refresh_button(button)
	if not button.has_meta("betterui_resize_connected"):
		button.set_meta("betterui_resize_connected", true)
		var ref: WeakRef = weakref(button)
		var update := func():
			var target := ref.get_ref() as Button
			if target != null:
				refresh_button(target)
		button.resized.connect(update)
		update.call_deferred()

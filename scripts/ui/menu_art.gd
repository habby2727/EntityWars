extends RefCounted

const DIR := "res://assets/ui/new-elements/"
static var _button_textures := {}

static func _button_frame(file: String) -> StyleBoxTexture:
	if not _button_textures.has(file):
		var texture: Texture2D = load(DIR + file)
		var image := texture.get_image()
		image.resize(400, maxi(1, roundi(float(image.get_height()) * 400 / image.get_width())), Image.INTERPOLATE_LANCZOS)
		_button_textures[file] = ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = _button_textures[file]
	style.texture_margin_left = 36
	style.texture_margin_top = 16
	style.texture_margin_right = 36
	style.texture_margin_bottom = 16
	style.content_margin_left = 25
	style.content_margin_top = 8
	style.content_margin_right = 25
	style.content_margin_bottom = 8
	return style

static func frame(file: String, padding: Vector4 = Vector4.ZERO) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(DIR + file)
	style.content_margin_left = padding.x
	style.content_margin_top = padding.y
	style.content_margin_right = padding.z
	style.content_margin_bottom = padding.w
	return style

static func button(button: Button) -> void:
	var normal := _button_frame("boton-loadout-opciones.png")
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.2, 1.2, 1.15)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.78, 0.9, 0.9)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", _button_frame("boton-bloqueado-off.png"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

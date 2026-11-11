extends RefCounted

const DIR := "res://assets/ui/new-elements/"

static func frame(file: String, padding: Vector4 = Vector4.ZERO) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(DIR + file)
	style.content_margin_left = padding.x
	style.content_margin_top = padding.y
	style.content_margin_right = padding.z
	style.content_margin_bottom = padding.w
	return style

static func button(button: Button) -> void:
	var normal := frame("boton-loadout-opciones.png", Vector4(22, 8, 22, 8))
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.2, 1.2, 1.15)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.78, 0.9, 0.9)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", frame("boton-bloqueado-off.png", Vector4(22, 8, 22, 8)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

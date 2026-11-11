extends Node

const FRAME := preload("res://assets/ui/new-elements/marco-horizontal-popup.png")
const BUTTON := preload("res://assets/ui/new-elements/boton-loadout-opciones.png")
const DISABLED := preload("res://assets/ui/new-elements/boton-bloqueado-off.png")

var _frame_texture: ImageTexture
var _button_texture: ImageTexture
var _disabled_texture: ImageTexture

func _ready() -> void:
	_frame_texture = _resize_texture(FRAME, 360)
	_button_texture = _resize_texture(BUTTON, 400)
	_disabled_texture = _resize_texture(DISABLED, 400)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is PopupMenu:
		call_deferred("_configure_popup", node)
	elif node is OptionButton:
		call_deferred("_configure_button", node)

func _resize_texture(texture: Texture2D, width: int) -> ImageTexture:
	var image := texture.get_image()
	var height := maxi(1, roundi(float(image.get_height()) * width / image.get_width()))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _style(texture: Texture2D, margins: Vector4, content: Vector4) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = texture
	result.texture_margin_left = margins.x
	result.texture_margin_top = margins.y
	result.texture_margin_right = margins.z
	result.texture_margin_bottom = margins.w
	result.content_margin_left = content.x
	result.content_margin_top = content.y
	result.content_margin_right = content.z
	result.content_margin_bottom = content.w
	return result

func _configure_button(button: OptionButton) -> void:
	if not is_instance_valid(button):
		return
	var normal := _style(_button_texture, Vector4(36, 16, 36, 16), Vector4(25, 8, 30, 8))
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.2, 1.2, 1.12)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.8, 0.9, 0.9)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", _style(_disabled_texture, Vector4(36, 16, 36, 16), Vector4(25, 8, 30, 8)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.89))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

func _configure_popup(popup: PopupMenu) -> void:
	if not is_instance_valid(popup):
		return
	var frame := _style(_frame_texture, Vector4(32, 45, 32, 30), Vector4(34, 48, 34, 32))
	popup.add_theme_stylebox_override("panel", frame)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.08, 0.3, 0.27, 0.92)
	hover.border_color = Color(0.8, 0.67, 0.35)
	hover.set_border_width_all(1)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_color_override("font_color", Color(0.95, 0.95, 0.89))
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(0.6, 0.63, 0.6))
	popup.add_theme_constant_override("v_separation", 8)
	if not popup.about_to_popup.is_connected(_on_about_to_popup.bind(popup)):
		popup.about_to_popup.connect(_on_about_to_popup.bind(popup))

func _on_about_to_popup(popup: PopupMenu) -> void:
	if is_instance_valid(popup):
		popup.min_size = Vector2i(maxi(popup.min_size.x, 220), maxi(popup.min_size.y, 220))

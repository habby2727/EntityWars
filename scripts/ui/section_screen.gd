extends Control
class_name SectionScreen

@export var back_button_path: NodePath
@export var background_panel_path: NodePath

func _ready() -> void:
	UIThemeFactory.apply_theme_to(self)
	_apply_background_panel()
	_bind_back_button()

func _apply_background_panel() -> void:
	var panel: Panel = _get_panel(background_panel_path)
	if panel == null:
		push_error("SectionScreen: Background Panel not found at %s" % background_panel_path)
		return
	var tex: Texture2D = AssetCatalog.new().get_tex("ui_panel")
	if tex == null:
		return
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	UIThemeFactory._configure_stylebox(sb)
	panel.add_theme_stylebox_override("panel", sb)

func _bind_back_button() -> void:
	var button: Button = _get_button(back_button_path)
	if button == null:
		push_error("SectionScreen: Back Button not found at %s" % back_button_path)
		return
	button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	SceneRouter.go_to_main_menu()

func _get_button(path: NodePath) -> Button:
	if path == NodePath(""):
		return null
	var node = get_node_or_null(path)
	if node is Button:
		return node
	return null

func _get_panel(path: NodePath) -> Panel:
	if path == NodePath(""):
		return null
	var node = get_node_or_null(path)
	if node is Panel:
		return node
	return null

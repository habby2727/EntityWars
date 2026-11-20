extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")

func _ready() -> void:
	UIThemeFactory.apply_theme_scaled(self, clampf(minf(get_viewport_rect().size.x / 1920.0, get_viewport_rect().size.y / 1080.0), 0.65, 1.0))
	var panel := $Background as Panel
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/new-elements/fondo-menu-seleccion-worldgate.png")
	panel.add_theme_stylebox_override("panel", style)
	var back := $Background/Margin/Content/Back as Button
	MenuArt.button(back)
	back.pressed.connect(SceneRouter.go_to_world_gate)

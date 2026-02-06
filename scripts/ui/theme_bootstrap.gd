extends Control
class_name ThemeBootstrap

func _ready() -> void:
	UIThemeFactory.apply_theme_to(self)

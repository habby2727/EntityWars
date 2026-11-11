extends Control

const SETTINGS_PATH := "user://settings.cfg"

@onready var language: OptionButton = $Center/Panel/Margin/Content/Language

func _ready() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	language.add_item("English")
	language.add_item("Español")
	language.select(1 if config.get_value("interface", "language", "en") == "es" else 0)
	language.item_selected.connect(_on_language_selected)
	$Center/Panel/Margin/Content/Back.pressed.connect(SceneRouter.go_to_main_menu)

func _on_language_selected(index: int) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("interface", "language", "es" if index == 1 else "en")
	config.save(SETTINGS_PATH)

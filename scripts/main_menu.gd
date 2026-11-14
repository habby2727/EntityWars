extends Control

const COMBAT_BUTTON_PATH := NodePath("LowerButtons/CombatButton")
const INVENTORY_BUTTON_PATH := NodePath("LowerButtons/InventoryButton")
const LABORATORY_BUTTON_PATH := NodePath("LowerButtons/LaboratoryButton")
const SETTINGS_BUTTON_PATH := NodePath("LowerButtons/SettingsButton")

@onready var combat_btn: Button = _get_button(COMBAT_BUTTON_PATH)
@onready var inventory_btn: Button = _get_button(INVENTORY_BUTTON_PATH)
@onready var laboratory_btn: Button = _get_button(LABORATORY_BUTTON_PATH)
@onready var settings_btn: Button = _get_button(SETTINGS_BUTTON_PATH)

func _ready() -> void:
	preload("res://scripts/ui/settings_screen.gd").apply_saved_display_mode()
	UIThemeFactory.apply_theme_to(self)
	if combat_btn:
		combat_btn.pressed.connect(_on_combat_pressed)
	else:
		push_error("MainMenu: Combat button not found at %s" % COMBAT_BUTTON_PATH)
	if inventory_btn:
		inventory_btn.pressed.connect(_on_inventory_pressed)
	else:
		push_error("MainMenu: Inventory button not found at %s" % INVENTORY_BUTTON_PATH)
	if laboratory_btn:
		laboratory_btn.pressed.connect(_on_laboratory_pressed)
	else:
		push_error("MainMenu: Laboratory button not found at %s" % LABORATORY_BUTTON_PATH)
	if settings_btn:
		settings_btn.pressed.connect(SceneRouter.go_to_settings)

func _on_combat_pressed() -> void:
	SceneRouter.go_to_loadout()

func _on_inventory_pressed() -> void:
	SceneRouter.go_to_inventory()

func _on_laboratory_pressed() -> void:
	SceneRouter.go_to_lab_hub()

func _get_button(path: NodePath) -> Button:
	if path == NodePath(""):
		return null
	var node = get_node_or_null(path)
	if node is Button:
		return node
	return null

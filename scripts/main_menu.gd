extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")

const COMBAT_BUTTON_PATH := NodePath("LowerButtons/CombatButton")
const INVENTORY_BUTTON_PATH := NodePath("LowerButtons/InventoryButton")
const LABORATORY_BUTTON_PATH := NodePath("LowerButtons/LaboratoryButton")
const SETTINGS_BUTTON_PATH := NodePath("LowerButtons/SettingsButton")

@onready var combat_btn: Button = _get_button(COMBAT_BUTTON_PATH)
@onready var inventory_btn: Button = _get_button(INVENTORY_BUTTON_PATH)
@onready var laboratory_btn: Button = _get_button(LABORATORY_BUTTON_PATH)
@onready var settings_btn: Button = _get_button(SETTINGS_BUTTON_PATH)
@onready var background_video: VideoStreamPlayer = $BackgroundVideo
var _exit_overlay: CanvasLayer
var _quitting := false

func _ready() -> void:
	preload("res://scripts/ui/settings_screen.gd").apply_saved_display_mode()
	UIThemeFactory.apply_theme_to(self)
	background_video.finished.connect(background_video.play)
	background_video.play()
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
	$ExitButton.pressed.connect(_show_exit_confirmation)

func _exit_tree() -> void:
	background_video.stop()

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

func _show_exit_confirmation() -> void:
	if _quitting or is_instance_valid(_exit_overlay):
		return
	var spanish := TranslationServer.get_locale().begins_with("es")
	_exit_overlay = CanvasLayer.new()
	_exit_overlay.layer = 100
	add_child(_exit_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 220)
	panel.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup.png", Vector4(45, 35, 45, 35)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	var label := Label.new()
	label.text = "¿Estás seguro?" if spanish else "Are you sure?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	box.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "No"
	cancel.custom_minimum_size = Vector2(150, 48)
	MenuArt.button(cancel)
	cancel.pressed.connect(_cancel_exit)
	buttons.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "Sí" if spanish else "Yes"
	confirm.custom_minimum_size = Vector2(150, 48)
	MenuArt.button(confirm)
	confirm.pressed.connect(func():
		if not _quitting:
			_quitting = true
			get_tree().quit())
	buttons.add_child(confirm)
	cancel.grab_focus()

func _cancel_exit() -> void:
	if is_instance_valid(_exit_overlay):
		_exit_overlay.queue_free()
		_exit_overlay = null

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_exit_overlay) and event.is_action_pressed("ui_cancel"):
		_cancel_exit()
		get_viewport().set_input_as_handled()

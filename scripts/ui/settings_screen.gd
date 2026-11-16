extends Control

const SETTINGS_PATH := "user://settings.cfg"

@onready var language: OptionButton = $Center/Panel/Margin/Content/Language
@onready var fullscreen: OptionButton = $Center/Panel/Margin/Content/Fullscreen
var _display_status_key := ""

static func apply_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var screen := DisplayServer.window_get_current_screen()
		var area := DisplayServer.screen_get_usable_rect(screen)
		var window_size := Vector2i(mini(1280, int(area.size.x * 0.8)), mini(720, int(area.size.y * 0.8)))
		DisplayServer.window_set_size(window_size)
		DisplayServer.window_set_position(area.position + (area.size - window_size) / 2)

static func apply_saved_display_mode() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK and config.has_section_key("display", "fullscreen"):
		apply_fullscreen(bool(config.get_value("display", "fullscreen")))

func _ready() -> void:
	language.add_item("English")
	language.add_item("Español")
	language.select(1 if TranslationServer.get_locale() == "es" else 0)
	language.item_selected.connect(_on_language_selected)
	fullscreen.add_item(tr("SETTINGS_YES"))
	fullscreen.add_item(tr("SETTINGS_NO"))
	var mode := DisplayServer.window_get_mode()
	fullscreen.select(0 if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN] else 1)
	fullscreen.item_selected.connect(func(_index: int): _set_display_status("SETTINGS_DISPLAY_PENDING"))
	$Center/Panel/Margin/Content/ApplyDisplay.pressed.connect(_apply_display_selection)
	$Center/Panel/Margin/Content/Back.pressed.connect(SceneRouter.go_to_main_menu)

func _apply_display_selection() -> void:
	var enabled := fullscreen.selected == 0
	apply_fullscreen(enabled)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("display", "fullscreen", enabled)
	if config.save(SETTINGS_PATH) == OK:
		_set_display_status("SETTINGS_DISPLAY_FULLSCREEN" if enabled else "SETTINGS_DISPLAY_WINDOWED")
	else:
		_set_display_status("SETTINGS_DISPLAY_SAVE_FAILED")

func _on_language_selected(index: int) -> void:
	GameLocalization.set_language("es" if index == 1 else "en")

func _set_display_status(key: String) -> void:
	_display_status_key = key
	$Center/Panel/Margin/Content/DisplayStatus.text = tr(key)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		fullscreen.set_item_text(0, tr("SETTINGS_YES"))
		fullscreen.set_item_text(1, tr("SETTINGS_NO"))
		if not _display_status_key.is_empty():
			_set_display_status(_display_status_key)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		var mode := DisplayServer.window_get_mode()
		fullscreen.select(0 if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_MAXIMIZED] else 1)

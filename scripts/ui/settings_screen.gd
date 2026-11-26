extends Control

const SETTINGS_PATH := "user://settings.cfg"

@onready var language: OptionButton = $Center/Panel/Margin/Content/Language
@onready var fullscreen: OptionButton = $Center/Panel/Margin/Content/Fullscreen
var _display_status_key := ""
var _logout_dialog: ConfirmationDialog
var _logout_busy := false

static func apply_fullscreen(enabled: bool) -> void:
	if OS.has_feature("android"):
		return
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
	if OS.has_feature("android"):
		fullscreen.disabled = true
		$Center/Panel/Margin/Content/ApplyDisplay.disabled = true
	else:
		var mode := DisplayServer.window_get_mode()
		fullscreen.select(0 if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN] else 1)
	fullscreen.item_selected.connect(func(_index: int): _set_display_status("SETTINGS_DISPLAY_PENDING"))
	$Center/Panel/Margin/Content/ApplyDisplay.pressed.connect(_apply_display_selection)
	$Center/Panel/Margin/Content/Back.pressed.connect(SceneRouter.go_to_main_menu)
	var logout: Button = $Center/Panel/Margin/Content/Logout
	logout.pressed.connect(_confirm_logout)
	_logout_dialog = ConfirmationDialog.new()
	_logout_dialog.dialog_text = tr("SETTINGS_LOGOUT_CONFIRM")
	_logout_dialog.ok_button_text = tr("SETTINGS_LOGOUT")
	_logout_dialog.cancel_button_text = tr("SETTINGS_LOGOUT_CANCEL")
	add_child(_logout_dialog)
	_logout_dialog.confirmed.connect(_logout)

func _confirm_logout() -> void:
	if _logout_busy:
		return
	if not ConnectionGate.explicit_logout_safe():
		_set_display_status("SETTINGS_LOGOUT_RECOVERY")
		return
	_logout_dialog.popup_centered()

func _logout() -> void:
	if _logout_busy:
		return
	if not ConnectionGate.explicit_logout_safe():
		_set_display_status("SETTINGS_LOGOUT_RECOVERY")
		return
	var old_token: String = ConnectionGate.token
	var old_url: String = ConnectionGate.base_url
	if old_token.is_empty() and FileAccess.file_exists(BackendClient.AUTH_PATH):
		var saved := FileAccess.open(BackendClient.AUTH_PATH, FileAccess.READ)
		if saved == null:
			_set_display_status("SETTINGS_LOGOUT_STORAGE_ERROR")
			return
		var credentials: Variant = JSON.parse_string(saved.get_as_text())
		saved.close()
		if credentials is Dictionary:
			old_token = str(credentials.get("token", ""))
	if old_url.is_empty():
		old_url = preload("res://scripts/net/backend_endpoint.gd").resolve("http://127.0.0.1:8787")
	if not BackendClient.clear_saved_token():
		_set_display_status("SETTINGS_LOGOUT_STORAGE_ERROR")
		return
	_logout_busy = true
	$Center/Panel/Margin/Content/Logout.disabled = true
	$Center/Panel/Margin/Content/Back.disabled = true
	ConnectionGate.explicit_logout_reset()
	var confirmed := old_token.is_empty()
	if not old_token.is_empty() and not old_url.is_empty():
		var http := HTTPRequest.new()
		http.timeout = 8.0
		http.max_redirects = 0
		add_child(http)
		var headers := PackedStringArray(["Authorization: Bearer " + old_token, "Content-Type: application/json", preload("res://scripts/net/client_build.gd").header()])
		if http.request(old_url + "/auth/logout", headers, HTTPClient.METHOD_POST, "{}") == OK:
			var response: Array = await http.request_completed
			confirmed = response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200
		http.queue_free()
	SceneRouter.logout_notice = "" if confirmed else "AUTH_LOGOUT_UNCONFIRMED"
	get_tree().change_scene_to_file("res://scenes/ui/Auth.tscn")

func _apply_display_selection() -> void:
	if OS.has_feature("android"):
		return
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
		_logout_dialog.dialog_text = tr("SETTINGS_LOGOUT_CONFIRM")
		_logout_dialog.ok_button_text = tr("SETTINGS_LOGOUT")
		_logout_dialog.cancel_button_text = tr("SETTINGS_LOGOUT_CANCEL")
		fullscreen.set_item_text(0, tr("SETTINGS_YES"))
		fullscreen.set_item_text(1, tr("SETTINGS_NO"))
		if not _display_status_key.is_empty():
			_set_display_status(_display_status_key)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		var mode := DisplayServer.window_get_mode()
		fullscreen.select(0 if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_MAXIMIZED] else 1)

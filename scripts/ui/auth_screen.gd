extends Control

const BACKGROUNDS := [
	"res://assets/ui/loading_screens/entity_wars_loading/backgrounds/laboratory_1920x1080.png",
	"res://assets/ui/loading_screens/entity_wars_loading/backgrounds/portal_1920x1080.png",
	"res://assets/ui/loading_screens/entity_wars_loading/backgrounds/chaos_1920x1080.png",
]
const LOADING := "res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_startup.tscn"
const MenuArt := preload("res://scripts/ui/menu_art.gd")

var client: BackendClient
var http: HTTPRequest
var tabs: TabContainer
var username: Array[LineEdit] = []
var password: Array[LineEdit] = []
var confirm: LineEdit
var message: Label
var submit_buttons: Array[Button] = []
var retry: Button
var debug_button: Button
var busy := false
var verifying := false
var endpoint_safe := false
var submitted_name := ""
var preflight_ok := false
var preflighting := false

func auth_gate_screen() -> void:
	pass

func _ready() -> void:
	_build_ui()
	client = BackendClient.new()
	client.auto_dev_login = false
	client.base_url = preload("res://scripts/net/backend_endpoint.gd").resolve(client.base_url)
	var url := client.base_url.to_lower()
	var authority := url.trim_prefix("http://").get_slice("/", 0).get_slice(":", 0)
	endpoint_safe = url.begins_with("https://") or (url.begins_with("http://") and authority in ["localhost", "127.0.0.1"])
	if not endpoint_safe:
		message.text = tr("AUTH_SECURE_CONNECTION")
		return
	for field in username:
		field.text = client.dev_display_name
	http = HTTPRequest.new()
	http.max_redirects = 0
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(_on_auth_response)
	if OS.has_feature("editor"):
		_finish_preflight()
	else:
		_start_preflight()

func _finish_preflight() -> void:
	preflight_ok = true
	retry.hide()
	message.text = ""
	add_child(client)
	for button in submit_buttons: button.disabled = false
	if not client.token.is_empty():
		verifying = true
		tabs.hide()
		message.text = tr("AUTH_VERIFYING")

func _start_preflight() -> void:
	preflight_ok = false
	preflighting = true
	for button in submit_buttons: button.disabled = true
	retry.hide()
	message.text = "Checking client version..."
	if http.request(client.base_url + "/static/version", PackedStringArray([preload("res://scripts/net/client_build.gd").header()])) != OK:
		preflighting = false
		message.text = tr("AUTH_CONNECTION_ERROR")
		retry.show()

func _process(_delta: float) -> void:
	if ConnectionGate.state == ConnectionGate.State.UPDATE_REQUIRED:
		verifying = false
		preflight_ok = false
		for button in submit_buttons: button.disabled = true
		if is_instance_valid(debug_button): debug_button.disabled = true
		message.text = "Update required. Please update Entity Wars to continue."
		retry.hide()
		return
	if not verifying:
		return
	if ConnectionGate.state == ConnectionGate.State.AUTH_REQUIRED:
		verifying = false
		client.set_token("")
		tabs.show()
		retry.hide()
		message.text = tr("AUTH_SESSION_EXPIRED")
	elif ConnectionGate.state == ConnectionGate.State.CONNECTED and not ConnectionGate.player_id.is_empty() and client._verified_player_id == ConnectionGate.player_id:
		verifying = false
		get_tree().change_scene_to_file(LOADING)
	elif ConnectionGate.state == ConnectionGate.State.RECONNECTING or ConnectionGate.state == ConnectionGate.State.ERROR:
		message.text = tr("AUTH_CONNECTION_ERROR")
		retry.show()

func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUNDS[randi() % BACKGROUNDS.size()])
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.04, 0.92)
	style.border_color = Color(0.65, 0.49, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ENTITY WARS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/UncialAntiqua-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.42))
	box.add_child(title)
	tabs = TabContainer.new()
	box.add_child(tabs)
	for index in 2:
		var form := VBoxContainer.new()
		form.name = tr("AUTH_LOGIN") if index == 0 else tr("AUTH_REGISTER")
		form.add_theme_constant_override("separation", 12)
		tabs.add_child(form)
		var user := _field(form, "AUTH_USERNAME", false)
		username.append(user)
		var pass_field := _field(form, "AUTH_PASSWORD", true)
		password.append(pass_field)
		if index == 1:
			confirm = _field(form, "AUTH_CONFIRM", true)
		var button := Button.new()
		button.text = tr("AUTH_LOGIN") if index == 0 else tr("AUTH_REGISTER")
		button.custom_minimum_size.y = 55
		MenuArt.button(button)
		button.pressed.connect(_submit.bind(index))
		form.add_child(button)
		submit_buttons.append(button)
		user.text_submitted.connect(func(_text: String): _submit(index))
		pass_field.text_submitted.connect(func(_text: String): _submit(index))
		if index == 1:
			confirm.text_submitted.connect(func(_text: String): _submit(index))
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color(0.5, 0.9, 0.94))
	box.add_child(message)
	retry = Button.new()
	retry.text = tr("AUTH_RETRY")
	MenuArt.button(retry)
	retry.pressed.connect(_retry)
	box.add_child(retry)
	retry.hide()
	if OS.has_feature("editor"):
		debug_button = Button.new()
		debug_button.name = "DebugLaboratory"
		debug_button.text = tr("AUTH_DEBUG_LAB")
		debug_button.custom_minimum_size.y = 48
		MenuArt.button(debug_button)
		debug_button.pressed.connect(func():
			if ConnectionGate.enable_debug_lab():
				SceneRouter.go_to_lab_hub())
		box.add_child(debug_button)

func _field(parent: Control, placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = tr(placeholder)
	field.secret = secret
	field.custom_minimum_size.y = 48
	parent.add_child(field)
	return field

func _submit(index: int) -> void:
	if busy or verifying or not endpoint_safe or not preflight_ok:
		return
	var name := username[index].text
	var expression := RegEx.new()
	expression.compile("^[A-Za-z0-9_]{3,20}$")
	if expression.search(name) == null:
		message.text = tr("AUTH_INVALID_USERNAME")
		return
	if password[index].text.length() < 6:
		message.text = tr("AUTH_SHORT_PASSWORD")
		return
	if index == 1 and password[index].text != confirm.text:
		message.text = tr("AUTH_PASSWORD_MISMATCH")
		return
	if index == 1:
		var dir := DirAccess.open("user://")
		if dir == null:
			message.text = tr("AUTH_RECOVERY_REQUIRED")
			return
		for filename in dir.get_files():
			if filename.begins_with("session_recovery_") and filename.ends_with(".json"):
				message.text = tr("AUTH_RECOVERY_REQUIRED")
				return
	busy = true
	submitted_name = name
	for button in submit_buttons: button.disabled = true
	message.text = ""
	retry.hide()
	var payload := JSON.stringify({"username": name, "password": password[index].text})
	var err := http.request(client.base_url + ("/auth/login" if index == 0 else "/auth/register"), PackedStringArray(["Content-Type: application/json", preload("res://scripts/net/client_build.gd").header()]), HTTPClient.METHOD_POST, payload)
	if err != OK:
		_auth_finished()
		message.text = tr("AUTH_CONNECTION_ERROR")
		retry.show()

func _on_auth_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if preflighting:
		preflighting = false
		var version: Variant = JSON.parse_string(body.get_string_from_utf8())
		if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not version is Dictionary or not version.has("min_client_build") or typeof(version.min_client_build) not in [TYPE_INT, TYPE_FLOAT] or float(version.min_client_build) != floor(float(version.min_client_build)) or float(version.min_client_build) < 1 or float(version.min_client_build) > 9007199254740991.0:
			message.text = tr("AUTH_CONNECTION_ERROR")
			retry.show()
		elif float(version.min_client_build) > preload("res://scripts/net/client_build.gd").BUILD:
			message.text = "Update required. Please update Entity Wars to continue."
		else:
			_finish_preflight()
		return
	_auth_finished()
	if code == 426:
		ConnectionGate.require_update()
		return
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code == 408:
		message.text = tr("AUTH_CONNECTION_ERROR")
		retry.show()
		return
	if code < 200 or code >= 300:
		message.text = tr("AUTH_DUPLICATE") if code == 409 else tr("AUTH_INVALID_LOGIN")
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or str(data.get("token", "")).is_empty():
		message.text = tr("AUTH_CONNECTION_ERROR")
		retry.show()
		return
	var identity := str(data.get("player_id", ""))
	var dir := DirAccess.open("user://")
	if identity.is_empty() or dir == null:
		message.text = tr("AUTH_RECOVERY_REQUIRED")
		return
	var expected_journal := "session_recovery_%s.json" % identity.sha256_text()
	for filename in dir.get_files():
		if filename.begins_with("session_recovery_") and filename.ends_with(".json") and filename != expected_journal:
			message.text = tr("AUTH_RECOVERY_REQUIRED")
			return
	if not ConnectionGate.begin_explicit_login():
		message.text = tr("AUTH_RECOVERY_REQUIRED")
		return
	client._last_login_name = submitted_name
	for field in password: field.clear()
	confirm.clear()
	verifying = true
	tabs.hide()
	message.text = tr("AUTH_VERIFYING")
	client.set_token(str(data.token))

func _auth_finished() -> void:
	busy = false
	for button in submit_buttons: button.disabled = false

func _retry() -> void:
	retry.hide()
	if not preflight_ok:
		_start_preflight()
	elif verifying:
		ConnectionGate._check()
	else:
		_submit(tabs.current_tab)

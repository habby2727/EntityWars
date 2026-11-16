extends Node

const MenuArt := preload("res://scripts/ui/menu_art.gd")
enum State { CONNECTED, RECONNECTING, ERROR, AUTH_REQUIRED }
var state: State = State.CONNECTED
var player_id := ""
var token := ""
var base_url := ""
var _http: HTTPRequest
var _timer: Timer
var _attempt := 0
var _generation := 0
var _checking := false
var _player_verified := false
var _identity_mismatch := false
var _recovery_owner_id := 0
var _loadout_session_requested := false
var _loadout_session_verified := false
var _layer: CanvasLayer
var _title: Label
var _detail: Label
var _retry: Button

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_check_completed)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_check)
	add_child(_timer)
	_create_overlay()

func register_identity(client: Node, identity: String) -> void:
	if identity.is_empty() or str(client.token).is_empty():
		return
	if not player_id.is_empty() and player_id != identity:
		_identity_mismatch = true
		_fail(State.ERROR, "Account changed. Sign in with the original account.")
		return
	if player_id.is_empty():
		player_id = identity
		token = client.token
		base_url = client.base_url
		_timer.start(15.0)
	elif token != client.token:
		token = client.token
		_generation += 1
		if state != State.CONNECTED:
			_check()

func require_authentication() -> void:
	_fail(State.AUTH_REQUIRED, "Authentication required")

func observe_credentials(client: Node) -> void:
	if player_id.is_empty() and token.is_empty() and not str(client.token).is_empty():
		token = str(client.token)
		base_url = str(client.base_url)

func authentication_changed(new_token: String, url: String) -> void:
	if player_id.is_empty() and token.is_empty() and state == State.CONNECTED:
		token = new_token
		base_url = url
		return
	if new_token.is_empty():
		token = ""
		_generation += 1
		require_authentication()
	elif token != new_token:
		token = new_token
		base_url = url
		_generation += 1
		if state == State.AUTH_REQUIRED:
			state = State.CONNECTED
		_fail(State.RECONNECTING, "Recovering connection and verifying your session...")
		_check()

func blocked() -> bool:
	return state != State.CONNECTED

func report_failure(client: Node, reason: String, status: int = 0) -> void:
	if str(client.token).is_empty():
		return
	observe_credentials(client)
	if status in [401, 403] or reason == "identity_mismatch":
		if reason == "identity_mismatch":
			_identity_mismatch = true
		_fail(State.AUTH_REQUIRED if status in [401, 403] else State.ERROR, "Authentication required" if status in [401, 403] else "Account changed. Sign in with the original account.")
	elif reason in ["network_error", "bad_json", "bad_state"] or status >= 500 or status == 408:
		_fail(State.RECONNECTING, "Recovering connection and verifying your session...")

func _fail(next: State, message: String) -> void:
	if (state == State.AUTH_REQUIRED or _identity_mismatch) and next == State.RECONNECTING:
		return
	var was_connected := state == State.CONNECTED
	state = next
	_player_verified = false
	_loadout_session_requested = false
	_loadout_session_verified = false
	_title.text = "Disconnected (Reconnecting...)" if next == State.RECONNECTING else "Error"
	_detail.text = message
	_layer.show()
	if was_connected:
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.has_method("connection_gate_lost"):
			_recovery_owner_id = scene.get_instance_id()
			scene.connection_gate_lost()
		elif is_instance_valid(scene) and scene.has_method("_recover_hunt_session") and (not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty() or not str(SceneRouter._dungeon_context.get("run_id", "")).is_empty()):
			_recovery_owner_id = scene.get_instance_id()
	if next == State.RECONNECTING:
		_schedule_retry()

func _schedule_retry() -> void:
	if _checking:
		return
	var delay := minf(30.0, float(2 ** mini(_attempt + 1, 5)))
	_attempt += 1
	_timer.start(delay)

func _check() -> void:
	if _checking or _identity_mismatch or token.is_empty():
		return
	_timer.stop()
	_checking = true
	_http.set_meta("generation", _generation)
	var err := _http.request(base_url + "/player/state", PackedStringArray(["Authorization: Bearer " + token]), HTTPClient.METHOD_GET)
	if err != OK:
		_checking = false
		_fail(State.RECONNECTING, "Recovering connection and verifying your session...")

func _on_check_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_checking = false
	if int(_http.get_meta("generation", -1)) != _generation:
		_check()
		return
	if code in [401, 403]:
		_fail(State.AUTH_REQUIRED, "Authentication required")
		return
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_fail(State.RECONNECTING, "Recovering connection and verifying your session...")
		return
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(body.get_string_from_utf8()) == OK else null
	if not parsed is Dictionary or not parsed.get("updated_player_state") is Dictionary or (parsed.has("ok") and not bool(parsed.ok)):
		_fail(State.ERROR, "Invalid server response. Retry connection.")
		_schedule_retry()
		return
	var recovered_id := str(parsed.updated_player_state.get("player_id", ""))
	if recovered_id.is_empty() or recovered_id.length() > 128:
		_fail(State.ERROR, "Invalid server response. Retry connection.")
		_schedule_retry()
		return
	if not player_id.is_empty() and recovered_id != player_id:
		_identity_mismatch = true
		_fail(State.ERROR, "Account changed. Sign in with the original account.")
		return
	if player_id.is_empty():
		player_id = recovered_id
	if state == State.CONNECTED:
		_attempt = 0
		_timer.start(15.0)
		return
	_player_verified = true
	var scene := get_tree().current_scene
	if _recovery_owner_id != 0 and (not is_instance_valid(scene) or scene.get_instance_id() != _recovery_owner_id):
		_detail.text = "The original session must be recovered before continuing."
		_timer.start(2.0)
	elif is_instance_valid(scene) and scene.has_method("connection_gate_recover"):
		scene.connection_gate_recover()
		_timer.start(2.0)
	elif is_instance_valid(scene) and scene.has_method("_recover_hunt_session") and (not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty() or not str(SceneRouter._dungeon_context.get("run_id", "")).is_empty()):
		_recover_loadout(scene)
		if blocked():
			_timer.start(2.0)
	elif not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty() or not str(SceneRouter._dungeon_context.get("run_id", "")).is_empty():
		_detail.text = "Session recovery is required before continuing."
		_timer.start(2.0)
	else:
		_unlock()

func recovery_completed() -> void:
	if blocked() and _player_verified:
		_unlock()

func _recover_loadout(scene: Node) -> void:
	var dungeon := not str(SceneRouter._dungeon_context.get("run_id", "")).is_empty()
	var client: BackendClient = scene._dungeon_backend if dungeon else scene._hunt_backend
	if client == null or client.token != token:
		return
	if client._verified_player_id.is_empty():
		client.refresh_state()
		return
	if client._verified_player_id != player_id or not client._api_in_flight.is_empty():
		return
	if not _loadout_session_verified:
		if _loadout_session_requested:
			var recovered: bool = scene._dungeon_recovered if dungeon else scene._hunt_recovered
			if recovered:
				_loadout_session_verified = true
			else:
				_loadout_session_requested = false
				return
		else:
			if dungeon:
				scene._dungeon_recovered = false
				scene._dungeon_kind = "session"
				scene._dungeon_request = client.request_api("GET", "/dungeon/session", null, false, true)
				_loadout_session_requested = not scene._dungeon_request.is_empty()
			else:
				scene._hunt_recovered = false
				var path := "/world/boss-hunts/session?session_id=" + str(SceneRouter._solo_hunt_context.get("session_id", "")).uri_encode()
				scene._hunt_recovery_request = client.request_api("GET", path, null, false, true)
				_loadout_session_requested = not scene._hunt_recovery_request.is_empty()
			return
	var pending: Dictionary = scene._dungeon_payload if dungeon else scene._hunt_payload
	if not pending.is_empty():
		if dungeon:
			scene._dungeon_kind = "loadout"
			scene._dungeon_request = client.request_api("POST", "/dungeon/loadout", pending.duplicate(true), false, true)
		else:
			scene._hunt_submit_request = client.request_api("POST", "/world/boss-hunts/loadout", pending.duplicate(true), false, true)
		return
	_unlock()
	if dungeon and SceneRouter._dungeon_context.has("session"):
		get_tree().call_deferred("change_scene_to_file", SceneRouter.SCENE_COMBAT)

func _unlock() -> void:
	state = State.CONNECTED
	_attempt = 0
	_player_verified = false
	_recovery_owner_id = 0
	_loadout_session_requested = false
	_loadout_session_verified = false
	_layer.hide()
	_timer.start(15.0)
	for client in get_tree().get_nodes_in_group("backend_session_clients"):
		if client.auto_flush and client._verified_player_id == player_id:
			client.call_deferred("flush_queue")

func _input(event: InputEvent) -> void:
	if blocked() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()

func _create_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 1000
	add_child(_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.035, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 260)
	var art := StyleBoxTexture.new()
	art.texture = load("res://assets/ui/new-elements/marco-horizontal-popup-grande.png")
	art.content_margin_left = 45
	art.content_margin_right = 45
	art.content_margin_top = 35
	art.content_margin_bottom = 35
	panel.add_theme_stylebox_override("panel", art)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	box.add_child(_title)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail)
	_retry = Button.new()
	_retry.text = "Retry Connection"
	_retry.custom_minimum_size = Vector2(220, 48)
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	MenuArt.button(_retry)
	_retry.pressed.connect(_check)
	box.add_child(_retry)
	_layer.hide()

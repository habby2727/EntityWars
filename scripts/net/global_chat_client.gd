extends Node

signal updated
signal send_finished(success: bool)

var messages: Array = []
var latest_id := 0
var unread := false
var online_count := 0
var online_players: Array = []
var error_key := ""
var panel_open := false
var _initialized := false
var _identity := ""
var _was_available := false
var _next_poll := 0
var _poll: HTTPRequest
var _send: HTTPRequest
var _poll_busy := false
var _send_busy := false
var _pending_text := ""
var _pending_id := ""
var _panel: CanvasLayer
var _scene_id := 0

func _ready() -> void:
	_panel = preload("res://scripts/ui/global_chat_panel.gd").new()
	add_child(_panel)
	_poll = HTTPRequest.new()
	_send = HTTPRequest.new()
	_poll.max_redirects = 0
	_send.max_redirects = 0
	_poll.timeout = 8.0
	_send.timeout = 8.0
	add_child(_poll)
	add_child(_send)
	_poll.request_completed.connect(_poll_completed)
	_send.request_completed.connect(_send_completed)

func available() -> bool:
	return not ConnectionGate.blocked() and not ConnectionGate.player_id.is_empty() and not ConnectionGate.token.is_empty() and not ConnectionGate.base_url.is_empty()

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var scene_id := scene.get_instance_id() if is_instance_valid(scene) else 0
	if scene_id != _scene_id:
		_scene_id = scene_id
		if is_instance_valid(scene) and scene.scene_file_path in [SceneRouter.SCENE_COMBAT, SceneRouter.SCENE_LOADOUT]:
			_panel._close()
			_panel._online_panel.hide()
	_panel.visible = available() and is_instance_valid(scene) and not scene.has_method("auth_gate_screen") and not scene.scene_file_path.to_lower().contains("loading")
	var identity: String = ConnectionGate.player_id
	if not identity.is_empty() and identity != _identity:
		_identity = identity
		messages = []
		online_players = []
		online_count = 0
		latest_id = 0
		unread = false
		_initialized = false
		_pending_id = ""
		_pending_text = ""
		_next_poll = 0
	var connected := available()
	if connected != _was_available:
		_was_available = connected
		if connected:
			_next_poll = 0
		else:
			_poll.cancel_request()
			_send.cancel_request()
			_poll_busy = false
			_send_busy = false
			online_count = 0
			online_players = []
		updated.emit()
	if connected and not _poll_busy and Time.get_ticks_msec() >= _next_poll:
		poll_now()

func poll_now() -> void:
	if not available() or _poll_busy:
		return
	_next_poll = Time.get_ticks_msec() + (5000 if panel_open else 15000)
	_poll_busy = true
	var err := _poll.request(ConnectionGate.base_url + "/chat/state", PackedStringArray(["Authorization: Bearer " + ConnectionGate.token, preload("res://scripts/net/client_build.gd").header()]))
	if err != OK:
		_poll_busy = false
		error_key = "CHAT_UNAVAILABLE"
		updated.emit()

func _poll_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_poll_busy = false
	if code == 401:
		ConnectionGate.require_authentication()
		return
	if code == 426:
		ConnectionGate.require_update()
		return
	if not available():
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary or not data.get("messages") is Array:
		error_key = "CHAT_UNAVAILABLE"
		updated.emit()
		return
	error_key = ""
	_apply_snapshot(data)

func _apply_snapshot(data: Dictionary) -> void:
	var incoming: Array = data.get("messages", []).slice(-20)
	for entry in incoming:
		if not entry is Dictionary:
			continue
		var id := int(entry.get("id", 0))
		if _initialized and id > latest_id and str(entry.get("player_id", "")) != ConnectionGate.player_id and not panel_open:
			unread = true
	var newest := latest_id
	for entry in incoming:
		if entry is Dictionary:
			newest = maxi(newest, int(entry.get("id", 0)))
	latest_id = newest
	_initialized = true
	messages = incoming
	online_count = int(data.get("online_count", 0))
	var players: Variant = data.get("online_players", [])
	online_players = players if players is Array else []
	updated.emit()

func set_panel_open(value: bool) -> void:
	panel_open = value
	if value:
		unread = false
		_next_poll = 0
	updated.emit()

func send_message(text: String) -> bool:
	if not available() or _send_busy:
		error_key = "CHAT_UNAVAILABLE"
		updated.emit()
		return false
	if text.length() > 200:
		error_key = "CHAT_TOO_LONG"
		updated.emit()
		return false
	if text.strip_edges().is_empty():
		error_key = "CHAT_INVALID"
		updated.emit()
		return false
	if _pending_id.is_empty() or _pending_text != text:
		_pending_text = text
		_pending_id = "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]
	_send_busy = true
	var headers := PackedStringArray(["Authorization: Bearer " + ConnectionGate.token, "Content-Type: application/json", preload("res://scripts/net/client_build.gd").header()])
	var err := _send.request(ConnectionGate.base_url + "/chat/send", headers, HTTPClient.METHOD_POST, JSON.stringify({"text": text, "client_message_id": _pending_id}))
	if err != OK:
		_send_busy = false
		error_key = "CHAT_UNAVAILABLE"
		updated.emit()
		return false
	return true

func _send_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_send_busy = false
	if code == 401:
		ConnectionGate.require_authentication()
		return
	if code == 426:
		ConnectionGate.require_update()
		return
	if not available():
		return
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_pending_id = ""
		_pending_text = ""
		error_key = ""
		send_finished.emit(true)
		poll_now()
	else:
		error_key = "CHAT_RATE_LIMIT" if code == 429 else ("CHAT_INVALID" if code == 400 else "CHAT_UNAVAILABLE")
		send_finished.emit(false)
	updated.emit()

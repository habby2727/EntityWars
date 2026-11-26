extends Node

signal updated(data: Dictionary, initial: bool)
signal failed(message: String)
var _http: HTTPRequest
var _request := ""
var _owner := ""
var _base := ""
var _generation := -1
var _target := ""
var _target_name := ""
var _origin := ""
var _observation := ""
var _mode := ""
var _cursor := 0
var _initial := true
var _next := 0
var _closed := false
var _view_ready := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	_http.max_redirects = 0
	add_child(_http)
	_http.request_completed.connect(_completed)

func start(target: String, username: String) -> void:
	if not _request.is_empty() or not _observation.is_empty() or target.is_empty() or target == str(ConnectionGate.player_id) or not SceneRouter._forest_modes_safe() or not GlobalChatClient.available(): return
	if not preload("res://scripts/net/practice_recovery.gd").read().is_empty() or not DuelClient._tracked_invite.is_empty() or not DuelClient._pending_body.is_empty():
		failed.emit("SPECTATOR_UNAVAILABLE")
		return
	_owner = str(ConnectionGate.player_id)
	_base = str(ConnectionGate.base_url).strip_edges().trim_suffix("/")
	_generation = int(ConnectionGate._generation)
	_target = target
	_target_name = username
	var scene := get_tree().current_scene
	_origin = scene.scene_file_path if is_instance_valid(scene) else ""
	_send("POST", "/spectator/start", {"target_player_id":target}, "start")

func _valid() -> bool:
	return not _owner.is_empty() and _owner == str(ConnectionGate.player_id) and _base == str(ConnectionGate.base_url).strip_edges().trim_suffix("/") and _generation == int(ConnectionGate._generation) and not str(ConnectionGate.token).is_empty()

func _send(method: String, path: String, payload: Variant, kind: String) -> bool:
	if not _request.is_empty() or not _valid(): return false
	var headers := PackedStringArray(["Authorization: Bearer " + ConnectionGate.token, "Content-Type: application/json", preload("res://scripts/net/client_build.gd").header()])
	_request = kind
	var code := _http.request(_base + path, headers, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, JSON.stringify(payload) if payload != null else "")
	if code != OK:
		_request = ""
		return false
	return true

func _process(_delta: float) -> void:
	if _owner.is_empty(): return
	if ConnectionGate.blocked(): return
	if not _valid():
		_http.cancel_request()
		_request = ""
		_observation = ""
		_owner = ""
		failed.emit("SPECTATOR_CONNECTION")
		return
	if _view_ready and not _observation.is_empty() and not _closed and _request.is_empty() and Time.get_ticks_msec() >= _next:
		_next = Time.get_ticks_msec() + 2000
		_send("GET", "/spectator/state?observation_id=%s&after=%d" % [_observation.uri_encode(), _cursor], null, "state")

func _completed(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	var kind := _request
	_request = ""
	if not _valid(): return
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary:
		if kind == "start":
			_owner = ""
			failed.emit("SPECTATOR_UNAVAILABLE")
		elif code >= 400 and code < 500:
			_closed = true
			failed.emit("SPECTATOR_ENDED")
		return
	if kind == "start":
		_observation = str(data.get("observation_id", ""))
		_mode = str(data.get("mode", ""))
		if _observation.is_empty() or _mode not in ["ranked", "friendly", "practice", "hunt", "dungeon", "expedition"]:
			_owner = ""
			failed.emit("SPECTATOR_UNAVAILABLE")
			return
		var context := {"observation_id":_observation, "mode":_mode, "player_id":_owner, "base_url":_base, "generation":_generation, "username":_target_name, "origin":_origin}
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.has_method("spectator_handoff"):
			await scene.spectator_handoff(context)
		else:
			SceneRouter.begin_spectating(context)
		if SceneRouter._spectator_context.is_empty():
			leave()
		return
	if kind != "state" or str(data.get("observation_id", "")) != _observation or not data.get("snapshot") is Dictionary or not data.get("events") is Array: return
	for event in data.events:
		if event is Dictionary: _cursor = maxi(_cursor, int(event.get("id", 0)))
	_closed = bool(data.get("closed", false))
	updated.emit(data, _initial)
	_initial = false

func pause_for_recovery() -> void:
	if not _request.is_empty(): _http.cancel_request()
	_request = ""

func recover_after_gate() -> bool:
	if _owner.is_empty() or _owner != str(ConnectionGate.player_id) or _base != str(ConnectionGate.base_url).strip_edges().trim_suffix("/") or str(ConnectionGate.token).is_empty() or not bool(ConnectionGate._player_verified): return false
	_generation = int(ConnectionGate._generation)
	if not SceneRouter._spectator_context.is_empty(): SceneRouter._spectator_context["generation"] = _generation
	_initial = true
	_next = 0
	return true

func ready_to_observe() -> void:
	if _valid() and not _observation.is_empty():
		_view_ready = true
		_next = 0

func leave() -> void:
	if not _request.is_empty(): _http.cancel_request(); _request = ""
	if _valid() and not _observation.is_empty() and not _closed:
		_send("POST", "/spectator/leave", {"observation_id":_observation}, "leave")
	_observation = ""
	_owner = ""
	_closed = false
	_view_ready = false
	_cursor = 0
	_initial = true

func reset_for_logout() -> void:
	leave()

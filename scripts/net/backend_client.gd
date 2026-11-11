extends Node
class_name BackendClient

signal action_sent(action_id: String, action_key: String)
signal action_queued(action_id: String, action_key: String, reason: String)
signal action_confirmed(action_id: String)
signal action_failed(action_id: String, error: String)
signal state_updated(state: Dictionary)
signal queue_drained()
signal auth_changed(token: String)
signal api_completed(request_id: String, ok: bool, data: Dictionary)

@export var base_url := "http://127.0.0.1:8787"
@export var auto_flush := true
@export var auto_dev_login := true
@export var dev_display_name := ""

const AUTH_PATH := "user://auth.json"
static var _auto_login_started := false

var token: String = ""
var last_server_time_unix_ms: int = -1

var _http: HTTPRequest = null
var _api_http: HTTPRequest = null
var _pending := PendingQueue.new()
var _reconcile := Reconcile.new(_pending)
var _in_flight: Dictionary = {}
var _pending_keys: Dictionary = {}
var _api_in_flight: Dictionary = {}
var _auth_loaded := false
var _last_login_name := ""
var _debug_bypass := false
var _debug_flags := DebugFlags.new()

func _ready() -> void:
	_ensure_http()
	_pending.load()
	_build_pending_keys()
	_reconcile.load_cached_state()
	_load_debug_flags()
	_load_auth()
	if auto_dev_login and token == "" and not _auto_login_started:
		_auto_login_started = true
		var dev_name := _get_dev_name()
		_last_login_name = dev_name
		login_dev(dev_name)
	if auto_flush and token != "":
		flush_queue()

func set_token(new_token: String) -> void:
	token = new_token.strip_edges()
	_save_auth()
	emit_signal("auth_changed", token)
	if auto_flush and token != "":
		flush_queue()

func login_dev(display_name: String) -> void:
	var use_name := display_name.strip_edges()
	if use_name == "":
		use_name = _get_dev_name()
	_last_login_name = use_name
	var payload = {"name": use_name}
	var err = _send_request("POST", "/auth/dev_login", payload, {"kind": "login"})
	if err != OK:
		push_error("BackendClient: login failed to send (%s)" % err)

func ensure_dev_login() -> void:
	if token != "":
		return
	if _auto_login_started:
		return
	_auto_login_started = true
	var dev_name := _get_dev_name()
	_last_login_name = dev_name
	login_dev(dev_name)

func load_cached_state() -> Dictionary:
	return _reconcile.get_state()

func get_server_time_unix_ms() -> int:
	return last_server_time_unix_ms

func save_cached_state(state: Dictionary) -> void:
	_reconcile.save_cached_state(state)

func get_pending_count() -> int:
	return _pending.size()

func get_pending_actions() -> Array:
	return _pending.to_array()

func send_action(action_dict: Dictionary) -> String:
	var action = _normalize_action(action_dict)
	if action.is_empty():
		return ""
	var action_id: String = action.get("client_action_id", "")
	var online_only := str(action.get("action_type", "")) == "SET_SPELL_LOADOUT"
	var key := _make_action_key(action)
	if key != "" and _pending_keys.has(key):
		return str(_pending_keys[key])
	if _in_flight.size() > 0:
		if online_only:
			return ""
		_enqueue_action(action, key, "busy")
		return action_id
	if token == "":
		if online_only:
			return ""
		_enqueue_action(action, key, "no_token")
		return action_id
	var err = _send_request("POST", "/player/action", action, {"kind": "action", "action": action, "action_key": key})
	if err != OK:
		if online_only:
			return ""
		_enqueue_action(action, key, "offline")
		return action_id
	_in_flight = {"kind": "action", "action": action, "action_key": key}
	_pending_keys[key] = action_id
	emit_signal("action_sent", action_id, key)
	return action_id

func refresh_state() -> void:
	if token == "":
		return
	var err = _send_request("GET", "/player/state", null, {"kind": "state"})
	if err != OK:
		push_error("BackendClient: refresh_state failed to send (%s)" % err)

func request_api(method: String, path: String, body: Variant, expect_state: bool = false) -> String:
	_ensure_api_http()
	if _api_in_flight.size() > 0:
		return ""
	var request_id := _make_uuid()
	var meta := {"kind": "api", "request_id": request_id, "expect_state": expect_state}
	var err = _send_api_request(method, path, body, meta)
	if err != OK:
		return ""
	_api_in_flight = meta
	return request_id

func flush_queue() -> void:
	if _in_flight.size() > 0:
		return
	if _pending.size() == 0:
		emit_signal("queue_drained")
		return
	var next_action = _pending.peek()
	if next_action.is_empty():
		return
	var ct = next_action.get("client_time_unix_ms", null)
	if typeof(ct) != TYPE_INT and typeof(ct) != TYPE_FLOAT:
		next_action["client_time_unix_ms"] = Time.get_unix_time_from_system() * 1000
	var action_id = str(next_action.get("client_action_id", ""))
	if action_id == "":
		_pending.pop_next()
		_pending.save()
		flush_queue()
		return
	var key := _make_action_key(next_action)
	if token == "":
		return
	var err = _send_request(
		"POST",
		"/player/action",
		next_action,
		{"kind": "action", "action": next_action, "action_key": key, "queued": true}
	)
	if err != OK:
		return
	_in_flight = {"kind": "action", "action": next_action, "action_key": key, "queued": true}
	_pending_keys[key] = action_id
	emit_signal("action_sent", action_id, key)

func _normalize_action(action_dict: Dictionary) -> Dictionary:
	if typeof(action_dict) != TYPE_DICTIONARY:
		push_error("BackendClient: action must be a Dictionary.")
		return {}
	if not action_dict.has("action_type"):
		push_error("BackendClient: action_type missing.")
		return {}
	var action_type = str(action_dict.get("action_type", "")).strip_edges()
	if action_type == "":
		push_error("BackendClient: action_type empty.")
		return {}
	var payload = action_dict.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}
	var action_id = str(action_dict.get("client_action_id", ""))
	if action_id == "":
		action_id = _make_uuid()
	var client_time = action_dict.get("client_time_unix_ms", action_dict.get("created_at", 0))
	if typeof(client_time) != TYPE_INT and typeof(client_time) != TYPE_FLOAT:
		client_time = Time.get_unix_time_from_system() * 1000
	var out = {
		"client_action_id": action_id,
		"action_type": action_type,
		"payload": payload,
		"client_time_unix_ms": client_time
	}
	return out

func _make_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var part1 = "%08x" % rng.randi()
	var part2 = "%04x" % (rng.randi() & 0xffff)
	var part3 = "%04x" % ((rng.randi() & 0x0fff) | 0x4000)
	var part4 = "%04x" % ((rng.randi() & 0x3fff) | 0x8000)
	var part5 = "%012x" % ((rng.randi() << 16) | (rng.randi() & 0xffff))
	return "%s-%s-%s-%s-%s" % [part1, part2, part3, part4, part5]

func _make_action_key(action: Dictionary) -> String:
	var action_type = str(action.get("action_type", ""))
	if action_type == "":
		return ""
	var payload = action.get("payload", {})
	var key = action_type
	if typeof(payload) == TYPE_DICTIONARY:
		if payload.has("building_id"):
			key += ":" + str(payload.get("building_id"))
		elif payload.has("resource_id"):
			key += ":" + str(payload.get("resource_id"))
	return key

func _enqueue_action(action: Dictionary, key: String, reason: String) -> void:
	_pending.enqueue(action)
	_pending.save()
	if key != "":
		_pending_keys[key] = action.get("client_action_id", "")
	emit_signal("action_queued", action.get("client_action_id", ""), key, reason)

func _build_pending_keys() -> void:
	_pending_keys.clear()
	var list = _pending.to_array()
	for action in list:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var key := _make_action_key(action)
		if key == "":
			continue
		_pending_keys[key] = action.get("client_action_id", "")

func _send_request(method: String, path: String, body: Variant, meta: Dictionary) -> int:
	_ensure_http()
	var action: Dictionary = meta.get("action", {})
	_http.timeout = 8.0 if str(action.get("action_type", "")) == "SET_SPELL_LOADOUT" else 0.0
	_load_debug_flags()
	var url = base_url + path
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer %s" % token)
	if _debug_bypass:
		headers.append("X-Debug-Bypass: 1")
	var body_text := ""
	if body != null:
		body_text = JSON.stringify(body)
	var http_method := HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST
	_http.set_meta("request_meta", meta)
	return _http.request(url, headers, http_method, body_text)

func _send_api_request(method: String, path: String, body: Variant, meta: Dictionary) -> int:
	_ensure_api_http()
	_load_debug_flags()
	var url = base_url + path
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer %s" % token)
	if _debug_bypass:
		headers.append("X-Debug-Bypass: 1")
	var body_text := ""
	if body != null:
		body_text = JSON.stringify(body)
	var http_method := HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST
	_api_http.set_meta("request_meta", meta)
	return _api_http.request(url, headers, http_method, body_text)

func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func _ensure_api_http() -> void:
	if _api_http != null:
		return
	_api_http = HTTPRequest.new()
	add_child(_api_http)
	_api_http.request_completed.connect(_on_api_request_completed)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var meta = _http.get_meta("request_meta") if _http.has_meta("request_meta") else {}
	_http.remove_meta("request_meta")
	var kind = str(meta.get("kind", ""))
	var action: Dictionary = meta.get("action", {})
	var action_id = str(action.get("client_action_id", ""))
	var action_key = str(meta.get("action_key", ""))
	var was_queued = bool(meta.get("queued", false))
	_in_flight.clear()
	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_request_failure(kind, action, action_key, "network_error", was_queued)
		return
	if response_code < 200 or response_code >= 300:
		var err_data = _parse_json(body)
		if typeof(err_data) == TYPE_DICTIONARY and err_data.has("error"):
			var msg = str(err_data.get("error", "http_%s" % response_code))
			_handle_request_failure(kind, action, action_key, "server_reject:%s" % msg, was_queued)
		else:
			var err = "http_%s" % response_code
			_handle_request_failure(kind, action, action_key, err, was_queued)
		return
	var data = _parse_json(body)
	if typeof(data) != TYPE_DICTIONARY:
		_handle_request_failure(kind, action, action_key, "bad_json", was_queued)
		return
	var ok = true
	if data.has("server_time_unix_ms"):
		last_server_time_unix_ms = int(data.get("server_time_unix_ms", -1))
	if data.has("ok"):
		ok = bool(data.get("ok", true))
	if not ok:
		var err_msg = str(data.get("error", "server_error"))
		_handle_request_failure(kind, action, action_key, "server_reject:%s" % err_msg, was_queued)
		return
	if kind == "login":
		var new_token = str(data.get("token", ""))
		if new_token != "":
			set_token(new_token)
		return
	if kind == "state":
		var state = data.get("updated_player_state", data)
		if typeof(state) != TYPE_DICTIONARY:
			_handle_request_failure(kind, action, action_key, "bad_state", was_queued)
			return
		_reconcile.apply_server_state(state)
		emit_signal("state_updated", state)
		return
	if kind == "action":
		var state = data.get("updated_player_state", data)
		if typeof(state) != TYPE_DICTIONARY:
			_handle_request_failure(kind, action, action_key, "bad_state", was_queued)
			return
		_reconcile.apply_server_state(state, action_id)
		emit_signal("state_updated", state)
		emit_signal("action_confirmed", action_id)
		if action_key != "":
			_pending_keys.erase(action_key)
		flush_queue()
		if _pending.size() == 0:
			emit_signal("queue_drained")

func _on_api_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var meta = _api_http.get_meta("request_meta").duplicate() if _api_http.has_meta("request_meta") else {}
	_api_http.remove_meta("request_meta")
	_api_in_flight.clear()
	var request_id = str(meta.get("request_id", ""))
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("api_completed", request_id, false, {"error": "network_error"})
		return
	if response_code < 200 or response_code >= 300:
		var err_data = _parse_json(body)
		if typeof(err_data) == TYPE_DICTIONARY and err_data.has("error"):
			emit_signal("api_completed", request_id, false, err_data)
		else:
			emit_signal("api_completed", request_id, false, {"error": "http_%s" % response_code})
		return
	var data = _parse_json(body)
	if typeof(data) != TYPE_DICTIONARY:
		emit_signal("api_completed", request_id, false, {"error": "bad_json"})
		return
	if data.has("server_time_unix_ms"):
		last_server_time_unix_ms = int(data.get("server_time_unix_ms", -1))
	var ok = true
	if data.has("ok"):
		ok = bool(data.get("ok", true))
	if not ok:
		emit_signal("api_completed", request_id, false, data)
		return
	if bool(meta.get("expect_state", false)) or data.has("updated_player_state"):
		var state = data.get("updated_player_state", data)
		if typeof(state) == TYPE_DICTIONARY:
			_reconcile.apply_server_state(state)
			emit_signal("state_updated", state)
	emit_signal("api_completed", request_id, true, data)

func _handle_request_failure(kind: String, action: Dictionary, action_key: String, reason: String, was_queued: bool) -> void:
	if kind == "action":
		if str(action.get("action_type", "")) == "SET_SPELL_LOADOUT" and not was_queued:
			emit_signal("action_failed", str(action.get("client_action_id", "")), reason)
			if action_key != "":
				_pending_keys.erase(action_key)
			return
		if reason.begins_with("http_4") or reason.begins_with("server_reject") or reason in ["server_error", "bad_state"]:
			emit_signal("action_failed", str(action.get("client_action_id", "")), reason)
			if action_key != "":
				_pending_keys.erase(action_key)
			return
		if not was_queued:
			_enqueue_action(action, action_key, reason)
		return
	if kind == "state":
		return
	if kind == "login":
		_auto_login_started = false
		return
	if was_queued:
		return

func _parse_json(body: PackedByteArray) -> Variant:
	if body.is_empty():
		return {}
	var text = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return {}
	if typeof(parsed) == TYPE_OBJECT:
		if parsed.error != OK:
			return {}
		return parsed.result
	return parsed

func _load_auth() -> void:
	if _auth_loaded:
		return
	_auth_loaded = true
	if not FileAccess.file_exists(AUTH_PATH):
		return
	var f = FileAccess.open(AUTH_PATH, FileAccess.ModeFlags.READ as FileAccess.ModeFlags)
	if f == null:
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		var tok = str(parsed.get("token", "")).strip_edges()
		if tok != "":
			token = tok
		if dev_display_name == "":
			var saved_name = str(parsed.get("dev_name", "")).strip_edges()
			if saved_name != "":
				dev_display_name = saved_name

func _load_debug_flags() -> void:
	_debug_flags.reload()
	_debug_bypass = bool(_debug_flags.unlock_all_buildings or _debug_flags.force_all_clickable)

func _save_auth() -> void:
	var data := {}
	if token != "":
		data["token"] = token
	var name_to_save := ""
	if _last_login_name != "":
		name_to_save = _last_login_name
	elif dev_display_name != "":
		name_to_save = dev_display_name
	if name_to_save != "":
		data["dev_name"] = name_to_save
	var f = FileAccess.open(AUTH_PATH, FileAccess.ModeFlags.WRITE as FileAccess.ModeFlags)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

func _get_dev_name() -> String:
	if dev_display_name != "":
		return dev_display_name
	var os_name := ""
	var env_user := str(OS.get_environment("USERNAME")).strip_edges()
	if env_user == "":
		env_user = str(OS.get_environment("USER")).strip_edges()
	if env_user != "":
		os_name = env_user
	if os_name != "":
		return os_name
	return "DevPlayer"

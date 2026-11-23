extends Node

signal state_changed
signal mutation_finished(success: bool)

var friends := {}
var incoming: Array = []
var outgoing: Array = []
var enabled := false
var error_key := ""
var _identity := ""
var _next_poll := 0
var _poll: HTTPRequest
var _mutation: HTTPRequest
var _poll_busy := false
var _mutation_busy := false
var _pending_path := ""
var _pending_body := ""
var _epoch := 0
var last_response_id := ""
var _popup: CanvasLayer

func _ready() -> void:
	_popup = preload("res://scripts/ui/social_popup.gd").new()
	add_child(_popup)
	_reset_requests()

func available() -> bool:
	return not ConnectionGate.blocked() and not ConnectionGate.debug_offline_enabled and not ConnectionGate.player_id.is_empty() and not ConnectionGate.token.is_empty() and not ConnectionGate.base_url.is_empty()

func _identity_key() -> String:
	return JSON.stringify([ConnectionGate.player_id, ConnectionGate.token, ConnectionGate.base_url, ConnectionGate._generation, available()])

func _process(_delta: float) -> void:
	var key := _identity_key()
	if key != _identity:
		_identity = key
		_epoch += 1
		_reset_requests()
		_clear_state()
		_pending_path = ""
		_pending_body = ""
		last_response_id = ""
		_next_poll = 0
		state_changed.emit()
	if available() and not _poll_busy and Time.get_ticks_msec() >= _next_poll:
		poll_now()

func _reset_requests() -> void:
	for node in [_poll, _mutation]:
		if is_instance_valid(node):
			node.cancel_request()
			node.queue_free()
	_poll_busy = false
	_mutation_busy = false
	_poll = HTTPRequest.new()
	_mutation = HTTPRequest.new()
	for node in [_poll, _mutation]:
		node.timeout = 8.0
		node.max_redirects = 0
		add_child(node)
	_poll.request_completed.connect(_poll_completed.bind(_epoch))
	_mutation.request_completed.connect(_mutation_completed.bind(_epoch))

func _clear_state() -> void:
	friends.clear()
	incoming.clear()
	outgoing.clear()
	enabled = false
	error_key = ""

func _headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + ConnectionGate.token, "Content-Type: application/json", preload("res://scripts/net/client_build.gd").header()])

func _decode(body: PackedByteArray) -> Variant:
	if body.is_empty():
		return null
	var json := JSON.new()
	return json.data if json.parse(body.get_string_from_utf8()) == OK else null

func poll_now() -> void:
	if not available() or _poll_busy:
		return
	var scene := get_tree().current_scene
	_next_poll = Time.get_ticks_msec() + (3000 if is_instance_valid(scene) and scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD else 5000)
	_poll_busy = true
	if _poll.request(ConnectionGate.base_url + "/social/state", _headers()) != OK:
		_poll_busy = false
		error_key = "SOCIAL_FAILURE"
		state_changed.emit()

func _auth_response(result: int, code: int, data: Variant) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS:
		return false
	if code == 401:
		ConnectionGate.require_authentication()
		return true
	if code == 426:
		ConnectionGate.require_update()
		return true
	if code == 409 and data is Dictionary and data.get("error") == "SESSION_IDLE":
		ConnectionGate.require_idle()
		return true
	return false

func _poll_completed(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray, epoch: int) -> void:
	if epoch != _epoch or _identity != _identity_key():
		return
	_poll_busy = false
	var data: Variant = _decode(body)
	if _auth_response(result, code, data):
		return
	if result == HTTPRequest.RESULT_SUCCESS and code == 503 and data is Dictionary and data.get("error") == "SOCIAL_DISABLED":
		_epoch += 1
		_reset_requests()
		_clear_state()
		_pending_body = ""
		_pending_path = ""
		_next_poll = Time.get_ticks_msec() + 60000
		state_changed.emit()
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary or not _apply_snapshot(data):
		error_key = "SOCIAL_FAILURE"
		state_changed.emit()
		return
	if _pending_body.is_empty() and error_key == "SOCIAL_FAILURE":
		error_key = ""
	state_changed.emit()

func _apply_snapshot(data: Dictionary) -> bool:
	if str(data.get("player_id", "")) != ConnectionGate.player_id or not data.get("friends") is Array or not data.get("incoming") is Array or not data.get("outgoing") is Array:
		return false
	var next_friends := {}
	for row in data.friends.slice(0, 200):
		if row is Dictionary and _valid_id(row.get("player_id")):
			next_friends[str(row.player_id)] = str(row.get("display_name", "")).left(100)
	var next_incoming := _parse_requests(data.incoming, "requester", 100)
	var next_outgoing := _parse_requests(data.outgoing, "recipient", 20)
	friends = next_friends
	incoming = next_incoming
	outgoing = next_outgoing
	enabled = true
	return true

func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128

func _parse_requests(rows: Array, prefix: String, limit: int) -> Array:
	var parsed := []
	var seen := {}
	for row in rows.slice(0, limit):
		if not row is Dictionary or not _valid_id(row.get("request_id")) or not _valid_id(row.get(prefix + "_id")) or seen.has(row.request_id):
			continue
		seen[row.request_id] = true
		parsed.append({"request_id": row.request_id, prefix + "_id": row[prefix + "_id"], prefix + "_name": str(row.get(prefix + "_name", "")).left(100), "created_at": int(row.get("created_at", 0))})
	return parsed

func incoming_for(player_id: String) -> Dictionary:
	for row in incoming:
		if row.requester_id == player_id:
			return row
	return {}

func outgoing_for(player_id: String) -> Dictionary:
	for row in outgoing:
		if row.recipient_id == player_id:
			return row
	return {}

func request_friend(player_id: String) -> bool:
	return _start_mutation("/social/friends/request", {"target_player_id": player_id})

func respond(request_id: String, accept: bool) -> bool:
	return _start_mutation("/social/friends/respond", {"request_id": request_id, "accept": accept})

func cancel(request_id: String) -> bool:
	return _start_mutation("/social/friends/cancel", {"request_id": request_id})

func _start_mutation(path: String, body: Dictionary) -> bool:
	if not available() or not enabled or _mutation_busy or not _pending_body.is_empty():
		return false
	body["client_action_id"] = "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), Crypto.new().generate_random_bytes(16).hex_encode()]
	error_key = ""
	_pending_path = path
	_pending_body = JSON.stringify(body)
	return retry_mutation()

func retry_mutation() -> bool:
	if not available() or not enabled or _mutation_busy or _pending_body.is_empty():
		return false
	_mutation_busy = true
	if _mutation.request(ConnectionGate.base_url + _pending_path, _headers(), HTTPClient.METHOD_POST, _pending_body) != OK:
		_mutation_busy = false
		error_key = "SOCIAL_RETRY"
		state_changed.emit()
		return false
	state_changed.emit()
	return true

func _mutation_completed(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray, epoch: int) -> void:
	if epoch != _epoch or _identity != _identity_key():
		return
	_mutation_busy = false
	var data: Variant = _decode(body)
	if _auth_response(result, code, data):
		return
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code == 408:
		if code == 503 and data is Dictionary and data.get("error") == "SOCIAL_DISABLED":
			_epoch += 1
			_reset_requests()
			_clear_state()
			_pending_body = ""
			_pending_path = ""
			_next_poll = Time.get_ticks_msec() + 60000
		else:
			error_key = "SOCIAL_RETRY"
		mutation_finished.emit(false)
		state_changed.emit()
		return
	_pending_path = ""
	last_response_id = ""
	if code == 200:
		var previous: Variant = JSON.parse_string(_pending_body)
		if previous is Dictionary and previous.has("accept"):
			last_response_id = str(previous.get("request_id", ""))
	_pending_body = ""
	error_key = "" if code == 200 else ("SOCIAL_COOLDOWN" if code == 429 else ("SOCIAL_PENDING" if code == 409 else "SOCIAL_FAILURE"))
	mutation_finished.emit(code == 200)
	state_changed.emit()
	_next_poll = 0
	poll_now()
	var chat := get_node_or_null("/root/GlobalChatClient")
	if code == 200 and chat != null:
		chat.poll_now()

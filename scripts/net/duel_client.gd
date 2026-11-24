extends Node

signal state_changed
signal mutation_finished(success: bool, action: String)
signal accepted(invite: Dictionary)
signal match_started(invite_id: String, match_id: String)

var enabled := false
var incoming: Array = []
var outgoing: Array = []
var accepted_invites: Array = []
var started := {}
var cooldowns := {}
var error_key := ""
var _server_time := 0
var _server_ticks := 0
var _last_second := -1
var _epoch := 0
var _identity := ""
var _next_poll := 0
var _poll: HTTPRequest
var _mutation: HTTPRequest
var _poll_busy := false
var _mutation_busy := false
var _pending_path := ""
var _pending_body := ""
var _action_owner := ""
var _action_base := ""
var _next_retry := 0
var _tracked_invite := ""
var _verify_match := ""
var _verify_invite := ""
var _reported_match := ""
var _reported_invite := ""
const RECOVERY_FILE := "user://friendly_duel_recovery.cfg"

func _ready() -> void:
	_reset_requests()

func available() -> bool:
	return SocialClient.available()

func _identity_key() -> String:
	return JSON.stringify([ConnectionGate.player_id, ConnectionGate.token, ConnectionGate.base_url, ConnectionGate._generation])

func reset_for_logout() -> void:
	_epoch += 1
	_reset_requests()
	_identity = ""
	enabled = false
	incoming.clear()
	outgoing.clear()
	accepted_invites.clear()
	started.clear()
	cooldowns.clear()
	error_key = ""
	_server_time = 0
	_server_ticks = 0
	_last_second = -1
	_next_retry = 0
	_pending_path = ""
	_pending_body = ""
	_action_owner = ""
	_action_base = ""
	_tracked_invite = ""
	_verify_match = ""
	_verify_invite = ""
	_reported_match = ""
	_reported_invite = ""
	_next_poll = 0
	state_changed.emit()

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

func _process(_delta: float) -> void:
	var identity := _identity_key()
	if identity != _identity:
		_identity = identity
		_epoch += 1
		_reset_requests()
		enabled = false
		incoming.clear()
		outgoing.clear()
		accepted_invites.clear()
		started.clear()
		cooldowns.clear()
		if _action_owner != str(ConnectionGate.player_id) or _action_base != str(ConnectionGate.base_url):
			_pending_path = ""
			_pending_body = ""
			_action_owner = ""
			_action_base = ""
		_tracked_invite = ""
		if available():
			var config := ConfigFile.new()
			if config.load(RECOVERY_FILE) == OK:
				_tracked_invite = str(config.get_value("players", _recovery_key(), ""))
				if _pending_body.is_empty():
					var pending: Variant = config.get_value("pending", _recovery_key(), {})
					if pending is Dictionary and str(pending.get("path", "")) == "/forest/duels/ready" and not _tracked_invite.is_empty():
						var saved_body: String = str(pending.get("body", ""))
						var parsed: Variant = JSON.parse_string(saved_body)
						if parsed is Dictionary and str(parsed.get("invite_id", "")) == _tracked_invite and parsed.get("selection") is Dictionary and not str(parsed.get("client_action_id", "")).is_empty():
							_pending_path = "/forest/duels/ready"
							_pending_body = saved_body
							_action_owner = str(ConnectionGate.player_id)
							_action_base = str(ConnectionGate.base_url)
		_reported_invite = ""
		_reported_match = ""
		_verify_match = ""
		_next_poll = 0
		state_changed.emit()
	if enabled and _server_time > 0 and (not cooldowns.is_empty() or not incoming.is_empty() or not outgoing.is_empty() or not accepted_invites.is_empty()):
		var second := int(server_now() / 1000)
		if second != _last_second:
			_last_second = second
			state_changed.emit()
	var scene := get_tree().current_scene
	var forest_scene := is_instance_valid(scene) and scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD
	var friendly_loadout := is_instance_valid(scene) and scene.scene_file_path == SceneRouter.SCENE_LOADOUT and str(SceneRouter._friendly_context.get("player_id", "")) == str(ConnectionGate.player_id) and not SceneRouter._friendly_context.is_empty()
	var startup_recovery := is_instance_valid(scene) and scene.scene_file_path == SceneRouter.SCENE_MAIN_MENU and not _tracked_invite.is_empty() and SceneRouter._forest_modes_safe()
	var active_scene := forest_scene or friendly_loadout or startup_recovery
	if available() and active_scene and not _pending_body.is_empty() and not _mutation_busy and Time.get_ticks_msec() >= _next_retry:
		retry_mutation()
	if available() and active_scene and not _poll_busy and Time.get_ticks_msec() >= _next_poll:
		poll_now()

func _headers() -> PackedStringArray:
	return SocialClient._headers()

func server_now() -> int:
	return _server_time + Time.get_ticks_msec() - _server_ticks if _server_time > 0 else 0

func cooldown_seconds(id: String) -> int:
	return maxi(0, ceili(float(int(cooldowns.get(id, 0)) - server_now()) / 1000.0)) if _server_time > 0 else 0

func poll_now() -> void:
	if not available() or _poll_busy:
		return
	_next_poll = Time.get_ticks_msec() + (2000 if not incoming.is_empty() or not outgoing.is_empty() or not accepted_invites.is_empty() or not _tracked_invite.is_empty() else 7000)
	_poll_busy = true
	if _poll.request(ConnectionGate.base_url + "/forest/duels/state", _headers()) != OK:
		_poll_busy = false

func _poll_completed(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray, epoch: int) -> void:
	if epoch != _epoch or _identity != _identity_key():
		return
	_poll_busy = false
	var data: Variant = SocialClient._decode(body)
	if SocialClient._auth_response(result, code, data):
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary:
		_verify_match = ""
		_verify_invite = ""
		if code == 503:
			enabled = false
			error_key = str(data.get("error", "FOREST_DUELS_UNAVAILABLE")) if data is Dictionary else "FOREST_DUELS_UNAVAILABLE"
			_next_poll = Time.get_ticks_msec() + 30000
		state_changed.emit()
		return
	if not _verify_match.is_empty():
		var match_id := _verify_match
		var invite_id := _verify_invite
		_verify_match = ""
		_verify_invite = ""
		if str(data.get("match_id", "")) == match_id and str(data.get("kind", "")) == "friendly" and _tracked_invite == invite_id:
			if str(data.get("status", "")) == "FINISHED":
				clear_recovery()
			elif str(data.get("status", "")) == "ACTIVE" and _reported_match != match_id:
				var scene := get_tree().current_scene
				if is_instance_valid(scene) and scene.scene_file_path == SceneRouter.SCENE_MAIN_MENU:
					if SceneRouter.recover_friendly_after_startup({"invite_id":invite_id}, match_id): _reported_match = match_id
				elif not match_started.get_connections().is_empty():
					_reported_match = match_id
					match_started.emit(invite_id, match_id)
		return
	if str(data.get("player_id", "")) != ConnectionGate.player_id or not data.get("incoming") is Array or not data.get("outgoing") is Array or not data.get("accepted") is Array:
		return
	incoming = data.incoming.slice(0, 1)
	outgoing = data.outgoing.slice(0, 1)
	accepted_invites = data.accepted.slice(0, 1)
	started = data.get("started", {}) if data.get("started") is Dictionary else {}
	_server_time = int(data.get("server_time", 0))
	_server_ticks = Time.get_ticks_msec()
	cooldowns.clear()
	for row in data.get("cooldowns", []):
		if row is Dictionary and row.get("player_id") is String:
			cooldowns[row.player_id] = int(row.get("cooldown_until", 0))
	enabled = true
	error_key = ""
	state_changed.emit()
	if not accepted_invites.is_empty():
		var invite: Dictionary = accepted_invites[0]
		var invite_id := str(invite.get("invite_id", ""))
		if not invite_id.is_empty() and int(invite.get("expires_at", 0)) > server_now() :
			var scene := get_tree().current_scene
			if is_instance_valid(scene) and scene.scene_file_path == SceneRouter.SCENE_MAIN_MENU:
				if _tracked_invite == invite_id: SceneRouter.recover_friendly_after_startup(invite)
			else:
				_reported_invite = invite_id
				_tracked_invite = invite_id
				_save_recovery(invite_id)
				accepted.emit(invite)
	if not _tracked_invite.is_empty() and accepted_invites.is_empty() and str(started.get("invite_id", "")) != _tracked_invite:
		clear_recovery()
	if not _tracked_invite.is_empty() and str(started.get("invite_id", "")) == _tracked_invite:
		_verify_match = str(started.get("match_id", ""))
		_verify_invite = _tracked_invite
		if not _verify_match.is_empty():
			_poll_busy = true
			if _poll.request(ConnectionGate.base_url + "/forest/duels/match/state?match_id=" + _verify_match.uri_encode(), _headers()) != OK:
				_poll_busy = false
				_verify_match = ""

func _recovery_key() -> String:
	return JSON.stringify([str(ConnectionGate.base_url).strip_edges().trim_suffix("/"), str(ConnectionGate.player_id)]).sha256_text()

func _save_pending() -> void:
	if str(ConnectionGate.player_id).is_empty() or str(ConnectionGate.base_url).strip_edges().is_empty(): return
	var config := ConfigFile.new()
	config.load(RECOVERY_FILE)
	if _pending_path == "/forest/duels/ready" and not _pending_body.is_empty():
		config.set_value("pending", _recovery_key(), {"path":_pending_path,"body":_pending_body})
	else:
		config.erase_section_key("pending", _recovery_key())
	if config.save(RECOVERY_FILE) != OK: push_warning("Unable to save duel action recovery")

func _save_recovery(invite_id: String) -> void:
	if str(ConnectionGate.player_id).is_empty() or str(ConnectionGate.base_url).strip_edges().is_empty(): return
	var config := ConfigFile.new()
	config.load(RECOVERY_FILE)
	config.set_value("players", _recovery_key(), invite_id)
	if config.save(RECOVERY_FILE) != OK: push_warning("Unable to save duel recovery identifier")

func clear_recovery() -> void:
	_tracked_invite = ""
	_reported_match = ""
	if _pending_path == "/forest/duels/ready" and not _mutation_busy:
		_pending_path = ""
		_pending_body = ""
		_save_pending()
	_save_recovery("")

func request_duel(player_id: String) -> bool:
	return _start_mutation("/forest/duels/request", {"target_player_id":player_id})

func respond(invite_id: String, accept: bool) -> bool:
	return _start_mutation("/forest/duels/respond", {"invite_id":invite_id,"accept":accept})

func cancel(invite_id: String) -> bool:
	return _start_mutation("/forest/duels/cancel", {"invite_id":invite_id})

func submit_ready(invite_id: String, selection: Dictionary) -> bool:
	return _start_mutation("/forest/duels/ready", {"invite_id":invite_id,"selection":selection,"playback_protocol":1})

func _start_mutation(path: String, body: Dictionary) -> bool:
	if not available() or not enabled or _mutation_busy or not _pending_body.is_empty():
		return false
	body["client_action_id"] = "%s-%s" % [Time.get_ticks_usec(), Crypto.new().generate_random_bytes(16).hex_encode()]
	_pending_path = path
	_pending_body = JSON.stringify(body)
	_action_owner = str(ConnectionGate.player_id)
	_action_base = str(ConnectionGate.base_url)
	_save_pending()
	return retry_mutation()

func retry_mutation() -> bool:
	if not available() or _mutation_busy or _pending_body.is_empty():
		return false
	_mutation_busy = true
	_next_retry = Time.get_ticks_msec() + 4000
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
	var data: Variant = SocialClient._decode(body)
	if SocialClient._auth_response(result, code, data):
		return
	var action := _pending_path.get_file()
	if code == 503 and data is Dictionary and data.get("error") == "PVP_SECRET_REQUIRED":
		_pending_body = ""
		_pending_path = ""
		_save_pending()
		error_key = "PVP_SECRET_REQUIRED"
		mutation_finished.emit(false, action)
		state_changed.emit()
		return
	if result != HTTPRequest.RESULT_SUCCESS or code == 408 or code >= 500:
		error_key = str(data.get("error", "SOCIAL_RETRY")) if data is Dictionary else "SOCIAL_RETRY"
		if error_key == "FOREST_DUELS_UNAVAILABLE": _next_retry = Time.get_ticks_msec() + 30000
		mutation_finished.emit(false, action)
		state_changed.emit()
		return
	_pending_body = ""
	_pending_path = ""
	_save_pending()
	_action_owner = ""
	_action_base = ""
	if code == 200 and action == "cancel": clear_recovery()
	error_key = "" if code == 200 else ("SOCIAL_COOLDOWN" if code == 429 else "SOCIAL_FAILURE")
	mutation_finished.emit(code == 200, action)
	_next_poll = 0
	poll_now()
	state_changed.emit()

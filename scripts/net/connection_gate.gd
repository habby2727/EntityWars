extends Node

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const RecoveryJournal := preload("res://scripts/net/session_recovery_journal.gd")
enum State { CONNECTED, RECONNECTING, ERROR, AUTH_REQUIRED, UPDATE_REQUIRED, IDLE }
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
var _journal_checked := false
var _layer: CanvasLayer
var _title: Label
var _detail: Label
var _retry: Button
var _sign_in: Button
var _suspended_scene: Node
var _suspended_process_mode: int
var _suspended_visible := true
var _debug_lab_button: Button
var debug_offline_enabled := false
var _dungeon_http: HTTPRequest
var _dungeon_timer: Timer
var _dungeon_return_after_disconnect := false
var _explicit_login_pending := false
var _announcement_http: HTTPRequest
var _announcement_timer: Timer
var _announcement_events: Array[Dictionary] = []

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.max_redirects = 0
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_check_completed)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_check)
	add_child(_timer)
	_announcement_http = HTTPRequest.new()
	_announcement_http.timeout = 8.0
	add_child(_announcement_http)
	_announcement_http.request_completed.connect(_announcement_completed)
	_announcement_timer = Timer.new()
	_announcement_timer.one_shot = true
	_announcement_timer.timeout.connect(_send_announcement)
	add_child(_announcement_timer)
	_create_overlay()
	_dungeon_http = HTTPRequest.new()
	_dungeon_http.timeout = 8.0
	add_child(_dungeon_http)
	_dungeon_http.request_completed.connect(_dungeon_heartbeat_completed)
	_dungeon_timer = Timer.new()
	_dungeon_timer.wait_time = 5.0
	_dungeon_timer.timeout.connect(_dungeon_heartbeat)
	add_child(_dungeon_timer)

func register_identity(client: Node, identity: String) -> void:
	if debug_offline_enabled:
		return
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

func require_update() -> void:
	_timer.stop()
	_generation += 1
	_fail(State.UPDATE_REQUIRED, "Update required. Please update Entity Wars to continue.")

func require_authentication() -> void:
	_fail(State.AUTH_REQUIRED, "Authentication required")

func require_idle() -> void:
	if state in [State.UPDATE_REQUIRED, State.AUTH_REQUIRED]:
		return
	_generation += 1
	_http.cancel_request()
	_checking = false
	_fail(State.IDLE, "Are you still playing? Please Reconnect")

func reconnect_idle() -> void:
	if state != State.IDLE or _checking or token.is_empty():
		return
	_checking = true
	_retry.disabled = true
	_http.set_meta("generation", _generation)
	_http.set_meta("idle_reconnect", true)
	var err := _http.request(base_url + "/auth/reconnect", PackedStringArray(["Authorization: Bearer " + token, preload("res://scripts/net/client_build.gd").header()]), HTTPClient.METHOD_POST)
	if err != OK:
		_checking = false
		_retry.disabled = false
		_detail.text = "Connection unavailable. Please try again."

func sign_in_again() -> void:
	if state != State.AUTH_REQUIRED or is_instance_valid(_suspended_scene):
		return
	var scene := get_tree().current_scene
	var auth: Node = preload("res://scenes/ui/Auth.tscn").instantiate()
	if not is_instance_valid(scene) or auth == null:
		return
	_suspended_scene = scene
	_suspended_process_mode = scene.process_mode
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	if scene is CanvasItem:
		_suspended_visible = scene.visible
		scene.hide()
	get_tree().root.add_child(auth)
	get_tree().current_scene = auth
	_layer.hide()

# Explicit sign-out must not abandon a server action that needs reconciliation.
func explicit_logout_safe() -> bool:
	if is_instance_valid(_suspended_scene) or _recovery_owner_id != 0:
		return false
	if not SceneRouter._forest_modes_safe() or not SceneRouter._friendly_context.is_empty():
		return false
	if not DuelClient._tracked_invite.is_empty() or not DuelClient._pending_body.is_empty() or DuelClient._mutation_busy:
		return false
	if not SocialClient._pending_body.is_empty() or SocialClient._mutation_busy:
		return false
	var directory := DirAccess.open("user://")
	if directory == null:
		return false
	for filename in directory.get_files():
		if filename.begins_with("session_recovery_") and filename.ends_with(".json"):
			return false
		if player_id.is_empty() and filename.begins_with("pending_actions_") and filename.ends_with(".json"):
			if not _logout_queue_empty("user://" + filename):
				return false
	if not player_id.is_empty():
		var queue_path := "user://pending_actions_%s.json" % player_id.sha256_text()
		if not _logout_queue_empty(queue_path):
			return false
	var duel_config := ConfigFile.new()
	if FileAccess.file_exists(DuelClient.RECOVERY_FILE):
		if duel_config.load(DuelClient.RECOVERY_FILE) != OK:
			return false
		if player_id.is_empty():
			if duel_config.has_section("players"):
				for key in duel_config.get_section_keys("players"):
					if not str(duel_config.get_value("players", key, "")).is_empty():
						return false
			if duel_config.has_section("pending") and not duel_config.get_section_keys("pending").is_empty():
				return false
		else:
			var key: String = DuelClient._recovery_key()
			if not str(duel_config.get_value("players", key, "")).is_empty() or duel_config.has_section_key("pending", key):
				return false
	for client in get_tree().get_nodes_in_group("backend_session_clients"):
		if not client._in_flight.is_empty() or not client._api_in_flight.is_empty() or client._pending.size() > 0:
			return false
	return true

func _logout_queue_empty(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return data is Dictionary and data.get("actions") is Array and data.actions.is_empty()

func explicit_logout_reset() -> void:
	var update_required := state == State.UPDATE_REQUIRED
	_generation += 1
	_timer.stop()
	_dungeon_timer.stop()
	_announcement_timer.stop()
	_http.cancel_request()
	_dungeon_http.cancel_request()
	_announcement_http.cancel_request()
	_http.request_completed.disconnect(_on_check_completed)
	_dungeon_http.request_completed.disconnect(_dungeon_heartbeat_completed)
	_announcement_http.request_completed.disconnect(_announcement_completed)
	_http.queue_free()
	_dungeon_http.queue_free()
	_announcement_http.queue_free()
	_http = HTTPRequest.new()
	_http.max_redirects = 0
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_check_completed)
	_dungeon_http = HTTPRequest.new()
	_dungeon_http.timeout = 8.0
	add_child(_dungeon_http)
	_dungeon_http.request_completed.connect(_dungeon_heartbeat_completed)
	_announcement_http = HTTPRequest.new()
	_announcement_http.timeout = 8.0
	add_child(_announcement_http)
	_announcement_http.request_completed.connect(_announcement_completed)
	_announcement_events.clear()
	_checking = false
	_player_verified = false
	_identity_mismatch = false
	_recovery_owner_id = 0
	_loadout_session_requested = false
	_loadout_session_verified = false
	_journal_checked = false
	_explicit_login_pending = false
	_dungeon_return_after_disconnect = false
	debug_offline_enabled = false
	player_id = ""
	token = ""
	base_url = ""
	state = State.UPDATE_REQUIRED if update_required else State.CONNECTED
	if not update_required:
		_layer.hide()
	for client in get_tree().get_nodes_in_group("backend_session_clients"):
		client._invalidate_external_session()
	GlobalChatClient.reset_for_logout()
	SocialClient.reset_for_logout()
	DuelClient.reset_for_logout()
	SceneRouter.clear_account_context()

func resume_after_sign_in(identity: String, new_token: String) -> bool:
	if not is_instance_valid(_suspended_scene):
		return true
	if identity != player_id:
		return false
	var auth_scene := get_tree().current_scene
	get_tree().current_scene = _suspended_scene
	_suspended_scene.process_mode = _suspended_process_mode
	if _suspended_scene is CanvasItem and _suspended_visible:
		_suspended_scene.show()
	_suspended_scene = null
	for client in get_tree().get_nodes_in_group("backend_session_clients"):
		if not auth_scene.is_ancestor_of(client):
			client.token = new_token
			client.call_deferred("refresh_state")
	auth_scene.queue_free()
	_layer.show()
	return true

func begin_explicit_login() -> bool:
	if _identity_mismatch:
		return false
	var directory := DirAccess.open("user://")
	if directory == null:
		return false
	debug_offline_enabled = false
	_explicit_login_pending = true
	var session_active := not SceneRouter._solo_hunt_context.is_empty() or not SceneRouter._dungeon_context.is_empty() or _recovery_owner_id != 0
	for filename in directory.get_files():
		if filename.begins_with("session_recovery_") and filename.ends_with(".json"):
			session_active = true
	if not session_active and not is_instance_valid(_suspended_scene):
		player_id = ""
	token = ""
	_generation += 1
	_journal_checked = false
	if state == State.AUTH_REQUIRED:
		state = State.CONNECTED
	_fail(State.RECONNECTING, "Recovering connection and verifying your session...")
	return true

func observe_credentials(client: Node) -> void:
	if player_id.is_empty() and token.is_empty() and not str(client.token).is_empty():
		token = str(client.token)
		base_url = str(client.base_url)
		_fail(State.RECONNECTING, "Recovering connection and verifying your session...")
		call_deferred("_check")

func authentication_changed(new_token: String, url: String) -> void:
	if player_id.is_empty() and token.is_empty() and state == State.CONNECTED:
		token = new_token
		base_url = url
		if not new_token.is_empty():
			_fail(State.RECONNECTING, "Recovering connection and verifying your session...")
			call_deferred("_check")
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

func enable_debug_lab() -> bool:
	if not OS.has_feature("editor") or state == State.UPDATE_REQUIRED:
		return false
	debug_offline_enabled = true
	_timer.stop()
	_generation += 1
	_http.cancel_request()
	_checking = false
	state = State.AUTH_REQUIRED
	_layer.hide()
	return true

func debug_lab_navigation_allowed() -> bool:
	return OS.has_feature("editor") and debug_offline_enabled and state != State.UPDATE_REQUIRED

func report_failure(client: Node, reason: String, status: int = 0) -> void:
	if status == 426:
		require_update()
		return
	if str(client.token).is_empty():
		return
	observe_credentials(client)
	if status == 401 or reason == "identity_mismatch":
		if reason == "identity_mismatch":
			_identity_mismatch = true
		_fail(State.AUTH_REQUIRED if status == 401 else State.ERROR, "Authentication required" if status == 401 else "Account changed. Sign in with the original account.")
	elif status == 403:
		_fail(State.ERROR, "Access forbidden. Your account or this action is not permitted.")
	elif reason in ["network_error", "bad_json", "bad_state"] or status >= 500 or status == 408:
		_fail(State.RECONNECTING, "Recovering connection and verifying your session...")

func _fail(next: State, message: String) -> void:
	if state == State.UPDATE_REQUIRED and next != State.UPDATE_REQUIRED:
		return
	if state == State.IDLE and next not in [State.IDLE, State.AUTH_REQUIRED, State.UPDATE_REQUIRED]:
		return
	if (state == State.AUTH_REQUIRED or _identity_mismatch) and next == State.RECONNECTING:
		return
	var was_connected := state == State.CONNECTED
	var lost_dungeon := was_connected and not str(SceneRouter._dungeon_context.get("run_id", "")).is_empty()
	if lost_dungeon:
		_dungeon_end(false)
		_dungeon_return_after_disconnect = true
	state = next
	_player_verified = false
	_loadout_session_requested = false
	_loadout_session_verified = false
	_title.text = "" if next == State.IDLE else ("Update required" if next == State.UPDATE_REQUIRED else ("Disconnected (Reconnecting...)" if next == State.RECONNECTING else "Error"))
	_retry.visible = next in [State.RECONNECTING, State.ERROR, State.IDLE]
	_retry.text = "Reconnect" if next == State.IDLE else "Retry Connection"
	_retry.disabled = false
	_sign_in.visible = next == State.AUTH_REQUIRED
	if next != State.RECONNECTING:
		_timer.stop()
	if is_instance_valid(_debug_lab_button):
		_debug_lab_button.visible = next not in [State.UPDATE_REQUIRED, State.IDLE]
	_detail.text = message
	var auth_scene := get_tree().current_scene
	if not debug_lab_navigation_allowed() and (next == State.IDLE or not (is_instance_valid(auth_scene) and auth_scene.has_method("auth_gate_screen"))):
		_layer.show()
	if was_connected and not lost_dungeon:
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.has_method("connection_gate_lost"):
			_recovery_owner_id = scene.get_instance_id()
			scene.connection_gate_lost()
		elif is_instance_valid(scene) and scene.has_method("_recover_hunt_session") and (not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty()):
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
	if debug_offline_enabled or state in [State.UPDATE_REQUIRED, State.AUTH_REQUIRED, State.IDLE] or _checking or _identity_mismatch or token.is_empty():
		return
	_timer.stop()
	_checking = true
	_http.set_meta("generation", _generation)
	var err := _http.request(base_url + "/player/state", PackedStringArray(["Authorization: Bearer " + token, preload("res://scripts/net/client_build.gd").header()]), HTTPClient.METHOD_GET)
	if err != OK:
		_checking = false
		_fail(State.RECONNECTING, "Recovering connection and verifying your session...")

func _on_check_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_checking = false
	var idle_reconnect := bool(_http.get_meta("idle_reconnect", false))
	_http.remove_meta("idle_reconnect")
	_retry.disabled = false
	if int(_http.get_meta("generation", -1)) != _generation:
		_check()
		return
	if code == 426:
		require_update()
		return
	if state == State.UPDATE_REQUIRED:
		return
	if code == 401:
		_fail(State.AUTH_REQUIRED, "Authentication required")
		if idle_reconnect:
			if is_instance_valid(get_tree().current_scene) and get_tree().current_scene.has_method("auth_gate_screen"):
				_layer.hide()
			else:
				sign_in_again()
		return
	if idle_reconnect:
		if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
			state = State.RECONNECTING
			_fail(State.RECONNECTING, "Recovering connection and verifying your session...")
			_check()
		else:
			_detail.text = "Access forbidden. Please try again." if code == 403 else "Connection unavailable. Please try again."
		return
	if code == 403:
		_fail(State.ERROR, "Access forbidden. Your account is not permitted.")
		return
	if result == HTTPRequest.RESULT_SUCCESS and code == 409:
		var error_data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if error_data is Dictionary and str(error_data.get("error", "")) == "SESSION_IDLE":
			require_idle()
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
	if not _journal_checked:
		if not _restore_journal():
			return
	if _dungeon_return_after_disconnect:
		_unlock()
		return
	var scene := get_tree().current_scene
	if _recovery_owner_id != 0 and (not is_instance_valid(scene) or scene.get_instance_id() != _recovery_owner_id):
		_detail.text = "The original session must be recovered before continuing."
		_timer.start(2.0)
	elif is_instance_valid(scene) and scene.has_method("connection_gate_recover"):
		scene.connection_gate_recover()
		_timer.start(2.0)
	elif is_instance_valid(scene) and scene.has_method("_recover_hunt_session") and (not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty()):
		_recover_loadout(scene)
		if blocked():
			_timer.start(2.0)
	elif not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty():
		_detail.text = "Session recovery is required before continuing."
		_timer.start(2.0)
	else:
		_unlock()

func _restore_journal() -> bool:
	_discard_legacy_dungeon_journals()
	var journal := RecoveryJournal.new()
	if not journal.set_identity(player_id):
		_fail(State.ERROR, "Invalid recovery identity.")
		return false
	var entry := journal.load_entry()
	if entry.has("error"):
		_fail(State.ERROR, "Recovery journal is invalid. Session remains locked.")
		return false
	_journal_checked = true
	if entry.is_empty():
		return true
	var kind := str(entry.pending_kind)
	if entry.mode != "hunt":
		return journal.remove()
	SceneRouter._dungeon_context.clear()
	SceneRouter._solo_hunt_context = entry.context.duplicate(true)
	SceneRouter._solo_hunt_context["session_id"] = entry.session_id
	SceneRouter._solo_hunt_context["loadout_identity"] = player_id
	if kind == "loadout":
		SceneRouter._hunt_loadout_active = true
		SceneRouter._solo_hunt_context["pending_loadout"] = entry.payload.duplicate(true)
	elif not kind.is_empty():
		SceneRouter._solo_hunt_context["pending_action"] = {"kind": kind, "payload": entry.payload.duplicate(true)}
	var scene_path: String = SceneRouter.SCENE_LOADOUT if kind == "loadout" else SceneRouter.SCENE_COMBAT
	_navigate_recovery(scene_path)
	return false

func journal_pending(client: Node, mode: String, kind: String, payload: Dictionary) -> bool:
	if mode != "hunt": return false
	if client._verified_player_id.is_empty() or client._verified_player_id != player_id:
		return false
	var journal := RecoveryJournal.new()
	journal.set_identity(player_id)
	var previous := journal.load_entry()
	if previous.has("error"):
		_fail(State.ERROR, "Recovery journal is invalid. Session remains locked.")
		return false
	var session_id := str(payload.get("session_id" if mode == "hunt" else "run_id", ""))
	if not previous.is_empty() and (previous.mode != mode or previous.session_id != session_id):
		_journal_checked = false
		_fail(State.RECONNECTING, "Recovering the previous session before continuing...")
		call_deferred("_check")
		return false
	if not previous.is_empty() and not str(previous.pending_kind).is_empty() and JSON.stringify(previous.payload) != JSON.stringify(JSON.parse_string(JSON.stringify(payload))):
		_fail(State.ERROR, "Another session action requires recovery.")
		return false
	var context := {}
	if mode == "hunt":
		var source := SceneRouter._solo_hunt_context
		var scene := get_tree().current_scene
		if source.is_empty() and is_instance_valid(scene):
			source = scene.get("_solo_context")
		if source is Dictionary:
			for key in RecoveryJournal.CONTEXT_KEYS:
				if source.has(key): context[key] = source[key]
	var entry := {"version": RecoveryJournal.VERSION, "mode": mode, "player_id": player_id, "session_id": session_id, "context": context, "pending_kind": kind, "payload": payload.duplicate(true)}
	if not journal.save_entry(entry):
		_fail(State.ERROR, "Cannot save session recovery. Action was not sent.")
		return false
	return true

func journal_confirm(action_id: String) -> bool:
	var journal := RecoveryJournal.new()
	if not journal.set_identity(player_id): return false
	var entry := journal.load_entry()
	if entry.is_empty() or entry.has("error") or str(entry.payload.get("client_action_id", "")) != action_id:
		_fail(State.ERROR, "Recovery journal confirmation failed.")
		return false
	entry.pending_kind = ""
	entry.payload = {}
	if not journal.save_entry(entry):
		_fail(State.ERROR, "Cannot save session confirmation.")
		return false
	return true

func journal_close(mode: String, session_id: String) -> bool:
	if mode == "dungeon": return true
	var journal := RecoveryJournal.new()
	if not journal.set_identity(player_id): return false
	var entry := journal.load_entry()
	if entry.has("error") or (not entry.is_empty() and (entry.mode != mode or entry.session_id != session_id or (mode == "hunt" and not str(entry.pending_kind).is_empty()) or not journal.remove())):
		_fail(State.ERROR, "Cannot close session recovery.")
		return false
	return true

func recovery_completed() -> void:
	if blocked() and _player_verified:
		_unlock()

func recovery_to_combat() -> void:
	if not blocked() or not _player_verified:
		return
	SceneRouter._hunt_loadout_active = false
	_navigate_recovery(SceneRouter.SCENE_COMBAT)

func _navigate_recovery(scene_path: String) -> void:
	if not blocked() or not _player_verified or scene_path not in [SceneRouter.SCENE_LOADOUT, SceneRouter.SCENE_COMBAT]:
		return
	_recovery_owner_id = 0
	_loadout_session_requested = false
	_loadout_session_verified = false
	call_deferred("_perform_recovery_navigation", scene_path)
	_timer.start(2.0)

func _perform_recovery_navigation(scene_path: String) -> void:
	if not blocked() or not _player_verified:
		return
	if get_tree().change_scene_to_file(scene_path) != OK:
		_fail(State.ERROR, "Cannot open the recovery session.")

func _recover_loadout(scene: Node) -> void:
	var client: BackendClient = scene._hunt_backend
	if client == null or client.token != token:
		return
	if client._verified_player_id.is_empty():
		client.refresh_state()
		return
	if client._verified_player_id != player_id or not client._api_in_flight.is_empty():
		return
	if not _loadout_session_verified:
		if _loadout_session_requested:
			if scene._hunt_recovered:
				_loadout_session_verified = true
			else:
				_loadout_session_requested = false
				return
		else:
			scene._hunt_recovered = false
			var path := "/world/boss-hunts/session?session_id=" + str(SceneRouter._solo_hunt_context.get("session_id", "")).uri_encode()
			scene._hunt_recovery_request = client.request_api("GET", path, null, false, true)
			_loadout_session_requested = not scene._hunt_recovery_request.is_empty()
			return
	if not scene._hunt_payload.is_empty():
		scene._hunt_submit_request = client.request_api("POST", "/world/boss-hunts/loadout", scene._hunt_payload.duplicate(true), false, true)
		return
	if int(SceneRouter._solo_hunt_context.get("recovered_session", {}).get("combat_revision", 0)) >= 1:
		SceneRouter._hunt_loadout_active = false
		_navigate_recovery(SceneRouter.SCENE_COMBAT)
	else:
		_unlock()

func _unlock() -> void:
	if debug_offline_enabled or state in [State.UPDATE_REQUIRED, State.AUTH_REQUIRED, State.IDLE]:
		return
	if state != State.CONNECTED and not _explicit_login_pending:
		_announcement_events.append({"id": Crypto.new().generate_random_bytes(16).hex_encode(), "token": token, "url": base_url})
		_send_announcement()
	_explicit_login_pending = false
	state = State.CONNECTED
	_attempt = 0
	_player_verified = false
	_recovery_owner_id = 0
	_loadout_session_requested = false
	_loadout_session_verified = false
	_layer.hide()
	if _dungeon_return_after_disconnect:
		_dungeon_return_after_disconnect = false
		SceneRouter.return_from_dungeon()
	_timer.start(15.0)
	for client in get_tree().get_nodes_in_group("backend_session_clients"):
		if client.auto_flush and client._verified_player_id == player_id:
			client.call_deferred("flush_queue")

func _send_announcement() -> void:
	if _announcement_events.is_empty() or _announcement_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var event: Dictionary = _announcement_events[0]
	var headers := PackedStringArray(["Authorization: Bearer " + str(event.token), "Content-Type: application/json", preload("res://scripts/net/client_build.gd").header()])
	var error := _announcement_http.request(str(event.url) + "/chat/announce-reconnect", headers, HTTPClient.METHOD_POST, JSON.stringify({"event_id": event.id}))
	if error != OK:
		_announcement_timer.start(5.0)

func _announcement_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if _announcement_events.is_empty():
		return
	if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code in [400, 401, 403, 426]):
		_announcement_events.pop_front()
		if not _announcement_events.is_empty():
			_announcement_timer.start(0.1)
	else:
		_announcement_timer.start(31.0 if code == 429 else 5.0)

func _input(event: InputEvent) -> void:
	var scene := get_tree().current_scene
	if state != State.IDLE and is_instance_valid(scene) and scene.has_method("auth_gate_screen"):
		return
	if blocked() and not debug_lab_navigation_allowed() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
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
	_retry.pressed.connect(func():
		if state == State.IDLE: reconnect_idle()
		else: _check())
	box.add_child(_retry)
	_sign_in = Button.new()
	_sign_in.text = "Sign in again"
	_sign_in.custom_minimum_size = Vector2(220, 48)
	_sign_in.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	MenuArt.button(_sign_in)
	_sign_in.pressed.connect(sign_in_again)
	box.add_child(_sign_in)
	if OS.has_feature("editor"):
		_debug_lab_button = Button.new()
		_debug_lab_button.text = tr("AUTH_DEBUG_LAB")
		_debug_lab_button.custom_minimum_size = Vector2(220, 48)
		_debug_lab_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		MenuArt.button(_debug_lab_button)
		_debug_lab_button.pressed.connect(func():
			if enable_debug_lab():
				SceneRouter.go_to_lab_hub())
		box.add_child(_debug_lab_button)
	_layer.hide()

func _discard_legacy_dungeon_journals() -> void:
	var directory := DirAccess.open("user://")
	if directory == null: return
	for filename in directory.get_files():
		if not filename.begins_with("session_recovery_") or not filename.ends_with(".json"): continue
		var path := "user://" + filename
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 65536: continue
		var entry: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if entry is Dictionary and entry.get("mode") == "dungeon": DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func dungeon_started() -> void:
	_dungeon_timer.start()
	_dungeon_heartbeat()

func dungeon_finished() -> void:
	_dungeon_timer.stop()
	_dungeon_http.cancel_request()

func _dungeon_heartbeat() -> void:
	var run_id := str(SceneRouter._dungeon_context.get("run_id", ""))
	if run_id.is_empty() or blocked() or token.is_empty(): return
	if _dungeon_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	var headers := PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json", preload("res://scripts/net/client_build.gd").header()])
	if _dungeon_http.request(base_url + "/dungeon/heartbeat", headers, HTTPClient.METHOD_POST, JSON.stringify({"run_id": run_id})) != OK:
		_fail(State.RECONNECTING, "Dungeon ended after connection loss.")

func _dungeon_heartbeat_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if SceneRouter._dungeon_context.is_empty(): return
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_fail(State.RECONNECTING, "Dungeon ended after connection loss.")

func _dungeon_end(navigate: bool) -> void:
	_dungeon_timer.stop()
	_dungeon_http.cancel_request()
	var run_id := str(SceneRouter._dungeon_context.get("run_id", ""))
	if not run_id.is_empty() and not token.is_empty():
		var request := HTTPRequest.new()
		request.timeout = 8.0
		add_child(request)
		request.request_completed.connect(func(_r, _c, _h, _b): request.queue_free())
		var headers := PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json", preload("res://scripts/net/client_build.gd").header()])
		var action_id := "%s-%s" % [str(Time.get_ticks_usec()), run_id]
		if request.request(base_url + "/dungeon/abandon", headers, HTTPClient.METHOD_POST, JSON.stringify({"run_id": run_id, "client_action_id": action_id})) != OK: request.queue_free()
	SceneRouter._dungeon_context.clear()
	if navigate: SceneRouter.return_from_dungeon()

func dungeon_exit_warning() -> void:
	dungeon_warning("DUNGEON_EXIT_WARNING", "DUNGEON_EXIT_CONFIRM", "DUNGEON_STAY", func(): _dungeon_end(true))

func dungeon_warning(message_key: String, confirm_key: String, cancel_key: String, confirmed: Callable) -> void:
	var existing := get_node_or_null("DungeonWarning")
	if existing != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "DungeonWarning"
	layer.layer = 900
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 300)
	panel.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup.png", Vector4(55, 50, 55, 40)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	var label := Label.new()
	label.name = "WarningText"
	label.text = tr(message_key)
	label.custom_minimum_size = Vector2(500, 110)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)
	for spec in [[confirm_key, true], [cancel_key, false]]:
		var button := Button.new()
		button.text = tr(spec[0])
		button.custom_minimum_size = Vector2(180, 52)
		MenuArt.button(button)
		buttons.add_child(button)
		if spec[1]:
			button.pressed.connect(func(): layer.queue_free(); confirmed.call())
		else:
			button.pressed.connect(layer.queue_free)

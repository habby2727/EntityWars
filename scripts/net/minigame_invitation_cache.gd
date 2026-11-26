extends Node

signal changed
signal operation_changed(kind: String)

var data := {}
var received_tick := 0
var _identity := ""
var _busy := false
var _next_poll := 0
var _backoff := 8000
var stale := true
var _locks := {}
var _overlay: CanvasLayer
var _operations := {}
var _resumed_identity := ""
const FILE := "user://minigame_invite_recovery.cfg"
const SAFE_SCENES := [SceneRouter.SCENE_MAIN_MENU, SceneRouter.SCENE_LAB_HUB, SceneRouter.SCENE_LAB_STRUCTURES, "res://scenes/ui/Lab.tscn", SceneRouter.SCENE_INVENTORY, SceneRouter.SCENE_TRADE_HALL, SceneRouter.SCENE_EXPEDITIONS, SceneRouter.SCENE_WORLD_GATE, SceneRouter.SCENE_SETTINGS, SceneRouter.SCENE_TOP_PLAYERS, SceneRouter.SCENE_FOREST_WORLD, SceneRouter.SCENE_WOE_PREGAME, SceneRouter.SCENE_CD_PREGAME]

func _ready() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)
	var notices = preload("res://scripts/ui/minigame_invitation_notices.gd").new()
	notices.name = "MinigameInvitationNotices"
	notices.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notices.offset_left = -400
	notices.offset_right = -20
	notices.offset_top = 100
	_overlay.add_child(notices)
	_overlay.hide()

func eligible() -> bool:
	var scene := get_tree().current_scene
	return WoeClient.available() and not ConnectionGate.debug_offline_enabled and is_instance_valid(scene) and scene.scene_file_path in SAFE_SCENES and not scene.has_method("auth_gate_screen") and SceneRouter._spectator_context.is_empty() and SceneRouter._ranked_context.is_empty() and SceneRouter._friendly_context.is_empty() and SceneRouter._solo_hunt_context.is_empty() and SceneRouter._dungeon_context.is_empty() and not SceneRouter._hunt_loadout_active

func _journal_key(kind: String) -> String:
	return WoeClient.account_key() + "|" + kind

func saved(kind: String) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	var value: Variant = cfg.get_value("pending", _journal_key(kind), {})
	return value if value is Dictionary else {}

func save(kind: String, value: Dictionary) -> bool:
	if not WoeClient.available() or kind not in ["woe", "core_defense"]: return false
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("pending", _journal_key(kind), value)
	return cfg.save(FILE) == OK

func clear_exact(kind: String, pending: Dictionary) -> bool:
	if saved(kind) != pending: return false
	return save(kind, {})

func lock(kind: String, owner: Node) -> bool:
	var key := _journal_key(kind)
	if _locks.has(key) and is_instance_valid(_locks[key].get_ref()): return false
	_locks[key] = weakref(owner)
	return true

func unlock(kind: String, owner: Node, account: String) -> void:
	var key := account + "|" + kind
	if _locks.has(key) and _locks[key].get_ref() == owner: _locks.erase(key)

func _process(_delta: float) -> void:
	var identity: String = WoeClient.identity()
	if identity != _identity:
		_identity = identity
		data = {}
		received_tick = 0
		stale = true
		_backoff = 8000
		_next_poll = 0
		_operations.clear()
		_last_status.clear()
		_resumed_identity = ""
		changed.emit()
	_overlay.visible = eligible()
	if not data.is_empty() and not stale and received_tick > 0 and Time.get_ticks_msec() - received_tick > 20000:
		stale = true
		changed.emit()
	if not eligible(): return
	if _resumed_identity != identity:
		_resumed_identity = identity
		for kind in ["woe", "core_defense"]:
			var pending := saved(kind)
			if not pending.is_empty(): _start_saved(kind, pending)
	for kind in _operations.keys():
		var op: Dictionary = _operations[kind]
		if op.get("verified") is Dictionary and not op.verified.is_empty() and SceneRouter.invitation_handoff_safe() and not op.get("verifying", false): _reverify_before_navigation(kind, op)
	if not _busy and Time.get_ticks_msec() >= _next_poll: refresh()

func refresh() -> void:
	if _busy or not eligible() or Time.get_ticks_msec() < _next_poll: return
	_busy = true
	var identity: String = WoeClient.identity()
	var result: Dictionary = await WoeClient.request("/forest/minigames/invitations", null, self)
	_busy = false
	if identity != WoeClient.identity(): return
	if result.code == 200 and result.get("data") is Dictionary:
		data = result.data
		received_tick = Time.get_ticks_msec()
		_backoff = 8000
		stale = false
	else:
		stale = true
		_backoff = maxi(int(float(result.get("retry_after", 0.0)) * 1000.0), mini(60000, maxi(8000, _backoff * 2)))
	_next_poll = Time.get_ticks_msec() + _backoff
	changed.emit()

# The journal belongs to the authenticated account, and the cache owns every
# request so closing an invitation panel cannot abandon an in-flight action.
func operation(kind: String) -> Dictionary:
	return _operations.get(kind, {})

func operation_pending(kind: String) -> bool:
	var current := operation(kind)
	return not current.is_empty() and current.get("status") != "INVITE_RECONNECT_FAILED"

func submit(kind: String, action: String, values: Dictionary, room: String = "", expires_at: int = 0) -> bool:
	if not eligible() or kind not in ["woe", "core_defense"]: return false
	var current := operation(kind)
	if not current.is_empty():
		if current.get("status") == "INVITE_RECONNECT_FAILED" and current.get("pending", {}).get("action") == action and current.get("pending", {}).get("values") == values:
			_operations.erase(kind)
			_start_saved(kind, saved(kind))
			return true
		return false
	var existing := saved(kind)
	if not existing.is_empty():
		if existing.get("action") != action or existing.get("values") != values: return false
		existing.session = WoeClient.identity().sha256_text()
		if not save(kind, existing): return false
		_start_saved(kind, existing)
		return true
	var stamp := int(data.get("server_time_unix_ms", 0)) + maxi(0, Time.get_ticks_msec() - received_tick)
	if stale or stamp <= 0:
		_operations[kind] = {"status":"INVITE_RECONNECTING", "verified":{}}
		operation_changed.emit(kind)
		_submit_after_refresh(kind, action, values.duplicate(true), room, expires_at, WoeClient.identity())
		return true
	var body := values.duplicate(true)
	body.client_action_id = "%d:%s" % [stamp, Crypto.new().generate_random_bytes(16).hex_encode()]
	var pending := {"action":action, "values":values.duplicate(true), "body":body, "recover_room":room, "expires_at":expires_at, "session":WoeClient.identity().sha256_text()}
	if not save(kind, pending): return false
	_start_saved(kind, pending)
	return true

func _submit_after_refresh(kind: String, action: String, values: Dictionary, room: String, expiry: int, identity: String) -> void:
	# An explicit click is retained while the existing polling backoff elapses.
	for attempt in range(8):
		if identity != WoeClient.identity() or not _operations.has(kind): return
		if not stale and not data.is_empty():
			if action == "invite/respond":
				var found := false
				for invite in data.get("incoming", []):
					if invite is Dictionary and str(invite.get("invite_id", "")) == str(values.get("invite_id", "")) and str(invite.get("game_kind", "")) == kind and (room.is_empty() or str(invite.get("room_id", "")) == room):
						found = true
						expiry = int(invite.get("expires_at", 0))
						break
				if not found:
					_operations.erase(kind)
					_last_status[kind] = "INVITE_EXPIRED"
					operation_changed.emit(kind)
					return
			_operations.erase(kind)
			if not submit(kind, action, values, room, expiry):
				_last_status[kind] = "CD_INVITE_UNAVAILABLE"
				operation_changed.emit(kind)
			return
		refresh()
		await get_tree().create_timer(maxf(2.0, minf(60.0, float(_next_poll - Time.get_ticks_msec()) / 1000.0))).timeout
	if identity == WoeClient.identity() and _operations.has(kind):
		_operations.erase(kind)
		_last_status[kind] = "INVITE_RECONNECT_FAILED"
		operation_changed.emit(kind)

func _start_saved(kind: String, pending: Dictionary) -> void:
	if not operation(kind).is_empty() or not pending.get("body") is Dictionary or str(pending.get("action", "")) not in ["invite", "invite/respond", "invite/cancel"]: return
	var session := WoeClient.identity().sha256_text()
	if not str(pending.get("session", "")).is_empty() and str(pending.session) != session:
		_last_status[kind] = "INVITE_SESSION_CHANGED"
		operation_changed.emit(kind)
		return
	if not pending.has("session"):
		pending = pending.duplicate(true)
		pending.session = session
		if not save(kind, pending): return
	_operations[kind] = {"pending":pending, "status":"INVITE_ACCEPTING" if pending.get("action") == "invite/respond" and pending.get("values", {}).get("accept", false) else "INVITE_SENDING", "verified":{}}
	operation_changed.emit(kind)
	_run_operation(kind, pending, WoeClient.identity())

func _run_operation(kind: String, pending: Dictionary, identity: String) -> void:
	var client: Node = WoeClient if kind == "woe" else CoreDefenseClient
	var accepting: bool = pending.get("action") == "invite/respond" and bool(pending.get("values", {}).get("accept", false))
	var endpoint := "/forest/woe/state?room_id=" if kind == "woe" else "/forest/core-defense/state?room_id="
	var room := str(pending.get("recover_room", ""))
	var reconcile := false
	var expired_action := false
	for attempt in range(8):
		if identity != WoeClient.identity() or saved(kind) != pending: return
		var result: Dictionary
		if reconcile and accepting and not room.is_empty():
			result = await client.request(endpoint + room.uri_encode(), null, self)
			if identity != WoeClient.identity(): return
			if int(result.get("code", 0)) == 200 and client.valid_room(result.get("data"), str(ConnectionGate.player_id)) and str(result.data.get("room_id", "")) == room:
				_operations[kind].verified = result.data
				_operations[kind].verify_after = Time.get_ticks_msec() + 8000
				operation_changed.emit(kind)
				_navigate_verified(kind, result.data)
				return
			if int(result.get("code", 0)) == 403 or int(result.get("code", 0)) == 404:
				if expired_action:
					_finish_operation(kind, pending, "INVITE_EXPIRED")
					return
				reconcile = false
			else:
				await _retry_wait(kind, attempt, result, identity)
				continue
		var expires := int(pending.get("expires_at", 0))
		var server_now := int(data.get("server_time_unix_ms", 0)) + maxi(0, Time.get_ticks_msec() - received_tick)
		if expires > 0 and server_now >= expires:
			_finish_operation(kind, pending, "INVITE_EXPIRED")
			return
		result = await client.request("/forest/minigames/" + str(pending.action), pending.body, self)
		if identity != WoeClient.identity(): return
		var code := int(result.get("code", 0))
		var error := str(result.get("error", ""))
		if code == 200:
			if accepting:
				if not result.get("data") is Dictionary or result.data.get("status") != "ACCEPTED" or str(result.data.get("room", {}).get("room_id", "")) != room:
					_finish_operation(kind, pending, "CD_INVITE_UNAVAILABLE")
					return
				reconcile = true
				continue
			_finish_operation(kind, pending, "")
			return
		if error == "ACTION_EXPIRED" and accepting and not room.is_empty():
			expired_action = true
			reconcile = true
			await _retry_wait(kind, attempt, result, identity)
			continue
		if code == 0 or code == 408 or (code >= 500 and error != "GAME_UNAVAILABLE") or (code == 429 and error not in ["INVITE_COOLDOWN", "INVITE_LIMIT", "ACTION_LIMIT"]):
			reconcile = accepting
			await _retry_wait(kind, attempt, result, identity)
			continue
		var key := "CD_INVITE_UNAVAILABLE"
		if error == "PREVIOUS_ROOM_OPEN": key = "PREVIOUS_ROOM_OPEN"
		elif error == "PLAYER_BUSY": key = "WOE_ERROR_BUSY"
		elif error == "ROOM_FULL": key = "WOE_ERROR_FULL"
		elif error == "TARGET_UNAVAILABLE": key = "INVITE_TARGET_UNAVAILABLE"
		elif error == "INVITE_COOLDOWN": key = "INVITE_COOLDOWN"
		elif error == "GAME_UNAVAILABLE": key = "WOE_ERROR_DISABLED"
		elif error in ["INVITE_NOT_PENDING", "INVITE_UNAVAILABLE"]: key = "INVITE_EXPIRED"
		_finish_operation(kind, pending, key)
		return
	if identity == WoeClient.identity() and _operations.has(kind):
		_operations[kind].status = "INVITE_RECONNECT_FAILED"
		operation_changed.emit(kind)

func _retry_wait(kind: String, attempt: int, result: Dictionary, identity: String) -> void:
	if identity != WoeClient.identity() or not _operations.has(kind): return
	_operations[kind].status = "INVITE_RECONNECTING"
	operation_changed.emit(kind)
	var delay := maxf(minf(16.0, pow(2.0, attempt)), float(result.get("retry_after", 0.0)))
	await get_tree().create_timer(delay).timeout

func _finish_operation(kind: String, pending: Dictionary, status: String) -> void:
	if not clear_exact(kind, pending): return
	_operations.erase(kind)
	_last_status[kind] = status
	operation_changed.emit(kind)
	refresh()

var _last_status := {}
func last_status(kind: String) -> String:
	return str(_last_status.get(kind, ""))

func _reverify_before_navigation(kind: String, op: Dictionary) -> void:
	if Time.get_ticks_msec() < int(op.get("verify_after", 0)): return
	op.verifying = true
	var identity := WoeClient.identity()
	var client: Node = WoeClient if kind == "woe" else CoreDefenseClient
	var room := str(op.verified.get("room_id", ""))
	var endpoint := "/forest/woe/state?room_id=" if kind == "woe" else "/forest/core-defense/state?room_id="
	var result: Dictionary = await client.request(endpoint + room.uri_encode(), null, self)
	if identity != WoeClient.identity() or not _operations.has(kind): return
	op.verifying = false
	op.verify_after = Time.get_ticks_msec() + 8000
	if int(result.get("code", 0)) == 200 and client.valid_room(result.get("data"), str(ConnectionGate.player_id)) and str(result.data.get("room_id", "")) == room:
		op.verified = result.data
		_navigate_verified(kind, result.data)
	elif int(result.get("code", 0)) in [403, 404]:
		_finish_operation(kind, op.pending, "CD_INVITE_UNAVAILABLE")

func _navigate_verified(kind: String, room: Dictionary) -> void:
	if not eligible() or not SceneRouter.invitation_handoff_safe(): return
	var scene := get_tree().current_scene
	if scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD:
		if scene.has_method("invitation_handoff"): scene.invitation_handoff(kind, room)
	else:
		if SceneRouter.begin_invited_minigame(kind, room): invitation_navigation_complete(kind, room)

func invitation_navigation_complete(kind: String, room: Dictionary) -> void:
	var op: Dictionary = operation(kind)
	if op.is_empty() or op.get("verified", {}) != room: return
	var client: Node = WoeClient if kind == "woe" else CoreDefenseClient
	client.save_room(str(room.room_id))
	_finish_operation(kind, op.pending, "")

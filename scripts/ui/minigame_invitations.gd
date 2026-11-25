extends VBoxContainer

const MENU_ART := preload("res://scripts/ui/menu_art.gd")

signal admitted(room: Dictionary)
var room_id := ""
var game_kind := "core_defense"
var allow_accept := false
var can_invite := true
var _identity := ""
var _busy := false
var _status: Label
var _items: VBoxContainer
var _server_time := 0
var _server_tick := 0
var _reply_room := ""
var _render_key := ""
const FILE := "user://minigame_invite_recovery.cfg"

func _ready() -> void:
	_identity = _client().identity()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var refresh := Button.new()
	MENU_ART.button(refresh)
	refresh.text = tr("CD_INVITE_REFRESH")
	refresh.pressed.connect(refresh_invitations)
	add_child(refresh)
	_items = VBoxContainer.new()
	add_child(_items)
	MinigameInvitationCache.changed.connect(_cache_changed)
	refresh_invitations()

func _client() -> Node:
	return WoeClient if game_kind == "woe" else CoreDefenseClient

func _valid() -> bool:
	return is_inside_tree() and _identity == _client().identity()

func _saved() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	var value: Variant = cfg.get_value("pending", _client().account_key() + "|" + game_kind, {})
	return value if value is Dictionary else {}

func _save(value: Dictionary) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("pending", _client().account_key() + "|" + game_kind, value)
	return cfg.save(FILE) == OK

func refresh_invitations() -> void:
	if _busy or not _valid(): return
	_render_key = ""
	MinigameInvitationCache.refresh()
	_render_cache()

func _cache_changed() -> void:
	if _valid() and not _busy: _render_cache()

func _render_cache() -> void:
	var data: Dictionary = MinigameInvitationCache.data
	if data.is_empty():
		_status.text = tr("CD_INVITE_UNAVAILABLE")
		return
	_server_time = int(data.get("server_time_unix_ms", 0))
	_server_tick = MinigameInvitationCache.received_tick
	var key := JSON.stringify([data.get("incoming", []), data.get("outgoing", []), data.get("recent", []), room_id, game_kind, _saved()])
	if key == _render_key: return
	_render_key = key
	for child in _items.get_children(): child.queue_free()
	_status.text = tr("CD_INVITE_HINT")
	for invite in data.get("incoming", []):
		if not invite is Dictionary or str(invite.get("game_kind", "")) != game_kind: continue
		var row := HBoxContainer.new()
		_items.add_child(row)
		var label := Label.new()
		var remaining := maxi(0, int(ceil(float(int(invite.get("expires_at", 0)) - (_server_time + Time.get_ticks_msec() - _server_tick)) / 1000.0)))
		label.text = (tr("CD_INVITED_BY") % _friend_name(str(invite.get("inviter_id", "")))) + (" (%ds)" % remaining)
		row.add_child(label)
		_add_button(row, "CD_ACCEPT", _respond.bind(str(invite.invite_id), true, str(invite.get("room_id", ""))))
		_add_button(row, "CD_DECLINE", _respond.bind(str(invite.invite_id), false, str(invite.get("room_id", ""))))
	for invite in data.get("outgoing", []):
		if not invite is Dictionary or str(invite.get("room_id", "")) != room_id: continue
		var row := HBoxContainer.new()
		_items.add_child(row)
		var label := Label.new()
		label.text = tr("CD_PENDING") % _friend_name(str(invite.get("recipient_id", "")))
		row.add_child(label)
		_add_button(row, "CD_CANCEL_INVITE", _cancel.bind(str(invite.invite_id)))
	for invite in data.get("recent", []):
		if not invite is Dictionary or str(invite.get("game_kind", "")) != game_kind: continue
		var label := Label.new()
		label.text = "%s: %s" % [_friend_name(str(invite.get("recipient_id", ""))), tr("CD_INVITE_STATUS_" + str(invite.get("status", "")).to_upper())]
		_items.add_child(label)
	if not room_id.is_empty() and can_invite:
		_busy = true
		var friends: Dictionary = await _client().request("/forest/minigames/invite-friends?room_id=" + room_id.uri_encode(), null, self)
		if not _valid(): return
		_busy = false
		if friends.code == 200:
			for friend in friends.data.get("friends", []):
				if not friend is Dictionary: continue
				var id := str(friend.get("player_id", ""))
				var button := Button.new()
				MENU_ART.button(button)
				var display := str(friend.get("display_name", "")).strip_edges()
				button.text = tr("CD_INVITE_FRIEND") % (display if not display.is_empty() else tr("INVITE_UNKNOWN_PLAYER"))
				button.set_meta("invite_friend", true)
				button.disabled = not can_invite
				button.pressed.connect(_send.bind(id))
				_items.add_child(button)
	if not _saved().is_empty():
		_add_button(_items, "WOE_RETRY", _retry)

func _add_button(parent: Node, key: String, callback: Callable) -> void:
	var button := Button.new()
	MENU_ART.button(button)
	button.text = tr(key)
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)

func _friend_name(id: String) -> String:
	var value := str(SocialClient.friends.get(id, "")).strip_edges()
	return value if not value.is_empty() else tr("INVITE_UNKNOWN_PLAYER")

func set_inviting_enabled(enabled: bool) -> void:
	if can_invite == enabled: return
	can_invite = enabled
	if not is_instance_valid(_items): return
	for item in _items.get_children():
		if item is Button and item.has_meta("invite_friend"): item.disabled = not enabled
	if enabled and not _busy: refresh_invitations()

func _accept_context_valid() -> bool:
	if not allow_accept: return false
	var scene := get_tree().current_scene
	if not is_instance_valid(scene) or scene.scene_file_path != SceneRouter.SCENE_FOREST_WORLD: return false
	var browser_name := "WOEBrowser" if game_kind == "woe" else "CoreDefenseBrowser"
	if scene._canvas.get_node_or_null(browser_name) == null: return false
	return scene.forest_action_allowed(game_kind, str(scene._zones[scene._zone_index].id), scene._player.position, scene._player.facing)

func _send(id: String) -> void:
	if not can_invite: return
	_submit("invite", {"room_id":room_id,"game_kind":game_kind,"target_player_id":id})

func _respond(id: String, accept: bool, admitted_room: String) -> void:
	_reply_room = admitted_room if accept else ""
	await _submit("invite/respond", {"invite_id":id,"accept":accept})

func _cancel(id: String) -> void:
	_submit("invite/cancel", {"invite_id":id})

func _retry() -> void:
	var saved := _saved()
	if not saved.is_empty(): _submit(str(saved.get("action", "")), saved.get("values", {}))

func _submit(action: String, values: Dictionary) -> void:
	if _busy or not _valid(): return
	if action == "invite/respond" and bool(values.get("accept", false)) and not _accept_context_valid():
		_status.text = tr("INVITE_CLEARING_GUIDANCE")
		return
	var pending := _saved()
	if not pending.is_empty() and (pending.get("action") != action or pending.get("values") != values):
		_status.text = tr("WOE_RETRY_PENDING")
		return
	if pending.is_empty():
		var stamp: int = _server_time + maxi(0, Time.get_ticks_msec() - _server_tick) if _server_time > 0 else 0
		if stamp <= 0:
			_status.text = tr("CD_INVITE_UNAVAILABLE")
			return
		var body := values.duplicate(true)
		body.client_action_id = "%d:%s" % [stamp, Crypto.new().generate_random_bytes(16).hex_encode()]
		pending = {"action":action,"values":values.duplicate(true),"body":body,"recover_room":_reply_room}
		if not _save(pending):
			_status.text = tr("CD_INVITE_UNAVAILABLE")
			return
	_busy = true
	var result: Dictionary = await _client().request("/forest/minigames/" + action, pending.body, self)
	if not _valid(): return
	_busy = false
	var code := int(result.get("code", 0))
	var error := str(result.get("error", ""))
	if code == 200 and action == "invite/respond" and bool(values.get("accept", false)) and (not result.get("data") is Dictionary or result.data.get("status") != "ACCEPTED" or not _client().valid_room(result.data.get("room"), str(ConnectionGate.player_id))):
		_status.text = tr("CD_INVITE_UNAVAILABLE")
		return
	if code > 0 and code < 500 and code != 408 and code != 429 and error != "FOREST_PRESENCE_REQUIRED" and not (action == "invite/respond" and bool(values.get("accept", false)) and (error == "ACTION_EXPIRED" or code == 200)): _save({})
	if code == 200 and action == "invite/respond" and bool(values.get("accept", false)) and str(pending.get("recover_room", "")) != str(result.data.get("room", {}).get("room_id", "")):
		_status.text = tr("CD_INVITE_UNAVAILABLE")
		return
	if code == 200 and result.data.get("status") == "ACCEPTED":
		var room: Variant = result.data.get("room", {})
		if _client().valid_room(room, str(ConnectionGate.player_id)):
			if game_kind == "core_defense":
				if not CoreDefenseClient.persist_room(str(room.room_id)):
					_status.text = tr("CD_INVITE_UNAVAILABLE")
					return
			else: _client().save_room(str(room.room_id))
			_busy = true
			var endpoint := "/forest/woe/state?room_id=" if game_kind == "woe" else "/forest/core-defense/state?room_id="
			var verified: Dictionary = await _client().request(endpoint + str(room.room_id).uri_encode(), null, self)
			if not _valid(): return
			_busy = false
			if verified.code == 200 and _client().valid_room(verified.data, str(ConnectionGate.player_id)) and str(verified.data.room_id) == str(pending.get("recover_room", "")):
				if not _accept_context_valid():
					_status.text = tr("INVITE_CLEARING_GUIDANCE")
					return
				if not _save({}):
					_status.text = tr("CD_INVITE_UNAVAILABLE")
					return
				admitted.emit(verified.data)
				return
			_status.text = tr("CD_INVITE_UNAVAILABLE")
			return
	if error == "ACTION_EXPIRED" and action == "invite/respond" and bool(values.get("accept", false)) and not str(pending.get("recover_room", "")).is_empty():
		var endpoint := "/forest/woe/state?room_id=" if game_kind == "woe" else "/forest/core-defense/state?room_id="
		_busy = true
		var recovered: Dictionary = await _client().request(endpoint + str(pending.recover_room).uri_encode(), null, self)
		if not _valid(): return
		_busy = false
		if recovered.code == 200 and _client().valid_room(recovered.data, str(ConnectionGate.player_id)) and str(recovered.data.room_id) == str(pending.recover_room):
			if not _accept_context_valid():
				_status.text = tr("INVITE_CLEARING_GUIDANCE")
				return
			if game_kind == "core_defense":
				if not CoreDefenseClient.persist_room(str(recovered.data.room_id)):
					_status.text = tr("CD_INVITE_UNAVAILABLE")
					return
			else: _client().save_room(str(recovered.data.room_id))
			_save({})
			admitted.emit(recovered.data)
			return
		if recovered.code == 404: _save({})
	if error == "ACTION_EXPIRED" and action == "invite/respond" and str(pending.get("recover_room", "")).is_empty(): _save({})
	if error == "FOREST_PRESENCE_REQUIRED": _status.text = tr("WOE_ERROR_PRESENCE")
	elif error == "ACTION_EXPIRED": _status.text = tr("CD_ACTION_EXPIRED")
	elif code != 200: _status.text = tr("CD_INVITE_UNAVAILABLE")
	else: refresh_invitations()

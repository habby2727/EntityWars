extends VBoxContainer

const MENU_ART := preload("res://scripts/ui/menu_art.gd")
const PANEL_STYLE := preload("res://scripts/ui/minigame_panel_style.gd")
const PLAYER_NAMES := preload("res://scripts/ui/minigame_names.gd")

signal admitted(room: Dictionary)
var room_id := ""
var game_kind := "core_defense"
var allow_accept := false
var can_invite := true
var plain_buttons := false
var _identity := ""
var _busy := false
var _status: Label
var _items: VBoxContainer
var _server_time := 0
var _server_tick := 0
var _reply_room := ""
var _render_key := ""
var _countdown := 0.0
var _friends: Array = []
var _friends_room := ""
var _render_again := false

func _ready() -> void:
	_identity = _client().identity()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var refresh := Button.new()
	_style_button(refresh)
	refresh.text = tr("CD_INVITE_REFRESH")
	refresh.pressed.connect(refresh_invitations)
	add_child(refresh)
	_items = VBoxContainer.new()
	add_child(_items)
	MinigameInvitationCache.changed.connect(_cache_changed)
	MinigameInvitationCache.operation_changed.connect(_operation_changed)
	refresh_invitations()

func _client() -> Node:
	return WoeClient if game_kind == "woe" else CoreDefenseClient

func _valid() -> bool:
	return is_inside_tree() and _identity == _client().identity()

func _saved() -> Dictionary:
	return MinigameInvitationCache.saved(game_kind)

func _save(value: Dictionary) -> bool:
	return _valid() and MinigameInvitationCache.save(game_kind, value)

func refresh_invitations() -> void:
	if _busy or not _valid(): return
	_friends_room = ""
	_render_key = ""
	MinigameInvitationCache.refresh()
	_render_cache()

func _cache_changed() -> void:
	if not _valid(): return
	if _busy: _render_again = true
	else: _render_cache()

func _process(delta: float) -> void:
	_countdown -= delta
	if _countdown > 0 or not is_instance_valid(_items): return
	_countdown = 1.0
	for row in _items.get_children():
		if not row.has_meta("invitation"): continue
		var invite: Dictionary = row.get_meta("invitation")
		var remaining := maxi(0, int(ceil(float(int(invite.get("expires_at", 0)) - (_server_time + Time.get_ticks_msec() - _server_tick)) / 1000.0)))
		if row.get_meta("incoming", false): row.get_meta("label").text = (tr("CD_INVITED_BY") % _friend_name(str(invite.get("inviter_id", "")))) + (" (%ds)" % remaining)
		for button in row.get_children():
			if button is Button: button.disabled = remaining <= 0 or MinigameInvitationCache.operation_pending(game_kind)

func _render_cache() -> void:
	var data: Dictionary = MinigameInvitationCache.data
	if data.is_empty():
		_status.text = tr("CD_INVITE_UNAVAILABLE")
		return
	_server_time = int(data.get("server_time_unix_ms", 0))
	_server_tick = MinigameInvitationCache.received_tick
	var operation: Dictionary = MinigameInvitationCache.operation(game_kind)
	var message := str(operation.get("status", MinigameInvitationCache.last_status(game_kind)))
	_status.text = tr(message) if not message.is_empty() else (tr("INVITE_STALE") if MinigameInvitationCache.stale else tr("CD_INVITE_HINT"))
	var key := JSON.stringify([data.get("incoming", []), data.get("outgoing", []), data.get("recent", []), room_id, game_kind, _saved()])
	if key == _render_key: return
	_render_key = key
	for child in _items.get_children(): child.queue_free()
	for invite in data.get("incoming", []):
		if not invite is Dictionary or str(invite.get("game_kind", "")) != game_kind: continue
		var row := HBoxContainer.new()
		row.set_meta("invitation", invite)
		row.set_meta("incoming", true)
		_items.add_child(row)
		var label := Label.new()
		row.set_meta("label", label)
		var remaining := maxi(0, int(ceil(float(int(invite.get("expires_at", 0)) - (_server_time + Time.get_ticks_msec() - _server_tick)) / 1000.0)))
		label.text = (tr("CD_INVITED_BY") % _friend_name(str(invite.get("inviter_id", "")))) + (" (%ds)" % remaining)
		row.add_child(label)
		_add_button(row, "CD_ACCEPT", _respond.bind(str(invite.invite_id), true, str(invite.get("room_id", ""))))
		_add_button(row, "CD_DECLINE", _respond.bind(str(invite.invite_id), false, str(invite.get("room_id", ""))))
		for button in row.get_children():
			if button is Button: button.disabled = remaining <= 0 or MinigameInvitationCache.operation_pending(game_kind)
	for invite in data.get("outgoing", []):
		if not invite is Dictionary or str(invite.get("room_id", "")) != room_id: continue
		var row := HBoxContainer.new()
		row.set_meta("invitation", invite)
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
		if _friends_room != room_id:
			_busy = true
			var friends: Dictionary = await _client().request("/forest/minigames/invite-friends?room_id=" + room_id.uri_encode(), null, self)
			if not _valid(): return
			_busy = false
			if friends.code == 200 and friends.get("data") is Dictionary:
				_friends = friends.data.get("friends", [])
				_friends_room = room_id
			if _render_again or key != _render_key:
				_render_again = false
				_render_key = ""
				_render_cache()
				return
		for friend in _friends:
			if not friend is Dictionary: continue
			var id := str(friend.get("player_id", ""))
			var button := Button.new()
			_style_button(button)
			var display := PLAYER_NAMES.clean(friend.get("display_name"))
			button.text = tr("CD_INVITE_FRIEND") % (display if not display.is_empty() else tr("INVITE_UNKNOWN_PLAYER"))
			button.set_meta("invite_friend", true)
			button.disabled = not can_invite or MinigameInvitationCache.operation_pending(game_kind)
			button.pressed.connect(_send.bind(id))
			_items.add_child(button)

func _add_button(parent: Node, key: String, callback: Callable) -> void:
	var button := Button.new()
	_style_button(button)
	button.text = tr(key)
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)

func _style_button(button: Button) -> void:
	if plain_buttons: PANEL_STYLE.button(button)
	else: MENU_ART.button(button)

func _friend_name(id: String) -> String:
	var value := PLAYER_NAMES.clean(SocialClient.friends.get(id))
	return value if not value.is_empty() else tr("INVITE_UNKNOWN_PLAYER")

func set_inviting_enabled(enabled: bool) -> void:
	if can_invite == enabled: return
	can_invite = enabled
	if not is_instance_valid(_items): return
	for item in _items.get_children():
		if item is Button and item.has_meta("invite_friend"): item.disabled = not enabled
	if enabled and not _busy: refresh_invitations()

func _operation_changed(kind: String) -> void:
	if kind != game_kind or not _valid(): return
	_render_key = ""
	if _busy: _render_again = true
	else: _render_cache()

func _accept_context_valid() -> bool:
	return allow_accept and SceneRouter.invitation_handoff_safe()

func _send(id: String) -> void:
	if can_invite: _submit("invite", {"room_id":room_id, "game_kind":game_kind, "target_player_id":id})

func _respond(id: String, accept: bool, admitted_room: String) -> void:
	if accept and not _accept_context_valid():
		_status.text = tr("CD_INVITE_UNAVAILABLE")
		return
	var expiry := 0
	for invite in MinigameInvitationCache.data.get("incoming", []):
		if invite is Dictionary and str(invite.get("invite_id", "")) == id and str(invite.get("game_kind", "")) == game_kind and str(invite.get("room_id", "")) == admitted_room:
			expiry = int(invite.get("expires_at", 0))
			break
	if expiry <= 0:
		MinigameInvitationCache.refresh()
		_status.text = tr("CD_INVITE_UNAVAILABLE")
		return
	_submit("invite/respond", {"invite_id":id, "accept":accept}, admitted_room if accept else "", expiry)

func _cancel(id: String) -> void:
	_submit("invite/cancel", {"invite_id":id})

func _submit(action: String, values: Dictionary, room: String = "", expiry: int = 0) -> void:
	if not _valid() or _busy: return
	if not MinigameInvitationCache.submit(game_kind, action, values, room, expiry):
		_status.text = tr("INVITE_STALE") if MinigameInvitationCache.stale else tr("WOE_RETRY_PENDING")

extends VBoxContainer

const MENU_ART := preload("res://scripts/ui/menu_art.gd")
var _rows := {}
var _actions := {}
var _identity := ""

func _ready() -> void:
	_identity = WoeClient.identity()
	_create_actions()
	MinigameInvitationCache.changed.connect(_refresh)
	_refresh()

func _create_actions() -> void:
	for kind in ["woe", "core_defense"]:
		var actions = preload("res://scripts/ui/minigame_invitations.gd").new()
		actions.game_kind = kind
		actions.allow_accept = true
		actions.visible = false
		add_child(actions)
		actions.admitted.connect(_admitted.bind(kind))
		_actions[kind] = actions

func _admitted(room: Dictionary, kind: String) -> void:
	var forest := get_tree().current_scene
	if not is_instance_valid(forest): return
	if kind == "woe": forest._woe_admitted(room)
	else: forest._core_defense_admitted(room)

func _refresh() -> void:
	if _identity != WoeClient.identity():
		for row in _rows.values(): row.queue_free()
		_rows.clear()
		for action in _actions.values(): action.queue_free()
		_actions.clear()
		_identity = WoeClient.identity()
		_create_actions()
	var incoming: Array = MinigameInvitationCache.data.get("incoming", [])
	var current := {}
	for invite in incoming:
		if not invite is Dictionary: continue
		var id := str(invite.get("invite_id", ""))
		var kind := str(invite.get("game_kind", ""))
		if id.is_empty() or kind not in _actions: continue
		current[id] = true
		if _rows.has(id):
			_set_label(_rows[id].get_meta("label"), invite)
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", MENU_ART.frame("marco-horizontal-popup.png", Vector4(20, 20, 20, 20)))
		add_child(panel)
		_rows[id] = panel
		var box := VBoxContainer.new()
		panel.add_child(box)
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_set_label(label, invite)
		panel.set_meta("label", label)
		box.add_child(label)
		var feedback := Label.new()
		feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(feedback)
		var buttons := HBoxContainer.new()
		box.add_child(buttons)
		for accept in [true, false]:
			var button := Button.new()
			MENU_ART.button(button)
			button.text = tr("CD_ACCEPT" if accept else "CD_DECLINE")
			button.custom_minimum_size.y = 44
			button.pressed.connect(_respond.bind(kind, id, accept, str(invite.get("room_id", "")), feedback))
			buttons.add_child(button)
	for id in _rows.keys():
		if not current.has(id):
			_rows[id].queue_free()
			_rows.erase(id)

func _set_label(label: Label, invite: Dictionary) -> void:
	var friend := str(SocialClient.friends.get(str(invite.get("inviter_id", "")), "")).strip_edges()
	if friend.is_empty(): friend = tr("INVITE_UNKNOWN_PLAYER")
	var seconds := maxi(0, int(ceil(float(int(invite.get("expires_at", 0)) - int(MinigameInvitationCache.data.get("server_time_unix_ms", 0))) / 1000.0)))
	label.text = "%s: %s (%ds)" % [tr("WOE_TITLE" if invite.get("game_kind") == "woe" else "CD_TITLE"), friend, seconds]

func _respond(kind: String, id: String, accept: bool, room: String, feedback: Label) -> void:
	var actions: Node = _actions[kind]
	if accept and not actions._accept_context_valid():
		feedback.text = tr("INVITE_CLEARING_GUIDANCE")
		return
	await actions._respond(id, accept, room)
	if is_instance_valid(feedback): feedback.text = actions._status.text

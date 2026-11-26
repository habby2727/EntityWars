extends VBoxContainer

const MENU_ART := preload("res://scripts/ui/menu_art.gd")
const PLAYER_NAMES := preload("res://scripts/ui/minigame_names.gd")
var _rows := {}
var _actions := {}
var _identity := ""
var _inbox_button: Button
var _inbox_scroll: ScrollContainer
var _inbox_rows: VBoxContainer
var _countdown := 0.0

func _ready() -> void:
	_identity = WoeClient.identity()
	_create_actions()
	_inbox_button = Button.new()
	MENU_ART.button(_inbox_button)
	_inbox_button.text = tr("INVITE_INBOX")
	_inbox_button.custom_minimum_size.y = 44
	_inbox_button.pressed.connect(func(): _inbox_scroll.visible = not _inbox_scroll.visible)
	add_child(_inbox_button)
	_inbox_scroll = ScrollContainer.new()
	_inbox_scroll.custom_minimum_size = Vector2(360, 220)
	_inbox_scroll.visible = false
	add_child(_inbox_scroll)
	_inbox_rows = VBoxContainer.new()
	_inbox_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inbox_scroll.add_child(_inbox_rows)
	MinigameInvitationCache.changed.connect(_refresh)
	MinigameInvitationCache.operation_changed.connect(func(_kind): _refresh())
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
	MinigameInvitationCache._navigate_verified(kind, room)

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
	var count := 0
	for invite in incoming:
		if not invite is Dictionary: continue
		var id := str(invite.get("invite_id", ""))
		var kind := str(invite.get("game_kind", ""))
		if id.is_empty() or kind not in _actions: continue
		current[id] = true
		var parent: Node = self if count < 2 else _inbox_rows
		count += 1
		if _rows.has(id):
			if _rows[id].get_parent() != parent: _rows[id].reparent(parent)
			_rows[id].set_meta("invite", invite)
			_set_label(_rows[id].get_meta("label"), invite)
			var status := str(MinigameInvitationCache.operation(kind).get("status", MinigameInvitationCache.last_status(kind)))
			_rows[id].get_meta("feedback").text = tr(status) if not status.is_empty() else ""
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", MENU_ART.frame("panel_horizontal.png", Vector4(20, 20, 20, 20)))
		parent.add_child(panel)
		_rows[id] = panel
		panel.set_meta("invite", invite)
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
		panel.set_meta("feedback", feedback)
		var status := str(MinigameInvitationCache.operation(kind).get("status", MinigameInvitationCache.last_status(kind)))
		feedback.text = tr(status) if not status.is_empty() else ""
		var buttons := HBoxContainer.new()
		box.add_child(buttons)
		for accept in [true, false]:
			var button := Button.new()
			MENU_ART.button(button)
			button.text = tr("CD_ACCEPT" if accept else "CD_DECLINE")
			button.custom_minimum_size.y = 44
			button.pressed.connect(_respond.bind(kind, id, accept, str(invite.get("room_id", "")), feedback))
			buttons.add_child(button)
		panel.set_meta("buttons", buttons)
	for id in _rows.keys():
		if not current.has(id):
			_rows[id].queue_free()
			_rows.erase(id)
	_inbox_button.visible = count > 2
	if count <= 2: _inbox_scroll.hide()
	_update_countdowns()

func _process(delta: float) -> void:
	_countdown -= delta
	if _countdown <= 0:
		_countdown = 1.0
		_update_countdowns()

func _update_countdowns() -> void:
	for row in _rows.values():
		if not is_instance_valid(row): continue
		var invite: Dictionary = row.get_meta("invite")
		_set_label(row.get_meta("label"), invite)
		var remaining := int(invite.get("expires_at", 0)) - int(MinigameInvitationCache.data.get("server_time_unix_ms", 0)) - maxi(0, Time.get_ticks_msec() - MinigameInvitationCache.received_tick)
		for button in row.get_meta("buttons").get_children(): button.disabled = remaining <= 0 or MinigameInvitationCache.operation_pending(str(invite.get("game_kind", "")))

func _set_label(label: Label, invite: Dictionary) -> void:
	var friend := PLAYER_NAMES.clean(SocialClient.friends.get(str(invite.get("inviter_id", ""))))
	if friend.is_empty(): friend = tr("INVITE_UNKNOWN_PLAYER")
	var seconds := maxi(0, int(ceil(float(int(invite.get("expires_at", 0)) - int(MinigameInvitationCache.data.get("server_time_unix_ms", 0)) - maxi(0, Time.get_ticks_msec() - MinigameInvitationCache.received_tick)) / 1000.0)))
	label.text = "%s: %s (%ds)%s" % [tr("WOE_TITLE" if invite.get("game_kind") == "woe" else "CD_TITLE"), friend, seconds, " " + tr("INVITE_STALE") if MinigameInvitationCache.stale else ""]

func _respond(kind: String, id: String, accept: bool, room: String, feedback: Label) -> void:
	var actions: Node = _actions[kind]
	if accept and not actions._accept_context_valid():
		feedback.text = tr("INVITE_ACTIVITY_BLOCKED")
		return
	actions._respond(id, accept, room)
	if is_instance_valid(feedback) and is_instance_valid(actions): feedback.text = actions._status.text

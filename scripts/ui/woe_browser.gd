extends PanelContainer

const PANEL_STYLE := preload("res://scripts/ui/minigame_panel_style.gd")

signal admitted(room: Dictionary)
var _rows: VBoxContainer
var _status: Label
var _code: LineEdit
var _buttons: Array[Button] = []
var _busy := false
var _epoch := ""

func _ready() -> void:
	PANEL_STYLE.panel(self)
	_epoch = WoeClient.identity()
	custom_minimum_size = Vector2(420, 360)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = tr("WOE_TITLE")
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	for mode in ["1v1", "2v2"]:
		var create := _button(actions, "WOE_CREATE_" + mode.to_upper(), _mutate.bind("create", {"mode":mode}))
		create.custom_minimum_size.y = 70
		create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		create.add_theme_font_size_override("font_size", 22)
	_button(box, "WOE_REFRESH", refresh)
	_code = LineEdit.new()
	_code.placeholder_text = tr("WOE_CODE_HINT")
	box.add_child(_code)
	_button(box, "WOE_JOIN_CODE", func(): _mutate("join", {"room_id_or_code":_code.text.strip_edges()}))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 70
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var invite_scroll := ScrollContainer.new()
	invite_scroll.custom_minimum_size.y = 100
	invite_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(invite_scroll)
	var invites = preload("res://scripts/ui/minigame_invitations.gd").new()
	invites.name = "Invitations"
	invites.game_kind = "woe"
	invites.allow_accept = true
	invites.plain_buttons = true
	invites.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invite_scroll.add_child(invites)
	invites.admitted.connect(_invite_admitted)
	_button(box, "WOE_RETRY", _retry)
	var close := Button.new()
	PANEL_STYLE.button(close)
	close.text = tr("FOREST_CLOSE")
	close.pressed.connect(queue_free)
	box.add_child(close)
	if not WoeClient.saved_pending().is_empty():
		_status.text = tr("WOE_RETRY_PENDING")
	elif not WoeClient.saved_room().is_empty() or not WoeClient.saved_match().is_empty():
		_recover()
	else:
		_recover_current()

func _process(_delta: float) -> void:
	if _epoch != WoeClient.identity(): queue_free()

func _button(parent: Node, text_key: String, action: Callable) -> Button:
	var b := Button.new()
	PANEL_STYLE.button(b, text_key in ["WOE_CREATE_1V1", "WOE_CREATE_2V2"])
	b.text = tr(text_key)
	b.pressed.connect(action)
	parent.add_child(b)
	_buttons.append(b)
	return b

func _set_busy(value: bool) -> void:
	_busy = value
	for b in _buttons:
		if is_instance_valid(b): b.disabled = value

func _valid() -> bool:
	return is_inside_tree() and _epoch == WoeClient.identity()

func _invite_admitted(room: Dictionary) -> void:
	if _valid(): admitted.emit(room)

func _show_error(result: Dictionary) -> void:
	var code := int(result.get("code", 0))
	var error := str(result.get("error", ""))
	var key := "WOE_ERROR_NETWORK"
	if code == 503: key = "WOE_ERROR_DISABLED"
	elif error == "ROOM_FULL": key = "WOE_ERROR_FULL"
	elif error in ["PLAYER_BUSY", "WOE_BUSY"]: key = "WOE_ERROR_BUSY"
	elif error == "REVISION_CONFLICT": key = "WOE_ERROR_STALE"
	elif error == "FOREST_PRESENCE_REQUIRED": key = "WOE_ERROR_PRESENCE"
	elif error == "WOE_RETRY_PENDING": key = "WOE_RETRY_PENDING"
	elif code == 404: key = "WOE_ERROR_NOT_FOUND"
	_status.text = tr(key)

func refresh() -> void:
	if _busy: return
	_set_busy(true)
	var result: Dictionary = await WoeClient.request("/forest/woe/rooms")
	if not _valid(): return
	_set_busy(false)
	if result.code != 200 or not result.data.get("rooms") is Array:
		_show_error(result)
		return
	_status.text = tr("WOE_BROWSER_HINT")
	for child in _rows.get_children(): child.queue_free()
	for room in result.data.rooms:
		if not room is Dictionary: continue
		var id := str(room.get("room_id", ""))
		if id.is_empty(): continue
		var capacity := 2 if room.get("mode") == "1v1" else 4
		var count := int(room.get("member_count", 0))
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var label := Label.new()
		label.text = "%s  %s/%s  %s: %s" % [room.get("mode", ""), count, capacity, tr("WOE_HOST"), str(room.get("host_name", "")) if not str(room.get("host_name", "")).is_empty() else tr("INVITE_UNKNOWN_PLAYER")]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var join_button := _button(row, "WOE_JOIN", _mutate.bind("join", {"room_id_or_code":id}))
		join_button.disabled = count >= capacity

func _mutate(action: String, values: Dictionary) -> void:
	if _busy: return
	_set_busy(true)
	var result: Dictionary = await WoeClient.mutate(action, values)
	if not _valid(): return
	_set_busy(false)
	_complete(result)

func _retry() -> void:
	if _busy: return
	if WoeClient.saved_pending().is_empty():
		_recover()
		return
	_set_busy(true)
	var action := str(WoeClient.saved_pending().get("action", ""))
	var result: Dictionary = await WoeClient.retry_pending()
	if not _valid(): return
	_set_busy(false)
	if action.begins_with("match/") and int(result.get("code",0)) > 0 and int(result.get("code",0)) < 500:
		_recover_current()
	else:
		_complete(result)

func _recover() -> void:
	if _busy: return
	if WoeClient.saved_room().is_empty():
		_recover_current()
		return
	_set_busy(true)
	var result: Dictionary = await WoeClient.request("/forest/woe/state?room_id=" + WoeClient.saved_room().uri_encode())
	if not _valid(): return
	_set_busy(false)
	if result.code == 404:
		WoeClient.save_room("")
		_recover_current()
		return
	_complete(result)

func _recover_current() -> void:
	if _busy: return
	_set_busy(true)
	var result: Dictionary = await WoeClient.request("/forest/woe/match/current")
	if not _valid(): return
	_set_busy(false)
	if result.code == 200 and WoeClient.valid_match(result.data, str(ConnectionGate.player_id)) and (result.data.status == "RUNNING" or str(result.data.match_id) == WoeClient.saved_match()):
		admitted.emit(result.data)
	elif result.code == 200:
		WoeClient.save_match("")
		refresh()
	else:
		_show_error(result)

func _complete(result: Dictionary) -> void:
	if int(result.get("code", 0)) == 200 and WoeClient.valid_room(result.get("data"), str(ConnectionGate.player_id)):
		# An idempotent replay may describe a room that has since expired or been left.
		_set_busy(true)
		var verified: Dictionary = await WoeClient.request("/forest/woe/state?room_id=" + str(result.data.room_id).uri_encode())
		if not _valid(): return
		_set_busy(false)
		if verified.code == 200 and WoeClient.valid_room(verified.data, str(ConnectionGate.player_id)):
			admitted.emit(verified.data)
		else:
			if verified.code == 404: WoeClient.save_room("")
			_show_error(verified)
	elif int(result.get("code", 0)) == 200 and result.get("data", {}).get("left", false):
		refresh()
	else:
		_show_error(result)

extends Control

const PANEL_STYLE := preload("res://scripts/ui/minigame_panel_style.gd")
const PLAYER_NAMES := preload("res://scripts/ui/minigame_names.gd")

const BG := preload("res://assets/forest/woe/backgrounds/Classic_Arena_1920x1080.png")
const ARENA := "res://data/static/woe_arena.json"
var _room := {}
var _identity := ""
var _canvas: Control
var _labels := {}
var _seat_buttons := {}
var _info: Label
var _code_label: Label
var _copy_button
var _message: Label
var _start: Button
var _invite_button: Button
var _invite_popup: PopupPanel
var _invites
var _fill: CheckBox
var _poll := 0.0
var _requesting := false
var _changing := false
var _expired := false
var _transitioning := false

func _ready() -> void:
	_identity = WoeClient.identity()
	if not SceneRouter.woe_context_valid():
		SceneRouter.go_to_lab_hub.call_deferred()
		return
	_build()
	_refresh()

func _build() -> void:
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	add_child(aspect)
	_canvas = Control.new()
	_canvas.set_meta("minigame_native_typography", true)
	aspect.add_child(_canvas)
	_canvas.theme = PANEL_STYLE.readable_theme()
	_canvas.resized.connect(_resize)
	var bg := TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bg)
	var arena: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARENA))
	if arena is Dictionary:
		for team in ["blue", "red"]:
			for lane in ["left", "right"]:
				var point: Dictionary = arena.laboratories[team][lane]
				var seat: String = str(team) + ":" + str(lane)
				var button := Button.new()
				PANEL_STYLE.button(button)
				button.name = seat
				button.position = Vector2(float(point.x)-150, float(point.y)-75)
				button.size = Vector2(300, 150)
				button.add_theme_font_size_override("font_size", 24)
				button.text = tr("WOE_" + team.to_upper()) + "\n" + tr("WOE_EMPTY")
				button.pressed.connect(_seat.bind(seat))
				_canvas.add_child(button)
				_seat_buttons[seat] = button
	var panel := PanelContainer.new()
	PANEL_STYLE.panel(panel)
	panel.position = Vector2(650, 260)
	panel.size = Vector2(620, 560)
	_canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 22)
	_info.max_lines_visible = 4
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_info)
	var code_row := HBoxContainer.new()
	box.add_child(code_row)
	_code_label = Label.new()
	_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_code_label.add_theme_font_size_override("font_size", 18)
	code_row.add_child(_code_label)
	_copy_button = preload("res://scripts/ui/copy_code_button.gd").new()
	PANEL_STYLE.button(_copy_button)
	code_row.add_child(_copy_button)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)
	_fill = CheckBox.new()
	_fill.text = tr("WOE_FILL_BOTS")
	_fill.add_theme_font_size_override("font_size", 21)
	_fill.button_pressed = true
	box.add_child(_fill)
	_start = Button.new()
	PANEL_STYLE.button(_start, true)
	_start.text = tr("WOE_START")
	_start.custom_minimum_size.y = 62
	_start.add_theme_font_size_override("font_size", 30)
	_start.pressed.connect(_start_match)
	box.add_child(_start)
	_invite_button = Button.new()
	PANEL_STYLE.button(_invite_button)
	_invite_button.text = tr("INVITE_OPEN")
	_invite_button.custom_minimum_size.y = 54
	_invite_button.add_theme_font_size_override("font_size", 24)
	_invite_button.pressed.connect(_open_invites)
	box.add_child(_invite_button)
	var secondary := HBoxContainer.new()
	box.add_child(secondary)
	var refresh := Button.new()
	PANEL_STYLE.button(refresh)
	refresh.text = tr("WOE_REFRESH")
	refresh.add_theme_font_size_override("font_size", 21)
	refresh.pressed.connect(_refresh)
	refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary.add_child(refresh)
	var retry := Button.new()
	PANEL_STYLE.button(retry)
	retry.text = tr("WOE_RECOVER_SHORT")
	retry.add_theme_font_size_override("font_size", 21)
	retry.pressed.connect(_retry)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary.add_child(retry)
	var leave := Button.new()
	PANEL_STYLE.button(leave)
	leave.text = tr("WOE_LEAVE")
	leave.custom_minimum_size.y = 52
	leave.add_theme_font_size_override("font_size", 22)
	leave.pressed.connect(_leave_pressed)
	box.add_child(leave)
	_resize()

func _resize() -> void:
	if not is_instance_valid(_canvas): return
	var scale_factor: Vector2 = _canvas.size / Vector2(1920, 1080)
	var arena: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARENA))
	for seat in _seat_buttons:
		var button: Button = _seat_buttons[seat]
		var parts := str(seat).split(":")
		var p: Dictionary = arena.laboratories[parts[0]][parts[1]]
		button.position = Vector2(float(p.x)-150,float(p.y)-75) * scale_factor
		button.scale = scale_factor
	for child in _canvas.get_children():
		if child is PanelContainer:
			child.position = Vector2(650,260) * scale_factor
			child.size = Vector2(620,560)
			child.scale = scale_factor

func _valid() -> bool:
	return is_inside_tree() and _identity == WoeClient.identity() and SceneRouter.woe_context_valid()

func _process(delta: float) -> void:
	if _identity != WoeClient.identity() and WoeClient.available():
		# A new authentication generation cannot reuse the old secure return context.
		# The account-scoped room remains saved for server-validated recovery.
		SceneRouter._woe_context.clear()
		SceneRouter._clear_forest_return()
		SceneRouter.go_to_lab_hub()
		return
	_poll -= delta
	if _poll <= 0.0 and not _requesting and not _changing:
		_refresh()

func _refresh() -> void:
	if _requesting or not _valid(): return
	_requesting = true
	_poll = 2.0
	var result: Dictionary = await WoeClient.request("/forest/woe/state?room_id=" + str(SceneRouter._woe_context.room_id).uri_encode())
	if not _valid(): return
	_requesting = false
	if result.code == 200 and WoeClient.valid_room(result.data, str(ConnectionGate.player_id)):
		if _room.is_empty() or int(result.data.get("revision", 0)) >= int(_room.get("revision", 0)):
			_room = result.data
			_render()
	else:
		if int(result.get("code", 0)) == 404:
			_expired = true
			_invite_button.disabled = true
			WoeClient.save_room("")
		_error(result)

func _render() -> void:
	var owner := str(ConnectionGate.player_id)
	var host := str(_room.get("host_id", ""))
	var mode := str(_room.get("mode", ""))
	var started := str(_room.get("status", "")) == "STARTED"
	if started and not _transitioning and _valid():
		_transitioning = true
		SceneRouter.enter_woe_match(_room)
		return
	_info.text = "%s  %s\n%s: %s" % [tr("WOE_TITLE"),mode,tr("WOE_HOST"),_display_name(host)]
	var join_code := PLAYER_NAMES.clean(_room.get("join_code"))
	_code_label.text = "%s: %s" % [tr("WOE_CODE"), join_code if not join_code.is_empty() else "-"]
	_copy_button.code = join_code
	_copy_button.disabled = _copy_button.code.is_empty()
	var player_list: Array[String] = []
	for member in _room.get("members", []):
		if member is Dictionary:
			var chosen := PLAYER_NAMES.clean(member.get("seat"))
			player_list.append("%s (%s)" % [_display_name(str(member.get("player_id", ""))), chosen if not chosen.is_empty() else tr("WOE_EMPTY")])
	_info.text += "\n" + tr("WOE_PLAYERS") + ": " + ", ".join(player_list)
	var own_seat := ""
	for member in _room.get("members", []):
		if member is Dictionary and str(member.get("player_id", "")) == owner: own_seat = PLAYER_NAMES.clean(member.get("seat"))
	for seat in _seat_buttons:
		var button: Button = _seat_buttons[seat]
		var occupant := ""
		for member in _room.get("members", []):
			if not member is Dictionary: continue
			var selected := PLAYER_NAMES.clean(member.get("seat"))
			if selected == seat or (mode == "1v1" and not selected.is_empty() and selected.get_slice(":",0) == seat.get_slice(":",0)):
				occupant = str(member.get("player_id", ""))
		if started:
			for controller in _room.get("controllers", []):
				if controller is Dictionary and (controller.get("seat") == seat or (mode == "1v1" and controller.get("seat") == seat.get_slice(":",0))):
					occupant = tr("WOE_NPC") if controller.get("bot", false) else str(controller.get("controller_id", ""))
		button.text = tr("WOE_" + seat.get_slice(":",0).to_upper()) + " / " + tr("WOE_" + seat.get_slice(":",1).to_upper()) + "\n" + (tr("WOE_EMPTY") if occupant.is_empty() else (occupant if occupant == tr("WOE_NPC") else _display_name(occupant)))
		button.modulate = Color("9ce3ff") if occupant == owner else (Color("ffb4a2") if not occupant.is_empty() else Color.WHITE)
		button.disabled = started or _changing or (not occupant.is_empty() and occupant != owner)
	_start.disabled = started or host != owner or own_seat.is_empty() or _changing
	_invite_button.disabled = _expired or started or host != owner or _changing or _room.get("members", []).size() >= (2 if mode == "1v1" else 4)
	if _invite_button.disabled and is_instance_valid(_invite_popup): _invite_popup.hide()
	if is_instance_valid(_invites): _invites.set_inviting_enabled(not _invite_button.disabled and _room.get("members", []).size() < (2 if mode == "1v1" else 4))
	_fill.disabled = host != owner or started or _changing
	_message.text = tr("WOE_INITIALIZED") if started else tr("WOE_WAITING")
	_resize.call_deferred()

func _display_name(id: String) -> String:
	for member in _room.get("members", []):
		if member is Dictionary and str(member.get("player_id", "")) == id:
			var name := PLAYER_NAMES.clean(member.get("display_name"))
			if not name.is_empty(): return name
	var friend := PLAYER_NAMES.clean(SocialClient.friends.get(id))
	return friend if not friend.is_empty() else tr("INVITE_UNKNOWN_PLAYER")

func _open_invites() -> void:
	if _invite_button.disabled or not _valid(): return
	if is_instance_valid(_invite_popup):
		_invites.refresh_invitations()
		_invite_popup.popup_centered()
		return
	_invite_popup = PopupPanel.new()
	add_child(_invite_popup)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 340)
	_invite_popup.add_child(scroll)
	_invites = preload("res://scripts/ui/minigame_invitations.gd").new()
	_invites.game_kind = "woe"
	_invites.plain_buttons = true
	_invites.room_id = str(_room.get("room_id", ""))
	_invites.can_invite = _room.get("members", []).size() < (2 if _room.get("mode") == "1v1" else 4)
	_invites.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_invites)
	_invite_popup.popup_centered()

func _error(result: Dictionary) -> void:
	var error := str(result.get("error", ""))
	var key := "WOE_ERROR_NETWORK"
	if int(result.get("code", 0)) == 503: key = "WOE_ERROR_DISABLED"
	elif error == "REVISION_CONFLICT": key = "WOE_ERROR_STALE"
	elif error == "PREVIOUS_ROOM_OPEN": key = "PREVIOUS_ROOM_OPEN"
	elif error in ["PLAYER_BUSY", "SEAT_TAKEN"]: key = "WOE_ERROR_BUSY"
	elif error == "ROOM_NOT_FULL": key = "WOE_ERROR_NOT_FULL"
	elif error == "SEAT_REQUIRED": key = "WOE_ERROR_SEAT_REQUIRED"
	elif int(result.get("code", 0)) == 403: key = "WOE_ERROR_HOST"
	elif error == "WOE_RETRY_PENDING": key = "WOE_RETRY_PENDING"
	elif int(result.get("code", 0)) == 404: key = "WOE_ERROR_NOT_FOUND"
	_message.text = tr(key)

func _seat(seat: String) -> void:
	if _room.is_empty(): return
	_action("seat", {"room_id":_room.room_id,"seat":seat,"expected_revision":_room.revision})

func _start_match() -> void:
	if _room.is_empty(): return
	_action("start", {"room_id":_room.room_id,"fill_bots":_fill.button_pressed,"expected_revision":_room.revision})

func _leave_pressed() -> void:
	if _expired:
		SceneRouter.finish_woe()
		return
	if _room.get("status") == "STARTED":
		var confirm := ConfirmationDialog.new()
		confirm.dialog_text = tr("WOE_LEAVE_STARTED_CONFIRM")
		confirm.confirmed.connect(func(): _action("leave", {"room_id":str(SceneRouter._woe_context.room_id)}))
		_canvas.add_child(confirm)
		confirm.popup_centered()
	else:
		_action("leave", {"room_id":str(SceneRouter._woe_context.room_id)})

func _retry() -> void:
	if _changing or WoeClient.saved_pending().is_empty():
		_refresh()
		return
	_changing = true
	var action := str(WoeClient.saved_pending().get("action", ""))
	var result: Dictionary = await WoeClient.retry_pending()
	if not _valid(): return
	_changing = false
	_finish_action(action, result)

func _action(action: String, values: Dictionary) -> void:
	if _changing or not _valid(): return
	_changing = true
	_render()
	var result: Dictionary = await WoeClient.mutate(action, values)
	if not _valid(): return
	_changing = false
	_finish_action(action, result)

func _finish_action(action: String, result: Dictionary) -> void:
	if result.code == 200 and action == "leave":
		SceneRouter.finish_woe()
		return
	if result.code == 200 and WoeClient.valid_room(result.get("data"), str(ConnectionGate.player_id)):
		_room = result.data
		_render()
	else:
		_error(result)
		if result.get("error") == "REVISION_CONFLICT": _refresh()

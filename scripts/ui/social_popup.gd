extends CanvasLayer

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const SocialSpanishFont := preload("res://scripts/ui/social_spanish_font.gd")
var _panel: PanelContainer
var _message: Label
var _status: Label
var _accept: Button
var _decline: Button
var _dismiss: Button
var _retry: Button
var _feedback: PanelContainer
var _feedback_text: Label
var _feedback_retry: Button
var _shown := {}
var _current := ""
var _current_kind := "friend"
var _identity := ""

func _ready() -> void:
	layer = 45
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.offset_top = 24
	_panel.offset_bottom = 180
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.08, 0.97)
	style.border_color = Color("bba66b")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_message)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var row := HBoxContainer.new()
	column.add_child(row)
	_accept = _button(row, "SOCIAL_ACCEPT")
	_decline = _button(row, "SOCIAL_DECLINE")
	_dismiss = _button(row, "SOCIAL_LATER")
	_retry = _button(row, "SOCIAL_RETRY_BUTTON")
	_accept.pressed.connect(func(): _respond_current(true))
	_decline.pressed.connect(func(): _respond_current(false))
	_dismiss.pressed.connect(_dismiss_current)
	_retry.pressed.connect(func(): DuelClient.retry_mutation() if _current_kind == "duel" else SocialClient.retry_mutation())
	_feedback = PanelContainer.new()
	_feedback.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_feedback.offset_left = 500
	_feedback.offset_right = -500
	_feedback.offset_top = -100
	_feedback.offset_bottom = -20
	_feedback.add_theme_stylebox_override("panel", style.duplicate())
	add_child(_feedback)
	var feedback_row := HBoxContainer.new()
	_feedback.add_child(feedback_row)
	_feedback_text = Label.new()
	_feedback_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_row.add_child(_feedback_text)
	_feedback_retry = _button(feedback_row, "SOCIAL_RETRY_BUTTON")
	_feedback_retry.pressed.connect(func(): DuelClient.retry_mutation() if _current_kind == "duel" else SocialClient.retry_mutation())
	_apply_social_fonts()
	_feedback.hide()
	SocialClient.state_changed.connect(_refresh)
	SocialClient.mutation_finished.connect(_mutation_finished)
	DuelClient.state_changed.connect(_refresh)
	DuelClient.mutation_finished.connect(_duel_mutation_finished)
	_panel.hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_social_fonts()

func _apply_social_fonts() -> void:
	SocialSpanishFont.apply(_message, _message.text)
	SocialSpanishFont.apply(_status, _status.text)
	SocialSpanishFont.apply(_dismiss, tr("SOCIAL_LATER"))
	SocialSpanishFont.apply(_feedback_text, _feedback_text.text)

func _button(parent: Control, key: String) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size = Vector2(90, 68)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuArt.button(button)
	parent.add_child(button)
	return button

func _safe_scene() -> bool:
	var scene := get_tree().current_scene
	if not SocialClient.available() or not (SocialClient.enabled or DuelClient.enabled) or not is_instance_valid(scene):
		return false
	if scene.has_method("auth_gate_screen") or scene.scene_file_path.to_lower().contains("loading") or scene.scene_file_path == SceneRouter.SCENE_COMBAT:
		return false
	if scene.scene_file_path == SceneRouter.SCENE_EXPEDITIONS and is_instance_valid(scene.get("combat_view")):
		return false
	return true

func _process(_delta: float) -> void:
	if _identity != SocialClient._identity:
		_identity = SocialClient._identity
		_shown.clear()
		_current = ""
	if not _safe_scene():
		_panel.hide()
		_feedback.hide()
		return
	_feedback.visible = not SocialClient.error_key.is_empty()
	_feedback_text.text = tr(SocialClient.error_key) if _feedback.visible else ""
	SocialSpanishFont.apply(_feedback_text, _feedback_text.text)
	_feedback_retry.visible = not SocialClient._pending_body.is_empty()
	_feedback_retry.disabled = SocialClient._mutation_busy
	if _current.is_empty():
		for request in SocialClient.incoming:
			if not _shown.has(request.request_id):
				_current_kind = "friend"
				_current = request.request_id
				_shown[_current] = true
				break
		if _current.is_empty():
			for invite in DuelClient.incoming:
				if invite is Dictionary and not _shown.has("duel:" + str(invite.get("invite_id", ""))) and int(invite.get("expires_at", 0)) > DuelClient.server_now():
					_current_kind = "duel"
					_current = str(invite.invite_id)
					_shown["duel:" + _current] = true
					break
	_refresh()

func _respond_current(accept: bool) -> void:
	if _current_kind == "duel":
		DuelClient.respond(_current, accept)
	else:
		SocialClient.respond(_current, accept)

func _duel_mutation_finished(success: bool, action: String) -> void:
	if success and action == "respond" and _current_kind == "duel":
		_dismiss_current()

func open_request(request_id: String) -> void:
	if not _current.is_empty() and _current_kind == "duel": return
	if not _safe_scene():
		return
	_current_kind = "friend"
	_current = request_id
	_shown[request_id] = true
	_refresh()

func _dismiss_current() -> void:
	_current = ""
	_panel.hide()

func _mutation_finished(success: bool) -> void:
	if success and SocialClient.last_response_id == _current:
		_dismiss_current()

func _refresh() -> void:
	if not is_instance_valid(_panel) or not _safe_scene() or _current.is_empty():
		if is_instance_valid(_panel): _panel.hide()
		return
	var found := {}
	if _current_kind == "duel":
		for row in DuelClient.incoming:
			if row is Dictionary and row.get("invite_id") == _current:
				found = row
				break
		if found.is_empty() or int(found.get("expires_at", 0)) <= DuelClient.server_now():
			_dismiss_current()
			return
		_message.text = tr("DUEL_CHALLENGE_MESSAGE") % str(found.get("challenger_name", ""))
		_status.text = tr("DUEL_EXPIRES_SECONDS") % maxi(0, ceili(float(int(found.expires_at) - DuelClient.server_now()) / 1000.0))
		SocialSpanishFont.apply(_message, _message.text)
		SocialSpanishFont.apply(_status, _status.text)
		_accept.disabled = DuelClient._mutation_busy or not DuelClient._pending_body.is_empty()
		_decline.disabled = _accept.disabled
		_retry.visible = not DuelClient._pending_body.is_empty()
		_retry.disabled = DuelClient._mutation_busy
		_panel.show()
		return
	for row in SocialClient.incoming:
		if row.request_id == _current:
			found = row
			break
	if found.is_empty():
		_dismiss_current()
		return
	_message.text = tr("SOCIAL_REQUEST_MESSAGE") % str(found.requester_name)
	_status.text = tr(SocialClient.error_key) if not SocialClient.error_key.is_empty() else ""
	SocialSpanishFont.apply(_message, _message.text)
	SocialSpanishFont.apply(_status, _status.text)
	_accept.disabled = SocialClient._mutation_busy or not SocialClient._pending_body.is_empty()
	_decline.disabled = _accept.disabled
	_retry.visible = not SocialClient._pending_body.is_empty()
	_retry.disabled = SocialClient._mutation_busy
	_panel.show()

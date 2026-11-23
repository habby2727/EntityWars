extends CanvasLayer

const MenuArt := preload("res://scripts/ui/menu_art.gd")
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
	_accept.pressed.connect(func(): SocialClient.respond(_current, true))
	_decline.pressed.connect(func(): SocialClient.respond(_current, false))
	_dismiss.pressed.connect(_dismiss_current)
	_retry.pressed.connect(func(): SocialClient.retry_mutation())
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
	_feedback_retry.pressed.connect(func(): SocialClient.retry_mutation())
	_feedback.hide()
	SocialClient.state_changed.connect(_refresh)
	SocialClient.mutation_finished.connect(_mutation_finished)
	_panel.hide()

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
	if not SocialClient.available() or not SocialClient.enabled or not is_instance_valid(scene):
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
	_feedback_retry.visible = not SocialClient._pending_body.is_empty()
	_feedback_retry.disabled = SocialClient._mutation_busy
	if _current.is_empty():
		for request in SocialClient.incoming:
			if not _shown.has(request.request_id):
				_current = request.request_id
				_shown[_current] = true
				break
	_refresh()

func open_request(request_id: String) -> void:
	if not _safe_scene():
		return
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
	for row in SocialClient.incoming:
		if row.request_id == _current:
			found = row
			break
	if found.is_empty():
		_dismiss_current()
		return
	_message.text = tr("SOCIAL_REQUEST_MESSAGE") % str(found.requester_name)
	_status.text = tr(SocialClient.error_key) if not SocialClient.error_key.is_empty() else ""
	_accept.disabled = SocialClient._mutation_busy or not SocialClient._pending_body.is_empty()
	_decline.disabled = _accept.disabled
	_retry.visible = not SocialClient._pending_body.is_empty()
	_retry.disabled = SocialClient._mutation_busy
	_panel.show()

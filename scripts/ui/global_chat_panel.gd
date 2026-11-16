extends CanvasLayer

var _button: Button
var _badge: Label
var _online: Label
var _panel: PanelContainer
var _scroll: ScrollContainer
var _log: RichTextLabel
var _input: LineEdit
var _send_button: Button
var _status: Label

func _ready() -> void:
	layer = 40
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	var toggle_row := HBoxContainer.new()
	toggle_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_row.offset_left = -190
	toggle_row.offset_top = -55
	toggle_row.offset_right = -15
	toggle_row.offset_bottom = -15
	anchor.add_child(toggle_row)
	_online = Label.new()
	toggle_row.add_child(_online)
	_badge = Label.new()
	_badge.text = "!"
	_badge.add_theme_color_override("font_color", Color.YELLOW)
	toggle_row.add_child(_badge)
	_button = Button.new()
	_button.text = "💬"
	_button.custom_minimum_size = Vector2(44, 36)
	_button.pressed.connect(_open)
	toggle_row.add_child(_button)
	# The project typography applies deferred; use the platform emoji font for this glyph.
	_set_emoji_font.call_deferred()
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left = -365
	_panel.offset_top = -255
	_panel.offset_right = -15
	_panel.offset_bottom = -15
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.85)
	background.content_margin_left = 8
	background.content_margin_right = 8
	background.content_margin_top = 5
	background.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", background)
	anchor.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "💬"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = tr("CHAT_CLOSE")
	close.pressed.connect(_close)
	header.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.fit_content = true
	_log.scroll_active = false
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll.add_child(_log)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	column.add_child(_status)
	var row := HBoxContainer.new()
	column.add_child(row)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_text: String): _submit())
	row.add_child(_input)
	_send_button = Button.new()
	_send_button.pressed.connect(_submit)
	row.add_child(_send_button)
	GlobalChatClient.updated.connect(_refresh)
	GlobalChatClient.send_finished.connect(_send_finished)
	_panel.hide()
	_refresh()

func _exit_tree() -> void:
	GlobalChatClient.set_panel_open(false)

func _set_emoji_font() -> void:
	if not is_instance_valid(_button):
		return
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"])
	_button.add_theme_font_override("font", font)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()

func _open() -> void:
	_panel.show()
	GlobalChatClient.set_panel_open(true)
	_input.grab_focus()

func _close() -> void:
	_panel.hide()
	GlobalChatClient.set_panel_open(false)

func _submit() -> void:
	GlobalChatClient.send_message(_input.text)

func _send_finished(success: bool) -> void:
	if success:
		_input.clear()

func _refresh() -> void:
	if not is_instance_valid(_log):
		return
	_online.text = "%s: %d" % [tr("CHAT_ONLINE"), GlobalChatClient.online_count]
	_badge.visible = GlobalChatClient.unread
	_button.visible = not _panel.visible
	_online.visible = not _panel.visible
	_badge.visible = GlobalChatClient.unread and not _panel.visible
	_send_button.text = tr("CHAT_SEND")
	_input.placeholder_text = tr("CHAT_PLACEHOLDER")
	var key: String = GlobalChatClient.error_key
	_status.text = tr("CHAT_UNAVAILABLE") if not GlobalChatClient.available() else (tr(key) if not key.is_empty() else "")
	_send_button.disabled = not GlobalChatClient.available()
	var bar := _scroll.get_v_scroll_bar()
	var was_bottom := bar.value >= bar.max_value - bar.page - 2.0
	var old_scroll := _scroll.scroll_vertical
	_log.clear()
	for entry in GlobalChatClient.messages:
		if not entry is Dictionary:
			continue
		_log.push_color(Color.RED)
		_log.add_text(str(entry.get("username", "")) + ": ")
		_log.pop()
		_log.push_color(Color.WHITE)
		_log.add_text(str(entry.get("text", "")) + "\n")
		_log.pop()
	_restore_scroll.call_deferred(was_bottom, old_scroll)

func _restore_scroll(at_bottom: bool, old_scroll: int) -> void:
	if not is_instance_valid(_scroll):
		return
	if at_bottom:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	else:
		_scroll.scroll_vertical = old_scroll

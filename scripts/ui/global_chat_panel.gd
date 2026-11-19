extends CanvasLayer

const MenuArt = preload("res://scripts/ui/menu_art.gd")
const DISCORD_INVITE := "https://discord.gg/W2mrgZ69r9"

var _button: Button
var _badge: Label
var _online: Button
var _header_online: Label
var _online_panel: PanelContainer
var _online_list: VBoxContainer
var _online_scroll: ScrollContainer
var _panel: PanelContainer
var _scroll: ScrollContainer
var _log: RichTextLabel
var _input: LineEdit
var _send_button: Button
var _status: Label
var _toggle_row: HBoxContainer
var _disclosure: Label
var _keyboard_height := -1

func _android_ui() -> bool:
	return OS.has_feature("android") or (OS.is_debug_build() and OS.get_environment("UI_ANDROID_PREVIEW") == "1")

func _process(_delta: float) -> void:
	if OS.has_feature("android"):
		var height := DisplayServer.virtual_keyboard_get_height()
		if height != _keyboard_height:
			_keyboard_height = height
			_resize_to_viewport()

func _ready() -> void:
	layer = 40
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	var toggle_row := HBoxContainer.new()
	_toggle_row = toggle_row
	toggle_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_row.offset_left = -277.5
	toggle_row.offset_top = -75
	toggle_row.offset_right = -15
	toggle_row.offset_bottom = -15
	anchor.add_child(toggle_row)
	_online = Button.new()
	_online.custom_minimum_size = Vector2(100, 54)
	_online.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online.add_theme_font_size_override("font_size", 14)
	MenuArt.button(_online)
	_online.pressed.connect(_toggle_online)
	toggle_row.add_child(_online)
	_badge = Label.new()
	_badge.text = "!"
	_badge.add_theme_font_size_override("font_size", 18)
	_badge.add_theme_color_override("font_color", Color.YELLOW)
	toggle_row.add_child(_badge)
	_button = Button.new()
	_button.text = "💬 Chat"
	_button.custom_minimum_size = Vector2(90, 54)
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button.add_theme_font_size_override("font_size", 14)
	MenuArt.button(_button)
	_button.pressed.connect(_open)
	toggle_row.add_child(_button)
	# The project typography applies deferred; use the platform emoji font for this glyph.
	_set_emoji_font.call_deferred()
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left = -540
	_panel.offset_top = -375
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
	_online_panel = PanelContainer.new()
	_online_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_online_panel.offset_right = -15
	_online_panel.offset_bottom = -80
	_online_panel.add_theme_stylebox_override("panel", background.duplicate())
	anchor.add_child(_online_panel)
	var online_column := VBoxContainer.new()
	_online_panel.add_child(online_column)
	var online_header := HBoxContainer.new()
	online_column.add_child(online_header)
	var online_title := Label.new()
	online_title.text = tr("CHAT_ONLINE")
	online_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_header.add_child(online_title)
	var online_close := Button.new()
	online_close.text = "×"
	online_close.custom_minimum_size = Vector2(40, 40)
	online_close.add_theme_font_size_override("font_size", 28)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		online_close.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	online_close.pressed.connect(func(): _online_panel.hide())
	online_header.add_child(online_close)
	var online_scroll := ScrollContainer.new()
	_online_scroll = online_scroll
	online_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	online_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	online_column.add_child(online_scroll)
	_online_list = VBoxContainer.new()
	_online_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_scroll.add_child(_online_list)
	_online_panel.hide()
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_disclosure = Label.new()
	_disclosure.add_theme_font_size_override("font_size", 14)
	_disclosure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_disclosure)
	var title := Label.new()
	title.text = "Chat"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_header_online = Label.new()
	_header_online.add_theme_font_size_override("font_size", 18)
	header.add_child(_header_online)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(64, 64)
	close.add_theme_font_size_override("font_size", 36)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		close.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close.tooltip_text = tr("CHAT_CLOSE")
	close.pressed.connect(_close)
	header.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.meta_clicked.connect(_discord_link_clicked)
	_log.add_theme_font_size_override("normal_font_size", 22)
	_log.fit_content = true
	_log.scroll_active = false
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll.add_child(_log)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	column.add_child(_status)
	var row := HBoxContainer.new()
	column.add_child(row)
	_input = LineEdit.new()
	_input.add_theme_font_size_override("font_size", 22)
	_input.custom_minimum_size.y = 48
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_text: String): _submit())
	row.add_child(_input)
	if _android_ui():
		_input.custom_minimum_size.y = maxf(_input.custom_minimum_size.y, GameTypography.touch_size(_input))
	_send_button = Button.new()
	_send_button.add_theme_font_size_override("font_size", 22)
	_send_button.pressed.connect(_submit)
	row.add_child(_send_button)
	GlobalChatClient.updated.connect(_refresh)
	GlobalChatClient.send_finished.connect(_send_finished)
	_panel.hide()
	get_viewport().size_changed.connect(_resize_to_viewport)
	_resize_to_viewport()
	_refresh()

func _resize_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if _android_ui():
		var target := GameTypography.touch_size(_button)
		var keyboard := 0.0
		if OS.has_feature("android") and _keyboard_height > 0:
			keyboard = float(_keyboard_height) / maxf(0.01, get_viewport().get_screen_transform().get_scale().y)
		keyboard = clampf(keyboard, 0.0, viewport_size.y * 0.65)
		_panel.offset_bottom = -15.0 - keyboard
		_toggle_row.offset_top = -target - 15.0
		_toggle_row.offset_left = -minf(maxf(360.0, target * 3.0), viewport_size.x - 30.0) - 15.0
		_panel.offset_left = -minf(maxf(viewport_size.x * 0.48, target * 5.0), viewport_size.x - 30.0) - 15.0
		_panel.offset_top = _panel.offset_bottom - minf(maxf(viewport_size.y * 0.72, target * 5.0), viewport_size.y - keyboard - 30.0)
		_online_panel.offset_bottom = -target - 30.0
		_online_panel.offset_left = -minf(maxf(400.0, target * 3.0), viewport_size.x - 30.0) - 15.0
		_online_panel.offset_top = -minf(560.0, maxf(0.0, viewport_size.y - target - 45.0)) - target - 30.0
		return
	_panel.offset_left = -minf(525.0, maxf(0.0, viewport_size.x - 30.0)) - 15.0
	_panel.offset_top = -minf(360.0, maxf(0.0, viewport_size.y - 30.0)) - 15.0
	_toggle_row.offset_left = -minf(262.5, maxf(0.0, viewport_size.x - 30.0)) - 15.0
	_online_panel.offset_left = -minf(300.0, maxf(0.0, viewport_size.x - 30.0)) - 15.0
	_online_panel.offset_top = -minf(360.0, maxf(0.0, viewport_size.y - 95.0)) - 80.0

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
	_online_panel.hide()
	_panel.show()
	GlobalChatClient.set_panel_open(true)
	_input.grab_focus()

func _close() -> void:
	_panel.hide()
	GlobalChatClient.set_panel_open(false)

func _toggle_online() -> void:
	_online_panel.visible = not _online_panel.visible
	if _online_panel.visible:
		_refresh_online_list()

func _league_icon(league: String) -> Texture2D:
	var name := league.to_lower()
	if name not in ["copper", "quartz", "amethyst", "obsidian"]:
		return null
	var path := "res://assets/ui/pvp/league_icons_128x128/%s_league.png" % name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _refresh_online_list() -> void:
	var old_scroll := _online_scroll.scroll_vertical
	for child in _online_list.get_children():
		_online_list.remove_child(child)
		child.queue_free()
	for player in GlobalChatClient.online_players:
		if not player is Dictionary:
			continue
		var row := HBoxContainer.new()
		_online_list.add_child(row)
		var texture := _league_icon(str(player.get("league", "")))
		if texture != null:
			var icon := TextureRect.new()
			icon.texture = texture
			icon.custom_minimum_size = Vector2(32, 32)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
		var username := Label.new()
		username.text = str(player.get("username", ""))
		username.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		username.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(username)
	_restore_online_scroll.call_deferred(old_scroll)

func _restore_online_scroll(value: int) -> void:
	if is_instance_valid(_online_scroll):
		_online_scroll.scroll_vertical = value

func _submit() -> void:
	GlobalChatClient.send_message(_input.text)

func _discord_link_clicked(meta: Variant) -> void:
	if str(meta) == "discord_invite":
		OS.shell_open(DISCORD_INVITE)

func _send_finished(success: bool) -> void:
	if success:
		_input.clear()

func _refresh() -> void:
	if not is_instance_valid(_log):
		return
	_online.text = "%s: %d" % [tr("CHAT_ONLINE"), GlobalChatClient.online_count]
	_header_online.text = _online.text
	if _online_panel.visible:
		_refresh_online_list()
	_badge.visible = GlobalChatClient.unread
	_button.visible = not _panel.visible
	_online.visible = not _panel.visible
	_badge.visible = GlobalChatClient.unread and not _panel.visible
	_send_button.text = tr("CHAT_SEND")
	_disclosure.text = tr("CHAT_DISCORD_DISCLOSURE")
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
		var icon := _league_icon(str(entry.get("league", "")))
		if icon != null:
			_log.add_image(icon, 24, 24)
			_log.add_text(" ")
		var username := str(entry.get("username", ""))
		if entry.get("source", "") == "discord" and username.begins_with("[Discord] "):
			_log.push_color(Color("7289da"))
			_log.push_meta("discord_invite")
			_log.add_text("[Discord]")
			_log.pop()
			_log.add_text(username.substr(9) + ": ")
		else:
			_log.push_color(Color.RED)
			_log.add_text(username + ": ")
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

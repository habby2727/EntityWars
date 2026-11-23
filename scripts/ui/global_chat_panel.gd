extends CanvasLayer

const MenuArt = preload("res://scripts/ui/menu_art.gd")
const SocialGlyph = preload("res://scripts/ui/social_glyph.gd")
const SocialSpanishFont = preload("res://scripts/ui/social_spanish_font.gd")
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
	_send_button = Button.new()
	_send_button.add_theme_font_size_override("font_size", 22)
	_send_button.pressed.connect(_submit)
	row.add_child(_send_button)
	GlobalChatClient.updated.connect(_refresh)
	GlobalChatClient.send_finished.connect(_send_finished)
	SocialClient.state_changed.connect(_refresh_social)
	_panel.hide()
	get_viewport().size_changed.connect(_resize_to_viewport)
	_resize_to_viewport()
	_refresh()

func _resize_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
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
	if SocialClient.enabled:
		if not SocialClient.error_key.is_empty():
			var status := Label.new()
			status.text = tr(SocialClient.error_key)
			status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_online_list.add_child(status)
			SocialSpanishFont.apply(status, status.text)
		if not SocialClient._pending_body.is_empty():
			var retry := Button.new()
			retry.text = tr("SOCIAL_RETRY_BUTTON")
			retry.custom_minimum_size.y = 68
			retry.disabled = SocialClient._mutation_busy
			retry.pressed.connect(func(): SocialClient.retry_mutation())
			_online_list.add_child(retry)
		if not SocialClient.incoming.is_empty():
			var heading := Label.new()
			heading.text = tr("SOCIAL_INCOMING")
			_online_list.add_child(heading)
			for request in SocialClient.incoming:
				var request_button := Button.new()
				request_button.text = str(request.requester_name) + " · " + tr("SOCIAL_REVIEW")
				request_button.custom_minimum_size.y = 68
				request_button.pressed.connect(SocialClient._popup.open_request.bind(str(request.request_id)))
				_online_list.add_child(request_button)
				SocialSpanishFont.apply(request_button, request_button.text)
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
		if SocialClient.enabled and bool(player.get("is_friend", false)):
			var glyph := SocialGlyph.new()
			glyph.custom_minimum_size = Vector2(24, 24)
			row.add_child(glyph)
		var username := Label.new()
		username.text = str(player.get("username", ""))
		username.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		username.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(username)
		var player_id := str(player.get("player_id", ""))
		if SocialClient.enabled and not player_id.is_empty() and player_id != ConnectionGate.player_id and not bool(player.get("is_friend", false)) and not SocialClient.friends.has(player_id):
			var action := Button.new()
			action.custom_minimum_size = Vector2(72, 68)
			action.disabled = SocialClient._mutation_busy or not SocialClient._pending_body.is_empty()
			var incoming := SocialClient.incoming_for(player_id)
			var outgoing := SocialClient.outgoing_for(player_id)
			if not incoming.is_empty():
				action.text = tr("SOCIAL_REVIEW")
				action.pressed.connect(SocialClient._popup.open_request.bind(str(incoming.request_id)))
			elif not outgoing.is_empty():
				action.text = tr("SOCIAL_PENDING")
				action.tooltip_text = tr("SOCIAL_CANCEL")
				action.pressed.connect(SocialClient.cancel.bind(str(outgoing.request_id)))
			else:
				action.text = "+"
				action.tooltip_text = tr("SOCIAL_ADD")
				action.pressed.connect(SocialClient.request_friend.bind(player_id))
			row.add_child(action)
	_restore_online_scroll.call_deferred(old_scroll)

func _refresh_social() -> void:
	if is_instance_valid(_online_panel) and _online_panel.visible:
		_refresh_online_list()

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
			_log.push_color(Color("e5c76d") if entry.get("source", "") == "system" else Color.RED)
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

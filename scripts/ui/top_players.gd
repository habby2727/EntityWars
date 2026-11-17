extends Control

const Art = preload("res://scripts/ui/menu_art.gd")
const GOLD := Color("e7c980")
const CYAN := Color("92d8dc")
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
var backend: BackendClient
var request_id := ""
var showing_previous := false
var requested_previous := false
var data := {}
var cards: VBoxContainer
var personal: HBoxContainer
var global_rows: VBoxContainer
var division_rows: VBoxContainer
var season_label: Label
var footer_label: Label
var status: Label
var toggle: Button

func _ready() -> void:
	_build_ui()
	backend = BackendClient.new()
	backend.auto_dev_login = false
	backend.state_updated.connect(_on_identity)
	backend.auth_changed.connect(_on_auth_changed)
	backend.api_completed.connect(_on_response)
	add_child(backend)
	if backend.token.is_empty():
		status.text = "Sign in to view rankings."
	else:
		status.text = "Loading rankings..."
		get_tree().create_timer(12.0).timeout.connect(_identity_timeout)

func _identity_timeout() -> void:
	if is_instance_valid(backend) and backend._verified_player_id.is_empty():
		status.text = "Unable to connect. Return and try again."

func _on_identity(state: Dictionary) -> void:
	if not state.is_empty() and request_id.is_empty() and data.is_empty():
		_request(false)

func _on_auth_changed(_token: String) -> void:
	request_id = ""
	data.clear()
	toggle.disabled = false
	status.text = "Sign in to view rankings."

func _request(previous: bool) -> void:
	if not request_id.is_empty():
		return
	var path := "/pvp/leaderboard"
	if previous:
		var season := str(data.get("previous_season", ""))
		if season.is_empty():
			return
		path += "?season=" + season.uri_encode()
	requested_previous = previous
	request_id = backend.request_api("GET", path, null)
	if request_id.is_empty():
		status.text = "Connection unavailable. Return and try again."
		return
	toggle.disabled = true
	status.text = "Loading rankings..."

func _on_response(id: String, ok: bool, response: Dictionary) -> void:
	if id != request_id:
		return
	request_id = ""
	toggle.disabled = false
	if not ok:
		var error := str(response.get("error", ""))
		status.text = "Ranked is currently unavailable." if error == "PVP_DISABLED" else "Could not load rankings. Please try again."
		return
	data = response
	showing_previous = requested_previous
	toggle.text = "Current Season" if showing_previous else "Previous Season"
	status.text = ""
	_render()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var outer_scroll := ScrollContainer.new()
	outer_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(outer_scroll)
	var outer := VBoxContainer.new()
	outer.custom_minimum_size.x = 1500
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	outer_scroll.add_child(outer)
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(top_bar)
	var back := Button.new()
	back.text = "Close"
	back.custom_minimum_size = Vector2(180, 64)
	Art.button(back)
	top_bar.add_child(back)
	back.pressed.connect(SceneRouter.go_to_loadout)
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	outer.add_child(main)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 340
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.27
	main.add_child(left)
	var leagues_title := _backed_label("Leagues & Divisions", 28, GOLD)
	leagues_title.size_flags_horizontal = Control.SIZE_SHRINK_END
	left.add_child(leagues_title)
	var card_scroll := _scroll()
	left.add_child(card_scroll)
	cards = VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(cards)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 1100
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.73
	right.add_theme_constant_override("separation", 8)
	main.add_child(right)
	var head := _panel(Vector4(12, 8, 12, 8))
	head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(head)
	var head_box := VBoxContainer.new()
	head_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_box)
	head_box.add_child(_label("TOP PLAYERS", 36, GOLD))
	personal = HBoxContainer.new()
	head_box.add_child(personal)
	status = _label("Loading rankings...", 18, CYAN)
	head_box.add_child(status)
	var tables := HBoxContainer.new()
	tables.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tables.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tables.add_theme_constant_override("separation", 10)
	right.add_child(tables)
	var global_box := _table(tables, "Global Top 10")
	var global_header := HBoxContainer.new()
	global_box.add_child(global_header)
	var season_background := _panel(Vector4(8, 4, 8, 4))
	season_background.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	global_header.add_child(season_background)
	season_label = _label("", 19, CYAN)
	season_background.add_child(season_label)
	toggle = Button.new()
	toggle.text = "Previous Season"
	toggle.disabled = true
	Art.button(toggle)
	global_header.add_child(toggle)
	toggle.pressed.connect(func(): _request(not showing_previous))
	global_box.add_child(_backed_label("RANK    PLAYER                         LEAGUE / DIVISION      MP", 14, GOLD))
	global_rows = _table_rows(global_box)
	var division_box := _table(tables, "Top 10 of Your Division")
	division_box.add_child(_backed_label("RANK     PLAYER                                                MP", 14, GOLD))
	division_rows = _table_rows(division_box)
	var footer := HBoxContainer.new()
	outer.add_child(footer)
	var footer_background := _panel(Vector4(8, 4, 8, 4))
	footer_background.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	footer.add_child(footer_background)
	footer_label = _label("", 18, CYAN)
	footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_background.add_child(footer_label)

func _panel(padding: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.62)
	background.content_margin_left = padding.x
	background.content_margin_top = padding.y
	background.content_margin_right = padding.z
	background.content_margin_bottom = padding.w
	panel.add_theme_stylebox_override("panel", background)
	return panel

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

func _backed_label(value: String, font_size: int, color: Color) -> PanelContainer:
	var background := _panel(Vector4(8, 4, 8, 4))
	background.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	background.add_child(_label(value, font_size, color))
	return background

func _scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll

func _table(parent: Control, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	box.add_child(_backed_label(title, 25, GOLD))
	return box

func _table_rows(box: VBoxContainer) -> VBoxContainer:
	var scroll := _scroll()
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	return rows

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _icon(league: String, pixels: int, display_size: int) -> Control:
	var path := "res://assets/ui/pvp/league_icons_%dx%d/%s_league.png" % [pixels, pixels, league.to_lower()]
	if ResourceLoader.exists(path):
		var icon := TextureRect.new()
		icon.texture = load(path)
		icon.custom_minimum_size = Vector2(display_size, display_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return icon
	var badge := _label(league, 15, GOLD)
	badge.custom_minimum_size.x = display_size
	return badge

func _render() -> void:
	_clear(cards)
	var thresholds: Array = data.get("thresholds", [])
	for league in ["Obsidian", "Amethyst", "Quartz", "Copper"]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_theme_constant_override("separation", 8)
		cards.add_child(row)
		row.add_child(_icon(league, 256, 85))
		var text_background := _panel(Vector4(8, 4, 8, 4))
		row.add_child(text_background)
		var details := VBoxContainer.new()
		text_background.add_child(details)
		details.add_child(_label(league.to_upper(), 21, GOLD))
		for division in ["I", "II", "III", "IV"]:
			for threshold in thresholds:
				if threshold is Dictionary and threshold.get("league") == league and threshold.get("division") == division:
					var suffix := "+" if league == "Obsidian" and division == "I" else ""
					details.add_child(_label("%s   %d%s MP" % [division, int(threshold.get("minimum", 0)), suffix], 16, Color.WHITE))
	var note := _backed_label("Below 1000 MP remains Copper IV", 15, CYAN)
	note.size_flags_horizontal = Control.SIZE_SHRINK_END
	cards.add_child(note)
	_clear(personal)
	var player: Dictionary = data.get("player", {})
	personal.add_child(_icon(str(player.get("league", "")), 256, 110))
	var summary := VBoxContainer.new()
	summary.custom_minimum_size.x = 500
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	personal.add_child(summary)
	summary.add_child(_label("%s %s   ·   %d MP" % [player.get("league", ""), player.get("division", ""), int(player.get("mp", 0))], 25, GOLD))
	summary.add_child(_label("Global rank #%d   ·   Division rank #%d" % [int(player.get("global_rank", 0)), int(player.get("division_rank", 0))], 20, CYAN))
	season_label.text = _month(str(data.get("view_season", "")))
	var current := str(data.get("season", ""))
	footer_label.text = "Current UTC season: %s    ·    Next reset: %s 1, %s UTC" % [_month(current), MONTHS[int(current.substr(5, 2)) % 12] if current.length() == 7 else "", str(int(current.substr(0, 4)) + (1 if current.ends_with("12") else 0)) if current.length() == 7 else ""]
	_render_rows(global_rows, data.get("global_top_10", []), true)
	_render_rows(division_rows, data.get("division_top_10", []), false)

func _month(season: String) -> String:
	if season.length() != 7:
		return season
	var month := int(season.substr(5, 2))
	return "%s %s" % [MONTHS[month - 1], season.substr(0, 4)] if month >= 1 and month <= 12 else season

func _render_rows(container: VBoxContainer, rows: Array, global: bool) -> void:
	_clear(container)
	if rows.is_empty():
		container.add_child(_backed_label("No rankings from this season" if global else "No rankings in your division", 19, CYAN))
		return
	for entry in rows:
		if not entry is Dictionary:
			continue
		var viewer := str(entry.get("player_id", "")) == backend._verified_player_id
		var panel := _panel(Vector4(8, 4, 8, 4))
		if viewer:
			panel.modulate = Color(1.2, 1.1, 0.78)
		container.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var rank := int(entry.get("rank", 0))
		var rank_color := GOLD if rank == 1 else (Color("c8d0d6") if rank == 2 else (Color("c58f68") if rank == 3 else Color.WHITE))
		var rank_label := _label("#%d" % rank, 18, rank_color)
		rank_label.custom_minimum_size.x = 40
		row.add_child(rank_label)
		row.add_child(_icon(str(entry.get("league", "")), 128, 40))
		var name_label := _label(str(entry.get("display_name", "")), 18, GOLD if viewer else Color.WHITE)
		name_label.custom_minimum_size.x = 120
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		row.add_child(name_label)
		if global:
			var league_label := _label("%s %s" % [entry.get("league", ""), entry.get("division", "")], 16, CYAN)
			league_label.custom_minimum_size.x = 110
			row.add_child(league_label)
		var mp_label := _label("%d MP" % int(entry.get("mp", 0)), 18, GOLD)
		mp_label.custom_minimum_size.x = 80
		row.add_child(mp_label)

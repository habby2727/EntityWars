extends PanelContainer

const MENU_ART := preload("res://scripts/ui/menu_art.gd")
var _identity := ""
var _generation := 0
var _mode := "solo"
var _month := "current"
var _status: Label
var _rows: VBoxContainer
var _current: Button
var _previous: Button
var _retry: Button
var _mode_buttons := {}
var _closing := false
var _requests := 0

func _ready() -> void:
	_identity = CoreDefenseClient.identity()
	add_theme_stylebox_override("panel", MENU_ART.frame("marco-horizontal-popup-grande.png", Vector4(22, 22, 22, 22)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = tr("CD_TOP_PLAYERS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var modes := HBoxContainer.new()
	box.add_child(modes)
	for choice in [["CD_SOLO", "solo"], ["CD_COOP", "coop"]]:
		var button := _button(tr(choice[0]))
		modes.add_child(button)
		_mode_buttons[choice[1]] = button
		button.pressed.connect(_set_mode.bind(choice[1]))
	var months := HBoxContainer.new()
	box.add_child(months)
	_current = _button(tr("CD_CURRENT_MONTH"))
	_previous = _button(tr("CD_PREVIOUS_MONTH"))
	months.add_child(_current)
	months.add_child(_previous)
	_current.pressed.connect(_set_month.bind("current"))
	_previous.pressed.connect(_set_month.bind("previous"))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var header := Label.new()
	header.text = tr("CD_RANKING_HEADER")
	box.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 55
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_retry = _button(tr("WOE_RETRY"))
	actions.add_child(_retry)
	_retry.pressed.connect(_fetch)
	var close := _button(tr("FOREST_CLOSE"))
	actions.add_child(close)
	close.pressed.connect(_close)
	_fetch()

func _button(caption: String) -> Button:
	var button := Button.new()
	MENU_ART.button(button)
	button.text = caption
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _process(_delta: float) -> void:
	if _identity != CoreDefenseClient.identity(): _close()

func _close() -> void:
	if _closing: return
	_closing = true
	_generation += 1
	hide()
	if _requests == 0: queue_free()

func _set_mode(value: String) -> void:
	_mode = value
	_fetch()

func _set_month(value: String) -> void:
	_month = value
	_fetch()

func _fetch() -> void:
	_generation += 1
	for key in _mode_buttons: _mode_buttons[key].disabled = key == _mode
	_current.disabled = _month == "current"
	_previous.disabled = _month == "previous"
	var request_generation := _generation
	var requested_mode := _mode
	var requested_month := _month
	for child in _rows.get_children(): child.queue_free()
	_status.text = tr("CD_RANKING_LOADING")
	_retry.disabled = true
	if not CoreDefenseClient.available():
		_status.text = tr("CD_UNAVAILABLE")
		_retry.disabled = false
		return
	_requests += 1
	var result: Dictionary = await CoreDefenseClient.request("/forest/core-defense/leaderboard?mode=" + requested_mode + "&month=" + requested_month, null, self)
	_requests -= 1
	if _closing:
		if _requests == 0: queue_free()
		return
	if not is_inside_tree() or is_queued_for_deletion() or request_generation != _generation or _identity != CoreDefenseClient.identity(): return
	_retry.disabled = false
	if result.get("code") != 200 or not result.get("data") is Dictionary or not result.data.get("entries") is Array or result.data.get("mode") != requested_mode or not result.data.get("current_month") is String or not result.data.get("previous_month") is String or result.data.get("viewed_month") != result.data.get("current_month" if requested_month == "current" else "previous_month"):
		_status.text = tr("CD_UNAVAILABLE")
		return
	_current.text = str(result.data.get("current_month", ""))
	_previous.text = str(result.data.get("previous_month", ""))
	_status.text = tr("CD_RANKING_EMPTY") if result.data.entries.is_empty() else ""
	var position := 0
	for entry in result.data.entries:
		if not entry is Dictionary: continue
		position += 1
		var row := HBoxContainer.new()
		var rank := Label.new()
		rank.custom_minimum_size.x = 48
		rank.text = "%d." % position
		row.add_child(rank)
		var player_name := Label.new()
		player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_name.clip_text = true
		player_name.text = str(entry.get("display_name", ""))
		row.add_child(player_name)
		var wave := Label.new()
		wave.custom_minimum_size.x = 48
		wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		wave.text = str(int(entry.get("completed_waves", 0)))
		row.add_child(wave)
		_rows.add_child(row)

extends PanelContainer

const MENU_ART := preload("res://scripts/ui/menu_art.gd")

signal admitted(room: Dictionary)
var _identity := ""
var _busy := false
var _status: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", MENU_ART.frame("marco-horizontal-popup-grande.png", Vector4(28, 28, 28, 28)))
	_identity = CoreDefenseClient.identity()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = tr("CD_TITLE")
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	for choice in [["CD_SOLO", "solo"], ["CD_COOP", "coop"]]:
		var button := Button.new()
		MENU_ART.button(button)
		button.text = tr(choice[0])
		button.custom_minimum_size.y = 48
		button.pressed.connect(_create.bind(choice[1]))
		box.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var invites = preload("res://scripts/ui/minigame_invitations.gd").new()
	invites.name = "Invitations"
	invites.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(invites)
	invites.admitted.connect(_verified)
	var retry := Button.new()
	MENU_ART.button(retry)
	retry.text = tr("WOE_RETRY")
	retry.pressed.connect(_recover)
	box.add_child(retry)
	var close := Button.new()
	MENU_ART.button(close)
	close.text = tr("FOREST_CLOSE")
	close.pressed.connect(queue_free)
	box.add_child(close)
	_recover()

func _process(_delta: float) -> void:
	if _identity != CoreDefenseClient.identity(): queue_free()

func _valid() -> bool:
	return is_inside_tree() and _identity == CoreDefenseClient.identity()

func _create(mode: String) -> void:
	if _busy: return
	_busy = true
	var result: Dictionary = await CoreDefenseClient.mutate("create", {"mode":mode})
	if not _valid(): return
	_busy = false
	await _complete(result)

func _recover() -> void:
	if _busy or not _valid(): return
	# Inspect journals before replaying them: terminal states obsolete only their own actions.
	var journal_ids: Array[String] = []
	for item in [CoreDefenseClient.saved_pending(), CoreDefenseClient.saved_forfeit_action()]:
		var id := str(item.get("values", {}).get("match_id", ""))
		if not id.is_empty() and id not in journal_ids: journal_ids.append(id)
	for id in journal_ids:
		_busy = true
		var state: Dictionary = await CoreDefenseClient.request("/forest/core-defense/match/state?match_id=" + id.uri_encode() + "&after=0", null, self)
		if not _valid(): return
		_busy = false
		if state.code != 200 or not CoreDefenseClient.valid_match(state.get("data"), str(ConnectionGate.player_id)) or str(state.data.match_id) != id:
			_status.text = tr("WOE_RETRY_PENDING")
			return
		if state.data.status == "FINISHED":
			if not CoreDefenseClient.reconcile_terminal(state.data):
				_status.text = tr("WOE_RETRY_PENDING")
				return
		else:
			# Arena retry logic is restricted to the authenticated current match.
			_busy = true
			var live: Dictionary = await CoreDefenseClient.request("/forest/core-defense/match/current", null, self)
			if not _valid(): return
			_busy = false
			if live.code == 200 and CoreDefenseClient.valid_match(live.get("data"), str(ConnectionGate.player_id)) and live.data.status == "RUNNING" and str(live.data.match_id) == id:
				admitted.emit(live.data)
			else: _status.text = tr("WOE_RETRY_PENDING")
			return
	if not CoreDefenseClient.saved_forfeit_action().is_empty():
		_busy = true
		var forfeited: Dictionary = await CoreDefenseClient.retry_forfeit()
		if not _valid(): return
		_busy = false
		if int(forfeited.get("code", 0)) == 0 or int(forfeited.get("code", 0)) >= 500 or int(forfeited.get("code", 0)) == 429:
			_status.text = tr("WOE_RETRY_PENDING")
			return
	if not CoreDefenseClient.saved_pending().is_empty():
		_busy = true
		var result: Dictionary = await CoreDefenseClient.retry_pending()
		if not _valid(): return
		_busy = false
		if int(result.get("code", 0)) == 0 or int(result.get("code", 0)) >= 500 or int(result.get("code", 0)) == 429:
			_status.text = tr("WOE_RETRY_PENDING")
			return
		if CoreDefenseClient.valid_room(result.get("data"), str(ConnectionGate.player_id)):
			await _complete(result)
			return
	_busy = true
	var current: Dictionary = await CoreDefenseClient.request("/forest/core-defense/match/current", null, self)
	if not _valid(): return
	_busy = false
	if current.code == 200 and CoreDefenseClient.valid_match(current.data, str(ConnectionGate.player_id)) and (current.data.status == "RUNNING" or str(current.data.match_id) == CoreDefenseClient.saved_match()):
		admitted.emit(current.data)
		return
	if current.code == 200 and current.data.has("match") and current.data.match == null: CoreDefenseClient.save_match("")
	if not CoreDefenseClient.saved_room().is_empty():
		_busy = true
		var room: Dictionary = await CoreDefenseClient.request("/forest/core-defense/state?room_id=" + CoreDefenseClient.saved_room().uri_encode(), null, self)
		if not _valid(): return
		_busy = false
		if room.code == 200 and CoreDefenseClient.valid_room(room.data, str(ConnectionGate.player_id)):
			admitted.emit(room.data)
			return
		if room.code == 404: CoreDefenseClient.save_room("")
	_status.text = tr("CD_CHOOSE_MODE") if current.code == 200 else tr("CD_UNAVAILABLE")

func _complete(result: Dictionary) -> void:
	if int(result.get("code", 0)) != 200 or not CoreDefenseClient.valid_room(result.get("data"), str(ConnectionGate.player_id)):
		_status.text = tr("CD_UNAVAILABLE")
		return
	_busy = true
	var verified: Dictionary = await CoreDefenseClient.request("/forest/core-defense/state?room_id=" + str(result.data.room_id).uri_encode(), null, self)
	if not _valid(): return
	_busy = false
	if verified.code == 200 and CoreDefenseClient.valid_room(verified.data, str(ConnectionGate.player_id)):
		admitted.emit(verified.data)
	else:
		_status.text = tr("CD_UNAVAILABLE")

func _verified(room: Dictionary) -> void:
	if _valid(): admitted.emit(room)

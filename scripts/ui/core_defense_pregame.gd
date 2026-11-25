extends Control

const PANEL_STYLE := preload("res://scripts/ui/minigame_panel_style.gd")

var _identity := ""
var _room := {}
var _requesting := false
var _changing := false
var _poll := 0.0
var _backoff := 1.0
var _room_missing := false
var _message: Label
var _info: Label
var _start: Button
var _invites

func _ready() -> void:
	_identity = CoreDefenseClient.identity()
	if not SceneRouter.woe_context_valid() or SceneRouter._woe_context.get("kind") != "core_defense":
		SceneRouter.finish_woe_safely.call_deferred()
		return
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	PANEL_STYLE.panel(panel)
	panel.custom_minimum_size = Vector2(700, 520)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 24)
	box.add_child(_info)
	_message = Label.new()
	box.add_child(_message)
	_start = Button.new()
	PANEL_STYLE.button(_start, true)
	_start.text = tr("WOE_START")
	_start.custom_minimum_size.y = 64
	_start.add_theme_font_size_override("font_size", 30)
	_start.pressed.connect(_start_match)
	box.add_child(_start)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_invites = preload("res://scripts/ui/minigame_invitations.gd").new()
	_invites.name = "Invitations"
	_invites.plain_buttons = true
	_invites.room_id = str(SceneRouter._woe_context.room_id)
	scroll.add_child(_invites)
	var retry := Button.new()
	PANEL_STYLE.button(retry)
	retry.text = tr("WOE_RETRY")
	retry.custom_minimum_size.y = 48
	retry.add_theme_font_size_override("font_size", 22)
	retry.pressed.connect(_retry)
	box.add_child(retry)
	var leave := Button.new()
	PANEL_STYLE.button(leave)
	leave.text = tr("WOE_LEAVE")
	leave.custom_minimum_size.y = 48
	leave.add_theme_font_size_override("font_size", 22)
	leave.pressed.connect(_leave)
	box.add_child(leave)
	var local_return := Button.new()
	PANEL_STYLE.button(local_return)
	local_return.text = tr("WOE_RETURN")
	local_return.custom_minimum_size.y = 48
	local_return.add_theme_font_size_override("font_size", 22)
	local_return.pressed.connect(SceneRouter.finish_woe_safely)
	box.add_child(local_return)
	_refresh()

func _valid() -> bool:
	return is_inside_tree() and _identity == CoreDefenseClient.identity() and SceneRouter.woe_context_valid() and SceneRouter._woe_context.get("kind") == "core_defense"

func _process(delta: float) -> void:
	if not _valid():
		SceneRouter.finish_woe_safely()
		return
	_poll -= delta
	if _poll <= 0 and not _requesting and not _changing and not _room_missing: _refresh()

func _refresh() -> void:
	if _requesting or not _valid(): return
	_requesting = true
	var result: Dictionary = await CoreDefenseClient.request("/forest/core-defense/state?room_id=" + str(SceneRouter._woe_context.room_id).uri_encode(), null, self)
	if not _valid(): return
	_requesting = false
	if int(result.get("code", 0)) == 404 and str(result.get("error", "")) == "ROOM_UNAVAILABLE":
		await _missing_room()
		return
	if result.code == 200:
		_backoff = 1.0
	else:
		_backoff = minf(16.0, maxf(2.0, _backoff * 2.0))
	_poll = _backoff
	if result.code != 200 or not CoreDefenseClient.valid_room(result.get("data"), str(ConnectionGate.player_id)):
		_message.text = tr("CD_UNAVAILABLE")
		return
	if int(result.data.get("revision", 0)) >= int(_room.get("revision", 0)): _room = result.data
	_render()

func _render() -> void:
	if _room.is_empty(): return
	if _room.status == "STARTED":
		SceneRouter.enter_core_defense_match(_room)
		return
	var names: Array[String] = []
	for member in _room.get("members", []):
		var id := str(member.get("player_id", ""))
		var display := str(member.get("display_name", SocialClient.friends.get(id, ""))).strip_edges()
		names.append(display if not display.is_empty() else tr("INVITE_UNKNOWN_PLAYER"))
	var host_id := str(_room.get("host_id", ""))
	var host_name := str(_room.get("host_name", SocialClient.friends.get(host_id, ""))).strip_edges()
	_info.text = "%s\n%s: %s\n%s: %s" % [tr("CD_COOP"), tr("WOE_HOST"), host_name if not host_name.is_empty() else tr("INVITE_UNKNOWN_PLAYER"), tr("WOE_PLAYERS"), ", ".join(names)]
	_start.disabled = _changing or str(_room.get("host_id", "")) != str(ConnectionGate.player_id) or names.size() != 2
	_invites.visible = str(_room.get("host_id", "")) == str(ConnectionGate.player_id)
	_invites.set_inviting_enabled(_invites.visible and names.size() < 2 and not _changing and not _room_missing)

func _start_match() -> void:
	if _changing or _room.is_empty(): return
	_changing = true
	var result: Dictionary = await CoreDefenseClient.mutate("start", {"room_id":_room.room_id,"expected_revision":_room.revision})
	if not _valid(): return
	_changing = false
	if result.code == 200 and CoreDefenseClient.valid_room(result.data, str(ConnectionGate.player_id)):
		_room = result.data
		_render()
	else:
		_message.text = tr("WOE_RETRY_PENDING") if not CoreDefenseClient.saved_pending().is_empty() else tr("CD_UNAVAILABLE")
		_poll = 1.0

func _leave() -> void:
	if _changing: return
	_changing = true
	var result: Dictionary = await CoreDefenseClient.mutate("leave", {"room_id":str(SceneRouter._woe_context.room_id)})
	if not _valid(): return
	_changing = false
	if result.code == 200: SceneRouter.finish_woe_safely()
	elif int(result.get("code", 0)) == 404 and str(result.get("error", "")) == "ROOM_UNAVAILABLE": await _missing_room()
	else: _message.text = tr("CD_UNAVAILABLE")

# A missing room may be a completed match. Query the authenticated current match
# before discarding room recovery; transient failures keep all recovery records.
func _missing_room() -> void:
	_room_missing = true
	_start.disabled = true
	var room_id := str(SceneRouter._woe_context.room_id)
	var current: Dictionary = await CoreDefenseClient.request("/forest/core-defense/match/current", null, self)
	if not _valid(): return
	if current.code != 200:
		_room_missing = false
		_backoff = minf(16.0, maxf(2.0, _backoff * 2.0))
		_poll = _backoff
		_message.text = tr("CD_UNAVAILABLE")
		return
	if not CoreDefenseClient.valid_match(current.get("data"), str(ConnectionGate.player_id)) and not (current.get("data") is Dictionary and current.data.has("match") and current.data.match == null):
		_room_missing = false
		_poll = 8.0
		_message.text = tr("CD_UNAVAILABLE")
		return
	if CoreDefenseClient.valid_match(current.get("data"), str(ConnectionGate.player_id)):
		if current.data.status == "FINISHED" and not CoreDefenseClient.reconcile_terminal(current.data):
			_message.text = tr("CD_UNAVAILABLE")
			return
		if current.data.status == "RUNNING":
			if not CoreDefenseClient.reconcile_missing_room(room_id):
				_message.text = tr("CD_UNAVAILABLE")
				return
			SceneRouter._woe_context.match_id = str(current.data.match_id)
			CoreDefenseClient.save_match(str(current.data.match_id))
			SceneRouter._go_to(SceneRouter.SCENE_WOE_ARENA, "WOEArena")
			return
	if CoreDefenseClient.reconcile_missing_room(room_id): SceneRouter.finish_woe_safely()
	else: _message.text = tr("CD_UNAVAILABLE")

func _retry() -> void:
	if _changing or not _valid(): return
	if CoreDefenseClient.saved_pending().is_empty():
		_refresh()
		return
	_changing = true
	var action := str(CoreDefenseClient.saved_pending().get("action", ""))
	var result: Dictionary = await CoreDefenseClient.retry_pending()
	if not _valid(): return
	_changing = false
	if result.code == 200 and action == "leave":
		SceneRouter.finish_woe_safely()
	elif result.code == 200 and CoreDefenseClient.valid_room(result.data, str(ConnectionGate.player_id)):
		_room = result.data
		_render()
	else:
		_message.text = tr("WOE_RETRY_PENDING") if not CoreDefenseClient.saved_pending().is_empty() else tr("CD_UNAVAILABLE")

extends Node

signal changed

var data := {}
var received_tick := 0
var _identity := ""
var _busy := false
var _next_poll := 0
var _backoff := 8000
var stale := true
var _locks := {}
var _overlay: CanvasLayer
const FILE := "user://minigame_invite_recovery.cfg"
const SAFE_SCENES := [SceneRouter.SCENE_MAIN_MENU, SceneRouter.SCENE_LAB_HUB, SceneRouter.SCENE_LAB_STRUCTURES, "res://scenes/ui/Lab.tscn", SceneRouter.SCENE_INVENTORY, SceneRouter.SCENE_TRADE_HALL, SceneRouter.SCENE_EXPEDITIONS, SceneRouter.SCENE_WORLD_GATE, SceneRouter.SCENE_SETTINGS, SceneRouter.SCENE_TOP_PLAYERS, SceneRouter.SCENE_FOREST_WORLD, SceneRouter.SCENE_WOE_PREGAME, SceneRouter.SCENE_CD_PREGAME]

func _ready() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)
	var notices = preload("res://scripts/ui/minigame_invitation_notices.gd").new()
	notices.name = "MinigameInvitationNotices"
	notices.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notices.offset_left = -400
	notices.offset_right = -20
	notices.offset_top = 100
	_overlay.add_child(notices)
	_overlay.hide()

func eligible() -> bool:
	var scene := get_tree().current_scene
	return WoeClient.available() and not ConnectionGate.debug_offline_enabled and is_instance_valid(scene) and scene.scene_file_path in SAFE_SCENES and not scene.has_method("auth_gate_screen") and SceneRouter._spectator_context.is_empty() and SceneRouter._ranked_context.is_empty() and SceneRouter._friendly_context.is_empty() and SceneRouter._solo_hunt_context.is_empty() and SceneRouter._dungeon_context.is_empty() and not SceneRouter._hunt_loadout_active

func _journal_key(kind: String) -> String:
	return WoeClient.account_key() + "|" + kind

func saved(kind: String) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	var value: Variant = cfg.get_value("pending", _journal_key(kind), {})
	return value if value is Dictionary else {}

func save(kind: String, value: Dictionary) -> bool:
	if not WoeClient.available() or kind not in ["woe", "core_defense"]: return false
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("pending", _journal_key(kind), value)
	return cfg.save(FILE) == OK

func clear_exact(kind: String, pending: Dictionary) -> bool:
	if saved(kind) != pending: return false
	return save(kind, {})

func lock(kind: String, owner: Node) -> bool:
	var key := _journal_key(kind)
	if _locks.has(key) and is_instance_valid(_locks[key].get_ref()): return false
	_locks[key] = weakref(owner)
	return true

func unlock(kind: String, owner: Node, account: String) -> void:
	var key := account + "|" + kind
	if _locks.has(key) and _locks[key].get_ref() == owner: _locks.erase(key)

func _process(_delta: float) -> void:
	var identity: String = WoeClient.identity()
	if identity != _identity:
		_identity = identity
		data = {}
		received_tick = 0
		stale = true
		_backoff = 8000
		_next_poll = 0
		changed.emit()
	_overlay.visible = eligible()
	if not data.is_empty() and not stale and received_tick > 0 and Time.get_ticks_msec() - received_tick > 20000:
		stale = true
		changed.emit()
	if not eligible(): return
	if not _busy and Time.get_ticks_msec() >= _next_poll: refresh()

func refresh() -> void:
	if _busy or not eligible() or Time.get_ticks_msec() < _next_poll: return
	_busy = true
	var identity: String = WoeClient.identity()
	var result: Dictionary = await WoeClient.request("/forest/minigames/invitations", null, self)
	_busy = false
	if identity != WoeClient.identity(): return
	if result.code == 200 and result.get("data") is Dictionary:
		data = result.data
		received_tick = Time.get_ticks_msec()
		_backoff = 8000
		stale = false
	else:
		stale = true
		_backoff = mini(60000, maxi(8000, _backoff * 2))
	_next_poll = Time.get_ticks_msec() + _backoff
	changed.emit()

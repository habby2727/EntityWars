extends Node

signal changed

var data := {}
var received_tick := 0
var _identity := ""
var _busy := false
var _next_poll := 0
var _backoff := 8000

func _process(_delta: float) -> void:
	var identity: String = WoeClient.identity()
	if identity != _identity:
		_identity = identity
		data = {}
		_next_poll = 0
		changed.emit()
	if not WoeClient.available() or ConnectionGate.debug_offline_enabled: return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene) or scene.scene_file_path not in [SceneRouter.SCENE_FOREST_WORLD, SceneRouter.SCENE_WOE_PREGAME, SceneRouter.SCENE_CD_PREGAME]: return
	if not _busy and Time.get_ticks_msec() >= _next_poll: refresh()

func refresh() -> void:
	if _busy or not WoeClient.available() or ConnectionGate.debug_offline_enabled: return
	_busy = true
	var identity: String = WoeClient.identity()
	var result: Dictionary = await WoeClient.request("/forest/minigames/invitations", null, self)
	_busy = false
	if identity != WoeClient.identity(): return
	if result.code == 200 and result.get("data") is Dictionary:
		data = result.data
		received_tick = Time.get_ticks_msec()
		_backoff = 8000
		changed.emit()
	else:
		_backoff = mini(60000, maxi(8000, _backoff * 2))
	_next_poll = Time.get_ticks_msec() + _backoff

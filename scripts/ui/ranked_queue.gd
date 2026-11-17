extends Node

var host
var backend: BackendClient
var request_id := ""
var request_kind := ""
var selected := false
var queued := false
var joined_at := 0
var expires_at := 0
var next_poll := 0.0
var synced := false
var server_state := {}
var rating_needed := false
var availability_blocked := false
var column: VBoxContainer
var select_button: Button
var ready_button: Button
var cancel_button: Button
var info: Label
var overlay: ColorRect
var disabled_before := {}

func _ready() -> void:
	host = get_parent()
	column = VBoxContainer.new()
	column.name = "RankedColumn"
	column.z_as_relative = false
	column.z_index = 101
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	host.get_node("RootMargin/MainHSplit/LeftPanel/ModeRow").add_child(column)
	select_button = Button.new()
	select_button.text = "RANKED PvP"
	select_button.custom_minimum_size = Vector2(120, 55)
	column.add_child(select_button)
	select_button.pressed.connect(_select)
	host.btn_seal_attack.pressed.connect(_select_practice)
	host.btn_seal_defense.pressed.connect(_select_practice)
	info = Label.new()
	info.text = "Ranked"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(info)
	var top := Button.new()
	top.text = "Top Players"
	top.disabled = true
	top.tooltip_text = "Coming in 0.61i"
	column.add_child(top)
	ready_button = Button.new()
	ready_button.text = "READY"
	ready_button.disabled = true
	column.add_child(ready_button)
	ready_button.pressed.connect(_join)
	cancel_button = Button.new()
	cancel_button.text = "X Cancel"
	cancel_button.hide()
	column.add_child(cancel_button)
	cancel_button.pressed.connect(_cancel)
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_as_relative = false
	overlay.z_index = 100
	overlay.hide()
	host.add_child(overlay)
	backend = BackendClient.new()
	backend.base_url = host.spell_backend_url
	backend.auto_dev_login = false
	backend.state_updated.connect(_on_identity)
	backend.auth_changed.connect(_on_auth)
	backend.api_completed.connect(_on_response)
	add_child(backend)

func _on_auth(_token: String) -> void:
	request_id = ""
	request_kind = ""
	synced = false
	server_state = {}
	availability_blocked = false
	ready_button.disabled = true
	if queued:
		info.text = "Reconnect to recover queue"

func _on_identity(state: Dictionary) -> void:
	if state.is_empty() or str(state.get("player_id", "")) != backend._verified_player_id:
		return
	server_state = state.duplicate(true)
	synced = true
	next_poll = 0.0

func _select() -> void:
	if queued:
		return
	selected = true
	availability_blocked = false
	host._on_seal_attack()
	if host._verified_preferences_identity() == backend._verified_player_id and not backend._verified_player_id.is_empty():
		host._load_seal("attack")
	select_button.text = "RANKED PvP ✓"
	ready_button.disabled = not synced
	info.text = "Ranked — loading rating" if synced else "Sign in to play Ranked"
	rating_needed = true
	next_poll = 0.0

func _select_practice() -> void:
	if not queued:
		selected = false
		select_button.text = "RANKED PvP"
		ready_button.disabled = true

func _send(method: String, path: String, body: Variant, kind: String) -> bool:
	if not request_id.is_empty() or backend == null or backend.token.is_empty() or backend._verified_player_id.is_empty():
		return false
	request_id = backend.request_api(method, path, body)
	if request_id.is_empty():
		return false
	request_kind = kind
	return true

func _join() -> void:
	if not selected or queued or not synced or not request_id.is_empty():
		return
	var path: String = preload("res://scripts/domain/build_preferences.gd").seal_path(backend._verified_player_id, "attack")
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var seal: Dictionary = loaded if loaded is Dictionary and str(loaded.get("player_id", "")) == backend._verified_player_id else {}
	var entity := str(seal.get("entity_id", ""))
	if entity.is_empty():
		info.text = "Save an attack loadout first"
		return
	var progress: Dictionary = server_state.get("spell_progress", {})
	var equipped: Dictionary = progress.get("equipped_by_mode", {}).get("attack", {})
	var spells: Array = equipped.get(entity, preload("res://scripts/domain/spell_loadout.gd").initial_ids(host._reg, entity))
	if spells.size() != 4:
		info.text = "Server spell loadout unavailable"
		return
	var a := str(seal.get("equip_1", ""))
	var b := str(seal.get("equip_2", ""))
	var hom := str(seal.get("homunculus_id", ""))
	var selection := {"entity_id": entity, "weapon_ids": [null if a.is_empty() else a, null if b.is_empty() else b], "homunculus_id": null if hom.is_empty() else hom, "spell_ids": spells.duplicate(), "mode": "attack"}
	if _send("POST", "/pvp/queue/join", {"client_action_id": backend._make_uuid(), "selection": selection}, "join"):
		_set_queued(true)
		info.text = "Joining queue..."
	else:
		info.text = "Connection busy. Retry."

func _cancel() -> void:
	if not queued or not request_id.is_empty():
		return
	if not _send("POST", "/pvp/queue/cancel", {"client_action_id": backend._make_uuid()}, "cancel"):
		info.text = "Connection unavailable. Retry."

func _set_queued(value: bool) -> void:
	if value and not queued:
		_lock_controls(host)
	elif not value and queued:
		for control in disabled_before:
			if is_instance_valid(control):
				control.disabled = disabled_before[control]
		disabled_before.clear()
	queued = value
	overlay.visible = value
	ready_button.text = "Searching..." if value else "READY"
	ready_button.disabled = value or not synced or not selected
	cancel_button.visible = value
	select_button.disabled = value

func _lock_controls(node: Node) -> void:
	if node == column or node == self:
		return
	if node is BaseButton:
		disabled_before[node] = node.disabled
		node.disabled = true
	for child in node.get_children():
		_lock_controls(child)

func _process(delta: float) -> void:
	next_poll -= delta
	if queued and joined_at > 0:
		var seconds := clampi(int(Time.get_unix_time_from_system()) - int(joined_at / 1000), 0, 3600)
		info.text = "Searching %02d:%02d" % [seconds / 60, seconds % 60]
	if synced and not availability_blocked and request_id.is_empty() and next_poll <= 0.0:
		next_poll = 3.0
		if rating_needed and selected and not queued:
			_send("GET", "/pvp/leaderboard", null, "leaderboard")
		else:
			_send("GET", "/pvp/queue/state", null, "state")

func _on_response(id: String, ok: bool, data: Dictionary) -> void:
	if id != request_id:
		return
	var kind := request_kind
	request_id = ""
	request_kind = ""
	if not ok:
		if str(data.get("error", "")) in ["PVP_DISABLED", "PVP_SECRET_REQUIRED"]:
			availability_blocked = true
		if str(data.get("error", "")) in ["PVP_DISABLED", "PVP_SECRET_REQUIRED"] or (int(data.get("http_status", 0)) >= 400 and int(data.get("http_status", 0)) < 500):
			_set_queued(false)
		info.text = "Ranked unavailable" if str(data.get("error", "")) == "PVP_DISABLED" else "Connection error — retrying"
		next_poll = 3.0
		return
	if kind == "leaderboard":
		rating_needed = false
		var rank: Dictionary = data.get("player", {})
		info.text = "%d MP · %s %s" % [int(rank.get("mp", 1000)), str(rank.get("league", "Copper")), str(rank.get("division", "IV"))]
		ready_button.disabled = not selected or not synced or queued
		return
	var state := str(data.get("state", ""))
	if state == "MATCHED":
		var match_id := str(data.get("match_id", ""))
		if not match_id.is_empty():
			SceneRouter.go_to_ranked_combat(match_id)
	elif state == "QUEUED":
		joined_at = int(data.get("joined_at", 0))
		expires_at = int(data.get("expires_at", 0))
		selected = true
		_set_queued(true)
	elif state == "IDLE":
		var was_queued := queued
		_set_queued(false)
		if was_queued:
			info.text = "Queue cancelled" if kind == "cancel" else "Queue expired"
			rating_needed = selected

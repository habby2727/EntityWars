extends Node

const SETTINGS_PATH := "user://settings.cfg"

var host
var backend: BackendClient
var request_id := ""
var request_kind := ""
var selected := false
var queued := false
var cancel_requested := false
var joined_at := 0
var expires_at := 0
var next_poll := 0.0
var synced := false
var server_state := {}
var rating_needed := false
var availability_blocked := false
var column: VBoxContainer
var top_button: Button
var debug_button: Button
var cancel_button: Button
var info: Label
var overlay: ColorRect
var disabled_before := {}
var practice_selected_label: Label
var ranked_selected_label: Label
var play_z_index: int
var play_z_as_relative: bool
var play_disabled_style: StyleBox
var play_disabled_color: Color
var had_play_disabled_style := false
var had_play_disabled_color := false
var margin_bottom_before: float

func _ready() -> void:
	host = get_parent()
	practice_selected_label = _make_selected_label(host.btn_seal_attack)
	ranked_selected_label = _make_selected_label(host.btn_seal_defense)
	_update_selected_labels()
	column = VBoxContainer.new()
	column.name = "RankedColumn"
	column.z_as_relative = false
	column.z_index = 101
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.custom_minimum_size.x = 240
	host.get_node("RootMargin/MainHSplit/LeftPanel/ModeRow").add_child(column)
	info = Label.new()
	info.text = "Ranked"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.custom_minimum_size = Vector2(240, 72)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.clip_text = true
	info.max_lines_visible = 3
	info.add_theme_color_override("font_color", Color.WHITE)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 3)
	column.add_child(info)
	top_button = Button.new()
	top_button.text = "Top Players"
	preload("res://scripts/ui/menu_art.gd").button(top_button)
	column.add_child(top_button)
	top_button.pressed.connect(SceneRouter.go_to_top_players)
	if ConnectionGate.debug_lab_navigation_allowed():
		debug_button = Button.new()
		debug_button.text = "PVP_DEBUG_COMBAT"
		debug_button.custom_minimum_size.y = 48
		preload("res://scripts/ui/menu_art.gd").button(debug_button)
		column.add_child(debug_button)
		debug_button.hide()
		debug_button.pressed.connect(SceneRouter.go_to_debug_ranked_combat)
	cancel_button = Button.new()
	cancel_button.text = "X Cancel"
	preload("res://scripts/ui/menu_art.gd").button(cancel_button)
	cancel_button.custom_minimum_size = Vector2(180, 48)
	cancel_button.z_as_relative = false
	cancel_button.z_index = 101
	cancel_button.hide()
	host.add_child(cancel_button)
	cancel_button.pressed.connect(_cancel)
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	if str(config.get_value("combat", "selected_seal", "practice")) == "pvp":
		_select()

func _make_selected_label(seal: BaseButton) -> Label:
	var label := Label.new()
	label.text = "SELECTED"
	label.add_theme_font_override("font", preload("res://assets/fonts/old-newspaper-types-font/Oldnewspapertypes-449D.ttf"))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 2
	label.offset_bottom = 26
	return label

func _update_selected_labels() -> void:
	practice_selected_label.visible = not selected
	ranked_selected_label.visible = selected
	if is_instance_valid(debug_button):
		debug_button.visible = selected and ConnectionGate.debug_lab_navigation_allowed()

func _on_auth(_token: String) -> void:
	request_id = ""
	request_kind = ""
	synced = false
	server_state = {}
	availability_blocked = false
	if queued:
		info.text = "Reconnect to recover queue"

func _on_identity(state: Dictionary) -> void:
	if state.is_empty() or str(state.get("player_id", "")) != backend._verified_player_id:
		return
	server_state = state.duplicate(true)
	synced = true
	next_poll = 0.0

func _save_selection(value: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("combat", "selected_seal", value)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Could not save combat seal preference.")

func _select() -> void:
	if queued:
		return
	selected = true
	_save_selection("pvp")
	_update_selected_labels()
	host._update_save_button_label()
	availability_blocked = false
	host.btn_seal_attack.set_pressed_no_signal(false)
	host.btn_seal_defense.set_pressed_no_signal(true)
	info.text = "Ranked ? loading rating" if synced else "Sign in to play Ranked"
	rating_needed = true
	next_poll = 0.0

func _select_practice() -> void:
	if not queued:
		selected = false
		_save_selection("practice")
		_update_selected_labels()
		host._update_save_button_label()
		info.text = "Ranked"

func _send(method: String, path: String, body: Variant, kind: String) -> bool:
	if not request_id.is_empty() or backend == null or backend.token.is_empty() or backend._verified_player_id.is_empty():
		return false
	request_id = backend.request_api(method, path, body)
	if request_id.is_empty():
		return false
	request_kind = kind
	return true

func _join() -> void:
	if not selected or queued:
		return
	if not synced:
		info.text = "Sign in and wait for Ranked connection"
		return
	if not request_id.is_empty():
		info.text = "Connection busy. Retry."
		return
	var identity: String = backend._verified_player_id
	if identity.is_empty() or host._verified_preferences_identity() != identity or host._spell_backend == null or host._spell_backend.token.is_empty() or host._spell_backend._verified_player_id != identity or str(host._spell_state.get("player_id", "")) != identity:
		info.text = "Sign in with the same account to play Ranked"
		return
	if not host._spell_pending_id.is_empty():
		info.text = "Wait for spell loadout confirmation"
		return
	for action in host._spell_backend.get_pending_actions():
		if str(action.get("action_type", "")) == "SET_SPELL_LOADOUT":
			info.text = "Wait for spell loadout confirmation"
			return
	if not host._spell_synced:
		info.text = "Waiting for server spell loadout"
		return
	if host._has_duplicate_build_items():
		info.text = "Choose different weapons"
		return
	if not host._save_seal("attack"):
		info.text = "Could not save loadout"
		return
	host._update_save_button_label()
	var path: String = preload("res://scripts/domain/build_preferences.gd").seal_path(backend._verified_player_id, "attack")
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var seal: Dictionary = loaded if loaded is Dictionary and str(loaded.get("player_id", "")) == backend._verified_player_id else {}
	var entity := str(seal.get("entity_id", ""))
	if entity.is_empty():
		info.text = "Press Save Loadout first"
		return
	var current := {"entity_id": host._current_entity_id, "homunculus_id": host._current_homunculus_id, "equip_1": host._idx_to_id(host._items, host.dd_item1), "equip_2": host._idx_to_id(host._items, host.dd_item2), "side_1": host._idx_to_id(host._items, host.dd_side1), "side_2": host._idx_to_id(host._items, host.dd_side2), "attack_tech": host._idx_to_id(host._atk_techs, host.dd_atktech), "defense_tech": host._idx_to_id(host._def_techs, host.dd_deftech)}
	for key in current:
		if str(seal.get(key, "")) != str(current[key]):
			info.text = "Press Save Loadout first"
			return
	var progress: Dictionary = host._spell_state.get("spell_progress", {})
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
		joined_at = 0
		_set_queued(true)
		info.text = "Joining queue..."
	else:
		info.text = "Connection busy. Retry."

func _cancel() -> void:
	if not queued:
		return
	if not request_id.is_empty():
		cancel_requested = true
		info.text = "Cancelling queue..."
		return
	cancel_requested = false
	if not _send("POST", "/pvp/queue/cancel", {"client_action_id": backend._make_uuid()}, "cancel"):
		info.text = "Connection unavailable. Retry."

func _set_queued(value: bool) -> void:
	if value and not queued:
		var margin: Control = host.get_node("RootMargin")
		margin_bottom_before = margin.offset_bottom
		margin.offset_bottom -= 56
		play_z_index = host.btn_play.z_index
		play_z_as_relative = host.btn_play.z_as_relative
		had_play_disabled_style = host.btn_play.has_theme_stylebox_override("disabled")
		if had_play_disabled_style:
			play_disabled_style = host.btn_play.get_theme_stylebox("disabled")
		had_play_disabled_color = host.btn_play.has_theme_color_override("font_disabled_color")
		if had_play_disabled_color:
			play_disabled_color = host.btn_play.get_theme_color("font_disabled_color")
		host.btn_play.add_theme_stylebox_override("disabled", host.btn_play.get_theme_stylebox("normal"))
		host.btn_play.add_theme_color_override("font_disabled_color", host.btn_play.get_theme_color("font_color"))
		host.btn_play.z_as_relative = false
		host.btn_play.z_index = 101
		_lock_controls(host)
	elif not value and queued:
		var margin: Control = host.get_node("RootMargin")
		margin.offset_bottom = margin_bottom_before
		host.btn_play.z_index = play_z_index
		host.btn_play.z_as_relative = play_z_as_relative
		if had_play_disabled_style:
			host.btn_play.add_theme_stylebox_override("disabled", play_disabled_style)
		else:
			host.btn_play.remove_theme_stylebox_override("disabled")
		if had_play_disabled_color:
			host.btn_play.add_theme_color_override("font_disabled_color", play_disabled_color)
		else:
			host.btn_play.remove_theme_color_override("font_disabled_color")
		for control in disabled_before:
			if is_instance_valid(control):
				control.disabled = disabled_before[control]
		disabled_before.clear()
		cancel_requested = false
	queued = value
	overlay.visible = value
	host.btn_play.text = "Searching... 00:00" if value else tr("LOADOUT_READY_BO3")
	cancel_button.visible = value
	top_button.disabled = value

func _lock_controls(node: Node) -> void:
	if node == column or node == self or node == cancel_button:
		return
	if node is BaseButton:
		disabled_before[node] = node.disabled
		node.disabled = true
	for child in node.get_children():
		_lock_controls(child)

func _process(delta: float) -> void:
	next_poll -= delta
	if queued:
		cancel_button.global_position = host.btn_play.global_position + Vector2((host.btn_play.size.x - cancel_button.size.x) / 2.0, host.btn_play.size.y + 4.0)
	if queued and joined_at > 0:
		var seconds := clampi(int(Time.get_unix_time_from_system()) - int(joined_at / 1000), 0, 3600)
		host.btn_play.text = "Searching... %02d:%02d" % [seconds / 60, seconds % 60]
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
		var error := str(data.get("error", ""))
		if error == "UNTRUSTED_SETUP":
			info.text = "Loadout rejected — save and check your loadout"
		elif error == "QUEUE_CONFLICT":
			info.text = "Queue conflict — check your loadout and rejoin"
		else:
			info.text = "Ranked unavailable" if error == "PVP_DISABLED" else "Connection error — retrying"
		if cancel_requested and queued:
			_cancel()
		next_poll = 3.0
		return
	if kind == "leaderboard":
		rating_needed = false
		var rank: Dictionary = data.get("player", {})
		info.text = "%d MP · %s %s" % [int(rank.get("mp", 1000)), str(rank.get("league", "Copper")), str(rank.get("division", "IV"))]
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
		_update_selected_labels()
		host._update_save_button_label()
		host.btn_seal_attack.set_pressed_no_signal(false)
		host.btn_seal_defense.set_pressed_no_signal(true)
		_set_queued(true)
		if cancel_requested:
			_cancel()
	elif state == "IDLE":
		var was_queued := queued
		_set_queued(false)
		if was_queued:
			info.text = "Queue cancelled" if kind == "cancel" else "Queue expired"
			rating_needed = selected

extends Control
class_name WorldZone

@export var backend_path: NodePath
@export var background_path: NodePath
@export var header_label_path: NodePath
@export var session_label_path: NodePath
@export var modifier_label_path: NodePath
@export var heat_label_path: NodePath
@export var enter_button_path: NodePath
@export var farm_count_path: NodePath
@export var farm_button_path: NodePath
@export var claim_button_path: NodePath
@export var error_label_path: NodePath
@export var back_button_path: NodePath
@export var zone_id_override: String = ""

const MenuArt := preload("res://scripts/ui/menu_art.gd")

var _backend: BackendClient = null
var _background: TextureRect = null
var _header_label: Label = null
var _session_label: Label = null
var _modifier_label: Label = null
var _heat_label: Label = null
var _enter_button: Button = null
var _farm_count: OptionButton = null
var _farm_button: Button = null
var _claim_button: Button = null
var _error_label: Label = null
var _back_button: Button = null

var _catalog := AssetCatalog.new()
var _db := StaticDB.new()
var _debug := DebugFlags.new()

var _zone_id := ""
var _session_id := ""
var _world_state: Dictionary = {}
var _player_world: Dictionary = {}
var _bosses: Array = []
var _boss_picker: OptionButton
var _boss_portrait: TextureRect
var _boss_status: Label
var _boss_hp: ProgressBar
var _boss_open: Button
var _loot_label: Label
var _enter_confirm: ConfirmationDialog
var _auth_refresh_needed := false
var _gate_clock = preload("res://scripts/domain/world_gate_cooldown.gd").new()
var _gate_display_seconds := -2

func _exit_tree() -> void:
	_catalog.free()
	_db.free()
	_debug.free()

func _ready() -> void:
	_debug.reload()
	_resolve_nodes()
	_apply_background()
	_setup_zone_view()
	_setup_buttons()
	_enter_confirm = ConfirmationDialog.new()
	_enter_confirm.title = "Enter zone"
	_enter_confirm.confirmed.connect(_confirm_zone_entry)
	add_child(_enter_confirm)
	_setup_farm_options()
	_load_state()
	_request_world_state()

func _process(_delta: float) -> void:
	var remaining := _gate_remaining()
	if remaining != _gate_display_seconds:
		_gate_display_seconds = remaining
		_update_labels()

func _resolve_nodes() -> void:
	_backend = get_node_or_null(backend_path) as BackendClient
	_background = get_node_or_null(background_path) as TextureRect
	_header_label = get_node_or_null(header_label_path) as Label
	_session_label = get_node_or_null(session_label_path) as Label
	_modifier_label = get_node_or_null(modifier_label_path) as Label
	_heat_label = get_node_or_null(heat_label_path) as Label
	_enter_button = get_node_or_null(enter_button_path) as Button
	_farm_count = get_node_or_null(farm_count_path) as OptionButton
	_farm_button = get_node_or_null(farm_button_path) as Button
	_claim_button = get_node_or_null(claim_button_path) as Button
	_error_label = get_node_or_null(error_label_path) as Label
	_back_button = get_node_or_null(back_button_path) as Button
	if _backend != null:
		_backend.api_completed.connect(_on_api_completed)
		_backend.state_updated.connect(_on_state_updated)
		_backend.auth_changed.connect(_on_auth_changed)

func _setup_zone_view() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.02, 0.025)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)
	var overlay := get_node_or_null("Overlay") as PanelContainer
	if overlay != null:
		overlay.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var root := get_node_or_null("Overlay/Margin/RootVBox") as VBoxContainer
	if root != null:
		for node in root.find_children("*", "Label", true, false):
			var label := node as Label
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 5)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if _header_label != null:
			_header_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_loot_label = Label.new()
		_loot_label.add_theme_color_override("font_color", Color.WHITE)
		_loot_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_loot_label.add_theme_constant_override("outline_size", 5)
		_loot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(_loot_label)
		root.move_child(_loot_label, 4)
	if _back_button != null:
		_back_button.set("target", "world_gate")
		_back_button.reparent(self)
		_back_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_back_button.offset_left = -170
		_back_button.offset_right = -30
		_back_button.offset_top = 28
		_back_button.offset_bottom = 70
		_back_button.z_index = 5
		MenuArt.button(_back_button)
	if _enter_button != null:
		_enter_button.text = "Enter zone"
	if _farm_button != null:
		_farm_button.text = "Explore"
	if _claim_button != null:
		_claim_button.text = "Claim loot"
	for button in [_enter_button, _farm_button, _claim_button]:
		if button != null:
			button.custom_minimum_size = Vector2(130, 42)
			MenuArt.button(button)
	var panel := PanelContainer.new()
	panel.name = "WorldBossPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -390
	panel.offset_right = -30
	panel.offset_top = 125
	panel.offset_bottom = 660
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.07, 0.9)
	style.border_color = Color(0.58, 0.5, 0.3, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var title := Label.new()
	title.text = "WORLD BOSSES"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	_boss_picker = OptionButton.new()
	_boss_picker.disabled = true
	_boss_picker.item_selected.connect(_on_boss_selected)
	content.add_child(_boss_picker)
	_boss_portrait = TextureRect.new()
	_boss_portrait.custom_minimum_size = Vector2(0, 180)
	_boss_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_boss_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_boss_portrait)
	_boss_status = Label.new()
	_boss_status.text = "Waiting for server data."
	_boss_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_boss_status)
	_boss_hp = ProgressBar.new()
	_boss_hp.show_percentage = false
	_boss_hp.visible = false
	content.add_child(_boss_hp)
	_boss_open = Button.new()
	_boss_open.text = "Open boss encounter"
	_boss_open.disabled = true
	_boss_open.custom_minimum_size.y = 42
	MenuArt.button(_boss_open)
	_boss_open.pressed.connect(_open_boss)
	content.add_child(_boss_open)

func _refresh_bosses() -> void:
	if _boss_picker == null:
		return
	_boss_picker.clear()
	for boss in _bosses:
		if not boss is Dictionary:
			continue
		var id := str(boss.get("boss_id", ""))
		if id == "":
			continue
		_boss_picker.add_item(str(_db.bosses.get(id, {}).get("name", id)))
		_boss_picker.set_item_metadata(_boss_picker.item_count - 1, boss)
	_boss_picker.disabled = _boss_picker.item_count == 0
	_boss_open.disabled = _boss_picker.disabled
	if _boss_picker.disabled:
		_boss_portrait.texture = null
		_boss_hp.visible = false
		_boss_status.text = "No world boss reported by the server."
		return
	_boss_picker.select(0)
	_on_boss_selected(0)

func _on_boss_selected(index: int) -> void:
	if index < 0 or index >= _boss_picker.item_count:
		return
	var boss: Dictionary = _boss_picker.get_item_metadata(index)
	var id := str(boss.get("boss_id", ""))
	_boss_portrait.texture = _catalog.get_tex(id) if _catalog.has(id) else null
	var hp := float(boss.get("hp", 0))
	var max_hp := maxf(1, float(boss.get("max_hp", 1)))
	_boss_hp.max_value = max_hp
	_boss_hp.value = hp
	_boss_hp.visible = true
	_boss_status.text = "Global encounter  |  HP: %s / %s" % [int(hp), int(max_hp)]

func _open_boss() -> void:
	if _boss_picker.selected < 0:
		return
	var boss: Dictionary = _boss_picker.get_item_metadata(_boss_picker.selected)
	SceneRouter.go_to_world_gate_boss(str(boss.get("boss_id", "")))

func _on_auth_changed(token: String) -> void:
	if token != "":
		_auth_refresh_needed = true
		_request_world_state()

func _apply_background() -> void:
	if _background == null:
		return
	var zone_id = _get_zone_id()
	var tex: Texture2D = _catalog.get_tex(zone_id)
	if tex == null:
		var fallback = _catalog.find_id_contains(zone_id.replace("zone_", ""))
		if fallback != "":
			tex = _catalog.get_tex(fallback)
	_background.texture = tex
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if _header_label != null:
		_header_label.text = _get_zone_name(zone_id)

func _setup_buttons() -> void:
	if _enter_button != null:
		_enter_button.pressed.connect(_on_enter_pressed)
	if _farm_button != null:
		_farm_button.pressed.connect(_on_farm_pressed)
	if _claim_button != null:
		_claim_button.pressed.connect(_on_claim_pressed)

func _setup_farm_options() -> void:
	if _farm_count == null:
		return
	_farm_count.clear()
	var max_blocks := clampi(int(_db.get_balance("world_max_blocks_per_action", 4)), 1, 100)
	for count in range(1, max_blocks + 1):
		_farm_count.add_item("x%s" % count)
		_farm_count.set_item_metadata(_farm_count.item_count - 1, count)
	_farm_count.select(0)

func _load_state() -> void:
	if _backend != null:
		var state = _backend.load_cached_state()
		_update_from_state(state)

func _update_from_state(state: Dictionary) -> void:
	if _backend != null:
		_gate_clock.sync(_backend.get_server_time_unix_ms())
	_player_world = state.get("world", {})
	_sync_session()
	_update_labels()

func _request_world_state() -> void:
	if _backend == null:
		return
	var request_id := _backend.request_api("GET", "/world/state", null, false)
	if request_id != "" and _backend.token != "":
		_auth_refresh_needed = false
	if _backend.token == "":
		_backend.ensure_dev_login()
		_set_error("Logging in...")

func _on_api_completed(_request_id: String, ok: bool, data: Dictionary) -> void:
	_gate_clock.sync(int(data.get("server_time_unix_ms", 0)))
	if not ok:
		_set_error(str(data.get("error", "Request failed.")))
		if _boss_status != null and _bosses.is_empty():
			_boss_status.text = "Boss data unavailable. Check the server connection."
		return
	if data.has("world_state"):
		_world_state = data.get("world_state", {})
		var bosses: Variant = _world_state.get("bosses", [])
		_bosses = bosses if bosses is Array else []
		_refresh_bosses()
		var pw = data.get("player_world", null)
		if typeof(pw) == TYPE_DICTIONARY:
			_player_world = pw
		_sync_session()
		_update_labels()
		if _auth_refresh_needed:
			call_deferred("_request_world_state")
		elif pw is Dictionary:
			_clear_error()
		return
	# world_enter response
	if data.has("session_id"):
		_session_id = str(data.get("session_id", ""))
		_update_labels()

func _on_state_updated(state: Dictionary) -> void:
	_update_from_state(state)

func _on_enter_pressed() -> void:
	_clear_error()
	if not _ensure_auth():
		return
	if not _has_world_unlock():
		_set_error("World Gate locked. Build the World Gate to enter zones.")
		return
	if _session_id != "":
		return
	if _gate_remaining() != 0:
		_set_error("World Gate cooldown: %s" % _gate_remaining_text())
		return
	var fee := int(_db.get_balance("world_entry_fee_essence", 0))
	var balance := int(_backend.load_cached_state().get("wallet", {}).get("essence", 0))
	var daily_limit := int(_db.get_balance("world_daily_entries", 10))
	_enter_confirm.dialog_text = "Enter %s?\nCost: %d Essence (available: %d).\nDaily entries: %d / %d.\nRequires a constructed World Gate." % [_get_zone_name(_get_zone_id()), fee, balance, int(_player_world.get("daily_entries", 0)), daily_limit]
	_enter_confirm.popup_centered()

func _confirm_zone_entry() -> void:
	if _session_id != "" or _gate_remaining() != 0 or not _ensure_auth() or not _has_world_unlock():
		return
	var zone_id = _get_zone_id()
	if zone_id == "":
		return
	var body = {"client_action_id": _make_client_id(), "zone_id": zone_id}
	if _backend != null:
		if _backend.request_api("POST", "/world/enter", body, true) == "":
			_set_error("Request in progress. Try again shortly.")

func _on_farm_pressed() -> void:
	_clear_error()
	if not _ensure_auth():
		return
	if _session_id == "":
		_set_error("No active session.")
		return
	var count = _get_farm_count()
	var body = {"client_action_id": _make_client_id(), "session_id": _session_id, "blocks": count}
	if _backend != null:
		if _backend.request_api("POST", "/world/farm", body, true) == "":
			_set_error("Request in progress. Try again shortly.")

func _on_claim_pressed() -> void:
	_clear_error()
	if not _ensure_auth():
		return
	if _session_id == "":
		_set_error("No active session.")
		return
	var body = {"client_action_id": _make_client_id(), "session_id": _session_id}
	if _backend != null:
		if _backend.request_api("POST", "/world/claim", body, true) == "":
			_set_error("Request in progress. Try again shortly.")

func _get_zone_id() -> String:
	if zone_id_override != "":
		return zone_id_override
	if _zone_id != "":
		return _zone_id
	_zone_id = SceneRouter.consume_world_zone_id()
	if _zone_id == "":
		var zones: Array = _db.zones.keys()
		zones.sort()
		if zones.size() > 0:
			_zone_id = str(zones[0])
	return _zone_id

func _get_zone_name(zone_id: String) -> String:
	var entry = _db.zones.get(zone_id, {})
	if typeof(entry) == TYPE_DICTIONARY:
		return str(entry.get("display_name", entry.get("name", zone_id)))
	return zone_id

func _sync_session() -> void:
	_session_id = ""
	var sessions = _player_world.get("sessions", {})
	if typeof(sessions) != TYPE_DICTIONARY:
		return
	for sid in sessions.keys():
		var entry = sessions[sid]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("zone_id", "")) == _get_zone_id():
			_session_id = str(sid)
			break

func _update_labels() -> void:
	var zone_id = _get_zone_id()
	if _session_label != null:
		_session_label.text = "Zone session active" if _session_id != "" else "World Gate cooldown: %s" % _gate_remaining_text() if _gate_remaining() != 0 else "No active zone session"
	if _modifier_label != null:
		var mods := []
		var zone_map = _world_state.get("zones", [])
		if typeof(zone_map) == TYPE_ARRAY:
			for entry in zone_map:
				if typeof(entry) == TYPE_DICTIONARY and str(entry.get("zone_id", "")) == zone_id:
					mods = entry.get("modifier_ids", [])
					break
		_modifier_label.text = "Modifiers: %s" % _format_list(mods)
	if _heat_label != null:
		var heat := 0
		var rep := 0
		var progress = _player_world.get("zone_progress", {})
		if typeof(progress) == TYPE_DICTIONARY and progress.has(zone_id):
			var entry2 = progress[zone_id]
			if typeof(entry2) == TYPE_DICTIONARY:
				heat = int(entry2.get("heat", 0))
				rep = int(entry2.get("reputation", 0))
		_heat_label.text = "Heat: %s | Rep: %s" % [heat, rep]
	if _loot_label != null:
		var sessions: Variant = _player_world.get("sessions", {})
		var session: Dictionary = sessions.get(_session_id, {}) if sessions is Dictionary else {}
		var loot: Variant = session.get("pending_loot", {})
		var parts: Array[String] = []
		if loot is Dictionary:
			for key in loot:
				parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), loot[key]])
		_loot_label.text = "Stamina: %s  |  Unclaimed loot: %s" % [_player_world.get("stamina", "-"), ", ".join(parts) if not parts.is_empty() else "None"]
	if _enter_button != null:
		_enter_button.disabled = _session_id != "" or _gate_remaining() != 0
		_enter_button.tooltip_text = "World Gate cooldown: %s" % _gate_remaining_text() if _session_id == "" and _gate_remaining() != 0 else ""
	if _farm_button != null:
		_farm_button.disabled = _session_id == ""
	if _claim_button != null:
		_claim_button.disabled = _session_id == ""

func _gate_remaining() -> int:
	return _gate_clock.remaining_seconds(_player_world, int(_db.get_balance("world_gate_cooldown_seconds", 3600)))

func _gate_remaining_text() -> String:
	var remaining := _gate_remaining()
	return "checking server time" if remaining < 0 else _gate_clock.format_remaining(remaining)

func _ensure_auth() -> bool:
	if _backend == null:
		_set_error("Backend unavailable.")
		return false
	if _backend.token != "":
		return true
	_backend.ensure_dev_login()
	_set_error("Logging in...")
	return false

func _has_world_unlock() -> bool:
	_debug.reload()
	if _debug.unlock_all_buildings or _debug.force_all_clickable:
		return true
	var lab = _backend.load_cached_state().get("lab", {})
	if typeof(lab) != TYPE_DICTIONARY:
		return false
	var buildings = lab.get("buildings", {})
	if typeof(buildings) != TYPE_DICTIONARY:
		return false
	var entry = buildings.get("world_gate", {})
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	return int(entry.get("level", 0)) > 0

func _get_farm_count() -> int:
	if _farm_count == null or _farm_count.item_count == 0:
		return 1
	var count = int(_farm_count.get_item_metadata(_farm_count.selected))
	return max(1, count)

func _make_client_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func _set_error(message: String) -> void:
	if _error_label != null:
		_error_label.text = message

func _clear_error() -> void:
	if _error_label != null:
		_error_label.text = ""

func _format_list(values: Variant) -> String:
	if typeof(values) != TYPE_ARRAY:
		return "-"
	if values.is_empty():
		return "-"
	var list: Array = []
	for item in values:
		list.append(str(item))
	return ", ".join(list)

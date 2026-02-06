extends Control
class_name WorldGate

@export var backend_path: NodePath
@export var panel_path: NodePath
@export var back_button_path: NodePath
@export var tabs_path: NodePath

@export var zone_list_path: NodePath
@export var zone_refresh_path: NodePath
@export var session_zone_label_path: NodePath
@export var session_stats_label_path: NodePath
@export var farm_count_option_path: NodePath
@export var farm_button_path: NodePath
@export var farm_progress_label_path: NodePath
@export var drops_label_path: NodePath
@export var claim_button_path: NodePath
@export var zone_error_label_path: NodePath

@export var boss_portrait_path: NodePath
@export var boss_hp_bar_path: NodePath
@export var boss_window_label_path: NodePath
@export var boss_modifiers_label_path: NodePath
@export var boss_tickets_label_path: NodePath
@export var boss_contribution_label_path: NodePath
@export var boss_reward_label_path: NodePath
@export var boss_refresh_path: NodePath
@export var boss_attack_button_path: NodePath
@export var boss_claim_button_path: NodePath
@export var boss_error_label_path: NodePath

const FARM_COUNTS := [1, 5, 10, 25, 50]
const FARM_THROTTLE_MS := 250
const FARM_MAX_QUEUE := 200

var _backend: BackendClient = null
var _panel: Panel = null
var _back_button: Button = null
var _tabs: TabContainer = null

var _zone_list: VBoxContainer = null
var _zone_refresh: Button = null
var _session_zone_label: Label = null
var _session_stats_label: Label = null
var _farm_count_option: OptionButton = null
var _farm_button: Button = null
var _farm_progress_label: Label = null
var _drops_label: Label = null
var _claim_button: Button = null
var _zone_error_label: Label = null

var _boss_portrait: TextureRect = null
var _boss_hp_bar: ProgressBar = null
var _boss_window_label: Label = null
var _boss_modifiers_label: Label = null
var _boss_tickets_label: Label = null
var _boss_contribution_label: Label = null
var _boss_reward_label: Label = null
var _boss_refresh: Button = null
var _boss_attack_button: Button = null
var _boss_claim_button: Button = null
var _boss_error_label: Label = null

var _catalog := AssetCatalog.new()
var _db := StaticDB.new()
var _ui_scale := 1.0

const CONTENT_BASE_SIZE := Vector2(1400, 660)

var _state: Dictionary = {}
var _player_world: Dictionary = {}
var _world_state: Dictionary = {}
var _bosses: Array = []
var _zone_rows: Dictionary = {}
var _player_id := ""
var _selected_zone_id := ""
var _active_zone_id := ""
var _active_session_id := ""

var _requests: Dictionary = {}
var _api_queue: Array = []
var _busy := false
var _farm_next_allowed_ms := 0
var _farm_backoff_ms := 0.25
var _farm_throttle_timer: SceneTreeTimer = null
var _poll_timer: SceneTreeTimer = null

const POLL_INTERVAL_SEC := 8.0

var _server_time_offset_ms: float = 0.0

func _ready() -> void:
	_ui_scale = _compute_panel_scale()
	UIThemeFactory.apply_theme_scaled(self, _ui_scale)
	_resolve_nodes()
	_apply_panel_background()
	_connect_backend()
	_connect_buttons()
	_setup_farm_options()
	_load_state()
	_build_zone_cards()
	_request_world_state()
	_request_boss_state()
	_schedule_poll()

func _process(_delta: float) -> void:
	_update_boss_countdown()

func _resolve_nodes() -> void:
	_backend = get_node_or_null(backend_path) as BackendClient
	_panel = get_node_or_null(panel_path) as Panel
	_back_button = get_node_or_null(back_button_path) as Button
	_tabs = get_node_or_null(tabs_path) as TabContainer

	_zone_list = get_node_or_null(zone_list_path) as VBoxContainer
	_zone_refresh = get_node_or_null(zone_refresh_path) as Button
	_session_zone_label = get_node_or_null(session_zone_label_path) as Label
	_session_stats_label = get_node_or_null(session_stats_label_path) as Label
	_farm_count_option = get_node_or_null(farm_count_option_path) as OptionButton
	_farm_button = get_node_or_null(farm_button_path) as Button
	_farm_progress_label = get_node_or_null(farm_progress_label_path) as Label
	_drops_label = get_node_or_null(drops_label_path) as Label
	_claim_button = get_node_or_null(claim_button_path) as Button
	_zone_error_label = get_node_or_null(zone_error_label_path) as Label

	_boss_portrait = get_node_or_null(boss_portrait_path) as TextureRect
	_boss_hp_bar = get_node_or_null(boss_hp_bar_path) as ProgressBar
	_boss_window_label = get_node_or_null(boss_window_label_path) as Label
	_boss_modifiers_label = get_node_or_null(boss_modifiers_label_path) as Label
	_boss_tickets_label = get_node_or_null(boss_tickets_label_path) as Label
	_boss_contribution_label = get_node_or_null(boss_contribution_label_path) as Label
	_boss_reward_label = get_node_or_null(boss_reward_label_path) as Label
	_boss_refresh = get_node_or_null(boss_refresh_path) as Button
	_boss_attack_button = get_node_or_null(boss_attack_button_path) as Button
	_boss_claim_button = get_node_or_null(boss_claim_button_path) as Button
	_boss_error_label = get_node_or_null(boss_error_label_path) as Label
	if _boss_portrait != null:
		var portrait_size = int(round(240.0 * _ui_scale))
		_boss_portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)

func _apply_panel_background() -> void:
	if _panel == null:
		return
	_catalog.apply_panel(_panel, "ui_panel")

func _connect_backend() -> void:
	if _backend == null:
		return
	_backend.api_completed.connect(_on_api_completed)
	_backend.state_updated.connect(_on_state_updated)

func _connect_buttons() -> void:
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	if _zone_refresh != null:
		_zone_refresh.pressed.connect(_on_refresh_zones_pressed)
	if _farm_button != null:
		_farm_button.pressed.connect(_on_farm_pressed)
	if _claim_button != null:
		_claim_button.pressed.connect(_on_claim_pressed)
	if _boss_refresh != null:
		_boss_refresh.pressed.connect(_on_refresh_boss_pressed)
	if _boss_attack_button != null:
		_boss_attack_button.pressed.connect(_on_boss_attack_pressed)
	if _boss_claim_button != null:
		_boss_claim_button.pressed.connect(_on_boss_claim_pressed)

func _setup_farm_options() -> void:
	if _farm_count_option == null:
		return
	_farm_count_option.clear()
	for count in FARM_COUNTS:
		_farm_count_option.add_item("x%s" % count)
		_farm_count_option.set_item_metadata(_farm_count_option.item_count - 1, count)
	_farm_count_option.select(0)

func _load_state() -> void:
	_state = {}
	if _backend != null:
		_state = _backend.load_cached_state()
	if typeof(_state) != TYPE_DICTIONARY:
		_state = {}
	_player_id = str(_state.get("player_id", ""))
	_player_world = _state.get("world", {})
	if typeof(_player_world) != TYPE_DICTIONARY:
		_player_world = {}
	_sync_active_session()

func _build_zone_cards() -> void:
	if _zone_list == null:
		return
	_clear_container(_zone_list)
	_zone_rows.clear()
	var zone_ids: Array = _db.zones.keys()
	zone_ids.sort()
	for zone_id in zone_ids:
		var entry = _db.zones.get(zone_id, {})
		if typeof(entry) != TYPE_DICTIONARY:
			entry = {"id": zone_id, "name": zone_id}
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 120) * _ui_scale
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		card.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_child(row)
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(180, 100) * _ui_scale
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(preview)
		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)
		var name_label := Label.new()
		name_label.text = str(entry.get("display_name", entry.get("name", zone_id)))
		name_label.add_theme_font_size_override("font_size", int(round(18.0 * _ui_scale)))
		text_col.add_child(name_label)
		var mod_label := Label.new()
		mod_label.text = "Modifiers: -"
		mod_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(mod_label)
		var stats_label := Label.new()
		stats_label.text = "Heat: 0 | Rep: 0"
		text_col.add_child(stats_label)
		var enter_btn := Button.new()
		enter_btn.text = "Enter"
		enter_btn.pressed.connect(_on_enter_pressed.bind(zone_id))
		row.add_child(enter_btn)
		_zone_list.add_child(card)
		_zone_rows[zone_id] = {
			"preview": preview,
			"mod": mod_label,
			"stats": stats_label,
			"enter": enter_btn,
			"name": name_label
		}
	if zone_ids.size() > 0:
		_selected_zone_id = str(zone_ids[0])
	_update_zone_cards()
	_update_session_panel()

func _on_back_pressed() -> void:
	SceneRouter.go_to_lab()

func _on_refresh_zones_pressed() -> void:
	_request_world_state()

func _on_enter_pressed(zone_id: String) -> void:
	_clear_zone_error()
	if zone_id == "":
		return
	_selected_zone_id = zone_id
	var body = {
		"client_action_id": _make_client_id(),
		"zone_id": zone_id
	}
	_send_api_request("POST", "/world/enter", body, "world_enter", true, {"zone_id": zone_id})

func _on_farm_pressed() -> void:
	_clear_zone_error()
	if _active_session_id == "":
		_set_zone_error("No active session.")
		return
	var count := _get_farm_count()
	_enqueue_farm_requests(count)

func _on_claim_pressed() -> void:
	_clear_zone_error()
	if _active_session_id == "":
		_set_zone_error("No active session.")
		return
	var body = {
		"client_action_id": _make_client_id(),
		"session_id": _active_session_id
	}
	_send_api_request("POST", "/world/claim", body, "world_claim", true)

func _on_boss_attack_pressed() -> void:
	_clear_boss_error()
	var boss = _get_active_boss()
	if boss.is_empty():
		return
	var body = {
		"client_action_id": _make_client_id(),
		"boss_id": str(boss.get("boss_id", ""))
	}
	_send_api_request("POST", "/boss/attack", body, "boss_attack", true)

func _on_boss_claim_pressed() -> void:
	_clear_boss_error()
	var boss = _get_active_boss()
	if boss.is_empty():
		return
	var body = {
		"client_action_id": _make_client_id(),
		"boss_id": str(boss.get("boss_id", ""))
	}
	_send_api_request("POST", "/boss/claim_rewards", body, "boss_claim", true)

func _request_world_state() -> void:
	_send_api_request("GET", "/world/state", null, "world_state", false)

func _request_boss_state() -> void:
	_send_api_request("GET", "/boss/state", null, "boss_state", false)

func _on_refresh_boss_pressed() -> void:
	_request_boss_state()

func _send_api_request(
	method: String,
	path: String,
	body: Variant,
	kind: String,
	expect_state: bool,
	extra: Dictionary = {}
) -> void:
	if _backend == null:
		return
	if _busy:
		_api_queue.append({
			"method": method,
			"path": path,
			"body": body,
			"kind": kind,
			"expect_state": expect_state,
			"extra": extra
		})
		_update_farm_progress()
		return
	var request_id = _dispatch_api_request(method, path, body, kind, expect_state, extra)
	if request_id == "":
		_set_zone_error("Request failed to send.")

func _dispatch_api_request(
	method: String,
	path: String,
	body: Variant,
	kind: String,
	expect_state: bool,
	extra: Dictionary
) -> String:
	if _backend == null:
		return ""
	var request_id = _backend.request_api(method, path, body, expect_state)
	if request_id == "":
		return ""
	var info = {"kind": kind}
	for key in extra.keys():
		info[key] = extra[key]
	_requests[request_id] = info
	_set_busy(true)
	if kind == "farm":
		_farm_next_allowed_ms = Time.get_ticks_msec() + FARM_THROTTLE_MS
	return request_id

func _flush_api_queue() -> void:
	if _busy or _api_queue.is_empty():
		return
	var now_ms = Time.get_ticks_msec()
	var next = _api_queue[0]
	if typeof(next) != TYPE_DICTIONARY:
		_api_queue.pop_front()
		return
	if str(next.get("kind", "")) == "farm" and now_ms < _farm_next_allowed_ms:
		_schedule_farm_throttle()
		return
	_api_queue.pop_front()
	var request_id = _dispatch_api_request(
		str(next.get("method", "GET")),
		str(next.get("path", "")),
		next.get("body", null),
		str(next.get("kind", "")),
		bool(next.get("expect_state", false)),
		next.get("extra", {})
	)
	if request_id == "":
		if str(next.get("kind", "")) == "farm":
			_schedule_farm_backoff()
		else:
			_schedule_api_retry()
		return
	_update_farm_progress()

func _schedule_farm_throttle() -> void:
	if _farm_throttle_timer != null:
		return
	var wait_ms = max(1, _farm_next_allowed_ms - Time.get_ticks_msec())
	_farm_throttle_timer = get_tree().create_timer(float(wait_ms) / 1000.0)
	_farm_throttle_timer.timeout.connect(_on_farm_throttle_timeout)

func _on_farm_throttle_timeout() -> void:
	_farm_throttle_timer = null
	_flush_api_queue()

func _schedule_farm_backoff() -> void:
	if _farm_throttle_timer != null:
		return
	_farm_backoff_ms = min(_farm_backoff_ms * 2.0, 2.0)
	_farm_next_allowed_ms = Time.get_ticks_msec() + int(_farm_backoff_ms * 1000.0)
	_schedule_farm_throttle()

func _schedule_api_retry() -> void:
	if _farm_throttle_timer != null:
		return
	_farm_throttle_timer = get_tree().create_timer(0.25)
	_farm_throttle_timer.timeout.connect(_on_farm_throttle_timeout)

func _on_api_completed(request_id: String, ok: bool, data: Dictionary) -> void:
	var info = _requests.get(request_id, {})
	_requests.erase(request_id)
	_set_busy(false)
	if data.has("server_time_unix_ms"):
		_update_server_time(int(data.get("server_time_unix_ms", 0)))
	if not ok:
		_handle_api_error(info, data)
		_flush_api_queue()
		return
	var kind = str(info.get("kind", ""))
	if kind == "world_state":
		_world_state = data.get("world_state", {})
		var pw = data.get("player_world", null)
		if typeof(pw) == TYPE_DICTIONARY:
			_player_world = pw
		_update_zone_cards()
		_update_session_panel()
		_update_boss_panel()
	elif kind == "boss_state":
		_bosses = data.get("bosses", [])
		_update_boss_panel()
	elif kind == "world_enter":
		_active_session_id = str(data.get("session_id", ""))
		_active_zone_id = str(data.get("zone_id", info.get("zone_id", "")))
		_selected_zone_id = _active_zone_id
		_request_world_state()
	elif kind == "farm":
		_farm_backoff_ms = 0.25
		_update_farm_progress()
	elif kind == "world_claim":
		_request_world_state()
	elif kind == "boss_attack":
		_request_boss_state()
	elif kind == "boss_claim":
		_request_boss_state()
	_update_zone_cards()
	_update_session_panel()
	_update_boss_panel()
	_flush_api_queue()

func _handle_api_error(info: Dictionary, data: Dictionary) -> void:
	var kind = str(info.get("kind", ""))
	var err = str(data.get("error", "Request failed."))
	if kind == "farm":
		_set_zone_error("Farm failed: %s" % err)
		if _active_session_id != "":
			_api_queue.push_front({
				"method": "POST",
				"path": "/world/farm",
				"body": {
					"client_action_id": _make_client_id(),
					"session_id": _active_session_id,
					"blocks": 1
				},
				"kind": "farm",
				"expect_state": true,
				"extra": {}
			})
		_schedule_farm_backoff()
		return
	if kind.begins_with("boss"):
		_set_boss_error(err)
		return
	_set_zone_error(err)

func _on_state_updated(state: Dictionary) -> void:
	_state = state
	_player_id = str(state.get("player_id", ""))
	_player_world = state.get("world", {})
	if typeof(_player_world) != TYPE_DICTIONARY:
		_player_world = {}
	if _backend != null and _backend.get_server_time_unix_ms() > 0:
		_update_server_time(_backend.get_server_time_unix_ms())
	_sync_active_session()
	_update_zone_cards()
	_update_session_panel()
	_update_boss_panel()

func _sync_active_session() -> void:
	if _active_session_id != "":
		var active_sessions = _player_world.get("sessions", {})
		if typeof(active_sessions) == TYPE_DICTIONARY and active_sessions.has(_active_session_id):
			return
	_active_session_id = ""
	_active_zone_id = ""
	var sessions_data = _player_world.get("sessions", {})
	if typeof(sessions_data) != TYPE_DICTIONARY:
		return
	for session_id in sessions_data.keys():
		var entry = sessions_data[session_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_active_session_id = str(session_id)
		_active_zone_id = str(entry.get("zone_id", ""))
		if _selected_zone_id == "":
			_selected_zone_id = _active_zone_id
		break

func _enqueue_farm_requests(count: int) -> void:
	count = clamp(count, 1, FARM_MAX_QUEUE)
	for i in range(count):
		_api_queue.append({
			"method": "POST",
			"path": "/world/farm",
			"body": {
				"client_action_id": _make_client_id(),
				"session_id": _active_session_id,
				"blocks": 1
			},
			"kind": "farm",
			"expect_state": true,
			"extra": {}
		})
	_update_farm_progress()
	_flush_api_queue()

func _update_zone_cards() -> void:
	if _zone_rows.is_empty():
		return
	var zone_map: Dictionary = _get_zone_map()
	var progress_map = _player_world.get("zone_progress", {})
	for zone_id in _zone_rows.keys():
		var row = _zone_rows[zone_id]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var preview: TextureRect = row.get("preview", null)
		if preview != null:
			preview.texture = _catalog.get_tex(str(zone_id))
		var modifiers = []
		if zone_map.has(zone_id):
			modifiers = zone_map[zone_id].get("modifier_ids", [])
		var mod_text = "Modifiers: %s" % _format_list(modifiers)
		var mod_label: Label = row.get("mod", null)
		if mod_label != null:
			mod_label.text = mod_text
		var heat := 0
		var rep := 0
		if typeof(progress_map) == TYPE_DICTIONARY and progress_map.has(zone_id):
			var entry = progress_map[zone_id]
			if typeof(entry) == TYPE_DICTIONARY:
				heat = int(entry.get("heat", 0))
				rep = int(entry.get("reputation", 0))
		var stats_label: Label = row.get("stats", null)
		if stats_label != null:
			stats_label.text = "Heat: %s | Rep: %s" % [heat, rep]
		var enter_btn: Button = row.get("enter", null)
		if enter_btn != null:
			enter_btn.disabled = _busy

func _update_session_panel() -> void:
	if _session_zone_label == null or _session_stats_label == null:
		return
	var zone_id := _selected_zone_id
	if zone_id == "" and _active_zone_id != "":
		zone_id = _active_zone_id
	var display_name = zone_id
	if _db.zones.has(zone_id):
		var entry = _db.zones[zone_id]
		if typeof(entry) == TYPE_DICTIONARY:
			display_name = str(entry.get("display_name", entry.get("name", zone_id)))
	_session_zone_label.text = "Active Zone: %s" % display_name
	var heat := 0
	var rep := 0
	var progress = _player_world.get("zone_progress", {})
	if typeof(progress) == TYPE_DICTIONARY and progress.has(zone_id):
		var entry = progress[zone_id]
		if typeof(entry) == TYPE_DICTIONARY:
			heat = int(entry.get("heat", 0))
			rep = int(entry.get("reputation", 0))
	var mods := []
	var zone_map = _get_zone_map()
	if zone_map.has(zone_id):
		mods = zone_map[zone_id].get("modifier_ids", [])
	_session_stats_label.text = "Modifiers: %s | Heat: %s | Rep: %s" % [_format_list(mods), heat, rep]
	if _drops_label != null:
		var min_drop = int(_db.get_balance("world_drop_min", 1))
		var max_drop = int(_db.get_balance("world_drop_max", 3))
		_drops_label.text = "Expected per block: %s-%s items" % [min_drop, max_drop]
	var has_session = _active_session_id != ""
	if _farm_button != null:
		_farm_button.disabled = _busy or not has_session
	if _claim_button != null:
		_claim_button.disabled = _busy or not has_session
	_update_farm_progress()

func _update_boss_panel() -> void:
	var boss = _get_active_boss()
	if boss.is_empty():
		return
	var boss_id = str(boss.get("boss_id", ""))
	if _boss_portrait != null:
		_boss_portrait.texture = _catalog.get_tex(boss_id)
	if _boss_hp_bar != null:
		_boss_hp_bar.max_value = float(boss.get("max_hp", 1))
		_boss_hp_bar.value = float(boss.get("hp", 0))
	if _boss_modifiers_label != null:
		_boss_modifiers_label.text = "Modifiers: %s" % _format_list(boss.get("modifiers", []))
	var tickets = int(_player_world.get("boss_tickets", 0))
	if _boss_tickets_label != null:
		_boss_tickets_label.text = "Tickets: %s" % tickets
	var contrib = _get_contribution_score(boss)
	if _boss_contribution_label != null:
		_boss_contribution_label.text = "Contribution: %s" % contrib
	if _boss_reward_label != null:
		_boss_reward_label.text = "Reward Tier: %s" % _compute_reward_tier(boss)
	_update_boss_buttons()
	_update_boss_countdown()

func _update_boss_buttons() -> void:
	var boss = _get_active_boss()
	if boss.is_empty():
		return
	var now_ms = _get_server_now_ms()
	var starts_at = int(boss.get("window_starts_at", 0))
	var ends_at = int(boss.get("window_ends_at", 0))
	var in_window = now_ms >= starts_at and now_ms <= ends_at
	var tickets = int(_player_world.get("boss_tickets", 0))
	if _boss_attack_button != null:
		_boss_attack_button.disabled = _busy or not in_window or tickets <= 0
	if _boss_claim_button != null:
		_boss_claim_button.disabled = _busy or now_ms <= ends_at

func _update_boss_countdown() -> void:
	if _boss_window_label == null:
		return
	var boss = _get_active_boss()
	if boss.is_empty():
		_boss_window_label.text = ""
		return
	var now_ms = _get_server_now_ms()
	var starts_at = int(boss.get("window_starts_at", 0))
	var ends_at = int(boss.get("window_ends_at", 0))
	if now_ms < starts_at:
		_boss_window_label.text = "Window starts in %s" % _format_seconds(starts_at - now_ms)
	elif now_ms <= ends_at:
		_boss_window_label.text = "Window ends in %s" % _format_seconds(ends_at - now_ms)
	else:
		_boss_window_label.text = "Window ended"

func _get_zone_map() -> Dictionary:
	var map: Dictionary = {}
	var zones = _world_state.get("zones", [])
	if typeof(zones) != TYPE_ARRAY:
		return map
	for entry in zones:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var zone_id = str(entry.get("zone_id", ""))
		if zone_id == "":
			continue
		map[zone_id] = entry
	return map

func _get_active_boss() -> Dictionary:
	if typeof(_bosses) == TYPE_ARRAY and _bosses.size() > 0:
		var entry = _bosses[0]
		if typeof(entry) == TYPE_DICTIONARY:
			return entry
	return {}

func _get_contribution_score(boss: Dictionary) -> int:
	if _player_id == "":
		return 0
	var contributors = boss.get("contributors", {})
	if typeof(contributors) != TYPE_DICTIONARY:
		return 0
	return int(contributors.get(_player_id, 0))

func _compute_reward_tier(boss: Dictionary) -> String:
	if _player_id == "":
		return "-"
	var contributors = boss.get("contributors", {})
	if typeof(contributors) != TYPE_DICTIONARY or contributors.is_empty():
		return "-"
	var entries: Array = []
	for key in contributors.keys():
		entries.append({"id": key, "score": int(contributors.get(key, 0))})
	entries.sort_custom(Callable(self, "_sort_contrib"))
	var rank := -1
	for i in range(entries.size()):
		if str(entries[i].get("id", "")) == _player_id:
			rank = i
			break
	if rank < 0:
		return "-"
	var percentile = float(rank + 1) / max(1.0, float(entries.size()))
	if percentile <= 0.1:
		return "T1"
	if percentile <= 0.25:
		return "T2"
	if percentile <= 0.5:
		return "T3"
	return "T4"

func _sort_contrib(a: Variant, b: Variant) -> bool:
	return int(a.get("score", 0)) > int(b.get("score", 0))

func _update_farm_progress() -> void:
	if _farm_progress_label == null:
		return
	var count = _count_farm_queue()
	var text = "Queue: %s" % count
	_farm_progress_label.text = text

func _get_farm_count() -> int:
	if _farm_count_option == null:
		return 1
	if _farm_count_option.item_count == 0:
		return 1
	var count = int(_farm_count_option.get_item_metadata(_farm_count_option.selected))
	if count <= 0:
		count = 1
	return count

func _set_busy(value: bool) -> void:
	_busy = value
	if _zone_refresh != null:
		_zone_refresh.disabled = _busy
	if _boss_refresh != null:
		_boss_refresh.disabled = _busy
	_update_zone_cards()
	_update_boss_buttons()

func _set_zone_error(message: String) -> void:
	if _zone_error_label != null:
		_zone_error_label.text = message

func _clear_zone_error() -> void:
	if _zone_error_label != null:
		_zone_error_label.text = ""

func _set_boss_error(message: String) -> void:
	if _boss_error_label != null:
		_boss_error_label.text = message

func _clear_boss_error() -> void:
	if _boss_error_label != null:
		_boss_error_label.text = ""

func _format_list(values: Variant) -> String:
	if typeof(values) != TYPE_ARRAY:
		return "-"
	if values.is_empty():
		return "-"
	var list: Array = []
	for item in values:
		list.append(str(item))
	return ", ".join(list)

func _format_seconds(ms: float) -> String:
	var total = int(ceil(ms / 1000.0))
	if total < 0:
		total = 0
	var minutes = int(total / 60.0)
	var seconds = total % 60
	if minutes > 0:
		return "%dm %02ds" % [minutes, seconds]
	return "%ds" % total

func _compute_panel_scale() -> float:
	var view = get_viewport_rect().size
	var content = Vector2(max(1.0, view.x - 200.0), max(1.0, view.y - 240.0))
	var ui_scale = min(content.x / CONTENT_BASE_SIZE.x, content.y / CONTENT_BASE_SIZE.y)
	return clamp(ui_scale, 0.9, 1.35)

func _update_server_time(server_time_ms: int) -> void:
	var local_ms = Time.get_unix_time_from_system() * 1000.0
	_server_time_offset_ms = float(server_time_ms) - local_ms

func _get_server_now_ms() -> int:
	if _server_time_offset_ms == 0.0:
		return int(Time.get_unix_time_from_system() * 1000.0)
	return int(Time.get_unix_time_from_system() * 1000.0 + _server_time_offset_ms)

func _make_client_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x" % rng.randi()

func _clear_container(container: Control) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

func _schedule_poll() -> void:
	if _poll_timer != null:
		return
	_poll_timer = get_tree().create_timer(POLL_INTERVAL_SEC)
	_poll_timer.timeout.connect(_on_poll_timeout)

func _on_poll_timeout() -> void:
	_poll_timer = null
	if _busy or _api_queue.size() > 0:
		_schedule_poll()
		return
	_request_world_state()
	_request_boss_state()
	_schedule_poll()

func _count_farm_queue() -> int:
	var count := 0
	for entry in _api_queue:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("kind", "")) == "farm":
			count += 1
	return count

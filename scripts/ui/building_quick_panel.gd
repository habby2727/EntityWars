extends PanelContainer

const MenuArt := preload("res://scripts/ui/menu_art.gd")
signal manage_requested(building_id: String)
signal debug_state_changed(state: Dictionary)

const DESCRIPTIONS := {
	"lab_th": "Unlock structures and raise their level caps.",
	"essence_reactor": "Produces Essence over time.",
	"storage_vault": "Increases resource storage capacity.",
	"build_forge": "Manage your builds and equipment.",
	"homunculus_vat": "Manage your homunculi.",
	"ultrahit_tower": "Research spells for your entities.",
	"experiment_chamber": "Run laboratory experiments.",
	"arcane_archives": "Research new laboratory knowledge.",
	"sync_nexus": "Synchronizes laboratory networks.",
	"anomaly_containment": "Contains unstable anomalies.",
	"trade_hall": "Trade resources and services.",
	"world_gate": "Travel to distant zones."
}

@onready var _name_label: Label = $Margin/Scroll/Content/Header/Name
@onready var _close: Button = $Margin/Scroll/Content/Header/Close
@onready var _frame: TextureRect = $Margin/Scroll/Content/ImageFrame/Frame
@onready var _icon: TextureRect = $Margin/Scroll/Content/ImageFrame/Frame/Icon
@onready var _description: Label = $Margin/Scroll/Content/Description
@onready var _level: Label = $Margin/Scroll/Content/Level
@onready var _requirement: Label = $Margin/Scroll/Content/Requirement
@onready var _cost_title: Label = $Margin/Scroll/Content/CostTitle
@onready var _costs: VBoxContainer = $Margin/Scroll/Content/Costs
@onready var _status: Label = $Margin/Scroll/Content/Status
@onready var _upgrade: Button = $Margin/Scroll/Content/Upgrade
@onready var _collect: Button = $Margin/Scroll/Content/Collect
@onready var _manage: Button = $Margin/Scroll/Content/Manage
@onready var _timer: Timer = $HealthTimer
@onready var _blocker: Control = get_parent().get_node("QuickPanelBlocker")
@onready var _lab_canvas: Control = get_parent().get_node("Aspect/Canvas")

var _backend: BackendClient
var _db: StaticDB
var _catalog: AssetCatalog
var _resolver: CostResolver
var _debug: DebugFlags
var _state: Dictionary = {}
var _building_id := ""
var _pending: Dictionary = {}
var _health_ok := false
var _fresh_state := false
var _health_id := ""
var _refresh_id := ""
var _message := ""

func _ready() -> void:
	var margin := $Margin as MarginContainer
	var scroll := $Margin/Scroll as ScrollContainer
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)
	scroll.reparent(layout)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for action in [_upgrade, _collect, _manage]:
		action.reparent(layout)
		action.custom_minimum_size.y = 36
	_close.pressed.connect(_close_panel)
	visibility_changed.connect(_sync_blocker)
	_upgrade.pressed.connect(_on_upgrade)
	_collect.pressed.connect(_on_collect)
	_manage.pressed.connect(_on_manage)
	_timer.timeout.connect(_probe_health)
	get_parent().resized.connect(_layout_panel)
	_lab_canvas.resized.connect(_layout_panel)
	_layout_panel()
	_sync_blocker()

func _close_panel() -> void:
	hide()

func _sync_blocker() -> void:
	_blocker.visible = visible

func setup(backend: BackendClient, db: StaticDB, catalog: AssetCatalog, state: Dictionary, debug: DebugFlags) -> void:
	_backend = backend
	_db = db
	_catalog = catalog
	_state = state
	_debug = debug
	_resolver = CostResolver.new(_db.buildings, _db.balance)
	_apply_art()
	if _backend == null or _debug.unlock_all_buildings:
		return
	_backend.state_updated.connect(_on_state_updated)
	_backend.action_sent.connect(_on_action_sent)
	_backend.action_queued.connect(_on_action_queued)
	_backend.action_confirmed.connect(_on_action_confirmed)
	_backend.action_failed.connect(_on_action_failed)
	_backend.api_completed.connect(_on_api_completed)
	_backend.auth_changed.connect(_on_auth_changed)
	for action in _backend.get_pending_actions():
		if action is Dictionary:
			var payload = action.get("payload", {})
			if payload is Dictionary and payload.has("building_id"):
				_pending[str(action.get("client_action_id", ""))] = str(payload.building_id)
	_timer.start()
	_probe_health()

func show_building(building_id: String) -> void:
	if _db == null or _db.get_building(building_id).is_empty():
		return
	_building_id = building_id
	_message = ""
	_layout_panel()
	_refresh()
	show()

func _layout_panel() -> void:
	var canvas_transform = get_parent().get_global_transform().affine_inverse() * _lab_canvas.get_global_transform()
	var content_rect := Rect2(Vector2.ZERO, _lab_canvas.size)
	var background := _lab_canvas.get_node_or_null("Background") as TextureRect
	if background != null and background.texture != null:
		var texture_size := background.texture.get_size()
		var factor := minf(_lab_canvas.size.x / texture_size.x, _lab_canvas.size.y / texture_size.y)
		content_rect.size = texture_size * factor
		content_rect.position = (_lab_canvas.size - content_rect.size) * 0.5
		# The existing lab background includes side margins around the map artwork.
		var side_margin := content_rect.size.x * 0.08
		content_rect.position.x += side_margin
		content_rect.size.x -= side_margin * 2.0
	var origin: Vector2 = canvas_transform * content_rect.position
	var available: Vector2 = canvas_transform * content_rect.end - origin
	if available.x <= 0 or available.y <= 0:
		return
	var panel_width = min(460.0, max(0.0, available.x - 24.0))
	var panel_height = min(650.0, max(0.0, available.y - 24.0))
	position = origin + Vector2(available.x - panel_width - 12.0, (available.y - panel_height) * 0.5)
	size = Vector2(panel_width, panel_height)

func _apply_art() -> void:
	add_theme_stylebox_override("panel", _stretch_art(load("res://assets/ui/new-elements/marco-horizontal-popup-grande.png")))
	_frame.texture = load("res://assets/ui/new-elements/marco-slot-small.png")
	for button in [_close, _upgrade, _collect, _manage]:
		MenuArt.button(button)

func _stretch_art(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style

func _refresh() -> void:
	if _building_id == "" or _db == null:
		return
	var data = _db.get_building(_building_id)
	var lab = _state.get("lab", {})
	if not lab is Dictionary:
		lab = {}
	var hq_level = int(lab.get("hqLevel", 1))
	var buildings = lab.get("buildings", {})
	if not buildings is Dictionary:
		buildings = {}
	var level = hq_level if _building_id == "lab_th" else int(buildings.get(_building_id, {}).get("level", 0))
	var max_level = HqRules.get_max_level(_building_id)
	var unlocked = HqRules.is_unlocked(_building_id, hq_level)
	var can_upgrade = HqRules.can_upgrade(_building_id, level, hq_level)
	var debug_enabled = _debug != null and _debug.unlock_all_buildings
	if debug_enabled:
		unlocked = true
		can_upgrade = level < max_level
	var result = _resolver.resolve_upgrade_cost(_building_id, level, hq_level, str(lab.get("hqPath", "Scientific")))
	var cost: Dictionary = result.get("cost", {})
	var wallet = _state.get("wallet", {})
	if not wallet is Dictionary:
		wallet = {}
	_name_label.text = str(data.get("display_name", data.get("name", _building_id)))
	_description.text = str(DESCRIPTIONS.get(_building_id, ""))
	if _building_id in ["sync_nexus", "anomaly_containment"]:
		_description.text += "\nSpecialized functions: Coming Soon."
	if _building_id == "essence_reactor" and level < max_level:
		var reactor: Dictionary = buildings.get("essence_reactor", {})
		var storage: Dictionary = buildings.get("storage_vault", {})
		var route := str(reactor.get("route", "stable"))
		if route.is_empty():
			route = "stable"
		var engine := ProductionEngine.new()
		var balance := ProductionEngine.balance_for_server(_db.balance)
		var hq_path := str(lab.get("hqPath", "Scientific"))
		var storage_route := str(storage.get("route", ""))
		var current_rate := 0.0 if level <= 0 else engine._compute_output_rate(level, route, storage_route, hq_path, balance) * 3600.0
		var next_rate: float = engine._compute_output_rate(level + 1, route, storage_route, hq_path, balance) * 3600.0
		_description.text += "\nEstimated base: %.0f → %.0f Essence/h (excludes boosts)." % [current_rate, next_rate]
	elif _building_id == "storage_vault" and level < max_level:
		var storage: Dictionary = buildings.get("storage_vault", {})
		var route := str(storage.get("route", ""))
		var hq_path := str(lab.get("hqPath", "Scientific"))
		var current_capacity := Capacity.compute_total_capacity(level, route, hq_path, _db.balance)
		var next_capacity := Capacity.compute_total_capacity(level + 1, route, hq_path, _db.balance)
		_description.text += "\nCapacity: %d → %d." % [current_capacity, next_capacity]
	_icon.texture = _catalog.get_tex(_building_id) if _catalog.has(_building_id) else null
	_level.text = "Level %s / %s%s" % [level, max_level, ("  →  %s" % (level + 1)) if level < max_level else ""]
	_requirement.text = ""
	if not unlocked:
		_requirement.text = "Unlocks at HQ level %s" % HqRules.get_unlock_level(_building_id)
	elif level >= max_level:
		_requirement.text = "Maximum level reached"
	elif not can_upgrade:
		_requirement.text = "Upgrade your HQ to continue"
	_cost_title.visible = level < max_level
	for child in _costs.get_children():
		_costs.remove_child(child)
		child.queue_free()
	var affordable := not cost.is_empty()
	for resource_id in cost:
		var available = int(wallet.get(resource_id, 0))
		var amount = int(cost[resource_id])
		if available < amount:
			affordable = false
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _catalog.get_tex(resource_id) if _catalog.has(resource_id) else null
		var label := Label.new()
		var resource = _db.get_resource(resource_id)
		label.text = "%s: %s / %s" % [resource.get("display_name", resource.get("name", resource_id)), available, amount]
		label.modulate = Color(1.0, 0.48, 0.4) if available < amount else Color.WHITE
		row.add_child(icon)
		row.add_child(label)
		_costs.add_child(row)
	var pending = _debug.lab_cooldown_active(_state, _building_id) if debug_enabled else _pending.values().has(_building_id)
	var online = debug_enabled or (_backend != null and _backend.token != "" and _health_ok and _fresh_state)
	_upgrade.text = "Build" if level == 0 else "Upgrade"
	_upgrade.disabled = not online or pending or not can_upgrade or (not debug_enabled and not affordable)
	_collect.visible = _building_id == "essence_reactor"
	_collect.disabled = not online or pending or level <= 0 or not unlocked
	_manage.disabled = not unlocked or (level <= 0 and not debug_enabled) or pending
	_status.text = _message
	if debug_enabled:
		_status.text = "Local debug - cooldown 1s" if pending else ("Local debug" if _message == "" else _message)
	elif not online:
		_status.text = "Offline or awaiting server state. Actions unavailable."
	elif pending and _status.text == "":
		_status.text = "Action pending server confirmation."
	if _building_id == "essence_reactor" and level > 0:
		var stored = buildings.get("essence_reactor", {}).get("runtime", {}).get("stored_output", 0)
		_status.text += "\nStored at last update: %.1f Essence." % float(stored)

func _on_upgrade() -> void:
	if not _upgrade.disabled:
		_send("UPGRADE_BUILDING")

func _on_collect() -> void:
	if not _collect.disabled:
		_send("CLAIM_PRODUCTION")

func _send(action_type: String) -> void:
	if _debug != null and _debug.unlock_all_buildings:
		_send_local_debug(action_type)
		return
	_message = "Sending action..."
	var action_id = _backend.send_action({"action_type": action_type, "payload": {"building_id": _building_id}})
	if action_id == "":
		_message = "Could not send action."
	else:
		_pending[action_id] = _building_id
	_refresh()

func _send_local_debug(action_type: String) -> void:
	if _debug.lab_cooldown_active(_state, _building_id):
		return
	var next = _state.duplicate(true)
	var lab = next.get("lab", {})
	if not lab is Dictionary:
		lab = {}
	var buildings = lab.get("buildings", {})
	if not buildings is Dictionary:
		buildings = {}
	var entry = buildings.get(_building_id, {})
	if not entry is Dictionary:
		entry = {}
	if action_type == "UPGRADE_BUILDING":
		var current = int(lab.get("hqLevel", 1)) if _building_id == "lab_th" else int(entry.get("level", 0))
		if current >= HqRules.get_max_level(_building_id):
			return
		entry["level"] = current + 1
		if _building_id == "essence_reactor" and not entry.has("runtime"):
			entry["runtime"] = {"stored_output": 0.0, "last_tick": int(Time.get_unix_time_from_system() * 1000)}
		buildings[_building_id] = entry
		lab["buildings"] = buildings
		if _building_id == "lab_th":
			lab["hqLevel"] = current + 1
		next["lab"] = lab
	elif action_type == "CLAIM_PRODUCTION" and _building_id == "essence_reactor":
		if _debug.claim_lab_production(next, _db).is_empty():
			_message = "Reactor must be built before collection."
			_refresh()
			return
	else:
		return
	_debug.start_lab_cooldown(next, _building_id)
	if not _debug.save_lab_state(next):
		_message = "Could not save local debug state."
		_refresh()
		return
	_state = next
	_message = "Local debug action saved."
	debug_state_changed.emit(_state)
	_refresh()
	get_tree().create_timer(1.0).timeout.connect(_refresh, CONNECT_ONE_SHOT)

func _on_manage() -> void:
	if not _manage.disabled:
		manage_requested.emit(_building_id)

func _probe_health() -> void:
	if _backend == null or _health_id != "" or _refresh_id != "":
		return
	_health_id = _backend.request_api("GET", "/health", null)

func _on_api_completed(request_id: String, ok: bool, _data: Dictionary) -> void:
	if request_id == _health_id and _health_id != "":
		_health_id = ""
		_health_ok = ok
		if not ok:
			_fresh_state = false
		elif _backend.token != "" and not _fresh_state:
			_refresh_id = _backend.request_api("GET", "/player/state", null, true)
		elif _backend.get_pending_count() > 0:
			_backend.flush_queue()
	elif request_id == _refresh_id and _refresh_id != "":
		_refresh_id = ""
		if not ok:
			_fresh_state = false
	_refresh()

func _on_auth_changed(_token: String) -> void:
	_fresh_state = false
	_probe_health()
	_refresh()

func _on_state_updated(state: Dictionary) -> void:
	if _debug != null and _debug.unlock_all_buildings:
		return
	_state = state
	_fresh_state = true
	_health_ok = true
	_refresh()

func _on_action_sent(action_id: String, action_key: String) -> void:
	_remember_action(action_id, action_key)
	_refresh()

func _on_action_queued(action_id: String, action_key: String, reason: String) -> void:
	_remember_action(action_id, action_key)
	if reason in ["offline", "network_error", "no_token"]:
		_health_ok = false
		_fresh_state = false
	_message = "Action queued; awaiting confirmation."
	_refresh()

func _remember_action(action_id: String, action_key: String) -> void:
	var parts = action_key.split(":")
	if action_id != "" and parts.size() >= 2 and parts[0] in ["UPGRADE_BUILDING", "CLAIM_PRODUCTION"]:
		_pending[action_id] = parts[1]

func _on_action_confirmed(action_id: String) -> void:
	if _pending.has(action_id):
		_pending.erase(action_id)
		_message = "Action confirmed."
		_refresh()

func _on_action_failed(action_id: String, error: String) -> void:
	if _pending.has(action_id):
		_pending.erase(action_id)
		_message = "Action failed: %s" % error.trim_prefix("server_reject:")
		_refresh()

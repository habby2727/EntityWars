extends Control
class_name LabHub

@export var backend_path: NodePath
@export var canvas_path: NodePath
@export var background_path: NodePath
@export var icon_layer_path: NodePath
@export var placeholder_popup_path: NodePath
@export var resource_bar_panel_path: NodePath
@export var resource_bar_path: NodePath
@export var structures_button_path: NodePath

const DESIGN_SIZE := Vector2(1600, 900)
const BUILDING_IDS := [
	"lab_th",
	"essence_reactor",
	"storage_vault",
	"build_forge",
	"homunculus_vat",
	"ultrahit_tower",
	"experiment_chamber",
	"arcane_archives",
	"sync_nexus",
	"anomaly_containment",
	"trade_hall",
	"world_gate"
]

const INVENTORY_TABS := {
	"build_forge": "Builds",
	"homunculus_vat": "Homunculi"
}

const LAYOUT_POS := {
	"lab_th": Vector2(800, 450),
	"arcane_archives": Vector2(800, 140),
	"essence_reactor": Vector2(480, 280),
	"storage_vault": Vector2(1120, 280),
	"build_forge": Vector2(320, 450),
	"homunculus_vat": Vector2(1280, 450),
	"ultrahit_tower": Vector2(480, 620),
	"experiment_chamber": Vector2(1120, 620),
	"sync_nexus": Vector2(640, 280),
	"anomaly_containment": Vector2(960, 280),
	"trade_hall": Vector2(650, 620),
	"world_gate": Vector2(950, 620)
}

const ICON_SIZE_PX := {
	"lab_th": 160,
	"default": 120
}

var _backend: BackendClient = null
var _catalog := AssetCatalog.new()
var _db := StaticDB.new()
var _debug := DebugFlags.new()

func _exit_tree() -> void:
	_catalog.free()
	_db.free()
	_debug.free()

var _canvas: Control = null
var _background: TextureRect = null
var _icon_layer: Control = null
var _placeholder_popup: PopupPanel = null
var _resource_bar_panel: PanelContainer = null
var _resource_bar: HBoxContainer = null
var _structures_button: Button = null

var _buttons: Dictionary = {}
var _state: Dictionary = {}
var _resource_rows: Dictionary = {}
@onready var _quick_panel = $BuildingQuickPanel

func _enter_tree() -> void:
	if _debug.unlock_all_buildings:
		var client = get_node_or_null(backend_path) as BackendClient
		if client != null:
			client.auto_dev_login = false
			client.auto_flush = false

func _ready() -> void:
	UIThemeFactory.apply_theme_to(self)
	_debug.reload()
	_resolve_nodes()
	_setup_background()
	_connect_backend()
	_build_icons()
	_build_resource_bar()
	_load_state()
	_quick_panel.setup(_backend, _db, _catalog, _state, _debug)
	_quick_panel.manage_requested.connect(_manage_building)
	_quick_panel.debug_state_changed.connect(_on_debug_state_changed)
	_update_lock_states()
	_update_resource_bar()
	_layout_icons()
	call_deferred("_layout_icons")

func _resolve_nodes() -> void:
	_backend = get_node_or_null(backend_path) as BackendClient
	_canvas = get_node_or_null(canvas_path) as Control
	_background = get_node_or_null(background_path) as TextureRect
	_icon_layer = get_node_or_null(icon_layer_path) as Control
	_placeholder_popup = get_node_or_null(placeholder_popup_path) as PopupPanel
	_resource_bar_panel = get_node_or_null(resource_bar_panel_path) as PanelContainer
	_resource_bar = get_node_or_null(resource_bar_path) as HBoxContainer
	_structures_button = get_node_or_null(structures_button_path) as Button
	if _canvas != null:
		_canvas.resized.connect(_on_canvas_resized)
	if _structures_button != null:
		_structures_button.pressed.connect(func(): SceneRouter.go_to_lab_structures(""))

func _setup_background() -> void:
	if _background == null:
		return
	var tex: Texture2D = null
	if _catalog.has("labscene_bg"):
		tex = _catalog.get_tex("labscene_bg")
	if tex == null:
		var found_id = _catalog.find_id_contains("labscene_bg")
		if found_id != "":
			tex = _catalog.get_tex(found_id)
	if tex == null and ResourceLoader.exists("res://assets/lab/more_ui/labscene_bg.png"):
		tex = load("res://assets/lab/more_ui/labscene_bg.png")
	_background.texture = tex
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _connect_backend() -> void:
	if _backend == null or _debug.unlock_all_buildings:
		return
	_backend.state_updated.connect(_on_state_updated)

func _build_icons() -> void:
	if _icon_layer == null:
		return
	for child in _icon_layer.get_children():
		child.queue_free()
	_buttons.clear()
	for building_id in BUILDING_IDS:
		var button := TextureButton.new()
		button.name = "Btn_%s" % building_id
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var icon_tex = _catalog.get_tex(building_id)
		if icon_tex != null:
			button.texture_normal = icon_tex
			button.texture_hover = icon_tex
			button.texture_pressed = icon_tex
		else:
			var label := Label.new()
			label.text = _get_building_display_name(building_id)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.anchor_right = 1.0
			label.anchor_bottom = 1.0
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(label)

		button.tooltip_text = _get_building_display_name(building_id)
		button.pressed.connect(_on_building_pressed.bind(building_id))
		_icon_layer.add_child(button)
		_buttons[building_id] = button

func _load_state() -> void:
	_state = {}
	if _debug.unlock_all_buildings:
		_state = _debug.load_lab_state()
	elif _backend != null:
		_state = _backend.load_cached_state()
	if typeof(_state) != TYPE_DICTIONARY or _state.is_empty():
		_state = {
			"lab": {"hqLevel": 1, "buildings": {}}
		}

func _update_lock_states() -> void:
	for building_id in BUILDING_IDS:
		var button: BaseButton = _buttons.get(building_id, null)
		if button == null:
			continue
		var unlock_level = _get_unlock_level(building_id)
		var locked = _get_hq_level() < unlock_level
		if building_id == "lab_th":
			locked = false
		if _debug.unlock_all_buildings or _debug.force_all_clickable:
			locked = false
		button.disabled = false
		var display_name = _get_building_display_name(building_id)
		if locked:
			button.modulate = Color(1, 1, 1, 0.4)
			button.tooltip_text = "%s\nUnlock at HQ Lv %s" % [display_name, unlock_level]
		else:
			button.modulate = Color(1, 1, 1, 1)
			button.tooltip_text = display_name

func _build_resource_bar() -> void:
	if _resource_bar_panel != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.55)
		sb.content_margin_left = 6
		sb.content_margin_top = 4
		sb.content_margin_right = 6
		sb.content_margin_bottom = 4
		_resource_bar_panel.add_theme_stylebox_override("panel", sb)
	if _resource_bar == null:
		return
	for child in _resource_bar.get_children():
		child.queue_free()
	_resource_rows.clear()
	for res_id in StaticDB.REQUIRED_RESOURCE_IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _catalog.get_tex(res_id)
		var label := Label.new()
		label.text = "0"
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(icon)
		row.add_child(label)
		_resource_bar.add_child(row)
		_resource_rows[res_id] = {"row": row, "icon": icon, "label": label}

func _update_resource_bar() -> void:
	if _resource_bar == null:
		return
	var wallet = _state.get("wallet", {})
	if typeof(wallet) != TYPE_DICTIONARY:
		wallet = {}
	var per_hour = _get_production_per_hour()
	for res_id in _resource_rows.keys():
		var row_data = _resource_rows.get(res_id, {})
		if typeof(row_data) != TYPE_DICTIONARY:
			continue
		var row: Control = row_data.get("row", null)
		var label: Label = row_data.get("label", null)
		var icon: TextureRect = row_data.get("icon", null)
		if icon != null and icon.texture == null:
			icon.texture = _catalog.get_tex(res_id)
		var amount = int(wallet.get(res_id, 0))
		if label != null:
			label.text = str(amount)
		if row != null:
			var res_name = _get_resource_name(res_id)
			var rate = float(per_hour.get(res_id, 0.0))
			row.tooltip_text = "%s\n+%s / hr" % [res_name, _format_number(rate)]

func _layout_icons() -> void:
	if _canvas == null:
		return
	var canvas_size = _canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	var icon_scale = canvas_size.x / DESIGN_SIZE.x
	for building_id in BUILDING_IDS:
		var button: Control = _buttons.get(building_id, null)
		if button == null:
			continue
		var base_size = float(ICON_SIZE_PX.get(building_id, ICON_SIZE_PX["default"]))
		var icon_size = Vector2(base_size, base_size) * icon_scale
		var pos = Vector2(0, 0)
		if LAYOUT_POS.has(building_id):
			pos = LAYOUT_POS[building_id] * icon_scale
		button.size = icon_size
		button.position = pos - icon_size * 0.5

func _on_canvas_resized() -> void:
	_layout_icons()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_icons()

func _on_state_updated(state: Dictionary) -> void:
	if _debug.unlock_all_buildings:
		return
	_state = state
	_update_lock_states()
	_update_resource_bar()

func _on_debug_state_changed(state: Dictionary) -> void:
	_state = state
	_update_lock_states()
	_update_resource_bar()

func _on_building_pressed(building_id: String) -> void:
	_quick_panel.show_building(building_id)

func _manage_building(building_id: String) -> void:
	if building_id == "trade_hall":
		SceneRouter.go_to_trade_hall()
		return
	if building_id == "world_gate":
		SceneRouter.go_to_world_gate()
		return
	SceneRouter.go_to_lab_structures(building_id)

func _get_hq_level() -> int:
	return int(_state.get("lab", {}).get("hqLevel", 1))

func _get_building_level(building_id: String) -> int:
	if building_id == "lab_th":
		return _get_hq_level()
	var lab = _state.get("lab", {})
	var buildings = lab.get("buildings", {})
	var entry = buildings.get(building_id, {})
	return int(entry.get("level", 0))

func _get_building_route(building_id: String) -> String:
	if building_id == "lab_th":
		return str(_state.get("lab", {}).get("hqPath", "Scientific"))
	var lab = _state.get("lab", {})
	var buildings = lab.get("buildings", {})
	var entry = buildings.get(building_id, {})
	return str(entry.get("route", ""))

func _get_unlock_level(building_id: String) -> int:
	var data = _db.get_building(building_id)
	if typeof(data) == TYPE_DICTIONARY and data.has("unlock_hq"):
		return int(data.get("unlock_hq", 1))
	return HqRules.get_unlock_level(building_id)

func _get_building_display_name(building_id: String) -> String:
	var data = _db.get_building(building_id)
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("display_name"):
			return str(data.get("display_name", building_id))
		if data.has("name"):
			return str(data.get("name", building_id))
	return building_id

func _get_resource_name(res_id: String) -> String:
	var entry = _db.get_resource(res_id)
	if typeof(entry) == TYPE_DICTIONARY:
		if entry.has("display_name"):
			return str(entry.get("display_name", res_id))
		if entry.has("name"):
			return str(entry.get("name", res_id))
	return res_id

func _get_production_per_hour() -> Dictionary:
	var out := {}
	for res_id in StaticDB.REQUIRED_RESOURCE_IDS:
		out[res_id] = 0.0
	var lab = _state.get("lab", {})
	if typeof(lab) != TYPE_DICTIONARY:
		return out
	var runtime = lab.get("runtime", {})
	if typeof(runtime) == TYPE_DICTIONARY and runtime.has("production_per_hour"):
		var prod = runtime.get("production_per_hour", {})
		if typeof(prod) == TYPE_DICTIONARY:
			for key in prod.keys():
				out[str(key)] = float(prod.get(key, 0.0))
			return out
	out["essence"] = _get_reactor_rate_per_hour()
	return out

func _get_reactor_rate_per_hour() -> float:
	var level = _get_building_level("essence_reactor")
	if level <= 0:
		return 0.0
	var route := _get_building_route("essence_reactor")
	if route.is_empty():
		route = "stable"
	var hq_path = str(_state.get("lab", {}).get("hqPath", "Scientific"))
	var engine := ProductionEngine.new()
	var rate: float = engine._compute_output_rate(level, route, _get_building_route("storage_vault"), hq_path, ProductionEngine.balance_for_server(_db.balance))
	var overclock = _state.get("lab", {}).get("runtime", {}).get("boosts", {}).get("volatile_overclock", {})
	if int(overclock.get("expires_at", 0)) > int(Time.get_unix_time_from_system() * 1000):
		rate *= float(_db.get_balance("overclock_output_mult", 1.25))
	return rate * 3600.0

func _get_mult(map: Variant, key: String, default_value: float) -> float:
	if typeof(map) != TYPE_DICTIONARY:
		return default_value
	var needle = key.strip_edges().to_lower()
	for k in map.keys():
		if str(k).to_lower() == needle:
			var value = map[k]
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				return float(value)
	return default_value

func _format_number(value: float) -> String:
	if value >= 1000.0:
		return "%.0f" % value
	if value >= 10.0:
		return "%.1f" % value
	return "%.2f" % value

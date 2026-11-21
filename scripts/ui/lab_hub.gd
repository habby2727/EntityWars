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
@export var animated_background := true

const LabActionAlert := preload("res://scripts/ui/lab_action_alert.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const ResourceBars := preload("res://scripts/ui/lab_resource_bars.gd")
const Localization := preload("res://scripts/ui/game_localization.gd")

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
	"arcane_archives": Vector2(800, 300),
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
	$Aspect/Canvas/BackgroundVideo.stop()
	_catalog.free()
	_db.free()
	_debug.free()

var _canvas: Control = null
var _background: TextureRect = null
var _icon_layer: Control = null
var _placeholder_popup: PopupPanel = null
var _resource_bar_panel: PanelContainer = null
var _resource_bar: VBoxContainer = null
var _structures_button: Button = null
var _android_pan := Vector2.ZERO

var _buttons: Dictionary = {}
var _state: Dictionary = {}
var _alert_synced := false
var _alert_elapsed := 0.0
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
	if OS.has_feature("editor") and ConnectionGate.debug_lab_navigation_allowed():
		var expedition_debug := Button.new()
		expedition_debug.name = "ExpeditionVisualDebug"
		expedition_debug.text = "EXPEDITIONS · VISUAL DEBUG"
		expedition_debug.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		expedition_debug.offset_left = -350
		expedition_debug.offset_top = -76
		expedition_debug.offset_right = -24
		expedition_debug.offset_bottom = -20
		expedition_debug.add_theme_font_size_override("font_size", 18)
		MenuArt.button(expedition_debug)
		expedition_debug.pressed.connect(SceneRouter.go_to_expeditions)
		add_child(expedition_debug)
	_debug.reload()
	_resolve_nodes()
	_setup_background()
	_connect_backend()
	for button in [$Aspect/Canvas/TopOverlay/BackButton, _structures_button]:
		MenuArt.button(button)
	if OS.has_feature("android"):
		_structures_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		get_viewport().size_changed.connect(_position_android_structures, CONNECT_DEFERRED)
		_position_android_structures.call_deferred()
		_icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background.mouse_filter = Control.MOUSE_FILTER_STOP
		_background.gui_input.connect(_pan_lab_background)
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
	_resource_bar = get_node_or_null(resource_bar_path) as VBoxContainer
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
	if OS.has_feature("android"):
		_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		get_viewport().size_changed.connect(_resize_android_canvas)
		_resize_android_canvas()
	var video: VideoStreamPlayer = $Aspect/Canvas/BackgroundVideo
	video.visible = animated_background
	if animated_background and video.stream != null:
		video.finished.connect(video.play)
		video.play()

func _connect_backend() -> void:
	if _backend == null or _debug.unlock_all_buildings:
		return
	_backend.state_updated.connect(_on_state_updated)
	_backend.auth_changed.connect(func(_token):
		_alert_synced = false
		_update_lock_states()
	)

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
		LabActionAlert.badge(button)
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
		var pending: bool = _quick_panel._pending.values().has(building_id) if not _debug.unlock_all_buildings else _debug.lab_cooldown_active(_state, building_id)
		var now := int(Time.get_unix_time_from_system() * 1000) if _debug.unlock_all_buildings else (_backend.get_server_time_unix_ms() if _backend != null else -1)
		button.get_node("ActionBadge").visible = (_debug.unlock_all_buildings or _alert_synced) and now >= 0 and LabActionAlert.available(building_id, _state, _db, now, pending)
		var display_name = _get_building_display_name(building_id)
		if locked:
			button.modulate = Color(1, 1, 1, 0.4)
			button.tooltip_text = tr("LAB_UNLOCK_BUILDING").replace("\\n", "\n") % [display_name, unlock_level]
		else:
			button.modulate = Color(1, 1, 1, 1)
			button.tooltip_text = display_name

func _build_resource_bar() -> void:
	if _resource_bar_panel != null:
		_resource_bar_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if _resource_bar != null:
		_resource_rows = ResourceBars.build(_resource_bar, _catalog, not OS.has_feature("android"), 5 if OS.has_feature("android") else -10)
		if OS.has_feature("android") and _resource_bar_panel != null:
			var band := HBoxContainer.new()
			band.add_theme_constant_override("separation", 10)
			_resource_bar.get_parent().add_child(band)
			for id in _resource_rows:
				_resource_rows[id].row.reparent(band)
				_resource_rows[id].icon.custom_minimum_size = Vector2(72, 72)
				_resource_rows[id].bar.custom_minimum_size = Vector2(220, 36)
				_resource_rows[id].label.add_theme_font_size_override("font_size", 22)
				_resource_rows[id].clip.size.y = 32
				_resource_rows[id].clip.get_child(0).size.y = 32
			_resource_bar.queue_free()
			_resource_bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			_resource_bar_panel.offset_left = 24
			_resource_bar_panel.offset_top = -112
			_resource_bar_panel.offset_right = -350
			_resource_bar_panel.offset_bottom = -24

func _update_resource_bar() -> void:
	ResourceBars.update(_resource_rows, _state, _debug.unlock_all_buildings, _db.balance)
	for res_id in _resource_rows:
		var row: Control = _resource_rows[res_id].row
		row.tooltip_text = _get_resource_name(res_id)
	_update_essence_tooltip()

func _update_essence_tooltip() -> void:
	if not _resource_rows.has("essence"):
		return
	var row: Control = _resource_rows.essence.row
	var rate := float(_get_production_per_hour().get("essence", 0.0))
	row.tooltip_text = "%s\n+%s / h" % [_get_resource_name("essence"), _format_number(rate)]

func _layout_icons() -> void:
	if _canvas == null:
		return
	var canvas_size = _canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	var icon_scale = canvas_size.x / DESIGN_SIZE.x
	var origin := Vector2.ZERO
	if OS.has_feature("android"):
		icon_scale = maxf(canvas_size.x / DESIGN_SIZE.x, canvas_size.y / DESIGN_SIZE.y)
		var overflow: Vector2 = (DESIGN_SIZE * icon_scale - canvas_size) / 2.0
		_android_pan = _android_pan.clamp(-overflow, overflow)
		origin = (canvas_size - DESIGN_SIZE * icon_scale) / 2.0 + _android_pan
		_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_background.position = origin
		_background.size = DESIGN_SIZE * icon_scale
		var video: VideoStreamPlayer = $Aspect/Canvas/BackgroundVideo
		video.set_anchors_preset(Control.PRESET_TOP_LEFT)
		video.position = origin
		video.size = DESIGN_SIZE * icon_scale
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
		button.position = origin + pos - icon_size * 0.5

func _pan_lab_background(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_android_pan += event.relative
		_layout_icons()

func _resize_android_canvas() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.y > 0.0:
		$Aspect.ratio = viewport_size.x / viewport_size.y

func _position_android_structures() -> void:
	var viewport_size := get_viewport_rect().size
	var target := GameTypography.touch_size(_structures_button)
	var chat_width := minf(maxf(360.0, target * 3.0), viewport_size.x - 30.0)
	var button_width := maxf(180.0, _structures_button.get_combined_minimum_size().x)
	_structures_button.offset_right = -chat_width - 25.0
	_structures_button.offset_left = _structures_button.offset_right - button_width
	_structures_button.offset_bottom = -15.0
	_structures_button.offset_top = -15.0 - maxf(target, _structures_button.get_combined_minimum_size().y)
	if is_instance_valid(_resource_bar_panel):
		_resource_bar_panel.offset_right = _structures_button.offset_left - 10.0

func _on_canvas_resized() -> void:
	_layout_icons()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_icons()
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_lock_states()
		_update_resource_bar()
		_quick_panel._refresh()

func _on_state_updated(state: Dictionary) -> void:
	if _debug.unlock_all_buildings:
		return
	_state = state
	_alert_synced = _backend != null and _backend.token != "" and _backend.get_server_time_unix_ms() >= 0
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
			return Localization.catalog("building", building_id, "name", str(data.get("display_name", building_id)))
		if data.has("name"):
			return Localization.catalog("building", building_id, "name", str(data.get("name", building_id)))
	return building_id

func _get_resource_name(res_id: String) -> String:
	var entry = _db.get_resource(res_id)
	if typeof(entry) == TYPE_DICTIONARY:
		if entry.has("display_name"):
			return Localization.catalog("resource", res_id, "name", str(entry.get("display_name", res_id)))
		if entry.has("name"):
			return Localization.catalog("resource", res_id, "name", str(entry.get("name", res_id)))
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
	var runtime: Dictionary = _state.get("lab", {}).get("runtime", {})
	var now := int(Time.get_unix_time_from_system() * 1000)
	var multiplier := 1.0
	for id in ["volatile_overclock", "essence_turbo"]:
		var boost: Dictionary = runtime.get("boosts", {}).get(id, {})
		if int(boost.get("started_at", 0)) <= now and now < int(boost.get("expires_at", 0)):
			multiplier = maxf(multiplier, float(ExperimentCatalog.get_by_id(id).get("effect", {}).get("reactor_output_mult", 1.0)))
	var directive: Dictionary = runtime.get("directive", {})
	if str(directive.get("id", "")) == "production" and int(directive.get("starts_at", 0)) <= now and now < int(directive.get("ends_at", 0)):
		multiplier *= float(_db.get_balance("hq_directive_production_mult", 1.1))
	var base_hourly: float = 3600.0 * (float(_db.get_balance("reactor_base_rate", 0.0)) + level * float(_db.get_balance("reactor_rate_per_level", 0.002777777777777778)))
	return minf(rate * multiplier * 3600.0, base_hourly * 2.0)

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

func _process(delta: float) -> void:
	_alert_elapsed += delta
	if _alert_elapsed >= 1.0:
		_alert_elapsed = 0.0
		_update_lock_states()
		_update_essence_tooltip()

extends Control
class_name LabScreen

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const SpellView := preload("res://scripts/ui/spell_presentation.gd")
const SpecializedPanel := preload("res://scripts/ui/lab_specialized_panel.gd")
@export var backend_path: NodePath
@export var grid_path: NodePath
@export var background_panel_path: NodePath
@export var resource_bar_panel_path: NodePath
@export var resource_bar_path: NodePath
@export var left_panel_path: NodePath
@export var right_panel_path: NodePath
@export var detail_icon_path: NodePath
@export var detail_name_path: NodePath
@export var detail_desc_path: NodePath
@export var detail_level_path: NodePath
@export var route_option_path: NodePath
@export var cost_list_path: NodePath
@export var upgrade_button_path: NodePath
@export var route_button_path: NodePath
@export var claim_button_path: NodePath
@export var open_button_path: NodePath
@export var locked_label_path: NodePath
@export var pending_label_path: NodePath
@export var placeholder_popup_path: NodePath
@export var experiment_section_path: NodePath
@export var experiment_list_path: NodePath
@export var research_section_path: NodePath
@export var research_list_path: NodePath

@export var building_card_scene: PackedScene = preload("res://scenes/ui/BuildingCard.tscn")

const BUILDING_ORDER := [
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

const REACTOR_ROUTES := ["Stable", "Volatile", "Mutagenic"]
const STORAGE_ROUTES := ["Compact", "Reactive", "Sealed"]
const HQ_PATHS := ["Scientific", "Chaotic", "Industrial"]
const GATE_BUILDINGS := ["sync_nexus", "anomaly_containment", "trade_hall", "world_gate"]
const RESEARCH_FLAG_ONLY := ["unlock_sync", "unlock_anomalies", "reduce_experiment_cooldown", "increase_storage_capacity", "reactor_efficiency", "unlock_arcane_catalog", "unlock_gateway_studies"]

var _backend: BackendClient = null
var _catalog := AssetCatalog.new()
var _db := StaticDB.new()
var _spell_registry := DataRegistry.new()
var _spell_section: VBoxContainer
var _spell_entity_selector: OptionButton
var _spell_list: VBoxContainer
var _spell_rows := {}
var _spell_server_offset_ms := 0
var _spell_state_synced := false
var _spell_filter := "All"
var _spell_info: Control
var _spell_info_title: Label
var _spell_info_text: Label
var _specialized_panel

var _grid: GridContainer = null
var _background_panel: PanelContainer = null
var _resource_bar_panel: PanelContainer = null
var _resource_bar: HBoxContainer = null
var _left_panel: Panel = null
var _right_panel: Panel = null
var _detail_icon: TextureRect = null
var _detail_name: Label = null
var _detail_desc: Label = null
var _detail_level: Label = null
var _route_option: OptionButton = null
var _cost_list: VBoxContainer = null
var _upgrade_btn: Button = null
var _route_btn: Button = null
var _claim_btn: Button = null
var _open_btn: Button = null
var _locked_label: Label = null
var _pending_label: Label = null
var _placeholder_popup: PopupPanel = null
var _experiment_section: Control = null
var _experiment_list: VBoxContainer = null
var _research_section: Control = null
var _research_list: VBoxContainer = null

var _cards: Dictionary = {}
var _state: Dictionary = {}
var _selected_id: String = ""
var _pending_by_id: Dictionary = {}
var _pending_action_to_building: Dictionary = {}
var _experiments: Array = []
var _experiment_rows: Dictionary = {}
var _research_rows: Dictionary = {}
var _resource_rows: Dictionary = {}
var _debug := DebugFlags.new()
var _ui_scale := 1.0
var _status_refresh_elapsed := 0.0
var _action_message := ""
var _action_message_building := ""

const CONTENT_BASE_SIZE := Vector2(1400, 660)

func _enter_tree() -> void:
	if _debug.unlock_all_buildings:
		var client = get_node_or_null(backend_path) as BackendClient
		if client != null:
			client.auto_dev_login = false
			client.auto_flush = false

func _ready() -> void:
	_ui_scale = _compute_panel_scale()
	UIThemeFactory.apply_theme_scaled(self, _ui_scale)
	_debug.reload()
	_resolve_nodes()
	_setup_compact_navigation()
	_setup_section_scrolls()
	_apply_ui_scale()
	_apply_panel_textures()
	_connect_backend()
	_build_grid()
	_build_resource_bar()
	_build_experiments()
	_build_research()
	_build_spell_section()
	_build_specialized_panel()
	_load_state()
	_select_default()

func _setup_section_scrolls() -> void:
	for section in [_experiment_section, _research_section]:
		if section == null:
			continue
		var list: VBoxContainer = _experiment_list if section == _experiment_section else _research_list
		if list == null:
			continue
		section.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size.y = 120
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		section.add_child(scroll)
		list.reparent(scroll)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _build_specialized_panel() -> void:
	var detail := _right_panel.get_node_or_null("Margin/DetailVBox") as VBoxContainer
	if detail == null:
		return
	_specialized_panel = SpecializedPanel.new()
	_specialized_panel.setup(_spell_registry, _backend, _debug.unlock_all_buildings, int(_db.get_balance("forge_upgrade_essence_base", 20)), int(_db.get_balance("forge_upgrade_essence_per_level", 10)))
	_specialized_panel.debug_forge_updated.connect(_on_debug_forge_updated)
	detail.add_child(_specialized_panel)

func _on_debug_forge_updated(state: Dictionary) -> void:
	_state = state
	_refresh_from_state()

func _setup_compact_navigation() -> void:
	if _left_panel == null or _right_panel == null or _grid == null:
		return
	_left_panel.custom_minimum_size.x = 96
	_left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grid.columns = 1
	var overlay := _background_panel.get_node_or_null("ContentMargin/TopOverlay") as Control
	if overlay != null and _resource_bar_panel != null:
		_resource_bar_panel.reparent(overlay)
		_resource_bar_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_resource_bar_panel.position = Vector2(110, -42)
		_resource_bar_panel.custom_minimum_size = Vector2(500, 34)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.07, 0.08, 0.9)
	background.border_color = Color(0.47, 0.4, 0.25, 0.8)
	background.set_border_width_all(1)
	_right_panel.add_theme_stylebox_override("panel", background)
	for button in [_upgrade_btn, _route_btn, _claim_btn, _open_btn]:
		if button:
			button.custom_minimum_size = Vector2(100, 42)
			MenuArt.button(button)

func _process(delta: float) -> void:
	_status_refresh_elapsed += delta
	if _status_refresh_elapsed >= 1.0:
		_status_refresh_elapsed = 0.0
		_update_experiments()
		_update_research()
		_update_spell_section()

func _resolve_nodes() -> void:
	_backend = get_node_or_null(backend_path) as BackendClient
	_grid = get_node_or_null(grid_path) as GridContainer
	_background_panel = get_node_or_null(background_panel_path) as PanelContainer
	_resource_bar_panel = get_node_or_null(resource_bar_panel_path) as PanelContainer
	_resource_bar = get_node_or_null(resource_bar_path) as HBoxContainer
	_left_panel = get_node_or_null(left_panel_path) as Panel
	_right_panel = get_node_or_null(right_panel_path) as Panel
	_detail_icon = get_node_or_null(detail_icon_path) as TextureRect
	_detail_name = get_node_or_null(detail_name_path) as Label
	_detail_desc = get_node_or_null(detail_desc_path) as Label
	_detail_level = get_node_or_null(detail_level_path) as Label
	_route_option = get_node_or_null(route_option_path) as OptionButton
	_cost_list = get_node_or_null(cost_list_path) as VBoxContainer
	_upgrade_btn = get_node_or_null(upgrade_button_path) as Button
	_route_btn = get_node_or_null(route_button_path) as Button
	_claim_btn = get_node_or_null(claim_button_path) as Button
	_open_btn = get_node_or_null(open_button_path) as Button
	_locked_label = get_node_or_null(locked_label_path) as Label
	_pending_label = get_node_or_null(pending_label_path) as Label
	_placeholder_popup = get_node_or_null(placeholder_popup_path) as PopupPanel
	_experiment_section = get_node_or_null(experiment_section_path) as Control
	_experiment_list = get_node_or_null(experiment_list_path) as VBoxContainer
	_research_section = get_node_or_null(research_section_path) as Control
	_research_list = get_node_or_null(research_list_path) as VBoxContainer
	if _detail_icon != null:
		_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if _route_btn != null:
		_route_btn.pressed.connect(_on_set_route_pressed)
	if _upgrade_btn != null:
		_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	if _claim_btn != null:
		_claim_btn.pressed.connect(_on_claim_pressed)
	if _open_btn != null:
		_open_btn.pressed.connect(_on_open_pressed)

func _apply_ui_scale() -> void:
	if _detail_icon != null:
		var icon_size = int(round(96.0 * _ui_scale))
		_detail_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_scale_label_font(_detail_name, 24)
	_scale_label_font(_detail_level, 16)
	_scale_label_font(_detail_desc, 16)
	_scale_label_font(_locked_label, 16)
	_scale_label_font(_pending_label, 16)

func _scale_label_font(label: Label, base_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", int(round(float(base_size) * _ui_scale)))

func _compute_panel_scale() -> float:
	var view = get_viewport_rect().size
	var content = Vector2(max(1.0, view.x - 200.0), max(1.0, view.y - 240.0))
	var ui_scale = min(content.x / CONTENT_BASE_SIZE.x, content.y / CONTENT_BASE_SIZE.y)
	return clamp(ui_scale, 0.9, 1.35)

func _apply_panel_textures() -> void:
	var panel_tex: Texture2D = load("res://assets/ui/new-elements/fondo-menus-edificios-laboratorio.png")
	if panel_tex == null:
		return
	if _background_panel != null:
		var background := StyleBoxTexture.new()
		background.texture = panel_tex
		background.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		background.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		_background_panel.add_theme_stylebox_override("panel", background)
		return
	if _left_panel != null:
		_left_panel.add_theme_stylebox_override("panel", _make_panel_style(panel_tex))
	if _right_panel != null:
		_right_panel.add_theme_stylebox_override("panel", _make_panel_style(panel_tex))

func _connect_backend() -> void:
	if _backend == null or _debug.unlock_all_buildings:
		return
	_backend.action_sent.connect(_on_action_sent)
	_backend.action_queued.connect(_on_action_queued)
	_backend.action_confirmed.connect(_on_action_confirmed)
	_backend.action_failed.connect(_on_action_failed)
	_backend.state_updated.connect(_on_state_updated)
	_backend.auth_changed.connect(_on_spell_auth_changed)
	_rebuild_pending_from_queue()
	if _backend.token != "":
		_backend.refresh_state()

func _load_state() -> void:
	_state = {}
	if _debug.unlock_all_buildings:
		_state = _debug.load_lab_state()
	elif _backend != null:
		_state = _backend.load_cached_state()
	if typeof(_state) != TYPE_DICTIONARY or _state.is_empty():
		_state = _default_state()
	_refresh_from_state()

func _default_state() -> Dictionary:
	return {
		"wallet": {},
		"research_flags": {},
		"lab": {
			"hqLevel": 1,
			"hqPath": HQ_PATHS[0],
			"buildings": {},
			"runtime": {"cooldowns": {}, "boosts": {}, "research": {}}
		}
	}

func _build_grid() -> void:
	if _grid == null or building_card_scene == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	for id in BUILDING_ORDER:
		var card: BuildingCard = building_card_scene.instantiate()
		_apply_card_scale(card)
		card.building_id = id
		card.pressed.connect(_on_card_pressed.bind(id))
		_grid.add_child(card)
		_cards[id] = card

func _apply_card_scale(card: BuildingCard) -> void:
	if card == null:
		return
	MenuArt.button(card)
	card.custom_minimum_size = Vector2(64, 64) * _ui_scale
	card.toggle_mode = true
	var content := card.get_node_or_null("HBox") as HBoxContainer
	if content:
		content.offset_left = 4
		content.offset_right = -4
		content.offset_top = 4
		content.offset_bottom = -4
		var labels := content.get_node_or_null("Text") as Control
		if labels:
			labels.hide()
	var icon_frame := card.get_node_or_null("HBox/IconFrame") as TextureRect
	if icon_frame != null:
		icon_frame.custom_minimum_size = Vector2(52, 52) * _ui_scale
	var name_label := card.get_node_or_null("HBox/Text/Name") as Label
	if name_label != null:
		name_label.add_theme_font_size_override("font_size", int(round(18.0 * _ui_scale)))
	var level_label := card.get_node_or_null("HBox/Text/Level") as Label
	if level_label != null:
		level_label.add_theme_font_size_override("font_size", int(round(14.0 * _ui_scale)))
	var pending_label := card.get_node_or_null("HBox/Text/Pending") as Label
	if pending_label != null:
		pending_label.add_theme_font_size_override("font_size", int(round(14.0 * _ui_scale)))
	var locked_label := card.get_node_or_null("HBox/Text/Locked") as Label
	if locked_label != null:
		locked_label.add_theme_font_size_override("font_size", int(round(14.0 * _ui_scale)))

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
		var icon_size = int(round(18.0 * _ui_scale))
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _catalog.get_tex(res_id)
		var label := Label.new()
		label.text = "0"
		label.add_theme_font_size_override("font_size", int(round(12.0 * _ui_scale)))
		row.add_child(icon)
		row.add_child(label)
		_resource_bar.add_child(row)
		_resource_rows[res_id] = {
			"row": row,
			"icon": icon,
			"label": label
		}

func _build_experiments() -> void:
	if _experiment_list == null:
		return
	for child in _experiment_list.get_children():
		child.queue_free()
	_experiment_rows.clear()
	_experiments = ExperimentCatalog.get_all()
	for entry in _experiments:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var exp_id = str(entry.get("id", "")).strip_edges()
		if exp_id == "":
			continue
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = str(entry.get("name", exp_id))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var start_btn := Button.new()
		start_btn.text = "Start"
		start_btn.pressed.connect(_on_start_experiment_pressed.bind(exp_id))
		header.add_child(name_label)
		header.add_child(start_btn)

		var desc_label := Label.new()
		desc_label.text = str(entry.get("desc", ""))
		if str(entry.get("kind", "")) == "convert":
			desc_label.text += " | Success: %d%% | Reward: %s" % [int(round(float(entry.get("success_chance", 1.0)) * 100)), str(entry.get("grants", {}))]
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 6)
		_populate_cost_row(cost_row, entry.get("cost", {}))

		var cooldown_label := Label.new()
		cooldown_label.text = ""

		row.add_child(header)
		row.add_child(desc_label)
		row.add_child(cost_row)
		row.add_child(cooldown_label)
		_experiment_list.add_child(row)

		_experiment_rows[exp_id] = {
			"button": start_btn,
			"cooldown": cooldown_label,
			"data": entry
		}

func _build_research() -> void:
	if _research_list == null:
		return
	for child in _research_list.get_children():
		child.queue_free()
	_research_rows.clear()
	var entries = _db.list_research()
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var research_id = str(entry.get("id", "")).strip_edges()
		if research_id == "":
			continue
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = str(entry.get("name", research_id))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var status_label := Label.new()
		status_label.text = ""
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)
		header.add_child(status_label)

		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 6)
		_populate_cost_row(cost_row, entry.get("cost", {}))

		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		var start_btn := Button.new()
		start_btn.text = "Start"
		start_btn.pressed.connect(_on_start_research_pressed.bind(research_id))
		var claim_btn := Button.new()
		claim_btn.text = "Claim"
		claim_btn.pressed.connect(_on_claim_research_pressed.bind(research_id))
		buttons.add_child(start_btn)
		buttons.add_child(claim_btn)

		row.add_child(header)
		var info := Label.new()
		info.text = "Time: %ss | Requires: %s | Flag: %s" % [int(entry.get("time_sec", 0)), _format_requirements(entry.get("requires", [])), str(entry.get("flag_id", research_id))]
		if str(entry.get("flag_id", research_id)) in RESEARCH_FLAG_ONLY:
			info.text += " | Additional effect: Coming Soon"
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		row.add_child(cost_row)
		row.add_child(buttons)
		_research_list.add_child(row)

		_research_rows[research_id] = {
			"start": start_btn,
			"claim": claim_btn,
			"status": status_label,
			"data": entry
		}

func _build_spell_section() -> void:
	if _right_panel == null:
		return
	var detail := _right_panel.get_node_or_null("Margin/DetailVBox") as VBoxContainer
	if detail == null:
		return
	_spell_section = VBoxContainer.new()
	_spell_section.name = "SpellSection"
	_spell_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spell_section.add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.text = "Spell Research"
	_spell_section.add_child(heading)
	_spell_entity_selector = OptionButton.new()
	var entity_ids := _spell_registry.entities.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity: Dictionary = _spell_registry.entities[entity_id]
		_spell_entity_selector.add_item("%s (%s)" % [entity.get("name", entity_id), str(entity.get("type", "")).capitalize()])
		_spell_entity_selector.set_item_metadata(_spell_entity_selector.item_count - 1, entity_id)
	_spell_entity_selector.item_selected.connect(_on_spell_entity_selected)
	_spell_section.add_child(_spell_entity_selector)
	var filters := HBoxContainer.new()
	var group := ButtonGroup.new()
	for kind in ["All", "Initial", "Hybrid", "Universal"]:
		var filter := Button.new()
		filter.text = kind
		filter.custom_minimum_size = Vector2(90, 32)
		filter.toggle_mode = true
		filter.button_group = group
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.05, 0.24, 0.21, 0.95) if state in ["pressed", "hover_pressed"] else Color(0.03, 0.1, 0.1, 0.95)
			style.border_color = Color(0.77, 0.62, 0.31) if state in ["pressed", "hover_pressed"] else Color(0.27, 0.44, 0.4)
			style.set_border_width_all(1)
			filter.add_theme_stylebox_override(state, style)
		filter.button_pressed = kind == "All"
		filter.pressed.connect(_set_spell_filter.bind(kind))
		filters.add_child(filter)
	_spell_section.add_child(filters)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_spell_list = VBoxContainer.new()
	_spell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_spell_list)
	_spell_section.add_child(scroll)
	detail.add_child(_spell_section)
	_build_spell_info()
	_build_spell_rows()

func _set_spell_filter(kind: String) -> void:
	_spell_filter = kind
	_build_spell_rows()
	_update_spell_section()

func _build_spell_info() -> void:
	_spell_info = Control.new()
	_spell_info.name = "SpellInfoOverlay"
	_spell_info.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spell_info.mouse_filter = Control.MOUSE_FILTER_STOP
	_spell_info.z_index = 100
	_spell_info.hide()
	add_child(_spell_info)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_info.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spell_info.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 400)
	panel.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup-grande.png", Vector4(60, 65, 60, 48)))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_spell_info_title = Label.new()
	_spell_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_info_title.add_theme_font_size_override("font_size", 22)
	header.add_child(_spell_info_title)
	var close := Button.new()
	close.text = "X"
	close.tooltip_text = "Close"
	close.custom_minimum_size = Vector2(45, 40)
	MenuArt.button(close)
	close.pressed.connect(_spell_info.hide)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_spell_info_text = Label.new()
	_spell_info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_spell_info_text)

func _show_spell_info(spell: Dictionary) -> void:
	_spell_info_title.text = str(spell.get("name", ""))
	_spell_info_text.text = SpellView.detail(spell, "Research")
	_spell_info.show()

func _spell_entity_id() -> String:
	if _spell_entity_selector == null or _spell_entity_selector.selected < 0:
		return ""
	return str(_spell_entity_selector.get_item_metadata(_spell_entity_selector.selected))

func _on_spell_entity_selected(_index: int) -> void:
	_build_spell_rows()
	_update_spell_section()

func _build_spell_rows() -> void:
	if _spell_list == null:
		return
	for child in _spell_list.get_children():
		_spell_list.remove_child(child)
		child.queue_free()
	_spell_rows.clear()
	var entity_id := _spell_entity_id()
	var entity: Dictionary = _spell_registry.entities.get(entity_id, {})
	var entity_type := str(entity.get("type", ""))
	var current_group := ""
	for spell in _spell_registry.get_researchable_spells_for_type(entity_type):
		var kind := str(spell.get("type", ""))
		if _spell_filter != "All" and SpellView.group(spell) != _spell_filter:
			continue
		var group := "Initial Spells" if kind == entity_type else ("Universal" if kind == "universal" else "Hybrid")
		if current_group != group:
			current_group = group
			var group_label := Label.new()
			group_label.text = group
			_spell_list.add_child(group_label)
		var row := VBoxContainer.new()
		var name_label := Label.new()
		var types := kind.capitalize()
		if kind == "hybrid":
			types = "%s / %s" % [str(spell.get("primary_type", "")).capitalize(), str(spell.get("secondary_type", "")).capitalize()]
		name_label.text = "%s  |  %s" % [spell.name, types]
		name_label.add_theme_font_size_override("font_size", 18)
		row.add_child(name_label)
		var actions := HBoxContainer.new()
		var status := Label.new()
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		actions.add_child(status)
		var info := Button.new()
		info.text = "i"
		info.tooltip_text = "Spell details"
		info.custom_minimum_size = Vector2(38, 34)
		MenuArt.button(info)
		info.pressed.connect(_show_spell_info.bind(spell))
		actions.add_child(info)
		var button := Button.new()
		button.text = "Research"
		button.custom_minimum_size = Vector2(110, 34)
		MenuArt.button(button)
		button.pressed.connect(_on_spell_research_pressed.bind(str(spell.id)))
		actions.add_child(button)
		row.add_child(actions)
		_spell_list.add_child(row)
		_spell_rows[str(spell.id)] = {"spell": spell, "status": status, "button": button}

func _update_spell_section() -> void:
	if _spell_section == null:
		return
	_spell_section.visible = _selected_id == "ultrahit_tower"
	if not _spell_section.visible:
		return
	var entity_id := _spell_entity_id()
	var progress: Dictionary = _state.get("spell_progress", {})
	var learned: Array = progress.get("learned_by_entity", {}).get(entity_id, [])
	var active: Variant = progress.get("active_research")
	if not active is Dictionary:
		active = {}
	var now := int(Time.get_unix_time_from_system() * 1000) + (0 if _debug.unlock_all_buildings else _spell_server_offset_ms)
	var pending := _is_pending_building("ultrahit_tower")
	for id in _spell_rows:
		var row: Dictionary = _spell_rows[id]
		var spell: Dictionary = row.spell
		var status: Label = row.status
		var button: Button = row.button
		button.text = "Research"
		button.disabled = true
		if spell.get("type", "") not in ["universal", "hybrid"]:
			status.text = "Available (initial)"
		elif id in learned:
			status.text = "Learned"
		elif not active.is_empty():
			if active.get("entity_id") == entity_id and active.get("spell_id") == id:
				var remaining := maxi(0, int(active.get("completes_at", 0)) - now)
				status.text = "Researching: %s" % _format_seconds(remaining) if remaining > 0 else "Ready to claim"
				button.text = "Claim"
				button.disabled = pending or remaining > 0
			else:
				status.text = "Locked: another spell is being researched"
		elif not _debug.unlock_all_buildings and _get_building_level("ultrahit_tower") < int(spell.tower_level_required):
			status.text = "Locked: Spell Tower level %d required" % int(spell.tower_level_required)
		elif not _can_afford(spell.research_cost):
			status.text = "Locked: insufficient resources"
		else:
			status.text = "Researchable" if not _debug.unlock_all_buildings else "Researchable (local debug: 1s)"
			button.disabled = pending
		if not _debug.unlock_all_buildings and (_backend == null or _backend.token == ""):
			if not button.disabled:
				status.text = "Locked: backend sign-in required"
			button.disabled = true
		elif not _debug.unlock_all_buildings and not _spell_state_synced:
			if not button.disabled:
				status.text = "Locked: awaiting server state"
			button.disabled = true

func _on_spell_research_pressed(spell_id: String) -> void:
	if not _spell_rows.has(spell_id) or _spell_rows[spell_id].button.disabled:
		return
	var entity_id := _spell_entity_id()
	var active: Variant = _state.get("spell_progress", {}).get("active_research")
	var action_type := "CLAIM_SPELL_RESEARCH" if active is Dictionary and active.get("entity_id") == entity_id and active.get("spell_id") == spell_id else "START_SPELL_RESEARCH"
	_send_action({"action_type": action_type, "payload": {"building_id": "ultrahit_tower", "entity_id": entity_id, "spell_id": spell_id}}, "ultrahit_tower")

func _select_default() -> void:
	var focus_id := SceneRouter.consume_lab_focus_id()
	if focus_id != "" and BUILDING_ORDER.has(focus_id):
		_select_building(focus_id)
		return
	if BUILDING_ORDER.size() > 0:
		_select_building(BUILDING_ORDER[0])

func _select_building(building_id: String) -> void:
	_selected_id = building_id
	for id in _cards:
		_cards[id].button_pressed = id == building_id
	_update_detail()

func _refresh_from_state() -> void:
	_update_cards()
	_update_detail()
	_update_resource_bar()

func _update_cards() -> void:
	for id in BUILDING_ORDER:
		var card: BuildingCard = _cards.get(id, null)
		if card == null:
			continue
		var display_name = _get_building_name(id)
		var level = _get_building_level(id)
		var icon = _get_building_icon(id)
		card.set_icon_frame(load(MenuArt.DIR + "marco-slot-small.png"))
		card.set_icon(icon)
		card.set_title(display_name)
		card.set_level(level)
		card.tooltip_text = "%s - Lv %d" % [display_name, level]
		var unlock_level = _get_unlock_level(id)
		var locked = _get_hq_level() < unlock_level
		if _debug.unlock_all_buildings:
			locked = false
		card.set_locked(locked, unlock_level)
		card.set_pending(_is_pending_building(id))

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

func _update_detail() -> void:
	if _selected_id == "":
		return
	if _detail_name != null:
		_detail_name.text = _get_building_name(_selected_id)
	if _detail_desc != null:
		var desc = _get_building_desc(_selected_id)
		if _selected_id == "essence_reactor" and _backend != null and _backend.get_server_time_unix_ms() < 0:
			desc += "\nUnverified Offline (backend offline; estimates capped to 1h)."
		_detail_desc.text = desc
	if _detail_level != null:
		_detail_level.text = "Level %s" % _get_building_level(_selected_id)
	if _detail_icon != null:
		_detail_icon.texture = _get_building_icon(_selected_id)
	var unlock_level = _get_unlock_level(_selected_id)
	var locked = _get_hq_level() < unlock_level
	if _debug.unlock_all_buildings:
		locked = false
	if _locked_label != null:
		_locked_label.visible = locked
		_locked_label.text = "Unlock at HQ Lv %s" % unlock_level
	if _pending_label != null:
		var is_pending := _is_pending_building(_selected_id)
		_pending_label.visible = is_pending or (_action_message_building == _selected_id and _action_message != "")
		_pending_label.text = "Action pending server confirmation." if is_pending else _action_message
	_update_routes()
	_update_costs()
	_update_buttons()
	_update_experiments()
	_update_research()
	_update_spell_section()
	if _specialized_panel != null:
		var names := {}
		for id in BUILDING_ORDER:
			names[id] = _get_building_name(id)
		var metrics := {}
		if _selected_id == "essence_reactor":
			metrics["rate"] = _get_reactor_rate_per_hour()
			metrics["stored"] = _state.get("lab", {}).get("buildings", {}).get("essence_reactor", {}).get("runtime", {}).get("stored_output", 0)
		elif _selected_id == "storage_vault":
			var level := _get_building_level("storage_vault")
			var route := _get_building_route("storage_vault")
			var hq_path := _get_building_route("lab_th")
			metrics["capacity"] = Capacity.compute_total_capacity(level, route, hq_path, _db.balance)
			metrics["next_capacity"] = Capacity.compute_total_capacity(level + 1, route, hq_path, _db.balance) if level < HqRules.get_max_level("storage_vault") else "MAX"
		_specialized_panel.show_building(_selected_id, _state, names, metrics, _spell_state_synced)

func _update_routes() -> void:
	if _route_option == null:
		return
	_route_option.clear()
	var options: Array = []
	if _selected_id == "lab_th":
		options = HQ_PATHS
	elif _selected_id == "essence_reactor":
		options = REACTOR_ROUTES
	elif _selected_id == "storage_vault":
		options = STORAGE_ROUTES
	if _route_option.get_parent() is Control:
		_route_option.get_parent().visible = not options.is_empty()
	if options.is_empty():
		_route_option.disabled = true
		return
	_route_option.disabled = false
	for opt in options:
		_route_option.add_item(opt)
	var current = _get_building_route(_selected_id)
	var idx = 0
	for i in range(options.size()):
		if options[i].to_lower() == current.to_lower():
			idx = i
			break
	_route_option.select(idx)

func _update_costs() -> void:
	if _cost_list == null:
		return
	for child in _cost_list.get_children():
		child.queue_free()
	var cost = _get_upgrade_cost(_selected_id)
	if cost.is_empty():
		var label := Label.new()
		label.text = "No cost data"
		_cost_list.add_child(label)
		return
	for key in cost.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var slot := UIThemeFactory.make_icon_slot()
		var slot_size = int(round(28.0 * _ui_scale))
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		var icon = slot.get_node_or_null("Icon")
		if icon is TextureRect:
			icon.texture = _catalog.get_tex(key)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var amount := Label.new()
		amount.text = str(cost[key])
		row.add_child(slot)
		row.add_child(amount)
		_cost_list.add_child(row)

func _populate_cost_row(container: HBoxContainer, cost: Variant) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	if typeof(cost) != TYPE_DICTIONARY or cost.is_empty():
		var label := Label.new()
		label.text = "No cost"
		container.add_child(label)
		return
	for key in cost.keys():
		var row_slot := UIThemeFactory.make_icon_slot()
		var slot_size = int(round(24.0 * _ui_scale))
		row_slot.custom_minimum_size = Vector2(slot_size, slot_size)
		var icon = row_slot.get_node_or_null("Icon")
		if icon is TextureRect:
			icon.texture = _catalog.get_tex(str(key))
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var amount := Label.new()
		amount.text = str(cost[key])
		container.add_child(row_slot)
		container.add_child(amount)

func _update_buttons() -> void:
	var locked = _get_hq_level() < _get_unlock_level(_selected_id)
	if _debug.unlock_all_buildings:
		locked = false
	var pending = _is_pending_building(_selected_id)
	var cost = _get_upgrade_cost(_selected_id)
	var cost_ok = not cost.is_empty() and _can_afford(cost)
	var can_upgrade = HqRules.can_upgrade(_selected_id, _get_building_level(_selected_id), _get_hq_level())
	if _debug.unlock_all_buildings:
		cost_ok = true
		can_upgrade = _get_building_level(_selected_id) < HqRules.get_max_level(_selected_id)
	if _upgrade_btn != null:
		_upgrade_btn.disabled = locked or pending or not cost_ok or not can_upgrade
	if _route_btn != null:
		_route_btn.visible = _selected_id in ["lab_th", "essence_reactor", "storage_vault"]
		_route_btn.disabled = locked or pending or _route_option == null or _route_option.item_count == 0
	if _claim_btn != null:
		_claim_btn.visible = _selected_id == "essence_reactor"
		_claim_btn.text = "Collect"
		_claim_btn.disabled = pending or _selected_id != "essence_reactor"
	if _open_btn != null:
		_open_btn.visible = GATE_BUILDINGS.has(_selected_id)
		_open_btn.text = "Enter World Gate" if _selected_id == "world_gate" else ("Open Trade Hall" if _selected_id == "trade_hall" else "Open")
		_open_btn.disabled = pending or not GATE_BUILDINGS.has(_selected_id)

func _update_experiments() -> void:
	if _experiment_section != null:
		_experiment_section.visible = _selected_id == "experiment_chamber"
	if _selected_id != "experiment_chamber":
		return
	var runtime = _get_lab_runtime()
	var cooldowns = runtime.get("cooldowns", {})
	var boosts = runtime.get("boosts", {})
	var now_ms = Time.get_unix_time_from_system() * 1000
	var unlock_level = _get_unlock_level("experiment_chamber")
	var locked = _get_hq_level() < unlock_level or _get_building_level("experiment_chamber") <= 0
	if _debug.unlock_all_buildings:
		locked = false
	var pending = _is_pending_building("experiment_chamber")
	for exp_id in _experiment_rows.keys():
		var row = _experiment_rows.get(exp_id, {})
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var data = row.get("data", {})
		var button: Button = row.get("button", null)
		var label: Label = row.get("cooldown", null)
		var cooldown_end = _get_time_value(cooldowns, str(exp_id))
		var remaining = max(0, cooldown_end - now_ms)
		var text := ""
		if locked:
			text = "Unlock at HQ Lv %s" % unlock_level
		elif remaining > 0:
			text = "Cooldown: %s" % _format_seconds(remaining)
		else:
			text = "Ready"
		var boost_id = str(data.get("boost_id", ""))
		if boost_id != "":
			var boost_end = _get_time_value(boosts, boost_id)
			var boost_remaining = max(0, boost_end - now_ms)
			if boost_remaining > 0:
				text += " | Boost: %s" % _format_seconds(boost_remaining)
		if _debug.unlock_all_buildings:
			var last_result = runtime.get("debug_results", {}).get(str(exp_id), "")
			if last_result == "Boost active" and boost_id != "" and _get_time_value(boosts, boost_id) <= now_ms:
				last_result = "Boost expired"
			if last_result != "":
				text += " | " + str(last_result)
		if label != null:
			label.text = text
		if button != null:
			var cost = data.get("cost", {})
			var can_afford = _can_afford(cost)
			button.disabled = locked or pending or remaining > 0 or not can_afford

func _update_research() -> void:
	if _research_section != null:
		_research_section.visible = _selected_id == "arcane_archives"
	if _selected_id != "arcane_archives":
		return
	var runtime = _get_lab_runtime()
	var research_runtime = runtime.get("research", {})
	if typeof(research_runtime) != TYPE_DICTIONARY:
		research_runtime = {}
	var active_id = str(research_runtime.get("active_id", ""))
	var completes_at = int(research_runtime.get("completes_at", 0))
	var now_ms = Time.get_unix_time_from_system() * 1000
	var flags = _get_research_flags()
	var unlock_level = _get_unlock_level("arcane_archives")
	var locked = _get_hq_level() < unlock_level or _get_building_level("arcane_archives") <= 0
	if _debug.unlock_all_buildings:
		locked = false
	var pending = _is_pending_building("arcane_archives")
	for research_id in _research_rows.keys():
		var row = _research_rows.get(research_id, {})
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var data = row.get("data", {})
		var start_btn: Button = row.get("start", null)
		var claim_btn: Button = row.get("claim", null)
		var status: Label = row.get("status", null)
		var flag_id = str(data.get("flag_id", research_id))
		var requirements = data.get("requires", [])
		var text := ""
		var can_start := true
		var can_claim := false
		if locked:
			text = "Unlock at HQ Lv %s" % unlock_level
			can_start = false
		elif bool(flags.get(flag_id, false)):
			text = "Completed"
			can_start = false
		elif active_id != "":
			if active_id == research_id:
				if completes_at <= now_ms:
					text = "Ready to claim"
					can_claim = true
				else:
					text = "In progress: %s" % _format_seconds(completes_at - now_ms)
				can_start = false
			else:
				text = "Research in progress"
				can_start = false
		else:
			if not _debug.unlock_all_buildings and not _requirements_met(requirements, flags):
				text = "Requires: %s" % _format_requirements(requirements)
				can_start = false
			elif not _can_afford(data.get("cost", {})):
				text = "Insufficient resources"
				can_start = false
			else:
				text = "Ready"
		if status != null:
			status.text = text
		if start_btn != null:
			start_btn.disabled = locked or pending or not can_start
		if claim_btn != null:
			claim_btn.disabled = locked or pending or not can_claim

func _on_card_pressed(building_id: String) -> void:
	_select_building(building_id)

func _on_upgrade_pressed() -> void:
	if _selected_id == "":
		return
	var action = {
		"action_type": "UPGRADE_BUILDING",
		"payload": {"building_id": _selected_id}
	}
	_send_action(action, _selected_id)

func _on_set_route_pressed() -> void:
	if _selected_id == "" or _route_option == null or _route_option.item_count == 0:
		return
	var route = _route_option.get_item_text(_route_option.selected)
	var action = {
		"action_type": "SET_BUILDING_ROUTE",
		"payload": {"building_id": _selected_id, "route": route}
	}
	_send_action(action, _selected_id)

func _on_claim_pressed() -> void:
	if _selected_id != "essence_reactor":
		return
	var action = {
		"action_type": "CLAIM_PRODUCTION",
		"payload": {"building_id": "essence_reactor"}
	}
	_send_action(action, "essence_reactor")

func _on_start_experiment_pressed(experiment_id: String) -> void:
	if experiment_id == "":
		return
	var action = {
		"action_type": "START_EXPERIMENT",
		"payload": {"experiment_id": experiment_id, "building_id": "experiment_chamber"}
	}
	_send_action(action, "experiment_chamber")

func _on_start_research_pressed(research_id: String) -> void:
	if research_id == "":
		return
	var action = {
		"action_type": "START_RESEARCH",
		"payload": {"research_id": research_id, "building_id": "arcane_archives"}
	}
	_send_action(action, "arcane_archives")

func _on_claim_research_pressed(research_id: String) -> void:
	if research_id == "":
		return
	var action = {
		"action_type": "CLAIM_RESEARCH",
		"payload": {"research_id": research_id, "building_id": "arcane_archives"}
	}
	_send_action(action, "arcane_archives")

func _on_open_pressed() -> void:
	if not GATE_BUILDINGS.has(_selected_id):
		return
	if _selected_id == "trade_hall":
		SceneRouter.go_to_trade_hall()
		return
	if _selected_id == "world_gate":
		SceneRouter.go_to_world_gate()
		return
	if _placeholder_popup != null:
		_placeholder_popup.popup_centered()

func _send_action(action: Dictionary, building_id: String) -> void:
	if _debug.unlock_all_buildings:
		if not _debug.lab_cooldown_active(_state, building_id):
			_simulate_debug_action(action)
		return
	if _backend == null:
		return
	var action_id = _backend.send_action(action)
	if action_id == "":
		return
	_mark_pending(building_id, action_id)

func _simulate_debug_action(action: Dictionary) -> void:
	if typeof(action) != TYPE_DICTIONARY:
		return
	var action_type = str(action.get("action_type", ""))
	var payload = action.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}
	var building_id = str(payload.get("building_id", ""))
	var previous = _state.duplicate(true)
	match action_type:
		"UPGRADE_BUILDING":
			if building_id == "" or _get_building_level(building_id) >= HqRules.get_max_level(building_id):
				return
			_debug_upgrade_building(building_id)
		"SET_BUILDING_ROUTE":
			_debug_set_route(building_id, str(payload.get("route", "")))
		"CLAIM_PRODUCTION":
			if building_id != "essence_reactor" or _debug.claim_lab_production(_state, _db).is_empty():
				return
		"START_SPELL_RESEARCH", "CLAIM_SPELL_RESEARCH":
			var entity_id := str(payload.get("entity_id", ""))
			var spell_id := str(payload.get("spell_id", ""))
			var entity: Dictionary = _spell_registry.entities.get(entity_id, {})
			var spell := _spell_registry.get_spell_by_id(spell_id)
			if entity.is_empty() or spell.is_empty() or spell.get("type", "") not in ["universal", "hybrid"] or str(entity.get("type", "")) not in spell.get("eligible_types", []):
				return
			var progress: Dictionary = _state.get("spell_progress", {})
			var learned: Dictionary = progress.get("learned_by_entity", {})
			var owned: Array = learned.get(entity_id, [])
			var active: Variant = progress.get("active_research")
			if action_type == "START_SPELL_RESEARCH":
				if spell_id in owned or owned.size() >= 20 or (active is Dictionary and not active.is_empty()):
					return
				var now := int(Time.get_unix_time_from_system() * 1000)
				progress["active_research"] = {"entity_id": entity_id, "spell_id": spell_id, "started_at": now, "completes_at": now + 1000}
			else:
				if spell_id in owned:
					return
				if not active is Dictionary or active.get("entity_id") != entity_id or active.get("spell_id") != spell_id or int(active.get("completes_at", 0)) > int(Time.get_unix_time_from_system() * 1000):
					return
				owned.append(spell_id)
				learned[entity_id] = owned
				progress["learned_by_entity"] = learned
				progress["active_research"] = null
			_state["spell_progress"] = progress
		"START_EXPERIMENT", "START_RESEARCH", "CLAIM_RESEARCH":
			var lab = _state.get("lab", {})
			var runtime = lab.get("runtime", {})
			if action_type == "START_EXPERIMENT":
				var experiment_id = str(payload.get("experiment_id", ""))
				var experiment = ExperimentCatalog.get_by_id(experiment_id)
				if experiment.is_empty():
					return
				var cooldowns = runtime.get("cooldowns", {})
				if int(cooldowns.get(experiment_id, 0)) > int(Time.get_unix_time_from_system() * 1000):
					return
				cooldowns[experiment_id] = int(Time.get_unix_time_from_system() * 1000) + 1000
				runtime["cooldowns"] = cooldowns
				var results: Dictionary = runtime.get("debug_results", {})
				if str(experiment.get("kind", "")) == "boost":
					var boosts = runtime.get("boosts", {})
					boosts[str(experiment.get("boost_id", ""))] = {"expires_at": int(Time.get_unix_time_from_system() * 1000) + int(experiment.get("boost_duration_s", 0)) * 1000}
					runtime["boosts"] = boosts
					results[experiment_id] = "Boost active"
				elif randf() < float(experiment.get("success_chance", 1.0)):
					var wallet = _state.get("wallet", {})
					for resource in experiment.get("grants", {}):
						wallet[resource] = int(wallet.get(resource, 0)) + int(experiment.grants[resource])
					_state["wallet"] = wallet
					results[experiment_id] = "Reward: %s" % str(experiment.get("grants", {}))
				else:
					results[experiment_id] = "Experiment failed; no reward"
				runtime["debug_results"] = results
			else:
				var research_id = str(payload.get("research_id", ""))
				var research = _db.get_research(research_id)
				if research.is_empty():
					return
				if action_type == "START_RESEARCH":
					if bool(_state.get("research_flags", {}).get(str(research.get("flag_id", research_id)), false)) or not runtime.get("research", {}).get("active_id", "").is_empty():
						return
					var now = int(Time.get_unix_time_from_system() * 1000)
					runtime["research"] = {"active_id": research_id, "started_at": now, "completes_at": now + 1000}
				else:
					var active = runtime.get("research", {})
					if str(active.get("active_id", "")) != research_id or int(active.get("completes_at", 0)) > int(Time.get_unix_time_from_system() * 1000):
						return
					var flags = _state.get("research_flags", {})
					flags[str(research.get("flag_id", research_id))] = true
					_state["research_flags"] = flags
					runtime["research"] = {}
			lab["runtime"] = runtime
			_state["lab"] = lab
		_:
			return
	_debug.start_lab_cooldown(_state, building_id)
	_action_message_building = building_id
	if not _debug.save_lab_state(_state):
		_state = previous
		_action_message = "Could not save local debug state."
	else:
		_action_message = "Local debug action saved."
	_refresh_from_state()
	get_tree().create_timer(1.0).timeout.connect(_refresh_from_state, CONNECT_ONE_SHOT)

func _debug_upgrade_building(building_id: String) -> void:
	if building_id == "":
		return
	if building_id == "lab_th":
		var lvl = _get_hq_level()
		_state["lab"]["hqLevel"] = lvl + 1
		return
	var lab = _state.get("lab", {})
	if typeof(lab) != TYPE_DICTIONARY:
		return
	var buildings = lab.get("buildings", {})
	if typeof(buildings) != TYPE_DICTIONARY:
		buildings = {}
	var entry = buildings.get(building_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		entry = {}
	entry["level"] = int(entry.get("level", 0)) + 1
	if building_id == "essence_reactor" and not entry.has("runtime"):
		entry["runtime"] = {"stored_output": 0.0, "last_tick": int(Time.get_unix_time_from_system() * 1000)}
	buildings[building_id] = entry
	lab["buildings"] = buildings
	_state["lab"] = lab

func _debug_set_route(building_id: String, route: String) -> void:
	if building_id == "":
		return
	if building_id == "lab_th":
		_state["lab"]["hqPath"] = route
		return
	var lab = _state.get("lab", {})
	if typeof(lab) != TYPE_DICTIONARY:
		return
	var buildings = lab.get("buildings", {})
	if typeof(buildings) != TYPE_DICTIONARY:
		buildings = {}
	var entry = buildings.get(building_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		entry = {}
	entry["route"] = route
	buildings[building_id] = entry
	lab["buildings"] = buildings
	_state["lab"] = lab

func _mark_pending(building_id: String, action_id: String) -> void:
	if building_id == "" or action_id == "":
		return
	_pending_by_id[building_id] = true
	_pending_action_to_building[action_id] = building_id
	_update_cards()
	_update_detail()

func _clear_pending(action_id: String) -> void:
	if not _pending_action_to_building.has(action_id):
		return
	var building_id = _pending_action_to_building[action_id]
	_pending_action_to_building.erase(action_id)
	_pending_by_id.erase(building_id)
	_update_cards()
	_update_detail()

func _on_action_sent(action_id: String, action_key: String) -> void:
	# Already marked pending in _send_action; keep for safety.
	if action_id != "" and not _pending_action_to_building.has(action_id):
		var building_id = _resolve_building_from_key(action_key)
		_mark_pending(building_id, action_id)

func _on_action_queued(action_id: String, action_key: String, _reason: String) -> void:
	if action_id != "" and not _pending_action_to_building.has(action_id):
		var building_id = _resolve_building_from_key(action_key)
		_mark_pending(building_id, action_id)

func _on_action_confirmed(action_id: String) -> void:
	if _pending_action_to_building.has(action_id):
		_action_message_building = str(_pending_action_to_building[action_id])
		_action_message = "Action confirmed by server; check updated resources and state."
	_clear_pending(action_id)

func _on_action_failed(action_id: String, error: String) -> void:
	if _pending_action_to_building.has(action_id):
		_action_message_building = str(_pending_action_to_building[action_id])
		_action_message = "Action rejected: " + error
	_clear_pending(action_id)

func _on_state_updated(state: Dictionary) -> void:
	if _debug.unlock_all_buildings:
		return
	if _backend != null and _backend.get_server_time_unix_ms() >= 0:
		_spell_server_offset_ms = _backend.get_server_time_unix_ms() - int(Time.get_unix_time_from_system() * 1000)
		_spell_state_synced = true
	_state = state
	_refresh_from_state()

func _on_spell_auth_changed(token: String) -> void:
	_spell_state_synced = false
	if token != "" and _backend != null:
		_backend.request_api("GET", "/player/state", null, true)
	_update_spell_section()

func _rebuild_pending_from_queue() -> void:
	if _backend == null:
		return
	var actions = _backend.get_pending_actions()
	_pending_by_id.clear()
	_pending_action_to_building.clear()
	for entry in actions:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var action_id = str(entry.get("client_action_id", ""))
		var action_key = _make_action_key(entry)
		var building_id = _resolve_building_from_key(action_key)
		if building_id != "" and action_id != "":
			_pending_by_id[building_id] = true
			_pending_action_to_building[action_id] = building_id

func _resolve_building_from_key(action_key: String) -> String:
	var parts = action_key.split(":")
	if parts.size() >= 2:
		return parts[1]
	return ""

func _make_action_key(action: Dictionary) -> String:
	var action_type = str(action.get("action_type", ""))
	if action_type == "":
		return ""
	var payload = action.get("payload", {})
	var key = action_type
	if typeof(payload) == TYPE_DICTIONARY and payload.has("building_id"):
		key += ":" + str(payload.get("building_id"))
	return key

func _get_lab_runtime() -> Dictionary:
	var lab = _state.get("lab", {})
	if typeof(lab) != TYPE_DICTIONARY:
		return {"cooldowns": {}, "boosts": {}}
	var runtime = lab.get("runtime", {})
	if typeof(runtime) != TYPE_DICTIONARY:
		return {"cooldowns": {}, "boosts": {}}
	if typeof(runtime.get("cooldowns", {})) != TYPE_DICTIONARY:
		runtime["cooldowns"] = {}
	if typeof(runtime.get("boosts", {})) != TYPE_DICTIONARY:
		runtime["boosts"] = {}
	if typeof(runtime.get("research", {})) != TYPE_DICTIONARY:
		runtime["research"] = {}
	return runtime

func _get_research_flags() -> Dictionary:
	var flags = _state.get("research_flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		return {}
	return flags

func _get_time_value(container: Variant, key: String) -> int:
	if typeof(container) != TYPE_DICTIONARY:
		return 0
	var value = container.get(key, 0)
	if typeof(value) == TYPE_DICTIONARY:
		return int(value.get("expires_at", 0))
	return int(value)

func _can_afford(cost: Variant) -> bool:
	if _debug.unlock_all_buildings:
		return true
	if typeof(cost) != TYPE_DICTIONARY:
		return true
	var wallet = _state.get("wallet", {})
	if typeof(wallet) != TYPE_DICTIONARY:
		return false
	for key in cost.keys():
		var needed = int(cost.get(key, 0))
		var have = int(wallet.get(key, 0))
		if have < needed:
			return false
	return true

func _format_seconds(ms: float) -> String:
	var total = int(ceil(ms / 1000.0))
	if total < 0:
		total = 0
	var minutes = int(total / 60.0)
	var seconds = total % 60
	if minutes > 0:
		return "%dm %02ds" % [minutes, seconds]
	return "%ds" % total

func _requirements_met(requires: Variant, flags: Dictionary) -> bool:
	if typeof(requires) != TYPE_ARRAY:
		return true
	for req in requires:
		if typeof(req) != TYPE_STRING:
			continue
		if not bool(flags.get(req, false)):
			return false
	return true

func _format_requirements(requires: Variant) -> String:
	if typeof(requires) != TYPE_ARRAY or requires.is_empty():
		return "-"
	var names: Array = []
	for req in requires:
		if typeof(req) == TYPE_STRING:
			names.append(req)
	return ", ".join(names)

func _is_pending_building(building_id: String) -> bool:
	if _debug.unlock_all_buildings:
		return _debug.lab_cooldown_active(_state, building_id)
	return _pending_by_id.has(building_id)

func _get_building_level(building_id: String) -> int:
	if building_id == "lab_th":
		return _get_hq_level()
	var lab = _state.get("lab", {})
	var buildings = lab.get("buildings", {})
	var entry = buildings.get(building_id, {})
	return int(entry.get("level", 0))

func _get_building_route(building_id: String) -> String:
	if building_id == "lab_th":
		return str(_state.get("lab", {}).get("hqPath", HQ_PATHS[0]))
	var lab = _state.get("lab", {})
	var buildings = lab.get("buildings", {})
	var entry = buildings.get(building_id, {})
	return str(entry.get("route", ""))

func _get_unlock_level(building_id: String) -> int:
	var data = _db.get_building(building_id)
	if typeof(data) == TYPE_DICTIONARY and data.has("unlock_hq"):
		return int(data.get("unlock_hq", 1))
	return HqRules.get_unlock_level(building_id)

func _get_hq_level() -> int:
	return int(_state.get("lab", {}).get("hqLevel", 1))

func _get_building_name(building_id: String) -> String:
	var data = _db.get_building(building_id)
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("display_name"):
			return str(data.get("display_name", building_id))
		if data.has("name"):
			return str(data.get("name", building_id))
	return building_id

func _get_building_desc(building_id: String) -> String:
	match building_id:
		"lab_th":
			return "Unlock new structures and increase caps."
		"essence_reactor":
			return "Generates Essence over time."
		"storage_vault":
			return "Increases storage capacity."
		"build_forge":
			return "Creates experimental constructs."
		"homunculus_vat":
			return "Grows homunculi for specialized tasks."
		"ultrahit_tower":
			return "View the spells available to your entities."
		"experiment_chamber":
			return "Enables advanced experiments."
		"arcane_archives":
			return "Stores arcane knowledge and tomes."
		"sync_nexus":
			return "Synchronizes lab networks."
		"anomaly_containment":
			return "Contains unstable anomalies."
		"trade_hall":
			return "Facilitates rare exchanges."
		"world_gate":
			return "Opens access to distant realms."
		_:
			return ""

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

func _get_upgrade_cost(building_id: String) -> Dictionary:
	var data = _db.get_building(building_id)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var buildings := {building_id: data}
	var balance := {"hq_cost_mult": _db.get_balance("hq_cost_mult", CostResolver.DEFAULT_HQ_COST_MULT)}
	var resolver := CostResolver.new(buildings, balance)
	var result = resolver.resolve_upgrade_cost(building_id, _get_building_level(building_id), _get_hq_level(), _get_building_route("lab_th"))
	return result.get("cost", {})

func _get_building_icon(building_id: String) -> Texture2D:
	var icon_id = building_id
	if building_id == "lab_th":
		icon_id = "lab_th"
	return _catalog.get_tex(icon_id)

func _make_panel_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	UIThemeFactory._configure_stylebox(sb)
	return sb

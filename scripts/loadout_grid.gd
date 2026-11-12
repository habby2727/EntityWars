extends Control

## Loadout screen (Attack/Defense seals).
## Nodes are resolved by explicit scene paths to avoid %UniqueName shorthand.

const REG_PATH := "res://scripts/data_registry.gd"
const SpellLoadout := preload("res://scripts/domain/spell_loadout.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const SpellView := preload("res://scripts/ui/spell_presentation.gd")
const LockIndicator := preload("res://scripts/ui/lock_indicator.gd")
const PREVIEW_256_DIR := "res://assets/entities/previews_256/"
const HOM_PREVIEW_256_DIR := "res://assets/entities/previews_256/homunculus/"
const BUILD_DIR := "res://assets/entities/builds/"
const ITEM_ICON_MAP := {
	"bismuth_talisman": "talisman_bismuth.png",
	"wind_amulet": "wind_amulet.png",
	"saltstone_charm": "saltstone_charm.png",
	"mirror_sigel": "mirror.png",
	"vitriol_vial": "vitriol.png",
	"gilded_scale": "gilded_scale.png",
	"mercury_lens": "mercury_lens.png",
	"aether_knot": "aether_knot.png",
}
const HOM_PREVIEW_STEMS := ["chimera", "cinder", "drakon", "pyritc", "silphide", "sodium", "nighty", "mothy"]
const HOM_PREVIEW_MAP := {
	"cinder": "cinder",
	"silphide": "silphide",
	"sodium": "sodium",
	"drakon": "drakon",
	"pyritc": "pyritc",
	"chimera": "chimera",
	"nighty": "nighty",
	"mothy": "mothy",
}

@export var use_attack_dark_defense_light: bool = true
@export var spell_backend_url := "http://127.0.0.1:8787"

var tab_entities: Control = null
var tab_homunculi: Control = null
var tabs: TabContainer = null
var btn_tab_entities: Button = null
var btn_tab_homunculi: Button = null

var grid_entities: GridContainer = null
var grid_homunculi: GridContainer = null

var btn_seal_attack: BaseButton = null
var btn_seal_defense: BaseButton = null
var btn_save: Button = null
var btn_play: Button = null

var lbl_title: Label = null
var lbl_name: Label = null
var lbl_mode: Label = null
var lbl_homunculus: Label = null
var lbl_types: Label = null
var lbl_base: Label = null
var lbl_desc: RichTextLabel = null
var lbl_build_error: Label = null
var preview: TextureRect = null
var hom_preview: TextureRect = null
var tooltip_panel: PanelContainer = null
var tooltip_icon: TextureRect = null
var tooltip_label: Label = null

var dd_item1: Button = null
var dd_item2: Button = null
var dd_side1: Button = null
var dd_side2: Button = null
var dd_atktech: Button = null
var dd_deftech: Button = null

var _reg: Object = null

var _entities: Array = []
var _homunculi: Array = []
var _items: Array = []
var _atk_techs: Array = []
var _def_techs: Array = []

var _current_entity_id: String = ""
var _current_homunculus_id: String = ""

var _mode: String = "attack" # "attack" or "defense"
var _has_saved: bool = false
var _spell_debug := DebugFlags.new()

func _exit_tree() -> void:
	_spell_debug.free()
	if is_instance_valid(_reg):
		_reg.free()
var _spell_backend: BackendClient
var _spell_state := {}
var _spell_synced := false
var _spell_pending_id := ""
var _spell_pending_mode := ""
var _spell_pending_entity := ""
var _spell_button: Button
var _spell_dialog: Control
var _spell_slots: Array[Button] = []
var _spell_description: Label
var _spell_draft: Array = []
var _spell_confirm: Button
var _spell_catalog: VBoxContainer
var _spell_heading: Label
var _spell_filter := "All"
var _spell_selected_slot := 0

func _resolve_nodes() -> void:
	# Bind to concrete paths in LoadoutGrid.tscn
	if tab_entities == null:
		tab_entities = get_node_or_null("RootMargin/MainHSplit/LeftPanel/Tabs/Entities")
	if tab_homunculi == null:
		tab_homunculi = get_node_or_null("RootMargin/MainHSplit/LeftPanel/Tabs/Homunculi")
	if tabs == null:
		tabs = get_node_or_null("RootMargin/MainHSplit/LeftPanel/Tabs")
	if btn_tab_entities == null:
		btn_tab_entities = get_node_or_null("RootMargin/MainHSplit/LeftPanel/TabButtons/BtnEntities")
	if btn_tab_homunculi == null:
		btn_tab_homunculi = get_node_or_null("RootMargin/MainHSplit/LeftPanel/TabButtons/BtnHomunculi")

	if grid_entities == null:
		grid_entities = get_node_or_null("RootMargin/MainHSplit/LeftPanel/Tabs/Entities/EntitiesScroll/EntitiesGrid")
	if grid_homunculi == null:
		grid_homunculi = get_node_or_null("RootMargin/MainHSplit/LeftPanel/Tabs/Homunculi/HomunculiScroll/HomunculiGrid")

	if btn_seal_attack == null:
		btn_seal_attack = get_node_or_null("RootMargin/MainHSplit/LeftPanel/ModeRow/AttackCol/AttackBtn")
	if btn_seal_defense == null:
		btn_seal_defense = get_node_or_null("RootMargin/MainHSplit/LeftPanel/ModeRow/DefenseCol/DefenseBtn")
	if btn_save == null:
		btn_save = get_node_or_null("RootMargin/MainHSplit/RightPanel/BottomRow/Save")
	if btn_play == null:
		btn_play = get_node_or_null("RootMargin/MainHSplit/RightPanel/BottomRow/Play")

	if lbl_title == null:
		lbl_title = get_node_or_null("RootMargin/MainHSplit/LeftPanel/Title")
	if lbl_name == null:
		lbl_name = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/SelectedRow/InfoVBox/Name")
	if lbl_mode == null:
		lbl_mode = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/SelectedRow/InfoVBox/Mode")
	if lbl_homunculus == null:
		lbl_homunculus = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/SelectedRow/InfoVBox/HomunculusName")
	if lbl_types == null:
		lbl_types = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/SelectedRow/InfoVBox/Types")
	if lbl_base == null:
		lbl_base = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/SelectedRow/InfoVBox/Stats")
	if lbl_desc == null:
		lbl_desc = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/SelectedRow/InfoVBox/Desc")
	if lbl_build_error == null:
		lbl_build_error = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/BuildCenter/BuildBlock/BuildError")
	if tooltip_panel == null:
		tooltip_panel = get_node_or_null("RootMargin/MainHSplit/RightPanel/ItemTooltip")
	if tooltip_icon == null:
		tooltip_icon = get_node_or_null("RootMargin/MainHSplit/RightPanel/ItemTooltip/TooltipVBox/TooltipIcon")
	if tooltip_label == null:
		tooltip_label = get_node_or_null("RootMargin/MainHSplit/RightPanel/ItemTooltip/TooltipVBox/TooltipText")
	if preview == null:
		preview = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/SelectedRow/PreviewFrame/Preview")
	if hom_preview == null:
		hom_preview = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/SelectedRow/HomPreviewFrame/HomPreview")

	# BuildGrid controls (Equip/Side are Buttons in the scene)
	if dd_item1 == null:
		dd_item1 = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/BuildCenter/BuildBlock/BuildGrid/Equip1")
	if dd_item2 == null:
		dd_item2 = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/BuildCenter/BuildBlock/BuildGrid/Equip2")
	if dd_side1 == null:
		dd_side1 = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/BuildCenter/BuildBlock/BuildGrid/Side1")
	if dd_side2 == null:
		dd_side2 = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/BuildCenter/BuildBlock/BuildGrid/Side2")

	# Buttons for techniques (cycle on click)
	if dd_atktech == null:
		dd_atktech = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/TechCenter/TechBlock/TechGrid/AtkTech")
	if dd_deftech == null:
		dd_deftech = get_node_or_null("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/TechCenter/TechBlock/TechGrid/DefTech")

	print_debug("[loadout_grid] Resolved nodes: grid_entities=%s, btn_attack=%s, btn_defense=%s" % [str(grid_entities), str(btn_seal_attack), str(btn_seal_defense)])

func _ready() -> void:
	_resolve_nodes()
	if tooltip_panel:
		tooltip_panel.visible = false
		if tooltip_panel.get_parent() != self:
			tooltip_panel.reparent(self)
		tooltip_panel.top_level = true
		tooltip_panel.z_index = 100
		tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooltip_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tooltip_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tooltip_panel.custom_minimum_size = Vector2(220, 0)
		tooltip_panel.anchor_left = 0.0
		tooltip_panel.anchor_top = 0.0
		tooltip_panel.anchor_right = 0.0
		tooltip_panel.anchor_bottom = 0.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.6)
		sb.set_content_margin_all(8)
		tooltip_panel.add_theme_stylebox_override("panel", sb)
	if tooltip_label:
		tooltip_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		tooltip_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tooltip_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tooltip_label.custom_minimum_size = Vector2(220, 0)
		tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		var font := load("res://assets/fonts/liberation-serif/LiberationSerif-Regular.ttf")
		tooltip_label.add_theme_font_override("font", font)
	if tooltip_icon:
		tooltip_icon.custom_minimum_size = Vector2(32, 32)
		tooltip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tooltip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tune_tabs()
	_setup_build_dialog()
	_load_registry_safe()
	_setup_spell_state()
	_build_spell_dialog()
	_wire_buttons()
	_wire_build_tooltips()
	_populate_dropdowns()
	_build_cards()
	_refresh_details()
	_update_save_button_label()

func _setup_build_dialog() -> void:
	var card: VBoxContainer = $RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox
	var center: HBoxContainer = card.get_node("BuildCenter")
	var block: VBoxContainer = center.get_node("BuildBlock")
	var overlay := Control.new()
	overlay.name = "BuildOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 50
	overlay.hide()
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var center_popup := CenterContainer.new()
	center_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_popup.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center_popup)
	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(720, 430)
	dialog.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup-grande.png", Vector4(62, 72, 62, 48)))
	center_popup.add_child(dialog)
	if lbl_build_error:
		lbl_build_error.reparent(card)
	block.reparent(dialog)
	block.custom_minimum_size = Vector2.ZERO
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	var grid := block.get_node("BuildGrid") as GridContainer
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for slot in [dd_item1, dd_item2, dd_side1, dd_side2]:
		if slot is Button:
			slot.custom_minimum_size = Vector2(275, 70)
			MenuArt.button(slot)
	var close := Button.new()
	close.text = "Done"
	close.custom_minimum_size = Vector2(160, 46)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	MenuArt.button(close)
	close.pressed.connect(overlay.hide)
	block.add_child(close)
	var button := Button.new()
	button.text = "Build"
	button.custom_minimum_size = Vector2(160, 48)
	MenuArt.button(button)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.get_node("BuildCenterSpacer").hide()
	center.add_child(button)
	button.pressed.connect(overlay.show)
	for action_path in ["RootMargin/MainHSplit/RightPanel/BottomRow/Save", "RootMargin/MainHSplit/RightPanel/BottomRow/Play"]:
		var action := get_node_or_null(action_path) as Button
		if action:
			MenuArt.button(action)
	for path in ["SelectedRow/PreviewFrame", "SelectedRow/HomPreviewFrame"]:
		var portrait := card.get_node_or_null(path) as PanelContainer
		if portrait:
			portrait.add_theme_stylebox_override("panel", MenuArt.frame("marco-forma-carta-vertical.png", Vector4(16, 22, 16, 18)))
	var row := card.get_node("SelectedRow") as HBoxContainer
	var info := row.get_node("InfoVBox") as VBoxContainer
	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.custom_minimum_size.y = 275
	info_panel.add_theme_stylebox_override("panel", MenuArt.frame("marco-informativo-small.png", Vector4(48, 42, 48, 42)))
	row.add_child(info_panel)
	info.reparent(info_panel)
	info.get_node("InfoSpacer").custom_minimum_size.y = 0

func _load_registry_safe() -> void:
	if ResourceLoader.exists(REG_PATH):
		var reg_script: Script = load(REG_PATH)
		_reg = reg_script.new()
	else:
		_reg = null

	# Entities
	if _reg != null and _reg.has_method("get_entities"):
		_entities = _as_array(_reg.call("get_entities"))
	elif _reg != null and _reg.get_script() != null:
		var v = _reg.get("entities")
		_entities = _as_array(v)
	else:
		_entities = []

	# Homunculi
	if _reg != null and _reg.has_method("get_homunculi"):
		_homunculi = _as_array(_reg.call("get_homunculi"))
	elif _reg != null and _reg.get_script() != null:
		var vv = _reg.get("homunculi")
		_homunculi = _as_array(vv)
	else:
		_homunculi = []

	# Items
	if _reg != null and _reg.has_method("get_items"):
		_items = _as_array(_reg.call("get_items"))
	elif _reg != null and _reg.get_script() != null:
		var v3 = _reg.get("items")
		_items = _as_array(v3)
	else:
		_items = []

	# Techniques
	if _reg != null and _reg.has_method("get_attack_techniques"):
		_atk_techs = _as_array(_reg.call("get_attack_techniques"))
	elif _reg != null and _reg.get_script() != null:
		_atk_techs = _as_array(_reg.get("attack_techniques"))
	else:
		_atk_techs = []

	if _reg != null and _reg.has_method("get_defense_techniques"):
		_def_techs = _as_array(_reg.call("get_defense_techniques"))
	elif _reg != null and _reg.get_script() != null:
		_def_techs = _as_array(_reg.get("defense_techniques"))
	else:
		_def_techs = []

func _setup_spell_state() -> void:
	_spell_debug.reload()
	if _spell_debug.unlock_all_buildings:
		_spell_state = _spell_debug.load_lab_state()
		_spell_synced = true
		return
	_spell_backend = BackendClient.new()
	_spell_backend.base_url = spell_backend_url
	_spell_backend.state_updated.connect(_on_spell_state_updated)
	_spell_backend.auth_changed.connect(_on_spell_auth_changed)
	_spell_backend.action_confirmed.connect(_on_spell_action_confirmed)
	_spell_backend.action_failed.connect(_on_spell_action_failed)
	add_child(_spell_backend)
	_spell_state = _spell_backend.load_cached_state() if _spell_backend.token != "" else {}
	if _spell_backend.token != "":
		_spell_backend.request_api("GET", "/player/state", null, true)

func _on_spell_auth_changed(token: String) -> void:
	_spell_synced = false
	_spell_state = {}
	_refresh_spell_button()
	if token != "" and _spell_backend != null:
		_spell_backend.request_api("GET", "/player/state", null, true)

func _on_spell_state_updated(state: Dictionary) -> void:
	if _spell_debug.unlock_all_buildings:
		return
	_spell_state = state.duplicate(true)
	_spell_synced = true
	_refresh_spell_button()

func _read_seal_data(mode: String) -> Dictionary:
	var path := "user://seal_%s.json" % mode
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _equipped_spells(mode: String, entity_id: String) -> Array:
	if _reg == null:
		return []
	return SpellLoadout.saved_ids(_reg, _spell_state, mode, entity_id, _read_seal_data(mode), not _spell_debug.unlock_all_buildings)

func _refresh_spell_button() -> void:
	if _spell_button == null or _reg == null:
		return
	var available := SpellLoadout.available_ids(_reg, _current_entity_id, _spell_state.get("spell_progress", {}))
	_spell_button.visible = available.size() > 4
	_spell_button.disabled = _spell_pending_id != ""

func _build_spell_dialog() -> void:
	_spell_button = get_node_or_null("SpellConfig") as Button
	if _spell_button == null:
		return
	_spell_button.pressed.connect(_open_spell_dialog)
	_spell_dialog = Control.new()
	_spell_dialog.name = "SpellOverlay"
	_spell_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spell_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_spell_dialog.z_index = 50
	_spell_dialog.hide()
	add_child(_spell_dialog)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_dialog.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spell_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1020, 620)
	panel.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup-grande.png", Vector4(65, 75, 65, 55)))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_spell_heading = Label.new()
	_spell_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_heading.add_theme_font_size_override("font_size", 20)
	_spell_heading.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	header.add_child(_spell_heading)
	var close := Button.new()
	close.text = "X"
	close.tooltip_text = "Close"
	close.custom_minimum_size = Vector2(44, 36)
	MenuArt.button(close)
	close.pressed.connect(_spell_dialog.hide)
	header.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	var slots := VBoxContainer.new()
	slots.custom_minimum_size.x = 230
	slots.add_theme_constant_override("separation", 8)
	body.add_child(slots)
	for i in 4:
		var slot := Button.new()
		slot.custom_minimum_size.y = 58
		slot.toggle_mode = true
		_style_spell_button(slot)
		slot.pressed.connect(_select_spell_slot.bind(i))
		slots.add_child(slot)
		_spell_slots.append(slot)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	var filters := HBoxContainer.new()
	right.add_child(filters)
	var filter_group := ButtonGroup.new()
	for group_name in ["All", "Initial", "Hybrid", "Universal"]:
		var filter := Button.new()
		filter.text = group_name
		filter.toggle_mode = true
		filter.button_group = filter_group
		_style_spell_button(filter)
		filter.button_pressed = group_name == "All"
		filter.pressed.connect(_filter_spell_catalog.bind(group_name))
		filters.add_child(filter)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_spell_catalog = VBoxContainer.new()
	_spell_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_spell_catalog)
	_spell_description = Label.new()
	_spell_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spell_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_description.add_theme_font_size_override("font_size", 13)
	_spell_description.add_theme_color_override("font_color", Color(0.93, 0.94, 0.88))
	var details_scroll := ScrollContainer.new()
	details_scroll.custom_minimum_size.y = 125
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(details_scroll)
	details_scroll.add_child(_spell_description)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(150, 42)
	MenuArt.button(cancel)
	cancel.pressed.connect(_spell_dialog.hide)
	actions.add_child(cancel)
	_spell_confirm = Button.new()
	_spell_confirm.text = "Confirm"
	_spell_confirm.custom_minimum_size = Vector2(150, 42)
	MenuArt.button(_spell_confirm)
	_spell_confirm.pressed.connect(func():
		_confirm_spell_dialog()
		_spell_dialog.hide()
	)
	actions.add_child(_spell_confirm)

func _open_spell_dialog() -> void:
	if _spell_pending_id != "" or _reg == null:
		return
	_spell_draft = _equipped_spells(_mode, _current_entity_id).duplicate()
	_spell_selected_slot = 0
	var entity: Dictionary = _reg.entities.get(_current_entity_id, {})
	_spell_heading.text = "Configure Spells   |   %s - %s   |   4/4 Equipped" % [entity.get("name", ""), str(entity.get("type", "")).capitalize()]
	_rebuild_spell_catalog()
	_refresh_spell_draft(0)
	_spell_dialog.show()

func _select_spell_slot(index: int) -> void:
	_spell_selected_slot = index
	_refresh_spell_draft(index)

func _filter_spell_catalog(value: String) -> void:
	_spell_filter = value
	_rebuild_spell_catalog()

func _rebuild_spell_catalog() -> void:
	for child in _spell_catalog.get_children():
		_spell_catalog.remove_child(child)
		child.queue_free()
	var entity: Dictionary = _reg.entities.get(_current_entity_id, {})
	var entity_type := str(entity.get("type", ""))
	for spell in _reg.get_researchable_spells_for_type(entity_type):
		if _spell_filter != "All" and SpellView.group(spell) != _spell_filter:
			continue
		var status := SpellView.status(spell, _current_entity_id, entity_type, _spell_state.get("spell_progress", {}), _spell_synced or _spell_debug.unlock_all_buildings)
		var row := Button.new()
		row.text = "%s   |   %s   |   %s" % [spell.name, SpellView.affinity(spell), status]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 32
		if status == "Locked":
			row.modulate = Color(0.7, 0.7, 0.7)
			var lock := LockIndicator.new()
			lock.position = Vector2(4, 6)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lock)
			row.text = "     " + row.text
		row.pressed.connect(_choose_catalog_spell.bind(spell, status))
		_spell_catalog.add_child(row)
		_style_spell_button(row)

func _style_spell_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.2, 0.2, 0.95) if state in ["hover", "pressed", "hover_pressed"] else Color(0.02, 0.07, 0.08, 0.92)
		style.border_color = Color(0.8, 0.67, 0.35) if state in ["pressed", "hover_pressed"] else Color(0.22, 0.43, 0.4)
		style.set_border_width_all(1)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color(0.95, 0.95, 0.89))
	button.add_theme_font_size_override("font_size", 14)

func _choose_catalog_spell(spell: Dictionary, status: String) -> void:
	_spell_description.text = "%s\n%s" % [spell.name, SpellView.detail(spell, status)]
	if status not in ["Initial", "Learned"]:
		return
	var id := str(spell.id)
	if id in _spell_draft and _spell_draft[_spell_selected_slot] != id:
		_spell_description.text += "\nAlready equipped in another slot."
		return
	_spell_draft[_spell_selected_slot] = id
	_refresh_spell_draft(_spell_selected_slot)

func _refresh_spell_draft(slot_index: int) -> void:
	var valid := SpellLoadout.valid(_reg, _current_entity_id, _spell_state.get("spell_progress", {}), _spell_draft)
	_spell_confirm.disabled = not valid or _spell_pending_id != "" or (not _spell_debug.unlock_all_buildings and not _spell_synced)
	for i in _spell_slots.size():
		var selected_spell: Dictionary = _reg.get_spell_by_id(str(_spell_draft[i])) if i < _spell_draft.size() else {}
		_spell_slots[i].text = "%d. %s\n%s | CD %d" % [i + 1, selected_spell.get("name", "-"), SpellView.affinity(selected_spell), int(selected_spell.get("cooldown_turns", 0))]
		_spell_slots[i].button_pressed = i == _spell_selected_slot
	var spell: Dictionary = _reg.get_spell_by_id(str(_spell_draft[slot_index])) if slot_index < _spell_draft.size() else {}
	_spell_description.text = "%s\n%s" % [spell.get("name", ""), SpellView.detail(spell, "Equipped")]
	if not valid:
		_spell_description.text += "\nEach slot must contain a different available spell."
	elif not _spell_debug.unlock_all_buildings and not _spell_synced:
		_spell_description.text += "\nWaiting for an authenticated server state."

func _confirm_spell_dialog() -> void:
	if not SpellLoadout.valid(_reg, _current_entity_id, _spell_state.get("spell_progress", {}), _spell_draft):
		return
	if _spell_debug.unlock_all_buildings:
		var next := _spell_debug.load_lab_state()
		var progress: Dictionary = next.get("spell_progress", {})
		var equipped: Dictionary = progress.get("equipped_by_mode", {})
		var mode_entries: Dictionary = equipped.get(_mode, {})
		mode_entries[_current_entity_id] = _spell_draft.duplicate()
		equipped[_mode] = mode_entries
		progress["equipped_by_mode"] = equipped
		next["spell_progress"] = progress
		if not _spell_debug.save_lab_state(next):
			_set_build_error("Could not save the debug spell loadout.")
			return
		_spell_state = next
		_save_seal(_mode)
		_set_build_error("Debug spell loadout saved.")
		return
	if _spell_backend == null or not _spell_synced or _spell_pending_id != "":
		_set_build_error("Server state is unavailable.")
		return
	_spell_pending_mode = _mode
	_spell_pending_entity = _current_entity_id
	_spell_pending_id = _spell_backend.send_action({"action_type": "SET_SPELL_LOADOUT", "payload": {"mode": _mode, "entity_id": _current_entity_id, "spell_ids": _spell_draft.duplicate()}})
	if _spell_pending_id == "":
		_spell_synced = false
	_set_build_error("Waiting for server confirmation." if _spell_pending_id != "" else "Could not send spell loadout.")
	_refresh_spell_button()

func _on_spell_action_confirmed(action_id: String) -> void:
	if action_id != _spell_pending_id or action_id == "":
		return
	_spell_pending_id = ""
	if _mode == _spell_pending_mode and _current_entity_id == _spell_pending_entity:
		_save_seal(_mode)
	_set_build_error("Spell loadout confirmed by server.")
	_refresh_spell_button()

func _on_spell_action_failed(action_id: String, error: String) -> void:
	if action_id != _spell_pending_id or action_id == "":
		return
	_spell_pending_id = ""
	if error in ["network_error", "bad_json", "bad_state"]:
		_set_build_error("Server unavailable; spell loadout was not confirmed.")
		_spell_synced = false
		if _spell_backend != null and _spell_backend.token != "":
			_spell_backend.request_api("GET", "/player/state", null, true)
	else:
		_set_build_error("Spell loadout rejected: " + error)
	_refresh_spell_button()

func _wire_buttons() -> void:
	if btn_seal_attack:
		var cb_attack := Callable(self, "_on_seal_attack")
		if not btn_seal_attack.pressed.is_connected(cb_attack):
			btn_seal_attack.pressed.connect(cb_attack)
			print_debug("[loadout_grid] Connected AttackBtn")
	else:
		print_debug("[loadout_grid] AttackBtn NULL")
	if btn_seal_defense:
		var cb_defense := Callable(self, "_on_seal_defense")
		if not btn_seal_defense.pressed.is_connected(cb_defense):
			btn_seal_defense.pressed.connect(cb_defense)
			print_debug("[loadout_grid] Connected DefenseBtn")
	else:
		print_debug("[loadout_grid] DefenseBtn NULL")
	if btn_save:
		var cb_save := Callable(self, "_on_save_pressed")
		if not btn_save.pressed.is_connected(cb_save):
			btn_save.pressed.connect(cb_save)
			print_debug("[loadout_grid] Connected SaveBtn")
		if not btn_save.gui_input.is_connected(Callable(self, "_on_save_gui_input")):
			btn_save.gui_input.connect(Callable(self, "_on_save_gui_input"))
	if btn_play:
		var cb_play := Callable(self, "_on_play_pressed")
		if not btn_play.pressed.is_connected(cb_play):
			btn_play.pressed.connect(cb_play)
			print_debug("[loadout_grid] Connected PlayBtn")
	if btn_tab_entities:
		var cb_tab_e := Callable(self, "_on_tab_entities")
		if not btn_tab_entities.pressed.is_connected(cb_tab_e):
			btn_tab_entities.pressed.connect(cb_tab_e)
	if btn_tab_homunculi:
		var cb_tab_h := Callable(self, "_on_tab_homunculi")
		if not btn_tab_homunculi.pressed.is_connected(cb_tab_h):
			btn_tab_homunculi.pressed.connect(cb_tab_h)

func _populate_dropdowns() -> void:
	_populate_control_with_list(dd_item1, _items)
	_populate_control_with_list(dd_item2, _items)
	# Sideboard uses the same item pool as equips for now.
	_populate_control_with_list(dd_side1, _items)
	_populate_control_with_list(dd_side2, _items)
	_populate_control_with_list(dd_atktech, _atk_techs)
	_populate_control_with_list(dd_deftech, _def_techs)

func _populate_option(dd: OptionButton, arr: Array) -> void:
	if dd == null:
		return
	dd.clear()
	dd.flat = true
	dd.theme_type_variation = ""
	# Hide built-in label so only the centered overlay label is visible.
	dd.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	dd.add_theme_color_override("font_color_hover", Color(0, 0, 0, 0))
	dd.add_theme_color_override("font_color_pressed", Color(0, 0, 0, 0))
	dd.add_theme_color_override("font_color_focus", Color(0, 0, 0, 0))
	dd.add_theme_color_override("font_color_disabled", Color(0, 0, 0, 0))
	for i in range(arr.size()):
		var item = arr[i]
		var label = _label_for_item(item, "Item")
		dd.add_item(label, i)
	dd.select(0 if arr.size() > 0 else -1)
	dd.set_meta("items", arr)
	dd.set_meta("selected_idx", 0)
	_tune_option_popup(dd)
	_ensure_option_label(dd)

func _populate_control_with_list(control: Node, items: Array) -> void:
	if control == null:
		return
	if control is OptionButton:
		_populate_option(control, items)
		return
	if control is Button:
		control.set_meta("items", items)
		control.set_meta("selected_idx", 0)
		var label = _label_for_item(items[0], "None") if items.size() > 0 else "None"
		control.text = label
		var btn := control as Button
		_refresh_build_slot_icon(btn)
		var cb_equip := Callable(self, "_on_equip_button_pressed").bind(btn)
		if not btn.pressed.is_connected(cb_equip):
			btn.pressed.connect(cb_equip)
		return

func _on_equip_button_pressed(btn: Button) -> void:
	if btn == null:
		return
	var items = btn.get_meta("items")
	if items == null or items.size() == 0:
		return
	var sidx = btn.get_meta("selected_idx")
	if typeof(sidx) != TYPE_INT:
		sidx = int(sidx)
	sidx = (sidx + 1) % items.size()
	btn.set_meta("selected_idx", sidx)
	btn.text = _label_for_item(items[sidx], "None")
	_refresh_build_slot_icon(btn)
	if tooltip_panel and tooltip_panel.visible:
		var mouse_pos := get_viewport().get_mouse_position()
		if btn.get_global_rect().has_point(mouse_pos):
			_on_build_hover_entered(btn)

func _build_cards() -> void:
	_clear_children(grid_entities)
	_clear_children(grid_homunculi)

	var bastion_entry = null
	for d in _entities:
		if _is_bastion_entity(d):
			bastion_entry = d
			continue
		var eid := str(d.get("id",""))
		var ename := _clean_name(str(d.get("name", eid)))
		var tex := _load_preview_tex(eid, "entity", ename)
		var card := _make_card("entity", eid, ename, tex)
		if grid_entities: grid_entities.add_child(card)
	if bastion_entry != null:
		var beid := str(bastion_entry.get("id",""))
		var bename := _clean_name(str(bastion_entry.get("name", beid)))
		var btex := _load_preview_tex(beid, "entity", bename)
		var bcard := _make_card("entity", beid, bename, btex)
		if grid_entities: grid_entities.add_child(bcard)

	for d2 in _homunculi:
		var hid := str(d2.get("id",""))
		var hname := _clean_name(str(d2.get("name", hid)))
		var htex := _load_preview_tex(hid, "homunculus", hname)
		var hcard := _make_card("homunculus", hid, hname, htex)
		if grid_homunculi: grid_homunculi.add_child(hcard)

	# Add bottom padding so last labels aren't clipped.
	_add_grid_padding(grid_entities)
	_add_grid_padding(grid_homunculi)

	if _entities.size() > 0:
		_current_entity_id = str(_entities[0].get("id",""))
	if _homunculi.size() > 0:
		_current_homunculus_id = str(_homunculi[0].get("id",""))

	_update_selected_visuals()

func _make_card(p_kind: String, p_id: String, p_name: String, p_tex: Texture2D) -> Control:
	# Simple self-contained card to avoid theme/scene inconsistencies.
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 200)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.text = ""
	b.focus_mode = Control.FOCUS_NONE
	b.flat = false
	var card_style := MenuArt.frame("marco-forma-carta-vertical.png", Vector4(12, 12, 12, 12))
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, card_style)
	b.pressed.connect(func(): _on_card_picked(p_kind, p_id))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 24
	v.offset_bottom = -20
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	b.add_child(v)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(118, 118)
	tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.z_as_relative = true
	tex_rect.z_index = 0
	if p_tex:
		tex_rect.texture = p_tex
	v.add_child(tex_rect)

	var lbl := Label.new()
	lbl.text = p_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_as_relative = true
	lbl.z_index = 2
	lbl.custom_minimum_size = Vector2(0, 28)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	v.add_child(lbl)
	return b

func _add_grid_padding(grid: GridContainer) -> void:
	if grid == null:
		return
	for i in range(2):
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(0, 40)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(pad)

func _is_bastion_entity(d: Dictionary) -> bool:
	var display_name = _clean_name(str(d.get("name", ""))).to_lower()
	var id = str(d.get("id", "")).to_lower()
	return display_name.find("bastion") != -1 or id == "sodium_01"

func _on_card_picked(p_kind: String, p_id: String) -> void:
	if p_kind == "entity":
		_current_entity_id = p_id
	elif p_kind == "homunculus":
		_current_homunculus_id = p_id
	_update_selected_visuals()
	_refresh_details()

func _update_selected_visuals() -> void:
	if grid_entities:
		for c in grid_entities.get_children():
			if c and c.has_method("set_selected"):
				c.call("set_selected", c.get("id") == _current_entity_id)
	if grid_homunculi:
		for c2 in grid_homunculi.get_children():
			if c2 and c2.has_method("set_selected"):
				c2.call("set_selected", c2.get("id") == _current_homunculus_id)

func _refresh_details() -> void:
	var ent := _find_by_id(_entities, _current_entity_id)
	if ent.is_empty() and _entities.size() > 0:
		_current_entity_id = str(_entities[0].get("id",""))
		ent = _find_by_id(_entities, _current_entity_id)
	if ent.is_empty():
		if lbl_name: lbl_name.text = "(Select an entity)"
		if lbl_mode: lbl_mode.text = "Mode: " + _mode.to_upper()
		if lbl_homunculus: lbl_homunculus.text = "Homunculus: —"
		if preview: preview.texture = null
		if _spell_button: _spell_button.hide()
		return
	_refresh_spell_button()

	if lbl_name: lbl_name.text = str(ent.get("name", _current_entity_id))
	if lbl_mode: lbl_mode.text = "Mode: " + _mode.to_upper()
	if lbl_homunculus:
		var hom0 := _find_by_id(_homunculi, _current_homunculus_id)
		var hname0 := str(hom0.get("name", _current_homunculus_id)) if typeof(hom0) == TYPE_DICTIONARY else _current_homunculus_id
		lbl_homunculus.text = "Homunculus: " + hname0
	if lbl_types:
		lbl_types.text = "Types: " + _type_for_entity(ent)
	if lbl_base:
		var stats = _get_base_stats(ent)
		var buffs = _get_homunculus_buffs(_current_homunculus_id)
		var hp = stats.hp + buffs.hp
		var atk = stats.atk + buffs.atk
		var def = stats.def + buffs.def
		lbl_base.text = "Base: HP %s | ATK %s | DEF %s" % [str(hp), str(atk), str(def)]
	if lbl_desc: lbl_desc.text = str(ent.get("desc","—"))
	if lbl_desc:
		lbl_desc.text = _lore_for_entity(ent)

	if preview:
		preview.texture = _load_preview_tex(_current_entity_id, "entity", str(ent.get("name", _current_entity_id)))
	if hom_preview:
		var hom := _find_by_id(_homunculi, _current_homunculus_id)
		if hom.is_empty() and _homunculi.size() > 0:
			hom = _homunculi[0]
		var hid := str(hom.get("id","")) if typeof(hom) == TYPE_DICTIONARY else ""
		var hname := str(hom.get("name", hid)) if typeof(hom) == TYPE_DICTIONARY else ""
		hom_preview.texture = _load_preview_tex(hid, "homunculus", hname)

func _find_by_id(arr: Array, pid: String) -> Dictionary:
	for d in arr:
		if str(d.get("id","")) == pid:
			return d
	return {}

func _load_preview_tex(pid: String, kind: String = "entity", display_name: String = "") -> Texture2D:
	if pid == "":
		return null
	if kind == "homunculus":
		var stem := _resolve_homunculus_stem(pid, display_name)
		var p1 = "%s%s.png" % [HOM_PREVIEW_256_DIR, stem]
		var p2 = "%s%s_01.png" % [HOM_PREVIEW_256_DIR, stem]
		if ResourceLoader.exists(p2):
			return load(p2)
		if ResourceLoader.exists(p1):
			return load(p1)
		return null
	var p3 = "%s%s.png" % [PREVIEW_256_DIR, pid]
	var p4 = "%s%s_01.png" % [PREVIEW_256_DIR, pid]
	if ResourceLoader.exists(p4):
		return load(p4)
	if ResourceLoader.exists(p3):
		return load(p3)
	return null

func _resolve_homunculus_stem(pid: String, display_name: String) -> String:
	var id_norm := _normalize_id(pid)
	var name_norm := _normalize_id(display_name)
	if HOM_PREVIEW_MAP.has(id_norm):
		return HOM_PREVIEW_MAP[id_norm]
	# direct match
	for stem in HOM_PREVIEW_STEMS:
		if id_norm == stem:
			return stem
		if name_norm == stem:
			return stem
	# contains match
	for stem2 in HOM_PREVIEW_STEMS:
		if id_norm.find(stem2) != -1:
			return stem2
		if name_norm.find(stem2) != -1:
			return stem2
	# keyword-based fallback
	if id_norm.find("cinder") != -1 or id_norm.find("sulfur") != -1:
		return "cinder"
	if id_norm.find("sodium") != -1 or id_norm.find("salt") != -1:
		return "sodium"
	if id_norm.find("mercury") != -1 or id_norm.find("quick") != -1 or id_norm.find("silph") != -1:
		return "silphide"
	if id_norm.find("aether") != -1 or id_norm.find("veil") != -1 or id_norm.find("seraph") != -1:
		return "drakon"
	if id_norm.find("vitriol") != -1 or id_norm.find("green") != -1:
		return "pyritc"
	if id_norm.find("gold") != -1 or id_norm.find("gilded") != -1:
		return "chimera"
	return HOM_PREVIEW_STEMS[0]

func _normalize_id(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	s = s.replace("(temp)", "")
	s = s.replace("temp", "")
	s = s.replace("[temp]", "")
	s = s.replace("(", "").replace(")", "")
	s = s.replace("[", "").replace("]", "")
	s = s.strip_edges()
	if s.find(" ") != -1:
		var parts := s.split(" ", false)
		if parts.size() > 0:
			s = parts[parts.size()-1]
	var cleaned := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			cleaned += ch
	return cleaned

func _tune_option_popup(dd: OptionButton) -> void:
	var popup: PopupMenu = dd.get_popup()
	if popup == null:
		return
	var empty := StyleBoxEmpty.new()
	# Force a clean, texture-less theme on the popup itself.
	var t := Theme.new()
	t.set_stylebox("panel", "PopupMenu", empty)
	t.set_stylebox("hover", "PopupMenu", empty)
	t.set_stylebox("pressed", "PopupMenu", empty)
	t.set_stylebox("separator", "PopupMenu", empty)
	t.set_stylebox("labeled_separator", "PopupMenu", empty)
	popup.theme = t
	popup.theme_type_variation = ""
	popup.transparent = true
	call_deferred("_defer_popup_size", popup, dd)

func _defer_popup_size(popup: PopupMenu, dd: OptionButton) -> void:
	if popup == null or dd == null:
		return
	var w: float = max(dd.size.x, 220.0)
	var h: float = max(220.0, dd.size.y * 6.0)
	popup.min_size = Vector2(w, h)

func _tune_tabs() -> void:
	if tabs == null:
		return
	var bar := tabs.get_tab_bar()
	if bar:
		bar.add_theme_constant_override("hseparation", 32)
		bar.add_theme_constant_override("tab_overlap", -20)
	if tabs:
		tabs.tabs_visible = false
	_set_tab_state(0)

func _set_tab_state(idx: int) -> void:
	if tabs:
		tabs.current_tab = idx
	if btn_tab_entities:
		btn_tab_entities.button_pressed = idx == 0
	if btn_tab_homunculi:
		btn_tab_homunculi.button_pressed = idx == 1

func _on_tab_entities() -> void:
	_set_tab_state(0)

func _on_tab_homunculi() -> void:
	_set_tab_state(1)


func _ensure_option_label(dd: OptionButton) -> void:
	if dd == null:
		return
	var lbl := dd.get_node_or_null("CenterLabel")
	if lbl == null:
		lbl = Label.new()
		lbl.name = "CenterLabel"
		lbl.anchor_left = 0.0
		lbl.anchor_top = 0.0
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.offset_left = 8
		lbl.offset_top = 0
		lbl.offset_right = -8
		lbl.offset_bottom = 0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lbl.add_theme_constant_override("outline_size", 2)
		dd.add_child(lbl)
	var sel := dd.get_selected_id()
	if sel < 0 and dd.item_count > 0:
		sel = 0
	if sel >= 0:
		lbl.text = dd.get_item_text(sel)
	dd.text = ""
	if not dd.item_selected.is_connected(Callable(self, "_on_option_selected")):
		dd.item_selected.connect(Callable(self, "_on_option_selected").bind(dd))

func _on_option_selected(idx: int, dd: OptionButton) -> void:
	if dd == null:
		return
	var lbl := dd.get_node_or_null("CenterLabel")
	if lbl:
		lbl.text = dd.get_item_text(idx)

func _clear_children(n: Node) -> void:
	if n == null:
		return
	for c in n.get_children():
		c.queue_free()

func _as_array(v) -> Array:
	if v is Array:
		return v
	if v is Dictionary:
		return v.values()
	return []

func _as_string_array(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(str(x))
	return out

func _label_for_item(item, fallback: String) -> String:
	if typeof(item) == TYPE_DICTIONARY:
		if item.has("name"):
			return str(item.get("name", fallback))
		if item.has("id"):
			return str(item.get("id", fallback))
	return str(item) if item != null else fallback

func _get_base_stats(ent: Dictionary) -> Dictionary:
	var out := {"hp": 0, "atk": 0, "def": 0}
	if ent.has("base_stats") and typeof(ent["base_stats"]) == TYPE_DICTIONARY:
		var bs: Dictionary = ent["base_stats"]
		out.hp = int(bs.get("hp", 0))
		out.atk = int(bs.get("power", bs.get("atk", 0)))
		out.def = int(bs.get("guard", bs.get("def", 0)))
	else:
		out.hp = int(ent.get("hp", 0))
		out.atk = int(ent.get("atk", 0))
		out.def = int(ent.get("def", 0))
	return out

func _get_homunculus_buffs(hom_id: String) -> Dictionary:
	var out := {"hp": 0, "atk": 0, "def": 0}
	var hom := _find_by_id(_homunculi, hom_id)
	if hom.is_empty():
		return out
	out.hp = int(hom.get("buff_hp", 0))
	out.atk = int(hom.get("buff_atk", 0))
	out.def = int(hom.get("buff_def", 0))
	return out

func _clean_name(s: String) -> String:
	var o := s.strip_edges()
	o = o.replace("(TEMP)", "")
	o = o.replace("(Temp)", "")
	o = o.replace("TEMP", "")
	o = o.replace("temp", "")
	return o.strip_edges()

func _type_for_entity(ent: Dictionary) -> String:
	var ent_name := _clean_name(str(ent.get("name", ""))).to_lower()
	var id := str(ent.get("id", "")).to_lower()
	if ent_name.find("anomaly") != -1 or id.find("anomaly") != -1:
		return "Aether"
	if ent_name.find("igniter") != -1 or id.find("igniter") != -1:
		return "Sulfur"
	if ent_name.find("quicksprite") != -1 or id.find("quicksprite") != -1:
		return "Mercury"
	if ent_name.find("corroder") != -1 or id.find("corroder") != -1:
		return "Vitriol"
	if ent_name.find("arbiter") != -1 or id.find("arbiter") != -1:
		return "Gold"
	if ent_name.find("bastion") != -1 or id == "sodium_01":
		return "Sodium"
	return "-"

func _lore_for_entity(ent: Dictionary) -> String:
	var ent_name := _clean_name(str(ent.get("name", ""))).to_lower()
	var id := str(ent.get("id", "")).to_lower()
	if ent_name.find("anomaly") != -1 or id.find("anomaly") != -1:
		return "A rift-born mind that hums with aether and rewrites the rules."
	if ent_name.find("igniter") != -1 or id.find("igniter") != -1:
		return "Sulfur’s first spark, a burning oath that turns steel to ash."
	if ent_name.find("quicksprite") != -1 or id.find("quicksprite") != -1:
		return "Mercury given legs, a restless slip of lightning and mirth."
	if ent_name.find("corroder") != -1 or id.find("corroder") != -1:
		return "Vitriol’s whisper made flesh, patient rust for proud blades."
	if ent_name.find("arbiter") != -1 or id.find("arbiter") != -1:
		return "Gold’s decree incarnate, weighing souls with a silent scale."
	if ent_name.find("bastion") != -1 or id == "sodium_01":
		return "Salt-stone sentinel, unyielding to rot and rumor."
	return "An unknown force watches from the edges of the seal."

func _on_seal_attack() -> void:
	var changed := _mode != "attack"
	_mode = "attack"
	# Visual feedback
	if btn_seal_attack:
		btn_seal_attack.button_pressed = true
		_pulse_button(btn_seal_attack)
	if btn_seal_defense:
		btn_seal_defense.button_pressed = false
	if lbl_mode:
		lbl_mode.text = "Mode: ATTACK"
	if changed:
		_load_seal("attack")
		_refresh_details()
	_update_save_button_label()

func _on_seal_defense() -> void:
	var changed := _mode != "defense"
	_mode = "defense"
	# Visual feedback
	if btn_seal_attack:
		btn_seal_attack.button_pressed = false
	if btn_seal_defense:
		btn_seal_defense.button_pressed = true
		_pulse_button(btn_seal_defense)
	if lbl_mode:
		lbl_mode.text = "Mode: DEFENSE"
	if changed:
		_load_seal("defense")
		_refresh_details()
	_update_save_button_label()

func _pulse_button(btn: BaseButton) -> void:
	if btn == null:
		return
	var t = create_tween()
	btn.modulate = Color(1, 1, 1, 1)
	t.tween_property(btn, "modulate", Color(1.1, 1.1, 1.1, 1), 0.08)
	t.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.12)

func _on_save_pressed() -> void:
	if _has_saved:
		# If X area was clicked, skip loading.
		if btn_save:
			var local_x := btn_save.get_local_mouse_position().x
			if local_x >= btn_save.size.x - 180:
				return
		_load_seal(_mode)
	else:
		_save_seal(_mode)
	_update_save_button_label()

func _on_save_reset_pressed() -> void:
	var path := "user://seal_%s.json" % _mode
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_has_saved = false
	_update_save_button_label()

func _on_save_gui_input(ev: InputEvent) -> void:
	if not _has_saved:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		var _mb := ev as InputEventMouseButton
		var b := btn_save
		if b == null:
			return
		var local_x := b.get_local_mouse_position().x
		# If click near right edge, treat as reset.
		if local_x >= b.size.x - 180:
			_on_save_reset_pressed()
			b.accept_event()

func _on_play_pressed() -> void:
	if _spell_pending_id != "":
		_set_build_error("Wait for spell loadout confirmation.")
		return
	if not _spell_debug.unlock_all_buildings and _spell_backend != null and _spell_backend.token != "" and not _spell_synced:
		_set_build_error("Waiting for server spell loadouts.")
		return
	if _has_duplicate_build_items():
		_set_build_error("You can't choose the same item twice")
		return
	_set_build_error("")
	_save_seal(_mode)
	SceneRouter.set_combat_seal_mode(_mode)
	if ResourceLoader.exists("res://scenes/Combat.tscn"):
		get_tree().change_scene_to_file("res://scenes/Combat.tscn")
	else:
		_on_ready()

func _has_duplicate_build_items() -> bool:
	var e1 := _idx_to_id(_items, dd_item1)
	var e2 := _idx_to_id(_items, dd_item2)
	if e1 == "" or e2 == "":
		return false
	return e1 == e2

func _set_build_error(msg: String) -> void:
	if lbl_build_error == null:
		return
	lbl_build_error.text = msg

func _save_seal(which: String) -> void:
	var payload := {
		"mode": which,
		"entity_id": _current_entity_id,
		"homunculus_id": _current_homunculus_id,
		"equip_1": _idx_to_id(_items, dd_item1),
		"equip_2": _idx_to_id(_items, dd_item2),
		"side_1": _idx_to_id(_items, dd_side1),
		"side_2": _idx_to_id(_items, dd_side2),
		"attack_tech": _idx_to_id(_atk_techs, dd_atktech),
		"defense_tech": _idx_to_id(_def_techs, dd_deftech),
		"spell_ids": _equipped_spells(_mode, _current_entity_id),
	}
	var path := "user://seal_%s.json" % which
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()
	print("Saved SEAL %s -> %s" % [which.to_upper(), path])
	_has_saved = true

func _load_seal(which: String) -> void:
	var path := "user://seal_%s.json" % which
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.has("entity_id"):
		_current_entity_id = str(data.get("entity_id", _current_entity_id))
	if data.has("homunculus_id"):
		_current_homunculus_id = str(data.get("homunculus_id", _current_homunculus_id))
	_refresh_details()

	_set_button_selection(dd_item1, _items, data.get("equip_1", ""))
	_set_button_selection(dd_item2, _items, data.get("equip_2", ""))
	_set_button_selection(dd_side1, _items, data.get("side_1", ""))
	_set_button_selection(dd_side2, _items, data.get("side_2", ""))
	_set_button_selection(dd_atktech, _atk_techs, data.get("attack_tech", ""))
	_set_button_selection(dd_deftech, _def_techs, data.get("defense_tech", ""))

func _set_button_selection(btn: Button, items: Array, desired) -> void:
	if btn == null:
		return
	if items == null or items.size() == 0:
		return
	var target := str(desired)
	var idx := 0
	for i in range(items.size()):
		var item = items[i]
		var id = ""
		if typeof(item) == TYPE_DICTIONARY:
			id = str(item.get("id", ""))
		else:
			id = str(item)
		var label = _label_for_item(item, "None")
		if id == target or label == target:
			idx = i
			break
	btn.set_meta("items", items)
	btn.set_meta("selected_idx", idx)
	btn.text = _label_for_item(items[idx], "None")
	_refresh_build_slot_icon(btn)

func _refresh_build_slot_icon(btn: Button) -> void:
	if btn not in [dd_item1, dd_item2, dd_side1, dd_side2]:
		return
	var item := _get_selected_item_from_button(btn)
	btn.icon = _load_item_icon(item) if not item.is_empty() else null
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 40)

func _wire_build_tooltips() -> void:
	var build_buttons := [dd_item1, dd_item2, dd_side1, dd_side2]
	for b in build_buttons:
		if b == null:
			continue
		if not b.mouse_entered.is_connected(Callable(self, "_on_build_hover_entered")):
			b.mouse_entered.connect(Callable(self, "_on_build_hover_entered").bind(b))
		if not b.mouse_exited.is_connected(Callable(self, "_on_build_hover_exited")):
			b.mouse_exited.connect(Callable(self, "_on_build_hover_exited"))

func _on_build_hover_entered(btn: Button) -> void:
	if tooltip_panel == null or tooltip_label == null or tooltip_icon == null:
		return
	var item := _get_selected_item_from_button(btn)
	if item == null or item.is_empty():
		return
	var helper = preload("res://scripts/domain/item_progress.gd")
	var level: int = helper.level_for(str(item.get("id", "")), _spell_state.get("item_progress", {}))
	var effective: Dictionary = helper.effective_item(item, _spell_state.get("item_progress", {}))
	tooltip_label.text = "%s  |  Level %d\n%s\n%s" % [_label_for_item(item, "None"), level, _item_desc(item), str(effective.get("effects", {}))]
	tooltip_icon.texture = _load_item_icon(item)
	tooltip_panel.visible = true
	tooltip_panel.custom_minimum_size = Vector2.ZERO
	tooltip_panel.size = Vector2.ZERO
	var label_min := tooltip_label.get_minimum_size()
	var icon_min := tooltip_icon.get_minimum_size()
	var sep := 6.0
	var w: float = float(max(label_min.x, icon_min.x)) + 16.0
	var h: float = float(icon_min.y) + sep + float(label_min.y) + 16.0
	if w < 220.0:
		w = 220.0
	var min_size := Vector2(w, h)
	tooltip_panel.custom_minimum_size = min_size
	tooltip_panel.size = min_size
	var gp := btn.get_global_rect().position
	tooltip_panel.global_position = gp + Vector2(0, btn.size.y + 6)

func _on_build_hover_exited() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _get_selected_item_from_button(btn: Button) -> Dictionary:
	var items = btn.get_meta("items")
	if items == null or items.size() == 0:
		return {}
	var sidx = btn.get_meta("selected_idx")
	if typeof(sidx) != TYPE_INT:
		sidx = int(sidx)
	if sidx >= 0 and sidx < items.size():
		return items[sidx]
	return {}

func _item_desc(item: Dictionary) -> String:
	return str(item.get("desc", ""))

func _load_item_icon(item: Dictionary) -> Texture2D:
	var pid: String = str(item.get("id", ""))
	var file: String = str(ITEM_ICON_MAP.get(pid, ""))
	if file != "":
		var p = "%s%s" % [BUILD_DIR, file]
		if ResourceLoader.exists(p):
			return load(p)
	var fallback: String = _normalize_id(str(item.get("name", ""))).replace("-", "_")
	if fallback != "":
		var p2 = "%s%s.png" % [BUILD_DIR, fallback]
		if ResourceLoader.exists(p2):
			return load(p2)
	return null

func _update_save_button_label() -> void:
	if btn_save == null:
		return
	var path := "user://seal_%s.json" % _mode
	_has_saved = FileAccess.file_exists(path)
	btn_save.text = "Load Seal              [X]" if _has_saved else "Save Seal"

func _idx_to_id(_arr: Array, dd: Node) -> String:
	if dd == null:
		return ""
	# OptionButton path
	if dd is OptionButton:
		var ob := dd as OptionButton
		var idx = ob.get_selected_id()
		var meta = ob.get_meta("items")
		if meta == null:
			return ""
		if idx >= 0 and idx < meta.size():
			var item = meta[idx]
			if typeof(item) == TYPE_DICTIONARY and item.has("id"):
				return str(item["id"])
			return str(item)
		return ""
	# Button path: read selected_idx meta
	if dd is Button:
		var sidx = dd.get_meta("selected_idx")
		var items = dd.get_meta("items")
		if items == null:
			return ""
		if typeof(sidx) != TYPE_INT:
			sidx = int(sidx)
		if sidx >= 0 and sidx < items.size():
			var item = items[sidx]
			if typeof(item) == TYPE_DICTIONARY and item.has("id"):
				return str(item["id"])
			return str(item)
		return ""
	return ""

func _on_ready() -> void:
	print("READY (attack) - next: combat scene should consume user://seal_attack.json")

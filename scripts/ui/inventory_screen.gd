extends Control
class_name InventoryScreen

const ULTRA_MAP := {
	"sulfur": [
		{"name": "Ember", "effects": [{"kind": "heal", "value": 14}]},
		{"name": "Crucible", "effects": [{"kind": "atk_boost", "value": 0.35, "penalty": 0.15}]}
	],
	"mercury": [
		{"name": "Quicksilver", "effects": [{"kind": "hom_stun", "value": 1}]},
		{"name": "Slipstream", "effects": [{"kind": "shield", "value": 0.15}, {"kind": "atk_down", "value": 0.1}]}
	],
	"sodium": [
		{"name": "Bulwark", "effects": [{"kind": "shield", "value": 0.22}, {"kind": "atk_down", "value": 0.1}]},
		{"name": "Tonic", "effects": [{"kind": "heal", "value": 16}, {"kind": "vuln", "value": 0.1}]}
	],
	"aether": [
		{"name": "Null", "effects": [{"kind": "hom_stun", "value": 1}, {"kind": "vuln", "value": 0.1}]},
		{"name": "Flux", "effects": [{"kind": "atk_boost", "value": 0.25, "penalty": 0.1}]}
	],
	"vitriol": [
		{"name": "Corrode", "effects": [{"kind": "poison", "value": 3}]},
		{"name": "Miasma", "effects": [{"kind": "atk_down", "value": 0.15}, {"kind": "vuln", "value": 0.1}]}
	],
	"gold": [
		{"name": "Edict", "effects": [{"kind": "shield", "value": 0.18}, {"kind": "atk_down", "value": 0.1}]},
		{"name": "Mirror", "effects": [{"kind": "reflect", "value": 0.2}]}
	]
}

const PREVIEW_DIR := "res://assets/entities/previews_256/"
const HOM_PREVIEW_DIR := "res://assets/entities/previews_256/homunculus/"
const BUILD_DIR := "res://assets/entities/builds/"

@export var panel_path: NodePath
@export var back_button_path: NodePath
@export var loadout_button_path: NodePath
@export var tabs_path: NodePath
@export var entities_list_path: NodePath
@export var builds_list_path: NodePath
@export var homunculi_list_path: NodePath
@export var ultrahit_list_path: NodePath
@export var techs_list_path: NodePath

var _panel: Panel = null
var _back_button: Button = null
var _loadout_button: Button = null
var _tabs: TabContainer = null
var _entities_list: VBoxContainer = null
var _builds_list: VBoxContainer = null
var _homunculi_list: VBoxContainer = null
var _ultrahit_list: VBoxContainer = null
var _techs_list: VBoxContainer = null

var _catalog := AssetCatalog.new()
var _registry: DataRegistry = null
var _ui_scale := 1.0

const CONTENT_BASE_SIZE := Vector2(1400, 660)

func _ready() -> void:
	_ui_scale = _compute_panel_scale()
	UIThemeFactory.apply_theme_scaled(self, _ui_scale)
	_resolve_nodes()
	_apply_tab_titles()
	_apply_panel_background()
	_connect_buttons()
	_load_registry()
	_populate_lists()
	_apply_initial_tab()

func _apply_tab_titles() -> void:
	if _tabs == null:
		return
	for i in range(_tabs.get_tab_count()):
		var child = _tabs.get_child(i)
		if child == null:
			continue
		var tab_name = str(child.name)
		if tab_name == "Ultrahit":
			_tabs.set_tab_title(i, "UltraHit")
		if tab_name == "Techs":
			_tabs.set_tab_title(i, "Techs")

func _resolve_nodes() -> void:
	_panel = get_node_or_null(panel_path) as Panel
	_back_button = get_node_or_null(back_button_path) as Button
	_loadout_button = get_node_or_null(loadout_button_path) as Button
	_tabs = get_node_or_null(tabs_path) as TabContainer
	_entities_list = get_node_or_null(entities_list_path) as VBoxContainer
	_builds_list = get_node_or_null(builds_list_path) as VBoxContainer
	_homunculi_list = get_node_or_null(homunculi_list_path) as VBoxContainer
	_ultrahit_list = get_node_or_null(ultrahit_list_path) as VBoxContainer
	_techs_list = get_node_or_null(techs_list_path) as VBoxContainer

func _apply_panel_background() -> void:
	if _panel == null:
		return
	var tex: Texture2D = _catalog.get_tex("ui_panel")
	if tex == null:
		return
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	UIThemeFactory._configure_stylebox(sb)
	_panel.add_theme_stylebox_override("panel", sb)

func _connect_buttons() -> void:
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	if _loadout_button != null:
		_loadout_button.pressed.connect(_on_loadout_pressed)

func _on_back_pressed() -> void:
	if _back_button != null:
		_back_button.disabled = true
	SceneRouter.go_to_main_menu()

func _on_loadout_pressed() -> void:
	if _loadout_button != null:
		_loadout_button.disabled = true
	SceneRouter.go_to_loadout()

func _load_registry() -> void:
	var registry_script = load("res://scripts/data_registry.gd")
	if registry_script == null:
		push_warning("InventoryScreen: data_registry.gd not found.")
		return
	var instance = registry_script.new()
	if instance is DataRegistry:
		_registry = instance
	else:
		push_warning("InventoryScreen: data_registry.gd is not a DataRegistry.")

func _populate_lists() -> void:
	_populate_entities()
	_populate_builds()
	_populate_homunculi()
	_populate_ultrahit()
	_populate_techs()

func _populate_entities() -> void:
	if _entities_list == null:
		return
	_clear_container(_entities_list)
	if _registry == null:
		_add_placeholder(_entities_list)
		return
	if not _registry.has_method("get_entities"):
		push_warning("InventoryScreen: DataRegistry missing get_entities().")
		_add_placeholder(_entities_list)
		return
	var entities = _registry.get_entities()
	var list = _dict_to_sorted_list(entities, "entity")
	if list.is_empty():
		_add_placeholder(_entities_list)
		return
	for entry in list:
		_entities_list.add_child(_make_entry_row(entry))

func _populate_builds() -> void:
	if _builds_list == null:
		return
	_clear_container(_builds_list)
	if _registry == null:
		_add_placeholder(_builds_list)
		return
	if not _registry.has_method("get_items"):
		push_warning("InventoryScreen: DataRegistry missing get_items().")
		_add_placeholder(_builds_list)
		return
	var items = _registry.get_items()
	var list = _dict_to_sorted_list(items, "build")
	if list.is_empty():
		_add_placeholder(_builds_list)
		return
	for entry in list:
		_builds_list.add_child(_make_entry_row(entry, true))

func _populate_homunculi() -> void:
	if _homunculi_list == null:
		return
	_clear_container(_homunculi_list)
	if _registry == null:
		_add_placeholder(_homunculi_list)
		return
	if not _registry.has_method("get_homunculi"):
		push_warning("InventoryScreen: DataRegistry missing get_homunculi().")
		_add_placeholder(_homunculi_list)
		return
	var homunculi = _registry.get_homunculi()
	var list = _dict_to_sorted_list(homunculi, "homunculus")
	if list.is_empty():
		_add_placeholder(_homunculi_list)
		return
	for entry in list:
		_homunculi_list.add_child(_make_entry_row(entry))

func _populate_ultrahit() -> void:
	if _ultrahit_list == null:
		return
	_clear_container(_ultrahit_list)
	var entries = _build_ultrahit_entries()
	if entries.is_empty():
		_add_placeholder(_ultrahit_list)
		return
	for entry in entries:
		_ultrahit_list.add_child(_make_entry_row(entry, false, true))

func _populate_techs() -> void:
	if _techs_list == null:
		return
	_clear_container(_techs_list)
	if _registry == null:
		_add_placeholder(_techs_list)
		return
	var entries: Array = []
	if _registry.has_method("get_attack_techniques"):
		var attack = _registry.get_attack_techniques()
		if typeof(attack) == TYPE_ARRAY:
			entries.append_array(attack)
	if _registry.has_method("get_defense_techniques"):
		var defense = _registry.get_defense_techniques()
		if typeof(defense) == TYPE_ARRAY:
			entries.append_array(defense)
	if entries.is_empty():
		_add_placeholder(_techs_list)
		return
	for entry in entries:
		_techs_list.add_child(_make_entry_row(entry))

func _build_ultrahit_entries() -> Array:
	var out: Array = []
	if _registry == null:
		return out
	var entities = {}
	if _registry.has_method("get_entities"):
		entities = _registry.get_entities()
	if typeof(entities) != TYPE_DICTIONARY:
		return out
	for key in entities.keys():
		var ent = entities[key]
		if typeof(ent) != TYPE_DICTIONARY:
			continue
		var ent_id = str(ent.get("id", key))
		var ent_name = str(ent.get("name", ent_id))
		var ent_type = str(ent.get("type", "")).to_lower()
		if not ULTRA_MAP.has(ent_type):
			continue
		var ultras: Array = ULTRA_MAP[ent_type]
		for ultra in ultras:
			var ultra_name = str(ultra.get("name", "Ultra"))
			var entry = {
				"id": "%s_%s" % [ent_type, ultra_name],
				"name": "%s - %s" % [ent_name, ultra_name],
				"desc": _ultra_desc(ultra),
				"kind": "ultra",
				"preview_id": ent_id
			}
			out.append(entry)
	out.sort_custom(Callable(self, "_sort_by_name"))
	return out

func _ultra_desc(ultra: Dictionary) -> String:
	var effects: Array = ultra.get("effects", [])
	var parts: Array = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var kind: String = str(effect.get("kind", ""))
		match kind:
			"heal":
				parts.append("Heal %d" % int(effect.get("value", 0)))
			"shield":
				parts.append("Ward %d%%" % int(float(effect.get("value", 0.0)) * 100))
			"atk_boost":
				parts.append("+%d%% atk" % int(float(effect.get("value", 0.0)) * 100))
			"hom_stun":
				parts.append("Seal homunculus")
			"atk_down":
				parts.append("-%d%% atk" % int(float(effect.get("value", 0.0)) * 100))
			"poison":
				parts.append("Poison")
			"reflect":
				parts.append("Reflect %d%%" % int(float(effect.get("value", 0.0)) * 100))
			"vuln":
				parts.append("+%d%% dmg taken" % int(float(effect.get("value", 0.0)) * 100))
	return ", ".join(parts)

func _apply_initial_tab() -> void:
	if _tabs == null:
		return
	var tab_label := SceneRouter.consume_inventory_tab()
	if tab_label == "":
		return
	var idx = _find_tab_index(tab_label)
	if idx >= 0:
		_tabs.current_tab = idx

func _find_tab_index(tab_label: String) -> int:
	var needle = tab_label.to_lower()
	for i in range(_tabs.get_tab_count()):
		var title = _tabs.get_tab_title(i).to_lower()
		if title.find(needle) != -1:
			return i
	return -1

func _make_entry_row(entry: Variant, include_costs: bool = false, is_ultra: bool = false) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var icon_slot := UIThemeFactory.make_icon_slot()
	var icon_size = int(round(96.0 * _ui_scale))
	icon_slot.custom_minimum_size = Vector2(icon_size, icon_size)
	var icon = icon_slot.get_node_or_null("Icon")
	if icon is TextureRect:
		var preview = _extract_preview_texture(entry)
		if preview != null:
			icon.texture = preview
		else:
			var icon_id = _extract_icon_id(entry)
			if icon_id != "":
				icon.texture = _catalog.get_tex(icon_id)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.add_child(icon_slot)
	var name_label := Label.new()
	name_label.text = _extract_name(entry)
	name_label.add_theme_font_size_override("font_size", int(round(18.0 * _ui_scale)))
	header.add_child(name_label)
	row.add_child(header)
	if is_ultra and typeof(entry) == TYPE_DICTIONARY:
		row.tooltip_text = str(entry.get("desc", ""))
	if include_costs:
		var cost = _extract_cost(entry)
		if not cost.is_empty():
			row.add_child(_make_cost_row(cost))
	return row

func _make_cost_row(cost: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for key in cost.keys():
		var slot := UIThemeFactory.make_icon_slot()
		var slot_size = int(round(32.0 * _ui_scale))
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		var icon = slot.get_node_or_null("Icon")
		if icon is TextureRect:
			icon.texture = _catalog.get_tex(str(key))
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var amount := Label.new()
		amount.text = str(cost[key])
		row.add_child(slot)
		row.add_child(amount)
	return row

func _extract_name(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str(entry.get("name", entry.get("id", "Unknown")))
	return str(entry)

func _extract_icon_id(entry: Variant) -> String:
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	var icon_id = str(entry.get("icon_id", entry.get("tex_id", entry.get("icon", ""))))
	return icon_id

func _extract_preview_texture(entry: Variant) -> Texture2D:
	if typeof(entry) != TYPE_DICTIONARY:
		return null
	if entry.has("preview_tex") and entry.get("preview_tex") is Texture2D:
		return entry.get("preview_tex")
	var preview_path = str(entry.get("preview_path", ""))
	if preview_path != "" and ResourceLoader.exists(preview_path):
		return load(preview_path)
	var kind = str(entry.get("kind", ""))
	var pid = str(entry.get("id", entry.get("preview_id", "")))
	if kind == "ultra":
		pid = str(entry.get("preview_id", pid))
		kind = "entity"
	if pid == "":
		return null
	match kind:
		"entity":
			return _load_preview_from_dir(PREVIEW_DIR, pid)
		"homunculus":
			return _load_preview_from_dir(HOM_PREVIEW_DIR, pid)
		"build":
			return _load_build_preview(pid, entry)
		_:
			return null

func _load_preview_from_dir(base: String, pid: String) -> Texture2D:
	var p0 = "%s%s.png" % [base, pid]
	var p1 = "%s%s_01.png" % [base, pid]
	if ResourceLoader.exists(p1):
		return load(p1)
	if ResourceLoader.exists(p0):
		return load(p0)
	return null

func _load_build_preview(pid: String, entry: Dictionary) -> Texture2D:
	var p0 = "%s%s.png" % [BUILD_DIR, pid]
	var p1 = "%s%s_01.png" % [BUILD_DIR, pid]
	if ResourceLoader.exists(p1):
		return load(p1)
	if ResourceLoader.exists(p0):
		return load(p0)
	var icon_id = _extract_icon_id(entry)
	if icon_id != "":
		var p2 = "%s%s.png" % [BUILD_DIR, icon_id]
		if ResourceLoader.exists(p2):
			return load(p2)
	return null

func _extract_cost(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	if entry.has("cost") and typeof(entry.get("cost")) == TYPE_DICTIONARY:
		return entry.get("cost")
	if entry.has("price") and typeof(entry.get("price")) == TYPE_DICTIONARY:
		return entry.get("price")
	if entry.has("costs") and typeof(entry.get("costs")) == TYPE_DICTIONARY:
		var costs = entry.get("costs")
		if costs.has("1") and typeof(costs.get("1")) == TYPE_DICTIONARY:
			return costs.get("1")
	return {}

func _dict_to_sorted_list(data: Variant, kind: String = "") -> Array:
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var entries: Array = []
	for key in data.keys():
		var entry = data[key]
		if typeof(entry) != TYPE_DICTIONARY:
			entry = {"id": key, "name": str(key)}
		if kind != "":
			entry["kind"] = kind
		entries.append(entry)
	entries.sort_custom(Callable(self, "_sort_by_name"))
	return entries

func _compute_panel_scale() -> float:
	var view = get_viewport_rect().size
	var content = Vector2(max(1.0, view.x - 200.0), max(1.0, view.y - 240.0))
	var ui_scale = min(content.x / CONTENT_BASE_SIZE.x, content.y / CONTENT_BASE_SIZE.y)
	return clamp(ui_scale, 0.9, 1.35)

func _sort_by_name(a: Variant, b: Variant) -> bool:
	return str(_extract_name(a)).to_lower() < str(_extract_name(b)).to_lower()

func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

func _add_placeholder(container: Control) -> void:
	var label := Label.new()
	label.text = "Coming soon"
	container.add_child(label)

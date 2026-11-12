extends Control
class_name InventoryScreen

const PREVIEW_DIR := "res://assets/entities/previews_256/"
const HOM_PREVIEW_DIR := "res://assets/entities/previews_256/homunculus/"
const BUILD_DIR := "res://assets/entities/builds/"
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const SpellView := preload("res://scripts/ui/spell_presentation.gd")
const LockIndicator := preload("res://scripts/ui/lock_indicator.gd")

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

func _exit_tree() -> void:
	_catalog.free()
	if is_instance_valid(_registry):
		_registry.free()
var _ui_scale := 1.0
var _return_to_lab := false
var _entry_group := ButtonGroup.new()
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_icon: TextureRect
var _detail_text: Label
var _tab_layouts: Array[HBoxContainer] = []
var _spell_filter := "All"
var _spell_entity := ""
var _spell_progress := {}
var _spell_progress_known := false
var _spell_backend: BackendClient
var _spell_entity_option: OptionButton
var _spell_filter_buttons: Array[Button] = []
var _item_progress: Dictionary = {}
var _item_progress_known := false

const CONTENT_BASE_SIZE := Vector2(1400, 660)

func _ready() -> void:
	_ui_scale = _compute_panel_scale()
	UIThemeFactory.apply_theme_scaled(self, _ui_scale)
	_resolve_nodes()
	_apply_tab_titles()
	_apply_panel_background()
	_setup_inventory_layout()
	_connect_buttons()
	_return_to_lab = SceneRouter.consume_inventory_return_to_lab()
	_entry_group.allow_unpress = false
	_load_registry()
	_setup_spell_progress()
	_populate_lists()
	_apply_initial_tab()
	_tabs.tab_changed.connect(_on_inventory_tab_changed)
	_on_inventory_tab_changed(_tabs.current_tab)

func _setup_inventory_layout() -> void:
	for button in [_back_button, _loadout_button]:
		if button:
			button.custom_minimum_size = Vector2(140, 44)
			MenuArt.button(button)
	for tab in _tabs.get_children():
		var scroll := tab.get_node_or_null("Scroll") as ScrollContainer
		if scroll == null:
			continue
		var layout := HBoxContainer.new()
		if tab.name == "Ultrahit":
			var column := VBoxContainer.new()
			column.set_anchors_preset(Control.PRESET_FULL_RECT)
			column.add_theme_constant_override("separation", 8)
			tab.add_child(column)
			var filters := HBoxContainer.new()
			filters.add_theme_constant_override("separation", 6)
			column.add_child(filters)
			var group := ButtonGroup.new()
			for filter_name in ["All", "Initial", "Hybrid", "Universal"]:
				var filter_button := Button.new()
				filter_button.text = filter_name
				filter_button.toggle_mode = true
				filter_button.button_group = group
				filter_button.custom_minimum_size = Vector2(74, 32)
				for state in ["normal", "hover", "pressed", "hover_pressed"]:
					var style := StyleBoxFlat.new()
					style.bg_color = Color(0.07, 0.24, 0.22, 0.95) if state in ["pressed", "hover_pressed"] else Color(0.03, 0.09, 0.1, 0.95)
					style.border_color = Color(0.8, 0.67, 0.35) if state in ["pressed", "hover_pressed"] else Color(0.3, 0.45, 0.42)
					style.set_border_width_all(1)
					filter_button.add_theme_stylebox_override(state, style)
				filter_button.button_pressed = filter_name == "All"
				filter_button.pressed.connect(_on_spell_filter_changed.bind(filter_name))
				filters.add_child(filter_button)
				_spell_filter_buttons.append(filter_button)
			_spell_entity_option = OptionButton.new()
			_spell_entity_option.custom_minimum_size.x = 160
			_spell_entity_option.item_selected.connect(_on_spell_entity_changed)
			filters.add_child(_spell_entity_option)
			layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
			column.add_child(layout)
		else:
			layout.set_anchors_preset(Control.PRESET_FULL_RECT)
			tab.add_child(layout)
		layout.add_theme_constant_override("separation", 18)
		scroll.reparent(layout)
		scroll.custom_minimum_size.x = 350
		scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tab_layouts.append(layout)
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_stylebox_override("panel", MenuArt.frame("marco-informativo-small.png", Vector4(95, 105, 80, 60)))
	_tab_layouts[0].add_child(_detail_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	var icon_frame := UIThemeFactory.make_icon_slot() as TextureRect
	icon_frame.texture = load(MenuArt.DIR + "marco-slot-small.png")
	icon_frame.custom_minimum_size = Vector2(112, 112)
	header.add_child(icon_frame)
	_detail_icon = icon_frame.get_node("Icon") as TextureRect
	_detail_title = Label.new()
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.add_theme_font_size_override("font_size", 24)
	header.add_child(_detail_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_detail_text = Label.new()
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.add_theme_font_size_override("font_size", 17)
	scroll.add_child(_detail_text)

func _setup_spell_progress() -> void:
	if _registry == null:
		return
	var ids: Array = _registry.entities.keys()
	ids.sort()
	for id in ids:
		var entity: Dictionary = _registry.entities[id]
		_spell_entity_option.add_item(str(entity.get("name", id)))
		_spell_entity_option.set_item_metadata(_spell_entity_option.item_count - 1, str(id))
	if _spell_entity_option.item_count > 0:
		_spell_entity = str(_spell_entity_option.get_item_metadata(0))
	var debug := DebugFlags.new()
	debug.reload()
	if debug.unlock_all_buildings:
		var debug_state := debug.load_lab_state()
		_spell_progress = debug_state.get("spell_progress", {})
		_item_progress = debug_state.get("item_progress", {})
		_item_progress_known = true
		_spell_progress_known = true
		debug.free()
		return
	debug.free()
	_spell_backend = BackendClient.new()
	_spell_backend.auto_dev_login = false
	_spell_backend.auto_flush = false
	_spell_backend.state_updated.connect(_on_spell_progress_updated)
	_spell_backend.auth_changed.connect(_on_spell_auth_changed)
	add_child(_spell_backend)
	if _spell_backend.token != "":
		_spell_backend.request_api("GET", "/player/state", null, true)

func _on_spell_progress_updated(state: Dictionary) -> void:
	_spell_progress = state.get("spell_progress", {})
	_spell_progress_known = not state.is_empty()
	_item_progress = state.get("item_progress", {})
	_item_progress_known = not state.is_empty()
	_refresh_build_levels()
	_refresh_spell_catalog()

func _on_spell_auth_changed(_token: String) -> void:
	_spell_progress = {}
	_spell_progress_known = false
	_item_progress = {}
	_item_progress_known = false
	_refresh_build_levels()
	_refresh_spell_catalog()
	if _token != "":
		_spell_backend.request_api("GET", "/player/state", null, true)

func _on_spell_filter_changed(value: String) -> void:
	_spell_filter = value
	_refresh_spell_catalog()

func _on_spell_entity_changed(index: int) -> void:
	_spell_entity = str(_spell_entity_option.get_item_metadata(index))
	_refresh_spell_catalog()

func _refresh_spell_catalog() -> void:
	if _registry == null or _ultrahit_list == null:
		return
	var selected_id := ""
	var old_button := _entry_group.get_pressed_button()
	if old_button != null and old_button.has_meta("entry"):
		var old_entry: Variant = old_button.get_meta("entry")
		if old_entry is Dictionary and old_entry.get("kind") == "spell":
			selected_id = str(old_entry.get("id", ""))
	var scroll := _ultrahit_list.get_parent() as ScrollContainer
	var old_scroll := scroll.scroll_vertical if scroll else 0
	_populate_spells()
	if _tabs.current_tab == 3:
		for child in _ultrahit_list.get_children():
			if child is Button and str(child.get_meta("entry").get("id", "")) == selected_id:
				child.button_pressed = true
				_show_entry(child.get_meta("entry"))
				if scroll: scroll.set_deferred("scroll_vertical", old_scroll)
				return
		_on_inventory_tab_changed(3)

func _on_inventory_tab_changed(index: int) -> void:
	if index < 0 or index >= _tab_layouts.size():
		return
	if _detail_panel.get_parent() != _tab_layouts[index]:
		_detail_panel.reparent(_tab_layouts[index])
	var lists := [_entities_list, _builds_list, _homunculi_list, _ultrahit_list, _techs_list]
	for child in lists[index].get_children():
		if child is Button:
			child.button_pressed = true
			_show_entry(child.get_meta("entry"))
			return
	_detail_title.text = ""
	_detail_text.text = "No entries available."
	_detail_icon.texture = null

func _show_entry(entry: Variant) -> void:
	_detail_title.text = _extract_name(entry)
	_detail_text.text = SpellView.detail(entry, str(entry.get("spell_status", "Unknown"))) if entry is Dictionary and entry.get("kind") == "spell" else _entry_details(entry)
	var cost := _extract_cost(entry)
	if not cost.is_empty():
		var parts: Array[String] = []
		for key in cost:
			parts.append("%s: %s" % [str(key).capitalize(), cost[key]])
		_detail_text.text += "\n\nCost: " + ", ".join(parts)
	_detail_icon.texture = _extract_preview_texture(entry)
	var icon_id := _extract_icon_id(entry)
	if _detail_icon.texture == null and icon_id != "":
		_detail_icon.texture = _catalog.get_tex(icon_id)

func _refresh_build_levels() -> void:
	if _builds_list == null:
		return
	for child in _builds_list.get_children():
		if child is Button and child.has_meta("entry"):
			var subtitle := child.get_node_or_null("EntryRow/EntryText/ItemLevel") as Label
			if subtitle != null:
				var id := str(child.get_meta("entry").get("id", ""))
				subtitle.text = "Level %d / 10" % int(_item_progress.get(id, {}).get("level", 0)) if _item_progress_known else "Level unavailable"
	var selected := _entry_group.get_pressed_button()
	if selected != null and selected.has_meta("entry") and selected.get_meta("entry").get("kind") == "build":
		_show_entry(selected.get_meta("entry"))

func _apply_tab_titles() -> void:
	if _tabs == null:
		return
	for i in range(_tabs.get_tab_count()):
		var child = _tabs.get_child(i)
		if child == null:
			continue
		var tab_name = str(child.name)
		if tab_name == "Ultrahit":
			_tabs.set_tab_title(i, "Spells")
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
	var tex: Texture2D = load("res://assets/ui/new-elements/fondo-inventario.png")
	if tex == null:
		return
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_panel.add_theme_stylebox_override("panel", sb)

func _connect_buttons() -> void:
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	if _loadout_button != null:
		_loadout_button.pressed.connect(_on_loadout_pressed)

func _on_back_pressed() -> void:
	if _back_button != null:
		_back_button.disabled = true
	if _return_to_lab:
		SceneRouter.go_to_lab_hub()
	else:
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
	_populate_spells()
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

func _populate_spells() -> void:
	if _ultrahit_list == null:
		return
	_clear_container(_ultrahit_list)
	var entries = _build_spell_entries()
	if entries.is_empty():
		_add_placeholder(_ultrahit_list)
		return
	for entry in entries:
		_ultrahit_list.add_child(_make_entry_row(entry))

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
			for technique in attack:
				if technique is Dictionary:
					var entry: Dictionary = technique.duplicate(true)
					if _extract_icon_id(entry) == "" and _catalog.has("rune_offensive"):
						entry["icon_id"] = "rune_offensive"
					entries.append(entry)
	if _registry.has_method("get_defense_techniques"):
		var defense = _registry.get_defense_techniques()
		if typeof(defense) == TYPE_ARRAY:
			for technique in defense:
				if technique is Dictionary:
					var entry: Dictionary = technique.duplicate(true)
					if _extract_icon_id(entry) == "" and _catalog.has("rune_defense"):
						entry["icon_id"] = "rune_defense"
					entries.append(entry)
	if entries.is_empty():
		_add_placeholder(_techs_list)
		return
	for entry in entries:
		_techs_list.add_child(_make_entry_row(entry))

func _build_spell_entries() -> Array:
	var out: Array = []
	if _registry == null:
		return out
	var ent_type := str(_registry.entities.get(_spell_entity, {}).get("type", ""))
	for spell in _registry.spells.values():
		if _spell_filter != "All" and SpellView.group(spell) != _spell_filter:
			continue
		var entry: Dictionary = spell.duplicate(true)
		entry["kind"] = "spell"
		var preview_type := str(entry.get("primary_type", entry.get("type", "")))
		entry["preview_id"] = _spell_entity
		for entity_id in _registry.entities:
			if str(_registry.entities[entity_id].get("type", "")) == preview_type:
				entry["preview_id"] = str(entity_id)
				break
		entry["spell_status"] = SpellView.status(entry, _spell_entity, ent_type, _spell_progress, _spell_progress_known)
		out.append(entry)
	out.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out

func _spell_effects(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		var kind: String = str(effect.get("kind", ""))
		var value := float(effect.get("value", 0))
		var pct := int(round(value * 100.0))
		var target := "propio" if effect.get("target") == "self" else "enemigo"
		match kind:
			"heal": parts.append("Cura %d HP (%s)" % [int(value), target])
			"shield": parts.append("Escudo %d %% (%s)" % [pct, target])
			"atk_boost": parts.append("Ataque +%d %% (%s)" % [pct, target])
			"atk_down": parts.append("Ataque -%d %% (%s)" % [pct, target])
			"hom_stun": parts.append("Bloquea homúnculo %d turno(s)" % int(value))
			"poison": parts.append("Veneno %d turno(s) (%s)" % [int(value), target])
			"reflect": parts.append("Refleja %d %% de daño (%s)" % [pct, target])
			"vuln": parts.append("Vulnerabilidad %d %% (%s)" % [pct, target])
			"type_neutralize": parts.append("Reduce %d %% la ventaja o desventaja de tipo en el próximo intercambio" % pct)
			"bonus_if_poisoned": parts.append("Potencia +%d %% si el enemigo ya está envenenado" % pct)
			"bonus_if_hit_last_exchange": parts.append("Potencia +%d %% si recibió daño en el intercambio anterior" % pct)
	return "; ".join(parts) if not parts.is_empty() else "Sin efecto adicional"

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
	if needle == "ultrahit":
		needle = "spells"
	for i in range(_tabs.get_tab_count()):
		var title = _tabs.get_tab_title(i).to_lower()
		if title.find(needle) != -1:
			return i
	return -1

func _make_entry_row(entry: Variant, _include_costs: bool = false) -> Control:
	var select := Button.new()
	select.custom_minimum_size = Vector2(0, 72)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.toggle_mode = true
	select.button_group = _entry_group
	select.set_meta("entry", entry)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.16, 0.16, 0.96) if state in ["pressed", "hover_pressed"] else Color(0.02, 0.07, 0.08, 0.9)
		if state == "hover":
			style.bg_color = Color(0.07, 0.2, 0.2, 0.95)
		style.border_color = Color(0.74, 0.6, 0.29) if state in ["pressed", "hover_pressed"] else Color(0.28, 0.42, 0.39)
		style.set_border_width_all(1)
		select.add_theme_stylebox_override(state, style)
	select.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.name = "EntryRow"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 4
	row.offset_bottom = -4
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select.add_child(row)
	var icon_slot := UIThemeFactory.make_icon_slot() as TextureRect
	icon_slot.texture = load(MenuArt.DIR + "marco-slot-small.png")
	icon_slot.custom_minimum_size = Vector2(58, 58)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := icon_slot.get_node("Icon") as TextureRect
	icon.texture = _extract_preview_texture(entry)
	var icon_id := _extract_icon_id(entry)
	if icon.texture == null and icon_id != "":
		icon.texture = _catalog.get_tex(icon_id)
	row.add_child(icon_slot)
	var text_column := VBoxContainer.new()
	text_column.name = "EntryText"
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)
	var title := Label.new()
	title.text = _extract_name(entry)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(title)
	if entry is Dictionary and entry.get("kind") == "build":
		var item_level := Label.new()
		item_level.name = "ItemLevel"
		item_level.add_theme_font_size_override("font_size", 12)
		item_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_level.text = "Level %d / 10" % int(_item_progress.get(str(entry.get("id", "")), {}).get("level", 0)) if _item_progress_known else "Level unavailable"
		text_column.add_child(item_level)
	if entry is Dictionary and entry.get("kind") == "spell":
		var status := str(entry.get("spell_status", "Unknown"))
		var subtitle := Label.new()
		subtitle.text = "%s  |  %s" % [SpellView.affinity(entry), status]
		subtitle.add_theme_font_size_override("font_size", 12)
		subtitle.modulate = Color(0.73, 0.79, 0.76)
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_column.add_child(subtitle)
		if status == "Locked":
			var lock := LockIndicator.new()
			lock.custom_minimum_size = Vector2(22, 22)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lock)
			icon_slot.modulate = Color(0.65, 0.65, 0.65)
	select.toggled.connect(func(pressed: bool):
		if pressed: _show_entry(entry)
	)
	return select

func _entry_details(entry: Variant) -> String:
	if not entry is Dictionary:
		return "No details available."
	var lines: Array[String] = []
	var kind = str(entry.get("kind", ""))
	if kind == "entity":
		lines.append("Type: %s  |  Role: %s" % [str(entry.get("type", "Unknown")).capitalize(), str(entry.get("role", "Unknown")).capitalize()])
		var stats = entry.get("base_stats", {})
		if stats is Dictionary:
			lines.append("HP: %s    ATK: %s    GUARD: %s    TEMPO: %s" % [stats.get("hp", "-"), stats.get("power", "-"), stats.get("guard", "-"), stats.get("tempo", "-")])
	elif kind == "homunculus":
		lines.append("Rarity: %s" % str(entry.get("rarity", "Unknown")).capitalize())
		lines.append("Bonuses  |  ATK: %+d    GUARD: %+d    HP: %+d" % [int(entry.get("buff_atk", 0)), int(entry.get("buff_def", 0)), int(entry.get("buff_hp", 0))])
		var per_type = entry.get("per_type", {})
		if per_type is Dictionary and not per_type.is_empty():
			lines.append("Synergies:")
			for entity_type in per_type:
				if per_type[entity_type] is Dictionary:
					lines.append("  %s: %s" % [str(entity_type).capitalize(), _format_effects(per_type[entity_type])])
	elif kind == "build":
		lines.append("Level: %d / 10" % int(_item_progress.get(str(entry.get("id", "")), {}).get("level", 0)) if _item_progress_known else "Level: unavailable")
		lines.append("Rarity: %s" % str(entry.get("rarity", "Unknown")).capitalize())
		var effects = preload("res://scripts/domain/item_progress.gd").effective_item(entry, _item_progress).get("effects", {}) if _item_progress_known else entry.get("effects", {})
		if effects is Dictionary and not effects.is_empty():
			lines.append("Current effects: %s" % _format_effects(effects) if _item_progress_known else "Effects by level: %s" % _format_effects(effects))
	elif kind == "spell":
		lines.append("Type: %s  |  %s" % [str(entry.get("type", "Unknown")).capitalize(), str(entry.get("category", "")).capitalize()])
		lines.append("Power: x%.2f  |  Accuracy: %d%%  |  Cooldown: %d" % [float(entry.get("power_mult", 0)), int(round(float(entry.get("accuracy", 0)) * 100)), int(entry.get("cooldown_turns", 0))])
		lines.append("Efectos: %s" % _spell_effects(entry.get("effects", [])))
	var description = str(entry.get("desc", ""))
	if description != "":
		lines.append(description)
	return "\n".join(lines) if not lines.is_empty() else "No details available."

func _format_effects(effects: Dictionary) -> String:
	var parts: Array[String] = []
	for key in effects:
		var value = effects[key]
		var label = str(key).replace("_", " ").capitalize()
		if value is Array:
			var values: Array[String] = []
			for number in value:
				values.append(str(number))
			var levels = " (levels 1-%s)" % value.size() if value.size() > 1 else ""
			parts.append("%s%s: %s" % [label, levels, ", ".join(values)])
		else:
			parts.append("%s: %s" % [label, value])
	return "; ".join(parts)

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
	if kind == "spell":
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
	var mapped_files := {
		"bismuth_talisman": "talisman_bismuth.png",
		"wind_amulet": "wind_amulet.png",
		"mirror_sigel": "mirror.png",
		"vitriol_vial": "vitriol.png",
	}
	if mapped_files.has(pid):
		var mapped_path: String = BUILD_DIR + mapped_files[pid]
		if ResourceLoader.exists(mapped_path):
			return load(mapped_path)
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
		container.remove_child(child)
		child.queue_free()

func _add_placeholder(container: Control) -> void:
	var label := Label.new()
	label.text = "No data available"
	container.add_child(label)

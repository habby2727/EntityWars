extends VBoxContainer

signal debug_forge_updated(state: Dictionary)

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const ITEM_FILES := {"bismuth_talisman": "talisman_bismuth", "mirror_sigel": "mirror", "vitriol_vial": "vitriol"}

var _registry: DataRegistry
var _current_id := ""
var _backend: BackendClient
var _forge_state: Dictionary = {}
var _forge_item := ""
var _forge_pending := ""
var _forge_button: Button
var _forge_status: Label
var _forge_info: Label
var _forge_confirm: ConfirmationDialog
var _forge_debug := false
var _forge_synced := false
var _forge_base_cost := 20
var _forge_cost_per_level := 10

func setup(registry: DataRegistry, backend: BackendClient, debug: bool, base_cost: int, cost_per_level: int) -> void:
	_registry = registry
	_backend = backend
	_forge_debug = debug
	_forge_base_cost = base_cost
	_forge_cost_per_level = cost_per_level
	if _backend != null:
		_backend.action_confirmed.connect(_forge_confirmed)
		_backend.action_failed.connect(_forge_failed)
		_backend.action_uncertain.connect(_forge_uncertain)
		_backend.auth_changed.connect(func(_token): _update_forge_button())
	custom_minimum_size.y = 210
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

func show_building(building_id: String, state: Dictionary, building_names: Dictionary, metrics: Dictionary = {}, synced: bool = false) -> void:
	if state.is_empty():
		_forge_pending = ""
	_forge_state = state
	_forge_synced = synced
	if building_id == _current_id and building_id in ["build_forge", "homunculus_vat", "sync_nexus", "anomaly_containment"]:
		_update_forge_button()
		return
	_current_id = building_id
	_forge_button = null
	_forge_status = null
	_forge_info = null
	_forge_confirm = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = true
	match building_id:
		"build_forge": _catalog(false)
		"homunculus_vat": _catalog(true)
		"sync_nexus": _unconfigured("Nexus status", ["Overview", "Projects", "Contributions"])
		"anomaly_containment": _unconfigured("Containment status", ["Threats", "Containment", "History"])
		"lab_th": _hq(state, building_names)
		"essence_reactor": _message("PRODUCTION", "Current rate: %.1f Essence / hour\nStored at last update: %.1f Essence\nRates and storage are estimates until confirmed by the server." % [float(metrics.get("rate", 0)), float(metrics.get("stored", 0))])
		"storage_vault": _message("STORAGE", "Capacity: %s   |   Next level: %s\nResources:\n%s" % [metrics.get("capacity", "-"), metrics.get("next_capacity", "-"), _format_values(state.get("wallet", {}))])
		"trade_hall": _message("MARKET AND JOBS", "Open Trade Hall to manage market orders and trade jobs.")
		"world_gate": _message("WORLD ACCESS", "Open World Gate to access the available zones.")
		_:
			visible = false

func _message(title: String, message: String) -> void:
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 18)
	add_child(heading)
	var description := Label.new()
	description.text = message
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)

func _hq(state: Dictionary, names: Dictionary) -> void:
	var level := int(state.get("lab", {}).get("hqLevel", 1))
	var unlocked: Array[String] = []
	var next: Array[String] = []
	for id in names:
		if id == "lab_th":
			continue
		var required := HqRules.get_unlock_level(id)
		if required <= level:
			unlocked.append(str(names[id]))
		elif required == level + 1:
			next.append(str(names[id]))
	_message("LAB PROGRESS", "Unlocked: %s\nNext HQ level: %s" % [", ".join(unlocked), ", ".join(next) if not next.is_empty() else "No additional unlocks"])

func _unconfigured(title: String, tabs: Array) -> void:
	var heading := Label.new()
	heading.text = title + "  |  Not configured"
	heading.add_theme_font_size_override("font_size", 18)
	add_child(heading)
	var container := TabContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(container)
	for name in tabs:
		var label := Label.new()
		label.name = name
		label.text = "Not configured. No server data is available for this feature."
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(label)

func _catalog(homunculi: bool) -> void:
	var title := Label.new()
	title.text = "HOMUNCULUS CATALOG" if homunculi else "TALISMAN CATALOG"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var entries: Dictionary = _registry.get_homunculi() if homunculi else _registry.get_items()
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(220, 150)
	list.add_theme_font_size_override("font_size", 19)
	var list_bg := StyleBoxFlat.new()
	list_bg.bg_color = Color(0.02, 0.08, 0.08, 0.94)
	list.add_theme_stylebox_override("panel", list_bg)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color(0.08, 0.27, 0.24, 1)
	selected.border_color = Color(0.75, 0.62, 0.32)
	selected.set_border_width_all(1)
	list.add_theme_stylebox_override("selected", selected)
	list.add_theme_stylebox_override("selected_focus", selected)
	row.add_child(list)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(120, 120)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	var heading := Label.new()
	heading.add_theme_font_size_override("font_size", 18)
	details.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(scroll)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 19)
	if not homunculi:
		_forge_info = info
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(info)
	var actions := HBoxContainer.new()
	details.add_child(actions)
	for label in (["Upgrade Homunculus", "Mutation"] if homunculi else ["Upgrade", "Reroll"]):
		var action := Button.new()
		action.text = label
		action.disabled = true
		action.tooltip_text = "Not implemented on the server."
		MenuArt.button(action)
		actions.add_child(action)
		if not homunculi and label == "Upgrade":
			_forge_button = action
			action.tooltip_text = "Upgrade selected talisman"
			action.pressed.connect(_request_forge_confirmation)
	var inventory := Button.new()
	inventory.text = "Open Inventory"
	MenuArt.button(inventory)
	inventory.pressed.connect(func(): SceneRouter.go_to_inventory("Homunculi" if homunculi else "Builds", true))
	actions.add_child(inventory)
	if not homunculi:
		_forge_status = Label.new()
		_forge_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(_forge_status)
		_forge_confirm = ConfirmationDialog.new()
		_forge_confirm.title = "Upgrade talisman"
		_forge_confirm.confirmed.connect(_send_forge_upgrade)
		add_child(_forge_confirm)
	var keys := entries.keys()
	keys.sort()
	for id in keys:
		list.add_item(str(entries[id].get("name", id)))
		list.set_item_metadata(list.item_count - 1, id)
	var select := func(index: int):
		var id := str(list.get_item_metadata(index))
		if not homunculi:
			_forge_item = id
			_update_forge_button()
		var entry: Dictionary = entries[id]
		heading.text = str(entry.get("name", id))
		if homunculi:
			info.text = "%s\nBase bonuses: ATK %+d, GUARD %+d, HP %+d\nSynergies:\n%s\nEvolution and mutations: not implemented." % [entry.get("desc", ""), int(entry.get("buff_atk", 0)), int(entry.get("buff_def", 0)), int(entry.get("buff_hp", 0)), _format_values(entry.get("per_type", {}))]
		else:
			_update_forge_button()
		var file: String = str(ITEM_FILES.get(id, id))
		var path := ("res://assets/entities/previews_256/homunculus/" if homunculi else "res://assets/entities/builds/") + file + ".png"
		preview.texture = load(path) if ResourceLoader.exists(path) else null
	list.item_selected.connect(select)
	if list.item_count > 0:
		list.select(0)
		select.call(0)

func _update_forge_button() -> void:
	if not is_instance_valid(_forge_button) or not is_instance_valid(_forge_status):
		return
	var progress: Dictionary = _forge_state.get("item_progress", {})
	var level := int(progress.get(_forge_item, {}).get("level", 0))
	if is_instance_valid(_forge_info) and _registry != null:
		var item: Dictionary = _registry.get_items().get(_forge_item, {})
		var helper = preload("res://scripts/domain/item_progress.gd")
		var current: Dictionary = helper.effective_item(item, progress)
		var next: Dictionary = helper.effective_item(item, {_forge_item: {"level": mini(10, level + 1)}})
		var base: Dictionary = helper.effective_item(item, {_forge_item: {"level": 0}})
		var level_one: Dictionary = helper.effective_item(item, {_forge_item: {"level": 1}})
		var level_two: Dictionary = helper.effective_item(item, {_forge_item: {"level": 2}})
		_forge_info.text = "%s\nBase (Lv 0): %s\nLv 1: %s\nLv 2: %s\nCurrent: %s\nNext: %s" % [item.get("desc", ""), _format_values(base.get("effects", {})), _format_values(level_one.get("effects", {})), _format_values(level_two.get("effects", {})), _format_values(current.get("effects", {})), _format_values(next.get("effects", {}))]
	var forge_level := int(_forge_state.get("lab", {}).get("buildings", {}).get("build_forge", {}).get("level", 0))
	var cost := maxi(0, _forge_base_cost + level * _forge_cost_per_level)
	var essence := int(_forge_state.get("wallet", {}).get("essence", 0))
	var online_ready := _backend != null and _backend.token != "" and _forge_synced
	var outstanding := ""
	if not _forge_debug and _backend != null:
		for action in _backend.get_pending_actions():
			if str(action.get("action_type", "")) == "FORGE_UPGRADE":
				outstanding = str(action.get("client_action_id", ""))
				break
		if _backend._verified_player_id.is_empty():
			_forge_pending = ""
		elif _forge_pending.is_empty() and not outstanding.is_empty():
			_forge_pending = outstanding
	_forge_button.disabled = _forge_item == "" or _forge_pending != "" or outstanding != "" or (not _forge_debug and not online_ready) or forge_level < 1 or level >= 10 or essence < cost
	_forge_status.text = "Level %d / 10 | Next: %s | Essence: %d / %d" % [level, str(level + 1) if level < 10 else "MAX", essence, cost]
	if _forge_pending != "" or outstanding != "":
		_forge_status.text += " | Waiting for confirmation / Reconnecting"
	elif _forge_debug:
		_forge_status.text += " | Local debug"
	elif _backend == null or _backend.token == "":
		_forge_status.text += " | Sign in to upgrade"
	elif not _forge_synced:
		_forge_status.text += " | Waiting for server state"
	elif forge_level < 1:
		_forge_status.text += " | Build Forge first"
	elif level < 10 and essence < cost:
		_forge_status.text += " | Insufficient Essence"

func _request_forge_confirmation() -> void:
	if _forge_button == null or _forge_button.disabled:
		return
	var level := int(_forge_state.get("item_progress", {}).get(_forge_item, {}).get("level", 0))
	_forge_confirm.dialog_text = "Upgrade %s from level %d to %d for %d Essence?" % [_forge_item, level, level + 1, maxi(0, _forge_base_cost + level * _forge_cost_per_level)]
	_forge_confirm.popup_centered()

func _send_forge_upgrade() -> void:
	if _forge_button == null or _forge_button.disabled:
		return
	if _forge_debug:
		var debug := DebugFlags.new()
		debug.reload()
		if not debug.unlock_all_buildings:
			_forge_status.text = "Debug mode is no longer active."
			debug.free()
			return
		var next := debug.load_lab_state()
		var progress: Dictionary = next.get("item_progress", {})
		var item: Dictionary = progress.get(_forge_item, {})
		var level := int(item.get("level", 0))
		var cost := maxi(0, _forge_base_cost + level * _forge_cost_per_level)
		var wallet: Dictionary = next.get("wallet", {})
		var forge: Dictionary = next.get("lab", {}).get("buildings", {}).get("build_forge", {})
		if level >= 10 or int(forge.get("level", 0)) < 1 or int(wallet.get("essence", 0)) < cost:
			_forge_status.text = "Upgrade requirements are not met."
			debug.free()
			return
		wallet["essence"] = int(wallet.get("essence", 0)) - cost
		item["level"] = level + 1
		progress[_forge_item] = item
		next["wallet"] = wallet
		next["item_progress"] = progress
		if not debug.save_lab_state(next):
			_forge_status.text = "Could not save local debug state."
			debug.free()
			return
		debug.free()
		_forge_state = next
		debug_forge_updated.emit(next)
		_update_forge_button()
		_forge_status.text += " | Upgrade saved"
		return
	if _backend == null:
		return
	_forge_pending = _backend.send_action({"action_type": "FORGE_UPGRADE", "payload": {"item_id": _forge_item}})
	_update_forge_button()
	if _forge_pending == "":
		_forge_status.text = "Could not send upgrade; check the connection."

func _forge_confirmed(action_id: String) -> void:
	if action_id != _forge_pending or action_id == "":
		return
	_forge_pending = ""
	_update_forge_button()
	if is_instance_valid(_forge_status):
		_forge_status.text += " | Upgrade confirmed"

func _forge_failed(action_id: String, error: String) -> void:
	if action_id == "" or action_id != _forge_pending:
		return
	_forge_pending = ""
	_update_forge_button()
	if is_instance_valid(_forge_status):
		_forge_status.text = "Upgrade failed: " + error

func _forge_uncertain(action_id: String, _reason: String) -> void:
	if action_id == _forge_pending:
		_forge_pending = action_id
		_update_forge_button()

func _format_values(values: Dictionary) -> String:
	var lines: Array[String] = []
	for key in values:
		var value: Variant = values[key]
		var formatted := _format_values(value).replace("\n", ", ") if value is Dictionary else str(value)
		lines.append("%s: %s" % [str(key).replace("_", " ").capitalize(), formatted])
	return "\n".join(lines)

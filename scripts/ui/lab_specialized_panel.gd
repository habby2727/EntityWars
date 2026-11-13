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
var _forge_trait_buttons: Array[Button] = []
var _forge_reroll_button: Button
var _forge_reroll_slot: OptionButton
var _forge_confirm_action := ""
var _forge_confirm_payload: Dictionary = {}

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
	_forge_reroll_button = null
	_forge_reroll_slot = null
	_forge_trait_buttons.clear()
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
		elif not homunculi and label == "Reroll":
			_forge_reroll_button = action
			action.pressed.connect(_request_forge_reroll)
	var inventory := Button.new()
	inventory.text = "Open Inventory"
	MenuArt.button(inventory)
	inventory.pressed.connect(func(): SceneRouter.go_to_inventory("Homunculi" if homunculi else "Builds", true))
	actions.add_child(inventory)
	if not homunculi:
		var trait_actions := HBoxContainer.new()
		details.add_child(trait_actions)
		_forge_reroll_slot = OptionButton.new()
		_forge_reroll_slot.tooltip_text = "Trait to reroll"
		for i in range(3):
			_forge_reroll_slot.add_item("Slot %d" % (i + 1))
		trait_actions.add_child(_forge_reroll_slot)
		for i in range(3):
			var trait_button := Button.new()
			trait_button.custom_minimum_size = Vector2(90, 38)
			MenuArt.button(trait_button)
			trait_actions.add_child(trait_button)
			_forge_trait_buttons.append(trait_button)
			trait_button.pressed.connect(_request_trait_action.bind(i))
		_forge_status = Label.new()
		_forge_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(_forge_status)
		_forge_confirm = ConfirmationDialog.new()
		_forge_confirm.title = "Upgrade talisman"
		_forge_confirm.confirmed.connect(_send_forge_confirmed)
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
	var item_state: Dictionary = progress.get(_forge_item, {}) if progress.get(_forge_item, {}) is Dictionary else {}
	var level := int(item_state.get("level", 0))
	var specialization := str(item_state.get("specialization", ""))
	var traits: Variant = item_state.get("traits", [])
	if not traits is Array:
		traits = []
	var offer: Variant = item_state.get("pending_reroll", {})
	if not offer is Dictionary:
		offer = {}
	var options: Variant = offer.get("options", [])
	if not options is Array:
		options = []
	var has_offer: bool = not offer.is_empty()
	var allocated := 0
	var trait_lines: Array[String] = []
	for trait_entry in traits:
		if trait_entry is Dictionary:
			var points := int(trait_entry.get("points", 0))
			allocated += points
			trait_lines.append("Equipped: %s | %d / 4" % [str(trait_entry.get("id", "Unknown")).replace("_", " ").capitalize(), points])
	if is_instance_valid(_forge_info) and _registry != null:
		var item: Dictionary = _registry.get_items().get(_forge_item, {})
		var helper = preload("res://scripts/domain/item_progress.gd")
		var current: Dictionary = helper.effective_item(item, progress)
		var next_state := item_state.duplicate(true)
		next_state["level"] = mini(10, level + 1)
		var next: Dictionary = helper.effective_item(item, {_forge_item: next_state})
		var base: Dictionary = helper.effective_item(item, {_forge_item: {"level": 0}})
		var level_one: Dictionary = helper.effective_item(item, {_forge_item: {"level": 1}})
		var level_two: Dictionary = helper.effective_item(item, {_forge_item: {"level": 2}})
		_forge_info.text = "%s\nSpecialization: %s | Unspent points: %d\n%s\nBase (Lv 0): %s\nLv 1: %s\nLv 2: %s\nCurrent: %s\nNext: %s" % [item.get("desc", ""), specialization.capitalize() if specialization != "" else "None", maxi(0, level - allocated), "\n".join(trait_lines), _format_values(base.get("effects", {})), _format_values(level_one.get("effects", {})), _format_values(level_two.get("effects", {})), _format_values(current.get("effects", {})), _format_values(next.get("effects", {}))]
	var forge_level := int(_forge_state.get("lab", {}).get("buildings", {}).get("build_forge", {}).get("level", 0))
	var cost := maxi(0, _forge_base_cost + level * _forge_cost_per_level)
	var essence := int(_forge_state.get("wallet", {}).get("essence", 0))
	var online_ready := _backend != null and _backend.token != "" and _forge_synced
	var outstanding := ""
	if not _forge_debug and _backend != null:
		for action in _backend.get_pending_actions():
			if str(action.get("action_type", "")) in ["FORGE_UPGRADE", "FORGE_SPECIALIZE", "FORGE_ALLOCATE_TRAIT", "FORGE_REROLL_TRAIT", "FORGE_CHOOSE_REROLL"]:
				outstanding = str(action.get("client_action_id", ""))
				break
		if _backend._verified_player_id.is_empty():
			_forge_pending = ""
		elif _forge_pending.is_empty() and not outstanding.is_empty():
			_forge_pending = outstanding
	_forge_button.disabled = _forge_item == "" or _forge_pending != "" or outstanding != "" or (not _forge_debug and not online_ready) or forge_level < 1 or level >= 10 or essence < cost
	var can_trait := (_forge_debug or (online_ready and not _backend._verified_player_id.is_empty())) and _forge_pending == "" and outstanding == "" and forge_level >= 1
	var balance_file := FileAccess.open("res://data/static/balance.json", FileAccess.READ)
	var balance_data: Variant = JSON.parse_string(balance_file.get_as_text()) if balance_file else {}
	var specialize_cost: Dictionary = balance_data.get("balance", {}).get("forge_specialize_cost", {}) if balance_data is Dictionary else {}
	var reroll_cost: Dictionary = balance_data.get("balance", {}).get("forge_reroll_cost", {}) if balance_data is Dictionary else {}
	var shard_cost := int(balance_data.get("balance", {}).get("forge_reroll_high_level_shard", 1)) if level >= 7 and balance_data is Dictionary else 0
	var wallet: Dictionary = _forge_state.get("wallet", {})
	var reroll_text := "%d Essence, %d Core%s" % [int(reroll_cost.get("essence", 0)), int(reroll_cost.get("core", 0)), ", %d Arcane Shard" % shard_cost if shard_cost > 0 else ""]
	if is_instance_valid(_forge_reroll_button) and is_instance_valid(_forge_reroll_slot):
		_forge_reroll_slot.visible = specialization != "" and not has_offer
		_forge_reroll_slot.disabled = not can_trait or traits.size() != 3
		for i in range(mini(3, traits.size())):
			if traits[i] is Dictionary:
				_forge_reroll_slot.set_item_text(i, "%s (%d)" % [str(traits[i].get("id", "Slot")).replace("_", " ").capitalize(), int(traits[i].get("points", 0))])
		_forge_reroll_button.tooltip_text = "Reroll cost: " + reroll_text
		_forge_reroll_button.disabled = not can_trait or has_offer or specialization == "" or traits.size() != 3 or reroll_cost.is_empty() or essence < int(reroll_cost.get("essence", 0)) or int(wallet.get("core", 0)) < int(reroll_cost.get("core", 0)) or int(wallet.get("arcane_shard", 0)) < shard_cost
	for i in range(_forge_trait_buttons.size()):
		var button := _forge_trait_buttons[i]
		if has_offer:
			var option := str(options[i]) if i < options.size() else ""
			var slot_index := int(offer.get("slot", -1))
			var points := int(traits[slot_index].get("points", 0)) if slot_index >= 0 and slot_index < traits.size() and traits[slot_index] is Dictionary else 0
			var pool: Dictionary = balance_data.get("balance", {}).get("forge_trait_pool", {}).get(specialization, {}) if balance_data is Dictionary else {}
			var bonus := float(pool.get(option, 0))
			button.text = "%s\n+%s / point | +%s total" % [option.replace("_", " ").capitalize(), str(bonus), str(bonus * points)]
			button.tooltip_text = "%s per point | %s total at %d points" % [str(bonus), str(bonus * points), points]
			button.disabled = not can_trait or options.size() != 3 or option == "" or bonus <= 0
		elif specialization == "":
			button.text = ["Aggressive", "Defensive", "Technical"][i]
			button.tooltip_text = "Specialize: %d Essence, %d Core" % [int(specialize_cost.get("essence", 0)), int(specialize_cost.get("core", 0))]
			button.disabled = not can_trait or level < 1 or specialize_cost.is_empty() or essence < int(specialize_cost.get("essence", 0)) or int(_forge_state.get("wallet", {}).get("core", 0)) < int(specialize_cost.get("core", 0))
		else:
			var slot: Variant = traits[i] if i < traits.size() else {}
			button.text = "+1 " + (str(slot.get("id", "Slot %d" % (i + 1))).replace("_", " ").capitalize() if slot is Dictionary else "Slot %d" % (i + 1))
			button.tooltip_text = "Allocate one point"
			button.disabled = not can_trait or has_offer or traits.size() != 3 or not slot is Dictionary or int(slot.get("points", 4)) >= 4 or allocated >= level
	_forge_status.text = "Level %d / 10 | Next: %s | Essence: %d / %d" % [level, str(level + 1) if level < 10 else "MAX", essence, cost]
	if specialization != "":
		_forge_status.text += " | Reroll: " + reroll_text
	if has_offer:
		_forge_status.text += " | Choose a reroll option"
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
	_forge_confirm_action = "FORGE_UPGRADE"
	_forge_confirm.dialog_text = "Upgrade %s from level %d to %d for %d Essence?" % [_forge_item, level, level + 1, maxi(0, _forge_base_cost + level * _forge_cost_per_level)]
	_forge_confirm.popup_centered()

func _request_trait_action(index: int) -> void:
	if index < 0 or index >= _forge_trait_buttons.size() or _forge_trait_buttons[index].disabled:
		return
	var state: Dictionary = _forge_state.get("item_progress", {}).get(_forge_item, {})
	_forge_confirm_payload = {"item_id": _forge_item}
	var offer: Variant = state.get("pending_reroll", {})
	if offer is Dictionary and not offer.is_empty():
		var options: Variant = offer.get("options", [])
		if not options is Array or index >= options.size():
			return
		_forge_confirm_action = "FORGE_CHOOSE_REROLL"
		_forge_confirm_payload["slot"] = int(offer.get("slot", -1))
		_forge_confirm_payload["trait_id"] = options[index]
		_forge_confirm.dialog_text = "Choose %s?\n%s" % [_forge_trait_buttons[index].text, _forge_trait_buttons[index].tooltip_text]
	elif str(state.get("specialization", "")) == "":
		_forge_confirm_action = "FORGE_SPECIALIZE"
		_forge_confirm_payload["path"] = ["aggressive", "defensive", "technical"][index]
		_forge_confirm.dialog_text = "Specialize %s as %s?\n%s" % [_forge_item, _forge_confirm_payload.path, _forge_trait_buttons[index].tooltip_text]
	else:
		_forge_confirm_action = "FORGE_ALLOCATE_TRAIT"
		_forge_confirm_payload["slot"] = index
		_forge_confirm.dialog_text = "Allocate one point to %s?" % _forge_trait_buttons[index].text.trim_prefix("+1 ")
	_forge_confirm.popup_centered()

func _request_forge_reroll() -> void:
	if not is_instance_valid(_forge_reroll_button) or _forge_reroll_button.disabled:
		return
	_forge_confirm_action = "FORGE_REROLL_TRAIT"
	_forge_confirm_payload = {"item_id": _forge_item, "slot": _forge_reroll_slot.selected}
	_forge_confirm.dialog_text = "Reroll %s for %s?" % [_forge_reroll_slot.get_item_text(_forge_reroll_slot.selected), _forge_reroll_button.tooltip_text.trim_prefix("Reroll cost: ")]
	_forge_confirm.popup_centered()

func _send_forge_confirmed() -> void:
	if _forge_confirm_action == "FORGE_UPGRADE":
		_send_forge_upgrade()
		return
	if (not _forge_debug and _backend == null) or _forge_pending != "" or _forge_confirm_payload.get("item_id") != _forge_item:
		return
	if _forge_confirm_action == "FORGE_REROLL_TRAIT":
		if not is_instance_valid(_forge_reroll_button) or _forge_reroll_button.disabled or _forge_reroll_slot.selected != int(_forge_confirm_payload.get("slot", -1)):
			return
	else:
		var index := int(_forge_confirm_payload.get("slot", ["aggressive", "defensive", "technical"].find(_forge_confirm_payload.get("path", ""))))
		if _forge_confirm_action == "FORGE_CHOOSE_REROLL":
			var pending: Variant = _forge_state.get("item_progress", {}).get(_forge_item, {}).get("pending_reroll", {})
			index = pending.get("options", []).find(_forge_confirm_payload.get("trait_id")) if pending is Dictionary and pending.get("options", []) is Array else -1
		if index < 0 or index >= _forge_trait_buttons.size() or _forge_trait_buttons[index].disabled:
			return
	if _forge_debug:
		_apply_debug_trait_action()
		return
	_forge_pending = _backend.send_action({"action_type": _forge_confirm_action, "payload": _forge_confirm_payload.duplicate()})
	_update_forge_button()
	if _forge_pending == "":
		_forge_status.text = "Could not send action; check the connection."

func _apply_debug_trait_action() -> void:
	var debug := DebugFlags.new()
	debug.reload()
	if not debug.unlock_all_buildings:
		debug.free()
		return
	var state := debug.load_lab_state()
	var progress: Dictionary = state.get("item_progress", {})
	var item: Dictionary = progress.get(_forge_item, {})
	var level := int(item.get("level", 0))
	var file := FileAccess.open("res://data/static/balance.json", FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text()) if file else {}
	if not data is Dictionary:
		debug.free()
		return
	var balance: Dictionary = data.get("balance", {})
	var wallet: Dictionary = state.get("wallet", {})
	var traits: Array = item.get("traits", [])
	var slot := int(_forge_confirm_payload.get("slot", -1))
	var cost: Dictionary = {}
	if _forge_confirm_action == "FORGE_SPECIALIZE":
		var path := str(_forge_confirm_payload.get("path", ""))
		var pool: Dictionary = balance.get("forge_trait_pool", {}).get(path, {})
		if level < 1 or item.has("specialization") or pool.size() < 3:
			debug.free()
			return
		var choices := pool.keys()
		choices.shuffle()
		traits = []
		for i in range(3):
			traits.append({"id": choices[i], "points": 0})
		item["specialization"] = path
		item["traits"] = traits
		cost = balance.get("forge_specialize_cost", {}).duplicate()
	elif _forge_confirm_action == "FORGE_ALLOCATE_TRAIT" and slot >= 0 and slot < traits.size():
		var allocated := 0
		for entry in traits:
			allocated += int(entry.get("points", 0))
		if item.has("pending_reroll") or allocated >= level or int(traits[slot].get("points", 0)) >= 4:
			debug.free()
			return
		traits[slot]["points"] = int(traits[slot].get("points", 0)) + 1
	elif _forge_confirm_action == "FORGE_REROLL_TRAIT" and slot >= 0 and slot < traits.size():
		var pool: Dictionary = balance.get("forge_trait_pool", {}).get(str(item.get("specialization", "")), {})
		var choices := pool.keys()
		for entry in traits:
			choices.erase(entry.get("id", ""))
		if item.has("pending_reroll") or choices.size() < 3:
			debug.free()
			return
		choices.shuffle()
		item["pending_reroll"] = {"slot": slot, "options": choices.slice(0, 3)}
		cost = balance.get("forge_reroll_cost", {}).duplicate()
		if level >= 7:
			cost["arcane_shard"] = int(balance.get("forge_reroll_high_level_shard", 1))
	elif _forge_confirm_action == "FORGE_CHOOSE_REROLL" and slot >= 0 and slot < traits.size():
		var offer: Dictionary = item.get("pending_reroll", {})
		var choice := str(_forge_confirm_payload.get("trait_id", ""))
		if int(offer.get("slot", -1)) != slot or choice not in offer.get("options", []):
			debug.free()
			return
		traits[slot]["id"] = choice
		item.erase("pending_reroll")
	else:
		debug.free()
		return
	for resource in cost:
		if int(wallet.get(resource, 0)) < int(cost[resource]):
			_forge_status.text = "Insufficient resources in local debug."
			debug.free()
			return
		wallet[resource] = int(wallet.get(resource, 0)) - int(cost[resource])
	progress[_forge_item] = item
	state["item_progress"] = progress
	state["wallet"] = wallet
	if debug.save_lab_state(state):
		_forge_state = state
		debug_forge_updated.emit(state)
		_update_forge_button()
		_forge_status.text += " | Local debug action saved"
	else:
		_forge_status.text = "Could not save local debug state."
	debug.free()

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
		_forge_status.text += " | Action confirmed"

func _forge_failed(action_id: String, error: String) -> void:
	if action_id == "" or action_id != _forge_pending:
		return
	_forge_pending = ""
	_update_forge_button()
	if is_instance_valid(_forge_status):
		_forge_status.text = "Forge action failed: " + error

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

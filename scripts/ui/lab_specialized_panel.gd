extends VBoxContainer

signal debug_forge_updated(state: Dictionary)
signal lab_action_requested(action: Dictionary, building_id: String)

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const HomProgress := preload("res://scripts/domain/homunculus_progress.gd")
const Stats := preload("res://scripts/ui/stat_presentation.gd")
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
var _fusion_donor: OptionButton
var _fusion_button: Button
var _fusion_info: Label
var _forge_confirm_action := ""
var _forge_confirm_payload: Dictionary = {}
var _lab_status: Label
var _lab_progress: ProgressBar
var _lab_buttons: Array[Button] = []
var _lab_metrics: Dictionary = {}
var _vat_item := ""
var _vat_info: Label
var _vat_status: Label
var _vat_upgrade: Button
var _vat_mutations: Array[Button] = []
var _vat_confirm: ConfirmationDialog
var _vat_action: Dictionary = {}
var _vat_now := 0
var _vat_pending := false
var _anomaly_confirm: ConfirmationDialog
var _anomaly_choice := ""
var _sync_now := 0
var _sync_pending := false
var _sync_badge: Label
var _dungeon_ranking_button: Button
var _dungeon_ranking_dialog: AcceptDialog
var _dungeon_ranking_text: Label
var _dungeon_ranking_month := ""
var _dungeon_request := ""
var _dungeon_request_owner := ""
var _dungeon_entry_button: Button
var _dungeon_entry_status: Label
var _dungeon_entry_request := ""
var _dungeon_entry_kind := ""
var _dungeon_entry_owner := ""
var _dungeon_debug_waiting := false
var _dungeon_debug_expected_player := ""
var _dungeon_debug_login_token := ""
var _dungeon_debug_confirm: ConfirmationDialog
var _dungeon_debug_run_choice: ConfirmationDialog
var _dungeon_debug_abandon_confirm: ConfirmationDialog
var _dungeon_debug_session: Dictionary = {}

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
		_backend.api_completed.connect(_on_dungeon_api_completed)
		_backend.auth_changed.connect(func(_token): _update_forge_button())
		_backend.state_updated.connect(_on_dungeon_debug_state)
	custom_minimum_size.y = 210
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

func show_building(building_id: String, state: Dictionary, building_names: Dictionary, metrics: Dictionary = {}, synced: bool = false) -> void:
	if state.is_empty():
		_forge_pending = ""
	_forge_state = state
	_forge_synced = synced
	_lab_metrics = metrics
	if building_id == _current_id and building_id == "sync_nexus":
		_update_sync_status()
		return
	if building_id == _current_id and building_id in ["lab_th", "essence_reactor", "anomaly_containment"]:
		return
	if building_id == _current_id and building_id == "homunculus_vat":
		_update_vat_status()
		return
	if building_id == _current_id and building_id == "build_forge":
		_update_forge_button()
		return
	_current_id = building_id
	_forge_button = null
	_forge_status = null
	_forge_info = null
	_forge_confirm = null
	_forge_reroll_button = null
	_forge_reroll_slot = null
	_fusion_donor = null
	_fusion_button = null
	_fusion_info = null
	_forge_trait_buttons.clear()
	_lab_buttons.clear()
	_lab_status = null
	_lab_progress = null
	_dungeon_ranking_button = null
	_dungeon_ranking_dialog = null
	_dungeon_ranking_text = null
	_dungeon_entry_button = null
	_dungeon_entry_status = null
	_vat_info = null
	_vat_status = null
	_vat_upgrade = null
	_vat_confirm = null
	_vat_mutations.clear()
	_anomaly_confirm = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = true
	match building_id:
		"build_forge": _catalog(false)
		"homunculus_vat": _catalog(true)
		"sync_nexus": _sync_controls()
		"anomaly_containment": _anomaly_controls()
		"lab_th": _hq(state, building_names)
		"essence_reactor": _reactor_controls()
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
	var row := HBoxContainer.new()
	add_child(row)
	for directive in ["production", "research", "experimentation"]:
		var button := Button.new()
		button.text = {"production": "Production +10%", "research": "Research time -10%", "experimentation": "Experiment chance +5%"}[directive]
		MenuArt.button(button)
		button.pressed.connect(func(): lab_action_requested.emit({"action_type": "SET_HQ_DIRECTIVE", "payload": {"directive": directive}}, "lab_th"))
		row.add_child(button)
		_lab_buttons.append(button)
	_lab_status = Label.new()
	add_child(_lab_status)

func _reactor_controls() -> void:
	_message("PRODUCTION", "Collect Essence to charge the reactor.")
	_lab_progress = ProgressBar.new()
	_lab_progress.show_percentage = false
	add_child(_lab_progress)
	_lab_status = Label.new()
	add_child(_lab_status)
	var button := Button.new()
	button.text = "Activate Overcharge"
	button.custom_minimum_size = Vector2(200, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.tooltip_text = "Reward: 15 Essence and 1 Core"
	MenuArt.button(button)
	button.pressed.connect(func(): lab_action_requested.emit({"action_type": "REACTOR_OVERCHARGE", "payload": {}}, "essence_reactor"))
	add_child(button)
	_lab_buttons.append(button)

func _setup_dungeon_ranking(parent: Control) -> void:
	_dungeon_entry_button = Button.new()
	_dungeon_entry_button.text = "ENTER DUNGEON"
	_dungeon_entry_button.custom_minimum_size = Vector2(165, 52)
	_dungeon_entry_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_dungeon_entry_button.pressed.connect(_enter_dungeon)
	MenuArt.button(_dungeon_entry_button)
	parent.add_child(_dungeon_entry_button)
	_dungeon_entry_status = Label.new()
	_dungeon_entry_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_dungeon_entry_status)
	_dungeon_ranking_button = Button.new()
	_dungeon_ranking_button.text = "MONTHLY RANKING"
	_dungeon_ranking_button.custom_minimum_size = Vector2(165, 52)
	_dungeon_ranking_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_dungeon_ranking_button.pressed.connect(_open_dungeon_ranking)
	MenuArt.button(_dungeon_ranking_button)
	parent.add_child(_dungeon_ranking_button)
	_dungeon_ranking_dialog = AcceptDialog.new()
	_dungeon_ranking_dialog.title = "Dungeons - Monthly Ranking"
	_dungeon_ranking_dialog.min_size = Vector2i(620, 560)
	_dungeon_ranking_dialog.borderless = true
	_dungeon_ranking_dialog.transparent_bg = true
	_dungeon_ranking_dialog.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	_dungeon_ranking_dialog.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	_dungeon_ranking_dialog.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup-grande.png", Vector4(60, 65, 60, 48)))
	MenuArt.button(_dungeon_ranking_dialog.get_ok_button())
	add_child(_dungeon_ranking_dialog)
	var ranking_content := VBoxContainer.new()
	_dungeon_ranking_dialog.add_child(ranking_content)
	var previous := Button.new()
	previous.text = "Previous Month"
	previous.alignment = HORIZONTAL_ALIGNMENT_CENTER
	previous.custom_minimum_size = Vector2(165, 52)
	previous.pressed.connect(_previous_dungeon_month)
	MenuArt.button(previous)
	ranking_content.add_child(previous)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ranking_content.add_child(scroll)
	_dungeon_ranking_text = Label.new()
	_dungeon_ranking_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dungeon_ranking_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_dungeon_ranking_text)

func _sync_card(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(275, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup.png", Vector4(35, 35, 35, 30)))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_color_override("font_color", Color("e5c76d"))
	content.add_child(heading)
	return content

func _sync_controls() -> void:
	var cards := HFlowContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	add_child(cards)
	var calibration := _sync_card(cards, "CALIBRATION PROJECT")
	var description := Label.new()
	description.text = "Echo (NPC)\nCalibrate the Nexus to earn resources."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calibration.add_child(description)
	_lab_progress = ProgressBar.new()
	_lab_progress.show_percentage = false
	_lab_progress.max_value = 100
	calibration.add_child(_lab_progress)
	_lab_status = Label.new()
	_lab_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calibration.add_child(_lab_status)
	var button := Button.new()
	button.custom_minimum_size = Vector2(165, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	MenuArt.button(button)
	button.pressed.connect(_sync_pressed)
	calibration.add_child(button)
	_lab_buttons.append(button)
	_sync_badge = preload("res://scripts/ui/lab_action_alert.gd").badge(button)
	_setup_dungeon_ranking(_sync_card(cards, "DUNGEONS"))

func _sync_pressed() -> void:
	if _lab_buttons.is_empty() or _lab_buttons[0].disabled:
		return
	var project: Variant = _forge_state.get("lab", {}).get("runtime", {}).get("sync_project")
	var action_type := "SYNC_CLAIM" if project is Dictionary and not project.is_empty() else "SYNC_START"
	lab_action_requested.emit({"action_type": action_type, "payload": {"building_id": "sync_nexus"}}, "sync_nexus")

func _update_sync_status() -> void:
	if not is_instance_valid(_lab_status) or not is_instance_valid(_lab_progress) or _lab_buttons.is_empty():
		return
	var project: Variant = _forge_state.get("lab", {}).get("runtime", {}).get("sync_project")
	var active: bool = project is Dictionary and not project.is_empty()
	var remaining := maxi(0, int(project.get("completes_at", 0)) - _sync_now) if active else 0
	var duration := maxi(1, int(project.get("completes_at", 0)) - int(project.get("started_at", 0))) if active else 1
	_lab_progress.value = clampf(100.0 * (1.0 - float(remaining) / float(duration)), 0.0, 100.0) if active else 0
	var reward: Dictionary = _lab_metrics.get("sync_reward", {"core": 1, "arcane_shard": 1})
	_lab_status.text = "%s\nReward: %s" % ["Project in progress" if active and remaining > 0 else ("Ready to claim" if active else "Ready to start"), _format_values(reward).replace("\n", ", ")]
	var ready := _forge_debug or (_forge_synced and _backend != null and _backend.token != "" and not _backend._verified_player_id.is_empty())
	var level := int(_forge_state.get("lab", {}).get("buildings", {}).get("sync_nexus", {}).get("level", 0))
	var hq := int(_forge_state.get("lab", {}).get("hqLevel", 0))
	if not active and not _forge_debug and (level < 1 or hq < 4):
		_lab_status.text += "\nRequires Sync Nexus level 1 and HQ level 4 (current: %d / %d)." % [level, hq]
	_lab_buttons[0].text = (_clock(remaining) if remaining > 0 else "CLAIM") if active else "START"
	if is_instance_valid(_sync_badge):
		_sync_badge.visible = active and remaining <= 0 and ready and not _sync_pending
	_lab_buttons[0].disabled = not ready or _sync_pending or (active and remaining > 0) or (not active and not _forge_debug and (level < 1 or hq < 4))
	if is_instance_valid(_dungeon_ranking_button):
		_dungeon_ranking_button.disabled = _backend == null or _backend.token.is_empty() or _backend._verified_player_id.is_empty()
	if is_instance_valid(_dungeon_entry_button):
		var debug_local := _dungeon_local_debug()
		_dungeon_entry_button.disabled = _backend == null or (not debug_local and (_backend.token.is_empty() or _backend._verified_player_id.is_empty())) or not _dungeon_entry_request.is_empty() or _dungeon_debug_waiting

func _dungeon_local_debug() -> bool:
	if not _forge_debug or _backend == null:
		return false
	var local := RegEx.new()
	local.compile("^http://(127\\.0\\.0\\.1|localhost|\\[::1\\])(?::[0-9]{1,5})?/?$")
	return local.search(_backend.base_url.to_lower()) != null

func _style_dungeon_dialog(dialog: ConfirmationDialog, extra_buttons: Array = []) -> void:
	dialog.min_size = Vector2i(620, 300)
	dialog.borderless = true
	dialog.transparent_bg = true
	dialog.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	dialog.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	dialog.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup.png", Vector4(55, 50, 55, 40)))
	var message := dialog.get_label()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 18)
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()] + extra_buttons:
		button.custom_minimum_size = Vector2(160, 52)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 16)
		MenuArt.button(button)

func _enter_dungeon() -> void:
	if _backend == null or not _dungeon_entry_request.is_empty() or _dungeon_debug_waiting:
		return
	if _dungeon_local_debug():
		var cached: Dictionary = _backend.load_cached_state()
		var dedicated := not _backend._verified_player_id.is_empty() and str(cached.get("player_id", "")) == _backend._verified_player_id and str(cached.get("display_name", "")) == "dungeon_debug_local"
		if dedicated:
			_dungeon_debug_prepare()
		elif not _backend.token.is_empty():
			if not is_instance_valid(_dungeon_debug_confirm):
				_dungeon_debug_confirm = ConfirmationDialog.new()
				_dungeon_debug_confirm.title = "Switch account?"
				_dungeon_debug_confirm.dialog_text = "Switch to the dedicated local Dungeon debug account?"
				_dungeon_debug_confirm.confirmed.connect(_dungeon_debug_login)
				add_child(_dungeon_debug_confirm)
				_style_dungeon_dialog(_dungeon_debug_confirm)
			_dungeon_debug_confirm.popup_centered()
		else:
			_dungeon_debug_login()
		return
	if _backend.token.is_empty() or _backend._verified_player_id.is_empty():
		return
	_dungeon_check_session()

func _dungeon_check_session() -> void:
	_dungeon_entry_owner = _backend._verified_player_id
	_dungeon_entry_kind = "session"
	_dungeon_entry_request = _backend.request_api("GET", "/dungeon/session", null)
	_dungeon_entry_status.text = "Checking Dungeon session..." if not _dungeon_entry_request.is_empty() else "Connection busy. Try again."
	_update_sync_status()

func _dungeon_debug_login() -> void:
	if not _dungeon_local_debug() or not _dungeon_entry_request.is_empty():
		return
	_dungeon_debug_login_token = _backend.token
	_dungeon_entry_kind = "debug_login"
	_dungeon_entry_request = _backend.request_api("POST", "/auth/dev_login", {"name": "dungeon_debug_local"})
	_dungeon_entry_status.text = "Connecting local Dungeon test account..." if not _dungeon_entry_request.is_empty() else "Connection busy. Retry."
	_update_sync_status()

func _on_dungeon_debug_state(state: Dictionary) -> void:
	if not _dungeon_debug_waiting or state.is_empty() or not is_instance_valid(_dungeon_entry_status):
		return
	if not _dungeon_local_debug() or _backend._verified_player_id != _dungeon_debug_expected_player or str(state.get("player_id", "")) != _dungeon_debug_expected_player or str(state.get("display_name", "")) != "dungeon_debug_local":
		_dungeon_debug_waiting = false
		_dungeon_entry_status.text = "Account verification failed. Retry."
		_update_sync_status()
		return
	_dungeon_debug_waiting = false
	_dungeon_debug_prepare()

func _dungeon_debug_prepare() -> void:
	if not _dungeon_local_debug() or _backend._verified_player_id.is_empty():
		return
	_dungeon_entry_owner = _backend._verified_player_id
	_dungeon_entry_kind = "debug_prepare"
	_dungeon_entry_request = _backend.request_api("POST", "/debug/dungeons/prepare", {}, true)
	_dungeon_entry_status.text = "Preparing local Dungeon account..." if not _dungeon_entry_request.is_empty() else "Connection busy. Retry."
	_update_sync_status()

func _on_dungeon_entry_completed(request_id: String, ok: bool, data: Dictionary) -> void:
	if _dungeon_entry_request.is_empty() or request_id != _dungeon_entry_request:
		return
	_dungeon_entry_request = ""
	if not is_instance_valid(_dungeon_entry_status):
		return
	if _dungeon_entry_kind == "debug_login":
		if not ok or _backend == null or not _dungeon_local_debug() or _backend.token != _dungeon_debug_login_token or str(data.get("token", "")).is_empty() or str(data.get("player_id", "")).is_empty():
			_dungeon_entry_status.text = "Local debug login failed. Check the local Docker API and retry."
			_update_sync_status()
			return
		_dungeon_debug_expected_player = str(data.player_id)
		_dungeon_debug_waiting = true
		_backend.set_token(str(data.token))
		_dungeon_entry_status.text = "Verifying local Dungeon account..."
		var expected := _dungeon_debug_expected_player
		get_tree().create_timer(10.0).timeout.connect(func():
			if _dungeon_debug_waiting and _dungeon_debug_expected_player == expected and is_instance_valid(_dungeon_entry_status):
				_dungeon_debug_waiting = false
				_dungeon_entry_status.text = "Account verification timed out. Check the local Docker API and retry."
				_update_sync_status()
		)
		_update_sync_status()
		return
	if _backend == null or _dungeon_entry_owner.is_empty() or _backend._verified_player_id != _dungeon_entry_owner:
		_dungeon_entry_status.text = "Account changed. Reopen Sync Nexus."
		_update_sync_status()
		return
	if not ok:
		_dungeon_entry_status.text = "Debug preparation unavailable. Check the local Docker API configuration and retry." if _dungeon_entry_kind == "debug_prepare" else str(data.get("error", "Connection unavailable. Retry."))
		_update_sync_status()
		return
	if _dungeon_entry_kind == "debug_prepare":
		_dungeon_check_session()
		return
	if _dungeon_entry_kind == "debug_abandon":
		SceneRouter._dungeon_context.erase("pending_debug_abandon")
		_dungeon_check_session()
		return
	var session: Variant = data.get("session") if _dungeon_entry_kind == "session" else data
	var pending: Variant = SceneRouter._dungeon_context.get("pending_debug_abandon")
	if _dungeon_entry_kind == "session" and _dungeon_local_debug() and pending is Dictionary and str(pending.get("owner", "")) == _dungeon_entry_owner:
		_dungeon_entry_kind = "debug_abandon"
		_dungeon_entry_request = _backend.request_api("POST", "/dungeon/abandon", pending.get("payload", {}).duplicate(true))
		_dungeon_entry_status.text = "Resolving previous test run..." if not _dungeon_entry_request.is_empty() else "Connection busy. Retry."
		_update_sync_status()
		return
	if session is Dictionary and str(session.get("status", "")) == "ACTIVE" and not str(session.get("run_id", "")).is_empty():
		if _dungeon_entry_kind == "session" and _dungeon_local_debug():
			_dungeon_debug_session = session.duplicate(true)
			if not is_instance_valid(_dungeon_debug_run_choice):
				_dungeon_debug_run_choice = ConfirmationDialog.new()
				_dungeon_debug_run_choice.title = ""
				_dungeon_debug_run_choice.dialog_text = "Resume the active run or start a new test run."
				_dungeon_debug_run_choice.get_ok_button().text = "RESUME RUN"
				var new_run_button := _dungeon_debug_run_choice.add_button("NEW RUN", false, "new_test_run")
				_dungeon_debug_run_choice.confirmed.connect(_dungeon_debug_resume)
				_dungeon_debug_run_choice.custom_action.connect(_dungeon_debug_run_action)
				add_child(_dungeon_debug_run_choice)
				_style_dungeon_dialog(_dungeon_debug_run_choice, [new_run_button])
			_dungeon_debug_run_choice.popup_centered()
		else:
			_dungeon_open_session(session)
		return
	if _dungeon_entry_kind != "session" or session != null:
		_dungeon_entry_status.text = "Dungeon session unavailable. Retry."
		_update_sync_status()
		return
	var action_id := str(SceneRouter._dungeon_context.get("start_action_id", "")) if str(SceneRouter._dungeon_context.get("player_id", "")) == _dungeon_entry_owner else ""
	if action_id.is_empty():
		action_id = _backend._make_uuid()
		SceneRouter._dungeon_context = {"player_id": _dungeon_entry_owner, "start_action_id": action_id}
	_dungeon_entry_kind = "start"
	_dungeon_entry_request = _backend.request_api("POST", "/dungeon/start", {"client_action_id": action_id})
	_dungeon_entry_status.text = "Starting Dungeon..." if not _dungeon_entry_request.is_empty() else "Connection busy. Retry."
	_update_sync_status()

func _dungeon_open_session(session: Dictionary) -> void:
	SceneRouter._dungeon_context = {"run_id": str(session.run_id), "player_id": _dungeon_entry_owner, "session": session.duplicate(true)}
	if bool(session.get("combat_ready", false)) and int(session.get("combat_revision", 0)) >= 1 and session.get("combat_state") is Dictionary:
		SceneRouter.go_to_dungeon_combat()
	else:
		SceneRouter.go_to_dungeon_loadout(str(session.run_id), _dungeon_entry_owner)

func _dungeon_debug_resume() -> void:
	if _dungeon_local_debug() and _backend._verified_player_id == _dungeon_entry_owner and not _dungeon_debug_session.is_empty():
		_dungeon_open_session(_dungeon_debug_session)

func _dungeon_debug_run_action(action: StringName) -> void:
	if action != "new_test_run" or not _dungeon_local_debug() or _backend._verified_player_id != _dungeon_entry_owner:
		return
	_dungeon_debug_run_choice.hide()
	if not is_instance_valid(_dungeon_debug_abandon_confirm):
		_dungeon_debug_abandon_confirm = ConfirmationDialog.new()
		_dungeon_debug_abandon_confirm.title = ""
		_dungeon_debug_abandon_confirm.dialog_text = "Abandon current run?\n\nThe current Dungeon run will end before starting a new run."
		_dungeon_debug_abandon_confirm.confirmed.connect(_dungeon_debug_abandon)
		add_child(_dungeon_debug_abandon_confirm)
		_style_dungeon_dialog(_dungeon_debug_abandon_confirm)
	_dungeon_debug_abandon_confirm.popup_centered()

func _dungeon_debug_abandon() -> void:
	if not _dungeon_local_debug() or _backend._verified_player_id != _dungeon_entry_owner or not _dungeon_entry_request.is_empty() or _dungeon_debug_session.is_empty():
		return
	var pending: Variant = SceneRouter._dungeon_context.get("pending_debug_abandon")
	if not pending is Dictionary or str(pending.get("owner", "")) != _dungeon_entry_owner or str(pending.get("payload", {}).get("run_id", "")) != str(_dungeon_debug_session.get("run_id", "")):
		pending = {"owner": _dungeon_entry_owner, "payload": {"run_id": str(_dungeon_debug_session.run_id), "client_action_id": _backend._make_uuid()}}
		SceneRouter._dungeon_context["pending_debug_abandon"] = pending.duplicate(true)
	_dungeon_entry_kind = "debug_abandon"
	_dungeon_entry_request = _backend.request_api("POST", "/dungeon/abandon", pending.payload.duplicate(true))
	_dungeon_entry_status.text = "Ending previous test run..." if not _dungeon_entry_request.is_empty() else "Connection busy. Retry."
	_update_sync_status()

func _open_dungeon_ranking() -> void:
	if _backend == null or _backend.token.is_empty() or _backend._verified_player_id.is_empty():
		return
	var server_ms := _backend.get_server_time_unix_ms()
	var utc := Time.get_datetime_dict_from_unix_time(int(server_ms / 1000) if server_ms > 0 else int(Time.get_unix_time_from_system()))
	_dungeon_ranking_month = "%04d-%02d" % [int(utc.year), int(utc.month)]
	_dungeon_ranking_dialog.popup_centered()
	_request_dungeon_ranking()

func _previous_dungeon_month() -> void:
	if _dungeon_request != "":
		return
	var parts := _dungeon_ranking_month.split("-")
	if parts.size() != 2:
		return
	var year := int(parts[0])
	var month := int(parts[1]) - 1
	if month == 0:
		year -= 1
		month = 12
	if year < 1:
		return
	_dungeon_ranking_month = "%04d-%02d" % [year, month]
	_request_dungeon_ranking()

func _request_dungeon_ranking() -> void:
	if not is_instance_valid(_dungeon_ranking_text) or _backend == null or _dungeon_request != "":
		return
	_dungeon_request_owner = _backend._verified_player_id
	_dungeon_request = _backend.request_api("GET", "/dungeon/leaderboard?month=" + _dungeon_ranking_month, null)
	_dungeon_ranking_text.text = "Loading..." if not _dungeon_request.is_empty() else "Connection busy. Try again."

func _on_dungeon_api_completed(request_id: String, ok: bool, data: Dictionary) -> void:
	_on_dungeon_entry_completed(request_id, ok, data)
	if request_id != _dungeon_request or _dungeon_request.is_empty():
		return
	_dungeon_request = ""
	if not is_instance_valid(_dungeon_ranking_text):
		return
	if _backend == null or _dungeon_request_owner != _backend._verified_player_id or _dungeon_request_owner.is_empty():
		_dungeon_ranking_text.text = "Account changed. Reopen the ranking."
		return
	if not ok:
		_dungeon_ranking_text.text = str(data.get("error", "Ranking unavailable."))
		return
	var lines: PackedStringArray = ["Season: " + str(data.get("season", _dungeon_ranking_month))]
	var leaders: Array = data.get("leaders", [])
	for i in mini(20, leaders.size()):
		var entry: Dictionary = leaders[i]
		lines.append("%d. %s  |  Floor %d  |  %d turns" % [int(entry.get("rank", i + 1)), str(entry.get("display_name", "")), int(entry.get("cleared_floor", 0)), int(entry.get("total_turns", 0))])
	var own: Variant = data.get("player")
	lines.append("Your rank: #%d | Floor %d" % [int(own.get("rank", 0)), int(own.get("cleared_floor", 0))] if own is Dictionary else "Your rank: —")
	_dungeon_ranking_text.text = "\n".join(lines)

func _anomaly_controls() -> void:
	_message("ANOMALY DETECTED", "Seal: 20 Essence + 1 Arcane Shard.\nInvestigate: 50% nothing, 40% 2 Arcane Shards, 10% 1 Time Crystal.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for choice in ["seal", "investigate"]:
		var button := Button.new()
		button.text = choice.to_upper()
		MenuArt.button(button)
		button.pressed.connect(_request_anomaly.bind(choice))
		row.add_child(button)
		_lab_buttons.append(button)
	_lab_status = Label.new()
	_lab_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_lab_status)
	_anomaly_confirm = ConfirmationDialog.new()
	_anomaly_confirm.title = "Resolve anomaly"
	_anomaly_confirm.confirmed.connect(_confirm_anomaly)
	add_child(_anomaly_confirm)

func _request_anomaly(choice: String) -> void:
	var index := ["seal", "investigate"].find(choice)
	if index < 0 or _lab_buttons[index].disabled:
		return
	_anomaly_choice = choice
	_anomaly_confirm.dialog_text = "Resolve this anomaly by %s?" % choice
	_anomaly_confirm.popup_centered()

func _confirm_anomaly() -> void:
	var index := ["seal", "investigate"].find(_anomaly_choice)
	if index >= 0 and index < _lab_buttons.size() and not _lab_buttons[index].disabled:
		lab_action_requested.emit({"action_type": "ANOMALY_RESOLVE", "payload": {"choice": _anomaly_choice}}, "anomaly_containment")

func update_lab_status(state: Dictionary, now_ms: int, pending: bool, metrics: Dictionary) -> void:
	if _current_id == "sync_nexus":
		_forge_state = state
		_lab_metrics = metrics
		_sync_now = now_ms
		_sync_pending = pending
		_update_sync_status()
		return
	if _current_id == "homunculus_vat":
		_forge_state = state
		_vat_now = now_ms
		_vat_pending = pending
		_update_vat_status()
		return
	if not is_instance_valid(_lab_status):
		return
	var runtime: Dictionary = state.get("lab", {}).get("runtime", {})
	var ready := _forge_debug or (_forge_synced and _backend != null and _backend.token != "" and not _backend._verified_player_id.is_empty())
	if _current_id == "lab_th":
		var directive: Dictionary = runtime.get("directive", {})
		var remaining := maxi(0, int(directive.get("ends_at", 0)) - now_ms)
		_lab_status.text = "Active: %s | %s remaining" % [str(directive.get("id", "")).capitalize(), _clock(remaining)] if remaining > 0 else "Ready to choose"
		for i in range(_lab_buttons.size()):
			_lab_buttons[i].disabled = not ready or pending or remaining > 0
			_lab_buttons[i].modulate = Color(1.25, 1.1, 0.7) if remaining > 0 and directive.get("id") == ["production", "research", "experimentation"][i] else Color.WHITE
	elif _current_id == "essence_reactor":
		var charge: Dictionary = runtime.get("reactor_overcharge", {})
		var threshold := int(metrics.get("threshold", 300))
		var progress := clampi(int(charge.get("progress", 0)), 0, threshold)
		var last := int(charge.get("last_used_at", 0))
		var remaining := maxi(0, last + int(metrics.get("cooldown", 10800)) * 1000 - now_ms) if last > 0 else 0
		_lab_progress.max_value = threshold
		_lab_progress.value = progress
		_lab_status.text = "Rate: %.1f Essence / hour | Stored: %.1f\n%d / %d collected | %s\nReward: %s" % [float(metrics.get("rate", 0)), float(metrics.get("stored", 0)), progress, threshold, "Cooldown: " + _clock(remaining) if remaining > 0 else ("Ready to activate" if progress >= threshold else "Charging"), _format_values(metrics.get("reward", {})).replace("\n", ", ")]
		if int(state.get("lab", {}).get("buildings", {}).get("essence_reactor", {}).get("level", 0)) < 1:
			_lab_status.text += "\nRequires Essence Reactor level 1."
		_lab_buttons[0].disabled = not ready or pending or int(state.get("lab", {}).get("buildings", {}).get("essence_reactor", {}).get("level", 0)) < 1 or progress < threshold or remaining > 0
		_lab_buttons[0].modulate = Color(1.25, 1.1, 0.7) if not _lab_buttons[0].disabled else Color.WHITE
	elif _current_id == "anomaly_containment":
		var anomaly: Dictionary = runtime.get("anomaly", {})
		var remaining := maxi(0, int(anomaly.get("next_at", 0)) - now_ms)
		var level := int(state.get("lab", {}).get("buildings", {}).get("anomaly_containment", {}).get("level", 0))
		var hq := int(state.get("lab", {}).get("hqLevel", 0))
		_lab_status.text = "Level %d | %s" % [level, "Cooldown: " + _clock(remaining) if remaining > 0 else "Ready"]
		if level < 1 or hq < 5:
			_lab_status.text += "\nRequires Anomaly Containment level 1 and HQ level 5 (current: %d / %d)." % [level, hq]
		if anomaly.has("last_choice"):
			var reward: Dictionary = anomaly.get("last_reward", {})
			_lab_status.text += "\nLast: %s | %s" % [str(anomaly.last_choice).capitalize(), "No reward" if reward.is_empty() else _format_values(reward).replace("\n", ", ")]
		for button in _lab_buttons:
			button.disabled = not ready or pending or level < 1 or hq < 5 or remaining > 0

func _clock(milliseconds: int) -> String:
	var seconds := int(ceil(float(milliseconds) / 1000.0))
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]

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
	title.text = "HOMUNCULUS CATALOG" if homunculi else "WEAPONS CATALOG"
	title.add_theme_font_size_override("font_size", 18)
	if not homunculi:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	if homunculi:
		add_child(row)
	else:
		var center := HBoxContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(center)
		var left_space := Control.new()
		left_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.add_child(left_space)
		row.custom_minimum_size.x = 1050
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		center.add_child(row)
		var right_space := Control.new()
		right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.add_child(right_space)
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
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not homunculi:
		details.add_theme_constant_override("separation", 8)
	row.add_child(details)
	var heading := Label.new()
	heading.add_theme_font_size_override("font_size", 18)
	if not homunculi:
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_child(heading)
	var stats_area: BoxContainer = VBoxContainer.new() if homunculi else HBoxContainer.new()
	stats_area.name = "CatalogStatsArea"
	stats_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_area.add_theme_constant_override("separation", 12)
	details.add_child(stats_area)
	var preview_center := CenterContainer.new()
	preview_center.name = "PreviewSlot"
	preview_center.custom_minimum_size = Vector2(150, 150) if homunculi else Vector2(190, 190)
	stats_area.add_child(preview_center)
	var frame := TextureRect.new()
	frame.custom_minimum_size = preview_center.custom_minimum_size
	frame.texture = load("res://assets/ui/new-elements/marco-slot-small.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_center.add_child(frame)
	frame.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 18
	preview.offset_top = 18
	preview.offset_right = -18
	preview.offset_bottom = -18
	var scroll := ScrollContainer.new()
	scroll.name = "StatsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 135
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_area.add_child(scroll)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 19)
	if not homunculi:
		_forge_info = info
	else:
		_vat_info = info
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(info)
	var actions := HBoxContainer.new()
	if not homunculi:
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 10)
	details.add_child(actions)
	for label in (["Upgrade Homunculus"] if homunculi else ["Upgrade", "Reroll"]):
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
		elif homunculi:
			_vat_upgrade = action
			action.pressed.connect(_request_vat_upgrade)
	var inventory := Button.new()
	inventory.text = "Open Inventory"
	MenuArt.button(inventory)
	inventory.pressed.connect(func(): SceneRouter.go_to_inventory("Homunculi" if homunculi else "Builds", true))
	actions.add_child(inventory)
	if homunculi:
		var mutation_heading := Label.new()
		mutation_heading.text = "Mutations"
		details.add_child(mutation_heading)
		var mutation_row := HBoxContainer.new()
		details.add_child(mutation_row)
		for mutation_id in ["catalyst", "vitality", "resonance"]:
			var button := Button.new()
			button.text = str(HomProgress.mutation_catalog().get(mutation_id, {}).get("name", mutation_id))
			button.tooltip_text = str(HomProgress.mutation_catalog().get(mutation_id, {}).get("description", ""))
			MenuArt.button(button)
			button.pressed.connect(_request_vat_mutation.bind(mutation_id))
			mutation_row.add_child(button)
			_vat_mutations.append(button)
		_vat_status = Label.new()
		_vat_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(_vat_status)
		_vat_confirm = ConfirmationDialog.new()
		_vat_confirm.title = "Confirm Homunculus Vat"
		_vat_confirm.confirmed.connect(_send_vat_action)
		add_child(_vat_confirm)
	if not homunculi:
		var trait_actions := HBoxContainer.new()
		trait_actions.alignment = BoxContainer.ALIGNMENT_CENTER
		trait_actions.add_theme_constant_override("separation", 8)
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
		var fusion_row := HBoxContainer.new()
		fusion_row.alignment = BoxContainer.ALIGNMENT_CENTER
		fusion_row.add_theme_constant_override("separation", 8)
		details.add_child(fusion_row)
		_fusion_donor = OptionButton.new()
		_fusion_donor.custom_minimum_size.x = 165
		for donor_id in entries:
			_fusion_donor.add_item(str(entries[donor_id].get("name", donor_id)))
			_fusion_donor.set_item_metadata(_fusion_donor.item_count - 1, donor_id)
		_fusion_donor.item_selected.connect(func(_index): _update_forge_button())
		fusion_row.add_child(_fusion_donor)
		_fusion_button = Button.new()
		_fusion_button.text = "Fusion"
		MenuArt.button(_fusion_button)
		_fusion_button.pressed.connect(_request_fusion)
		fusion_row.add_child(_fusion_button)
		_fusion_info = Label.new()
		_fusion_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fusion_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(_fusion_info)
		_forge_status = Label.new()
		_forge_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_forge_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
			_vat_item = id
			_update_vat_status()
		else:
			_update_forge_button()
		var file: String = str(ITEM_FILES.get(id, id))
		var path := ("res://assets/entities/previews_256/homunculus/" if homunculi else "res://assets/entities/builds/") + file + ".png"
		preview.texture = load(path) if ResourceLoader.exists(path) else null
	list.item_selected.connect(select)
	if list.item_count > 0:
		list.select(0)
		select.call(0)

func _update_vat_status() -> void:
	if not is_instance_valid(_vat_info) or not is_instance_valid(_vat_upgrade) or _registry == null or _vat_item == "":
		return
	var progress: Dictionary = _forge_state.get("homunculus_progress", {})
	var entry: Dictionary = progress.get(_vat_item, {})
	var hom: Dictionary = _registry.get_homunculi().get(_vat_item, {})
	var level := clampi(int(entry.get("level", 0)), 0, 10)
	var next_progress := progress.duplicate(true)
	var next_entry := entry.duplicate(true)
	next_entry["level"] = mini(10, level + 1)
	next_progress[_vat_item] = next_entry
	var mutations := HomProgress.mutation_catalog()
	var active := str(entry.get("mutation_id", ""))
	_vat_info.text = "%s\nLevel %d / 10 | Mutation: %s\nCurrent: %s\nNext: %s\nMutations: Catalyst +1 Power | Vitality +5 HP | Resonance +3%% favorable type bonus\nSynergies:\n%s" % [hom.get("desc", ""), level, str(mutations.get(active, {}).get("name", "None")), _format_values(HomProgress.effective_bonuses(hom, progress)).replace("\n", ", "), _format_values(HomProgress.effective_bonuses(hom, next_progress)).replace("\n", ", "), _format_values(hom.get("per_type", {}))]
	var wallet: Dictionary = _forge_state.get("wallet", {})
	var essence_cost := 25 + 15 * level
	var core_cost := 1 if level >= 5 else 0
	var cooldown := maxi(0, int(entry.get("mutation_changed_at", 0)) + 21600000 - _vat_now) if int(entry.get("mutation_changed_at", 0)) > 0 else 0
	var ready := _forge_debug or (_forge_synced and _backend != null and _backend.token != "" and not _backend._verified_player_id.is_empty())
	var vat_level := int(_forge_state.get("lab", {}).get("buildings", {}).get("homunculus_vat", {}).get("level", 0))
	var hq_level := int(_forge_state.get("lab", {}).get("hqLevel", 0))
	var mutation_reason := ""
	if not ready:
		mutation_reason = "Sign in and wait for server state."
	elif _vat_pending:
		mutation_reason = "Waiting for action confirmation."
	elif vat_level < 1:
		mutation_reason = "Build the Homunculus Vat first."
	elif level < 3:
		mutation_reason = "Requires homunculus level 3 (current: %d)." % level
	elif cooldown > 0:
		mutation_reason = "Next mutation available in %s." % _clock(cooldown)
	elif int(wallet.get("essence", 0)) < 70 or int(wallet.get("core", 0)) < 2 or int(wallet.get("arcane_shard", 0)) < 1:
		mutation_reason = "Insufficient resources: %d/70 Essence, %d/2 Core, %d/1 Arcane Shard." % [int(wallet.get("essence", 0)), int(wallet.get("core", 0)), int(wallet.get("arcane_shard", 0))]
	_vat_upgrade.disabled = not ready or _vat_pending or vat_level < 1 or hq_level < 2 or level >= 10 or int(wallet.get("essence", 0)) < essence_cost or int(wallet.get("core", 0)) < core_cost
	_vat_upgrade.tooltip_text = "Cost: %d Essence%s" % [essence_cost, ", 1 Core" if core_cost else ""]
	for i in range(_vat_mutations.size()):
		var id: String = ["catalyst", "vitality", "resonance"][i]
		_vat_mutations[i].disabled = not ready or _vat_pending or vat_level < 1 or level < 3 or cooldown > 0 or active == id or int(wallet.get("essence", 0)) < 70 or int(wallet.get("core", 0)) < 2 or int(wallet.get("arcane_shard", 0)) < 1
		_vat_mutations[i].modulate = Color(1.25, 1.1, 0.7) if active == id else Color.WHITE
		var description := str(mutations.get(id, {}).get("description", ""))
		_vat_mutations[i].tooltip_text = description + ("\nCurrently equipped." if active == id else "\n" + mutation_reason if mutation_reason != "" else "\nSelect this mutation.")
	_vat_status.text = "Upgrade: %d Essence%s | Mutation: 70 Essence, 2 Core, 1 Arcane Shard\nMutation cooldown: %s" % [essence_cost, ", 1 Core" if core_cost else "", _clock(cooldown) if cooldown > 0 else "Ready"]
	if vat_level < 1 or hq_level < 2:
		_vat_status.text += "\nUpgrade requires Homunculus Vat level 1 and HQ level 2 (current: %d / %d)." % [vat_level, hq_level]
	if level < 3:
		_vat_status.text += "\nMutation requires homunculus level 3 (current: %d)." % level
	elif mutation_reason != "":
		_vat_status.text += "\n" + mutation_reason
	else:
		_vat_status.text += "\nChoose a mutation above. The current mutation is highlighted."

func _request_vat_upgrade() -> void:
	if _vat_upgrade.disabled:
		return
	_vat_action = {"action_type": "HOM_UPGRADE", "payload": {"homunculus_id": _vat_item}}
	_vat_confirm.dialog_text = "Upgrade %s? %s" % [_vat_item, _vat_upgrade.tooltip_text]
	_vat_confirm.popup_centered()

func _request_vat_mutation(id: String) -> void:
	var index := ["catalyst", "vitality", "resonance"].find(id)
	if index < 0 or _vat_mutations[index].disabled:
		return
	_vat_action = {"action_type": "HOM_MUTATE", "payload": {"homunculus_id": _vat_item, "mutation_id": id}}
	_vat_confirm.dialog_text = "Apply %s to %s for 70 Essence, 2 Core and 1 Arcane Shard?\n%s" % [id.capitalize(), _vat_item, _vat_mutations[index].tooltip_text]
	_vat_confirm.popup_centered()

func _send_vat_action() -> void:
	if _vat_action.get("payload", {}).get("homunculus_id") != _vat_item:
		return
	_update_vat_status()
	var action_type := str(_vat_action.get("action_type", ""))
	var index := ["catalyst", "vitality", "resonance"].find(_vat_action.get("payload", {}).get("mutation_id", ""))
	if (action_type == "HOM_UPGRADE" and _vat_upgrade.disabled) or (action_type == "HOM_MUTATE" and (index < 0 or _vat_mutations[index].disabled)):
		return
	lab_action_requested.emit(_vat_action.duplicate(true), "homunculus_vat")

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
		_forge_info.text = "%s\nSpecialization: %s | Unspent points: %d\n%s\nBase (Lv 0): %s\nLv 1: %s\nLv 2: %s\nCurrent: %s\nNext: %s" % [item.get("desc", ""), specialization.capitalize() if specialization != "" else "None", maxi(0, level - allocated), "\n".join(trait_lines), _format_values(base.get("effects", {})).replace("\n", ", "), _format_values(level_one.get("effects", {})).replace("\n", ", "), _format_values(level_two.get("effects", {})).replace("\n", ", "), _format_values(current.get("effects", {})).replace("\n", ", "), _format_values(next.get("effects", {})).replace("\n", ", ")]
	var forge_level := int(_forge_state.get("lab", {}).get("buildings", {}).get("build_forge", {}).get("level", 0))
	var cost := maxi(0, _forge_base_cost + level * _forge_cost_per_level)
	var essence := int(_forge_state.get("wallet", {}).get("essence", 0))
	var online_ready := _backend != null and _backend.token != "" and _forge_synced
	var outstanding := ""
	if not _forge_debug and _backend != null:
		for action in _backend.get_pending_actions():
			if str(action.get("action_type", "")) in ["FORGE_UPGRADE", "FORGE_SPECIALIZE", "FORGE_ALLOCATE_TRAIT", "FORGE_REROLL_TRAIT", "FORGE_CHOOSE_REROLL", "FORGE_FUSE"]:
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
	if is_instance_valid(_fusion_donor) and is_instance_valid(_fusion_button) and _fusion_donor.selected >= 0:
		var donor := str(_fusion_donor.get_item_metadata(_fusion_donor.selected))
		var donor_item: Dictionary = _registry.get_items().get(donor, {})
		var fusion_balance: Dictionary = balance_data.get("balance", {}) if balance_data is Dictionary else {}
		var imprint: Dictionary = fusion_balance.get("forge_fusion_imprints", {}).get(donor, {})
		var fusion_cost: Dictionary = fusion_balance.get("forge_fusion_cost_" + str(donor_item.get("rarity", "")), {})
		var current_fusion: Variant = item_state.get("fusion", {})
		var current_donor := str(current_fusion.get("donor_id", "")) if current_fusion is Dictionary else ""
		var preview_progress := progress.duplicate(true)
		var preview_entry := item_state.duplicate(true)
		preview_entry["fusion"] = {"donor_id": donor}
		preview_progress[_forge_item] = preview_entry
		var preview: Dictionary = preload("res://scripts/domain/item_progress.gd").effective_item(_registry.get_items().get(_forge_item, {}), preview_progress)
		var enough := not fusion_cost.is_empty()
		for resource in fusion_cost:
			if int(wallet.get(resource, 0)) < int(fusion_cost[resource]):
				enough = false
		_fusion_donor.disabled = not can_trait
		_fusion_button.disabled = not can_trait or has_offer or donor == _forge_item or donor == current_donor or level < 3 or int(progress.get(donor, {}).get("level", 0)) < 3 or imprint.is_empty() or not enough
		_fusion_info.text = "Fusion: %s | Imprint: %s | Cost: %s\nPreview: %s" % [str(_registry.get_items().get(current_donor, {}).get("name", "None")), _format_values(imprint).replace("\n", ", "), _format_values(fusion_cost).replace("\n", ", "), _format_values(preview.get("effects", {})).replace("\n", ", ")]
		if level < 3 or int(progress.get(donor, {}).get("level", 0)) < 3:
			_fusion_info.text += "\nFusion requires both weapons at level 3 (current: %d / %d)." % [level, int(progress.get(donor, {}).get("level", 0))]
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
			button.text = "%s\n+%s / point | +%s total" % [option.replace("_", " ").capitalize(), Stats.stat_value(option, bonus), Stats.stat_value(option, bonus * points)]
			button.tooltip_text = "%s per point | %s total at %d points" % [Stats.stat_value(option, bonus), Stats.stat_value(option, bonus * points), points]
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

func _request_fusion() -> void:
	if not is_instance_valid(_fusion_button) or _fusion_button.disabled:
		return
	_forge_confirm_action = "FORGE_FUSE"
	_forge_confirm_payload = {"item_id": _forge_item, "donor_id": str(_fusion_donor.get_item_metadata(_fusion_donor.selected))}
	_forge_confirm.dialog_text = "Fuse %s with %s? Resources are spent permanently; the donor is not consumed.\n%s" % [_forge_item, _fusion_donor.get_item_text(_fusion_donor.selected), _fusion_info.text]
	_forge_confirm.popup_centered()

func _send_forge_confirmed() -> void:
	if _forge_confirm_action == "FORGE_UPGRADE":
		_send_forge_upgrade()
		return
	if (not _forge_debug and _backend == null) or _forge_pending != "" or _forge_confirm_payload.get("item_id") != _forge_item:
		return
	if _forge_confirm_action == "FORGE_FUSE":
		if not is_instance_valid(_fusion_button) or _fusion_button.disabled or str(_fusion_donor.get_item_metadata(_fusion_donor.selected)) != str(_forge_confirm_payload.get("donor_id", "")):
			return
	elif _forge_confirm_action == "FORGE_REROLL_TRAIT":
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
	if _forge_confirm_action == "FORGE_FUSE":
		var donor := str(_forge_confirm_payload.get("donor_id", ""))
		var donor_item: Dictionary = _registry.get_items().get(donor, {})
		var fusion: Variant = item.get("fusion", {})
		if donor == _forge_item or donor_item.is_empty() or level < 3 or int(progress.get(donor, {}).get("level", 0)) < 3 or item.has("pending_reroll") or (fusion is Dictionary and fusion.get("donor_id") == donor) or balance.get("forge_fusion_imprints", {}).get(donor, {}).is_empty() or int(state.get("lab", {}).get("buildings", {}).get("build_forge", {}).get("level", 0)) < 1:
			debug.free()
			return
		cost = balance.get("forge_fusion_cost_" + str(donor_item.get("rarity", "")), {}).duplicate()
		if cost.is_empty():
			debug.free()
			return
		item["fusion"] = {"donor_id": donor}
	elif _forge_confirm_action == "FORGE_SPECIALIZE":
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
		var formatted := _format_values(value).replace("\n", ", ") if value is Dictionary else Stats.stat_value(str(key), value)
		lines.append("%s: %s" % [str(key).replace("_", " ").capitalize(), formatted])
	return "\n".join(lines)

extends Control

class HomTooltipButton extends Button:
	func _make_custom_tooltip(for_text: String) -> Object:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.05, 0.97)
		style.set_content_margin_all(12)
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = for_text
		label.custom_minimum_size.x = 360
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color.WHITE)
		panel.add_child(label)
		return panel


## Loadout screen (Attack/Defense seals).
## Nodes are resolved by explicit scene paths to avoid %UniqueName shorthand.

const REG_PATH := "res://scripts/data_registry.gd"
const SpellLoadout := preload("res://scripts/domain/spell_loadout.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const SpellView := preload("res://scripts/ui/spell_presentation.gd")
const HomProgress := preload("res://scripts/domain/homunculus_progress.gd")
const LockIndicator := preload("res://scripts/ui/lock_indicator.gd")
const BuildPreferences := preload("res://scripts/domain/build_preferences.gd")
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
var ranked_queue: Node

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
var _hom_progress: Dictionary = {}
var _hom_identity := ""
var _pending_restored_hom := ""
var _hom_backend: BackendClient
var _items: Array = []
var _atk_techs: Array = []
var _def_techs: Array = []

var _current_entity_id: String = ""
var _current_homunculus_id: String = ""

var _mode: String = "attack" # "attack" or "defense"
var _has_saved: bool = false
var _hunt_mode := false
var _dungeon_mode := false
var _expedition_mode := false
var _expedition_preview := false
var _dungeon_backend: BackendClient
var _dungeon_request := ""
var _dungeon_kind := ""
var _dungeon_recovered := false
var _dungeon_payload: Dictionary = {}
var _hunt_spells: Dictionary = {}
var _dungeon_spells_changed: Dictionary = {}
var _hunt_backend: BackendClient
var _hunt_recovery_request := ""
var _hunt_submit_request := ""
var _hunt_identity := ""
var _hunt_payload: Dictionary = {}
var _hunt_recovered := false
var _hunt_ready_requested := false
var _hunt_exit_requested := false
var _hunt_exit_after_loadout := false
var _hunt_exit_request := ""
var _hunt_exit_action := ""
var _hunt_closed_recovery := ""
var _spell_debug := DebugFlags.new()
var _preferences_owner := ""
var _preferences_ready := false
var _cards_ready := false
var _weapon_overlay: Control
var _weapon_list: VBoxContainer
var _weapon_heading: Label
var _weapon_target: Button

func _exit_tree() -> void:
	_spell_debug.free()
	if is_instance_valid(_reg):
		_reg.free()
var _spell_backend: BackendClient
var _spell_state := {}
var _dungeon_spell_progress: Variant = null
var _build_warning: Label
var _spell_warning: Label
var _spell_synced := false
var _spell_pending_id := ""
var _spell_pending_mode := ""
var _spell_pending_entity := ""
var _spell_button: Button
var _spell_dialog: Control
var _spell_picker: Control
var _spell_empty_notice: Label
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
	_dungeon_mode = not str(SceneRouter._dungeon_context.get("run_id", "")).is_empty()
	_expedition_preview = OS.has_feature("editor") and get_node("/root/ConnectionGate").debug_lab_navigation_allowed() and bool(SceneRouter._expedition_context.get("visual_preview", false))
	if _expedition_preview: _dungeon_mode = false
	_expedition_mode = bool(SceneRouter._expedition_context.get("loadout", false)) and not _dungeon_mode
	_hunt_mode = SceneRouter._hunt_loadout_active and not _dungeon_mode and not _expedition_mode
	if _hunt_mode and not str(SceneRouter._solo_hunt_context.get("replaced_session_id", "")).is_empty():
		var notice := Label.new()
		notice.text = "Previous hunt abandoned."
		notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
		notice.offset_left = -120
		notice.offset_right = 120
		notice.offset_top = 8
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(notice)
		SceneRouter._solo_hunt_context.erase("replaced_session_id")
		get_tree().create_timer(5.0).timeout.connect(notice.queue_free)
	if _hunt_mode or _dungeon_mode or _expedition_mode:
		$RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/TechCenter.hide()
		if _dungeon_mode or _expedition_mode:
			$RootMargin/MainHSplit/LeftPanel/ModeRow.hide()
			$RootMargin/MainHSplit/LeftPanel/ModeRow/AttackCol.hide()
			$RootMargin/MainHSplit/LeftPanel/ModeRow/DefenseCol.hide()
			if btn_play: btn_play.text = tr("LOADOUT_START_RUN")
		else:
			$RootMargin/MainHSplit/LeftPanel/ModeRow.hide()
			if btn_play: btn_play.text = tr("LOADOUT_READY")
		btn_save.hide()
		var back := $BackButton as Button
		var original_back := Callable(back, "_on_pressed")
		if back.pressed.is_connected(original_back):
			back.pressed.disconnect(original_back)
		back.pressed.connect(SceneRouter.go_to_expeditions if _expedition_mode else (_dungeon_exit_warning if _dungeon_mode else _on_hunt_back))
		if _expedition_preview:
			back.pressed.disconnect(SceneRouter.go_to_expeditions)
			back.pressed.connect(queue_free)
			btn_play.disabled = true
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
	if _dungeon_mode:
		_items = _items.duplicate()
		_items.push_front({"id": "", "name": "None"})
	else:
		_items = _items.duplicate()
		_items.append({"id": "", "name": "None"})
	_setup_spell_state()
	_build_spell_dialog()
	_wire_buttons()
	_wire_build_tooltips()
	_populate_dropdowns()
	_refresh_build_warning()
	_build_cards()
	_cards_ready = true
	if not _hunt_mode and not _dungeon_mode and not _expedition_mode:
		ranked_queue = preload("res://scripts/ui/ranked_queue.gd").new()
		add_child(ranked_queue)
		$RootMargin/MainHSplit/LeftPanel/ModeRow/AttackCol/AttackLabel.text = "" if ranked_queue.friendly else "PRACTICE"
		$RootMargin/MainHSplit/LeftPanel/ModeRow/DefenseCol/DefenseLabel.text = "" if ranked_queue.friendly else "RANKED PvP"
		btn_seal_attack.set_pressed_no_signal(not ranked_queue.selected)
		if ranked_queue.friendly:
			var back := $BackButton as Button
			var original_back := Callable(back, "_on_pressed")
			if back.pressed.is_connected(original_back): back.pressed.disconnect(original_back)
			back.pressed.connect(ranked_queue._friendly_cancel)
	if not _hunt_mode and not _dungeon_mode and not _expedition_mode and not _expedition_preview and not ranked_queue.friendly:
		var forest_return = preload("res://scripts/ui/forest_return_button.gd").attach(self)
		if forest_return != null:
			forest_return.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			forest_return.offset_left = -460
			forest_return.offset_right = -210
			forest_return.offset_top = 12
			forest_return.offset_bottom = 64
			forest_return.z_index = 40
	if not _hunt_mode and not _dungeon_mode:
		_restore_build_preferences(_verified_preferences_identity())
	_refresh_details()
	_update_save_button_label()
	if _hunt_mode and lbl_mode != null:
		lbl_mode.text = "LOADOUT_HUNT"
	if _dungeon_mode:
		if lbl_mode != null:
			lbl_mode.text = "LOADOUT_DUNGEON"
		_dungeon_payload = SceneRouter._dungeon_context.get("pending_loadout", {}).duplicate(true)
		_dungeon_backend = BackendClient.new()
		_dungeon_backend.base_url = spell_backend_url
		_dungeon_backend.auto_dev_login = false
		_dungeon_backend.state_updated.connect(_on_dungeon_identity)
		_dungeon_backend.api_completed.connect(_on_dungeon_loadout_response)
		add_child(_dungeon_backend)
		_set_build_error("Dungeons: verifying account...")
	if _hunt_mode and not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty():
		_hunt_identity = str(SceneRouter._solo_hunt_context.get("loadout_identity", ""))
		var saved_payload: Variant = SceneRouter._solo_hunt_context.get("pending_loadout", {})
		if saved_payload is Dictionary:
			_hunt_payload = saved_payload.duplicate(true)
		_hunt_backend = BackendClient.new()
		_hunt_backend.base_url = spell_backend_url
		_hunt_backend.auto_dev_login = false
		_hunt_backend.api_completed.connect(_on_hunt_recovery_completed)
		_hunt_backend.state_updated.connect(_on_hunt_identity_updated)
		_hunt_backend.auth_changed.connect(_on_hunt_auth_changed)
		add_child(_hunt_backend)
		_set_build_error("Verifying account for Boss Hunt...")

func _on_hunt_back() -> void:
	var session_id := str(SceneRouter._solo_hunt_context.get("session_id", ""))
	if session_id.is_empty():
		SceneRouter.cancel_hunt_loadout()
		return
	_hunt_ready_requested = false
	if _hunt_backend == null or _hunt_identity.is_empty() or _hunt_backend._verified_player_id != _hunt_identity or _hunt_backend.token.is_empty() or get_node("/root/ConnectionGate").blocked():
		_set_build_error("Recover the authenticated Boss Hunt before leaving.")
		return
	if not _hunt_submit_request.is_empty() or not _hunt_recovery_request.is_empty() or not _hunt_exit_request.is_empty():
		_set_build_error("Wait for the pending Boss Hunt request to recover.")
		return
	if not _hunt_payload.is_empty() or SceneRouter._solo_hunt_context.has("pending_loadout"):
		_hunt_exit_after_loadout = true
		_set_build_error("Recover the pending loadout before leaving.")
		_hunt_recovered = false
		_recover_hunt_session()
		return
	_hunt_exit_requested = true
	# A fresh server snapshot also resolves an uncertain forfeit response.
	_recover_hunt_session()

func _send_hunt_exit(session_id: String) -> void:
	if _hunt_exit_action.is_empty():
		_hunt_exit_action = _hunt_backend._make_uuid()
	_hunt_exit_request = _hunt_backend.request_api("POST", "/world/boss-hunts/forfeit", {"session_id": session_id, "client_action_id": _hunt_exit_action}, false, get_node("/root/ConnectionGate").blocked())
	if _hunt_exit_request.is_empty():
		_set_build_error("Forfeit not confirmed. Recover the session and retry.")
		_hunt_recovered = false
	else:
		_set_build_error("Confirming Boss Hunt forfeit...")

func _finish_hunt_exit(session_id: String) -> void:
	var gate := get_node("/root/ConnectionGate")
	if gate.blocked() and not gate._player_verified:
		return
	if not _hunt_exit_action.is_empty():
		if not gate.journal_confirm(_hunt_exit_action): return
		_hunt_exit_action = ""
	if not gate.journal_close("hunt", session_id): return
	_hunt_exit_requested = false
	if gate.blocked(): gate.recovery_completed()
	SceneRouter.cancel_hunt_loadout()

func _on_hunt_auth_changed(_token: String) -> void:
	_clear_hom_ownership()
	if not _hunt_identity.is_empty():
		_hunt_ready_requested = false
	_preferences_ready = false
	_preferences_owner = ""
	_hunt_recovered = false
	_hunt_submit_request = ""
	_hunt_recovery_request = ""
	if btn_play:
		btn_play.disabled = false
	SceneRouter._solo_hunt_context.erase("recovered_session")
	_set_build_error("Account changed. Return to World Zone to reopen the Boss Hunt.")

func _on_hunt_identity_updated(state: Dictionary) -> void:
	_update_hom_ownership(state, _hunt_backend, str(SceneRouter._solo_hunt_context.get("loadout_identity", "")))
	if _hunt_backend == null or state.is_empty():
		_hunt_recovered = false
		return
	var identity := str(state.get("player_id", ""))
	if identity.is_empty() or identity != _hunt_backend._verified_player_id:
		return
	if not _hunt_identity.is_empty() and identity != _hunt_identity:
		_hunt_recovered = false
		_set_build_error("Account changed. Return to World Zone to reopen the Boss Hunt.")
		return
	if _hunt_identity.is_empty():
		_hunt_identity = identity
		SceneRouter._solo_hunt_context["loadout_identity"] = identity
	_refresh_hom_cards()
	if not _hunt_recovered and _hunt_recovery_request.is_empty() and _hunt_submit_request.is_empty():
		_recover_hunt_session()

func _recover_hunt_session() -> void:
	if _hunt_backend == null or _hunt_backend.token.is_empty() or _hunt_identity.is_empty() or _hunt_backend._verified_player_id != _hunt_identity:
		_set_build_error("Sign in to recover this Boss Hunt. Your session remains active.")
		return
	var session_id := str(SceneRouter._solo_hunt_context.get("session_id", ""))
	_hunt_recovery_request = _hunt_backend.request_api("GET", "/world/boss-hunts/session?session_id=" + session_id.uri_encode(), null, false)
	if _hunt_recovery_request.is_empty():
		_set_build_error("Could not recover this Boss Hunt. Return to World Zone and retry.")
	else:
		_set_build_error("Recovering Boss Hunt session...")

func _on_hunt_recovery_completed(request_id: String, ok: bool, data: Dictionary) -> void:
	if request_id == _hunt_exit_request and not request_id.is_empty():
		_hunt_exit_request = ""
		if _hunt_closed_recovery in ["EXPIRED", "VERIFIED_WIN", "VERIFIED_LOSS"] and not ok and int(data.get("http_status", 0)) == 409 and str(data.get("error", "")) == "Session is already closed." and not _hunt_identity.is_empty() and _hunt_backend._verified_player_id == _hunt_identity:
			_hunt_closed_recovery = ""
			_finish_hunt_exit(str(SceneRouter._solo_hunt_context.get("session_id", "")))
			return
		if ok and str(data.get("status", "")) == "FORFEIT" and str(data.get("session_id", "")) == str(SceneRouter._solo_hunt_context.get("session_id", "")) and not _hunt_identity.is_empty() and _hunt_backend._verified_player_id == _hunt_identity:
			_finish_hunt_exit(str(SceneRouter._solo_hunt_context.get("session_id", "")))
		else:
			_hunt_recovered = false
			_set_build_error("Forfeit not confirmed. Recover the session and retry.")
		return
	if request_id == _hunt_submit_request and not request_id.is_empty():
		_hunt_submit_request = ""
		if btn_play:
			btn_play.disabled = false
		if _hunt_backend._verified_player_id != _hunt_identity or _hunt_identity.is_empty():
			_hunt_recovered = false
			_set_build_error("Account changed. Return to World Zone.")
			return
		if not _hunt_closed_recovery.is_empty() and not _hunt_payload.is_empty():
			var rejected := not ok and int(data.get("http_status", 0)) == 409 and str(data.get("error", "")) == "Session unavailable for initialization."
			var replayed := ok and str(data.get("session_id", "")) == str(SceneRouter._solo_hunt_context.get("session_id", "")) and _hunt_loadout_matches(data)
			if rejected or replayed:
				var gate := get_node("/root/ConnectionGate")
				if not gate.journal_confirm(str(_hunt_payload.get("client_action_id", ""))): return
				if not gate.journal_close("hunt", str(SceneRouter._solo_hunt_context.get("session_id", ""))): return
				_hunt_payload.clear()
				SceneRouter._solo_hunt_context.erase("pending_loadout")
				_hunt_closed_recovery = ""
				if gate.blocked(): gate.recovery_to_combat()
				else: SceneRouter.go_to_combat()
				return
		if ok and _accept_hunt_session(data) and int(data.get("combat_revision", 0)) >= 1 and data.get("combat_state") is Dictionary and _hunt_loadout_matches(data):
			if _hunt_payload.has("session_id") and not get_node("/root/ConnectionGate").journal_confirm(str(_hunt_payload.get("client_action_id", ""))): return
			_hunt_payload.clear()
			SceneRouter._solo_hunt_context.erase("pending_loadout")
			_hunt_recovered = true
			if _hunt_exit_after_loadout:
				_hunt_exit_after_loadout = false
				call_deferred("_on_hunt_back")
			else:
				_continue_hunt_ready()
			return
		if not ok and str(data.get("error", "")) in ["Invalid or unsupported hunt loadout.", "Invalid hunt loadout selection.", "Invalid hunt loadout request."]:
			if _hunt_payload.has("session_id") and not get_node("/root/ConnectionGate").journal_confirm(str(_hunt_payload.get("client_action_id", ""))): return
			_hunt_payload.clear()
			SceneRouter._solo_hunt_context.erase("pending_loadout")
			_hunt_ready_requested = false
			if _hunt_exit_after_loadout:
				_hunt_exit_after_loadout = false
				call_deferred("_on_hunt_back")
			_set_build_error("Loadout rejected: " + str(data.get("error")))
			return
		_hunt_recovered = false
		_set_build_error("Response uncertain; recovering session before retry.")
		_recover_hunt_session()
		return
	if request_id != _hunt_recovery_request or request_id.is_empty():
		return
	_hunt_recovery_request = ""
	var session: Variant = data.get("session")
	if _hunt_exit_requested:
		var session_id := str(SceneRouter._solo_hunt_context.get("session_id", ""))
		if not ok or not session is Dictionary or session_id.is_empty() or str(session.get("session_id", "")) != session_id or _hunt_identity.is_empty() or _hunt_backend._verified_player_id != _hunt_identity or not _hunt_payload.is_empty() or SceneRouter._solo_hunt_context.has("pending_loadout"):
			_hunt_recovered = false
			_set_build_error("Boss Hunt exit is uncertain. Recover and retry.")
			return
		var status := str(session.get("status", ""))
		if status == "ACTIVE":
			_send_hunt_exit(session_id)
		elif not _hunt_exit_action.is_empty() and (status == "EXPIRED" or (status in ["VERIFIED_WIN", "VERIFIED_LOSS"] and _accept_hunt_session(session))):
			_hunt_closed_recovery = status
			_send_hunt_exit(session_id)
		elif status == "FORFEIT" or (status in ["EXPIRED", "VERIFIED_WIN", "VERIFIED_LOSS"] and _hunt_exit_action.is_empty() and (status == "EXPIRED" or _accept_hunt_session(session))):
			_finish_hunt_exit(session_id)
		else:
			_set_build_error("Boss Hunt exit is uncertain. Recover and retry.")
		return
	if ok and session is Dictionary and not _hunt_identity.is_empty() and _hunt_backend._verified_player_id == _hunt_identity and str(session.get("session_id", "")) == str(SceneRouter._solo_hunt_context.get("session_id", "")) and str(session.get("status", "")) in ["EXPIRED", "FORFEIT"]:
		var gate := get_node("/root/ConnectionGate")
		if not _hunt_payload.is_empty():
			if not _payload_hom_safe(_hunt_payload):
				_set_build_error(tr("LOADOUT_HOM_PENDING"))
				return
			_hunt_closed_recovery = str(session.status)
			_hunt_submit_request = _hunt_backend.request_api("POST", "/world/boss-hunts/loadout", _hunt_payload.duplicate(true), false, gate.blocked() and gate._player_verified)
			return
		if not gate.journal_close("hunt", str(session.session_id)): return
		_hunt_payload.clear()
		SceneRouter._solo_hunt_context.erase("pending_loadout")
		if gate.blocked(): gate.recovery_to_combat()
		else: SceneRouter.go_to_combat()
		return
	if not ok or not session is Dictionary or not _accept_hunt_session(session):
		_hunt_recovered = false
		_hunt_ready_requested = false
		_set_build_error("Boss Hunt unavailable or connection failed. Return to World Zone and retry.")
		return
	_hunt_recovered = true
	if int(session.get("combat_revision", 0)) >= 1:
		if not _hunt_payload.is_empty() and not _hunt_loadout_matches(session):
			_hunt_recovered = false
			_set_build_error("Recovered loadout differs from the submitted selection. Return to World Zone.")
			return
		if not _hunt_payload.is_empty():
			if _hunt_payload.has("session_id") and not get_node("/root/ConnectionGate").journal_confirm(str(_hunt_payload.get("client_action_id", ""))): return
		_hunt_payload.clear()
		SceneRouter._solo_hunt_context.erase("pending_loadout")
		if _hunt_exit_after_loadout:
			_hunt_exit_after_loadout = false
			call_deferred("_on_hunt_back")
		else:
			_continue_hunt_ready()
	else:
		_set_build_error("Session recovered. Retry the same loadout." if not _hunt_payload.is_empty() else "Session recovered. Select your loadout.")
		if _hunt_payload.is_empty() and not SceneRouter._solo_hunt_context.has("pending_loadout"):
			_restore_build_preferences(_hunt_identity)
		if _hunt_ready_requested or _hunt_exit_after_loadout:
			call_deferred("_submit_hunt_loadout")

func _continue_hunt_ready() -> void:
	if not _hunt_ready_requested:
		_set_build_error("Combat ready. Press Ready to continue.")
		return
	_hunt_ready_requested = false
	SceneRouter._hunt_loadout_active = false
	var gate := get_node("/root/ConnectionGate")
	if gate.blocked():
		gate.recovery_to_combat()
	else:
		SceneRouter.go_to_combat()

func _accept_hunt_session(session: Dictionary) -> bool:
	if _hunt_identity.is_empty() or _hunt_backend == null or _hunt_backend._verified_player_id != _hunt_identity or str(session.get("session_id", "")) != str(SceneRouter._solo_hunt_context.get("session_id", "")):
		return false
	var status := str(session.get("status", ""))
	if status != "ACTIVE":
		if status not in ["VERIFIED_WIN", "VERIFIED_LOSS"] or int(session.get("combat_revision", 0)) < 1 or not _hunt_payload.is_empty() or not _hunt_submit_request.is_empty() or SceneRouter._solo_hunt_context.has("pending_loadout"):
			return false
		var state: Variant = session.get("combat_state")
		var loadout: Variant = session.get("combat_loadout")
		if not state is Dictionary or state.is_empty() or not loadout is Dictionary or loadout.is_empty() or str(state.get("terminal_result", "")) != ("WIN" if status == "VERIFIED_WIN" else "LOSS"):
			return false
	SceneRouter._solo_hunt_context["recovered_session"] = session.duplicate(true)
	return true

func _hunt_loadout_matches(session: Dictionary) -> bool:
	var saved: Variant = session.get("combat_loadout", {})
	if not saved is Dictionary:
		return false
	for key in ["entity_id", "weapon_ids", "homunculus_id", "spell_ids", "mode"]:
		if saved.get(key) != _hunt_payload.get(key):
			return false
	return true

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
	dd_side1.hide()
	dd_side2.hide()
	for slot in [dd_item1, dd_item2]:
		if slot is Button:
			slot.custom_minimum_size = Vector2(275, 70)
			MenuArt.button(slot)
			var heading := Label.new()
			heading.text = "Primary Weapon" if slot == dd_item1 else "Secondary Weapon"
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			heading.add_theme_color_override("font_color", Color(0.92, 0.92, 0.85))
			heading.add_theme_font_size_override("font_size", 18)
			grid.add_child(heading)
			grid.move_child(heading, 0 if slot == dd_item1 else 1)
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
	if _dungeon_mode:
		_build_warning = _create_dungeon_warning(button, "No weapon selected")
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

func _create_dungeon_warning(button: Button, hint: String) -> Label:
	var badge := Label.new()
	badge.name = "DungeonWarning"
	badge.text = "!"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -24
	badge.offset_top = 3
	badge.offset_right = -4
	badge.offset_bottom = 23
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("cf2936")
	background.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("normal", background)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)
	button.tooltip_text = hint
	return badge

func _refresh_build_warning() -> void:
	if is_instance_valid(_build_warning):
		_build_warning.visible = _dungeon_mode and _idx_to_id(_items, dd_item1).is_empty() and _idx_to_id(_items, dd_item2).is_empty()

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
	if _reg != null and _reg.has_method("get_homunculus_collection"):
		_homunculi = _as_array(_reg.call("get_homunculus_collection"))
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
	if _expedition_preview:
		_spell_state = {"player_id":"visual-preview", "spell_progress":{}, "item_progress":{}, "homunculus_progress":{}}
		_spell_synced = true
		return
	_spell_debug.reload()
	if not SceneRouter._friendly_context.is_empty():
		_spell_debug.unlock_all_buildings = false
		_spell_debug.force_all_clickable = false
	if _spell_debug.unlock_all_buildings and not _dungeon_mode and not _expedition_mode:
		_spell_state = _spell_debug.load_lab_state()
		_spell_synced = true
		if not _hunt_mode:
			_hom_backend = BackendClient.new()
			_hom_backend.auto_dev_login = false
			_hom_backend.base_url = spell_backend_url
			_hom_backend.auth_changed.connect(func(_token): _clear_hom_ownership())
			_hom_backend.state_updated.connect(func(state): _update_hom_ownership(state, _hom_backend))
			add_child(_hom_backend)
		return
	_spell_backend = BackendClient.new()
	if _dungeon_mode:
		_spell_backend.auto_dev_login = false
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
	_clear_hom_ownership()
	if not _hunt_mode and not _dungeon_mode:
		_preferences_owner = ""
		_preferences_ready = false
		if _cards_ready:
			_reset_build_defaults()
	_spell_synced = false
	_spell_state = {}
	if _dungeon_mode and _dungeon_spell_progress is Dictionary: _spell_state["spell_progress"] = _dungeon_spell_progress.duplicate(true)
	_refresh_spell_button()
	if token != "" and _spell_backend != null:
		_spell_backend.request_api("GET", "/player/state", null, true)

func _on_spell_state_updated(state: Dictionary) -> void:
	if not _hunt_mode and not _dungeon_mode:
		_update_hom_ownership(state, _spell_backend)
	if _spell_debug.unlock_all_buildings and not _dungeon_mode and not _expedition_mode:
		return
	_spell_state = state.duplicate(true)
	if _dungeon_mode and _dungeon_spell_progress is Dictionary: _spell_state["spell_progress"] = _dungeon_spell_progress.duplicate(true)
	_spell_synced = true
	_refresh_spell_button()
	if not _hunt_mode and not _dungeon_mode and _spell_backend != null and not state.is_empty() and str(state.get("player_id", "")) == _spell_backend._verified_player_id:
		_restore_build_preferences(_spell_backend._verified_player_id)

func _read_seal_data(mode: String) -> Dictionary:
	var path := BuildPreferences.seal_path(_verified_preferences_identity(), mode)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var identity := _verified_preferences_identity()
	if not identity.is_empty() and str(parsed.get("player_id", "")) != identity:
		return {}
	return parsed

func _equipped_spells(mode: String, entity_id: String) -> Array:
	if _reg == null:
		return []
	if _hunt_mode or _dungeon_mode or _expedition_mode:
		var selected: Variant = _hunt_spells.get(entity_id, [])
		if SpellLoadout.valid(_reg, entity_id, _spell_state.get("spell_progress", {}), selected):
			return selected.duplicate()
		return SpellLoadout.initial_ids(_reg, entity_id)
	return SpellLoadout.saved_ids(_reg, _spell_state, mode, entity_id, _read_seal_data(mode), not _spell_debug.unlock_all_buildings)

func _refresh_spell_button() -> void:
	if _spell_button == null or _reg == null:
		return
	_spell_button.text = tr("LOADOUT_CHANGE_SPELLS")
	var available := SpellLoadout.available_ids(_reg, _current_entity_id, _spell_state.get("spell_progress", {}))
	_spell_button.visible = true
	_spell_button.disabled = _spell_pending_id != ""
	if _dungeon_mode and not _dungeon_spell_progress is Dictionary: _spell_button.disabled = true
	var equipped := _equipped_spells(_mode, _current_entity_id)
	var extra := available.any(func(id): return id not in equipped)
	_spell_button.tooltip_text = tr("LOADOUT_CHANGE_SPELLS_HINT") if extra else tr("LOADOUT_SPELLS_EMPTY")
	MenuArt.button(_spell_button)
	if is_instance_valid(_spell_warning):
		_spell_warning.visible = _dungeon_mode and _dungeon_spell_progress is Dictionary and extra and not _dungeon_spells_changed.has(_current_entity_id)

func _build_spell_dialog() -> void:
	_spell_button = get_node_or_null("SpellConfig") as Button
	if _spell_button == null:
		return
	_spell_button.text = tr("LOADOUT_CHANGE_SPELLS")
	_spell_button.reparent($RootMargin/MainHSplit/RightPanel/BottomRow)
	_spell_button.custom_minimum_size = Vector2(190, 72)
	_spell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$RootMargin/MainHSplit/RightPanel/BottomRow.move_child(_spell_button, 0)
	if _dungeon_mode:
		_spell_warning = _create_dungeon_warning(_spell_button, "Additional spells available")
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
	close.tooltip_text = "UI_CLOSE"
	close.custom_minimum_size = Vector2(44, 36)
	MenuArt.button(close)
	close.pressed.connect(_spell_dialog.hide)
	header.add_child(close)
	_spell_empty_notice = Label.new()
	_spell_empty_notice.text = tr("LOADOUT_SPELLS_EMPTY")
	_spell_empty_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spell_empty_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spell_empty_notice.hide()
	content.add_child(_spell_empty_notice)
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
	_spell_picker = right
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	var filters := HBoxContainer.new()
	right.add_child(filters)
	var filter_group := ButtonGroup.new()
	for group_name in ["All", "Initial", "Hybrid", "Universal"]:
		var filter := Button.new()
		filter.text = "SPELL_FILTER_" + group_name.to_upper()
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
	cancel.text = "UI_CANCEL"
	cancel.custom_minimum_size = Vector2(150, 42)
	MenuArt.button(cancel)
	cancel.pressed.connect(_spell_dialog.hide)
	actions.add_child(cancel)
	_spell_confirm = Button.new()
	_spell_confirm.text = "UI_CONFIRM"
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
	var available := SpellLoadout.available_ids(_reg, _current_entity_id, _spell_state.get("spell_progress", {}))
	_spell_empty_notice.visible = not available.any(func(id): return id not in _spell_draft)
	_spell_selected_slot = 0
	_spell_filter = "All"
	var entity: Dictionary = _reg.entities.get(_current_entity_id, {})
	_spell_heading.text = tr("LOADOUT_CONFIGURE_SPELLS") % [entity.get("name", ""), SpellView.affinity(entity)]
	_rebuild_spell_catalog()
	_refresh_spell_draft(0)
	_spell_picker.hide()
	_spell_dialog.show()

func _select_spell_slot(index: int) -> void:
	_spell_selected_slot = index
	_refresh_spell_draft(index)
	_spell_picker.show()

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
		if status not in ["Initial", "Learned"]: continue
		var row := Button.new()
		row.set_meta("spell", spell)
		row.text = "%s   |   %s" % [GameLocalization.catalog("spell", str(spell.id), "name", str(spell.name)), SpellView.affinity(spell)]
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

func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready():
		return
	if lbl_mode != null:
		lbl_mode.text = _localized_mode()
	_refresh_spell_button()
	_refresh_hom_cards()
	if is_instance_valid(_spell_empty_notice):
		_spell_empty_notice.text = tr("LOADOUT_SPELLS_EMPTY")
	if btn_play != null and (_hunt_mode or _dungeon_mode):
		btn_play.text = tr("LOADOUT_START_RUN" if _dungeon_mode else "LOADOUT_READY")
	if lbl_homunculus != null:
		var hom := _find_by_id(_homunculi, _current_homunculus_id)
		lbl_homunculus.text = tr("LOADOUT_HOMUNCULUS") % str(hom.get("name", _current_homunculus_id if not _current_homunculus_id.is_empty() else "—"))
	if lbl_types != null:
		var entity := _find_by_id(_entities, _current_entity_id)
		if not entity.is_empty():
			var kind := _type_for_entity(entity)
			lbl_types.text = tr("LOADOUT_TYPES") % GameLocalization.catalog("type", kind, "name", kind)
	for button in [dd_item1, dd_item2, dd_side1, dd_side2]:
		if button != null and button.has_meta("items"):
			var item := _get_selected_item_from_button(button)
			button.text = tr("LOADOUT_NONE") if item.is_empty() or str(item.get("id", "")).is_empty() else _label_for_item(item, "None")
	if is_instance_valid(tooltip_panel) and tooltip_panel.visible:
		var hovered: Variant = tooltip_panel.get_meta("hovered_button", null)
		if is_instance_valid(hovered):
			_on_build_hover_entered(hovered)
	if is_instance_valid(_spell_catalog):
		for row in _spell_catalog.get_children():
			if row is Button and row.has_meta("spell"):
				var spell: Dictionary = row.get_meta("spell")
				row.text = "%s   |   %s" % [GameLocalization.catalog("spell", str(spell.id), "name", str(spell.name)), SpellView.affinity(spell)]
	if is_instance_valid(_spell_dialog) and _spell_dialog.visible and _spell_draft.size() > _spell_selected_slot:
		var entity: Dictionary = _reg.entities.get(_current_entity_id, {})
		_spell_heading.text = tr("LOADOUT_CONFIGURE_SPELLS") % [entity.get("name", ""), SpellView.affinity(entity)]
		var duplicate_preview: Dictionary = _spell_description.get_meta("duplicate_preview", {})
		var duplicate_status := str(_spell_description.get_meta("duplicate_status", "Learned"))
		_refresh_spell_draft(_spell_selected_slot)
		if not duplicate_preview.is_empty():
			_spell_description.text = "%s\n%s\n%s" % [GameLocalization.catalog("spell", str(duplicate_preview.id), "name", str(duplicate_preview.name)), SpellView.detail(duplicate_preview, duplicate_status), tr("LOADOUT_SPELL_DUPLICATE")]
			_spell_description.set_meta("duplicate_preview", duplicate_preview)

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
	_spell_description.set_meta("duplicate_preview", {})
	_spell_description.text = "%s\n%s" % [GameLocalization.catalog("spell", str(spell.id), "name", str(spell.name)), SpellView.detail(spell, status)]
	if status not in ["Initial", "Learned"]:
		return
	var id := str(spell.id)
	if id in _spell_draft and _spell_draft[_spell_selected_slot] != id:
		_spell_description.set_meta("duplicate_preview", spell)
		_spell_description.set_meta("duplicate_status", status)
		_spell_description.text += "\n" + tr("LOADOUT_SPELL_DUPLICATE")
		return
	_spell_draft[_spell_selected_slot] = id
	_refresh_spell_draft(_spell_selected_slot)

func _refresh_spell_draft(slot_index: int) -> void:
	_spell_description.set_meta("duplicate_preview", {})
	var valid := SpellLoadout.valid(_reg, _current_entity_id, _spell_state.get("spell_progress", {}), _spell_draft)
	_spell_confirm.disabled = not valid or _spell_pending_id != "" or (not _spell_debug.unlock_all_buildings and not _spell_synced)
	for i in _spell_slots.size():
		var selected_spell: Dictionary = _reg.get_spell_by_id(str(_spell_draft[i])) if i < _spell_draft.size() else {}
		_spell_slots[i].text = "%d. %s\n%s | CD %d" % [i + 1, GameLocalization.catalog("spell", str(selected_spell.get("id", "")), "name", str(selected_spell.get("name", "-"))), SpellView.affinity(selected_spell), int(selected_spell.get("cooldown_turns", 0))]
		_spell_slots[i].button_pressed = i == _spell_selected_slot
	var spell: Dictionary = _reg.get_spell_by_id(str(_spell_draft[slot_index])) if slot_index < _spell_draft.size() else {}
	_spell_description.text = "%s\n%s" % [GameLocalization.catalog("spell", str(spell.get("id", "")), "name", str(spell.get("name", ""))), SpellView.detail(spell, "Equipped")]
	if not valid:
		_spell_description.text += "\n" + tr("LOADOUT_SPELL_DISTINCT")
	elif not _spell_debug.unlock_all_buildings and not _spell_synced:
		_spell_description.text += "\nWaiting for an authenticated server state."

func _confirm_spell_dialog() -> void:
	if not SpellLoadout.valid(_reg, _current_entity_id, _spell_state.get("spell_progress", {}), _spell_draft):
		return
	if _hunt_mode or _dungeon_mode or _expedition_mode:
		if not _spell_debug.unlock_all_buildings and not _spell_synced:
			_set_build_error("Server state is unavailable.")
			return
		if _dungeon_mode and _spell_draft != _equipped_spells(_mode, _current_entity_id):
			_dungeon_spells_changed[_current_entity_id] = true
		_hunt_spells[_current_entity_id] = _spell_draft.duplicate()
		_refresh_spell_button()
		_set_build_error("" if _dungeon_mode or _expedition_mode else "Boss Hunt spells selected.")
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
	_ensure_distinct_weapons()
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

func _open_weapon_selector(target: Button) -> void:
	_weapon_target = target
	if not is_instance_valid(_weapon_overlay):
		_weapon_overlay = Control.new()
		_weapon_overlay.name = "WeaponSelector"
		_weapon_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_weapon_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_weapon_overlay.z_index = 60
		add_child(_weapon_overlay)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.78)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weapon_overlay.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		_weapon_overlay.add_child(center)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(820, 550)
		panel.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup-grande.png", Vector4(62, 72, 62, 48)))
		center.add_child(panel)
		var layout := VBoxContainer.new()
		layout.add_theme_constant_override("separation", 8)
		panel.add_child(layout)
		_weapon_heading = Label.new()
		_weapon_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_weapon_heading.add_theme_font_size_override("font_size", 22)
		_weapon_heading.add_theme_color_override("font_color", Color.WHITE)
		_weapon_heading.add_theme_color_override("font_outline_color", Color.BLACK)
		_weapon_heading.add_theme_constant_override("outline_size", 4)
		layout.add_child(_weapon_heading)
		var scroll := ScrollContainer.new()
		scroll.name = "WeaponScroll"
		scroll.custom_minimum_size = Vector2(650, 400)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		layout.add_child(scroll)
		_weapon_list = VBoxContainer.new()
		_weapon_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_weapon_list)
		var close := Button.new()
		close.text = tr("UI_CLOSE")
		close.custom_minimum_size.y = 42
		MenuArt.button(close)
		close.pressed.connect(_weapon_overlay.hide)
		layout.add_child(close)
	_weapon_heading.text = tr("LOADOUT_PRIMARY_WEAPON") if target == dd_item1 else tr("LOADOUT_SECONDARY_WEAPON")
	for child in _weapon_list.get_children():
		_weapon_list.remove_child(child)
		child.queue_free()
	var selected := _idx_to_id(_items, target)
	var other := _idx_to_id(_items, dd_item2 if target == dd_item1 else dd_item1)
	for item in _items:
		if not item is Dictionary:
			continue
		var id := str(item.get("id", ""))
		var row := Button.new()
		row.name = "Weapon_" + (id if not id.is_empty() else "none")
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.y = 98
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.toggle_mode = true
		row.button_pressed = id == selected
		row.disabled = not id.is_empty() and id == other
		row.tooltip_text = tr("LOADOUT_WEAPON_OTHER_SLOT") if row.disabled else ""
		row.icon = _load_item_icon(item) if not id.is_empty() else null
		row.expand_icon = true
		row.add_theme_constant_override("icon_max_width", 54)
		row.add_theme_font_size_override("font_size", 20)
		var effective: Dictionary = preload("res://scripts/domain/item_progress.gd").effective_item(item, _spell_state.get("item_progress", {})) if not id.is_empty() else {}
		var status := " [" + tr("LOADOUT_WEAPON_EQUIPPED") + "]" if id == selected else (" [" + tr("LOADOUT_WEAPON_OTHER_SLOT") + "]" if row.disabled else "")
		row.text = _label_for_item(item, "None") + status if id.is_empty() else "%s%s\n%s\n%s" % [_label_for_item(item, "None"), status, _item_desc(item), _build_effects_text(effective.get("effects", {})).replace("\n", "  •  ")]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		MenuArt.button(row)
		row.pressed.connect(_choose_weapon.bind(id))
		_weapon_list.add_child(row)
	_weapon_overlay.show()

func _choose_weapon(id: String) -> void:
	if not is_instance_valid(_weapon_target):
		return
	var other := _idx_to_id(_items, dd_item2 if _weapon_target == dd_item1 else dd_item1)
	if not id.is_empty() and id == other:
		return
	_set_button_selection(_weapon_target, _items, id)
	_save_build_preferences()
	_weapon_overlay.hide()

func _on_equip_button_pressed(btn: Button) -> void:
	if btn == null:
		return
	if btn in [dd_item1, dd_item2]:
		_open_weapon_selector(btn)
		return
	var items = btn.get_meta("items")
	if items == null or items.size() == 0:
		return
	var sidx = btn.get_meta("selected_idx")
	if typeof(sidx) != TYPE_INT:
		sidx = int(sidx)
	var other: Button = dd_item2 if btn == dd_item1 else dd_item1 if btn == dd_item2 else null
	var other_id := _idx_to_id(_items, other) if other != null else ""
	for attempt in items.size():
		sidx = (sidx + 1) % items.size()
		var candidate: Variant = items[sidx]
		var candidate_id := str(candidate.get("id", "")) if candidate is Dictionary else str(candidate)
		if candidate_id.is_empty() or candidate_id != other_id:
			break
	btn.set_meta("selected_idx", sidx)
	btn.text = _label_for_item(items[sidx], "None")
	_refresh_build_slot_icon(btn)
	_refresh_build_warning()
	_save_build_preferences()
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
		var htex := _hom_texture(d2)
		var hcard := _make_card("homunculus", hid, hname, htex)
		hcard.set_meta("hom_id", hid)
		if grid_homunculi: grid_homunculi.add_child(hcard)
		_update_hom_card(hcard, d2)

	# Add bottom padding so entity labels aren't clipped.
	_add_grid_padding(grid_entities)

	if _entities.size() > 0:
		_current_entity_id = str(_entities[0].get("id",""))
	_current_homunculus_id = _legacy_hom_fallback()

	_update_selected_visuals()

func _make_card(p_kind: String, p_id: String, p_name: String, p_tex: Texture2D) -> Control:
	# Simple self-contained card to avoid theme/scene inconsistencies.
	var b: Button = HomTooltipButton.new() if p_kind == "homunculus" else Button.new()
	b.custom_minimum_size = Vector2(150, 150) if p_kind == "homunculus" else Vector2(170, 200)
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
	v.name = "CardContent"
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 12 if p_kind == "homunculus" else 24
	v.offset_bottom = -10 if p_kind == "homunculus" else -20
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	b.add_child(v)

	var tex_rect := TextureRect.new()
	tex_rect.name = "Portrait"
	tex_rect.custom_minimum_size = Vector2(85, 85) if p_kind == "homunculus" else Vector2(118, 118)
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
	lbl.name = "CardName"
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
		_pending_restored_hom = ""
		if not _is_combat_hom(p_id):
			_set_build_error(tr("HOM_CAPTURE_REQUIRED") if _hom_status(p_id) == "locked" else tr("HOM_STATUS_UNKNOWN") if _hom_status(p_id) == "unknown" else tr("LOADOUT_HOM_PENDING"))
			return
		_current_homunculus_id = p_id
	_update_selected_visuals()
	_refresh_details()
	_save_build_preferences()

func _update_selected_visuals() -> void:
	if grid_entities:
		for c in grid_entities.get_children():
			if c and c.has_method("set_selected"):
				c.call("set_selected", c.get("id") == _current_entity_id)
	_refresh_hom_cards()

func _localized_mode() -> String:
	if _dungeon_mode:
		return tr("LOADOUT_DUNGEON")
	if _hunt_mode:
		return tr("LOADOUT_HUNT")
	return tr("LOADOUT_MODE") % tr("LOADOUT_ATTACK" if _mode == "attack" else "LOADOUT_DEFENSE")

func _refresh_details() -> void:
	var ent := _find_by_id(_entities, _current_entity_id)
	if ent.is_empty() and _entities.size() > 0:
		_current_entity_id = str(_entities[0].get("id",""))
		ent = _find_by_id(_entities, _current_entity_id)
	if ent.is_empty():
		if lbl_name: lbl_name.text = "LOADOUT_SELECT_ENTITY"
		if lbl_mode: lbl_mode.text = _localized_mode()
		if lbl_homunculus: lbl_homunculus.text = tr("LOADOUT_HOMUNCULUS") % "—"
		if preview: preview.texture = null
		if _spell_button: _spell_button.show()
		return
	_refresh_spell_button()

	if lbl_name: lbl_name.text = str(ent.get("name", _current_entity_id))
	if lbl_mode: lbl_mode.text = _localized_mode()
	if lbl_homunculus:
		var hom0 := _find_by_id(_homunculi, _current_homunculus_id)
		var hname0 := str(hom0.get("name", _current_homunculus_id)) if typeof(hom0) == TYPE_DICTIONARY else _current_homunculus_id
		lbl_homunculus.text = tr("LOADOUT_HOMUNCULUS") % hname0
	if lbl_types:
		var kind := _type_for_entity(ent)
		lbl_types.text = tr("LOADOUT_TYPES") % GameLocalization.catalog("type", kind, "name", kind)
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
		hom_preview.texture = _hom_texture(hom)

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
	_save_build_preferences()

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
		if str(item.get("id", "")) == "":
			return tr("SPECIALIZATION_NONE_NAME")
		if item.has("name"):
			return GameLocalization.catalog("item", str(item.get("id", "")), "name", str(item.get("name", fallback)))
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
	if ent_name.find("igniter") != -1 or id.find("igniter") != -1 or id == "sulfur_01":
		return "Sulfur"
	if ent_name.find("quicksprite") != -1 or id.find("quicksprite") != -1:
		return "Mercury"
	if ent_name.find("corroder") != -1 or id.find("corroder") != -1 or id == "vitriol_01":
		return "Vitriol"
	if ent_name.find("arbiter") != -1 or id.find("arbiter") != -1 or id == "gold_01":
		return "Gold"
	if ent_name.find("bastion") != -1 or id == "sodium_01":
		return "Sodium"
	return "-"

func _lore_for_entity(ent: Dictionary) -> String:
	var ent_name := _clean_name(str(ent.get("name", ""))).to_lower()
	var id := str(ent.get("id", "")).to_lower()
	if ent_name.find("anomaly") != -1 or id.find("anomaly") != -1:
		return "A rift-born mind that hums with aether and rewrites the rules."
	if ent_name.find("igniter") != -1 or id.find("igniter") != -1 or id == "sulfur_01":
		return "Sulfur’s first spark, a burning oath that turns steel to ash."
	if ent_name.find("quicksprite") != -1 or id.find("quicksprite") != -1:
		return "Mercury given legs, a restless slip of lightning and mirth."
	if ent_name.find("corroder") != -1 or id.find("corroder") != -1 or id == "vitriol_01":
		return "Vitriol’s whisper made flesh, patient rust for proud blades."
	if ent_name.find("arbiter") != -1 or id.find("arbiter") != -1 or id == "gold_01":
		return "Gold’s decree incarnate, weighing souls with a silent scale."
	if ent_name.find("bastion") != -1 or id == "sodium_01":
		return "Salt-stone sentinel, unyielding to rot and rumor."
	return "An unknown force watches from the edges of the seal."

func _on_seal_attack() -> void:
	if ranked_queue != null:
		ranked_queue._select_practice()
	if btn_seal_defense != null:
		var notice := btn_seal_defense.get_node_or_null("ComingSoon") as Label
		if notice != null:
			notice.hide()
	var changed := _mode != "attack"
	_mode = "attack"
	# Visual feedback
	if btn_seal_attack:
		btn_seal_attack.button_pressed = true
		_pulse_button(btn_seal_attack)
	if btn_seal_defense:
		btn_seal_defense.button_pressed = false
	if lbl_mode:
		lbl_mode.text = _localized_mode()
	if changed:
		_refresh_details()
	_update_save_button_label()

func _on_seal_defense() -> void:
	if not _hunt_mode and not _dungeon_mode:
		if ranked_queue != null:
			if ranked_queue.selected:
				_on_seal_attack()
			else:
				ranked_queue._select()
		return
	var changed := _mode != "defense"
	_mode = "defense"
	# Visual feedback
	if btn_seal_attack:
		btn_seal_attack.button_pressed = false
	if btn_seal_defense:
		btn_seal_defense.button_pressed = true
		_pulse_button(btn_seal_defense)
	if lbl_mode:
		lbl_mode.text = _localized_mode()
	if changed:
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
	if ranked_queue != null and ranked_queue.selected:
		if _verified_preferences_identity().is_empty():
			ranked_queue.info.text = "Sign in before saving loadout"
			return
		if not _spell_pending_id.is_empty() or not _spell_synced:
			ranked_queue.info.text = "Wait for spell confirmation"
			return
		if _spell_backend == null:
			ranked_queue.info.text = "Server spell loadout unavailable"
			return
		for action in _spell_backend.get_pending_actions():
			if str(action.get("action_type", "")) == "SET_SPELL_LOADOUT":
				ranked_queue.info.text = "Wait for spell confirmation"
				return
		if _has_duplicate_build_items():
			ranked_queue.info.text = "Choose different weapons"
			return
		if not _save_seal("attack"):
			ranked_queue.info.text = "Could not save loadout"
			return
		ranked_queue.info.text = "Loadout saved — press READY"
		_update_save_button_label()
		return
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
	var path := BuildPreferences.seal_path(_verified_preferences_identity(), _mode)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_has_saved = false
	_update_save_button_label()

func _on_save_gui_input(ev: InputEvent) -> void:
	if ranked_queue != null and ranked_queue.selected:
		return
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
	if _expedition_preview: return
	if not _is_combat_hom(_current_homunculus_id):
		_set_build_error(tr("LOADOUT_HOM_PENDING"))
		return
	if _expedition_mode:
		_submit_expedition_loadout()
		return
	if ranked_queue != null and ranked_queue.selected:
		ranked_queue._join()
		return
	if _dungeon_mode:
		_submit_dungeon_loadout()
		return
	if _hunt_mode and not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty():
		_hunt_ready_requested = true
		_submit_hunt_loadout()
		return
	if _spell_pending_id != "":
		_set_build_error(tr("LOADOUT_WAIT_SPELLS"))
		return
	if not _spell_debug.unlock_all_buildings and _spell_backend != null and _spell_backend.token != "" and not _spell_synced:
		_set_build_error("Waiting for server spell loadouts.")
		return
	if _has_duplicate_build_items():
		_set_build_error(tr("LOADOUT_DUPLICATE_ITEM"))
		return
	_set_build_error("")
	_save_seal(_mode)
	if _hunt_mode:
		SceneRouter._hunt_loadout_active = false
		SceneRouter.go_to_combat()
		return
	if ranked_queue != null and not str(ConnectionGate.token).is_empty() and not ConnectionGate.debug_lab_navigation_allowed():
		ranked_queue._join(true)
		return
	SceneRouter.set_combat_seal_mode(_mode)
	if ResourceLoader.exists("res://scenes/Combat.tscn"):
		get_tree().change_scene_to_file("res://scenes/Combat.tscn")
	else:
		_on_ready()

func _submit_expedition_loadout() -> void:
	var owner := str(SceneRouter._expedition_context.get("player_id", ""))
	if _spell_backend == null or owner.is_empty() or _spell_backend._verified_player_id != owner or _spell_backend.token.is_empty() or not _spell_synced or _hom_identity != owner:
		_set_build_error(tr("EXPEDITION_ACCOUNT_REQUIRED"))
		return
	var first := _idx_to_id(_items, dd_item1)
	var second := _idx_to_id(_items, dd_item2)
	var spells := _equipped_spells("attack", _current_entity_id)
	if _current_entity_id.is_empty() or (not first.is_empty() and first == second):
		_set_build_error(tr("LOADOUT_CHOOSE_ENTITY_WEAPONS"))
		return
	if spells.size() != 4 or not SpellLoadout.valid(_reg, _current_entity_id, _spell_state.get("spell_progress", {}), spells):
		_set_build_error(tr("LOADOUT_CHOOSE_FOUR_SPELLS"))
		return
	var payload := {"client_action_id": _spell_backend._make_uuid(), "entity_id": _current_entity_id, "weapon_ids": [null if first.is_empty() else first, null if second.is_empty() else second], "homunculus_id": _current_homunculus_id, "spell_ids": spells.duplicate(), "mode": "attack"}
	_confirm_expedition_start(owner, payload)

func _confirm_expedition_start(owner: String, payload: Dictionary) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.name = "ExpeditionRiskConfirmation"
	confirm.title = tr("EXPEDITION_START")
	confirm.borderless = true
	confirm.transparent = true
	confirm.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	confirm.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	confirm.add_theme_stylebox_override("panel", MenuArt.frame("marco-horizontal-popup-grande.png", Vector4(62, 72, 62, 48)))
	confirm.dialog_text = tr("EXPEDITION_RISK_WARNING")
	confirm.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm.get_label().vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm.get_label().add_theme_color_override("font_color", Color.WHITE)
	confirm.confirmed.connect(func():
		if _spell_backend != null and _spell_backend._verified_player_id == owner and not get_node("/root/ConnectionGate").blocked():
			SceneRouter._expedition_context["pending_start"] = payload
			SceneRouter.go_to_expeditions())
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered(Vector2i(750, 300))

func _on_dungeon_identity(state: Dictionary) -> void:
	_update_hom_ownership(state, _dungeon_backend, str(SceneRouter._dungeon_context.get("player_id", "")))
	if _dungeon_backend == null or state.is_empty() or _dungeon_backend._verified_player_id != str(SceneRouter._dungeon_context.get("player_id", "")):
		_dungeon_recovered = false
		_dungeon_spell_progress = null
		_refresh_spell_button()
		return
	_spell_state = state.duplicate(true)
	if _dungeon_spell_progress is Dictionary: _spell_state["spell_progress"] = _dungeon_spell_progress.duplicate(true)
	_spell_synced = true
	_refresh_spell_button()
	if _dungeon_request.is_empty() and not _dungeon_recovered:
		_recover_dungeon()

func _recover_dungeon() -> void:
	var session: Variant = SceneRouter._dungeon_context.get("session")
	if _dungeon_backend == null or _dungeon_backend._verified_player_id != str(SceneRouter._dungeon_context.get("player_id", "")) or not session is Dictionary or str(session.get("run_id", "")) != str(SceneRouter._dungeon_context.get("run_id", "")) or not session.get("spell_progress") is Dictionary:
		_dungeon_recovered = false
		_set_build_error("Dungeon unavailable. Return to Sync Nexus.")
		return
	_dungeon_spell_progress = session.spell_progress.duplicate(true)
	_spell_state["spell_progress"] = _dungeon_spell_progress.duplicate(true)
	_dungeon_recovered = true
	_refresh_spell_button()
	_set_build_error("")
	_restore_build_preferences(_dungeon_backend._verified_player_id)

func _on_dungeon_loadout_response(request_id: String, ok: bool, data: Dictionary) -> void:
	if request_id.is_empty() or request_id != _dungeon_request:
		return
	_dungeon_request = ""
	if btn_play: btn_play.disabled = false
	if _dungeon_backend == null or _dungeon_backend._verified_player_id != str(SceneRouter._dungeon_context.get("player_id", "")):
		_dungeon_recovered = false
		_set_build_error("Account changed. Return to Sync Nexus.")
		return
	if _dungeon_kind == "loadout" and not ok:
		var message := str(data.get("error", ""))
		if message in ["Invalid or unsupported dungeon loadout.", "Invalid dungeon loadout.", "UNSUPPORTED_MECHANIC", "UNTRUSTED_SETUP"]:
			_dungeon_payload.clear()
			SceneRouter._dungeon_context.erase("pending_loadout")
			_set_build_error("The server rejected this loadout. Check your entity, homunculus, weapons and learned spells; verify the backend is up to date.")
		else:
			_dungeon_recovered = false
			_set_build_error("Dungeon ended. Return to Sync Nexus.")
		return
	var session: Variant = data
	if ok and _dungeon_kind == "session" and session is Dictionary and str(session.get("run_id", "")) == str(SceneRouter._dungeon_context.get("run_id", "")) and str(session.get("status", "")) in ["LOSS", "EXPIRED", "ABANDONED"]:
		var gate := get_node("/root/ConnectionGate")
		_dungeon_payload.clear()
		SceneRouter._dungeon_context.erase("pending_loadout")
		if gate.blocked(): gate.recovery_to_combat()
		else: SceneRouter.go_to_dungeon_combat()
		return
	if not ok or not session is Dictionary or str(session.get("run_id", "")) != str(SceneRouter._dungeon_context.get("run_id", "")) or (_dungeon_kind == "session" and str(session.get("status", "")) != "ACTIVE"):
		_dungeon_recovered = false
		_set_build_error("Dungeon unavailable. Retry or return to Sync Nexus.")
		return
	_dungeon_recovered = true
	if _dungeon_kind == "session" and not bool(session.get("combat_ready", false)):
		if not session.get("spell_progress") is Dictionary:
			_dungeon_recovered = false
			_set_build_error("Dungeon spell inventory unavailable. Retry.")
			return
		_dungeon_spell_progress = session.spell_progress.duplicate(true)
		_spell_state["spell_progress"] = _dungeon_spell_progress.duplicate(true)
		_refresh_spell_button()
	if bool(session.get("combat_ready", false)) and int(session.get("combat_revision", 0)) >= 1 and session.get("combat_state") is Dictionary and not session.combat_state.is_empty():
		if not _dungeon_payload.is_empty():
			var saved: Variant = session.get("loadout", {})
			for key in ["entity_id", "weapon_ids", "homunculus_id", "spell_ids", "mode"]:
				if not saved is Dictionary or saved.get(key) != _dungeon_payload.get(key):
					_dungeon_recovered = false
					_set_build_error("Recovered loadout differs. Return to Sync Nexus.")
					return
		_dungeon_payload.clear()
		SceneRouter._dungeon_context.erase("pending_loadout")
		SceneRouter._dungeon_context["session"] = session.duplicate(true)
		SceneRouter.go_to_dungeon_combat()
	else:
		_set_build_error("")
		if _dungeon_payload.is_empty() and not SceneRouter._dungeon_context.has("pending_loadout"):
			_restore_build_preferences(_dungeon_backend._verified_player_id)

func _submit_dungeon_loadout() -> void:
	if not _is_combat_hom(_current_homunculus_id) or (not _dungeon_payload.is_empty() and not _payload_hom_safe(_dungeon_payload)):
		_set_build_error(tr("LOADOUT_HOM_PENDING"))
		return
	if not _dungeon_request.is_empty():
		return
	if not _dungeon_recovered:
		_recover_dungeon()
		return
	if _dungeon_payload.is_empty():
		var first := _idx_to_id(_items, dd_item1)
		var second := _idx_to_id(_items, dd_item2)
		if _current_entity_id.is_empty() or (not first.is_empty() and first == second):
			_set_build_error(tr("LOADOUT_CHOOSE_ENTITY_WEAPONS"))
			return
		var spells: Array = _equipped_spells("attack", _current_entity_id)
		var unique := {}
		for id in spells:
			if not id is String or id.is_empty() or unique.has(id):
				_set_build_error(tr("LOADOUT_CHOOSE_FOUR_SPELLS"))
				return
			unique[id] = true
		if spells.size() != 4:
			_set_build_error(tr("LOADOUT_CHOOSE_FOUR_SPELLS"))
			return
		_dungeon_payload = {"run_id": str(SceneRouter._dungeon_context.get("run_id", "")), "client_action_id": _dungeon_backend._make_uuid(), "entity_id": _current_entity_id, "weapon_ids": [null if first.is_empty() else first, null if second.is_empty() else second], "homunculus_id": null if _current_homunculus_id.is_empty() else _current_homunculus_id, "spell_ids": spells.duplicate(), "mode": "attack"}
		SceneRouter._dungeon_context["pending_loadout"] = _dungeon_payload.duplicate(true)
	_dungeon_kind = "loadout"
	_dungeon_request = _dungeon_backend.request_api("POST", "/dungeon/loadout", _dungeon_payload.duplicate(true))
	if _dungeon_request.is_empty():
		_dungeon_recovered = false
		_recover_dungeon()
	else:
		if btn_play: btn_play.disabled = true
		_set_build_error("Confirming Dungeon loadout...")

func _submit_hunt_loadout() -> void:
	if not _is_combat_hom(_current_homunculus_id) or (not _hunt_payload.is_empty() and not _payload_hom_safe(_hunt_payload)):
		_set_build_error(tr("LOADOUT_HOM_PENDING"))
		return
	if _hunt_exit_requested or not _hunt_exit_request.is_empty() or not _hunt_submit_request.is_empty() or not _hunt_recovery_request.is_empty():
		return
	if not _hunt_recovered or _hunt_backend == null or _hunt_identity.is_empty() or _hunt_backend._verified_player_id != _hunt_identity or _hunt_backend.token.is_empty():
		_set_build_error("Recover the authenticated Boss Hunt before submitting a loadout.")
		if _hunt_backend != null and not _hunt_identity.is_empty() and _hunt_backend._verified_player_id == _hunt_identity and not _hunt_backend.token.is_empty():
			_recover_hunt_session()
		return
	var session: Variant = SceneRouter._solo_hunt_context.get("recovered_session", {})
	if not session is Dictionary or not _accept_hunt_session(session):
		_hunt_recovered = false
		_set_build_error("Boss Hunt session is unavailable. Return to World Zone.")
		return
	if int(session.get("combat_revision", 0)) >= 1:
		if not _hunt_payload.is_empty() or SceneRouter._solo_hunt_context.has("pending_loadout") or not session.get("combat_state") is Dictionary or not session.get("combat_loadout") is Dictionary or session.get("combat_state", {}).is_empty() or session.get("combat_loadout", {}).is_empty():
			_set_build_error("Combat session is not ready. Recover it and retry.")
			return
		_continue_hunt_ready()
		return
	if _hunt_payload.is_empty():
		if _has_duplicate_build_items() or _current_entity_id.is_empty():
			_hunt_ready_requested = false
			_set_build_error("Choose an entity and two different weapons.")
			return
		var spells: Array = _equipped_spells(_mode, _current_entity_id)
		var unique := {}
		for id in spells:
			if not id is String or id.is_empty() or unique.has(id):
				_hunt_ready_requested = false
				_set_build_error("Choose four distinct spells.")
				return
			unique[id] = true
		if spells.size() != 4:
			_hunt_ready_requested = false
			_set_build_error("Choose four distinct spells.")
			return
		var first := _idx_to_id(_items, dd_item1)
		var second := _idx_to_id(_items, dd_item2)
		_hunt_payload = {"session_id": str(session.session_id), "client_action_id": _hunt_backend._make_uuid(), "entity_id": _current_entity_id, "weapon_ids": [null if first.is_empty() else first, null if second.is_empty() else second], "homunculus_id": null if _current_homunculus_id.is_empty() else _current_homunculus_id, "spell_ids": spells.duplicate(), "mode": _mode}
		SceneRouter._solo_hunt_context["pending_loadout"] = _hunt_payload.duplicate(true)
	_hunt_submit_request = _hunt_backend.request_api("POST", "/world/boss-hunts/loadout", _hunt_payload.duplicate(true), false)
	if _hunt_submit_request.is_empty():
		_hunt_recovered = false
		_set_build_error("Request not sent; recover the session before retrying.")
		_recover_hunt_session()
		return
	if btn_play:
		btn_play.disabled = true
	_set_build_error("Confirming Boss Hunt loadout...")

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

func _verified_preferences_identity() -> String:
	var backend: BackendClient = _dungeon_backend if _dungeon_mode else (_hunt_backend if _hunt_mode else _spell_backend)
	if backend == null and not _hunt_mode and not _dungeon_mode and _spell_debug.unlock_all_buildings:
		var gate := get_node_or_null("/root/ConnectionGate")
		if gate != null and not gate.blocked() and not gate.token.is_empty():
			return str(gate.player_id)
	if backend == null or backend.token.is_empty() or backend._verified_player_id.is_empty():
		return ""
	if _hunt_mode and backend._verified_player_id != _hunt_identity:
		return ""
	if _dungeon_mode and backend._verified_player_id != str(SceneRouter._dungeon_context.get("player_id", "")):
		return ""
	return backend._verified_player_id

func _preferences_can_edit() -> bool:
	if _hunt_mode:
		var session: Dictionary = SceneRouter._solo_hunt_context.get("recovered_session", {})
		return _hunt_recovered and _hunt_payload.is_empty() and not SceneRouter._solo_hunt_context.has("pending_loadout") and int(session.get("combat_revision", 0)) == 0
	if _dungeon_mode:
		return _dungeon_recovered and _dungeon_payload.is_empty() and not SceneRouter._dungeon_context.has("pending_loadout") and not SceneRouter._dungeon_context.has("session")
	return true

func _restore_build_preferences(player_id: String) -> void:
	if not _cards_ready or not _preferences_can_edit() or player_id.is_empty() or player_id != _verified_preferences_identity() or (_preferences_ready and _preferences_owner == player_id):
		return
	if not _preferences_owner.is_empty() and _preferences_owner != player_id:
		_reset_build_defaults()
	var build := BuildPreferences.load_for(player_id)
	_preferences_owner = player_id
	_preferences_ready = true
	_update_save_button_label()
	if build.is_empty():
		return
	var entity_id := str(build.get("entity_id", ""))
	var hom_id := str(build.get("homunculus_id", ""))
	_pending_restored_hom = hom_id if _hom_status(hom_id) == "unknown" and not _find_by_id(_homunculi, hom_id).is_empty() else ""
	if not _find_by_id(_entities, entity_id).is_empty():
		_current_entity_id = entity_id
	_current_homunculus_id = hom_id if _is_combat_hom(hom_id) else _legacy_hom_fallback()
	for entry in [[dd_item1, _items, "equip_1"], [dd_item2, _items, "equip_2"], [dd_side1, _items, "side_1"], [dd_side2, _items, "side_2"], [dd_atktech, _atk_techs, "attack_tech"], [dd_deftech, _def_techs, "defense_tech"]]:
		if build.has(entry[2]):
			_set_button_selection(entry[0], entry[1], build[entry[2]])
	_ensure_distinct_weapons()
	_update_selected_visuals()
	_refresh_details()

func _reset_build_defaults() -> void:
	if not _entities.is_empty():
		_current_entity_id = str(_entities[0].get("id", ""))
	_current_homunculus_id = _legacy_hom_fallback()
	for entry in [[dd_item1, _items], [dd_item2, _items], [dd_side1, _items], [dd_side2, _items], [dd_atktech, _atk_techs], [dd_deftech, _def_techs]]:
		_set_button_selection(entry[0], entry[1], "")
	_ensure_distinct_weapons()
	_update_selected_visuals()
	_refresh_details()

func _save_build_preferences() -> void:
	if _expedition_preview: return
	if not _preferences_ready or not _preferences_can_edit() or _preferences_owner.is_empty() or _preferences_owner != _verified_preferences_identity():
		return
	var build := {"entity_id": _current_entity_id, "homunculus_id": _current_homunculus_id, "equip_1": _idx_to_id(_items, dd_item1), "equip_2": _idx_to_id(_items, dd_item2), "side_1": _idx_to_id(_items, dd_side1), "side_2": _idx_to_id(_items, dd_side2), "attack_tech": _idx_to_id(_atk_techs, dd_atktech), "defense_tech": _idx_to_id(_def_techs, dd_deftech)}
	if not BuildPreferences.save_for(_preferences_owner, build):
		_set_build_error("Could not save build preferences.")

func _save_seal(which: String) -> bool:
	if _expedition_preview: return false
	if not _is_combat_hom(_current_homunculus_id):
		_set_build_error(tr("LOADOUT_HOM_PENDING"))
		return false
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
	var identity := _verified_preferences_identity()
	if not identity.is_empty():
		payload["player_id"] = identity
	if _hunt_mode:
		SceneRouter._hunt_loadout = payload
		return true
	var path := BuildPreferences.seal_path(_verified_preferences_identity(), which)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	var save_error := f.get_error()
	f.close()
	if save_error != OK:
		return false
	print("Saved SEAL %s -> %s" % [which.to_upper(), path])
	_has_saved = true
	return true

func _load_seal(which: String) -> void:
	var path := BuildPreferences.seal_path(_verified_preferences_identity(), which)
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
	var identity := _verified_preferences_identity()
	if not identity.is_empty() and str(data.get("player_id", "")) != identity:
		return
	if data.has("entity_id"):
		_current_entity_id = str(data.get("entity_id", _current_entity_id))
	if data.has("homunculus_id"):
		var saved_hom := str(data.get("homunculus_id", ""))
		_current_homunculus_id = saved_hom if _is_combat_hom(saved_hom) else _legacy_hom_fallback()
	_refresh_details()

	_set_button_selection(dd_item1, _items, data.get("equip_1", ""))
	_set_button_selection(dd_item2, _items, data.get("equip_2", ""))
	_ensure_distinct_weapons()
	_set_button_selection(dd_side1, _items, data.get("side_1", ""))
	_set_button_selection(dd_side2, _items, data.get("side_2", ""))
	_set_button_selection(dd_atktech, _atk_techs, data.get("attack_tech", ""))
	_set_button_selection(dd_deftech, _def_techs, data.get("defense_tech", ""))
	_save_build_preferences()

func _ensure_distinct_weapons() -> void:
	if not _has_duplicate_build_items():
		return
	var selected := _idx_to_id(_items, dd_item1)
	for item in _items:
		var item_id := str(item.get("id", "")) if item is Dictionary else str(item)
		if not item_id.is_empty() and item_id != selected:
			_set_button_selection(dd_item2, _items, item_id)
			return

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
	_refresh_build_warning()

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
	tooltip_panel.set_meta("hovered_button", btn)
	var helper = preload("res://scripts/domain/item_progress.gd")
	var level: int = helper.level_for(str(item.get("id", "")), _spell_state.get("item_progress", {}))
	var effective: Dictionary = helper.effective_item(item, _spell_state.get("item_progress", {}))
	tooltip_label.text = tr("LOADOUT_WEAPON_LEVEL").replace("\\n", "\n") % [_label_for_item(item, "None"), level, _item_desc(item), _build_effects_text(effective.get("effects", {}))]
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
	var bounds := get_viewport_rect().size
	var tooltip_pos := gp + Vector2(0, btn.size.y + 6)
	if tooltip_pos.y + min_size.y > bounds.y:
		tooltip_pos.y = gp.y - min_size.y - 6
	tooltip_pos.x = clampf(tooltip_pos.x, 0.0, maxf(0.0, bounds.x - min_size.x))
	tooltip_pos.y = clampf(tooltip_pos.y, 0.0, maxf(0.0, bounds.y - min_size.y))
	tooltip_panel.global_position = tooltip_pos

func _build_effects_text(effects: Dictionary) -> String:
	var lines: Array[String] = []
	var labels := {
		"power_flat": "Power", "guard_flat": "Guard", "tempo_flat": "Tempo",
		"true_on_hit": "True damage on hit", "dot_true": "Corrosion damage on hit",
		"tempo_on_win": "Tempo after winning a round", "ward_pct": "Ward each round",
		"reflect_pct": "Damage reflected", "evasion_pct": "Evasion",
		"vuln_on_hit": "Vulnerability on hit", "disadvantage_reduction": "Type disadvantage reduction",
		"ignore_reflect_chance": "Chance to ignore reflection"
	}
	var percentages := ["ward_pct", "reflect_pct", "evasion_pct", "vuln_on_hit", "disadvantage_reduction", "ignore_reflect_chance"]
	for key in effects:
		var value: Variant = effects[key]
		if value is Array:
			if value.is_empty():
				continue
			value = value[0]
		if not (value is int or value is float) or not is_finite(float(value)):
			continue
		var amount := float(value) * (100.0 if str(key) in percentages else 1.0)
		var formatted := str(snappedf(amount, 0.01))
		if formatted.ends_with(".0"):
			formatted = formatted.trim_suffix(".0")
		lines.append("%s: %s%s" % [GameLocalization.catalog("loadout_stat", str(key), "name", str(labels.get(str(key), str(key).replace("_", " ").capitalize()))), formatted, "%" if str(key) in percentages else ""])
	return "\n".join(lines) if not lines.is_empty() else tr("LOADOUT_NO_ACTIVE_EFFECTS")

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
	return GameLocalization.catalog("item", str(item.get("id", "")), "desc", str(item.get("desc", "")))

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
	var path := BuildPreferences.seal_path(_verified_preferences_identity(), _mode)
	_has_saved = FileAccess.file_exists(path)
	if ranked_queue != null and ranked_queue.selected:
		btn_save.text = "Save Loadout"
		btn_save.get_node("ResetMark").visible = false
		return
	btn_save.text = "Load Seal" if _has_saved else "Save Seal"
	btn_save.get_node("ResetMark").visible = _has_saved

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

func _is_combat_hom(id: String) -> bool:
	if _reg == null or not _reg.get_homunculus_collection().has(id):
		return false
	return _hom_status(id) == "owned"

func _payload_hom_safe(payload: Dictionary) -> bool:
	var id := str(payload.get("homunculus_id", "")) if payload.get("homunculus_id") != null else ""
	return id.is_empty() or _is_combat_hom(id)

func _legacy_hom_fallback() -> String:
	if _reg == null or _reg.get_homunculi().is_empty(): return ""
	return str(_reg.get_homunculi().keys()[0])

func _hom_status(id: String) -> String:
	if _expedition_preview: return "owned"
	var synced := not _hom_identity.is_empty() and _hom_identity == _verified_preferences_identity()
	return HomProgress.collection_status(id, _reg != null and _reg.get_homunculi().has(id), _hom_progress, synced)

func _clear_hom_ownership() -> void:
	_hom_identity = ""
	_hom_progress = {}
	_pending_restored_hom = ""
	_revalidate_hom_selection()
	_refresh_hom_cards()

func _update_hom_ownership(state: Dictionary, backend: BackendClient, expected: String = "") -> void:
	var identity := str(state.get("player_id", ""))
	if backend == null or backend.token.is_empty() or identity.is_empty() or identity != backend._verified_player_id or (not expected.is_empty() and identity != expected):
		_clear_hom_ownership()
		return
	_hom_identity = identity
	var progress: Variant = state.get("homunculus_progress", {})
	_hom_progress = progress.duplicate(true) if progress is Dictionary else {}
	if not _pending_restored_hom.is_empty() and identity == _verified_preferences_identity():
		if _is_combat_hom(_pending_restored_hom):
			_current_homunculus_id = _pending_restored_hom
			_update_selected_visuals()
			_refresh_details()
		_pending_restored_hom = ""
	_revalidate_hom_selection()
	_refresh_hom_cards()

func _hom_texture(hom: Dictionary) -> Texture2D:
	if hom.has("preview_texture"):
		var path := str(hom.preview_texture)
		return load(path) if ResourceLoader.exists(path) else null
	return _load_preview_tex(str(hom.get("id", "")), "homunculus", str(hom.get("name", "")))

func _refresh_hom_cards() -> void:
	if not is_instance_valid(grid_homunculi): return
	for card in grid_homunculi.get_children():
		if card.has_meta("hom_id"):
			_update_hom_card(card, _find_by_id(_homunculi, str(card.get_meta("hom_id"))))

func _update_hom_card(card: Control, hom: Dictionary) -> void:
	var id := str(hom.get("id", ""))
	var portrait := card.get_node_or_null("CardContent/Portrait") as TextureRect
	var title := card.get_node_or_null("CardContent/CardName") as Label
	if portrait == null: return
	var status := _hom_status(id)
	var locked := status != "owned"
	portrait.modulate = Color(0.5, 0.5, 0.5, 1.0) if locked else Color.WHITE
	card.self_modulate = Color(0.5, 0.5, 0.5, 1.0) if locked else Color(1.35, 1.2, 0.8, 1.0) if id == _current_homunculus_id else Color.WHITE
	var overlay := card.get_node_or_null("HomLock")
	if overlay == null:
		var center := CenterContainer.new()
		center.name = "HomLock"
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var lock := LockIndicator.new()
		lock.custom_minimum_size = Vector2(20, 20)
		lock.scale = Vector2(1.7, 1.7)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(lock)
		overlay = center
	overlay.visible = locked
	var name_text := GameLocalization.catalog("homunculus", id, "name", str(hom.get("name", id)))
	if title: title.text = name_text
	var parts: Array[String] = [name_text]
	if hom.has("type"):
		parts.append(tr("HOM_TYPE") % GameLocalization.catalog("type", str(hom.type), "name", str(hom.type).capitalize()))
		parts.append(tr("INVENTORY_RARITY") % ("%d / 10" % int(hom.rarity)))
		parts.append(tr("HOM_PASSIVE") % HomProgress.passive_text(hom))
		if locked:
			parts.append(tr("HOM_CAPTURE_REQUIRED"))
			if status == "unknown": parts.append(tr("HOM_STATUS_UNKNOWN"))
		else:
			parts.append(tr("HOM_STATUS_OWNED"))
	card.tooltip_text = "\n".join(parts)

func _revalidate_hom_selection() -> void:
	if _cards_ready and not _current_homunculus_id.is_empty() and not _is_combat_hom(_current_homunculus_id):
		_current_homunculus_id = _legacy_hom_fallback()
		_update_selected_visuals()
		_refresh_details()

func _dungeon_exit_warning() -> void:
	get_node("/root/ConnectionGate").dungeon_exit_warning()

func forest_return_safe() -> bool:
	if _hunt_mode or _dungeon_mode or _expedition_mode or _expedition_preview or not _spell_pending_id.is_empty() or not is_instance_valid(ranked_queue):
		return false
	if ranked_queue.queued or ranked_queue.cancel_requested or not ranked_queue.request_id.is_empty():
		return false
	return ConnectionGate.debug_lab_navigation_allowed() or ranked_queue.forest_idle_verified

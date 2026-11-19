extends Control
class_name WorldZone

@export var backend_path: NodePath
@export var background_path: NodePath
@export var header_label_path: NodePath
@export var session_label_path: NodePath
@export var modifier_label_path: NodePath
@export var heat_label_path: NodePath
@export var enter_button_path: NodePath
@export var farm_count_path: NodePath
@export var farm_button_path: NodePath
@export var claim_button_path: NodePath
@export var error_label_path: NodePath
@export var back_button_path: NodePath
@export var zone_id_override: String = ""

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const WORLD_ART := {
	"zone_chaos": ["chaos_astral_alchemist", "chaos_astral_alchemist_variant", "chaos_astral_eagle", "chaos_cyber_warrior", "chaos_lion_warrior"],
	"zone_corrupted": ["corrupted_cocodragon", "corrupted_cybermantis", "corrupted_doctor", "corrupted_hipovenom", "corrupted_medusa", "corrupted_sphinx"],
	"zone_crystal": ["crystal_bear", "crystal_golem", "crystal_hydra", "crystal_mage", "crystal_sentinel", "crystal_wolf"]
}
const WORLD_BACKGROUNDS := {"zone_chaos": "bg1", "zone_corrupted": "bg2", "zone_crystal": "bg3"}
const TIER_COLORS := {"common": "65e47b", "mythic": "ffd65a", "rare": "6eb8ff", "epic": "ff9d5c", "legendary": "d697ff"}

var _backend: BackendClient = null
var _background: TextureRect = null
var _header_label: Label = null
var _session_label: Label = null
var _modifier_label: Label = null
var _heat_label: Label = null
var _enter_button: Button = null
var _farm_count: OptionButton = null
var _farm_button: Button = null
var _claim_button: Button = null
var _reroll_button: Button
var _reroll_request := ""
var _reroll_action := ""
var _reroll_owner := ""
var _reroll_restored := false
var _world_synced := false
var _world_requests: Dictionary = {}
const DEBUG_REROLL_PATH := "user://world_zone_debug_rerolls.json"
var _debug_reroll_until := 0
var _claim_request := ""
var _claim_action := ""
var _claim_owner := ""
var _error_label: Label = null
var _back_button: Button = null

var _catalog := AssetCatalog.new()
var _db := StaticDB.new()
var _debug := DebugFlags.new()

var _zone_id := ""
var _session_id := ""
var _world_state: Dictionary = {}
var _player_world: Dictionary = {}
var _bosses: Array = []
var _boss_picker: OptionButton
var _boss_portrait: TextureRect
var _boss_status: Label
var _boss_hp: ProgressBar
var _boss_open: Button
var _loot_label: Label
var _enter_confirm: ConfirmationDialog
var _auth_refresh_needed := false
var _gate_clock = preload("res://scripts/domain/world_gate_cooldown.gd").new()
var _gate_display_seconds := -2
var _world_sprite: TextureRect
var _world_name: RichTextLabel
var _world_companions: Array[TextureRect] = []
var _world_art_index := 0
var _world_art_order: Array = []
var _appearance_seed := 0
var _debug_rare_index := 0
const DEBUG_APPEARANCE_PATH := "user://world_zone_debug_appearances.json"
var _world_idle: Tween
var _world_modal: Control
var _world_stage: Control
var _preview_stage: Control
var _preview_tweens: Array[Tween] = []
var _preview_selection := ""
var _preview_selected_encounter: Dictionary = {}
var _preview_status: Label
var _debug_fight: Button
var _view_guardians: Button
var _nearby_debug_index := -1
var _debug_hunt_id := "hunt_common"
var _debug_rotation := 0
var _hunt_schedule: Array = []
var _display_hunts: Array = []
var _hunt_rotation := -1
var _hunt_selected: Dictionary = {}
var _map_displayed_boss: Dictionary = {}
var _hunt_progress: Dictionary = {}
var _hunt_progress_key := ""
var _hunt_progress_owner := ""
var _hunt_guardian_id := ""
var _guardian_request_key := ""
var _guardian_request_owner := ""
var _hunt_wants_schedule := false
var _hunt_wants_session := false
var _hunt_wants_guardians := false
var _hunt_pending_start_payload: Dictionary = {}
var _hunt_active: Dictionary = {}
var _hunt_session_checked := false
var _common_cooldown_until := 0
var _common_progress: Dictionary = {}
var _common_owner := ""
var _common_request_owner := ""
var _common_wants_refresh := false
var _common_picker: OptionButton
var _special_picker: OptionButton
var _actor_roster: Control
var _boss_view := false
var _return_encounter: Dictionary = {}
var _restart_zone: Button
var _restart_action := ""
var _hunt_active_owner := ""
var _hunt_requests: Dictionary = {}
var _hunt_action_id := ""
var _hunt_action_key := ""
var _hunt_action_owner := ""
var _hunt_fight: Button
var _hunt_boundary := 0
var _debug_visual: Dictionary = {}
var _central_visual: Dictionary = {}
var _global_event: Dictionary = {}
var _global_actor: Control
var _global_wants_refresh := false
var _global_request_owner := ""
var _global_poll_timer := 0.0
var _global_connection_lost := false

func _exit_tree() -> void:
	_clear_guardian_preview()
	if _world_idle != null:
		_world_idle.kill()
	_catalog.free()
	_db.free()
	_debug.free()

func _ready() -> void:
	_debug.reload()
	_resolve_nodes()
	_return_encounter = SceneRouter._world_encounter_return.duplicate(true)
	SceneRouter._world_encounter_return.clear()
	if str(_return_encounter.get("zone_id", "")) != _get_zone_id():
		_return_encounter.clear()
	if _debug.unlock_all_buildings:
		_debug_reroll_until = int(_load_debug_rerolls().get(_get_zone_id(), 0))
	_apply_background()
	_setup_zone_view()
	if _debug.unlock_all_buildings:
		_restore_debug_appearance()
	_setup_buttons()
	_enter_confirm = ConfirmationDialog.new()
	_enter_confirm.title = "Enter zone"
	_enter_confirm.confirmed.connect(_confirm_zone_entry)
	add_child(_enter_confirm)
	_setup_farm_options()
	_load_state()
	_request_world_state()
	_request_map_hunts()
	_request_global_boss()

func _process(_delta: float) -> void:
	if is_instance_valid(_world_modal) and _world_modal.visible and _hunt_selected.has("appearance_id"):
		_update_common_details()
	_global_poll_timer += _delta
	if _global_poll_timer >= 20.0:
		_request_global_boss()
	_update_reroll_button()
	var remaining := _gate_remaining()
	if remaining != _gate_display_seconds:
		_gate_display_seconds = remaining
		_update_labels()

func _resolve_nodes() -> void:
	_backend = get_node_or_null(backend_path) as BackendClient
	_background = get_node_or_null(background_path) as TextureRect
	_header_label = get_node_or_null(header_label_path) as Label
	_session_label = get_node_or_null(session_label_path) as Label
	_modifier_label = get_node_or_null(modifier_label_path) as Label
	_heat_label = get_node_or_null(heat_label_path) as Label
	_enter_button = get_node_or_null(enter_button_path) as Button
	_farm_count = get_node_or_null(farm_count_path) as OptionButton
	_farm_button = get_node_or_null(farm_button_path) as Button
	_claim_button = get_node_or_null(claim_button_path) as Button
	_error_label = get_node_or_null(error_label_path) as Label
	_back_button = get_node_or_null(back_button_path) as Button
	if _backend != null:
		_backend.api_completed.connect(_on_api_completed)
		_backend.state_updated.connect(_on_state_updated)
		_backend.auth_changed.connect(_on_auth_changed)

func _setup_zone_view() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.02, 0.025)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)
	var overlay := get_node_or_null("Overlay") as PanelContainer
	if overlay != null:
		overlay.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 10
		for control in overlay.find_children("*", "Control", true, false):
			if not control is BaseButton and not control is OptionButton:
				control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var root := get_node_or_null("Overlay/Margin/RootVBox") as VBoxContainer
	if root != null:
		for node in root.find_children("*", "Label", true, false):
			var label := node as Label
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 5)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if _header_label != null:
			_header_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_loot_label = Label.new()
		_loot_label.add_theme_color_override("font_color", Color.WHITE)
		_loot_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_loot_label.add_theme_constant_override("outline_size", 5)
		_loot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(_loot_label)
		root.move_child(_loot_label, 4)
	if _back_button != null:
		_back_button.set("target", "world_gate")
		_back_button.reparent(self)
		_back_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_back_button.offset_left = -170
		_back_button.offset_right = -30
		_back_button.offset_top = 28
		_back_button.offset_bottom = 70
		_back_button.z_index = 5
		MenuArt.button(_back_button)
	for legacy in [_header_label, _session_label, _modifier_label, _heat_label, _enter_button, _farm_count, _farm_button]:
		if legacy != null:
			legacy.hide()
	var actions := get_node_or_null("Overlay/Margin/RootVBox/Buttons") as HBoxContainer
	if actions != null:
		_reroll_button = Button.new()
		_reroll_button.name = "RerollButton"
		_reroll_button.text = "WORLD_REROLL"
		_reroll_button.custom_minimum_size = Vector2(130, 42)
		_reroll_button.pressed.connect(_reroll_world_art)
		actions.add_child(_reroll_button)
		actions.move_child(_reroll_button, 0)
		MenuArt.button(_reroll_button)
		_reroll_button.add_theme_stylebox_override("disabled", _reroll_button.get_theme_stylebox("normal"))
	if _enter_button != null:
		_enter_button.text = "WORLD_ENTER_ZONE"
	if _farm_button != null:
		_farm_button.text = "WORLD_EXPLORE"
	if _claim_button != null:
		_claim_button.text = "WORLD_CLAIM_LOOT"
	for button in [_enter_button, _farm_button, _claim_button]:
		if button != null:
			button.custom_minimum_size = Vector2(130, 42)
			MenuArt.button(button)
	_setup_world_art()
	var roster := VBoxContainer.new()
	roster.name = "EncounterNavigation"
	roster.position = Vector2(24, 24)
	roster.custom_minimum_size = Vector2(260, 0)
	add_child(roster)
	var commons_button := Button.new()
	commons_button.text = "Common Hunt"
	commons_button.custom_minimum_size = Vector2(260, 58)
	MenuArt.button(commons_button)
	commons_button.pressed.connect(func(): _set_boss_view(false))
	roster.add_child(commons_button)
	var hunts_button := Button.new()
	hunts_button.text = "Ancient Hunt"
	hunts_button.custom_minimum_size = Vector2(260, 58)
	MenuArt.button(hunts_button)
	hunts_button.pressed.connect(func(): _set_boss_view(true))
	roster.add_child(hunts_button)
	_restart_zone = Button.new()
	_restart_zone.text = "Restart Zone"
	_restart_zone.visible = false
	_restart_zone.pressed.connect(_restart_common_zone)
	roster.add_child(_restart_zone)
	_refresh_common_picker()
	var panel := PanelContainer.new()
	panel.name = "WorldBossPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -330
	panel.offset_right = -30
	panel.offset_top = 125
	panel.offset_bottom = 330
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.07, 0.9)
	style.border_color = Color(0.58, 0.5, 0.3, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	_preview_status = Label.new()
	_preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status.visible = false
	content.add_child(_preview_status)
	var title := Label.new()
	title.name = "EncounterTitle"
	title.text = "WORLD_ENCOUNTER"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	_boss_picker = OptionButton.new()
	_boss_picker.visible = false
	_boss_picker.disabled = true
	content.add_child(_boss_picker)
	_boss_portrait = TextureRect.new()
	_boss_portrait.custom_minimum_size = Vector2(0, 115)
	_boss_portrait.visible = false
	_boss_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_boss_portrait)
	_boss_status = Label.new()
	_boss_status.text = ""
	_boss_status.visible = false
	_boss_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_boss_status)
	_boss_hp = ProgressBar.new()
	_boss_hp.show_percentage = false
	_boss_hp.visible = false
	content.add_child(_boss_hp)
	_boss_open = Button.new()
	_boss_open.visible = false
	_boss_open.text = "WORLD_BOSS_OPEN"
	_boss_open.disabled = true
	_boss_open.custom_minimum_size.y = 42
	MenuArt.button(_boss_open)
	content.add_child(_boss_open)
	_hunt_fight = Button.new()
	_set_hunt_button_text("HUNT_PREVIEW_FIGHT")
	_hunt_fight.visible = false
	_hunt_fight.pressed.connect(_start_map_hunt)
	MenuArt.button(_hunt_fight)
	content.add_child(_hunt_fight)
	_view_guardians = Button.new()
	_view_guardians.text = "HUNT_VIEW_GUARDIANS"
	_view_guardians.visible = false
	_view_guardians.pressed.connect(_show_selected_guardians)
	MenuArt.button(_view_guardians)
	content.add_child(_view_guardians)
	_debug_fight = Button.new()
	_debug_fight.text = "HUNT_DEBUG_FIGHT"
	_debug_fight.visible = _debug.unlock_all_buildings
	_debug_fight.pressed.connect(_start_debug_hunt)
	MenuArt.button(_debug_fight)
	content.add_child(_debug_fight)
	panel.visible = false
	_world_modal = Control.new()
	_world_modal.name = "EncounterModal"
	_world_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_world_modal.visible = false
	add_child(_world_modal)
	panel.reparent(_world_modal)
	panel.visible = true
	var close := Button.new()
	close.name = "CloseEncounter"
	close.text = "UI_CLOSE"
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(func(): _world_modal.visible = false)
	content.add_child(close)
	MenuArt.button(close)

func _setup_world_art() -> void:
	var stage := Control.new()
	_world_stage = stage
	stage.name = "WorldArt"
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_world_sprite = TextureRect.new()
	_world_sprite.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_world_sprite.anchor_top = 0.79
	_world_sprite.anchor_bottom = 0.79
	_world_sprite.offset_left = -115
	_world_sprite.offset_right = 115
	_world_sprite.offset_top = -335
	_world_sprite.offset_bottom = -110
	_world_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_world_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_world_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	_world_sprite.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_debug_visual = _central_visual.duplicate(true)
			_debug_hunt_id = "hunt_common"
			_show_common_details())
	stage.add_child(_world_sprite)
	for x in [0.32, 0.68]:
		var companion := TextureRect.new()
		companion.anchor_left = x
		companion.anchor_right = x
		companion.anchor_top = 0.79
		companion.anchor_bottom = 0.79
		companion.offset_left = -80
		companion.offset_right = 80
		companion.offset_top = -270
		companion.offset_bottom = -110
		companion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		companion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		companion.mouse_filter = Control.MOUSE_FILTER_STOP
		companion.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_debug_hunt_id = "hunt_common"
				_debug_visual = {"id": str(companion.get_meta("appearance_id", "")), "tier": "common", "texture": str(companion.get_meta("appearance_path", "")), "name": str(companion.get_meta("appearance_name", "Common"))}
				_show_common_details())
		stage.add_child(companion)
		var companion_name := RichTextLabel.new()
		companion_name.name = "EncounterName"
		companion_name.set_anchors_preset(Control.PRESET_TOP_WIDE)
		companion_name.offset_left = -35
		companion_name.offset_right = 35
		companion_name.offset_top = -38
		companion_name.offset_bottom = -4
		companion_name.bbcode_enabled = true
		companion_name.fit_content = true
		companion_name.scroll_active = false
		companion_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		companion_name.add_theme_font_size_override("normal_font_size", 18)
		companion_name.add_theme_constant_override("outline_size", 5)
		companion_name.add_theme_color_override("font_outline_color", Color.BLACK)
		companion.add_child(companion_name)
		_world_companions.append(companion)
	var name_panel := PanelContainer.new()
	name_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	name_panel.anchor_top = 0.79
	name_panel.anchor_bottom = 0.79
	name_panel.offset_left = -165
	name_panel.offset_right = 165
	name_panel.offset_top = -385
	name_panel.offset_bottom = -345
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	stage.add_child(name_panel)
	_world_name = RichTextLabel.new()
	_world_name.name = "WorldTitle"
	_world_name.bbcode_enabled = true
	_world_name.fit_content = true
	_world_name.scroll_active = false
	_world_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_name.add_theme_color_override("default_color", Color.WHITE)
	_world_name.add_theme_font_size_override("bold_font_size", 22)
	var bold_font := SystemFont.new()
	bold_font.font_names = PackedStringArray(["Arial"])
	bold_font.font_weight = 700
	_world_name.add_theme_font_override("bold_font", bold_font)
	name_panel.add_child(_world_name)

	_change_world_art(0)
	for child in stage.get_children():
		child.visible = false
	_actor_roster = Control.new()
	_actor_roster.name = "ActorRoster"
	_actor_roster.set_anchors_preset(Control.PRESET_FULL_RECT)
	_actor_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_actor_roster)
	_render_actor_roster()

func _set_boss_view(value: bool) -> void:
	_boss_view = value
	_clear_guardian_preview()
	_world_modal.visible = false
	_render_actor_roster()

func _render_actor_roster() -> void:
	if not is_instance_valid(_actor_roster):
		return
	for child in _actor_roster.get_children():
		_actor_roster.remove_child(child)
		child.queue_free()
	var entries: Array = []
	if _boss_view:
		for boss in _hunt_schedule:
			if str(boss.get("tier", "")) != "common":
				entries.append(boss)
	else:
		entries = _world_art_order if not _world_art_order.is_empty() else WORLD_ART.get(_get_zone_id(), [])
	var columns := 2 if _boss_view else 3
	for i in entries.size():
		var item = entries[i]
		var id := str(item.get("id", "")) if _boss_view else str(item)
		var display := str(item.get("name", "Boss")) if _boss_view else _common_display_name(id, _get_zone_id())
		var texture: Texture2D
		if _boss_view:
			var texture_id := str(item.get("display_texture_id", item.get("texture_id", "")))
			if _catalog.has(texture_id):
				texture = _catalog.get_tex(texture_id)
			elif ResourceLoader.exists(texture_id):
				texture = load(texture_id) as Texture2D
		else:
			texture = load("res://assets/lab/bosses/%s_zone_common/%s.png" % [_get_zone_id().trim_prefix("zone_"), id]) as Texture2D
		var actor := TextureButton.new()
		actor.name = "Roster_" + id
		actor.set_meta("appearance_id", id)
		actor.texture_normal = texture
		actor.ignore_texture_size = true
		actor.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var x := (0.43 + 0.28 * (i % columns)) if _boss_view else (0.36 + 0.20 * (i % columns))
		var y := 0.37 + 0.26 * floori(float(i) / columns)
		actor.anchor_left = x
		actor.anchor_right = x
		actor.anchor_top = y
		actor.anchor_bottom = y
		actor.offset_left = -75
		actor.offset_right = 75
		actor.offset_top = -65
		actor.offset_bottom = 65
		_actor_roster.add_child(actor)
		var label := Label.new()
		label.text = display + (" ? Defeated" if not _boss_view and _common_defeated(id) else "")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		label.offset_left = -20
		label.offset_right = 20
		label.offset_top = -38
		label.offset_bottom = -2
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		actor.add_child(label)
		if _boss_view:
			var boss: Dictionary = item
			actor.pressed.connect(func():
				_show_map_hunt(boss)
				_select_nearby_hunt(boss))
		else:
			actor.pressed.connect(func():
				_debug_visual = {"id": id, "tier": "common", "texture": "res://assets/lab/bosses/%s_zone_common/%s.png" % [_get_zone_id().trim_prefix("zone_"), id], "name": display}
				_show_common_details())

# Isolated presentation only: no selection from this fixture authorizes a fight.
func show_guardian_preview(main: Dictionary, guardians: Array) -> void:
	_clear_guardian_preview()
	_world_stage.visible = false
	if _world_idle != null and _world_idle.is_valid():
		_world_idle.pause()
	_preview_stage = Control.new()
	_preview_stage.name = "GuardianPreview"
	_preview_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview_stage)
	if _world_modal != null:
		move_child(_world_modal, get_child_count() - 1)
	var remaining: Array = []
	for guardian in guardians:
		if guardian is Dictionary and not guardian.get("defeated", false):
			remaining.append(guardian)
	var required: PackedStringArray = []
	for guardian in remaining:
		required.append(str(guardian.get("name", guardian.get("id", "Guardian"))))
	_add_preview_actor(main, 0.55, 0.52, true, required)
	var count := mini(remaining.size(), 5)
	for i in count:
		var x := 0.55 if count == 1 else 0.30 + 0.50 * float(i) / float(count - 1)
		_add_preview_actor(remaining[i], x, 0.76, false, PackedStringArray())

func _add_preview_actor(entry: Dictionary, x: float, ground: float, main: bool, required: PackedStringArray) -> void:
	var texture: Texture2D = null
	var texture_id := str(entry.get("texture_id", ""))
	if texture_id.begins_with("res://assets/lab/bosses/") and texture_id.ends_with(".png") and not ".." in texture_id and not "\\" in texture_id and ResourceLoader.exists(texture_id):
		texture = load(texture_id) as Texture2D
	elif _catalog.has(texture_id):
		texture = _catalog.get_tex(texture_id)
	if texture == null:
		return
	var actor := Control.new()
	actor.name = "Actor_" + str(entry.get("id", "unknown"))
	actor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	actor.anchor_left = x
	actor.anchor_right = x
	actor.anchor_top = ground
	actor.anchor_bottom = ground
	var width := 200.0 if main else 140.0
	var height := 190.0 if main else 135.0
	actor.offset_left = -width / 2
	actor.offset_right = width / 2
	actor.offset_top = -height
	actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_stage.add_child(actor)
	var sprite := TextureRect.new()
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture = texture
	sprite.pivot_offset = Vector2(width / 2, height)
	sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	actor.add_child(sprite)
	var title := RichTextLabel.new()
	title.name = "ActorTitle"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = -36
	title.offset_right = 36
	title.offset_top = -42
	title.offset_bottom = -4
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_size_override("normal_font_size", 18)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	var tier := str(entry.get("tier", "common")).to_lower()
	title.text = "[center][color=#%s][lb]%s[rb][/color] %s%s[/center]" % [TIER_COLORS.get(tier, TIER_COLORS["common"]), tier.capitalize(), "🔒 " if main and not required.is_empty() else "", str(entry.get("name", "Boss"))]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.add_child(title)
	var actor_id := str(entry.get("id", ""))
	var select_actor := func():
			_view_guardians.visible = false
			_boss_portrait.texture = texture
			_boss_portrait.visible = true
			if not _map_displayed_boss.is_empty():
				_hunt_selected = _map_displayed_boss.duplicate(true)
			_preview_selection = actor_id
			_debug_hunt_id = "hunt_" + str(entry.get("tier", "common"))
			_debug_visual = {"id": texture_id.get_file().get_basename() if texture_id.begins_with("res://") else actor_id, "tier": str(entry.get("tier", "common")), "texture": texture_id, "name": str(entry.get("name", "Boss")), "guardian": not main, "parent_index": _debug_rotation, "encounter_id": actor_id}
			_preview_selected_encounter = {"id": actor_id, "texture_id": texture_id, "zone_id": _get_zone_id(), "preview": true}
			var online_guardian := str(entry.get("guardian_id", ""))
			var real_hunt := not _hunt_selected.is_empty() and (actor_id == str(_hunt_selected.get("id", "")) or not online_guardian.is_empty())
			if real_hunt:
				_hunt_guardian_id = online_guardian
			_preview_status.text = ("Boss Hunt: %s\nUnverified preview: no rewards." % str(entry.get("name", actor_id))) if real_hunt else ("Unverified debug preview: %s\n%s" % [str(entry.get("name", actor_id)), "Locked: " + ", ".join(required) if main and not required.is_empty() else "No rewards or persistent victories."])
			_preview_status.visible = true
			_boss_picker.visible = false
			_boss_hp.visible = false
			_boss_status.visible = false
			_boss_open.visible = false
			_hunt_fight.visible = real_hunt
			_debug_fight.visible = _debug.unlock_all_buildings
			_debug_fight.disabled = main and not required.is_empty()
			if real_hunt:
				var active := _active_hunt_matches(online_guardian)
				var verified := _hunt_progress_key == _guardian_key() and _backend != null and _hunt_progress_owner == _backend._verified_player_id and not _hunt_progress_owner.is_empty()
				var unlocked := not online_guardian.is_empty() or bool(_hunt_progress.get("boss_unlocked", false))
				if not verified:
					call_deferred("_request_guardian_progress")
				_hunt_fight.disabled = not verified or _backend.token.is_empty() or (not active and (not unlocked or (online_guardian.is_empty() and not bool(_hunt_selected.get("available", false)))))
				var reason := "" if not _hunt_fight.disabled else ("Progress unavailable; retry." if not verified else ("Defeat all guardians first." if not unlocked else "Special boss is outside its rotation window."))
				_preview_status.text = "%s\n%s\nGuardians: %d/%d defeated%s" % [str(entry.get("name", "Boss")), "Special Boss" if online_guardian.is_empty() else "Guardian of " + str(_hunt_selected.get("name", "Boss")) + " — " + tier.capitalize(), int(_hunt_progress.get("defeated_count", 0)), int(_hunt_progress.get("total_count", 0)), "\n" + reason if not reason.is_empty() else ""]
				_set_hunt_button_text("HUNT_RESUME" if active else "HUNT_FIGHT")
				_view_guardians.visible = main and verified and not unlocked and not active
			_world_modal.visible = true
			call_deferred("_fit_encounter_card")
	actor.set_meta("select_actor", select_actor)
	sprite.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select_actor.call())
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.01, 1.01), 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(1.0)
	_preview_tweens.append(tween)

func _open_main_preview() -> void:
	if not is_instance_valid(_preview_stage) or _preview_stage.get_child_count() == 0:
		return
	var actor := _preview_stage.get_child(0)
	if actor.has_meta("select_actor"):
		var select_actor: Callable = actor.get_meta("select_actor")
		select_actor.call()

func _fit_encounter_card() -> void:
	if not is_instance_valid(_world_modal):
		return
	var panel := _world_modal.get_node_or_null("WorldBossPanel") as Control
	if panel == null:
		return
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -330
	panel.offset_right = -30
	panel.offset_top = 125
	panel.offset_bottom = 390

func _clear_guardian_preview() -> void:
	_map_displayed_boss.clear()
	if is_instance_valid(_view_guardians):
		_view_guardians.visible = false
	_preview_selected_encounter.clear()
	_preview_selection = ""
	for tween in _preview_tweens:
		if tween.is_valid():
			tween.kill()
	_preview_tweens.clear()
	if is_instance_valid(_preview_stage):
		_preview_stage.queue_free()
		_preview_stage = null
	if is_instance_valid(_world_stage):
		_world_stage.visible = true
		if _world_idle != null and _world_idle.is_valid():
			_world_idle.play()
	if is_instance_valid(_preview_status):
		_preview_status.visible = false
		_hunt_fight.visible = false
		_boss_picker.visible = false
		_boss_status.visible = false
		_boss_open.visible = false

func _show_common_details() -> void:
	_hunt_wants_guardians = false
	_hunt_selected = {"id": "hunt_common", "appearance_id": str(_debug_visual.get("id", ""))}
	_hunt_guardian_id = ""
	var texture_path := str(_debug_visual.get("texture", ""))
	_boss_portrait.texture = load(texture_path) as Texture2D if texture_path.begins_with("res://assets/lab/bosses/") and not ".." in texture_path and ResourceLoader.exists(texture_path) else null
	_boss_portrait.visible = _boss_portrait.texture != null
	_view_guardians.visible = false
	_preview_status.visible = true
	_boss_picker.visible = false
	_boss_hp.visible = false
	_boss_status.visible = false
	_boss_open.visible = false
	_hunt_fight.visible = true
	_debug_fight.visible = false
	_world_modal.visible = true
	_update_common_details()

func _update_common_details() -> void:
	var active := _active_hunt_matches("")
	var reason := ""
	if _backend == null or _backend.token.is_empty() or _backend._verified_player_id.is_empty() or _global_connection_lost:
		reason = "Offline. Connect and sign in to fight."
	elif _hunt_requests.values().has("start") or not _hunt_pending_start_payload.is_empty():
		reason = "Starting encounter..."
	elif not _hunt_session_checked or _hunt_rotation < 0:
		reason = "Checking hunt availability..."
	elif _common_owner != _backend._verified_player_id or _common_progress.is_empty():
		reason = "Checking common progression..."
	elif _common_defeated(str(_hunt_selected.get("appearance_id", ""))):
		reason = "Defeated in this zone cycle."
	_hunt_fight.disabled = not reason.is_empty()
	_set_hunt_button_text("HUNT_RESUME" if active else "HUNT_FIGHT")
	_preview_status.text = "%s\nCommon%s" % [str(_debug_visual.get("name", "Common")), "\n" + reason if not reason.is_empty() else ""]

func _common_defeated(id: String) -> bool:
	for entry in _common_progress.get("commons", []):
		if str(entry.get("appearance_id", "")) == id:
			return bool(entry.get("defeated", false))
	return false

func _refresh_common_picker() -> void:
	if is_instance_valid(_restart_zone):
		_restart_zone.visible = bool(_common_progress.get("complete", false))
	_render_actor_roster()

func _select_common_roster(index: int) -> void:
	var entries: Array = WORLD_ART.get(_get_zone_id(), [])
	if index < 1 or index > entries.size():
		return
	_clear_guardian_preview()
	var id: String = entries[index - 1]
	_debug_visual = {"id": id, "tier": "common", "texture": "res://assets/lab/bosses/%s_zone_common/%s.png" % [_get_zone_id().trim_prefix("zone_"), id], "name": _common_display_name(id, _get_zone_id())}
	_show_common_details()

func _select_special_roster(index: int) -> void:
	if index < 1:
		return
	var specials := _hunt_schedule.filter(func(boss): return str(boss.get("tier", "")) != "common")
	if index <= specials.size():
		_show_map_hunt(specials[index - 1])
		_select_nearby_hunt(specials[index - 1])

func _restore_encounter_view() -> void:
	if _return_encounter.is_empty() or _backend == null or _backend._verified_player_id.is_empty():
		return
	if str(_return_encounter.get("player_id", "")) != _backend._verified_player_id:
		_return_encounter.clear()
		return
	match str(_return_encounter.get("category", "")):
		"special":
			if _hunt_schedule.is_empty():
				return
			var hunt_id := str(_return_encounter.get("hunt_id", ""))
			_return_encounter.clear()
			for boss in _hunt_schedule:
				if str(boss.get("id", "")) == hunt_id and str(boss.get("tier", "")) != "common":
					_show_map_hunt(boss)
					return
		"global":
			if _global_event.is_empty():
				return
			var event_id := str(_return_encounter.get("event_id", ""))
			_return_encounter.clear()
			if str(_global_event.get("event_id", "")) == event_id and str(_global_event.get("status", "")) == "ACTIVE":
				_open_global_boss()
		_:
			_return_encounter.clear()

func _restart_common_zone() -> void:
	if _backend == null or _backend.token.is_empty() or not bool(_common_progress.get("complete", false)):
		return
	if _restart_action.is_empty():
		_restart_action = _backend._make_uuid()
	var request := _backend.request_api("POST", "/world/boss-hunts/commons/restart", {"zone_id": _get_zone_id(), "client_action_id": _restart_action}, false)
	if not request.is_empty():
		_hunt_requests[request] = "restart_commons"
		_restart_zone.disabled = true

func _common_display_name(id: String, zone: String) -> String:
	if id == "chaos_astral_alchemist_variant":
		return "Astral Alchemist Ascendant"
	return id.trim_prefix(zone.trim_prefix("zone_") + "_").replace("_", " ").capitalize()

func _change_world_art(direction: int) -> void:
	var zone := _get_zone_id()
	var entries: Array = _world_art_order if not _world_art_order.is_empty() else WORLD_ART.get(zone, [])
	if entries.is_empty():
		return
	_world_art_index = posmod(_world_art_index + direction, entries.size())
	var id: String = entries[_world_art_index]
	var path := "res://assets/lab/bosses/%s_common/%s.png" % [zone.trim_prefix("zone_") + "_zone", id]
	_world_sprite.texture = load(path) as Texture2D
	for i in _world_companions.size():
		var other_id: String = entries[(_world_art_index + i + 1) % entries.size()]
		var other_path := "res://assets/lab/bosses/%s_zone_common/%s.png" % [zone.trim_prefix("zone_"), other_id]
		_world_companions[i].texture = load(other_path) as Texture2D
		_world_companions[i].set_meta("appearance_id", other_id)
		_world_companions[i].set_meta("appearance_path", other_path)
		var other_name := _common_display_name(other_id, zone)
		_world_companions[i].set_meta("appearance_name", other_name)
		var companion_name := _world_companions[i].get_node("EncounterName") as RichTextLabel
		companion_name.text = "[center][color=#%s][lb]Common[rb][/color] %s[/center]" % [TIER_COLORS["common"], other_name]
	var display_name := _common_display_name(id, zone)
	_debug_hunt_id = "hunt_common"
	_central_visual = {"id": id, "tier": "common", "texture": path, "name": display_name}
	_debug_visual = _central_visual.duplicate(true)
	_world_name.text = "[center][b][color=#%s][lb]Common[rb][/color] %s[/b][/center]" % [TIER_COLORS["common"], display_name]
	if _world_idle != null:
		_world_idle.kill()
	_world_sprite.scale = Vector2.ONE
	_world_sprite.pivot_offset = Vector2(115, 225)
	_world_idle = create_tween().set_loops()
	_world_idle.tween_property(_world_sprite, "scale", Vector2(1.015, 1.015), 1.2).set_trans(Tween.TRANS_SINE)
	_world_idle.tween_property(_world_sprite, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)
	_world_idle.tween_interval(1.0)

func _reroll_world_art() -> void:
	if _debug.unlock_all_buildings:
		if _reroll_remaining() > 0:
			return
		var deadlines := _load_debug_rerolls()
		deadlines[_get_zone_id()] = int(Time.get_unix_time_from_system() * 1000) + 60000
		var file := FileAccess.open(DEBUG_REROLL_PATH, FileAccess.WRITE)
		if file == null:
			_set_error("Unable to save reroll cooldown.")
			return
		file.store_string(JSON.stringify(deadlines))
		var save_error := file.get_error()
		file.close()
		if save_error != OK:
			_set_error("Unable to save reroll cooldown.")
			return
		_debug_reroll_until = int(deadlines[_get_zone_id()])
		var appearance := _load_debug_appearances()
		var random := RandomNumberGenerator.new()
		random.randomize()
		var new_seed := random.randi_range(1, 2147483647)
		while new_seed == int(appearance.get(_get_zone_id(), 0)):
			new_seed = random.randi_range(1, 2147483647)
		appearance[_get_zone_id()] = new_seed
		var appearance_file := FileAccess.open(DEBUG_APPEARANCE_PATH, FileAccess.WRITE)
		if appearance_file == null:
			_set_error("Unable to save encounter appearance.")
			return
		appearance_file.store_string(JSON.stringify(appearance))
		var appearance_error := appearance_file.get_error()
		appearance_file.close()
		if appearance_error != OK:
			_set_error("Unable to save encounter appearance.")
			return
		_appearance_seed = new_seed
		_apply_reroll()
		return
	if _backend == null or _backend.token.is_empty() or _backend._verified_player_id.is_empty() or not _reroll_request.is_empty() or _reroll_remaining() != 0:
		return
	if _reroll_action.is_empty():
		_reroll_action = _make_client_id()
	_reroll_owner = _backend._verified_player_id
	_reroll_request = _backend.request_api("POST", "/world/reroll", {"client_action_id": _reroll_action, "zone_id": _get_zone_id()}, true)
	if _reroll_request.is_empty():
		_set_error("Connection busy. Retry reroll.")

func _load_debug_rerolls() -> Dictionary:
	if not FileAccess.file_exists(DEBUG_REROLL_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEBUG_REROLL_PATH))
	return data if data is Dictionary else {}

func _reroll_remaining() -> int:
	if _debug.unlock_all_buildings:
		return maxi(0, ceili(float(_debug_reroll_until - int(Time.get_unix_time_from_system() * 1000)) / 1000.0))
	if not _world_synced or _backend == null or _backend.token.is_empty() or _backend._verified_player_id.is_empty():
		return -1
	var now := _gate_clock.now_ms()
	if now < 0:
		return -1
	var last := int(_player_world.get("last_reroll_at", 0))
	return maxi(0, ceili(float(last + 60000 - now) / 1000.0)) if last > 0 else 0

func _update_reroll_button() -> void:
	if not is_instance_valid(_reroll_button):
		return
	var remaining := _reroll_remaining()
	_reroll_button.text = "%02d:%02d" % [remaining / 60, remaining % 60] if remaining > 0 else "WORLD_REROLL"
	_reroll_button.disabled = remaining != 0 or not _reroll_request.is_empty()

func _load_debug_appearances() -> Dictionary:
	if not FileAccess.file_exists(DEBUG_APPEARANCE_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEBUG_APPEARANCE_PATH))
	return data if data is Dictionary else {}

func _restore_debug_appearance() -> void:
	var appearances := _load_debug_appearances()
	_appearance_seed = int(appearances.get(_get_zone_id(), 0))
	if _appearance_seed <= 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_appearance_seed = rng.randi_range(1, 2147483647)
		appearances[_get_zone_id()] = _appearance_seed
		var file := FileAccess.open(DEBUG_APPEARANCE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(appearances))
			file.close()
	_apply_appearance_seed(_appearance_seed)

func _apply_appearance_seed(value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	_world_art_order = WORLD_ART.get(_get_zone_id(), []).duplicate()
	for i in range(_world_art_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = _world_art_order[i]
		_world_art_order[i] = _world_art_order[j]
		_world_art_order[j] = swap
	_world_art_index = 0
	_debug_rare_index = rng.randi_range(0, 2)
	_display_hunts = _hunt_schedule.duplicate()
	for i in range(_display_hunts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = _display_hunts[i]
		_display_hunts[i] = _display_hunts[j]
		_display_hunts[j] = swap
	_debug_rotation = 0
	if _map_displayed_boss.is_empty():
		_clear_guardian_preview()
		_change_world_art(0)
	_render_actor_roster()

func _apply_reroll() -> void:
	if _debug.unlock_all_buildings:
		_apply_appearance_seed(_appearance_seed)
	else:
		_restore_reroll(true)
	_request_global_boss()

func _restore_reroll(force: bool = false) -> void:
	if _debug.unlock_all_buildings or not _world_synced or _hunt_schedule.is_empty() or _backend == null or _backend._verified_player_id.is_empty() or (_reroll_restored and not force):
		return
	_reroll_restored = true
	var seeds: Dictionary = _player_world.get("reroll_seeds", {})
	var seed_value := int(seeds.get(_get_zone_id(), 0))
	if seed_value <= 0:
		seed_value = absi((str(_backend._verified_player_id) + ":" + _get_zone_id()).hash()) + 1
	_appearance_seed = seed_value
	_apply_appearance_seed(seed_value)

func _request_map_hunts() -> void:
	_hunt_wants_schedule = true
	_common_wants_refresh = true
	_drain_hunt_requests()

func _hunt_action_context_key() -> String:
	var global_id := str(_hunt_selected.get("global_event_id", ""))
	if not global_id.is_empty():
		return _get_zone_id() + ":" + global_id
	return "%s:%s:%s:%d:%s" % [_get_zone_id(), str(_hunt_selected.get("id", "")), _hunt_guardian_id, _hunt_rotation, str(_hunt_selected.get("appearance_id", ""))]

func _request_global_boss() -> void:
	_global_poll_timer = 0.0
	_global_wants_refresh = true
	_drain_hunt_requests()

func _render_global_boss() -> void:
	if is_instance_valid(_global_actor):
		_global_actor.queue_free()
		_global_actor = null
	if str(_global_event.get("status", "")) != "ACTIVE":
		return
	var boss: Dictionary = _global_event.get("boss", {})
	var texture_id := str(boss.get("texture_id", ""))
	if not _catalog.has(texture_id):
		return
	_global_actor = Control.new()
	_global_actor.name = "GlobalBoss"
	_global_actor.anchor_left = 0.16
	_global_actor.anchor_right = 0.16
	_global_actor.anchor_top = 0.61
	_global_actor.anchor_bottom = 0.61
	_global_actor.offset_left = -75
	_global_actor.offset_right = 75
	_global_actor.offset_top = -150
	_global_actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_global_actor)
	move_child(_global_actor, _world_modal.get_index())
	var sprite := TextureButton.new()
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.texture_normal = _catalog.get_tex(texture_id)
	sprite.ignore_texture_size = true
	sprite.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	sprite.pressed.connect(_open_global_boss)
	_global_actor.add_child(sprite)
	var label := Label.new()
	label.text = "GLOBAL EVENT: %s [%s]  %d/5" % [str(boss.get("name", "Boss")), str(boss.get("tier", "")).capitalize(), int(_global_event.get("winner_count", 0))]
	label.position = Vector2(-35, -28)
	label.size = Vector2(220, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_global_actor.add_child(label)
	var icon := Button.new()
	icon.text = "🌐"
	icon.position = Vector2(60, -60)
	icon.size = Vector2(30, 28)
	_global_actor.add_child(icon)
	var bubble := Label.new()
	bubble.text = "WORLD_GLOBAL_BOSS"
	bubble.position = Vector2(0, -88)
	bubble.size = Vector2(150, 24)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.visible = false
	bubble.add_theme_constant_override("outline_size", 5)
	_global_actor.add_child(bubble)
	icon.set_meta("bubble_pinned", false)
	icon.mouse_entered.connect(func(): bubble.visible = true)
	icon.mouse_exited.connect(func(): bubble.visible = bool(icon.get_meta("bubble_pinned")))
	icon.pressed.connect(func():
		var pinned := not bool(icon.get_meta("bubble_pinned"))
		icon.set_meta("bubble_pinned", pinned)
		bubble.visible = pinned)

func _open_global_boss() -> void:
	if str(_global_event.get("status", "")) != "ACTIVE":
		return
	_hunt_wants_guardians = false
	_hunt_selected = (_global_event.get("boss", {}) as Dictionary).duplicate(true)
	_hunt_selected["global_event_id"] = str(_global_event.get("event_id", ""))
	_hunt_guardian_id = ""
	var texture_id := str(_hunt_selected.get("texture_id", ""))
	_boss_portrait.texture = _catalog.get_tex(texture_id) if _catalog.has(texture_id) else null
	_boss_portrait.visible = _boss_portrait.texture != null
	_preview_status.text = "Global Boss Event: %s [%s]\n%d/5\n%s" % [str(_hunt_selected.get("name", "Boss")), str(_hunt_selected.get("tier", "")).capitalize(), int(_global_event.get("winner_count", 0)), "Already defeated" if _global_event.get("reward_status") != null else "Reward delivered after five victories."]
	_preview_status.visible = true
	_boss_picker.visible = false
	_boss_hp.visible = false
	_boss_status.visible = false
	_boss_open.visible = false
	_view_guardians.visible = false
	_debug_fight.visible = false
	_hunt_fight.visible = true
	_hunt_fight.disabled = _backend == null or _backend.token.is_empty() or _global_event.get("reward_status") != null
	if _backend == null or _backend.token.is_empty():
		_preview_status.text += "\nConnect and sign in to fight."
	var has_active := _backend != null and _hunt_active_owner == _backend._verified_player_id and not _hunt_active.is_empty() and int(_hunt_active.get("expires_at", 0)) > _backend.get_server_time_unix_ms()
	_set_hunt_button_text("HUNT_RESUME" if has_active and _active_hunt_matches("") else "HUNT_FIGHT")
	_world_modal.visible = true
	call_deferred("_fit_encounter_card")

func _drain_hunt_requests() -> void:
	if not is_inside_tree() or not is_instance_valid(_backend) or not _backend.is_inside_tree() or _backend.token.is_empty():
		return
	if not _hunt_pending_start_payload.is_empty():
		var current_key := _hunt_action_context_key()
		if _hunt_action_owner != _backend._verified_player_id or _hunt_action_key != current_key:
			return
		var start_id := _backend.request_api("POST", "/world/boss-hunts/start", _hunt_pending_start_payload.duplicate(true), false)
		if not start_id.is_empty():
			_hunt_pending_start_payload.clear()
			_hunt_requests[start_id] = "start"
			_hunt_fight.disabled = true
			_preview_status.text = "Starting encounter..."
		elif _backend._api_in_flight.is_empty():
			_hunt_fight.disabled = false
			_preview_status.text = "Could not send encounter request. Retry."
		return
	var kind := ""
	var path := ""
	if _hunt_wants_schedule:
		kind = "schedule"
		path = "/world/boss-hunts"
	elif _hunt_wants_session:
		kind = "session"
		path = "/world/boss-hunts/session"
	elif _common_wants_refresh:
		kind = "commons"
		path = "/world/boss-hunts/commons?zone_id=" + _get_zone_id().uri_encode()
	elif _hunt_wants_guardians and not _hunt_selected.is_empty() and not _hunt_selected.has("appearance_id") and not _hunt_selected.has("global_event_id") and not _backend._verified_player_id.is_empty():
		kind = "guardians"
		path = "/world/boss-hunts/guardians?zone_id=" + _get_zone_id().uri_encode() + "&hunt_id=" + str(_hunt_selected.get("id", "")).uri_encode()
	elif _global_wants_refresh and not _backend._verified_player_id.is_empty():
		kind = "global"
		path = "/world/global-bosses"
	if kind.is_empty() or _hunt_requests.values().has(kind):
		return
	var id := _backend.request_api("GET", path, null, false)
	if id.is_empty():
		return
	_hunt_requests[id] = kind
	match kind:
		"schedule": _hunt_wants_schedule = false
		"session": _hunt_wants_session = false
		"commons":
			_common_wants_refresh = false
			_common_request_owner = _backend._verified_player_id
		"global":
			_global_wants_refresh = false
			_global_request_owner = _backend._verified_player_id
		"guardians":
			_hunt_wants_guardians = false
			_guardian_request_key = _guardian_key()
			_guardian_request_owner = _backend._verified_player_id

func _request_hunt_session() -> void:
	_hunt_wants_session = true
	_drain_hunt_requests()

func _guardian_key() -> String:
	return _get_zone_id() + "|" + str(_hunt_selected.get("id", "")) + "|" + str(_appearance_seed)

func _active_hunt_matches(guardian_id: String) -> bool:
	if _backend == null or _hunt_active.is_empty() or _hunt_active_owner != _backend._verified_player_id or _hunt_active_owner.is_empty() or int(_hunt_active.get("expires_at", 0)) <= _backend.get_server_time_unix_ms():
		return false
	if _hunt_selected.has("global_event_id"):
		return str(_hunt_active.get("global_event_id", "")) == str(_hunt_selected.get("global_event_id", ""))
	if _hunt_selected.has("appearance_id") and str(_hunt_active.get("boss_definition", {}).get("appearance_id", "")) != str(_hunt_selected.appearance_id):
		return false
	var parent := str(_hunt_active.get("parent_hunt_id", _hunt_active.get("hunt_id", "")))
	return parent == str(_hunt_selected.get("id", "")) and str(_hunt_active.get("zone_id", "")) == _get_zone_id() and str(_hunt_active.get("guardian_id", "")) == guardian_id

func _request_guardian_progress() -> void:
	if _hunt_selected.is_empty() or _hunt_selected.has("global_event_id") or _hunt_selected.has("appearance_id"):
		_hunt_wants_guardians = false
		return
	if _hunt_requests.values().has("guardians") and _guardian_request_key == _guardian_key() and _backend != null and _guardian_request_owner == _backend._verified_player_id:
		return
	_hunt_wants_guardians = true
	_drain_hunt_requests()

func _show_map_hunt(boss: Dictionary) -> void:
	_hunt_selected = boss.duplicate(true)
	_hunt_guardian_id = ""
	_clear_guardian_preview()
	_map_displayed_boss = boss.duplicate(true)
	_world_stage.visible = false
	_preview_stage = Control.new()
	_preview_stage.name = "MapHunt"
	_preview_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview_stage)
	move_child(_world_modal, get_child_count() - 1)
	var entry := {"id": str(boss.get("id", "")), "name": str(boss.get("name", "Boss")), "tier": str(boss.get("tier", "common")), "texture_id": str(boss.get("display_texture_id", boss.get("texture_id", "")))}
	var guardians: Array = []
	var verified := _hunt_progress_key == _guardian_key() and _backend != null and not _backend._verified_player_id.is_empty() and _hunt_progress_owner == _backend._verified_player_id
	if verified:
		for guardian in _hunt_progress.get("guardians", []):
			if guardian is Dictionary and not bool(guardian.get("defeated", false)):
				var actor: Dictionary = guardian.duplicate(true)
				actor["id"] = str(guardian.get("guardian_id", ""))
				guardians.append(actor)
	var required := PackedStringArray()
	if not verified or (not bool(_hunt_progress.get("boss_unlocked", false)) and not _active_hunt_matches("")):
		required.append("Server-verified guardians")
	_add_preview_actor(entry, 0.55, 0.52, true, required)
	var order_rng := RandomNumberGenerator.new()
	order_rng.seed = _appearance_seed + absi(str(entry.id).hash())
	for i in range(guardians.size() - 1, 0, -1):
		var j := order_rng.randi_range(0, i)
		var swap = guardians[i]
		guardians[i] = guardians[j]
		guardians[j] = swap
	for i in guardians.size():
		var x := 0.55 if guardians.size() == 1 else 0.30 + 0.50 * float(i) / float(guardians.size() - 1)
		_add_preview_actor(guardians[i], x, 0.76, false, PackedStringArray())
	if not verified:
		_request_guardian_progress()

func _select_nearby_hunt(boss: Dictionary, request_progress: bool = true) -> void:
	_nearby_debug_index = -1
	_hunt_selected = boss.duplicate(true)
	_hunt_guardian_id = ""
	_preview_selection = str(boss.get("id", ""))
	var portrait_id := str(boss.get("display_texture_id", boss.get("texture_id", "")))
	_boss_portrait.texture = _catalog.get_tex(portrait_id) if _catalog.has(portrait_id) else null
	_boss_portrait.visible = _boss_portrait.texture != null
	var verified := _hunt_progress_key == _guardian_key() and _backend != null and not _backend._verified_player_id.is_empty() and _hunt_progress_owner == _backend._verified_player_id
	var active := _active_hunt_matches("")
	var unlocked := bool(_hunt_progress.get("boss_unlocked", false)) if verified else false
	_preview_status.text = "%s\nGuardians: %d/%d defeated%s" % [str(boss.get("name", "Boss")), int(_hunt_progress.get("defeated_count", 0)) if verified else 0, int(_hunt_progress.get("total_count", 0)) if verified else 0, "" if verified else "\nChecking guardian progress..."]
	if verified:
		for guardian in _hunt_progress.get("guardians", []):
			_preview_status.text += "\n%s — %s — %s" % [str(guardian.get("name", "Guardian")), str(guardian.get("tier", "")).capitalize(), "Defeated" if bool(guardian.get("defeated", false)) else "Available"]
	_preview_status.visible = true
	_boss_picker.visible = false
	_boss_hp.visible = false
	_boss_status.visible = false
	_boss_open.visible = false
	_debug_fight.visible = false
	_hunt_fight.visible = true
	_hunt_fight.disabled = not verified or _backend == null or _backend.token.is_empty() or (not active and (not unlocked or not bool(boss.get("available", false))))
	if _hunt_fight.disabled and verified:
		_preview_status.text += "\n" + ("Connect and sign in to fight." if _backend == null or _backend.token.is_empty() else ("Defeat all guardians first." if not unlocked else "Special boss is outside its rotation window."))
	_set_hunt_button_text("HUNT_RESUME" if active else "HUNT_FIGHT")
	_view_guardians.visible = verified and not unlocked and not active
	_world_modal.visible = true
	call_deferred("_fit_encounter_card")
	if not verified and request_progress:
		call_deferred("_request_guardian_progress")

func _start_map_hunt() -> void:
	if _backend == null or _backend.token.is_empty() or _backend._verified_player_id.is_empty():
		return
	if not _hunt_active.is_empty() and _hunt_active_owner == _backend._verified_player_id and int(_hunt_active.get("expires_at", 0)) > _backend.get_server_time_unix_ms() and _active_hunt_matches(_hunt_guardian_id):
		_enter_map_hunt(_hunt_active)
		return
	_hunt_active.clear()
	var global_id := str(_hunt_selected.get("global_event_id", ""))
	if not global_id.is_empty() and (global_id != str(_global_event.get("event_id", "")) or str(_global_event.get("status", "")) != "ACTIVE" or _global_event.get("reward_status") != null):
		_preview_status.text = "Global event unavailable. Refreshing..."
		_request_global_boss()
		return
	if global_id.is_empty() and not _hunt_selected.has("appearance_id") and (_hunt_progress_key != _guardian_key() or _hunt_progress_owner != _backend._verified_player_id or (_hunt_guardian_id.is_empty() and not bool(_hunt_progress.get("boss_unlocked", false)))):
		_preview_status.text = "Guardian progress unavailable or boss locked."
		return
	if global_id.is_empty() and ((not _hunt_selected.has("appearance_id") and _hunt_guardian_id.is_empty() and not bool(_hunt_selected.get("available", false))) or _hunt_rotation < 0 or (not _hunt_selected.has("appearance_id") and _hunt_guardian_id.is_empty() and _hunt_boundary > 0 and _backend.get_server_time_unix_ms() >= _hunt_boundary)):
		_preview_status.text = "Encounter expired. Refreshing..."
		_request_map_hunts()
		return
	var key := _hunt_action_context_key()
	if not _hunt_action_id.is_empty() and _hunt_action_key != key:
		_preview_status.text = "Previous request unresolved. Retry the same encounter."
		return
	if _hunt_action_id.is_empty():
		_hunt_action_id = _backend._make_uuid()
		_hunt_action_key = key
		_hunt_action_owner = _backend._verified_player_id
	if _hunt_action_owner != _backend._verified_player_id:
		_preview_status.text = "Account changed. Reopen the encounter."
		return
	if _hunt_requests.values().has("start"):
		return
	var payload := {"client_action_id": _hunt_action_id, "hunt_id": str(_hunt_selected.get("id", "")), "rotation_key": _hunt_rotation, "zone_id": _get_zone_id()}
	if _hunt_selected.has("appearance_id"):
		payload["appearance_id"] = _hunt_selected.appearance_id
	if not global_id.is_empty():
		payload["global_event_id"] = global_id
	if not _hunt_guardian_id.is_empty():
		payload["guardian_id"] = _hunt_guardian_id
	_hunt_pending_start_payload = payload.duplicate(true)
	_hunt_fight.disabled = true
	_preview_status.text = "Waiting to start encounter..."
	_drain_hunt_requests()

func _enter_map_hunt(session: Dictionary) -> void:
	if str(session.get("session_id", "")).is_empty() or str(session.get("status", "")) != "ACTIVE":
		_preview_status.text = "Session unavailable; refresh the encounter."
		return
	var boss: Dictionary = session.get("boss_definition", {})
	var session_zone := str(session.get("zone_id", session.get("global_status", {}).get("zone_id", _get_zone_id())))
	var return_view := {"zone_id": session_zone, "player_id": _backend._verified_player_id}
	if not str(session.get("global_event_id", "")).is_empty():
		return_view["category"] = "global"
		return_view["event_id"] = str(session.global_event_id)
	elif not str(session.get("parent_hunt_id", "")).is_empty() or str(session.get("hunt_id", "")) != "hunt_common":
		return_view["category"] = "special"
		return_view["hunt_id"] = str(session.get("parent_hunt_id", session.get("hunt_id", "")))
	else:
		return_view["category"] = "common"
	SceneRouter.go_to_solo_hunt(str(session.get("hunt_id", "")), int(session.get("rotation_key", -1)), str(boss.get("display_texture_id", boss.get("texture_id", ""))), str(session.get("session_id", "")), session_zone, {}, str(session.get("replaced_session_id", "")), return_view)

func _show_debug_boss(index: int, group_id: String = "") -> void:
	_nearby_debug_index = -1
	_hunt_selected.clear()
	_debug_rotation = index
	var tiers := ["common", "mythic", "rare", "epic", "legendary"]
	var rare_variants := ["boss_leviathan", "tier3boss", "scorpion_boss"]
	var textures := ["boss_common", "boss_colossus", rare_variants[_debug_rare_index % rare_variants.size()], "boss_temporal", "ghost_boss"]
	if group_id.is_empty():
		group_id = "debug_" + tiers[index]
	var guardians: Array = []
	if index > 1:
		var guardian_id := group_id + "|preview_higher"
		guardians.append({"id": guardian_id, "name": "Guardian", "tier": tiers[index - 1], "texture_id": textures[index - 1], "defeated": SceneRouter._debug_guardian_wins.has(SceneRouter.debug_guardian_key(_get_zone_id(), index, guardian_id))})
	var commons := 2 if index <= 2 else index
	var zone := _get_zone_id()
	var entries: Array = _world_art_order if not _world_art_order.is_empty() else WORLD_ART.get(zone, [])
	for i in mini(commons, entries.size()):
		var guardian_id: String = group_id + "|preview_common_%d" % i
		guardians.append({"id": guardian_id, "name": _common_display_name(entries[(_world_art_index + i) % entries.size()], zone), "tier": "common", "texture_id": "res://assets/lab/bosses/%s_zone_common/%s.png" % [zone.trim_prefix("zone_"), entries[(_world_art_index + i) % entries.size()]], "defeated": SceneRouter._debug_guardian_wins.has(SceneRouter.debug_guardian_key(zone, index, guardian_id))})
	var names := {"boss_colossus": "Arcane Colossus", "boss_leviathan": "Corrupted Leviathan", "tier3boss": "Dread Sovereign", "scorpion_boss": "Scorpion Overlord", "boss_temporal": "Temporal Warden", "ghost_boss": "Spectral Sovereign"}
	show_guardian_preview({"id": group_id, "name": names.get(textures[index], "Boss"), "tier": tiers[index], "texture_id": textures[index]}, guardians)
	var nearby_index := 1 if index == 4 else index + 1
	var other := TextureButton.new()
	other.name = "NearbyDebugBoss"
	other.anchor_left = 0.80
	other.anchor_right = 0.80
	other.anchor_top = 0.58
	other.anchor_bottom = 0.58
	other.offset_left = -75
	other.offset_right = 75
	other.offset_top = -150
	other.texture_normal = _catalog.get_tex(textures[nearby_index])
	other.ignore_texture_size = true
	other.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	other.tooltip_text = "%s Boss (debug preview)" % tiers[nearby_index].capitalize()
	other.pressed.connect(func(): _select_nearby_debug_boss(nearby_index, tiers[nearby_index], textures[nearby_index]))
	_preview_stage.add_child(other)
	var other_label := Label.new()
	other_label.text = "[%s] Boss" % tiers[nearby_index].capitalize()
	other_label.position = Vector2(-25, -28)
	other_label.size = Vector2(200, 28)
	other_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	other_label.add_theme_font_size_override("font_size", 16)
	other_label.add_theme_constant_override("outline_size", 5)
	other_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	other.add_child(other_label)


func _select_nearby_debug_boss(index: int, tier: String, texture_id: String) -> void:
	_boss_portrait.texture = _catalog.get_tex(texture_id) if _catalog.has(texture_id) else null
	_boss_portrait.visible = _boss_portrait.texture != null
	_nearby_debug_index = index
	var group_id := "debug_" + tier
	var remaining := 0
	if index > 1 and not SceneRouter._debug_guardian_wins.has(SceneRouter.debug_guardian_key(_get_zone_id(), index, group_id + "|preview_higher")):
		remaining += 1
	var count := 2 if index <= 2 else index
	for i in mini(count, WORLD_ART.get(_get_zone_id(), []).size()):
		if not SceneRouter._debug_guardian_wins.has(SceneRouter.debug_guardian_key(_get_zone_id(), index, group_id + "|preview_common_%d" % i)):
			remaining += 1
	_preview_selection = group_id
	_debug_hunt_id = "hunt_" + tier
	_debug_visual = {"id": group_id, "tier": tier, "texture": texture_id, "name": "Boss (preview)", "guardian": false, "parent_index": index, "encounter_id": group_id}
	_preview_status.text = "Unverified debug preview: %s Boss\n%s" % [tier.capitalize(), "Locked: defeat its %d guardians." % remaining if remaining > 0 else "No rewards or persistent victories."]
	_preview_status.visible = true
	_boss_picker.visible = false
	_boss_hp.visible = false
	_boss_status.visible = false
	_boss_open.visible = false
	_hunt_fight.visible = false
	_debug_fight.visible = _debug.unlock_all_buildings
	_debug_fight.disabled = remaining > 0
	_view_guardians.visible = remaining > 0
	_world_modal.visible = true
	call_deferred("_fit_encounter_card")

func _show_selected_guardians() -> void:
	if _debug.unlock_all_buildings and _hunt_selected.is_empty():
		var index := _nearby_debug_index if _nearby_debug_index >= 0 else _debug_rotation
		if _nearby_debug_index >= 0:
			var tiers := ["common", "mythic", "rare", "epic", "legendary"]
			var group_id: String = "debug_" + tiers[index]
			var entries: Array = _world_art_order if not _world_art_order.is_empty() else WORLD_ART.get(_get_zone_id(), [])
			var guardian: Dictionary = {}
			if index > 1 and not SceneRouter._debug_guardian_wins.has(SceneRouter.debug_guardian_key(_get_zone_id(), index, group_id + "|preview_higher")):
				var textures := ["boss_common", "boss_colossus", ["boss_leviathan", "tier3boss", "scorpion_boss"][_debug_rare_index % 3], "boss_temporal", "ghost_boss"]
				guardian = {"id": group_id + "|preview_higher", "tier": tiers[index - 1], "texture": textures[index - 1], "name": "Guardian"}
			else:
				var count := 2 if index <= 2 else index
				for i in mini(count, entries.size()):
					var guardian_id: String = group_id + "|preview_common_%d" % i
					if not SceneRouter._debug_guardian_wins.has(SceneRouter.debug_guardian_key(_get_zone_id(), index, guardian_id)):
						var art_id: String = entries[(_world_art_index + i) % entries.size()]
						guardian = {"id": guardian_id, "tier": "common", "texture": "res://assets/lab/bosses/%s_zone_common/%s.png" % [_get_zone_id().trim_prefix("zone_"), art_id], "name": _common_display_name(art_id, _get_zone_id())}
						break
			if guardian.is_empty():
				_preview_status.text = "All guardians defeated. Boss unlocked."
				_view_guardians.visible = false
				return
			var texture_id := str(guardian.texture)
			_boss_portrait.texture = load(texture_id) as Texture2D if texture_id.begins_with("res://") and ResourceLoader.exists(texture_id) else (_catalog.get_tex(texture_id) if _catalog.has(texture_id) else null)
			_boss_portrait.visible = _boss_portrait.texture != null
			_preview_selection = str(guardian.id)
			_debug_hunt_id = "hunt_" + str(guardian.tier)
			_debug_visual = {"id": texture_id.get_file().get_basename() if texture_id.begins_with("res://") else str(guardian.id), "tier": str(guardian.tier), "texture": texture_id, "name": str(guardian.name), "guardian": true, "parent_index": index, "encounter_id": str(guardian.id)}
			_preview_status.text = "Unverified debug preview: %s\nNo rewards or persistent victories." % str(guardian.name)
			_view_guardians.visible = false
			_debug_fight.visible = true
			_debug_fight.disabled = false
			return
		for child in _preview_stage.get_children():
			if child.has_meta("select_actor") and str(child.name).contains("preview_") and not SceneRouter._debug_guardian_wins.has(SceneRouter.debug_guardian_key(_get_zone_id(), index, str(child.name).trim_prefix("Actor_"))):
				child.get_meta("select_actor").call()
				return
		_preview_status.text = "All guardians defeated. Boss unlocked."
		return
	if _backend == null or _hunt_progress_key != _guardian_key() or _hunt_progress_owner.is_empty() or _hunt_progress_owner != _backend._verified_player_id:
		return
	for guardian in _hunt_progress.get("guardians", []):
		if guardian is Dictionary and not bool(guardian.get("defeated", false)):
			_hunt_guardian_id = str(guardian.get("guardian_id", ""))
			_preview_selection = _hunt_guardian_id
			var texture_id := str(guardian.get("texture_id", ""))
			_boss_portrait.texture = null
			if texture_id.begins_with("res://assets/lab/bosses/") and not ".." in texture_id and ResourceLoader.exists(texture_id):
				_boss_portrait.texture = load(texture_id) as Texture2D
			elif _catalog.has(texture_id):
				_boss_portrait.texture = _catalog.get_tex(texture_id)
			_boss_portrait.visible = _boss_portrait.texture != null
			_preview_status.text = str(guardian.get("name", "Guardian"))
			_view_guardians.visible = false
			_hunt_fight.visible = true
			var active := _active_hunt_matches(_hunt_guardian_id)
			_set_hunt_button_text("HUNT_RESUME" if active else "HUNT_FIGHT")
			_hunt_fight.disabled = _backend.token.is_empty()
			_preview_status.text = "%s\nGuardian of %s — %s" % [str(guardian.get("name", "Guardian")), str(_hunt_selected.get("name", "Boss")), str(guardian.get("tier", "")).capitalize()]
			_world_modal.visible = true
			return
	_view_guardians.visible = false
	_preview_status.text = "All guardians defeated. Boss unlocked."

func _start_debug_hunt() -> void:
	if not _debug.unlock_all_buildings:
		return
	SceneRouter.go_to_solo_hunt(_debug_hunt_id, 0, "", "", _get_zone_id(), _debug_visual)


func _on_auth_changed(token: String) -> void:
	_global_event.clear()
	_global_wants_refresh = false
	_global_request_owner = ""
	_render_global_boss()
	_player_world = {}
	_world_synced = false
	_reroll_restored = false
	_session_id = ""
	_claim_action = ""
	_reroll_action = ""
	_hunt_active.clear()
	_hunt_active_owner = ""
	_hunt_session_checked = false
	_common_cooldown_until = 0
	_common_progress.clear()
	_common_owner = ""
	_common_request_owner = ""
	_common_wants_refresh = false
	_restart_action = ""
	_refresh_common_picker()
	_hunt_schedule.clear()
	_display_hunts.clear()
	_world_art_order.clear()
	_hunt_progress.clear()
	_hunt_progress_key = ""
	_hunt_progress_owner = ""
	_hunt_action_id = ""
	_hunt_action_key = ""
	_hunt_action_owner = ""
	_hunt_wants_schedule = false
	_hunt_wants_session = false
	_hunt_wants_guardians = false
	_hunt_requests.clear()
	_hunt_pending_start_payload.clear()
	if not _hunt_selected.is_empty():
		_clear_guardian_preview()
		_hunt_selected.clear()
	if token != "":
		_auth_refresh_needed = true
		_common_wants_refresh = true
		_request_world_state()
		_request_map_hunts()
		_request_global_boss()

func _apply_background() -> void:
	if _background == null:
		return
	var zone_id = _get_zone_id()
	var background_id: String = WORLD_BACKGROUNDS.get(zone_id, "")
	var tex: Texture2D = load("res://assets/lab/resources/world_zones/%s.png" % background_id) as Texture2D if background_id != "" else null
	_background.texture = tex
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if _header_label != null:
		_header_label.text = _get_zone_name(zone_id)

func _setup_buttons() -> void:
	if _enter_button != null:
		_enter_button.pressed.connect(_on_enter_pressed)
	if _farm_button != null:
		_farm_button.pressed.connect(_on_farm_pressed)
	if _claim_button != null:
		_claim_button.pressed.connect(_on_claim_pressed)

func _setup_farm_options() -> void:
	if _farm_count == null:
		return
	_farm_count.clear()
	var max_blocks := clampi(int(_db.get_balance("world_max_blocks_per_action", 4)), 1, 100)
	for count in range(1, max_blocks + 1):
		_farm_count.add_item("x%s" % count)
		_farm_count.set_item_metadata(_farm_count.item_count - 1, count)
	_farm_count.select(0)

func _load_state() -> void:
	if _backend != null:
		var state = _backend.load_cached_state()
		_update_from_state(state)

func _update_from_state(state: Dictionary) -> void:
	if _backend != null:
		_gate_clock.sync(_backend.get_server_time_unix_ms())
	_player_world = state.get("world", {})
	_sync_session()
	_update_labels()

func _request_world_state() -> void:
	if _backend == null:
		return
	var request_id := _backend.request_api("GET", "/world/state", null, false)
	if not request_id.is_empty():
		_world_requests[request_id] = _backend.token
	if request_id != "" and _backend.token != "":
		_auth_refresh_needed = false
	if _backend.token == "":
		_backend.ensure_dev_login()
		_set_error("Logging in...")

func _on_api_completed(_request_id: String, ok: bool, data: Dictionary) -> void:
	if not ok and str(data.get("error", "")) == "network_error":
		_global_connection_lost = true
	elif ok and _global_connection_lost:
		_global_connection_lost = false
		call_deferred("_request_global_boss")
	if _world_requests.has(_request_id):
		var request_token := str(_world_requests[_request_id])
		_world_requests.erase(_request_id)
		if _backend == null or request_token != _backend.token:
			if _backend != null and not _backend.token.is_empty():
				call_deferred("_request_world_state")
			return
	if _request_id == _reroll_request and not _reroll_request.is_empty():
		_gate_clock.sync(int(data.get("server_time_unix_ms", 0)))
		_reroll_request = ""
		if _backend == null or _reroll_owner != _backend._verified_player_id:
			_reroll_action = ""
			return
		if ok:
			_reroll_action = ""
			_hunt_progress.clear()
			_hunt_progress_key = ""
			_hunt_progress_owner = ""
			_update_from_state(data.get("updated_player_state", {}))
			_apply_reroll()
		else:
			_set_error(str(data.get("error", "Reroll failed. Retry.")))
			_request_world_state()
		return
	if _request_id == _claim_request and not _claim_request.is_empty():
		_claim_request = ""
		if _backend == null or _claim_owner.is_empty() or _claim_owner != _backend._verified_player_id:
			return
		if ok:
			_claim_action = ""
			_update_from_state(data.get("updated_player_state", {}))
			_set_error("Loot claimed.")
		else:
			_set_error(str(data.get("error", "Claim failed. Retry.")))
		_update_labels()
		return
	call_deferred("_drain_hunt_requests")
	if _hunt_requests.has(_request_id):
		var kind: String = _hunt_requests[_request_id]
		_hunt_requests.erase(_request_id)
		if kind == "schedule":
			call_deferred("_request_hunt_session")
		if kind == "guardians" and (_hunt_selected.is_empty() or _hunt_selected.has("appearance_id") or _hunt_selected.has("global_event_id")):
			return
		if kind == "guardians" and (_guardian_request_key != _guardian_key() or _backend == null or _guardian_request_owner.is_empty() or _guardian_request_owner != _backend._verified_player_id):
			call_deferred("_request_guardian_progress")
			return
		if kind == "global" and (_backend == null or _global_request_owner.is_empty() or _global_request_owner != _backend._verified_player_id):
			call_deferred("_request_global_boss")
			return
		if not ok:
			if kind == "start":
				if str(data.get("error", "")) != "network_error":
					_hunt_action_id = ""
					_hunt_action_key = ""
					_hunt_action_owner = ""
					call_deferred("_request_hunt_session")
				if int(data.get("cooldown_remaining_seconds", 0)) > 0:
					_common_cooldown_until = _backend.get_server_time_unix_ms() + int(data.cooldown_remaining_seconds) * 1000
				_preview_status.text = str(data.get("error", "Encounter unavailable."))
				_hunt_fight.disabled = false
			elif kind == "session" and _hunt_selected.has("appearance_id"):
				_preview_status.text = "Hunt availability unavailable. Reconnect and retry."
			elif kind == "guardians":
				_hunt_progress.clear()
				_hunt_progress_key = ""
				_preview_status.text = "Guardian progress unavailable. Select the boss to retry."
			elif kind == "restart_commons":
				_restart_zone.disabled = false
				_set_error(str(data.get("error", "Could not restart zone.")))
			return
		match kind:
			"global":
				_gate_clock.sync(int(data.get("server_time_unix_ms", 0)))
				for event in data.get("events", []):
					if event is Dictionary and str(event.get("zone_id", "")) == _get_zone_id():
						_global_event = event.duplicate(true)
						_render_global_boss()
						_restore_encounter_view()
						if _world_modal.visible and _hunt_selected.has("global_event_id"):
							if str(_hunt_selected.global_event_id) == str(_global_event.get("event_id", "")) and str(_global_event.get("status", "")) == "ACTIVE":
								_open_global_boss()
							else:
								_hunt_fight.disabled = true
								_preview_status.text = "Global boss defeated. Reward delivered." if _global_event.get("reward_status") == "PAID" else "Global event complete."
						break
			"schedule":
				_hunt_schedule.clear()
				for boss in data.get("bosses", []):
					if boss is Dictionary:
						_hunt_schedule.append(boss)
				_render_actor_roster()
				_hunt_rotation = int(data.get("rotation_key", -1))
				_restore_reroll()
				var now := _backend.get_server_time_unix_ms()
				var window_end := int(data.get("special_window_ends_at", 0))
				_hunt_boundary = window_end if window_end > now else int(data.get("next_rotation_at", 0))
				_restore_encounter_view()
			"session":
				_hunt_active = data.get("session", {}) if data.get("session") is Dictionary else {}
				_hunt_active_owner = _backend._verified_player_id
				_hunt_session_checked = true
				_common_cooldown_until = int(data.get("common_cooldown_until", 0))
				if _hunt_selected.has("appearance_id") and _world_modal.visible:
					_update_common_details()
				if not _hunt_selected.is_empty() and not _hunt_selected.has("appearance_id") and not _hunt_selected.has("global_event_id"):
					call_deferred("_request_guardian_progress")
			"commons":
				if _common_request_owner == _backend._verified_player_id and not _common_request_owner.is_empty() and str(data.get("zone_id", "")) == _get_zone_id():
					_common_progress = data.duplicate(true)
					_common_owner = _backend._verified_player_id
					_refresh_common_picker()
					if is_instance_valid(_world_stage) and _world_stage.visible and not _world_modal.visible:
						_world_art_index = 0
						_change_world_art(0)
					if _world_modal.visible and _hunt_selected.has("appearance_id"):
						_update_common_details()
			"restart_commons":
				_restart_action = ""
				_restart_zone.disabled = false
				_common_wants_refresh = true
			"guardians":
				if _guardian_request_key != _guardian_key() or _guardian_request_owner.is_empty() or _guardian_request_owner != _backend._verified_player_id or str(data.get("zone_id", "")) != _get_zone_id() or str(data.get("hunt_id", "")) != str(_hunt_selected.get("id", "")):
					call_deferred("_request_guardian_progress")
					return
				var reopen_main := _world_modal.visible and _preview_selection == str(_hunt_selected.get("id", ""))
				_hunt_progress = data.duplicate(true)
				_hunt_progress_key = _guardian_key()
				_hunt_progress_owner = _backend._verified_player_id
				if str(_map_displayed_boss.get("id", "")) != str(_hunt_selected.get("id", "")):
					if reopen_main:
						_select_nearby_hunt(_hunt_selected, false)
				else:
					_show_map_hunt(_hunt_selected.duplicate(true))
					if reopen_main:
						_open_main_preview()
			"start":
				var current_key := _hunt_action_context_key()
				if _hunt_action_owner.is_empty() or _hunt_action_owner != _backend._verified_player_id:
					return
				if _hunt_action_key != current_key:
					_hunt_active = data.duplicate(true)
					_hunt_active_owner = _hunt_action_owner
					_hunt_action_id = ""
					_hunt_action_key = ""
					_hunt_action_owner = ""
					_preview_status.text = "Another encounter started. Select it to resume."
					return
				_hunt_action_id = ""
				_hunt_action_key = ""
				_hunt_action_owner = ""
				_enter_map_hunt(data)
		return
	_gate_clock.sync(int(data.get("server_time_unix_ms", 0)))
	if not ok:
		_set_error(str(data.get("error", "Request failed.")))
		if _boss_status != null and _bosses.is_empty():
			_boss_status.text = "Boss data unavailable. Check the server connection."
		return
	if data.has("world_state"):
		_world_state = data.get("world_state", {})
		var pw = data.get("player_world", null)
		if typeof(pw) == TYPE_DICTIONARY:
			_player_world = pw
			_world_synced = true
			_restore_reroll()
		_sync_session()
		_update_labels()
		if _auth_refresh_needed:
			call_deferred("_request_world_state")
		elif pw is Dictionary:
			_clear_error()
			if _hunt_schedule.is_empty():
				call_deferred("_request_map_hunts")
		return
	# world_enter response
	if data.has("session_id"):
		_session_id = str(data.get("session_id", ""))
		_update_labels()

func _on_state_updated(state: Dictionary) -> void:
	_update_from_state(state)
	_restore_reroll()
	if _global_connection_lost and not state.is_empty():
		_global_connection_lost = false
		call_deferred("_request_global_boss")
	if _backend != null and not _backend._verified_player_id.is_empty():
		_restore_encounter_view()
		if _hunt_active_owner != _backend._verified_player_id:
			call_deferred("_request_hunt_session")
		elif not _hunt_selected.is_empty() and not _hunt_selected.has("global_event_id") and not _hunt_selected.has("appearance_id") and _hunt_progress_key != _guardian_key():
			call_deferred("_request_guardian_progress")

func _on_enter_pressed() -> void:
	_clear_error()
	if not _ensure_auth():
		return
	if not _has_world_unlock():
		_set_error("World Gate locked. Build the World Gate to enter zones.")
		return
	if _session_id != "":
		return
	if _gate_remaining() != 0:
		_set_error("World Gate cooldown: %s" % _gate_remaining_text())
		return
	var fee := int(_db.get_balance("world_entry_fee_essence", 0))
	var balance := int(_backend.load_cached_state().get("wallet", {}).get("essence", 0))
	var daily_limit := int(_db.get_balance("world_daily_entries", 10))
	_enter_confirm.dialog_text = "Enter %s?\nCost: %d Essence (available: %d).\nDaily entries: %d / %d.\nRequires a constructed World Gate." % [_get_zone_name(_get_zone_id()), fee, balance, int(_player_world.get("daily_entries", 0)), daily_limit]
	_enter_confirm.popup_centered()

func _confirm_zone_entry() -> void:
	if _session_id != "" or _gate_remaining() != 0 or not _ensure_auth() or not _has_world_unlock():
		return
	var zone_id = _get_zone_id()
	if zone_id == "":
		return
	var body = {"client_action_id": _make_client_id(), "zone_id": zone_id}
	if _backend != null:
		if _backend.request_api("POST", "/world/enter", body, true) == "":
			_set_error("Request in progress. Try again shortly.")

func _on_farm_pressed() -> void:
	_clear_error()
	if not _ensure_auth():
		return
	if _session_id == "":
		_set_error("No active session.")
		return
	var count = _get_farm_count()
	var body = {"client_action_id": _make_client_id(), "session_id": _session_id, "blocks": count}
	if _backend != null:
		if _backend.request_api("POST", "/world/farm", body, true) == "":
			_set_error("Request in progress. Try again shortly.")

func _on_claim_pressed() -> void:
	_clear_error()
	if not _ensure_auth():
		return
	if _session_id == "":
		_set_error("No active session.")
		return
	if not _claim_request.is_empty() or (_claim_button != null and _claim_button.disabled):
		return
	if _claim_action.is_empty():
		_claim_action = _make_client_id()
	var body = {"client_action_id": _claim_action, "session_id": _session_id}
	_claim_owner = _backend._verified_player_id
	_claim_request = _backend.request_api("POST", "/world/claim", body, true)
	if _claim_request.is_empty():
		_set_error("Request in progress. Try again shortly.")
	else:
		_set_error("Claiming loot...")
		_update_labels()

func _get_zone_id() -> String:
	if zone_id_override != "":
		return zone_id_override
	if _zone_id != "":
		return _zone_id
	_zone_id = SceneRouter.consume_world_zone_id()
	if _zone_id == "":
		var zones: Array = _db.zones.keys()
		zones.sort()
		if zones.size() > 0:
			_zone_id = str(zones[0])
	return _zone_id

func _set_hunt_button_text(key: String) -> void:
	_hunt_fight.set_meta("localization_key", key)
	_hunt_fight.text = tr(key)

func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready():
		return
	if _header_label != null and not _zone_id.is_empty():
		_header_label.text = _get_zone_name(_zone_id)
	if is_instance_valid(_hunt_fight) and _hunt_fight.has_meta("localization_key"):
		_set_hunt_button_text(str(_hunt_fight.get_meta("localization_key")))

func _get_zone_name(zone_id: String) -> String:
	var entry = _db.zones.get(zone_id, {})
	if typeof(entry) == TYPE_DICTIONARY:
		return GameLocalization.catalog("zone", zone_id, "name", str(entry.get("display_name", entry.get("name", zone_id))))
	return zone_id

func _sync_session() -> void:
	var previous := _session_id
	_session_id = ""
	var sessions = _player_world.get("sessions", {})
	if typeof(sessions) != TYPE_DICTIONARY:
		return
	for sid in sessions.keys():
		var entry = sessions[sid]
		if typeof(entry) != TYPE_DICTIONARY or str(entry.get("zone_id", "")) != _get_zone_id():
			continue
		if _session_id.is_empty():
			_session_id = str(sid)
		var loot: Variant = entry.get("pending_loot", {})
		if loot is Dictionary and loot.values().any(func(amount): return int(amount) > 0):
			_session_id = str(sid)
			break
	if previous != _session_id and _claim_request.is_empty():
		_claim_action = ""

func _update_labels() -> void:
	var zone_id = _get_zone_id()
	if _session_label != null:
		_session_label.text = "Zone session active" if _session_id != "" else "World Gate cooldown: %s" % _gate_remaining_text() if _gate_remaining() != 0 else "No active zone session"
	if _modifier_label != null:
		var mods := []
		var zone_map = _world_state.get("zones", [])
		if typeof(zone_map) == TYPE_ARRAY:
			for entry in zone_map:
				if typeof(entry) == TYPE_DICTIONARY and str(entry.get("zone_id", "")) == zone_id:
					mods = entry.get("modifier_ids", [])
					break
		_modifier_label.text = "Modifiers: %s" % _format_list(mods)
	if _heat_label != null:
		var heat := 0
		var rep := 0
		var progress = _player_world.get("zone_progress", {})
		if typeof(progress) == TYPE_DICTIONARY and progress.has(zone_id):
			var entry2 = progress[zone_id]
			if typeof(entry2) == TYPE_DICTIONARY:
				heat = int(entry2.get("heat", 0))
				rep = int(entry2.get("reputation", 0))
		_heat_label.text = "Heat: %s | Rep: %s" % [heat, rep]
	var sessions: Variant = _player_world.get("sessions", {})
	var session: Dictionary = sessions.get(_session_id, {}) if sessions is Dictionary else {}
	var loot: Variant = session.get("pending_loot", {})
	if _loot_label != null:
		var parts: Array[String] = []
		if loot is Dictionary:
			for key in loot:
				parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), loot[key]])
		_loot_label.text = "Unclaimed loot: %s" % [", ".join(parts) if not parts.is_empty() else "None"]
	if _enter_button != null:
		_enter_button.disabled = _session_id != "" or _gate_remaining() != 0
		_enter_button.tooltip_text = "World Gate cooldown: %s" % _gate_remaining_text() if _session_id == "" and _gate_remaining() != 0 else ""
	if _farm_button != null:
		_farm_button.disabled = _session_id == ""
	if _claim_button != null:
		_claim_button.disabled = not _world_synced or _backend == null or _backend.token.is_empty() or _backend._verified_player_id.is_empty() or not _claim_request.is_empty() or _session_id == "" or not (loot is Dictionary and loot.values().any(func(amount): return int(amount) > 0))

func _gate_remaining() -> int:
	return _gate_clock.remaining_seconds(_player_world, int(_db.get_balance("world_gate_cooldown_seconds", 3600)))

func _gate_remaining_text() -> String:
	var remaining := _gate_remaining()
	return "checking server time" if remaining < 0 else _gate_clock.format_remaining(remaining)

func _ensure_auth() -> bool:
	if _backend == null:
		_set_error("Backend unavailable.")
		return false
	if _backend.token != "":
		return true
	_backend.ensure_dev_login()
	_set_error("Logging in...")
	return false

func _has_world_unlock() -> bool:
	_debug.reload()
	if _debug.unlock_all_buildings or _debug.force_all_clickable:
		return true
	var lab = _backend.load_cached_state().get("lab", {})
	if typeof(lab) != TYPE_DICTIONARY:
		return false
	var buildings = lab.get("buildings", {})
	if typeof(buildings) != TYPE_DICTIONARY:
		return false
	var entry = buildings.get("world_gate", {})
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	return int(entry.get("level", 0)) > 0

func _get_farm_count() -> int:
	if _farm_count == null or _farm_count.item_count == 0:
		return 1
	var count = int(_farm_count.get_item_metadata(_farm_count.selected))
	return max(1, count)

func _make_client_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func _set_error(message: String) -> void:
	if _error_label != null:
		_error_label.text = message

func _clear_error() -> void:
	if _error_label != null:
		_error_label.text = ""

func _format_list(values: Variant) -> String:
	if typeof(values) != TYPE_ARRAY:
		return "-"
	if values.is_empty():
		return "-"
	var list: Array = []
	for item in values:
		list.append(str(item))
	return ", ".join(list)

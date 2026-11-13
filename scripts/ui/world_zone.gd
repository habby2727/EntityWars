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
var _world_art_index := 0
var _world_idle: Tween
var _world_modal: Control
var _world_stage: Control
var _preview_stage: Control
var _preview_tweens: Array[Tween] = []
var _preview_selection := ""
var _preview_selected_encounter: Dictionary = {}
var _preview_status: Label

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
	_apply_background()
	_setup_zone_view()
	_setup_buttons()
	_enter_confirm = ConfirmationDialog.new()
	_enter_confirm.title = "Enter zone"
	_enter_confirm.confirmed.connect(_confirm_zone_entry)
	add_child(_enter_confirm)
	_setup_farm_options()
	_load_state()
	_request_world_state()

func _process(_delta: float) -> void:
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
	var encounters := Button.new()
	encounters.text = "Global encounters"
	encounters.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	encounters.offset_left = -235
	encounters.offset_right = -30
	encounters.offset_top = 80
	encounters.offset_bottom = 122
	encounters.pressed.connect(func(): _open_encounters("Boss Hunts"))
	add_child(encounters)
	MenuArt.button(encounters)
	if _enter_button != null:
		_enter_button.text = "Enter zone"
	if _farm_button != null:
		_farm_button.text = "Explore"
	if _claim_button != null:
		_claim_button.text = "Claim loot"
	for button in [_enter_button, _farm_button, _claim_button]:
		if button != null:
			button.custom_minimum_size = Vector2(130, 42)
			MenuArt.button(button)
	_setup_world_art()
	var panel := PanelContainer.new()
	panel.name = "WorldBossPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -330
	panel.offset_right = -30
	panel.offset_top = 125
	panel.offset_bottom = 420
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
	title.text = "WORLD BOSSES"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	_boss_picker = OptionButton.new()
	_boss_picker.disabled = true
	_boss_picker.item_selected.connect(_on_boss_selected)
	content.add_child(_boss_picker)
	_boss_portrait = TextureRect.new()
	_boss_portrait.custom_minimum_size = Vector2(0, 0)
	_boss_portrait.visible = false
	_boss_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_boss_portrait)
	_boss_status = Label.new()
	_boss_status.text = "Waiting for server data."
	_boss_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_boss_status)
	_boss_hp = ProgressBar.new()
	_boss_hp.show_percentage = false
	_boss_hp.visible = false
	content.add_child(_boss_hp)
	_boss_open = Button.new()
	_boss_open.text = "Open boss encounter"
	_boss_open.disabled = true
	_boss_open.custom_minimum_size.y = 42
	MenuArt.button(_boss_open)
	_boss_open.pressed.connect(_open_boss)
	content.add_child(_boss_open)
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
	close.text = "X"
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
			_world_modal.visible = true)
	stage.add_child(_world_sprite)
	var name_panel := PanelContainer.new()
	name_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	name_panel.anchor_top = 0.79
	name_panel.anchor_bottom = 0.79
	name_panel.offset_left = -250
	name_panel.offset_right = 250
	name_panel.offset_top = -385
	name_panel.offset_bottom = -345
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = Color(0.025, 0.03, 0.04, 0.94)
	name_style.set_corner_radius_all(4)
	name_style.set_content_margin_all(6)
	name_panel.add_theme_stylebox_override("panel", name_style)
	stage.add_child(name_panel)
	_world_name = RichTextLabel.new()
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
	for direction in [-1, 1]:
		var button := Button.new()
		button.text = "<" if direction < 0 else ">"
		button.tooltip_text = "Previous appearance" if direction < 0 else "Next appearance"
		button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		button.offset_left = -300 if direction < 0 else 250
		button.offset_right = button.offset_left + 50
		button.offset_top = -310
		button.offset_bottom = -260
		button.pressed.connect(func(): _change_world_art(direction))
		stage.add_child(button)
		MenuArt.button(button)
	_change_world_art(0)

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
	_add_preview_actor(main, 0.5, 0.59, true, required)
	var count := mini(remaining.size(), 5)
	for i in count:
		var x := 0.5 if count == 1 else 0.27 + 0.46 * float(i) / float(count - 1)
		_add_preview_actor(remaining[i], x, 0.75, false, PackedStringArray())

func _add_preview_actor(entry: Dictionary, x: float, ground: float, main: bool, required: PackedStringArray) -> void:
	var texture: Texture2D = null
	var texture_id := str(entry.get("texture_id", ""))
	if texture_id.begins_with("res://"):
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
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = -36
	title.offset_right = 36
	title.offset_top = -42
	title.offset_bottom = -4
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_size_override("normal_font_size", 20)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	var tier := str(entry.get("tier", "common")).to_lower()
	title.text = "[center][color=#%s][lb]%s[rb][/color] %s%s[/center]" % [TIER_COLORS.get(tier, TIER_COLORS["common"]), tier.capitalize(), str(entry.get("name", "Boss")), " - LOCKED" if main and not required.is_empty() else ""]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.add_child(title)
	var actor_id := str(entry.get("id", ""))
	sprite.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_preview_selection = actor_id
			_preview_selected_encounter = {"id": actor_id, "texture_id": texture_id, "zone_id": _get_zone_id(), "preview": true}
			_preview_status.text = "PREVIEW: %s\n%s" % [str(entry.get("name", actor_id)), "Locked: " + ", ".join(required) if main and not required.is_empty() else "No authoritative encounter available."]
			_preview_status.visible = true
			_boss_picker.visible = false
			_boss_hp.visible = false
			_boss_status.visible = false
			_boss_open.visible = false
			_world_modal.visible = true)
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.01, 1.01), 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(1.0)
	_preview_tweens.append(tween)

func _clear_guardian_preview() -> void:
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
		_boss_picker.visible = true
		_boss_status.visible = true
		_boss_open.visible = true

func _change_world_art(direction: int) -> void:
	var zone := _get_zone_id()
	var entries: Array = WORLD_ART.get(zone, [])
	if entries.is_empty():
		return
	_world_art_index = posmod(_world_art_index + direction, entries.size())
	var id: String = entries[_world_art_index]
	var path := "res://assets/lab/bosses/%s_common/%s.png" % [zone.trim_prefix("zone_") + "_zone", id]
	_world_sprite.texture = load(path) as Texture2D
	var display_name := id.trim_prefix(zone.trim_prefix("zone_") + "_").replace("_", " ").capitalize()
	_world_name.text = "[center][b][color=#%s][lb]Common[rb][/color] %s[/b][/center]" % [TIER_COLORS["common"], display_name]
	if _world_idle != null:
		_world_idle.kill()
	_world_sprite.scale = Vector2.ONE
	_world_sprite.pivot_offset = Vector2(115, 225)
	_world_idle = create_tween().set_loops()
	_world_idle.tween_property(_world_sprite, "scale", Vector2(1.015, 1.015), 1.2).set_trans(Tween.TRANS_SINE)
	_world_idle.tween_property(_world_sprite, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)
	_world_idle.tween_interval(1.0)

func _refresh_bosses() -> void:
	if _boss_picker == null:
		return
	_boss_picker.clear()
	for boss in _bosses:
		if not boss is Dictionary:
			continue
		var id := str(boss.get("boss_id", ""))
		if id == "":
			continue
		_boss_picker.add_item(str(_db.bosses.get(id, {}).get("name", id)))
		_boss_picker.set_item_metadata(_boss_picker.item_count - 1, boss)
	_boss_picker.disabled = _boss_picker.item_count == 0
	_boss_open.disabled = _boss_picker.disabled
	if _boss_picker.disabled:
		_boss_portrait.texture = null
		_boss_hp.visible = false
		_boss_status.text = "No world boss reported by the server."
		return
	_boss_picker.select(0)
	_on_boss_selected(0)

func _on_boss_selected(index: int) -> void:
	if index < 0 or index >= _boss_picker.item_count:
		return
	var boss: Dictionary = _boss_picker.get_item_metadata(index)
	var id := str(boss.get("boss_id", ""))
	_boss_portrait.texture = _catalog.get_tex(id) if _catalog.has(id) else null
	var hp := float(boss.get("hp", 0))
	var max_hp := maxf(1, float(boss.get("max_hp", 1)))
	_boss_hp.max_value = max_hp
	_boss_hp.value = hp
	_boss_hp.visible = true
	_boss_status.text = "Global encounter  |  HP: %s / %s" % [int(hp), int(max_hp)]

func _open_boss() -> void:
	if _boss_picker.selected < 0:
		return
	var boss: Dictionary = _boss_picker.get_item_metadata(_boss_picker.selected)
	_world_modal.visible = false
	_open_encounters("Boss", str(boss.get("boss_id", "")))

func _open_encounters(tab_name: String, boss_id: String = "") -> void:
	if has_node("GlobalEncounterOverlay"):
		return
	var overlay := Control.new()
	overlay.name = "GlobalEncounterOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 10
	add_child(overlay)
	var gate := (load("res://scenes/ui/WorldGate.tscn") as PackedScene).instantiate()
	gate.embedded_encounters = true
	gate.initial_encounter_tab = tab_name
	gate.initial_boss_id = boss_id
	gate.visual_zone_id = _get_zone_id()
	overlay.add_child(gate)
	gate.anchor_left = 0.08
	gate.anchor_right = 0.92
	gate.anchor_top = 0.08
	gate.anchor_bottom = 0.92
	gate.offset_left = 0
	gate.offset_right = 0
	gate.offset_top = 0
	gate.offset_bottom = 0

func _on_auth_changed(token: String) -> void:
	if token != "":
		_auth_refresh_needed = true
		_request_world_state()

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
	if request_id != "" and _backend.token != "":
		_auth_refresh_needed = false
	if _backend.token == "":
		_backend.ensure_dev_login()
		_set_error("Logging in...")

func _on_api_completed(_request_id: String, ok: bool, data: Dictionary) -> void:
	_gate_clock.sync(int(data.get("server_time_unix_ms", 0)))
	if not ok:
		_set_error(str(data.get("error", "Request failed.")))
		if _boss_status != null and _bosses.is_empty():
			_boss_status.text = "Boss data unavailable. Check the server connection."
		return
	if data.has("world_state"):
		_world_state = data.get("world_state", {})
		var bosses: Variant = _world_state.get("bosses", [])
		_bosses = bosses if bosses is Array else []
		_refresh_bosses()
		var pw = data.get("player_world", null)
		if typeof(pw) == TYPE_DICTIONARY:
			_player_world = pw
		_sync_session()
		_update_labels()
		if _auth_refresh_needed:
			call_deferred("_request_world_state")
		elif pw is Dictionary:
			_clear_error()
		return
	# world_enter response
	if data.has("session_id"):
		_session_id = str(data.get("session_id", ""))
		_update_labels()

func _on_state_updated(state: Dictionary) -> void:
	_update_from_state(state)

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
	var body = {"client_action_id": _make_client_id(), "session_id": _session_id}
	if _backend != null:
		if _backend.request_api("POST", "/world/claim", body, true) == "":
			_set_error("Request in progress. Try again shortly.")

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

func _get_zone_name(zone_id: String) -> String:
	var entry = _db.zones.get(zone_id, {})
	if typeof(entry) == TYPE_DICTIONARY:
		return str(entry.get("display_name", entry.get("name", zone_id)))
	return zone_id

func _sync_session() -> void:
	_session_id = ""
	var sessions = _player_world.get("sessions", {})
	if typeof(sessions) != TYPE_DICTIONARY:
		return
	for sid in sessions.keys():
		var entry = sessions[sid]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("zone_id", "")) == _get_zone_id():
			_session_id = str(sid)
			break

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
	if _loot_label != null:
		var sessions: Variant = _player_world.get("sessions", {})
		var session: Dictionary = sessions.get(_session_id, {}) if sessions is Dictionary else {}
		var loot: Variant = session.get("pending_loot", {})
		var parts: Array[String] = []
		if loot is Dictionary:
			for key in loot:
				parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), loot[key]])
		_loot_label.text = "Stamina: %s  |  Unclaimed loot: %s" % [_player_world.get("stamina", "-"), ", ".join(parts) if not parts.is_empty() else "None"]
	if _enter_button != null:
		_enter_button.disabled = _session_id != "" or _gate_remaining() != 0
		_enter_button.tooltip_text = "World Gate cooldown: %s" % _gate_remaining_text() if _session_id == "" and _gate_remaining() != 0 else ""
	if _farm_button != null:
		_farm_button.disabled = _session_id == ""
	if _claim_button != null:
		_claim_button.disabled = _session_id == ""

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

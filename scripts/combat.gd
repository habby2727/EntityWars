extends Control

const REG_PATH := "res://scripts/data_registry.gd"
const SpellLoadout := preload("res://scripts/domain/spell_loadout.gd")
const CombatLogPresenter := preload("res://scripts/ui/combat_log_presenter.gd")
const CombatTypeIcon := preload("res://scripts/ui/combat_type_icon.gd")
const CombatHomStatus := preload("res://scripts/ui/combat_hom_status.gd")
const CombatInspiration := preload("res://scripts/ui/combat_inspiration.gd")
const PREVIEW_256_DIR := "res://assets/entities/previews_256/"
const HOM_PREVIEW_256_DIR := "res://assets/entities/previews_256/homunculus/"
const BUILD_DIR := "res://assets/entities/builds/"
const GAMEPLAY_ENTITY_DIR := "res://assets/entities/gameplay/"
const GAMEPLAY_HOM_DIR := "res://assets/entities/gameplay/homunculus/"
const ENTITY_GAMEPLAY_MAP := {
	"sulfur": "ignite",
	"mercury": "mercury",
	"vitriol": "vitriol",
	"sodium": "sodium",
	"gold": "gold",
	"aether": "aether",
}
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
const HOM_PREVIEW_STEMS := ["chimera", "cinder", "drakon", "pyro", "silphide", "sodi", "nighty", "mothy"]
const HOM_PREVIEW_MAP := {
	"cinder": "cinder",
	"silphide": "silphide",
	"sodium": "sodi",
	"drakon": "drakon",
	"pyritc": "pyro",
	"chimera": "chimera",
	"nighty": "nighty",
	"mothy": "mothy",
}
const LOG_STEP_SECONDS := 1.0
@export var backend_url := "http://127.0.0.1:8787"

var _reg: Object = null
var _entities: Array = []
var _homunculi: Array = []
var _items: Array = []
var _combat_spell_state := {}
var _log_presenter := CombatLogPresenter.new()
var _spell_detail: AcceptDialog
var _highlights := {"damage": 0, "damage_text": "", "reflection": 0, "reflection_text": ""}
var _spell_damage_totals := {}
var _combat_backend: BackendClient
var _combat_started := false
var _combat_session_invalid := false
var _combat_identity := ""
var _combat_debug := false
# Populated only by a future server-authoritative combat verification flow.
var _verified_combat_match_id := ""
var _reward_action_id := ""
var _reward_request_id := ""
var _reward_label: Label
var _combat_wait_timer: Timer
var _type_effectiveness := {}
var _spell_exchange_active := false
var _resolving_exchange := false
var _spell_acts_second := false
var _animation_tweens := {}
var _animation_original := {}
var _pending_hom_action := {}
var _player_hom_status: PanelContainer
var _enemy_hom_status: PanelContainer
var _hom_details: PanelContainer
var _inspiration_panel: PanelContainer
var _inspiration_cards: Array[Button] = []
var _inspiration_options: Array = []
var _player_inspiration: Control
var _enemy_inspiration: Control
var _ultra_armed := false
var _solo_boss_mode := false
var _solo_context := {}
var _solo_forfeit_request := ""
var _solo_forfeit_action := ""
var _solo_def := {}
var _solo_texture: Texture2D
var _solo_minion_texture: Texture2D
var _solo_minions: Array = []
var _solo_target_index := 0
var _solo_base_hp := 1
var _solo_base_atk := 1
var _solo_summoned := false
var _solo_actions := 0
var _solo_signature := {}
var _solo_intent := "Strike"
var _solo_shield_turns := 0
var _solo_shield_cooldown := 0
var _solo_shield_high := false
var _solo_shield_low := false
var _solo_panel: VBoxContainer
var _solo_status: Label
var _solo_targets: VBoxContainer
var _solo_events: Array = []
var _solo_power_used := false
var _solo_power_active := false
var _solo_power_eligible := 0
var _solo_fury_pending := false
var _solo_power_label: Label

var player := {}
var enemy := {}

var _turn: int = 0
var _round: int = 1
var _battle_index: int = 1
var _player_wins: int = 0
var _enemy_wins: int = 0
var _sudden_death: bool = false
var _player_turn: bool = true
var _battle_over: bool = false
var _step_queue: Array = []
var _processing_steps: bool = false
var _hp_fill_green: StyleBoxFlat = null
var _hp_fill_yellow: StyleBoxFlat = null
var _hp_fill_red: StyleBoxFlat = null

@onready var player_name: Label = $PlayerPanel/PlayerName
@onready var player_entity_name: Label = $PlayerPanel/PlayerEntityNameRow/PlayerEntityName
@onready var player_hom_name: Label = $PlayerPanel/PlayerHomNameRow/PlayerHomName
@onready var player_entity: TextureRect = $PlayerPanel/PlayerSprites/PlayerEntityFrame/PlayerEntity
@onready var player_hom: TextureRect = $PlayerPanel/PlayerSprites/PlayerHomFrame/PlayerHom
@onready var player_hp: ProgressBar = $PlayerPanel/PlayerHPRow/PlayerHP
@onready var player_indicators: Control = $PlayerPanel/PlayerHPRow/PlayerHP/Indicators
@onready var player_item1: TextureRect = $PlayerPanel/PlayerItems/Slot1/PlayerItem1
@onready var player_item2: TextureRect = $PlayerPanel/PlayerItems/Slot2/PlayerItem2

@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_entity_name: Label = $EnemyPanel/EnemyNames/EnemyEntityName
@onready var enemy_hom_name: Label = $EnemyPanel/EnemyNames/EnemyHomName
@onready var enemy_entity: TextureRect = $EnemyPanel/EnemySprites/EnemyEntityFrame/EnemyEntity
@onready var enemy_hom: TextureRect = $EnemyPanel/EnemySprites/EnemyHomFrame/EnemyHom
@onready var enemy_hp: ProgressBar = $EnemyPanel/EnemyHPRow/EnemyHP
@onready var enemy_indicators: Control = $EnemyPanel/EnemyHPRow/EnemyHP/Indicators
@onready var enemy_item1: TextureRect = $EnemyPanel/EnemyItems/Slot1/EnemyItem1
@onready var enemy_item2: TextureRect = $EnemyPanel/EnemyItems/Slot2/EnemyItem2

@onready var log_box: RichTextLabel = $Log
@onready var next_turn_btn: Button = $NextTurn
@onready var switch_weapon_btn: Button = $SwitchWeapon
@onready var ultra_button: Button = $Ultraturn
@onready var hom_decision: HBoxContainer = $HomDecision
@onready var spell_panel: PanelContainer = $SpellPanel
@onready var spell_buttons: Array = [$SpellPanel/SpellGrid/Spell1, $SpellPanel/SpellGrid/Spell2, $SpellPanel/SpellGrid/Spell3, $SpellPanel/SpellGrid/Spell4]
@onready var back_button: Button = $BackButton


@onready var item_tooltip: PanelContainer = $ItemTooltip
@onready var tooltip_label: Label = $ItemTooltip/TooltipLabel
@onready var turn_label: Label = $TurnLabel
@onready var confirm_popup: PopupPanel = $ConfirmLeave
@onready var confirm_stay: Button = $ConfirmLeave/Panel/VBox/Buttons/StayButton
@onready var confirm_leave: Button = $ConfirmLeave/Panel/VBox/Buttons/LeaveButton

func _ready() -> void:
	var configured_url := OS.get_environment("ENTITYWARS_BACKEND_URL").strip_edges().trim_suffix("/")
	if backend_url == "http://127.0.0.1:8787" and not configured_url.is_empty():
		backend_url = configured_url
	_fit_combat_view()
	get_viewport().size_changed.connect(_fit_combat_view)
	_load_registry_safe()
	_setup_combat_log()
	_setup_hp_styles()
	_setup_hom_ui()
	_setup_combat_labels()
	_setup_aligned_health_panels()
	_setup_inspiration_ui()
	_configure_tooltip_text()
	next_turn_btn.pressed.connect(_on_next_turn)
	switch_weapon_btn.pressed.connect(_on_switch_weapon)
	ultra_button.toggled.connect(_on_ultra_toggled)
	$HomDecision/Hold.pressed.connect(_on_hom_choice.bind("hold"))
	$HomDecision/Attack.pressed.connect(_on_hom_choice.bind("attack"))
	$HomDecision/Sacrifice.pressed.connect(_on_hom_choice.bind("sacrifice"))
	_connect_item_tooltips()
	for i in spell_buttons.size():
		spell_buttons[i].pressed.connect(_on_spell_chosen.bind(i))
	_style_spell_buttons()
	next_turn_btn.hide()
	spell_panel.hide()
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if confirm_stay:
		confirm_stay.pressed.connect(_on_confirm_stay)
	if confirm_leave:
		confirm_leave.pressed.connect(_on_confirm_leave)
	_begin_combat_initialization()

func _fit_combat_view() -> void:
	var available := get_viewport_rect().size
	if available.x <= 0 or available.y <= 0:
		return
	var factor := minf(available.x / 1920.0, available.y / 1080.0)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = available / factor
	scale = Vector2.ONE * factor

func _setup_combat_log() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.045, 0.9)
	style.border_color = Color("95834f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	$LogBG.add_theme_stylebox_override("panel", style)
	log_box.add_theme_font_override("normal_font", load("res://assets/fonts/liberation-serif/LiberationSerif-Regular.ttf"))
	log_box.meta_clicked.connect(_on_log_spell_clicked)
	log_box.meta_hover_started.connect(_on_log_spell_hovered)
	log_box.meta_hover_ended.connect(func(_meta): log_box.tooltip_text = "")
	_spell_detail = AcceptDialog.new()
	_spell_detail.title = "Spell Details"
	_spell_detail.dialog_autowrap = true
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.025, 0.055, 0.06, 0.98)
	dialog_style.border_color = Color("ac975e")
	dialog_style.set_border_width_all(2)
	dialog_style.set_content_margin_all(16)
	_spell_detail.add_theme_stylebox_override("panel", dialog_style)
	add_child(_spell_detail)

func _on_log_spell_clicked(meta: Variant) -> void:
	if _reg == null:
		return
	var spell_id := str(meta.get("id", "")) if meta is Dictionary else str(meta)
	var spell: Dictionary = _reg.get_spell_by_id(spell_id)
	if spell.is_empty():
		return
	_spell_detail.dialog_text = _spell_description(spell)
	if meta is Dictionary and meta.get("context") is Dictionary:
		var damage := int(meta.context.get("actual_damage", 0))
		if damage > 0:
			_spell_detail.dialog_text += "\nRecorded damage: %d" % damage
	_spell_detail.popup_centered(Vector2i(440, 260))

func _on_log_spell_hovered(meta: Variant) -> void:
	if _reg != null:
		var spell_id := str(meta.get("id", "")) if meta is Dictionary else str(meta)
		var spell: Dictionary = _reg.get_spell_by_id(spell_id)
		log_box.tooltip_text = _spell_description(spell) if not spell.is_empty() else ""

func _spell_description(spell: Dictionary) -> String:
	var lines: Array[String] = []
	for effect in spell.get("effects", []):
		var extra: Array[String] = []
		for key in effect:
			if key not in ["kind", "value", "target"]:
				extra.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(effect[key])])
		lines.append("%s: %s (%s)%s" % [str(effect.get("kind", "")).replace("_", " ").capitalize(), str(effect.get("value", "")), str(effect.get("target", "")), "; " + ", ".join(extra) if not extra.is_empty() else ""])
	return "%s\nType: %s | %s\nPower: x%.2f | Accuracy: %d%% | Cooldown: %d\n%s\n%s" % [spell.get("name", ""), str(spell.get("type", "")).capitalize(), str(spell.get("category", "")).capitalize(), float(spell.get("power_mult", 0)), int(round(float(spell.get("accuracy", 0)) * 100)), int(spell.get("cooldown_turns", 0)), ", ".join(lines) if not lines.is_empty() else "No additional effects", spell.get("desc", "")]

func _status_effect_text(kind: String, value: float) -> String:
	var label := kind.replace("_", " ").capitalize()
	if kind in ["poison", "hom_stun"]:
		return "%s %dT" % [label, int(value)]
	return "%s %d%%" % [label, roundi(value * 100.0)]

func _begin_combat_initialization() -> void:
	var debug := DebugFlags.new()
	_combat_debug = debug.unlock_all_buildings
	if debug.unlock_all_buildings:
		_combat_spell_state = debug.load_lab_state()
		debug.free()
		_start_combat()
		return
	debug.free()
	_combat_backend = BackendClient.new()
	_combat_backend.base_url = backend_url
	_combat_backend.auto_dev_login = false
	_combat_backend.state_updated.connect(_on_combat_state_updated)
	_combat_backend.api_completed.connect(_on_combat_reward_completed)
	add_child(_combat_backend)
	if _combat_backend.token.is_empty():
		_log_immediate("Offline battle: no online progression loaded.")
		_start_combat()
		return
	_log_immediate("Loading authenticated player state...")
	_wait_for_combat_state()

func _wait_for_combat_state() -> void:
	if _combat_wait_timer == null:
		_combat_wait_timer = Timer.new()
		_combat_wait_timer.one_shot = true
		_combat_wait_timer.timeout.connect(_on_combat_state_timeout)
		add_child(_combat_wait_timer)
	_combat_wait_timer.start(10.0)
	_combat_backend.refresh_state()

func _on_combat_state_timeout() -> void:
	if not _combat_started:
		_log_immediate("Player state unavailable. Press Retry or leave combat.")
		next_turn_btn.text = "Retry"
		next_turn_btn.show()

func _on_combat_state_updated(state: Dictionary) -> void:
	if _combat_started:
		if _combat_identity != "" and (state.is_empty() or str(state.get("player_id", "")) != _combat_identity):
			_restore_inspiration(player)
			_restore_inspiration(enemy)
			_inspiration_panel.hide()
			_combat_session_invalid = true
			_battle_over = true
			spell_panel.hide()
			next_turn_btn.text = "Return"
			next_turn_btn.show()
			_log_immediate("Session changed. Leave combat and authenticate again.")
		return
	if state.is_empty() or _combat_backend._verified_player_id.is_empty():
		return
	if str(state.get("player_id", "")) != _combat_backend._verified_player_id:
		return
	_combat_identity = _combat_backend._verified_player_id
	_combat_spell_state = state.duplicate(true)
	_start_combat()

func _start_combat() -> void:
	if _combat_wait_timer != null:
		_combat_wait_timer.stop()
	_combat_started = true
	next_turn_btn.hide()
	if not _load_player_from_seal():
		_combat_started = false
		_log_immediate("Invalid Boss Hunt loadout. Return and select your equipment again.")
		next_turn_btn.text = "Return"
		next_turn_btn.show()
		return
	_setup_enemy()
	_solo_context = SceneRouter.consume_solo_hunt_context()
	if not _solo_context.is_empty():
		if not str(_solo_context.get("session_id", "")).is_empty() and _combat_backend == null:
			_combat_backend = BackendClient.new()
			_combat_backend.base_url = backend_url
			_combat_backend.auto_dev_login = false
			_combat_backend.api_completed.connect(_on_combat_reward_completed)
			add_child(_combat_backend)
		if not _setup_solo_boss():
			get_tree().call_deferred("change_scene_to_file", SceneRouter.SCENE_WORLD_GATE)
			return
		_apply_world_combat_visuals(str(_solo_context.get("visual_zone_id", "")))
		_prepare_solo_power_turn()
		_prepare_solo_intent()
		_create_solo_panel()
	for pair in [[player_hp, player], [enemy_hp, enemy]]:
		var icon := CombatTypeIcon.new()
		icon.name = "CombatTypeIcon"
		icon.position = Vector2(-30, -3)
		icon.configure(str(pair[1].get("type", "")))
		pair[0].add_child(icon)
	_update_ui()
	_refresh_spell_buttons()
	_log_immediate("Unverified boss preview: no rewards." if _solo_boss_mode else "Battle 1 begins.")

func _apply_world_combat_visuals(zone_id: String) -> void:
	var layouts := {
		"zone_chaos": ["bgcombat1", Vector2(210, 710), Vector2(620, 710), Vector2(1520, 710)],
		"zone_corrupted": ["bgcombat2", Vector2(220, 675), Vector2(610, 665), Vector2(1500, 665)],
		"zone_crystal": ["bgcombat3", Vector2(210, 665), Vector2(610, 665), Vector2(1590, 665)]
	}
	if not layouts.has(zone_id):
		return
	var layout: Array = layouts[zone_id]
	var background := $Background as TextureRect
	background.texture = load("res://assets/lab/resources/world_zones/%s.png" % layout[0]) as Texture2D
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var layer := Control.new()
	layer.name = "WorldCombatSprites"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	move_child(layer, background.get_index() + 1)
	for entry in [[player_hom, layout[1], Vector2(190, 210)], [player_entity, layout[2], Vector2(360, 390)], [enemy_entity, layout[3], Vector2(410, 390)]]:
		var sprite: TextureRect = entry[0]
		var center: Vector2 = entry[1]
		var dimensions: Vector2 = entry[2]
		if sprite == player_hom or sprite == player_entity:
			center.y += 25
		sprite.reparent(layer)
		sprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sprite.position = Vector2(center.x - dimensions.x / 2, center.y - dimensions.y)
		sprite.size = dimensions
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_hom.visible = false
	_player_hom_status.position = Vector2(float(layout[1].x) - 120.0, 710)
	$PlayerPanel/PlayerBottomSpacer.custom_minimum_size.y = 132
	_align_health_panels()

func _on_back_pressed() -> void:
	if confirm_popup == null:
		push_warning("Combat: ConfirmLeave popup missing, leaving combat directly.")
		_leave_combat()
		return
	if confirm_popup.visible:
		return
	confirm_popup.popup_centered()

func _on_confirm_stay() -> void:
	if confirm_popup:
		confirm_popup.hide()

func _on_confirm_leave() -> void:
	if confirm_popup:
		confirm_popup.hide()
	if _solo_boss_mode and not str(_solo_context.get("session_id", "")).is_empty():
		if _resolving_exchange or _processing_steps:
			_log_immediate("Wait for the current exchange before forfeiting.")
			return
		_request_solo_forfeit()
		return
	_leave_combat()

func _request_solo_forfeit() -> void:
	if not _solo_forfeit_request.is_empty():
		return
	if _combat_backend == null or _combat_backend.token.is_empty():
		_log_immediate("Forfeit unavailable: reconnect and retry. Session remains active.")
		return
	if _solo_forfeit_action.is_empty():
		_solo_forfeit_action = _combat_backend._make_uuid()
	_solo_forfeit_request = _combat_backend.request_api("POST", "/world/boss-hunts/forfeit", {"session_id": str(_solo_context.session_id), "client_action_id": _solo_forfeit_action}, false)
	if _solo_forfeit_request.is_empty():
		_log_immediate("Forfeit could not be sent; retry. Session remains active.")
	else:
		_log_immediate("Confirming forfeit with server...")

func _leave_combat() -> void:
	_clear_solo_power()
	_restore_inspiration(player)
	_restore_inspiration(enemy)
	_reset_animations()
	_battle_over = true
	_log_immediate("You forfeited the combat.")
	if _solo_boss_mode:
		_solo_events.append({"turn": _turn, "result": "defeat", "forfeit": true})
		_return_from_solo_hunt()
		return
	if ResourceLoader.exists("res://scenes/LoadoutGrid.tscn"):
		get_tree().change_scene_to_file("res://scenes/LoadoutGrid.tscn")

func _return_from_solo_hunt() -> void:
	var zone := str(_solo_context.get("visual_zone_id", ""))
	if zone in ["zone_chaos", "zone_corrupted", "zone_crystal"]:
		SceneRouter.go_to_world_zone(zone)
	else:
		SceneRouter.go_to_world_gate()

func _configure_tooltip_text() -> void:
	var font := load("res://assets/fonts/liberation-serif/LiberationSerif-Regular.ttf")
	if tooltip_label:
		tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		tooltip_label.add_theme_font_override("font", font)

func _load_registry_safe() -> void:
	if ResourceLoader.exists(REG_PATH):
		var reg_script: Script = load(REG_PATH)
		_reg = reg_script.new()
	if _reg and _reg.has_method("get_entities"):
		_entities = _as_array(_reg.call("get_entities"))
	if _reg and _reg.has_method("get_homunculi"):
		_homunculi = _as_array(_reg.call("get_homunculi"))
	if _reg and _reg.has_method("get_items"):
		_items = _as_array(_reg.call("get_items"))

func _load_player_from_seal() -> bool:
	var mode := SceneRouter.consume_combat_seal_mode()
	var hunt := not SceneRouter._solo_hunt_context.is_empty()
	var data: Dictionary = SceneRouter._hunt_loadout.duplicate(true) if hunt else {}
	SceneRouter._hunt_loadout.clear()
	if hunt:
		var entity_id := str(data.get("entity_id", ""))
		var hom_id := str(data.get("homunculus_id", ""))
		var first := str(data.get("equip_1", ""))
		var second := str(data.get("equip_2", ""))
		if _find_by_id(_entities, entity_id).is_empty() or _find_by_id(_homunculi, hom_id).is_empty():
			return false
		if (not first.is_empty() and _find_by_id(_items, first).is_empty()) or (not second.is_empty() and _find_by_id(_items, second).is_empty()) or (not first.is_empty() and first == second):
			return false
		if not SpellLoadout.valid(_reg, entity_id, _combat_spell_state.get("spell_progress", {}), data.get("spell_ids", [])):
			return false
		player = _build_fighter(data, true)
		return true
	if data.is_empty():
		data = _load_seal(mode)
	if data.is_empty():
		mode = "defense" if mode == "attack" else "attack"
		data = _load_seal(mode)
	if data.is_empty():
		if _entities.size() > 0:
			data["entity_id"] = str(_entities[0].get("id", ""))
		if _homunculi.size() > 0:
			data["homunculus_id"] = str(_homunculi[0].get("id", ""))
		data["equip_1"] = ""
		data["equip_2"] = ""
	var debug := DebugFlags.new()
	var debug_enabled := debug.unlock_all_buildings
	debug.free()
	data["spell_ids"] = SpellLoadout.saved_ids(_reg, _combat_spell_state, mode, str(data.get("entity_id", "")), data, not debug_enabled)
	player = _build_fighter(data, true)
	return true

func _setup_enemy(spell_ids: Array = []) -> void:
	var pick := _pick_enemy_entity(player.get("type", ""))
	var hom_id := _pick_enemy_homunculus_balanced(pick)
	var used: Array[String] = []
	var e1 := _pick_item_id_unique(used)
	if e1 != "":
		used.append(e1)
	var e2 := _pick_item_id_unique(used)
	if e2 != "":
		used.append(e2)
	var data := {
		"entity_id": pick,
		"homunculus_id": hom_id,
		"equip_1": e1,
		"equip_2": e2,
		"spell_ids": spell_ids,
	}
	enemy = _build_fighter(data, false)

func _setup_solo_boss() -> bool:
	var file := FileAccess.open("res://data/static/solo_bosses.json", FileAccess.READ)
	if file == null or int(_solo_context.get("rotation_key", -1)) < 0:
		return false
	var catalog: Variant = JSON.parse_string(file.get_as_text())
	if not catalog is Dictionary or not catalog.get("bosses") is Array:
		return false
	for boss in catalog.bosses:
		if boss is Dictionary and str(boss.get("id", "")) == str(_solo_context.get("hunt_id", "")):
			_solo_def = boss.duplicate(true)
			break
	if str(_solo_def.get("tier", "")) not in ["common", "mythic", "rare", "epic", "legendary"]:
		return false
	var pool: Variant = _solo_def.get("signature_pool", [])
	if not pool is Array or pool.is_empty() or _reg == null:
		return false
	_solo_signature = _reg.get_spell_by_id(str(pool.pick_random()))
	if _solo_signature.is_empty():
		return false
	var assets := AssetCatalog.new()
	var texture_id := str(_solo_def.get("texture_id", ""))
	var requested_texture := str(_solo_context.get("display_texture_id", ""))
	var variants: Variant = _solo_def.get("texture_variants", [])
	if requested_texture == texture_id or (variants is Array and requested_texture in variants):
		texture_id = requested_texture
	_solo_texture = assets.get_tex(texture_id)
	var debug_visual: Variant = _solo_context.get("debug_visual", {})
	if _combat_debug and str(_solo_context.get("session_id", "")).is_empty() and debug_visual is Dictionary and not debug_visual.is_empty():
		var debug_tier := str(debug_visual.get("tier", ""))
		var debug_texture := str(debug_visual.get("texture", ""))
		var zone := str(_solo_context.get("visual_zone_id", ""))
		var allowed := {"mythic": "boss_colossus", "rare": "boss_leviathan", "epic": "boss_temporal", "legendary": "ghost_boss"}
		var accepted := false
		if debug_tier == "common" and zone in ["zone_chaos", "zone_corrupted", "zone_crystal"]:
			var id := str(debug_visual.get("id", ""))
			var world_art: Dictionary = load("res://scripts/ui/world_zone.gd").WORLD_ART
			var path := "res://assets/lab/bosses/%s_zone_common/%s.png" % [zone.trim_prefix("zone_"), id]
			if id in world_art.get(zone, []) and debug_texture == path and ResourceLoader.exists(path):
				_solo_texture = load(path) as Texture2D
				accepted = true
		elif allowed.get(debug_tier, "") == debug_texture and assets.has(debug_texture):
			_solo_texture = assets.get_tex(debug_texture)
			accepted = true
		if accepted:
			_solo_def.name = str(debug_visual.get("name", "Boss")).left(80)
	var minion_texture_id := str(_solo_def.get("minion_texture_id", ""))
	_solo_minion_texture = assets.get_tex(minion_texture_id) if not minion_texture_id.is_empty() else null
	assets.free()
	_solo_boss_mode = true
	enemy.equip_1 = {}
	enemy.equip_2 = {}
	enemy.hom_spent = true
	enemy.hom_id = ""
	enemy.mods = _item_mods([])
	_apply_mods(enemy)
	_solo_base_hp = maxi(1, roundi(float(enemy.max_hp) / float(_solo_def.hp_mult)))
	_solo_base_atk = maxi(1, roundi(float(enemy.atk) / float(_solo_def.attack_mult)))
	enemy.hp = enemy.max_hp
	enemy.name = str(_solo_def.name)
	return true

func _create_solo_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = 220
	panel.offset_bottom = 490
	if has_node("WorldCombatSprites"):
		panel.offset_left = -220
		panel.offset_right = 220
		panel.offset_top = 285
		panel.offset_bottom = 425
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.055, 0.94)
	style.border_color = Color("a9955d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_solo_panel = VBoxContainer.new()
	_solo_panel.add_theme_constant_override("separation", 8)
	panel.add_child(_solo_panel)
	_solo_power_label = Label.new()
	_solo_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_solo_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_solo_power_label.add_theme_color_override("font_color", Color("ffca67"))
	_solo_panel.add_child(_solo_power_label)
	_solo_status = Label.new()
	_solo_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_solo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_solo_panel.add_child(_solo_status)
	_solo_targets = VBoxContainer.new()
	_solo_panel.add_child(_solo_targets)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.text = "Below 50% HP, a Power Turn may appear: deal x2 damage. If the boss survives, its next strike gains tier-scaled Fury. Defeat minions to expose the boss. " + ("Session active / Settlement locked. Local loadout unverified." if not str(_solo_context.get("session_id", "")).is_empty() else "Unverified preview.")
	if has_node("WorldCombatSprites"):
		panel.tooltip_text = help.text
		help.visible = false
	_solo_panel.add_child(help)
	_enemy_hom_status.hide()
	_enemy_inspiration.hide()
	enemy_name.modulate.a = 0.0
	$EnemyPanel/EnemyBuildTitle.modulate.a = 0.0
	$EnemyPanel/EnemyItems.modulate.a = 0.0
	enemy_item1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_item2.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_solo_panel() -> void:
	if not is_instance_valid(_solo_status):
		return
	_solo_power_label.visible = _solo_power_active or _solo_fury_pending
	_solo_power_label.text = "POWER TURN x2\nDEFEAT BOSS NOW OR FACE FURY x%.1f" % float(_solo_def.fury_mult) if _solo_power_active else "FURY PENDING x%.1f" % float(_solo_def.fury_mult)
	_solo_status.text = "%s | %s\nBoss Intent: %s\nShield: %d%% | %d turns\n%s" % [str(_solo_def.get("name", "Boss")), str(_solo_def.get("tier", "")).to_upper(), _solo_intent, roundi(float(_solo_def.shield_reduction) * 100.0) if _solo_shield_turns > 0 else 0, _solo_shield_turns, "Boss Protected - Kill Minions" if _solo_has_minions() else "Boss vulnerable"]
	for child in _solo_targets.get_children():
		_solo_targets.remove_child(child)
		child.queue_free()
	for i in _solo_minions.size():
		var minion: Dictionary = _solo_minions[i]
		if int(minion.hp) <= 0:
			continue
		var button := Button.new()
		button.icon = _solo_minion_texture
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
		button.text = "%s: %d / %d HP%s" % [minion.name, minion.hp, minion.max_hp, " [TARGET]" if i == _solo_target_index else ""]
		button.disabled = _resolving_exchange or _battle_over
		button.pressed.connect(_select_solo_target.bind(i))
		_solo_targets.add_child(button)

func _select_solo_target(index: int) -> void:
	if not _resolving_exchange and index >= 0 and index < _solo_minions.size() and _solo_minions[index].hp > 0:
		_solo_target_index = index
		_update_solo_panel()

func _solo_has_minions() -> bool:
	for minion in _solo_minions:
		if int(minion.hp) > 0:
			return true
	return false

func _solo_target() -> Dictionary:
	if _solo_target_index >= 0 and _solo_target_index < _solo_minions.size() and _solo_minions[_solo_target_index].hp > 0:
		return _solo_minions[_solo_target_index]
	for i in _solo_minions.size():
		if _solo_minions[i].hp > 0:
			_solo_target_index = i
			return _solo_minions[i]
	return enemy

func _clear_solo_power() -> void:
	_solo_power_active = false
	_solo_fury_pending = false
	_solo_power_used = false
	_solo_power_eligible = 0

func _prepare_solo_power_turn(roll: float = -1.0) -> void:
	_solo_power_active = false
	if not _solo_boss_mode or _solo_power_used or _battle_over or player.hp <= 0 or enemy.hp <= 0 or float(enemy.hp) >= float(enemy.max_hp) * 0.5 or _solo_has_minions() or _solo_shield_turns > 0:
		return
	_solo_power_eligible += 1
	var activate := _solo_power_eligible >= 4
	if not activate:
		activate = (randf() if roll < 0.0 else roll) < 0.35
	if activate:
		_solo_power_used = true
		_solo_power_active = true
		_solo_events.append({"turn": _turn + 1, "power_turn": true})
		_log_immediate("POWER TURN x2 - Defeat the boss now or face Fury x%.1f." % float(_solo_def.fury_mult))

func _prepare_solo_intent() -> void:
	var ratio := float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
	if _solo_fury_pending:
		_solo_intent = "FURY STRIKE"
	elif _solo_has_minions():
		_solo_intent = "Strike"
	elif not _solo_summoned and int(_solo_def.minions) > 0 and (_solo_actions >= 2 or ratio < 0.7):
		_solo_intent = "Summon"
	elif enemy.hp < enemy.max_hp and _solo_shield_turns == 0 and _solo_shield_cooldown == 0 and ((ratio > 0.5 and not _solo_shield_high) or (ratio <= 0.5 and not _solo_shield_low)):
		_solo_intent = "Shield"
	elif _solo_actions % 2 == 1 and int(enemy.spell_cooldowns.get(_solo_signature.id, 0)) == 0:
		_solo_intent = "Special"
	else:
		_solo_intent = "Strike"

func _solo_summon() -> void:
	_solo_summoned = true
	var ratios := {"mythic": 0.18, "rare": 0.20, "epic": 0.25, "legendary": 0.30}
	for i in int(_solo_def.minions):
		var minion := enemy.duplicate(true)
		minion.name = "Minion %d" % (i + 1)
		minion.type = ""
		minion.max_hp = maxi(1, roundi(_solo_base_hp * float(ratios.get(_solo_def.tier, 0.0))))
		minion.hp = minion.max_hp
		minion.atk = maxi(1, roundi(_solo_base_atk * 0.25))
		minion.status = {"poison": 0, "stun": 0, "shield_pct": 0.0, "atk_boost": 0.0, "vuln_pct": 0.0, "atk_down": 0.0, "hom_stun": 0, "reflect_pct": 0.0, "tempo_bonus": 0.0}
		_solo_minions.append(minion)
	_solo_target_index = 0

func _solo_boss_action() -> void:
	_solo_actions += 1
	var intent := _solo_intent
	_solo_events.append({"turn": _turn, "intent": intent})
	if intent == "Special":
		await _resolve_spell_action(enemy, player, {"kind": "spell", "spell": _solo_signature})
		return
	for key in enemy.spell_cooldowns.keys():
		enemy.spell_cooldowns[key] = maxi(0, int(enemy.spell_cooldowns[key]) - 1)
	if int(enemy.status.stun) > 0:
		_log_step("%s is stunned." % enemy.name, func(): enemy.status.stun -= 1)
	elif intent == "Summon":
		_log_step("%s summons minions." % enemy.name, _solo_summon)
	elif intent == "Shield":
		_log_step("%s raises a shield." % enemy.name, func():
			_solo_shield_turns = int(_solo_def.shield_turns)
			if float(enemy.hp) > float(enemy.max_hp) * 0.5:
				_solo_shield_high = true
			else:
				_solo_shield_low = true
		)
	else:
		var ratio := float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
		var fury := float(_solo_def.fury_mult) if intent == "FURY STRIKE" and _solo_fury_pending else (1.0 if ratio > 0.7 else 1.2 if ratio > 0.4 else 1.4 if ratio > 0.15 else 1.6)
		if intent == "FURY STRIKE":
			_solo_fury_pending = false
		elif _solo_has_minions():
			fury *= 0.5
		_attack_entity(enemy, player, fury, 0.9, true)
	await _flush_steps()

func _solo_player_action(action: Dictionary) -> void:
	var target := _solo_target()
	await _resolve_spell_action(player, target, action)
	if player.hp > 0 and (target.hp > 0 or action.get("hom", "hold") == "sacrifice"):
		await _resolve_hom_choice(player, target, str(action.get("hom", "hold")))

func _resolve_solo_exchange(action: Dictionary) -> void:
	_turn += 1
	_begin_spell_exchange()
	var shield_active_at_start := _solo_shield_turns > 0
	var minions_at_start := _solo_minions.duplicate()
	if _initiative(player) >= _initiative(enemy):
		await _solo_player_action(action)
		if _combat_session_invalid:
			return
		if player.hp > 0 and enemy.hp > 0:
			await _solo_boss_action()
	else:
		await _solo_boss_action()
		if _combat_session_invalid:
			return
		if player.hp > 0 and enemy.hp > 0:
			await _solo_player_action(action)
	if _combat_session_invalid:
		return
	for minion in minions_at_start:
		if player.hp <= 0 or enemy.hp <= 0:
			break
		if minion.hp > 0:
			_attack_entity(minion, player, 1.0, 0.9, true)
			await _flush_steps()
	if player.hp > 0:
		_apply_spell_poison(player)
		_apply_spell_poison(enemy)
		for minion in _solo_minions:
			if minion.hp > 0:
				_apply_spell_poison(minion)
		await _flush_steps()
	_charge_homunculus(player)
	await _flush_steps()
	_end_spell_exchange()
	if _solo_power_active:
		_solo_power_active = false
		if enemy.hp > 0 and player.hp > 0:
			_solo_fury_pending = true
			_log_immediate("FURY PENDING x%.1f on the boss's next strike." % float(_solo_def.fury_mult))
	if shield_active_at_start and _solo_shield_turns > 0:
		_solo_shield_turns -= 1
		if _solo_shield_turns == 0:
			_solo_shield_cooldown = 3
	elif _solo_shield_turns == 0 and _solo_shield_cooldown > 0:
		_solo_shield_cooldown -= 1
	if player.hp <= 0 or (enemy.hp <= 0 and not _solo_has_minions()):
		_check_end()
		return
	_player_turn = not _player_turn
	if not _player_turn:
		_round += 1
		_apply_round_start_effects()
		await _flush_steps()
		_apply_round_winner_tempo()
		await _flush_steps()

func _build_fighter(data: Dictionary, _is_player: bool) -> Dictionary:
	var ent := _find_by_id(_entities, str(data.get("entity_id", "")))
	var entity_id := str(ent.get("id", ""))
	var requested_spells: Variant = data.get("spell_ids", [])
	var progress: Dictionary = _combat_spell_state.get("spell_progress", {})
	var fighter_spells: Array
	if _is_player:
		fighter_spells = SpellLoadout.repair(_reg, entity_id, progress, requested_spells)
	else:
		fighter_spells = requested_spells.duplicate() if SpellLoadout.valid(_reg, entity_id, {}, requested_spells, true) else SpellLoadout.initial_ids(_reg, entity_id)
	var hom := _find_by_id(_homunculi, str(data.get("homunculus_id", "")))
	var stats := _get_base_stats(ent)
	var hom_progress: Dictionary = _combat_spell_state.get("homunculus_progress", {}) if _is_player else {}
	var effective := preload("res://scripts/domain/homunculus_progress.gd").effective_bonuses(hom, hom_progress)
	var synergy: Dictionary = hom.get("per_type", {}).get(str(ent.get("type", "")), {})
	var buffs := {"atk": int(effective.get("power_flat", 0)) + int(synergy.get("power_flat", 0)), "def": int(effective.get("guard_flat", 0)) + int(synergy.get("guard_flat", 0)), "hp": int(effective.get("hp_flat", 0))}
	var atk = stats.atk + buffs.atk
	var def = stats.def + buffs.def
	var hp = stats.hp + buffs.hp

	var equip1 = _find_by_id(_items, str(data.get("equip_1", "")))
	var equip2 = _find_by_id(_items, str(data.get("equip_2", "")))
	if _is_player:
		var progress_items: Dictionary = _combat_spell_state.get("item_progress", {})
		var helper = preload("res://scripts/domain/item_progress.gd")
		equip1 = helper.effective_item(equip1, progress_items)
		equip2 = helper.effective_item(equip2, progress_items)

	var scaled := _scaled_hom_weapon(equip1, synergy)
	var mods = _item_mods([scaled])
	var fx = _collect_item_effects([scaled])
	atk += mods.atk_flat
	def += mods.def_flat

	return {
		"id": str(ent.get("id", "")),
		"name": str(ent.get("name", "")),
		"type": str(ent.get("type", "")),
		"hom_id": str(hom.get("id", "")),
		"hom_name": str(hom.get("name", "")),
		"hom_data": hom.duplicate(true), "hom_progress": hom_progress.duplicate(true), "hom_synergy": synergy.duplicate(true),
		"hom_energy": 0,
		"hom_max_energy": 6,
		"hom_ready_at": 3,
		"hom_spent": hom.is_empty(),
		"atk": atk,
		"def": def,
		"max_hp": hp,
		"hp": hp,
		"mods": mods,
		"item_fx": fx,
		"equip_1": equip1,
		"equip_2": equip2,
		"active_weapon_slot": 1,
		"npc_weapon_switched": false,
		"spell_ids": fighter_spells,
		"original_spell_ids": fighter_spells.duplicate(),
		"inspiration": 0,
		"inspiration_used_this_battle": false,
		"inspiration_pending": false,
		"temporary_spell_id": "",
		"temporary_replaced_slot": -1,
		"ultra_used": false,
		"status": {"poison": 0, "stun": 0, "shield_pct": 0.0, "atk_boost": 0.0, "vuln_pct": 0.0, "atk_down": 0.0, "hom_stun": 0, "reflect_pct": 0.0, "tempo_bonus": 0.0},
		"spell_cooldowns": {}, "spell_hit_this_exchange": false, "spell_hit_last_exchange": false,
		"spell_neutralize_pending": 0.0, "spell_neutralize_active": 0.0
	}

func _update_ui() -> void:
	if is_instance_valid(_hom_details) and _hom_details.visible:
		_hom_details.call("refresh")
	_player_inspiration.call("set_fighter", player)
	_enemy_inspiration.call("set_fighter", enemy)
	_player_hom_status.call("set_fighter", player)
	_enemy_hom_status.call("set_fighter", enemy)
	player_hom.visible = not bool(player.get("hom_spent", false))
	enemy_hom.visible = not has_node("WorldCombatSprites") and not bool(enemy.get("hom_spent", false))
	for pair in [[player_hp, player], [enemy_hp, enemy]]:
		var icon: Node = pair[0].get_node_or_null("CombatTypeIcon")
		if icon != null and str(icon.get("element")) != str(pair[1].get("type", "")):
			icon.call("configure", str(pair[1].get("type", "")))
	player_indicators.set_fighter(_player_wins, player)
	enemy_indicators.set_fighter(_enemy_wins, enemy)
	var header = "Sudden Death" if _sudden_death else "Battle %d" % _battle_index
	turn_label.text = "%s\nTurn %d" % [header, _display_turn()]
	player_name.text = "Player"
	player_entity_name.text = str(player.get("name", ""))
	player_hom_name.text = ""
	enemy_name.text = "NPC"
	enemy_entity_name.text = str(enemy.get("name", ""))
	enemy_hom_name.text = ""
	player_hp.max_value = float(player.get("max_hp", 1))
	player_hp.value = float(player.get("hp", 1))
	enemy_hp.max_value = float(enemy.get("max_hp", 1))
	enemy_hp.value = float(enemy.get("hp", 1))
	player_hp.get_node("HealthValue").text = "%d / %d" % [int(player.hp), int(player.max_hp)]
	enemy_hp.get_node("HealthValue").text = "%d / %d" % [int(enemy.hp), int(enemy.max_hp)]
	player_entity.texture = _load_preview_tex(player.get("id", ""), "entity", player.get("type", ""))
	player_hom.texture = _load_preview_tex(player.get("hom_id", ""), "homunculus", player.get("hom_name", ""))
	enemy_entity.texture = _load_preview_tex(enemy.get("id", ""), "entity", enemy.get("type", ""))
	enemy_hom.texture = _load_preview_tex(enemy.get("hom_id", ""), "homunculus", enemy.get("hom_name", ""))
	if _solo_boss_mode:
		enemy_entity.texture = _solo_texture
		enemy_name.text = "BOSS - %s" % str(_solo_def.get("tier", "")).to_upper()
		turn_label.text = "Boss Hunt\nTurn %d" % _display_turn()
		enemy_indicators.visible = false
		_update_solo_panel()
	_set_item_icon(player_item1, player.get("equip_1", {}))
	_set_item_icon(player_item2, player.get("equip_2", {}))
	_set_item_icon(enemy_item1, enemy.get("equip_1", {}))
	_set_item_icon(enemy_item2, enemy.get("equip_2", {}))
	_update_weapon_slots(player, [player_item1, player_item2])
	_update_weapon_slots(enemy, [enemy_item1, enemy_item2])
	_apply_hp_colors()

func _get_active_weapon(fighter: Dictionary) -> Dictionary:
	return _scaled_hom_weapon(fighter.get("equip_%d" % int(fighter.get("active_weapon_slot", 1)), {}), _hom_synergy(fighter))

func _hom_synergy(fighter: Dictionary) -> Dictionary:
	return {} if bool(fighter.get("hom_spent", true)) else fighter.get("hom_synergy", {})

func _scaled_hom_weapon(item: Dictionary, synergy: Dictionary) -> Dictionary:
	var multiplier := clampf(float(synergy.get("item_effect_mult", 1.0)), 0.0, 2.0)
	if item.is_empty() or is_equal_approx(multiplier, 1.0):
		return item
	var result := item.duplicate(true)
	var effects: Dictionary = result.get("effects", {})
	for key in effects:
		var values: Variant = effects[key]
		if values is Array and not values.is_empty() and (values[0] is int or values[0] is float):
			values[0] = float(values[0]) * multiplier
	return result

func _set_active_weapon(fighter: Dictionary, slot: int) -> void:
	if slot not in [1, 2] or fighter.get("equip_%d" % slot, {}).is_empty():
		return
	for field in ["shield_pct", "reflect_pct"]:
		var key: String = "weapon_" + field
		if fighter.has(key):
			fighter.status[field] = float(fighter.get("other_" + field, 0.0))
			fighter.erase(key)
			fighter.erase("other_" + field)
	fighter.active_weapon_slot = slot
	_refresh_weapon_stats(fighter)

func _weapon_defense(fighter: Dictionary, field: String, value: float) -> void:
	var key := "weapon_" + field
	if not fighter.has(key):
		fighter["other_" + field] = float(fighter.status.get(field, 0.0))
	fighter[key] = maxf(float(fighter.get(key, 0.0)), value)
	fighter.status[field] = maxf(float(fighter["other_" + field]), float(fighter[key]))

func _other_defense(fighter: Dictionary, field: String, value: float) -> void:
	if field == "reflect_pct" and fighter.has("hom_reflect_active") and not bool(fighter.get("recording_hom_reflect", false)):
		fighter.hom_other_reflect = maxf(float(fighter.get("hom_other_reflect", 0.0)), value)
	if fighter.has("weapon_" + field):
		fighter["other_" + field] = maxf(float(fighter.get("other_" + field, 0.0)), value)
	fighter.status[field] = maxf(float(fighter.status.get(field, 0.0)), value)

func _clear_defense(fighter: Dictionary, field: String) -> void:
	if field == "reflect_pct":
		fighter.erase("hom_reflect_active")
		fighter.erase("hom_other_reflect")
	fighter.status[field] = 0.0
	fighter.erase("weapon_" + field)
	fighter.erase("other_" + field)

func _refresh_weapon_stats(fighter: Dictionary) -> void:
	fighter.mods = _item_mods([_get_active_weapon(fighter)])
	_apply_mods(fighter)

func _update_weapon_slots(fighter: Dictionary, slots: Array) -> void:
	for i in 2:
		var slot: Control = slots[i].get_parent()
		var active := int(fighter.get("active_weapon_slot", 1)) == i + 1
		slot.modulate = Color.WHITE if active else Color(0.55, 0.55, 0.55, 0.8)
		var label := slot.get_node_or_null("ActiveWeapon") as Label
		if label == null:
			label = Label.new()
			label.name = "ActiveWeapon"
			label.text = "ACTIVE"
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color("7af1ef"))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.position = Vector2(35, 8)
			slot.add_child(label)
			_add_label_plaque(label)
			var plaque := label.get_node("LabelPlaque") as TextureRect
			plaque.offset_left = -55
			plaque.offset_right = 55
			plaque.offset_top = -4
			plaque.offset_bottom = 21
		label.visible = active and not _get_active_weapon(fighter).is_empty()

func _setup_hp_styles() -> void:
	_hp_fill_green = StyleBoxFlat.new()
	_hp_fill_green.bg_color = Color(0.2, 0.85, 0.35, 1.0)
	_hp_fill_yellow = StyleBoxFlat.new()
	_hp_fill_yellow.bg_color = Color(0.95, 0.8, 0.2, 1.0)
	_hp_fill_red = StyleBoxFlat.new()
	_hp_fill_red.bg_color = Color(0.9, 0.2, 0.2, 1.0)
	for bar in [player_hp, enemy_hp]:
		bar.custom_minimum_size.y = 22
		var background := StyleBoxFlat.new()
		background.bg_color = Color("15232a")
		background.border_color = Color("b9a66c")
		background.set_border_width_all(2)
		background.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", background)
		bar.show_percentage = false
		bar.tooltip_text = "Entity health"
		var value_label := Label.new()
		value_label.name = "HealthValue"
		value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", Color.WHITE)
		value_label.add_theme_color_override("font_outline_color", Color.BLACK)
		value_label.add_theme_constant_override("outline_size", 2)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(value_label)
	for fill in [_hp_fill_green, _hp_fill_yellow, _hp_fill_red]:
		fill.set_corner_radius_all(3)

func _setup_hom_ui() -> void:
	_player_hom_status = CombatHomStatus.new()
	_player_hom_status.position = Vector2(28, 540)
	add_child(_player_hom_status)
	_enemy_hom_status = CombatHomStatus.new()
	_enemy_hom_status.position = Vector2(1652, 540)
	add_child(_enemy_hom_status)
	_hom_details = preload("res://scripts/ui/combat_hom_details.gd").new()
	add_child(_hom_details)
	for entry in [[player_hom, true], [enemy_hom, false], [_player_hom_status, true], [_enemy_hom_status, false]]:
		var control: Control = entry[0]
		control.mouse_filter = Control.MOUSE_FILTER_PASS
		control.gui_input.connect(_on_hom_details_input.bind(bool(entry[1])))

func _on_hom_details_input(event: InputEvent, is_player: bool) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var fighter := player if is_player else enemy
		if not fighter.is_empty():
			_hom_details.call("show_fighter", fighter, player_hom.texture if is_player else enemy_hom.texture, "Player" if is_player else "NPC")

func _setup_combat_labels() -> void:
	for label in [player_name, enemy_name, $PlayerPanel/PlayerBuildTitle, $EnemyPanel/EnemyBuildTitle, turn_label]:
		if label == player_name or label == enemy_name:
			label.custom_minimum_size.x = 130
			label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_add_label_plaque(label)
		var plaque := label.get_node("LabelPlaque") as TextureRect
		if label == player_name or label == enemy_name:
			plaque.offset_left = -70
			plaque.offset_right = 70
		elif label == turn_label:
			plaque.offset_left = -150
			plaque.offset_right = 150
			plaque.offset_bottom = 56
	for label in [player_entity_name, enemy_entity_name]:
		var panel := Panel.new()
		panel.name = "HealthPanel"
		panel.show_behind_parent = true
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.offset_left = -145
		panel.offset_right = 112
		panel.offset_top = -5
		panel.offset_bottom = 52
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.06, 0.07, 0.94)
		style.border_color = Color("a9955d")
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		panel.add_theme_stylebox_override("panel", style)
		label.add_child(panel)

func _setup_aligned_health_panels() -> void:
	var player_name_row := player_entity_name.get_parent() as Control
	var player_hp_row := player_hp.get_parent() as Control
	var enemy_hp_row := enemy_hp.get_parent() as Control
	player_name_row.custom_minimum_size.y = 22
	player_hp_row.custom_minimum_size.y = 22
	enemy_hp_row.custom_minimum_size.y = 22
	for pair in [[player_entity_name, player_hp], [enemy_entity_name, enemy_hp]]:
		var group := Control.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.size = Vector2(200, 44)
		add_child(group)
		pair[0].reparent(group, false)
		pair[1].reparent(group, false)
		pair[0].custom_minimum_size = Vector2(200, 22)
		pair[0].position = Vector2.ZERO
		pair[0].size = Vector2(200, 22)
		pair[1].position = Vector2(0, 22)
		pair[1].size = Vector2(200, 22)
		group.name = "PlayerHealthGroup" if pair[0] == player_entity_name else "EnemyHealthGroup"
	call_deferred("_align_health_panels")
	get_viewport().size_changed.connect(_align_health_panels, CONNECT_DEFERRED)

func _align_health_panels() -> void:
	var inverse := get_global_transform().affine_inverse()
	var player_center: Vector2 = inverse * player_entity.get_global_rect().get_center()
	var enemy_center: Vector2 = inverse * enemy_entity.get_global_rect().get_center()
	var health_y := 690 if has_node("WorldCombatSprites") else 610
	$PlayerHealthGroup.position = Vector2(player_center.x - 100, health_y)
	$EnemyHealthGroup.position = Vector2(enemy_center.x - 100, health_y)

func _setup_inspiration_ui() -> void:
	_player_inspiration = CombatInspiration.new()
	_player_inspiration.position = Vector2(0, -32)
	$PlayerHealthGroup.add_child(_player_inspiration)
	_enemy_inspiration = CombatInspiration.new()
	_enemy_inspiration.position = Vector2(0, -32)
	$EnemyHealthGroup.add_child(_enemy_inspiration)
	_inspiration_panel = PanelContainer.new()
	_inspiration_panel.name = "InspirationSelection"
	_inspiration_panel.set_anchors_preset(Control.PRESET_CENTER)
	_inspiration_panel.position = Vector2(-455, -200)
	_inspiration_panel.custom_minimum_size = Vector2(910, 400)
	_inspiration_panel.z_index = 150
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.06, 0.98)
	style.border_color = Color("d4af37")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	_inspiration_panel.add_theme_stylebox_override("panel", style)
	add_child(_inspiration_panel)
	var column := VBoxContainer.new()
	column.name = "Content"
	column.add_theme_constant_override("separation", 8)
	_inspiration_panel.add_child(column)
	var title := Label.new()
	title.text = "INSPIRATION - Choose a temporary spell"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("d4af37"))
	column.add_child(title)
	var info := Label.new()
	info.text = "Choose one spell. It replaces a random equipped spell until this battle ends."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	column.add_child(info)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)
	for i in 3:
		var button := Button.new()
		button.custom_minimum_size = Vector2(275, 280)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_choose_inspiration.bind(i))
		var icon := CombatTypeIcon.new()
		icon.name = "TypeIcon"
		icon.position = Vector2(10, 8)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		cards.add_child(button)
		_inspiration_cards.append(button)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "Cancel"
	cancel.tooltip_text = "Keep your current spells. Inspiration will be consumed and cannot be used again this battle."
	cancel.custom_minimum_size = Vector2(180, 40)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		cancel.add_theme_stylebox_override(state, next_turn_btn.get_theme_stylebox(state))
	cancel.pressed.connect(_on_inspiration_cancel)
	column.add_child(cancel)
	_inspiration_panel.hide()

func _award_inspiration(caster: Dictionary, recipient: Dictionary, kind: String) -> void:
	if is_same(caster, recipient) or bool(caster.get("inspiration_used_this_battle", false)):
		return
	var previous := int(caster.get("inspiration", 0))
	if previous >= 3:
		return
	caster.inspiration = previous + 1
	caster.inspiration_pending = caster.inspiration == 3
	var text := " gains inspiration (%d/3) from %s." % [caster.inspiration, kind.replace("_", " ")]
	_append_combat_log("", _combat_event(caster, "inspiration", text, {}))
	if caster.inspiration_pending:
		_append_combat_log("", _combat_event(caster, "inspiration", " reaches 3/3 inspiration.", {}))

func _inspiration_candidates(fighter: Dictionary) -> Array:
	var candidates := []
	if _reg == null:
		return candidates
	var element := str(fighter.get("type", ""))
	for spell in _reg.get_spells_for_type(element) + _reg.get_spells_for_type("hybrid"):
		if (spell.get("type") == element or (spell.get("type") == "hybrid" and spell.get("primary_type") == element)) and spell.id not in fighter.get("spell_ids", []):
			candidates.append(spell)
	candidates.shuffle()
	return candidates.slice(0, 3)

func _finish_inspiration_exchange() -> void:
	if _battle_over or _combat_session_invalid or _processing_steps or _resolving_exchange or _inspiration_panel.visible or player.hp <= 0 or enemy.hp <= 0:
		return
	if bool(enemy.get("inspiration_pending", false)):
		var options := _inspiration_candidates(enemy)
		if options.size() == 3:
			_append_combat_log("", _combat_event(enemy, "inspiration", " considers three temporary spells.", {}))
			var best: Dictionary = options[0]
			var best_score := -1.0
			for option in options:
				var score := float(option.get("power_mult", 0.0)) + randf() * 0.15
				for effect in option.get("effects", []):
					if effect.kind == "heal" and enemy.hp < enemy.max_hp * 0.5:
						score += 2.0
					elif effect.kind == "poison" and player.status.poison <= 0:
						score += 0.6
				if score > best_score:
					best_score = score
					best = option
			_replace_inspiration_spell(enemy, best)
	if bool(player.get("inspiration_pending", false)):
		_inspiration_options = _inspiration_candidates(player)
		if _inspiration_options.size() != 3:
			push_warning("Inspiration: fewer than three eligible spells")
			return
		_append_combat_log("", _combat_event(player, "inspiration", " can choose one of three temporary spells.", {}))
		for i in 3:
			var spell: Dictionary = _inspiration_options[i]
			var elements := str(spell.get("primary_type", spell.type)).capitalize()
			if spell.type == "hybrid":
				elements += " + " + str(spell.get("secondary_type", "")).capitalize()
			var details := _spell_description(spell)
			_inspiration_cards[i].text = elements + "\n\n" + details
			_inspiration_cards[i].tooltip_text = details
			_inspiration_cards[i].get_node("TypeIcon").call("configure", str(spell.get("primary_type", spell.type)))
		_inspiration_panel.show()
		_refresh_spell_buttons()
	_update_ui()

func _choose_inspiration(index: int) -> void:
	if not _inspiration_panel.visible or index < 0 or index >= _inspiration_options.size() or not bool(player.get("inspiration_pending", false)):
		return
	var choice: Dictionary = _inspiration_options[index]
	_inspiration_panel.hide()
	_inspiration_options.clear()
	_replace_inspiration_spell(player, choice)
	_update_ui()
	_refresh_spell_buttons()

func _on_inspiration_cancel() -> void:
	if not _inspiration_panel.visible or not bool(player.get("inspiration_pending", false)) or _inspiration_options.size() != 3 or bool(player.get("inspiration_used_this_battle", false)):
		return
	_inspiration_panel.hide()
	_inspiration_options.clear()
	player.inspiration_pending = false
	player.inspiration_used_this_battle = true
	player.inspiration = 0
	_append_combat_log("", _combat_event(player, "inspiration", " declines Inspiration; the existing four spells are preserved.", {}))
	_update_ui()
	_refresh_spell_buttons()

func _replace_inspiration_spell(fighter: Dictionary, spell: Dictionary) -> void:
	if not bool(fighter.get("inspiration_pending", false)) or bool(fighter.get("inspiration_used_this_battle", false)) or fighter.get("spell_ids", []).size() != 4:
		return
	var slot := randi() % 4
	var old_id := str(fighter.spell_ids[slot])
	var old_spell: Dictionary = _reg.get_spell_by_id(old_id)
	fighter.original_spell_ids = fighter.spell_ids.duplicate()
	fighter.temporary_replaced_slot = slot
	fighter.temporary_spell_id = str(spell.id)
	fighter.spell_ids[slot] = str(spell.id)
	fighter.inspiration_used_this_battle = true
	fighter.inspiration_pending = false
	_append_combat_log("", _combat_event(fighter, "inspiration", " chooses %s: %s replaced until this battle ends." % [spell.name, old_spell.get("name", old_id)], {}))

func _restore_inspiration(fighter: Dictionary) -> void:
	if fighter.is_empty():
		return
	if not str(fighter.get("temporary_spell_id", "")).is_empty():
		fighter.spell_ids = fighter.get("original_spell_ids", []).duplicate()
		_append_combat_log("", _combat_event(fighter, "inspiration", " restores the original spell loadout.", {}))
	fighter.original_spell_ids = fighter.get("spell_ids", []).duplicate()
	fighter.temporary_spell_id = ""
	fighter.temporary_replaced_slot = -1
	fighter.inspiration = 0
	fighter.inspiration_pending = false
	fighter.inspiration_used_this_battle = false

func _add_label_plaque(label: Label, centered: bool = true) -> void:
	var plaque := TextureRect.new()
	plaque.name = "LabelPlaque"
	plaque.show_behind_parent = true
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.texture = load("res://assets/ui/new-elements/boton-loadout-opciones.png")
	plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if centered:
		plaque.anchor_left = 0.5
		plaque.anchor_right = 0.5
		plaque.offset_left = -100
		plaque.offset_right = 100
	else:
		plaque.offset_left = -25
		plaque.offset_right = 110
	plaque.offset_top = -7
	plaque.offset_bottom = 33
	label.add_child(plaque)

func _apply_hp_colors() -> void:
	_apply_hp_color(player_hp, player)
	_apply_hp_color(enemy_hp, enemy)

func _apply_hp_color(bar: ProgressBar, f: Dictionary) -> void:
	if bar == null:
		return
	var max_hp := float(f.get("max_hp", 1))
	if max_hp <= 0.0:
		max_hp = 1.0
	var cur_hp := float(f.get("hp", 0))
	var pct := cur_hp / max_hp
	var fill: StyleBoxFlat = _hp_fill_green
	if pct < 0.25:
		fill = _hp_fill_red
	elif pct < 0.5:
		fill = _hp_fill_yellow
	bar.add_theme_stylebox_override("fill", fill)

func _on_next_turn() -> void:
	if not _combat_started and _combat_backend != null:
		next_turn_btn.hide()
		_log_immediate("Retrying player state...")
		_wait_for_combat_state()
		return
	if _battle_over and not _processing_steps and _solo_boss_mode:
		_return_from_solo_hunt()
		return
	if _battle_over and not _processing_steps and ResourceLoader.exists("res://scenes/LoadoutGrid.tscn"):
		get_tree().change_scene_to_file("res://scenes/LoadoutGrid.tscn")

func _on_spell_chosen(index: int) -> void:
	if _resolving_exchange or _processing_steps or _battle_over or not _solo_forfeit_request.is_empty() or _inspiration_panel.visible:
		return
	var options := _fighter_spell_options(player)
	if index < 0 or index >= options.size():
		return
	var chosen: Dictionary = options[index]
	if int(player.spell_cooldowns.get(chosen.id, 0)) > 0:
		return
	var action := {"kind": "spell", "spell": chosen, "ultra": _ultra_armed and _ultra_available(player)}
	_ultra_armed = false
	await _queue_combat_action(action)

func _ultra_available(fighter: Dictionary) -> bool:
	return not _solo_boss_mode and _battle_index == 3 and _player_wins == 1 and _enemy_wins == 1 and not _sudden_death and not bool(fighter.get("ultra_used", false))

func _on_ultra_toggled(armed: bool) -> void:
	_ultra_armed = armed and _ultra_available(player) and not _resolving_exchange and not _processing_steps and not _inspiration_panel.visible and _pending_hom_action.is_empty()
	_refresh_spell_buttons()

func _commit_ultra(fighter: Dictionary, action: Dictionary) -> void:
	if action.get("kind", "spell") != "spell" or not bool(action.get("ultra", false)) or not _ultra_available(fighter):
		action["ultra"] = false
		return
	fighter.ultra_used = true
	var actors: Array = _highlights.get("ultraturn_actors", [])
	var side := "player" if is_same(fighter, player) else "enemy"
	if side not in actors:
		actors.append(side)
	_highlights["ultraturn_actors"] = actors
	_append_combat_log("", _combat_event(fighter, "inspiration", " activates ULTRATURN x2; consumed for this battle.", {}))

func _on_switch_weapon() -> void:
	if _resolving_exchange or _processing_steps or _battle_over or not _solo_forfeit_request.is_empty() or not _combat_started or _inspiration_panel.visible:
		return
	var slot := 2 if int(player.get("active_weapon_slot", 1)) == 1 else 1
	if player.get("equip_%d" % slot, {}).is_empty():
		return
	await _queue_combat_action({"kind": "switch", "slot": slot})

func _hom_ready(fighter: Dictionary) -> bool:
	return not bool(fighter.get("hom_spent", true)) and int(fighter.get("hom_energy", 0)) >= int(fighter.get("hom_ready_at", 3))

func _queue_combat_action(action: Dictionary) -> void:
	if not _pending_hom_action.is_empty():
		return
	if _hom_ready(player):
		_pending_hom_action = action
		hom_decision.show()
		$HomDecision/Attack.text = "Attack (BOOST)" if int(player.hom_energy) >= 6 else "Attack"
		$HomDecision/Hold.grab_focus()
		_refresh_spell_buttons()
		return
	action["hom"] = "hold"
	await _start_weapon_exchange(action)

func _on_hom_choice(choice: String) -> void:
	if _pending_hom_action.is_empty() or _resolving_exchange:
		return
	var action := _pending_hom_action
	_pending_hom_action = {}
	hom_decision.hide()
	action["hom"] = choice if _hom_ready(player) else "hold"
	await _start_weapon_exchange(action)

func _start_weapon_exchange(action: Dictionary) -> void:
	if _combat_session_invalid or _battle_over:
		return
	if _solo_boss_mode:
		_resolving_exchange = true
		_refresh_spell_buttons()
		await _resolve_solo_exchange(action)
		_resolving_exchange = false
		_finish_inspiration_exchange()
		if not _battle_over:
			_prepare_solo_power_turn()
			_prepare_solo_intent()
		_update_ui()
		_refresh_spell_buttons()
		return
	var npc_action := _choose_npc_action()
	if npc_action.is_empty():
		_log_immediate("No spell available for the opponent.")
		return
	if npc_action.get("kind") == "spell":
		npc_action["ultra"] = _npc_should_ultra(npc_action.spell)
	_commit_ultra(player, action)
	_commit_ultra(enemy, npc_action)
	npc_action["hom"] = _choose_npc_hom_action()
	_resolving_exchange = true
	_refresh_spell_buttons()
	await _resolve_spell_exchange(action, npc_action)
	_resolving_exchange = false
	_finish_inspiration_exchange()
	_refresh_spell_buttons()

func _choose_npc_action() -> Dictionary:
	var alternative: Dictionary = enemy.get("equip_2", {})
	if int(enemy.get("active_weapon_slot", 1)) == 1 and not bool(enemy.get("npc_weapon_switched", false)) and not alternative.is_empty():
		var current := _get_active_weapon(enemy)
		var low_hp := float(enemy.hp) < float(enemy.max_hp) * 0.5
		var current_mods := _item_mods([current])
		var alternative_mods := _item_mods([alternative])
		if low_hp and int(alternative_mods.def_flat) >= int(current_mods.def_flat) + 2:
			return {"kind": "switch", "slot": 2}
	var spell := _choose_npc_spell()
	return {} if spell.is_empty() else {"kind": "spell", "spell": spell}

func _choose_npc_hom_action() -> String:
	if not _hom_ready(enemy):
		return "hold"
	var damage := maxi(1, roundi(float(enemy.atk) * (0.6 if int(enemy.hom_energy) >= 6 else 0.4)))
	if int(enemy.hom_energy) >= 6 or damage >= int(player.hp):
		return "attack"
	if enemy.hp <= enemy.max_hp - 15 and enemy.hp <= enemy.max_hp * 0.3 and randf() < 0.15:
		return "sacrifice"
	if player.hp < player.max_hp * 0.3 and randf() < 0.45:
		return "attack"
	return "hold"

func _npc_should_ultra(spell: Dictionary) -> bool:
	if not _ultra_available(enemy) or spell.is_empty():
		return false
	var power := float(spell.get("power_mult", 0.0))
	var estimate := maxi(1, roundi((float(enemy.atk) - float(player.def) * 0.5) * power)) * 2
	if power > 0 and estimate >= int(player.hp):
		return true
	if float(enemy.hp) <= float(enemy.max_hp) * 0.4:
		return true
	if _turn >= 4:
		return true
	return _turn >= 3 and (power >= 1.1 or (power == 0.0 and not spell.get("effects", []).is_empty()))

func _resolve_spell_exchange(chosen: Dictionary, npc_spell: Dictionary) -> void:
	_turn += 1
	_begin_spell_exchange()
	var player_init: float = _initiative(player)
	var enemy_init: float = _initiative(enemy)
	var first: Dictionary = player if player_init >= enemy_init else enemy
	var second: Dictionary = enemy if player_init >= enemy_init else player
	var first_spell: Dictionary = chosen if player_init >= enemy_init else npc_spell
	var second_spell: Dictionary = npc_spell if player_init >= enemy_init else chosen
	_spell_acts_second = false
	await _resolve_spell_action(first, second, first_spell)
	if _combat_session_invalid:
		return
	if first.hp > 0 and (second.hp > 0 or first_spell.get("hom", "hold") == "sacrifice"):
		await _resolve_hom_choice(first, second, str(first_spell.get("hom", "hold")))
	if first.hp > 0 and second.hp > 0:
		_spell_acts_second = true
		await _resolve_spell_action(second, first, second_spell)
		if _combat_session_invalid:
			return
		if second.hp > 0 and (first.hp > 0 or second_spell.get("hom", "hold") == "sacrifice"):
			await _resolve_hom_choice(second, first, str(second_spell.get("hom", "hold")))
	if player.hp > 0 and enemy.hp > 0:
		_apply_spell_poison(player)
		_apply_spell_poison(enemy)
		await _flush_steps()
	_charge_homunculus(player)
	_charge_homunculus(enemy)
	await _flush_steps()
	_end_spell_exchange()
	if player.hp <= 0 or enemy.hp <= 0:
		_check_end()
		_update_ui()
		return
	_player_turn = not _player_turn
	if not _player_turn:
		_round += 1
		_apply_round_start_effects()
		await _flush_steps()
		_apply_round_winner_tempo()
		await _flush_steps()
	_update_ui()

func _resolve_spell_action(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	if spell.get("kind", "spell") == "switch":
		for key in caster.spell_cooldowns.keys():
			caster.spell_cooldowns[key] = maxi(0, int(caster.spell_cooldowns[key]) - 1)
		if int(caster.status.stun) > 0:
			_log_step("%s is stunned and cannot switch." % caster.name, func(): caster.status.stun -= 1, _combat_event(caster, "debuff", " is stunned and cannot switch.", {}))
		else:
			var old_name := _item_label(_get_active_weapon(caster))
			var slot := int(spell.get("slot", 1))
			var new_name := _item_label(caster.get("equip_%d" % slot, {}))
			_log_step("%s switches %s to %s; action spent." % [caster.name, old_name, new_name], func():
				_set_active_weapon(caster, slot)
				if is_same(caster, enemy):
					caster.npc_weapon_switched = true
			, _combat_event(caster, "switch", " switches %s to %s. Action spent; no spell." % [old_name, new_name], {}))
		await _flush_steps()
		return
	var ultra := bool(spell.get("ultra", false))
	if spell.has("spell"):
		spell = spell.spell
	_execute_spell(caster, target, spell, ultra)
	await _flush_steps()
	if _combat_session_invalid:
		return
	if caster.hp <= 0 or target.hp <= 0:
		spell_panel.hide()

func _resolve_hom_choice(fighter: Dictionary, target: Dictionary, choice: String) -> void:
	if not _hom_ready(fighter):
		return
	match choice:
		"attack":
			var boosted := int(fighter.hom_energy) >= 6
			fighter.hom_energy = 0
			if boosted:
				_log_step("%s unleashes an overcharged attack." % fighter.hom_name, Callable(), _combat_event(fighter, "homunculus", " unleashes an overcharged attack.", {}, true))
			_attack_homunculus(fighter, target, boosted)
		"sacrifice":
			_log_step("%s sacrifices its homunculus." % fighter.name, func():
				fighter.hom_spent = true
				fighter.hom_energy = 0
				if fighter.has("hom_reflect_active"):
					var remaining := maxf(float(fighter.get("hom_other_reflect", 0.0)), float(fighter.get("weapon_reflect_pct", 0.0)))
					fighter.status.reflect_pct = remaining
					if fighter.has("other_reflect_pct"):
						fighter.other_reflect_pct = float(fighter.get("hom_other_reflect", 0.0))
					fighter.erase("hom_reflect_active")
					fighter.erase("hom_other_reflect")
				_refresh_weapon_stats(fighter)
				var healed := mini(30, int(fighter.max_hp) - int(fighter.hp))
				fighter.hp = mini(int(fighter.max_hp), int(fighter.hp) + 30)
				_animate_pulse(_fighter_sprite(fighter), Color(0.55, 1.0, 0.65), 1.04)
				_highlights["sacrifice"] = "%s sacrificed %s, healing %d HP" % [fighter.name, fighter.hom_name, healed]
			, _combat_event(fighter, "heal", " sacrifices %s: restores up to 30 HP; homunculus unavailable for this combat." % fighter.hom_name, {}))
		_:
			_log_step("%s holds homunculus energy." % fighter.name, Callable(), _combat_event(fighter, "homunculus", " holds its charge.", {}, true))
	await _flush_steps()

func _charge_homunculus(fighter: Dictionary) -> void:
	if bool(fighter.get("hom_spent", true)):
		return
	fighter.hom_energy = mini(int(fighter.get("hom_max_energy", 6)), int(fighter.get("hom_energy", 0)) + 1)
	if fighter.hom_energy in [3, 6]:
		var state := "is ready (3/6)." if fighter.hom_energy == 3 else "is overcharged (6/6)."
		_log_step("%s %s" % [fighter.hom_name, state], Callable(), _combat_event(fighter, "homunculus", " " + state, {}, true))

func _apply_spell_poison(fighter: Dictionary) -> void:
	if _solo_boss_mode and is_same(fighter, enemy) and _solo_has_minions():
		return
	if fighter.status.poison > 0:
		_log_step("%s suffers poison (2)." % fighter.name, func():
			_record_highlight("damage", mini(int(fighter.hp), 2), "%s: poison" % fighter.name)
			fighter.status.poison -= 1
			fighter.hp = max(0, fighter.hp - 2)
			fighter.spell_hit_this_exchange = true
		, _combat_event(fighter, "debuff", " suffers 2 poison damage.", {}))

func _refresh_spell_buttons() -> void:
	var options := _fighter_spell_options(player)
	spell_panel.visible = not _battle_over
	var alternative := 2 if int(player.get("active_weapon_slot", 1)) == 1 else 1
	var weapon: Dictionary = player.get("equip_%d" % alternative, {})
	switch_weapon_btn.visible = _combat_started and not _battle_over and not weapon.is_empty()
	switch_weapon_btn.disabled = _resolving_exchange or _processing_steps or _battle_over or _inspiration_panel.visible or not _pending_hom_action.is_empty()
	switch_weapon_btn.text = "Switch to: %s" % _item_label(weapon)
	var deciding := _battle_index == 3 and _player_wins == 1 and _enemy_wins == 1 and not _sudden_death
	ultra_button.visible = _combat_started and deciding and not _battle_over
	ultra_button.disabled = not _ultra_available(player) or _resolving_exchange or _processing_steps or _inspiration_panel.visible or not _pending_hom_action.is_empty()
	ultra_button.set_pressed_no_signal(_ultra_armed and _ultra_available(player))
	ultra_button.text = "ULTRATURN USED" if bool(player.get("ultra_used", false)) else "ULTRATURN x2 - ARMED" if _ultra_armed else "ULTRATURN x2 - Ready"
	ultra_button.modulate = Color("d7b6ff") if _ultra_armed else Color.WHITE
	for i in spell_buttons.size():
		var button: Button = spell_buttons[i]
		button.visible = i < options.size()
		if i >= options.size():
			continue
		var spell: Dictionary = options[i]
		var type_icon := button.get_node_or_null("SpellTypeIcon") as Control
		if type_icon == null:
			type_icon = CombatTypeIcon.new()
			type_icon.name = "SpellTypeIcon"
			type_icon.position = Vector2(8, 5)
			type_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(type_icon)
		var type_id := str(spell.get("type", ""))
		type_icon.visible = type_id in ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"]
		if type_icon.visible and str(type_icon.get("element")) != type_id:
			type_icon.call("configure", type_id)
		var cd := int(player.get("spell_cooldowns", {}).get(spell.id, 0))
		var power := "Support" if float(spell.power_mult) == 0.0 else "x%.2f" % float(spell.power_mult)
		var cooldown := "  |  CD: %d" % cd if cd > 0 else ""
		button.text = "%s\n%s  |  %d%%%s" % [spell.name, power, int(round(float(spell.accuracy) * 100)), cooldown]
		button.tooltip_text = _spell_description(spell)
		button.disabled = _resolving_exchange or _processing_steps or _battle_over or _inspiration_panel.visible or not _pending_hom_action.is_empty() or cd > 0

func _style_spell_buttons() -> void:
	var accent := Color("a7b0bd")
	var file := FileAccess.open("res://data/types.json", FileAccess.READ)
	if file:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			for entry in data.get("types", []):
				if entry.get("id", "") == player.get("type", ""):
					accent = Color.from_string(str(entry.get("color", "")), accent)
					break
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.07, 0.08, 0.94)
	panel_style.border_color = accent.darkened(0.45)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(6)
	spell_panel.add_theme_stylebox_override("panel", panel_style)
	for button: Button in spell_buttons:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.13, 0.14, 1.0)
			if state == "hover":
				style.bg_color = Color(0.19, 0.20, 0.20, 1.0)
			elif state == "pressed":
				style.bg_color = Color(0.09, 0.10, 0.11, 1.0)
			elif state == "disabled":
				style.bg_color = Color(0.09, 0.09, 0.10, 1.0)
			style.border_color = accent.darkened(0.35 if state != "disabled" else 0.7)
			style.set_border_width_all(1)
			style.set_corner_radius_all(3)
			style.set_content_margin_all(4)
			button.add_theme_stylebox_override(state, style)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.92))
		button.add_theme_color_override("font_disabled_color", Color(0.53, 0.54, 0.54))

func _choose_npc_spell() -> Dictionary:
	if not _reg:
		return {}
	var candidates := []
	for spell in _fighter_spell_options(enemy):
		if int(enemy.spell_cooldowns.get(spell.id, 0)) > 0:
			continue
		var weight := 1.0 + float(spell.power_mult) * 2.0
		for effect in spell.effects:
			match str(effect.kind):
				"heal":
					weight = 0.0 if enemy.hp >= enemy.max_hp else (9.0 if enemy.hp <= enemy.max_hp * 0.4 else 2.0)
				"shield":
					weight = 0.0 if enemy.status.shield_pct >= float(effect.value) else (5.0 if enemy.hp < enemy.max_hp * 0.75 else 2.0)
				"reflect":
					weight = 0.0 if enemy.status.reflect_pct >= float(effect.value) else 3.0
				"poison":
					weight = 1.0 if player.status.poison > 0 else 6.0
				"hom_stun":
					weight = 1.0 if player.status.hom_stun > 0 else 4.0
				"atk_down":
					weight = 1.0 if player.status.atk_down > 0 else 3.5
				"vuln":
					if effect.target == "enemy":
						weight = 1.0 if player.status.vuln_pct > 0 else 3.5
				"atk_boost":
					weight = 0.0 if enemy.status.atk_boost >= float(effect.value) else 3.0
				"type_neutralize":
					weight = 0.0 if enemy.spell_neutralize_pending > 0 or _type_multiplier(player, enemy, false) >= 1.0 else 3.0
				"bonus_if_poisoned":
					weight += 4.0 if player.status.poison > 0 else 0.0
				"bonus_if_hit_last_exchange":
					weight += 4.0 if enemy.spell_hit_this_exchange else 0.0
		if weight > 0:
			candidates.append({"spell": spell, "weight": weight})
	var total := 0.0
	for candidate in candidates:
		total += candidate.weight
	var roll := randf() * total
	for candidate in candidates:
		roll -= candidate.weight
		if roll <= 0:
			return candidate.spell
	return candidates.back().spell if not candidates.is_empty() else {}

func _fighter_spell_options(fighter: Dictionary) -> Array:
	var options := []
	if _reg == null:
		return options
	for id in fighter.get("spell_ids", []):
		var spell: Dictionary = _reg.get_spell_by_id(str(id))
		if not spell.is_empty():
			options.append(spell)
	return options

# C2B must flush each action before resolving the next one.
func _begin_spell_exchange() -> void:
	_spell_exchange_active = true
	for fighter in [player, enemy]:
		fighter.spell_hit_last_exchange = fighter.get("spell_hit_this_exchange", false)
		fighter.spell_hit_this_exchange = false
		fighter.spell_neutralize_active = fighter.get("spell_neutralize_pending", 0.0)
		fighter.spell_neutralize_pending = 0.0

func _end_spell_exchange() -> void:
	_spell_exchange_active = false
	for fighter in [player, enemy]:
		fighter.spell_neutralize_active = 0.0

func _execute_spell(caster: Dictionary, target: Dictionary, spell: Dictionary, ultra_active: bool = false) -> bool:
	var id := str(spell.get("id", ""))
	if id.is_empty() or caster.get("hp", 0) <= 0 or target.get("hp", 0) <= 0:
		return false
	if not caster.has("spell_cooldowns"):
		caster.spell_cooldowns = {}
	var cooldowns: Dictionary = caster.spell_cooldowns
	if int(cooldowns.get(id, 0)) > 0:
		_log_step("%s is on cooldown." % spell.get("name", id), Callable())
		return false
	for key in cooldowns.keys():
		cooldowns[key] = max(0, int(cooldowns[key]) - 1)
	cooldowns[id] = int(spell.get("cooldown_turns", 0))
	var mark_owner := "player" if is_same(caster, player) else "enemy"
	var mark: Dictionary = target.status.get("hybrid_mark", {})
	var marked := str(mark.get("owner", "")) == mark_owner and int(mark.get("remaining", 0)) > 0
	if marked:
		_log_step("%s's mark approaches expiry." % caster.name, func():
			var current: Dictionary = target.status.get("hybrid_mark", {})
			if current.get("owner", "") == mark_owner:
				current["remaining"] = int(current.get("remaining", 0)) - 1
				if current.remaining <= 0:
					target.status.erase("hybrid_mark")
		, _combat_event(caster, "debuff", "'s mark approaches expiry.", {}))
	var attack_context := {"spell": spell, "actual_damage": 0, "pierce": 0.0, "dispel": 0.0, "ultra": ultra_active}
	if ultra_active:
		_log_step("%s boosts the spell with Ultraturn." % caster.name, Callable(), _combat_event(caster, "inspiration", " boosts this spell with ULTRATURN x2.", {}))
	var animate_attack: bool = spell.get("category") == "attack" and caster.status.stun <= 0
	_log_step("%s uses spell %s." % [caster.name, spell.get("name", id)], func():
		if animate_attack:
			_animate_lunge(_fighter_sprite(caster), 20.0 if is_same(caster, player) else -20.0, true)
	, _combat_event(caster, "damage" if animate_attack else "buff", " uses ", {"spell_id": id, "spell_name": spell.get("name", id), "spell_meta": {"id": id, "context": attack_context}, "suffix": "."}))
	if caster.status.stun > 0:
		_log_step("%s is stunned and skips the spell." % caster.name, func(): caster.status.stun -= 1, _combat_event(caster, "debuff", " is stunned and skips the spell.", {}))
		return true
	if id == str(caster.get("temporary_spell_id", "")):
		_highlights["inspiration_spell"] = "%s used %s" % [caster.name, spell.get("name", id)]
	var power := float(spell.get("power_mult", 0.0))
	var accuracy_focus := 0.0
	var accuracy_misalign := 0.0
	var poisoned_before := int(target.status.poison) > 0
	var combo_poisoned := false
	var combo_retaliation := false
	if spell.get("category") == "attack":
		accuracy_focus = float(caster.status.get("focus_next", 0.0))
		accuracy_misalign = float(caster.status.get("misalign_next", 0.0))
		if accuracy_focus > 0 or accuracy_misalign > 0:
			_log_step("%s expends accuracy effects." % caster.name, func():
				caster.status.erase("focus_next")
				caster.status.erase("misalign_next")
			, _combat_event(caster, "buff", " expends accuracy effects.", {}))
	for effect in spell.get("effects", []):
		if effect.kind == "bonus_if_poisoned" and target.status.poison > 0:
			power *= 1.0 + float(effect.value)
			combo_poisoned = true
		elif effect.kind == "bonus_if_hit_last_exchange" and caster.get("spell_hit_last_exchange", false):
			power *= 1.0 + float(effect.value)
			combo_retaliation = true
		elif effect.kind == "bonus_if_low_hp" and float(caster.hp) < float(caster.max_hp) * float(effect.get("threshold", 0.4)):
			power += float(effect.value)
		elif effect.kind == "bonus_if_marked" and marked:
			power += float(effect.value)
		elif effect.kind == "bonus_power_if_poisoned" and poisoned_before:
			power += float(effect.value)
		elif effect.kind == "bonus_if_shielded" and float(caster.status.shield_pct) > 0.0:
			power += float(effect.value)
		elif effect.kind == "bonus_power_if_hit_last_exchange" and caster.get("spell_hit_last_exchange", false):
			power += float(effect.value)
		elif effect.kind == "pierce_ward":
			attack_context.pierce = float(effect.value)
		elif effect.kind == "ward_dispel":
			attack_context.dispel = float(effect.value)
	var hit := false
	if spell.get("category") == "attack" and power > 0.0:
		hit = _attack_entity(caster, target, power, float(spell.get("accuracy", 1.0)), true, attack_context, accuracy_focus, accuracy_misalign)
	else:
		hit = randf() < float(spell.get("accuracy", 1.0))
		_log_step("%s's spell %s." % [caster.name, "succeeds" if hit else "misses"], Callable(), _combat_event(caster, "buff" if hit else "miss", "'s spell %s." % ("succeeds" if hit else "misses"), {}))
	if not hit:
		return true
	if combo_poisoned:
		_log_step("%s exploits poison." % caster.name, Callable(), _combat_event(caster, "combo", " COMBO: exploits poison.", {}))
	if combo_retaliation:
		_log_step("%s retaliates for the previous exchange." % caster.name, Callable(), _combat_event(caster, "combo", " COMBO: retaliates for the previous exchange.", {}))
	if spell.get("type") == "hybrid" and marked:
		_log_step("%s consumes the hybrid mark." % caster.name, func(): target.status.erase("hybrid_mark"), _combat_event(caster, "combo", " consumes the hybrid mark.", {}))
	for effect in spell.get("effects", []):
		var recipient: Dictionary = caster if effect.target == "self" else target
		var value := float(effect.value)
		var kind := str(effect.kind)
		if ultra_active and kind in ["heal", "recoil", "atk_boost", "atk_down", "shield", "reflect", "vuln", "poison", "hom_stun", "focus_next", "misalign_next", "tempo_shift", "hybrid_mark", "type_neutralize", "poison_on_reflect"]:
			value *= 2.0
			if kind in ["atk_boost", "atk_down", "shield", "reflect", "vuln", "focus_next", "misalign_next", "type_neutralize"]:
				value = clampf(value, 0.0, 0.95 if kind in ["shield", "reflect"] else 1.0)
		match kind:
			"cleanse_one":
				_log_step("%s cleanses one negative status." % recipient.name, func():
					for field in ["poison", "stun", "vuln_pct", "atk_down", "misalign_next"]:
						if float(recipient.status.get(field, 0)) > 0:
							recipient.status[field] = 0
							break
				, _combat_event(recipient, "buff", " cleanses one negative status.", {}))
			"focus_next", "misalign_next":
				_log_step("%s gains %s." % [recipient.name, kind], func():
					var before := float(recipient.status.get(kind, 0))
					recipient.status[kind] = maxf(before, value)
					if kind == "misalign_next" and float(recipient.status[kind]) > before:
						_award_inspiration(caster, recipient, kind)
				, _combat_event(recipient, "buff" if kind == "focus_next" else "debuff", " gains %s." % _status_effect_text(kind, value), {}))
			"tempo_shift":
				_log_step("%s's next initiative shifts by %s." % [recipient.name, str(value)], func():
					var before := float(recipient.status.get("tempo_bonus", 0.0))
					recipient.status.tempo_bonus = value
					if value < 0.0 and value < before:
						_award_inspiration(caster, recipient, kind)
				, _combat_event(recipient, "buff", "'s initiative shifts by %s." % str(value), {}))
			"recoil":
				_log_step("%s takes %d recoil." % [recipient.name, int(value)], func():
					_record_highlight("damage", mini(int(recipient.hp), int(value)), "%s: recoil" % recipient.name)
					if recipient.hp > 0 and value > 0:
						recipient.spell_hit_this_exchange = true
					recipient.hp = max(0, recipient.hp - int(value))
					if value > 0:
						_animate_hit(_fighter_sprite(recipient), int(value), recipient.max_hp)
				, _combat_event(recipient, "damage", " takes %d recoil." % int(value), {}))
			"life_leech":
				var cap := int(effect.get("max_heal", 0)) * (2 if ultra_active else 1)
				_log_step("%s siphons health." % recipient.name, func():
					if recipient.hp > 0:
						var recovered := mini(cap, int(floor(float(attack_context.actual_damage) * value)))
						var actual := mini(recovered, int(recipient.max_hp) - int(recipient.hp))
						recipient.hp = mini(recipient.max_hp, recipient.hp + recovered)
						_append_combat_log("", _combat_event(recipient, "heal", " restores %d HP from life leech." % actual, {}))
				, _combat_event(recipient, "heal", " siphons health.", {}))
			"consume_poison":
				if poisoned_before:
					_log_step("%s consumes poison." % caster.name, func(): recipient.status.poison = maxi(0, int(recipient.status.poison) - int(value)), _combat_event(caster, "combo", " consumes poison.", {}))
			"hybrid_mark":
				_log_step("%s marks %s." % [caster.name, recipient.name], func():
					var before: Dictionary = recipient.status.get("hybrid_mark", {}).duplicate(true)
					recipient.status.hybrid_mark = {"owner": mark_owner, "remaining": int(value)}
					if before != recipient.status.hybrid_mark:
						_award_inspiration(caster, recipient, kind)
				, _combat_event(caster, "debuff", " marks ", {"target": recipient.name, "target_color": _actor_color(recipient), "suffix": " for %d actions." % int(value)}))
			"shield_by_order":
				var shield_value := float(effect.get("second_value", value)) if _spell_acts_second else value
				if ultra_active:
					shield_value = minf(shield_value * 2.0, 0.95)
				_log_step("%s gains a shield." % recipient.name, func(): _other_defense(recipient, "shield_pct", shield_value), _combat_event(recipient, "shield", " gains shield %d%%." % roundi(shield_value * 100), {}))
			"poison_on_reflect":
				_log_step("%s prepares a toxic reflection." % recipient.name, func(): recipient.status.poison_on_reflect = int(value), _combat_event(recipient, "shield", " prepares a reflection with %d poison turns." % int(value), {}))
			"heal":
				_log_step("%s restores %d HP." % [recipient.name, int(value)], func():
					if recipient.hp < recipient.max_hp:
						_animate_pulse(_fighter_sprite(recipient), Color(0.55, 1.0, 0.65), 1.04)
					var healed := mini(int(value), int(recipient.max_hp) - int(recipient.hp))
					recipient.hp = min(recipient.max_hp, recipient.hp + int(value))
					if ultra_active:
						_append_combat_log("", _combat_event(recipient, "heal", " restores %d HP from the boosted spell." % healed, {}))
				, _combat_event(recipient, "heal", " restores up to %d HP." % int(value), {}))
			"shield", "reflect", "atk_boost", "atk_down", "vuln", "poison", "hom_stun":
				var fields := {"shield": "shield_pct", "reflect": "reflect_pct", "vuln": "vuln_pct"}
				var field: String = fields.get(kind, kind)
				_log_step("%s gains %s (%s)." % [recipient.name, kind, str(value)], func():
					var before := float(recipient.status.get(field, 0))
					if kind in ["shield", "reflect", "atk_boost"] and value > float(recipient.status.get(field, 0)):
						_animate_pulse(_fighter_sprite(recipient), Color(0.62, 0.7, 1.0), 1.04)
					if kind in ["shield", "reflect"]:
						_other_defense(recipient, field, value)
					else:
						recipient.status[field] = max(recipient.status.get(field, 0), value)
					if kind in ["atk_down", "vuln", "poison", "hom_stun"] and float(recipient.status.get(field, 0)) > before:
						_award_inspiration(caster, recipient, kind)
				, _combat_event(recipient, "shield" if kind in ["shield", "reflect"] else "buff" if kind == "atk_boost" else "debuff", " gains %s." % _status_effect_text(kind, value), {}))
			"type_neutralize":
				_log_step("%s prepares type neutralization." % recipient.name, func():
					if value > float(recipient.get("spell_neutralize_pending", 0.0)):
						_animate_pulse(_fighter_sprite(recipient), Color(0.8, 0.65, 1.0), 1.04)
					recipient.spell_neutralize_pending = max(recipient.get("spell_neutralize_pending", 0.0), value)
				, _combat_event(recipient, "buff", " prepares %d%% type neutralization." % roundi(value * 100), {}))
	return true

func _attack_entity(attacker: Dictionary, defender: Dictionary, power_mult: float = 1.0, accuracy: float = 0.9, spell_attack: bool = false, context: Dictionary = {}, accuracy_focus: float = 0.0, accuracy_misalign: float = 0.0) -> bool:
	if _solo_boss_mode and is_same(defender, enemy) and _solo_has_minions():
		return false
	if defender.hp <= 0:
		return false
	if attacker.status.stun > 0:
		_log_step("%s is stunned and skips a turn." % attacker.name, func(): attacker.status.stun -= 1, _combat_event(attacker, "debuff", " is stunned and skips a turn.", {}))
		return false
	if _try_evasion(defender):
		var ev_item := _item_with_effect([_get_active_weapon(defender)], "evasion_pct")
		_log_step("%s evades the strike via %s." % [defender.name, _item_label(ev_item)], func(): _animate_item_effect(defender, "evasion_pct"), _combat_event(defender, "miss", " evades via %s." % _item_label(ev_item), {}))
		return false
	if not _roll_hit(attacker, defender, accuracy, spell_attack, accuracy_focus, accuracy_misalign):
		_log_step("%s's attack misses %s." % [attacker.name, defender.name], Callable(), _combat_event(attacker, "miss", " misses ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": "."}))
		return false

	var mult: float = _spell_multiplier(attacker, defender, context.get("spell", {})) if not context.is_empty() else _type_multiplier(attacker, defender)
	var base_atk: int = int(attacker.atk)
	if attacker.status.atk_down > 0:
		base_atk = int(round(base_atk * (1.0 - attacker.status.atk_down)))
		_log_step("%s shakes off the weakness." % attacker.name, func(): attacker.status.atk_down = 0, _combat_event(attacker, "debuff", " shakes off the weakness.", {}))
	if attacker.status.atk_boost > 0:
		var previous_atk := base_atk
		base_atk = int(round(base_atk * (1.0 + attacker.status.atk_boost)))
		var boost_gain := maxi(0, maxi(1, int(round((base_atk - int(defender.def * 0.5)) * mult * power_mult))) - maxi(1, int(round((previous_atk - int(defender.def * 0.5)) * mult * power_mult))))
		_log_step("%s expends the surge." % attacker.name, func():
			attacker.status.atk_boost = 0
			_record_highlight("combo", boost_gain, "%s: attack boost" % attacker.name)
		, _combat_event(attacker, "combo", " COMBO: attack boost applied.", {}))
	var dmg: int = max(1, int(round((base_atk - int(defender.def * 0.5)) * mult * power_mult)))
	dmg = maxi(1, int(round(dmg * clampf(float(_hom_synergy(defender).get("incoming_mult", 1.0)), 0.1, 1.0))))
	if defender.status.vuln_pct > 0:
		var before_vulnerability := dmg
		dmg = int(round(dmg * (1.0 + defender.status.vuln_pct)))
		var vulnerability_gain := maxi(0, dmg - before_vulnerability)
		_log_step("%s's vulnerability is consumed." % defender.name, func():
			defender.status.vuln_pct = 0
			_record_highlight("combo", vulnerability_gain, "%s: vulnerability" % attacker.name)
		, _combat_event(attacker, "combo", " COMBO: exploits vulnerability.", {}))
	if defender.status.shield_pct > 0:
		var dispel := clampf(float(context.get("dispel", 0.0)), 0.0, 1.0)
		var pierce := clampf(float(context.get("pierce", 0.0)), 0.0, 1.0)
		if dispel > 0.0:
			_log_step("%s's shield is weakened." % defender.name, func():
				defender.status.shield_pct *= 1.0 - dispel
				for field in ["weapon_shield_pct", "other_shield_pct"]:
					if defender.has(field):
						defender[field] *= 1.0 - dispel
			, _combat_event(defender, "shield", "'s shield is weakened.", {}))
		var effective_shield: float = defender.status.shield_pct * (1.0 - dispel) * (1.0 - pierce)
		var before_shield := dmg
		dmg = int(round(dmg * (1.0 - effective_shield)))
		var prevented := maxi(0, before_shield - dmg)
		_log_step("%s's ward shatters." % defender.name, func():
			_clear_defense(defender, "shield_pct")
			_record_highlight("defense", prevented, str(defender.name))
		, _combat_event(defender, "shield", "'s ward blocks %d damage." % prevented, {}))
	if bool(context.get("ultra", false)):
		dmg *= 2
	if _solo_boss_mode and _solo_power_active and is_same(attacker, player) and is_same(defender, enemy):
		dmg *= 2
	var boss_prevented := 0
	if _solo_boss_mode and is_same(defender, enemy) and _solo_shield_turns > 0:
		var reduced := maxi(0, roundi(float(dmg) * (1.0 - float(_solo_def.shield_reduction))))
		boss_prevented = dmg - reduced
		dmg = reduced
	_log_step("%s hits %s for %d." % [attacker.name, defender.name, dmg], func():
		_record_highlight("damage", mini(int(defender.hp), dmg), "%s to %s" % [attacker.name, defender.name])
		if not context.is_empty():
			_record_spell_damage(context.get("spell", {}), mini(int(defender.hp), dmg))
			context.actual_damage += mini(int(defender.hp), dmg)
		defender.hp = max(0, defender.hp - dmg)
		if boss_prevented > 0:
			defender.hp = mini(int(defender.max_hp), int(defender.hp) + floori(boss_prevented * float(_solo_def.shield_heal_ratio)))
		_animate_hit(_fighter_sprite(defender), dmg, defender.max_hp)
		if spell_attack and dmg > 0:
			defender.spell_hit_this_exchange = true
	, _combat_event(attacker, "damage", " hits ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": " for %d." % dmg, "damage": dmg, "effectiveness": mult, "spell_id": str(context.get("spell", {}).get("id", "")) if not context.is_empty() else "", "show_spell_link": false}))
	if defender.status.reflect_pct > 0:
		if _try_ignore_reflect(attacker):
			var ir_item := _item_with_effect([_get_active_weapon(attacker)], "ignore_reflect_chance")
			_log_step("%s nullifies reflect via %s." % [attacker.name, _item_label(ir_item)], func():
				_clear_defense(defender, "reflect_pct")
				defender.status.erase("poison_on_reflect")
				_animate_item_effect(attacker, "ignore_reflect_chance")
			, _combat_event(attacker, "shield", " nullifies reflect via %s." % _item_label(ir_item), {}))
		else:
			var r := int(round(dmg * defender.status.reflect_pct))
			if _solo_boss_mode and is_same(attacker, enemy) and _solo_has_minions():
				r = 0
			_log_step("%s reflects %d damage." % [defender.name, r], func():
				_record_highlight("damage", mini(int(attacker.hp), r), "%s: reflection" % defender.name)
				_record_highlight("reflection", mini(int(attacker.hp), r), "%s against %s" % [defender.name, attacker.name])
				attacker.hp = max(0, attacker.hp - r)
				if r > 0:
					_animate_hit(_fighter_sprite(attacker), r, attacker.max_hp)
				if spell_attack and r > 0:
					attacker.spell_hit_this_exchange = true
				_clear_defense(defender, "reflect_pct")
				if int(defender.status.get("poison_on_reflect", 0)) > 0 and not (_solo_boss_mode and is_same(attacker, enemy) and _solo_has_minions()):
					attacker.status.poison = maxi(int(attacker.status.poison), int(defender.status.poison_on_reflect))
				defender.status.erase("poison_on_reflect")
			, _combat_event(defender, "shield", " reflects %d damage." % r, {}))
	var true_bonus: int = _true_on_hit(attacker)
	if true_bonus > 0:
		var t_item := _item_with_effect([_get_active_weapon(attacker)], "true_on_hit")
		_log_step("%s's %s adds +%d true damage." % [attacker.name, _item_label(t_item), true_bonus], func():
			_record_highlight("damage", mini(int(defender.hp), true_bonus), "%s: %s" % [attacker.name, _item_label(t_item)])
			if not context.is_empty():
				_record_spell_damage(context.get("spell", {}), mini(int(defender.hp), true_bonus))
				context.actual_damage += mini(int(defender.hp), true_bonus)
			defender.hp = max(0, defender.hp - true_bonus)
			_animate_item_effect(attacker, "true_on_hit")
			_animate_hit(_fighter_sprite(defender), true_bonus, defender.max_hp)
		, _combat_event(attacker, "damage", "'s %s adds +%d true damage." % [_item_label(t_item), true_bonus], {}))
	var dot_true: int = _dot_on_hit(attacker)
	if dot_true > 0:
		var d_item := _item_with_effect([_get_active_weapon(attacker)], "dot_true")
		_log_step("%s's %s corrodes for %d." % [attacker.name, _item_label(d_item), dot_true], func():
			_record_highlight("damage", mini(int(defender.hp), dot_true), "%s: %s" % [attacker.name, _item_label(d_item)])
			if not context.is_empty():
				_record_spell_damage(context.get("spell", {}), mini(int(defender.hp), dot_true))
				context.actual_damage += mini(int(defender.hp), dot_true)
			defender.hp = max(0, defender.hp - dot_true)
			_animate_item_effect(attacker, "dot_true")
			_animate_hit(_fighter_sprite(defender), dot_true, defender.max_hp)
		, _combat_event(attacker, "debuff", "'s %s corrodes for %d." % [_item_label(d_item), dot_true], {}))
		var v_hit: float = _vuln_on_hit(attacker)
		if v_hit > 0.0:
			_log_step("%s is left vulnerable by the corrosion." % defender.name, func():
				defender.status.vuln_pct = max(defender.status.vuln_pct, v_hit)
				_animate_item_effect(attacker, "vuln_on_hit")
			, _combat_event(defender, "debuff", " is left vulnerable by the corrosion.", {}))
	var hom_dot := maxi(0, int(_hom_synergy(attacker).get("dot_true", 0)))
	if hom_dot > 0:
		_log_step("%s corrodes for %d." % [attacker.hom_name, hom_dot], func():
			defender.hp = maxi(0, int(defender.hp) - hom_dot)
			_animate_hit(_fighter_sprite(defender), hom_dot, defender.max_hp)
		, _combat_event(attacker, "debuff", "'s homunculus %s corrodes for %d." % [attacker.hom_name, hom_dot], {}, true))

	if attacker.type == "vitriol" and randi() % 100 < 30:
		_log_step("%s corrodes %s (Poison)." % [attacker.name, defender.name], func(): defender.status.poison = 2, _combat_event(attacker, "debuff", " corrodes ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": " (Poison)."}))
	if attacker.type == "mercury" and randi() % 100 < 20:
		_log_step("%s shocks %s (Stun)." % [attacker.name, defender.name], func(): defender.status.stun = 1, _combat_event(attacker, "debuff", " shocks ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": " (Stun)."}))
	if attacker.type == "sulfur" and randi() % 100 < 20:
		_log_step("%s sears %s (Atk down)." % [attacker.name, defender.name], func(): defender.status.atk_down = max(defender.status.atk_down, 0.15), _combat_event(attacker, "debuff", " sears ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": " (Atk down)."}))
	if attacker.type == "sodium" and randi() % 100 < 20:
		_log_step("%s crystallizes a ward." % attacker.name, func():
			if attacker.status.shield_pct < 0.12:
				_animate_pulse(_fighter_sprite(attacker), Color(0.62, 0.7, 1.0), 1.04)
			_other_defense(attacker, "shield_pct", 0.12)
		, _combat_event(attacker, "shield", " crystallizes a ward.", {}))
	if attacker.type == "aether" and randi() % 100 < 20:
		_log_step("%s rends the veil (Vulnerable)." % attacker.name, func(): defender.status.vuln_pct = max(defender.status.vuln_pct, 0.12), _combat_event(attacker, "debuff", " rends the veil (Vulnerable).", {}))
	if attacker.type == "gold" and randi() % 100 < 20:
		_log_step("%s mints 3 HP." % attacker.name, func():
			if attacker.hp < attacker.max_hp:
				_animate_pulse(_fighter_sprite(attacker), Color(0.55, 1.0, 0.65), 1.04)
			attacker.hp = min(attacker.max_hp, attacker.hp + 3)
		, _combat_event(attacker, "heal", " mints up to 3 HP.", {}))

	if not spell_attack and defender.status.poison > 0:
		defender.status.poison -= 1
		defender.hp = max(0, defender.hp - 2)
		_log("%s suffers poison (2)." % defender.name, _combat_event(defender, "debuff", " suffers 2 poison damage.", {}))
	return true

func _attack_homunculus(attacker: Dictionary, defender: Dictionary, boosted: bool = false) -> void:
	if _solo_boss_mode and is_same(defender, enemy) and _solo_has_minions():
		return
	if defender.hp <= 0:
		return
	if bool(attacker.get("hom_spent", true)):
		return
	var stunned_fighter := attacker if _spell_exchange_active else defender
	if stunned_fighter.status.hom_stun > 0:
		_log_step("%s's homunculus is nullified this turn." % stunned_fighter.name, func(): stunned_fighter.status.hom_stun -= 1, _combat_event(stunned_fighter, "debuff", " is nullified.", {}, true))
		return
	if not _roll_hit(attacker, defender, 0.95):
		_log_step("%s's homunculus misses %s." % [attacker.name, defender.name], func(): _animate_lunge(_fighter_sprite(attacker, true), 12.0 if is_same(attacker, player) else -12.0, false), _combat_event(attacker, "miss", " misses ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": "."}, true))
		return
	var hom_dmg: int = max(1, int(round(attacker.atk * (0.6 if boosted else 0.4) * clampf(float(_hom_synergy(defender).get("incoming_mult", 1.0)), 0.1, 1.0))))
	if _solo_boss_mode and _solo_power_active and is_same(attacker, player) and is_same(defender, enemy):
		hom_dmg *= 2
	var boss_prevented := 0
	if _solo_boss_mode and is_same(defender, enemy) and _solo_shield_turns > 0:
		var reduced := maxi(0, roundi(float(hom_dmg) * (1.0 - float(_solo_def.shield_reduction))))
		boss_prevented = hom_dmg - reduced
		hom_dmg = reduced
	var track_hit := _spell_exchange_active
	_log_step("%s's homunculus strikes %s for %d." % [attacker.name, defender.name, hom_dmg], func():
		_record_highlight("damage", mini(int(defender.hp), hom_dmg), "%s (%s) to %s" % [attacker.hom_name, attacker.name, defender.name])
		_animate_lunge(_fighter_sprite(attacker, true), 12.0 if is_same(attacker, player) else -12.0, false)
		defender.hp = max(0, defender.hp - hom_dmg)
		if boss_prevented > 0:
			defender.hp = mini(int(defender.max_hp), int(defender.hp) + floori(boss_prevented * float(_solo_def.shield_heal_ratio)))
		_animate_hit(_fighter_sprite(defender), hom_dmg, defender.max_hp)
		if track_hit:
			defender.spell_hit_this_exchange = true
	, _combat_event(attacker, "homunculus", " overcharged attack on " if boosted else " strikes ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": " for %d." % hom_dmg}, true))

func _apply_round_winner_tempo() -> void:
	if _round != 2:
		return
	if player.hp == enemy.hp:
		return
	var player_wins: bool = player.hp > enemy.hp
	if player_wins:
		_apply_tempo_win_bonus(player, true)
	else:
		_apply_tempo_win_bonus(enemy, false)

func _apply_mods(f: Dictionary) -> void:
	var ent := _find_by_id(_entities, f.id)
	var hom := _find_by_id(_homunculi, f.hom_id)
	var stats := _get_base_stats(ent)
	var effective := preload("res://scripts/domain/homunculus_progress.gd").effective_bonuses(hom, f.get("hom_progress", {}))
	var synergy := _hom_synergy(f)
	var buffs := {"atk": int(effective.get("power_flat", 0)) + int(synergy.get("power_flat", 0)), "def": int(effective.get("guard_flat", 0)) + int(synergy.get("guard_flat", 0)), "hp": int(effective.get("hp_flat", 0))}
	if bool(f.get("hom_spent", false)):
		buffs = {"atk": 0, "def": 0, "hp": 0}
	var atk = stats.atk + buffs.atk
	var def = stats.def + buffs.def
	var hp = stats.hp + buffs.hp
	var mods = f.mods
	f.atk = atk + mods.atk_flat
	f.def = def + mods.def_flat
	f.max_hp = hp
	if _solo_boss_mode and is_same(f, enemy):
		f.atk = maxi(1, roundi(float(f.atk) * float(_solo_def.attack_mult)))
		f.max_hp = maxi(1, roundi(float(f.max_hp) * float(_solo_def.hp_mult)))
	f.hp = min(f.hp, f.max_hp)
	f.item_fx = _collect_item_effects([_get_active_weapon(f)])

func _check_end() -> void:
	if _solo_boss_mode and enemy.hp <= 0 and _solo_has_minions() and player.hp > 0:
		return
	if player.hp <= 0 or enemy.hp <= 0:
		_handle_battle_end()

func _handle_battle_end() -> void:
	if _battle_over:
		return
	if _solo_boss_mode:
		_clear_solo_power()
		_battle_over = true
		var victory: bool = player.hp > 0 and enemy.hp <= 0 and not _solo_has_minions()
		var preview: Variant = _solo_context.get("debug_visual", {})
		if victory and _combat_debug and str(_solo_context.get("session_id", "")).is_empty() and preview is Dictionary and bool(preview.get("guardian", false)):
			var index := int(preview.get("parent_index", 0))
			var guardian_id := str(preview.get("encounter_id", ""))
			var zone := str(_solo_context.get("visual_zone_id", ""))
			if index >= 1 and index <= 4 and not guardian_id.is_empty() and zone in ["zone_chaos", "zone_corrupted", "zone_crystal"]:
				SceneRouter._debug_guardian_wins[SceneRouter.debug_guardian_key(zone, index, guardian_id)] = true
		_solo_events.append({"turn": _turn, "result": "victory" if victory else "defeat"})
		_log_immediate("Victory - Rewards available in WG-B4 (Unverified / Preview)" if victory else "Defeat - Resource loss available in WG-B4 (Unverified / Preview)")
		spell_panel.hide()
		switch_weapon_btn.hide()
		_inspiration_panel.hide()
		next_turn_btn.text = "Return to World Zone" if not str(_solo_context.get("visual_zone_id", "")).is_empty() else "Return to World Gate"
		next_turn_btn.disabled = false
		next_turn_btn.show()
		return
	var player_dead: bool = int(player.get("hp", 0)) <= 0
	var enemy_dead: bool = int(enemy.get("hp", 0)) <= 0
	if player_dead and enemy_dead:
		_log_immediate("Battle %d ends in a draw." % _battle_index)
	elif player_dead:
		_enemy_wins += 1
		_log_immediate("You lose battle %d." % _battle_index)
	else:
		_player_wins += 1
		_log_immediate("You win battle %d." % _battle_index)

	_log_immediate("Score: %d-%d" % [_player_wins, _enemy_wins])
	_restore_inspiration(player)
	_restore_inspiration(enemy)
	_inspiration_panel.hide()

	if _player_wins >= 2 or _enemy_wins >= 2:
		if _player_wins > _enemy_wins:
			_log_immediate("Match win.")
		elif _enemy_wins > _player_wins:
			_log_immediate("Match loss.")
		else:
			_log_immediate("Match draw.")
		_battle_over = true
		if _player_wins > _enemy_wins:
			_show_unverified_reward_status()
		_show_highlights()
		next_turn_btn.text = "Return to Loadout"
		next_turn_btn.show()
		next_turn_btn.disabled = false
		return
	if _battle_index >= 3:
		if _player_wins == _enemy_wins and not _sudden_death:
			_sudden_death = true
			_battle_index += 1
			_reset_battle_state()
			_log_immediate("Sudden Death begins.")
			_update_ui()
			next_turn_btn.disabled = false
			return
		if _player_wins == _enemy_wins:
			_log_immediate("Match draw.")
		elif _player_wins > _enemy_wins:
			_log_immediate("Match win.")
		else:
			_log_immediate("Match loss.")
		_battle_over = true
		if _player_wins > _enemy_wins:
			_show_unverified_reward_status()
		_show_highlights()
		next_turn_btn.text = "Return to Loadout"
		next_turn_btn.show()
		next_turn_btn.disabled = false
		return

	_battle_index += 1
	_reset_battle_state()
	_log_immediate("Battle %d begins." % _battle_index)
	_update_ui()
	next_turn_btn.disabled = false

func _reset_battle_state() -> void:
	_reset_animations()
	_turn = 0
	_round = 1
	_player_turn = true
	_pending_hom_action.clear()
	hom_decision.hide()
	_processing_steps = false
	_spell_exchange_active = false
	_spell_acts_second = false
	next_turn_btn.hide()
	_step_queue.clear()
	_reset_fighter(player)
	_reset_fighter(enemy)
	_update_ui()

func _record_highlight(kind: String, amount: int, description: String) -> void:
	if amount > int(_highlights.get(kind, 0)):
		_highlights[kind] = amount
		_highlights[kind + "_text"] = description

func _record_spell_damage(spell: Dictionary, amount: int) -> void:
	var spell_name := str(spell.get("name", ""))
	if not spell_name.is_empty() and amount > 0:
		_spell_damage_totals[spell_name] = int(_spell_damage_totals.get(spell_name, 0)) + amount

func _show_unverified_reward_status() -> void:
	if _verified_combat_match_id.is_empty() or _combat_debug or _combat_session_invalid or _combat_backend == null or _combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity:
		_set_reward_status("Rewards unavailable: online combat verification required.")
		return
	if _reward_action_id.is_empty():
		_reward_action_id = _combat_backend._make_uuid()
	_reward_request_id = _combat_backend.request_api("POST", "/combat/rewards/claim", {"match_id": _verified_combat_match_id, "client_action_id": _reward_action_id}, true)
	_set_reward_status("Claiming..." if not _reward_request_id.is_empty() else "Reward claim unavailable; retry later.")

func _on_combat_reward_completed(request_id: String, ok: bool, data: Dictionary) -> void:
	if not request_id.is_empty() and request_id == _solo_forfeit_request:
		_solo_forfeit_request = ""
		if ok and str(data.get("status", "")) == "FORFEIT":
			_leave_combat()
		else:
			_log_immediate("Forfeit not confirmed: %s. Session may remain active; retry." % str(data.get("error", "invalid response")))
		return
	if request_id.is_empty() or request_id != _reward_request_id:
		return
	_reward_request_id = ""
	if _combat_session_invalid or _combat_backend == null or _combat_backend._verified_player_id != _combat_identity:
		_set_reward_status("Reward verification unavailable: session changed.")
		return
	if not ok:
		_set_reward_status("Reward verification unavailable or rejected: %s" % str(data.get("error", "unknown error")))
		return
	var reward: Variant = data.get("reward")
	var prefix := "Already claimed: " if bool(data.get("duplicate", false)) else ""
	if reward == null:
		_set_reward_status(prefix + "No material dropped.")
	elif reward is Dictionary:
		var id := str(reward.get("resource_id", ""))
		_set_reward_status(prefix + "%s x%d" % [_reward_resource_name(id), int(reward.get("amount", 0))])
	else:
		_set_reward_status("Reward response invalid.")

func _reward_resource_name(id: String) -> String:
	var file := FileAccess.open("res://data/static/resources.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			for resource in parsed.get("resources", []):
				if resource is Dictionary and str(resource.get("id", "")) == id:
					return str(resource.get("display_name", id))
	return id

func _set_reward_status(message: String) -> void:
	_highlights["reward_status"] = message
	_log_immediate(message)
	if is_instance_valid(_reward_label):
		_reward_label.text = message

func _show_highlights() -> void:
	var lines: Array[String] = []
	if int(_highlights.damage) > 0:
		lines.append("Highest damage: %d | %s" % [_highlights.damage, _highlights.damage_text])
	if int(_highlights.reflection) > 0:
		lines.append("Largest reflection: %d | %s" % [_highlights.reflection, _highlights.reflection_text])
	if int(_highlights.get("defense", 0)) > 0:
		lines.append("Damage blocked: %d | %s" % [_highlights.defense, _highlights.defense_text])
	if int(_highlights.get("combo", 0)) > 0:
		lines.append("Best synergy: +%d before mitigation | %s" % [_highlights.combo, _highlights.combo_text])
	if _highlights.has("sacrifice"):
		lines.append(str(_highlights.sacrifice))
	if _highlights.has("inspiration_spell"):
		lines.append("Inspiration: " + str(_highlights.inspiration_spell))
	for side in _highlights.get("ultraturn_actors", []):
		var fighter: Dictionary = player if side == "player" else enemy
		lines.append("%s used Ultraturn" % str(fighter.get("name", side)))
	var strongest := ""
	var total := 0
	for spell_name in _spell_damage_totals:
		if int(_spell_damage_totals[spell_name]) > total:
			strongest = str(spell_name)
			total = int(_spell_damage_totals[spell_name])
	if total > 0:
		lines.append("Most damaging spell: %s (%d total)" % [strongest, total])
	if lines.is_empty() and not _highlights.has("reward_status"):
		return
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(440, 0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.04, 0.045, 0.92)
	background.border_color = Color("95834f")
	background.set_border_width_all(1)
	background.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", background)
	var label := Label.new()
	label.text = "BATTLE HIGHLIGHTS\n" + "\n".join(lines)
	label.add_theme_font_size_override("font_size", 17)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var content := VBoxContainer.new()
	panel.add_child(content)
	content.add_child(label)
	if _highlights.has("reward_status"):
		_reward_label = Label.new()
		_reward_label.text = str(_highlights.reward_status)
		_reward_label.add_theme_font_size_override("font_size", 16)
		_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(_reward_label)
	add_child(panel)

func _reset_fighter(f: Dictionary) -> void:
	_restore_inspiration(f)
	f.hom_energy = 0
	f.erase("hom_reflect_active")
	f.erase("hom_other_reflect")
	f.hp = f.max_hp
	for field in ["shield_pct", "reflect_pct"]:
		f.erase("weapon_" + field)
		f.erase("other_" + field)
	f.spell_cooldowns = {}
	f.spell_hit_this_exchange = false
	f.spell_hit_last_exchange = false
	f.spell_neutralize_pending = 0.0
	f.spell_neutralize_active = 0.0
	f.status = {
		"poison": 0,
		"stun": 0,
		"shield_pct": 0.0,
		"atk_boost": 0.0,
		"vuln_pct": 0.0,
		"atk_down": 0.0,
		"hom_stun": 0,
		"reflect_pct": 0.0,
		"tempo_bonus": 0.0
	}

func _ensure_type_effectiveness() -> void:
	if _type_effectiveness.is_empty():
		var file := FileAccess.open("res://data/types.json", FileAccess.READ)
		if file:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data is Dictionary and data.get("effectiveness") is Dictionary:
				_type_effectiveness = data.effectiveness

func _spell_multiplier(attacker: Dictionary, defender: Dictionary, spell: Dictionary) -> float:
	var kind := str(spell.get("type", ""))
	if kind == "universal":
		return 1.0
	if kind != "hybrid":
		return _type_multiplier(attacker, defender)
	_ensure_type_effectiveness()
	var target_type := str(defender.get("type", ""))
	var primary: Dictionary = _type_effectiveness.get(str(spell.get("primary_type", "")), {})
	var secondary: Dictionary = _type_effectiveness.get(str(spell.get("secondary_type", "")), {})
	var p := float(primary.get(target_type, 1.0))
	var s := float(secondary.get(target_type, 1.0))
	p = 1.25 if p > 1.0 else (0.80 if p < 1.0 else 1.0)
	s = 1.25 if s > 1.0 else (0.80 if s < 1.0 else 1.0)
	var multiplier := clampf(pow(p, 0.65) * pow(s, 0.35), 0.80, 1.25)
	if multiplier > 1.0:
		multiplier += _hom_advantage_bonus(attacker)
	var neutralize := maxf(maxf(float(attacker.get("spell_neutralize_active", 0.0)), float(defender.get("spell_neutralize_active", 0.0))), maxf(float(_hom_synergy(attacker).get("type_neutralize", 0.0)), float(_hom_synergy(defender).get("type_neutralize", 0.0))))
	return 1.0 + (multiplier - 1.0) * (1.0 - neutralize)

func _type_multiplier(attacker: Dictionary, defender: Dictionary, emit_log: bool = true) -> float:
	_ensure_type_effectiveness()
	var row: Dictionary = _type_effectiveness.get(str(attacker.type), {})
	var relationship := float(row.get(str(defender.type), 1.0))
	var multiplier := 1.0
	if relationship > 1.0:
		multiplier = 1.12 + _hom_advantage_bonus(attacker)
	elif relationship < 1.0:
		var red: float = float(attacker.item_fx.get("disadvantage_reduction", 0.0))
		if red > 0.0 and emit_log:
			var d_item := _item_with_effect([_get_active_weapon(attacker)], "disadvantage_reduction")
			_log("%s steadies the disadvantage via %s." % [attacker.name, _item_label(d_item)], _combat_event(attacker, "advantage", " steadies the disadvantage via %s." % _item_label(d_item), {}))
		multiplier = min(0.92 + red, 1.0)
	var neutralize := maxf(maxf(float(attacker.get("spell_neutralize_active", 0.0)), float(defender.get("spell_neutralize_active", 0.0))), maxf(float(_hom_synergy(attacker).get("type_neutralize", 0.0)), float(_hom_synergy(defender).get("type_neutralize", 0.0))))
	return 1.0 + (multiplier - 1.0) * (1.0 - neutralize)

func _hom_advantage_bonus(fighter: Dictionary) -> float:
	if bool(fighter.get("hom_spent", true)):
		return 0.0
	var bonuses: Dictionary = preload("res://scripts/domain/homunculus_progress.gd").effective_bonuses(fighter.get("hom_data", {}), fighter.get("hom_progress", {}))
	return clampf(float(_hom_synergy(fighter).get("type_adv_bonus", 0.0)) + float(bonuses.get("favorable_type_bonus", 0.0)), 0.0, 0.5)

func _type_advantage(t: String) -> String:
	_ensure_type_effectiveness()
	var row: Dictionary = _type_effectiveness.get(t, {})
	for target in row:
		if float(row[target]) > 1.0:
			return str(target)
	return ""

func _item_mods(items: Array) -> Dictionary:
	var mods := {"atk_flat": 0, "def_flat": 0}
	for it in items:
		if it == null or it.is_empty():
			continue
		mods.atk_flat += int(_item_effect_value(it, "power_flat", 0))
		mods.def_flat += int(_item_effect_value(it, "guard_flat", 0))
	return mods

func _collect_item_effects(items: Array) -> Dictionary:
	var fx := {
		"true_on_hit": 0,
		"dot_true": 0,
		"vuln_on_hit": 0.0,
		"evasion_pct": 0.0,
		"ward_pct": 0.0,
		"reflect_pct": 0.0,
		"disadvantage_reduction": 0.0,
		"tempo_on_win": 0.0,
		"ignore_reflect_chance": 0.0
	}
	for it in items:
		if it == null or it.is_empty():
			continue
		fx.true_on_hit += _item_effect_value(it, "true_on_hit", 0)
		fx.dot_true += _item_effect_value(it, "dot_true", 0)
		fx.vuln_on_hit = max(fx.vuln_on_hit, _item_effect_value(it, "vuln_on_hit", 0.0))
		fx.evasion_pct = max(fx.evasion_pct, _item_effect_value(it, "evasion_pct", 0.0))
		fx.ward_pct = max(fx.ward_pct, _item_effect_value(it, "ward_pct", 0.0))
		fx.reflect_pct = max(fx.reflect_pct, _item_effect_value(it, "reflect_pct", 0.0))
		fx.disadvantage_reduction = max(fx.disadvantage_reduction, _item_effect_value(it, "disadvantage_reduction", 0.0))
		fx.tempo_on_win = max(fx.tempo_on_win, _item_effect_value(it, "tempo_on_win", 0.0))
		fx.ignore_reflect_chance = max(fx.ignore_reflect_chance, _item_effect_value(it, "ignore_reflect_chance", 0.0))
	return fx

func _item_effect_value(item: Dictionary, key: String, default_value) -> Variant:
	if item == null or item.is_empty():
		return default_value
	var effects = item.get("effects", {})
	if not effects.has(key):
		return default_value
	var v = effects.get(key)
	if v is Array and v.size() > 0:
		return v[0]
	return v

func _item_with_effect(items: Array, key: String) -> Dictionary:
	for it in items:
		if it == null or it.is_empty():
			continue
		var effects = it.get("effects", {})
		if effects.has(key):
			return it
	return {}

func _try_evasion(defender: Dictionary) -> bool:
	var chance: float = float(defender.item_fx.get("evasion_pct", 0.0))
	if chance <= 0.0:
		return false
	return randf() < chance

func _try_ignore_reflect(attacker: Dictionary) -> bool:
	var chance: float = float(attacker.item_fx.get("ignore_reflect_chance", 0.0))
	if chance <= 0.0:
		return false
	return randf() < chance

func _roll_hit(attacker: Dictionary, defender: Dictionary, base_accuracy: float, spell_attack: bool = false, accuracy_focus: float = 0.0, accuracy_misalign: float = 0.0) -> bool:
	var acc := base_accuracy
	var atk := float(attacker.get("atk", 0))
	var def := float(defender.get("def", 0))
	if atk > def * 1.6:
		acc -= 0.08
	var max_hp := float(attacker.get("max_hp", 0))
	var def_hp := float(defender.get("max_hp", 0))
	if max_hp > def_hp and max_hp > 0.0:
		var diff_ratio := (max_hp - def_hp) / max_hp
		acc -= clamp(diff_ratio * 0.2, 0.0, 0.15)
	if accuracy_focus > 0.0:
		acc = minf(0.99, acc + accuracy_focus)
	if accuracy_misalign > 0.0:
		acc = maxf(0.55, acc - accuracy_misalign)
	acc = clamp(acc, 0.0 if spell_attack else 0.6, 1.0 if spell_attack else 0.98)
	return randf() < acc

func _true_on_hit(attacker: Dictionary) -> int:
	return int(attacker.item_fx.get("true_on_hit", 0))

func _dot_on_hit(attacker: Dictionary) -> int:
	return int(attacker.item_fx.get("dot_true", 0))

func _vuln_on_hit(attacker: Dictionary) -> float:
	return float(attacker.item_fx.get("vuln_on_hit", 0.0))

func _apply_round_start_effects() -> void:
	_apply_round_start_for(player, true)
	_apply_round_start_for(enemy, false)

func _apply_round_start_for(f: Dictionary, _is_player: bool) -> void:
	var hom_reflect := clampf(float(_hom_synergy(f).get("reflect_pct", 0.0)), 0.0, 1.0)
	if hom_reflect > 0:
		_log_step("%s grants reflection." % f.hom_name, func():
			f.hom_other_reflect = float(f.status.get("reflect_pct", 0.0))
			f.hom_reflect_active = hom_reflect
			f.recording_hom_reflect = true
			_other_defense(f, "reflect_pct", hom_reflect)
			f.erase("recording_hom_reflect")
		, _combat_event(f, "shield", " grants reflection.", {}, true))
	if f.item_fx.get("ward_pct", 0.0) > 0.0:
		var ward: float = float(f.item_fx.get("ward_pct", 0.0))
		_log_step("%s forms a ward via %s." % [f.name, _item_label(_item_with_effect([_get_active_weapon(f)], "ward_pct"))], func():
			if ward > f.status.shield_pct:
				_animate_item_effect(f, "ward_pct")
				_animate_pulse(_fighter_sprite(f), Color(0.62, 0.7, 1.0), 1.04)
			_weapon_defense(f, "shield_pct", ward)
		, _combat_event(f, "shield", " forms a ward via %s." % _item_label(_item_with_effect([_get_active_weapon(f)], "ward_pct")), {}))
	if f.item_fx.get("reflect_pct", 0.0) > 0.0:
		var refl: float = float(f.item_fx.get("reflect_pct", 0.0))
		_log_step("%s readies a mirror from %s." % [f.name, _item_label(_item_with_effect([_get_active_weapon(f)], "reflect_pct"))], func():
			if refl > f.status.reflect_pct:
				_animate_item_effect(f, "reflect_pct")
				_animate_pulse(_fighter_sprite(f), Color(0.8, 0.65, 1.0), 1.04)
			_weapon_defense(f, "reflect_pct", refl)
		, _combat_event(f, "shield", " readies a mirror from %s." % _item_label(_item_with_effect([_get_active_weapon(f)], "reflect_pct")), {}))

func _apply_tempo_win_bonus(f: Dictionary, _is_player: bool) -> void:
	var tempo: float = float(f.item_fx.get("tempo_on_win", 0.0))
	if tempo <= 0.0:
		return
	_log_step("%s accelerates via %s." % [f.name, _item_label(_item_with_effect([_get_active_weapon(f)], "tempo_on_win"))], func():
		f.status.tempo_bonus = tempo
		_animate_item_effect(f, "tempo_on_win")
	, _combat_event(f, "buff", " accelerates via %s." % _item_label(_item_with_effect([_get_active_weapon(f)], "tempo_on_win")), {}))

func _initiative(f: Dictionary) -> float:
	var score: float = 10.0
	score += _item_initiative(_get_active_weapon(f)) + float(_hom_synergy(f).get("tempo_flat", 0.0))
	score += float(f.status.get("tempo_bonus", 0.0))
	f.status.tempo_bonus = 0.0
	return score

func _item_initiative(item: Dictionary) -> float:
	if item == null or item.is_empty():
		return 0.0
	return float(_item_effect_value(item, "tempo_flat", 0))

func _pick_enemy_entity(player_type: String) -> String:
	if _entities.is_empty():
		return ""
	var wanted := _type_advantage(player_type)
	var adv_list: Array = []
	var other_list: Array = []
	for e in _entities:
		var t = str(e.get("type", ""))
		if t == wanted:
			adv_list.append(e)
		else:
			other_list.append(e)
	var pool: Array = _entities
	if not adv_list.is_empty() and randf() < 0.6:
		pool = adv_list
	var player_id: String = str(player.get("id", ""))
	if pool.size() > 1 and randf() < 0.85:
		var filtered: Array = []
		for e in pool:
			if str(e.get("id", "")) != player_id:
				filtered.append(e)
		if not filtered.is_empty():
			pool = filtered
	return str(pool[randi() % pool.size()].get("id", ""))

func _pick_enemy_homunculus() -> String:
	if _homunculi.is_empty():
		return ""
	return str(_homunculi[randi() % _homunculi.size()].get("id", ""))

func _pick_enemy_homunculus_balanced(entity_id: String) -> String:
	if _homunculi.is_empty():
		return ""
	var ent := _find_by_id(_entities, entity_id)
	var stats := _get_base_stats(ent)
	var player_power := _combat_power(player)
	var scored: Array = []
	for h in _homunculi:
		var buffs := _get_homunculus_buffs(h)
		var atk := int(stats.atk + buffs.atk)
		var def := int(stats.def + buffs.def)
		var hp := int(stats.hp + buffs.hp)
		var power := _combat_power({"atk": atk, "def": def, "max_hp": hp})
		var delta: float = abs(power - player_power)
		scored.append({"id": str(h.get("id", "")), "delta": delta})
	scored.sort_custom(Callable(self, "_sort_delta"))
	var pick_count: int = int(min(3, scored.size()))
	var pick_index: int = 0
	if pick_count > 1:
		pick_index = randi() % pick_count
	return str(scored[pick_index].get("id", ""))

func _sort_delta(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("delta", 0.0)) < float(b.get("delta", 0.0))

func _combat_power(f: Dictionary) -> float:
	var atk := float(f.get("atk", 0))
	var def := float(f.get("def", 0))
	var hp := float(f.get("max_hp", f.get("hp", 0)))
	return atk * 1.15 + def * 1.0 + hp * 0.45

func _pick_item_id(_random: bool) -> String:
	if _items.is_empty():
		return ""
	return str(_items[randi() % _items.size()].get("id", ""))

func _pick_item_id_unique(exclude: Array[String]) -> String:
	if _items.is_empty():
		return ""
	var candidates: Array = []
	for it in _items:
		var pid := str(it.get("id", ""))
		if not exclude.has(pid):
			candidates.append(it)
	if candidates.is_empty():
		return _pick_item_id(true)
	return str(candidates[randi() % candidates.size()].get("id", ""))

func _item_label(item: Dictionary) -> String:
	if item == null or item.is_empty():
		return "None"
	return str(item.get("name", item.get("id", "")))

func _load_seal(which: String) -> Dictionary:
	var path := "user://seal_%s.json" % which
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

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

func _get_homunculus_buffs(hom: Dictionary) -> Dictionary:
	var out := {"hp": 0, "atk": 0, "def": 0}
	if hom == null or hom.is_empty():
		return out
	out.hp = int(hom.get("buff_hp", 0))
	out.atk = int(hom.get("buff_atk", 0))
	out.def = int(hom.get("buff_def", 0))
	return out

func _find_by_id(arr: Array, pid: String) -> Dictionary:
	for d in arr:
		if str(d.get("id", "")) == pid:
			return d
	return {}

func _as_array(v) -> Array:
	if v is Array:
		return v
	if v is Dictionary:
		return v.values()
	return []

func _load_preview_tex(pid: String, kind: String = "entity", display_name: String = "") -> Texture2D:
	if pid == "":
		return null
	if kind == "homunculus":
		var stem := _resolve_homunculus_stem(pid, display_name)
		var p0 = "%s%s.png" % [GAMEPLAY_HOM_DIR, stem]
		var p1 = "%s%s.png" % [HOM_PREVIEW_256_DIR, stem]
		var p2 = "%s%s_01.png" % [HOM_PREVIEW_256_DIR, stem]
		if ResourceLoader.exists(p0):
			return load(p0)
		if ResourceLoader.exists(p2):
			return load(p2)
		if ResourceLoader.exists(p1):
			return load(p1)
		return null
	var type_norm: String = _normalize_id(display_name)
	var stem_ent: String = str(ENTITY_GAMEPLAY_MAP.get(type_norm, ""))
	var p0e = "%s%s.png" % [GAMEPLAY_ENTITY_DIR, stem_ent]
	var p3 = "%s%s.png" % [PREVIEW_256_DIR, pid]
	var p4 = "%s%s_01.png" % [PREVIEW_256_DIR, pid]
	if stem_ent != "" and ResourceLoader.exists(p0e):
		return load(p0e)
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
	for stem in HOM_PREVIEW_STEMS:
		if id_norm == stem:
			return stem
		if name_norm == stem:
			return stem
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

func _set_item_icon(slot: TextureRect, item: Dictionary) -> void:
	if item == null or item.is_empty():
		slot.texture = null
		slot.visible = false
		slot.set_meta("item", {})
		return
	slot.visible = true
	slot.texture = _load_item_icon(item)
	slot.set_meta("item", item)

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

func _connect_item_tooltips() -> void:
	var slots: Array[TextureRect] = [player_item1, player_item2, enemy_item1, enemy_item2]
	for s in slots:
		s.mouse_entered.connect(func(): _show_item_tooltip(s))
		s.mouse_exited.connect(_hide_item_tooltip)
		s.gui_input.connect(func(event): _on_item_gui_input(event, s))

func _on_item_gui_input(event: InputEvent, slot: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed:
		_show_item_tooltip(slot)

func _show_item_tooltip(slot: TextureRect) -> void:
	var item: Dictionary = slot.get_meta("item", {})
	if item == null or item.is_empty():
		return
	var item_name: String = str(item.get("name", item.get("id", "")))
	var desc: String = str(item.get("desc", ""))
	tooltip_label.text = "%s\n%s" % [item_name, _alchemy_flair(desc)]
	item_tooltip.visible = true
	var min_size := tooltip_label.get_minimum_size()
	item_tooltip.custom_minimum_size = min_size + Vector2(16, 16)
	item_tooltip.size = item_tooltip.custom_minimum_size
	# Clamp tooltip inside viewport
	var vp := get_viewport_rect()
	var pos := get_viewport().get_mouse_position() + Vector2(16, 16)
	var tip_size := item_tooltip.size
	if pos.x + tip_size.x > vp.size.x:
		pos.x = max(8.0, vp.size.x - tip_size.x - 8.0)
	if pos.y + tip_size.y > vp.size.y:
		pos.y = max(8.0, vp.size.y - tip_size.y - 8.0)
	item_tooltip.global_position = pos

func _hide_item_tooltip() -> void:
	item_tooltip.visible = false

func _alchemy_flair(desc: String) -> String:
	if desc == "":
		return ""
	return desc

func _log(msg: String, event: Dictionary = {}) -> void:
	_step_queue.append({"msg": msg, "action": Callable(), "event": event})

func _actor_color(fighter: Dictionary, homunculus: bool = false) -> String:
	if is_same(fighter, player):
		return "85dca2" if homunculus else "69d7e8"
	return "c6a5f5" if homunculus else "f2a078"

func _combat_event(fighter: Dictionary, category: String, verb: String, details: Dictionary, homunculus: bool = false) -> Dictionary:
	var event := details.duplicate()
	event["category"] = category
	event["actor"] = str(fighter.get("hom_name" if homunculus else "name", ""))
	event["actor_kind"] = "homunculus" if homunculus else "entity"
	event["actor_side"] = "player" if is_same(fighter, player) else "enemy"
	event["actor_color"] = _actor_color(fighter, homunculus)
	event["verb"] = verb
	if homunculus:
		event["parent"] = str(fighter.get("name", ""))
		event["parent_color"] = _actor_color(fighter)
	return event

func _log_step(msg: String, action: Callable, event: Dictionary = {}) -> void:
	_step_queue.append({"msg": msg, "action": action, "event": event})

func _log_immediate(msg: String) -> void:
	_append_combat_log(msg)

func _append_combat_log(msg: String, event: Dictionary = {}) -> void:
	var scroll := log_box.get_v_scroll_bar()
	var following := scroll == null or scroll.value >= scroll.max_value - scroll.page - 2.0
	log_box.scroll_following = following
	_log_presenter.append(log_box, _display_turn(), msg, event)

func _fighter_sprite(fighter: Dictionary, homunculus: bool = false) -> Control:
	if is_same(fighter, player):
		return player_hom if homunculus else player_entity
	return enemy_hom if homunculus else enemy_entity

func _begin_animation(node: Control) -> Tween:
	_restore_animation(node)
	_animation_original[node] = {"position": node.position, "scale": node.scale, "rotation": node.rotation, "modulate": node.modulate, "pivot": node.pivot_offset}
	node.pivot_offset = node.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_animation_tweens[node] = tween
	tween.finished.connect(func(): _restore_animation(node))
	return tween

func _restore_animation(node: Control) -> void:
	if _animation_tweens.has(node):
		var tween: Tween = _animation_tweens[node]
		if tween.is_valid():
			tween.kill()
		_animation_tweens.erase(node)
	if _animation_original.has(node):
		var original: Dictionary = _animation_original[node]
		if is_instance_valid(node):
			node.position = original.position
			node.scale = original.scale
			node.rotation = original.rotation
			node.modulate = original.modulate
			node.pivot_offset = original.pivot
		_animation_original.erase(node)

func _reset_animations() -> void:
	for node in _animation_original.keys():
		_restore_animation(node)

func _exit_tree() -> void:
	_clear_solo_power()
	_reset_animations()
	if is_instance_valid(_reg):
		_reg.free()
		_reg = null

func _animate_lunge(node: Control, distance: float, scale_up: bool) -> void:
	var tween := _begin_animation(node)
	var original: Dictionary = _animation_original[node]
	tween.set_parallel(true)
	tween.tween_property(node, "position", original.position + Vector2(distance, 0), 0.12)
	if scale_up:
		tween.tween_property(node, "scale", original.scale * 1.05, 0.12)
	tween.chain().tween_property(node, "position", original.position, 0.16)
	if scale_up:
		tween.parallel().tween_property(node, "scale", original.scale, 0.16)

func _animate_hit(node: Control, damage: int, max_hp: int) -> void:
	var tween := _begin_animation(node)
	var original: Dictionary = _animation_original[node]
	var intensity := clampf(float(damage) / maxf(float(max_hp), 1.0), 0.04, 0.5)
	var shake := 2.0 + intensity * 12.0
	tween.set_parallel(true)
	tween.tween_property(node, "position", original.position + Vector2(shake, 0), 0.07)
	tween.tween_property(node, "modulate", original.modulate.lerp(Color(1.0, 0.15, 0.15, original.modulate.a), 0.35 + intensity), 0.07)
	tween.chain().tween_property(node, "position", original.position - Vector2(shake, 0), 0.07)
	tween.chain().tween_property(node, "position", original.position, 0.12)
	tween.parallel().tween_property(node, "modulate", original.modulate, 0.12)

func _animate_pulse(node: Control, color: Color, factor: float) -> void:
	var tween := _begin_animation(node)
	var original: Dictionary = _animation_original[node]
	tween.set_parallel(true)
	tween.tween_property(node, "scale", original.scale * factor, 0.12)
	tween.tween_property(node, "modulate", original.modulate.lerp(color, 0.5), 0.12)
	tween.chain().tween_property(node, "scale", original.scale, 0.16)
	tween.parallel().tween_property(node, "modulate", original.modulate, 0.16)

func _animate_item_effect(fighter: Dictionary, effect: String) -> void:
	var slots := [player_item1, player_item2] if is_same(fighter, player) else [enemy_item1, enemy_item2]
	var i := int(fighter.get("active_weapon_slot", 1)) - 1
	if _get_active_weapon(fighter).get("effects", {}).has(effect):
		_animate_pulse(slots[i], Color.WHITE, 1.12)

func _flush_steps() -> void:
	if _processing_steps:
		return
	_processing_steps = true
	for step in _step_queue:
		if _combat_session_invalid:
			break
		var msg := str(step.get("msg", ""))
		if msg != "":
			_append_combat_log(msg, step.get("event", {}))
		var action: Callable = step.get("action", Callable())
		if action.is_valid():
			action.call()
		_update_ui()
		var category := str(step.get("event", {}).get("category", "system"))
		var delay := 1.35 if category == "combo" else 1.25 if category in ["debuff", "shield"] else 0.8 if category == "system" else LOG_STEP_SECONDS
		await get_tree().create_timer(delay).timeout
	_step_queue.clear()
	_processing_steps = false

func _display_turn() -> int:
	return maxi(1, _turn)

func _scroll_log_to_bottom() -> void:
	await get_tree().process_frame
	var lc := log_box.get_line_count()
	if lc > 0:
		log_box.scroll_to_line(lc - 1)

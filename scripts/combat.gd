extends Control

const REG_PATH := "res://scripts/data_registry.gd"
const SpellLoadout := preload("res://scripts/domain/spell_loadout.gd")
const CombatLogPresenter := preload("res://scripts/ui/combat_log_presenter.gd")
const CombatVFX := preload("res://scripts/ui/combat_vfx.gd")
const CombatTypeIcon := preload("res://scripts/ui/combat_type_icon.gd")
const CombatHomStatus := preload("res://scripts/ui/combat_hom_status.gd")
const CombatInspiration := preload("res://scripts/ui/combat_inspiration.gd")
const ExpeditionPassive := preload("res://scripts/domain/expedition_passive.gd")
const SpellPresentation := preload("res://scripts/ui/spell_presentation.gd")
const Stats := preload("res://scripts/ui/stat_presentation.gd")
const PREVIEW_256_DIR := "res://assets/entities/previews_256/"
const HOM_PREVIEW_256_DIR := "res://assets/entities/previews_256/homunculus/"
const BUILD_DIR := "res://assets/entities/builds/"
const GAMEPLAY_ENTITY_DIR := "res://assets/entities/gameplay/"
const GAMEPLAY_HOM_DIR := "res://assets/entities/gameplay/homunculus/"
const COMBAT_HOM_TEXTURES := {
	"chimera": preload("res://assets/entities/gameplay/homunculus/ingame/1024/Chimera.png"),
	"cinder": preload("res://assets/entities/gameplay/homunculus/ingame/1024/Cinder.png"),
	"drakon": preload("res://assets/entities/gameplay/homunculus/ingame/1024/Drakon.png"),
	"mothy": preload("res://assets/entities/gameplay/homunculus/ingame/1024/Mothy.png"),
	"nighty": preload("res://assets/entities/gameplay/homunculus/ingame/1024/Nighty.png"),
	"pyro": preload("res://assets/entities/gameplay/homunculus/ingame/1024/Pyro.png"),
	"silphide": preload("res://assets/entities/gameplay/homunculus/ingame/1024/Silphide.png"),
	"sodi": preload("res://assets/entities/gameplay/homunculus/ingame/1024/Sodi.png"),
}
const COMBAT_ENTITY_TEXTURES := {
	"aether": preload("res://assets/entities/gameplay/ingame-entities/aether/aether_2_5d_1024.png"),
	"gold": preload("res://assets/entities/gameplay/ingame-entities/gold/gold_2_5d_1024.png"),
	"mercury": preload("res://assets/entities/gameplay/ingame-entities/mercury/mercury_2_5d_1024.png"),
	"sodium": preload("res://assets/entities/gameplay/ingame-entities/sodium/sodium_2_5d_1024.png"),
	"sulfur": preload("res://assets/entities/gameplay/ingame-entities/sulfur/sulfur_2_5d_1024.png"),
	"vitriol": preload("res://assets/entities/gameplay/ingame-entities/vitriol/vitriol_2_5d_1024.png"),
}
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
var _spell_hold_token := 0
var _spell_hold_index := -1
var _spell_hold_open := false
var _spell_hold_overlay: Control
var _highlights := {"damage": 0, "damage_text": "", "reflection": 0, "reflection_text": ""}
var _spell_damage_totals := {}
var _combat_backend: BackendClient
var _ranked_controller: Node
var _hom_action_outlines: Array[Panel] = []
var _hom_outline_tween: Tween
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
var _decision_spacer_before := -1.0
var _decision_growth_before := 0
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
var _online_hunt_guard := false
var _dungeon_guard := false
var _dungeon_session: Dictionary = {}
var _dungeon_request := ""
var _blessing_panel: PanelContainer
var _blessing_cards: Array[Button] = []
var _dungeon_blessing_log_key := ""
var _dungeon_kind := ""
var _dungeon_pending: Dictionary = {}
var _dungeon_hom_choice: Dictionary = {}
var _dungeon_identity := ""
var _dungeon_brief: ConfirmationDialog
var _dungeon_floor_label: Label
var _dungeon_brief_floor := 0
var _dungeon_encounter_log_key := ""
var _dungeon_encounter_details := {}
static var _dungeon_last_brief_key := ""
var _dungeon_seen_actions := {}
var _spectator_readonly := false
var _spectator_controller: Node
var _dungeon_playing_events := false
var _gate_epoch := 0
var _gate_session_verified := false
var _dungeon_presentation_turn := -1
var _dungeon_rank_loaded := false
var _dungeon_best := -1
var _dungeon_rank_floor := -1
var _dungeon_synchronized := false
var _physical_anomaly: Dictionary = {}
var _physical_anomaly_label: Label
var _physical_anomaly_display_id := ""
var _strategic_delays: Array = []
var _strategic_jams: Array = []
var _pending_drains: Array = []
var _online_hunt_request := ""
var _online_hunt_session: Dictionary = {}
var _online_hunt_revision := 0
var _online_turn_request := ""
var _online_turn_payload: Dictionary = {}
var _online_hom_payload: Dictionary = {}
var _online_processed_turns := {}
var _online_presenting_events := false
var _online_terminal_shown := false
var _reward_popup_shown := false
static var _global_reward_presented := {}
var _global_reward_popup_layer: CanvasLayer
var _online_identity_invalid := false
var _online_event_turn := -1
var _online_hunt_info: Label
var _online_inspected_minion := ""
var _online_visible_minions: Array[String] = []
var _solo_context := {}
var _solo_forfeit_request := ""
var _solo_forfeit_action := ""
var _online_exit_reconciled := false
var _online_closed_recovery := ""
var _solo_def := {}
var _solo_texture: Texture2D
var _solo_minion_texture: Texture2D
var _solo_minions: Array = []
var _solo_minion_views: Array[Control] = []
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
var _solo_intent_button: Button

func _boss_ability_description(ability: String) -> String:
	match ability:
		"Strike": return "Strike: 90% base accuracy. Damage scales with boss HP: above 70% x1, above 40% x1.2, above 15% x1.4, otherwise x1.6. Normal defenses apply; living minions halve ordinary Strike damage."
		"Summon": return "Summon creates independent minions once per battle. Defeat all living minions to expose the boss. Each surviving minion attacks once per exchange, starting next exchange."
		"Shield": return "Alchemical Shield: %d%% direct damage mitigation for %d exchanges. Restores %d%% of prevented damage. One activation above 50%% HP and one at or below 50%%, subject to cooldown." % [roundi(float(_solo_def.get("shield_reduction", 0)) * 100), int(_solo_def.get("shield_turns", 0)), roundi(float(_solo_def.get("shield_heal_ratio", 0)) * 100)]
		"Power": return "Power Turn doubles direct spell and homunculus damage against the boss for this exchange. Poison, damage over time and reflection are not doubled. It happens once per battle; if the boss survives, Fury follows."
		"Fury": return "Fury is a retaliatory Strike at %s power after the boss survives your Power Turn. It replaces ordinary Strike scaling and is not an extra turn. Stun delays it without consuming it." % Stats.percent(float(_solo_def.get("fury_mult", 1.0)))
		"Poison": return "Poison deals periodic damage at the end of an exchange while active. Remaining duration: %d turns." % int(enemy.get("status", {}).get("poison", 0))
		"Stun": return "Stun prevents the boss from acting. Fury remains pending until an offensive action executes. Remaining duration: %d turns." % int(enemy.get("status", {}).get("stun", 0))
	return ""

func _show_boss_ability(ability: String) -> void:
	var description := _boss_ability_description(ability)
	if not description.is_empty() and is_instance_valid(_spell_detail):
		_spell_detail.title = "Boss Action Details"
		_spell_detail.dialog_text = description
		_spell_detail.popup_centered(Vector2i(440, 260))

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
var _step_hit_target := ""
var _step_hit_damage := 0
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
var _next_turn_action := ""
@onready var switch_weapon_btn: Button = $SwitchWeapon
@onready var ultra_button: Button = $Ultraturn
@onready var hom_decision: VBoxContainer = $HomDecision
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
	set_meta("combat_font", true)
	_spectator_readonly = not SceneRouter._spectator_context.is_empty()
	backend_url = preload("res://scripts/net/backend_endpoint.gd").resolve(backend_url)
	player_entity.flip_h = false
	player_hom.flip_h = false
	enemy_entity.flip_h = true
	enemy_hom.flip_h = true
	_fit_combat_view()
	get_viewport().size_changed.connect(_fit_combat_view)
	_load_registry_safe()
	_setup_combat_log()
	_setup_physical_anomaly_ui()
	_setup_hp_styles()
	_setup_hom_ui()
	if OS.has_feature("android"):
		player_entity.offset_left += 70
		player_entity.offset_right += 70
		enemy_entity.offset_left -= 70
		enemy_entity.offset_right -= 70
	var enemy_hom_frame := enemy_hom.get_parent() as Control
	enemy_hom_frame.resized.connect(_align_enemy_hom_to_circle, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_align_enemy_hom_to_circle, CONNECT_DEFERRED)
	call_deferred("_align_enemy_hom_to_circle")
	_setup_combat_labels()
	if OS.has_feature("android"):
		call_deferred("_raise_enemy_title")
	var spectator_indicator := preload("res://scripts/ui/spectator_indicator.gd").new()
	$PlayerPanel.add_child(spectator_indicator)
	spectator_indicator.position = Vector2(20, 125)
	spectator_indicator.visible = false
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
	if OS.has_feature("android"):
		get_viewport().size_changed.connect(_layout_android_combat, CONNECT_DEFERRED)
		child_entered_tree.connect(_keep_android_back_on_top)
		call_deferred("_layout_android_combat")
	next_turn_btn.hide()
	spell_panel.hide()
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if confirm_stay:
		confirm_stay.pressed.connect(_on_confirm_stay)
	if confirm_leave:
		confirm_leave.pressed.connect(_on_confirm_leave)
	_style_leave_confirmation()
	_begin_combat_initialization()

func _style_leave_confirmation() -> void:
	var art = preload("res://scripts/ui/menu_art.gd")
	confirm_popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var panel := confirm_popup.get_node("Panel") as PanelContainer
	panel.add_theme_stylebox_override("panel", art.frame("panel_horizontal.png", Vector4(65, 38, 65, 32)))
	var title := confirm_popup.get_node("Panel/VBox/Title") as Label
	title.add_theme_font_size_override("font_size", 24)
	var body := confirm_popup.get_node("Panel/VBox/Body") as Label
	body.add_theme_font_size_override("font_size", 17)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for button in [confirm_stay, confirm_leave]:
		art.button(button)
		button.custom_minimum_size = Vector2(155, 46)

func _fit_combat_view() -> void:
	var available := get_viewport_rect().size
	if available.x <= 0 or available.y <= 0:
		return
	var factor := minf(available.x / 1920.0, available.y / 1080.0)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = available / factor
	scale = Vector2.ONE * factor

func _align_enemy_hom_to_circle() -> void:
	# Dungeon and world encounters position their sprites in dedicated layers.
	if enemy_hom.get_parent().name != "EnemyHomFrame":
		return
	var inverse := get_global_transform().affine_inverse()
	var rect := enemy_hom.get_global_rect()
	var top_left: Vector2 = inverse * rect.position
	var bottom_right: Vector2 = inverse * rect.end
	var dimensions := bottom_right - top_left
	var image_bottom := top_left.y + (dimensions.y + minf(dimensions.x, dimensions.y)) / 2.0
	var target := Vector2(size.x * 1730.0 / 1920.0, size.y * 505.0 / 1080.0)
	var delta := target - Vector2(top_left.x + dimensions.x / 2.0, image_bottom)
	enemy_hom.position += delta
	if OS.has_feature("android") and is_instance_valid(_enemy_hom_status):
		var status_width := maxf(_enemy_hom_status.size.x, _enemy_hom_status.get_combined_minimum_size().x)
		_enemy_hom_status.position = Vector2(clampf(target.x - status_width / 2.0, 0.0, maxf(0.0, size.x - status_width)), target.y + 24.0)

func _raise_enemy_title() -> void:
	if not is_instance_valid(enemy_name) or enemy_name.get_parent() != $EnemyPanel:
		return
	var previous_position := enemy_name.position
	var holder := Node2D.new()
	holder.name = "EnemyTitleAnchor"
	$EnemyPanel.add_child(holder)
	enemy_name.reparent(holder, false)
	enemy_name.position = previous_position - Vector2(0, 60)

func _setup_combat_log() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.045, 0.9)
	style.border_color = Color("95834f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	$LogBG.add_theme_stylebox_override("panel", style)
	log_box.set_meta("global_chat_font", true)
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
	if meta is Dictionary and meta.has("ability"):
		if str(meta.ability).begins_with("dungeon_encounter:"):
			var encounter: Variant = _dungeon_encounter_details.get(str(meta.ability))
			if encounter is Dictionary:
				_spell_detail.title = str(encounter.get("label", "Encounter"))
				_spell_detail.dialog_text = str(encounter.get("hint", ""))
				_spell_detail.popup_centered(Vector2i(440, 260))
			return
		_show_boss_ability(str(meta.ability))
		return
	if _reg == null:
		return
	var spell_id := str(meta.get("id", "")) if meta is Dictionary else str(meta)
	var spell: Dictionary = _reg.get_spell_by_id(spell_id)
	if spell.is_empty():
		return
	_spell_detail.title = "Spell Details"
	_spell_detail.dialog_text = _spell_description(spell)
	if meta is Dictionary and meta.get("context") is Dictionary:
		var damage := int(meta.context.get("actual_damage", 0))
		if damage > 0:
			_spell_detail.dialog_text += "\nRecorded damage: %d" % damage
	_spell_detail.popup_centered(Vector2i(440, 260))

func _on_log_spell_hovered(meta: Variant) -> void:
	if meta is Dictionary and meta.has("ability"):
		if str(meta.ability).begins_with("dungeon_encounter:"):
			var encounter: Variant = _dungeon_encounter_details.get(str(meta.ability))
			log_box.tooltip_text = str(encounter.get("hint", "")) if encounter is Dictionary else ""
			return
		log_box.tooltip_text = _boss_ability_description(str(meta.ability))
		return
	if _reg != null:
		var spell_id := str(meta.get("id", "")) if meta is Dictionary else str(meta)
		var spell: Dictionary = _reg.get_spell_by_id(spell_id)
		log_box.tooltip_text = _spell_description(spell) if not spell.is_empty() else ""

func _spell_description(spell: Dictionary) -> String:
	for effect in spell.get("effects", []):
		if effect.get("kind") == "physical_anomaly":
			return SpellPresentation.anomaly_detail(spell, effect)
	var lines: Array[String] = []
	for effect in spell.get("effects", []):
		var strategic := SpellPresentation.localized_strategic_detail(effect)
		if not strategic.is_empty():
			lines.append(strategic)
			continue
		var extra: Array[String] = []
		for key in effect:
			if key not in ["kind", "value", "target"]:
				extra.append("%s: %s" % [GameLocalization.catalog("stat", str(key), "name", str(key).replace("_", " ").capitalize()), Stats.effect_value(str(effect.get("kind", "")), effect[key], str(key))])
		var kind := str(effect.get("kind", ""))
		var target := str(effect.get("target", ""))
		lines.append("%s: %s (%s)%s" % [GameLocalization.catalog("effect_kind", kind, "name", kind.replace("_", " ").capitalize()), Stats.effect_value(kind, effect.get("value", "")), GameLocalization.catalog("effect_target", target, "name", target), "; " + ", ".join(extra) if not extra.is_empty() else ""])
	var id := str(spell.get("id", ""))
	var spell_type := str(spell.get("type", ""))
	var category := str(spell.get("category", ""))
	return tr("COMBAT_SPELL_TOOLTIP").replace("\\n", "\n") % [GameLocalization.catalog("spell", id, "name", str(spell.get("name", ""))), GameLocalization.catalog("type", spell_type, "name", spell_type.capitalize()), GameLocalization.catalog("spell_category", category, "name", category.capitalize()), Stats.percent(float(spell.get("power_mult", 0))), int(round(float(spell.get("accuracy", 0)) * 100)), int(spell.get("cooldown_turns", 0)), ", ".join(lines) if not lines.is_empty() else tr("COMBAT_NO_EFFECTS"), GameLocalization.catalog("spell", id, "desc", str(spell.get("desc", "")))]

func _status_effect_text(kind: String, value: float) -> String:
	var label := GameLocalization.catalog("effect_kind", kind, "name", kind.replace("_", " ").capitalize())
	if kind in ["poison", "hom_stun"]:
		return "%s %dT" % [label, int(value)]
	return "%s %d%%" % [label, roundi(value * 100.0)]

func _dungeon_on_identity(state: Dictionary) -> void:
	if not _dungeon_guard:
		return
	if state.is_empty() or _combat_backend == null or _dungeon_identity.is_empty() or _combat_backend._verified_player_id != _dungeon_identity:
		_dungeon_synchronized = false
		_dungeon_refresh_controls()
		return
	if _dungeon_request.is_empty():
		_dungeon_recover()

func _dungeon_on_auth_changed(_token: String) -> void:
	_dungeon_playing_events = false
	_dungeon_presentation_turn = -1
	_dungeon_request = ""
	_dungeon_synchronized = false
	_dungeon_show_retry("Account changed. Sign in with the original account.")

func _dungeon_recover() -> void:
	if _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity or not _dungeon_request.is_empty():
		return
	if not _dungeon_session.is_empty():
		return
	var session: Variant = SceneRouter._dungeon_context.get("session")
	if not session is Dictionary or str(session.get("run_id", "")) != str(SceneRouter._dungeon_context.get("run_id", "")) or str(session.get("status", "")) != "ACTIVE" or not session.get("combat_state") is Dictionary:
		_dungeon_show_retry("Dungeon unavailable. Return to Sync Nexus.")
		return
	_dungeon_session = session.duplicate(true)
	SceneRouter._dungeon_context.erase("session")
	_dungeon_synchronized = true
	_dungeon_render()

func _dungeon_show_retry(message: String) -> void:
	_dungeon_synchronized = false
	_log_immediate(message)
	_set_next_turn_action("retry")
	next_turn_btn.show()
	_dungeon_refresh_controls()

func _dungeon_send_pending() -> void:
	if _spectator_readonly: return
	if _dungeon_pending.is_empty() or not _dungeon_request.is_empty() or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity:
		return
	_dungeon_kind = str(_dungeon_pending.get("kind", ""))
	_dungeon_request = _combat_backend.request_api("POST", "/dungeon/" + _dungeon_kind, _dungeon_pending.get("payload", {}).duplicate(true), false, _connection_gate().blocked() and _gate_session_verified)
	if _dungeon_request.is_empty():
		_dungeon_show_retry("Request unresolved. Retry recovery.")
	_dungeon_refresh_controls()

func _dungeon_on_response(request_id: String, ok: bool, data: Dictionary) -> void:
	if ok and not _spectator_readonly and not request_id.is_empty() and request_id == _dungeon_request and _combat_backend != null and _combat_backend._verified_player_id == _dungeon_identity and _dungeon_identity == str(ConnectionGate.player_id): GlobalChatClient.apply_combat_spectators(data)
	if request_id.is_empty() or request_id != _dungeon_request:
		return
	_dungeon_request = ""
	if _connection_gate().blocked() and (not _connection_gate()._player_verified or (_dungeon_kind != "session" and not _gate_session_verified)):
		_dungeon_synchronized = false
		return
	if _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity or _dungeon_identity.is_empty():
		_dungeon_show_retry("Account changed. Return to Sync Nexus.")
		return
	if _dungeon_kind == "ranking":
		if ok:
			var previous_best := _dungeon_best
			var own: Variant = data.get("player")
			_dungeon_best = int(own.get("cleared_floor", 0)) if own is Dictionary else 0
			_dungeon_rank_loaded = true
			var current_floor := int(_dungeon_session.get("combat_state", {}).get("floor", 0))
			if str(_dungeon_session.get("phase", "")) == "FLOOR_CLEARED" and previous_best >= 0 and current_floor > previous_best and _dungeon_best >= current_floor:
				_log_immediate("NEW PERSONAL BEST%s" % (" | Rank #%d" % int(own.get("rank", 0)) if own is Dictionary else ""))
			elif str(_dungeon_session.get("status", "")) == "LOSS" and own is Dictionary:
				_log_immediate("Monthly best: Floor %d | Rank #%d" % [_dungeon_best, int(own.get("rank", 0))])
		_dungeon_refresh_controls()
		_refresh_dungeon_blessing()
		return
	if not ok and str(data.get("error", "")) in ["Dungeon run unavailable or stale.", "Dungeon run is closed."]:
		_dungeon_synchronized = false
		_connection_gate().dungeon_finished()
		_log_immediate("Dungeon session ended. Return to Sync Nexus.")
		_set_next_turn_action("return")
		next_turn_btn.show()
		_dungeon_refresh_controls()
		return
	if not ok and str(data.get("error", "")) in ["INVALID_DECISION", "UNSUPPORTED_MECHANIC", "Floor not cleared."]:
		_dungeon_pending.clear()
		SceneRouter._dungeon_context.erase("pending_action")
		_log_immediate("Action rejected: " + str(data.get("error", "")))
		_dungeon_synchronized = true
		_dungeon_refresh_controls()
		return
	if not ok or str(data.get("run_id", "")) != str(SceneRouter._dungeon_context.get("run_id", "")) or not data.get("combat_state") is Dictionary or int(data.get("combat_revision", 0)) != int(_dungeon_pending.get("payload", {}).get("expected_revision", -1)) + 1:
		_dungeon_synchronized = false
		_log_immediate("Dungeon session ended. Return to Sync Nexus.")
		_set_next_turn_action("return")
		next_turn_btn.show()
		_dungeon_refresh_controls()
		return
	if str(data.get("status", "")) != "ACTIVE": _connection_gate().dungeon_finished()
	var action_id := str(_dungeon_pending.get("payload", {}).get("client_action_id", ""))
	if not _dungeon_seen_actions.has(action_id):
		_dungeon_seen_actions[action_id] = true
		var generation := _combat_backend._session_generation
		var run_id := str(SceneRouter._dungeon_context.get("run_id", ""))
		var revision := int(data.combat_revision)
		_dungeon_playing_events = true
		_dungeon_presentation_turn = int(data.get("combat_state", {}).get("turn", 0))
		_dungeon_refresh_controls()
		var playback_epoch := _gate_epoch
		await _dungeon_present_events(data.get("events", []), _dungeon_identity, generation, run_id, action_id, revision, playback_epoch)
		if not _dungeon_playback_valid(_dungeon_identity, generation, run_id, action_id, revision, playback_epoch):
			if playback_epoch == _gate_epoch:
				_dungeon_playing_events = false
				_dungeon_presentation_turn = -1
			return
		_dungeon_playing_events = false
		_dungeon_presentation_turn = -1
		if not is_inside_tree() or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity:
			return
	_dungeon_pending.clear()
	SceneRouter._dungeon_context.erase("pending_action")
	if int(data.combat_revision) >= int(_dungeon_session.get("combat_revision", 0)):
		_dungeon_session = data.duplicate(true)
		_dungeon_synchronized = true
		_dungeon_render()
		connection_gate_recover()
	else:
		_dungeon_recover()

func _dungeon_playback_valid(owner: String, generation: int, run_id: String, action_id: String, revision: int, playback_epoch: int) -> bool:
	if _spectator_readonly:
		return is_instance_valid(_spectator_controller) and _spectator_controller.valid_playback(owner, generation, action_id, playback_epoch)
	return is_inside_tree() and playback_epoch == _gate_epoch and _combat_backend != null and _combat_backend._session_generation == generation and _combat_backend._verified_player_id == owner and not owner.is_empty() and str(SceneRouter._dungeon_context.get("run_id", "")) == run_id and str(_dungeon_pending.get("payload", {}).get("client_action_id", "")) == action_id and int(_dungeon_pending.get("payload", {}).get("expected_revision", -1)) + 1 == revision and int(_dungeon_session.get("combat_revision", 0)) <= revision

func _dungeon_present_events(events: Array, owner: String, generation: int, run_id: String, action_id: String, revision: int, playback_epoch: int) -> void:
	var view: Dictionary = _dungeon_session.get("combat_state", {}).duplicate(true)
	for event in events:
		if not _dungeon_playback_valid(owner, generation, run_id, action_id, revision, playback_epoch):
			return
		if not event is Dictionary:
			continue
		var kind := str(event.get("kind", ""))
		var actor := str(event.get("actor", ""))
		var target := str(event.get("side", event.get("target", "")))
		if kind == "hom_passive" and event.has("effects"):
			if actor in ["player", "npc"]: CombatVFX.passive(player_hom if actor == "player" else enemy_hom, player_entity if actor == "player" else enemy_entity)
			var passive_hom: Dictionary = _reg.get_homunculus_collection().get(str(event.get("hom_id", "")), {}) if _reg else {}
			if not passive_hom.is_empty():
				_append_combat_log(_log_presenter.passive_message(event, passive_hom), {"category":"homunculus"})
			else:
				_append_combat_log("Homunculus passive activated.", {"category":"homunculus"})
			await get_tree().create_timer(0.65).timeout
			if not _dungeon_playback_valid(owner, generation, run_id, action_id, revision, playback_epoch): return
			continue
		if target not in ["player", "npc"] and actor in ["player", "npc"] and kind in ["damage", "hom_attack", "true_on_hit", "dot_true", "hom_dot", "delayed_damage"]:
			target = "npc" if actor == "player" else "player"
		elif target not in ["player", "npc"] and event.has("hp") and actor in ["player", "npc"]:
			target = actor
		var combo := _dungeon_strategic_event(event)
		var category := "combo" if not combo.is_empty() else "switch" if kind == "switch" else "damage" if kind in ["damage", "hom_attack", "true_on_hit", "dot_true", "hom_dot", "delayed_damage", "poison"] else "heal" if kind == "heal" else "debuff" if kind == "status_applied" else "system"
		var actor_id := actor if actor in ["player", "npc"] else target
		var fighter: Dictionary = view.get(actor_id, {})
		var actor_sprite: Control = player_entity if actor_id == "player" else enemy_entity
		var target_sprite: Control = player_entity if target == "player" else enemy_entity
		if kind == "spell" and actor_id in ["player", "npc"]:
			var action_spell: Dictionary = _reg.get_spell_by_id(str(event.get("spell_id", ""))) if _reg else {}
			if str(action_spell.get("category", "")) == "attack" or str(event.get("spell_id", "")) == "basic_attack":
				_animate_lunge(actor_sprite, 20.0 if actor_id == "player" else -20.0, true)
				if bool(event.get("hit", false)):
					CombatVFX.hit_fighter(enemy_entity if actor_id == "player" else player_entity, fighter)
				if not bool(event.get("hit", true)):
					_animate_lunge(enemy_entity if actor_id == "player" else player_entity, 8.0 if actor_id == "player" else -8.0, false)
			else:
				_animate_pulse(actor_sprite, Color(0.68, 0.85, 1.0), 1.04)
		elif kind in ["hom_attack", "hom_miss"] and actor in ["player", "npc"]:
			_animate_lunge(player_hom if actor == "player" else enemy_hom, 12.0 if actor == "player" else -12.0, false)
		elif kind in ["evade", "miss"] and actor_id in ["player", "npc"]:
			_animate_lunge(actor_sprite, -8.0 if actor_id == "player" else 8.0, false)
			if kind == "evade" and actor_id == "player":
				var active_slot := int(view.get("active_weapon_slot", 0))
				if active_slot in [1, 2]: _animate_pulse(player_item1 if active_slot == 1 else player_item2, Color.WHITE, 1.12)
		elif kind == "physical_anomaly_cast":
			_show_physical_anomaly(event.get("anomaly"))
			_animate_pulse(player_entity, Color(0.76, 0.72, 1.0), 1.03)
			_animate_pulse(enemy_entity, Color(0.76, 0.72, 1.0), 1.03)
		elif kind in ["switch", "true_on_hit", "dot_true", "evade"] and actor_id == "player":
			var slot := int(event.get("slot", view.get("active_weapon_slot", 0)))
			if slot in [1, 2]:
				_animate_pulse(player_item1 if slot == 1 else player_item2, Color.WHITE, 1.12)
			if kind == "switch":
				view["active_weapon_slot"] = slot
		elif kind in ["status_applied", "heal", "buff_steal", "debuff_transfer", "cooldown_jam", "ward_convert", "hom_energy_siphon"] and target in ["player", "npc"]:
			_animate_pulse(target_sprite, Color(0.72, 0.9, 0.84), 1.03)
		elif kind == "inspiration" and actor_id in ["player", "npc"]:
			var meter: Control = _player_inspiration if actor_id == "player" else _enemy_inspiration
			meter.call("set_fighter", {"inspiration": int(event.get("value", 0)), "inspiration_used_this_battle": false})
			_animate_pulse(meter, Color(0.78, 0.7, 1.0), 1.05)
		var entity: Dictionary = _find_by_id(_entities, str(fighter.get("id", "")))
		var actor_name := str(entity.get("name", fighter.get("id", "Combat")))
		var formatted := {"category": category, "actor": actor_name, "actor_kind": "entity", "actor_side": "player" if actor_id == "player" else "enemy", "actor_color": "69d7e8" if actor_id == "player" else "f2a078", "verb": " " + kind.replace("_", " ")}
		if target in ["player", "npc"] and target != actor_id and view.get(target) is Dictionary:
			var target_entity: Dictionary = _find_by_id(_entities, str(view[target].get("id", "")))
			formatted["target"] = " " + str(target_entity.get("name", view[target].get("id", "")))
			formatted["target_color"] = "69d7e8" if target == "player" else "f2a078"
		if event.has("spell_id"):
			var spell: Dictionary = _reg.get_spell_by_id(str(event.spell_id))
			formatted["verb"] = " uses " if kind == "spell" else " " + kind.replace("_", " ") + " with "
			formatted["spell_id"] = str(event.spell_id)
			formatted["spell_name"] = str(spell.get("name", event.spell_id))
			if kind == "spell" and event.has("hit") and not bool(event.hit):
				formatted["category"] = "miss"
				formatted["suffix"] = " — misses."
		if event.has("amount"):
			formatted["suffix"] = " %d" % int(event.amount)
		if kind == "elite_trait_triggered":
			formatted["verb"] = " activates " + str(event.get("label", "elite ability"))
		_append_combat_log(combo, {"category": "combo"} if not combo.is_empty() else formatted)
		if target in ["player", "npc"] and view.get(target) is Dictionary:
			var target_view: Dictionary = view[target]
			if event.get("target_status") is Dictionary:
				target_view.status = event.target_status.duplicate(true)
			if event.has("hp"):
				var bar: ProgressBar = player_hp if target == "player" else enemy_hp
				var next_hp := int(event.hp)
				var lost := maxi(0, int(bar.value) - next_hp)
				if lost > 0:
					_animate_hit(target_sprite, lost, int(target_view.max_hp))
					_show_damage_number(target_sprite, lost)
				await get_tree().create_timer(0.26).timeout
				if not _dungeon_playback_valid(owner, generation, run_id, action_id, revision, playback_epoch):
					return
				target_view.hp = next_hp
				_set_display_hp(bar, next_hp)
			if kind == "status_applied":
				target_view.status[str(event.get("status", ""))] = event.get("value", 0)
			elif kind in ["status_consumed", "status_cleansed"]:
				target_view.status[str(event.get("status", ""))] = event.get("remaining", 0)
			elif kind == "poison":
				target_view.status.poison = int(event.get("remaining", 0))
			var display_status: Dictionary = target_view.get("status", {}).duplicate(true)
			display_status["shield_pct"] = display_status.get("shield", display_status.get("shield_pct", 0))
			display_status["vuln_pct"] = display_status.get("vuln", display_status.get("vuln_pct", 0))
			display_status["reflect_pct"] = display_status.get("reflect", display_status.get("reflect_pct", 0))
			(player_indicators if target == "player" else enemy_indicators).set_fighter(0, {"status": display_status})
		_dungeon_event_effects(view, event, target)
		await get_tree().create_timer(1.35 if category == "combo" else 1.25 if category == "debuff" else 0.8 if category == "system" else LOG_STEP_SECONDS).timeout

func _dungeon_event_effects(view: Dictionary, event: Dictionary, target: String) -> void:
	var kind := str(event.get("kind", ""))
	if kind == "physical_anomaly_cast" and event.get("anomaly") is Dictionary:
		view["physical_anomaly"] = event.anomaly.duplicate(true)
	elif kind == "delayed_damage_queued" and target in ["player", "npc"]:
		var delayed: Array = view.get("strategic_delayed", [])
		delayed = delayed.filter(func(entry): return not (str(entry.get("target", "")) == target and str(entry.get("actor", "")) == str(event.get("actor", ""))))
		delayed.append({"actor": event.get("actor", ""), "target": target, "amount": event.get("amount", 0), "due_turn": event.get("due_turn", 0)})
		view["strategic_delayed"] = delayed
	elif kind == "delayed_damage" and target in ["player", "npc"]:
		var delayed: Array = view.get("strategic_delayed", [])
		view["strategic_delayed"] = delayed.filter(func(entry): return not (str(entry.get("target", "")) == target and str(entry.get("actor", "")) == str(event.get("actor", ""))))
	elif target in ["player", "npc"] and view.get(target) is Dictionary:
		if kind == "counter_trap_armed": view[target]["strategic_trap"] = {"value": event.get("value", 0), "expires_turn": event.get("expires_turn", 0)}
		elif kind == "heal_suppression_applied": view[target]["strategic_heal_suppression"] = {"expires_turn": event.get("expires_turn", 0)}
		elif kind == "counter_trap_expired": view[target].erase("strategic_trap")
		elif kind == "heal_suppression_expired": view[target].erase("strategic_heal_suppression")
	if kind == "counter_trap_triggered" and str(event.get("actor", "")) in ["player", "npc"]:
		view[str(event.actor)].erase("strategic_trap")
	for pair in [[player_indicators, "player"], [enemy_indicators, "npc"]]:
		var fighter: Dictionary = view.get(pair[1], {})
		var effects: Array = []
		for entry in view.get("strategic_delayed", []):
			if str(entry.get("target", "")) == pair[1]: effects.append({"icon": "hourglass", "label": str(entry.get("amount", 0)), "tooltip": "Delayed damage: %d at exchange %d." % [int(entry.get("amount", 0)), int(entry.get("due_turn", 0))]})
		if fighter.has("strategic_trap"):
			var trap: Dictionary = fighter.strategic_trap
			var remaining := maxi(0, int(trap.get("expires_turn", 0)) - maxi(int(view.get("turn", 0)), _dungeon_presentation_turn))
			effects.append({"icon": "trap", "label": "%dT" % remaining, "tooltip": "Counter trap: %d%% of direct damage; %d exchanges remaining." % [roundi(float(trap.get("value", 0)) * 100), remaining]})
		if fighter.has("strategic_heal_suppression"):
			var remaining := maxi(0, int(fighter.strategic_heal_suppression.get("expires_turn", 0)) - maxi(int(view.get("turn", 0)), _dungeon_presentation_turn))
			effects.append({"icon": "heal_block", "label": "%dT" % remaining, "tooltip": "Healing reduced by 50%%; %d exchanges remaining." % remaining})
		var anomaly: Variant = view.get("physical_anomaly")
		if anomaly is Dictionary and not anomaly.is_empty():
			var affinity := str(fighter.get("type", ""))
			var modifier := 15 if affinity == str(anomaly.get("favored_type", "")) else -15 if affinity == str(anomaly.get("weakened_type", "")) else 0
			if modifier != 0: effects.append({"icon": "type", "label": ("+" if modifier > 0 else "") + str(modifier) + "%", "tooltip": tr("ANOMALY_TOOLTIP") % [GameLocalization.catalog("type", str(anomaly.get("favored_type", "")), "name", str(anomaly.get("favored_type", "")).capitalize()), GameLocalization.catalog("type", str(anomaly.get("weakened_type", "")), "name", str(anomaly.get("weakened_type", "")).capitalize()), int(anomaly.get("remaining_exchanges", 0))]})
		pair[0].set_boss_effects(true, effects)

func _dungeon_strategic_event(event: Dictionary) -> String:
	var kind := str(event.get("kind", ""))
	match kind:
		"combo_trigger":
			var spell: Dictionary = _reg.get_spell_by_id(str(event.get("source_spell_id", "")))
			return "ALCHEMICAL COMBO | %s + %s | +%d damage" % [str(event.get("prerequisite", "")).capitalize(), str(spell.get("name", event.get("source_spell_id", ""))), int(event.get("actual_bonus_damage", 0))]
		"ward_convert": return "ALCHEMICAL COMBO | Shield Conversion | +%d damage" % int(event.get("amount", 0)) if int(event.get("amount", 0)) > 0 else ""
		"counter_trap_triggered": return "ALCHEMICAL COMBO | Counter Trap | %d damage returned" % int(event.get("amount", 0)) if int(event.get("amount", 0)) > 0 else ""
		"cooldown_jam": return "ALCHEMICAL COMBO | Cooldown Jam | +%d turn" % (int(event.get("value", 0)) - int(event.get("previous", 0)))
	return ""

func _setup_physical_anomaly_ui() -> void:
	_physical_anomaly_label = Label.new()
	_physical_anomaly_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_physical_anomaly_label.position = Vector2(-400, 195)
	_physical_anomaly_label.size = Vector2(800, 36)
	_physical_anomaly_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_physical_anomaly_label.add_theme_font_size_override("font_size", 17)
	_physical_anomaly_label.add_theme_constant_override("outline_size", 5)
	_physical_anomaly_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_physical_anomaly_label.hide()
	add_child(_physical_anomaly_label)

func _show_physical_anomaly(value: Variant) -> void:
	var active: Dictionary = value if value is Dictionary else {}
	var next_id := str(active.get("id", ""))
	if not _physical_anomaly_display_id.is_empty() and _physical_anomaly_display_id != next_id:
		_log_immediate(tr("ANOMALY_EXPIRED") if next_id.is_empty() else tr("ANOMALY_REPLACED"))
	_physical_anomaly_display_id = next_id
	if active.is_empty():
		if _physical_anomaly_label.has_meta("active_anomaly"):
			_physical_anomaly_label.remove_meta("active_anomaly")
		_physical_anomaly_label.hide()
		return
	_physical_anomaly_label.set_meta("active_anomaly", active.duplicate(true))
	_render_physical_anomaly(active)
	_physical_anomaly_label.show()

func _render_physical_anomaly(active: Dictionary) -> void:
	var spell: Dictionary = _reg.get_spell_by_id(str(active.get("id", ""))) if _reg != null else {}
	_physical_anomaly_label.text = tr("ANOMALY_DISPLAY") % [GameLocalization.catalog("spell", str(active.get("id", "")), "name", str(spell.get("name", active.get("id", "")))), int(active.get("remaining_exchanges", 0)), GameLocalization.catalog("type", str(active.get("favored_type", "")), "name", str(active.get("favored_type", "")).capitalize()), GameLocalization.catalog("type", str(active.get("weakened_type", "")), "name", str(active.get("weakened_type", "")).capitalize())]
	_physical_anomaly_label.tooltip_text = _spell_description(spell)

func _dungeon_render() -> void:
	var state: Dictionary = _dungeon_session.get("combat_state", {})
	_show_physical_anomaly(state.get("physical_anomaly"))
	if not state.get("player") is Dictionary or not state.get("npc") is Dictionary:
		_dungeon_show_retry("Invalid Dungeon state.")
		return
	var p: Dictionary = state.player
	var n: Dictionary = state.npc
	for pair in [[player_hp, p, "player"], [enemy_hp, n, "npc"]]:
		var details: Array[String] = []
		for entry in state.get("strategic_delayed", []):
			if str(entry.get("target", "")) == str(pair[2]):
				details.append("Delayed damage: %d at end of exchange %d" % [int(entry.get("amount", 0)), int(entry.get("due_turn", 0))])
		for field in ["strategic_trap", "strategic_heal_suppression"]:
			if pair[1].has(field):
				details.append("%s: %d exchanges remaining" % ["Counter trap" if field == "strategic_trap" else "Healing suppression", maxi(0, int(pair[1][field].get("expires_turn", 0)) - int(state.get("turn", 0)))])
		pair[0].tooltip_text = "\n".join(details)
	if int(p.get("max_hp", 0)) <= 0 or int(n.get("max_hp", 0)) <= 0 or not p.get("spell_ids") is Array or p.spell_ids.size() != 4:
		_dungeon_show_retry("Invalid Dungeon fighters.")
		return
	get_node("PlayerPanel").show()
	get_node("EnemyPanel").show()
	spell_panel.show()
	for pair in [[player_hp, p], [enemy_hp, n]]:
		var icon: Node = pair[0].get_node_or_null("CombatTypeIcon")
		if icon == null:
			icon = CombatTypeIcon.new()
			icon.name = "CombatTypeIcon"
			icon.position = Vector2(-30, -3)
			pair[0].add_child(icon)
		icon.call("configure", str(pair[1].get("type", "")))
	var pe := _find_by_id(_entities, str(p.get("id", "")))
	var ne := _find_by_id(_entities, str(n.get("id", "")))
	var ph := _online_homunculus(str(p.get("hom_id", "")))
	var nh := _online_homunculus(str(n.get("hom_id", "")))
	player_entity_name.text = str(pe.get("name", p.get("id", "")))
	enemy_entity_name.text = str(ne.get("name", n.get("id", "")))
	player_entity.texture = _load_preview_tex(str(p.id), "entity", str(p.get("type", "")))
	enemy_entity.texture = _load_preview_tex(str(n.id), "entity", str(n.get("type", "")))
	enemy_entity.flip_h = true
	enemy_hom.flip_h = true
	player_entity.flip_h = false
	player_hom.flip_h = false
	player_hom.visible = not ph.is_empty()
	enemy_hom.visible = not nh.is_empty()
	if not ph.is_empty(): player_hom.texture = _load_preview_tex(str(p.hom_id), "homunculus", str(ph.get("name", "")))
	if not nh.is_empty(): enemy_hom.texture = _load_preview_tex(str(n.hom_id), "homunculus", str(nh.get("name", "")))
	for pair in [[player_hp, p], [enemy_hp, n]]:
		pair[0].max_value = float(pair[1].max_hp)
		pair[0].value = float(pair[1].hp)
		_apply_hp_color(pair[0], pair[1])
		pair[0].get_node("HealthValue").text = "%d / %d" % [int(pair[1].hp), int(pair[1].max_hp)]
	for pair in [[player_indicators, p, "player"], [enemy_indicators, n, "npc"]]:
		var status: Dictionary = pair[1].get("status", {}).duplicate(true)
		status["shield_pct"] = status.get("shield", status.get("shield_pct", 0))
		status["vuln_pct"] = status.get("vuln", status.get("vuln_pct", 0))
		status["reflect_pct"] = status.get("reflect", status.get("reflect_pct", 0))
		var effects: Array = []
		for delayed in state.get("strategic_delayed", []):
			if str(delayed.get("target", "")) == str(pair[2]):
				effects.append({"icon": "hourglass", "label": str(delayed.get("amount", 0)), "tooltip": tr("STATUS_DELAYED_DETAIL") % [int(delayed.get("amount", 0)), int(delayed.get("due_turn", 0))]})
		if pair[1].has("strategic_trap"):
			var trap: Dictionary = pair[1].strategic_trap
			var remaining := maxi(0, int(trap.get("expires_turn", 0)) - int(state.get("turn", 0)))
			effects.append({"icon": "trap", "label": "%dT" % remaining, "tooltip": tr("STATUS_TRAP_DETAIL") % [roundi(float(trap.get("value", 0)) * 100), remaining]})
		if pair[1].has("strategic_heal_suppression"):
			var remaining := maxi(0, int(pair[1].strategic_heal_suppression.get("expires_turn", 0)) - int(state.get("turn", 0)))
			effects.append({"icon": "heal_block", "label": "%dT" % remaining, "tooltip": tr("STATUS_HEAL_SUPPRESSION_DETAIL") % remaining})
		var anomaly: Variant = state.get("physical_anomaly")
		if anomaly is Dictionary and not anomaly.is_empty():
			var affinity := str(pair[1].get("type", ""))
			var modifier := 15 if affinity == str(anomaly.get("favored_type", "")) else -15 if affinity == str(anomaly.get("weakened_type", "")) else 0
			if modifier != 0:
				effects.append({"icon": "type", "label": ("+" if modifier > 0 else "") + str(modifier) + "%", "tooltip": tr("ANOMALY_TOOLTIP_GAIN") % [GameLocalization.catalog("type", str(anomaly.get("favored_type", "")), "name", str(anomaly.get("favored_type", "")).capitalize()), GameLocalization.catalog("type", str(anomaly.get("weakened_type", "")), "name", str(anomaly.get("weakened_type", "")).capitalize()), int(anomaly.get("remaining_exchanges", 0))]})
		pair[0].set_boss_effects(true, effects)
		if not pair[0].effect_clicked.is_connected(_show_dungeon_status):
			pair[0].effect_clicked.connect(_show_dungeon_status)
		var status_fighter: Dictionary = pair[1].duplicate(true)
		status_fighter.status = status
		pair[0].set_fighter(0, status_fighter)
	_player_hom_status.visible = not ph.is_empty()
	_enemy_hom_status.visible = not nh.is_empty()
	_player_hom_status.call("set_fighter", {"hom_name": str(ph.get("name", "")), "hom_data": ph, "hom_energy": int(p.get("hom_energy", 0)), "hom_spent": false})
	_enemy_hom_status.call("set_fighter", {"hom_name": str(nh.get("name", "")), "hom_data": nh, "hom_energy": int(n.get("hom_energy", 0)), "hom_spent": false})
	_player_inspiration.show()
	_enemy_inspiration.show()
	_player_inspiration.call("set_fighter", {"inspiration": int(p.get("inspiration", 0)), "inspiration_used_this_battle": bool(p.get("inspiration_used", false))})
	_enemy_inspiration.call("set_fighter", {"inspiration": int(n.get("inspiration", 0)), "inspiration_used_this_battle": bool(n.get("inspiration_used", false))})
	for i in 4:
		var id := str(p.spell_ids[i])
		var spell: Dictionary = _reg.get_spell_by_id(id)
		var cd := int(p.get("cooldowns", {}).get(id, 0))
		_set_localized_spell_button(spell_buttons[i], spell, str(spell.get("name", id)), float(spell.get("power_mult", 0)), float(spell.get("accuracy", 0)), cd)
		var types: Array = [str(spell.get("primary_type", "")), str(spell.get("secondary_type", ""))] if spell.get("type") == "hybrid" else [str(spell.get("type", "universal"))]
		for icon_index in 2:
			var icon_name := "DungeonSpellType%d" % icon_index
			var icon: Control = spell_buttons[i].get_node_or_null(icon_name)
			if icon == null:
				icon = CombatTypeIcon.new()
				icon.name = icon_name
				icon.position = Vector2(5 + icon_index * 25, 5)
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				spell_buttons[i].add_child(icon)
			icon.visible = icon_index < types.size()
			if icon.visible:
				icon.call("configure", types[icon_index])
	var floor_id := int(state.get("floor", 1))
	if _dungeon_floor_label == null:
		_dungeon_floor_label = Label.new()
		_dungeon_floor_label.name = "DungeonFloorHeader"
		_dungeon_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dungeon_floor_label.add_theme_font_size_override("font_size", 20)
		_dungeon_floor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spell_panel.get_parent().add_child(_dungeon_floor_label)
		spell_panel.resized.connect(_layout_dungeon_floor_header)
		spell_panel.item_rect_changed.connect(_layout_dungeon_floor_header)
	_dungeon_floor_label.text = tr("DUNGEON_FLOOR_TITLE") % floor_id
	_dungeon_floor_label.set_meta("localized_floor", floor_id)
	_dungeon_floor_label.set_meta("localized_prefix", _dungeon_floor_label.text)
	var elite: Variant = state.get("elite")
	var is_elite := elite is Dictionary and not str(elite.get("label", "")).is_empty()
	if is_elite:
		_dungeon_floor_label.text += " | ELITE: %s" % str(elite.get("label", ""))
		_dungeon_floor_label.add_theme_color_override("font_color", Color("e6c878"))
		enemy_entity_name.add_theme_color_override("font_color", Color("e6c878"))
	else:
		_dungeon_floor_label.remove_theme_color_override("font_color")
		enemy_entity_name.remove_theme_color_override("font_color")
	var encounter: Variant = state.get("special_encounter")
	if not is_elite and encounter is Dictionary and not str(encounter.get("label", "")).is_empty():
		var effects := {"corrupted_fog": "VULN +10%", "crystal_bastion": "SHIELD 15%", "arcane_instability": "ATK +10%"}
		_dungeon_floor_label.text += " | %s" % str(encounter.label)
		if effects.has(str(encounter.get("kind", ""))): _dungeon_floor_label.text += " · %s" % effects[str(encounter.kind)]
		var encounter_key := "%s:%d" % [str(_dungeon_session.get("run_id", "")), floor_id]
		if _dungeon_encounter_log_key != encounter_key:
			_dungeon_encounter_log_key = encounter_key
			_dungeon_encounter_details["dungeon_encounter:" + str(encounter.get("kind", ""))] = encounter.duplicate(true)
			_append_combat_log("ENCOUNTER: %s" % str(encounter.label), {"category": "advantage", "ability_id": "dungeon_encounter:" + str(encounter.get("kind", ""))})
	var blessing: Variant = state.get("blessing")
	if blessing is Dictionary and blessing.get("selected") is Dictionary:
		var selected: Dictionary = blessing.selected
		_dungeon_floor_label.text += " | " + str(selected.get("name", "Blessing"))
		var blessing_key := "%s:%d:%s" % [str(_dungeon_session.get("run_id", "")), floor_id, str(selected.get("id", ""))]
		if _dungeon_blessing_log_key != blessing_key:
			_dungeon_blessing_log_key = blessing_key
			var detail_key := "dungeon_encounter:blessing:" + blessing_key
			_dungeon_encounter_details[detail_key] = {"label": str(selected.get("name", "Blessing")), "hint": str(selected.get("description", ""))}
			_append_combat_log("BLESSING: " + str(selected.get("name", "")), {"category": "advantage", "ability_id": detail_key})
	_dungeon_floor_label.show()
	_layout_dungeon_floor_header()
	turn_label.text = tr("DUNGEON_CLEARED_COUNT") % int(_dungeon_session.get("cleared_floor", 0))
	turn_label.set_meta("localized_cleared", int(_dungeon_session.get("cleared_floor", 0)))
	turn_label.set_meta("localized_cleared_text", turn_label.text)
	var weapons: Array = state.get("weapons", [])
	var active_slot := int(state.get("active_weapon_slot", 0))
	for i in 2:
		var weapon_id := str(weapons[i].get("id", "")) if i < weapons.size() and weapons[i] is Dictionary and weapons[i].get("id") != null else ""
		var slot_icon: TextureRect = [player_item1, player_item2][i]
		_set_item_icon(slot_icon, _find_by_id(_items, weapon_id))
		slot_icon.modulate.a = 1.0 if i + 1 == active_slot else 0.5
	if _spectator_readonly:
		for button in spell_buttons: button.disabled = true
		switch_weapon_btn.disabled = true
		ultra_button.disabled = true
		next_turn_btn.hide()
		return
	var phase := str(_dungeon_session.get("phase", "COMBAT"))
	if phase == "FLOOR_CLEARED":
		_log_immediate(tr("DUNGEON_FLOOR_CLEARED") % [floor_id, int(p.hp), int(p.max_hp)])
		if int(p.hp) * 10 <= int(p.max_hp): _log_immediate(tr("DUNGEON_CLOSE_CALL"))
		if int(state.get("turn", 0)) <= 5: _log_immediate(tr("DUNGEON_SWIFT_CLEAR"))
		_set_next_turn_action("next_floor")
		next_turn_btn.disabled = floor_id >= 1000
		next_turn_btn.show()
	elif str(_dungeon_session.get("status", "")) == "LOSS":
		_log_immediate(tr("DUNGEON_RUN_OVER") % int(_dungeon_session.get("cleared_floor", 0)))
		_set_next_turn_action("return")
		next_turn_btn.show()
	else:
		next_turn_btn.hide()
		var brief_key := "%s:%d" % [str(_dungeon_session.get("run_id", "")), floor_id]
		if floor_id != _dungeon_brief_floor and int(state.get("turn", 0)) == 0 and (str(_dungeon_session.get("run_id", "")).is_empty() or brief_key != _dungeon_last_brief_key):
			_dungeon_brief_floor = floor_id
			_dungeon_brief.dialog_text = "Floor %d\n%s (%s)\nHomunculus: %s\nCleared: %d" % [floor_id, str(ne.get("name", n.id)), str(n.get("type", "")).capitalize(), str(nh.get("name", "None")), int(_dungeon_session.get("cleared_floor", 0))]
			if not is_elite and encounter is Dictionary and not str(encounter.get("label", "")).is_empty():
				_dungeon_brief.dialog_text += "\n%s: %s" % [str(encounter.label), str(encounter.get("hint", ""))]
			if is_elite:
				var bonuses: Array[String] = []
				var modifiers: Variant = elite.get("modifiers", {})
				if modifiers is Dictionary:
					for pair in [["hp", "HP"], ["attack", "ATK"], ["defense", "DEF"]]:
						var value: Variant = modifiers.get(pair[0])
						if (value is float or value is int) and float(value) > 1.0:
							bonuses.append("%s +%d%%" % [pair[1], roundi((float(value) - 1.0) * 100.0)])
				_dungeon_brief.dialog_text += "\nELITE: %s" % str(elite.label)
				if not bonuses.is_empty(): _dungeon_brief.dialog_text += " (%s)" % ", ".join(bonuses)
				var ability: Variant = state.get("elite_trait")
				if ability is Dictionary and not str(ability.get("label", "")).is_empty():
					_dungeon_brief.dialog_text += "\n%s: %s" % [str(ability.label), str(ability.get("hint", ""))]
			var personality := str(state.get("npc_personality", ""))
			var hints := {"AGGRESSIVE": "favors attacks and finishers", "DEFENSIVE": "favors protection and healing", "OPPORTUNIST": "exploits existing weaknesses", "ALCHEMIST": "seeks combos and anomalies"}
			if hints.has(personality): _dungeon_brief.dialog_text += "\n%s: %s." % [personality, hints[personality]]
			_dungeon_brief.popup_centered()
	_dungeon_refresh_controls()
	_refresh_dungeon_inspiration()
	_refresh_dungeon_blessing()
	if _dungeon_request.is_empty() and _dungeon_pending.is_empty() and (not _dungeon_rank_loaded or ((phase == "FLOOR_CLEARED" or str(_dungeon_session.get("status", "")) == "LOSS") and _dungeon_rank_floor != floor_id)):
		_dungeon_rank_floor = floor_id
		_dungeon_kind = "ranking"
		_dungeon_request = _combat_backend.request_api("GET", "/dungeon/leaderboard?month=" + str(_dungeon_session.get("season", "")).uri_encode(), null)
		_dungeon_refresh_controls()

func _dungeon_refresh_controls() -> void:
	var state: Dictionary = _dungeon_session.get("combat_state", {})
	var p: Dictionary = state.get("player", {})
	var ids: Array = p.get("spell_ids", [])
	var blocked := _dungeon_playing_events or (state.get("blessing") is Dictionary and bool(state.blessing.get("pending", false))) or bool(p.get("inspiration_pending", false)) or not _dungeon_synchronized or _dungeon_session.is_empty() or str(_dungeon_session.get("status", "")) != "ACTIVE" or str(_dungeon_session.get("phase", "")) != "COMBAT" or not _dungeon_request.is_empty() or not _dungeon_pending.is_empty() or not _dungeon_hom_choice.is_empty() or (_dungeon_brief != null and _dungeon_brief.visible) or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity
	for i in spell_buttons.size():
		spell_buttons[i].disabled = blocked or i >= ids.size() or int(p.get("cooldowns", {}).get(str(ids[i]), 0)) > 0
	var weapons: Array = state.get("weapons", [])
	var active_slot := int(state.get("active_weapon_slot", 0))
	var other := 2 if active_slot == 1 else 1
	var available := active_slot in [1, 2] and weapons.size() == 2 and weapons[other - 1] is Dictionary and not str(weapons[other - 1].get("id", "")).is_empty() and weapons[other - 1].get("id") != null
	switch_weapon_btn.visible = available
	switch_weapon_btn.disabled = blocked or not available
	if available:
		var item_id := str(weapons[other - 1].id)
		var item := _find_by_id(_items, item_id)
		switch_weapon_btn.text = ("Switch to:\n" if OS.has_feature("android") else "Switch to: ") + str(item.get("name", item_id))
	ultra_button.disabled = true

func _show_dungeon_status(description: String) -> void:
	_spell_detail.title = "Combat Status"
	_spell_detail.dialog_text = description
	_spell_detail.popup_centered(Vector2i(440, 260))

func _setup_dungeon_blessing_ui() -> void:
	_blessing_panel = PanelContainer.new()
	_blessing_panel.name = "DungeonBlessingSelection"
	_blessing_panel.set_anchors_preset(Control.PRESET_CENTER)
	_blessing_panel.position = Vector2(-455, -200)
	_blessing_panel.custom_minimum_size = Vector2(910, 400)
	_blessing_panel.z_index = 150
	_blessing_panel.add_theme_stylebox_override("panel", _inspiration_panel.get_theme_stylebox("panel"))
	add_child(_blessing_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_blessing_panel.add_child(column)
	var title := Label.new()
	title.text = "DUNGEON_BLESSING_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("d4af37"))
	column.add_child(title)
	var info := Label.new()
	info.text = "DUNGEON_BLESSING_INFO"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		button.pressed.connect(_choose_dungeon_blessing.bind(i))
		cards.add_child(button)
		_blessing_cards.append(button)
	_blessing_panel.hide()

func _refresh_dungeon_blessing() -> void:
	if not _dungeon_guard or _blessing_panel == null:
		return
	var blessing: Variant = _dungeon_session.get("combat_state", {}).get("blessing")
	if not blessing is Dictionary or not bool(blessing.get("pending", false)) or str(_dungeon_session.get("status", "")) != "ACTIVE" or not blessing.get("offers") is Array or blessing.offers.size() != 3 or (_dungeon_brief != null and _dungeon_brief.visible):
		_blessing_panel.hide()
		return
	var locked := _dungeon_playing_events or not _dungeon_synchronized or not _dungeon_request.is_empty() or not _dungeon_pending.is_empty() or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity
	for i in 3:
		var offer: Dictionary = blessing.offers[i]
		_blessing_cards[i].text = str(offer.get("name", "")) + "\n\n" + str(offer.get("description", ""))
		_blessing_cards[i].tooltip_text = str(offer.get("description", ""))
		_blessing_cards[i].disabled = locked
	_blessing_panel.show()

func _choose_dungeon_blessing(index: int) -> void:
	if _spectator_readonly: return
	var blessing: Variant = _dungeon_session.get("combat_state", {}).get("blessing")
	if not blessing is Dictionary or not bool(blessing.get("pending", false)) or index < 0 or index >= blessing.get("offers", []).size() or not _dungeon_synchronized or not _dungeon_request.is_empty() or not _dungeon_pending.is_empty() or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity:
		return
	_dungeon_pending = {"kind": "blessing", "payload": {"run_id": str(SceneRouter._dungeon_context.get("run_id", "")), "client_action_id": _combat_backend._make_uuid(), "expected_revision": int(_dungeon_session.get("combat_revision", 0)), "decision": {"blessing_id": str(blessing.offers[index].id)}}}
	SceneRouter._dungeon_context["pending_action"] = _dungeon_pending.duplicate(true)
	_refresh_dungeon_blessing()
	_dungeon_send_pending()

func _refresh_dungeon_inspiration() -> void:
	if not _dungeon_guard or _inspiration_panel == null:
		return
	var p: Dictionary = _dungeon_session.get("combat_state", {}).get("player", {})
	var offers: Variant = p.get("inspiration_offers", [])
	if (_dungeon_session.get("combat_state", {}).get("blessing") is Dictionary and bool(_dungeon_session.combat_state.blessing.get("pending", false))) or not bool(p.get("inspiration_pending", false)) or str(_dungeon_session.get("status", "")) != "ACTIVE" or not offers is Array or offers.size() != 3:
		_inspiration_panel.hide()
		_inspiration_options.clear()
		return
	var options: Array = []
	var seen := {}
	for id in offers:
		var spell: Dictionary = _reg.get_spell_by_id(str(id))
		if spell.is_empty() or seen.has(str(id)):
			_inspiration_panel.hide()
			return
		seen[str(id)] = true
		options.append(spell)
	_inspiration_options = options
	var locked := _dungeon_playing_events or not _dungeon_synchronized or not _dungeon_request.is_empty() or not _dungeon_pending.is_empty() or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity
	for i in 3:
		var spell: Dictionary = options[i]
		_inspiration_cards[i].text = _spell_description(spell)
		_inspiration_cards[i].tooltip_text = _spell_description(spell)
		_inspiration_cards[i].disabled = locked
		_inspiration_cards[i].get_node("TypeIcon").call("configure", str(spell.get("primary_type", spell.get("type", ""))))
		var secondary: Control = _inspiration_cards[i].get_node_or_null("DungeonSecondaryType")
		if secondary == null:
			secondary = CombatTypeIcon.new()
			secondary.name = "DungeonSecondaryType"
			secondary.position = Vector2(35, 4)
			secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_inspiration_cards[i].add_child(secondary)
		secondary.visible = spell.get("type") == "hybrid"
		if secondary.visible: secondary.call("configure", str(spell.get("secondary_type", "")))
	(_inspiration_panel.get_node("Content/Cancel") as Button).disabled = locked
	_inspiration_panel.show()

func _send_dungeon_inspiration(decision: Dictionary) -> void:
	if _spectator_readonly: return
	var p: Dictionary = _dungeon_session.get("combat_state", {}).get("player", {})
	if not _dungeon_synchronized or _dungeon_playing_events or not _dungeon_pending.is_empty() or not _dungeon_request.is_empty() or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity or not bool(p.get("inspiration_pending", false)):
		return
	if decision.get("kind") == "choose" and str(decision.get("spell_id", "")) not in p.get("inspiration_offers", []):
		return
	_dungeon_pending = {"kind": "inspiration", "payload": {"run_id": str(SceneRouter._dungeon_context.get("run_id", "")), "client_action_id": _combat_backend._make_uuid(), "expected_revision": int(_dungeon_session.get("combat_revision", 0)), "decision": decision.duplicate(true)}}
	SceneRouter._dungeon_context["pending_action"] = _dungeon_pending.duplicate(true)
	_refresh_dungeon_inspiration()
	_dungeon_send_pending()

func _layout_dungeon_floor_header() -> void:
	if not is_instance_valid(_dungeon_floor_label) or not is_instance_valid(spell_panel):
		return
	_dungeon_floor_label.position = spell_panel.position + Vector2(0, -28)
	_dungeon_floor_label.size = Vector2(spell_panel.size.x, 26)

func _begin_combat_initialization() -> void:
	if _spectator_readonly:
		var mode := str(SceneRouter._spectator_context.get("mode", ""))
		if mode in ["ranked", "friendly", "practice"]:
			_ranked_controller = preload("res://scripts/ui/ranked_combat.gd").new()
			add_child(_ranked_controller)
		else:
			_spectator_controller = preload("res://scripts/ui/spectator_combat.gd").new()
			add_child(_spectator_controller)
		return
	if bool(SceneRouter._ranked_context.get("debug_visual", false)) and ConnectionGate.debug_lab_navigation_allowed():
		_combat_debug = true
		var debug := DebugFlags.new()
		_combat_spell_state = debug.load_lab_state()
		debug.free()
		_start_combat()
		_ranked_controller = preload("res://scripts/ui/ranked_combat.gd").new()
		add_child(_ranked_controller)
		return
	if not str(SceneRouter._ranked_context.get("match_id", "")).is_empty():
		_ranked_controller = preload("res://scripts/ui/ranked_combat.gd").new()
		add_child(_ranked_controller)
		return
	if not str(SceneRouter._dungeon_context.get("run_id", "")).is_empty():
		_dungeon_guard = true
		_apply_dungeon_combat_visuals()
		_combat_session_invalid = true
		spell_panel.hide()
		switch_weapon_btn.disabled = true
		ultra_button.disabled = true
		for path in ["PlayerPanel", "EnemyPanel", "HomDecision"]:
			var dungeon_panel := get_node_or_null(path) as CanvasItem
			if dungeon_panel:
				dungeon_panel.hide()
		next_turn_btn.hide()
		_dungeon_identity = str(SceneRouter._dungeon_context.get("player_id", ""))
		_dungeon_pending = SceneRouter._dungeon_context.get("pending_action", {}).duplicate(true)
		_dungeon_brief = ConfirmationDialog.new()
		_dungeon_brief.title = "DUNGEONS"
		_dungeon_brief.get_ok_button().text = "Fight"
		_dungeon_brief.get_cancel_button().hide()
		_dungeon_brief.confirmed.connect(func():
			_dungeon_last_brief_key = "%s:%d" % [str(_dungeon_session.get("run_id", "")), _dungeon_brief_floor]
			call_deferred("_refresh_dungeon_blessing")
			call_deferred("_dungeon_refresh_controls")
		)
		_dungeon_brief.canceled.connect(func(): _dungeon_brief.call_deferred("popup_centered"); call_deferred("_dungeon_refresh_controls"))
		add_child(_dungeon_brief)
		_setup_dungeon_blessing_ui()
		_combat_backend = BackendClient.new()
		_combat_backend.base_url = backend_url
		_combat_backend.auto_dev_login = false
		_combat_backend.state_updated.connect(_dungeon_on_identity)
		_combat_backend.api_completed.connect(_dungeon_on_response)
		_combat_backend.auth_changed.connect(_dungeon_on_auth_changed)
		add_child(_combat_backend)
		_combat_backend._ensure_api_http()
		_combat_backend._api_http.timeout = 10.0
		if _combat_backend.token.is_empty():
			_connection_gate().require_authentication()
		else:
			_connection_gate().register_identity(_combat_backend, _dungeon_identity)
		_log_immediate("Starting Dungeon...")
		return
	if not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty():
		_online_hunt_guard = true
		_solo_context = SceneRouter.consume_solo_hunt_context()
		var recovered_pending: Dictionary = _solo_context.get("pending_action", {})
		if recovered_pending.get("kind") == "forfeit":
			_solo_forfeit_action = str(recovered_pending.get("payload", {}).get("client_action_id", ""))
		elif recovered_pending.get("kind") in ["turn", "inspiration"]:
			_online_turn_payload = recovered_pending.get("payload", {}).duplicate(true)
		_combat_identity = str(_solo_context.get("loadout_identity", ""))
		_combat_session_invalid = true
		spell_panel.hide()
		switch_weapon_btn.disabled = true
		ultra_button.disabled = true
		for path in ["PlayerPanel", "EnemyPanel", "HomDecision"]:
			var panel := get_node_or_null(path) as CanvasItem
			if panel:
				panel.hide()
		next_turn_btn.hide()
		_combat_backend = BackendClient.new()
		_combat_backend.base_url = backend_url
		_combat_backend.auto_dev_login = false
		_combat_backend.state_updated.connect(_on_online_hunt_identity)
		_combat_backend.api_completed.connect(_on_online_hunt_response)
		_combat_backend.auth_changed.connect(_on_online_hunt_auth_changed)
		add_child(_combat_backend)
		if _combat_backend.token.is_empty():
			_connection_gate().require_authentication()
		else:
			_connection_gate().register_identity(_combat_backend, _combat_identity)
		_log_immediate("Recovering server combat...")
		_wait_for_combat_state()
		return
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

func _on_online_hunt_auth_changed(_token: String) -> void:
	_online_presenting_events = false
	_online_event_turn = -1
	_online_identity_invalid = true
	_online_hom_payload.clear()
	hom_decision.hide()
	_online_hunt_session.clear()
	_online_hunt_request = ""
	_online_turn_request = ""
	_hide_online_hunt_view()
	_set_next_turn_action("return")
	next_turn_btn.show()
	_log_immediate("Account changed. Return to World Zone; the session remains active.")

func _hide_online_hunt_view() -> void:
	get_node("PlayerPanel").hide()
	get_node("EnemyPanel").hide()
	switch_weapon_btn.disabled = true
	switch_weapon_btn.hide()
	var world_sprites := get_node_or_null("WorldCombatSprites") as CanvasItem
	if world_sprites:
		world_sprites.hide()
	if _player_hom_status:
		_player_hom_status.hide()
	spell_panel.hide()
	if _inspiration_panel:
		_inspiration_panel.hide()
	if _online_hunt_info:
		_online_hunt_info.hide()
	if is_instance_valid(_solo_panel):
		(_solo_panel.get_parent().get_parent() if OS.has_feature("android") else _solo_panel.get_parent()).hide()

func _on_online_hunt_identity(state: Dictionary) -> void:
	if _online_identity_invalid:
		return
	if state.is_empty() or _combat_backend._verified_player_id.is_empty():
		return
	if _combat_identity.is_empty() or str(state.get("player_id", "")) != _combat_identity or _combat_backend._verified_player_id != _combat_identity:
		_on_online_hunt_auth_changed("")
		return
	if not _online_presenting_events and _online_hunt_request.is_empty() and _online_turn_request.is_empty():
		_online_hunt_request = _combat_backend.request_api("GET", "/world/boss-hunts/session?session_id=" + str(_solo_context.get("session_id", "")).uri_encode(), null, false, _connection_gate().blocked())
		if _online_hunt_request.is_empty():
			_on_combat_state_timeout()
		elif _combat_wait_timer:
			_combat_wait_timer.start(10.0)

func _on_online_hunt_response(request_id: String, ok: bool, data: Dictionary) -> void:
	if ok and not _spectator_readonly and not request_id.is_empty() and request_id in [_online_hunt_request, _online_turn_request, _solo_forfeit_request] and _combat_backend != null and _combat_backend._verified_player_id == _combat_identity and _combat_identity == str(ConnectionGate.player_id): GlobalChatClient.apply_combat_spectators(data)
	if not request_id.is_empty() and request_id == _solo_forfeit_request:
		_solo_forfeit_request = ""
		if _connection_gate().blocked() and not _gate_session_verified:
			return
		if _online_closed_recovery in ["EXPIRED", "VERIFIED_WIN", "VERIFIED_LOSS"] and not ok and int(data.get("http_status", 0)) == 409 and str(data.get("error", "")) == "Session is already closed." and _combat_backend != null and not _combat_identity.is_empty() and _combat_backend._verified_player_id == _combat_identity:
			if not _connection_gate().journal_confirm(_solo_forfeit_action): return
			if not _connection_gate().journal_close("hunt", str(_solo_context.get("session_id", ""))): return
			_solo_forfeit_action = ""
			var closed_status := _online_closed_recovery
			_online_closed_recovery = ""
			_online_exit_reconciled = true
			if closed_status == "EXPIRED":
				_show_closed_online_session(closed_status)
			else:
				_present_online_terminal()
			if _connection_gate().blocked(): _connection_gate().recovery_completed()
			if closed_status == "EXPIRED": _return_from_solo_hunt()
			return
		if ok and str(data.get("status", "")) == "FORFEIT" and str(data.get("session_id", "")) == str(_solo_context.get("session_id", "")) and _combat_backend != null and not _online_identity_invalid and not _combat_identity.is_empty() and _combat_backend._verified_player_id == _combat_identity:
			if not _connection_gate().journal_confirm(_solo_forfeit_action): return
			if not _connection_gate().journal_close("hunt", str(_solo_context.get("session_id", ""))): return
			_solo_forfeit_action = ""
			_show_closed_online_session("FORFEIT")
			_online_exit_reconciled = true
			if _connection_gate().blocked():
				_connection_gate().recovery_completed()
			_return_from_solo_hunt()
		else:
			_log_immediate("Forfeit not confirmed. Reconnect and retry; the session remains active.")
		return
	if not request_id.is_empty() and request_id == _online_turn_request:
		_online_turn_request = ""
		if _connection_gate().blocked() and (not _connection_gate()._player_verified or not _gate_session_verified):
			_online_turn_unresolved()
			return
		if _combat_wait_timer:
			_combat_wait_timer.stop()
		var inspiration_action := str(_online_turn_payload.get("decision", {}).get("kind", "")) in ["choose", "decline"]
		if not _online_closed_recovery.is_empty() and not _combat_identity.is_empty() and _combat_backend._verified_player_id == _combat_identity:
			var rejected := not ok and int(data.get("http_status", 0)) == 409 and str(data.get("error", "")) == ("Session unavailable for inspiration." if inspiration_action else "Session unavailable for turn.")
			var replayed := ok and str(data.get("session_id", "")) == str(_solo_context.get("session_id", "")) and int(data.get("combat_revision", 0)) == int(_online_turn_payload.get("expected_revision", -2)) + 1 and _valid_online_result(data)
			if rejected or replayed:
				if not _connection_gate().journal_confirm(str(_online_turn_payload.get("client_action_id", ""))): return
				if not _connection_gate().journal_close("hunt", str(_solo_context.get("session_id", ""))): return
				_online_turn_payload.clear()
				_online_exit_reconciled = true
				_show_closed_online_session(_online_closed_recovery)
				_online_closed_recovery = ""
				connection_gate_recover()
				return
		if not ok or _combat_backend._verified_player_id != _combat_identity or _combat_identity.is_empty() or str(data.get("session_id", "")) != str(_solo_context.get("session_id", "")) or not _valid_online_result(data) or int(data.get("combat_revision", 0)) != int(_online_turn_payload.get("expected_revision", -2)) + 1 or not data.get("combat_state") is Dictionary or not data.get("combat_loadout") is Dictionary or (not inspiration_action and not data.get("events") is Array):
			_online_turn_unresolved()
			return
		if int(data.combat_revision) >= _online_hunt_revision:
			var old_session := _online_hunt_session
			var old_revision := _online_hunt_revision
			_online_hunt_session = data.duplicate(true)
			_online_hunt_revision = int(data.combat_revision)
			if not _render_online_hunt(data, not _online_processed_turns.has(str(_online_turn_payload.get("client_action_id", ""))) and not data.get("events", []).is_empty()):
				_online_hunt_session = old_session
				_online_hunt_revision = old_revision
				_online_turn_unresolved()
				return
		var action_id := str(_online_turn_payload.get("client_action_id", ""))
		if not _online_processed_turns.has(action_id):
			_online_presenting_events = true
			_online_processed_turns[action_id] = true
			var generation := _combat_backend._session_generation
			var session_id := str(_solo_context.get("session_id", ""))
			var revision := int(data.combat_revision)
			var playback_epoch := _gate_epoch
			var decision: Dictionary = _online_turn_payload.get("decision", {})
			if not inspiration_action and decision.has("spell_id"):
				_log_online_spell(str(decision.spell_id), true)
				await get_tree().create_timer(LOG_STEP_SECONDS).timeout
			for event in data.get("events", []):
				if not _online_playback_valid(generation, session_id, action_id, revision, playback_epoch):
					if playback_epoch == _gate_epoch and str(_online_turn_payload.get("client_action_id", "")) == action_id:
						_online_presenting_events = false
						_online_event_turn = -1
					return
				if event is Dictionary:
					_online_event_turn = int(event.get("turn", -1))
					_log_online_hunt_event(event)
					var target := str(event.get("target", ""))
					var bar: ProgressBar = player_hp if target == "player" else enemy_hp if target == "boss" else null
					if bar != null and (event.has("hp") or int(event.get("actual_damage", event.get("damage", 0))) > 0):
						var before := int(bar.value)
						var after := int(event.hp) if event.has("hp") else maxi(0, before - int(event.get("actual_damage", event.get("damage", 0))))
						await get_tree().create_timer(0.26).timeout
						if not _online_playback_valid(generation, session_id, action_id, revision, playback_epoch):
							return
						_set_display_hp(bar, after)
					elif bar == null and event.has("hp"):
						await get_tree().create_timer(0.26).timeout
						if not _online_playback_valid(generation, session_id, action_id, revision, playback_epoch):
							return
						for minion in _solo_minions:
							if str(minion.get("id", "")) == target:
								minion.hp = int(event.hp)
								break
						_update_solo_minion_views()
					var delay := _online_hunt_event_delay(event)
					if delay > 0.0:
						await get_tree().create_timer(delay).timeout
			if not _online_playback_valid(generation, session_id, action_id, revision, playback_epoch):
				if playback_epoch == _gate_epoch and str(_online_turn_payload.get("client_action_id", "")) == action_id:
					_online_presenting_events = false
					_online_event_turn = -1
				return
			_online_event_turn = -1
			_online_presenting_events = false
			_set_display_hp(player_hp, int(data.combat_state.player.get("hp", 0)))
			_set_display_hp(enemy_hp, int(data.combat_state.boss.get("hp", 0)))
			_solo_minions = data.combat_state.minions.duplicate(true)
			_update_solo_minion_views()
		if not _connection_gate().journal_confirm(str(_online_turn_payload.get("client_action_id", ""))): return
		if str(data.get("status", "")) in ["VERIFIED_WIN", "VERIFIED_LOSS"]:
			if not _connection_gate().journal_close("hunt", str(_solo_context.get("session_id", ""))): return
			_online_exit_reconciled = true
		_online_turn_payload.clear()
		_refresh_online_spell_buttons()
		_refresh_online_inspiration()
		_present_online_terminal()
		connection_gate_recover()
		return
	if request_id.is_empty() or request_id != _online_hunt_request:
		return
	_online_hunt_request = ""
	if _connection_gate().blocked() and not _connection_gate()._player_verified:
		return
	var session: Variant = data.get("session")
	if ok and session is Dictionary and str(session.get("session_id", "")) == str(_solo_context.get("session_id", "")) and str(session.get("status", "")) in ["EXPIRED", "FORFEIT"] and not _online_identity_invalid and not _combat_identity.is_empty() and _combat_backend._verified_player_id == _combat_identity:
		_gate_session_verified = not _connection_gate().blocked() or _connection_gate()._player_verified
		if not _online_turn_payload.is_empty():
			_online_closed_recovery = str(session.status)
			_send_online_pending_turn()
			return
		if not _solo_forfeit_action.is_empty():
			if str(session.status) == "FORFEIT":
				if not _connection_gate().journal_confirm(_solo_forfeit_action): return
				_solo_forfeit_action = ""
			else:
				_online_closed_recovery = str(session.status)
				_solo_forfeit_request = _combat_backend.request_api("POST", "/world/boss-hunts/forfeit", {"session_id": str(_solo_context.session_id), "client_action_id": _solo_forfeit_action}, false, _connection_gate().blocked())
				return
		if not _connection_gate().journal_close("hunt", str(_solo_context.get("session_id", ""))): return
		_online_exit_reconciled = true
		_show_closed_online_session(str(session.status))
		connection_gate_recover()
		return
	# A forfeit may have been journaled on the loadout screen before combat existed.
	if ok and session is Dictionary and not _solo_forfeit_action.is_empty() and _online_turn_payload.is_empty() and not _online_identity_invalid and not _combat_identity.is_empty() and _combat_backend._verified_player_id == _combat_identity and str(session.get("session_id", "")) == str(_solo_context.get("session_id", "")) and str(session.get("status", "")) == "ACTIVE" and int(session.get("combat_revision", -1)) == 0:
		_gate_session_verified = not _connection_gate().blocked() or _connection_gate()._player_verified
		_solo_forfeit_request = _combat_backend.request_api("POST", "/world/boss-hunts/forfeit", {"session_id": str(_solo_context.session_id), "client_action_id": _solo_forfeit_action}, false, _connection_gate().blocked())
		return
	if not ok or not session is Dictionary or _online_identity_invalid or _combat_backend._verified_player_id != _combat_identity or _combat_identity.is_empty() or str(session.get("session_id", "")) != str(_solo_context.get("session_id", "")) or not _valid_online_result(session) or int(session.get("combat_revision", 0)) < maxi(1, _online_hunt_revision) or not session.get("combat_state") is Dictionary or not session.get("combat_loadout") is Dictionary or session.get("combat_state", {}).is_empty() or session.get("combat_loadout", {}).is_empty():
		_hide_online_hunt_view()
		_log_immediate("Server combat unavailable. Retry or return; the session remains active.")
		_set_next_turn_action("retry")
		next_turn_btn.show()
		return
	if _combat_wait_timer:
		_combat_wait_timer.stop()
	_online_hunt_session = session.duplicate(true)
	_online_hunt_revision = int(session.combat_revision)
	if not _render_online_hunt(session):
		_online_hunt_session.clear()
		_log_immediate("Invalid server combat snapshot. Retry or return.")
		_set_next_turn_action("retry")
		next_turn_btn.show()
		return
	_gate_session_verified = not _connection_gate().blocked() or _connection_gate()._player_verified
	if not _online_turn_payload.is_empty():
		var expected := int(_online_turn_payload.get("expected_revision", -1))
		if _online_hunt_revision < expected or (_online_hunt_revision == expected and str(session.status) != "ACTIVE"):
			_online_turn_unresolved()
			return
		_send_online_pending_turn()
		return
	if not _solo_forfeit_action.is_empty() and not _connection_gate().blocked():
		if str(session.status) in ["VERIFIED_WIN", "VERIFIED_LOSS"]:
			_online_closed_recovery = str(session.status)
		_request_solo_forfeit()
		return
	if str(session.status) in ["VERIFIED_WIN", "VERIFIED_LOSS"] and not _solo_forfeit_action.is_empty():
		_online_closed_recovery = str(session.status)
	if str(session.status) in ["VERIFIED_WIN", "VERIFIED_LOSS"] and _solo_forfeit_action.is_empty():
		if not _connection_gate().journal_close("hunt", str(_solo_context.get("session_id", ""))): return
		_online_exit_reconciled = true
	_refresh_online_spell_buttons()
	_refresh_online_inspiration()
	next_turn_btn.hide()
	_present_online_terminal()
	connection_gate_recover()

func _online_playback_valid(generation: int, session_id: String, action_id: String, revision: int, playback_epoch: int) -> bool:
	return is_inside_tree() and playback_epoch == _gate_epoch and not _online_identity_invalid and _combat_backend != null and _combat_backend._session_generation == generation and not _combat_identity.is_empty() and _combat_backend._verified_player_id == _combat_identity and str(_solo_context.get("session_id", "")) == session_id and str(_online_turn_payload.get("client_action_id", "")) == action_id and _online_hunt_revision == revision

func connection_gate_lost() -> void:
	if _spectator_readonly:
		SpectatorClient.pause_for_recovery()
		return
	_gate_epoch += 1
	_gate_session_verified = false
	_online_presenting_events = false
	_online_event_turn = -1
	_dungeon_playing_events = false
	_dungeon_presentation_turn = -1
	_dungeon_synchronized = false
	if _online_hunt_guard:
		_refresh_online_spell_buttons()
		_refresh_online_inspiration()
	elif _dungeon_guard:
		_dungeon_refresh_controls()

func connection_gate_recover() -> void:
	if _spectator_readonly:
		if SpectatorClient.recover_after_gate(): _connection_gate().recovery_completed()
		return
	if not _connection_gate().blocked() or not _connection_gate()._player_verified:
		return
	if _combat_backend == null:
		return
	if _combat_backend._verified_player_id.is_empty() and not _combat_backend.token.is_empty():
		_combat_backend.refresh_state()
		return
	if _online_hunt_guard:
		if _online_identity_invalid or _combat_backend._verified_player_id != _combat_identity:
			return
		if not _gate_session_verified:
			if _online_hunt_request.is_empty() and _online_turn_request.is_empty() and not _online_presenting_events:
				_on_online_hunt_identity({"player_id": _combat_identity})
		elif _online_turn_payload.is_empty() and _online_turn_request.is_empty() and not _online_presenting_events and _solo_forfeit_request.is_empty():
			if not _solo_forfeit_action.is_empty():
				_solo_forfeit_request = _combat_backend.request_api("POST", "/world/boss-hunts/forfeit", {"session_id": str(_solo_context.session_id), "client_action_id": _solo_forfeit_action}, false, true)
			else:
				_connection_gate().recovery_completed()
	elif _dungeon_guard:
		if _combat_backend._verified_player_id != _dungeon_identity:
			return
		if not _gate_session_verified:
			if _dungeon_request.is_empty() and not _dungeon_playing_events:
				_dungeon_recover()
		elif _dungeon_pending.is_empty() and not _dungeon_playing_events:
			_connection_gate().recovery_completed()
	else:
		_connection_gate().recovery_completed()

func _show_closed_online_session(status: String) -> void:
	_online_hunt_session = {"status": status}
	_hide_online_hunt_view()
	_log_immediate("Encounter " + status.to_lower() + ".")
	_set_next_turn_action("return")
	next_turn_btn.show()

func _online_hunt_event_delay(event: Dictionary) -> float:
	var kind := str(event.get("kind", ""))
	if kind in ["status_snapshot", "boss_intent", "combat_terminal"]:
		return 0.0
	if kind in ["status_applied", "status_changed"] or kind.begins_with("boss_shield"):
		return 1.25
	if kind in ["damage", "true_damage", "reflect", "corrosion", "hom_corrosion", "hom_damage", "status_tick", "heal", "miss", "evade", "hom_miss", "switch", "boss_special_cast"]:
		return LOG_STEP_SECONDS
	return 0.8

func _log_online_spell(spell_id: String, player_cast: bool) -> void:
	var spell: Dictionary = _reg.get_spell_by_id(spell_id)
	var attacker: Control = player_entity if player_cast else enemy_entity
	var attack := str(spell.get("category", "")) == "attack"
	if attack:
		_animate_lunge(attacker, 20.0 if player_cast else -20.0, true)
	else:
		_animate_pulse(attacker, Color(0.62, 0.7, 1.0), 1.04)
	_append_combat_log("", {"category": "damage" if attack else "buff", "actor": player_entity_name.text if player_cast else enemy_entity_name.text, "actor_color": "69d7e8" if player_cast else "f2a078", "verb": " uses ", "spell_id": spell_id, "spell_name": str(spell.get("name", spell_id)), "suffix": "."})

func _log_online_hunt_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	if kind == "hom_passive" and event.has("effects"):
		if str(event.get("actor", "")) == "player": CombatVFX.passive(player_hom, player_entity)
		var passive_hom: Dictionary = _reg.get_homunculus_collection().get(str(event.get("hom_id", "")), {}) if _reg else {}
		if not passive_hom.is_empty():
			_append_combat_log(_log_presenter.passive_message(event, passive_hom), {"category":"homunculus"})
		else:
			_append_combat_log("Homunculus passive activated.", {"category":"homunculus"})
		return
	if kind in ["status_snapshot", "boss_intent", "combat_terminal"]:
		return
	if kind == "boss_special_cast":
		_log_online_spell(str(event.get("spell_id", "")), false)
		return
	var actor := str(event.get("actor", ""))
	var target := str(event.get("target", ""))
	if actor.is_empty():
		actor = target
	var is_player := actor == "player"
	var actor_name := player_entity_name.text if is_player else enemy_entity_name.text if actor == "boss" else "Minion" if not actor.is_empty() else "Combat"
	var damage := int(event.get("actual_damage", event.get("damage", 0)))
	var category := "damage" if kind in ["damage", "true_damage", "reflect", "corrosion", "hom_corrosion", "hom_damage", "status_tick"] else "heal" if kind == "heal" else "miss" if kind in ["miss", "evade", "hom_miss"] else "shield" if kind.begins_with("boss_shield") else "debuff" if kind in ["status_applied", "status_changed"] else "switch" if kind == "switch" else "system"
	var entry := {"category": category, "actor": actor_name, "actor_kind": "entity", "actor_side": "player" if is_player else "enemy", "actor_color": "69d7e8" if is_player else "f2a078", "verb": " " + kind.replace("_", " ")}
	if kind in ["damage", "true_damage", "corrosion", "hom_corrosion", "hom_damage"]:
		entry["verb"] = " deals %d damage to" % damage
	elif kind == "miss" or kind == "hom_miss":
		entry["verb"] = "'s spell misses" if kind == "miss" and event.has("spell_id") else " misses"
	elif kind == "status_applied":
		entry["verb"] = " applies %s to" % str(event.get("status", "effect")).replace("_", " ")
	elif kind == "boss_action":
		entry["verb"] = " prepares " + str(event.get("action", "Strike"))
	if not target.is_empty() and target != actor:
		entry["target"] = " " + (player_entity_name.text if target == "player" else enemy_entity_name.text if target == "boss" else "Minion")
		entry["target_color"] = "69d7e8" if target == "player" else "f2a078"
	entry["suffix"] = "."
	if kind in ["hom_damage", "hom_miss"]:
		_animate_lunge(player_hom, 12.0, false)
	elif kind == "boss_action" and str(event.get("action", "")) in ["Strike", "Fury Strike"]:
		_animate_lunge(enemy_entity, -20.0, true)
	if damage > 0:
		var target_sprite: Control = player_entity if target == "player" else enemy_entity
		var hp_bar: ProgressBar = player_hp if target == "player" else enemy_hp
		var minion_index := _online_visible_minions.find(target)
		if minion_index >= 0 and minion_index < _solo_minion_views.size():
			target_sprite = _solo_minion_views[minion_index]
		var actual := mini(damage, int(hp_bar.value)) if target in ["player", "boss"] else damage
		if event.has("hp") and target in ["player", "boss"]:
			actual = maxi(0, int(hp_bar.value) - int(event.hp))
		elif event.has("hp") and minion_index >= 0:
			for minion in _solo_minions:
				if str(minion.get("id", "")) == target:
					actual = maxi(0, int(minion.get("hp", 0)) - int(event.hp))
					break
		var committed := int(event.get("actual_damage", damage)) > 0
		var direct := kind == "damage" and str(event.get("source", "")) != "pending_drain" and committed
		var combat: Dictionary = _online_hunt_session.get("combat_state", {})
		var source: Dictionary = combat.get("player" if is_player else "boss", {})
		if direct and is_player:
			var spell: Dictionary = _reg.get_spell_by_id(str(event.get("spell_id", ""))) if _reg else {}
			direct = str(spell.get("category", "")) == "attack" and (target == "boss" or minion_index >= 0)
		elif direct and actor != "boss":
			direct = false
			for minion in combat.get("minions", []):
				if str(minion.get("id", "")) == actor:
					source = minion.duplicate()
					if str(source.get("element_type", "")).is_empty(): source["element_type"] = str(combat.get("boss", {}).get("type", ""))
					direct = target == "player"
					break
		elif direct:
			direct = target == "player"
		if direct: CombatVFX.hit_fighter(target_sprite, source)
		if actual > 0:
			_animate_hit(target_sprite, actual, int(hp_bar.max_value))
			_show_damage_number(target_sprite, actual)
	elif kind in ["heal", "status_applied"]:
		_animate_pulse(player_entity if target == "player" else enemy_entity, Color(0.62, 0.85, 1.0), 1.04)
	_append_combat_log("", entry)

func _valid_online_result(session: Dictionary) -> bool:
	var status := str(session.get("status", ""))
	if status == "ACTIVE":
		return true
	if status not in ["VERIFIED_WIN", "VERIFIED_LOSS"] or not session.get("combat_state") is Dictionary:
		return false
	return str(session.combat_state.get("terminal_result", "")) == ("WIN" if status == "VERIFIED_WIN" else "LOSS")

func _present_online_terminal() -> void:
	var status := str(_online_hunt_session.get("status", ""))
	if status not in ["VERIFIED_WIN", "VERIFIED_LOSS"]:
		return
	_online_hunt_info.show()
	_online_hunt_info.text = "Server result: " + ("VICTORY" if status == "VERIFIED_WIN" else "DEFEAT")
	if status == "VERIFIED_WIN":
		if _online_hunt_session.has("global_event_id"):
			var global_value: Variant = _online_hunt_session.get("global_status", {})
			var global_status: Dictionary = global_value if global_value is Dictionary else {}
			var session_key := str(_online_hunt_session.get("session_id", ""))
			if session_key.is_empty():
				session_key = str(get_instance_id())
			var presented: Dictionary = _global_reward_presented.get(session_key, {})
			if global_status.get("reward_status") == "WAITING":
				_online_hunt_info.text = "Victory registered — awaiting other players (%d/5)" % int(global_status.get("winner_count", 0))
				if not presented.get("waiting", false) and not presented.get("paid", false):
					presented["waiting"] = true
					_global_reward_presented[session_key] = presented
					_show_global_rewards(global_status, false)
			elif global_status.get("reward_status") == "PAID":
				_online_hunt_info.text = "Victory registered — reward delivered (5/5)"
				if not presented.get("paid", false) and global_status.get("reward") is Dictionary:
					presented["paid"] = true
					_global_reward_presented[session_key] = presented
					_show_global_rewards(global_status, true)
			else:
				_online_hunt_info.text = "Victory after event completion — no reward registered."
		var reward: Variant = _online_hunt_session.get("pve_reward", {})
		if not _online_hunt_session.has("global_event_id") and reward is Dictionary and reward.get("grants") is Dictionary:
			var parts: Array[String] = []
			for resource in reward.grants:
				parts.append("+%s %s" % [str(reward.grants[resource]), str(resource).replace("_", " ").capitalize()])
			if not parts.is_empty():
				_online_hunt_info.text += " | " + ", ".join(parts)
				if not _reward_popup_shown:
					_reward_popup_shown = true
					_show_pve_rewards(reward.grants)
	if not _online_terminal_shown:
		_online_terminal_shown = true
		_log_immediate(_online_hunt_info.text)
	_set_next_turn_action("return")
	next_turn_btn.show()

func _send_online_pending_turn() -> void:
	if _spectator_readonly: return
	if _online_identity_invalid or _online_turn_payload.is_empty() or not _online_turn_request.is_empty() or not _online_hunt_request.is_empty() or _combat_backend == null or _combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity or _combat_backend.token.is_empty():
		_online_turn_unresolved()
		return
	var is_inspiration := str(_online_turn_payload.get("decision", {}).get("kind", "")) in ["choose", "decline"]
	var endpoint := "/world/boss-hunts/inspiration" if is_inspiration else "/world/boss-hunts/turn"
	_online_turn_request = _combat_backend.request_api("POST", endpoint, _online_turn_payload.duplicate(true), false, _connection_gate().blocked() and _gate_session_verified)
	if _online_turn_request.is_empty():
		_online_turn_unresolved()
	elif _combat_wait_timer:
		_combat_wait_timer.start(10.0)

func _render_online_hunt(session: Dictionary, preserve_hp: bool = false) -> bool:
	var state: Dictionary = session.combat_state
	_show_physical_anomaly(state.get("physical_anomaly"))
	var loadout: Dictionary = session.combat_loadout
	var boss_def: Variant = session.get("boss_definition", {})
	if not boss_def is Dictionary or not state.get("player") is Dictionary or not state.get("boss") is Dictionary or not state.get("moves") is Array or state.moves.size() != 4 or not state.get("minions") is Array:
		return false
	_solo_def = boss_def.duplicate(true)
	var p: Dictionary = state.player
	var b: Dictionary = state.boss
	if int(p.get("max_hp", 0)) <= 0 or int(b.get("max_hp", 0)) <= 0 or str(loadout.get("entity_id", "")).is_empty():
		return false
	if _online_hunt_info == null:
		_apply_world_combat_visuals(str(SceneRouter._spectator_context.get("visual_zone_id", "")) if _spectator_readonly else str(_solo_context.get("visual_zone_id", "")))
		_create_solo_panel()
		_online_hunt_info = Label.new()
		_online_hunt_info.name = "OnlineHuntInfo"
		_online_hunt_info.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_online_hunt_info.position = Vector2(-250, 215)
		_online_hunt_info.size = Vector2(500, 95)
		_online_hunt_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_online_hunt_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if OS.has_feature("android"):
			_solo_panel.add_child(_online_hunt_info)
		else:
			add_child(_online_hunt_info)
	if not OS.has_feature("android"):
		_solo_panel.get_parent().show()
	get_node("PlayerPanel").show()
	get_node("EnemyPanel").show()
	_enemy_hom_status.hide()
	_enemy_inspiration.hide()
	_player_inspiration.show()
	_player_inspiration.call("set_fighter", p)
	player_hom_name.modulate.a = 0.0
	enemy_hom_name.modulate.a = 0.0
	$EnemyPanel/EnemyBuildTitle.modulate.a = 0.0
	$EnemyPanel/EnemyItems.modulate.a = 0.0
	call_deferred("_align_health_panels")
	var world_sprites := get_node_or_null("WorldCombatSprites") as CanvasItem
	if world_sprites:
		world_sprites.show()
	_online_hunt_info.visible = not preserve_hp and str(session.get("status", "")) != "ACTIVE"
	spell_panel.show()
	for pair in [[player_hp, p], [enemy_hp, b]]:
		var icon: Node = pair[0].get_node_or_null("CombatTypeIcon")
		if icon == null:
			icon = CombatTypeIcon.new()
			icon.name = "CombatTypeIcon"
			icon.position = Vector2(-30, -3)
			pair[0].add_child(icon)
		icon.call("configure", str(pair[1].get("type", "")))
	player_hp.max_value = float(p.max_hp)
	enemy_hp.max_value = float(b.max_hp)
	if not preserve_hp:
		_set_display_hp(player_hp, int(p.get("hp", 0)))
		_set_display_hp(enemy_hp, int(b.get("hp", 0)))
	var entity_id := str(loadout.get("entity_id", ""))
	var entity := _find_by_id(_entities, entity_id)
	var hom_id := str(loadout.get("homunculus_id", "")) if loadout.get("homunculus_id") != null else ""
	var hom := _online_homunculus(hom_id)
	player_entity_name.text = str(entity.get("name", entity_id))
	enemy_entity_name.text = str(boss_def.get("name", "Boss"))
	enemy_name.text = "BOSS - " + str(b.get("tier", "")).to_upper()
	player_entity.texture = _load_preview_tex(entity_id, "entity", str(p.get("type", "")))
	player_hom.visible = not hom_id.is_empty() and not bool(p.get("homunculus_spent", false))
	if not hom_id.is_empty():
		player_hom.texture = _load_preview_tex(hom_id, "homunculus", str(hom.get("name", "")))
	_player_hom_status.visible = not hom_id.is_empty()
	_player_hom_status.call("set_fighter", {"hom_name": str(hom.get("name", hom_id)), "hom_data": hom, "hom_energy": int(p.get("homunculus_energy", 0)), "hom_spent": bool(p.get("homunculus_spent", false))})
	enemy_hom.hide()
	enemy_item1.hide()
	enemy_item2.hide()
	var assets := AssetCatalog.new()
	var texture_id := str(boss_def.get("texture_id", ""))
	var requested := str(_solo_context.get("display_texture_id", ""))
	if requested == texture_id or requested in boss_def.get("texture_variants", []):
		texture_id = requested
	if texture_id.begins_with("res://assets/lab/bosses/") and texture_id.ends_with(".png") and not ".." in texture_id and not "\\" in texture_id and ResourceLoader.exists(texture_id):
		enemy_entity.texture = load(texture_id) as Texture2D
	else:
		enemy_entity.texture = assets.get_tex(texture_id)
	enemy_entity.flip_h = false
	assets.free()
	var weapons: Variant = loadout.get("weapon_ids", [])
	for i in 2:
		var id := str(weapons[i]) if weapons is Array and weapons.size() > i and weapons[i] != null else ""
		var icon: TextureRect = player_item1 if i == 0 else player_item2
		_set_item_icon(icon, _find_by_id(_items, id))
		icon.modulate.a = 1.0 if int(p.get("active_weapon_slot", 1)) == i + 1 else 0.5
	for i in 4:
		var move: Dictionary = state.moves[i]
		var spell: Dictionary = _reg.get_spell_by_id(str(move.get("id", "")))
		var cd := int(move.get("cooldown_remaining", 0))
		var power_value := float(move.get("power_mult", spell.get("power_mult", 0)))
		_set_localized_spell_button(spell_buttons[i], spell, str(move.get("name", spell.get("name", move.get("id", "")))), power_value, float(move.get("accuracy", spell.get("accuracy", 0))), cd)
		var types: Array = [str(spell.get("primary_type", "")), str(spell.get("secondary_type", ""))] if spell.get("type") == "hybrid" else [str(spell.get("type", "universal"))]
		for icon_index in 2:
			var icon_name := "OnlineSpellType%d" % icon_index
			var type_icon: Control = spell_buttons[i].get_node_or_null(icon_name)
			if type_icon == null:
				type_icon = CombatTypeIcon.new()
				type_icon.name = icon_name
				type_icon.position = Vector2(5 + icon_index * 25, 5)
				type_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				spell_buttons[i].add_child(type_icon)
			type_icon.visible = icon_index < types.size() and not types[icon_index].is_empty()
			if type_icon.visible:
				type_icon.call("configure", types[icon_index])
		spell_buttons[i].disabled = true
	turn_label.text = "Boss Hunt | Turn %d | Revision %d" % [int(state.get("turn", 0)), _online_hunt_revision]
	player_indicators.set_fighter(0, p)
	enemy_indicators.set_fighter(0, b)
	var shield: Dictionary = state.get("shield", {})
	var fury: Dictionary = state.get("fury", {})
	var power: Dictionary = state.get("power_turn", {})
	var effects: Array = []
	var player_effects: Array = []
	for pair in [[p, player_effects], [b, effects]]:
		var fighter: Dictionary = pair[0]
		var indicators: Array = pair[1]
		var side := "player" if is_same(fighter, p) else "boss"
		if fighter.get("strategic_trap") is Dictionary:
			var trap: Dictionary = fighter.strategic_trap
			var remaining := maxi(0, int(trap.get("expires_turn", 0)) - int(state.get("turn", 0)))
			indicators.append({"icon": "trap", "label": "%dT" % remaining, "tooltip": tr("STATUS_TRAP_DETAIL") % [roundi(float(trap.get("value", 0)) * 100), remaining]})
		if fighter.get("strategic_heal_suppression") is Dictionary:
			var remaining := maxi(0, int(fighter.strategic_heal_suppression.get("expires_turn", 0)) - int(state.get("turn", 0)))
			indicators.append({"icon": "heal_block", "label": "%dT" % remaining, "tooltip": tr("STATUS_HEAL_SUPPRESSION_DETAIL") % remaining})
		for delayed in state.get("strategic_delayed", []):
			if delayed.get("target") == side: indicators.append({"icon":"hourglass", "label":str(delayed.get("amount", 0)), "tooltip":tr("STATUS_DELAYED_DETAIL") % [int(delayed.get("amount", 0)), int(delayed.get("due_turn", 0))]})
	if int(shield.get("turns", 0)) > 0:
		var shield_tooltip := tr("STATUS_BOSS_SHIELD_BURNED") if bool(shield.get("suppressed", false)) else _boss_ability_description("Shield")
		effects.append({"icon": "shield", "label": "%d%% %dT" % [roundi(float(shield.get("reduction", 0)) * 100), int(shield.turns)], "tooltip": shield_tooltip})
	if bool(fury.get("pending", false)):
		effects.append({"icon": "fury", "label": Stats.percent(float(fury.get("multiplier", 1))), "tooltip": _boss_ability_description("Fury")})
	if not preserve_hp:
		_solo_minions = state.minions.duplicate(true)
	var alive := 0
	for minion in _solo_minions:
		if int(minion.get("hp", 0)) > 0:
			alive += 1
	if alive > 0:
		effects.append({"icon": "minions", "label": str(alive), "tooltip": _boss_ability_description("Summon")})
	enemy_indicators.set_boss_effects(true, effects)
	if bool(power.get("active", false)):
		player_effects.append({"icon": "power", "label": "x2", "tooltip": _boss_ability_description("Power")})
	player_indicators.set_boss_effects(true, player_effects)
	_update_solo_minion_views()
	var intent := str(b.get("intent", ""))
	if intent == "Special":
		var special: Dictionary = _reg.get_spell_by_id(str(b.get("intent_spell_id", "")))
		intent = str(special.get("name", intent))
	_solo_intent = str(b.get("intent", ""))
	_solo_signature = _reg.get_spell_by_id(str(b.get("intent_spell_id", "")))
	_solo_intent_button.text = "NEXT: " + intent
	_solo_status.text = "%s | %s\nShield: %d%% | %d turns\n%s" % [str(boss_def.get("name", "Boss")), str(b.get("tier", "")).to_upper(), roundi(float(shield.get("reduction", 0)) * 100), int(shield.get("turns", 0)), "Boss Protected - Kill Minions" if alive > 0 else "Boss vulnerable"]
	_solo_power_label.visible = bool(power.get("active", false)) or bool(fury.get("pending", false))
	if bool(power.get("active", false)):
		_solo_power_label.text = "POWER TURN x2"
	elif bool(fury.get("pending", false)):
		_solo_power_label.text = "FURY PENDING %s power" % Stats.percent(float(fury.get("multiplier") if fury.get("multiplier") != null else 1.0))
	else:
		_solo_power_label.text = ""
	return true

func _refresh_online_spell_buttons() -> void:
	for i in spell_buttons.size():
		spell_buttons[i].disabled = not _online_turn_payload.is_empty() or not _online_turn_request.is_empty() or _online_spell_decision(i).is_empty()
	var decision := _online_switch_decision()
	switch_weapon_btn.visible = not _online_hunt_session.is_empty()
	switch_weapon_btn.disabled = decision.is_empty()
	if not decision.is_empty():
		var weapons: Array = _online_hunt_session.combat_loadout.weapon_ids
		var item := _find_by_id(_items, str(weapons[int(decision.switch_slot) - 1]))
		switch_weapon_btn.text = ("Switch to:\n" if OS.has_feature("android") else "Switch to: ") + str(item.get("name", weapons[int(decision.switch_slot) - 1]))

func _online_turn_unresolved() -> void:
	for button in spell_buttons:
		button.disabled = true
	switch_weapon_btn.disabled = true
	_refresh_online_inspiration()
	_log_immediate("Turn response uncertain. Recovery is required; no new turn has been sent.")
	_set_next_turn_action("recover")
	next_turn_btn.show()

func _refresh_online_inspiration() -> void:
	if not _online_hunt_guard or _inspiration_panel == null:
		return
	var state: Dictionary = _online_hunt_session.get("combat_state", {})
	var inspiration: Dictionary = state.get("inspiration", {})
	var offers: Variant = inspiration.get("offers", [])
	if str(_online_hunt_session.get("status", "")) != "ACTIVE" or not bool(inspiration.get("pending", false)) or not offers is Array or offers.size() != 3:
		_inspiration_panel.hide()
		_inspiration_options.clear()
		return
	var options: Array = []
	var seen := {}
	for id in offers:
		var spell: Dictionary = _reg.get_spell_by_id(str(id))
		if str(id).is_empty() or seen.has(str(id)) or spell.is_empty():
			_inspiration_panel.hide()
			_inspiration_options.clear()
			_log_immediate("Invalid server Inspiration offers. Reconnect to recover.")
			return
		seen[str(id)] = true
		options.append(spell)
	_inspiration_options = options
	var locked := not _online_turn_payload.is_empty() or not _online_turn_request.is_empty() or not _online_hunt_request.is_empty() or _online_identity_invalid or not _online_hom_payload.is_empty()
	for i in 3:
		var spell: Dictionary = options[i]
		_inspiration_cards[i].text = _spell_description(spell)
		_inspiration_cards[i].tooltip_text = _spell_description(spell)
		_inspiration_cards[i].disabled = locked
		_inspiration_cards[i].get_node("TypeIcon").call("configure", str(spell.get("primary_type", spell.get("type", ""))))
	var cancel := _inspiration_panel.get_node("Content/Cancel") as Button
	cancel.disabled = locked
	_inspiration_panel.show()

func _send_online_inspiration(decision: Dictionary) -> void:
	if _spectator_readonly: return
	if _online_identity_invalid or _combat_backend == null or _combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity or _combat_backend.token.is_empty() or not _online_turn_payload.is_empty() or not _online_hom_payload.is_empty() or not _online_turn_request.is_empty() or not _online_hunt_request.is_empty() or str(_online_hunt_session.get("status", "")) != "ACTIVE" or int(_online_hunt_session.get("combat_revision", 0)) != _online_hunt_revision:
		return
	var inspiration: Dictionary = _online_hunt_session.get("combat_state", {}).get("inspiration", {})
	if not bool(inspiration.get("pending", false)):
		return
	if str(decision.get("kind", "")) == "choose" and str(decision.get("spell_id", "")) not in inspiration.get("offers", []):
		return
	if str(decision.get("kind", "")) not in ["choose", "decline"]:
		return
	_online_turn_payload = {"session_id": str(_solo_context.get("session_id", "")), "client_action_id": _combat_backend._make_uuid(), "expected_revision": _online_hunt_revision, "decision": decision.duplicate(true)}
	_refresh_online_spell_buttons()
	_refresh_online_inspiration()
	_send_online_pending_turn()

func _wait_for_combat_state() -> void:
	if _combat_wait_timer == null:
		_combat_wait_timer = Timer.new()
		_combat_wait_timer.one_shot = true
		_combat_wait_timer.timeout.connect(_on_combat_state_timeout)
		add_child(_combat_wait_timer)
	_combat_wait_timer.start(10.0)
	_combat_backend.refresh_state()

func _on_combat_state_timeout() -> void:
	if _combat_backend != null:
		_connection_gate().report_failure(_combat_backend, "network_error")
	if _online_hunt_guard:
		if not _online_turn_request.is_empty() and _combat_backend != null:
			_combat_backend._api_http.cancel_request()
			_combat_backend._api_in_flight.clear()
			_online_turn_request = ""
			_online_turn_unresolved()
			return
		if not _online_hunt_request.is_empty() and _combat_backend != null:
			_combat_backend._api_http.cancel_request()
			_combat_backend._api_in_flight.clear()
			_online_hunt_request = ""
		_hide_online_hunt_view()
		_log_immediate("Server combat unavailable. Retry or return; the session remains active.")
		_set_next_turn_action("retry")
		next_turn_btn.show()
		return
	if not _combat_started:
		_log_immediate("Player state unavailable. Press Retry or leave combat.")
		_set_next_turn_action("retry")
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
			_set_next_turn_action("return")
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
		_set_next_turn_action("return")
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

func _apply_dungeon_combat_visuals() -> void:
	var background := $Background as TextureRect
	background.texture = load("res://assets/ui/alchemy_kit/dungeons_combatbg.png") as Texture2D
	background.stretch_mode = TextureRect.STRETCH_SCALE
	var layer := Control.new()
	layer.name = "DungeonCombatSprites"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	move_child(layer, background.get_index() + 1)
	for entry in [[player_hom, Vector2(190, 505), Vector2(165, 165)], [player_entity, Vector2(480, 555), Vector2(250, 275)], [enemy_entity, Vector2(1438, 555), Vector2(250, 275)], [enemy_hom, Vector2(1730, 505), Vector2(165, 165)]]:
		var sprite: TextureRect = entry[0]
		var center: Vector2 = entry[1]
		if OS.has_feature("android") and sprite == player_entity:
			center.x += 70
		elif OS.has_feature("android") and sprite == enemy_entity:
			center.x = size.x * 0.80
		elif OS.has_feature("android") and sprite == enemy_hom:
			center.x = size.x * 0.93
		var dimensions: Vector2 = entry[2]
		sprite.reparent(layer)
		sprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sprite.position = Vector2(center.x - dimensions.x / 2, center.y - dimensions.y)
		sprite.size = dimensions
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_hom_status.position = Vector2(70, 540)
	_enemy_hom_status.position = Vector2(1610, 540)
	if OS.has_feature("android"):
		get_viewport().size_changed.connect(_align_android_dungeon_opponents, CONNECT_DEFERRED)
		_align_android_dungeon_opponents.call_deferred()
	call_deferred("_align_health_panels")

func _align_android_dungeon_opponents() -> void:
	if not has_node("DungeonCombatSprites"):
		return
	enemy_entity.position.x = size.x * 0.80 - enemy_entity.size.x / 2.0
	enemy_hom.position.x = size.x * 0.93 - enemy_hom.size.x / 2.0
	var status_width := maxf(_enemy_hom_status.size.x, _enemy_hom_status.get_combined_minimum_size().x)
	_enemy_hom_status.position.x = clampf(size.x * 0.93 - status_width / 2.0, 0.0, maxf(0.0, size.x - status_width))
	_align_health_panels()

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
	background.stretch_mode = TextureRect.STRETCH_SCALE
	var layer := Control.new()
	layer.name = "WorldCombatSprites"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	move_child(layer, background.get_index() + 1)
	for entry in [[player_hom, layout[1], Vector2(190, 190)], [player_entity, layout[2], Vector2(360, 390)], [enemy_entity, layout[3], Vector2(410, 390)]]:
		var sprite: TextureRect = entry[0]
		var center: Vector2 = entry[1]
		var dimensions: Vector2 = entry[2]
		if sprite == player_entity:
			center.y += 25
		sprite.reparent(layer)
		sprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sprite.position = Vector2(center.x - dimensions.x / 2, center.y - dimensions.y)
		sprite.size = dimensions
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if OS.has_feature("android"):
			sprite.set_meta("world_foot", center)
			sprite.set_meta("world_size", dimensions)
	if OS.has_feature("android"):
		background.resized.connect(_layout_android_world_sprites.bind(layer, background), CONNECT_DEFERRED)
		_layout_android_world_sprites.call_deferred(layer, background)
	enemy_hom.visible = false
	_player_hom_status.position = Vector2(float(layout[1].x) - 120.0, 710)
	$PlayerPanel/PlayerBottomSpacer.custom_minimum_size.y = 132
	_align_health_panels()

func _layout_android_world_sprites(layer: Control, background: TextureRect) -> void:
	if not is_instance_valid(layer) or not is_instance_valid(background):
		return
	var ratio := background.size / Vector2(1920.0, 1080.0)
	for sprite in layer.get_children():
		if not sprite is TextureRect or not sprite.has_meta("world_foot"):
			continue
		var foot: Vector2 = sprite.get_meta("world_foot") * ratio
		var dimensions: Vector2 = sprite.get_meta("world_size") * minf(ratio.x, ratio.y)
		sprite.size = dimensions
		sprite.position = background.position + foot - Vector2(dimensions.x / 2.0, dimensions.y)
	_align_health_panels()

func _on_back_pressed() -> void:
	if _spectator_readonly:
		SceneRouter.finish_spectating()
		return
	if _ranked_controller:
		_ranked_controller.back()
		return
	if not str(SceneRouter._dungeon_context.get("run_id", "")).is_empty():
		_connection_gate().dungeon_exit_warning()
		return
	if _online_hunt_guard:
		_online_hunt_exit(false)
		return
	if confirm_popup == null:
		push_warning("Combat: ConfirmLeave popup missing, leaving combat directly.")
		_leave_combat()
		return
	if confirm_popup.visible:
		return
	confirm_popup.popup_centered(Vector2i(600, 240))

func _on_confirm_stay() -> void:
	if confirm_popup:
		confirm_popup.hide()

func _on_confirm_leave() -> void:
	if _spectator_readonly: return
	if confirm_popup:
		confirm_popup.hide()
	if _ranked_controller:
		_ranked_controller.forfeit()
		return
	if _online_hunt_guard:
		_online_hunt_exit(true)
		return
	if _solo_boss_mode and not str(_solo_context.get("session_id", "")).is_empty():
		if _resolving_exchange or _processing_steps:
			_log_immediate("Wait for the current exchange before forfeiting.")
			return
		_request_solo_forfeit()
		return
	_leave_combat()

func _online_hunt_exit(confirmed: bool) -> void:
	if _connection_gate().blocked() or _online_identity_invalid or _combat_backend == null or _combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity or _combat_backend.token.is_empty() or str(_solo_context.get("session_id", "")).is_empty():
		_log_immediate("Recover the authenticated encounter before leaving.")
		return
	if not _solo_forfeit_request.is_empty() or not _online_turn_payload.is_empty() or not _online_hom_payload.is_empty() or not _online_turn_request.is_empty() or not _online_hunt_request.is_empty() or _online_presenting_events:
		_log_immediate("Pending encounter action must be recovered before leaving.")
		return
	var status := str(_online_hunt_session.get("status", ""))
	if status == "ACTIVE":
		if not _solo_forfeit_action.is_empty():
			_on_online_hunt_identity({"player_id": _combat_identity})
		elif confirmed:
			_request_solo_forfeit()
		elif confirm_popup:
			confirm_popup.popup_centered(Vector2i(600, 240))
	elif status in ["VERIFIED_WIN", "VERIFIED_LOSS", "EXPIRED", "FORFEIT"] and _online_exit_reconciled and _solo_forfeit_action.is_empty():
		_return_from_solo_hunt()
	else:
		_log_immediate("Recover the encounter before leaving.")
		_on_online_hunt_identity({"player_id": _combat_identity})

func _request_solo_forfeit() -> void:
	if _spectator_readonly: return
	if not _solo_forfeit_request.is_empty():
		return
	if _online_hunt_guard and (_online_presenting_events or not _online_turn_payload.is_empty() or not _online_hom_payload.is_empty() or not _online_turn_request.is_empty() or not _online_hunt_request.is_empty() or _online_hunt_session.is_empty()):
		_log_immediate("Recover the encounter before forfeiting.")
		return
	if _combat_backend == null or _combat_backend.token.is_empty() or (_online_hunt_guard and (_combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity)):
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
	if _online_hunt_guard and (not _online_exit_reconciled or not _solo_forfeit_request.is_empty() or not _solo_forfeit_action.is_empty() or _connection_gate().blocked() or _online_identity_invalid or _combat_backend == null or _combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity):
		return
	var zone := str(_solo_context.get("visual_zone_id", ""))
	SceneRouter._world_encounter_return = _solo_context.get("return_view", {}).duplicate(true)
	if SceneRouter._world_encounter_return.is_empty() and not _combat_identity.is_empty() and not _online_hunt_session.is_empty():
		var session := _online_hunt_session
		var parent := str(session.get("parent_hunt_id", ""))
		var hunt := str(session.get("hunt_id", ""))
		var event := str(session.get("global_event_id", ""))
		SceneRouter._world_encounter_return = {"zone_id": zone, "player_id": _combat_identity, "category": "global" if not event.is_empty() else ("special" if not parent.is_empty() or hunt != "hunt_common" else "common"), "hunt_id": parent if not parent.is_empty() else hunt, "event_id": event}
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
		var valid_hom := not _find_by_id(_homunculi, hom_id).is_empty()
		if not valid_hom and not str(SceneRouter._solo_hunt_context.get("session_id", "")).is_empty() and _combat_backend != null and not _combat_backend.token.is_empty() and _combat_identity == _combat_backend._verified_player_id and str(_combat_spell_state.get("player_id", "")) == _combat_identity:
			valid_hom = not _online_homunculus(hom_id).is_empty() and preload("res://scripts/domain/homunculus_progress.gd").collection_status(hom_id, false, _combat_spell_state.get("homunculus_progress", {}), true) == "owned"
		if _find_by_id(_entities, entity_id).is_empty() or not valid_hom:
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
	var selected_hom := str(data.get("homunculus_id", ""))
	if _find_by_id(_homunculi, selected_hom).is_empty() and not _trusted_expedition_hom(selected_hom):
		data["homunculus_id"] = str(_homunculi[0].get("id", "")) if not _homunculi.is_empty() else ""
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
	# Offline previews use the minimum Ancient Hunt budget; online snapshots supply their own HP.
	var hunt_caps := {"common": 110, "mythic": 135, "rare": 165, "epic": 205, "legendary": 250}
	enemy.max_hp = roundi(float(hunt_caps[_solo_def.tier]) * 0.8)
	enemy.hp = enemy.max_hp
	enemy.name = str(_solo_def.name)
	return true

func _create_solo_panel() -> void:
	_create_solo_minion_views()
	var panel := PanelContainer.new()
	panel.name = "BossInformation"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = 220
	panel.offset_bottom = 490
	if has_node("WorldCombatSprites"):
		panel.offset_left = -220
		panel.offset_right = 220
		panel.offset_top = 360
		panel.offset_bottom = 470
	if OS.has_feature("android"):
		panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		panel.offset_left = -440
		panel.offset_right = -16
		panel.offset_top = 100
		panel.offset_bottom = 460
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.055, 0.94)
	style.border_color = Color("a9955d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(7 if has_node("WorldCombatSprites") else 14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	if OS.has_feature("android"):
		panel.hide()
		var info_button := Button.new()
		info_button.name = "BossInformationButton"
		info_button.text = "i"
		info_button.tooltip_text = "Boss information"
		info_button.custom_minimum_size = Vector2(64, 64)
		preload("res://scripts/ui/menu_art.gd").button(info_button)
		info_button.position = Vector2(68, 50)
		info_button.z_index = 190
		$EnemyHealthGroup.add_child(info_button)
		info_button.pressed.connect(func(): panel.visible = not panel.visible)
		panel.z_index = 195
	_solo_panel = VBoxContainer.new()
	_solo_panel.add_theme_constant_override("separation", 3 if has_node("WorldCombatSprites") else 8)
	if OS.has_feature("android"):
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		_solo_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_solo_panel)
	else:
		panel.add_child(_solo_panel)
	if OS.has_feature("android"):
		var close := Button.new()
		close.text = "X"
		close.tooltip_text = "UI_CLOSE"
		close.custom_minimum_size = Vector2(64, 64)
		close.size_flags_horizontal = Control.SIZE_SHRINK_END
		preload("res://scripts/ui/menu_art.gd").button(close)
		close.pressed.connect(panel.hide)
		_solo_panel.add_child(close)
	_solo_power_label = Label.new()
	_solo_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_solo_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_solo_power_label.add_theme_color_override("font_color", Color("ffca67"))
	_solo_panel.add_child(_solo_power_label)
	_solo_status = Label.new()
	_solo_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_solo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_solo_panel.add_child(_solo_status)
	_solo_intent_button = Button.new()
	_solo_intent_button.add_theme_font_size_override("font_size", 13)
	if OS.has_feature("android"):
		_solo_intent_button.custom_minimum_size.y = 60
		_solo_intent_button.add_theme_font_size_override("font_size", 20)
	_solo_intent_button.pressed.connect(func():
		if _solo_intent == "Special":
			_on_log_spell_clicked(str(_solo_signature.get("id", "")))
		else:
			_show_boss_ability("Fury" if _solo_intent == "FURY STRIKE" else _solo_intent)
	)
	_solo_panel.add_child(_solo_intent_button)
	_solo_targets = VBoxContainer.new()
	_solo_panel.add_child(_solo_targets)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.text = "Below 50% HP, a Power Turn may appear: deal x2 damage. If the boss survives, its next strike gains tier-scaled Fury. Defeat minions to expose the boss. " + ("Session active / Settlement locked. Local loadout unverified." if not str(_solo_context.get("session_id", "")).is_empty() else "Unverified preview.")
	if has_node("WorldCombatSprites") and not OS.has_feature("android"):
		panel.tooltip_text = help.text
		help.visible = false
	_solo_panel.add_child(help)
	for icons in [player_indicators, enemy_indicators]:
		icons.effect_clicked.connect(func(description: String):
			_spell_detail.title = "Combat Status"
			_spell_detail.dialog_text = description
			_spell_detail.popup_centered(Vector2i(440, 260))
		)
	_enemy_hom_status.hide()
	_enemy_inspiration.hide()
	enemy_name.modulate.a = 0.0
	$EnemyPanel/EnemyBuildTitle.modulate.a = 0.0
	$EnemyPanel/EnemyItems.modulate.a = 0.0
	enemy_item1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_item2.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _create_solo_minion_views() -> void:
	var texture := load("res://assets/lab/bosses/summoned-boss.png") as Texture2D
	for i in 2:
		var view := Control.new()
		view.name = "SummonedMinion%d" % i
		view.size = Vector2(110, 126)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.visible = false
		enemy_entity.add_child(view)
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(0, 10)
		portrait.size = Vector2(110, 106)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(portrait)
		if _online_hunt_guard or (_spectator_readonly and str(SceneRouter._spectator_context.get("mode", "")) == "hunt"):
			view.mouse_filter = Control.MOUSE_FILTER_STOP
			view.tooltip_text = "Inspect minion (no combat action)"
			view.gui_input.connect(_on_online_minion_input.bind(i))
			var marker := Label.new()
			marker.name = "Selection"
			marker.position = Vector2(0, 112)
			marker.size = Vector2(110, 18)
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marker.add_theme_font_size_override("font_size", 12)
			marker.add_theme_color_override("font_color", Color("67e5e2"))
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(marker)
		var hp := ColorRect.new()
		hp.name = "HP"
		hp.position = Vector2(10, 0)
		hp.size = Vector2(90, 4)
		hp.color = Color("182028")
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.color = Color("45d477")
		fill.size = Vector2(90, 4)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp.add_child(fill)
		view.add_child(hp)
		_solo_minion_views.append(view)

func _update_solo_minion_views() -> void:
	var alive: Array = []
	for minion in _solo_minions:
		if int(minion.get("hp", 0)) > 0:
			alive.append(minion)
	if _online_hunt_guard or (_spectator_readonly and str(SceneRouter._spectator_context.get("mode", "")) == "hunt"):
		_online_visible_minions.clear()
		for minion in alive:
			_online_visible_minions.append(str(minion.get("id", "")))
		if _online_inspected_minion not in _online_visible_minions:
			_online_inspected_minion = _online_visible_minions[0] if not _online_visible_minions.is_empty() else ""
	for i in _solo_minion_views.size():
		var view := _solo_minion_views[i]
		view.visible = i < alive.size()
		if not view.visible:
			continue
		var x := (enemy_entity.size.x - view.size.x) * 0.5
		var y := enemy_entity.size.y + 72.0
		if _online_hunt_guard or (_spectator_readonly and str(SceneRouter._spectator_context.get("mode", "")) == "hunt"):
			x = -view.size.x + 10.0 if i == 0 else enemy_entity.size.x - 10.0
			y = enemy_entity.size.y - view.size.y
		elif alive.size() > 1:
			x += -75.0 if i == 0 else 75.0
		view.position = Vector2(x, y)
		var fill := view.get_node("HP/Fill") as ColorRect
		fill.size.x = 90.0 * clampf(float(alive[i].hp) / maxf(1.0, float(alive[i].max_hp)), 0.0, 1.0)
		if _online_hunt_guard or (_spectator_readonly and str(SceneRouter._spectator_context.get("mode", "")) == "hunt"):
			var marker := view.get_node("Selection") as Label
			marker.text = "TARGET" if not _spectator_readonly and str(alive[i].get("id", "")) == _online_inspected_minion else ""

func _on_online_minion_input(event: InputEvent, index: int) -> void:
	if _spectator_readonly: return
	if not _online_hunt_guard or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or index < 0 or index >= _online_visible_minions.size():
		return
	_online_inspected_minion = _online_visible_minions[index]
	_update_solo_minion_views()

func _online_spell_decision(index: int) -> Dictionary:
	if not _online_hunt_guard or _online_hunt_session.is_empty() or str(_online_hunt_session.get("status", "")) != "ACTIVE" or _online_hunt_revision < 1 or int(_online_hunt_session.get("combat_revision", 0)) != _online_hunt_revision or not _online_hunt_request.is_empty() or not _online_turn_payload.is_empty() or not _online_hom_payload.is_empty() or _combat_backend == null or _combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity or _combat_backend.token.is_empty():
		return {}
	var state: Variant = _online_hunt_session.get("combat_state")
	if not state is Dictionary or bool(state.get("inspiration", {}).get("pending", false)):
		return {}
	var moves: Variant = state.get("moves")
	if not moves is Array or index < 0 or index >= moves.size() or not moves[index] is Dictionary:
		return {}
	var move: Dictionary = moves[index]
	if str(move.get("id", "")).is_empty() or int(move.get("cooldown_remaining", 0)) > 0:
		return {}
	var alive: Array[String] = []
	for minion in state.get("minions", []):
		if minion is Dictionary and int(minion.get("hp", 0)) > 0 and not str(minion.get("id", "")).is_empty():
			alive.append(str(minion.id))
	var target := "boss"
	if not alive.is_empty():
		target = _online_inspected_minion if _online_inspected_minion in alive else alive[0]
	return {"turn": int(state.get("turn", 0)) + 1, "spell_id": str(move.id), "target": target, "hom_action": "hold"}

func _online_switch_decision() -> Dictionary:
	if not _online_hunt_guard or _online_hunt_session.is_empty() or str(_online_hunt_session.get("status", "")) != "ACTIVE" or _online_hunt_revision < 1 or int(_online_hunt_session.get("combat_revision", 0)) != _online_hunt_revision or not _online_hunt_request.is_empty() or not _online_turn_request.is_empty() or not _online_turn_payload.is_empty() or not _online_hom_payload.is_empty() or _online_identity_invalid or _combat_backend == null or _combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity or _combat_backend.token.is_empty():
		return {}
	var state: Variant = _online_hunt_session.get("combat_state")
	var loadout: Variant = _online_hunt_session.get("combat_loadout")
	if not state is Dictionary or not state.get("player") is Dictionary or not loadout is Dictionary or not loadout.get("weapon_ids") is Array or loadout.weapon_ids.size() != 2 or bool(state.get("inspiration", {}).get("pending", false)):
		return {}
	var active := int(state.player.get("active_weapon_slot", 0))
	if active not in [1, 2]:
		return {}
	var other := 2 if active == 1 else 1
	if not loadout.weapon_ids[other - 1] is String or str(loadout.weapon_ids[other - 1]).is_empty():
		return {}
	return {"turn": int(state.get("turn", 0)) + 1, "switch_slot": other}

func _update_solo_panel() -> void:
	if not is_instance_valid(_solo_status):
		return
	_update_solo_minion_views()
	_solo_power_label.visible = _solo_power_active or _solo_fury_pending
	_solo_power_label.text = "POWER TURN x2 - DIRECT BOSS DAMAGE\nWARNING: SURVIVAL TRIGGERS FURY %s" % Stats.percent(float(_solo_def.fury_mult)) if _solo_power_active else "FURY PENDING %s power" % Stats.percent(float(_solo_def.fury_mult))
	var intent_name := str(_solo_signature.get("name", "Special")) if _solo_intent == "Special" else _solo_intent
	_solo_intent_button.text = "NEXT: " + intent_name
	_solo_status.text = "%s | %s\nShield: %d%% | %d turns\n%s" % [str(_solo_def.get("name", "Boss")), str(_solo_def.get("tier", "")).to_upper(), roundi(float(_solo_def.shield_reduction) * 100.0) if _solo_shield_turns > 0 else 0, _solo_shield_turns, "Boss Protected - Kill Minions" if _solo_has_minions() else "Boss vulnerable"]
	var player_effects: Array = []
	if _solo_power_active and not _battle_over:
		player_effects.append({"icon": "power", "label": "x2", "tooltip": _boss_ability_description("Power")})
	player_indicators.set_boss_effects(true, player_effects)
	var alive_minions := 0
	for minion in _solo_minions:
		if int(minion.hp) > 0:
			alive_minions += 1
	var boss_effects: Array = []
	if not _battle_over:
		if _solo_fury_pending:
			boss_effects.append({"icon": "fury", "label": Stats.percent(float(_solo_def.fury_mult)), "tooltip": _boss_ability_description("Fury")})
		if _solo_shield_turns > 0:
			boss_effects.append({"icon": "shield", "label": "%d%% %dT" % [roundi(float(_solo_def.shield_reduction) * 100), _solo_shield_turns], "tooltip": _boss_ability_description("Shield") + " Remaining: %d exchanges." % _solo_shield_turns})
		if alive_minions > 0:
			boss_effects.append({"icon": "minions", "label": str(alive_minions), "tooltip": _boss_ability_description("Summon")})
	enemy_indicators.set_boss_effects(true, boss_effects)
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
		_append_combat_log("POWER TURN x2 - Defeat the boss now or face Fury at %s power." % Stats.percent(float(_solo_def.fury_mult)), {"ability_id": "Power", "category": "buff"})

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
		_log_step("%s summons %d minions." % [enemy.name, int(_solo_def.minions)], _solo_summon, {"ability_id": "Summon", "category": "debuff"})
	elif intent == "Shield":
		_log_step("%s raises Alchemical Shield: %d%% mitigation, %d exchanges, %d%% healing." % [enemy.name, roundi(float(_solo_def.shield_reduction) * 100), int(_solo_def.shield_turns), roundi(float(_solo_def.shield_heal_ratio) * 100)], func():
			_solo_shield_turns = int(_solo_def.shield_turns)
			if float(enemy.hp) > float(enemy.max_hp) * 0.5:
				_solo_shield_high = true
			else:
				_solo_shield_low = true
		, {"ability_id": "Shield", "category": "shield"})
	else:
		var ratio := float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
		var fury := float(_solo_def.fury_mult) if intent == "FURY STRIKE" and _solo_fury_pending else (1.0 if ratio > 0.7 else 1.2 if ratio > 0.4 else 1.4 if ratio > 0.15 else 1.6)
		if intent == "FURY STRIKE":
			_solo_fury_pending = false
		elif _solo_has_minions():
			fury *= 0.5
		_append_combat_log("%s: %s at %s power, 90%% base accuracy." % [enemy.name, intent, Stats.percent(float(fury))], {"ability_id": "Fury" if intent == "FURY STRIKE" else "Strike", "category": "damage"})
		_attack_entity(enemy, player, fury, 0.9, true)
	await _flush_steps()

func _solo_player_action(action: Dictionary) -> void:
	var target := _solo_target()
	var was_protected := _solo_has_minions()
	var target_was_alive := int(target.get("hp", 0)) > 0
	await _resolve_spell_action(player, target, action)
	if player.hp > 0 and (target.hp > 0 or action.get("hom", "hold") == "sacrifice"):
		await _resolve_hom_choice(player, target, str(action.get("hom", "hold")))
	if was_protected and target_was_alive and int(target.get("hp", 0)) <= 0:
		_append_combat_log("%s defeated." % str(target.get("name", "Minion")), {"ability_id": "Summon", "category": "damage"})
	if was_protected and not _solo_has_minions():
		_append_combat_log("Boss exposed - protection broken.", {"ability_id": "Summon", "category": "advantage"})

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
		_apply_pending_drains()
		await _flush_steps()
		if _combat_session_invalid: return
		_apply_spell_poison(player)
		_apply_spell_poison(enemy)
		for minion in _solo_minions:
			if minion.hp > 0:
				_apply_spell_poison(minion)
		await _flush_steps()
		_apply_spell_poison(player)
		_apply_spell_poison(enemy)
		for minion in _solo_minions: _apply_spell_poison(minion)
		await _flush_steps()
	_charge_homunculus(player)
	await _flush_steps()
	_end_spell_exchange()
	if _solo_power_active:
		_solo_power_active = false
		if enemy.hp > 0 and player.hp > 0:
			_solo_fury_pending = true
			_log_immediate("FURY PENDING: %s power on the boss's next strike." % Stats.percent(float(_solo_def.fury_mult)))
	if shield_active_at_start and _solo_shield_turns > 0:
		_solo_shield_turns -= 1
		if _solo_shield_turns == 0:
			_solo_shield_cooldown = 3
			_append_combat_log("Alchemical Shield expired; cooldown: 3 exchanges.", {"ability_id": "Shield", "category": "shield"})
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
	if hom.is_empty() and _is_player and _trusted_expedition_hom(str(data.get("homunculus_id", ""))):
		hom = _online_homunculus(str(data.get("homunculus_id", ""))).duplicate(true)
		hom["buff_hp"] = 1
		hom["buff_atk"] = 1
		hom["buff_def"] = 1
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

	var result := {
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
		"tempo": float(ent.get("base_stats", {}).get("tempo", 10)),
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
	if hom.has("passive"):
		result["expedition_passive"] = ExpeditionPassive.create(hom, int(hom_progress.get(str(hom.id), {}).get("level", 0)))
	return result

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
	if not is_instance_valid(_ranked_controller) and not _solo_boss_mode:
		for pair in [[player_indicators, player], [enemy_indicators, enemy]]:
			var fighter: Dictionary = pair[1]
			var extra: Array = []
			if fighter.has("strategic_trap"):
				var trap: Dictionary = fighter.strategic_trap
				var remaining := maxi(0, int(trap.get("expires_turn", 0)) - _turn)
				extra.append({"icon":"trap", "label":"%dT" % remaining, "tooltip":tr("STATUS_TRAP_DETAIL") % [roundi(float(trap.get("value", 0)) * 100), remaining]})
			if fighter.has("strategic_heal_suppression"):
				var remaining := maxi(0, int(fighter.strategic_heal_suppression.get("expires_turn", 0)) - _turn)
				extra.append({"icon":"heal_block", "label":"%dT" % remaining, "tooltip":tr("STATUS_HEAL_SUPPRESSION_DETAIL") % remaining})
			for delayed in _strategic_delays:
				if is_same(delayed.target, fighter): extra.append({"icon":"hourglass", "label":str(delayed.amount), "tooltip":tr("STATUS_DELAYED_DETAIL") % [int(delayed.amount), int(delayed.due_turn)]})
			pair[0].set_extra_effects(extra)
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
	enemy_entity.flip_h = true
	enemy_hom.flip_h = true
	player_entity.flip_h = false
	player_hom.flip_h = false
	enemy_hom.texture = _load_preview_tex(enemy.get("hom_id", ""), "homunculus", enemy.get("hom_name", ""))
	if _solo_boss_mode:
		enemy_entity.texture = _solo_texture
		enemy_entity.flip_h = false
		enemy_name.text = "BOSS - %s" % str(_solo_def.get("tier", "")).to_upper()
		turn_label.text = "Boss Hunt\nTurn %d" % _display_turn()
		enemy_indicators.visible = not _battle_over
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
	if field == "shield_pct":
		fighter.erase("spell_ward")
		fighter.erase("spell_ward_baseline")

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
	hom_decision.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_setup_hom_action_outlines()
	hom_decision.visibility_changed.connect(func():
		if hom_decision.visible:
			_set_hom_action_outline_active(true)
			call_deferred("_position_hom_decision")
		else:
			_set_hom_action_outline_active(false)
			if _decision_spacer_before >= 0.0:
				$PlayerPanel/PlayerBottomSpacer.custom_minimum_size.y = _decision_spacer_before
				$PlayerPanel.grow_vertical = _decision_growth_before
				_decision_spacer_before = -1.0
	)
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

func _setup_hom_action_outlines() -> void:
	for button in [hom_decision.get_node("Hold"), hom_decision.get_node("Attack"), hom_decision.get_node("Sacrifice")]:
		var outline := Panel.new()
		outline.name = "ActionHighlight"
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = Color("ffe329")
		style.set_border_width_all(3)
		style.set_corner_radius_all(4)
		outline.add_theme_stylebox_override("panel", style)
		button.add_child(outline)
		outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hom_action_outlines.append(outline)

func _set_hom_action_outline_active(active: bool) -> void:
	if _hom_outline_tween != null and _hom_outline_tween.is_valid():
		_hom_outline_tween.kill()
	if not active:
		return
	_hom_outline_tween = create_tween().set_loops()
	_hom_outline_tween.set_parallel(true)
	for outline in _hom_action_outlines:
		outline.modulate.a = 1.0
		_hom_outline_tween.tween_property(outline, "modulate:a", 0.2, 0.55)
	_hom_outline_tween.chain().tween_property(_hom_action_outlines[0], "modulate:a", 1.0, 0.55)
	for i in range(1, _hom_action_outlines.size()):
		_hom_outline_tween.parallel().tween_property(_hom_action_outlines[i], "modulate:a", 1.0, 0.55)

func _layout_android_combat() -> void:
	var panel_min := spell_panel.get_combined_minimum_size()
	var width := minf(size.x - 360.0, maxf(size.x * 0.36, panel_min.x))
	spell_panel.offset_left = -width / 2.0
	spell_panel.offset_right = width / 2.0
	spell_panel.offset_top = 64.0
	spell_panel.offset_bottom = 64.0 + maxf(165.0, panel_min.y)
	var action_y := spell_panel.offset_bottom + 12.0
	var action_width := width / 8.0
	for entry in [[switch_weapon_btn, 0], [ultra_button, 1]]:
		var button: Control = entry[0]
		var actual_width := maxf(action_width, button.get_combined_minimum_size().x)
		button.offset_left = -actual_width / 2.0
		button.offset_right = actual_width / 2.0
		button.offset_top = action_y + int(entry[1]) * (maxf(60.0, switch_weapon_btn.get_combined_minimum_size().y) + 8.0)
		button.offset_bottom = button.offset_top + maxf(60.0, button.get_combined_minimum_size().y)
	if back_button:
		var safe := Rect2(Vector2.ZERO, size)
		var physical_safe := DisplayServer.get_display_safe_area()
		if physical_safe.size.x > 0 and physical_safe.size.y > 0:
			var to_local := get_global_transform_with_canvas().affine_inverse() * get_viewport().get_screen_transform().affine_inverse()
			var start := to_local * Vector2(physical_safe.position)
			var end := to_local * Vector2(physical_safe.end)
			safe = Rect2(start, end - start).intersection(Rect2(Vector2.ZERO, size))
		if safe.size.x < 160.0 or safe.size.y < 72.0:
			safe = Rect2(Vector2.ZERO, size)
		back_button.custom_minimum_size = Vector2(240, 105)
		back_button.position = Vector2(safe.end.x - 290.0, safe.position.y + 44.0)
		back_button.size = Vector2(240, 105)
		back_button.z_index = 250
		_raise_android_back.call_deferred()
	$LogBG.offset_left = -370.0
	$LogBG.offset_right = 370.0
	$LogBG.offset_top = -380.0
	$Log.offset_left = -356.0
	$Log.offset_right = 356.0
	$Log.offset_top = -366.0
	$Log.add_theme_font_size_override("normal_font_size", 24)
	turn_label.offset_left = -220
	turn_label.offset_right = 220
	turn_label.offset_top = -435
	turn_label.offset_bottom = -390
	if hom_decision.visible:
		_position_hom_decision()

func _keep_android_back_on_top(node: Node) -> void:
	if node is Control and node != back_button:
		_raise_android_back.call_deferred()

func _raise_android_back() -> void:
	if is_instance_valid(back_button) and back_button.get_parent() == self:
		move_child(back_button, get_child_count() - 1)

func _position_hom_decision() -> void:
	if OS.has_feature("android"):
		for button in hom_decision.get_children():
			if button is Button:
				button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 60.0)
		var android_minimum := hom_decision.get_combined_minimum_size()
		hom_decision.set_anchors_preset(Control.PRESET_TOP_LEFT)
		hom_decision.size = Vector2(maxf(260.0, android_minimum.x), android_minimum.y)
		hom_decision.position = Vector2(16.0, clampf(size.y - hom_decision.size.y - 100.0, 340.0, size.y - hom_decision.size.y - 16.0))
		return
	var minimum := hom_decision.get_combined_minimum_size()
	hom_decision.size = Vector2(maxf(_player_hom_status.size.x, minimum.x), minimum.y)
	var x := _player_hom_status.position.x + (_player_hom_status.size.x - hom_decision.size.x) / 2.0
	hom_decision.position = Vector2(clampf(x, 0.0, size.x - hom_decision.size.x), _player_hom_status.position.y - hom_decision.size.y - 8.0)
	if player_hom.is_visible_in_tree() and hom_decision.get_global_rect().intersects(player_hom.get_global_rect()):
		hom_decision.position.y = _player_hom_status.position.y + _player_hom_status.size.y + 8.0
		var decision_rect := hom_decision.get_global_rect()
		var title_rect: Rect2 = $PlayerPanel/PlayerBuildTitle.get_global_rect()
		var items_rect: Rect2 = $PlayerPanel/PlayerItems.get_global_rect()
		if decision_rect.intersects(title_rect) or decision_rect.intersects(items_rect):
			var spacer := $PlayerPanel/PlayerBottomSpacer
			_decision_spacer_before = spacer.custom_minimum_size.y
			_decision_growth_before = $PlayerPanel.grow_vertical
			$PlayerPanel.grow_vertical = Control.GROW_DIRECTION_END
			spacer.custom_minimum_size.y = spacer.size.y + (decision_rect.end.y - minf(title_rect.position.y, items_rect.position.y) + 8.0) / get_global_transform_with_canvas().get_scale().y

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
		var strip := Control.new()
		strip.name = "StatusStrip"
		strip.position = Vector2(-90, 52)
		strip.size = Vector2(600, 64)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(strip)
		var indicators: Control = player_indicators if pair[1] == player_hp else enemy_indicators
		var crowns: Control = preload("res://scripts/ui/combat_status_icons.gd").new()
		crowns.set("victory_only", true)
		crowns.position = Vector2(0, 46)
		group.add_child(crowns)
		indicators.set("victory_markers", crowns)
		indicators.reparent(strip, false)
		indicators.position = Vector2.ZERO
		indicators.mouse_filter = Control.MOUSE_FILTER_STOP
		indicators.call("_update_boss_height")
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
	# Place each strip at its side of the top edge, below the Back button.
	for group in [$PlayerHealthGroup, $EnemyHealthGroup]:
		var strip: Control = group.get_node("StatusStrip")
		var x := 20.0 if group == $PlayerHealthGroup else size.x - strip.size.x - 20.0
		strip.position = Vector2(x, 55.0) - group.position

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
	if OS.has_feature("android"):
		_inspiration_panel.resized.connect(_center_android_inspiration, CONNECT_DEFERRED)
		resized.connect(_center_android_inspiration, CONNECT_DEFERRED)
		_compact_inspiration.call_deferred()
	_inspiration_panel.hide()

func _compact_inspiration() -> void:
	if not is_instance_valid(_inspiration_panel):
		return
	_inspiration_panel.custom_minimum_size = Vector2(1100, 600)
	_inspiration_panel.size = Vector2(size.x * 0.8, size.y * 0.78)
	var content := _inspiration_panel.get_node("Content") as VBoxContainer
	content.get_child(0).add_theme_font_size_override("font_size", 36)
	content.get_child(1).add_theme_font_size_override("font_size", 28)
	for button in _inspiration_cards:
		button.custom_minimum_size = Vector2(280, 340)
		button.add_theme_font_size_override("font_size", 28)
	var cancel := content.get_node("Cancel") as Button
	cancel.custom_minimum_size = Vector2(180, 54)
	cancel.add_theme_font_size_override("font_size", 32)
	_center_android_inspiration.call_deferred()

func _center_android_inspiration() -> void:
	if is_instance_valid(_inspiration_panel):
		_inspiration_panel.position = (size - _inspiration_panel.size) / 2.0

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
	for spell in _reg.get_spells_for_type(element) + _reg.get_spells_for_type("universal") + _reg.get_spells_for_type("hybrid"):
		if (spell.get("type") == element or (spell.get("type") in ["universal", "hybrid"] and element in spell.get("eligible_types", []))) and spell.id not in fighter.get("spell_ids", []):
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
	if _spectator_readonly: return
	if _ranked_controller:
		_ranked_controller.choose_inspiration(index)
		return
	if _dungeon_guard:
		if index >= 0 and index < _inspiration_options.size():
			_send_dungeon_inspiration({"kind": "choose", "spell_id": str(_inspiration_options[index].get("id", ""))})
		return
	if _online_hunt_guard:
		if index >= 0 and index < _inspiration_options.size():
			_send_online_inspiration({"kind": "choose", "spell_id": str(_inspiration_options[index].get("id", ""))})
		return
	if not _inspiration_panel.visible or index < 0 or index >= _inspiration_options.size() or not bool(player.get("inspiration_pending", false)):
		return
	var choice: Dictionary = _inspiration_options[index]
	_inspiration_panel.hide()
	_inspiration_options.clear()
	_replace_inspiration_spell(player, choice)
	_update_ui()
	_refresh_spell_buttons()

func _on_inspiration_cancel() -> void:
	if _spectator_readonly: return
	if _ranked_controller:
		_ranked_controller.decline_inspiration()
		return
	if _dungeon_guard:
		_send_dungeon_inspiration({"kind": "decline"})
		return
	if _online_hunt_guard:
		_send_online_inspiration({"kind": "decline"})
		return
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
	_fire_expedition_passive(fighter, enemy if is_same(fighter, player) else player, "inspiration_activated")
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
	plaque.texture = load("res://assets/ui/new-elements/betterui/boton_largo.png")
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

func _set_localized_spell_button(button: Button, spell: Dictionary, fallback_name: String, power: float, accuracy: float, cooldown: int) -> void:
	button.set_meta("localized_spell", {"spell": spell, "name": fallback_name, "power": power, "accuracy": accuracy, "cooldown": cooldown})
	_refresh_localized_spell_button(button)

func _refresh_localized_spell_button(button: Button) -> void:
	var data: Dictionary = button.get_meta("localized_spell", {})
	if data.is_empty():
		return
	var spell: Dictionary = data.spell
	var power := tr("SPELL_SUPPORT") if is_zero_approx(float(data.power)) else Stats.percent(float(data.power))
	var cd := int(data.cooldown)
	button.text = "%s\n%s  |  %d%%%s" % [GameLocalization.catalog("spell", str(spell.get("id", "")), "name", str(data.name)), power, roundi(float(data.accuracy) * 100), "  |  CD: %d" % cd if cd > 0 else ""]
	button.tooltip_text = _spell_description(spell) if not spell.is_empty() else ""

func _set_next_turn_action(action: String) -> void:
	_next_turn_action = action
	var keys := {"retry": "COMBAT_RETRY", "next_floor": "COMBAT_NEXT_FLOOR", "return": "COMBAT_RETURN", "recover": "COMBAT_RECOVER", "return_zone": "COMBAT_RETURN_ZONE", "return_gate": "COMBAT_RETURN_GATE", "return_loadout": "COMBAT_RETURN_LOADOUT"}
	next_turn_btn.text = tr(keys.get(action, action))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		for button in spell_buttons:
			if is_instance_valid(button) and button.has_meta("localized_spell"):
				_refresh_localized_spell_button(button)
		if not _next_turn_action.is_empty():
			_set_next_turn_action(_next_turn_action)
		if is_instance_valid(_physical_anomaly_label) and _physical_anomaly_label.has_meta("active_anomaly"):
			_render_physical_anomaly(_physical_anomaly_label.get_meta("active_anomaly"))
		if is_instance_valid(_dungeon_floor_label) and _dungeon_floor_label.has_meta("localized_floor"):
			var old_prefix := str(_dungeon_floor_label.get_meta("localized_prefix", ""))
			var suffix := _dungeon_floor_label.text.trim_prefix(old_prefix)
			var prefix := tr("DUNGEON_FLOOR_TITLE") % int(_dungeon_floor_label.get_meta("localized_floor"))
			_dungeon_floor_label.text = prefix + suffix
			_dungeon_floor_label.set_meta("localized_prefix", prefix)
		if is_instance_valid(turn_label) and turn_label.has_meta("localized_cleared") and _dungeon_guard and turn_label.text == str(turn_label.get_meta("localized_cleared_text", "")):
			turn_label.text = tr("DUNGEON_CLEARED_COUNT") % int(turn_label.get_meta("localized_cleared"))
			turn_label.set_meta("localized_cleared_text", turn_label.text)

func _on_next_turn() -> void:
	if _spectator_readonly:
		SceneRouter.finish_spectating()
		return
	if _ranked_controller:
		_ranked_controller.return_to_loadout()
		return
	if _dungeon_guard:
		if _next_turn_action == "retry":
			if not _dungeon_pending.is_empty():
				_dungeon_send_pending()
			else:
				_dungeon_recover()
		elif _next_turn_action == "next_floor" and _dungeon_synchronized and _dungeon_pending.is_empty() and _dungeon_request.is_empty() and _combat_backend._verified_player_id == _dungeon_identity:
			_dungeon_pending = {"kind": "next", "payload": {"run_id": str(SceneRouter._dungeon_context.get("run_id", "")), "client_action_id": _combat_backend._make_uuid(), "expected_revision": int(_dungeon_session.get("combat_revision", 0))}}
			SceneRouter._dungeon_context["pending_action"] = _dungeon_pending.duplicate(true)
			_dungeon_send_pending()
		elif _next_turn_action == "return":
			SceneRouter.return_from_dungeon()
		return
	if _online_hunt_guard:
		if not _online_turn_payload.is_empty():
			if not _online_identity_invalid and _online_hunt_request.is_empty() and _online_turn_request.is_empty():
				next_turn_btn.hide()
				_on_online_hunt_identity({"player_id": _combat_identity})
			return
		if _next_turn_action == "retry" and _combat_backend != null and _combat_backend._verified_player_id == _combat_identity and not _combat_identity.is_empty():
			next_turn_btn.hide()
			_on_online_hunt_identity({"player_id": _combat_identity})
		else:
			_online_hunt_exit(false)
		return
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

func _input(event: InputEvent) -> void:
	if not OS.has_feature("android"):
		return
	if event is InputEventScreenDrag and event.index == _spell_hold_index and event.relative.length() > 8.0:
		_spell_hold_token += 1
		_spell_hold_index = -1
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _spell_hold_open:
				_spell_hold_open = false
				if is_instance_valid(_spell_hold_overlay):
					_spell_hold_overlay.queue_free()
				get_viewport().set_input_as_handled()
				return
			for button in spell_buttons:
				if button.is_visible_in_tree() and button.get_global_rect().has_point(event.position):
					_spell_hold_index = event.index
					_spell_hold_token += 1
					_show_spell_on_hold(button, _spell_hold_token)
					break
		elif event.index == _spell_hold_index:
			_spell_hold_token += 1
			_spell_hold_index = -1
			if _spell_hold_open:
				get_viewport().set_input_as_handled()

func _show_spell_on_hold(button: Button, token: int) -> void:
	await get_tree().create_timer(0.55).timeout
	if token != _spell_hold_token or not is_instance_valid(button) or not button.is_visible_in_tree():
		return
	var data: Dictionary = button.get_meta("localized_spell", {})
	var spell: Dictionary = data.get("spell", {})
	if spell.is_empty():
		return
	_spell_hold_open = true
	_spell_hold_overlay = Control.new()
	_spell_hold_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spell_hold_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_spell_hold_overlay.z_index = 300
	add_child(_spell_hold_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_hold_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_hold_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 300)
	center.add_child(panel)
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = GameLocalization.catalog("spell", str(spell.get("id", "")), "name", str(data.get("name", ""))) + "\n\n" + _spell_description(spell)
	description.add_theme_font_size_override("font_size", 24)
	panel.add_child(description)

func _on_spell_chosen(index: int) -> void:
	if _spell_hold_open:
		return
	if _spectator_readonly: return
	if _ranked_controller:
		_ranked_controller.spell(index)
		return
	if _dungeon_guard:
		if index < 0 or index >= spell_buttons.size() or spell_buttons[index].disabled or not _dungeon_request.is_empty() or not _dungeon_pending.is_empty() or not _dungeon_hom_choice.is_empty():
			return
		var state: Dictionary = _dungeon_session.get("combat_state", {})
		var p: Dictionary = state.get("player", {})
		var ids: Array = p.get("spell_ids", [])
		if index >= ids.size(): return
		var payload := {"run_id": str(SceneRouter._dungeon_context.get("run_id", "")), "client_action_id": _combat_backend._make_uuid(), "expected_revision": int(_dungeon_session.get("combat_revision", 0)), "decision": {"turn": int(state.get("turn", 0)) + 1, "spell_id": str(ids[index]), "hom_action": "hold"}}
		if p.get("hom_id") != null and not str(p.get("hom_id", "")).is_empty() and int(p.get("hom_energy", 0)) >= 3:
			_dungeon_hom_choice = payload
			hom_decision.show()
			$HomDecision/Sacrifice.hide()
			_dungeon_refresh_controls()
		else:
			_dungeon_pending = {"kind": "turn", "payload": payload}
			SceneRouter._dungeon_context["pending_action"] = _dungeon_pending.duplicate(true)
			_dungeon_send_pending()
		return
	if _online_hunt_guard:
		var decision := _online_spell_decision(index)
		if decision.is_empty() or not _online_turn_request.is_empty():
			return
		var payload := {"session_id": str(_solo_context.get("session_id", "")), "client_action_id": _combat_backend._make_uuid(), "expected_revision": _online_hunt_revision, "decision": decision}
		var hom: Dictionary = _online_hunt_session.get("combat_state", {}).get("player", {})
		if hom.get("homunculus_id") != null and not str(hom.get("homunculus_id", "")).is_empty() and not bool(hom.get("homunculus_spent", false)) and int(hom.get("homunculus_energy", 0)) >= 3:
			_online_hom_payload = payload
			_refresh_online_spell_buttons()
			hom_decision.show()
			return
		_online_turn_payload = payload
		_refresh_online_spell_buttons()
		_send_online_pending_turn()
		return
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
	if _spectator_readonly: return
	_ultra_armed = armed and _ultra_available(player) and not _resolving_exchange and not _processing_steps and not _inspiration_panel.visible and _pending_hom_action.is_empty()
	if _ranked_controller and not _ranked_controller.can_submit():
		_ultra_armed = false
	_refresh_spell_buttons()
	if _ranked_controller:
		_ranked_controller.refresh_controls()

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
	if _spectator_readonly: return
	if _ranked_controller:
		_ranked_controller.switch_weapon()
		return
	if _dungeon_guard:
		if switch_weapon_btn.disabled or not _dungeon_request.is_empty() or not _dungeon_pending.is_empty() or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity:
			return
		var state: Dictionary = _dungeon_session.get("combat_state", {})
		var slot := 2 if int(state.get("active_weapon_slot", 0)) == 1 else 1
		_dungeon_pending = {"kind": "turn", "payload": {"run_id": str(SceneRouter._dungeon_context.get("run_id", "")), "client_action_id": _combat_backend._make_uuid(), "expected_revision": int(_dungeon_session.get("combat_revision", 0)), "decision": {"turn": int(state.get("turn", 0)) + 1, "switch_slot": slot}}}
		SceneRouter._dungeon_context["pending_action"] = _dungeon_pending.duplicate(true)
		_dungeon_send_pending()
		return
	if _online_hunt_guard:
		var decision := _online_switch_decision()
		if decision.is_empty():
			return
		_online_turn_payload = {"session_id": str(_solo_context.get("session_id", "")), "client_action_id": _combat_backend._make_uuid(), "expected_revision": _online_hunt_revision, "decision": decision}
		_refresh_online_spell_buttons()
		_send_online_pending_turn()
		return
	if _resolving_exchange or _processing_steps or _battle_over or not _solo_forfeit_request.is_empty() or not _combat_started or _inspiration_panel.visible:
		return
	var slot := 2 if int(player.get("active_weapon_slot", 1)) == 1 else 1
	if player.get("equip_%d" % slot, {}).is_empty():
		return
	await _queue_combat_action({"kind": "switch", "slot": slot})

func _hom_ready(fighter: Dictionary) -> bool:
	return not bool(fighter.get("hom_spent", true)) and int(fighter.get("hom_energy", 0)) >= int(fighter.get("hom_ready_at", 3))

func _queue_combat_action(action: Dictionary) -> void:
	if _spectator_readonly: return
	if _online_hunt_guard:
		return
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
	if _spectator_readonly: return
	if _ranked_controller:
		_ranked_controller.hom_choice(choice)
		return
	if _dungeon_guard:
		if choice not in ["hold", "attack"] or _dungeon_hom_choice.is_empty() or _combat_backend == null or _combat_backend._verified_player_id != _dungeon_identity:
			return
		_dungeon_hom_choice.decision.hom_action = choice
		_dungeon_pending = {"kind": "turn", "payload": _dungeon_hom_choice.duplicate(true)}
		_dungeon_hom_choice.clear()
		hom_decision.hide()
		SceneRouter._dungeon_context["pending_action"] = _dungeon_pending.duplicate(true)
		_dungeon_send_pending()
		return
	if _online_hunt_guard:
		if choice not in ["hold", "attack", "sacrifice"] or _online_hom_payload.is_empty() or _online_identity_invalid or _combat_backend == null or _combat_backend._verified_player_id != _combat_identity or _combat_identity.is_empty() or _combat_backend.token.is_empty() or int(_online_hom_payload.get("expected_revision", -1)) != _online_hunt_revision or str(_online_hunt_session.get("status", "")) != "ACTIVE" or not _online_hunt_request.is_empty() or not _online_turn_request.is_empty():
			return
		_online_turn_payload = _online_hom_payload.duplicate(true)
		_online_hom_payload.clear()
		_online_turn_payload.decision.hom_action = choice
		hom_decision.hide()
		_refresh_online_spell_buttons()
		_send_online_pending_turn()
		return
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
	_preinitiative_passive(player, enemy, chosen)
	_preinitiative_passive(enemy, player, npc_spell)
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
		_apply_pending_drains()
		await _flush_steps()
		if _combat_session_invalid: return
		_apply_spell_poison(player)
		_apply_spell_poison(enemy)
		await _flush_steps()
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
				_fire_expedition_passive(caster, target, "weapon_switched")
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
				var healed := mini(_strategic_heal(fighter, 30), int(fighter.max_hp) - int(fighter.hp))
				fighter.hp = mini(int(fighter.max_hp), int(fighter.hp) + healed)
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
	if fighter.status.poison > 0 and int(fighter.get("poison_last_tick", -1)) != _turn:
		_log_step("", func():
			if int(fighter.hp) <= 0: return
			fighter.poison_last_tick = _turn
			var poison: Dictionary = fighter.get("poison_effect", {"stage": 0, "applied_exchange": _turn})
			var stage := clampi(int(poison.get("stage", 0)), 0, 2)
			var tick := maxi(1, roundi(float(fighter.max_hp) * [0.025, 0.05, 0.06][stage]))
			poison.stage = stage + 1
			fighter.poison_effect = poison
			var actual := mini(int(fighter.hp), tick)
			var source := str(fighter.get("poison_source", ""))
			_record_highlight("damage", actual, "%s: poison" % fighter.name)
			fighter.status.poison -= 1
			fighter.hp = max(0, fighter.hp - actual)
			fighter.spell_hit_this_exchange = true
			var other := enemy if is_same(fighter, player) else player
			var valid_source := source == ("enemy" if is_same(fighter, player) else "player")
			if is_same(fighter, player) and source not in ["", "enemy", "player"]:
				for minion in _solo_minions:
					if str(minion.get("id", "")) == source: other = minion; valid_source = true; break
			if valid_source and actual > 0:
				_fire_expedition_passive(other, fighter, "opponent_poison_damage", {}, actual)
				_fire_expedition_passive(fighter, other, "damage_received")
			if int(fighter.status.poison) <= 0:
				fighter.erase("poison_source")
				fighter.erase("poison_effect")
			_append_combat_log("%s suffers %d poison damage." % [fighter.name, actual], {"category":"debuff"})
		)

func _apply_pending_drains() -> void:
	for pending in _pending_drains.duplicate():
		if int(pending.due_turn) > _turn: continue
		_pending_drains.erase(pending)
		var caster: Dictionary = pending.caster
		var target: Dictionary = pending.target
		target.erase("pending_drain")
		_log_step("", func():
			if int(caster.hp) <= 0 or int(target.hp) <= 0 or (_solo_boss_mode and is_same(target, enemy) and _solo_has_minions()): return
			var shield := _timed_defense(target, "shield_pct")
			var amount := roundi(roundi(float(target.hp) * 0.06) * (1.0 - clampf(shield, 0.0, 1.0)) * clampf(float(_hom_synergy(target).get("incoming_mult", 1.0)), 0.1, 1.0))
			var boss_prevented := 0
			if _solo_boss_mode and is_same(target, enemy) and _solo_shield_turns > 0 and not _persistent_active(target, "burn"):
				var reduced := roundi(amount * (1.0 - float(_solo_def.shield_reduction)))
				boss_prevented = amount - reduced
				amount = reduced
			amount = mini(int(target.hp), amount)
			var healed := _strategic_heal(caster, mini(amount, int(caster.max_hp) - int(caster.hp)))
			if shield > 0.0 and float(target.status.get("shield_pct", 0.0)) > 0.0: _clear_defense(target, "shield_pct")
			target.hp -= amount
			caster.hp += healed
			if boss_prevented > 0 and int(target.hp) > 0: target.hp = mini(int(target.max_hp), int(target.hp) + _strategic_heal(target, floori(boss_prevented * float(_solo_def.shield_heal_ratio))))
			if amount > 0: target.spell_hit_this_exchange = true; _fire_expedition_passive(target, caster, "damage_received")
			_append_combat_log("%s drains %d HP from %s and restores %d HP." % [caster.name, amount, target.name, healed])
			var reflect := _timed_defense(target, "reflect_pct")
			if amount > 0 and reflect > 0.0:
				var ignored := _try_ignore_reflect(caster)
				var reflected := 0 if ignored else mini(int(caster.hp), roundi(amount * reflect))
				caster.hp -= reflected
				if reflected > 0: _fire_expedition_passive(caster, target, "damage_received")
				if float(target.status.get("reflect_pct", 0.0)) > 0.0: _clear_defense(target, "reflect_pct")
				if not ignored and int(target.status.get("poison_on_reflect", 0)) > 0:
					var previous := int(caster.status.poison)
					caster.status.poison = maxi(previous, int(target.status.poison_on_reflect))
					_record_poison_source(caster, previous, target)
					if previous <= 0: caster.poison_source = str(target.get("poison_reflect_source", ""))
				target.status.erase("poison_on_reflect")
				target.erase("poison_reflect_source")
		)

func _refresh_spell_buttons() -> void:
	var options := _fighter_spell_options(player)
	spell_panel.visible = not _battle_over
	var alternative := 2 if int(player.get("active_weapon_slot", 1)) == 1 else 1
	var weapon: Dictionary = player.get("equip_%d" % alternative, {})
	switch_weapon_btn.visible = _combat_started and not _battle_over and not weapon.is_empty()
	switch_weapon_btn.disabled = _resolving_exchange or _processing_steps or _battle_over or _inspiration_panel.visible or not _pending_hom_action.is_empty()
	switch_weapon_btn.text = ("Switch to:\n%s" if OS.has_feature("android") else "Switch to: %s") % _item_label(weapon)
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
		_set_localized_spell_button(button, spell, str(spell.name), float(spell.power_mult), float(spell.accuracy), cd)
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
		fighter.combat_exchange = _turn
		fighter.vitriol_corrosion_used = 0
		fighter.spell_hit_last_exchange = fighter.get("spell_hit_this_exchange", false)
		fighter.spell_hit_this_exchange = false
		fighter.spell_neutralize_active = fighter.get("spell_neutralize_pending", 0.0)
		fighter.spell_neutralize_pending = 0.0
		if fighter.has("expedition_passive"):
			ExpeditionPassive.begin_exchange(fighter.expedition_passive)
	for pair in [[player, enemy], [enemy, player]]:
		_fire_expedition_passive(pair[0], pair[1], "before_exchange")

func _end_spell_exchange() -> void:
	_spell_exchange_active = false
	for fighter in [player, enemy]:
		if fighter.has("expedition_passive"):
			ExpeditionPassive.finish_exchange(fighter.expedition_passive)
	for entry in _strategic_delays.duplicate():
		if int(entry.due_turn) <= _turn:
			var target: Dictionary = entry.target
			if int(target.get("hp", 0)) > 0:
				var damage := mini(int(target.hp), int(entry.amount))
				target.hp -= damage
				_append_combat_log("%s takes %d delayed damage." % [target.name, damage])
			_strategic_delays.erase(entry)
	for target in _strategic_jams:
		_strategic_jam(target)
	_strategic_jams.clear()
	for fighter in [player, enemy] + _solo_minions:
		for field in ["strategic_trap", "strategic_heal_suppression"]:
			if fighter.get(field, {}).get("expires_turn", _turn + 1) <= _turn:
				fighter.erase(field)
		for field in ["burn_effect", "lethargy_effect"]:
			if fighter.get(field, {}).get("expires_exchange", _turn + 1) <= _turn:
				fighter.erase(field)
	if not _physical_anomaly.is_empty() and int(_physical_anomaly.get("activated_exchange", 0)) < _turn:
		_physical_anomaly.remaining_exchanges = int(_physical_anomaly.remaining_exchanges) - 1
		if int(_physical_anomaly.remaining_exchanges) <= 0:
			_physical_anomaly.clear()
		_show_physical_anomaly(_physical_anomaly)
	for fighter in [player, enemy]:
		fighter.spell_neutralize_active = 0.0
		var defenses: Dictionary = fighter.get("timed_defenses", {})
		for field in defenses.keys():
			if int(defenses[field].expires_turn) <= _turn or int(player.hp) <= 0 or int(enemy.hp) <= 0: defenses.erase(field)
		if defenses.is_empty(): fighter.erase("timed_defenses")

func _timed_defense(fighter: Dictionary, field: String) -> float:
	if _persistent_active(fighter, "burn"): return 0.0
	return maxf(float(fighter.status.get(field, 0.0)), float(fighter.get("timed_defenses", {}).get(field, {}).get("value", 0.0)))

func _persistent_active(fighter: Dictionary, kind: String) -> bool:
	var effect: Dictionary = fighter.get(kind + "_effect", {})
	return not effect.is_empty() and int(effect.get("applied_exchange", _turn)) < _turn and _turn <= int(effect.get("expires_exchange", -1))

func _strategic_heal(fighter: Dictionary, amount: int) -> int:
	return floori(amount * 0.5) if fighter.has("strategic_heal_suppression") else amount

func _strategic_jam(target: Dictionary) -> void:
	var options := _fighter_spell_options(target).filter(func(s): return int(s.get("cooldown_turns", 0)) > 0)
	if _solo_boss_mode and is_same(target, enemy):
		options = [_solo_signature] if int(_solo_signature.get("cooldown_turns", 0)) > 0 else []
	options.sort_custom(func(a, b): return str(a.id) < str(b.id) if float(a.power_mult) == float(b.power_mult) else float(a.power_mult) > float(b.power_mult))
	if not options.is_empty():
		var id := str(options[0].id)
		var old := int(target.spell_cooldowns.get(id, 0))
		target.spell_cooldowns[id] = mini(4, old + 1) if old < 4 else old

func _strategic_transfer(kind: String, caster: Dictionary, target: Dictionary) -> void:
	var source := caster if kind == "debuff_transfer" else target
	var destination := target if kind == "debuff_transfer" else caster
	var fields := ["poison", "vuln_pct", "atk_down"] if kind == "debuff_transfer" else ["atk_boost", "shield_pct", "reflect_pct"]
	for field in fields:
		var previous := float(source.status.get(field, 0.0))
		if previous <= 0.0:
			continue
		var value := previous if kind == "debuff_transfer" else minf(0.2, previous * 0.5)
		if field in ["shield_pct", "reflect_pct"]:
			_clear_defense(source, field)
			_other_defense(destination, field, value)
		else:
			var destination_before := int(destination.status.get(field, 0))
			var poison_effect: Dictionary = source.get("poison_effect", {}).duplicate(true) if field == "poison" else {}
			var poison_source := str(source.get("poison_source", "")) if field == "poison" else ""
			source.status[field] = 0
			destination.status[field] = maxf(float(destination.status.get(field, 0.0)), value)
			if field == "poison":
				source.erase("poison_source")
				source.erase("poison_effect")
				if destination_before > 0:
					destination.status.poison = destination_before
				else:
					destination.poison_effect = poison_effect
					destination.poison_source = poison_source
		_append_combat_log("%s transfers %s." % [caster.name, str(field).replace("_", " ")])
		return
	if kind == "debuff_transfer":
		for field in ["burn_effect", "lethargy_effect"]:
			if source.has(field):
				if not destination.has(field): destination[field] = source[field].duplicate(true)
				source.erase(field)
				return

func _strategic_counter(defender: Dictionary, attacker: Dictionary, damage: int) -> void:
	var trap: Dictionary = defender.get("strategic_trap", {})
	if trap.is_empty() or _turn <= int(trap.activated_turn) or _turn > int(trap.expires_turn) or damage <= 0:
		return
	defender.erase("strategic_trap")
	var amount := mini(int(attacker.hp), mini(floori(float(attacker.max_hp) * 0.2), floori(damage * float(trap.value))))
	attacker.hp -= amount
	_append_combat_log("%s's counter trap deals %d damage." % [defender.name, amount])

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
	var attack_context := {"spell": spell, "actual_damage": 0, "direct_damage": 0, "pierce": 0.0, "dispel": 0.0, "ultra": ultra_active}
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
		elif effect.kind == "bonus_if_shielded" and _timed_defense(caster, "shield_pct") > 0.0:
			power += float(effect.value)
		elif effect.kind == "bonus_power_if_hit_last_exchange" and caster.get("spell_hit_last_exchange", false):
			power += float(effect.value)
		elif effect.kind == "pierce_ward":
			attack_context.pierce = float(effect.value)
		elif effect.kind == "ward_dispel":
			attack_context.dispel = float(effect.value)
	var hit := false
	if spell.get("category") == "attack" and power > 0.0:
		_fire_expedition_passive(caster, target, "before_attack", spell)
		hit = _attack_entity(caster, target, power, float(spell.get("accuracy", 1.0)), true, attack_context, accuracy_focus, accuracy_misalign)
		_log_step("", func():
			if caster.has("expedition_passive") and not bool(caster.get("hom_spent", true)):
				ExpeditionPassive.finish_attack(caster.expedition_passive, hit)
				if not hit:
					_fire_expedition_passive(caster, target, "spell_miss")
		)
	else:
		hit = randf() < clampf(float(spell.get("accuracy", 1.0)) + float(_passive_modifiers(caster).get("accuracy_pct", 0.0)) - (0.15 if _persistent_active(caster, "lethargy") else 0.0), 0.0, 1.0)
		_log_step("%s's spell %s." % [caster.name, "succeeds" if hit else "misses"], func():
			if not hit:
				_fire_expedition_passive(caster, target, "spell_miss")
		, _combat_event(caster, "buff" if hit else "miss", "'s spell %s." % ("succeeds" if hit else "misses"), {}))
	if not hit:
		return true
	if combo_poisoned:
		_log_step("%s exploits poison." % caster.name, Callable(), _combat_event(caster, "combo", " COMBO: exploits poison.", {}))
	if combo_retaliation:
		_log_step("%s retaliates for the previous exchange." % caster.name, Callable(), _combat_event(caster, "combo", " COMBO: retaliates for the previous exchange.", {}))
	if spell.get("type") == "hybrid" and marked:
		_log_step("%s consumes the hybrid mark." % caster.name, func(): target.status.erase("hybrid_mark"), _combat_event(caster, "combo", " consumes the hybrid mark.", {}))
	for effect in spell.get("effects", []):
		if effect.get("kind") == "ward_convert" and spell.get("category") == "attack":
			var conversion_value := float(effect.value)
			_log_step("%s converts a spell ward." % caster.name, func():
				var ward := float(caster.get("spell_ward", 0.0))
				if ward <= 0.0:
					return
				var baseline := float(caster.get("spell_ward_baseline", 0.0))
				caster.erase("spell_ward")
				caster.erase("spell_ward_baseline")
				caster.status.shield_pct = maxf(baseline, float(caster.get("weapon_shield_pct", 0.0)))
				if caster.has("weapon_shield_pct"):
					caster.other_shield_pct = baseline
				var amount := mini(int(target.hp), mini(floori(float(target.max_hp) * 0.2), floori(float(caster.max_hp) * ward * conversion_value)))
				target.hp -= amount
				_append_combat_log("Ward conversion deals %d damage." % amount)
			)
	for effect in spell.get("effects", []):
		var recipient: Dictionary = caster if effect.target == "self" else target
		var value := float(effect.value)
		var kind := str(effect.kind)
		if effect.has("chance") and randf() >= float(effect.chance): continue
		if ultra_active and kind in ["heal", "recoil", "atk_boost", "atk_down", "shield", "reflect", "vuln", "poison", "hom_stun", "focus_next", "misalign_next", "tempo_shift", "hybrid_mark", "type_neutralize", "poison_on_reflect"]:
			value *= 2.0
			if kind in ["atk_boost", "atk_down", "shield", "reflect", "vuln", "focus_next", "misalign_next", "type_neutralize"]:
				value = clampf(value, 0.0, 0.95 if kind in ["shield", "reflect"] else 1.0)
		match kind:
			"burn", "lethargy":
				_log_step("%s gains %s." % [recipient.name, kind], func():
					var key := kind + "_effect"
					if not recipient.has(key) or int(recipient[key].get("expires_exchange", 0)) < _turn:
						recipient[key] = {"source": mark_owner, "applied_exchange": _turn, "expires_exchange": _turn + 2}
						_award_inspiration(caster, recipient, kind)
				)
			"delayed_damage":
				_log_step("%s prepares delayed damage." % caster.name, func():
					var damage := int(attack_context.get("direct_damage", 0))
					if damage <= 0:
						return
					for pending in _strategic_delays.duplicate():
						if is_same(pending.caster, caster) and is_same(pending.target, target):
							_strategic_delays.erase(pending)
					var amount := floori(damage * value)
					if amount > 0:
						_strategic_delays.append({"caster": caster, "target": target, "amount": amount, "due_turn": _turn + 1})
				)
			"debuff_transfer", "buff_steal":
				_log_step("%s transfers a status." % caster.name, func(): _strategic_transfer(kind, caster, target))
			"cooldown_jam":
				_log_step("%s jams a cooldown." % caster.name, func(): _strategic_jams.append(target))
			"counter_trap":
				_log_step("%s arms a counter trap." % caster.name, func(): caster.strategic_trap = {"value": value, "activated_turn": _turn, "expires_turn": _turn + 2})
			"ward_convert":
				pass
			"heal_suppression":
				_log_step("%s suppresses healing." % caster.name, func(): target.strategic_heal_suppression = {"expires_turn": _turn + 2})
			"hom_energy_siphon":
				_log_step("%s siphons homunculus energy." % caster.name, func():
					if str(caster.get("hom_id", "")).is_empty() or str(target.get("hom_id", "")).is_empty() or bool(caster.get("hom_spent", true)) or bool(target.get("hom_spent", true)):
						return
					var amount := mini(2, mini(int(target.hom_energy), int(caster.hom_max_energy) - int(caster.hom_energy)))
					target.hom_energy -= amount
					caster.hom_energy += amount
				)
			"physical_anomaly":
				_log_step(tr("ANOMALY_REPLACES") % GameLocalization.catalog("spell", str(id), "name", str(spell.get("name", id))), func():
					_physical_anomaly = {"id": id, "favored_type": str(effect.favored_type), "weakened_type": str(effect.weakened_type), "remaining_exchanges": 3, "activated_exchange": _turn}
					_show_physical_anomaly(_physical_anomaly)
				)
			"cleanse_one":
				_log_step("%s cleanses one negative status." % recipient.name, func():
					var cleansed := false
					for field in ["poison", "stun", "vuln_pct", "atk_down", "misalign_next"]:
						if float(recipient.status.get(field, 0)) > 0:
							recipient.status[field] = 0
							if field == "poison": recipient.erase("poison_source"); recipient.erase("poison_effect")
							cleansed = true
							break
					if not cleansed:
						for field in ["burn_effect", "lethargy_effect"]:
							if recipient.has(field): recipient.erase(field); break
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
				if bool(effect.get("health_drain", false)):
					_log_step("%s drains health." % caster.name, func():
						if int(caster.hp) <= 0 or int(target.hp) <= 0: return
						var drain_amount: float = roundi(float(target.hp) * 0.06) if id == "brine_mend" else float(effect.get("max_heal", 0)) * (2.0 if ultra_active else 1.0)
						if id == "brine_mend": _pending_drains.append({"caster":caster, "target":target, "due_turn":_turn + 1}); target.pending_drain = [{"remaining":1}]
						var mitigated := roundi(drain_amount * (1.0 - clampf(_timed_defense(target, "shield_pct"), 0.0, 1.0)) * clampf(float(_hom_synergy(target).get("incoming_mult", 1.0)), 0.1, 1.0))
						var boss_prevented := 0
						if _solo_boss_mode and is_same(target, enemy) and _solo_shield_turns > 0 and not _persistent_active(target, "burn"):
							var reduced := roundi(mitigated * (1.0 - float(_solo_def.shield_reduction)))
							boss_prevented = mitigated - reduced
							mitigated = reduced
						var amount := mini(int(target.hp), mitigated)
						var healed := _strategic_heal(caster, mini(amount, int(caster.max_hp) - int(caster.hp)))
						if _timed_defense(target, "shield_pct") > 0.0 and float(target.status.get("shield_pct", 0.0)) > 0.0: _clear_defense(target, "shield_pct")
						target.hp -= amount
						caster.hp += healed
						if boss_prevented > 0 and int(target.hp) > 0: target.hp = mini(int(target.max_hp), int(target.hp) + _strategic_heal(target, floori(boss_prevented * float(_solo_def.shield_heal_ratio))))
						if amount > 0:
							target.spell_hit_this_exchange = true
							_fire_expedition_passive(target, caster, "damage_received")
							_animate_hit(_fighter_sprite(target), amount, target.max_hp)
							_animate_pulse(_fighter_sprite(caster), Color(0.55, 1.0, 0.65), 1.04)
						_append_combat_log("%s drains %d HP from %s and restores %d HP." % [caster.name, amount, target.name, healed])
						var reflect := _timed_defense(target, "reflect_pct")
						if amount > 0 and reflect > 0.0:
							var ignored := _try_ignore_reflect(caster)
							var reflected := 0 if ignored else mini(int(caster.hp), roundi(amount * reflect))
							caster.hp -= reflected
							if reflected > 0:
								caster.spell_hit_this_exchange = true
								_fire_expedition_passive(caster, target, "damage_received")
							if float(target.status.get("reflect_pct", 0.0)) > 0.0: _clear_defense(target, "reflect_pct")
							if not ignored and int(target.status.get("poison_on_reflect", 0)) > 0:
								var previous_poison := int(caster.status.poison)
								caster.status.poison = maxi(previous_poison, int(target.status.poison_on_reflect))
								_record_poison_source(caster, previous_poison, target)
								if previous_poison <= 0: caster.poison_source = str(target.get("poison_reflect_source", ""))
							target.status.erase("poison_on_reflect")
							target.erase("poison_reflect_source")
							_append_combat_log("%s reflects %d damage." % [target.name, reflected])
					, _combat_event(caster, "damage", " drains health.", {}))
				else:
					var cap := int(effect.get("max_heal", 0)) * (2 if ultra_active else 1)
					_log_step("%s siphons health." % recipient.name, func():
						if recipient.hp > 0:
							var recovered := _strategic_heal(recipient, mini(cap, int(floor(float(attack_context.actual_damage) * value))))
							var actual := mini(recovered, int(recipient.max_hp) - int(recipient.hp))
							recipient.hp = mini(recipient.max_hp, recipient.hp + recovered)
							_append_combat_log("", _combat_event(recipient, "heal", " restores %d HP from life leech." % actual, {}))
					, _combat_event(recipient, "heal", " siphons health.", {}))
			"consume_poison":
				if poisoned_before:
					_log_step("%s consumes poison." % caster.name, func():
						recipient.status.poison = maxi(0, int(recipient.status.poison) - int(value))
						if int(recipient.status.poison) == 0: recipient.erase("poison_source"); recipient.erase("poison_effect")
					, _combat_event(caster, "combo", " consumes poison.", {}))
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
				_log_step("%s gains a shield." % recipient.name, func():
					if not recipient.has("spell_ward_baseline"):
						recipient.spell_ward_baseline = float(recipient.status.get("shield_pct", 0.0))
					recipient.spell_ward = maxf(float(recipient.get("spell_ward", 0.0)), shield_value)
					_other_defense(recipient, "shield_pct", shield_value)
				, _combat_event(recipient, "shield", " gains shield %d%%." % roundi(shield_value * 100), {}))
			"poison_on_reflect":
				_log_step("%s prepares a toxic reflection." % recipient.name, func():
					var previous := int(recipient.status.get("poison_on_reflect", 0))
					recipient.status.poison_on_reflect = int(value)
					if int(value) > previous:
						recipient.poison_reflect_source = "player" if is_same(caster, player) else ("enemy" if is_same(caster, enemy) else "")
				, _combat_event(recipient, "shield", " prepares a reflection with %d poison turns." % int(value), {}))
			"heal":
				_log_step("%s restores %d HP." % [recipient.name, int(value)], func():
					if recipient.hp < recipient.max_hp:
						_animate_pulse(_fighter_sprite(recipient), Color(0.55, 1.0, 0.65), 1.04)
					var recovered := _strategic_heal(recipient, int(value))
					var healed := mini(recovered, int(recipient.max_hp) - int(recipient.hp))
					recipient.hp = min(recipient.max_hp, recipient.hp + recovered)
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
						if int(effect.get("duration_exchanges", 0)) > 0:
							if not recipient.has("timed_defenses"): recipient.timed_defenses = {}
							recipient.timed_defenses[field] = {"value": value, "expires_turn": _turn + int(effect.duration_exchanges) - 1}
							return
						if kind == "shield":
							if not recipient.has("spell_ward_baseline"):
								recipient.spell_ward_baseline = float(recipient.status.get("shield_pct", 0.0))
							recipient.spell_ward = maxf(float(recipient.get("spell_ward", 0.0)), value)
						_other_defense(recipient, field, value)
					else:
						recipient.status[field] = max(recipient.status.get(field, 0), value)
						if kind == "poison": _record_poison_source(recipient, int(before), caster)
					if kind in ["atk_down", "vuln", "poison", "hom_stun"] and float(recipient.status.get(field, 0)) > before:
						_award_inspiration(caster, recipient, kind)
				, _combat_event(recipient, "shield" if kind in ["shield", "reflect"] else "buff" if kind == "atk_boost" else "debuff", " gains %s." % _status_effect_text(kind, value), {}))
			"type_neutralize":
				_log_step("%s prepares type neutralization." % recipient.name, func():
					if value > float(recipient.get("spell_neutralize_pending", 0.0)):
						_animate_pulse(_fighter_sprite(recipient), Color(0.8, 0.65, 1.0), 1.04)
					recipient.spell_neutralize_pending = max(recipient.get("spell_neutralize_pending", 0.0), value)
				, _combat_event(recipient, "buff", " prepares %d%% type neutralization." % roundi(value * 100), {}))
	if spell.get("category") == "attack" and target.has("strategic_trap"):
		_log_step("", func(): _strategic_counter(target, caster, int(attack_context.direct_damage)))
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
		_log_step("%s evades the strike via %s." % [defender.name, _item_label(ev_item)], func():
			_animate_item_effect(defender, "evasion_pct")
			_fire_expedition_passive(defender, attacker, "dodge")
		, _combat_event(defender, "miss", " evades via %s." % _item_label(ev_item), {}))
		return false
	if not _roll_hit(attacker, defender, accuracy, spell_attack, accuracy_focus, accuracy_misalign, spell_attack and not context.is_empty()):
		_log_step("%s's attack misses %s." % [attacker.name, defender.name], Callable(), _combat_event(attacker, "miss", " misses ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": "."}))
		return false

	var mult: float = _spell_multiplier(attacker, defender, context.get("spell", {})) if not context.is_empty() else _type_multiplier(attacker, defender)
	var base_atk: int = int(attacker.atk) + int(_passive_modifiers(attacker).get("power_flat", 0))
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
	var anomaly_mult := 1.0
	if spell_attack and context.has("spell") and not _physical_anomaly.is_empty():
		var attacker_type := str(attacker.get("type", ""))
		if attacker_type == str(_physical_anomaly.get("favored_type", "")):
			anomaly_mult = 1.15
		elif attacker_type == str(_physical_anomaly.get("weakened_type", "")):
			anomaly_mult = 0.85
	var passive_guard := int(_passive_modifiers(defender).get("guard_flat", 0))
	var dmg: int = max(1, int(round((base_atk - int((int(defender.def) + passive_guard) * 0.5)) * mult * power_mult * anomaly_mult)))
	dmg = maxi(1, int(round(dmg * clampf(float(_hom_synergy(defender).get("incoming_mult", 1.0)), 0.1, 1.0))))
	if defender.status.vuln_pct > 0:
		var before_vulnerability := dmg
		dmg = int(round(dmg * (1.0 + defender.status.vuln_pct)))
		var vulnerability_gain := maxi(0, dmg - before_vulnerability)
		_log_step("%s's vulnerability is consumed." % defender.name, func():
			defender.status.vuln_pct = 0
			_record_highlight("combo", vulnerability_gain, "%s: vulnerability" % attacker.name)
		, _combat_event(attacker, "combo", " COMBO: exploits vulnerability.", {}))
	if _timed_defense(defender, "shield_pct") > 0:
		var dispel := clampf(float(context.get("dispel", 0.0)), 0.0, 1.0)
		var pierce := clampf(float(context.get("pierce", 0.0)), 0.0, 1.0)
		if dispel > 0.0:
			_log_step("%s's shield is weakened." % defender.name, func():
				defender.status.shield_pct *= 1.0 - dispel
				for field in ["weapon_shield_pct", "other_shield_pct"]:
					if defender.has(field):
						defender[field] *= 1.0 - dispel
			, _combat_event(defender, "shield", "'s shield is weakened.", {}))
		var effective_shield: float = _timed_defense(defender, "shield_pct") * (1.0 - dispel) * (1.0 - pierce)
		var before_shield := dmg
		dmg = int(round(dmg * (1.0 - effective_shield)))
		var prevented := maxi(0, before_shield - dmg)
		_log_step("%s's ward shatters." % defender.name, func():
			if float(defender.status.get("shield_pct", 0.0)) > 0.0: _clear_defense(defender, "shield_pct")
			_record_highlight("defense", prevented, str(defender.name))
		, _combat_event(defender, "shield", "'s ward blocks %d damage." % prevented, {}))
	if bool(context.get("ultra", false)):
		dmg *= 2
	if _solo_boss_mode and _solo_power_active and is_same(attacker, player) and is_same(defender, enemy):
		dmg *= 2
	var boss_prevented := 0
	if _solo_boss_mode and is_same(defender, enemy) and _solo_shield_turns > 0 and not _persistent_active(defender, "burn"):
		var reduced := maxi(0, roundi(float(dmg) * (1.0 - float(_solo_def.shield_reduction))))
		boss_prevented = dmg - reduced
		dmg = reduced
	_log_step("%s hits %s for %d." % [attacker.name, defender.name, dmg], func():
		var actual_damage := mini(int(defender.hp), dmg)
		_capture_step_hit(defender, dmg)
		_record_highlight("damage", mini(int(defender.hp), dmg), "%s to %s" % [attacker.name, defender.name])
		if not context.is_empty():
			_record_spell_damage(context.get("spell", {}), mini(int(defender.hp), dmg))
			context.direct_damage = mini(int(defender.hp), dmg)
			context.actual_damage += mini(int(defender.hp), dmg)
		defender.hp = max(0, defender.hp - dmg)
		if actual_damage > 0:
			_fire_expedition_passive(defender, attacker, "damage_received")
		if spell_attack and actual_damage > 0:
			var source := attacker
			if _solo_boss_mode and str(attacker.get("type", "")).is_empty(): source = enemy
			CombatVFX.hit_fighter(_fighter_sprite(defender), source)
		if boss_prevented > 0:
			var before_heal := int(defender.hp)
			defender.hp = mini(int(defender.max_hp), int(defender.hp) + _strategic_heal(defender, floori(boss_prevented * float(_solo_def.shield_heal_ratio))))
			_append_combat_log("Alchemical Shield prevented %d damage and restored %d HP." % [boss_prevented, int(defender.hp) - before_heal], {"ability_id": "Shield", "category": "shield"})
		_animate_hit(_fighter_sprite(defender), dmg, defender.max_hp)
		if spell_attack and dmg > 0:
			defender.spell_hit_this_exchange = true
	, _combat_event(attacker, "damage", " hits ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": " for %d." % dmg, "damage": dmg, "effectiveness": mult, "spell_id": str(context.get("spell", {}).get("id", "")) if not context.is_empty() else "", "show_spell_link": false}))
	if _timed_defense(defender, "reflect_pct") > 0:
		if _try_ignore_reflect(attacker):
			var ir_item := _item_with_effect([_get_active_weapon(attacker)], "ignore_reflect_chance")
			_log_step("%s nullifies reflect via %s." % [attacker.name, _item_label(ir_item)], func():
				_clear_defense(defender, "reflect_pct")
				defender.status.erase("poison_on_reflect")
				defender.erase("poison_reflect_source")
				_animate_item_effect(attacker, "ignore_reflect_chance")
			, _combat_event(attacker, "shield", " nullifies reflect via %s." % _item_label(ir_item), {}))
		else:
			var r := int(round(dmg * _timed_defense(defender, "reflect_pct")))
			if _solo_boss_mode and is_same(attacker, enemy) and _solo_has_minions():
				r = 0
			_log_step("%s reflects %d damage." % [defender.name, r], func():
				var actual_reflection := mini(int(attacker.hp), r)
				_record_highlight("damage", mini(int(attacker.hp), r), "%s: reflection" % defender.name)
				_record_highlight("reflection", mini(int(attacker.hp), r), "%s against %s" % [defender.name, attacker.name])
				attacker.hp = max(0, attacker.hp - r)
				if actual_reflection > 0:
					_fire_expedition_passive(attacker, defender, "damage_received")
				if r > 0:
					_animate_hit(_fighter_sprite(attacker), r, attacker.max_hp)
				if spell_attack and r > 0:
					attacker.spell_hit_this_exchange = true
				_clear_defense(defender, "reflect_pct")
				if int(defender.status.get("poison_on_reflect", 0)) > 0 and not (_solo_boss_mode and is_same(attacker, enemy) and _solo_has_minions()):
					var previous_poison := int(attacker.status.poison)
					attacker.status.poison = maxi(int(attacker.status.poison), int(defender.status.poison_on_reflect))
					_record_poison_source(attacker, previous_poison, defender)
					if previous_poison <= 0: attacker.poison_source = str(defender.get("poison_reflect_source", ""))
				defender.status.erase("poison_on_reflect")
				defender.erase("poison_reflect_source")
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
	if str(_get_active_weapon(attacker).get("id", "")) == "vitriol_vial":
		dot_true = mini(dot_true, maxi(0, 4 - int(attacker.get("vitriol_corrosion_used", 0))))
		attacker.vitriol_corrosion_used = int(attacker.get("vitriol_corrosion_used", 0)) + dot_true
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
			var actual := mini(int(defender.hp), hom_dot)
			defender.hp = maxi(0, int(defender.hp) - hom_dot)
			if actual > 0:
				var owner := "player" if is_same(attacker, player) else "enemy"
				var target_side := "enemy" if owner == "player" else "player"
				var entry := {"actor":owner, "effects":[{"kind":"dot_true", "target":target_side, "amount":actual, "unit":"hp", "duration":"instant"}]}
				CombatVFX.passive(player_hom if owner == "player" else enemy_hom, _fighter_sprite(attacker))
				_append_combat_log(_log_presenter.passive_message(entry, attacker.get("hom_data", {})), {"category":"homunculus"})
			_animate_hit(_fighter_sprite(defender), hom_dot, defender.max_hp)
		, _combat_event(attacker, "debuff", "'s homunculus %s corrodes for %d." % [attacker.hom_name, hom_dot], {}, true))

	if attacker.type == "vitriol" and randi() % 100 < 30:
		_log_step("%s corrodes %s (Poison)." % [attacker.name, defender.name], func():
			var previous_poison := int(defender.status.poison)
			defender.status.poison = 2
			_record_poison_source(defender, previous_poison, attacker)
		, _combat_event(attacker, "debuff", " corrodes ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": " (Poison)."}))
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
			attacker.hp = min(attacker.max_hp, attacker.hp + _strategic_heal(attacker, 3))
		, _combat_event(attacker, "heal", " mints up to 3 HP.", {}))

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
	if defender.has("expedition_passive") and _try_evasion(defender):
		_log_step("%s evades the homunculus." % defender.name, func(): _fire_expedition_passive(defender, attacker, "dodge"), _combat_event(defender, "miss", " evades the homunculus.", {}))
		return
	if not _roll_hit(attacker, defender, 0.95):
		_log_step("%s's homunculus misses %s." % [attacker.name, defender.name], func(): _animate_lunge(_fighter_sprite(attacker, true), 12.0 if is_same(attacker, player) else -12.0, false), _combat_event(attacker, "miss", " misses ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": "."}, true))
		return
	var hom_dmg: int = max(1, int(round((int(attacker.atk) + int(_passive_modifiers(attacker).get("power_flat", 0))) * (0.6 if boosted else 0.4) * clampf(float(_hom_synergy(defender).get("incoming_mult", 1.0)), 0.1, 1.0) * _expedition_hom_multiplier(attacker, defender))))
	var timed_shield := float(defender.get("timed_defenses", {}).get("shield_pct", {}).get("value", 0.0))
	if timed_shield > 0.0: hom_dmg = maxi(0, roundi(hom_dmg * (1.0 - timed_shield)))
	if _solo_boss_mode and _solo_power_active and is_same(attacker, player) and is_same(defender, enemy):
		hom_dmg *= 2
	var boss_prevented := 0
	if _solo_boss_mode and is_same(defender, enemy) and _solo_shield_turns > 0:
		var reduced := maxi(0, roundi(float(hom_dmg) * (1.0 - float(_solo_def.shield_reduction))))
		boss_prevented = hom_dmg - reduced
		hom_dmg = reduced
	var track_hit := _spell_exchange_active
	_log_step("%s's homunculus strikes %s for %d." % [attacker.name, defender.name, hom_dmg], func():
		var actual_damage := mini(int(defender.hp), hom_dmg)
		_capture_step_hit(defender, hom_dmg)
		_record_highlight("damage", mini(int(defender.hp), hom_dmg), "%s (%s) to %s" % [attacker.hom_name, attacker.name, defender.name])
		_animate_lunge(_fighter_sprite(attacker, true), 12.0 if is_same(attacker, player) else -12.0, false)
		defender.hp = max(0, defender.hp - hom_dmg)
		if actual_damage > 0:
			_fire_expedition_passive(defender, attacker, "damage_received")
		if boss_prevented > 0:
			defender.hp = mini(int(defender.max_hp), int(defender.hp) + _strategic_heal(defender, floori(boss_prevented * float(_solo_def.shield_heal_ratio))))
		_animate_hit(_fighter_sprite(defender), hom_dmg, defender.max_hp)
		if track_hit:
			defender.spell_hit_this_exchange = true
	, _combat_event(attacker, "homunculus", " overcharged attack on " if boosted else " strikes ", {"target": defender.name, "target_color": _actor_color(defender), "suffix": " for %d." % hom_dmg}, true))
	var timed_reflect := float(defender.get("timed_defenses", {}).get("reflect_pct", {}).get("value", 0.0))
	if timed_reflect > 0.0 and not _try_ignore_reflect(attacker):
		var reflected := roundi(hom_dmg * timed_reflect)
		_log_step("%s reflects %d damage." % [defender.name, reflected], func():
			var actual := mini(int(attacker.hp), reflected)
			attacker.hp -= actual
			if actual > 0:
				_fire_expedition_passive(attacker, defender, "damage_received")
				_animate_hit(_fighter_sprite(attacker), actual, attacker.max_hp)
		, _combat_event(defender, "shield", " reflects %d damage." % reflected, {}))

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
	var hom: Dictionary = f.get("hom_data", {})
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
		_set_next_turn_action("return_zone" if not str(_solo_context.get("visual_zone_id", "")).is_empty() else "return_gate")
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
		_set_next_turn_action("return_loadout")
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
		_set_next_turn_action("return_loadout")
		next_turn_btn.show()
		next_turn_btn.disabled = false
		return

	_battle_index += 1
	_reset_battle_state()
	_log_immediate("Battle %d begins." % _battle_index)
	_update_ui()
	next_turn_btn.disabled = false

func _reset_battle_state() -> void:
	_strategic_delays.clear()
	_strategic_jams.clear()
	_pending_drains.clear()
	_reset_animations()
	_physical_anomaly.clear()
	_show_physical_anomaly(null)
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
	if _spectator_readonly: return
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


# Shared presentation for authoritative end-of-match results.
func _result_popup(title: String) -> VBoxContainer:
	return preload("res://scripts/ui/shared_reward_panel.gd").result_popup(self, title)

func _show_pve_rewards(grants: Dictionary, possible: Dictionary = {}, global_status: Dictionary = {}) -> void:
	var body := _result_popup("REWARDS")
	if not global_status.is_empty():
		_global_reward_popup_layer = body.get_parent().get_parent().get_parent().get_parent() as CanvasLayer
	preload("res://scripts/ui/shared_reward_panel.gd").reward_rows(self, body, grants, possible, global_status)
	if not global_status.is_empty():
		var pending: bool = global_status.get("reward_status") == "WAITING"
		var count := clampi(int(global_status.get("winner_count", 0)), 0, 5)
		var message := Label.new()
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.add_theme_font_size_override("font_size", 20)
		message.add_theme_color_override("font_color", Color("e7d293") if pending else Color("92d8dc"))
		message.text = "REWARDS PENDING\nNot credited yet.\nWaiting for %d more players to defeat this Global Boss.\nProgress: %d/5 victories" % [maxi(0, 5 - count), count] if pending else "REWARDS RECEIVED\nGlobal Boss completed — 5/5 victories."
		body.add_child(message)

func _show_global_rewards(global_status: Dictionary, paid: bool) -> void:
	if is_instance_valid(_global_reward_popup_layer):
		_global_reward_popup_layer.queue_free()
	if paid:
		_show_pve_rewards(global_status.get("reward", {}), {}, global_status)
		return
	var file := FileAccess.open("res://data/static/balance.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else {}
	var balance: Dictionary = parsed.get("balance", {}) if parsed is Dictionary else {}
	var boss: Variant = _online_hunt_session.get("boss_definition", {})
	var tier := str(boss.get("tier", "")) if boss is Dictionary else ""
	var grants: Dictionary = balance.get("solo_hunt_rewards", {}).get("boss", {}).get(tier, {}).duplicate()
	var bonuses: Dictionary = balance.get("solo_hunt_bonus_loot", {}).get(tier, {})
	var chances := {}
	for resource in bonuses:
		var drop: Variant = bonuses[resource]
		if drop is Dictionary:
			grants[resource] = drop.get("quantity", 0)
			chances[resource] = drop.get("chance", 0.0)
	_show_pve_rewards(grants, chances, global_status)

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
	if f.has("expedition_passive"):
		f.expedition_passive = ExpeditionPassive.create(f.hom_data, int(f.hom_progress.get(str(f.hom_id), {}).get("level", 0)))
	for field in ["strategic_trap", "strategic_heal_suppression", "spell_ward", "spell_ward_baseline", "poison_effect", "poison_last_tick", "burn_effect", "lethargy_effect", "pending_drain", "combat_exchange"]:
		f.erase(field)
	f.hom_energy = 0
	f.erase("poison_source")
	f.erase("poison_reflect_source")
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
		multiplier = 1.18 + _hom_advantage_bonus(attacker)
	elif relationship < 1.0:
		var red: float = float(attacker.item_fx.get("disadvantage_reduction", 0.0))
		if red > 0.0 and emit_log:
			var d_item := _item_with_effect([_get_active_weapon(attacker)], "disadvantage_reduction")
			_log("%s steadies the disadvantage via %s." % [attacker.name, _item_label(d_item)], _combat_event(attacker, "advantage", " steadies the disadvantage via %s." % _item_label(d_item), {}))
		multiplier = min(0.84 + red, 1.0)
	var neutralize := maxf(maxf(float(attacker.get("spell_neutralize_active", 0.0)), float(defender.get("spell_neutralize_active", 0.0))), maxf(float(_hom_synergy(attacker).get("type_neutralize", 0.0)), float(_hom_synergy(defender).get("type_neutralize", 0.0))))
	return 1.0 + (multiplier - 1.0) * (1.0 - neutralize)

func _expedition_hom_multiplier(attacker: Dictionary, defender: Dictionary) -> float:
	var hom: Dictionary = attacker.get("hom_data", {})
	if not hom.has("combat_texture"):
		return 1.0
	_ensure_type_effectiveness()
	var row: Dictionary = _type_effectiveness.get(str(hom.get("type", "")), {})
	var relation := float(row.get(str(defender.get("type", "")), 1.0))
	var factor := 1.18 if relation > 1.0 else (0.84 if relation < 1.0 else 1.0)
	var neutralize := maxf(maxf(float(attacker.get("spell_neutralize_active", 0.0)), float(defender.get("spell_neutralize_active", 0.0))), maxf(float(_hom_synergy(attacker).get("type_neutralize", 0.0)), float(_hom_synergy(defender).get("type_neutralize", 0.0))))
	return 1.0 + (factor - 1.0) * (1.0 - clampf(neutralize, 0.0, 1.0))

func _record_poison_source(target: Dictionary, previous: int, source: Dictionary) -> void:
	if int(target.status.poison) <= 0:
		target.erase("poison_source")
		target.erase("poison_effect")
	elif previous > 0:
		target.status.poison = previous
	else:
		target.status.poison = 3
		var applied_exchange := _turn + (1 if int(target.get("poison_last_tick", -1)) == _turn else 0)
		target.poison_effect = {"stage": 0, "applied_exchange": applied_exchange, "expires_exchange": applied_exchange + 2}
		target["poison_source"] = "player" if is_same(source, player) else ("enemy" if is_same(source, enemy) else str(source.get("id", "")))

func _passive_modifiers(fighter: Dictionary) -> Dictionary:
	if bool(fighter.get("hom_spent", true)) or not fighter.has("expedition_passive"):
		return {}
	return ExpeditionPassive.modifiers(fighter.expedition_passive)

func _preinitiative_passive(fighter: Dictionary, target: Dictionary, action: Dictionary) -> void:
	var spell: Dictionary = action.get("spell", action)
	if str(fighter.get("hom_id", "")) == "luny" and action.get("kind", "spell") != "switch" and spell.get("category", "") == "attack" and int(fighter.status.stun) <= 0 and int(fighter.spell_cooldowns.get(str(spell.get("id", "")), 0)) <= 0:
		_fire_expedition_passive(fighter, target, "before_attack", spell)

func _fire_expedition_passive(fighter: Dictionary, target: Dictionary, event: String, spell: Dictionary = {}, poison_damage: int = 0) -> void:
	if bool(fighter.get("hom_spent", true)) or not fighter.has("expedition_passive") or int(fighter.get("hp", 0)) <= 0:
		return
	_ensure_type_effectiveness()
	var attack_type := str(fighter.get("type", ""))
	if not spell.is_empty():
		attack_type = str(spell.get("type", attack_type))
	var defender_type := str(target.get("type", ""))
	var row: Dictionary = _type_effectiveness.get(attack_type, {})
	var relation := float(row.get(defender_type, 1.0))
	if attack_type == "hybrid":
		var primary: Dictionary = _type_effectiveness.get(str(spell.get("primary_type", "")), {})
		var secondary: Dictionary = _type_effectiveness.get(str(spell.get("secondary_type", "")), {})
		var p := float(primary.get(defender_type, 1.0))
		var s := float(secondary.get(defender_type, 1.0))
		relation = pow(1.25 if p > 1.0 else (0.8 if p < 1.0 else 1.0), 0.65) * pow(1.25 if s > 1.0 else (0.8 if s < 1.0 else 1.0), 0.35)
	var status: Dictionary = target.get("status", {})
	var debuffed := false
	for key in ["poison", "stun", "vuln_pct", "atk_down", "hom_stun", "misalign_next"]:
		debuffed = debuffed or float(status.get(key, 0)) > 0.0
	var mark: Dictionary = status.get("hybrid_mark", {})
	var mark_active := not mark.is_empty()
	# The mark-expiry step is queued before an attack is calculated. Account for
	# that pending expiry when Mantillo evaluates the attack's target.
	if event == "before_attack" and not spell.is_empty() and str(mark.get("owner", "")) == ("player" if is_same(fighter, player) else "enemy") and int(mark.get("remaining", 0)) <= 1:
		mark_active = false
	debuffed = debuffed or mark_active or target.has("strategic_heal_suppression") or target.has("burn_effect") or target.has("lethargy_effect")
	var context := {"hp":fighter.hp, "max_hp":fighter.max_hp, "relation":relation, "target_debuffed":debuffed, "shielded":_timed_defense(fighter, "shield_pct") > 0.0, "poison_damage":poison_damage}
	var passive: Dictionary = fighter.expedition_passive
	var previous_markers: int = passive.markers.size()
	var instant := ExpeditionPassive.trigger(passive, event, context)
	var actor_side := "player" if is_same(fighter, player) else "enemy"
	var opponent_side := "enemy" if actor_side == "player" else "player"
	var applied: Array = []
	if passive.markers.size() > previous_markers:
		for definition in passive.get("passive", {}).get("effects", []):
			if definition.get("duration") == "instant": continue
			var exchange: int = int(passive.exchange) + (1 if definition.get("duration") == "next_exchange" else 0)
			for modifier in passive.modifiers:
				if modifier.kind == definition.kind and int(modifier.exchange) == exchange:
					applied.append({"kind":modifier.kind, "target":actor_side, "amount":modifier.amount, "unit":"fraction" if str(modifier.kind).ends_with("_pct") else "flat", "duration":modifier.duration})
	for effect in instant:
		if effect.kind == "heal":
			var previous_hp := int(fighter.hp)
			fighter.hp = mini(int(fighter.max_hp), previous_hp + _strategic_heal(fighter, int(effect.amount)))
			if int(fighter.hp) > previous_hp: applied.append({"kind":"heal", "target":actor_side, "amount":int(fighter.hp) - previous_hp, "unit":"hp", "duration":"instant"})
		elif effect.kind == "poison" and int(target.get("hp", 0)) > 0:
			var before := int(target.status.poison)
			target.status.poison = maxi(before, int(effect.amount))
			_record_poison_source(target, before, fighter)
			if int(target.status.poison) > before:
				applied.append({"kind":"poison", "target":opponent_side, "amount":int(target.status.poison) - before, "unit":"turns", "duration":"instant"})
	if not applied.is_empty():
		var passive_hom: Dictionary = fighter.get("hom_data", {})
		CombatVFX.passive(player_hom if is_same(fighter, player) else enemy_hom, _fighter_sprite(fighter))
		if not passive_hom.is_empty():
			_append_combat_log(_log_presenter.passive_message({"actor":actor_side, "effects":applied, "show_heal":true}, passive_hom), {"category":"homunculus"})

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
	var chance: float = float(defender.item_fx.get("evasion_pct", 0.0)) + float(_passive_modifiers(defender).get("evasion_pct", 0.0))
	if chance <= 0.0:
		return false
	return randf() < chance

func _try_ignore_reflect(attacker: Dictionary) -> bool:
	var chance: float = float(attacker.item_fx.get("ignore_reflect_chance", 0.0))
	if chance <= 0.0:
		return false
	return randf() < chance

func _roll_hit(attacker: Dictionary, defender: Dictionary, base_accuracy: float, spell_attack: bool = false, accuracy_focus: float = 0.0, accuracy_misalign: float = 0.0, spell_accuracy: bool = false) -> bool:
	var acc := base_accuracy + (float(_passive_modifiers(attacker).get("accuracy_pct", 0.0)) if spell_attack else 0.0)
	if spell_accuracy and _persistent_active(attacker, "lethargy"): acc -= 0.15
	if spell_accuracy:
		acc += accuracy_focus - accuracy_misalign
	else:
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
		_log_step("", func():
			var previous := float(f.status.get("reflect_pct", 0.0))
			f.hom_other_reflect = float(f.status.get("reflect_pct", 0.0))
			f.hom_reflect_active = hom_reflect
			f.recording_hom_reflect = true
			_other_defense(f, "reflect_pct", hom_reflect)
			f.erase("recording_hom_reflect")
			if float(f.status.reflect_pct) > previous:
				var owner := "player" if is_same(f, player) else "enemy"
				var entry := {"actor":owner, "effects":[{"kind":"reflect_pct", "target":owner, "amount":hom_reflect, "unit":"fraction", "duration":"until_consumed"}]}
				CombatVFX.passive(player_hom if is_same(f, player) else enemy_hom, _fighter_sprite(f))
				_append_combat_log(_log_presenter.passive_message(entry, f.get("hom_data", {})), {"category":"homunculus"})
		)
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
	var score: float = float(f.get("tempo", 10.0))
	score += _item_initiative(_get_active_weapon(f)) + float(_hom_synergy(f).get("tempo_flat", 0.0))
	score += float(f.status.get("tempo_bonus", 0.0))
	score += float(_passive_modifiers(f).get("tempo_flat", 0.0))
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
	var gate := get_node_or_null("/root/ConnectionGate")
	var identity := str(gate.player_id) if gate != null and not gate.blocked() else ""
	if _combat_backend != null and not _combat_backend.token.is_empty() and not _combat_identity.is_empty() and _combat_backend._verified_player_id == _combat_identity:
		identity = _combat_identity
	var path := preload("res://scripts/domain/build_preferences.gd").seal_path(identity, which)
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

# Enemy generation uses the legacy registry; verified player fighters may use
# the combined collection.
func _online_homunculus(id: String) -> Dictionary:
	if _reg != null and _reg.has_method("get_homunculus_collection"):
		return _reg.get_homunculus_collection().get(id, {})
	return _find_by_id(_homunculi, id)

func _trusted_expedition_hom(id: String) -> bool:
	if _combat_backend == null or _combat_backend.token.is_empty() or _combat_identity.is_empty() or _combat_backend._verified_player_id != _combat_identity or str(_combat_spell_state.get("player_id", "")) != _combat_identity:
		return false
	var hom := _online_homunculus(id)
	var progress: Variant = _combat_spell_state.get("homunculus_progress", {})
	return hom.has("combat_texture") and progress is Dictionary and preload("res://scripts/domain/homunculus_progress.gd").collection_status(id, false, progress, true) == "owned"

func _load_preview_tex(pid: String, kind: String = "entity", display_name: String = "") -> Texture2D:
	if pid == "":
		return null
	if kind == "homunculus":
		var record := _online_homunculus(pid)
		if record.has("combat_texture"):
			var path := str(record.get("combat_texture", ""))
			return load(path) if ResourceLoader.exists(path) else null
		var stem := _resolve_homunculus_stem(pid, display_name)
		if COMBAT_HOM_TEXTURES.has(stem):
			return COMBAT_HOM_TEXTURES[stem]
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
	if COMBAT_ENTITY_TEXTURES.has(type_norm):
		return COMBAT_ENTITY_TEXTURES[type_norm]
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
	if not homunculus:
		var visible_index := 0
		for minion in _solo_minions:
			if is_same(minion, fighter):
				if visible_index < _solo_minion_views.size(): return _solo_minion_views[visible_index]
				break
			if int(minion.get("hp", 0)) > 0: visible_index += 1
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
	for node in [player_entity, enemy_entity, player_hom, enemy_hom]:
		CombatVFX.clear(node)
	for node in _solo_minion_views: CombatVFX.clear(node)

func _exit_tree() -> void:
	_online_presenting_events = false
	_online_event_turn = -1
	_dungeon_playing_events = false
	_dungeon_presentation_turn = -1
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

# Presentation only: combat dictionaries remain authoritative.
func _show_damage_number(sprite: Control, damage: int) -> void:
	if damage <= 0 or not is_instance_valid(sprite):
		return
	var label := Label.new()
	label.text = "-%d" % damage
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 90 if OS.has_feature("android") else 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_size := Vector2(360, 120) if OS.has_feature("android") else Vector2(120, 40)
	label.size = label_size
	add_child(label)
	var viewport_rect := get_viewport_rect()
	var offset := 0
	for child in get_children():
		if child is Label and child.has_meta("floating_damage") and child.get_meta("floating_damage") == sprite.get_instance_id():
			offset += 1
	label.set_meta("floating_damage", sprite.get_instance_id())
	var global_pos := sprite.get_global_rect().get_center() - Vector2(label_size.x / 2.0, sprite.get_global_rect().size.y * 0.5 + label_size.y + 2.0 + (offset % 4) * 18)
	global_pos.x = clampf(global_pos.x, viewport_rect.position.x, viewport_rect.end.x - label_size.x)
	global_pos.y = clampf(global_pos.y, viewport_rect.position.y + 55, viewport_rect.end.y - label_size.y)
	label.global_position = global_pos
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(label.queue_free)

func _set_display_hp(bar: ProgressBar, hp: int) -> void:
	var value := clampi(hp, 0, int(bar.max_value))
	bar.value = value
	bar.get_node("HealthValue").text = "%d / %d" % [value, int(bar.max_value)]
	_apply_hp_color(bar, {"hp": value, "max_hp": bar.max_value})

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

# Capture the HP lost before shield healing in the same queued action.
func _capture_step_hit(target: Dictionary, damage: int) -> void:
	if not _processing_steps:
		return
	if is_same(target, player):
		_step_hit_target = "player"
	elif is_same(target, enemy):
		_step_hit_target = "enemy"
	else:
		return
	_step_hit_damage = mini(maxi(0, int(target.get("hp", 0))), maxi(0, damage))

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
		var before_player := int(player.get("hp", 0))
		var before_enemy := int(enemy.get("hp", 0))
		var minion_hp_before: Array[int] = []
		for minion in _solo_minions:
			minion_hp_before.append(int(minion.get("hp", 0)))
		_step_hit_target = ""
		_step_hit_damage = 0
		var action: Callable = step.get("action", Callable())
		if action.is_valid():
			action.call()
		var player_loss := maxi(0, before_player - int(player.get("hp", 0)))
		var enemy_loss := maxi(0, before_enemy - int(enemy.get("hp", 0)))
		if _step_hit_target == "player":
			player_loss = _step_hit_damage
		elif _step_hit_target == "enemy":
			enemy_loss = _step_hit_damage
		if player_loss > 0:
			_show_damage_number(player_entity, player_loss)
		if enemy_loss > 0:
			_show_damage_number(enemy_entity, enemy_loss)
		var minion_loss := false
		var visible_index := 0
		for i in mini(minion_hp_before.size(), _solo_minions.size()):
			var lost := maxi(0, minion_hp_before[i] - int(_solo_minions[i].get("hp", 0)))
			if lost > 0 and visible_index < _solo_minion_views.size():
				var sprite: Control = _solo_minion_views[visible_index]
				_animate_hit(sprite, lost, int(_solo_minions[i].get("max_hp", 1)))
				_show_damage_number(sprite, lost)
				minion_loss = true
			if minion_hp_before[i] > 0:
				visible_index += 1
		if player_loss > 0 or enemy_loss > 0 or minion_loss:
			await get_tree().create_timer(0.26).timeout
		_update_ui()
		var category := str(step.get("event", {}).get("category", "system"))
		var delay := 1.35 if category == "combo" else 1.25 if category in ["debuff", "shield"] else 0.8 if category == "system" else LOG_STEP_SECONDS
		await get_tree().create_timer(delay).timeout
	_step_queue.clear()
	_processing_steps = false
	_step_hit_target = ""
	_step_hit_damage = 0

func _display_turn() -> int:
	if _dungeon_guard:
		return _dungeon_presentation_turn if _dungeon_presentation_turn >= 0 else int(_dungeon_session.get("combat_state", {}).get("turn", 0))
	if _online_hunt_guard:
		if _online_event_turn >= 0:
			return _online_event_turn
		return int(_online_hunt_session.get("combat_state", {}).get("turn", 0))
	return maxi(1, _turn)

func _scroll_log_to_bottom() -> void:
	await get_tree().process_frame
	var lc := log_box.get_line_count()
	if lc > 0:
		log_box.scroll_to_line(lc - 1)

static func _connection_gate() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("ConnectionGate")

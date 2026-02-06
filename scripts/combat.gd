extends Control

const REG_PATH := "res://scripts/data_registry.gd"
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
	"wind_amulet": "amulet_of _wind.png",
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
const LOG_STEP_SECONDS := 3.0
const ULTRAS := {
	"sulfur": [
		{"name": "Ember", "effects": [{"kind": "heal", "value": 14}]},
		{"name": "Crucible", "effects": [{"kind": "atk_boost", "value": 0.35, "penalty": 0.15}]},
	],
	"mercury": [
		{"name": "Quicksilver", "effects": [{"kind": "hom_stun", "value": 1}]},
		{"name": "Slipstream", "effects": [{"kind": "shield", "value": 0.15}, {"kind": "atk_down", "value": 0.1}]},
	],
	"sodium": [
		{"name": "Bulwark", "effects": [{"kind": "shield", "value": 0.22}, {"kind": "atk_down", "value": 0.1}]},
		{"name": "Tonic", "effects": [{"kind": "heal", "value": 16}, {"kind": "vuln", "value": 0.1}]},
	],
	"aether": [
		{"name": "Null", "effects": [{"kind": "hom_stun", "value": 1}, {"kind": "vuln", "value": 0.1}]},
		{"name": "Flux", "effects": [{"kind": "atk_boost", "value": 0.25, "penalty": 0.1}]},
	],
	"vitriol": [
		{"name": "Corrode", "effects": [{"kind": "poison", "value": 3}]},
		{"name": "Miasma", "effects": [{"kind": "atk_down", "value": 0.15}, {"kind": "vuln", "value": 0.1}]},
	],
	"gold": [
		{"name": "Edict", "effects": [{"kind": "shield", "value": 0.18}, {"kind": "atk_down", "value": 0.1}]},
		{"name": "Mirror", "effects": [{"kind": "reflect", "value": 0.2}]},
	],
}

var _reg: Object = null
var _entities: Array = []
var _homunculi: Array = []
var _items: Array = []

var player := {}
var enemy := {}

var _turn: int = 0
var _round: int = 1
var _player_turn: bool = true
var _swap_pending: bool = false
var _battle_over: bool = false
var _ultra_pending: bool = false
var _ultra_used_player: bool = false
var _ultra_used_enemy: bool = false
var _step_queue: Array = []
var _processing_steps: bool = false

@onready var player_name: Label = $PlayerPanel/PlayerName
@onready var player_entity_name: Label = $PlayerPanel/PlayerEntityNameRow/PlayerEntityName
@onready var player_hom_name: Label = $PlayerPanel/PlayerHomNameRow/PlayerHomName
@onready var player_entity: TextureRect = $PlayerPanel/PlayerSprites/PlayerEntity
@onready var player_hom: TextureRect = $PlayerPanel/PlayerSprites/PlayerHom
@onready var player_hp: ProgressBar = $PlayerPanel/PlayerHPRow/PlayerHP
@onready var player_item1: TextureRect = $PlayerPanel/PlayerItems/PlayerItem1
@onready var player_item2: TextureRect = $PlayerPanel/PlayerItems/PlayerItem2

@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_entity_name: Label = $EnemyPanel/EnemyNames/EnemyEntityName
@onready var enemy_hom_name: Label = $EnemyPanel/EnemyNames/EnemyHomName
@onready var enemy_entity: TextureRect = $EnemyPanel/EnemySprites/EnemyEntity
@onready var enemy_hom: TextureRect = $EnemyPanel/EnemySprites/EnemyHom
@onready var enemy_hp: ProgressBar = $EnemyPanel/EnemyHPRow/EnemyHP
@onready var enemy_item1: TextureRect = $EnemyPanel/EnemyItems/EnemyItem1
@onready var enemy_item2: TextureRect = $EnemyPanel/EnemyItems/EnemyItem2

@onready var log_box: RichTextLabel = $Log
@onready var next_turn_btn: Button = $NextTurn
@onready var back_button: Button = $BackButton

@onready var swap_panel: PanelContainer = $SwapPanel
@onready var swap_side1: Button = $SwapPanel/SwapVBox/SwapButtons/SwapSide1
@onready var swap_side2: Button = $SwapPanel/SwapVBox/SwapButtons/SwapSide2
@onready var swap_icon1: TextureRect = $SwapPanel/SwapVBox/SwapIcons/SwapIcon1
@onready var swap_icon2: TextureRect = $SwapPanel/SwapVBox/SwapIcons/SwapIcon2
@onready var swap_cancel: Button = $SwapPanel/SwapVBox/SwapCancel

@onready var ultra_panel: PanelContainer = $UltraPanel
@onready var ultra_label: Label = $UltraPanel/UltraVBox/UltraLabel
@onready var ultra_btn1: Button = $UltraPanel/UltraVBox/UltraButtons/UltraChoice1/UltraBtn1
@onready var ultra_btn2: Button = $UltraPanel/UltraVBox/UltraButtons/UltraChoice2/UltraBtn2
@onready var ultra_desc1: Label = $UltraPanel/UltraVBox/UltraButtons/UltraChoice1/UltraDesc1
@onready var ultra_desc2: Label = $UltraPanel/UltraVBox/UltraButtons/UltraChoice2/UltraDesc2

@onready var item_tooltip: PanelContainer = $ItemTooltip
@onready var tooltip_label: Label = $ItemTooltip/TooltipLabel
@onready var turn_label: Label = $TurnLabel
@onready var confirm_popup: PopupPanel = $ConfirmLeave
@onready var confirm_stay: Button = $ConfirmLeave/Panel/VBox/Buttons/StayButton
@onready var confirm_leave: Button = $ConfirmLeave/Panel/VBox/Buttons/LeaveButton

func _ready() -> void:
	_load_registry_safe()
	_load_player_from_seal()
	_setup_enemy()
	_update_ui()
	_configure_tooltip_text()
	next_turn_btn.pressed.connect(_on_next_turn)
	swap_side1.pressed.connect(func(): _on_swap_chosen("side_1"))
	swap_side2.pressed.connect(func(): _on_swap_chosen("side_2"))
	swap_icon1.gui_input.connect(func(event): _on_swap_icon_input(event, "side_1"))
	swap_icon2.gui_input.connect(func(event): _on_swap_icon_input(event, "side_2"))
	swap_cancel.pressed.connect(_on_swap_cancel)
	ultra_btn1.pressed.connect(func(): _on_ultra_chosen(0))
	ultra_btn2.pressed.connect(func(): _on_ultra_chosen(1))
	_connect_item_tooltips()
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if confirm_stay:
		confirm_stay.pressed.connect(_on_confirm_stay)
	if confirm_leave:
		confirm_leave.pressed.connect(_on_confirm_leave)
	_log_immediate("Battle start.")

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
	_leave_combat()

func _leave_combat() -> void:
	_battle_over = true
	_log_immediate("You forfeited the combat.")
	if ResourceLoader.exists("res://scenes/LoadoutGrid.tscn"):
		get_tree().change_scene_to_file("res://scenes/LoadoutGrid.tscn")

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

func _load_player_from_seal() -> void:
	var data := _load_seal("attack")
	if data.is_empty():
		data = _load_seal("defense")
	if data.is_empty():
		if _entities.size() > 0:
			data["entity_id"] = str(_entities[0].get("id", ""))
		if _homunculi.size() > 0:
			data["homunculus_id"] = str(_homunculi[0].get("id", ""))
		data["equip_1"] = ""
		data["equip_2"] = ""
		data["side_1"] = ""
		data["side_2"] = ""

	player = _build_fighter(data, true)

func _setup_enemy() -> void:
	var pick := _pick_enemy_entity(player.get("type", ""))
	var hom_id := _pick_enemy_homunculus()
	var used: Array[String] = []
	var e1 := _pick_item_id_unique(used)
	if e1 != "":
		used.append(e1)
	var e2 := _pick_item_id_unique(used)
	if e2 != "":
		used.append(e2)
	var s1 := _pick_item_id_unique(used)
	if s1 != "":
		used.append(s1)
	var s2 := _pick_item_id_unique(used)
	var data := {
		"entity_id": pick,
		"homunculus_id": hom_id,
		"equip_1": e1,
		"equip_2": e2,
		"side_1": s1,
		"side_2": s2,
	}
	enemy = _build_fighter(data, false)

func _build_fighter(data: Dictionary, _is_player: bool) -> Dictionary:
	var ent := _find_by_id(_entities, str(data.get("entity_id", "")))
	var hom := _find_by_id(_homunculi, str(data.get("homunculus_id", "")))
	var stats := _get_base_stats(ent)
	var buffs := _get_homunculus_buffs(hom)
	var atk = stats.atk + buffs.atk
	var def = stats.def + buffs.def
	var hp = stats.hp + buffs.hp

	var equip1 = _find_by_id(_items, str(data.get("equip_1", "")))
	var equip2 = _find_by_id(_items, str(data.get("equip_2", "")))
	var side1 = _find_by_id(_items, str(data.get("side_1", "")))
	var side2 = _find_by_id(_items, str(data.get("side_2", "")))

	var mods = _item_mods([equip1, equip2])
	var fx = _collect_item_effects([equip1, equip2])
	atk = int(round(atk * (1.0 + mods.atk_mul)))
	def = int(round(def * (1.0 + mods.def_mul)))
	hp = int(round(hp * (1.0 + mods.hp_mul)))

	return {
		"id": str(ent.get("id", "")),
		"name": str(ent.get("name", "")),
		"type": str(ent.get("type", "")),
		"hom_id": str(hom.get("id", "")),
		"hom_name": str(hom.get("name", "")),
		"atk": atk,
		"def": def,
		"max_hp": hp,
		"hp": hp,
		"mods": mods,
		"item_fx": fx,
		"equip_1": equip1,
		"equip_2": equip2,
		"side_1": side1,
		"side_2": side2,
		"status": {"poison": 0, "stun": 0, "shield_pct": 0.0, "atk_boost": 0.0, "vuln_pct": 0.0, "atk_down": 0.0, "hom_stun": 0, "reflect_pct": 0.0, "tempo_bonus": 0.0}
	}

func _update_ui() -> void:
	turn_label.text = "Turn %d" % _display_turn()
	player_name.text = "Player"
	player_entity_name.text = str(player.get("name", ""))
	player_hom_name.text = str(player.get("hom_name", ""))
	enemy_name.text = "NPC"
	enemy_entity_name.text = str(enemy.get("name", ""))
	enemy_hom_name.text = str(enemy.get("hom_name", ""))
	player_hp.max_value = float(player.get("max_hp", 1))
	player_hp.value = float(player.get("hp", 1))
	enemy_hp.max_value = float(enemy.get("max_hp", 1))
	enemy_hp.value = float(enemy.get("hp", 1))
	player_entity.texture = _load_preview_tex(player.get("id", ""), "entity", player.get("type", ""))
	player_hom.texture = _load_preview_tex(player.get("hom_id", ""), "homunculus", player.get("hom_name", ""))
	enemy_entity.texture = _load_preview_tex(enemy.get("id", ""), "entity", enemy.get("type", ""))
	enemy_hom.texture = _load_preview_tex(enemy.get("hom_id", ""), "homunculus", enemy.get("hom_name", ""))
	_set_item_icon(player_item1, player.get("equip_1", {}))
	_set_item_icon(player_item2, player.get("equip_2", {}))
	_set_item_icon(enemy_item1, enemy.get("equip_1", {}))
	_set_item_icon(enemy_item2, enemy.get("equip_2", {}))

func _on_next_turn() -> void:
	if _processing_steps:
		return
	await _resolve_turn()

func _resolve_turn() -> void:
	next_turn_btn.disabled = true
	if _battle_over:
		if ResourceLoader.exists("res://scenes/LoadoutGrid.tscn"):
			get_tree().change_scene_to_file("res://scenes/LoadoutGrid.tscn")
		return
	if _swap_pending:
		next_turn_btn.disabled = false
		return
	if _turn == 2:
		if not _ultra_used_player:
			_show_ultra_panel()
			next_turn_btn.disabled = false
			return
		if not _ultra_used_enemy:
			_perform_ultra(enemy, player, false)
			_ultra_used_enemy = true
			_round += 1
			_apply_round_start_effects()
			await _flush_steps()
			_update_ui()
			_check_end()
			if not _player_turn:
				_check_round_swap()
			next_turn_btn.disabled = false
			return
		# both used, continue normal turns
		_turn = 3
	_turn += 1
	var player_init: float = _initiative(player)
	var enemy_init: float = _initiative(enemy)
	if player_init >= enemy_init:
		_side_attack(player, enemy, true)
		if enemy.hp > 0:
			_side_attack(enemy, player, false)
	else:
		_side_attack(enemy, player, false)
		if player.hp > 0:
			_side_attack(player, enemy, true)
	_player_turn = not _player_turn
	if not _player_turn:
		_round += 1
		_apply_round_start_effects()
	await _flush_steps()
	if not _player_turn:
		_check_round_swap()
	_update_ui()
	_check_end()
	next_turn_btn.disabled = false

func _side_attack(attacker: Dictionary, defender: Dictionary, _is_player: bool) -> void:
	_attack_entity(attacker, defender)
	if defender.hp > 0:
		_attack_homunculus(attacker, defender)

func _attack_entity(attacker: Dictionary, defender: Dictionary) -> void:
	if defender.hp <= 0:
		return
	if attacker.status.stun > 0:
		_log_step("%s is stunned and skips a turn." % attacker.name, func(): attacker.status.stun -= 1)
		return
	if _try_evasion(defender):
		var ev_item := _item_with_effect([defender.equip_1, defender.equip_2], "evasion_pct")
		_log_step("%s evades the strike via %s." % [defender.name, _item_label(ev_item)], Callable())
		return

	var mult: float = _type_multiplier(attacker, defender)
	var base_atk: int = int(attacker.atk)
	if attacker.status.atk_down > 0:
		base_atk = int(round(base_atk * (1.0 - attacker.status.atk_down)))
		_log_step("%s shakes off the weakness." % attacker.name, func(): attacker.status.atk_down = 0)
	if attacker.status.atk_boost > 0:
		base_atk = int(round(base_atk * (1.0 + attacker.status.atk_boost)))
		_log_step("%s expends the surge." % attacker.name, func(): attacker.status.atk_boost = 0)
	var dmg: int = max(1, int(round((base_atk - int(defender.def * 0.5)) * mult)))
	if defender.status.vuln_pct > 0:
		dmg = int(round(dmg * (1.0 + defender.status.vuln_pct)))
		_log_step("%s's vulnerability is consumed." % defender.name, func(): defender.status.vuln_pct = 0)
	if defender.status.shield_pct > 0:
		dmg = int(round(dmg * (1.0 - defender.status.shield_pct)))
		_log_step("%s's ward shatters." % defender.name, func(): defender.status.shield_pct = 0)
	_log_step("%s hits %s for %d." % [attacker.name, defender.name, dmg], func(): defender.hp = max(0, defender.hp - dmg))
	if defender.status.reflect_pct > 0:
		if _try_ignore_reflect(attacker):
			var ir_item := _item_with_effect([attacker.equip_1, attacker.equip_2], "ignore_reflect_chance")
			_log_step("%s nullifies reflect via %s." % [attacker.name, _item_label(ir_item)], func(): defender.status.reflect_pct = 0)
		else:
			var r := int(round(dmg * defender.status.reflect_pct))
			_log_step("%s reflects %d damage." % [defender.name, r], func():
				attacker.hp = max(0, attacker.hp - r)
				defender.status.reflect_pct = 0
			)
	var true_bonus: int = _true_on_hit(attacker)
	if true_bonus > 0:
		var t_item := _item_with_effect([attacker.equip_1, attacker.equip_2], "true_on_hit")
		_log_step("%s's %s adds +%d true damage." % [attacker.name, _item_label(t_item), true_bonus], func(): defender.hp = max(0, defender.hp - true_bonus))
	var dot_true: int = _dot_on_hit(attacker)
	if dot_true > 0:
		var d_item := _item_with_effect([attacker.equip_1, attacker.equip_2], "dot_true")
		_log_step("%s's %s corrodes for %d." % [attacker.name, _item_label(d_item), dot_true], func(): defender.hp = max(0, defender.hp - dot_true))
		var v_hit: float = _vuln_on_hit(attacker)
		if v_hit > 0.0:
			_log_step("%s is left vulnerable by the corrosion." % defender.name, func(): defender.status.vuln_pct = max(defender.status.vuln_pct, v_hit))

	if attacker.type == "vitriol" and randi() % 100 < 30:
		_log_step("%s corrodes %s (Poison)." % [attacker.name, defender.name], func(): defender.status.poison = 2)
	if attacker.type == "mercury" and randi() % 100 < 20:
		_log_step("%s shocks %s (Stun)." % [attacker.name, defender.name], func(): defender.status.stun = 1)
	if attacker.type == "sulfur" and randi() % 100 < 20:
		_log_step("%s sears %s (Atk down)." % [attacker.name, defender.name], func(): defender.status.atk_down = max(defender.status.atk_down, 0.15))
	if attacker.type == "sodium" and randi() % 100 < 20:
		_log_step("%s crystallizes a ward." % attacker.name, func(): attacker.status.shield_pct = max(attacker.status.shield_pct, 0.12))
	if attacker.type == "aether" and randi() % 100 < 20:
		_log_step("%s rends the veil (Vulnerable)." % attacker.name, func(): defender.status.vuln_pct = max(defender.status.vuln_pct, 0.12))
	if attacker.type == "gold" and randi() % 100 < 20:
		_log_step("%s mints 3 HP." % attacker.name, func(): attacker.hp = min(attacker.max_hp, attacker.hp + 3))

	if defender.status.poison > 0:
		defender.status.poison -= 1
		defender.hp = max(0, defender.hp - 2)
		_log("%s suffers poison (2)." % defender.name)

func _attack_homunculus(attacker: Dictionary, defender: Dictionary) -> void:
	if defender.hp <= 0:
		return
	if defender.status.hom_stun > 0:
		_log_step("%s's homunculus is nullified this turn." % defender.name, func(): defender.status.hom_stun -= 1)
		return
	var hom_dmg: int = max(1, int(round(attacker.atk * 0.4)))
	_log_step("%s's homunculus strikes %s for %d." % [attacker.name, defender.name, hom_dmg], func(): defender.hp = max(0, defender.hp - hom_dmg))

func _check_round_swap() -> void:
	if _round != 2:
		return
	if player.hp == enemy.hp:
		return
	var player_wins: bool = player.hp > enemy.hp
	if player_wins:
		_apply_tempo_win_bonus(player, true)
		_swap_pending = true
		swap_panel.visible = true
		swap_side1.text = _item_label(player.side_1)
		swap_side2.text = _item_label(player.side_2)
		swap_icon1.texture = _load_item_icon(player.side_1)
		swap_icon2.texture = _load_item_icon(player.side_2)
		swap_icon1.custom_minimum_size = Vector2(96, 96)
		swap_icon2.custom_minimum_size = Vector2(96, 96)
		_log_immediate("You won round 1. Choose a sideboard item to swap in.")
	else:
		_apply_tempo_win_bonus(enemy, false)
		_npc_swap()

func _on_swap_chosen(which: String) -> void:
	if not _swap_pending:
		return
	var item: Dictionary = player.get(which, {})
	if item == null or item.is_empty():
		_swap_pending = false
		swap_panel.visible = false
		return
	if _is_duplicate_swap(player, item):
		_log_immediate("Swap canceled: duplicate item.")
		_swap_pending = false
		swap_panel.visible = false
		return
	player.equip_1 = item
	player.mods = _item_mods([player.equip_1, player.equip_2])
	_apply_mods(player)
	_swap_pending = false
	swap_panel.visible = false
	_log_immediate("Swapped in %s." % _item_label(item))
	_update_ui()

func _on_swap_cancel() -> void:
	if not _swap_pending:
		return
	_swap_pending = false
	swap_panel.visible = false
	_log_immediate("Swap canceled.")

func _on_swap_icon_input(event: InputEvent, which: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_swap_chosen(which)

func _show_ultra_panel() -> void:
	if _ultra_pending:
		return
	var opts: Array = _get_ultra_options(player.get("type", ""))
	ultra_label.text = "Choose UltraHit (turn 3)"
	ultra_btn1.text = str(opts[0].get("name", "Ultra A"))
	ultra_btn2.text = str(opts[1].get("name", "Ultra B"))
	ultra_desc1.text = _ultra_desc(opts[0] as Dictionary)
	ultra_desc2.text = _ultra_desc(opts[1] as Dictionary)
	ultra_panel.visible = true
	_ultra_pending = true

func _on_ultra_chosen(idx: int) -> void:
	if not _ultra_pending:
		return
	var opts: Array = _get_ultra_options(player.get("type", ""))
	_perform_ultra(player, enemy, true, opts[idx] as Dictionary)
	_ultra_used_player = true
	_ultra_pending = false
	ultra_panel.visible = false
	if not _ultra_used_enemy:
		_perform_ultra(enemy, player, false)
		_ultra_used_enemy = true
	_update_ui()
	_check_end()

func _perform_ultra(user: Dictionary, target: Dictionary, _is_player: bool, forced: Dictionary = {}) -> void:
	var pick: Dictionary
	if not forced.is_empty():
		pick = forced
	else:
		var opts: Array = _get_ultra_options(user.get("type", ""))
		pick = opts[0] if randi() % 2 == 0 else opts[1]
	_log_step("%s uses UltraHit: %s." % [user.name, str(pick.get("name", "Ultra"))], Callable())
	var effects: Array = pick.get("effects", [])
	for effect in effects:
		var kind: String = str(effect.get("kind", ""))
		match kind:
			"heal":
				var val: int = int(effect.get("value", 0))
				_log_step("%s restores %d HP." % [user.name, val], func(): user.hp = min(user.max_hp, user.hp + val))
			"shield":
				var val_s: float = float(effect.get("value", 0.0))
				_log_step("%s gains a %d%% ward." % [user.name, int(val_s * 100)], func(): user.status.shield_pct = val_s)
			"atk_boost":
				var val_b: float = float(effect.get("value", 0.0))
				var pen: float = float(effect.get("penalty", 0.0))
				_log_step("%s surges (+%d%% atk), but becomes brittle." % [user.name, int(val_b * 100)], func():
					user.status.atk_boost = val_b
					user.status.vuln_pct = pen
				)
			"hom_stun":
				_log_step("%s seals the rival homunculus." % user.name, func(): target.status.hom_stun = 1)
			"atk_down":
				var val_a: float = float(effect.get("value", 0.0))
				_log_step("%s weakens %s (-%d%% atk next)." % [user.name, target.name, int(val_a * 100)], func(): target.status.atk_down = val_a)
			"poison":
				var val_p: int = int(effect.get("value", 0))
				_log_step("%s inflicts alchemical rot." % user.name, func(): target.status.poison = max(target.status.poison, val_p))
			"reflect":
				var val_r: float = float(effect.get("value", 0.0))
				_log_step("%s prepares a mirrored ward." % user.name, func(): user.status.reflect_pct = val_r)
			"vuln":
				var val_v: float = float(effect.get("value", 0.0))
				_log_step("%s becomes exposed to backlash." % user.name, func(): user.status.vuln_pct = val_v)

func _get_ultra_options(t: String) -> Array:
	if ULTRAS.has(t):
		return ULTRAS[t]
	return ULTRAS["sulfur"]

func _ultra_desc(pick: Dictionary) -> String:
	var effects: Array = pick.get("effects", [])
	var parts: Array[String] = []
	for effect in effects:
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

func _npc_swap() -> void:
	var s1 = enemy.side_1
	var s2 = enemy.side_2
	var m1 = _item_mods([s1])
	var m2 = _item_mods([s2])
	var pick = s1 if m1.atk_mul + m1.def_mul + m1.hp_mul >= m2.atk_mul + m2.def_mul + m2.hp_mul else s2
	if _is_duplicate_swap(enemy, pick):
		pick = s2 if pick == s1 else s1
	enemy.equip_1 = pick
	enemy.mods = _item_mods([enemy.equip_1, enemy.equip_2])
	_apply_mods(enemy)
	_log_immediate("NPC swaps in %s." % _item_label(pick))
	_update_ui()

func _apply_mods(f: Dictionary) -> void:
	var ent := _find_by_id(_entities, f.id)
	var hom := _find_by_id(_homunculi, f.hom_id)
	var stats := _get_base_stats(ent)
	var buffs := _get_homunculus_buffs(hom)
	var atk = stats.atk + buffs.atk
	var def = stats.def + buffs.def
	var hp = stats.hp + buffs.hp
	var mods = f.mods
	f.atk = int(round(atk * (1.0 + mods.atk_mul)))
	f.def = int(round(def * (1.0 + mods.def_mul)))
	f.max_hp = int(round(hp * (1.0 + mods.hp_mul)))
	f.hp = min(f.hp, f.max_hp)
	f.item_fx = _collect_item_effects([f.equip_1, f.equip_2])

func _check_end() -> void:
	if player.hp <= 0:
		_log_immediate("You lose.")
		_battle_over = true
		next_turn_btn.text = "Return"
		next_turn_btn.disabled = false
	if enemy.hp <= 0:
		_log_immediate("You win.")
		_battle_over = true
		next_turn_btn.text = "Return"
		next_turn_btn.disabled = false

func _type_multiplier(attacker: Dictionary, defender: Dictionary) -> float:
	var adv = _type_advantage(attacker.type)
	var defender_type: String = str(defender.type)
	if adv == defender_type:
		return 1.2
	if _type_advantage(defender_type) == attacker.type:
		var red: float = float(attacker.item_fx.get("disadvantage_reduction", 0.0))
		if red > 0.0:
			var d_item := _item_with_effect([attacker.equip_1, attacker.equip_2], "disadvantage_reduction")
			_log("%s steadies the disadvantage via %s." % [attacker.name, _item_label(d_item)])
		return min(0.85 + red, 1.0)
	return 1.0

func _type_advantage(t: String) -> String:
	match t:
		"sulfur": return "vitriol"
		"vitriol": return "sodium"
		"sodium": return "mercury"
		"mercury": return "sulfur"
		"aether": return "gold"
		"gold": return "aether"
		_: return ""

func _item_mods(items: Array) -> Dictionary:
	var mods := {"atk_mul": 0.0, "def_mul": 0.0, "hp_mul": 0.0}
	for it in items:
		if it == null or it.is_empty():
			continue
		var rarity = str(it.get("rarity", "basic"))
		var inc = 0.1 if rarity == "basic" else 0.2
		var effects = it.get("effects", {})
		if effects.has("power_flat"):
			mods.atk_mul += inc
		if effects.has("guard_flat"):
			mods.def_mul += inc
		if effects.has("tempo_flat"):
			mods.hp_mul += inc
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
	if f.item_fx.get("ward_pct", 0.0) > 0.0:
		var ward: float = float(f.item_fx.get("ward_pct", 0.0))
		_log_step("%s forms a ward via %s." % [f.name, _item_label(_item_with_effect([f.equip_1, f.equip_2], "ward_pct"))], func(): f.status.shield_pct = max(f.status.shield_pct, ward))
	if f.item_fx.get("reflect_pct", 0.0) > 0.0:
		var refl: float = float(f.item_fx.get("reflect_pct", 0.0))
		_log_step("%s readies a mirror from %s." % [f.name, _item_label(_item_with_effect([f.equip_1, f.equip_2], "reflect_pct"))], func(): f.status.reflect_pct = max(f.status.reflect_pct, refl))

func _apply_tempo_win_bonus(f: Dictionary, _is_player: bool) -> void:
	var tempo: float = float(f.item_fx.get("tempo_on_win", 0.0))
	if tempo <= 0.0:
		return
	_log_step("%s accelerates via %s." % [f.name, _item_label(_item_with_effect([f.equip_1, f.equip_2], "tempo_on_win"))], func(): f.status.tempo_bonus = tempo)

func _initiative(f: Dictionary) -> float:
	var score: float = 10.0
	score += _item_initiative(f.get("equip_1", {}))
	score += _item_initiative(f.get("equip_2", {}))
	score += float(f.status.get("tempo_bonus", 0.0))
	f.status.tempo_bonus = 0.0
	return score

func _item_initiative(item: Dictionary) -> float:
	if item == null or item.is_empty():
		return 0.0
	var effects = item.get("effects", {})
	var score: float = 0.0
	if effects.has("tempo_flat"):
		score += 2.0
	if effects.has("power_flat"):
		score += 1.0
	if effects.has("guard_flat"):
		score += 0.5
	return score

func _pick_enemy_entity(player_type: String) -> String:
	if _entities.is_empty():
		return ""
	var target := ""
	var wanted := _type_advantage(player_type)
	for e in _entities:
		var t = str(e.get("type", ""))
		if t == wanted:
			target = str(e.get("id", ""))
			break
	if target == "":
		target = str(_entities[0].get("id", ""))
	return target

func _pick_enemy_homunculus() -> String:
	if _homunculi.is_empty():
		return ""
	return str(_homunculi[randi() % _homunculi.size()].get("id", ""))

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

func _is_duplicate_swap(f: Dictionary, new_item: Dictionary) -> bool:
	if new_item == null or new_item.is_empty():
		return false
	var new_id: String = str(new_item.get("id", ""))
	var other: Dictionary = f.get("equip_2", {})
	var other_id: String = str(other.get("id", ""))
	return new_id != "" and new_id == other_id

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

func _log(msg: String) -> void:
	_step_queue.append({"msg": msg, "action": Callable()})

func _log_step(msg: String, action: Callable) -> void:
	_step_queue.append({"msg": msg, "action": action})

func _log_immediate(msg: String) -> void:
	log_box.append_text("T%d: %s\n" % [_display_turn(), msg])
	_scroll_log_to_bottom()

func _flush_steps() -> void:
	if _processing_steps:
		return
	_processing_steps = true
	for step in _step_queue:
		var msg := str(step.get("msg", ""))
		if msg != "":
			log_box.append_text("T%d: %s\n" % [_display_turn(), msg])
			_scroll_log_to_bottom()
		var action: Callable = step.get("action", Callable())
		if action.is_valid():
			action.call()
		_update_ui()
		await get_tree().create_timer(LOG_STEP_SECONDS).timeout
	_step_queue.clear()
	_processing_steps = false

func _display_turn() -> int:
	# Keep visible turns aligned with combat flow (no jump after UltraHit)
	if _turn <= 0:
		return 1
	if _turn >= 4:
		return _turn - 1
	return _turn

func _scroll_log_to_bottom() -> void:
	await get_tree().process_frame
	var lc := log_box.get_line_count()
	if lc > 0:
		log_box.scroll_to_line(lc - 1)

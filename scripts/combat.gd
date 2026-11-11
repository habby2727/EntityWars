extends Control

const REG_PATH := "res://scripts/data_registry.gd"
const SpellLoadout := preload("res://scripts/domain/spell_loadout.gd")
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

var _reg: Object = null
var _entities: Array = []
var _homunculi: Array = []
var _items: Array = []
var _combat_spell_state := {}
var _type_effectiveness := {}
var _spell_exchange_active := false
var _resolving_exchange := false
var _spell_acts_second := false
var _animation_tweens := {}
var _animation_original := {}

var player := {}
var enemy := {}

var _turn: int = 0
var _round: int = 1
var _battle_index: int = 1
var _player_wins: int = 0
var _enemy_wins: int = 0
var _sudden_death: bool = false
var _player_turn: bool = true
var _swap_pending: bool = false
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
@onready var player_item1: TextureRect = $PlayerPanel/PlayerItems/PlayerItem1
@onready var player_item2: TextureRect = $PlayerPanel/PlayerItems/PlayerItem2

@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_entity_name: Label = $EnemyPanel/EnemyNames/EnemyEntityName
@onready var enemy_hom_name: Label = $EnemyPanel/EnemyNames/EnemyHomName
@onready var enemy_entity: TextureRect = $EnemyPanel/EnemySprites/EnemyEntityFrame/EnemyEntity
@onready var enemy_hom: TextureRect = $EnemyPanel/EnemySprites/EnemyHomFrame/EnemyHom
@onready var enemy_hp: ProgressBar = $EnemyPanel/EnemyHPRow/EnemyHP
@onready var enemy_indicators: Control = $EnemyPanel/EnemyHPRow/EnemyHP/Indicators
@onready var enemy_item1: TextureRect = $EnemyPanel/EnemyItems/EnemyItem1
@onready var enemy_item2: TextureRect = $EnemyPanel/EnemyItems/EnemyItem2

@onready var log_box: RichTextLabel = $Log
@onready var next_turn_btn: Button = $NextTurn
@onready var spell_panel: PanelContainer = $SpellPanel
@onready var spell_buttons: Array = [$SpellPanel/SpellGrid/Spell1, $SpellPanel/SpellGrid/Spell2, $SpellPanel/SpellGrid/Spell3, $SpellPanel/SpellGrid/Spell4]
@onready var back_button: Button = $BackButton

@onready var swap_panel: PanelContainer = $SwapPanel
@onready var swap_side1: Button = $SwapPanel/SwapVBox/SwapButtons/SwapSide1
@onready var swap_side2: Button = $SwapPanel/SwapVBox/SwapButtons/SwapSide2
@onready var swap_icon1: TextureRect = $SwapPanel/SwapVBox/SwapIcons/SwapIcon1
@onready var swap_icon2: TextureRect = $SwapPanel/SwapVBox/SwapIcons/SwapIcon2
@onready var swap_cancel: Button = $SwapPanel/SwapVBox/SwapCancel

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
	_setup_hp_styles()
	_update_ui()
	_configure_tooltip_text()
	next_turn_btn.pressed.connect(_on_next_turn)
	swap_side1.pressed.connect(func(): _on_swap_chosen("side_1"))
	swap_side2.pressed.connect(func(): _on_swap_chosen("side_2"))
	swap_icon1.gui_input.connect(func(event): _on_swap_icon_input(event, "side_1"))
	swap_icon2.gui_input.connect(func(event): _on_swap_icon_input(event, "side_2"))
	swap_cancel.pressed.connect(_on_swap_cancel)
	_connect_item_tooltips()
	for i in spell_buttons.size():
		spell_buttons[i].pressed.connect(_on_spell_chosen.bind(i))
	_style_spell_buttons()
	next_turn_btn.hide()
	_refresh_spell_buttons()
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if confirm_stay:
		confirm_stay.pressed.connect(_on_confirm_stay)
	if confirm_leave:
		confirm_leave.pressed.connect(_on_confirm_leave)
	_log_immediate("Battle 1 begins.")

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
	_reset_animations()
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
	var mode := SceneRouter.consume_combat_seal_mode()
	var data := _load_seal(mode)
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
		data["side_1"] = ""
		data["side_2"] = ""
	var debug := DebugFlags.new()
	var debug_enabled := debug.unlock_all_buildings
	_combat_spell_state = debug.load_lab_state() if debug_enabled else Reconcile.new().get_state()
	debug.free()
	data["spell_ids"] = SpellLoadout.saved_ids(_reg, _combat_spell_state, mode, str(data.get("entity_id", "")), data, not debug_enabled)
	player = _build_fighter(data, true)

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
		"spell_ids": spell_ids,
	}
	enemy = _build_fighter(data, false)

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
		"spell_ids": fighter_spells,
		"status": {"poison": 0, "stun": 0, "shield_pct": 0.0, "atk_boost": 0.0, "vuln_pct": 0.0, "atk_down": 0.0, "hom_stun": 0, "reflect_pct": 0.0, "tempo_bonus": 0.0},
		"spell_cooldowns": {}, "spell_hit_this_exchange": false, "spell_hit_last_exchange": false,
		"spell_neutralize_pending": 0.0, "spell_neutralize_active": 0.0
	}

func _update_ui() -> void:
	player_indicators.set_fighter(_player_wins, player)
	enemy_indicators.set_fighter(_enemy_wins, enemy)
	var header = "Sudden Death" if _sudden_death else "Battle %d" % _battle_index
	turn_label.text = "%s\nTurn %d" % [header, _display_turn()]
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
	_apply_hp_colors()

func _setup_hp_styles() -> void:
	_hp_fill_green = StyleBoxFlat.new()
	_hp_fill_green.bg_color = Color(0.2, 0.85, 0.35, 1.0)
	_hp_fill_yellow = StyleBoxFlat.new()
	_hp_fill_yellow.bg_color = Color(0.95, 0.8, 0.2, 1.0)
	_hp_fill_red = StyleBoxFlat.new()
	_hp_fill_red.bg_color = Color(0.9, 0.2, 0.2, 1.0)

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
	if _battle_over and not _processing_steps and ResourceLoader.exists("res://scenes/LoadoutGrid.tscn"):
		get_tree().change_scene_to_file("res://scenes/LoadoutGrid.tscn")

func _on_spell_chosen(index: int) -> void:
	if _resolving_exchange or _processing_steps or _swap_pending or _battle_over:
		return
	var options := _fighter_spell_options(player)
	if index < 0 or index >= options.size():
		return
	var chosen: Dictionary = options[index]
	if int(player.spell_cooldowns.get(chosen.id, 0)) > 0:
		return
	var npc_spell := _choose_npc_spell()
	if npc_spell.is_empty():
		_log_immediate("No spell available for the opponent.")
		return
	_resolving_exchange = true
	_refresh_spell_buttons()
	await _resolve_spell_exchange(chosen, npc_spell)
	_resolving_exchange = false
	_refresh_spell_buttons()

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
	if first.hp > 0 and second.hp > 0:
		_spell_acts_second = true
		await _resolve_spell_action(second, first, second_spell)
	if player.hp > 0 and enemy.hp > 0:
		_apply_spell_poison(player)
		_apply_spell_poison(enemy)
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
		_check_round_swap()
		await _flush_steps()
	_update_ui()

func _resolve_spell_action(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	_execute_spell(caster, target, spell)
	await _flush_steps()
	if caster.hp <= 0 or target.hp <= 0:
		spell_panel.hide()
	if caster.hp > 0 and target.hp > 0:
		_attack_homunculus(caster, target)
		await _flush_steps()
		if caster.hp <= 0 or target.hp <= 0:
			spell_panel.hide()

func _apply_spell_poison(fighter: Dictionary) -> void:
	if fighter.status.poison > 0:
		_log_step("%s suffers poison (2)." % fighter.name, func():
			fighter.status.poison -= 1
			fighter.hp = max(0, fighter.hp - 2)
			fighter.spell_hit_this_exchange = true
		)

func _refresh_spell_buttons() -> void:
	var options := _fighter_spell_options(player)
	spell_panel.visible = not _battle_over and not _swap_pending
	for i in spell_buttons.size():
		var button: Button = spell_buttons[i]
		button.visible = i < options.size()
		if i >= options.size():
			continue
		var spell: Dictionary = options[i]
		var cd := int(player.get("spell_cooldowns", {}).get(spell.id, 0))
		var power := "Support" if float(spell.power_mult) == 0.0 else "x%.2f" % float(spell.power_mult)
		var cooldown := "  |  CD: %d" % cd if cd > 0 else ""
		button.text = "%s\n%s  |  %d%%%s" % [spell.name, power, int(round(float(spell.accuracy) * 100)), cooldown]
		button.tooltip_text = str(spell.get("desc", ""))
		button.disabled = _resolving_exchange or _processing_steps or _swap_pending or _battle_over or cd > 0

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
		button.add_theme_font_size_override("font_size", 14)
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
					weight = 0.0 if enemy.hp >= enemy.max_hp else (7.0 if enemy.hp < enemy.max_hp * 0.65 else 2.0)
				"shield":
					weight = 0.0 if enemy.status.shield_pct > 0 else (5.0 if enemy.hp < enemy.max_hp * 0.75 else 2.0)
				"reflect":
					weight = 0.0 if enemy.status.reflect_pct > 0 else 3.0
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
					weight = 0.0 if enemy.status.atk_boost > 0 else 3.0
				"type_neutralize":
					weight = 0.0 if enemy.spell_neutralize_pending > 0 or _type_multiplier(player, enemy) >= 1.0 else 3.0
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

func _side_attack(attacker: Dictionary, defender: Dictionary, _is_player: bool) -> void:
	_attack_entity(attacker, defender)
	if defender.hp > 0:
		_attack_homunculus(attacker, defender)

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

func _execute_spell(caster: Dictionary, target: Dictionary, spell: Dictionary) -> bool:
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
	var owner := "player" if is_same(caster, player) else "enemy"
	var mark: Dictionary = target.status.get("hybrid_mark", {})
	var marked := str(mark.get("owner", "")) == owner and int(mark.get("remaining", 0)) > 0
	if marked:
		_log_step("%s's mark approaches expiry." % caster.name, func():
			var current: Dictionary = target.status.get("hybrid_mark", {})
			if current.get("owner", "") == owner:
				current["remaining"] = int(current.get("remaining", 0)) - 1
				if current.remaining <= 0:
					target.status.erase("hybrid_mark")
		)
	var animate_attack: bool = spell.get("category") == "attack" and caster.status.stun <= 0
	_log_step("%s uses spell %s." % [caster.name, spell.get("name", id)], func():
		if animate_attack:
			_animate_lunge(_fighter_sprite(caster), 20.0 if is_same(caster, player) else -20.0, true)
	)
	if caster.status.stun > 0:
		_log_step("%s is stunned and skips the spell." % caster.name, func(): caster.status.stun -= 1)
		return true
	var power := float(spell.get("power_mult", 0.0))
	var accuracy_focus := 0.0
	var accuracy_misalign := 0.0
	var attack_context := {"spell": spell, "actual_damage": 0, "pierce": 0.0, "dispel": 0.0}
	var poisoned_before := int(target.status.poison) > 0
	if spell.get("category") == "attack":
		accuracy_focus = float(caster.status.get("focus_next", 0.0))
		accuracy_misalign = float(caster.status.get("misalign_next", 0.0))
		if accuracy_focus > 0 or accuracy_misalign > 0:
			_log_step("%s expends accuracy effects." % caster.name, func():
				caster.status.erase("focus_next")
				caster.status.erase("misalign_next")
			)
	for effect in spell.get("effects", []):
		if effect.kind == "bonus_if_poisoned" and target.status.poison > 0:
			power *= 1.0 + float(effect.value)
			_log_step("%s exploits poison." % caster.name, Callable())
		elif effect.kind == "bonus_if_hit_last_exchange" and caster.get("spell_hit_last_exchange", false):
			power *= 1.0 + float(effect.value)
			_log_step("%s retaliates for the previous exchange." % caster.name, Callable())
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
		_log_step("%s's spell %s." % [caster.name, "succeeds" if hit else "misses"], Callable())
	if not hit:
		return true
	if spell.get("type") == "hybrid" and marked:
		_log_step("%s consumes the hybrid mark." % caster.name, func(): target.status.erase("hybrid_mark"))
	for effect in spell.get("effects", []):
		var recipient: Dictionary = caster if effect.target == "self" else target
		var value := float(effect.value)
		var kind := str(effect.kind)
		match kind:
			"cleanse_one":
				_log_step("%s cleanses one negative status." % recipient.name, func():
					for field in ["poison", "stun", "vuln_pct", "atk_down", "misalign_next"]:
						if float(recipient.status.get(field, 0)) > 0:
							recipient.status[field] = 0
							break
				)
			"focus_next", "misalign_next":
				_log_step("%s gains %s." % [recipient.name, kind], func(): recipient.status[kind] = maxf(float(recipient.status.get(kind, 0)), value))
			"tempo_shift":
				_log_step("%s's next initiative shifts by %s." % [recipient.name, str(value)], func(): recipient.status.tempo_bonus = value)
			"recoil":
				_log_step("%s takes %d recoil." % [recipient.name, int(value)], func():
					if recipient.hp > 0 and value > 0:
						recipient.spell_hit_this_exchange = true
					recipient.hp = max(0, recipient.hp - int(value))
					if value > 0:
						_animate_hit(_fighter_sprite(recipient), int(value), recipient.max_hp)
				)
			"life_leech":
				var cap := int(effect.get("max_heal", 0))
				_log_step("%s siphons health." % recipient.name, func():
					if recipient.hp > 0:
						var recovered := mini(cap, int(floor(float(attack_context.actual_damage) * value)))
						recipient.hp = mini(recipient.max_hp, recipient.hp + recovered)
				)
			"consume_poison":
				if poisoned_before:
					_log_step("%s consumes poison." % caster.name, func(): recipient.status.poison = maxi(0, int(recipient.status.poison) - int(value)))
			"hybrid_mark":
				_log_step("%s marks %s." % [caster.name, recipient.name], func(): recipient.status.hybrid_mark = {"owner": owner, "remaining": int(value)})
			"shield_by_order":
				var shield_value := float(effect.get("second_value", value)) if _spell_acts_second else value
				_log_step("%s gains a shield." % recipient.name, func(): recipient.status.shield_pct = maxf(float(recipient.status.shield_pct), shield_value))
			"poison_on_reflect":
				_log_step("%s prepares a toxic reflection." % recipient.name, func(): recipient.status.poison_on_reflect = int(value))
			"heal":
				_log_step("%s restores %d HP." % [recipient.name, int(value)], func():
					if recipient.hp < recipient.max_hp:
						_animate_pulse(_fighter_sprite(recipient), Color(0.55, 1.0, 0.65), 1.04)
					recipient.hp = min(recipient.max_hp, recipient.hp + int(value))
				)
			"shield", "reflect", "atk_boost", "atk_down", "vuln", "poison", "hom_stun":
				var fields := {"shield": "shield_pct", "reflect": "reflect_pct", "vuln": "vuln_pct"}
				var field: String = fields.get(kind, kind)
				_log_step("%s gains %s (%s)." % [recipient.name, kind, str(effect.value)], func():
					if kind in ["shield", "reflect", "atk_boost"] and value > float(recipient.status.get(field, 0)):
						_animate_pulse(_fighter_sprite(recipient), Color(0.62, 0.7, 1.0), 1.04)
					recipient.status[field] = max(recipient.status.get(field, 0), value)
				)
			"type_neutralize":
				_log_step("%s prepares type neutralization." % recipient.name, func():
					if value > float(recipient.get("spell_neutralize_pending", 0.0)):
						_animate_pulse(_fighter_sprite(recipient), Color(0.8, 0.65, 1.0), 1.04)
					recipient.spell_neutralize_pending = max(recipient.get("spell_neutralize_pending", 0.0), value)
				)
	return true

func _attack_entity(attacker: Dictionary, defender: Dictionary, power_mult: float = 1.0, accuracy: float = 0.9, spell_attack: bool = false, context: Dictionary = {}, accuracy_focus: float = 0.0, accuracy_misalign: float = 0.0) -> bool:
	if defender.hp <= 0:
		return false
	if attacker.status.stun > 0:
		_log_step("%s is stunned and skips a turn." % attacker.name, func(): attacker.status.stun -= 1)
		return false
	if _try_evasion(defender):
		var ev_item := _item_with_effect([defender.equip_1, defender.equip_2], "evasion_pct")
		_log_step("%s evades the strike via %s." % [defender.name, _item_label(ev_item)], func(): _animate_item_effect(defender, "evasion_pct"))
		return false
	if not _roll_hit(attacker, defender, accuracy, spell_attack, accuracy_focus, accuracy_misalign):
		_log_step("%s's attack misses %s." % [attacker.name, defender.name], Callable())
		return false

	var mult: float = _spell_multiplier(attacker, defender, context.get("spell", {})) if not context.is_empty() else _type_multiplier(attacker, defender)
	var base_atk: int = int(attacker.atk)
	if attacker.status.atk_down > 0:
		base_atk = int(round(base_atk * (1.0 - attacker.status.atk_down)))
		_log_step("%s shakes off the weakness." % attacker.name, func(): attacker.status.atk_down = 0)
	if attacker.status.atk_boost > 0:
		base_atk = int(round(base_atk * (1.0 + attacker.status.atk_boost)))
		_log_step("%s expends the surge." % attacker.name, func(): attacker.status.atk_boost = 0)
	var dmg: int = max(1, int(round((base_atk - int(defender.def * 0.5)) * mult * power_mult)))
	if defender.status.vuln_pct > 0:
		dmg = int(round(dmg * (1.0 + defender.status.vuln_pct)))
		_log_step("%s's vulnerability is consumed." % defender.name, func(): defender.status.vuln_pct = 0)
	if defender.status.shield_pct > 0:
		var dispel := clampf(float(context.get("dispel", 0.0)), 0.0, 1.0)
		var pierce := clampf(float(context.get("pierce", 0.0)), 0.0, 1.0)
		if dispel > 0.0:
			_log_step("%s's shield is weakened." % defender.name, func(): defender.status.shield_pct *= 1.0 - dispel)
		var effective_shield: float = defender.status.shield_pct * (1.0 - dispel) * (1.0 - pierce)
		dmg = int(round(dmg * (1.0 - effective_shield)))
		_log_step("%s's ward shatters." % defender.name, func(): defender.status.shield_pct = 0)
	_log_step("%s hits %s for %d." % [attacker.name, defender.name, dmg], func():
		if not context.is_empty():
			context.actual_damage += mini(int(defender.hp), dmg)
		defender.hp = max(0, defender.hp - dmg)
		_animate_hit(_fighter_sprite(defender), dmg, defender.max_hp)
		if spell_attack and dmg > 0:
			defender.spell_hit_this_exchange = true
	)
	if defender.status.reflect_pct > 0:
		if _try_ignore_reflect(attacker):
			var ir_item := _item_with_effect([attacker.equip_1, attacker.equip_2], "ignore_reflect_chance")
			_log_step("%s nullifies reflect via %s." % [attacker.name, _item_label(ir_item)], func():
				defender.status.reflect_pct = 0
				defender.status.erase("poison_on_reflect")
				_animate_item_effect(attacker, "ignore_reflect_chance")
			)
		else:
			var r := int(round(dmg * defender.status.reflect_pct))
			_log_step("%s reflects %d damage." % [defender.name, r], func():
				attacker.hp = max(0, attacker.hp - r)
				if r > 0:
					_animate_hit(_fighter_sprite(attacker), r, attacker.max_hp)
				if spell_attack and r > 0:
					attacker.spell_hit_this_exchange = true
				defender.status.reflect_pct = 0
				if int(defender.status.get("poison_on_reflect", 0)) > 0:
					attacker.status.poison = maxi(int(attacker.status.poison), int(defender.status.poison_on_reflect))
				defender.status.erase("poison_on_reflect")
			)
	var true_bonus: int = _true_on_hit(attacker)
	if true_bonus > 0:
		var t_item := _item_with_effect([attacker.equip_1, attacker.equip_2], "true_on_hit")
		_log_step("%s's %s adds +%d true damage." % [attacker.name, _item_label(t_item), true_bonus], func():
			if not context.is_empty():
				context.actual_damage += mini(int(defender.hp), true_bonus)
			defender.hp = max(0, defender.hp - true_bonus)
			_animate_item_effect(attacker, "true_on_hit")
			_animate_hit(_fighter_sprite(defender), true_bonus, defender.max_hp)
		)
	var dot_true: int = _dot_on_hit(attacker)
	if dot_true > 0:
		var d_item := _item_with_effect([attacker.equip_1, attacker.equip_2], "dot_true")
		_log_step("%s's %s corrodes for %d." % [attacker.name, _item_label(d_item), dot_true], func():
			if not context.is_empty():
				context.actual_damage += mini(int(defender.hp), dot_true)
			defender.hp = max(0, defender.hp - dot_true)
			_animate_item_effect(attacker, "dot_true")
			_animate_hit(_fighter_sprite(defender), dot_true, defender.max_hp)
		)
		var v_hit: float = _vuln_on_hit(attacker)
		if v_hit > 0.0:
			_log_step("%s is left vulnerable by the corrosion." % defender.name, func():
				defender.status.vuln_pct = max(defender.status.vuln_pct, v_hit)
				_animate_item_effect(attacker, "vuln_on_hit")
			)

	if attacker.type == "vitriol" and randi() % 100 < 30:
		_log_step("%s corrodes %s (Poison)." % [attacker.name, defender.name], func(): defender.status.poison = 2)
	if attacker.type == "mercury" and randi() % 100 < 20:
		_log_step("%s shocks %s (Stun)." % [attacker.name, defender.name], func(): defender.status.stun = 1)
	if attacker.type == "sulfur" and randi() % 100 < 20:
		_log_step("%s sears %s (Atk down)." % [attacker.name, defender.name], func(): defender.status.atk_down = max(defender.status.atk_down, 0.15))
	if attacker.type == "sodium" and randi() % 100 < 20:
		_log_step("%s crystallizes a ward." % attacker.name, func():
			if attacker.status.shield_pct < 0.12:
				_animate_pulse(_fighter_sprite(attacker), Color(0.62, 0.7, 1.0), 1.04)
			attacker.status.shield_pct = max(attacker.status.shield_pct, 0.12)
		)
	if attacker.type == "aether" and randi() % 100 < 20:
		_log_step("%s rends the veil (Vulnerable)." % attacker.name, func(): defender.status.vuln_pct = max(defender.status.vuln_pct, 0.12))
	if attacker.type == "gold" and randi() % 100 < 20:
		_log_step("%s mints 3 HP." % attacker.name, func():
			if attacker.hp < attacker.max_hp:
				_animate_pulse(_fighter_sprite(attacker), Color(0.55, 1.0, 0.65), 1.04)
			attacker.hp = min(attacker.max_hp, attacker.hp + 3)
		)

	if not spell_attack and defender.status.poison > 0:
		defender.status.poison -= 1
		defender.hp = max(0, defender.hp - 2)
		_log("%s suffers poison (2)." % defender.name)
	return true

func _attack_homunculus(attacker: Dictionary, defender: Dictionary) -> void:
	if defender.hp <= 0:
		return
	var stunned_fighter := attacker if _spell_exchange_active else defender
	if stunned_fighter.status.hom_stun > 0:
		_log_step("%s's homunculus is nullified this turn." % stunned_fighter.name, func(): stunned_fighter.status.hom_stun -= 1)
		return
	if not _roll_hit(attacker, defender, 0.95):
		_log_step("%s's homunculus misses %s." % [attacker.name, defender.name], func(): _animate_lunge(_fighter_sprite(attacker, true), 12.0 if is_same(attacker, player) else -12.0, false))
		return
	var hom_dmg: int = max(1, int(round(attacker.atk * 0.4)))
	var track_hit := _spell_exchange_active
	_log_step("%s's homunculus strikes %s for %d." % [attacker.name, defender.name, hom_dmg], func():
		_animate_lunge(_fighter_sprite(attacker, true), 12.0 if is_same(attacker, player) else -12.0, false)
		defender.hp = max(0, defender.hp - hom_dmg)
		_animate_hit(_fighter_sprite(defender), hom_dmg, defender.max_hp)
		if track_hit:
			defender.spell_hit_this_exchange = true
	)

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
		_refresh_spell_buttons()
		return
	if _is_duplicate_swap(player, item):
		_log_immediate("Swap canceled: duplicate item.")
		_swap_pending = false
		swap_panel.visible = false
		_refresh_spell_buttons()
		return
	player.equip_1 = item
	player.mods = _item_mods([player.equip_1, player.equip_2])
	_apply_mods(player)
	_swap_pending = false
	swap_panel.visible = false
	_log_immediate("Swapped in %s." % _item_label(item))
	_update_ui()
	_refresh_spell_buttons()

func _on_swap_cancel() -> void:
	if not _swap_pending:
		return
	_swap_pending = false
	swap_panel.visible = false
	_log_immediate("Swap canceled.")
	_refresh_spell_buttons()

func _on_swap_icon_input(event: InputEvent, which: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_swap_chosen(which)

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
	if player.hp <= 0 or enemy.hp <= 0:
		_handle_battle_end()

func _handle_battle_end() -> void:
	if _battle_over:
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

	if _player_wins >= 2 or _enemy_wins >= 2:
		if _player_wins > _enemy_wins:
			_log_immediate("Match win.")
		elif _enemy_wins > _player_wins:
			_log_immediate("Match loss.")
		else:
			_log_immediate("Match draw.")
		_battle_over = true
		next_turn_btn.text = "Return"
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
		next_turn_btn.text = "Return"
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
	_swap_pending = false
	_processing_steps = false
	_spell_exchange_active = false
	_spell_acts_second = false
	next_turn_btn.hide()
	_step_queue.clear()
	swap_panel.visible = false
	_reset_fighter(player)
	_reset_fighter(enemy)

func _reset_fighter(f: Dictionary) -> void:
	f.hp = f.max_hp
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
	var neutralize := maxf(float(attacker.get("spell_neutralize_active", 0.0)), float(defender.get("spell_neutralize_active", 0.0)))
	return 1.0 + (multiplier - 1.0) * (1.0 - neutralize)

func _type_multiplier(attacker: Dictionary, defender: Dictionary) -> float:
	_ensure_type_effectiveness()
	var row: Dictionary = _type_effectiveness.get(str(attacker.type), {})
	var relationship := float(row.get(str(defender.type), 1.0))
	var multiplier := 1.0
	if relationship > 1.0:
		multiplier = 1.12
	elif relationship < 1.0:
		var red: float = float(attacker.item_fx.get("disadvantage_reduction", 0.0))
		if red > 0.0:
			var d_item := _item_with_effect([attacker.equip_1, attacker.equip_2], "disadvantage_reduction")
			_log("%s steadies the disadvantage via %s." % [attacker.name, _item_label(d_item)])
		multiplier = min(0.92 + red, 1.0)
	var neutralize := maxf(float(attacker.get("spell_neutralize_active", 0.0)), float(defender.get("spell_neutralize_active", 0.0)))
	return 1.0 + (multiplier - 1.0) * (1.0 - neutralize)

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
	if f.item_fx.get("ward_pct", 0.0) > 0.0:
		var ward: float = float(f.item_fx.get("ward_pct", 0.0))
		_log_step("%s forms a ward via %s." % [f.name, _item_label(_item_with_effect([f.equip_1, f.equip_2], "ward_pct"))], func():
			if ward > f.status.shield_pct:
				_animate_item_effect(f, "ward_pct")
				_animate_pulse(_fighter_sprite(f), Color(0.62, 0.7, 1.0), 1.04)
			f.status.shield_pct = max(f.status.shield_pct, ward)
		)
	if f.item_fx.get("reflect_pct", 0.0) > 0.0:
		var refl: float = float(f.item_fx.get("reflect_pct", 0.0))
		_log_step("%s readies a mirror from %s." % [f.name, _item_label(_item_with_effect([f.equip_1, f.equip_2], "reflect_pct"))], func():
			if refl > f.status.reflect_pct:
				_animate_item_effect(f, "reflect_pct")
				_animate_pulse(_fighter_sprite(f), Color(0.8, 0.65, 1.0), 1.04)
			f.status.reflect_pct = max(f.status.reflect_pct, refl)
		)

func _apply_tempo_win_bonus(f: Dictionary, _is_player: bool) -> void:
	var tempo: float = float(f.item_fx.get("tempo_on_win", 0.0))
	if tempo <= 0.0:
		return
	_log_step("%s accelerates via %s." % [f.name, _item_label(_item_with_effect([f.equip_1, f.equip_2], "tempo_on_win"))], func():
		f.status.tempo_bonus = tempo
		_animate_item_effect(f, "tempo_on_win")
	)

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
	_reset_animations()

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
	for i in 2:
		var item: Dictionary = fighter.get("equip_%d" % (i + 1), {})
		if item.get("effects", {}).has(effect):
			_animate_pulse(slots[i], Color.WHITE, 1.12)

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
	return maxi(1, _turn)

func _scroll_log_to_bottom() -> void:
	await get_tree().process_frame
	var lc := log_box.get_line_count()
	if lc > 0:
		log_box.scroll_to_line(lc - 1)

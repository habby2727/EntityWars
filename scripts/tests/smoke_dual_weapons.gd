extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		push_error("DUAL_WEAPONS_FAIL: " + message)
		quit(1)
		assert(false, message)

func _run() -> void:
	var output := OS.get_environment("DUAL_WEAPONS_DIR").replace("\\", "/")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/"):
		quit(1)
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var data := {"entity_id": "sulfur_01", "homunculus_id": scene.player.hom_id, "equip_1": "bismuth_talisman", "equip_2": "wind_amulet", "side_1": "mirror_sigel", "side_2": "vitriol_vial"}
	scene.player = scene._build_fighter(data, true)
	scene._update_ui()
	scene._refresh_spell_buttons()
	_check(scene.switch_weapon_btn.visible and not scene.switch_weapon_btn.disabled and scene.switch_weapon_btn.pressed.is_connected(Callable(scene, "_on_switch_weapon")), "switch button")
	var player: Dictionary = scene.player
	var enemy: Dictionary = scene.enemy
	var before_atk: int = player.atk
	_check(scene._get_active_weapon(player).id == "bismuth_talisman", "legacy primary")
	_check(int(player.item_fx.true_on_hit) == 1 and float(player.item_fx.evasion_pct) == 0.0 and float(player.item_fx.reflect_pct) == 0.0, "inactive effects")
	_check(scene._initiative(player) == 10.0, "inactive initiative")
	var hp: int = player.hp
	scene._weapon_defense(player, "shield_pct", 0.12)
	scene._other_defense(player, "shield_pct", 0.08)
	scene._set_active_weapon(player, 2)
	_check(player.atk == before_atk and player.hp == hp, "switch stats or hp")
	_check(is_equal_approx(float(player.status.shield_pct), 0.08), "spell shield preservation")
	_check(is_equal_approx(float(player.item_fx.evasion_pct), 0.08) and int(player.item_fx.true_on_hit) == 0, "switch effects")
	_check(scene._initiative(player) == 11.0, "active initiative")
	player.spell_cooldowns = {"test": 2}
	var enemy_hp: int = enemy.hp
	await scene._resolve_spell_action(player, enemy, {"kind": "switch", "slot": 1})
	_check(player.active_weapon_slot == 1 and enemy.hp == enemy_hp and player.spell_cooldowns.test == 1, "switch action")
	player.status.stun = 1
	await scene._resolve_spell_action(player, enemy, {"kind": "switch", "slot": 2})
	_check(player.active_weapon_slot == 1 and player.status.stun == 0, "stun bypass")
	player.hp = player.max_hp
	enemy.hp = enemy.max_hp
	player.status.poison = 2
	player.spell_cooldowns = {"test": 2}
	var turn: int = scene._turn
	var spell: Dictionary = scene._reg.get_spell_by_id("ash_temper")
	await scene._resolve_spell_exchange({"kind": "switch", "slot": 2}, {"kind": "spell", "spell": spell})
	_check(scene._turn == turn + 1 and player.active_weapon_slot == 2 and player.spell_cooldowns.test == 1, "exchange timing")
	_check(enemy.hp == enemy.max_hp and float(enemy.status.atk_boost) > 0.0 and player.hp < player.max_hp and player.status.poison == 1, "enemy action or poison")
	enemy.equip_2 = scene._find_by_id(scene._items, "mirror_sigel")
	var player_hp: int = player.hp
	await scene._resolve_spell_action(enemy, player, {"kind": "switch", "slot": 2})
	_check(enemy.active_weapon_slot == 2 and player.hp == player_hp, "npc switch action")
	enemy.equip_1 = scene._find_by_id(scene._items, "wind_amulet")
	enemy.equip_2 = scene._find_by_id(scene._items, "saltstone_charm")
	enemy.equip_2 = enemy.equip_2.duplicate(true)
	enemy.equip_2.effects.guard_flat = [2]
	enemy.active_weapon_slot = 1
	enemy.npc_weapon_switched = false
	enemy.hp = int(enemy.max_hp * 0.4)
	_check(scene._choose_npc_action().get("kind") == "switch", "npc defensive choice")
	enemy.npc_weapon_switched = true
	_check(scene._choose_npc_action().get("kind") != "switch", "npc repeat switch")
	scene._set_active_weapon(player, 1)
	scene._round = 2
	player.hp = player.max_hp
	enemy.hp = maxi(1, int(enemy.hp) - 1)
	scene._apply_round_winner_tempo()
	_check(not scene.has_node("SwapPanel") and player.active_weapon_slot == 1 and not player.has("side_1"), "free round swap")
	scene._set_active_weapon(player, 2)
	scene._reset_fighter(player)
	_check(player.active_weapon_slot == 2, "weapon persisted across battles")
	var helper = load("res://scripts/domain/item_progress.gd")
	scene._ensure_type_effectiveness()
	for source in scene._type_effectiveness:
		for target in scene._type_effectiveness[source]:
			if float(scene._type_effectiveness[source][target]) > 1.0:
				_check(scene._type_advantage(source) == target, "NPC type matrix")
	_check(scene._type_advantage("mercury") == "gold" and scene._type_advantage("aether") == "sulfur", "NPC type examples")
	var names := ["Bismuth Sword", "Wind Spear", "Saltstone Hammer", "Mirror Blade", "Vitriol Dagger", "Gilded Wardblade", "Mercury Sabre", "Aether Edge"]
	_check(scene._items.size() == 8, "catalog size")
	for i in 8:
		var item: Dictionary = scene._items[i]
		_check(item.name == names[i] and scene._load_item_icon(item) != null, "name or image " + str(item.id))
		for level in 11:
			var effective: Dictionary = helper.effective_item(item, {item.id: {"level": level}})
			for key in item.effects:
				var values: Array = item.effects[key]
				var expected: Variant = item.base_effects[key] if level == 0 and values.size() == 10 else values[clampi(level - 1, 0, values.size() - 1)]
				_check(effective.effects[key][0] == expected, "forge progression")
	print("PASS dual weapons: legacy slots, active effects, switching, stun, rounds, levels and icons")
	scene.queue_free()
	await process_frame
	quit(0)

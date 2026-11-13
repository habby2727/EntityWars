extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("ULTRATURN_FAIL: " + message)
		quit(1)
		assert(false, message)

func _spell(id: String, category: String, power: float, effects: Array = [], accuracy: float = 1.0) -> Dictionary:
	return {"id": id, "name": id, "type": "sulfur", "category": category, "power_mult": power, "accuracy": accuracy, "cooldown_turns": 0, "effects": effects}

func _run() -> void:
	var output := OS.get_environment("ULTRA_TEST_DIR").replace("\\", "/")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/"):
		quit(1)
		return
	Engine.time_scale = 25.0
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var parent: Node = root
	var viewport: SubViewport
	var dimensions := OS.get_environment("ULTRA_TEST_SIZE").split("x")
	if dimensions.size() == 2:
		viewport = SubViewport.new()
		viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		parent = viewport
	var scene = load("res://scenes/Combat.tscn").instantiate()
	parent.add_child(scene)
	await process_frame
	await process_frame
	var player: Dictionary = scene.player
	var enemy: Dictionary = scene.enemy
	_check(not scene._ultra_available(player), "early availability")
	scene._refresh_spell_buttons()
	_check(not scene.ultra_button.visible, "early UI")
	scene._battle_index = 3
	scene._player_wins = 1
	scene._enemy_wins = 0
	_check(not scene._ultra_available(player), "wrong score")
	scene._enemy_wins = 1
	scene._sudden_death = true
	_check(not scene._ultra_available(player), "sudden death")
	scene._sudden_death = false
	_check(scene._ultra_available(player), "deciding battle")
	scene._turn = 4
	_check(scene._npc_should_ultra(_spell("npc_test", "attack", 0.8)), "npc late activation")
	scene._turn = 0
	var switched := {"kind": "switch", "ultra": true}
	scene._commit_ultra(player, switched)
	_check(not switched.ultra and not player.ultra_used, "switch consumed ultra")
	var attack := _spell("attack_test", "attack", 1.0)
	player.atk = 20
	enemy.def = 8
	player.max_hp = 500
	player.hp = 500
	enemy.max_hp = 500
	enemy.hp = 500
	enemy.item_fx.evasion_pct = 0.0
	player.item_fx.true_on_hit = 0
	player.item_fx.dot_true = 0
	seed(1)
	scene._execute_spell(player, enemy, attack)
	await scene._flush_steps()
	var normal: int = 500 - int(enemy.hp)
	_check(normal > 0, "normal hit")
	enemy.hp = 500
	enemy.status.vuln_pct = 0
	player.status.atk_down = 0
	player.status.atk_boost = 0
	player.item_fx.true_on_hit = 1
	seed(1)
	scene._execute_spell(player, enemy, attack, true)
	await scene._flush_steps()
	_check(500 - int(enemy.hp) == normal * 2 + 1, "direct damage or weapon proc")
	player.item_fx.true_on_hit = 0
	player.hp = 400
	enemy.status.poison = 0
	player.inspiration = 0
	var support := _spell("support_test", "support", 0, [
		{"kind": "heal", "value": 11, "target": "self"},
		{"kind": "shield", "value": 0.24, "target": "self"},
		{"kind": "atk_down", "value": 0.12, "target": "enemy"},
		{"kind": "poison", "value": 2, "target": "enemy"},
		{"kind": "hom_stun", "value": 1, "target": "enemy"},
		{"kind": "recoil", "value": 3, "target": "self"}])
	scene._execute_spell(player, enemy, support, true)
	await scene._flush_steps()
	_check(player.hp == 416 and is_equal_approx(float(player.status.shield_pct), 0.48), "heal, recoil or shield")
	_check(is_equal_approx(float(enemy.status.atk_down), 0.24) and enemy.status.poison == 4 and enemy.status.hom_stun == 2, "debuff scaling")
	_check(player.inspiration == 3, "one inspiration per status")
	player.inspiration = 0
	player.inspiration_pending = false
	enemy.status.poison = 0
	scene._execute_spell(player, enemy, _spell("poison_only", "support", 0, [{"kind": "poison", "value": 2, "target": "enemy"}]), true)
	await scene._flush_steps()
	_check(player.inspiration == 1 and enemy.status.poison == 4, "one point for boosted poison")
	player.status.shield_pct = 0.0
	scene._spell_acts_second = true
	scene._execute_spell(player, enemy, _spell("ordered_shield", "support", 0, [{"kind": "shield_by_order", "value": 0.1, "second_value": 0.2, "target": "self"}]), true)
	await scene._flush_steps()
	_check(is_equal_approx(float(player.status.shield_pct), 0.4), "ordered shield")
	scene._spell_acts_second = false
	player.status.shield_pct = 0.0
	player.hp = 400
	enemy.hp = 500
	var leech := _spell("leech_test", "attack", 1.0, [{"kind": "life_leech", "value": 0.5, "max_heal": 3, "target": "self"}])
	seed(1)
	scene._execute_spell(player, enemy, leech, true)
	await scene._flush_steps()
	_check(player.hp == 406, "life leech cap")
	var action := {"kind": "spell", "spell": _spell("miss_test", "support", 0, [], 0.0), "ultra": true}
	scene._commit_ultra(player, action)
	await scene._resolve_spell_action(player, enemy, action)
	_check(player.ultra_used and not scene._ultra_available(player), "miss or repeated use")
	player.ultra_used = false
	player.status.stun = 1
	action = {"kind": "spell", "spell": attack, "ultra": true}
	scene._commit_ultra(player, action)
	await scene._resolve_spell_action(player, enemy, action)
	_check(player.ultra_used and player.status.stun == 0, "stun consumed ultra")
	player.status.poison = 1
	var hp_before_dot: int = player.hp
	scene._apply_spell_poison(player)
	await scene._flush_steps()
	_check(hp_before_dot - int(player.hp) == 2, "poison tick scaled")
	enemy.hp = 500
	enemy.status.hom_stun = 0
	seed(1)
	scene._attack_homunculus(player, enemy)
	await scene._flush_steps()
	_check(500 - int(enemy.hp) == maxi(1, roundi(float(player.atk) * 0.4)), "homunculus damage scaled")
	player.ultra_used = false
	enemy.ultra_used = false
	player.hp = 500
	enemy.hp = 500
	player.hom_energy = 0
	enemy.hom_energy = 0
	var player_action := {"kind": "spell", "spell": attack, "ultra": true, "hom": "hold"}
	var enemy_action := {"kind": "spell", "spell": attack, "ultra": true, "hom": "hold"}
	scene._commit_ultra(player, player_action)
	scene._commit_ultra(enemy, enemy_action)
	_check(scene._highlights.ultraturn_actors == ["player", "enemy"], "both ultraturn highlights")
	scene._show_highlights()
	var highlight_panel: Node = scene.get_child(scene.get_child_count() - 1)
	var highlighted := ""
	for label in highlight_panel.find_children("*", "Label", true, false):
		highlighted += label.text
	_check(highlighted.count("used Ultraturn") == 2, "both activations shown")
	var previous_turn: int = scene._turn
	seed(1)
	await scene._resolve_spell_exchange(player_action, enemy_action)
	_check(scene._turn == previous_turn + 1 and player.ultra_used and enemy.ultra_used and player.hom_energy == 1 and enemy.hom_energy == 1, "shared exchange")
	scene._reset_fighter(player)
	_check(player.ultra_used, "reset within match")
	player.ultra_used = false
	scene._ultra_armed = true
	scene._refresh_spell_buttons()
	_check(scene.ultra_button.visible and not scene.ultra_button.disabled and scene.ultra_button.button_pressed, "armed UI")
	if viewport != null:
		await process_frame
		await process_frame
		var path := "%s/ultraturn_%s.png" % [output, OS.get_environment("ULTRA_TEST_SIZE")]
		_check(viewport.get_texture().get_image().save_png(path) == OK, "capture")
	print("PASS ultraturn availability, damage, effects, consumption, exchange and UI")
	Engine.time_scale = 1.0
	scene.queue_free()
	await process_frame
	quit(0)

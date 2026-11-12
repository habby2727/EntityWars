extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		push_error("HOM_ENERGY_FAIL: " + message)
		quit(1)
		assert(false, message)

func _run() -> void:
	var output := OS.get_environment("HOM_TEST_DIR").replace("\\", "/")
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
	var player: Dictionary = scene.player
	var enemy: Dictionary = scene.enemy
	player.hom_energy = 0
	_check(not scene._hom_ready(player), "zero charge")
	await scene._resolve_hom_choice(player, enemy, "attack")
	await scene._resolve_hom_choice(player, enemy, "sacrifice")
	_check(player.hom_energy == 0 and not player.hom_spent, "unready actions")
	for i in 6:
		scene._charge_homunculus(player)
		_check(player.hom_energy == i + 1 and scene._hom_ready(player) == (i >= 2), "charge threshold")
	await scene._flush_steps()
	await scene._resolve_hom_choice(player, enemy, "hold")
	_check(player.hom_energy == 6, "hold")
	var old_hp: int = enemy.hp
	seed(1)
	await scene._resolve_hom_choice(player, enemy, "attack")
	_check(player.hom_energy == 0 and old_hp - int(enemy.hp) == maxi(1, roundi(float(player.atk) * 0.6)), "overcharged attack")
	enemy.hp = enemy.max_hp
	player.hom_energy = 3
	seed(1)
	await scene._resolve_hom_choice(player, enemy, "attack")
	_check(player.hom_energy == 0 and int(enemy.max_hp) - int(enemy.hp) == maxi(1, roundi(float(player.atk) * 0.4)), "ready attack")
	player.hom_energy = 3
	player.equip_1 = scene._find_by_id(scene._items, "bismuth_talisman")
	player.equip_2 = scene._find_by_id(scene._items, "wind_amulet")
	player.active_weapon_slot = 1
	scene._refresh_weapon_stats(player)
	enemy.hp = enemy.max_hp
	var previous_turn: int = scene._turn
	await scene._queue_combat_action({"kind": "switch", "slot": 2})
	_check(scene.hom_decision.visible and not scene._pending_hom_action.is_empty() and scene.switch_weapon_btn.disabled, "decision row")
	scene.get_node("HomDecision/Hold").pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while scene._resolving_exchange and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not scene._resolving_exchange and player.active_weapon_slot == 2 and scene._turn == previous_turn + 1 and player.hom_energy == 4, "hold with weapon switch")
	player.hp = player.max_hp - 11
	player.hom_energy = 3
	await scene._resolve_hom_choice(player, enemy, "sacrifice")
	_check(player.hp == player.max_hp and player.hom_spent and player.hom_energy == 0 and scene._highlights.has("sacrifice"), "sacrifice cap")
	scene._reset_fighter(player)
	scene._charge_homunculus(player)
	await scene._resolve_hom_choice(player, enemy, "attack")
	_check(player.hom_spent and player.hom_energy == 0 and not scene._hom_ready(player), "sacrifice across rounds")
	enemy.hom_energy = 3
	enemy.hp = enemy.max_hp - 40
	var enemy_hp: int = enemy.hp
	await scene._resolve_hom_choice(enemy, player, "sacrifice")
	_check(enemy.hp == enemy_hp + 30 and enemy.hom_spent, "full sacrifice healing")
	enemy.hom_spent = false
	enemy.hom_energy = 2
	_check(scene._choose_npc_hom_action() == "hold", "npc below threshold")
	enemy.hom_energy = 6
	enemy.hp = enemy.max_hp
	_check(scene._choose_npc_hom_action() == "attack", "npc overcharge")
	scene._update_ui()
	_check(not scene.player_hom.visible and scene._player_hom_status.tooltip_text.contains("6") and scene._player_hom_status.tooltip_text.contains("30 HP"), "ui or tooltip")
	print("PASS hom energy, attack, overcharge, hold, sacrifice, persistence, npc and UI")
	scene.queue_free()
	await process_frame
	quit(0)

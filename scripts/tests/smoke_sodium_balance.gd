extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("BALANCE_TEST_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		push_error("isolated user directory required")
		quit(1)
		return
	Engine.time_scale = 20.0
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var registry := DataRegistry.new()
	var brine: Dictionary = registry.get_spell_by_id("brine_mend")
	var barrier: Dictionary = registry.get_spell_by_id("salt_barrier")
	assert(not brine.is_empty() and not barrier.is_empty())
	var fighter: Dictionary = scene.player
	var target: Dictionary = scene.enemy
	fighter.hp = fighter.max_hp - 8
	fighter.hom_spent = true
	target.hom_spent = true
	target.status.shield_pct = 0.5
	var original_target_hp := int(target.hp)
	scene._turn = 1
	scene._execute_spell(fighter, target, brine)
	await scene._flush_steps()
	assert(int(fighter.hp) == int(fighter.max_hp))
	assert(int(target.hp) == original_target_hp - 8)
	fighter.spell_cooldowns.clear()
	target.hp = 5
	fighter.hp = fighter.max_hp
	scene._execute_spell(fighter, target, brine)
	await scene._flush_steps()
	assert(int(target.hp) == 5 and int(fighter.hp) == int(fighter.max_hp))
	fighter.spell_cooldowns.clear()
	fighter.hp = fighter.max_hp - 20
	scene._execute_spell(fighter, target, brine)
	await scene._flush_steps()
	assert(int(target.hp) == 0 and int(fighter.hp) == int(fighter.max_hp) - 15)
	target.hp = target.max_hp
	fighter.spell_cooldowns.clear()
	scene._execute_spell(fighter, target, barrier)
	await scene._flush_steps()
	assert(is_equal_approx(scene._timed_defense(fighter, "shield_pct"), 0.24))
	assert(is_equal_approx(scene._timed_defense(fighter, "reflect_pct"), 0.5))
	fighter.hp = 1000
	fighter.max_hp = 1000
	target.hp = 1000
	target.max_hp = 1000
	target.atk = 100
	target.hom_spent = false
	target.hom_id = "cinder"
	target.hom_name = "Cinder"
	target.status.hom_stun = 0
	fighter.status.hom_stun = 0
	var hits := 0
	for attempt in 10:
		var before := int(target.hp)
		scene._attack_homunculus(target, fighter)
		await scene._flush_steps()
		if int(target.hp) < before: hits += 1
		if hits == 2: break
	assert(hits == 2)
	assert(is_equal_approx(scene._timed_defense(fighter, "reflect_pct"), 0.5))
	for turn in [1, 2, 3]:
		scene._turn = turn
		assert(is_equal_approx(scene._timed_defense(fighter, "shield_pct"), 0.24))
		assert(is_equal_approx(scene._timed_defense(fighter, "reflect_pct"), 0.5))
		scene._end_spell_exchange()
	assert(is_zero_approx(scene._timed_defense(fighter, "shield_pct")))
	assert(is_zero_approx(scene._timed_defense(fighter, "reflect_pct")))
	registry.free()
	print("PASS Practice sodium drain and barrier")
	quit(0)

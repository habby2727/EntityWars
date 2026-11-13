extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		push_error("HOM_COMBAT_FAIL: " + message)
		quit(1)
		assert(false, message)

func _run() -> void:
	var directory := OS.get_environment("HOM_COMBAT_TEST_ROOT").replace("\\", "/").to_lower()
	if directory.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(directory + "/"):
		quit(1)
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._combat_spell_state["homunculus_progress"] = {"cinder": {"level": 10, "mutation_id": "vitality"}}
	var data := {"entity_id": "sulfur_01", "homunculus_id": "cinder", "equip_1": "bismuth_talisman", "equip_2": "wind_amulet"}
	scene.player = scene._build_fighter(data, true)
	var player: Dictionary = scene.player
	var npc: Dictionary = scene._build_fighter(data, false)
	_check(int(player.max_hp) == int(npc.max_hp) + 15 and int(player.atk) - int(player.mods.atk_flat) == int(npc.atk) - int(npc.mods.atk_flat) + 2 and int(player.def) - int(player.mods.def_flat) == int(npc.def) - int(npc.mods.def_flat) + 3, "progress and NPC isolation")
	var before := player.duplicate(true)
	scene._set_active_weapon(player, 2)
	scene._set_active_weapon(player, 1)
	_check(player.atk == before.atk and player.def == before.def and player.max_hp == before.max_hp, "weapon switching stacks")
	_check(int(player.hom_synergy.power_flat) == 3, "entity type synergy")
	var catalyst: Dictionary = scene._combat_spell_state.homunculus_progress.cinder
	catalyst.mutation_id = "catalyst"
	var improved: Dictionary = scene._build_fighter(data, true)
	_check(int(improved.atk) == int(player.atk) + 1, "catalyst")
	catalyst.mutation_id = "resonance"
	var resonant: Dictionary = scene._build_fighter(data, true)
	_check(is_equal_approx(scene._hom_advantage_bonus(resonant), 0.03), "resonance")
	_check(is_equal_approx(scene._spell_multiplier(resonant, npc, {"type": "universal"}), 1.0), "universal neutrality")
	scene._ensure_type_effectiveness()
	var favorable_source := ""
	var favorable_target := ""
	for source in scene._type_effectiveness:
		for target in scene._type_effectiveness[source]:
			if float(scene._type_effectiveness[source][target]) > 1.0:
				favorable_source = source
				favorable_target = target
				break
		if favorable_source != "":
			break
	resonant.type = favorable_source
	npc.type = favorable_target
	_check(is_equal_approx(scene._type_multiplier(resonant, npc, false), 1.15), "favorable resonance")
	npc.type = favorable_source
	_check(is_equal_approx(scene._type_multiplier(resonant, npc, false), 1.0), "neutral resonance")
	var scaled: Dictionary = scene._scaled_hom_weapon({"effects": {"power_flat": [10], "ward_pct": [0.2]}}, {"item_effect_mult": 1.05})
	_check(is_equal_approx(float(scaled.effects.power_flat[0]), 10.5) and is_equal_approx(float(scaled.effects.ward_pct[0]), 0.21), "weapon multiplier")
	player.hom_energy = 3
	await scene._resolve_hom_choice(player, npc, "sacrifice")
	_check(player.hom_spent and player.max_hp == npc.max_hp - int(npc.hom_data.buff_hp) and scene._hom_synergy(player).is_empty(), "sacrifice removes bonuses")
	scene._reset_fighter(player)
	_check(player.hom_spent and scene._hom_synergy(player).is_empty(), "sacrifice persists between battles")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene._on_hom_details_input(click, true)
	_check(scene._hom_details.visible and scene._hom_details._owner_name == "Player", "player panel")
	scene._on_hom_details_input(click, false)
	_check(scene._hom_details.visible and scene._hom_details._owner_name == "NPC", "NPC panel")
	var close: Button = scene._hom_details.find_children("*", "Button", true, false)[0]
	close.pressed.emit()
	_check(not scene._hom_details.visible, "close panel")
	print("HOM_COMBAT_PASS")
	scene.queue_free()
	await process_frame
	quit(0)

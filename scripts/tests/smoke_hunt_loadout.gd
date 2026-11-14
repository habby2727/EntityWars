extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_dir := OS.get_environment("HUNT_TEST_ROOT").replace("\\", "/").to_lower()
	if root_dir.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(root_dir + "/"):
		push_error("Isolated user directory required")
		quit(1)
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	change_scene_to_file("res://scenes/ui/WorldZoneChaos.tscn")
	await process_frame
	await process_frame
	var zone = current_scene
	zone._show_debug_boss(2)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	zone._preview_stage.get_child(2).get_child(0).gui_input.emit(click)
	assert(zone._debug_fight.visible and not zone._debug_fight.disabled)
	var texture_path: String = zone._debug_visual.texture
	zone._start_debug_hunt()
	await process_frame
	await process_frame
	var loadout = current_scene
	assert(loadout != null and loadout._hunt_mode)
	assert(not loadout.btn_save.is_visible_in_tree() and not loadout.btn_seal_attack.is_visible_in_tree())
	loadout._current_entity_id = str(loadout._entities[1].id)
	loadout._current_homunculus_id = str(loadout._homunculi[1].id)
	var entity_id: String = loadout._current_entity_id
	var hom_id: String = loadout._current_homunculus_id
	var weapon_id: String = loadout._idx_to_id(loadout._items, loadout.dd_item1)
	var weapon2: String = loadout._idx_to_id(loadout._items, loadout.dd_item2)
	var before: Dictionary = loadout._spell_debug.load_lab_state()
	var spells: Array = loadout._equipped_spells("attack", entity_id)
	spells.reverse()
	loadout._spell_draft = spells.duplicate()
	loadout._confirm_spell_dialog()
	assert(loadout._equipped_spells("attack", entity_id) == spells)
	assert(loadout._spell_debug.load_lab_state() == before)
	loadout._on_play_pressed()
	await process_frame
	await process_frame
	var combat = current_scene
	assert(combat != null and combat._solo_boss_mode)
	assert(combat._solo_context.visual_zone_id == "zone_chaos")
	assert(combat._solo_texture != null and combat._solo_texture.resource_path == texture_path)
	combat._update_ui()
	assert(combat.enemy_entity.texture.resource_path == texture_path)
	assert(combat.player.id == entity_id)
	assert(combat.player.hom_id == hom_id)
	assert(str(combat.player.equip_1.get("id", "")) == weapon_id)
	assert(str(combat.player.equip_2.get("id", "")) == weapon2)
	assert(combat.player.spell_ids == spells)
	assert(not FileAccess.file_exists("user://seal_attack.json"))
	var key := SceneRouter.debug_guardian_key("zone_chaos", 2, "preview_common_0")
	combat.player.hp = 0
	combat._handle_battle_end()
	assert(not SceneRouter._debug_guardian_wins.has(key))
	combat._battle_over = false
	combat.player.hp = combat.player.max_hp
	combat.enemy.hp = 0
	combat._handle_battle_end()
	assert(SceneRouter._debug_guardian_wins.has(key))
	combat._on_next_turn()
	await process_frame
	await process_frame
	assert(current_scene is WorldZone and current_scene.zone_id_override == "zone_chaos")
	current_scene._show_debug_boss(2)
	await process_frame
	assert(current_scene._preview_stage.get_child_count() == 4)
	current_scene._preview_stage.get_child(0).get_child(0).gui_input.emit(click)
	assert(current_scene._debug_fight.disabled)
	current_scene._world_modal.visible = false
	SceneRouter._debug_guardian_wins[SceneRouter.debug_guardian_key("zone_chaos", 2, "preview_higher")] = true
	SceneRouter._debug_guardian_wins[SceneRouter.debug_guardian_key("zone_chaos", 2, "preview_common_1")] = true
	current_scene._show_debug_boss(2)
	await process_frame
	current_scene._preview_stage.get_child(0).get_child(0).gui_input.emit(click)
	assert(not current_scene._debug_fight.disabled)
	print("PASS hunt loadout, boss session and selections")
	quit(0)

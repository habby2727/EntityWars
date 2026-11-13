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
	SceneRouter.go_to_solo_hunt("hunt_common", 1, "", "", "zone_chaos")
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
	loadout._on_play_pressed()
	await process_frame
	await process_frame
	var combat = current_scene
	assert(combat != null and combat._solo_boss_mode)
	assert(combat._solo_context.visual_zone_id == "zone_chaos")
	assert(combat.player.id == entity_id)
	assert(combat.player.hom_id == hom_id)
	assert(str(combat.player.equip_1.get("id", "")) == weapon_id)
	assert(not FileAccess.file_exists("user://seal_attack.json"))
	print("PASS hunt loadout, boss session and selections")
	quit(0)

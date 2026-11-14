extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("COMBAT_VISUAL_DIR").replace("\\", "/")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/"):
		push_error("Visual test requires isolated user data")
		quit(1)
		return
	var debug := FileAccess.open("user://debug.json", FileAccess.WRITE)
	debug.store_string(JSON.stringify({"unlock_all_buildings": true}))
	debug.close()
	var visual_zone := OS.get_environment("COMBAT_VISUAL_ZONE")
	if not visual_zone.is_empty():
		SceneRouter._solo_hunt_context = {"hunt_id": "hunt_legendary", "rotation_key": 1, "visual_zone_id": visual_zone}
		SceneRouter._hunt_loadout = {"entity_id": "sulfur_01", "homunculus_id": "cinder", "equip_1": "bismuth_talisman", "equip_2": "wind_amulet", "spell_ids": ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"]}
	var scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if not scene._combat_started or not scene.spell_buttons[0].visible or scene.spell_buttons[0].disabled:
		push_error("Combat controls unavailable")
		quit(1)
		return
	if not visual_zone.is_empty() and (not scene._solo_boss_mode or not scene.has_node("WorldCombatSprites")):
		push_error("World boss visuals unavailable")
		quit(1)
		return
	if OS.has_environment("COMBAT_ENERGY"):
		scene.player.hom_energy = int(OS.get_environment("COMBAT_ENERGY"))
		scene._update_ui()
		await process_frame
	if OS.has_environment("COMBAT_GUARDIAN_TEXTURE"):
		scene._solo_texture = load(OS.get_environment("COMBAT_GUARDIAN_TEXTURE")) as Texture2D
		scene._solo_def.name = "QA Guardian"
		scene._solo_def.tier = "common"
		scene.enemy.name = "QA Guardian"
		scene._update_ui()
		scene._update_solo_panel()
		if scene.enemy_entity.texture != scene._solo_texture:
			push_error("Guardian texture was not applied")
			quit(1)
			return
		await process_frame
		await process_frame
	var image := root.get_texture().get_image()
	var suffix := OS.get_environment("COMBAT_CAPTURE_NAME")
	if suffix.is_empty():
		suffix = "combat"
	if image == null or image.is_empty() or image.save_png(output + "/" + suffix + ".png") != OK:
		push_error("Cannot capture rendered combat")
		quit(1)
		return
	scene.spell_buttons[0].pressed.emit()
	if scene.hom_decision.visible:
		scene._on_hom_choice("hold")
	if not scene._resolving_exchange:
		push_error("Spell button did not start an exchange")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 15000
	while scene._resolving_exchange and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene._resolving_exchange:
		push_error("Combat exchange timed out")
		quit(1)
		return
	if OS.has_environment("COMBAT_GUARDIAN_TEXTURE") and scene.enemy_entity.texture != scene._solo_texture:
		push_error("Guardian texture changed after exchange")
		quit(1)
		return
	print("PASS rendered combat and spell button signal")
	scene.queue_free()
	await process_frame
	quit(0)

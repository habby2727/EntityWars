extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("DUAL_WEAPONS_DIR").replace("\\", "/")
	var dimensions := OS.get_environment("DUAL_WEAPONS_SIZE").split("x")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/") or dimensions.size() != 2:
		quit(1)
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var combat = load("res://scenes/Combat.tscn").instantiate()
	viewport.add_child(combat)
	await process_frame
	await process_frame
	combat.player = combat._build_fighter({"entity_id": "sulfur_01", "homunculus_id": combat.player.hom_id, "equip_1": "bismuth_talisman", "equip_2": "wind_amulet"}, true)
	combat._update_ui()
	combat._refresh_spell_buttons()
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png(output + "/combat_" + OS.get_environment("DUAL_WEAPONS_SIZE") + ".png")
	combat.queue_free()
	await process_frame
	var loadout = load("res://scenes/LoadoutGrid.tscn").instantiate()
	viewport.add_child(loadout)
	await process_frame
	await process_frame
	loadout.get_node("BuildOverlay").show()
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png(output + "/loadout_" + OS.get_environment("DUAL_WEAPONS_SIZE") + ".png")
	print("PASS dual weapon captures ", viewport.size)
	quit(0)

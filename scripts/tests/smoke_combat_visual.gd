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
	if OS.has_environment("COMBAT_MULTI_STATUS"):
		scene._solo_fury_pending = true
		scene._solo_shield_turns = 2
		scene._solo_summon()
		scene.enemy.status.poison = 2
		scene.enemy.status.stun = 1
		scene._update_solo_panel()
		scene.enemy_indicators.set_fighter(0, scene.enemy)
		var icons: Array = scene.enemy_indicators._visible_effects().map(func(effect): return effect.icon)
		for kind in ["fury", "shield", "minions", "poison", "stun"]:
			if not icons.has(kind):
				push_error("Boss status missing: " + kind)
				quit(1)
				return
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		var slots: Array = scene.enemy_indicators._boss_slots()
		var effects: Array = scene.enemy_indicators._visible_effects()
		for i in slots.size():
			for j in range(i + 1, slots.size()):
				if slots[i].intersects(slots[j]):
					push_error("Boss status slots overlap")
					quit(1)
					return
			click.position = slots[i].get_center()
			if scene.enemy_indicators._get_tooltip(click.position) != effects[i].tooltip:
				push_error("Boss status tooltip target mismatch")
				quit(1)
				return
			scene.enemy_indicators._gui_input(click)
			if not scene._spell_detail.visible or scene._spell_detail.dialog_text != effects[i].tooltip:
				push_error("Boss status click target mismatch")
				quit(1)
				return
			scene._spell_detail.hide()
		scene.enemy_indicators.size.x = 75
		var wrapped: Array = scene.enemy_indicators._boss_slots()
		if wrapped.size() != slots.size() or wrapped.back().position.y <= 0:
			push_error("Boss status wrapping unavailable")
			quit(1)
			return
		click.position = wrapped.back().get_center()
		if scene.enemy_indicators._get_tooltip(click.position) != effects.back().tooltip:
			push_error("Wrapped final status tooltip mismatch")
			quit(1)
			return
		scene.enemy_indicators._gui_input(click)
		if not scene._spell_detail.visible or scene._spell_detail.dialog_text != effects.back().tooltip:
			push_error("Wrapped final status click mismatch")
			quit(1)
			return
		scene._spell_detail.hide()
		scene.enemy_indicators.size.x = 300
		scene.enemy.status.stun = 0
		scene.enemy_indicators.set_fighter(0, scene.enemy)
		if scene.enemy_indicators._boss_slots().size() != slots.size() - 1:
			push_error("Expired status did not update layout")
			quit(1)
			return
		scene.enemy.status.stun = 1
		scene.enemy_indicators.set_fighter(0, scene.enemy)
		scene._solo_power_active = true
		scene._update_solo_panel()
		if scene.player_indicators._extra_effects.is_empty() or scene.player_indicators._extra_effects[0].icon != "power":
			push_error("Power Turn icon missing")
			quit(1)
			return
		scene._solo_power_active = OS.has_environment("COMBAT_POWER_ACTIVE")
		scene._update_solo_panel()
		await process_frame
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

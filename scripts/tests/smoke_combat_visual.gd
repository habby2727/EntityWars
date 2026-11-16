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
	if OS.has_environment("COMBAT_MINION_CASE"):
		var case_name := OS.get_environment("COMBAT_MINION_CASE")
		scene._solo_def.minions = 1 if case_name == "one" else 2
		scene._solo_summon()
		if case_name in ["one_dead", "none"]:
			scene._solo_minions[0].hp = 0
		if case_name == "none":
			scene._solo_minions[1].hp = 0
		scene._update_ui()
		var expected := 0 if case_name == "none" else 1 if case_name in ["one", "one_dead"] else 2
		var shown := 0
		for view in scene._solo_minion_views:
			if view.visible:
				shown += 1
				if view.get_node("Portrait").texture.resource_path != "res://assets/lab/bosses/summoned-boss.png" or not view.get_node("HP").visible:
					push_error("Summoned minion texture or HP missing")
					quit(1)
					return
		if shown != expected or scene.enemy_entity.texture != scene._solo_texture:
			push_error("Summoned minion visibility or boss texture mismatch")
			quit(1)
			return
		if expected > 0:
			var survivor: Dictionary = scene._solo_minions[1] if case_name == "one_dead" else scene._solo_minions[0]
			var original_hp: int = survivor.hp
			survivor.hp = int(survivor.max_hp / 2)
			scene._update_solo_panel()
			var width: float = scene._solo_minion_views[0].get_node("HP/Fill").size.x
			if not is_equal_approx(width, 90.0 * float(survivor.hp) / float(survivor.max_hp)):
				push_error("Summoned minion HP bar did not update")
				quit(1)
				return
			survivor.hp = original_hp
			scene._update_solo_panel()
		await process_frame
	if OS.has_environment("COMBAT_MULTI_STATUS"):
		if not visual_zone.is_empty():
			scene._solo_fury_pending = true
			scene._solo_shield_turns = 2
			scene._solo_summon()
			scene._update_solo_panel()
			var boss_icons: Array = scene.enemy_indicators._visible_effects().map(func(effect): return effect.icon)
			for kind in ["shield", "fury", "minions"]:
				if not boss_icons.has(kind):
					push_error("Boss status missing: " + kind)
					quit(1)
					return
		scene.enemy_indicators.set_boss_effects(true, [
			{"icon": "shield", "label": "50% 2T", "tooltip": "Shield"},
			{"icon": "fury", "label": "150%", "tooltip": "Fury"},
			{"icon": "minions", "label": "2", "tooltip": "Minions"},
		])
		var many := {"poison": 2, "shield_pct": 0.2, "reflect_pct": 0.2, "atk_boost": 0.2, "atk_down": 0.2, "vuln_pct": 0.2, "stun": 1, "hom_stun": 1}
		for indicator in [scene.player_indicators, scene.enemy_indicators]:
			indicator.set_fighter(1, {"status": many})
		for frame in 15:
			await process_frame
		for indicator in [scene.player_indicators, scene.enemy_indicators]:
			var strip := indicator.get_parent() as Control
			var bar: Control = scene.player_hp if indicator == scene.player_indicators else scene.enemy_hp
			var title: Control = scene.get_node("PlayerPanel/PlayerBuildTitle" if indicator == scene.player_indicators else "EnemyPanel/EnemyBuildTitle")
			var items: Control = scene.get_node("PlayerPanel/PlayerItems" if indicator == scene.player_indicators else "EnemyPanel/EnemyItems")
			var rect := strip.get_global_rect()
			var protected: Array = [bar, title, items, scene.next_turn_btn, scene.switch_weapon_btn, scene.log_box]
			protected.append_array(scene.spell_buttons)
			for other in protected:
				if other.is_visible_in_tree() and other.modulate.a > 0.0 and rect.intersects(other.get_global_rect()):
					push_error("Status strip %s intersects %s %s spacer=%s" % [rect, other.get_path(), other.get_global_rect(), scene.get_node("EnemyPanel/EnemyBottomSpacer").custom_minimum_size])
					quit(1)
					return
			if rect.end.y > bar.get_global_rect().position.y or indicator.size.x > strip.size.x:
				push_error("Status strip position or content width incorrect")
				quit(1)
				return
			var clicked: Array = []
			indicator.effect_clicked.connect(func(description): clicked.append(description))
			var slots: Array = indicator._slots()
			for endpoint in [0, slots.size() - 1]:
				await process_frame
				var point: Vector2 = root.get_final_transform() * indicator.get_global_transform_with_canvas() * slots[endpoint].get_center()
				var motion := InputEventMouseMotion.new()
				motion.position = point
				motion.global_position = point
				Input.parse_input_event(motion)
				await process_frame
				var hovered := root.gui_get_hovered_control()
				if hovered != indicator:
					push_error("Pointer did not reach status endpoint: %s point=%s strip=%s indicator=%s" % [hovered, point, strip.get_global_rect(), indicator.get_global_rect()])
					quit(1)
					return
				var expected: String = indicator._get_tooltip(slots[endpoint].get_center())
				if expected.is_empty():
					push_error("Missing endpoint tooltip")
					quit(1)
					return
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				click.position = point
				click.global_position = point
				Input.parse_input_event(click)
				await process_frame
				if clicked.is_empty() or clicked.back() != expected:
					push_error("Pointer click did not open status detail")
					quit(1)
					return
				scene._spell_detail.hide()
				click.pressed = false
				Input.parse_input_event(click)
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
	if OS.has_environment("COMBAT_HOM_DECISION"):
		scene.player.hom_energy = 6
		scene._update_ui()
		scene.spell_buttons[0].pressed.emit()
		for frame in 3:
			await process_frame
		if not scene.hom_decision.visible:
			push_error("Homunculus decision unavailable")
			quit(1)
			return
		var decision_rect: Rect2 = scene.hom_decision.get_global_rect()
		var energy_rect: Rect2 = scene._player_hom_status.get_global_rect()
		if decision_rect.intersects(energy_rect) or absf(decision_rect.get_center().x - energy_rect.get_center().x) > 1.0:
			push_error("Homunculus decision is not centered above energy")
			quit(1)
			return
		for control in [scene.spell_panel, scene.player_hp, scene.player_indicators.get_parent(), scene.log_box]:
			if control.is_visible_in_tree() and decision_rect.intersects(control.get_global_rect()):
				push_error("Homunculus decision intersects " + str(control.get_path()))
				quit(1)
				return
	var image := root.get_texture().get_image()
	var suffix := OS.get_environment("COMBAT_CAPTURE_NAME")
	if suffix.is_empty():
		suffix = "combat"
	if image == null or image.is_empty() or image.save_png(output + "/" + suffix + ".png") != OK:
		push_error("Cannot capture rendered combat")
		quit(1)
		return
	if not OS.has_environment("COMBAT_HOM_DECISION"):
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

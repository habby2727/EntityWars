extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(change_scene_to_file("res://scenes/ui/ExpeditionVisualDebug.tscn") == OK)
	for i in 30:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == SceneRouter.SCENE_EXPEDITIONS: break
	var screen = current_scene
	screen._enter_visual_debug()
	screen._set_visual_debug_view(2)
	screen.visual_inspector.set_phase(1)
	await process_frame
	var view = screen.combat_view
	for entry in [["spell", "player", view.player_sprite], ["spell", "npc", view.enemy_sprite], ["hom_attack", "player", view.player_hom_sprite], ["hom_attack", "npc", view.enemy_hom_sprite]]:
		var sprite: Control = entry[2]
		var initial := sprite.position
		view._animate_event({"kind":entry[0], "actor":entry[1], "spell_id":"cinder_fist"})
		view.animation_tweens[sprite].custom_step(0.06)
		assert(not sprite.position.is_equal_approx(initial))
		view.animation_tweens[sprite].custom_step(0.5)
		assert(sprite.position.is_equal_approx(initial))
	var icon: TextureRect = view.weapon_buttons[1].get_child(1)
	var initial_scale := icon.scale
	view._animate_event({"kind":"switch", "actor":"player", "slot":2})
	view.animation_tweens[icon].custom_step(0.06)
	assert(icon.scale.x > initial_scale.x)
	view.animation_tweens[icon].custom_step(0.5)
	assert(icon.scale.is_equal_approx(initial_scale))
	assert(view.hom_attack.toggle_mode)
	assert(view.hom_attack.get_theme_stylebox("normal") is StyleBoxTexture)
	assert(view.hom_attack.get_theme_stylebox("normal").texture == preload("res://scripts/ui/menu_art.gd")._button_frame("boton-loadout-opciones.png").texture)
	var previous_hp: float = view.enemy_hp.value
	var impact_hp := 5 if previous_hp != 5 else 6
	var before_log: String = view.log.get_parsed_text()
	view.present_events([{"kind":"spell", "actor":"player", "spell_id":"cinder_fist"}, {"kind":"damage", "actor":"player", "target":"npc", "hp":impact_hp, "amount":10}], screen.playback_epoch)
	await create_timer(0.2).timeout
	assert(view.log.get_parsed_text() != before_log and view.enemy_hp.value == previous_hp)
	assert(view.controls.all(func(control): return control.disabled))
	var spell_log: String = view.log.get_parsed_text()
	await create_timer(0.55).timeout
	assert(view.log.get_parsed_text() != spell_log and view.enemy_hp.value == impact_hp)
	assert(view.animation_tweens.has(view.enemy_sprite))
	await create_timer(0.6).timeout
	view.log.meta_clicked.emit("cinder_fist")
	var dialogs: Array = view.find_children("*", "AcceptDialog", true, false)
	assert(dialogs.size() == 1)
	var dialog: AcceptDialog = dialogs[0]
	assert(dialog.borderless and dialog.transparent)
	assert(dialog.dialog_text.begins_with(dialog.title))
	assert(dialog.get_theme_stylebox("embedded_border") is StyleBoxEmpty)
	assert(dialog.get_theme_stylebox("embedded_unfocused_border") is StyleBoxEmpty)
	var capture_path := OS.get_environment("EXPEDITION_PRESENTATION_CAPTURE")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_path)
	print("EXPEDITION_PRESENTATION_PASS")
	quit()

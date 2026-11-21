extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _snapshot() -> Dictionary:
	var result := {}
	var directory := DirAccess.open("user://")
	for file in directory.get_files():
		result[file] = FileAccess.get_file_as_bytes("user://" + file)
	return result

func _run() -> void:
	assert(OS.has_feature("editor"))
	var gate := root.get_node("ConnectionGate")
	var before := _snapshot()
	SceneRouter._expedition_context = {"player_id":"existing-owner", "loadout":true}
	assert(change_scene_to_file("res://scenes/ui/ExpeditionVisualDebug.tscn") == OK)
	for i in 30:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == SceneRouter.SCENE_EXPEDITIONS: break
	assert(is_instance_valid(current_scene) and current_scene.scene_file_path == SceneRouter.SCENE_EXPEDITIONS)
	assert(gate.debug_lab_navigation_allowed())
	var screen = current_scene
	assert(screen.backend == null and is_instance_valid(screen.visual_debug_entry) and screen.visual_debug_entry.visible)
	var lab = load("res://scenes/ui/LabHub.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	assert(lab.has_node("ExpeditionVisualDebug") and lab.get_node("ExpeditionVisualDebug").visible)
	lab.queue_free()
	await process_frame
	screen._enter_visual_debug()
	var inspector = screen.visual_inspector
	assert(screen.visual_debug and inspector.enemies.size() == 21 and inspector.homunculi.size() == 14 and inspector.backgrounds.size() == 26)
	(inspector.find_child("LoadoutPreview", true, false) as Button).pressed.emit()
	await process_frame
	var preview: Node = screen.get_node_or_null("ExpeditionLoadoutPreview")
	assert(preview != null and preview.scene_file_path == "res://scenes/LoadoutGrid.tscn")
	assert(preview._expedition_preview and preview._spell_backend == null and preview.btn_play.disabled)
	var selected_hom: String = preview._current_homunculus_id
	preview._confirm_expedition_start("visual-preview", {})
	var confirmation: ConfirmationDialog = preview.get_node("ExpeditionRiskConfirmation")
	assert(confirmation.visible and confirmation.dialog_text == preview.tr("EXPEDITION_RISK_WARNING"))
	confirmation.canceled.emit()
	assert(preview._current_homunculus_id == selected_hom and not SceneRouter._expedition_context.has("pending_start"))
	preview.queue_free()
	await process_frame
	var source := FileAccess.get_file_as_string("res://backend/src/expeditions_backgrounds.ts")
	var expression := RegEx.new()
	assert(expression.compile('"([A-Za-z0-9_]+\\.ogv)"') == OK)
	var server_keys: Array[String] = []
	for found in expression.search_all(source): server_keys.append(found.get_string(1))
	server_keys.sort()
	assert(server_keys == inspector.backgrounds)
	assert(SceneRouter._expedition_context == {"player_id":"existing-owner", "loadout":true})
	for picker in [inspector.enemy_picker, inspector.hom_picker, inspector.background_picker]:
		var row: Node = picker.get_parent()
		(row.get_child(picker.get_index() - 1) as Button).pressed.emit()
		assert(picker.selected == picker.item_count - 1)
		(row.get_child(picker.get_index() + 1) as Button).pressed.emit()
		assert(picker.selected == 0)
	var capture_mode := not OS.get_environment("EXPEDITION_VISUAL_CAPTURE").is_empty()
	for size in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = size
		for i in (range(1) if capture_mode else range(inspector.enemies.size())):
			inspector.set_phase(0)
			inspector.select_enemy(i)
			await process_frame
			var row: HBoxContainer = screen.body.get_child(0)
			var portrait: TextureRect = row.get_child(0).get_child(0).get_child(0)
			assert(portrait.texture.resource_path == inspector.enemies[i].preview_texture)
			inspector.set_phase(1)
			await process_frame
			assert(screen.combat_view.enemy_sprite.texture.resource_path == inspector.enemies[i].texture)
			assert(screen.combat_view.enemy_sprite.flip_h and not screen.combat_view.player_sprite.flip_h)
			var combat = screen.combat_view
			assert(combat.player_hom_sprite.position.x < combat.player_sprite.position.x)
			assert(combat.enemy_hom_sprite.position.x > combat.enemy_sprite.position.x)
			assert(combat.player_sprite.position.y + combat.player_sprite.size.y == combat.player_hom_sprite.position.y + combat.player_hom_sprite.size.y)
			assert(combat.enemy_sprite.position.y + combat.enemy_sprite.size.y == combat.enemy_hom_sprite.position.y + combat.enemy_hom_sprite.size.y)
			assert(combat.player_hp.size.x == 220 and combat.enemy_hp.size.x == 220)
			assert(combat.stage.get_node("BattleLog").size.x == 620)
			assert(combat.stage.get_node("SpellPanel/SpellGrid").columns == 2 and combat.spell_buttons.size() == 4)
			assert(combat.weapon_buttons.size() == 2)
			assert(combat.weapon_buttons[0].position.x >= combat.player_hp.position.x)
			assert(combat.weapon_buttons[1].position.x + combat.weapon_buttons[1].size.x <= combat.stage.get_node("BattleLog").position.x)
			assert(combat.stage.get_node("PlayerHomunculusMeter") and combat.stage.get_node("EnemyHomunculusMeter"))
			assert(combat.stage.get_node_or_null("EnemyWeaponSlot1") == null)
			assert(combat.stage.get_node("PlayerHomunculusMeter").position.y >= combat.player_hom_sprite.position.y + combat.player_hom_sprite.size.y)
			assert(combat.stage.get_node("EnemyHomunculusMeter").position.y >= combat.enemy_hom_sprite.position.y + combat.enemy_hom_sprite.size.y)
			assert(combat.hom_attack.position.y >= combat.stage.get_node("PlayerHomunculusMeter").position.y + combat.stage.get_node("PlayerHomunculusMeter").size.y * combat.stage.get_node("PlayerHomunculusMeter").scale.y)
			assert(combat.player_hom_sprite.position.x + combat.player_hom_sprite.size.x <= combat.player_sprite.position.x)
			assert(combat.enemy_sprite.position.x + combat.enemy_sprite.size.x <= combat.enemy_hom_sprite.position.x)
			assert(not screen.background_shade.visible)
			assert(not combat.spell_buttons[0].tooltip_text.is_empty())
			assert(combat.stage.get_node("PlayerHomunculusMeter").find_child("HomTypeAndAttack", true, false) != null)
			assert(combat.stage.get_node("EnemyHomunculusMeter").find_child("HomTypeAndAttack", true, false) != null)
			assert(screen.combat_view.spell_buttons.all(func(button): return button.disabled))
			if i == 0:
				assert(combat.log.get_parsed_text().contains("Cinder Fist"))
				combat.log.meta_clicked.emit("cinder_fist")
				var dialogs: Array = combat.find_children("*", "AcceptDialog", true, false)
				assert(dialogs.size() == 1)
				dialogs[0].queue_free()
		for i in (range(1) if capture_mode else range(inspector.homunculi.size())):
			inspector.select_hom(i)
			await process_frame
			assert(screen.combat_view.player_hom_sprite.texture.resource_path == inspector.homunculi[i].combat_texture)
			assert(screen.combat_view.enemy_hom_sprite.texture.resource_path == inspector.homunculi[i].combat_texture)
			inspector.set_phase(3)
			await process_frame
			assert(screen.capture_sprite.texture.resource_path == inspector.homunculi[i].combat_texture)
			inspector.preview_action("success")
			var images: Array = screen.reward_popup.find_children("*", "TextureRect", true, false)
			assert(images.size() == 1 and images[0].texture.resource_path == inspector.homunculi[i].preview_texture)
			screen.reward_popup.acknowledged.emit()
			inspector.set_phase(1)
		var previous_video: WeakRef
		for i in (range(1) if capture_mode else range(inspector.backgrounds.size())):
			inspector.select_background(i)
			await process_frame
			if previous_video != null: assert(previous_video.get_ref() == null)
			assert(screen.background_key == inspector.backgrounds[i] and screen.video.stream != null)
			screen._fit_video()
			assert(screen.video.size.x >= screen.video_clip.size.x and screen.video.size.y >= screen.video_clip.size.y)
			previous_video = weakref(screen.video.stream)
			var stream: VideoStream = screen.video.stream
			inspector.set_phase(0)
			inspector.set_phase(1)
			inspector.set_phase(3)
			assert(screen.video.stream == stream)
			stream = null
		inspector.set_phase(2)
		await process_frame
		assert(screen.combat_view.inspiration_buttons.size() == 3)
		assert(screen.combat_view.inspiration_buttons.all(func(button): return button.disabled))
		inspector.set_phase(4)
		await process_frame
		assert(screen.phase_buttons.size() == 3 and screen.phase_buttons.all(func(button): return button.disabled))
		inspector.set_phase(5)
		await process_frame
		assert(screen.session.phase == "LOSS")
		inspector.set_phase(6)
		assert(screen.exit_confirmation.visible)
		screen.exit_confirmation.confirmed.emit()
		assert(screen.pending.is_empty() and screen.backend == null)
		inspector.preview_action("failure")
		assert(screen.message.text == screen.tr("EXPEDITION_CAPTURE_FAILED"))
		assert(screen.capture_heading.text == screen.tr("EXPEDITION_CAPTURE_FAILED"))
		inspector.preview_action("suspense")
		assert(screen.playing_events and is_instance_valid(screen.capture_tween))
		assert(screen.capture_heading.text == screen.tr("EXPEDITION_CAPTURE_SUSPENSE"))
		inspector.preview_action("duplicate")
		assert(is_instance_valid(screen.reward_popup))
		assert(screen.reward_popup.find_children("*", "Label", true, false).any(func(label): return label.text == screen.tr("EXPEDITION_DUPLICATE_XP")))
		screen.reward_popup.acknowledged.emit()
		inspector.preview_action("crystal")
		var crystal: Array = screen.reward_popup.find_children("*", "TextureRect", true, false)
		assert(crystal.size() == 1 and crystal[0].texture.resource_path == "res://assets/entities/expeditions/capture.png")
		screen.reward_popup.acknowledged.emit()
		if not OS.get_environment("EXPEDITION_VISUAL_CAPTURE").is_empty():
			for phase in [1, 2, 3]:
				inspector.set_phase(phase)
				await process_frame
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				assert(image != null and not image.is_empty())
				assert(image.save_png(OS.get_environment("EXPEDITION_VISUAL_CAPTURE").path_join("%dx%d_%s.png" % [size.x, size.y, inspector.PHASES[phase]])) == OK)
		await process_frame
		screen._fit_video()
		assert(screen.video.size.x >= screen.video_clip.size.x and screen.video.size.y >= screen.video_clip.size.y)
		assert(screen.find_children("*", "VideoStreamPlayer", true, false).size() == 1)
	for resized in [Vector2i(1024, 768), Vector2i(1500, 800)]:
		root.size = resized
		inspector.set_phase(1)
		await process_frame
		await process_frame
		var combat = screen.combat_view
		assert(combat.stage.position.x >= 0 and combat.stage.position.y >= 0)
		assert(combat.stage.position.x + 1920 * combat.stage.scale.x <= combat.size.x + 1)
		assert(combat.stage.position.y + 900 * combat.stage.scale.y <= combat.size.y + 1)
		inspector.set_phase(0)
		await process_frame
		screen._fit_video()
		assert(screen.video.size.x >= screen.video_clip.size.x and screen.video.size.y >= screen.video_clip.size.y)
		assert(screen.video.position.is_equal_approx((screen.video_clip.size - screen.video.size) * 0.5))
		if capture_mode:
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(OS.get_environment("EXPEDITION_VISUAL_CAPTURE").path_join("%dx%d_RESIZE.png" % [resized.x, resized.y])) == OK)
	if OS.has_environment("EXPEDITION_LOOP_CHECK"):
		var count := {"finished":0}
		screen.video.finished.connect(func(): count.finished += 1)
		var stream: VideoStream = screen.video.stream
		await create_timer(15.0).timeout
		assert(int(count.finished) >= 1 and screen.video.stream == stream and screen.video.is_playing())
	assert(screen.pending.is_empty() and screen.backend == null and _snapshot() == before)
	gate.debug_offline_enabled = false
	screen._process(0.01)
	assert(not screen.visual_debug and screen.video.stream == null)
	assert(_snapshot() == before)
	screen.queue_free()
	await process_frame
	var normal = load("res://scenes/ui/Expeditions.tscn").instantiate()
	root.add_child(normal)
	await process_frame
	assert(normal.visual_debug_entry == null and not normal.visual_debug)
	assert(not is_instance_valid(normal.visual_inspector))
	normal.queue_free()
	await process_frame
	print("EXPEDITION_VISUAL_DEBUG_PASS")
	quit()

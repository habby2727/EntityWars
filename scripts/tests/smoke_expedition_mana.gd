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
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		for locale in ["en", "es"]:
			TranslationServer.set_locale(locale)
			screen.state_data = {"mana":5.5, "crystals":3, "server_time_unix_ms":1000, "next_regeneration_at":11000, "remaining_cooldown_ms":0, "mana_purchases_remaining":11}
			screen.received_ticks = Time.get_ticks_msec()
			screen._update_status()
			assert(screen.mana_bar.value == 5.5 and screen.mana_text.text == "5.5/6")
			assert(screen.crystal_bar.value == 3 and screen.crystal_text.text == "3/5")
			assert("00:00:10" in screen.mana_bar.tooltip_text and "%s" not in screen.mana_bar.tooltip_text)
			assert(screen.mana_bar.tooltip_text.contains("victory" if locale == "en" else "victoria"))
			assert(screen.crystal_bar.tooltip_text.contains("capture" if locale == "en" else "captura"))
			assert(screen.mana_bar.get_global_rect().end.x <= screen.get_viewport_rect().size.x)
			screen.state_data.mana = 0
			screen.session = {"run_id":"sample", "status":"ACTIVE", "revision":1, "phase":"EXPLORE"}
			screen.mana_prompt = true
			screen._render()
			await process_frame
			assert(screen.crystal_bar.get_global_rect().end.x <= screen.get_viewport_rect().size.x)
			assert(screen.exit_button.get_global_rect().end.x <= screen.get_viewport_rect().size.x)
			assert(screen.body.find_children("*", "Label", true, false).any(func(label): return label.text == tr("EXPEDITION_MANA_EMPTY")))
			assert(screen.phase_buttons.size() == 2)
			assert(screen.phase_buttons[0].text == tr("EXPEDITION_MANA_BUY"))
			assert(bool(screen.phase_buttons[1].get_meta("unavailable")))
			screen.state_data.mana = 0.1
			screen._render()
			assert(not bool(screen.phase_buttons[1].get_meta("unavailable")))
			screen.state_data.mana = 6
			screen.state_data.next_regeneration_at = null
			screen._update_status()
			assert(screen.mana_bar.tooltip_text.contains(tr("EXPEDITION_MANA_FULL")))
	print("EXPEDITION_MANA_HUD_PASS")
	quit()

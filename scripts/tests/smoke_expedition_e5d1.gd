extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := DirAccess.open("res://assets/entities/expeditions/backgrounds/")
	var backgrounds := 0
	for file in directory.get_files():
		if file.ends_with(".ogv"):
			backgrounds += 1
			assert(ResourceLoader.exists("res://assets/entities/expeditions/backgrounds/" + file))
	assert(backgrounds == 26)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/expedition_enemies.json"))
	var choices := []
	for i in 2:
		var enemy: Dictionary = manifest.enemies[i]
		choices.append({"choice": i, "id": enemy.id, "name": enemy.name, "types": enemy.types, "preview_texture": enemy.preview_texture})
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		var screen = load("res://scenes/ui/Expeditions.tscn").instantiate()
		root.add_child(screen)
		await process_frame
		screen.resumed = true
		screen.state_data = {"mana": 6, "crystals": 5, "server_time_unix_ms": 1}
		screen.session = {"run_id": "visual", "revision": 1, "phase": "EXPLORE", "background_key": "Ashen_Monastery_12s_1080p_Godot.ogv", "choices": choices, "loadout": {"homunculus_id": "astralotl"}}
		screen._render()
		await process_frame
		await process_frame
		var row: HBoxContainer = screen.body.get_child(screen.body.get_child_count() - 1)
		assert(row.get_child_count() == 2)
		for i in 2:
			var portrait: TextureRect = row.get_child(i).get_child(0).get_child(0)
			assert(portrait.texture.resource_path == choices[i].preview_texture)
		assert(screen.video.stream != null)
		await create_timer(0.5).timeout
		screen._fit_video()
		assert(screen.video.size.x >= screen.video_clip.size.x and screen.video.size.y >= screen.video_clip.size.y)
		var stream: VideoStream = screen.video.stream
		var player := {"id":"sulfur_01", "type":"sulfur", "hp":100, "max_hp":104}
		var npc := {"id":manifest.enemies[0].id, "type":manifest.enemies[0].types[0], "expedition_types":manifest.enemies[0].types, "texture":manifest.enemies[0].texture, "hp":80, "max_hp":80}
		screen.session.merge({"phase":"COMBAT", "revision":2, "combat_state":{"player":player, "npc":npc}}, true)
		screen._render()
		await process_frame
		assert(screen.video.stream == stream and screen.background_key == "Ashen_Monastery_12s_1080p_Godot.ogv")
		assert(not screen.combat_view.player_sprite.flip_h)
		assert(screen.combat_view.enemy_sprite.flip_h)
		assert(screen.combat_view.enemy_sprite.texture.resource_path == npc.texture)
		var p: Dictionary = screen.session.combat_state.player
		p["spell_ids"] = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"]
		p["inspiration_pending"] = true
		p["inspiration_offers"] = ["steady_script", "ward_glyph", "rift_touch"]
		screen._render()
		await process_frame
		assert(screen.combat_view.inspiration_buttons.size() == 3)
		assert(screen.combat_view.spell_buttons.all(func(button): return button.disabled))
		assert(screen.combat_view.decline_button != null)
		screen.session["phase"] = "REWARD"
		screen.session["capture_candidate"] = {"name":"Astralotl", "preview_texture":"res://assets/entities/gameplay/homunculus/astralotl_pv.png"}
		screen._render()
		await process_frame
		assert(screen.video.stream == stream and screen.body.get_child(screen.body.get_child_count() - 1) is CenterContainer)
		screen.session["phase"] = "LOSS"
		screen._render()
		await process_frame
		assert(screen.video.stream == stream)
		screen._auth_changed("")
		assert(screen.session.is_empty() and screen.video.stream == null)
		stream = null
		screen.queue_free()
		await process_frame
		SceneRouter._expedition_context = {"loadout": true, "player_id": "e5d1-smoke-account"}
		var loadout = load("res://scenes/LoadoutGrid.tscn").instantiate()
		root.add_child(loadout)
		await process_frame
		assert(loadout._expedition_mode and loadout.ranked_queue == null)
		assert(loadout._hom_status("astralotl") != "owned")
		assert(loadout._spell_slots.size() == 4)
		loadout.queue_free()
		await process_frame
		SceneRouter._expedition_context.clear()
	print("Expedition presentation smoke passed")
	quit()

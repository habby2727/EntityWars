extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for view_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = view_size
		var screen = load("res://scenes/LoadoutGrid.tscn").instantiate()
		root.add_child(screen)
		await process_frame
		await process_frame
		assert(screen._homunculi.size() == 22 and screen._reg.get_homunculi().size() == 8)
		assert(screen.grid_homunculi.get_child_count() == 22)
		screen._on_tab_homunculi()
		await process_frame
		await process_frame
		var scroll: ScrollContainer = screen.grid_homunculi.get_parent()
		var bar := scroll.get_v_scroll_bar()
		print("LAYOUT ", view_size, " scroll=", scroll.size, " grid=", screen.grid_homunculi.size, " max=", bar.max_value, " page=", bar.page, " visible=", bar.visible)
		assert(bar.visible and bar.max_value > bar.page)
		assert(scroll.size.x > 300 and scroll.size.y > 0)
		var legacy: String = screen._current_homunculus_id
		assert(screen._is_combat_hom(legacy))
		var card: Control
		for candidate in screen.grid_homunculi.get_children():
			if candidate.get_meta("hom_id", "") == "astralotl": card = candidate
		assert(card != null and card.get_node("HomLock").visible)
		var portrait: TextureRect = card.get_node("CardContent/Portrait")
		assert(is_equal_approx(portrait.modulate.r, 0.5))
		assert(portrait.texture.resource_path == "res://assets/entities/gameplay/homunculus/astralotl_pv.png")
		(card as Button).pressed.emit()
		assert(screen._current_homunculus_id == legacy)
		var backend: BackendClient = screen._spell_backend
		if backend == null:
			backend = BackendClient.new()
			screen.add_child(backend)
			screen._spell_backend = backend
		backend.token = "e4b-test"
		var account := "e4b-test-" + str(Time.get_ticks_usec())
		backend._verified_player_id = account
		for invalid in [{"owned":true}, {"owned":true, "level":1, "xp":0}, {"owned":true, "level":0, "xp":100}, {"owned":true, "level":0, "xp":0, "mutation_id":"vitality"}, {"owned":true, "level":3, "xp":550, "mutation_id":"unknown"}]:
			screen._update_hom_ownership({"player_id":account, "homunculus_progress":{"astralotl":invalid}}, backend)
			assert(screen._hom_status("astralotl") == "locked")
		scroll.scroll_vertical = 300
		await process_frame
		var pos := scroll.scroll_vertical
		screen._update_hom_ownership({"player_id":account, "homunculus_progress":{"astralotl":{"owned":true, "level":0, "xp":0}}}, backend)
		assert(screen._hom_status("astralotl") == "owned" and not card.get_node("HomLock").visible)
		assert(scroll.scroll_vertical == pos)
		screen._on_card_picked("homunculus", "astralotl")
		assert(screen._current_homunculus_id == "astralotl" and screen._is_combat_hom("astralotl"))
		var account_b := account + "-b"
		backend._verified_player_id = account_b
		assert(screen._hom_status("astralotl") == "unknown")
		screen._update_hom_ownership({"player_id":account_b, "homunculus_progress":{}}, backend)
		assert(screen._hom_status("astralotl") == "locked" and card.get_node("HomLock").visible)
		assert(screen._current_homunculus_id == legacy)
		screen._clear_hom_ownership()
		assert(screen._hom_status("astralotl") == "unknown")
		assert(not screen._payload_hom_safe({"homunculus_id":"astralotl"}) and screen._payload_hom_safe({"homunculus_id":legacy}))
		var prefs := preload("res://scripts/domain/build_preferences.gd")
		var saved_weapon := str(screen._items[0].id)
		assert(prefs.save_for(account_b, {"homunculus_id":"astralotl", "equip_1":saved_weapon}))
		screen._preferences_ready = false
		screen._preferences_owner = ""
		screen._restore_build_preferences(account_b)
		assert(screen._is_combat_hom(screen._current_homunculus_id))
		assert(screen._idx_to_id(screen._items, screen.dd_item1) == saved_weapon)
		var seal_path: String = prefs.seal_path(account_b, "attack")
		var seal := FileAccess.open(seal_path, FileAccess.WRITE)
		seal.store_string(JSON.stringify({"player_id":account_b, "homunculus_id":"astralotl", "equip_1":saved_weapon}))
		seal.close()
		screen._load_seal("attack")
		assert(screen._is_combat_hom(screen._current_homunculus_id))
		assert(screen._idx_to_id(screen._items, screen.dd_item1) == saved_weapon)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(seal_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path_for(account_b)))
		screen._current_homunculus_id = "astralotl"
		assert(not screen._save_seal("attack"))
		screen._submit_dungeon_loadout()
		assert(screen._dungeon_payload.is_empty())
		screen._submit_hunt_loadout()
		assert(screen._hunt_payload.is_empty())
		screen._on_play_pressed()
		assert(screen.lbl_build_error.text == screen.tr("LOADOUT_HOM_PENDING"))
		var ranked = screen.ranked_queue
		ranked.selected = true
		ranked.synced = true
		ranked.backend.token = "test"
		ranked.backend._verified_player_id = account_b
		screen._spell_state = {"player_id":account_b}
		screen._spell_synced = true
		ranked._join()
		assert(ranked.info.text == screen.tr("LOADOUT_HOM_PENDING") and ranked.request_id.is_empty())
		screen._reset_build_defaults()
		assert(screen._is_combat_hom(screen._current_homunculus_id))
		screen.queue_free()
		await process_frame
	print("LOADOUT_HOM_COLLECTION_PASS")
	quit()

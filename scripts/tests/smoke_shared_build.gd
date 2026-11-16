extends SceneTree

const Prefs := preload("res://scripts/domain/build_preferences.gd")

func _initialize() -> void:
	call_deferred("_run")

func _scene(mode: String, account: String) -> Node:
	SceneRouter._solo_hunt_context.clear()
	SceneRouter._dungeon_context.clear()
	SceneRouter._hunt_loadout_active = mode in ["hunt", "global"]
	if mode in ["hunt", "global"]:
		SceneRouter._solo_hunt_context = {"session_id": "session", "loadout_identity": account, "recovered_session": {"combat_revision": 0}, "global_event_id": "event" if mode == "global" else ""}
	elif mode == "dungeon":
		SceneRouter._dungeon_context = {"run_id": "run", "player_id": account}
	var scene = load("res://scenes/LoadoutGrid.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var backend = scene._dungeon_backend if mode == "dungeon" else (scene._hunt_backend if mode in ["hunt", "global"] else scene._spell_backend)
	backend.token = "fixture-token"
	backend._verified_player_id = account
	if mode in ["hunt", "global"]:
		scene._hunt_identity = account
		scene._hunt_recovered = true
	elif mode == "dungeon":
		scene._dungeon_recovered = true
	scene._restore_build_preferences(account)
	return scene

func _run() -> void:
	var test_root := OS.get_environment("BUILD_TEST_ROOT").replace("\\", "/").to_lower()
	assert(not test_root.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"))
	BackendClient._auto_login_started = true
	if OS.get_environment("BUILD_TEST_PHASE") == "restart":
		var saved := Prefs.load_for("account-a")
		assert(not saved.is_empty())
		for mode in ["bo3", "dungeon", "hunt", "global"]:
			var restored = await _scene(mode, "account-a")
			assert(restored._current_entity_id == saved.entity_id)
			assert(restored._idx_to_id(restored._items, restored.dd_item1) == saved.equip_1)
			assert(restored._idx_to_id(restored._items, restored.dd_item2) == saved.equip_2)
			restored.queue_free()
			await process_frame
		if UIThemeFactory._catalog != null:
			UIThemeFactory._catalog.free()
			UIThemeFactory._catalog = null
		print("PASS build preferences after application restart")
		quit(0)
		return
	var a = await _scene("bo3", "account-a")
	var entity := str(a._entities[1].id)
	var hom := str(a._homunculi[1].id)
	var first := str(a._items[2].id)
	var second := str(a._items[3].id)
	a._on_card_picked("entity", entity)
	a._on_card_picked("homunculus", hom)
	a._on_equip_button_pressed(a.dd_item1)
	a._choose_weapon(first)
	a._on_equip_button_pressed(a.dd_item2)
	a._choose_weapon(second)
	assert(Prefs.load_for("account-a").get("equip_1") == first)
	var raw := FileAccess.get_file_as_string(Prefs.path_for("account-a"))
	assert(not raw.contains("fixture-token"))
	a._save_seal("attack")
	assert(FileAccess.file_exists(Prefs.seal_path("account-a", "attack")))
	a.queue_free()
	await process_frame
	for mode in ["dungeon", "hunt", "global", "bo3"]:
		var scene = await _scene(mode, "account-a")
		assert(scene._current_entity_id == entity and scene._current_homunculus_id == hom)
		assert(scene._idx_to_id(scene._items, scene.dd_item1) == first and scene._idx_to_id(scene._items, scene.dd_item2) == second)
		scene._on_equip_button_pressed(scene.dd_item1)
		var duplicate: Button = scene._weapon_list.get_node("Weapon_" + second)
		assert(duplicate.disabled)
		scene._choose_weapon(second)
		assert(scene._idx_to_id(scene._items, scene.dd_item1) == first)
		var replacement := ""
		for item in scene._items:
			var candidate := str(item.get("id", ""))
			if not candidate.is_empty() and candidate != first and candidate != second:
				replacement = candidate
				break
		assert(not replacement.is_empty())
		scene._choose_weapon(replacement)
		first = replacement
		assert(Prefs.load_for("account-a").get("equip_1") == first)
		if mode in ["hunt", "global"]:
			scene._hunt_payload = {"client_action_id": "pending"}
			var pending_saved := Prefs.load_for("account-a")
			scene._on_card_picked("entity", str(scene._entities[0].id))
			assert(Prefs.load_for("account-a") == pending_saved)
			scene._hunt_payload.clear()
			SceneRouter._solo_hunt_context.recovered_session.combat_revision = 1
			var saved := Prefs.load_for("account-a")
			scene._on_card_picked("entity", str(scene._entities[0].id))
			assert(Prefs.load_for("account-a") == saved)
		scene.queue_free()
		await process_frame
	var b = await _scene("bo3", "account-b")
	assert(Prefs.load_for("account-b").is_empty())
	assert(b._read_seal_data("attack").is_empty())
	assert(b._current_entity_id != entity)
	b._on_card_picked("entity", str(b._entities[0].id))
	assert(Prefs.load_for("account-a").get("entity_id") == entity)
	b.queue_free()
	await process_frame
	assert(Prefs.save_for("account-b", {"entity_id": "invalid", "homunculus_id": "invalid", "equip_1": "invalid", "equip_2": "invalid"}))
	b = await _scene("bo3", "account-b")
	assert(not b._find_by_id(b._entities, b._current_entity_id).is_empty())
	assert(not b._has_duplicate_build_items())
	b._on_spell_auth_changed("")
	b._spell_backend.token = "fixture-token"
	b._spell_backend._verified_player_id = "account-a"
	b._on_spell_state_updated({"player_id": "account-a"})
	assert(b._current_entity_id == entity and b._idx_to_id(b._items, b.dd_item1) == first)
	b.queue_free()
	await process_frame
	var empty_slot = await _scene("bo3", "account-c")
	empty_slot._on_equip_button_pressed(empty_slot.dd_item1)
	empty_slot._choose_weapon("")
	assert(Prefs.load_for("account-c").get("equip_1") == "")
	empty_slot.queue_free()
	await process_frame
	for mode in ["dungeon", "hunt", "global"]:
		empty_slot = await _scene(mode, "account-c")
		assert(empty_slot._idx_to_id(empty_slot._items, empty_slot.dd_item1) == "")
		empty_slot.queue_free()
		await process_frame
	SceneRouter._hunt_loadout_active = false
	SceneRouter._solo_hunt_context.clear()
	SceneRouter._dungeon_context.clear()
	if UIThemeFactory._catalog != null:
		UIThemeFactory._catalog.free()
		UIThemeFactory._catalog = null
	print("PASS shared account build preferences and weapon selector")
	quit(0)

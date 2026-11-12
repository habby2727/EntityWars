extends SceneTree

var url := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	url = OS.get_environment("FORGE_SMOKE_URL")
	var user_root := OS.get_environment("FORGE_SMOKE_USER_ROOT").replace("\\", "/").to_lower()
	if not url.begins_with("http://127.0.0.1:") or user_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(user_root + "/"):
		_fail("Test isolation missing")
		return
	if OS.get_environment("COMBAT_RESTART_TEST") == "1":
		var restarted = await _open_combat()
		if restarted == null or not _check_fighters(restarted, 10) or not _check_spell(restarted, true):
			return
		restarted.queue_free()
		await process_frame
		if not await _check_debug():
			return
		print("PASS Godot process restart, authenticated spell progress and isolated debug")
		quit(0)
		return
	var seal := FileAccess.open("user://seal_attack.json", FileAccess.WRITE)
	seal.store_string(JSON.stringify({"entity_id": "sulfur_01", "equip_1": "wind_amulet", "side_1": "saltstone_charm"}))
	seal.close()
	var login := BackendClient.new()
	login.base_url = url
	login.auto_dev_login = false
	login.auto_flush = false
	root.add_child(login)
	login.login_dev("combat_account_a")
	if not await _wait_verified(login):
		return
	var scene = await _open_combat()
	if scene == null or not _check_fighters(scene, 10) or not _check_spell(scene, true) or not _check_swap(scene, 10):
		return
	login.login_dev("combat_account_b")
	if not scene._combat_session_invalid:
		_fail("Combat was not invalidated on account change")
		return
	if not await _wait_verified(login):
		return
	scene.queue_free()
	await process_frame
	scene = await _open_combat()
	if scene == null or not _check_fighters(scene, 0) or not _check_spell(scene, false) or not _check_swap(scene, 0):
		return
	login.login_dev("combat_account_a")
	if not scene._combat_session_invalid:
		_fail("External login did not invalidate combat")
		return
	if not await _wait_verified(login):
		return
	scene.queue_free()
	await process_frame
	scene = await _open_combat()
	if scene == null or not _check_fighters(scene, 10) or not _check_spell(scene, true):
		return
	print("PASS real Combat accounts A/B/A, fighter equipment, sideboard and NPC")
	scene.queue_free()
	login.queue_free()
	await process_frame
	quit(0)

func _wait_verified(client: BackendClient) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while client._verified_player_id.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if client._verified_player_id.is_empty():
		_fail("Backend identity timeout")
		return false
	return true

func _open_combat():
	var scene = load("res://scenes/Combat.tscn").instantiate()
	scene.backend_url = url
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 8000
	while not scene._combat_started and Time.get_ticks_msec() < deadline:
		await process_frame
	if not scene._combat_started or scene._combat_identity.is_empty():
		_fail("Combat did not start with verified identity")
		return null
	return scene

func _check_fighters(scene, level: int) -> bool:
	var data := {"entity_id": "sulfur_01", "equip_1": "saltstone_charm", "side_1": "saltstone_charm"}
	var fighter: Dictionary = scene._build_fighter(data, true)
	var npc: Dictionary = scene._build_fighter(data, false)
	var expected := 0.12
	if int(fighter.equip_1.get("forge_level", -1)) != level or int(fighter.side_1.get("forge_level", -1)) != level or not is_equal_approx(float(fighter.equip_1.effects.ward_pct[0]), expected):
		_fail("Incorrect equipment or sideboard progression")
		return false
	if int(fighter.equip_1.effects.guard_flat[0]) != (12 if level == 10 else 6 if level == 5 else 2):
		_fail("Incorrect catalog level effect")
		return false
	if npc.equip_1.has("forge_level") or not is_equal_approx(float(npc.equip_1.effects.ward_pct[0]), 0.12):
		_fail("NPC inherited player progression")
		return false
	var repeated: Dictionary = scene._build_fighter(data, true)
	if not is_equal_approx(float(repeated.equip_1.effects.ward_pct[0]), expected):
		_fail("Item effects accumulated")
		return false
	return true

func _check_spell(scene, learned: bool) -> bool:
	if ("steady_script" in scene.player.spell_ids) != learned:
		_fail("Combat spell loadout did not follow authenticated progress")
		return false
	return true

func _check_swap(scene, level: int) -> bool:
	scene._swap_pending = true
	scene._on_swap_chosen("side_1")
	var item: Dictionary = scene.player.equip_1
	if str(item.get("id", "")) != "saltstone_charm" or int(item.get("forge_level", -1)) != level or not is_equal_approx(float(item.effects.ward_pct[0]), 0.12):
		_fail("Actual sideboard swap lost or duplicated item progression")
		return false
	scene._reset_fighter(scene.player)
	if not is_equal_approx(float(scene.player.equip_1.effects.ward_pct[0]), 0.12):
		_fail("Battle reset changed item progression")
		return false
	return true

func _check_debug() -> bool:
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var local := FileAccess.open("user://lab_debug_state.json", FileAccess.WRITE)
	local.store_string(JSON.stringify({"item_progress": {"saltstone_charm": {"level": 5}}}))
	local.close()
	var scene = load("res://scenes/Combat.tscn").instantiate()
	scene.backend_url = url
	root.add_child(scene)
	if not scene._combat_started or scene._combat_backend != null or not _check_fighters(scene, 5):
		_fail("Offline debug did not use isolated progression")
		return false
	scene.queue_free()
	await process_frame
	return true

func _fail(message: String) -> void:
	push_error("COMBAT_SMOKE_FAIL: " + message)
	quit(1)

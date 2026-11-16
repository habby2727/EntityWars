extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for world in ["Chaos", "Corrupted", "Crystal"]:
		var zone = load("res://scenes/ui/WorldZone%s.tscn" % world).instantiate()
		zone.get_node("BackendClient").auto_dev_login = false
		zone.get_node("BackendClient").base_url = "http://127.0.0.1:1"
		root.add_child(zone)
		await process_frame
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		zone._world_sprite.gui_input.emit(click)
		assert(zone._hunt_fight.visible and zone._hunt_fight.disabled)
		assert(zone._preview_status.text.contains("Offline"))
		assert(not zone._boss_status.visible and not zone._boss_hp.visible)
		zone._backend.token = "fixture"
		zone._backend._verified_player_id = "player"
		zone._global_connection_lost = false
		zone._hunt_session_checked = true
		zone._hunt_rotation = 123
		zone._update_common_details()
		assert(not zone._hunt_fight.disabled, zone._preview_status.text)
		var appearance: String = zone._hunt_selected.appearance_id
		# A response for a prior standard hunt_common has the same guardian key.
		zone._hunt_active_owner = "player"
		zone._hunt_progress_key = ""
		zone._hunt_wants_guardians = false
		zone._backend.token = ""
		zone._on_state_updated({})
		zone._request_guardian_progress()
		assert(not zone._hunt_wants_guardians)
		zone._guardian_request_key = zone._guardian_key()
		zone._guardian_request_owner = "player"
		zone._hunt_requests["stale-common"] = "guardians"
		zone._on_api_completed("stale-common", true, {"zone_id": zone._get_zone_id(), "hunt_id": "hunt_common", "boss_unlocked": true, "guardians": []})
		assert(zone._hunt_selected.get("appearance_id") == appearance and zone._world_modal.visible)
		assert(zone._hunt_fight.visible and not zone._view_guardians.visible)
		zone._hunt_requests["stale-failed"] = "guardians"
		zone._on_api_completed("stale-failed", false, {"error": "test failure"})
		assert(zone._hunt_selected.get("appearance_id") == appearance and not zone._hunt_wants_guardians)
		zone._backend.token = "fixture"
		zone._hunt_active_owner = "player"
		zone._hunt_active = {"hunt_id": "hunt_common", "zone_id": zone._get_zone_id(), "expires_at": 9999999999999, "boss_definition": {"appearance_id": appearance}}
		zone._update_common_details()
		assert(not zone._hunt_fight.disabled and zone._active_hunt_matches(""))
		zone._hunt_active.boss_definition.appearance_id = "another"
		zone._update_common_details()
		assert(zone._hunt_fight.disabled and zone._preview_status.text.contains("Another hunt"))
		zone._hunt_active.clear()
		zone._common_cooldown_until = zone._backend.get_server_time_unix_ms() + 30000
		zone._update_common_details()
		assert(zone._hunt_fight.disabled and zone._preview_status.text.contains("cooldown"))
		zone.queue_free()
		await process_frame
	print("PASS common encounter availability and legacy UI")
	quit(0)

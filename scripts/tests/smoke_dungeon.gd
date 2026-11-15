extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := BackendClient.new()
	backend.auto_dev_login = false
	root.add_child(backend)
	await process_frame
	backend.token = "fixture-token"
	backend._verified_player_id = "fixture-player"
	var panel = load("res://scripts/ui/lab_specialized_panel.gd").new()
	root.add_child(panel)
	panel.setup(DataRegistry.new(), backend, false, 20, 10)
	var state := {"lab": {"hqLevel": 4, "buildings": {"sync_nexus": {"level": 1}}, "runtime": {}}}
	panel.show_building("sync_nexus", state, {}, {}, true)
	panel._update_sync_status()
	assert(panel._lab_buttons.size() == 1)
	assert(panel._lab_buttons[0].text == "START")
	assert(not panel._dungeon_ranking_button.disabled)
	panel._dungeon_request = "fixture-request"
	panel._dungeon_request_owner = "fixture-player"
	panel._dungeon_ranking_month = "2026-01"
	panel._on_dungeon_api_completed("fixture-request", true, {"season": "2026-01", "leaders": [{"rank": 1, "display_name": "Test", "cleared_floor": 3, "total_turns": 17}], "player": {"rank": 1, "cleared_floor": 3}})
	assert(panel._dungeon_ranking_text.text.contains("Test"))
	assert(panel._dungeon_ranking_text.text.contains("Floor 3"))
	assert(panel._lab_buttons[0].text == "START")
	panel.queue_free()
	backend.queue_free()
	await process_frame
	print("PASS Dungeon ranking and Sync Nexus calibration controls")
	quit(0)

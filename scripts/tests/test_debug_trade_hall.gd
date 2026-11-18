extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	assert(gate.enable_debug_lab())
	var debug := DebugFlags.new()
	assert(debug.save_lab_state({"wallet": {"essence": 500, "core": 5, "arcane_shard": 3, "time_crystal": 2}, "lab": {"hqLevel": 1, "hqPath": "Scientific", "buildings": {"storage_vault": {"level": 0}}}}))
	debug.free()
	SceneRouter.go_to_lab()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_LAB_HUB)
	current_scene._buttons["trade_hall"].pressed.emit()
	assert(current_scene._quick_panel.visible and not current_scene._quick_panel._manage.disabled)
	current_scene._quick_panel._manage.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_TRADE_HALL)
	var trade = current_scene
	assert(trade._resource_rows.size() == 4)
	assert(trade._resource_rows.essence.label.text == "500 / 1312")
	assert(trade._resource_rows.core.label.text == "5 / 131")
	var updated: Dictionary = trade._state.duplicate(true)
	updated.wallet.essence = 450
	trade._on_state_updated(updated)
	assert(trade._resource_rows.essence.label.text == "450 / 1312")
	assert(trade._npc_preview and trade._npc_offers.size() == 5)
	for button in trade._npc_buttons:
		assert(button.disabled and not button.text.is_empty())
	assert(trade._sell_create_button.disabled and trade._job_create_button.disabled)
	trade._send_api_request("POST", "/market/order", {}, "market_order_create", true)
	assert(trade._requests.is_empty() and trade._api_queue.is_empty())
	trade._back_button.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_LAB_HUB)
	SceneRouter.go_to_lab_structures("trade_hall")
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_LAB_STRUCTURES)
	assert(current_scene._selected_id == "trade_hall" and not current_scene._open_btn.disabled)
	current_scene._open_btn.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_TRADE_HALL)
	gate.require_update()
	assert(not gate.debug_lab_navigation_allowed())
	SceneRouter.go_to_trade_hall()
	assert(current_scene.scene_file_path == SceneRouter.SCENE_TRADE_HALL)
	print("PASS offline debug Trade Hall navigation and blocked requests")
	quit()

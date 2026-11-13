extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var user_root := OS.get_environment("FORGE_SMOKE_USER_ROOT").replace("\\", "/").to_lower()
	if user_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(user_root + "/"):
		_fail("Isolation missing")
		return
	var file := FileAccess.open("user://debug.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"unlock_all_buildings": true}))
	file.close()
	var debug := DebugFlags.new()
	var state := {"wallet": {"essence": 650}, "lab": {"buildings": {"build_forge": {"level": 1}}}, "item_progress": {"aether_knot": {"level": 0}}}
	if not debug.save_lab_state(state):
		_fail("Cannot write isolated fixture")
		return
	var registry := DataRegistry.new()
	var panel = load("res://scripts/ui/lab_specialized_panel.gd").new()
	root.add_child(panel)
	panel.setup(registry, null, true, 20, 10)
	panel.show_building("build_forge", state, {}, {}, true)
	panel._forge_item = "aether_knot"
	panel._update_forge_button()
	if not panel._forge_info.text.contains("Base (Lv 0)") or not panel._forge_info.text.contains("Lv 1:") or not panel._forge_info.text.contains("Lv 2:") or not panel._forge_info.text.contains("0.1") or not panel._forge_info.text.contains("0.15") or not panel._forge_info.text.contains("0.18"):
		_fail("Forge does not show baseline and level 1/2 effects")
		return
	for level in range(10):
		if panel._forge_button.disabled:
			_fail("Upgrade disabled at level %d" % level)
			return
		panel._send_forge_upgrade()
		var saved := debug.load_lab_state()
		if int(saved.item_progress.aether_knot.level) != level + 1 or int(saved.wallet.essence) != 650 - (level + 1) * 20 - 5 * level * (level + 1):
			_fail("Incorrect saved level or cost")
			return
	if not panel._forge_button.disabled:
		_fail("Maximum level not enforced")
		return
	state = debug.load_lab_state()
	state.item_progress.aether_knot.level = 0
	state.wallet.essence = 19
	debug.save_lab_state(state)
	panel.show_building("build_forge", state, {}, {}, true)
	if not panel._forge_button.disabled:
		_fail("Insufficient Essence not enforced")
		return
	panel._send_forge_upgrade()
	if int(debug.load_lab_state().wallet.essence) != 19:
		_fail("Rejected upgrade changed wallet")
		return
	state.item_progress.aether_knot.level = 3
	state.wallet = {"essence": 200, "core": 5, "arcane_shard": 2}
	debug.save_lab_state(state)
	panel.show_building("build_forge", state, {}, {}, true)
	panel._request_trait_action(0)
	panel._send_forge_confirmed()
	panel._request_trait_action(0)
	panel._send_forge_confirmed()
	if panel._forge_reroll_button.disabled:
		_fail("Debug reroll disabled")
		return
	panel._request_forge_reroll()
	panel._send_forge_confirmed()
	var offer_state := debug.load_lab_state()
	var offer: Dictionary = offer_state.item_progress.aether_knot.get("pending_reroll", {})
	if offer.get("options", []).size() != 3:
		_fail("Debug reroll offer not saved")
		return
	panel.show_building("build_forge", offer_state, {}, {}, true)
	panel._request_trait_action(0)
	panel._send_forge_confirmed()
	var chosen := debug.load_lab_state()
	if chosen.item_progress.aether_knot.has("pending_reroll") or chosen.item_progress.aether_knot.traits[0].id != offer.options[0] or int(chosen.item_progress.aether_knot.traits[0].points) != 1:
		_fail("Debug reroll selection not saved")
		return
	print("PASS debug Forge cost, levels 0-10, maximum, insufficient Essence and saved state")
	panel.queue_free()
	registry.free()
	debug.free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error("FORGE_DEBUG_FAIL: " + message)
	quit(1)

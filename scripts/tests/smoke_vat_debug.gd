extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_path := OS.get_environment("VAT_SMOKE_ROOT").replace("\\", "/").to_lower()
	if root_path.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(root_path + "/"):
		push_error("VAT_DEBUG_FAIL: isolation missing")
		quit(1)
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var debug := DebugFlags.new()
	var state := {"wallet": {"essence": 300, "core": 5, "arcane_shard": 2}, "lab": {"hqLevel": 2, "hqPath": "Scientific", "buildings": {"homunculus_vat": {"level": 1}}, "runtime": {"cooldowns": {}, "boosts": {}, "research": {}}}, "homunculus_progress": {"cinder": {"level": 2}}}
	assert(debug.save_lab_state(state))
	var scene = load("res://scenes/ui/LabStructures.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._simulate_debug_action({"action_type": "HOM_UPGRADE", "payload": {"homunculus_id": "cinder"}})
	scene._simulate_debug_action({"action_type": "HOM_MUTATE", "payload": {"homunculus_id": "cinder", "mutation_id": "catalyst"}})
	var saved := debug.load_lab_state()
	assert(saved.homunculus_progress.cinder.level == 3 and saved.homunculus_progress.cinder.mutation_id == "catalyst")
	assert(saved.wallet.essence == 175 and saved.wallet.core == 3 and saved.wallet.arcane_shard == 1)
	scene._simulate_debug_action({"action_type": "HOM_MUTATE", "payload": {"homunculus_id": "cinder", "mutation_id": "vitality"}})
	assert(debug.load_lab_state().homunculus_progress.cinder.mutation_id == "catalyst")
	print("VAT_DEBUG_PASS")
	scene.queue_free()
	debug.free()
	await process_frame
	quit(0)

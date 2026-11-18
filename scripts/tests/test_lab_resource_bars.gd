extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in ["res://scenes/ui/LabHub.tscn", "res://scenes/ui/LabStructures.tscn"]:
		var scene = load(path).instantiate()
		root.add_child(scene)
		await process_frame
		scene._debug.unlock_all_buildings = true
		scene._state = {"wallet": {"essence": 525, "core": 52, "arcane_shard": 26, "time_crystal": 10}, "wallet_capacities": {"essence": 9999}, "lab": {"hqPath": "Scientific", "buildings": {"storage_vault": {"level": 0, "route": ""}}}}
		scene._update_resource_bar()
		var expected := {"essence": 1312, "core": 131, "arcane_shard": 65, "time_crystal": 26}
		var colors := {"essence": "46c77a", "core": "f29b42", "arcane_shard": "a56df2", "time_crystal": "45c9e8"}
		for id in expected:
			var item: Dictionary = scene._resource_rows[id]
			assert(int(item.bar.max_value) == expected[id], "%s cap at level zero" % id)
			assert(int(item.bar.value) == int(scene._state.wallet[id]), "%s filled amount" % id)
			assert(item.label.text == "%d / %d" % [scene._state.wallet[id], expected[id]], "%s label" % id)
			assert(item.bar.get_theme_stylebox("fill").bg_color.is_equal_approx(Color(colors[id])), "%s color" % id)
			assert(item.clip.size.x > 0.0, "%s highlight clipped to fill" % id)
		assert(scene._resource_rows.essence.row.tooltip_text.ends_with("+0.00 / h"))
		assert(not scene._resource_rows.core.row.tooltip_text.contains("/ h"))
		scene._state.lab.buildings.essence_reactor = {"level": 1, "route": "stable"}
		scene._update_resource_bar()
		var expected_rate: String = scene._format_number(float(scene._get_production_per_hour().essence))
		assert(scene._resource_rows.essence.row.tooltip_text.ends_with("+%s / h" % expected_rate))
		assert(float(scene._get_production_per_hour().essence) > 0.0)
		var essence: Dictionary = scene._resource_rows.essence
		assert(essence.icon.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		assert(essence.icon.custom_minimum_size == Vector2(32, 32))
		assert(essence.bar.custom_minimum_size == Vector2(150, 24))
		assert(essence.label.get_theme_font_size("font_size") == 14)
		assert(essence.bar.get_theme_stylebox("background").border_width_left == 0)
		scene._state.wallet.essence = 1
		scene._state.lab.buildings.storage_vault.level = 10
		scene._update_resource_bar()
		assert(essence.bar.value / essence.bar.max_value * maxf(essence.bar.size.x, 150.0) >= 1.99)
		assert(essence.label.text.begins_with("1 / "))
		scene._state.wallet.essence = 0
		scene._update_resource_bar()
		assert(essence.bar.value == 0.0)
		scene._state.lab.hqPath = "Industrial"
		scene._state.lab.buildings.storage_vault = {"level": 2, "route": "Reactive"}
		scene._update_resource_bar()
		assert(int(scene._resource_rows.essence.bar.max_value) == 2268)
		assert(int(scene._resource_rows.core.bar.max_value) == 226)
		scene._debug.unlock_all_buildings = false
		scene._state.wallet_capacities = {"essence": 2500}
		scene._update_resource_bar()
		assert(int(scene._resource_rows.essence.bar.max_value) == 2500, "online uses server capacity")
		print("PASS resource bars: ", path)
		scene.queue_free()
		await process_frame
	quit()

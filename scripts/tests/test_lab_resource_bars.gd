extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in ["res://scenes/ui/LabHub.tscn", "res://scenes/ui/LabStructures.tscn", "res://scenes/ui/Lab.tscn"]:
		var scene = load(path).instantiate()
		root.add_child(scene)
		await process_frame
		scene._debug.unlock_all_buildings = true
		scene._state = {"wallet": {"essence": 525, "core": 52, "arcane_shard": 26, "time_crystal": 10}, "wallet_capacities": {"essence": 9999}, "lab": {"hqPath": "Scientific", "buildings": {"storage_vault": {"level": 0, "route": ""}}}}
		scene._update_resource_bar()
		await process_frame
		assert(scene._resource_bar is VBoxContainer)
		var last_y := -1.0
		for resource_id in ["essence", "core", "arcane_shard", "time_crystal"]:
			var row: Control = scene._resource_rows[resource_id].row
			assert(row.position.y > last_y, "vertical resource order")
			last_y = row.position.y
		for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = viewport_size
			await process_frame
			await process_frame
			var first_row: Control = scene._resource_rows.essence.row
			var last_row: Control = scene._resource_rows.time_crystal.row
			var back: Control = scene.get_node("Aspect/Canvas/TopOverlay/BackButton") if path.ends_with("LabHub.tscn") else scene.get_node("Background/ContentMargin/RootHBox/LeftPanel/Margin/LeftVBox/TopRow/BackButton")
			assert(back.visible and not back.get_global_rect().intersects(first_row.get_global_rect()), "back remains accessible")
			assert(first_row.get_global_rect().position.y >= back.get_global_rect().end.y, "resources below back")
			if not path.ends_with("LabHub.tscn"):
				var scroll: Control = scene.get_node("Background/ContentMargin/RootHBox/LeftPanel/Margin/LeftVBox/Scroll")
				assert(last_row.get_global_rect().end.y <= scroll.get_global_rect().position.y, "resources do not cover cards")
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
		var large: bool = path.ends_with("LabHub.tscn")
		assert(essence.icon.custom_minimum_size == (Vector2(40, 40) if large else Vector2(32, 32)))
		assert(essence.bar.custom_minimum_size == (Vector2(225, 40) if large else Vector2(150, 24)))
		assert(essence.label.get_theme_font_size("font_size") == (28 if large else 14))
		assert(essence.label.get_theme_constant("outline_size") == (5 if large else 3))
		if large:
			var bars = load("res://scripts/ui/lab_resource_bars.gd")
			bars.update(scene._resource_rows, {"wallet":{"essence":123456789}, "wallet_capacities":{"essence":987654321}})
			await process_frame
			assert(essence.bar.size.x >= essence.label.get_combined_minimum_size().x + 8.0, "large resource values fit inside the bar")
			var next_row: Control = scene._resource_rows.core.row
			assert(next_row.position.y >= essence.row.position.y + essence.row.size.y, "resource rows do not overlap")
			scene._update_resource_bar()
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
		var bars = load("res://scripts/ui/lab_resource_bars.gd")
		var details: String = bars.vault_details({"wallet_capacities": {"essence": 9999}}, scene._db.balance, 2, 10, "Reactive", "Industrial")
		assert(details.contains("Essence | 9999 | 2646"))
		assert(details.contains("Core | 226 | 264"))
		assert(details.contains("Reactor pending-production capacity"))
		var max_details: String = bars.vault_details({}, scene._db.balance, 10, 10, "", "Scientific")
		assert(max_details.count("MAX") == 5)
		print("PASS resource bars and vault details: ", path)
		scene.queue_free()
		await process_frame
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("ConnectionGate").enable_debug_lab()
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = dimensions
		if change_scene_to_file("res://scenes/ui/WorldGate.tscn") != OK:
			_fail("world gate load")
			return
		await process_frame
		await process_frame
		var gate := current_scene
		var button := gate.get_node("Background/Margin/RootVBox/Tabs/Zones/Scroll/ZoneVBox/ExpeditionMargin/ExpeditionButton") as Button
		var header := gate.get_node("Background/Margin/RootVBox/Tabs/Zones/Scroll/ZoneVBox/ZonesHeaderRow") as Control
		var list := gate.get_node("Background/Margin/RootVBox/Tabs/Zones/Scroll/ZoneVBox/ZoneList") as Control
		if button.size.y <= 0 or button.get_global_rect().end.y > header.get_global_rect().position.y or header.get_global_rect().end.y > list.get_global_rect().position.y:
			_fail("overlap at %s" % dimensions)
			return
		button.pressed.emit()
		await process_frame
		await process_frame
		if current_scene.name != "Expeditions":
			_fail("navigation to expeditions")
			return
		current_scene.back_button.pressed.emit()
		await process_frame
		await process_frame
		if current_scene.name != "WorldGate":
			_fail("navigation back")
			return
	print("PASS expedition navigation and container layout")
	quit()

func _fail(message: String) -> void:
	push_error("EXPEDITION_TEST_FAIL: " + message)
	quit(1)

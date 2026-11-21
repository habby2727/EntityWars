extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var panel = preload("res://scripts/ui/shared_reward_panel.gd")
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		var body: VBoxContainer = panel.result_popup(host, "Victoria excepcional", "Continuar")
		panel.reward_rows(host, body, {"essence":90, "core":2, "arcane_shard":1})
		await process_frame
		var frame := body.get_parent().get_parent() as Control
		assert(frame.size.x <= root.get_visible_rect().size.x and frame.size.y <= root.get_visible_rect().size.y)
		assert(body.get_child_count() == 3)
		for row in body.get_children():
			assert(row.get_child(0) is TextureRect and row.get_child(1) is Label)
		body.get_parent().get_parent().get_parent().get_parent().queue_free()
		await process_frame
	print("SHARED_REWARD_PANEL_PASS")
	quit()

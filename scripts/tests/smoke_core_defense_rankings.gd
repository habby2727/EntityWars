extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var popup = load("res://scripts/ui/core_defense_rankings.gd").new()
	root.add_child(popup)
	await process_frame
	assert(popup._status.text == popup.tr("CD_UNAVAILABLE"))
	popup._set_mode("coop")
	popup._set_month("previous")
	assert(popup._mode == "coop" and popup._month == "previous")
	assert(popup._status.text == popup.tr("CD_UNAVAILABLE"))
	popup._set_mode("solo")
	popup._set_month("current")
	assert(popup._mode == "solo" and popup._month == "current")
	popup._close()
	await process_frame
	assert(not is_instance_valid(popup))
	print("CD_RANKINGS_SMOKE_PASS")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GlobalChatClient").set_process(false)
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = "rankings-smoke"
	gate.token = "test-token"
	gate.base_url = "https://example.invalid"
	root.get_node("CoreDefenseClient").set_script(load("res://scripts/tests/rankings_fake_client.gd"))
	var popup = load("res://scripts/ui/core_defense_rankings.gd").new()
	root.add_child(popup)
	popup._set_mode("coop")
	await create_timer(0.4).timeout
	assert(popup._rows.get_child_count() == 1)
	assert(popup._rows.get_child(0).get_child(1).text == "Coop")
	assert(popup._rows.get_child(0).get_child(2).text == "7")
	popup._set_month("previous")
	await create_timer(0.1).timeout
	assert(popup._rows.get_child_count() == 0 and popup._status.text == popup.tr("CD_RANKING_EMPTY"))
	popup._set_mode("solo")
	gate.player_id = "other-account"
	await create_timer(0.35).timeout
	assert(not is_instance_valid(popup))
	print("CD_RANKINGS_SUCCESS_SMOKE_PASS")
	quit()

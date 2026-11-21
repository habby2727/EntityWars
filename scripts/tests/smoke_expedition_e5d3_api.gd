extends SceneTree

const Recovery := preload("res://scripts/net/expedition_recovery.gd")
const Seen := preload("res://scripts/net/expedition_rewards_seen.gd")
var token := ""
var player_id := ""
var base_url := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	token = OS.get_environment("EXPEDITION_TEST_TOKEN")
	player_id = OS.get_environment("EXPEDITION_TEST_PLAYER")
	base_url = OS.get_environment("EXPEDITION_TEST_URL")
	var gate := root.get_node("ConnectionGate")
	gate.player_id = player_id
	gate.token = token
	gate.base_url = base_url
	gate.state = gate.State.CONNECTED
	var screen = await _new_screen()
	assert(await _wait_state(screen))
	var payload := {"client_action_id":screen.backend._make_uuid(), "entity_id":"sulfur_01", "weapon_ids":[null, null], "homunculus_id":"cinder", "spell_ids":["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], "mode":"attack"}
	assert(Recovery.save_pending(player_id, "start", payload))
	screen.pending = Recovery.load_pending(player_id)
	screen._refresh()
	assert(await _wait_phase(screen, "EXPLORE"))
	var run_id: String = screen.session.run_id
	screen._select(0)
	assert(await _wait_phase(screen, "COMBAT"))
	var background: VideoStream = screen.video.stream
	assert(await _fixture(screen, "win"))
	screen._refresh()
	assert(await _wait_state(screen))
	for attempt in 3:
		var revision := int(screen.session.revision)
		screen.combat_view._cast("cinder_fist")
		assert(await _wait_revision(screen, revision + 1))
		if screen.session.phase == "REWARD": break
	assert(screen.session.phase == "REWARD" and screen.video.stream == background)
	assert(not is_instance_valid(screen.combat_view))
	var candidate: Dictionary = screen.session.capture_candidate
	assert(screen.capture_sprite.texture.resource_path == "res://assets/entities/gameplay/homunculus/ingame/1024/%s.png" % candidate.id)
	assert(int(screen.state_data.crystals) == 3)
	var before := int(screen.session.revision)
	screen._send_phase_action("capture")
	var capture_pending: Dictionary = screen.pending.duplicate(true)
	assert(screen.playing_events and capture_pending.kind == "capture")
	await create_timer(0.4).timeout
	assert(int(screen.session.revision) == before and screen.playing_events)
	# Close the scene with the request unresolved; the account journal must
	# recover the same action regardless of whether the server committed it.
	screen = await _new_screen()
	assert(await _wait_revision(screen, before + 1))
	assert(int(screen.state_data.crystals) == 2)
	var capture_reward: Dictionary = screen.session.latest_reward
	assert(capture_reward.kind in ["capture_success", "capture_failure"])
	print("E5D3 capture outcome: ", capture_reward.kind)
	if capture_reward.kind == "capture_success":
		assert(is_instance_valid(screen.reward_popup))
		screen.reward_popup.acknowledged.emit()
		assert(Seen.has_seen(player_id, str(capture_reward.reward_id)))
	assert(Recovery.save_pending(player_id, "capture", capture_pending.payload))
	screen.pending = Recovery.load_pending(player_id)
	screen._refresh()
	assert(await _wait_revision(screen, before + 1))
	assert(int(screen.state_data.crystals) == 2 and not is_instance_valid(screen.reward_popup))
	screen._send_phase_action("skip")
	assert(await _wait_phase(screen, "ROUTE"))
	assert(screen.phase_buttons.size() == 3 and screen.video.stream == background)
	assert(await _fixture(screen, "crystal"))
	screen._refresh()
	assert(await _wait_state(screen))
	before = int(screen.session.revision)
	screen.phase_buttons[1].pressed.emit()
	var advance_pending: Dictionary = screen.pending.duplicate(true)
	assert(await _wait_phase(screen, "EXPLORE"))
	assert(screen.session.choices.size() == 2 and screen.session.latest_reward.kind == "crystal_drop" and screen.session.latest_reward.granted)
	assert(is_instance_valid(screen.reward_popup))
	var reward_id := str(screen.session.latest_reward.reward_id)
	screen.reward_popup.acknowledged.emit()
	assert(Seen.has_seen(player_id, reward_id))
	assert(Seen.mark_seen(player_id, "e5d3-extra-reward"))
	assert(Seen.has_seen(player_id, reward_id) and Seen.has_seen(player_id, "e5d3-extra-reward"))
	assert(Recovery.save_pending(player_id, "advance", advance_pending.payload))
	screen.pending = Recovery.load_pending(player_id)
	screen._refresh()
	assert(await _wait_revision(screen, before + 1))
	assert(not is_instance_valid(screen.reward_popup))
	assert(screen.exit_button.visible and not screen.exit_button.disabled)
	screen._confirm_exit()
	assert(screen.exit_confirmation.visible)
	screen.exit_confirmation.confirmed.emit()
	var exit_pending: Dictionary = screen.pending.duplicate(true)
	assert(exit_pending.kind == "exit")
	for i in 300:
		if not is_instance_valid(screen): break
		await create_timer(0.05).timeout
	assert(not is_instance_valid(screen))
	assert(Recovery.save_pending(player_id, "exit", exit_pending.payload))
	var recovered = await _new_screen()
	for i in 300:
		if not is_instance_valid(recovered): break
		await create_timer(0.05).timeout
	assert(not is_instance_valid(recovered) and Recovery.load_pending(player_id).is_empty())
	var http := HTTPRequest.new()
	root.add_child(http)
	assert(http.request(base_url + "/expeditions/state", PackedStringArray(["Authorization: Bearer " + token])) == OK)
	var response: Array = await http.request_completed
	var result: Dictionary = JSON.parse_string(response[3].get_string_from_utf8())
	assert(response[1] == 200 and result.session == null and int(result.remaining_cooldown_ms) > 0)
	http.queue_free()
	print("EXPEDITION_REAL_API_PASS E5D3")
	quit()

func _new_screen() -> Control:
	var previous := current_scene
	var screen = load("res://scenes/ui/Expeditions.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	if is_instance_valid(previous): previous.queue_free()
	await process_frame
	screen.backend.base_url = base_url
	screen.backend.token = token
	screen.backend._verified_player_id = player_id
	screen._identity_changed({"player_id":player_id})
	return screen

func _wait_state(screen: Control) -> bool:
	for i in 300:
		if not screen.state_data.is_empty() and screen.request.is_empty() and screen.pending.is_empty() and not screen.playing_events: return true
		await create_timer(0.05).timeout
	return false

func _wait_phase(screen: Control, phase: String) -> bool:
	for i in 400:
		if screen.session.get("phase") == phase and screen.pending.is_empty() and not screen.playing_events: return true
		await create_timer(0.05).timeout
	return false

func _wait_revision(screen: Control, revision: int) -> bool:
	for i in 400:
		if int(screen.session.get("revision", 0)) == revision and screen.pending.is_empty() and not screen.playing_events: return true
		await create_timer(0.05).timeout
	return false

func _fixture(screen: Control, kind: String) -> bool:
	var dir := OS.get_environment("EXPEDITION_FIXTURE_DIR").replace("\\", "/")
	var done := dir.path_join("fixture-done")
	if FileAccess.file_exists(done): DirAccess.remove_absolute(done)
	var file := FileAccess.open(dir.path_join("fixture-request.json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"kind":kind, "run_id":screen.session.run_id}))
	file.close()
	for i in 200:
		if FileAccess.file_exists(done): return true
		await create_timer(0.05).timeout
	return false

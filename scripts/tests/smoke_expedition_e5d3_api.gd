extends SceneTree

const Seen := preload("res://scripts/net/expedition_rewards_seen.gd")
var token := ""
var player_id := ""
var base_url := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for locale in ["en", "es"]:
		TranslationServer.set_locale(locale)
		var warning := tr("EXPEDITION_RISK_WARNING")
		assert(warning != "EXPEDITION_RISK_WARNING" and warning.contains("15") and warning.contains("60") and warning.contains("1"))
	TranslationServer.set_locale("en")
	token = OS.get_environment("EXPEDITION_TEST_TOKEN")
	player_id = OS.get_environment("EXPEDITION_TEST_PLAYER")
	base_url = OS.get_environment("EXPEDITION_TEST_URL")
	var gate := root.get_node("ConnectionGate")
	gate.player_id = player_id
	gate.token = token
	gate.base_url = base_url
	gate.state = gate.State.CONNECTED
	var old_journal := FileAccess.open("user://expedition_pending_legacy.json", FileAccess.WRITE)
	old_journal.store_string("{}")
	old_journal.close()
	var other_journal := FileAccess.open("user://session_recovery_fixture.json", FileAccess.WRITE)
	other_journal.store_string("untouched")
	other_journal.close()
	var payload := {"client_action_id":"e5e2-start", "entity_id":"sulfur_01", "weapon_ids":[null, null], "homunculus_id":"cinder", "spell_ids":["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], "mode":"attack"}
	SceneRouter._expedition_context = {"player_id":player_id, "pending_start":payload}
	var screen = await _new_screen()
	assert(await _wait_phase(screen, "EXPLORE"))
	assert(not FileAccess.file_exists("user://expedition_pending_legacy.json"))
	assert(FileAccess.get_file_as_string("user://session_recovery_fixture.json") == "untouched")
	assert(screen.lease.length() == 64 and screen.lease_run == screen.session.run_id)
	var run_id: String = screen.session.run_id
	assert(not JSON.stringify(screen.session.choices).contains("hom_id"))
	var first_heartbeat: HTTPRequest = screen.heartbeat_http
	assert(first_heartbeat != screen.backend._api_http and screen.heartbeat_timer.wait_time == 5.0)
	screen._heartbeat()
	for i in 100:
		if not screen.heartbeat_in_flight: break
		await create_timer(0.05).timeout
	assert(not screen.forfeited and screen.session.run_id == run_id)
	screen._select(0)
	assert(await _wait_phase(screen, "COMBAT"))
	var npc: Dictionary = screen.session.combat_state.npc
	var fought := str(npc.hom_id)
	assert(not fought.is_empty() and npc.hom_energy == 0)
	assert(is_instance_valid(screen.combat_view.enemy_hom_sprite))
	assert(screen.combat_view.enemy_hom_sprite.texture.resource_path == npc.hom_texture)
	assert(await _fixture(screen, "win"))
	screen._refresh()
	assert(await _wait_state(screen))
	for attempt in 3:
		var revision := int(screen.session.revision)
		screen.combat_view._cast("cinder_fist")
		assert(await _wait_revision(screen, revision + 1))
		if screen.session.phase == "REWARD": break
	assert(screen.session.phase == "REWARD")
	assert(screen.session.reward_homunculus.id == fought and screen.session.capture_candidate.id == fought)
	assert(screen.capture_sprite.texture.resource_path == npc.hom_texture)
	assert(is_instance_valid(screen.reward_popup))
	assert(screen.session.victory_reward.reward_id.ends_with(":victory"))
	var reward_buttons: Array = screen.reward_popup.find_children("*", "Button", true, false)
	var continue_button: Button
	for button in reward_buttons:
		if button.text == screen.tr("EXPEDITION_CONTINUE"): continue_button = button
	assert(is_instance_valid(continue_button))
	continue_button.pressed.emit()
	await process_frame
	assert(not is_instance_valid(screen.reward_popup))
	var before_capture: int = int(screen.session.revision)
	var heartbeats := {"count":0}
	screen.heartbeat_http.request_completed.connect(func(_result, code, _headers, _body):
		if code == 200: heartbeats.count += 1)
	screen.heartbeat_timer.wait_time = 0.25
	screen.heartbeat_timer.start()
	screen._send_phase_action("capture")
	assert(screen.playing_events)
	assert(await _wait_revision(screen, before_capture + 1))
	assert(not screen.forfeited and int(screen.state_data.crystals) == 2 and heartbeats.count > 0)
	screen.heartbeat_timer.wait_time = 5.0
	screen.heartbeat_timer.start()
	if is_instance_valid(screen.reward_popup): screen.reward_popup.acknowledged.emit()
	assert(screen.exit_button.visible and not screen.exit_button.disabled)
	screen._confirm_exit()
	assert(screen.exit_confirmation.visible and screen.exit_confirmation.dialog_text == screen.tr("EXPEDITION_RISK_WARNING"))
	screen.exit_confirmation.confirmed.emit()
	for i in 300:
		if not is_instance_valid(screen): break
		await create_timer(0.05).timeout
	assert(not is_instance_valid(screen))
	var recovered = await _new_screen()
	assert(await _wait_state(recovered))
	assert(recovered.session.is_empty() and recovered.lease.is_empty())
	var login_http := HTTPRequest.new()
	root.add_child(login_http)
	assert(login_http.request(base_url + "/auth/dev_login", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"name":"e5e2_interrupted"})) == OK)
	var login: Array = await login_http.request_completed
	assert(login[1] == 200)
	var account: Dictionary = JSON.parse_string(login[3].get_string_from_utf8())
	token = str(account.token)
	player_id = str(account.player_id)
	gate.player_id = player_id
	gate.token = token
	SceneRouter._expedition_context = {"player_id":player_id, "pending_start":payload}
	var interrupted = await _new_screen()
	assert(await _wait_phase(interrupted, "EXPLORE"))
	interrupted.backend.base_url = "http://127.0.0.1:1"
	interrupted._heartbeat()
	for i in 120:
		if interrupted.forfeited: break
		await create_timer(0.05).timeout
	assert(interrupted.forfeited and interrupted.lease.is_empty() and interrupted.session.is_empty())
	assert(interrupted.message.text == interrupted.tr("EXPEDITION_FORFEITED"))
	var restarted = await _new_screen()
	assert(await _wait_state(restarted))
	assert(restarted.session.is_empty() and restarted.lease.is_empty())
	assert(login_http.request(base_url + "/auth/dev_login", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"name":"e5e2_loss"})) == OK)
	login = await login_http.request_completed
	assert(login[1] == 200)
	account = JSON.parse_string(login[3].get_string_from_utf8())
	token = str(account.token)
	player_id = str(account.player_id)
	gate.player_id = player_id
	gate.token = token
	SceneRouter._expedition_context = {"player_id":player_id, "pending_start":payload}
	var losing = await _new_screen()
	assert(await _wait_phase(losing, "EXPLORE"))
	losing._select(0)
	assert(await _wait_phase(losing, "COMBAT"))
	assert(await _fixture(losing, "loss"))
	losing._refresh()
	assert(await _wait_state(losing))
	for attempt in 5:
		var previous: int = int(losing.session.revision)
		losing.combat_view._cast("cinder_fist")
		assert(await _wait_revision(losing, previous + 1))
		if losing.session.phase == "LOSS": break
	assert(losing.session.phase == "LOSS" and losing.lease.is_empty() and not losing.forfeited)
	login_http.queue_free()
	print("EXPEDITION_REAL_API_PASS E5E2")
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

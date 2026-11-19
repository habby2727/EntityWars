extends SceneTree

const ACTION_ID := "expired-hq-upgrade"
var client: BackendClient
var confirmed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("AUTH_E2E_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("isolated user directory required")
		return
	var scene := Control.new()
	root.add_child(scene)
	current_scene = scene
	client = BackendClient.new()
	client.auto_dev_login = false
	client.base_url = OS.get_environment("ENTITYWARS_BACKEND_URL")
	client.action_confirmed.connect(func(id):
		if id == ACTION_ID: confirmed += 1)
	scene.add_child(client)
	client.set_token(OS.get_environment("AUTH_E2E_TOKEN"))
	var gate := root.get_node("ConnectionGate")
	var deadline := Time.get_ticks_msec() + 20000
	while (gate.blocked() or client._verified_player_id.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if gate.blocked() or client._verified_player_id != OS.get_environment("AUTH_E2E_PLAYER"):
		_fail("initial identity not verified")
		return
	gate._timer.stop()
	await create_timer(9.0).timeout
	var id := client.send_action({"action_type": "UPGRADE_BUILDING", "client_action_id": ACTION_ID, "payload": {"building_id": "lab_th"}})
	if id != ACTION_ID:
		_fail("HQ action was not submitted")
		return
	deadline = Time.get_ticks_msec() + 15000
	while gate.state != gate.State.AUTH_REQUIRED and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if gate.state != gate.State.AUTH_REQUIRED or client.get_pending_count() != 1 or str(client.get_pending_actions()[0].client_action_id) != ACTION_ID:
		_fail("expired action did not remain pending")
		return
	gate.sign_in_again()
	var auth = current_scene
	deadline = Time.get_ticks_msec() + 10000
	while (auth.verifying or not auth.preflight_ok) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if auth.verifying or not auth.preflight_ok:
		_fail("sign-in screen did not become ready")
		return
	auth.username[0].text = "otheruser"
	auth.password[0].text = "secret1"
	auth._submit(0)
	deadline = Time.get_ticks_msec() + 10000
	while auth.busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if current_scene != auth or gate.player_id != OS.get_environment("AUTH_E2E_PLAYER") or auth.message.text != auth.tr("AUTH_RECOVERY_REQUIRED"):
		_fail("other account was accepted")
		return
	auth.username[0].text = "hqowner"
	auth.password[0].text = "secret1"
	auth._submit(0)
	deadline = Time.get_ticks_msec() + 20000
	while (current_scene != scene or gate.blocked() or confirmed != 1) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if current_scene != scene or gate.blocked() or confirmed != 1 or client.get_pending_count() != 0:
		_fail("same-account login did not complete original HQ action: gate=%s confirmed=%s pending=%s message=%s verifying=%s busy=%s" % [gate.state, confirmed, client.get_pending_count(), auth.message.text if is_instance_valid(auth) else "closed", auth.verifying if is_instance_valid(auth) else false, auth.busy if is_instance_valid(auth) else false])
		return
	var state := client.load_cached_state()
	if int(state.get("lab", {}).get("buildings", {}).get("lab_th", {}).get("level", 0)) != 2:
		_fail("HQ level was not upgraded once")
		return
	print("PASS expired token -> same account -> original HQ action confirmed once")
	quit(0)

func _fail(message: String) -> void:
	push_error("AUTH_E2E_FAIL: " + message)
	quit(1)

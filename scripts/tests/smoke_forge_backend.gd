extends SceneTree

var client: BackendClient
var phase := "login"
var latest := {}
var sent := 0
var confirmed := 0
var base_cost := 0
var step_cost := 0
const ITEM := "bismuth_talisman"
const FIRST_ID := "godot-forge-smoke-1"

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var balance_file := FileAccess.open("res://data/static/balance.json", FileAccess.READ)
	if balance_file == null:
		_fail("Balance data unavailable")
		return
	var parsed: Variant = JSON.parse_string(balance_file.get_as_text())
	if not parsed is Dictionary or not parsed.get("balance") is Dictionary:
		_fail("Invalid balance data")
		return
	base_cost = int(parsed.balance.get("forge_upgrade_essence_base", 20))
	step_cost = int(parsed.balance.get("forge_upgrade_essence_per_level", 10))
	if base_cost <= 0 or 100 - (base_cost * 3 + step_cost * 3) < 0 or 100 - (base_cost * 3 + step_cost * 3) >= base_cost + 3 * step_cost:
		_fail("Balance does not produce the expected insufficient-funds scenario")
		return
	var url := OS.get_environment("FORGE_SMOKE_URL")
	if not url.begins_with("http://127.0.0.1:") or OS.get_environment("FORGE_SMOKE_ISOLATED") != "1":
		_fail("Missing isolated localhost configuration")
		return
	var isolated_root := OS.get_environment("FORGE_SMOKE_USER_ROOT").replace("\\", "/").to_lower()
	if isolated_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(isolated_root + "/"):
		_fail("user:// is not inside the isolated test directory: " + OS.get_user_data_dir())
		return
	client = BackendClient.new()
	client.base_url = url
	client.auto_dev_login = false
	client.auto_flush = false
	client.auth_changed.connect(_auth_changed)
	client.state_updated.connect(_state_updated)
	client.action_sent.connect(_action_sent)
	client.action_confirmed.connect(_action_confirmed)
	client.action_failed.connect(_action_failed)
	root.add_child(client)
	create_timer(25.0).timeout.connect(func(): _fail("Timeout at " + phase))
	client.login_dev("godot_forge_smoke")

func _auth_changed(token: String) -> void:
	if phase == "login" and token != "":
		phase = "initial"
		client.call_deferred("refresh_state")

func _state_updated(state: Dictionary) -> void:
	latest = state
	var level := int(state.get("item_progress", {}).get(ITEM, {}).get("level", 0))
	var essence := int(state.get("wallet", {}).get("essence", -1))
	if phase == "initial":
		if level != 0 or essence != 100:
			_fail("Initial fixture mismatch: %d / %d" % [level, essence])
			return
		print("INITIAL level=", level, " essence=", essence)
		phase = "upgrade"
		call_deferred("_send", FIRST_ID)
	elif phase == "reload":
		if level != 1 or essence != 100 - base_cost:
			_fail("Reload mismatch: %d / %d" % [level, essence])
			return
		phase = "duplicate"
		call_deferred("_send", FIRST_ID)
	elif phase == "rejection_reload":
		if level != 3 or essence != 100 - (base_cost * 3 + step_cost * 3):
			_fail("Rejected action changed persisted state")
			return
		print("PASS Godot/Bun: login, upgrade, reload, idempotency and insufficient resources")
		client.queue_free()
		quit(0)

func _send(id: String) -> void:
	if client.send_action({"action_type": "FORGE_UPGRADE", "client_action_id": id, "payload": {"item_id": ITEM}}) == "":
		_fail("Could not send action in " + phase)

func _action_sent(_id: String, _key: String) -> void:
	sent += 1

func _action_confirmed(_id: String) -> void:
	confirmed += 1
	var level := int(latest.get("item_progress", {}).get(ITEM, {}).get("level", 0))
	var essence := int(latest.get("wallet", {}).get("essence", -1))
	match phase:
		"upgrade":
			if level != 1 or essence != 100 - base_cost:
				_fail("Upgrade mismatch: %d / %d" % [level, essence])
				return
			print("UPGRADE level=", level, " essence=", essence)
			phase = "reload"
			client.call_deferred("refresh_state")
		"duplicate":
			if level != 1 or essence != 100 - base_cost:
				_fail("Duplicate charged again")
				return
			phase = "conflict"
			call_deferred("_send_conflict")
		"second":
			phase = "third"
			call_deferred("_send", "godot-forge-smoke-3")
		"third":
			if level != 3 or essence != 100 - (base_cost * 3 + step_cost * 3):
				_fail("Additional upgrades mismatch: %d / %d" % [level, essence])
				return
			phase = "insufficient"
			call_deferred("_send", "godot-forge-smoke-4")

func _action_failed(_id: String, error: String) -> void:
	if phase == "conflict" and error.contains("different content"):
		phase = "second"
		call_deferred("_send", "godot-forge-smoke-2")
		return
	if phase == "insufficient" and error.contains("Insufficient") and sent == 6 and confirmed == 4:
		phase = "rejection_reload"
		client.call_deferred("refresh_state")
		return
	_fail("Unexpected failure at %s: %s" % [phase, error])

func _send_conflict() -> void:
	if client.send_action({"action_type": "FORGE_UPGRADE", "client_action_id": FIRST_ID, "payload": {"item_id": "wind_amulet"}}) == "":
		_fail("Could not send conflict")

func _fail(message: String) -> void:
	push_error("FORGE_SMOKE_FAIL: " + message)
	quit(1)

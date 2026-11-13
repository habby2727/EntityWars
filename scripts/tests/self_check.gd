extends Node
class_name SelfCheck

@export var backend_url := "http://127.0.0.1:8787"

const REQUIRED_ASSET_IDS := [
	"lab_th",
	"essence_reactor",
	"storage_vault",
	"build_forge",
	"homunculus_vat",
	"ultrahit_tower",
	"experiment_chamber",
	"arcane_archives",
	"sync_nexus",
	"anomaly_containment",
	"trade_hall",
	"world_gate",
	"essence",
	"core",
	"arcane_shard",
	"time_crystal",
	"ui_panel",
	"button_base",
	"button_hover",
	"icon_slot_frame"
]

func run_all() -> void:
	print("SelfCheck: start")
	_check_static_db()
	_check_assets()
	_check_scenes()
	await _check_backend()
	print("SelfCheck: done")

func _check_static_db() -> void:
	var db := StaticDB.new()
	var ok = db.validate_all()
	if ok:
		print("SelfCheck: StaticDB validate_all OK")
	else:
		push_error("SelfCheck: StaticDB validate_all FAILED")

func _check_assets() -> void:
	var catalog := AssetCatalog.new()
	var missing: Array = []
	for id in REQUIRED_ASSET_IDS:
		if not catalog.has(id):
			missing.append(id)
	if missing.is_empty():
		print("SelfCheck: AssetCatalog required ids OK")
	else:
		push_error("SelfCheck: AssetCatalog missing ids: %s" % ", ".join(missing))

func _check_scenes() -> void:
	_check_scene("res://scenes/ui/Lab.tscn")
	_check_scene("res://scenes/ui/Inventory.tscn")

func _check_scene(path: String) -> void:
	var packed = load(path)
	if packed == null:
		push_error("SelfCheck: Missing scene %s" % path)
		return
	if not (packed is PackedScene):
		push_error("SelfCheck: Invalid PackedScene %s" % path)
		return
	var instance = packed.instantiate()
	if instance == null:
		push_error("SelfCheck: Failed to instantiate %s" % path)
		return
	instance.queue_free()
	print("SelfCheck: Scene loaded %s" % path)

func _check_backend() -> void:
	var version = await _request_json("GET", "/static/version", null, "")
	if not version.ok:
		push_warning("SelfCheck: Backend not reachable; skipping net checks")
		return
	print("SelfCheck: Backend /static/version OK")
	var login = await _request_json("POST", "/auth/dev_login", {"name": "self_check"}, "")
	if not login.ok:
		push_warning("SelfCheck: dev_login failed; skipping net checks")
		return
	var token = str(login.data.get("token", ""))
	if token == "":
		push_warning("SelfCheck: dev_login missing token; skipping net checks")
		return
	var state_resp = await _request_json("GET", "/player/state", null, token)
	if not state_resp.ok:
		push_warning("SelfCheck: state fetch failed")
		return
	var action_id = _make_action_id()
	var action_body = {
		"client_action_id": action_id,
		"action_type": "SET_BUILDING_ROUTE",
		"client_time_unix_ms": Time.get_unix_time_from_system() * 1000,
		"payload": {"building_id": "lab_th", "route": "Scientific"}
	}
	var first = await _request_json("POST", "/player/action", action_body, token)
	var second = await _request_json("POST", "/player/action", action_body, token)
	if first.ok and second.ok:
		print("SelfCheck: action idempotency OK")
	else:
		push_warning("SelfCheck: action idempotency failed")
	var invalid_action = {
		"client_action_id": _make_action_id(),
		"action_type": "UPGRADE_BUILDING",
		"client_time_unix_ms": Time.get_unix_time_from_system() * 1000,
		"payload": {"building_id": "world_gate"}
	}
	await _request_json("POST", "/player/action", invalid_action, token)
	var after_state = await _request_json("GET", "/player/state", null, token)
	if after_state.ok:
		if _wallet_has_negative(after_state.data):
			push_error("SelfCheck: wallet negative after invalid spend")
		else:
			print("SelfCheck: wallet non-negative after invalid spend")
	var claim_action = {
		"client_action_id": _make_action_id(),
		"action_type": "CLAIM_PRODUCTION",
		"client_time_unix_ms": Time.get_unix_time_from_system() * 1000,
		"payload": {"building_id": "essence_reactor"}
	}
	var claim_resp = await _request_json("POST", "/player/action", claim_action, token)
	if claim_resp.ok:
		var stored = _get_stored_output(claim_resp.data)
		if stored < 0:
			push_error("SelfCheck: stored_output negative after claim")
		else:
			print("SelfCheck: claim stored_output OK")

func _wallet_has_negative(data: Dictionary) -> bool:
	var state = data.get("updated_player_state", data)
	var wallet = state.get("wallet", {})
	if typeof(wallet) != TYPE_DICTIONARY:
		return false
	for key in wallet.keys():
		if int(wallet[key]) < 0:
			return true
	return false

func _get_stored_output(data: Dictionary) -> float:
	var state = data.get("updated_player_state", data)
	var lab = state.get("lab", {})
	var buildings = lab.get("buildings", {})
	var reactor = buildings.get("essence_reactor", {})
	var runtime = reactor.get("runtime", {})
	return float(runtime.get("stored_output", 0.0))

func _make_action_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x" % rng.randi()

func _request_json(method: String, path: String, body: Variant, token: String) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer %s" % token)
	var body_text := ""
	if body != null:
		body_text = JSON.stringify(body)
	var http_method := HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST
	var err = req.request(backend_url + path, headers, http_method, body_text)
	if err != OK:
		req.queue_free()
		return {"ok": false}
	var result = await req.request_completed
	req.queue_free()
	var response_code = int(result[1])
	var body_bytes: PackedByteArray = result[3]
	var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
	var data := {}
	if typeof(parsed) == TYPE_DICTIONARY:
		data = parsed
	elif typeof(parsed) == TYPE_OBJECT:
		data = parsed.result
	var ok = response_code >= 200 and response_code < 300 and (not data.has("ok") or bool(data.get("ok", true)))
	return {"ok": ok, "status": response_code, "data": data}

extends Node

const RECOVERY_FILE := "user://woe_recovery.cfg"
var mutation_busy := false
var pending := {}
var _pending_key := ""

func identity() -> String:
	return JSON.stringify([str(ConnectionGate.player_id), str(ConnectionGate.token), str(ConnectionGate.base_url), int(ConnectionGate._generation)])

func account_key() -> String:
	return JSON.stringify([str(ConnectionGate.base_url).strip_edges().trim_suffix("/"), str(ConnectionGate.player_id)]).sha256_text()

func available() -> bool:
	return not ConnectionGate.blocked() and not str(ConnectionGate.player_id).is_empty() and not str(ConnectionGate.token).is_empty() and not str(ConnectionGate.base_url).is_empty()

func _config() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(RECOVERY_FILE)
	return cfg

func saved_room() -> String:
	if not available(): return ""
	return str(_config().get_value("rooms", account_key(), ""))

func save_room(room_id: String) -> void:
	if not available(): return
	var cfg := _config()
	cfg.set_value("rooms", account_key(), room_id)
	if cfg.save(RECOVERY_FILE) != OK: push_warning("WOE recovery could not be saved")

func saved_pending() -> Dictionary:
	if not available(): return {}
	var value: Variant = _config().get_value("pending", account_key(), {})
	return value if value is Dictionary else {}

func _save_pending(value: Dictionary) -> void:
	if not available(): return
	var cfg := _config()
	cfg.set_value("pending", account_key(), value)
	if cfg.save(RECOVERY_FILE) != OK: push_warning("WOE pending action could not be saved")

func valid_room(data: Variant, player: String) -> bool:
	if not data is Dictionary or not data.get("room_id") is String or str(data.room_id).is_empty() or not data.get("members") is Array: return false
	if data.get("mode") not in ["1v1", "2v2"] or data.get("status") not in ["WAITING", "STARTED"]: return false
	for member in data.members:
		if member is Dictionary and str(member.get("player_id", "")) == player: return true
	return false

func saved_match() -> String:
	if not available(): return ""
	return str(_config().get_value("matches", account_key(), ""))

func save_match(match_id: String) -> void:
	if not available(): return
	var cfg := _config()
	cfg.set_value("matches", account_key(), match_id)
	if cfg.save(RECOVERY_FILE) != OK: push_warning("WOE match recovery could not be saved")

func saved_forfeit() -> String:
	if not available(): return ""
	return str(_config().get_value("forfeited", account_key(), ""))

func save_forfeit(match_id: String) -> void:
	if not available(): return
	var cfg := _config()
	cfg.set_value("forfeited", account_key(), match_id)
	if cfg.save(RECOVERY_FILE) != OK: push_warning("WOE forfeit recovery could not be saved")

func valid_match(data: Variant, player: String) -> bool:
	if not data is Dictionary or not data.get("match_id") is String or str(data.match_id).is_empty(): return false
	if data.get("status") not in ["RUNNING", "FINISHED"] or not data.get("snapshot") is Dictionary: return false
	var players: Variant = data.snapshot.get("players")
	if not players is Array: return false
	var found := false
	for entry in players:
		if not entry is Dictionary: return false
		if str(entry.get("id", "")) == player:
			found = entry.get("slots") is Array and entry.has("zeal")
		elif entry.has("slots") or entry.has("zeal"): return false
	return found

func request(path: String, body: Variant = null, request_owner: Node = null) -> Dictionary:
	if not available(): return {"code":0,"error":"WOE_NETWORK"}
	var key := identity()
	var http := HTTPRequest.new()
	http.timeout = 8.0
	http.max_redirects = 0
	if is_instance_valid(request_owner): request_owner.add_child(http)
	else: add_child(http)
	var err := http.request(str(ConnectionGate.base_url).trim_suffix("/") + path, SocialClient._headers(), HTTPClient.METHOD_GET if body == null else HTTPClient.METHOD_POST, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"code":0,"error":"WOE_NETWORK"}
	var response: Array = await http.request_completed
	http.queue_free()
	if key != identity(): return {"code":0,"error":"WOE_IDENTITY_CHANGED"}
	var code := int(response[1])
	var data: Variant = SocialClient._decode(response[3])
	if SocialClient._auth_response(int(response[0]), code, data): return {"code":code,"error":"WOE_AUTH"}
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS: return {"code":0,"error":"WOE_NETWORK"}
	return {"code":code,"data":data if data is Dictionary else {},"error":str(data.get("error", "")) if data is Dictionary else "WOE_NETWORK"}

func mutate(action: String, values: Dictionary = {}) -> Dictionary:
	if not available() or mutation_busy: return {"code":0,"error":"WOE_BUSY"}
	var key := identity()
	var account := account_key()
	var saved := saved_pending()
	if not saved.is_empty():
		if str(saved.get("action", "")) != action or saved.get("values", {}) != values:
			return {"code":0,"error":"WOE_RETRY_PENDING"}
		pending = saved
	else:
		var body := values.duplicate(true)
		body.client_action_id = "%s-%s" % [Time.get_ticks_usec(), Crypto.new().generate_random_bytes(16).hex_encode()]
		pending = {"action":action,"values":values.duplicate(true),"body":body}
		_save_pending(pending)
	_pending_key = account
	mutation_busy = true
	var result: Dictionary = await request("/forest/woe/" + action, pending.body)
	mutation_busy = false
	if key != identity() or account != account_key(): return {"code":0,"error":"WOE_IDENTITY_CHANGED"}
	var code := int(result.code)
	if code == 200 and action in ["create", "join"] and not valid_room(result.get("data"), str(ConnectionGate.player_id)):
		return {"code":0,"error":"WOE_NETWORK"}
	if code > 0 and code < 500 and code != 408:
		_save_pending({})
		pending = {}
		if code == 200:
			var data: Variant = result.get("data", {})
			if action in ["create", "join"] and valid_room(data, str(ConnectionGate.player_id)): save_room(str(data.room_id))
			if action == "leave": save_room("")
	return result

func retry_pending() -> Dictionary:
	var saved := saved_pending()
	if saved.is_empty(): return {"code":0,"error":"WOE_NETWORK"}
	return await mutate(str(saved.get("action", "")), saved.get("values", {}))

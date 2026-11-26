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

func recovery_file() -> String:
	return RECOVERY_FILE

func _config() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(recovery_file())
	return cfg

func saved_room() -> String:
	if not available(): return ""
	return str(_config().get_value("rooms", account_key(), ""))

func save_room(room_id: String) -> void:
	if not available(): return
	var cfg := _config()
	cfg.set_value("rooms", account_key(), room_id)
	if cfg.save(recovery_file()) != OK: push_warning("WOE recovery could not be saved")

func saved_pending() -> Dictionary:
	if not available(): return {}
	var value: Variant = _config().get_value("pending", account_key(), {})
	return value if value is Dictionary else {}

func _save_pending(value: Dictionary) -> bool:
	if not available(): return false
	var cfg := _config()
	cfg.set_value("pending", account_key(), value)
	return cfg.save(recovery_file()) == OK

func reconcile_started(room: Dictionary) -> void:
	var saved := saved_pending()
	if valid_room(room, str(ConnectionGate.player_id)) and room.get("status") == "STARTED" and saved.get("action") == "start" and str(saved.get("values", {}).get("room_id", "")) == str(room.get("room_id", "")):
		if _save_pending({}): pending = {}

func reconcile_terminal(match_data: Dictionary) -> bool:
	if not available() or not valid_match(match_data, str(ConnectionGate.player_id)) or match_data.get("status") != "FINISHED": return false
	var saved := saved_pending()
	if str(saved.get("action", "")).begins_with("match/") and str(saved.get("values", {}).get("match_id", "")) == str(match_data.match_id):
		if not _save_pending({}): return false
		pending = {}
	return true

func reconcile_missing_match(match_id: String, error: String) -> bool:
	if not available() or match_id.is_empty() or error not in ["MATCH_UNAVAILABLE", "NOT_PARTICIPANT"]: return false
	var cfg := _config()
	var saved: Variant = cfg.get_value("pending", account_key(), {})
	if saved is Dictionary and str(saved.get("action", "")).begins_with("match/") and str(saved.get("values", {}).get("match_id", "")) == match_id: cfg.set_value("pending", account_key(), {})
	if str(cfg.get_value("matches", account_key(), "")) == match_id: cfg.set_value("matches", account_key(), "")
	if cfg.save(recovery_file()) != OK: return false
	if str(pending.get("values", {}).get("match_id", "")) == match_id: pending = {}
	return true

func reconcile_missing_room(room_id: String) -> bool:
	if not available() or room_id.is_empty(): return false
	var cfg := _config()
	var saved: Variant = cfg.get_value("pending", account_key(), {})
	if saved is Dictionary and saved.get("action") in ["start", "leave"] and str(saved.get("values", {}).get("room_id", "")) == room_id: cfg.set_value("pending", account_key(), {})
	if str(cfg.get_value("rooms", account_key(), "")) == room_id: cfg.set_value("rooms", account_key(), "")
	if cfg.save(recovery_file()) != OK: return false
	if str(pending.get("values", {}).get("room_id", "")) == room_id: pending = {}
	return true

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
	if cfg.save(recovery_file()) != OK: push_warning("WOE match recovery could not be saved")

func saved_forfeit() -> String:
	if not available(): return ""
	return str(_config().get_value("forfeited", account_key(), ""))

func save_forfeit(match_id: String) -> void:
	if not available(): return
	var cfg := _config()
	cfg.set_value("forfeited", account_key(), match_id)
	if cfg.save(recovery_file()) != OK: push_warning("WOE forfeit recovery could not be saved")

func valid_match(data: Variant, player: String) -> bool:
	if not data is Dictionary or not data.get("match_id") is String or str(data.match_id).is_empty(): return false
	if data.get("status") not in ["RUNNING", "FINISHED"] or not data.get("snapshot") is Dictionary: return false
	if data.snapshot.get("kind") != "woe": return false
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
	var retry_after := 0.0
	for header in response[2]:
		var line := str(header)
		if line.to_lower().begins_with("retry-after:"):
			var value := line.substr(line.find(":") + 1).strip_edges()
			if value.is_valid_float(): retry_after = maxf(0.0, value.to_float())
			else:
				var parts := value.replace(",", "").split(" ", false)
				var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
				if parts.size() == 6 and parts[1].is_valid_int() and parts[3].is_valid_int() and parts[2] in months:
					var clock := parts[4].split(":")
					if clock.size() == 3 and clock[0].is_valid_int() and clock[1].is_valid_int() and clock[2].is_valid_int():
						var date := {"year":int(parts[3]), "month":months.find(parts[2]) + 1, "day":int(parts[1]), "hour":int(clock[0]), "minute":int(clock[1]), "second":int(clock[2])}
						retry_after = maxf(0.0, float(Time.get_unix_time_from_datetime_dict(date)) - Time.get_unix_time_from_system())
	return {"code":code,"data":data if data is Dictionary else {},"error":str(data.get("error", "")) if data is Dictionary else "WOE_NETWORK","retry_after":retry_after}

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
		if not _save_pending(pending):
			pending = {}
			return {"code":0,"error":"WOE_RECOVERY_STORAGE"}
	_pending_key = account
	mutation_busy = true
	var result: Dictionary = await request("/forest/woe/" + action, pending.body)
	mutation_busy = false
	if key != identity() or account != account_key(): return {"code":0,"error":"WOE_IDENTITY_CHANGED"}
	var code := int(result.code)
	if code == 200 and action in ["create", "join"] and not valid_room(result.get("data"), str(ConnectionGate.player_id)):
		return {"code":0,"error":"WOE_NETWORK"}
	if code == 200 and action.begins_with("match/") and (not valid_match(result.get("data"), str(ConnectionGate.player_id)) or str(result.data.match_id) != str(values.get("match_id", ""))): return {"code":0,"error":"WOE_NETWORK"}
	var definitive_limit := code == 429 and str(result.get("error", "")) in ["ACTION_LIMIT", "MATCH_LIMIT", "ROOM_LIMIT"]
	if code > 0 and code < 500 and code != 408 and (code != 429 or definitive_limit):
		if not _save_pending({}): return {"code":0,"error":"WOE_RECOVERY_STORAGE"}
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

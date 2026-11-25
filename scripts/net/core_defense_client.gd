extends "res://scripts/net/woe_client.gd"

var server_time_ms := 0
var server_tick_ms := 0
var _request_busy := false

func recovery_file() -> String:
	return "user://core_defense_recovery.cfg"

func valid_room(data: Variant, player: String) -> bool:
	if not data is Dictionary or not data.get("room_id") is String or str(data.room_id).is_empty() or not data.get("members") is Array: return false
	if data.get("mode") not in ["solo", "coop", "solo_bot"] or data.get("status") not in ["WAITING", "STARTED"]: return false
	if data.status == "WAITING" and data.mode != "coop": return false
	if data.status == "STARTED" and (not data.get("snapshot") is Dictionary or data.snapshot.get("kind") != "core_defense" or str(data.get("match_id", "")).is_empty() or not _valid_players(data.snapshot, player)): return false
	for member in data.members:
		if member is Dictionary and str(member.get("player_id", "")) == player: return true
	return false

func valid_match(data: Variant, player: String) -> bool:
	if not data is Dictionary or not data.get("snapshot") is Dictionary or data.snapshot.get("kind") != "core_defense": return false
	if not data.get("match_id") is String or str(data.match_id).is_empty() or data.get("status") not in ["RUNNING", "FINISHED"]: return false
	if data.snapshot.get("mode") not in ["solo", "coop", "solo_bot"]: return false
	return _valid_players(data.snapshot, player)

func _valid_players(snapshot: Dictionary, player: String) -> bool:
	if not snapshot.get("players") is Array: return false
	var found := false
	for entry in snapshot.players:
		if not entry is Dictionary or entry.get("team") != "blue": return false
		if str(entry.get("id", "")) == player: found = entry.get("slots") is Array and entry.has("zeal")
		elif entry.has("slots") or entry.has("zeal"): return false
	return found

func authoritative_time() -> int:
	return server_time_ms + maxi(0, Time.get_ticks_msec() - server_tick_ms) if server_time_ms > 0 else 0

func request(path: String, body: Variant = null, request_owner: Node = null) -> Dictionary:
	var key := identity()
	while _request_busy:
		await get_tree().process_frame
		if key != identity(): return {"code":0,"error":"WOE_IDENTITY_CHANGED"}
	_request_busy = true
	var result: Dictionary = await super.request(path, body, null)
	_request_busy = false
	if key == identity() and result.get("data") is Dictionary and int(result.data.get("server_time_unix_ms", 0)) > 0:
		server_time_ms = int(result.data.server_time_unix_ms)
		server_tick_ms = Time.get_ticks_msec()
	return result

func mutate(action: String, values: Dictionary = {}) -> Dictionary:
	if action == "match/forfeit": return await _forfeit(values)
	if not available() or mutation_busy: return {"code":0,"error":"WOE_BUSY"}
	var key := identity()
	var account := account_key()
	var saved := saved_pending()
	if not saved.is_empty():
		if str(saved.get("action", "")) != action or saved.get("values", {}) != values: return {"code":0,"error":"WOE_RETRY_PENDING"}
		pending = saved
	else:
		var body := values.duplicate(true)
		if action == "match/deploy":
			var stamp := authoritative_time()
			if stamp <= 0: return {"code":0,"error":"CD_TIME_REQUIRED"}
			body.client_action_id = "%d:%s" % [stamp, Crypto.new().generate_random_bytes(16).hex_encode()]
		else:
			body.client_action_id = "%s-%s" % [Time.get_ticks_usec(), Crypto.new().generate_random_bytes(16).hex_encode()]
		pending = {"action":action,"values":values.duplicate(true),"body":body}
		if not _persist_pending(pending):
			pending = {}
			return {"code":0,"error":"CD_RECOVERY_STORAGE"}
	mutation_busy = true
	var result: Dictionary = await request("/forest/core-defense/" + action, pending.body)
	mutation_busy = false
	if key != identity() or account != account_key(): return {"code":0,"error":"WOE_IDENTITY_CHANGED"}
	var code := int(result.get("code", 0))
	if code == 200 and action in ["create", "start"] and not valid_room(result.get("data"), str(ConnectionGate.player_id)): return {"code":0,"error":"WOE_NETWORK"}
	if code == 200 and action == "match/deploy" and (not result.get("data") is Dictionary or not bool(result.data.get("accepted", false)) or str(result.data.get("match_id", "")) != str(values.get("match_id", ""))): return {"code":0,"error":"WOE_NETWORK"}
	if code == 200 and action == "create" and not persist_room(str(result.data.room_id)): return {"code":0,"error":"CD_RECOVERY_STORAGE"}
	if code > 0 and code < 500 and code != 408 and code != 429:
		_save_pending({})
		pending = {}
		if code == 200 and action == "leave": save_room("")
	return result

func persist_room(room_id: String) -> bool:
	if not available(): return false
	var cfg := _config()
	cfg.set_value("rooms", account_key(), room_id)
	return cfg.save(recovery_file()) == OK

func _persist_pending(value: Dictionary) -> bool:
	if not available(): return false
	var cfg := _config()
	cfg.set_value("pending", account_key(), value)
	return cfg.save(recovery_file()) == OK

# A confirmed STARTED room reconciles an uncertain start without resubmission.
func reconcile_started(room: Dictionary) -> void:
	var saved := saved_pending()
	if valid_room(room, str(ConnectionGate.player_id)) and room.get("status") == "STARTED" and saved.get("action") == "start" and str(saved.get("values", {}).get("room_id", "")) == str(room.get("room_id", "")):
		_save_pending({})
		pending = {}

func saved_forfeit_action() -> Dictionary:
	if not available(): return {}
	var value: Variant = _config().get_value("forfeit_pending", account_key(), {})
	return value if value is Dictionary else {}

func _save_forfeit_action(value: Dictionary) -> bool:
	if not available(): return false
	var cfg := _config()
	cfg.set_value("forfeit_pending", account_key(), value)
	return cfg.save(recovery_file()) == OK

func retry_forfeit() -> Dictionary:
	var saved := saved_forfeit_action()
	if saved.is_empty(): return {"code":0,"error":"WOE_NETWORK"}
	return await _forfeit(saved.get("values", {}))

func _forfeit(values: Dictionary) -> Dictionary:
	if not available() or mutation_busy: return {"code":0,"error":"WOE_BUSY"}
	var key := identity()
	var account := account_key()
	var saved := saved_forfeit_action()
	if not saved.is_empty() and saved.get("values", {}) != values: return {"code":0,"error":"WOE_RETRY_PENDING"}
	if saved.is_empty():
		var body := values.duplicate(true)
		body.client_action_id = "%s-%s" % [Time.get_ticks_usec(), Crypto.new().generate_random_bytes(16).hex_encode()]
		saved = {"values":values.duplicate(true),"body":body}
		if not _save_forfeit_action(saved): return {"code":0,"error":"CD_RECOVERY_STORAGE"}
	mutation_busy = true
	var result: Dictionary = await request("/forest/core-defense/match/forfeit", saved.body)
	mutation_busy = false
	if key != identity() or account != account_key(): return {"code":0,"error":"WOE_IDENTITY_CHANGED"}
	var code := int(result.get("code", 0))
	if code == 200 and (not valid_match(result.get("data"), str(ConnectionGate.player_id)) or str(result.data.get("match_id", "")) != str(values.get("match_id", ""))): return {"code":0,"error":"WOE_NETWORK"}
	if code > 0 and code < 500 and code != 408 and code != 429:
		_save_forfeit_action({})
		if code == 200 or str(result.get("error", "")) == "MATCH_FINISHED":
			_save_pending({})
			pending = {}
	return result

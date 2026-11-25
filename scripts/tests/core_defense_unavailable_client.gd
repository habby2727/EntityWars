extends "res://scripts/net/core_defense_client.gd"
var room_code := 503
func recovery_file() -> String:
	return "user://cd_unavailable_smoke.cfg"
func request(path: String, _body: Variant = null, _owner: Node = null) -> Dictionary:
	if path.begins_with("/forest/core-defense/state?"):
		return {"code":room_code, "error":"ROOM_UNAVAILABLE" if room_code == 404 else "FOREST_CORE_DEFENSE_UNAVAILABLE", "data":{}}
	if path == "/forest/core-defense/match/current":
		return {"code":503, "error":"FOREST_CORE_DEFENSE_UNAVAILABLE", "data":{}}
	return {"code":503, "error":"FOREST_CORE_DEFENSE_UNAVAILABLE", "data":{}}

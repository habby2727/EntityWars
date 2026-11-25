extends "res://scripts/net/woe_client.gd"

var state_code := 404

func request(path: String, _body: Variant = null, _owner: Node = null) -> Dictionary:
	var room := {"room_id":"fixture-room", "mode":"1v1", "status":"WAITING", "members":[{"player_id":str(ConnectionGate.player_id)}]}
	if path == "/forest/minigames/invite/respond": return {"code":200, "data":{"status":"ACCEPTED", "room":room}}
	if path.begins_with("/forest/woe/state?"):
		if state_code == 200: return {"code":200, "data":room}
		return {"code":state_code, "error":"ROOM_UNAVAILABLE" if state_code == 404 else "WOE_NETWORK"}
	return {"code":0, "error":"WOE_NETWORK"}

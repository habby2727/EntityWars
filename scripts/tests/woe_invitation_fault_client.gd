extends "res://scripts/net/woe_client.gd"

var drop_accept_response := true
var accept_bodies: Array = []
var drop_start_response := true
var start_bodies: Array = []

func request(path: String, body: Variant = null, request_owner: Node = null) -> Dictionary:
	if OS.get_environment("FOREST_WOE_LOST_START") == "1" and path == "/forest/woe/start" and body is Dictionary:
		start_bodies.append(body.duplicate(true))
		var result: Dictionary = await super.request(path, body, request_owner)
		if drop_start_response and result.code == 200:
			drop_start_response = false
			return {"code":0,"error":"WOE_NETWORK"}
		return result
	if path == "/forest/minigames/invite/respond" and body is Dictionary and body.get("accept", false):
		accept_bodies.append(body.duplicate(true))
		var result: Dictionary = await super.request(path, body, request_owner)
		if drop_accept_response and result.code == 200:
			drop_accept_response = false
			return {"code":0, "error":"WOE_NETWORK"}
		return result
	return await super.request(path, body, request_owner)

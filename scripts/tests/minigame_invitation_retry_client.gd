extends "res://scripts/net/woe_client.gd"

var calls: Array = []
var send_count := 0

func request(path: String, body: Variant = null, _owner: Node = null) -> Dictionary:
	if path == "/forest/minigames/invite":
		calls.append(body.duplicate(true))
		send_count += 1
		await get_tree().create_timer(0.3).timeout
		if send_count == 1: return {"code":429, "error":"RATE_LIMITED", "retry_after":1.0}
		return {"code":200, "data":{"status":"PENDING"}}
	return {"code":0, "error":"WOE_NETWORK"}

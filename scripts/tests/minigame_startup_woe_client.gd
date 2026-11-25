extends "res://scripts/net/woe_client.gd"

var fixture_status := "FINISHED"

func request(path: String, _body: Variant = null, _owner: Node = null) -> Dictionary:
	if path == "/forest/woe/match/current":
		return {"code":200, "data":{"match_id":"woe-fixture", "status":fixture_status, "snapshot":{"kind":"woe", "players":[{"id":str(ConnectionGate.player_id), "team":"blue", "slots":[], "zeal":5}]}}}
	return {"code":0, "error":"WOE_NETWORK"}

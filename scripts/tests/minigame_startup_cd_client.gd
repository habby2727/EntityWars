extends "res://scripts/net/core_defense_client.gd"

var fixture_status := "RUNNING"

func request(path: String, _body: Variant = null, _owner: Node = null) -> Dictionary:
	if path == "/forest/core-defense/match/current":
		return {"code":200, "data":{"match_id":"cd-fixture", "status":fixture_status, "snapshot":{"kind":"core_defense", "mode":"solo", "players":[{"id":str(ConnectionGate.player_id), "team":"blue", "slots":[], "zeal":5}]}}}
	return {"code":0, "error":"WOE_NETWORK"}

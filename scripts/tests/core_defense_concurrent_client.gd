extends "res://scripts/net/core_defense_client.gd"

var mutation_pending := false

func _transport_request(path: String, body: Variant = null) -> Dictionary:
	if body is Dictionary:
		mutation_pending = true
		await get_tree().create_timer(0.4).timeout
		mutation_pending = false
		return {"code":200,"data":{}}
	if path.ends_with("old"):
		await get_tree().create_timer(0.3).timeout
		return {"code":200,"data":{"server_time_unix_ms":1700000000000}}
	await get_tree().create_timer(0.02).timeout
	return {"code":200,"data":{"server_time_unix_ms":1700000001000}}

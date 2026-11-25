extends "res://scripts/net/woe_client.gd"

var responses: Array = []
var bodies: Array[Dictionary] = []
var fail_storage := false

func recovery_file() -> String:
	return "user://woe_recovery_r1_smoke.cfg"

func _save_pending(value: Dictionary) -> bool:
	if fail_storage: return false
	return super._save_pending(value)

func request(_path: String, body: Variant = null, _owner: Node = null) -> Dictionary:
	if body is Dictionary: bodies.append(body.duplicate(true))
	return responses.pop_front()

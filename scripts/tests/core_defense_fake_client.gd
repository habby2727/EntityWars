extends "res://scripts/net/core_defense_client.gd"
var responses: Array = []
var bodies: Array[Dictionary] = []
func recovery_file() -> String:
	return "user://cd_recovery_smoke.cfg"
func request(_path: String, body: Variant = null, _owner: Node = null) -> Dictionary:
	if body is Dictionary: bodies.append(body.duplicate(true))
	return responses.pop_front()

var fail_storage := false
func _persist_pending(value: Dictionary) -> bool:
	if fail_storage: return false
	return super._persist_pending(value)

func _save_forfeit_action(value: Dictionary) -> bool:
	if fail_storage: return false
	return super._save_forfeit_action(value)

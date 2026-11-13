extends RefCounted

var _server_ms := 0
var _received_ticks := 0

func sync(server_ms: int) -> void:
	if server_ms > 0 and server_ms > _server_ms:
		_server_ms = server_ms
		_received_ticks = Time.get_ticks_msec()

func remaining_seconds(world: Dictionary, cooldown_seconds: int) -> int:
	var last_entry := int(world.get("last_gate_entry_at", 0))
	if last_entry <= 0 or cooldown_seconds <= 0:
		return 0
	if _server_ms <= 0:
		return -1
	var server_now := _server_ms + Time.get_ticks_msec() - _received_ticks
	return maxi(0, ceili(float(last_entry + cooldown_seconds * 1000 - server_now) / 1000.0))

static func format_remaining(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 60, seconds % 60]

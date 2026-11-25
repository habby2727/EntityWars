extends "res://scripts/net/core_defense_client.gd"
# Test-only injected transport outage. All successful requests still use live HTTP.
var simulate_disconnect := false
func request(path: String, body: Variant = null, request_owner: Node = null) -> Dictionary:
	if simulate_disconnect: return {"code":0,"error":"WOE_NETWORK"}
	return await super.request(path, body, request_owner)

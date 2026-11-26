extends "res://scripts/net/core_defense_client.gd"
# Test-only injected transport outage. All successful requests still use live HTTP.
var simulate_disconnect := false
var delay_next_deploy := false
var deploy_in_flight := false
func request(path: String, body: Variant = null, request_owner: Node = null) -> Dictionary:
	if simulate_disconnect: return {"code":0,"error":"WOE_NETWORK"}
	return await super.request(path, body, request_owner)

func _transport_request(path: String, body: Variant = null) -> Dictionary:
	if delay_next_deploy and path == "/forest/core-defense/match/deploy" and body is Dictionary:
		delay_next_deploy = false
		deploy_in_flight = true
		await get_tree().create_timer(2.8).timeout
		deploy_in_flight = false
	return await super._transport_request(path, body)

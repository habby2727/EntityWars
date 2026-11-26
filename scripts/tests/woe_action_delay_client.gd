extends "res://scripts/net/woe_client.gd"

var delay_next_deploy := false
var deploy_in_flight := false

func request(path: String, body: Variant = null, request_owner: Node = null) -> Dictionary:
	if delay_next_deploy and path == "/forest/woe/match/deploy" and body is Dictionary:
		delay_next_deploy = false
		deploy_in_flight = true
		await get_tree().create_timer(2.8).timeout
		deploy_in_flight = false
	return await super.request(path, body, request_owner)

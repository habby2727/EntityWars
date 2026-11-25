extends "res://scripts/net/core_defense_client.gd"

# Simulated HTTP responses with a deliberately late solo response.
func request(path: String, _body: Variant = null, _owner: Node = null) -> Dictionary:
	var solo := path.contains("mode=solo")
	var previous := path.contains("month=previous")
	await get_tree().create_timer(0.25 if solo else 0.02).timeout
	return {"code":200,"data":{"mode":"solo" if solo else "coop","current_month":"2026-11","previous_month":"2026-10","viewed_month":"2026-10" if previous else "2026-11","entries":[] if previous else [{"display_name":"Solo" if solo else "Coop", "completed_waves":7}]}}

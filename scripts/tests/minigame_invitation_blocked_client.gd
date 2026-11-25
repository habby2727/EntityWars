extends "res://scripts/net/woe_client.gd"

signal release_invitation

func request(path: String, _body: Variant = null, _owner: Node = null) -> Dictionary:
	if path == "/forest/minigames/invite": await release_invitation
	return {"code":0, "error":"WOE_NETWORK"}

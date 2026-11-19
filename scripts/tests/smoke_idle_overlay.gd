extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate := root.get_node("ConnectionGate")
	gate.token = "original-token"
	gate.player_id = "original-player"
	gate.require_idle()
	if gate.state != gate.State.IDLE or not gate.blocked() or not gate._layer.visible or gate._detail.text != "Are you still playing? Please Reconnect" or gate._retry.text != "Reconnect":
		push_error("Idle overlay is not modal or has incorrect text")
		quit(1)
		return
	gate._check()
	if gate._checking or gate.token != "original-token" or gate.player_id != "original-player":
		push_error("Idle polling or identity changed")
		quit(1)
		return
	print("PASS idle overlay and identity")
	quit(0)

extends Node

func _ready() -> void:
	if not OS.has_feature("editor") or not ConnectionGate.enable_debug_lab(): return
	call_deferred("_open")

func _open() -> void:
	if OS.has_feature("editor") and ConnectionGate.debug_lab_navigation_allowed():
		SceneRouter.go_to_expeditions()

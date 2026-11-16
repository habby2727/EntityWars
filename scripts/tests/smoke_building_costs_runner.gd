extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("en")
	var tests = load("res://scripts/tests/test_building_costs.gd")
	quit(0 if tests.run() else 1)

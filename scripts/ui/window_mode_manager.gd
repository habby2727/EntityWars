extends Node

func _process(_delta: float) -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MAXIMIZED:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("display", "fullscreen", true)
	config.save("user://settings.cfg")

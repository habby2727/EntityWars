extends RefCounted
class_name BuildingState

var level: int = 0
var route: String = ""
var runtime: Dictionary = {}

func _init(p_level: int = 0, p_route: String = "", p_runtime: Dictionary = {}) -> void:
	level = max(0, int(p_level))
	route = p_route
	runtime = p_runtime.duplicate(true)

func serialize() -> Dictionary:
	return {
		"level": level,
		"route": route,
		"runtime": runtime.duplicate(true)
	}

static func from_dict(data: Dictionary) -> BuildingState:
	var lvl = int(data.get("level", 0))
	var rt = str(data.get("route", ""))
	var run = data.get("runtime", {})
	if typeof(run) != TYPE_DICTIONARY:
		run = {}
	return BuildingState.new(lvl, rt, run)

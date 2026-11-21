extends RefCounted

const BUILD := 5507

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

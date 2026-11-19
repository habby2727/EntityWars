extends RefCounted

const BUILD := 5506

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

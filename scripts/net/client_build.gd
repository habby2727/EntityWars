extends RefCounted

const BUILD := 5512

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

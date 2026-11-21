extends RefCounted

const BUILD := 5508

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

extends RefCounted

const BUILD := 5510

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

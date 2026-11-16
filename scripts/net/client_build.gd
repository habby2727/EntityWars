extends RefCounted

const BUILD := 5503

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

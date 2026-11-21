extends RefCounted

const BUILD := 5509

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

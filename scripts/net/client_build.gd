extends RefCounted

const BUILD := 5504

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

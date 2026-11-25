extends RefCounted

const BUILD := 5511

static func header() -> String:
	return "X-EntityWars-Client-Build: %d" % BUILD

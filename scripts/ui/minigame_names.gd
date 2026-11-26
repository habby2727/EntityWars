extends RefCounted

static func clean(value: Variant) -> String:
	if not value is String: return ""
	var result: String = value.strip_edges()
	if result.to_lower() in ["null", "<null>", "nil", "<nil>", "none", "undefined"]: return ""
	return result

static func first(primary: Variant, fallback: Variant = "") -> String:
	var name := clean(primary)
	return name if not name.is_empty() else clean(fallback)

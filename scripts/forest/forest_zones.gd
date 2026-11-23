extends RefCounted

# Foot-anchor geometry in the original 1920 x 1080 image coordinates.
const ZONES := [
	{"id": "central_clearing", "image": "Central_Clearing.png", "spawn": Vector2(960, 760), "polygon": [Vector2(790,0), Vector2(1130,0), Vector2(1190,145), Vector2(1430,235), Vector2(1700,320), Vector2(1840,390), Vector2(1920,450), Vector2(1920,630), Vector2(1830,675), Vector2(1700,745), Vector2(1570,830), Vector2(1400,900), Vector2(1160,985), Vector2(1150,1080), Vector2(805,1080), Vector2(790,986), Vector2(520,905), Vector2(310,830), Vector2(165,750), Vector2(70,670), Vector2(0,635), Vector2(0,460), Vector2(120,400), Vector2(260,325), Vector2(470,240), Vector2(700,145)], "portals": [{"id": "north", "direction": "north", "corridor": [840, 0, 1100, 185], "destination": "arcane_sanctuary", "arrival": Vector2(960, 880)}, {"id": "west", "direction": "west", "corridor": [0, 455, 130, 625], "destination": "alchemical_ruins", "arrival": Vector2(1730, 540)}, {"id": "east", "direction": "east", "corridor": [1790, 455, 1920, 625], "destination": "crystal_grove", "arrival": Vector2(190, 540)}, {"id": "south", "direction": "south", "corridor": [825, 970, 1135, 1080], "destination": "ethereal_mist", "arrival": Vector2(960, 240)}]},
	{"id": "alchemical_ruins", "image": "Alchemical_Ruins.png", "spawn": Vector2(960,550), "polygon": [Vector2(830,0), Vector2(1120,0), Vector2(1190,145), Vector2(1400,200), Vector2(1680,300), Vector2(1840,395), Vector2(1920,450), Vector2(1920,620), Vector2(1770,650), Vector2(1730,715), Vector2(1560,765), Vector2(1310,835), Vector2(1120,855), Vector2(900,830), Vector2(680,820), Vector2(540,880), Vector2(430,825), Vector2(300,735), Vector2(150,700), Vector2(65,625), Vector2(65,460), Vector2(160,410), Vector2(290,325), Vector2(500,230), Vector2(770,140)], "portals": [{"id": "north", "direction": "north", "corridor": [840, 0, 1110, 185], "destination": "duel_clearing", "arrival": Vector2(960, 895)}, {"id": "east", "direction": "east", "corridor": [1790, 455, 1920, 615], "destination": "central_clearing", "arrival": Vector2(195, 540)}]},
	{"id": "crystal_grove", "image": "Crystal_Grove.png", "spawn": Vector2(980,560), "polygon": [Vector2(0,415), Vector2(120,340), Vector2(300,250), Vector2(480,195), Vector2(650,185), Vector2(760,170), Vector2(1020,165), Vector2(1210,185), Vector2(1430,195), Vector2(1600,240), Vector2(1760,310), Vector2(1850,390), Vector2(1865,610), Vector2(1740,675), Vector2(1680,760), Vector2(1530,830), Vector2(1350,900), Vector2(1110,970), Vector2(840,980), Vector2(620,925), Vector2(430,860), Vector2(240,790), Vector2(130,675), Vector2(0,630)], "portals": [{"id": "west", "direction": "west", "corridor": [0, 455, 135, 615], "destination": "central_clearing", "arrival": Vector2(1730, 540)}]},
	{"id": "ethereal_mist", "image": "Ethereal_Mist_Forest.png", "spawn": Vector2(960,550), "polygon": [Vector2(795,0), Vector2(1125,0), Vector2(1280,150), Vector2(1590,270), Vector2(1810,390), Vector2(1880,470), Vector2(1880,635), Vector2(1800,710), Vector2(1660,790), Vector2(1500,850), Vector2(1330,900), Vector2(1130,930), Vector2(930,930), Vector2(660,920), Vector2(470,890), Vector2(290,830), Vector2(140,750), Vector2(60,660), Vector2(60,440), Vector2(170,360), Vector2(430,250), Vector2(690,135)], "portals": [{"id": "north", "direction": "north", "corridor": [820, 0, 1100, 185], "destination": "central_clearing", "arrival": Vector2(960, 900)}]},
	{"id": "arcane_sanctuary", "image": "Arcane_Forest_Sanctuary.png", "spawn": Vector2(960,760), "polygon": [Vector2(780,300), Vector2(1130,300), Vector2(1300,335), Vector2(1490,350), Vector2(1740,410), Vector2(1860,490), Vector2(1860,625), Vector2(1760,710), Vector2(1640,820), Vector2(1510,900), Vector2(1240,945), Vector2(1120,1080), Vector2(820,1080), Vector2(780,950), Vector2(550,900), Vector2(340,850), Vector2(150,750), Vector2(65,650), Vector2(60,475), Vector2(185,400), Vector2(410,350), Vector2(620,335)], "portals": [{"id": "south", "direction": "south", "corridor": [830, 970, 1110, 1080], "destination": "central_clearing", "arrival": Vector2(960, 240)}]},
	{"id": "duel_clearing", "image": "Duel_Clearing.png", "spawn": Vector2(960,560), "polygon": [Vector2(710,210), Vector2(1210,210), Vector2(1410,245), Vector2(1640,320), Vector2(1800,400), Vector2(1850,465), Vector2(1840,590), Vector2(1750,690), Vector2(1650,775), Vector2(1460,860), Vector2(1200,930), Vector2(1150,1080), Vector2(810,1080), Vector2(780,920), Vector2(550,865), Vector2(370,800), Vector2(220,730), Vector2(95,600), Vector2(75,455), Vector2(200,330), Vector2(430,245)], "portals": [{"id": "south", "direction": "south", "corridor": [830, 970, 1120, 1080], "destination": "alchemical_ruins", "arrival": Vector2(960, 240)}]}
]
const BACKGROUND_DIR := "res://assets/forest/backgrounds/"

# The JSON is the wire catalog; the legacy constants above retain image names and
# provide the existing offline forest if an export has a corrupt catalog.
static func runtime_zones() -> Array:
	var file := FileAccess.open("res://data/static/forest_zones.json", FileAccess.READ)
	if file == null or file.get_length() > 100000:
		return []
	var raw = JSON.parse_string(file.get_as_text())
	return _catalog_from_data(raw)

static func _catalog_from_data(raw) -> Array:
	if not raw is Dictionary or raw.get("version") != 1 or raw.get("width") != 1920 or raw.get("height") != 1080 or not raw.get("zones") is Array or raw.zones.size() != 6:
		return []
	var images := {}
	for legacy in ZONES:
		images[legacy.id] = legacy.image
	var result: Array = []
	var ids := {}
	for item in raw.zones:
		if not item is Dictionary or not item.get("id") is String or not images.has(item.id) or ids.has(item.id) or not item.get("polygon") is Array or item.polygon.size() < 3 or item.polygon.size() > 100 or not item.get("portals") is Array:
			return []
		var poly := PackedVector2Array()
		for point in item.polygon:
			var v := _catalog_point(point)
			if not v.is_finite() or v.x < 0 or v.x > 1920 or v.y < 0 or v.y > 1080:
				return []
			poly.append(v)
		var area := 0.0
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			if a == b:
				return []
			area += a.cross(b)
			for j in range(i + 1, poly.size()):
				if j == i + 1 or (i == 0 and j == poly.size() - 1):
					continue
				var c := poly[j]
				var d := poly[(j + 1) % poly.size()]
				if Geometry2D.segment_intersects_segment(a, b, c, d) != null or _on_segment(a, c, d) or _on_segment(b, c, d) or _on_segment(c, a, b) or _on_segment(d, a, b):
					return []
		if absf(area) < 1.0:
			return []
		var spawn := _catalog_point(item.get("spawn"))
		if not spawn.is_finite() or not Geometry2D.is_point_in_polygon(spawn, poly):
			return []
		var zone := {"id": item.id, "image": images[item.id], "spawn": spawn, "polygon": poly, "portals": []}
		ids[item.id] = zone
		result.append(zone)
	var expected := {"central_clearing": {"north":"arcane_sanctuary", "west":"alchemical_ruins", "east":"crystal_grove", "south":"ethereal_mist"}, "alchemical_ruins":{"north":"duel_clearing", "east":"central_clearing"}, "crystal_grove":{"west":"central_clearing"}, "ethereal_mist":{"north":"central_clearing"}, "arcane_sanctuary":{"south":"central_clearing"}, "duel_clearing":{"south":"alchemical_ruins"}}
	var total := 0
	for item in raw.zones:
		var seen := {}
		for portal in item.portals:
			if not portal is Dictionary or not portal.get("direction") is String:
				return []
			var direction: String = portal.direction
			if seen.has(direction) or not expected[item.id].has(direction) or portal.get("id") != direction or portal.get("destination") != expected[item.id][direction]:
				return []
			var rect = portal.get("corridor")
			if not rect is Array or rect.size() != 4:
				return []
			for n in rect:
				if not (n is int or n is float) or not is_finite(float(n)):
					return []
			if rect[0] < 0 or rect[1] < 0 or rect[2] > 1920 or rect[3] > 1080 or rect[0] >= rect[2] or rect[1] >= rect[3]:
				return []
			if (direction == "north" and rect[1] != 0) or (direction == "south" and rect[3] != 1080) or (direction == "west" and rect[0] != 0) or (direction == "east" and rect[2] != 1920):
				return []
			var arrival := _catalog_point(portal.get("arrival"))
			if not arrival.is_finite() or not Geometry2D.is_point_in_polygon(arrival, ids[portal.destination].polygon):
				return []
			ids[item.id].portals.append({"id": direction, "direction": direction, "corridor": rect.duplicate(), "destination": portal.destination, "arrival": arrival})
			seen[direction] = true
			total += 1
		if seen.size() != expected[item.id].size():
			return []
	return result if total == 10 else []

static func _catalog_point(value) -> Vector2:
	if not value is Array or value.size() != 2 or not (value[0] is int or value[0] is float) or not (value[1] is int or value[1] is float):
		return Vector2.INF
	var point := Vector2(float(value[0]), float(value[1]))
	return point if point.is_finite() else Vector2.INF

static func contains_point(polygon: PackedVector2Array, point: Vector2) -> bool:
	if not point.is_finite() or polygon.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	for i in polygon.size():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])) < 0.001:
			return true
	return false

static func _on_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) < 0.0001

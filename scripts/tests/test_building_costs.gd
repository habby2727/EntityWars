extends Node
class_name BuildingCostTests

static var failures := 0

static func run() -> bool:
	failures = 0
	_test_cap_blocks_upgrade()
	_test_missing_cost_blocks()
	_test_path_multiplier_floor()
	_test_costs_and_lab_display()
	return failures == 0

static func _test_cap_blocks_upgrade() -> void:
	var resolver := CostResolver.new()
	var rules := HqRules.new()
	var result = resolver.resolve_upgrade_cost("essence_reactor", 1, 1, "scientific", rules)
	_assert_false(bool(result.get("ok", false)), "upgrade beyond cap blocked")

static func _test_missing_cost_blocks() -> void:
	var resolver := CostResolver.new()
	var result = resolver.resolve_upgrade_cost("essence_reactor", 10, 10, "scientific")
	_assert_false(bool(result.get("ok", false)), "missing cost blocks upgrade")

static func _test_path_multiplier_floor() -> void:
	var balance := {"hq_cost_mult": {"scientific": 0.8, "chaotic": 1.2, "industrial": 1.0}}
	var resolver := CostResolver.new({}, balance)
	var result = resolver.resolve_upgrade_cost("lab_th", 0, 5, "scientific", HqRules.new())
	var cost: Dictionary = result.get("cost", {})
	_assert_eq(int(cost.get("essence", -1)), 40, "cost floor with scientific multiplier")
	var result2 = resolver.resolve_upgrade_cost("lab_th", 0, 5, "chaotic", HqRules.new())
	var cost2: Dictionary = result2.get("cost", {})
	_assert_eq(int(cost2.get("essence", -1)), 60, "cost floor with chaotic multiplier")

static func _test_costs_and_lab_display() -> void:
	var screen := LabScreen.new()
	var db: StaticDB = screen._db
	var resolver := CostResolver.new(db.buildings, db.balance)
	_assert_eq(db.buildings.size(), 12, "building count")
	for id in db.buildings:
		for level in range(1, 11):
			var cost = resolver.get_cost_for_level(id, level)
			if cost.is_empty():
				failures += 1
				push_error("FAIL: missing cost for %s level %s" % [id, level])
				continue
			for amount in cost.values():
				if (typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT) or amount <= 0 or float(amount) != floor(float(amount)):
					failures += 1
					push_error("FAIL: invalid cost for %s level %s" % [id, level])
			for path in ["Scientific", "Chaotic", "Industrial"]:
				var hq_level = level - 1 if id == "lab_th" else 10
				screen._state = {"lab": {"hqLevel": hq_level, "hqPath": path, "buildings": {id: {"level": level - 1}}}}
				var expected = resolver.resolve_upgrade_cost(id, level - 1, hq_level, path).get("cost", {})
				if screen._get_upgrade_cost(id) != expected:
					failures += 1
					push_error("FAIL: displayed cost for %s level %s path %s" % [id, level, path])
	_assert_eq(HqRules.get_unlock_level("world_gate"), 1, "world gate unlocks at HQ 1")
	screen._catalog.free()
	screen._db.free()
	screen._debug.free()
	screen.free()

static func _assert_false(value: bool, label: String) -> void:
	if value:
		failures += 1
		push_error("FAIL: %s" % label)
	else:
		print("PASS: %s" % label)

static func _assert_eq(value: int, expected: int, label: String) -> void:
	if value == expected:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s expected %s got %s" % [label, expected, value])

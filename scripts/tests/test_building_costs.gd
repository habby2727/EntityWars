extends Node
class_name BuildingCostTests

static func run() -> void:
	_test_cap_blocks_upgrade()
	_test_missing_cost_blocks()
	_test_path_multiplier_floor()

static func _test_cap_blocks_upgrade() -> void:
	var resolver := CostResolver.new()
	var rules := HqRules.new()
	var result = resolver.resolve_upgrade_cost("essence_reactor", 1, 1, "scientific", rules)
	_assert_false(bool(result.get("ok", false)), "upgrade beyond cap blocked")

static func _test_missing_cost_blocks() -> void:
	var resolver := CostResolver.new()
	var rules := HqRules.new()
	var result = resolver.resolve_upgrade_cost("essence_reactor", 1, 5, "scientific", rules)
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

static func _assert_false(value: bool, label: String) -> void:
	if value:
		push_error("FAIL: %s" % label)
	else:
		print("PASS: %s" % label)

static func _assert_eq(value: int, expected: int, label: String) -> void:
	if value == expected:
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s expected %s got %s" % [label, expected, value])

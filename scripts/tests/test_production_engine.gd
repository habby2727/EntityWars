extends Node
class_name ProductionEngineTests

static func run() -> void:
	_test_offline_one_hour()
	_test_volatile_loss_compact()
	_test_mutagenic_rare_cap()

static func _test_offline_one_hour() -> void:
	var engine := ProductionEngine.new()
	engine.set_building_state("essence_reactor", 0.0, 0)
	var balance := {
		"reactor_base_rate": 1.0,
		"reactor_rate_per_level": 0.0,
		"reactor_route_output_mult": {"stable": 0.8},
		"route_multipliers": {"scientific": 1.0, "chaotic": 1.0, "industrial": 1.0},
		"offline_cap_hours": 12
	}
	var result = engine.accumulate(
		"essence_reactor",
		3600 * 1000,
		0,
		"stable",
		"",
		"scientific",
		balance,
		3600 * 1000
	)
	var expected := 3600.0 * 0.8
	_assert_close(float(result.get("produced", 0.0)), expected, 0.001, "1h offline essence")

static func _test_volatile_loss_compact() -> void:
	var engine := ProductionEngine.new()
	engine.set_building_state("essence_reactor", 100.0, 0)
	var balance := {
		"volatile_loss_chance": 1.0,
		"volatile_loss_pct": 0.4,
		"compact_loss_mult": 0.5
	}
	var no_compact = engine.claim("essence_reactor", 100.0, "volatile", "", "chaotic", balance)
	_assert_close(float(no_compact.get("lost", 0.0)), 40.0, 0.001, "volatile loss base")
	engine.set_building_state("essence_reactor", 100.0, 0)
	var compact = engine.claim("essence_reactor", 100.0, "volatile", "compact", "chaotic", balance)
	_assert_close(float(compact.get("lost", 0.0)), 20.0, 0.001, "compact reduces loss")

static func _test_mutagenic_rare_cap() -> void:
	var engine := ProductionEngine.new()
	var balance := {
		"mutagenic_rare_base_chance": 0.4,
		"sealed_rare_mult": 2.0,
		"hq_rare_mult": {"chaotic": 2.0},
		"mutagenic_rare_cap": 0.5
	}
	var chance = engine.get_mutagenic_rare_chance("sealed", "chaotic", balance)
	_assert_close(chance, 0.5, 0.0001, "mutagenic rare chance capped")

static func _assert_close(value: float, expected: float, eps: float, label: String) -> void:
	if abs(value - expected) <= eps:
		print("PASS: %s (%.4f)" % [label, value])
	else:
		push_error("FAIL: %s expected %.4f got %.4f" % [label, expected, value])

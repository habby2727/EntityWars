extends Node
class_name ProductionEngineTests

static func run() -> void:
	_test_reactor_hourly_rates()
	_test_debug_reactor()
	_test_fractional_remainder()
	_test_offline_one_hour()
	_test_volatile_loss_compact()
	_test_mutagenic_rare_cap()

static func _test_reactor_hourly_rates() -> void:
	var db := StaticDB.new()
	var engine := ProductionEngine.new()
	var balance := ProductionEngine.balance_for_server(db.balance)
	for level in [1, 5, 10]:
		var rate := engine._compute_output_rate(level, "", "", "Scientific", balance)
		_assert_close(rate * 3600.0, float(level * 10), 0.0001, "reactor hourly rate level %d" % level)
	var extreme := balance.duplicate(true)
	extreme["reactor_route_output_mult"] = {"volatile": 4.0}
	extreme["_reactor_extra_multiplier"] = 1.5
	_assert_close(engine._compute_output_rate(5, "volatile", "", "Scientific", extreme) * 3600.0, 100.0, 0.0001, "combined multipliers capped at x2")
	db.free()

static func _test_debug_reactor() -> void:
	var db := StaticDB.new()
	var debug := DebugFlags.new()
	debug.unlock_all_buildings = true
	for level in [1, 5, 10]:
		var now := int(Time.get_unix_time_from_system() * 1000)
		var state := {"lab": {"hqPath": "Scientific", "buildings": {"essence_reactor": {"level": level, "route": "stable", "runtime": {"stored_output": 0.0, "last_tick": now - 3600000}}, "storage_vault": {"level": 1}}, "runtime": {}}}
		debug.claim_lab_production(state, db, false)
		_assert_close(float(state.lab.buildings.essence_reactor.runtime.stored_output), level * 8.0, 0.01, "debug hourly production level %d" % level)
	debug.free()
	db.free()

static func _test_fractional_remainder() -> void:
	var engine := ProductionEngine.new()
	engine.set_building_state("essence_reactor", 10.625, 0)
	var result := engine.claim("essence_reactor", 1000, "stable", "", "Scientific")
	_assert_close(float(result.grants.essence), 10.0, 0.0001, "whole essence claimed")
	_assert_close(float(engine.get_building_state("essence_reactor").stored_output), 0.625, 0.0001, "fractional essence retained")

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

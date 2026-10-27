extends SceneTree
## Headless rule checks for CrowdSim and the economy formulas.
## Run from the project root:
##   godot --headless --path . --script res://tests/test_crowd_sim.gd
## Exit code is 0 when everything passes, 1 otherwise.

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_multiply_gate_clones()
	_test_add_gate_clones()
	_test_gate_triggers_once_per_unit()
	_test_gate_miss_outside_span()
	_test_cap_overflow_conserves_value()
	_test_champion_gate_scales_value()
	_test_combat_min_rule()
	_test_combat_conserves_difference()
	_test_swap_remove_keeps_data()
	_test_base_and_wall_damage()
	_test_formulas()
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: ", what)


func _sim_with_gate(op: GateDef.Op, amount: int, cap: int = 100, x0: float = -4.0, x1: float = 4.0) -> CrowdSim:
	var sim := CrowdSim.new(cap, 100)
	var g := GateDef.new()
	g.op = op
	g.amount = amount
	g.z = -5.0
	g.width = x1 - x0
	g.start_x = (x0 + x1) * 0.5
	var defs: Array[GateDef] = [g]
	sim.configure_gates(defs)
	return sim


func _test_multiply_gate_clones() -> void:
	var sim := _sim_with_gate(GateDef.Op.MULTIPLY, 3)
	sim.spawn_friendly(0.0, -4.95, CrowdSim.Kind.SOLDIER, 1, 0.0)
	sim.step(0.02, 0.0)
	_check(sim.f_count == 3, "x3 gate makes 3 units (got %d)" % sim.f_count)
	_check(sim.friendly_value_total() == 3, "x3 gate total value 3")
	_check(sim.g_hits[0] == 1, "gate hit counted once")
	for i in sim.f_count:
		_check((sim.f_mask[i] & 1) == 1, "clone %d inherits gate mask" % i)


func _test_add_gate_clones() -> void:
	var sim := _sim_with_gate(GateDef.Op.ADD, 7)
	sim.spawn_friendly(0.0, -4.95, CrowdSim.Kind.SOLDIER, 1, 0.0)
	sim.step(0.02, 0.0)
	_check(sim.f_count == 8, "+7 gate makes 8 units (got %d)" % sim.f_count)


func _test_gate_triggers_once_per_unit() -> void:
	var sim := _sim_with_gate(GateDef.Op.MULTIPLY, 2)
	sim.spawn_friendly(0.0, -4.95, CrowdSim.Kind.SOLDIER, 1, 0.0)
	sim.step(0.02, 0.0)
	# Put every unit back in front of the gate and let them cross again.
	for i in sim.f_count:
		sim.f_pz[i] = -4.95
	sim.step(0.02, 0.0)
	_check(sim.f_count == 2, "units never re-trigger a gate (got %d)" % sim.f_count)


func _test_gate_miss_outside_span() -> void:
	var sim := _sim_with_gate(GateDef.Op.MULTIPLY, 3, 100, -1.0, 1.0)
	sim.spawn_friendly(3.0, -4.95, CrowdSim.Kind.SOLDIER, 1, 0.0)
	sim.step(0.02, 0.0)
	_check(sim.f_count == 1, "unit outside the gate span is not cloned")


func _test_cap_overflow_conserves_value() -> void:
	var sim := _sim_with_gate(GateDef.Op.MULTIPLY, 3, 2)
	sim.spawn_friendly(0.0, -4.95, CrowdSim.Kind.SOLDIER, 1, 0.0)
	sim.step(0.02, 0.0)
	_check(sim.f_count == 2, "cap of 2 respected (got %d)" % sim.f_count)
	_check(sim.friendly_value_total() == 3, "overflow folded into original (total %d)" % sim.friendly_value_total())


func _test_champion_gate_scales_value() -> void:
	var sim := _sim_with_gate(GateDef.Op.MULTIPLY, 3)
	sim.spawn_friendly(0.0, -4.95, CrowdSim.Kind.CHAMPION, 6, 0.0)
	var r0: float = sim.f_rad[0]
	sim.step(0.02, 0.0)
	_check(sim.f_count == 1, "champion is never cloned")
	_check(sim.f_val[0] == 18, "x3 multiplies champion value (got %d)" % sim.f_val[0])
	_check(sim.f_rad[0] > r0, "champion grows with value")

	var sim_add := _sim_with_gate(GateDef.Op.ADD, 5)
	sim_add.spawn_friendly(0.0, -4.95, CrowdSim.Kind.CHAMPION, 6, 0.0)
	sim_add.step(0.02, 0.0)
	_check(sim_add.f_val[0] == 11, "+5 adds to champion value (got %d)" % sim_add.f_val[0])


func _test_combat_min_rule() -> void:
	var sim := CrowdSim.new(10, 10)
	sim.spawn_friendly(0.0, -10.0, CrowdSim.Kind.CHAMPION, 3, 0.0)
	sim.spawn_enemy(0.0, -10.1, CrowdSim.Kind.BRUTE, 2.0)
	sim.step(0.001, 0.0)
	_check(sim.f_count == 0, "friendly with 3 dies against a brute with 5")
	_check(sim.e_count == 1 and sim.e_val[0] == 2, "brute keeps 5 - 3 = 2")
	_check(sim.burst_count == 1, "one death burst recorded")


func _test_combat_conserves_difference() -> void:
	var sim := CrowdSim.new(800, 400)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 600:
		sim.spawn_friendly(rng.randf_range(-3.5, 3.5), rng.randf_range(-30.0, -20.0), CrowdSim.Kind.SOLDIER, 1, 0.0)
	for j in 300:
		var kind: int = CrowdSim.Kind.BRUTE if j % 7 == 0 else CrowdSim.Kind.GRUNT
		sim.spawn_enemy(rng.randf_range(-3.5, 3.5), rng.randf_range(-30.0, -20.0), kind, 2.0)
	var before := sim.friendly_value_total() - _enemy_total(sim)
	sim.step(1.0 / 60.0, 0.0)
	var after := sim.friendly_value_total() - _enemy_total(sim)
	_check(before == after, "clashes remove equal value from both sides (%d vs %d)" % [before, after])
	_check(sim.kills > 0, "overlapping crowds actually clash")
	for i in sim.f_count:
		_check(sim.f_val[i] > 0, "no dead friendly left after compaction")
		if sim.f_val[i] <= 0:
			break


func _test_swap_remove_keeps_data() -> void:
	var sim := CrowdSim.new(10, 10)
	sim.spawn_friendly(-1.0, -10.0, CrowdSim.Kind.SOLDIER, 1, 0.0)
	sim.spawn_friendly(0.0, -10.0, CrowdSim.Kind.SOLDIER, 1, 0.0)
	sim.spawn_friendly(1.0, -10.0, CrowdSim.Kind.CHAMPION, 9, 0.0)
	sim.f_val[1] = 0
	sim.step(0.001, 0.0)
	_check(sim.f_count == 2, "dead unit removed")
	_check(is_equal_approx(sim.f_px[1], 1.0) and sim.f_kind[1] == CrowdSim.Kind.CHAMPION and sim.f_val[1] == 9,
			"last unit swapped into the hole with all its data")


func _test_base_and_wall_damage() -> void:
	var sim := CrowdSim.new(10, 10)
	sim.spawn_friendly(0.0, sim.base_front_z + 0.01, CrowdSim.Kind.CHAMPION, 7, 0.0)
	sim.spawn_enemy(0.0, sim.wall_z - 0.001, CrowdSim.Kind.BRUTE, 2.0)
	sim.step(0.01, 0.0)
	_check(sim.base_damage == 7, "friendly deals its value to the base (got %d)" % sim.base_damage)
	_check(sim.wall_damage == Tuning.BRUTE_VALUE, "enemy deals its value to the wall (got %d)" % sim.wall_damage)
	_check(sim.f_count == 0 and sim.e_count == 0, "units are consumed on impact")


func _test_formulas() -> void:
	_check(Tuning.fort_hp(1) == 111, "fort hp L1 = 111")
	_check(Tuning.fort_hp(10) == 750, "fort hp L10 = 750")
	_check(Tuning.upgrade_cost(0) == 25, "upgrade cost 0 = 25")
	_check(Tuning.upgrade_cost(1) == 38, "upgrade cost 1 = 38")
	_check(Tuning.upgrade_cost(12) == 3244, "upgrade cost 12 = 3244 (got %d)" % Tuning.upgrade_cost(12))
	_check(is_equal_approx(Tuning.fire_interval(0), 0.112), "fire interval lvl 0")
	_check(is_equal_approx(Tuning.fire_interval(12), 0.045), "fire interval floor 0.045")
	_check(Tuning.wall_hp(2) == 20, "wall hp upgrade 2 = 20")
	_check(Tuning.champion_value(2) == 12, "champion value upgrade 2 = 12")
	_check(Tuning.coins_for_win(3, 10) == 69, "win coins L3 wall 10 = 69")
	_check(Tuning.coins_for_loss(5, 0.5) == 16, "loss coins L5 half = 16")
	_check(Tuning.gate_rows(2) == 1 and Tuning.gate_rows(3) == 2 and Tuning.gate_rows(7) == 3, "gate rows by level")
	_check(is_equal_approx(Tuning.fort_spawn_interval(20), 0.5), "spawn interval floor 0.5")
	var def := LevelBuilder.generate(8)
	_check(def.gates.size() >= 3, "level 8 has at least 3 gates")
	var again := LevelBuilder.generate(8)
	_check(again.gates[0].amount == def.gates[0].amount and is_equal_approx(again.gates[0].start_x, def.gates[0].start_x),
			"level generation is deterministic")


func _enemy_total(sim: CrowdSim) -> int:
	var total := 0
	for j in sim.e_count:
		total += sim.e_val[j]
	return total

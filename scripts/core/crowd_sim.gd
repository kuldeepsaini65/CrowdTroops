class_name CrowdSim
extends RefCounted
## Data-only crowd simulation (CLAUDE.md §3.3, §3.4, §5).
##
## Units are structure-of-arrays pools with swap-remove; nothing here is a Node.
## Packed arrays are copy-on-write, so every hot loop writes only to arrays that
## are members of this object (writing `other.arr[i]` would copy the array).
## For the same reason the enemy spatial grid lives here rather than in its own
## class.
##
## Per step: move friendlies (gates, base hits) -> move enemies (wall hits)
## -> rebuild enemy grid -> resolve clashes -> compact dead units.

enum Kind { SOLDIER, CHAMPION, GRUNT, BRUTE }
enum Team { FRIENDLY, ENEMY }

const MAX_BURSTS_PER_STEP := 8

# --- Friendly pool ---
var f_cap: int = 0
var f_count: int = 0
var f_px := PackedFloat32Array()
var f_pz := PackedFloat32Array()
var f_vx := PackedFloat32Array()
var f_vz := PackedFloat32Array()
var f_val := PackedInt32Array()
var f_rad := PackedFloat32Array()
var f_mask := PackedInt32Array()
var f_kind := PackedInt32Array()
var f_phase := PackedFloat32Array()

# --- Enemy pool ---
var e_cap: int = 0
var e_count: int = 0
var e_px := PackedFloat32Array()
var e_pz := PackedFloat32Array()
var e_vz := PackedFloat32Array()
var e_val := PackedInt32Array()
var e_rad := PackedFloat32Array()
var e_kind := PackedInt32Array()
var e_phase := PackedFloat32Array()

# --- Gates (spans are pushed in every tick by the Gate nodes) ---
var g_count: int = 0
var g_z := PackedFloat32Array()
var g_x0 := PackedFloat32Array()
var g_x1 := PackedFloat32Array()
var g_op := PackedInt32Array()
var g_amt := PackedInt32Array()
## How many units triggered each gate during the last step (for flashes / SFX).
var g_hits := PackedInt32Array()
var steer_start_z: float = Tuning.STEER_START_Z_NO_GATES

# --- Lane and targets ---
var lane_half_width: float = Tuning.ROAD_HALF_WIDTH
var base_x: float = 0.0
var base_front_z: float = Tuning.BASE_FRONT_Z
var wall_z: float = Tuning.WALL_Z

# --- Per-step outputs ---
var base_damage: int = 0
var wall_damage: int = 0
var burst_count: int = 0
var burst_x := PackedFloat32Array()
var burst_z := PackedFloat32Array()
var burst_team := PackedInt32Array()

# --- Level stats ---
var kills: int = 0
var peak_friendlies: int = 0

var rng := RandomNumberGenerator.new()

# --- Enemy spatial grid (counting sort, rebuilt every step) ---
var _max_enemy_radius: float = 0.0
var _inv_cell: float = 1.0
var _grid_x0: float = 0.0
var _grid_z0: float = 0.0
var _cols: int = 1
var _rows: int = 1
## Start index of each cell in _cell_items; entry [cells] is the live count.
var _cell_start := PackedInt32Array()
var _cell_items := PackedInt32Array()
var _e_cell := PackedInt32Array()
var _live_enemies: int = 0
var _enemy_front_z: float = -INF
var _enemy_back_z: float = INF


func _init(friendly_cap: int = Tuning.MAX_FRIENDLIES, enemy_cap: int = Tuning.MAX_ENEMIES) -> void:
	f_cap = friendly_cap
	f_px = _floats(f_cap)
	f_pz = _floats(f_cap)
	f_vx = _floats(f_cap)
	f_vz = _floats(f_cap)
	f_val = _ints(f_cap)
	f_rad = _floats(f_cap)
	f_mask = _ints(f_cap)
	f_kind = _ints(f_cap)
	f_phase = _floats(f_cap)

	e_cap = enemy_cap
	e_px = _floats(e_cap)
	e_pz = _floats(e_cap)
	e_vz = _floats(e_cap)
	e_val = _ints(e_cap)
	e_rad = _floats(e_cap)
	e_kind = _ints(e_cap)
	e_phase = _floats(e_cap)

	burst_x = _floats(MAX_BURSTS_PER_STEP)
	burst_z = _floats(MAX_BURSTS_PER_STEP)
	burst_team = _ints(MAX_BURSTS_PER_STEP)

	# Grid cell = 2x the biggest enemy radius (CLAUDE.md §5.4). It covers the
	# road plus a 1 m margin, from behind the base to behind the cannon.
	_max_enemy_radius = maxf(Tuning.GRUNT_RADIUS, Tuning.BRUTE_RADIUS)
	_inv_cell = 1.0 / (2.0 * _max_enemy_radius)
	_grid_x0 = -Tuning.ROAD_HALF_WIDTH - 1.0
	_grid_z0 = Tuning.BASE_Z - 4.0
	_cols = ceili((Tuning.ROAD_WIDTH + 2.0) * _inv_cell)
	_rows = ceili((Tuning.ROAD_NEAR_Z + 1.0 - _grid_z0) * _inv_cell)
	_cell_start = _ints(_cols * _rows + 1)
	_cell_items = _ints(e_cap)
	_e_cell = _ints(e_cap)


# --------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------

func configure_gates(defs: Array[GateDef]) -> void:
	g_count = mini(defs.size(), Tuning.MAX_GATES)
	g_z = _floats(g_count)
	g_x0 = _floats(g_count)
	g_x1 = _floats(g_count)
	g_op = _ints(g_count)
	g_amt = _ints(g_count)
	g_hits = _ints(g_count)
	var last_z := 0.0
	for i in g_count:
		var d := defs[i]
		g_z[i] = d.z
		g_op[i] = d.op
		g_amt[i] = d.amount
		g_x0[i] = d.start_x - d.width * 0.5
		g_x1[i] = d.start_x + d.width * 0.5
		last_z = minf(last_z, d.z)
	if g_count > 0:
		steer_start_z = last_z - Tuning.STEER_AFTER_GATES_MARGIN
	else:
		steer_start_z = Tuning.STEER_START_Z_NO_GATES


func set_gate_span(index: int, x0: float, x1: float) -> void:
	g_x0[index] = x0
	g_x1[index] = x1


func clear() -> void:
	f_count = 0
	e_count = 0
	kills = 0
	peak_friendlies = 0
	burst_count = 0


# --------------------------------------------------------------------------
# Spawning
# --------------------------------------------------------------------------

## Returns the new unit's index, or -1 when the pool is full.
func spawn_friendly(x: float, z: float, kind: int, value: int, vx: float) -> int:
	if f_count >= f_cap:
		return -1
	var i := f_count
	f_count += 1
	var is_champion := kind == Kind.CHAMPION
	f_px[i] = x
	f_pz[i] = z
	f_vx[i] = vx
	f_vz[i] = -(Tuning.CHAMPION_SPEED if is_champion else Tuning.SOLDIER_SPEED)
	f_val[i] = value
	f_rad[i] = champion_radius(value) if is_champion else Tuning.SOLDIER_RADIUS
	f_mask[i] = 0
	f_kind[i] = kind
	f_phase[i] = rng.randf() * TAU
	if f_count > peak_friendlies:
		peak_friendlies = f_count
	return i


## Returns the new unit's index, or -1 when the pool is full.
func spawn_enemy(x: float, z: float, kind: int, speed: float) -> int:
	if e_count >= e_cap:
		return -1
	var j := e_count
	e_count += 1
	var is_brute := kind == Kind.BRUTE
	e_px[j] = x
	e_pz[j] = z
	e_vz[j] = speed * (Tuning.BRUTE_SPEED_MUL if is_brute else 1.0)
	e_val[j] = Tuning.BRUTE_VALUE if is_brute else 1
	e_rad[j] = Tuning.BRUTE_RADIUS if is_brute else Tuning.GRUNT_RADIUS
	e_kind[j] = kind
	e_phase[j] = rng.randf() * TAU
	return j


static func champion_radius(value: int) -> float:
	var r := Tuning.CHAMPION_RADIUS * sqrt(float(value) / float(Tuning.CHAMPION_BASE_VALUE))
	return clampf(r, Tuning.CHAMPION_RADIUS * 0.8, Tuning.CHAMPION_MAX_RADIUS)


# --------------------------------------------------------------------------
# Step
# --------------------------------------------------------------------------

func step(dt: float, time: float) -> void:
	base_damage = 0
	wall_damage = 0
	burst_count = 0
	if g_count > 0:
		g_hits.fill(0)
	_move_friendlies(dt)
	_move_enemies(dt, time)
	_build_grid()
	_resolve_combat()
	_compact()


func friendly_value_total() -> int:
	var total := 0
	for i in f_count:
		total += f_val[i]
	return total


func _move_friendlies(dt: float) -> void:
	# Clones spawned by gates this step are appended past `n` and move next step.
	var n := f_count
	var damp := exp(-Tuning.LATERAL_DAMP * dt)
	var steer_blend := minf(1.0, Tuning.STEER_RATE * dt)
	for i in n:
		if f_val[i] <= 0:
			continue
		var x: float = f_px[i]
		var old_z: float = f_pz[i]
		var z: float = old_z + f_vz[i] * dt
		var vx: float = f_vx[i]
		if z < steer_start_z:
			var desired := clampf((base_x - x) * Tuning.STEER_GAIN, -Tuning.STEER_MAX_SPEED, Tuning.STEER_MAX_SPEED)
			vx = lerpf(vx, desired, steer_blend)
		else:
			vx *= damp
		x += vx * dt
		var limit: float = lane_half_width - f_rad[i]
		if x < -limit:
			x = -limit
			vx = 0.0
		elif x > limit:
			x = limit
			vx = 0.0
		f_px[i] = x
		f_pz[i] = z
		f_vx[i] = vx

		for g in g_count:
			var gate_z: float = g_z[g]
			if old_z > gate_z and z <= gate_z:
				var bit := 1 << g
				if (f_mask[i] & bit) == 0 and x >= g_x0[g] and x <= g_x1[g]:
					f_mask[i] |= bit
					g_hits[g] += 1
					_apply_gate(i, g)

		if z <= base_front_z:
			base_damage += f_val[i]
			f_val[i] = 0


## Gate rules (CLAUDE.md §3.4). The unit's mask bit is already set, so clones
## inherit it and can never re-trigger this gate.
func _apply_gate(i: int, g: int) -> void:
	var op: int = g_op[g]
	var amount: int = g_amt[g]
	var value: int = f_val[i]

	if f_kind[i] == Kind.CHAMPION:
		value = value * amount if op == GateDef.Op.MULTIPLY else value + amount
		f_val[i] = value
		f_rad[i] = champion_radius(value)
		return

	var clones := amount - 1 if op == GateDef.Op.MULTIPLY else amount
	var x: float = f_px[i]
	var z: float = f_pz[i]
	var limit: float = lane_half_width - f_rad[i]
	for _clone in clones:
		if f_count >= f_cap:
			# Pool full: fold the clone into the original so totals stay exact.
			f_val[i] += value
			continue
		var j := f_count
		f_count += 1
		f_px[j] = clampf(x + rng.randf_range(-Tuning.CLONE_SCATTER_X, Tuning.CLONE_SCATTER_X), -limit, limit)
		f_pz[j] = z - rng.randf_range(0.0, Tuning.CLONE_SCATTER_Z)
		f_vx[j] = rng.randf_range(-Tuning.SOLDIER_SPREAD, Tuning.SOLDIER_SPREAD)
		f_vz[j] = f_vz[i]
		f_val[j] = value
		f_rad[j] = f_rad[i]
		f_mask[j] = f_mask[i]
		f_kind[j] = f_kind[i]
		f_phase[j] = rng.randf() * TAU
	if f_count > peak_friendlies:
		peak_friendlies = f_count


func _move_enemies(dt: float, time: float) -> void:
	var front := -INF
	var back := INF
	for j in e_count:
		if e_val[j] <= 0:
			continue
		var z: float = e_pz[j] + e_vz[j] * dt
		var x: float = e_px[j] + sin(time * Tuning.ENEMY_SWAY_FREQ + e_phase[j]) * Tuning.ENEMY_SWAY_AMP * dt
		var limit: float = lane_half_width - e_rad[j]
		x = clampf(x, -limit, limit)
		e_px[j] = x
		e_pz[j] = z
		if z >= wall_z:
			wall_damage += e_val[j]
			e_val[j] = 0
			continue
		front = maxf(front, z)
		back = minf(back, z)
	_enemy_front_z = front
	_enemy_back_z = back


func _build_grid() -> void:
	var cells := _cols * _rows
	_cell_start.fill(0)
	var live := 0
	for j in e_count:
		if e_val[j] <= 0:
			_e_cell[j] = -1
			continue
		var cx := clampi(int((e_px[j] - _grid_x0) * _inv_cell), 0, _cols - 1)
		var cz := clampi(int((e_pz[j] - _grid_z0) * _inv_cell), 0, _rows - 1)
		var c := cz * _cols + cx
		_e_cell[j] = c
		_cell_start[c] += 1
		live += 1
	# Inclusive prefix sum gives each cell's end; filling by decrementing turns
	# it into each cell's start, and cell c spans [start[c], start[c + 1]).
	var running := 0
	for c in cells:
		running += _cell_start[c]
		_cell_start[c] = running
	_cell_start[cells] = live
	for j in e_count:
		var c: int = _e_cell[j]
		if c < 0:
			continue
		_cell_start[c] -= 1
		_cell_items[_cell_start[c]] = j
	_live_enemies = live


func _resolve_combat() -> void:
	if _live_enemies == 0:
		return
	for i in f_count:
		var fv: int = f_val[i]
		if fv <= 0:
			continue
		var fz: float = f_pz[i]
		var fr: float = f_rad[i]
		var reach: float = fr + _max_enemy_radius
		# Cheap cull: the whole enemy crowd is out of reach along Z.
		if fz - reach > _enemy_front_z or fz + reach < _enemy_back_z:
			continue
		var fx: float = f_px[i]
		var cx0 := clampi(int((fx - reach - _grid_x0) * _inv_cell), 0, _cols - 1)
		var cx1 := clampi(int((fx + reach - _grid_x0) * _inv_cell), 0, _cols - 1)
		var cz0 := clampi(int((fz - reach - _grid_z0) * _inv_cell), 0, _rows - 1)
		var cz1 := clampi(int((fz + reach - _grid_z0) * _inv_cell), 0, _rows - 1)
		var cz := cz0
		while cz <= cz1 and fv > 0:
			var row := cz * _cols
			var cx := cx0
			while cx <= cx1 and fv > 0:
				var c := row + cx
				var k: int = _cell_start[c]
				var k_end: int = _cell_start[c + 1]
				while k < k_end:
					var j: int = _cell_items[k]
					k += 1
					var ev: int = e_val[j]
					if ev <= 0:
						continue
					var dx: float = e_px[j] - fx
					var dz: float = e_pz[j] - fz
					var rr: float = fr + e_rad[j]
					if dx * dx + dz * dz >= rr * rr:
						continue
					var loss := mini(fv, ev)
					fv -= loss
					ev -= loss
					e_val[j] = ev
					if ev <= 0:
						kills += 1
						_record_burst(e_px[j], e_pz[j], Team.ENEMY)
					if fv <= 0:
						break
				cx += 1
			cz += 1
		f_val[i] = fv
		if fv <= 0:
			_record_burst(fx, fz, Team.FRIENDLY)


## Swap-remove every dead/consumed unit. Iterating downwards means the unit
## swapped in from the end has already been checked.
func _compact() -> void:
	var i := f_count - 1
	while i >= 0:
		if f_val[i] <= 0:
			_remove_friendly(i)
		i -= 1
	var j := e_count - 1
	while j >= 0:
		if e_val[j] <= 0:
			_remove_enemy(j)
		j -= 1


func _remove_friendly(i: int) -> void:
	var last := f_count - 1
	if i != last:
		f_px[i] = f_px[last]
		f_pz[i] = f_pz[last]
		f_vx[i] = f_vx[last]
		f_vz[i] = f_vz[last]
		f_val[i] = f_val[last]
		f_rad[i] = f_rad[last]
		f_mask[i] = f_mask[last]
		f_kind[i] = f_kind[last]
		f_phase[i] = f_phase[last]
	f_count = last


func _remove_enemy(j: int) -> void:
	var last := e_count - 1
	if j != last:
		e_px[j] = e_px[last]
		e_pz[j] = e_pz[last]
		e_vz[j] = e_vz[last]
		e_val[j] = e_val[last]
		e_rad[j] = e_rad[last]
		e_kind[j] = e_kind[last]
		e_phase[j] = e_phase[last]
	e_count = last


func _record_burst(x: float, z: float, team: int) -> void:
	if burst_count >= MAX_BURSTS_PER_STEP:
		return
	burst_x[burst_count] = x
	burst_z[burst_count] = z
	burst_team[burst_count] = team
	burst_count += 1


static func _floats(size: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(size)
	a.fill(0.0)
	return a


static func _ints(size: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(size)
	a.fill(0)
	return a

class_name LevelBuilder
extends RefCounted
## Builds LevelDefs from the spec formulas (CLAUDE.md §3.4–3.5) and the
## graybox world geometry. Hand-tuned levels/level_NNN.tres take priority
## once they exist (Milestone 4).

const LEVEL_PATH := "res://levels/level_%03d.tres"


static func load_level(level: int) -> LevelDef:
	var path := LEVEL_PATH % level
	if ResourceLoader.exists(path):
		var def := load(path) as LevelDef
		if def != null:
			return def
	return generate(level)


static func generate(level: int) -> LevelDef:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level * 7919 + 17)   # same layout on every retry of a level

	var def := LevelDef.new()
	def.level = level
	def.is_boss = false                  # boss levels arrive in Milestone 4
	def.base_hp = Tuning.fort_hp(level)
	def.spawn_interval = Tuning.fort_spawn_interval(level)
	def.enemy_speed = Tuning.enemy_speed(level)
	def.brute_chance = Tuning.brute_chance(level)
	def.gate_speed = Tuning.gate_speed(level)

	var rows := Tuning.gate_rows(level)
	for r in rows:
		var z := Tuning.GATE_ROW_Z_SINGLE
		if rows > 1:
			z = lerpf(Tuning.GATE_ROW_Z_NEAR, Tuning.GATE_ROW_Z_FAR, float(r) / float(rows - 1))
		var double_row := level >= 4 and rng.randf() < 0.5
		if double_row:
			var half := Tuning.ROAD_HALF_WIDTH
			var w := Tuning.GATE_WIDTH_DOUBLE
			var left := _make_gate(rng, level, z, -half, 0.0, w, 1.0)
			var right := _make_gate(rng, level, z, 0.0, half, w, -1.0)
			def.gates.append(left)
			def.gates.append(right)
		else:
			var dir := 1.0 if rng.randf() < 0.5 else -1.0
			def.gates.append(_make_gate(rng, level, z, -Tuning.ROAD_HALF_WIDTH, Tuning.ROAD_HALF_WIDTH,
					Tuning.GATE_WIDTH_SINGLE, dir))
	return def


static func _make_gate(rng: RandomNumberGenerator, level: int, z: float, min_x: float, max_x: float,
		width: float, dir: float) -> GateDef:
	var g := GateDef.new()
	g.z = z
	g.width = width
	g.min_x = min_x
	g.max_x = max_x
	g.direction = dir
	g.start_x = rng.randf_range(min_x + width * 0.5, max_x - width * 0.5)
	var roll := rng.randf()
	if level == 1 or roll < 0.25:
		g.op = GateDef.Op.MULTIPLY
		g.amount = 3
	elif roll < 0.7:
		g.op = GateDef.Op.MULTIPLY
		g.amount = 2
	else:
		g.op = GateDef.Op.ADD
		g.amount = rng.randi_range(5, 8 + int(level * 0.5))
	return g


# --------------------------------------------------------------------------
# Graybox world (replaced by the art pass in Milestone 3)
# --------------------------------------------------------------------------

static func build_graybox_world(parent: Node3D) -> void:
	var road_len := Tuning.ROAD_NEAR_Z - Tuning.ROAD_FAR_Z
	var road_mid_z := (Tuning.ROAD_NEAR_Z + Tuning.ROAD_FAR_Z) * 0.5

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 140.0)
	ground.mesh = plane
	ground.material_override = PlaceholderMeshes.material(Color(0.86, 0.6, 0.36), 0.95)
	ground.position = Vector3(0.0, -0.02, road_mid_z)
	parent.add_child(ground)

	var asphalt := PlaceholderMeshes.material(Color(0.36, 0.37, 0.4), 0.8)
	_add_box(parent, Vector3(Tuning.ROAD_WIDTH, 0.1, road_len), Vector3(0.0, -0.05, road_mid_z), asphalt)

	var paint := PlaceholderMeshes.material(Color(0.95, 0.95, 0.92), 0.6)
	for side: float in [-1.0, 1.0]:
		_add_box(parent, Vector3(0.12, 0.02, road_len), Vector3(side * (Tuning.ROAD_HALF_WIDTH - 0.25), 0.01, road_mid_z), paint)

	# Dashed centre line: one MultiMesh, one draw call.
	var dash := BoxMesh.new()
	dash.size = Vector3(0.14, 0.02, 1.4)
	dash.material = paint
	var dashes := MultiMesh.new()
	dashes.transform_format = MultiMesh.TRANSFORM_3D
	dashes.mesh = dash
	var spacing := 3.2
	dashes.instance_count = int(road_len / spacing)
	for i in dashes.instance_count:
		dashes.set_instance_transform(i, Transform3D(Basis(), Vector3(0.0, 0.01, Tuning.ROAD_NEAR_Z - 1.0 - i * spacing)))
	var dash_mmi := MultiMeshInstance3D.new()
	dash_mmi.multimesh = dashes
	dash_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(dash_mmi)

	# Simple rails standing in for the wooden fences.
	var wood := PlaceholderMeshes.material(Color(0.55, 0.36, 0.2), 0.85)
	for side: float in [-1.0, 1.0]:
		var x := side * (Tuning.ROAD_HALF_WIDTH + 0.3)
		_add_box(parent, Vector3(0.1, 0.1, road_len), Vector3(x, 0.55, road_mid_z), wood)
		_add_box(parent, Vector3(0.1, 0.1, road_len), Vector3(x, 0.25, road_mid_z), wood)

	# Wall line the enemies must not cross.
	var wall_mat := PlaceholderMeshes.material(Color(1.0, 0.3, 0.25), 0.5)
	wall_mat.emission_enabled = true
	wall_mat.emission = Color(1.0, 0.25, 0.2)
	wall_mat.emission_energy_multiplier = 0.6
	_add_box(parent, Vector3(Tuning.ROAD_WIDTH, 0.04, 0.25), Vector3(0.0, 0.02, Tuning.WALL_Z), wall_mat)


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

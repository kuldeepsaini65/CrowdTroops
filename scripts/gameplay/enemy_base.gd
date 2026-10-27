class_name EnemyBase
extends Node3D
## Enemy fort at the far end of the road (CLAUDE.md §3.5): has HP with a
## world-space bar, and spawns groups of red units into CrowdSim.

const BAR_WIDTH := 4.0
const BAR_HEIGHT := 0.36
const BAR_Y := 7.2
const HIT_PUNCH := 0.06
const HIT_RECOVER := 6.0

var hp: int = 100
var max_hp: int = 100

var _def: LevelDef
var _sim: CrowdSim
var _rng: RandomNumberGenerator
var _spawn_timer: float = Tuning.FORT_FIRST_SPAWN_DELAY
var _body: Node3D
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _hp_label: Label3D
var _punch: float = 0.0


func setup(def: LevelDef, sim: CrowdSim, rng: RandomNumberGenerator) -> void:
	_def = def
	_sim = sim
	_rng = rng
	max_hp = def.base_hp
	hp = max_hp
	position = Vector3(0.0, 0.0, Tuning.BASE_Z)
	_build_visuals()
	_refresh_bar()


func tick(dt: float) -> void:
	if hp <= 0:
		return
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn_group()
		var jitter := _rng.randf_range(1.0 - Tuning.FORT_SPAWN_JITTER, 1.0 + Tuning.FORT_SPAWN_JITTER)
		_spawn_timer += _def.spawn_interval * jitter


func apply_damage(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return
	hp = maxi(0, hp - amount)
	_punch = 1.0
	_refresh_bar()


func damage_fraction() -> float:
	return 1.0 - float(hp) / float(maxi(1, max_hp))


func _process(delta: float) -> void:
	if _punch > 0.0:
		_punch = maxf(0.0, _punch - HIT_RECOVER * delta)
		_body.scale = Vector3.ONE * (1.0 + HIT_PUNCH * _punch)
	# Keep the bar square to the camera, billboard-style.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var t := _bar_root.global_transform
		t.basis = camera.global_transform.basis
		_bar_root.global_transform = t


func _spawn_group() -> void:
	var count := _rng.randi_range(Tuning.FORT_GROUP_MIN, Tuning.FORT_GROUP_MAX)
	var center := _rng.randf_range(-Tuning.ENEMY_SPAWN_HALF_WIDTH, Tuning.ENEMY_SPAWN_HALF_WIDTH)
	for _i in count:
		var kind: int = CrowdSim.Kind.GRUNT
		if _rng.randf() < _def.brute_chance:
			kind = CrowdSim.Kind.BRUTE
		var x := clampf(center + _rng.randf_range(-0.9, 0.9), -Tuning.ENEMY_SPAWN_HALF_WIDTH, Tuning.ENEMY_SPAWN_HALF_WIDTH)
		var z := Tuning.ENEMY_SPAWN_Z - _rng.randf_range(0.0, 1.2)
		_sim.spawn_enemy(x, z, kind, _def.enemy_speed)


func _refresh_bar() -> void:
	var f := clampf(float(hp) / float(maxi(1, max_hp)), 0.001, 1.0)
	_bar_fill.scale.x = f
	_bar_fill.position.x = -BAR_WIDTH * (1.0 - f) * 0.5
	_hp_label.text = str(hp)


func _build_visuals() -> void:
	var stone := PlaceholderMeshes.material(Color(0.62, 0.32, 0.26), 0.85)
	var roof := PlaceholderMeshes.material(Color(0.75, 0.12, 0.12), 0.6)
	var dark := PlaceholderMeshes.material(Color(0.18, 0.1, 0.08), 0.9)

	_body = Node3D.new()
	add_child(_body)

	_add_box(_body, Vector3(7.4, 3.6, 3.5), Vector3(0.0, 1.8, 0.0), stone)
	_add_box(_body, Vector3(1.9, 2.3, 0.2), Vector3(0.0, 1.15, 1.76), dark)
	for k in 5:
		_add_box(_body, Vector3(0.7, 0.6, 0.7), Vector3(-2.6 + 1.3 * k, 3.9, 1.4), stone)

	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 1.05
	tower_mesh.bottom_radius = 1.2
	tower_mesh.height = 5.4
	tower_mesh.radial_segments = 12
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 1.4
	roof_mesh.height = 1.8
	roof_mesh.radial_segments = 12
	for side: float in [-1.0, 1.0]:
		var tower := MeshInstance3D.new()
		tower.mesh = tower_mesh
		tower.material_override = stone
		tower.position = Vector3(side * 3.7, 2.7, 0.3)
		_body.add_child(tower)
		var cap := MeshInstance3D.new()
		cap.mesh = roof_mesh
		cap.material_override = roof
		cap.position = Vector3(side * 3.7, 6.3, 0.3)
		_body.add_child(cap)

	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0.0, BAR_Y, 0.0)
	add_child(_bar_root)
	var bg_mat := PlaceholderMeshes.material(Color(0.08, 0.06, 0.06), 1.0)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fill_mat := PlaceholderMeshes.material(Color(0.95, 0.2, 0.2), 1.0)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bg := _add_box(_bar_root, Vector3(BAR_WIDTH + 0.16, BAR_HEIGHT + 0.16, 0.04), Vector3.ZERO, bg_mat)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_fill = _add_box(_bar_root, Vector3(BAR_WIDTH, BAR_HEIGHT, 0.06), Vector3(0.0, 0.0, 0.02), fill_mat)
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_hp_label = Label3D.new()
	_hp_label.font_size = 120
	_hp_label.outline_size = 32
	_hp_label.outline_modulate = Color(0.1, 0.02, 0.02)
	_hp_label.position = Vector3(0.0, 0.75, 0.0)
	_bar_root.add_child(_hp_label)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

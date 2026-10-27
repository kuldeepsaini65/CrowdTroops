class_name FxPool
extends Node3D
## Pooled one-shot particle bursts (CLAUDE.md §5.6): emitters are created once
## and re-triggered round-robin, never instantiated or freed during play.

const EMITTERS_PER_TEAM := 16
const BURST_HEIGHT := 0.4

var _friendly: Array[GPUParticles3D] = []
var _enemy: Array[GPUParticles3D] = []
var _next_friendly: int = 0
var _next_enemy: int = 0


func setup(friendly_color: Color, enemy_color: Color) -> void:
	var friendly_mat := _make_process_material(friendly_color)
	var enemy_mat := _make_process_material(enemy_color)
	var chunk := _make_chunk_mesh()
	for i in EMITTERS_PER_TEAM:
		_friendly.append(_make_emitter(friendly_mat, chunk))
		_enemy.append(_make_emitter(enemy_mat, chunk))


func burst(x: float, z: float, team: int) -> void:
	var emitter: GPUParticles3D
	if team == CrowdSim.Team.FRIENDLY:
		emitter = _friendly[_next_friendly]
		_next_friendly = (_next_friendly + 1) % _friendly.size()
	else:
		emitter = _enemy[_next_enemy]
		_next_enemy = (_next_enemy + 1) % _enemy.size()
	emitter.position = Vector3(x, BURST_HEIGHT, z)
	emitter.restart()


func _make_emitter(process_material: ParticleProcessMaterial, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.process_material = process_material
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 4.0, 4.0))
	add_child(p)
	return p


func _make_process_material(color: Color) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 70.0
	m.initial_velocity_min = 2.5
	m.initial_velocity_max = 4.5
	m.gravity = Vector3(0.0, -14.0, 0.0)
	m.scale_min = 0.6
	m.scale_max = 1.2
	m.color = color
	return m


func _make_chunk_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.13
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	mesh.material = mat
	return mesh

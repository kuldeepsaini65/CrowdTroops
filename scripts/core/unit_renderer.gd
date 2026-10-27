class_name UnitRenderer
extends Node3D
## Draws every unit type with one MultiMeshInstance3D each (CLAUDE.md §5.2).
##
## Each frame the live units' positions are written into a per-type
## PackedFloat32Array that is assigned to `multimesh.buffer` in one go.
## Buffer layout per instance (16 floats): a 3x4 row-major transform
## [sx,0,0,x, 0,sy,0,y, 0,0,sz,z] followed by INSTANCE_CUSTOM (phase,0,0,0).
## Off-diagonal entries are never written, so they stay 0 forever.
## The buffers are members of this node so writes happen in place.

const STRIDE := 16
const CUSTOM := 12

var _sim: CrowdSim

var _mm_soldier: MultiMesh
var _mm_champion: MultiMesh
var _mm_grunt: MultiMesh
var _mm_brute: MultiMesh

var _buf_soldier := PackedFloat32Array()
var _buf_champion := PackedFloat32Array()
var _buf_grunt := PackedFloat32Array()
var _buf_brute := PackedFloat32Array()

var _cap_soldier: int = 0
var _cap_champion: int = 0
var _cap_grunt: int = 0
var _cap_brute: int = 0

var _champion_scale: float = 1.0


func setup(sim: CrowdSim, visuals: Dictionary) -> void:
	_sim = sim
	_cap_soldier = sim.f_cap
	_cap_champion = mini(sim.f_cap, Tuning.MAX_CHAMPIONS_DRAWN)
	_cap_grunt = sim.e_cap
	_cap_brute = mini(sim.e_cap, Tuning.MAX_BRUTES_DRAWN)

	var v_soldier: UnitVisuals = visuals[CrowdSim.Kind.SOLDIER]
	var v_champion: UnitVisuals = visuals[CrowdSim.Kind.CHAMPION]
	var v_grunt: UnitVisuals = visuals[CrowdSim.Kind.GRUNT]
	var v_brute: UnitVisuals = visuals[CrowdSim.Kind.BRUTE]
	_mm_soldier = _make_layer(v_soldier, _cap_soldier)
	_mm_champion = _make_layer(v_champion, _cap_champion)
	_mm_grunt = _make_layer(v_grunt, _cap_grunt)
	_mm_brute = _make_layer(v_brute, _cap_brute)
	_champion_scale = v_champion.base_scale

	# Fixed-scale layers get their diagonal written once here.
	_buf_soldier = _make_buffer(_cap_soldier, v_soldier.base_scale)
	_buf_champion = _make_buffer(_cap_champion, v_champion.base_scale)
	_buf_grunt = _make_buffer(_cap_grunt, v_grunt.base_scale)
	_buf_brute = _make_buffer(_cap_brute, v_brute.base_scale)


func update_from_sim() -> void:
	# Local references are read-only, so they never trigger a copy.
	var f_px := _sim.f_px
	var f_pz := _sim.f_pz
	var f_kind := _sim.f_kind
	var f_rad := _sim.f_rad
	var f_phase := _sim.f_phase
	var soldiers := 0
	var champions := 0
	for i in _sim.f_count:
		if f_kind[i] == CrowdSim.Kind.CHAMPION:
			if champions >= _cap_champion:
				continue
			var s: float = _champion_scale * f_rad[i] / Tuning.CHAMPION_RADIUS
			var o := champions * STRIDE
			_buf_champion[o] = s
			_buf_champion[o + 3] = f_px[i]
			_buf_champion[o + 5] = s
			_buf_champion[o + 10] = s
			_buf_champion[o + 11] = f_pz[i]
			_buf_champion[o + CUSTOM] = f_phase[i]
			champions += 1
		else:
			var o := soldiers * STRIDE
			_buf_soldier[o + 3] = f_px[i]
			_buf_soldier[o + 11] = f_pz[i]
			_buf_soldier[o + CUSTOM] = f_phase[i]
			soldiers += 1

	var e_px := _sim.e_px
	var e_pz := _sim.e_pz
	var e_kind := _sim.e_kind
	var e_phase := _sim.e_phase
	var grunts := 0
	var brutes := 0
	for j in _sim.e_count:
		if e_kind[j] == CrowdSim.Kind.BRUTE:
			if brutes >= _cap_brute:
				continue
			var o := brutes * STRIDE
			_buf_brute[o + 3] = e_px[j]
			_buf_brute[o + 11] = e_pz[j]
			_buf_brute[o + CUSTOM] = e_phase[j]
			brutes += 1
		else:
			var o := grunts * STRIDE
			_buf_grunt[o + 3] = e_px[j]
			_buf_grunt[o + 11] = e_pz[j]
			_buf_grunt[o + CUSTOM] = e_phase[j]
			grunts += 1

	_upload(_mm_soldier, _buf_soldier, soldiers)
	_upload(_mm_champion, _buf_champion, champions)
	_upload(_mm_grunt, _buf_grunt, grunts)
	_upload(_mm_brute, _buf_brute, brutes)


func _upload(mm: MultiMesh, buffer: PackedFloat32Array, count: int) -> void:
	if count == 0 and mm.visible_instance_count == 0:
		return
	mm.buffer = buffer
	mm.visible_instance_count = count


func _make_layer(visuals: UnitVisuals, capacity: int) -> MultiMesh:
	var mm := MultiMesh.new()
	# Format flags must be set before instance_count.
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = true
	mm.mesh = visuals.mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = visuals.material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visuals.cast_shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Units are always somewhere on the road; a fixed box skips per-frame AABB work for culling.
	mmi.custom_aabb = AABB(
			Vector3(-Tuning.ROAD_HALF_WIDTH - 2.0, -1.0, Tuning.ROAD_FAR_Z - 2.0),
			Vector3(Tuning.ROAD_WIDTH + 4.0, 6.0, Tuning.ROAD_NEAR_Z - Tuning.ROAD_FAR_Z + 4.0))
	add_child(mmi)
	return mm


func _make_buffer(capacity: int, scale: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(capacity * STRIDE)
	buf.fill(0.0)
	for i in capacity:
		var o := i * STRIDE
		buf[o] = scale
		buf[o + 5] = scale
		buf[o + 10] = scale
	return buf

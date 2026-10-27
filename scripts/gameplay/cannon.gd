class_name Cannon
extends Node3D
## Player cannon (CLAUDE.md §3.2): drag anywhere or A/D to move, hold a
## finger or Space to auto-fire. Every 26th shot is a champion.

const RECOIL_DISTANCE := 0.18
const RECOIL_RECOVER := 14.0

var fire_interval: float = Tuning.fire_interval(0)
var champion_value: int = Tuning.CHAMPION_BASE_VALUE
var shots: int = 0
var target_x: float = 0.0
var enabled: bool = true

var _sim: CrowdSim
var _cooldown: float = 0.0
var _touches: Dictionary = {}
var _barrel: Node3D
var _recoil: float = 0.0


func setup(sim: CrowdSim, interval: float, champ_value: int) -> void:
	_sim = sim
	fire_interval = interval
	champion_value = champ_value
	position = Vector3(0.0, 0.0, Tuning.CANNON_Z)
	_build_visuals()


func is_firing() -> bool:
	return enabled and (not _touches.is_empty() or Input.is_action_pressed(&"fire"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = true
		else:
			_touches.erase(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var screen_width := get_viewport().get_visible_rect().size.x
		if screen_width > 0.0:
			target_x += drag.relative.x / screen_width * Tuning.ROAD_WIDTH * Tuning.DRAG_SENSITIVITY
			target_x = clampf(target_x, -Tuning.CANNON_MAX_X, Tuning.CANNON_MAX_X)


func _notification(what: int) -> void:
	# A finger lifted while paused or backgrounded never sends its release.
	if what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_touches.clear()


func tick(dt: float) -> void:
	var axis := Input.get_axis(&"move_left", &"move_right")
	if axis != 0.0:
		target_x = clampf(target_x + axis * Tuning.CANNON_KEY_SPEED * dt, -Tuning.CANNON_MAX_X, Tuning.CANNON_MAX_X)
	position.x = lerpf(position.x, target_x, 1.0 - exp(-Tuning.CANNON_FOLLOW_RATE * dt))

	if is_firing():
		_cooldown -= dt
		while _cooldown <= 0.0:
			_fire_one()
			_cooldown += fire_interval
	else:
		_cooldown = maxf(0.0, _cooldown - dt)

	_recoil = maxf(0.0, _recoil - RECOIL_RECOVER * dt)
	_barrel.position.z = -0.55 + _recoil * RECOIL_DISTANCE


func _fire_one() -> void:
	shots += 1
	var x := position.x + randf_range(-Tuning.MUZZLE_JITTER_X, Tuning.MUZZLE_JITTER_X)
	var vx := randf_range(-Tuning.SOLDIER_SPREAD, Tuning.SOLDIER_SPREAD)
	var is_champion := shots % Tuning.CHAMPION_EVERY == 0
	if is_champion:
		_sim.spawn_friendly(x, Tuning.MUZZLE_Z, CrowdSim.Kind.CHAMPION, champion_value, vx * 0.3)
	else:
		_sim.spawn_friendly(x, Tuning.MUZZLE_Z, CrowdSim.Kind.SOLDIER, 1, vx)
	_recoil = 1.0
	GameEvents.shot_fired.emit(is_champion)
	GameEvents.champion_progress.emit(float(shots % Tuning.CHAMPION_EVERY) / float(Tuning.CHAMPION_EVERY))


func _build_visuals() -> void:
	var blue := PlaceholderMeshes.material(Color(0.18, 0.45, 0.95), 0.45)
	var dark := PlaceholderMeshes.material(Color(0.15, 0.17, 0.22), 0.6)

	var carriage_mesh := BoxMesh.new()
	carriage_mesh.size = Vector3(1.3, 0.5, 1.5)
	var carriage := MeshInstance3D.new()
	carriage.mesh = carriage_mesh
	carriage.material_override = blue
	carriage.position = Vector3(0.0, 0.55, 0.15)
	add_child(carriage)

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.42
	wheel_mesh.bottom_radius = 0.42
	wheel_mesh.height = 0.2
	wheel_mesh.radial_segments = 14
	for side: float in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.material_override = dark
		wheel.rotation.z = PI * 0.5
		wheel.position = Vector3(side * 0.75, 0.42, 0.3)
		add_child(wheel)

	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.24
	barrel_mesh.bottom_radius = 0.3
	barrel_mesh.height = 1.5
	barrel_mesh.radial_segments = 12
	var barrel := MeshInstance3D.new()
	barrel.mesh = barrel_mesh
	barrel.material_override = blue
	barrel.rotation.x = -PI * 0.5   # cylinder +Y now points down the road (-Z)
	_barrel = Node3D.new()
	_barrel.position = Vector3(0.0, 0.95, -0.55)
	_barrel.rotation.x = deg_to_rad(8.0)
	_barrel.add_child(barrel)
	add_child(_barrel)

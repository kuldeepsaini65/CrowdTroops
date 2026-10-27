class_name CameraRig
extends Node3D
## Fixed perspective camera behind and above the cannon (CLAUDE.md §3.1).
## Height and distance are solved from pitch + FOV so the ground strip
## [CAMERA_VIEW_FAR_Z, CAMERA_VIEW_NEAR_Z] exactly fills a 9:16 screen. Taller
## screens keep the width (and see more above/below); wider screens keep the
## height. The rig follows the cannon on X and supports trauma-based shake.

var follow_target: Node3D

var _camera: Camera3D
var _trauma: float = 0.0


func _ready() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		add_child(_camera)
	_camera.current = true
	_camera.near = 0.5
	_camera.far = 250.0
	_place_camera()
	_apply_aspect()
	get_viewport().size_changed.connect(_apply_aspect)
	GameEvents.screen_shake_requested.connect(add_shake)


func add_shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _process(delta: float) -> void:
	if follow_target != null:
		var goal := follow_target.position.x * Tuning.CAMERA_FOLLOW_AMOUNT
		var k := 1.0 - pow(1.0 - Tuning.CAMERA_FOLLOW_LERP, delta * 60.0)
		position.x = lerpf(position.x, goal, k)
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - Tuning.SHAKE_DECAY * delta)
		var s := _trauma * _trauma * Tuning.SHAKE_MAX_OFFSET
		_camera.h_offset = randf_range(-s, s)
		_camera.v_offset = randf_range(-s, s)
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


func _place_camera() -> void:
	var pitch := deg_to_rad(Tuning.CAMERA_PITCH_DEG)
	var half_vfov := deg_to_rad(Tuning.CAMERA_VFOV_DEG) * 0.5
	var top_angle := pitch - half_vfov       # ray to the top screen edge (below horizon)
	var bottom_angle := pitch + half_vfov    # ray to the bottom screen edge
	var ground_span := Tuning.CAMERA_VIEW_NEAR_Z - Tuning.CAMERA_VIEW_FAR_Z
	var height := ground_span / (1.0 / tan(top_angle) - 1.0 / tan(bottom_angle))
	var z := Tuning.CAMERA_VIEW_NEAR_Z + height / tan(bottom_angle)
	_camera.position = Vector3(0.0, height, z)
	_camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _apply_aspect() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var vfov := deg_to_rad(Tuning.CAMERA_VFOV_DEG)
	if aspect < Tuning.CAMERA_REF_ASPECT:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.fov = rad_to_deg(2.0 * atan(tan(vfov * 0.5) * Tuning.CAMERA_REF_ASPECT))
	else:
		_camera.keep_aspect = Camera3D.KEEP_HEIGHT
		_camera.fov = Tuning.CAMERA_VFOV_DEG

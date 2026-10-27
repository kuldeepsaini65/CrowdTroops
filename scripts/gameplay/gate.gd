class_name Gate
extends Node3D
## A sliding glass gate with posts and a floating label (CLAUDE.md §3.4).
## GameController ticks it and pushes its span into CrowdSim; the sim decides
## which units pass through.

const PANEL_HEIGHT := 2.0
const PANEL_BOTTOM := 0.25
const POST_RADIUS := 0.1
const LABEL_HEIGHT := 3.1
const FLASH_DECAY := 4.0
const BASE_EMISSION := 0.35

const COLOR_MULTIPLY := Color(0.55, 0.3, 1.0)
const COLOR_ADD := Color(0.2, 0.6, 1.0)

var def: GateDef
var width: float = Tuning.GATE_WIDTH_SINGLE
var speed: float = 0.0
var direction: float = 1.0
var center_x: float = 0.0

var _min_center: float = 0.0
var _max_center: float = 0.0
var _panel_mat: StandardMaterial3D
var _flash: float = 0.0


func setup(gate_def: GateDef, world_speed: float) -> void:
	def = gate_def
	width = def.width
	speed = world_speed * def.speed_mult
	direction = -1.0 if def.direction < 0.0 else 1.0
	_min_center = def.min_x + width * 0.5
	_max_center = maxf(_min_center, def.max_x - width * 0.5)
	center_x = clampf(def.start_x, _min_center, _max_center)
	position = Vector3(center_x, 0.0, def.z)
	_build_visuals()


func tick(dt: float) -> void:
	if speed > 0.0 and _max_center > _min_center:
		center_x += direction * speed * dt
		if center_x > _max_center:
			center_x = 2.0 * _max_center - center_x
			direction = -1.0
		elif center_x < _min_center:
			center_x = 2.0 * _min_center - center_x
			direction = 1.0
		position.x = center_x
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - FLASH_DECAY * dt)
		_panel_mat.emission_energy_multiplier = BASE_EMISSION + _flash * 2.5


func span_x0() -> float:
	return center_x - width * 0.5


func span_x1() -> float:
	return center_x + width * 0.5


func flash() -> void:
	_flash = 1.0


func _build_visuals() -> void:
	var color := COLOR_MULTIPLY if def.op == GateDef.Op.MULTIPLY else COLOR_ADD

	_panel_mat = StandardMaterial3D.new()
	_panel_mat.albedo_color = Color(color, 0.45)
	_panel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_panel_mat.roughness = 0.15
	_panel_mat.metallic_specular = 0.8
	_panel_mat.emission_enabled = true
	_panel_mat.emission = color
	_panel_mat.emission_energy_multiplier = BASE_EMISSION
	_panel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(width, PANEL_HEIGHT, 0.08)
	var panel := MeshInstance3D.new()
	panel.mesh = panel_mesh
	panel.material_override = _panel_mat
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.position.y = PANEL_BOTTOM + PANEL_HEIGHT * 0.5
	add_child(panel)

	var post_mat := PlaceholderMeshes.material(Color(0.92, 0.92, 0.98), 0.3)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = POST_RADIUS
	post_mesh.bottom_radius = POST_RADIUS
	post_mesh.height = PANEL_BOTTOM + PANEL_HEIGHT + 0.2
	post_mesh.radial_segments = 8
	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = post_mat
		post.position = Vector3(side * width * 0.5, post_mesh.height * 0.5, 0.0)
		add_child(post)

	var label := Label3D.new()
	label.text = def.label_text()
	label.font_size = 150
	label.outline_size = 36
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.12, 0.05, 0.25)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = LABEL_HEIGHT
	add_child(label)

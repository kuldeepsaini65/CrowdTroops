class_name UnitVisuals
extends Resource
## Mesh + material for one unit type. Swap the mesh for a real model later
## (e.g. a .tres pointing at an imported glTF mesh) with no code changes.
## The mesh must face -Z for friendlies; enemies are mirrored by their mesh.

@export var mesh: Mesh
@export var material: Material
## Uniform scale applied to every instance (champions also scale by √value).
@export var base_scale: float = 1.0
@export var cast_shadows: bool = true

const UNIT_SHADER: Shader = preload("res://assets/shaders/unit.gdshader")


static func make_placeholder(kind: int) -> UnitVisuals:
	var v := UnitVisuals.new()
	var step_rate := 12.0
	match kind:
		CrowdSim.Kind.SOLDIER:
			v.mesh = PlaceholderMeshes.soldier(Color(0.16, 0.45, 1.0), Color(0.1, 0.3, 0.85))
		CrowdSim.Kind.CHAMPION:
			v.mesh = PlaceholderMeshes.champion(Color(1.0, 0.78, 0.18), Color(1.0, 0.92, 0.4))
			step_rate = 9.0
		CrowdSim.Kind.GRUNT:
			v.mesh = PlaceholderMeshes.soldier(Color(0.95, 0.18, 0.16), Color(0.7, 0.08, 0.08))
			step_rate = 7.0
		CrowdSim.Kind.BRUTE:
			v.mesh = PlaceholderMeshes.brute(Color(0.55, 0.06, 0.07), Color(0.95, 0.9, 0.8))
			step_rate = 5.0
	var mat := ShaderMaterial.new()
	mat.shader = UNIT_SHADER
	mat.set_shader_parameter("step_rate", step_rate)
	v.material = mat
	return v

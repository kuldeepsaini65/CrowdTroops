class_name PlaceholderMeshes
extends RefCounted
## Procedural stand-in meshes (CLAUDE.md §4) built from primitives and merged
## into one surface with baked vertex colours, so each unit type is a single
## draw call. Kept deliberately low-poly: there can be 2,000+ of them on screen.


static func soldier(body: Color, spikes: Color) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	parts.append(_part(_capsule(0.22, 0.6), Vector3(0, 0.3, 0), body))
	parts.append(_part(_sphere(0.17), Vector3(0, 0.7, 0), body))
	_add_spikes(parts, 3, Vector3(0, 0.82, 0), 0.08, 0.07, 0.2, 0.55, spikes)
	return _combine(parts)


static func champion(body: Color, crown: Color) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	parts.append(_part(_capsule(0.24, 0.64), Vector3(0, 0.32, 0), body))
	parts.append(_part(_sphere(0.18), Vector3(0, 0.74, 0), body))
	var band := CylinderMesh.new()
	band.top_radius = 0.16
	band.bottom_radius = 0.15
	band.height = 0.07
	band.radial_segments = 8
	band.rings = 0
	parts.append(_part(band, Vector3(0, 0.88, 0), crown))
	_add_spikes(parts, 5, Vector3(0, 0.95, 0), 0.13, 0.045, 0.14, 0.15, crown)
	return _combine(parts)


static func brute(body: Color, horns: Color) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	parts.append(_part(_capsule(0.36, 0.86), Vector3(0, 0.43, 0), body))
	parts.append(_part(_sphere(0.22), Vector3(0, 0.98, 0), body))
	for side: float in [-1.0, 1.0]:
		var horn := _cone(0.07, 0.3)
		var basis := Basis(Vector3.BACK, -side * 1.0)
		parts.append({"mesh": horn, "xform": Transform3D(basis, Vector3(side * 0.2, 1.1, 0)), "color": horns})
	return _combine(parts)


static func material(color: Color, roughness: float = 0.7) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


static func _add_spikes(parts: Array[Dictionary], count: int, center: Vector3, ring: float,
		radius: float, height: float, tilt: float, color: Color) -> void:
	for k in count:
		var yaw := TAU * float(k) / float(count)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		var offset := Vector3(sin(yaw) * ring, 0.0, cos(yaw) * ring)
		parts.append({"mesh": _cone(radius, height), "xform": Transform3D(basis, center + offset), "color": color})


static func _part(mesh: PrimitiveMesh, pos: Vector3, color: Color) -> Dictionary:
	return {"mesh": mesh, "xform": Transform3D(Basis(), pos), "color": color}


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 8
	m.rings = 2
	return m


static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	return m


static func _cone(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 5
	m.rings = 0
	m.cap_top = false
	m.cap_bottom = false
	return m


## Merges primitive parts into one indexed surface with per-part vertex colour.
static func _combine(parts: Array[Dictionary]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var mesh: PrimitiveMesh = part["mesh"]
		var xform: Transform3D = part["xform"]
		var srgb: Color = part["color"]
		var color := srgb.srgb_to_linear()   # shaders read vertex colours as linear
		var arrays := mesh.get_mesh_arrays()
		var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var offset := verts.size()
		var normal_basis := xform.basis.inverse().transposed()
		for k in src_verts.size():
			verts.append(xform * src_verts[k])
			normals.append((normal_basis * src_normals[k]).normalized())
			colors.append(color)
		for k in src_indices.size():
			indices.append(src_indices[k] + offset)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return result

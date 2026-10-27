// Crowd unit shader (CLAUDE.md §5.3): hop + waddle animated per instance in
// the vertex stage, so thousands of MultiMesh instances need no CPU animation.
// INSTANCE_CUSTOM.x = phase offset (radians), written by UnitRenderer.
// Base colours come from the mesh's vertex colours, multiplied by `tint`.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.42;
uniform float step_rate = 12.0;
uniform float hop_height = 0.1;
uniform float waddle = 0.14;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	float t = TIME * step_rate + INSTANCE_CUSTOM.x;
	float s = sin(t);
	float ang = s * waddle;
	float c = cos(ang);
	float sn = sin(ang);
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	// Roll around the forward (Z) axis, pivoting at the feet, then hop.
	VERTEX.x = c * v.x - sn * v.y;
	VERTEX.y = sn * v.x + c * v.y + abs(s) * hop_height;
	NORMAL.x = c * n.x - sn * n.y;
	NORMAL.y = sn * n.x + c * n.y;
}

void fragment() {
	ALBEDO = COLOR.rgb * tint.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	RIM = rim_amount;
	RIM_TINT = rim_tint;
}

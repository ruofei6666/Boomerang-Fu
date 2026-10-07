shader_type spatial;
render_mode cull_disabled;

uniform vec4 skin_color : source_color = vec4(1.0);
uniform float surface_roughness = 0.7;
uniform mat4 slice_space;
uniform float half_sign = 1.0;
uniform bool uses_vertex_color = false;
varying float cut_x;
varying vec3 mesh_tint;

void vertex() {
	cut_x = (slice_space * vec4(VERTEX, 1.0)).x;
	mesh_tint = COLOR.rgb;
}

void fragment() {
	if (cut_x * half_sign < -0.001) {
		discard;
	}
	ALBEDO = skin_color.rgb * (uses_vertex_color ? mesh_tint : vec3(1.0));
	ROUGHNESS = surface_roughness;
}

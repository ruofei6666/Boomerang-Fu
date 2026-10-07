shader_type spatial;
render_mode cull_disabled;

uniform vec4 skin_color : source_color = vec4(1.0);
uniform float surface_roughness = 0.7;
uniform mat4 slice_space;
uniform float half_sign = 1.0;
varying float cut_x;

void vertex() {
	cut_x = (slice_space * vec4(VERTEX, 1.0)).x;
}

void fragment() {
	if (cut_x * half_sign < -0.001) {
		discard;
	}
	ALBEDO = skin_color.rgb;
	ROUGHNESS = surface_roughness;
}

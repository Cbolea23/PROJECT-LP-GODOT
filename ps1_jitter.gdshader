shader_type spatial;
// Remove "skip_vertex_transform" so Godot handles shadows/lighting normally
// We only disable advanced PBR features to keep it PS1-style fast
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color; // Removed "filter_nearest" to let you decide
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float jitter_amount : hint_range(0.0, 1.0) = 0.5; 
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	// 1. Standard Vertex Transform
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 2. Apply Jitter (Snap to Grid)
	float snap_res = 50.0 * (1.0 - jitter_amount); // Adjust 50.0 up for less jitter
	vec4 snapped = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	
	if (snap_res > 0.0) {
		snapped.xyz = snapped.xyz / snapped.w; 
		snapped.xy = floor(snapped.xy * snap_res) / snap_res; 
		snapped.xyz = snapped.xyz * snapped.w; 
	}
	
	POSITION = snapped;
}

void fragment() {
	// 3. Standard Texture Lookup (No Affine Warping)
	vec4 tex_color = texture(albedo_tex, UV);
	
	// Mix Texture and Color (Fixes "White" or "Brown" glitches)
	ALBEDO = tex_color.rgb * albedo_color.rgb;
	ALPHA = tex_color.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}
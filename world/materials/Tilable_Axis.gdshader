shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Texture Maps (with anisotropic filtering for sharp grazing angles on trim sheets)
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

// Material Properties
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform float roughness_mult : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_mult : hint_range(0.0, 2.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float normal_scale : hint_range(-2.0, 2.0) = 1.0;

// Trim Sheet UV Controls
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform bool auto_scale = true;
uniform int scale_axis : hint_enum("X", "Y", "Z") = 0; // 0 = X, 1 = Y, 2 = Z

void vertex() {
	// Extract the object's scale along the selected axis (0=X, 1=Y, 2=Z)
	float axis_scale = auto_scale ? length(MODEL_MATRIX[scale_axis].xyz) : 1.0;
	
	// Scale U by the selected axis scale, apply user scale & offset
	UV.x = (UV.x * axis_scale * uv_scale.x) + uv_offset.x;
	UV.y = (UV.y * uv_scale.y) + uv_offset.y;
}

void fragment() {
	// 1. Sample Albedo with Tint & Brightness
	vec3 albedo_sample = texture(albedo_tex, UV).rgb;
	ALBEDO = albedo_sample * albedo_tint.rgb * brightness;
	
	// 2. Sample ORM (R = Occlusion, G = Roughness, B = Metallic)
	vec3 orm = texture(orm_tex, UV).rgb;
	AO = mix(1.0, orm.r, ao_strength);
	ROUGHNESS = clamp(orm.g * roughness_mult, 0.0, 1.0);
	METALLIC = clamp(orm.b * metallic_mult, 0.0, 1.0);
	
	// 3. Normal Map (supports negative values to flip/invert normal relief)
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
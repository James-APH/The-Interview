shader_type spatial;

// Albedo & Saturation
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

// Separate AO, Roughness, and Metallic Maps
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ao_light_affect : hint_range(0.0, 3.0) = 1.0;

uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 3.0) = 1.0;

uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float metallic : hint_range(0.0, 3.0) = 1.0;

// Normal Map
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

// UV Controls
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

void vertex() {
	UV = UV * uv_scale + uv_offset;
}

void fragment() {
	// 1. Sample Albedo and adjust saturation
	vec4 tex_albedo = texture(albedo_texture, UV) * albedo_tint;
	float luma = dot(tex_albedo.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(luma), tex_albedo.rgb, saturation);

	// 2. Sample individual AO, Roughness, and Metallic maps
	AO = texture(ao_texture, UV).r;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = texture(roughness_texture, UV).g * roughness;
	METALLIC = texture(metallic_texture, UV).b * metallic;

	// 3. Sample Normal Map
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
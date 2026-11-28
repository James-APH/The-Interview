shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Texture Maps
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;

// Material Properties
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float roughness_mult : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_mult : hint_range(0.0, 2.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 3.0) = 1.0;
uniform float normal_scale : hint_range(-2.0, 2.0) = 1.0;
uniform float brightness : hint_range(0.0, 5.0) = 1.0;

// Triplanar & POM Settings
uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv_offset = vec3(0.0, 0.0, 0.0);
uniform float triplanar_sharpness : hint_range(0.5, 16.0) = 4.0;
uniform bool world_triplanar = true;

uniform float height_scale : hint_range(0.0, 0.2) = 0.04;
uniform int min_layers : hint_range(1, 64) = 8;
uniform int max_layers : hint_range(1, 64) = 32;
uniform bool invert_height = true; // True if white = high (standard heightmap), False if black = deep (depthmap)

varying vec3 v_pos;
varying vec3 v_normal;

void vertex() {
if (world_triplanar) {
v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
v_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
} else {
v_pos = VERTEX;
v_normal = normalize(NORMAL);
}
}

// Parallax Occlusion Mapping function for a single planar projection
vec2 parallax_mapping(vec2 base_uv, vec3 view_dir_ts) {
// Prevent extreme stretching at grazing angles
view_dir_ts.z = max(view_dir_ts.z, 0.15);

float num_layers = mix(float(max_layers), float(min_layers), abs(dot(vec3(0.0, 0.0, 1.0), view_dir_ts)));
float layer_depth = 1.0 / num_layers;
float current_layer_depth = 0.0;

vec2 p = (view_dir_ts.xy / view_dir_ts.z) * height_scale;
vec2 delta_uv = p / num_layers;

vec2 current_uv = base_uv;
float raw_h = texture(height_tex, current_uv).r;
float current_depth = invert_height ? (1.0 - raw_h) : raw_h;

// Raymarch through height layers
for (int i = 0; i < max_layers; i++) {
if (current_layer_depth >= current_depth) {
break;
}
current_uv -= delta_uv;
raw_h = texture(height_tex, current_uv).r;
current_depth = invert_height ? (1.0 - raw_h) : raw_h;
current_layer_depth += layer_depth;
}

// Steep Parallax / Occlusion interpolation
vec2 prev_uv = current_uv + delta_uv;
float after_depth = current_depth - current_layer_depth;
float prev_raw_h = texture(height_tex, prev_uv).r;
float before_depth = (invert_height ? (1.0 - prev_raw_h) : prev_raw_h) - current_layer_depth + layer_depth;

float weight = after_depth / (after_depth - before_depth);
return mix(current_uv, prev_uv, weight);
}

// Reorient normal map from tangent space of each axis to world/local space
vec3 blend_rnm(vec3 n1, vec3 n2) {
n1.z += 1.0;
n2.xy = -n2.xy;
return n1 * dot(n1, n2) / n1.z - n2;
}

void fragment() {
// 1. Calculate Triplanar Blend Weights
vec3 blend = pow(abs(v_normal), vec3(triplanar_sharpness));
blend /= (blend.x + blend.y + blend.z);

// 2. Get View Direction in matching coordinate space (World or Local)
vec3 view_dir_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
vec3 view_dir = world_triplanar ? view_dir_world : normalize((inverse(MODEL_MATRIX) * vec4(view_dir_world, 0.0)).xyz);

// 3. Base UVs for each projection plane
vec3 scaled_pos = v_pos * uv_scale + uv_offset;
vec2 uv_x = scaled_pos.zy;
vec2 uv_y = scaled_pos.xz;
vec2 uv_z = scaled_pos.xy;

// 4. Run POM per axis using axis-aligned tangent view vectors
vec3 v_ts_x = vec3(view_dir.z, view_dir.y, abs(view_dir.x));
vec3 v_ts_y = vec3(view_dir.x, view_dir.z, abs(view_dir.y));
vec3 v_ts_z = vec3(view_dir.x, view_dir.y, abs(view_dir.z));

if (blend.x > 0.01) uv_x = parallax_mapping(uv_x, v_ts_x);
if (blend.y > 0.01) uv_y = parallax_mapping(uv_y, v_ts_y);
if (blend.z > 0.01) uv_z = parallax_mapping(uv_z, v_ts_z);

// 5. Sample Albedo
vec3 alb_x = texture(albedo_tex, uv_x).rgb;
vec3 alb_y = texture(albedo_tex, uv_y).rgb;
vec3 alb_z = texture(albedo_tex, uv_z).rgb;
vec3 base_albedo = (alb_x * blend.x + alb_y * blend.y + alb_z * blend.z) * albedo_tint.rgb * brightness;

// 6. Sample ORM (R = Occlusion, G = Roughness, B = Metallic)
vec3 orm_x = texture(orm_tex, uv_x).rgb;
vec3 orm_y = texture(orm_tex, uv_y).rgb;
vec3 orm_z = texture(orm_tex, uv_z).rgb;
vec3 orm = orm_x * blend.x + orm_y * blend.y + orm_z * blend.z;

float ao = mix(1.0, orm.r, ao_strength);
AO = ao;
// Stronger crevice darkening to preserve deep mortar contrast under direct light
ALBEDO = base_albedo * mix(1.0, ao, 0.75);
ROUGHNESS = clamp(orm.g * roughness_mult, 0.0, 1.0);
METALLIC = clamp(orm.b * metallic_mult, 0.0, 1.0);
SPECULAR = 0.05; // Prevents direct light from washing out dark bricks with white glare

// 7. Sample & Reorient Triplanar Normal Maps (UDN style with Z reconstruction)
	vec2 n_xy_x = (texture(normal_tex, uv_x).xy * 2.0 - 1.0) * normal_scale;
	vec2 n_xy_y = (texture(normal_tex, uv_y).xy * 2.0 - 1.0) * normal_scale;
	vec2 n_xy_z = (texture(normal_tex, uv_z).xy * 2.0 - 1.0) * normal_scale;

	// Reconstruct Z so hint_normal (RG-packed) always points outward (+Z)
	vec3 tnorm_x = vec3(n_xy_x, sqrt(max(1.0 - dot(n_xy_x, n_xy_x), 0.0)));
	vec3 tnorm_y = vec3(n_xy_y, sqrt(max(1.0 - dot(n_xy_y, n_xy_y), 0.0)));
	vec3 tnorm_z = vec3(n_xy_z, sqrt(max(1.0 - dot(n_xy_z, n_xy_z), 0.0)));

	vec3 sign_n = vec3(
		v_normal.x < 0.0 ? -1.0 : 1.0,
		v_normal.y < 0.0 ? -1.0 : 1.0,
		v_normal.z < 0.0 ? -1.0 : 1.0
	);

	// Swizzle tangent normals into world/local space
	// X plane (UV = ZY -> U = Z, V = Y)
	vec3 world_norm_x = vec3(tnorm_x.z * sign_n.x, tnorm_x.y, tnorm_x.x * sign_n.x);
	// Y plane (UV = XZ -> U = X, V = Z)
	vec3 world_norm_y = vec3(tnorm_y.x * sign_n.y, tnorm_y.z * sign_n.y, tnorm_y.y);
	// Z plane (UV = XY -> U = X, V = Y)
	vec3 world_norm_z = vec3(tnorm_z.x * sign_n.z, tnorm_z.y, tnorm_z.z * sign_n.z);

	// Blend the projections
	vec3 final_norm = normalize(
		world_norm_x * blend.x +
		world_norm_y * blend.y +
		world_norm_z * blend.z
	);

	// If triplanar was calculated in local space, convert to world space first
	if (!world_triplanar) {
		final_norm = normalize(MODEL_NORMAL_MATRIX * final_norm);
	}

	// Convert world-space normal into view space
	NORMAL = normalize((VIEW_MATRIX * vec4(final_norm, 0.0)).xyz);
}
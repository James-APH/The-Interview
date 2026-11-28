shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float point_size : hint_range(0,128);
uniform sampler2D texture_orm : hint_roughness_g,filter_linear_mipmap,repeat_enable;
uniform float ao_light_affect : hint_range(0.0, 1.0, 0.01);
uniform sampler2D texture_normal : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform float normal_scale : hint_range(-16,16);
uniform float heightmap_scale;
uniform int height_iters_max : hint_range(1, 30, 1) = 10;
uniform int height_iters_min : hint_range(1, 30, 1) = 4;
uniform vec2 heightmap_flip;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;
}

void fragment() {
	vec2 base_uv = UV; //Parallax code starts here
	{
		vec3 view_dir = normalize(normalize(-VERTEX)*mat3(TANGENT*heightmap_flip.x,-BINORMAL*heightmap_flip.y,NORMAL));
		
		float num_layers = mix(float(height_iters_max), float(height_iters_min), abs(dot(vec3(0.0, 0.0, 1.0), view_dir))/2. ); //Distance lod
		num_layers = round(num_layers/3.)*3.; //Layers stepped every 3
		
		for (float i = 0.; i < num_layers; i++){
			float h = (texture(texture_orm, base_uv).a - 0.5); //Uses alpha channel of ORM texture
			h *= heightmap_scale/num_layers;
			h -= (1./(i+1.))*(1./num_layers);
			h = clamp(h, -0.5, 0.5);
			h -= 0.5/num_layers;
			
			vec2 view = view_dir.xy;
			view *= 0.01;
			view *= h;
			
			base_uv += view;
		}
	}
	
	//Material stuff
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	vec4 orm_tex = texture(texture_orm,base_uv);
	ROUGHNESS = orm_tex.g;
	METALLIC = orm_tex.b;
	NORMAL_MAP = texture(texture_normal,base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	AO = orm_tex.r;
	AO_LIGHT_AFFECT = ao_light_affect;
}
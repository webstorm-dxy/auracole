// 角色专用二次元着色器，仅在角色材质上生效，不承担任何场景级或环境级后处理职责。
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// 可从原始材质继承的基础贴图输入。
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_texture = false;

// 与设置脚本共享的核心颜色参数。
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(0.74, 0.8, 0.92, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.97, 0.98, 1.0);

// 暴露给检查器的明暗分段、高光与边缘光阈值。
uniform float shadow_threshold : hint_range(0.0, 1.0, 0.01) = 0.48;
uniform float shadow_softness : hint_range(0.001, 0.2, 0.001) = 0.04;
uniform float shadow_wrap : hint_range(-0.2, 0.2, 0.01) = 0.05;
uniform float shadow_tint_strength : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float highlight_threshold : hint_range(0.0, 1.0, 0.01) = 0.86;
uniform float highlight_softness : hint_range(0.001, 0.2, 0.001) = 0.04;
uniform float rim_strength : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float rim_threshold : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform float rim_softness : hint_range(0.001, 0.2, 0.001) = 0.1;
uniform float ambient_boost : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform float alpha_cutoff : hint_range(0.0, 1.0, 0.01) = 0.1;


// 采样基础颜色，并将环境反射相关参数压低，避免角色材质干扰场景环境表现。
void fragment() {
	vec4 tex = use_texture ? texture(albedo_texture, UV) : vec4(1.0);
	vec4 base = tex * base_color;

	ALBEDO = base.rgb;
	ALPHA = base.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	// 仅保留角色自身的轻微补光，不依赖环境探针、反射或屏幕空间链路。
	EMISSION = base.rgb * ambient_boost;
}


// 通过柔和分段、受控高光和轮廓边缘光生成自然的角色向二次元光照。
void light() {
	vec3 normal_dir = normalize(NORMAL);
	vec3 light_dir = normalize(LIGHT);
	vec3 view_dir = normalize(VIEW);

	float lambert_term = clamp(dot(normal_dir, light_dir) + shadow_wrap, 0.0, 1.0);
	float light_band = smoothstep(
		shadow_threshold - shadow_softness,
		shadow_threshold + shadow_softness,
		lambert_term
	);

	vec3 shadow_tinted = ALBEDO * mix(vec3(1.0), shadow_color.rgb, shadow_tint_strength);
	vec3 toon_diffuse = mix(shadow_tinted, ALBEDO, light_band);

	vec3 half_vector = normalize(light_dir + view_dir);
	float specular_term = pow(max(dot(normal_dir, half_vector), 0.0), 24.0);
	float specular_band = smoothstep(
		highlight_threshold - highlight_softness,
		highlight_threshold + highlight_softness,
		specular_term
	) * highlight_strength * light_band;

	float view_falloff = 1.0 - max(dot(normal_dir, view_dir), 0.0);
	float rim_band = smoothstep(
		rim_threshold - rim_softness,
		rim_threshold + rim_softness,
		view_falloff
	) * rim_strength * mix(0.35, 1.0, 1.0 - light_band);

	vec3 light_contribution = LIGHT_COLOR * ATTENUATION;
	DIFFUSE_LIGHT += toon_diffuse * light_contribution;
	SPECULAR_LIGHT += (
		highlight_color.rgb * specular_band +
		mix(ALBEDO, highlight_color.rgb, 0.85) * rim_band
	) * light_contribution;
}

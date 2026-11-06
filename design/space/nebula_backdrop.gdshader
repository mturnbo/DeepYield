// Full-screen space backdrop: a procedural nebula and two layers of stars.
// The view pans across the sky as the camera rotates, so the nebula sits in one
// fixed direction from the platform.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

group_uniforms Nebula;
uniform float nebula_azimuth_deg = 200.0;
uniform float nebula_elevation_deg = 4.0;
uniform float nebula_spread_deg : hint_range(10.0, 180.0) = 75.0;
uniform float nebula_strength : hint_range(0.0, 3.0) = 1.15;
uniform vec3 core_color : source_color = vec3(1.0, 0.55, 0.75);
uniform vec3 mid_color : source_color = vec3(0.62, 0.3, 0.85);
uniform vec3 edge_color : source_color = vec3(0.12, 0.42, 0.68);
uniform float dust_strength : hint_range(0.0, 1.0) = 0.55;

group_uniforms Stars;
uniform float star_brightness : hint_range(0.0, 3.0) = 1.6;
uniform float star_density : hint_range(0.0, 1.0) = 0.9;

group_uniforms Space;
uniform vec3 space_color : source_color = vec3(0.008, 0.011, 0.026);
uniform float view_width_deg : hint_range(30.0, 180.0) = 110.0;
uniform float view_tilt_deg = 6.0;

void vertex() {
	// Draw the quad over the whole screen at the far plane (reverse-Z: 0 is far).
	POSITION = vec4(VERTEX.xy, 0.00001, 1.0);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x);
	float b = mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x);
	float c = mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x);
	float d = mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 6; k++) {
		sum += amp * value_noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

vec3 direction_from(float azimuth, float elevation) {
	return vec3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth));
}

float star_layer(vec3 dir, float scale, float threshold) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float h = hash13(cell);
	if (h < threshold) {
		return 0.0;
	}
	vec3 center = vec3(hash13(cell + 1.7), hash13(cell + 3.1), hash13(cell + 5.3)) * 0.6 + 0.2;
	float r = length(fract(p) - center);
	float brightness = (h - threshold) / (1.0 - threshold);
	return brightness * smoothstep(0.16, 0.0, r);
}

void fragment() {
	// Camera heading around the vertical axis, read from the view matrix.
	vec3 cam_back = INV_VIEW_MATRIX[2].xyz;
	float yaw = atan(cam_back.x, cam_back.z) + PI;

	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float width = radians(view_width_deg);
	float azimuth = yaw - (SCREEN_UV.x - 0.5) * width;
	float elevation = radians(view_tilt_deg) + (0.5 - SCREEN_UV.y) * width / aspect;
	vec3 dir = direction_from(azimuth, elevation);

	vec3 center = direction_from(radians(nebula_azimuth_deg), radians(nebula_elevation_deg));
	float angle = acos(clamp(dot(dir, center), -1.0, 1.0));
	float falloff = 1.0 - smoothstep(0.0, radians(nebula_spread_deg), angle);

	float warp = fbm(dir * 2.2 + vec3(0.0, 0.0, TIME * 0.002));
	float clouds = fbm(dir * 4.5 + warp * 1.6);
	float density = clamp((clouds - 0.36) * 2.4, 0.0, 1.0) * falloff;
	density = pow(density, 1.35) * nebula_strength;

	vec3 nebula = mix(edge_color, mid_color, smoothstep(0.08, 0.45, density));
	nebula = mix(nebula, core_color, smoothstep(0.45, 0.95, density));
	vec3 color = space_color + nebula * density;

	float dust = smoothstep(0.52, 0.78, fbm(dir * 8.0 + 3.1));
	color *= 1.0 - dust * dust_strength * falloff;

	float twinkle = 0.85 + 0.15 * sin(TIME * 2.0 + hash13(floor(dir * 90.0)) * 40.0);
	float stars = star_layer(dir, 90.0, 1.0 - 0.03 * star_density) * twinkle;
	stars += 0.5 * star_layer(dir, 160.0, 1.0 - 0.06 * star_density);
	color += vec3(0.9, 0.93, 1.0) * stars * star_brightness * (1.0 - density * 0.6);

	ALBEDO = color;
}

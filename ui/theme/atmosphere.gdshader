// 907Hustle screen-space atmosphere: a physical-material soft-light pass +
// animated film grain + soft vignette. Reads the composited framebuffer beneath
// this layer and re-outputs it with the filmic pass on top.
//
//  * material  — a tiled grayscale surface (tex-card) blended in SOFT LIGHT, so
//    it adds worn concrete/paper character to every card and panel WITHOUT
//    shifting overall brightness (mid-gray in the texture = no change).
//  * grain     — bipolar per-pixel noise, reseeded each grain step (alive).
//  * vignette  — multiplies the edges down.
// Every knob is a uniform so intensity is one edit; tuned subtle by default.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// Material
uniform sampler2D material_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 material_tiles = vec2(2.4, 5.1);
uniform float material_strength : hint_range(0.0, 1.0) = 0.4;
uniform float material_contrast : hint_range(0.5, 4.0) = 1.6;

// Grain
uniform float grain_amount : hint_range(0.0, 0.15) = 0.05;
uniform float grain_speed : hint_range(0.0, 30.0) = 12.0;
// Vignette (UV-space; on a portrait screen this reads as a natural top/bottom falloff)
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.42;
uniform float vignette_radius : hint_range(0.0, 0.71) = 0.34;
uniform float vignette_softness : hint_range(0.01, 0.9) = 0.5;

// Cheap hash for per-pixel grain, reseeded each grain step.
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;

	// Material pass — bipolar detail add. The fibers/pits of the concrete texture
	// add faint light and dark, which stays visible on near-black cards where a
	// tonal (soft-light) blend would crush into the shadows. Mid-gray = no change.
	float m = texture(material_tex, SCREEN_UV * material_tiles).r;
	float d = (m - 0.5) * material_contrast;
	base += d * material_strength;

	// Vignette — multiply the edges down.
	float dist = length(SCREEN_UV - vec2(0.5));
	float vig = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);
	base *= (1.0 - vig * vignette_strength);

	// Animated film grain — per-pixel, quantized in time so it flickers like film.
	float t = floor(TIME * grain_speed);
	float g = hash13(vec3(FRAGCOORD.xy, t));
	base += (g - 0.5) * grain_amount;

	COLOR = vec4(base, 1.0);
}

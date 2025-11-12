shader_type canvas_item;

// Vignette / radial screen darken shader
// Attach this Shader to a full-screen ColorRect inside a CanvasLayer.

// SCREEN_TEXTURE is provided as a uniform in Godot 4+; declare it with the hint so
// the engine binds the current screen texture for sampling.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Vignette parameters (normalized screen space where applicable)
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.6;
uniform float smoothness = 0.25;
uniform float intensity = 0.7;
uniform vec4 vignette_color = vec4(0.0, 0.0, 0.0, 1.0);

// Film noise / scanline parameters
uniform float noise_strength = 0.05;    // overall grain strength
uniform float noise_scale = 800.0;      // grain size (larger = finer grain)
uniform float noise_speed = 1.0;        // grain animation speed
uniform vec3 noise_color = vec3(1.0, 1.0, 1.0); // grain tint (usually white)
uniform float scanline_strength = 0.02; // strength of horizontal scanlines
uniform float scanline_count = 800.0;   // number of scanlines across the screen
// Blur parameters
uniform float blur_strength = 0.0;      // 0 = off, 1 = full blur (mixes original with blurred)
uniform float blur_radius = 1.0;        // blur radius in pixels (affects sample offsets)

void vertex() {
	// Keep default vertex behavior (no special processing needed)
}

void fragment() {
	// Normalized screen UV [0..1]
	vec2 uv = SCREEN_UV;

	// Sample the current screen color
	vec4 screen_col = texture(SCREEN_TEXTURE, uv);

	// --- Optional blur (9-tap box blur) ---
	if (blur_strength > 0.0) {
		// compute texel size from the bound screen texture
		vec2 tex_size = vec2(textureSize(SCREEN_TEXTURE, 0));
		vec2 texel = 1.0 / tex_size;
		vec2 ofs = texel * blur_radius;
		vec4 b = vec4(0.0);
		b += texture(SCREEN_TEXTURE, uv + vec2(0.0, 0.0) * ofs);
		b += texture(SCREEN_TEXTURE, uv + vec2(1.0, 0.0) * ofs);
		b += texture(SCREEN_TEXTURE, uv + vec2(-1.0, 0.0) * ofs);
		b += texture(SCREEN_TEXTURE, uv + vec2(0.0, 1.0) * ofs);
		b += texture(SCREEN_TEXTURE, uv + vec2(0.0, -1.0) * ofs);
		b += texture(SCREEN_TEXTURE, uv + vec2(1.0, 1.0) * ofs);
		b += texture(SCREEN_TEXTURE, uv + vec2(1.0, -1.0) * ofs);
		b += texture(SCREEN_TEXTURE, uv + vec2(-1.0, 1.0) * ofs);
		b += texture(SCREEN_TEXTURE, uv + vec2(-1.0, -1.0) * ofs);
		b /= 9.0;
		// mix between original and blurred based on blur_strength
		screen_col = mix(screen_col, b, clamp(blur_strength, 0.0, 1.0));
	}

	// Distance from the chosen center
	float dist = distance(uv, center);

	// Create a smooth radial mask: 0.0 at center, 1.0 at the outer edge
	float vign = smoothstep(radius - smoothness, radius, dist);

	// Mix the screen color with the vignette color based on intensity
	vec4 out_col = mix(screen_col, vignette_color, vign * intensity);

	// --- Film grain (procedural) ---
	// Create pseudo-random noise based on screen coords and time
	float t = TIME * noise_speed;
	// scale uv to control grain frequency
	vec2 noise_uv = uv * noise_scale;
	// simple 2D hash / noise
	float n = fract(sin(dot(noise_uv + t, vec2(12.9898,78.233))) * 43758.5453);
	// center the noise around 0
	float grain = (n - 0.5) * 2.0 * noise_strength;

	// convert grain to color tint and add to the output color
	out_col.rgb = clamp(out_col.rgb + grain * noise_color, 0.0, 1.0);

	// --- Scanlines ---
	// Create horizontal scanline pattern
	float scan_pos = uv.y * scanline_count;
	float scan = sin(scan_pos * 3.14159);
	out_col.rgb = mix(out_col.rgb, out_col.rgb * (1.0 - scanline_strength * scan), 0.5);

	COLOR = out_col;
}

// Optional: implement light() if you need custom lighting behaviour for CanvasItems

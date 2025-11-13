// Nama file: xray_shader.gdshader
shader_type canvas_item;

// Variabel ini kita kirim dari GDScript
uniform vec2 player_world_pos;

// Anda bisa atur ini di Inspector nanti
uniform float xray_radius : hint_range(0.0, 500.0) = 150.0; // Jarak X-Ray (dalam piksel)
uniform float xray_alpha : hint_range(0.0, 1.0) = 0.3;   // Seberapa transparan
uniform float fade_margin : hint_range(0.0, 100.0) = 40.0; // Seberapa lembut tepinya

// Ini untuk meneruskan info dari vertex() ke fragment()
varying vec2 pixel_world_pos;

void vertex() {
	// Dapatkan posisi dunia dari pixel/vertex ini
	pixel_world_pos = (WORLD_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Ambil warna asli tile (piksel saat ini)
	vec4 current_color = texture(TEXTURE, UV);
	float final_alpha = current_color.a; // Mulai dengan alpha normal

	// Kondisi 1: Apakah piksel ini secara visual "di depan" player?
	// (Posisi Y-nya lebih besar di dunia isometrik)
	if (pixel_world_pos.y > player_world_pos.y) {
		
		// Kondisi 2: Hitung jarak (kita pakai jarak "diamond"
		// agar pas dengan grid isometrik, bukan lingkaran)
		vec2 diff = abs(pixel_world_pos - player_world_pos);
		float iso_dist = diff.x + diff.y; // Ini disebut Manhattan distance
		
		// Hitung seberapa kuat efek X-Ray (0.0 = tidak, 1.0 = penuh)
		// Ini akan fade dari 1.0 (dekat) ke 0.0 (jauh)
		float xray_amount = 1.0 - smoothstep(xray_radius - fade_margin, xray_radius, iso_dist);
		
		// Campur alpha-nya
		// mix(alpha_asli, alpha_target, seberapa_kuat_efeknya)
		final_alpha = mix(current_color.a, xray_alpha, xray_amount);
	}
	
	// Terapkan warna akhir
	COLOR = vec4(current_color.rgb, final_alpha);
}
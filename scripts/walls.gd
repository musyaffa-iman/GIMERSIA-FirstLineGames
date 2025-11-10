# WallTileMap.gd (KODE FINAL - Menggunakan get_cell_tile_data)

extends TileMapLayer

# Variabel yang perlu Anda atur di Inspector (drag node Player ke sini)
@export var player_node: CharacterBody2D
@export var wall_layer_index: int = 0 # Index Layer TileMap yang berisi tembok

# Radius (dalam koordinat sel/ubin) tempat tembok akan menjadi transparan
const XRAY_RADIUS = 3 

# Transparansi target ketika x-ray aktif (misalnya 0.2 untuk 20% alpha)
const XRAY_ALPHA = 0.2

# Dictionary untuk melacak sel-sel yang saat ini transparan dan nilai alpha-nya
var cells_alpha: Dictionary = {}

# PENTING: Fungsi Runtime Update yang sesuai dengan Godot 4.5.1 Anda
func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData):
	# Ambil nilai alpha yang tersimpan, jika tidak ada, default ke 1.0 (penuh)
	var current_alpha = cells_alpha.get(coords, 1.0)
	
	# Terapkan alpha ke modulasi TileData
	tile_data.modulate.a = current_alpha
	
# PENTING: Fungsi Runtime Check yang sesuai dengan Godot 4.5.1 Anda
func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	# Kembalikan true jika sel tersebut ada di Dictionary
	return cells_alpha.has(coords)

func _process(delta):
	if not player_node:
		return

	# 1. Konversi posisi Player ke koordinat ubin (sel)
	var player_coords: Vector2i = local_to_map(player_node.global_position)
	
	# 2. Area yang akan diperiksa (radius sekitar pemain)
	var new_alpha_cells: Dictionary = {}
	
	# Iterasi di sekitar posisi pemain
	for x in range(-XRAY_RADIUS, XRAY_RADIUS + 1):
		for y in range(-XRAY_RADIUS, XRAY_RADIUS + 1):
			var cell_coord = player_coords + Vector2i(x, y)
			
			# Gunakan get_cell_tile_data(layer, coords) untuk memeriksa keberadaan ubin.
			# Jika ini juga error, kita akan kembali ke get_cell_source_id(layer, coords)
			var tile_data = get_cell_tile_data(cell_coord)
			
			# Cek jarak antara cell dan pemain
			if cell_coord.distance_to(player_coords) <= XRAY_RADIUS:
				# Cek apakah tile_data bukan null (artinya ada ubin di koordinat dan layer ini)
				if tile_data != null:
					# Tentukan transparansi target
					new_alpha_cells[cell_coord] = XRAY_ALPHA
				
	# 3. Bandingkan dan Update Logika (Tidak Berubah)
	var changed = false
	var old_coords_to_clear = cells_alpha.keys()
	
	# A. Terapkan transparansi baru / update yang lama
	for coord in new_alpha_cells:
		if cells_alpha.get(coord, 1.0) != new_alpha_cells[coord]:
			cells_alpha[coord] = new_alpha_cells[coord]
			changed = true
		
		if coord in old_coords_to_clear:
			old_coords_to_clear.erase(coord)

	# B. Kembalikan alpha untuk sel yang sudah tidak terpengaruh radius (keluar dari radius)
	for coord in old_coords_to_clear:
		if cells_alpha.get(coord) != 1.0:
			cells_alpha[coord] = 1.0
			changed = true
			
	# C. Panggil update_internals() pada layer yang relevan
	if changed:
		# Jika Anda menggunakan Godot 4.5.1, coba panggil dengan layer index
		update_internals() 
		# Jika error, ganti baris di atas dengan: update_internals()

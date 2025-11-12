extends Node

## Variable Node
@onready var player: CharacterBody2D = $Player
@onready var walls_layer: TileMapLayer = $Walls
@onready var spawnpoints = $Spawnpoint
@onready var times = $GUI/Timer
var zombiescene = preload("res://scenes/enemy/zombie_grunt.tscn")
var magescene = preload("res://scenes/enemy/mage.tscn")
var skeletonscene = preload("res://scenes/enemy/skeleton_enemy.tscn")
var enemylist = []
var time_speed : int = 1
var time_left : int = 60
var keys = false

## Jarak deteksi dalam 'tile'. 
@export var detection_radius: int = 2

## Seberapa transparan dinding saat X-Ray aktif (0.0 = tak terlihat, 1.0 = normal)
@export var xray_alpha: float = 0.3

## Kecepatan fade in/out (dalam detik)
@export var fade_speed: float = 0.25

var is_occluded: bool = false
var active_tween: Tween

func _ready() -> void:
	time_left = 60
	for i in range(spawnpoints.get_child_count()) :
		enemylist.push_front(randi_range(0,2))
	spawnmonster()

func spawnmonster():
	for i in range(spawnpoints.get_child_count() - 1) :
		var spawnpos = spawnpoints.get_child(i)
		var newMonster
		if enemylist[i] == 0 : newMonster = zombiescene.instantiate()
		elif enemylist[i] == 1 : newMonster = skeletonscene.instantiate()
		else : newMonster = magescene.instantiate()
		newMonster.position = spawnpos.get_position()
		add_child(newMonster)

func _process(delta: float) -> void:
	times.set_text(str(time_left))
	if time_left <= 0 :
		time_left = 60
		$Timer.start(1)
		time_speed = 1
		player.reset()
		spawnmonster()
		player.position = $Spawnpoint/PlayerSpawn.get_position()

func _physics_process(delta):
	if not is_instance_valid(player) or not is_instance_valid(walls_layer):
		print("Player atau Walls_Layer belum di-assign di Inspector!")
		return
	var new_occlusion_state = check_player_occlusion()
	if new_occlusion_state != is_occluded:
		is_occluded = new_occlusion_state
		update_wall_alpha()

func check_player_occlusion() -> bool:
	var player_pos = player.global_position
	var player_map_pos = walls_layer.local_to_map(player_pos)
	for y in range(-detection_radius, detection_radius + 1):
		for x in range(-detection_radius, detection_radius + 1):
			var cell_to_check = player_map_pos + Vector2i(x, y)
			if walls_layer.get_cell_source_id(cell_to_check) == -1:
				continue
			var cell_world_pos = walls_layer.map_to_local(cell_to_check) + Vector2(walls_layer.tile_set.tile_size / 2)
			if cell_world_pos.y > player_pos.y and \
			   abs(cell_world_pos.x - player_pos.x) < (walls_layer.tile_set.tile_size.x * 1.5):
				return true
	return false

# Fungsi untuk menjalankan animasi fade (Tween)
func update_wall_alpha():
	var target_alpha = 1.0 # Normal
	if is_occluded:
		target_alpha = xray_alpha # Transparan
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	# Buat tween baru untuk fade alpha
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE) # Transisi yang mulus
	active_tween.tween_property(walls_layer, "modulate:a", target_alpha, fade_speed)


func _on_next_level_body_entered(body: Node2D) -> void:
	if body.name == "Player" :
		get_tree().change_scene_to_packed(load("res://scenes/Level/Level1.tscn"))

func _on_timer_timeout() -> void:
	time_left -= time_speed

func _on_speed_up_body_entered(body: Node2D) -> void:
	if body.name == "Player" :
		time_speed = 3
		$Timer.start(0.1)

func _on_speed_up_body_exited(body: Node2D) -> void:
	if body.name == "Player" :
		time_speed = 1

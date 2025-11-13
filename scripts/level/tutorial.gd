extends Node

## Variable Node
@onready var player: CharacterBody2D = $Player
@onready var walls_layer: TileMapLayer = $Walls
@onready var spawnpoints = $Spawnpoint
@onready var times = $GUI/Timer
@onready var bgm_normal: AudioStreamPlayer = $bgmNormal
@onready var bgm_low: AudioStreamPlayer = $bgmLowHealth
var zombiescene = preload("res://scenes/enemy/zombie_grunt.tscn")
var magescene = preload("res://scenes/enemy/mage.tscn")
var skeletonscene = preload("res://scenes/enemy/skeleton_enemy.tscn")
var level1scene = preload("res://scenes/Level/Level1.tscn")
var enemylist = []
var enemypool = []
var time_speed : int = 1
var time_left : int = 60
var KEYA = false

## Jarak deteksi dalam 'tile'. 
@export var detection_radius: int = 2

## Seberapa transparan dinding saat X-Ray aktif (0.0 = tak terlihat, 1.0 = normal)
@export var xray_alpha: float = 0.3

## Kecepatan fade in/out (dalam detik)
@export var fade_speed: float = 0.25

var is_occluded: bool = false
var active_tween: Tween
var _low_health_active: bool = false
@export var low_health_threshold_percent: float = 0.30
var _ambient_tween: Tween

func _ready() -> void:
	time_left = 60
	for i in range(spawnpoints.get_child_count()) :
		enemylist.push_front(randi_range(0,2))
	spawnmonster()

	# Ambient music setup: ensure both streams are playing so we can cross-fade
	if is_instance_valid(bgm_normal):
		bgm_normal.volume_db = 0.0
		bgm_normal.play()
	if is_instance_valid(bgm_low):
		# start muted
		bgm_low.volume_db = -80.0
		bgm_low.play()

func spawnmonster():
	for i in range(spawnpoints.get_child_count() - 1) :
		var spawnpos = spawnpoints.get_child(i)
		var newMonster
		if enemylist[i] == 0 : newMonster = zombiescene.instantiate()
		elif enemylist[i] == 1 : newMonster = skeletonscene.instantiate()
		else : newMonster = magescene.instantiate()
		newMonster.position = spawnpos.get_position()
		enemypool.push_front(newMonster)
		add_child(newMonster)

func _process(delta: float) -> void:
	times.set_text(str(time_left))
	if time_left <= 0 :
		resets()

func updatekeys():
	$GUI.update(0)
	if KEYA :
		$RoomEffect/SpeedUp/Area.visible = false
	elif !KEYA :
		$RoomEffect/SpeedUp/Area.visible = true

func resets():
	time_left = 60
	if player.is_dead : 
		KEYA = false
		player.is_dead = false
	$Timer.start(1)
	time_speed = 1
	player.reset()
	for i in range(enemypool.size()) :
		if enemypool[i] != null :
			enemypool[i].queue_free()
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


func _on_player_health_updated(current: int, max: int) -> void:
	# current and max from Player signal; compute percentage
	if max == 0:
		return
	var perc := float(current) / float(max)
	if perc <= low_health_threshold_percent and not _low_health_active:
		_set_low_health_state(true)
	elif perc > low_health_threshold_percent and _low_health_active:
		_set_low_health_state(false)


func _set_low_health_state(enabled: bool) -> void:
	# Cross-fade: when enabled == true, fade bgm_normal down and bgm_low up
	_low_health_active = enabled
	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.set_trans(Tween.TRANS_SINE)
	_ambient_tween.set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(bgm_normal):
		var target_normal_db = -80.0 if enabled else 0.0
		_ambient_tween.tween_property(bgm_normal, "volume_db", target_normal_db, fade_speed)
	if is_instance_valid(bgm_low):
		var target_low_db = 0.0 if enabled else -80.0
		_ambient_tween.tween_property(bgm_low, "volume_db", target_low_db, fade_speed)


func _on_next_level_body_entered(body: Node2D) -> void:
	if body.name == "Player" :
		var tree = get_tree()
		var cur = get_tree().get_current_scene()
		var next = level1scene.instantiate()
		tree.get_root().remove_child(cur)
		tree.get_root().add_child(next)
		tree.set_current_scene(next)

func _on_timer_timeout() -> void:
	time_left -= time_speed

# Speed up functions are now handled by SpeedUpArea script
# which can be attached to any Area2D node in any level

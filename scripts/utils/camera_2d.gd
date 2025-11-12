extends Camera2D

@onready var tween: Tween

var player: Node2D # Player to follow
var shake_amount: float = 0.0

@export_group("Camera shake")
@export var shake_decay: float = 5.0 # How fast the shake reduces
@export var shake_strength: float = 5.0 # Max shake offset in pixels

@export_group("Camera movement")
@export var move_distance_to_player: float = 2.0 # Minimum distance to player to make camera follow player
@export var follow_speed: float = 0.2  # Camera movement speed to follow player

func _ready():
	# Find player in the scene
	player = get_tree().get_first_node_in_group("player")
	
func _process(delta):
	if player:
		camera_movement()
	if shake_amount > 0:
		# Offset camera to implement camera shake
		offset = Vector2(
			randf_range(-shake_strength, shake_strength) * shake_amount,
			randf_range(-shake_strength, shake_strength) * shake_amount
		)
		# Lower the shake amount
		shake_amount = lerp(shake_amount, 0.0, delta * shake_decay)
	else:
		offset = Vector2.ZERO # Stop camera shake

# Giving shake amount
func start_shake(intensity: float = 1.0):
	shake_amount = intensity

# Camera follow player
func camera_movement():
	var target_position = player.global_position
	# Only start tween if camera is far from target
	if global_position.distance_to(target_position) > move_distance_to_player:
		if tween and tween.is_running():
			return # Let the current tween finish
		tween = get_tree().create_tween()
		tween.tween_property(self, "global_position", target_position, follow_speed)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		print("AAAAAAAAAAAAAAAAAAAAAAAA")

extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var lifetime: float = 5.0  # Arrow disappears after 5 seconds

func _ready():
	# Set collision layers/masks
	collision_layer = 4  # Enemy projectile layer
	collision_mask = 1   # Can hit player layer
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Move the arrow
	position += velocity * delta

func set_velocity(vel: Vector2):
	velocity = vel

func set_damage(dmg: float):
	damage = dmg

func _on_body_entered(body):
	# Only damage the player group
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	# Hit wall/obstacle
	elif body.is_in_group("wall") or body is TileMap:
		queue_free()

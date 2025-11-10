extends Area2D

var velocity: Vector2 = Vector2.ZERO
# base_value carried by projectile (BASE_VALUE)
var base_value: float = 10.0
# attacker's ATK (used for final calculation)
var owner_atk: float = 0.0
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

func set_base_value(dmg: float):
	base_value = dmg

func set_owner_atk(a_atk: float) -> void:
	owner_atk = a_atk

func _on_body_entered(body):
	# Only damage the player group
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			# Compute defender DEF if available. If the target is the player and
			# they don't expose a `defense` property, assume the GDD value (25)
			var def_val: float = 1.0
			var maybe = body.get("defense")
			if maybe != null:
				def_val = float(maybe)
			elif body.is_in_group("player"):
				# player default from GDD
				def_val = 25.0
			var final = DamageCalc.calculate_damage(base_value, owner_atk, def_val)
			body.take_damage(final, (body.global_position - global_position).normalized())
		queue_free()
	# Hit wall/obstacle
	elif body.is_in_group("wall") or body is TileMap:
		queue_free()

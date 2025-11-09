extends Area2D
class_name RotatingShell

@export var angular_speed_deg: float = 180.0
@export var radius: float = 100.0
@export var bounce_multiplier: float = 1.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _process(delta: float) -> void:
	if owner and is_instance_valid(owner):
		global_position = owner.global_position + Vector2(radius, 0).rotated(rotation)
	rotation += deg_to_rad(angular_speed_deg) * delta

func _on_area_entered(area: Area2D) -> void:
	print(area.name, " entered rotating shell")
	# only reflect projectiles (expects projectiles to be in "projectile" group)
	if not area.is_in_group("projectile"):
		return
	
	var incoming = area.velocity

	# compute normal and reflected velocity
	var normal = (area.global_position - global_position).normalized()
	if normal.length() == 0:
		normal = Vector2.RIGHT
	var reflected = incoming - 2.0 * incoming.dot(normal) * normal
	reflected *= bounce_multiplier

	# apply reflected velocity back to the projectile using best-known API
	area.velocity = reflected
	area.rotation = reflected.angle()

	# mark projectile as bounced so game logic can treat it as hostile to enemies
	if area.is_in_group("player_projectile"):
		area.remove_from_group("player_projectile")
	area.add_to_group("bounced_projectile")
	# optionally tag with owner meta so damage logic can check
	if owner:
		area.set_meta("bounced_by", owner)

	# small visual or audio feedback could be triggered here (left minimal)

func start_lifetime_timer(duration: float=3.0) -> void:
	# detach lifetime waiter to avoid blocking ready
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		queue_free()

extends Area2D
class_name RotatingShell

@export var duration: float = 5.0
@export var angular_speed_deg: float = 180.0
@export var radius: float = 100.0
@export var bounce_multiplier: float = 1.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	monitoring = true
	monitorable = true
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	# configure circle shape radius if present
	if collision_shape and collision_shape.shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius
	# default owner to parent if not set
	if owner == null:
		owner = get_parent()

func _process(delta: float) -> void:
	if owner and is_instance_valid(owner):
		global_position = owner.global_position + Vector2(radius, 0).rotated(rotation)
	rotation += deg_to_rad(angular_speed_deg) * delta
	if sprite:
		sprite.rotation = rotation

func _on_body_entered(body: Node) -> void:
	if not body:
		return
	# only reflect projectiles (expects projectiles to be in "projectile" group)
	if not body.is_in_group("projectile"):
		return

	# determine incoming velocity (try common properties / APIs)
	var incoming :Vector2 = Vector2.ZERO
	if body is RigidBody2D:
		incoming = body.linear_velocity
	elif body.has_method("get_velocity"):
		incoming = body.get_velocity()
	else:
		# fallback attempts
		if body.has_meta("velocity"):
			incoming = body.get_meta("velocity")
		else:
			# try direct property access; will be null if not present
			if "velocity" in body:
				incoming = body.velocity

	if incoming == null:
		# can't reflect if we don't know velocity; as a fallback try to invert direction away from shell
		var fallback_dir = (body.global_position - global_position).normalized()
		if fallback_dir.length() == 0:
			fallback_dir = Vector2.RIGHT
		incoming = fallback_dir * 200.0

	# compute normal and reflected velocity
	var normal = (body.global_position - global_position).normalized()
	if normal.length() == 0:
		normal = Vector2.RIGHT
	var reflected = incoming - 2.0 * incoming.dot(normal) * normal
	reflected *= bounce_multiplier

	# apply reflected velocity back to the projectile using best-known API
	if body is RigidBody2D:
		body.linear_velocity = reflected
	elif body.has_method("set_velocity"):
		body.set_velocity(reflected)
	elif body.has_method("set_linear_velocity"):
		body.set_linear_velocity(reflected)
	else:
		# last-resort: try setting common property names
		if "velocity" in body:
			body.velocity = reflected
		else:
			body.set("velocity", reflected) # may work for many custom projectiles

	# mark projectile as bounced so game logic can treat it as hostile to enemies
	if body.is_in_group("player_projectile"):
		body.remove_from_group("player_projectile")
	body.add_to_group("bounced_projectile")
	# optionally tag with owner meta so damage logic can check
	if owner:
		body.set_meta("bounced_by", owner)

	# small visual or audio feedback could be triggered here (left minimal)

func start_lifetime_timer(duration: float=3.0) -> void:
	# detach lifetime waiter to avoid blocking ready
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		queue_free()

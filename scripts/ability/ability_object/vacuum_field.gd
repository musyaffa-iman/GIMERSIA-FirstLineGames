extends Area2D
class_name VacuumField

@export var projectile_speed: float = 600.0
@export var projectile_max_distance: float = 800.0

@export var active_radius: float = 200.0
@export var pull_strength: float = 800.0         # target velocity magnitude applied to enemies
@export var active_duration: float = 4.0

# small damp so pulled enemies don't snap instantly
@export var pull_damping: float = 400.0

# runtime
var _velocity: Vector2 = Vector2.ZERO
var _distance_travelled: float = 0.0
var _is_active: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	# belong to projectile groups so other systems can identify it
	if not is_in_group("projectile"):
		add_to_group("projectile")
	if not is_in_group("player_projectile"):
		add_to_group("player_projectile")

func launch(start_pos: Vector2, direction: Vector2, speed: float = -1.0, max_distance: float = -1.0, _owner: Node = null) -> void:
	global_position = start_pos
	owner = _owner
	_velocity = direction.normalized() * (speed if speed > 0 else projectile_speed)
	_distance_travelled = 0.0
	_is_active = false
	if max_distance > 0:
		projectile_max_distance = max_distance
	# ensure visible
	visible = true

func _physics_process(delta: float) -> void:
	if not _is_active:
		# fly forward
		var move = _velocity * delta
		global_position += move
		_distance_travelled += move.length()
		# simple activation condition: reached max distance
		if _distance_travelled >= projectile_max_distance:
			_activate()
		# optional: activate early when near an enemy
		else:
			_check_early_activation()
	else:
		# pull enemies toward center
		_apply_pull_to_enemies(delta)

func _check_early_activation() -> void:
	# if any enemy is within a short trigger distance, activate immediately
	var trigger_dist : float = 24.0 + collision_shape.shape.radius
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= trigger_dist:
			_activate()
			return

func _activate() -> void:
	if _is_active:
		return
	_is_active = true
	_velocity = Vector2.ZERO
	# become an active area that pulls enemies
	monitoring = true
	monitorable = true
	# expand collision shape to active radius if present
	if collision_shape and collision_shape.shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = active_radius
	# change groups: no longer a projectile
	if is_in_group("player_projectile"):
		remove_from_group("player_projectile")
	# optionally mark as a field
	if not is_in_group("vacuum_field"):
		add_to_group("vacuum_field")

func _apply_pull_to_enemies(delta: float) -> void:
	if active_radius <= 0:
		return
	# pull each enemy toward the field center
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var to_center = (global_position - enemy.global_position)
		var dist = to_center.length()
		if dist <= active_radius:
			var dir = to_center.normalized()
			enemy.global_position += dir * (pull_strength * delta * 0.25)

func start_lifetime_timer(duration: float=3.0) -> void:
	# keep the field active for active_duration, then free
	await get_tree().create_timer(active_duration).timeout
	if is_instance_valid(self):
		queue_free()

func set_active_radius(r: float) -> void:
	active_radius = r
	if collision_shape and collision_shape.shape and collision_shape.shape is CircleShape2D and _is_active:
		collision_shape.shape.radius = active_radius

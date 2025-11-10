extends CharacterBody2D

# Eye of Aberration - Beholder's Phase 3 transformation
# Large homing sphere that explodes on contact

@export var base_value: float = 65.0
@export var owner_atk: float = 38.0
@export var move_speed: float = 150.0
@export var explosion_radius: float = 100.0
@export var lifetime: float = 10.0

var owner_enemy: Node = null
var target: Node = null
var time_alive: float = 0.0
var exploded: bool = false

func _ready() -> void:
	# Set collision layers
	collision_layer = 2   # Enemy layer
	collision_mask = 1    # Player layer
	
	# Connect hitbox signals if available
	if has_node("Hitbox"):
		var hitbox = $Hitbox
		if hitbox and hitbox.has_signal("body_entered"):
			if not hitbox.is_connected("body_entered", Callable(self, "_on_hitbox_body_entered")):
				hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	
	# Find player for targeting
	target = get_tree().get_first_node_in_group("player")
	
	print("Eye of Aberration spawned at ", global_position)

func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime or exploded:
		queue_free()
		return
	
	# Move toward player
	if target and is_instance_valid(target):
		var to_target = target.global_position - global_position
		var direction = to_target.normalized()
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func set_base_value(val: float) -> void:
	base_value = val

func set_owner_atk(atk: float) -> void:
	owner_atk = atk

func set_speed(spd: float) -> void:
	move_speed = spd

func _on_hitbox_body_entered(body: Node) -> void:
	if not body or body == owner_enemy or exploded:
		return
	
	if body.has_method("take_damage") and body.is_in_group("player"):
		explode_on_contact()

func explode_on_contact() -> void:
	"""Explode on contact with target, dealing damage in radius"""
	if exploded:
		return
	exploded = true
	
	print("Eye of Aberration exploding at ", global_position)
	
	await get_tree().create_timer(1.0).timeout
	# Spawn visual effect if available
	var explosion_scene = load("res://Scenes/attacks/explosion.tscn")
	if explosion_scene:
		var explosion_vfx = explosion_scene.instantiate()
		get_parent().add_child(explosion_vfx)
		explosion_vfx.global_position = global_position
		if explosion_vfx.has_node("explosionParticle"):
			var particles = explosion_vfx.get_node("explosionParticle")
			particles.emitting = true
	
	# Use shape query to find all bodies in explosion radius
	var space = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	
	var params = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0, global_position)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [self]
	
	var results = space.intersect_shape(params)
	for r in results:
		var collider = null
		if typeof(r) == TYPE_DICTIONARY and r.has("collider"):
			collider = r["collider"]
		elif typeof(r) == TYPE_OBJECT:
			collider = r
		
		if collider and collider.has_method("take_damage"):
			# Direction from explosion center to target
			var dir = (collider.global_position - global_position)
			var ndir = dir.normalized() if dir.length() > 0 else Vector2.ZERO
			
			# Compute defender DEF
			var def_val: float = 25.0
			if collider.get("defense") != null:
				def_val = float(collider.get("defense"))
			
			# Calculate damage
			var final_damage = DamageCalc.calculate_damage(int(base_value), int(owner_atk), def_val)
			
			# Apply damage and knockback
			collider.take_damage(final_damage, ndir, 300.0)
			print("Eye of Aberration explosion hit ", collider.name, " for ", final_damage, " damage!")
	
	# Remove self
	queue_free()

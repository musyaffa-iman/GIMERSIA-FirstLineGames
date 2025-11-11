extends Enemy

# Spider Bomb: rushes the player and explodes on proximity or on death.
# Data from GDD (Level 1): HP=1, ATK=40, DEF=1, Explosion BASE_VALUE=60

@export var detection_range: float = 300.0

@export var explode_distance_m: float = 1.0 # meters
@export var pixels_per_meter: float = 48.0 # conversion used elsewhere in repo (0.75m ->36px)

@export var explosion_radius_px: float = 48.0 # default 1m radius
@export var explosion_damage: int = 60 # BASE_VALUE for Explosion (GDD)
@export var explosion_knockback: float = 200.0
@export var explosion_scene: PackedScene = null

@export var atk: int = 40
@export var defense: int = 1

@export var debug_logs: bool = false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var exploded: bool = false

 

func _ready() -> void:
	# Apply GDD HP before base setup so Enemy._ready() uses the correct health
	max_health = 1
	# let base class init player lookup and health
	super._ready()
	add_to_group("enemy")

func enemy_behavior(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	var to_player = player.global_position - global_position
	var dist = to_player.length()

	# If player is far, idle
	if dist > detection_range:
		velocity = Vector2.ZERO
		return

	# Move toward player
	var dir = to_player.normalized()
	velocity = dir * move_speed

	# If within explode distance, detonate
	var explode_px = explode_distance_m * pixels_per_meter
	if dist <= explode_px and not exploded:
		if debug_logs:
			print("SpiderBomb: in range to explode (dist=", dist, ")")
		explode()

func explode() -> void:
	if exploded:
		return
	exploded = true
	set_physics_process(false)  # stop movement
	if debug_logs:
		print("SpiderBomb: exploding at", global_position)

	animated_sprite_2d.play("telegraph_1")
	await get_tree().create_timer(0.5).timeout  # brief delay before explosion
	animated_sprite_2d.play("telegraph_2")
	await get_tree().create_timer(0.5).timeout  # brief delay before explosion
	# Spawn visual explosion effect with particles
	if not explosion_scene:
		var _e = load("res://Scenes/attacks/explosion.tscn")
		if _e and _e is PackedScene:
			explosion_scene = _e
	
	if explosion_scene:
		var explosion_vfx = explosion_scene.instantiate()
		get_parent().add_child(explosion_vfx)
		explosion_vfx.global_position = global_position
		# Enable particles if available
		if explosion_vfx.has_node("explosionParticle"):
			var particles = explosion_vfx.get_node("explosionParticle")
			particles.emitting = true
		if debug_logs:
			print("SpiderBomb: spawned explosion VFX")

	# Use a shape query to find nearby bodies and apply damage/knockback
	var space = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius_px

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
			# direction from explosion center to target
			var dir = (collider.global_position - global_position)
			var ndir = dir.normalized() if dir.length() > 0 else Vector2.ZERO

			# compute defender DEF. Use player default if missing.
			var def_val: float = 1.0
			var maybe = collider.get("defense")
			if maybe != null:
				def_val = float(maybe)
			elif collider.is_in_group("player"):
				def_val = 25.0

			# attacker ATK (this spider)
			var owner_atk = float(atk)
			# Use DamageCalc (class_name) to compute final damage per target
			var final = DamageCalc.calculate_damage(explosion_damage, owner_atk, def_val)

			# call take_damage on the player/other bodies
			collider.take_damage(final, ndir, explosion_knockback)

	# Optionally spawn a short-lived visual effect here (left to scene)

	# Remove self after explosion
	queue_free()

func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0) -> void:
	# If this damage will kill the spider, explode first so player is affected
	var will_die = (health - amount) <= 0
	if will_die and not exploded:
		if debug_logs:
			print("SpiderBomb: killed — exploding before death")
		explode()

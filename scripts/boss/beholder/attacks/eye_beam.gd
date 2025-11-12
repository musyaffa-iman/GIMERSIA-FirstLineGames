extends RayCast2D

# Eye Beam laser for Beholder (Phase 2+)
# Extends from Beholder across the map, tracking player movement

@export var cast_speed: float = 2000.0  # Pixels/second that laser extends
@export var max_length: float = 1200.0  # Maximum laser length
@export var start_distance: float = 40.0  # Distance from origin to start
@export var growth_time: float = 0.15  # Time to reach full width
@export var base_value: float = 60.0
@export var owner_atk: float = 38.0
@export var is_casting: bool = false

var line_2d: Line2D = null
var owner_enemy: Node = null
var target_player: Node = null
var tween: Tween = null
var line_width: float = 4.0
var active_time: float = 0.0
var lifetime: float = 3.0

func _ready() -> void:
	# Create Line2D for visual representation
	line_2d = Line2D.new()
	add_child(line_2d)
	
	# Setup line
	line_2d.width = line_width
	line_2d.modulate = Color(0.8, 0.2, 1, 1)  # Purple for eye beam
	line_2d.add_point(Vector2.ZERO)
	line_2d.add_point(Vector2.ZERO)
	
	# Setup raycast
	collision_mask = 1  # Player layer
	enabled = true
	
	# Find player for tracking
	target_player = get_tree().get_first_node_in_group("player")
	
	# Start laser
	start_laser()
	
	print("Eye Beam (laser) spawned at ", global_position)

func _physics_process(delta: float) -> void:
	active_time += delta
	
	if active_time >= lifetime:
		stop_laser()
		queue_free()
		return
	
	# Update laser rotation to track player with slight inaccuracy
	if target_player and is_instance_valid(target_player):
		var to_player = target_player.global_position - global_position
		var target_angle = to_player.angle()
		
		# Add wobble/inaccuracy by using sine wave offset
		var wobble = sin(active_time * 4.0) * 0.4  # ±23 degrees wobble
		rotation = target_angle + wobble
	
	# Extend laser
	if is_casting:
		target_position.x = move_toward(
			target_position.x,
			max_length,
			cast_speed * delta
		)
		
		# Update laser visuals
		var laser_end = target_position
		force_raycast_update()
		
		# Check if laser hits anything - continuous damage (no hit tracking)
		if is_colliding():
			laser_end = to_local(get_collision_point())
			
			var collider = get_collider()
			if collider:
				hit_target(collider, laser_end)
		
		# Draw laser line
		if line_2d:
			line_2d.points[1] = laser_end

func start_laser() -> void:
	"""Start the laser beam"""
	is_casting = true
	set_physics_process(true)
	
	var laser_start = Vector2.RIGHT * start_distance
	if line_2d:
		line_2d.points[0] = laser_start
		line_2d.points[1] = laser_start
		line_2d.visible = true
		
		# Animate width appearing
		if tween and tween.is_running():
			tween.kill()
		tween = create_tween()
		tween.tween_property(line_2d, "width", line_width, growth_time)

func stop_laser() -> void:
	"""Stop the laser beam"""
	is_casting = false
	set_physics_process(false)
	
	if line_2d:
		if tween and tween.is_running():
			tween.kill()
		tween = create_tween()
		tween.tween_property(line_2d, "width", 0.0, growth_time * 0.5)
		tween.tween_callback(line_2d.hide)

func hit_target(target: Node, hit_position: Vector2) -> void:
	"""Apply continuous damage to a target hit by the laser"""
	if not target or target == owner_enemy:
		return
	
	# Check if it's the player or player-owned
	var actual_target = target
	if not target.is_in_group("player"):
		if target.get_parent() and target.get_parent().is_in_group("player"):
			actual_target = target.get_parent()
		else:
			return
	
	if actual_target.has_method("take_damage"):
		# Compute defender DEF
		var def_val: float = 25.0
		if actual_target.get("defense") != null:
			def_val = float(actual_target.get("defense"))
		
		# Calculate damage using DamageCalc
		var final_damage = DamageCalc.calculate_damage(int(base_value), int(owner_atk), def_val)
		
		# Apply knockback in laser direction
		var knockback_dir = Vector2.RIGHT.rotated(rotation)
		actual_target.take_damage(final_damage, knockback_dir, 200.0)
		print("Eye Beam hit ", actual_target.name, " for ", final_damage, " damage!")

func set_base_value(val: float) -> void:
	base_value = val

func set_owner_atk(atk: float) -> void:
	owner_atk = atk

func set_owner_enemy(owner_node: Node) -> void:
	owner_enemy = owner_node




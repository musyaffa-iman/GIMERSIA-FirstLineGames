extends CharacterBody2D

# Enemy Stats
@export var max_health: float = 100.0
@export var attack_damage: float = 10.0
@export var defense: float = 5.0

# Shooting parameters
@export var arrow_speed: float = 300.0
@export var detection_range: float = 500.0
@export var arrow_rotation_offset_degrees: float = 0.0 # Set to -90 if your arrow texture points up
@export var rotate_to_player: bool = false # If true, rotate the skeleton to face the player

# Movement parameters
@export var move_speed: float = 120.0
@export var preferred_range_min: float = 200.0
@export var preferred_range_max: float = 320.0
@export var debug_logs: bool = false
@export var arrow_spawn_distance: float = 24.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.1
@export var dash_cooldown: float = 5.0

# Optional features
@export var use_los_check: bool = false # If true, only shoot when there's direct line-of-sight to player
@export var invulnerable_during_dash: bool = true

# Runtime invulnerability flag
var invulnerable: bool = false

# Dash state
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

# Drag and drop the player here in the Inspector! (optional)
@export var player: CharacterBody2D = null

# State machine variables
var current_health: float
var can_shoot: bool = true
var arrows_shot: int = 0
var is_resting: bool = false

# Timers
var shoot_timer: float = 0.0
var rest_timer: float = 0.0

const SHOOT_INTERVAL = 0.2  # Time between arrows
const REST_DURATION = 2.0   # Rest time after shooting 2 arrows
const MAX_ARROWS = 2        # Number of arrows per burst

# Arrow scene
@export var arrow_scene: PackedScene = preload("res://Scenes/arrow.tscn")

func _ready():
	current_health = max_health
	# Try to find player
	call_deferred("find_player")

	# Auto-connect hitbox signal if present
	if has_node("hitbox"):
		var hb = get_node("hitbox")
		if hb and hb.has_signal("area_entered"):
			hb.area_entered.connect(_on_hitbox_area_entered)

func find_player():
	if player and is_instance_valid(player):
		return
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		for candidate_name in ["Player", "player"]:
			var found = current_scene.find_child(candidate_name, true, false)
			if found:
				player = found
				return
	var group_nodes = get_tree().get_nodes_in_group("player")
	if group_nodes.size() > 0:
		player = group_nodes[0]

func _physics_process(delta):
	if not player:
		find_player()
		if debug_logs:
			print("Skeleton: Looking for player...")
		return
	
	# Check if player is in range
	var distance_to_player = global_position.distance_to(player.global_position)
	if debug_logs:
		print("Distance to player: ", distance_to_player)
	
	# Basic chase/kite movement to maintain a preferred range, but only when the
	# player is inside detection_range. Outside detection_range the skeleton idles.
	var move_dir := Vector2.ZERO
	if distance_to_player <= detection_range:
		var dir_to_player: Vector2 = (player.global_position - global_position).normalized()
		# Approach when too far, back off when too close
		if distance_to_player > preferred_range_max:
			move_dir = dir_to_player # approach
		elif distance_to_player < preferred_range_min:
			move_dir = -dir_to_player # back off
		else:
			move_dir = Vector2.ZERO

	# Handle dash cooldown timer
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

	# If currently dashing, override movement with dash velocity
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			# end invulnerability when dash ends
			if invulnerable_during_dash:
				invulnerable = false
			# stop dash; allow normal AI movement next frame
			velocity = Vector2.ZERO
		else:
			# during dash, continue moving along velocity set when dash started
			move_and_slide()
			return

	# Apply movement when not dashing
	velocity = move_dir * move_speed
	move_and_slide()

	# Only handle facing and shooting when within detection range
	if distance_to_player <= detection_range:
		# Optionally face the player (disabled by default to avoid upside-down visuals)
		if rotate_to_player:
			look_at(player.global_position)
		
		# If player is too close, attempt a dash back (only if not already dashing and cooldown is ready)
		if not is_dashing and dash_cooldown_timer <= 0.0 and distance_to_player < preferred_range_min:
			# start dash away from player
			is_dashing = true
			# start invulnerability window if enabled
			if invulnerable_during_dash:
				invulnerable = true
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown
			var away_dir = (global_position - player.global_position).normalized()
			velocity = away_dir * dash_speed
			if debug_logs:
				print("Skeleton: dashing away")
			move_and_slide()
			return
		
		# Handle shooting state machine
		if is_resting:
			rest_timer += delta
			if rest_timer >= REST_DURATION:
				# Done resting, ready to shoot again
				is_resting = false
				arrows_shot = 0
				rest_timer = 0.0
				can_shoot = true
		else:
			if can_shoot and arrows_shot < MAX_ARROWS:
				# Line-of-sight check (optional)
				var can_fire := true
				if use_los_check and player:
					can_fire = has_line_of_sight_to_player()
				if can_fire:
					shoot_arrow()
				can_shoot = false
				shoot_timer = 0.0
				arrows_shot += 1
			elif not can_shoot:
				shoot_timer += delta
				if shoot_timer >= SHOOT_INTERVAL:
					if arrows_shot < MAX_ARROWS:
						can_shoot = true
					else:
						# Shot 2 arrows, start resting
						is_resting = true
						rest_timer = 0.0

func shoot_arrow():
	if not arrow_scene or not player:
		return
	
	# Create arrow instance
	var arrow = arrow_scene.instantiate()
	
	# Add arrow to the scene tree (parent to the level/world)
	get_parent().add_child(arrow)
	
	# Set arrow position and direction
	var direction = (player.global_position - global_position).normalized()
	arrow.global_position = global_position + direction * arrow_spawn_distance
	arrow.rotation = direction.angle() + deg_to_rad(arrow_rotation_offset_degrees)
	
	# Set arrow velocity
	if arrow.has_method("set_velocity"):
		arrow.set_velocity(direction * arrow_speed)
	else:
		arrow.set("velocity", direction * arrow_speed)
	
	# Set arrow damage
	if arrow.has_method("set_damage"):
		arrow.set_damage(attack_damage)
	else:
		arrow.set("damage", attack_damage)

	if debug_logs:
		print("Skeleton: shot arrow at ", player.global_position, " from ", arrow.global_position)

func has_line_of_sight_to_player() -> bool:
	# Raycast from skeleton to player to detect walls/obstacles.
	if not player:
		return false
	var space := get_world_2d().direct_space_state
	var from_pos := global_position
	var to_pos := player.global_position
	var exclude := [self]
	var params = PhysicsRayQueryParameters2D.new()
	params.from = from_pos
	params.to = to_pos
	params.exclude = [self]
	params.collide_with_bodies = true
	params.collide_with_areas = true
	# Leave collision_mask default so walls and bodies are detected
	var res = space.intersect_ray(params)
	# If nothing hit, line is clear. If collider is the player, also clear.
	if not res or res.empty():
		return true
	var collider = res.get("collider")
	if collider == player:
		return true
	return false

func take_damage(damage: float):
	var actual_damage = max(damage - defense, 0)
	current_health -= actual_damage
	
	# Visual feedback (optional)
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func die():
	# Play death animation/effects here
	queue_free()

func _on_hitbox_area_entered(area):
	# Handle collision with player attack
	# Ignore damage while invulnerable (e.g., during dash)
	if invulnerable:
		if debug_logs:
			print("Skeleton: ignored hit due to invulnerability")
		return
	if area.is_in_group("player_attack"):
		var damage = 10.0
		if area.has_method("get_damage"):
			damage = area.get_damage()
		else:
			var maybe = area.get("damage")
			if typeof(maybe) != TYPE_NIL:
				damage = maybe
		take_damage(damage)

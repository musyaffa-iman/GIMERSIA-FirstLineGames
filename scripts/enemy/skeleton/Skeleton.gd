extends Enemy

# Shooting parameters
@export var arrow_speed: float = 300.0
@export var detection_range: float = 500.0
@export var arrow_rotation_offset_degrees: float = 0.0 # Set to -90 if your arrow texture points up
@export var rotate_to_player: bool = false # If true, rotate the skeleton to face the player

# GDD Stats
@export var atk: int = 32
@export var defense: int = 20

# Movement parameters
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

# Dash state
var is_dashing: bool = false
var dash_ready: bool = true
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer

# State machine variables
var can_shoot: bool = true
var arrows_shot: int = 0
var is_resting: bool = false

# Timers
@onready var shoot_timer: Timer = $ShootTimer
@onready var rest_timer: Timer = $RestTimer

const SHOOT_INTERVAL = 0.2  # Time between arrows
const REST_DURATION = 2.0   # Rest time after shooting 2 arrows
const MAX_ARROWS = 2        # Number of arrows per burst

# Arrow scene
@export var arrow_scene: PackedScene = preload("res://scenes/arrow.tscn")

func _ready():
	# Set GDD stats before calling super._ready()
	max_health = 18  # GDD: Skeleton HP = 18
	damage = 40      # GDD: BASE_VALUE = 40
	super._ready()
	
func enemy_behavior(delta: float) -> void:
	# Check if player is in range
	var distance_to_player = global_position.distance_to(player.global_position)
	if debug_logs:
		print("Distance to player: ", distance_to_player)
	
	# Don't move towards or away from player; only dash away when too close
	var move_dir := Vector2.ZERO
	if distance_to_player <= detection_range:
		# Idle (don't approach or back away)
		move_dir = Vector2.ZERO

	# Apply movement when not dashing
	velocity = move_dir * move_speed

	# Handle dash behavior (only dashes when player gets close)
	dash_behavior(delta)
	# Handle shooting behavior
	shoot_behavior(delta)

	move_and_slide()

func dash_behavior(delta: float) -> void:
	var distance_to_player = global_position.distance_to(player.global_position)
	if not is_dashing and dash_ready and distance_to_player < preferred_range_min:
		# start dash away from player: configure and start timers instead of assigning floats
		if dash_timer:
			dash_timer.wait_time = dash_duration
			dash_timer.start()
		if dash_cooldown_timer:
			dash_cooldown_timer.wait_time = dash_cooldown
			dash_cooldown_timer.start()
		dash_ready = false
		is_dashing = true

	if not is_dashing:
		if invulnerable_during_dash:
			invulnerable = false
		return

	# Only handle facing and shooting when within detection range
	if distance_to_player <= detection_range:
		# Optionally face the player (disabled by default to avoid upside-down visuals)
		if rotate_to_player:
			look_at(player.global_position)
		
		# start invulnerability window if enabled
		if invulnerable_during_dash:
			invulnerable = true
		var away_dir = (global_position - player.global_position).normalized()
		velocity = away_dir * dash_speed
		if debug_logs:
			print("Skeleton: dashing away")
		return

func shoot_behavior(delta: float) -> void:
	# Handle shooting state machine
	if not is_resting:
		if can_shoot and arrows_shot < MAX_ARROWS:
			# Line-of-sight check (optional)
			var can_fire := true
			if use_los_check and player:
				can_fire = has_line_of_sight_to_player()
			if can_fire:
				shoot_arrow()
				can_shoot = false
				shoot_timer.wait_time = SHOOT_INTERVAL
				shoot_timer.start()
				arrows_shot += 1

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
	arrow.velocity = direction * arrow_speed
	
	# Set arrow damage values for DamageCalc formula
	if arrow.has_method("set_base_value"):
		arrow.set_base_value(float(damage))  # damage = BASE_VALUE = 40
	if arrow.has_method("set_owner_atk"):
		arrow.set_owner_atk(float(atk))      # atk = 32

	if debug_logs:
		print("Skeleton: shot arrow at ", player.global_position, " from ", arrow.global_position)

func has_line_of_sight_to_player() -> bool:
	# Raycast from skeleton to player to detect walls/obstacles.
	if not player:
		return false
	var space := get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.new()
	params.from = global_position
	params.to = player.global_position
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

func _on_dash_timer_timeout() -> void:
	is_dashing = false

func _on_dash_cooldown_timer_timeout() -> void:
	dash_ready = true

func _on_shoot_timer_timeout() -> void:
	if arrows_shot < MAX_ARROWS:
		can_shoot = true
	else:
		# Shot all arrows, start resting
		is_resting = true
		rest_timer.wait_time = REST_DURATION
		rest_timer.start()

func _on_rest_timer_timeout() -> void:
	is_resting = false
	arrows_shot = 0
	can_shoot = true

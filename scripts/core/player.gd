class_name Player
extends CharacterBody2D

# CONSTANTS
const ACCELERATION = 50.0
const DASH_SPEED := 10000.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 1.2
const MELEE_DAMAGE := 1
const KNOCKBACK_FORCE := 300.0
const SNORE_COOLDOWN := 4.0

# EXPORTS
@export_group("Properties")
@export var max_health: int = 25
@export var speed := 200.0
@export var melee_damage := 35
@export var melee_knockback_force: float = 1000.0
@export_group("Run State")
@export var run_threshold_time: float = 5.0         # seconds of continuous movement required
@export var run_speed_multiplier: float = 1.5
@export var run_damage_multiplier: float = 1.5
@export_category("Abilities")
@export var abilities: Array[BaseAbility] = []  # Drag & drop abilities in Inspector
@export var ability_keys := ["ability_1", "ability_2"] # Input names for abilities
@export var mirror_clone_scene: PackedScene

signal update_health(current_health, max_health)

@onready var invulnerability_timer: Timer = $InvulnerabilityTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fire_animation: AnimatedSprite2D = $FireAnimation
@onready var run_timer: Timer = $RunTimer
@onready var sfx_hit: AudioStreamPlayer2D = $hit
@onready var sfx_snore1: AudioStreamPlayer2D = $snore1
@onready var sfx_walk: AudioStreamPlayer2D = $walk

# PLAYER STATE
var current_health: int
var can_take_damage: bool = true
var is_hurt: bool = false
var is_dashing: bool = false
var is_dead: bool = false

# TIMERS
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var snore_cooldown_timer := 0.0

var input : Vector2
var facing_direction : Vector2 = Vector2.RIGHT

var is_running: bool = false
var _base_speed: float
var _base_melee_damage: int

func _ready():
	current_health = max_health
	update_health.emit(current_health, max_health)

	_base_speed = speed
	_base_melee_damage = melee_damage
	run_timer.wait_time = run_threshold_time

	# (Note) We play the hit SFX just before pausing the tree in take_damage()


func _process(delta):
	if is_dead:
		return
		
	handle_input()
	handle_dash_logic(delta)
	handle_movement_and_animation()
	update_timers(delta)
	check_enemy_collision()

	handle_ability_input()

	update_run_state(delta)

func handle_input():
	input = get_movement_input()
	facing_direction = input if input != Vector2.ZERO else facing_direction
	# Note: flip handled by animation-selection logic to support 6-direction mirroring

func get_movement_input() -> Vector2:
	if is_hurt or is_dead:
		return Vector2.ZERO

	var movement_input = Vector2()
	movement_input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	movement_input.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		
	return movement_input.normalized()

func handle_dash_logic(delta):
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

	if Input.is_action_just_pressed("dash") and can_dash():
		start_dash()


func can_dash() -> bool:
	return not is_dashing and dash_cooldown_timer <= 0.0 and input != Vector2.ZERO and not is_dead

func handle_movement_and_animation():
	# Animation logic (select 8-direction animation based on facing_direction)
	if not is_hurt and not is_dead:
		var moving = input != Vector2.ZERO
		var anim_name = _get_direction_anim_name(facing_direction, moving)
		play_animation_if_not_playing(anim_name)

	# Walk SFX: start/stop depending on movement and states
	if sfx_walk:
		if input != Vector2.ZERO and not is_dashing and not is_hurt and not is_dead:
			if not sfx_walk.playing:
				sfx_walk.play()
		else:
			if sfx_walk.playing:
				sfx_walk.stop()

	if is_dashing:
		velocity = input * DASH_SPEED
	else:
		velocity = input * speed

	move_and_slide()


func _get_direction_anim_name(dir: Vector2, moving: bool) -> String:
	# Mapping according to user's specification (no mirroring):
	# 1. up = north
	# 2. down = south
	# 3. down+right = southEast
	# 4. down+left = southWest
	# 5. up+right = northEast
	# 6. up+left = northWest
	# 7. right = southEast
	# 8. left = southWest
	# Idle names use the same base with an "idle" prefix (e.g. idleNorthEast)

	var eps := 0.01
	if dir == Vector2.ZERO:
		dir = facing_direction if facing_direction != Vector2.ZERO else Vector2.DOWN

	var dx = dir.x
	var dy = dir.y
	var abs_dx = abs(dx)
	var abs_dy = abs(dy)

	var base := "south"

	# Pure vertical
	if abs_dx < eps and abs_dy >= eps:
		base = "north" if dy < 0 else "south"
	# Pure horizontal -> map right to southEast, left to southWest
	elif abs_dy < eps and abs_dx >= eps:
		base = "southEast" if dx > 0 else "southWest"
	else:
		# Diagonals
		if dx > 0 and dy < 0:
			base = "northEast"
		elif dx < 0 and dy < 0:
			base = "northWest"
		elif dx > 0 and dy > 0:
			base = "southEast"
		elif dx < 0 and dy > 0:
			base = "southWest"

	if moving:
		return base

	# Idle variant: e.g. "idleNorthEast"
	var suffix = base[0].to_upper() + base.substr(1)
	return "idle" + suffix

func update_timers(delta):
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# Snore cooldown timer decrement
	if snore_cooldown_timer > 0.0:
		snore_cooldown_timer -= delta

	# Play snore when idle, not hurt/dead, and cooldown elapsed
	if sfx_snore1 and input == Vector2.ZERO and not is_hurt and not is_dead and snore_cooldown_timer <= 0.0:
		if not sfx_snore1.playing:
			sfx_snore1.play()
			snore_cooldown_timer = SNORE_COOLDOWN

func check_enemy_collision():
	if self.velocity.length() <= 0.1:
		return
		
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider and collider.is_in_group("enemy"):
			if collider.has_method("take_damage"):
				is_dashing = false
				stop_running()
				var direction = (collider.global_position - global_position).normalized()
				collider.take_damage(melee_damage, direction, melee_knockback_force)
				velocity = -direction * (melee_knockback_force)

func take_damage(amount: int, _from_direction: Vector2 = Vector2.ZERO, _knockback_force: float = KNOCKBACK_FORCE):
	if not can_take_damage or is_dead:
		return
	can_take_damage = false
	
	stop_running()

	# mark as hurt and play hit SFX immediately
	is_hurt = true
	if sfx_hit:
		sfx_hit.play()

	# small freeze-frame effect
	get_tree().paused = true
	await get_tree().create_timer(0.05).timeout
	get_tree().paused = false

	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.start_shake(1.0)

	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	print("Player took ", amount, " damage!, Current health: ", current_health - amount)
	current_health -= amount
	invulnerability_timer.start()
	emit_signal("update_health", current_health, max_health)

	if current_health <= 0:
		die()
		return

func reset():
	current_health = max_health

func die():
	velocity = Vector2.ZERO
	is_dead = true
	print("Player has died.")
	# Play a one-shot ambient SFX (ambients3) at the player's location.
	# Add the player as a sibling so the sound continues after the player node is freed.
	var stream = ResourceLoader.load("res://assets/audio/sfx/ambients3.wav")
	if stream:
		var ap := AudioStreamPlayer2D.new()
		ap.stream = stream
		# place it in the same parent as the player so it does not get freed with the player
		if is_instance_valid(get_parent()):
			get_parent().add_child(ap)
		else:
			get_tree().get_root().add_child(ap)
		ap.global_position = global_position
		ap.play()
		# free the player-created audio node when it finishes playing
		# AudioStreamPlayer2D emits "finished" when the stream ends
		ap.connect("finished", Callable(ap, "queue_free"))

	queue_free()
	#play_animation_if_not_playing("death")

func play_animation_if_not_playing(anim_name: String):
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func update_run_state(_delta):
	if input != Vector2.ZERO:
		if not is_running:
			if not run_timer.is_stopped():
				# Timer is already running
				pass
			else:
				run_timer.start()
		else:
			# Already running
			pass
	else:
		# Reset running state
		if is_running:
			stop_running()
		run_timer.stop()
		run_timer.start()  # Restart timer when player stops moving

func stop_running():
	is_running = false
	speed = _base_speed
	melee_damage = _base_melee_damage
	run_timer.stop()
	run_timer.start()

#region Abilities
func handle_ability_input():
	for i in range(min(ability_keys.size(), abilities.size())):
		if Input.is_action_just_pressed(ability_keys[i]):
			var ability = abilities[i]
			if ability:
				ability.activate(self)

# Cooldown handling (called by BaseAbility)
func start_ability_cooldown(ability: BaseAbility, time: float):
	await get_tree().create_timer(time).timeout
	ability.is_on_cooldown = false

#region dash ability
func start_dash(_dash_distance: float=0, _invincibility_duration: float=0):
	if can_dash():
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN

func cleave_attack():
	# Simple cleave attack: damage all enemies in a radius around the player
	var cleave_radius = 100.0
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= cleave_radius:
			var direction = (enemy.global_position - global_position).normalized()
			enemy.take_damage(melee_damage, direction, melee_knockback_force)
#endregion

#region mirror mirror ability
func spawn_mirror_clone(duration: float=5.0):
	var clone = mirror_clone_scene.instantiate() as MirrorClone
	clone.set_name("MirrorClone")
	clone.set_position(global_position + 50 * facing_direction)
	clone.set_rotation(rotation)
	clone.speed = speed * 0.8
	clone.melee_damage = int(melee_damage * 0.5)

	get_parent().add_child(clone)
	clone.start_lifetime_timer(duration)

func start_lifetime_timer(duration: float):
	await get_tree().create_timer(duration).timeout
	queue_free()
#endregion

#region revolving flame ability
func add_area_damage(radius: float, duration: float):
	# Damage all enemies in radius over duration
	play_revolving_flame_animation(duration)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(MELEE_DAMAGE, (enemy.global_position - global_position).normalized(), melee_knockback_force)

func play_revolving_flame_animation(duration: float):
	fire_animation.visible = true
	fire_animation.play("revolving_flame")
	await get_tree().create_timer(duration).timeout
	fire_animation.stop()
	fire_animation.visible = false
#endregion

#region rotating shell ability
func spawn_rotating_shell(duration: float, shell_scene: PackedScene):
	var shell = shell_scene.instantiate()
	add_child(shell)
	shell.owner = self
	shell.start_lifetime_timer(duration)
#endregion

#region stunning stomp ability
func create_stomp_effect(radius: float, damage_multiplier: float= 1.0):
	var _duration = 0.75
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(int(melee_damage * damage_multiplier), (enemy.global_position - global_position).normalized(), melee_knockback_force)
#endregion

#region vacuum magic ability
func spawn_vacuum_field(duration: float, distance: float, vacuum_field_scene: PackedScene):
	var vacuum_field = vacuum_field_scene.instantiate()
	get_tree().get_root().add_child(vacuum_field)
	vacuum_field.start_lifetime_timer(duration)
	throw_vacuum_field(vacuum_field, distance)

func throw_vacuum_field(vacuum_field: VacuumField, distance: float):
	var direction = facing_direction.normalized()
	var target_position = global_position + direction * distance
	vacuum_field.global_position = target_position
#endregion

#endregion


func _on_invulnerability_timer_timeout() -> void:
	can_take_damage = true
	is_hurt = false


func _on_run_timer_timeout() -> void:
	is_running = true
	speed = _base_speed * run_speed_multiplier
	melee_damage = int(_base_melee_damage * run_damage_multiplier)
	print("Player is now running! Speed and damage increased.")

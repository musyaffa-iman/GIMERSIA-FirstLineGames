class_name Player
extends CharacterBody2D

# CONSTANTS
const ACCELERATION = 10.0
const DASH_SPEED := 700.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 1.2

const KNOCKBACK_FORCE := 300.0

# EXPORTS
@export_group("Properties")
@export var max_health: int = 25
@export var speed := 200.0
@export var melee_damage := 35
@export var melee_knockback_force: float = 1000.0
@export_category("Abilities")
@export var abilities: Array[BaseAbility] = []  # Drag & drop abilities in Inspector
@export var ability_keys := ["ability_1", "ability_2"] # Input names for abilities
@export var mirror_clone_scene: PackedScene

signal update_health(current_health, max_health)

@onready var invulnerability_timer: Timer = $InvulnerabilityTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# PLAYER STATE
var current_health: int
var can_take_damage: bool = true
var is_hurt: bool = false
var is_dashing: bool = false
var is_dead: bool = false

# TIMERS
var dash_timer := 0.0
var dash_cooldown_timer := 0.0

var input : Vector2
var facing_direction : Vector2 = Vector2.RIGHT

func _ready():
	current_health = max_health
	update_health.emit(current_health, max_health)

func _process(delta):
	if is_dead:
		return
		
	handle_input()
	handle_dash_logic(delta)
	handle_movement_and_animation()
	update_timers(delta)
	check_enemy_collision()

	handle_ability_input()

func handle_input():
	input = get_movement_input()
	facing_direction = input if input != Vector2.ZERO else facing_direction
	
	# Handle orientation
	if input.x > 0:
		animated_sprite.flip_h = false
	elif input.x < 0:
		animated_sprite.flip_h = true

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
	# Animation logic
	if not is_hurt and not is_dead:
		if input != Vector2.ZERO:
			play_animation_if_not_playing("move")
		else:
			play_animation_if_not_playing("idle")

	if is_dashing:
		velocity = input * DASH_SPEED
	else:
		velocity = lerp(velocity, input * speed, ACCELERATION * get_process_delta_time())

	move_and_slide()

func update_timers(delta):
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

func check_enemy_collision():
	if self.velocity.length() <= 0.1:
		return
		
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider and collider.is_in_group("enemy"):
			if collider.has_method("take_damage"):
				var direction = (collider.global_position - global_position).normalized()
				collider.take_damage(melee_damage, direction, melee_knockback_force)
				velocity = -direction * (melee_knockback_force)

func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO, knockback_force: float = KNOCKBACK_FORCE):
	if not can_take_damage or is_dead:
		return

	print("Player took ", amount, " damage!, Current health: ", current_health - amount)
	current_health -= amount
	can_take_damage = false
	invulnerability_timer.start()
	emit_signal("update_health", current_health, max_health)

	if current_health <= 0:
		die()
		return

func die():
	is_dead = true
	velocity = Vector2.ZERO
	print("Player has died.")
	queue_free()
	#play_animation_if_not_playing("death")

func play_animation_if_not_playing(anim_name: String):
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

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
func start_dash(dash_distance: float=0, invincibility_duration: float=0):
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
func add_area_damage(radius: float, damage: int):
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(damage, (enemy.global_position - global_position).normalized(), melee_knockback_force)
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
	var duration = 0.75
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

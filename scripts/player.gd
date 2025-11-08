extends CharacterBody2D

# CONSTANTS
const ACCELERATION = 10.0
const DASH_SPEED := 500.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 1.2
const MELEE_DAMAGE := 1
const KNOCKBACK_FORCE := 300.0

# EXPORTS
@export_group("Properties")
@export var max_health: int = 25
@export var speed := 200.0
@export var melee_knockback_force: float = 1000.0

signal update_health(current_health, max_health)

# PLAYER STATE
var current_health: int
var can_take_damage: bool = true
var is_hurt: bool = false
var is_dashing: bool = false
var is_dead: bool = false

# TIMERS
var dash_timer := 0.0
var dash_cooldown_timer := 0.0

# NODE REFERENCES
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var input : Vector2

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

func handle_input():
	input = get_movement_input()
	
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


func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	

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
				collider.take_damage(MELEE_DAMAGE, direction, melee_knockback_force)
				velocity = -direction * (melee_knockback_force)

func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO, knockback_force: float = KNOCKBACK_FORCE):
	if not can_take_damage or is_dead:
		return

	print("Player took ", amount, " damage!, Current health: ", current_health - amount)
	current_health -= amount
	emit_signal("update_health", current_health, max_health)

	if current_health <= 0:
		die()
		return

	#is_hurt = true
	#can_take_damage = false
	#velocity = from_direction.normalized() * knockback_force

func die():
	is_dead = true
	velocity = Vector2.ZERO
	print("Player has died.")
	queue_free()
	#play_animation_if_not_playing("death")

func play_animation_if_not_playing(anim_name: String):
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

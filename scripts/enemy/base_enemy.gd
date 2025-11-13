@abstract
extends CharacterBody2D
class_name Enemy

@export var max_health: int = 100
@export var move_speed: float = 800.0
@export var damage: int = 1
@export var knockback_resistance: float = 0.5  # 0 = full knockback, 1 = no knockback
@export var use_line_of_sight: bool = true  # If true, enemies can't see/target player through walls

@onready var player: Node2D = null
@onready var freeze_animation: AnimatedSprite2D = $FreezeAnimation

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 1000.0  # how quickly knockback fades
var invulnerable: bool = false
var invulnerability_time: float = 0.5
var invulnerability_timer: float = 0.0
var health: int = 0

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	enemy_behavior(delta)
	
	# Handle invulnerability timer
	if invulnerable:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0:
			invulnerable = false
			invulnerability_timer = 0.0
				
	# Apply knockback decay
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	velocity += knockback_velocity

	# flip sprite based on player direction
	if player:
		$AnimatedSprite2D.flip_h = (player.global_position.x - global_position.x) < 0
	move_and_slide()

@abstract
func enemy_behavior(delta: float) -> void

func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0) -> void:
	if invulnerable:
		return
		
	invulnerable = true
	invulnerability_timer = invulnerability_time

	get_tree().paused = true
	await get_tree().create_timer(0.02).timeout
	get_tree().paused = false

	health -= amount
	#print("Enemy ", self.name, " took ", amount, " damage! Current health: ", health)
	apply_knockback(from_direction, knockback_force)
	if health <= 0:
		die()

	# blink red to show damage taken
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
	
func apply_knockback(from_direction: Vector2, force: float) -> void:
	knockback_velocity = from_direction.normalized() * force * (1.0 - knockback_resistance)

func die() -> void:
	queue_free()

func freeze(duration: float) -> void:
	# Simple freeze implementation: stop movement for duration
	set_physics_process(false)
	freeze_animation.visible = true
	await get_tree().create_timer(duration).timeout
	set_physics_process(true)
	freeze_animation.visible = false

func has_line_of_sight_to_player() -> bool:
	# Raycast from enemy to player to check if there are walls blocking the view
	if not player or not is_instance_valid(player):
		return false
	
	var space := get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.new()
	params.from = global_position
	params.to = player.global_position
	params.exclude = [self]
	params.collide_with_bodies = true
	params.collide_with_areas = false
	
	var result = space.intersect_ray(params)
	
	# If nothing hit, line is clear
	if not result or result.is_empty():
		return true
	
	# If the collider is the player, line is clear
	var collider = result.get("collider")
	if collider == player:
		return true
	
	# Something else is blocking (likely a wall)
	return false

func can_see_player() -> bool:
	# Helper function that checks if line-of-sight is enabled and if player is visible
	if not use_line_of_sight:
		return true  # Line-of-sight disabled, always can "see" player
	return has_line_of_sight_to_player()

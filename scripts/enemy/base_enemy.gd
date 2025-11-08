@abstract
extends CharacterBody2D
class_name Enemy

@export var health: int = 3
@export var speed: float = 80.0
@export var damage: int = 1
@export var knockback_resistance: float = 0.5  # 0 = full knockback, 1 = no knockback

@onready var player: Node2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 100.0  # how quickly knockback fades
var invulnerable: bool = false
var invulnerability_time: float = 0.5
var invulnerability_timer: float = 0.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if player:
		move_behavior(delta)
	
	# Handle invulnerability timer
	if invulnerable:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0:
			invulnerable = false
			invulnerability_timer = 0.0
				
	# Apply knockback decay
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	velocity += knockback_velocity

	move_and_slide()

@abstract
func move_behavior(delta: float) -> void

func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0) -> void:
	if invulnerable:
		return

	health -= amount
	print("Enemy ", self.name, " took ", amount, " damage! Current health: ", health)
	apply_knockback(from_direction, knockback_force)
	if health <= 0:
		die()

	invulnerable = true
	invulnerability_timer = invulnerability_time
	
func apply_knockback(from_direction: Vector2, force: float) -> void:
	knockback_velocity = from_direction.normalized() * force * (1.0 - knockback_resistance)

func die() -> void:
	queue_free()

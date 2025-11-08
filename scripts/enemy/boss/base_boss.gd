@abstract
extends Enemy
class_name BossBase

@export var phase_two_threshold: int = 25
@export var attack_cooldown: float = 2.0
var phase_two: bool = false
var attack_timer: float = 0.0

func _ready() -> void:
	super()
	attack_timer = attack_cooldown
	print("Boss spawned:", name)

func _physics_process(delta: float) -> void:
	if player:
		enemy_behavior(delta)
		attack_timer -= delta
		if attack_timer <= 0:
			perform_attack()
			attack_timer = attack_cooldown

	# Handle knockback and physics from Enemy
	super._physics_process(delta)

	if not phase_two and health <= phase_two_threshold:
		enter_phase_two()

@abstract
func perform_attack()

func enter_phase_two():
	phase_two = true
	print(name, "entered PHASE TWO!")

func die():
	print("Boss defeated!")
	super.die()

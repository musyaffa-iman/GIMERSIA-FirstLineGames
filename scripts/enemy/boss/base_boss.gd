@abstract
extends Enemy
class_name BossBase

@export var phase_two_threshold: int = 50
@export var phase_three_threshold: int = 25
@export var attack_cooldown: float = 2.0
var phase_two: bool = false
var phase_three: bool = false
var attack_timer: float = 0.0

func _ready() -> void:
	super()
	attack_timer = attack_cooldown
	print("Boss spawned:", name)

func _physics_process(delta: float) -> void:
	# Handle knockback and physics from Enemy
	super._physics_process(delta)
	
	attack_timer -= delta
	if attack_timer <= 0:
		perform_attack()
		attack_timer = attack_cooldown

	if not phase_two and health <= phase_two_threshold:
		enter_phase_two()
	
	if not phase_three and health <= phase_three_threshold:
		enter_phase_three()

@abstract
func perform_attack()

@abstract
func enter_phase_two()

@abstract
func enter_phase_three()

func die():
	print("Boss defeated!")
	super.die()

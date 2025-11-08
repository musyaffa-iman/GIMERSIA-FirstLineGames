extends BossBase

@export var fireball_scene: PackedScene
@export var shoot_speed: float = 350.0

func move_behavior(delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed

func perform_attack():
	if not fireball_scene:
		return
	var fireball = fireball_scene.instantiate()
	fireball.global_position = global_position
	var dir = (player.global_position - global_position).normalized()
	fireball.velocity = dir * shoot_speed
	get_tree().current_scene.add_child(fireball)

func enter_phase_two():
	super()
	speed *= 1.4
	attack_cooldown *= 0.7
	print("FireBoss enraged!")

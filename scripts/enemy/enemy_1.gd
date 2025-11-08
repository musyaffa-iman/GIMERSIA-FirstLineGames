extends Enemy

func enemy_behavior(_delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed

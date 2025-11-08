extends Enemy

func move_behavior(delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed

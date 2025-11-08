extends BaseAbility
class_name RotatingShellAbility

@export var duration: float = 8.0

func _execute(player):
	player.spawn_rotating_shield(duration)

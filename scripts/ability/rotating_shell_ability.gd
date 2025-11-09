extends BaseAbility
class_name RotatingShellAbility

@export var duration: float = 8.0
@export var shell_scene: PackedScene

func _execute(player):
	player.spawn_rotating_shell(duration, shell_scene)

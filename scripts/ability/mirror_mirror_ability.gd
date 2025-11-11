extends BaseAbility
class_name MirrorMirrorAbility

@export var duration: float = 20.0

func _execute(player):
	player.spawn_mirror_clone(duration)

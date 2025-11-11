extends BaseAbility
class_name VacuumMagicAbility

@export var duration: float = 8.0
@export var distance: float = 400.0
@export var vacuum_field_scene: PackedScene

func _execute(player):
	player.spawn_vacuum_field(duration, distance, vacuum_field_scene)

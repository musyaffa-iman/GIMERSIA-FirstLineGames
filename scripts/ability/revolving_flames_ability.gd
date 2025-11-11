extends BaseAbility
class_name RevolvingFlamesAbility

@export var radius: float = 300.0
@export var duration: float = 5.0

func _execute(player):
	player.add_area_damage(radius, duration)

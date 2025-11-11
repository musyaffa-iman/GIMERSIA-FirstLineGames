extends BaseAbility
class_name DashAbility

@export var dash_distance: float = 200
@export var invincibility_duration: float = 0.5

func _execute(player):
	player.start_dash(dash_distance, invincibility_duration)
	player.cleave_attack()

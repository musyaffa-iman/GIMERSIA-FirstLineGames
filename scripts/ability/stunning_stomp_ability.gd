extends BaseAbility
class_name StunningStompAbility

@export var radius: float = 5.0
@export var damage_multiplier: float = 1.5

func _execute(player):
	player.create_stomp_effect(radius, damage_multiplier)

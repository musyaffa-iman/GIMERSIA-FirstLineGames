@abstract
extends Resource
class_name BaseAbility

@export var ability_name: String
@export var cooldown: float = 5.0
var is_on_cooldown := false

func activate(player):
	if is_on_cooldown:
		return
	print("Activating ability: ", ability_name)
	_execute(player)
	_start_cooldown(player)

@abstract
func _execute(player)

func _start_cooldown(player):
	is_on_cooldown = true
	player.start_ability_cooldown(self, cooldown)

extends BaseAbility
class_name EnemyFreezeAbility

@export var radius: float = 1000.0
@export var freeze_time: float = 3.0

func _execute(player):
	var enemies = player.get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if player.global_position.distance_to(enemy.global_position) <= radius:
			enemy.freeze(freeze_time)

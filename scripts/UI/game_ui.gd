extends Control

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		get_tree().paused = not get_tree().paused

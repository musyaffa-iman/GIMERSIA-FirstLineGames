extends Area2D

@export var Type : String = "KEYA or KEYB"
@export var World : Node2D

func _ready() -> void:
	var collision = CollisionPolygon2D.new()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" :
		World.set(Type, true)
		World.updatekeys()
		queue_free()

extends Area2D

# Simple fireball projectile

@export var speed := 600.0
@export var damage := 10
@export var lifetime := 3.0

var velocity := Vector2.ZERO
var shooter = null
var _time_alive := 0.0

func _ready():
	connect("body_entered",Callable(self, "_on_body_entered"))

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return
	global_position += velocity * delta


func _on_body_entered(body) -> void:
	if body == shooter:
		return
	if body and body.has_method("take_damage"):
		print("Fireball hit ", body.name)
		#body.call("take_damage", damage, shooter)
	queue_free()

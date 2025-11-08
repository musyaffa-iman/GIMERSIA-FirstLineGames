extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 1.5
var velocity: Vector2 = Vector2.ZERO
var damage: float = 15.0

func _ready():
	add_to_group("player_attack")
	# Default layers/masks (1) so it hits default enemy hitboxes unless customized.
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += velocity * delta

func set_velocity(v: Vector2) -> void:
	velocity = v

func set_damage(dmg: float) -> void:
	damage = dmg

func configure(dir: Vector2, dmg: float) -> void:
	damage = dmg
	velocity = dir.normalized() * speed

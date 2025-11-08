extends Area2D

@export var damage: float = 12.0
@export var lifetime: float = 0.12
var owner_enemy: Node = null

func _ready() -> void:
	# connect body_entered to handle hits
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	# ensure the sprite is visible and the slash draws above most objects
	# set a high z_index so it appears on top of character sprites
	if has_method("set_z_index"):
		z_index = 100
	else:
		# Node2D z_index property should be available; fallback ignored
		pass
	var sprite = $Sprite2D if has_node("Sprite2D") else null
	if sprite:
		sprite.visible = true
	# schedule auto-free
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not body:
		return
	# don't hit the owner enemy
	if owner_enemy and body == owner_enemy:
		return
	# only damage player group nodes
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()

func set_owner_enemy(owner_node: Node) -> void:
	owner_enemy = owner_node

func set_damage(d: float) -> void:
	damage = d

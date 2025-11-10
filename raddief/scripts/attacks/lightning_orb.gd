extends Area2D

# Lightning Orb projectile for Beholder
# Non-homing projectile that deals damage on contact

@export var base_value: float = 50.0
@export var owner_atk: float = 38.0
@export var lifetime: float = 3.0

var velocity: Vector2 = Vector2.ZERO
var owner_enemy: Node = null
var time_alive: float = 0.0

func _ready() -> void:
	# Set collision layers
	collision_layer = 4  # Enemy attack layer
	collision_mask = 1   # Player layer
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	print("Lightning Orb spawned at ", global_position)

func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return
	
	global_position += velocity * delta

func set_velocity(vel: Vector2) -> void:
	velocity = vel

func set_base_value(val: float) -> void:
	base_value = val

func set_owner_atk(atk: float) -> void:
	owner_atk = atk

func _on_body_entered(body: Node) -> void:
	if not body or body == owner_enemy:
		return
	
	if body.has_method("take_damage"):
		# Compute defender DEF
		var def_val: float = 25.0
		if body.get("defense") != null:
			def_val = float(body.get("defense"))
		
		# Calculate damage using DamageCalc
		var final_damage = DamageCalc.calculate_damage(int(base_value), int(owner_atk), def_val)
		
		# Apply knockback direction based on orb velocity
		var knockback_dir = velocity.normalized() if velocity.length() > 0 else Vector2.RIGHT
		
		body.take_damage(final_damage, knockback_dir, 200.0)
		print("Lightning Orb hit ", body.name, " for ", final_damage, " damage!")
		
		queue_free()

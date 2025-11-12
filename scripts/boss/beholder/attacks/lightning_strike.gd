extends Area2D

# Lightning Strike impact area for Beholder
# Similar to Dark Mage pillar: scales up over time, then deals damage

@export var base_value: float = 55.0
@export var owner_atk: float = 38.0
@export var radius: float = 40.0
@export var lifetime: float = 0.5  # Total lifetime
@export var active_time: float = 0.15  # How long to scale up

var owner_enemy: Node = null
var has_dealt_damage: bool = false
var time_alive: float = 0.0

func _ready() -> void:
	# Set collision layers
	collision_layer = 4  # Enemy attack layer
	collision_mask = 1   # Player layer
	
	# Start at scale 0
	scale = Vector2.ZERO
	
	# Change sprite to yellow lightning effect
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		sprite.modulate = Color.YELLOW
		sprite.scale = Vector2(0.6, 0.8)  # Lightning-like (taller)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	print("Lightning Strike spawned at ", global_position)

func _physics_process(delta: float) -> void:
	time_alive += delta
	
	# Scale up animation (from 0 to 1 over active_time, then stays at 1)
	if time_alive < active_time:
		var t = time_alive / active_time
		scale = Vector2.ONE * t
	else:
		scale = Vector2.ONE
	
	# Despawn after lifetime
	if time_alive >= lifetime:
		queue_free()

func set_base_value(val: float) -> void:
	base_value = val

func set_owner_atk(atk: float) -> void:
	owner_atk = atk

func set_owner_enemy(owner_node: Node) -> void:
	owner_enemy = owner_node

func set_radius(new_radius: float) -> void:
	radius = new_radius
	# Update collision shape if present
	if has_node("CollisionShape2D"):
		var collision = get_node("CollisionShape2D")
		if collision.shape is CircleShape2D:
			collision.shape.radius = new_radius

func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("player") and not has_dealt_damage:
		if body.has_method("take_damage"):
			# Compute defender DEF
			var def_val: float = 25.0
			var maybe = body.get("defense")
			if maybe != null:
				def_val = float(maybe)
			
			# Determine attacker's ATK (null-safe)
			var final_owner_atk = owner_atk
			if owner_enemy != null:
				var maybe_atk = owner_enemy.get("atk")
				if maybe_atk != null:
					final_owner_atk = float(maybe_atk)
			
			# Calculate final damage
			var final = DamageCalc.calculate_damage(int(base_value), int(final_owner_atk), def_val)
			
			# Knockback straight up (lightning from sky)
			var knockback_dir = Vector2.UP
			
			body.take_damage(final, knockback_dir, 150.0)
			has_dealt_damage = true
			print("Lightning Strike hit ", body.name, " for ", final, " damage!")

func _on_area_entered(area: Node) -> void:
	if not area or has_dealt_damage:
		return
	
	var target = area
	# Check if area is player or child of player
	if not target.is_in_group("player"):
		if target.get_parent() and target.get_parent().is_in_group("player"):
			target = target.get_parent()
	
	if target.is_in_group("player") and target.has_method("take_damage"):
		# Compute defender DEF
		var def_val: float = 25.0
		var maybe = target.get("defense")
		if maybe != null:
			def_val = float(maybe)
		
		# Determine attacker's ATK (null-safe)
		var final_owner_atk = owner_atk
		if owner_enemy != null:
			var maybe_atk = owner_enemy.get("atk")
			if maybe_atk != null:
				final_owner_atk = float(maybe_atk)
		
		# Calculate final damage
		var final = DamageCalc.calculate_damage(int(base_value), int(final_owner_atk), def_val)
		
		# Knockback straight up
		var knockback_dir = Vector2.UP
		
		target.take_damage(final, knockback_dir, 150.0)
		has_dealt_damage = true
		print("Lightning Strike hit ", target.name, " for ", final, " damage!")

extends Area2D

# Configuration
@export var damage: float = 15.0
@export var radius: float = 50.0
@export var lifetime: float = 1.5  # Total lifetime before despawn
@export var active_time: float = 0.2  # How long it takes to scale up

var time_alive: float = 0.0
var has_dealt_damage: bool = false

func _ready():
	# Set collision layers
	collision_layer = 4  # Enemy attack layer
	collision_mask = 1   # Player layer
	
	# Start at scale 0
	scale = Vector2.ZERO
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	print("Dark pillar spawned at ", global_position)

func _physics_process(delta):
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

func set_damage(new_damage: float):
	damage = new_damage

func set_radius(new_radius: float):
	radius = new_radius
	# Update collision shape if present
	if has_node("CollisionShape2D"):
		var collision = get_node("CollisionShape2D")
		if collision.shape is CircleShape2D:
			collision.shape.radius = new_radius

func _on_body_entered(body):
	# Check if it's the player
	if body.is_in_group("player") and not has_dealt_damage:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			has_dealt_damage = true
			print("Dark pillar hit player for ", damage, " damage!")

func _on_area_entered(area):
	# Check if the area is the player (some games use Area2D for player)
	if not has_dealt_damage:
		var target = area
		# Check if area itself is in player group
		if not target.is_in_group("player"):
			# Check if parent is player
			if target.get_parent() and target.get_parent().is_in_group("player"):
				target = target.get_parent()
		
		if target.is_in_group("player") and target.has_method("take_damage"):
			target.take_damage(damage)
			has_dealt_damage = true
			print("Dark pillar hit player (Area2D) for ", damage, " damage!")

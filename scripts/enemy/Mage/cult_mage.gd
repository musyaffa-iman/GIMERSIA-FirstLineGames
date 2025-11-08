extends Enemy

# Attack parameters
@export var detection_range: float = 350.0
@export var telegraph_duration: float = 1.0  # How long the red circle shows before attack
@export var attack_cooldown: float = 3.0     # Time between attacks
@export var pillar_radius: float = 16.0      # Size of the attack area (radius in pixels, 32px diameter)
@export var attack_damage: float = 55.0 # BASE_VALUE for Dark Pillar (GDD)
@export var defense: int = 20

# Drag and drop scenes here in the Inspector!
@export var dark_pillar_scene: PackedScene = null
@export var telegraph_circle_scene: PackedScene = null

# State machine
var is_telegraphing: bool = false
var can_attack: bool = true
var telegraph_timer: float = 0.0
var cooldown_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var telegraph_instance: Node2D = null

func _ready():
	# Apply GDD HP to inherited property before base setup runs
	max_health = 13

	# Let base class perform its setup (it will initialize health/player lookup)
	super._ready()

	# Ensure this node is in the common enemy group so other systems find it
	add_to_group("enemy")

	# Auto-connect hitbox signal if exists (safe, idempotent)
	if has_node("Hitbox"):
		var hb = $Hitbox
		if hb and hb.has_signal("area_entered"):
			if not hb.is_connected("area_entered", Callable(self, "_on_hitbox_area_entered")):
				hb.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))
				print("Mage: Hitbox connected!")

	# If scenes weren't set in the Inspector, try lazy-loading common defaults so the mage works out-of-the-box.
	if not dark_pillar_scene:
		var _p = load("res://Scenes/pillar.tscn")
		if _p and _p is PackedScene:
			dark_pillar_scene = _p
			print("Mage: lazily loaded dark_pillar_scene from res://Scenes/pillar.tscn")
		else:
			# Try alternate path used elsewhere in repo
			_p = load("res://Scenes/enemy/pillar.tscn")
			if _p and _p is PackedScene:
				dark_pillar_scene = _p
				print("Mage: lazily loaded dark_pillar_scene from res://Scenes/enemy/pillar.tscn")

	if not telegraph_circle_scene:
		var _c = load("res://Scenes/circle.tscn")
		if _c and _c is PackedScene:
			telegraph_circle_scene = _c
			print("Mage: lazily loaded telegraph_circle_scene from res://Scenes/circle.tscn")
		else:
			_c = load("res://Scenes/enemy/circle.tscn")
			if _c and _c is PackedScene:
				telegraph_circle_scene = _c
				print("Mage: lazily loaded telegraph_circle_scene from res://Scenes/enemy/circle.tscn")

func enemy_behavior(delta: float) -> void:
	# Debug: check if player exists
	if not player:
		print("Mage: No player found!")
		return
	
	# Check if scenes are assigned
	if not dark_pillar_scene:
		print("Mage: No dark_pillar scene assigned! Drag pillar.tscn to Inspector.")
		return
	if not telegraph_circle_scene:
		print("Mage: No telegraph_circle scene assigned! Drag circle.tscn to Inspector.")
		return
	
	# Always face the player
	var direction_to_player = player.global_position - global_position
	rotation = direction_to_player.angle()
	
	# Check if player is in range
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= detection_range:
		# Handle attack state machine
		if is_telegraphing:
			# Currently showing telegraph
			telegraph_timer += delta
			if telegraph_timer >= telegraph_duration:
				# Telegraph done, spawn the attack!
				spawn_dark_pillar()
				is_telegraphing = false
				can_attack = false
				cooldown_timer = 0.0
				# Remove telegraph instance
				if telegraph_instance and is_instance_valid(telegraph_instance):
					telegraph_instance.queue_free()
					telegraph_instance = null
		elif not can_attack:
			# On cooldown
			cooldown_timer += delta
			if cooldown_timer >= attack_cooldown:
				can_attack = true
		else:
			# Ready to attack - start telegraph
			start_telegraph()

func start_telegraph():
	is_telegraphing = true
	telegraph_timer = 0.0
	
	# Set target position (where player currently is)
	target_position = player.global_position
	
	# Spawn telegraph circle instance at target position
	if telegraph_circle_scene:
		telegraph_instance = telegraph_circle_scene.instantiate()
		get_parent().add_child(telegraph_instance)
		telegraph_instance.global_position = target_position
		# Set lifetime to match telegraph duration
		if "lifetime" in telegraph_instance:
			telegraph_instance.lifetime = telegraph_duration
	
	print("Mage: Telegraphing attack at ", target_position)

func spawn_dark_pillar():
	if not dark_pillar_scene:
		return
	
	# Create pillar instance
	var pillar = dark_pillar_scene.instantiate()
	
	# Add to scene tree
	get_parent().add_child(pillar)
	
	# Set pillar position to EXACT CENTER of telegraphed location
	# (target_position is already the center where the circle was shown)
	pillar.global_position = target_position
	
	# Set pillar damage if it has the property
	if pillar.has_method("set_damage"):
		pillar.set_damage(attack_damage)
	elif "damage" in pillar:
		pillar.damage = attack_damage
	
	# Set pillar radius if it has the property
	if pillar.has_method("set_radius"):
		pillar.set_radius(pillar_radius)
	elif "radius" in pillar:
		pillar.radius = pillar_radius
	
	print("Mage: Dark pillar spawned at ", target_position)

func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0) -> void:
	# Apply defense reduction
	var actual_damage = max(amount - int(defense), 0)
	
	# Visual feedback
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	# Delegate to base Enemy
	super.take_damage(actual_damage, from_direction, knockback_force)
	
	print("Mage took ", actual_damage, " damage. HP: ", health)

func _on_hitbox_area_entered(area):
	# Handle collision with player attack
	if not area:
		return
	if not area.is_in_group("player_attack"):
		return

	# Determine damage value safely
	var dmg = 10
	if area.has_method("get_damage"):
		dmg = int(area.get_damage())
	elif "damage" in area:
		var maybe = area.get("damage")
		if typeof(maybe) != TYPE_NIL:
			dmg = int(maybe)

	# Compute a reasonable knockback direction. Prefer explicit velocity from the attack.
	var from_dir = Vector2.ZERO
	if area.has_method("get_velocity"):
		from_dir = area.get_velocity()
	elif "velocity" in area:
		from_dir = area.velocity
	elif area.has_method("get_linear_velocity"):
		from_dir = area.get_linear_velocity()
	else:
		# Fallback: push away from the attack's position
		if is_instance_valid(area) and area.global_position:
			from_dir = (global_position - area.global_position)

	# Call take_damage with direction so base Enemy can apply knockback
	take_damage(dmg, from_dir)

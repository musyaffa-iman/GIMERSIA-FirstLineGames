extends Enemy

# Simple melee grunt: idle -> detect -> chase -> attack

@export var detection_range: float = 300.0
@export var attack_range: float = 36.0
@export var attack_damage: float = 40.0 # BASE_VALUE for Zombie swipe (GDD)
@export var defense: int = 24
@export var slash_scene: PackedScene
@export var attack_cooldown: float = 1.0
@export var knockback_strength: float = 150.0
@export var debug_logs: bool = false
@export var attack_buffer: float = 12.0 # extra buffer so collisions don't prevent melee triggering

var current_health: float
var attack_timer: float = 0.0
var player_in_hitbox: bool = false

func _ready():
	# Let base Enemy do common setup (find player, initialize health)
	# Apply GDD HP to inherited property before base setup runs
	max_health = 15

	# Let base Enemy do common setup (find player, initialize health)
	super._ready()
	# local mirror for previous code expectations
	current_health = max_health
	# Ensure this node is in the common enemy group so other systems find it
	add_to_group("enemy")
	# try to lazily load the slash scene at runtime to avoid preload errors
	if not slash_scene:
		var candidate = load("res://Scenes/slash.tscn")
		if candidate and candidate is PackedScene:
			slash_scene = candidate
			if debug_logs:
				print("Zombie: lazily loaded slash.tscn")
		else:
			if debug_logs:
				print("Zombie: slash scene not available; will fallback to direct damage")
	# enable hitbox monitoring if present so we can use area overlaps later
	if has_node("hitbox"):
		var hb = $hitbox
		if hb and hb is Area2D:
			hb.monitoring = true
			# connect signals to run overlap-based attacks
			if not hb.is_connected("body_entered", Callable(self, "_on_hitbox_body_entered")):
				hb.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
			if not hb.is_connected("body_exited", Callable(self, "_on_hitbox_body_exited")):
				hb.connect("body_exited", Callable(self, "_on_hitbox_body_exited"))

	# Also connect area_entered for hit detection from player projectiles/areas if present
	if has_node("Hitbox"):
		var hit = $Hitbox
		if hit and hit is Area2D and hit.has_signal("area_entered"):
			if not hit.is_connected("area_entered", Callable(self, "_on_hitbox_area_entered")):
				hit.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))

# player lookup is handled by Enemy base class

func enemy_behavior(delta: float) -> void:
	# Called from Enemy._physics_process once a player is found
	if debug_logs:
		print("Zombie: enemy_behavior tick; player valid?", player and is_instance_valid(player))

	# timers
	if attack_timer > 0.0:
		attack_timer = max(attack_timer - delta, 0.0)

	var to_player = player.global_position - global_position
	var dist = to_player.length()

	if dist <= detection_range:
		# chase when outside attack range
		if dist > attack_range:
			var dir = to_player.normalized()
			# set velocity; base will apply knockback and call move_and_slide()
			velocity = dir * move_speed
			if debug_logs:
				print("Zombie: chasing player; dist=", dist, "dir=", dir)
		else:
			velocity = Vector2.ZERO
			# attack when cooldown ready
			# allow a small buffer so collision prevents being stopped just outside range
			if dist <= attack_range or dist <= attack_range + attack_buffer:
				if debug_logs:
					print("Zombie: in attack range (dist=", dist, ") — attacking")
				if attack_timer <= 0.0:
					perform_attack()
					attack_timer = attack_cooldown
	else:
		# idle
		velocity = Vector2.ZERO

func perform_attack() -> void:
	if not player:
		return
	# melee: spawn a short-lived slash Area2D in front of the grunt
	var dir = (player.global_position - global_position).normalized()
	if slash_scene:
		var slash = slash_scene.instantiate()
		if slash:
			# position the slash slightly ahead of the enemy so it hits the player
			# parent the slash to the zombie so it inherits transform and z-order
			add_child(slash)
			slash.position = dir * (attack_range * 0.6)
			# orient the slash toward the player if it uses rotation
			if slash.has_method("set_rotation") or slash.has_method("set_global_rotation"):
				slash.rotation = dir.angle()
			# set damage and owner if available
			if slash.has_method("set_damage"):
				slash.set_damage(attack_damage)
				# fall back to direct property assignment only if method not available
				# (we avoid has_variable -- assume slash scene provides a setter)
			if slash.has_method("set_owner_enemy"):
				slash.set_owner_enemy(self)
				# assume setter exists; skip direct property assignment to avoid errors
			# already added as child above
			if debug_logs:
				print("Zombie: spawned slash attack with damage", attack_damage)
	else:
		# fallback: directly damage the player if no slash scene is set
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
			if debug_logs:
				print("Zombie: fallback attacked player for", attack_damage)
	# try knockback on player if they have methods
	if player.has_method("apply_impulse"):
		player.apply_impulse(dir * knockback_strength)
	elif player.has_method("set_velocity"):
		player.set_velocity(dir * knockback_strength)

func _on_hitbox_body_entered(body: Node) -> void:
	if not body:
		return
	if body.is_in_group("player"):
		player_in_hitbox = true
		if debug_logs:
			print("Zombie: player entered hitbox")
		if attack_timer <= 0.0:
			# defer actual attack to avoid changing monitoring/tree state while flushing queries
			call_deferred("perform_attack")
			attack_timer = attack_cooldown

func _on_hitbox_body_exited(body: Node) -> void:
	if not body:
		return
	if body.is_in_group("player"):
		player_in_hitbox = false
		if debug_logs:
			print("Zombie: player exited hitbox")

func _on_hitbox_area_entered(area: Area2D) -> void:
	# Handle overlaps from player projectiles or other damaging Areas
	if not area:
		return
	# Only respond to player attack areas/groups
	if not area.is_in_group("player_attack"):
		return
	# Try to read damage value from the area, fallback to attack_damage
	var dmg = attack_damage
	var maybe = area.get("damage")
	if maybe != null:
		dmg = maybe
	# Determine knockback direction: prefer projectile velocity if available
	var from_dir = Vector2.ZERO
	var vel = area.get("velocity")
	if vel != null and vel is Vector2 and vel.length() > 0.0:
		from_dir = vel.normalized()
	else:
		# fallback: direction from attacker to this enemy
		if area.has_method("global_position"):
			from_dir = (global_position - area.global_position).normalized()
		else:
			from_dir = (global_position - area.get_global_position()).normalized()
	# Apply damage and knockback via base Enemy API
	# Use this node's knockback_strength as default force
	take_damage(dmg, from_dir, knockback_strength)

func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0) -> void:
	# Delegate core damage/knockback/invulnerability handling to base Enemy
	super.take_damage(amount, from_direction, knockback_force)
	# local visual feedback
	modulate = Color(1, 0.6, 0.6)
	await get_tree().create_timer(0.08).timeout
	modulate = Color(1, 1, 1)

func die() -> void:
	queue_free()

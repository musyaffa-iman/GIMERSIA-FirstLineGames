extends CharacterBody2D

# Simple melee grunt: idle -> detect -> chase -> attack

@export var max_health: float = 80.0
@export var move_speed: float = 90.0
@export var detection_range: float = 300.0
@export var attack_range: float = 36.0
@export var attack_damage: float = 12.0
@export var slash_scene: PackedScene
@export var attack_cooldown: float = 1.0
@export var knockback_force: float = 150.0
@export var debug_logs: bool = false
@export var attack_buffer: float = 12.0 # extra buffer so collisions don't prevent melee triggering

var current_health: float
var player: Node = null
var attack_timer: float = 0.0
var player_in_hitbox: bool = false

func _ready():
	current_health = max_health
	call_deferred("find_player")
	add_to_group("enemies")
	# try to lazily load the slash scene at runtime to avoid preload errors
	if not slash_scene:
		var candidate = load("res://scenes/slash.tscn")
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

func find_player():
	if player and is_instance_valid(player):
		return
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		for candidate_name in ["Player", "player"]:
			var found = current_scene.find_child(candidate_name, true, false)
			if found:
				player = found
				if debug_logs:
					print("Zombie: found player by name", candidate_name)
				return
	var group_nodes = get_tree().get_nodes_in_group("player")
	if group_nodes.size() > 0:
		player = group_nodes[0]
		if debug_logs:
			print("Zombie: found player by group")

func _physics_process(delta: float) -> void:
	if debug_logs:
		print("Zombie: _physics_process tick; player valid?", player and is_instance_valid(player))
	if not player:
		find_player()
		if debug_logs:
			print("Zombie: player not found yet")
		return

	# timers
	if attack_timer > 0.0:
		attack_timer = max(attack_timer - delta, 0.0)

	var to_player = player.global_position - global_position
	var dist = to_player.length()

	if dist <= detection_range:
		# chase when outside attack range
		if dist > attack_range:
			var dir = to_player.normalized()
			velocity = dir * move_speed
			if debug_logs:
				print("Zombie: chasing player; dist=", dist, "dir=", dir)
			# CharacterBody2D.move_and_slide will move using the velocity property
			move_and_slide()
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
		player.apply_impulse(dir * knockback_force)
	elif player.has_method("set_velocity"):
		player.set_velocity(dir * knockback_force)

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

func take_damage(amount: float) -> void:
	var actual = max(amount - 0.0, 0.0)
	current_health -= actual
	modulate = Color(1, 0.6, 0.6)
	await get_tree().create_timer(0.08).timeout
	modulate = Color(1, 1, 1)
	if current_health <= 0.0:
		die()

func die() -> void:
	queue_free()

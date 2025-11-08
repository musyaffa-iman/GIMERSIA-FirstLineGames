extends Enemy

# Simple melee grunt: idle -> detect -> chase -> attack
@export var detection_range: float = 300.0
@export var attack_range: float = 36.0
@export var slash_scene: PackedScene
@export var attack_cooldown: float = 1.0
@export var knockback_force: float = 150.0
@export var debug_logs: bool = false
@export var attack_buffer: float = 12.0 # extra buffer so collisions don't prevent melee triggering

@onready var attack_timer: Timer = $AttackTimer
var can_attack: bool = true

var player_in_hitbox: bool = false

func _ready() -> void:
	super._ready()
	attack_timer.wait_time = attack_cooldown

func enemy_behavior(delta: float) -> void:
	if debug_logs:
		print("Zombie: _physics_process tick; player valid?", player and is_instance_valid(player))

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
			if dist <= attack_range + attack_buffer and can_attack:
				if debug_logs:
					print("Zombie: in attack range (dist=", dist, ") — attacking")
				perform_attack()
				can_attack = false
				attack_timer.start()
	else:
		# idle
		velocity = Vector2.ZERO
	
func perform_attack() -> void:
	if not player:
		return
	# melee: spawn a short-lived slash Area2D in front of the grunt
	if slash_scene:
		var slash = slash_scene.instantiate()
		var dir = (player.global_position - global_position).normalized()
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
				slash.set_damage(damage)
				# fall back to direct property assignment only if method not available
				# (we avoid has_variable -- assume slash scene provides a setter)
			if slash.has_method("set_owner_enemy"):
				slash.set_owner_enemy(self)
				# assume setter exists; skip direct property assignment to avoid errors
			# already added as child above
			if debug_logs:
				print("Zombie: spawned slash attack with damage", damage)
	else:
		# fallback: directly damage the player if no slash scene is set
		if player.has_method("take_damage"):
			player.take_damage(damage)
			if debug_logs:
				print("Zombie: fallback attacked player for", damage)

func _on_attack_timer_timeout() -> void:
	can_attack = true

extends BossBase

# GDD Stats: HP=100, ATK=38, DEF=18
@export var atk: int = 38
@export var defense: int = 18

# Front-facing detection (player can only damage from sides/back)
@export var front_facing_angle_tolerance: float = 45.0  # degrees

# Bite attack (Phase 1+)
@export_category("Beholder Attacks")
@export_group("Bite")
@export var bite_range: float = 36.0  # 0.75m in pixels (0.75 * 48)
@export var bite_base_value: float = 55.0
@export var bite_knockback: float = 96.0  # 2m knockback

# Lightning Orb (Phase 1+)
@export_group("Lightning Orb")
@export var lightning_orb_scene: PackedScene = null
@export var lightning_orb_base_value: float = 50.0
@export var lightning_orb_speed: float = 300.0
@export var lightning_orb_count: int = 5
@export var lightning_orb_interval: float = 0.2

# Sound effect tags (keys into AudioLibrary)
@export_group("Sound Effects")
@export var sfx_bite: String = ""
@export var sfx_lightning_orb: String = ""
@export var sfx_lightning_strike: String = "beholderLightning"
@export var sfx_lightning_burst: String = ""
@export var sfx_eye_beam: String = "beholderLaser"
@export var sfx_transform: String = ""
@export var sfx_hurt: String = ""
@export var sfx_die: String = ""

# Lightning Strike (Phase 1+)
@export_group("Lightning Strike")
@export var lightning_strike_scene: PackedScene = null
@export var lightning_strike_telegraph_scene: PackedScene = null
@export var lightning_strike_base_value: float = 55.0
@export var lightning_strike_count: int = 3
@export var lightning_strike_telegraph_duration: float = 0.5
@export var lightning_strike_cooldown: float = 1.5

# Lightning Orb Burst (Phase 2+)
@export_group("Lightning Burst")
@export var lightning_burst_min_projectiles: int = 8
@export var lightning_burst_max_projectiles: int = 12

# Eye Beam (Phase 2+)
@export_group("Eye Beam")
@export var eye_beam_scene: PackedScene = null
@export var eye_beam_base_value: float = 60.0
@export var eye_beam_speed: float = 400.0
@export var eye_beam_tracking: bool = true

# Eye of Aberration (Phase 3)
@export_group("Eye of Aberration")
@export var eye_aberration_scene: PackedScene = null
@export var eye_aberration_base_value: float = 65.0
@export var eye_aberration_speed: float = 150.0
@export var eye_aberration_explosion_radius: float = 100.0

# Phase state tracking
var phase_one: bool = true

# Attack state
var current_attack_type: String = ""
var orb_spawn_timer: float = 0.0
var orb_count: int = 0

# Lightning strike state
var is_telegraphing_strike: bool = false
var strike_timer: float = 0.0
var strike_target_position: Vector2 = Vector2.ZERO
var strike_telegraph_instance: Node2D = null
var strikes_completed: int = 0

# Transform state for Phase 3
var is_transformed: bool = false
var anchor_position: Vector2 = Vector2.ZERO

@onready var polyphonic_audio_player := $PolyphonicAudioPlayer if has_node("PolyphonicAudioPlayer") else null

func _play_sfx(tag: String) -> void:
	if not tag or tag == "":
		return
	if not polyphonic_audio_player:
		return
	if polyphonic_audio_player.has_method("play_sound_effect_from_library"):
		polyphonic_audio_player.play_sound_effect_from_library(tag)

func _ready() -> void:
	# Apply GDD HP before base setup
	max_health = 100
	
	# Let base class perform its setup
	super._ready()
	
	# Ensure this node is in the common enemy group
	add_to_group("enemy")
	
	# Store starting anchor position
	anchor_position = global_position
	
	# Lazy-load attack scenes if not set in Inspector
	if not lightning_orb_scene:
		var _o = load("res://Scenes/attacks/lightning_orb.tscn")
		if _o and _o is PackedScene:
			lightning_orb_scene = _o
	
	if not lightning_strike_scene:
		var _s = load("res://Scenes/attacks/lightning_strike.tscn")
		if _s and _s is PackedScene:
			lightning_strike_scene = _s
	
	if not lightning_strike_telegraph_scene:
		var _t = load("res://Scenes/attacks/circle.tscn")
		if _t and _t is PackedScene:
			lightning_strike_telegraph_scene = _t
	
	if not eye_beam_scene:
		var _b = load("res://Scenes/attacks/eye_beam.tscn")
		if _b and _b is PackedScene:
			eye_beam_scene = _b
	
	if not eye_aberration_scene:
		var _a = load("res://Scenes/attacks/eye_aberration.tscn")
		if _a and _a is PackedScene:
			eye_aberration_scene = _a

func enemy_behavior(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	# In Phase 3, Beholder moves toward player as Eye of Aberration
	if phase_three and is_transformed:
		var to_player = player.global_position - global_position
		velocity = to_player.normalized() * move_speed
	else:
		# Phases 1 & 2: Stay in place, no movement
		velocity = Vector2.ZERO

func perform_attack() -> void:
	if not player:
		return
	
	# Determine which attack to use based on phase
	var available_attacks = []
	
	# Phase 1 attacks (available in all phases)
	if phase_one or phase_two or phase_three:
		# Check if player is in bite range and in front
		var to_player = player.global_position - global_position
		var dist_to_player = to_player.length()
		if dist_to_player <= bite_range and is_player_in_front():
			available_attacks.append("bite")
		available_attacks.append("lightning_orb")
		available_attacks.append("lightning_strike")
	
	# Phase 2+ attacks
	if phase_two and not is_transformed:
		available_attacks.append("lightning_burst")
		available_attacks.append("eye_beam")
	
	# Phase 3 attack
	if phase_three:
		if not is_transformed:
			# Start transformation
			transform_to_eye_aberration()
			return
		else:
			# In Eye of Aberration form, just keep moving toward player
			# The explosion on contact is handled by take_damage/on_hitbox
			return
	
	# Pick a random attack from available options
	if available_attacks.size() > 0:
		var chosen = available_attacks[randi() % available_attacks.size()]
		execute_attack(chosen)

func execute_attack(attack_type: String) -> void:
	match attack_type:
		"bite":
			perform_bite()
		"lightning_orb":
			perform_lightning_orb()
		"lightning_strike":
			perform_lightning_strike()
		"lightning_burst":
			perform_lightning_burst()
		"eye_beam":
			perform_eye_beam()

func is_player_in_front() -> bool:
	"""Check if player is within front-facing cone"""
	if not player:
		return false
	
	var to_player = player.global_position - global_position
	var angle_to_player = to_player.angle()
	var facing_angle = rotation
	
	# Calculate angular difference
	var angle_diff = angle_difference(facing_angle, angle_to_player)
	
	# Player is in front if within tolerance
	return abs(angle_diff) <= deg_to_rad(front_facing_angle_tolerance)

func angle_difference(a: float, b: float) -> float:
	"""Calculate signed angle difference between two angles"""
	var diff = b - a
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff

func perform_bite() -> void:
	"""Melee bite attack - deals damage and knockback directly"""
	if not player:
		return
	
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	
	# Only bite if in range and player is in front
	if dist > bite_range or not is_player_in_front():
		return
	
	var direction = to_player.normalized()
	
	# Compute final damage using DamageCalc
	var player_def = float(player.get("defense")) if player.get("defense") != null else 25.0
	var final_damage = DamageCalc.calculate_damage(int(bite_base_value), atk, player_def)
	
	# Apply damage and knockback
	player.take_damage(final_damage, direction, bite_knockback)
	# Play bite SFX
	_play_sfx(sfx_bite)
	#print("Beholder: BITE! Damage=", final_damage)

func perform_lightning_orb() -> void:
	"""Shoot 5 lightning orbs over 1 second (0.2s intervals)"""
	if not lightning_orb_scene:
		print("Beholder: No lightning_orb scene assigned!")
		return
	
	# Start spawning orbs
	orb_count = 0
	orb_spawn_timer = 0.0
	current_attack_type = "lightning_orb"
	# Play orb-launch SFX (one-shot)
	_play_sfx(sfx_lightning_orb)
	#print("Beholder: Starting Lightning Orb attack")

func perform_lightning_strike() -> void:
	"""Telegraph and strike 3 times at player location"""
	if not lightning_strike_scene:
		print("Beholder: No lightning_strike scene assigned!")
		return
	
	# Reset strike state
	strikes_completed = 0
	is_telegraphing_strike = true
	strike_timer = 0.0
	strike_target_position = player.global_position
	current_attack_type = "lightning_strike"
	# Play telegraph/start SFX
	_play_sfx(sfx_lightning_strike)
	#print("Beholder: Starting Lightning Strike attack (3x)")
	
	# Start first telegraph
	start_lightning_strike_telegraph()

func perform_lightning_burst() -> void:
	"""Burst random number of projectiles in all directions"""
	if not lightning_orb_scene:
		print("Beholder: No lightning_orb scene assigned!")
		return
	
	var num_projectiles = randi_range(lightning_burst_min_projectiles, lightning_burst_max_projectiles)
	var angle_step = TAU / num_projectiles

	# Play burst SFX once at start
	_play_sfx(sfx_lightning_burst)
	
	for i in range(num_projectiles):
		var angle = i * angle_step
		var direction = Vector2(cos(angle), sin(angle))
		
		var orb = lightning_orb_scene.instantiate()
		if orb:
			orb.global_position = global_position
			if orb.has_method("set_velocity"):
				orb.set_velocity(direction * lightning_orb_speed)
			elif "velocity" in orb:
				orb.velocity = direction * lightning_orb_speed
			
			# Set damage properties for DamageCalc
			if orb.has_method("set_base_value"):
				orb.set_base_value(lightning_orb_base_value)
			if orb.has_method("set_owner_atk"):
				orb.set_owner_atk(float(atk))
			
			get_tree().current_scene.add_child(orb)
	
	#print("Beholder: Lightning Burst! Fired ", num_projectiles, " orbs")

func perform_eye_beam() -> void:
	"""Fire laser beam across the map toward player"""
	if not eye_beam_scene:
		print("Beholder: No eye_beam scene assigned!")
		return
	
	var beam = eye_beam_scene.instantiate()
	if beam:
		# Position laser at Beholder's location
		beam.global_position = global_position
		
		# Calculate direction toward player
		var dir_to_player = (player.global_position - global_position).normalized()
		
		# Rotate laser to point toward player
		beam.rotation = dir_to_player.angle()
		
		# Set damage properties
		if beam.has_method("set_base_value"):
			beam.set_base_value(eye_beam_base_value)
		if beam.has_method("set_owner_atk"):
			beam.set_owner_atk(float(atk))
		if beam.has_method("set_owner_enemy"):
			beam.set_owner_enemy(self)
		
		get_tree().current_scene.add_child(beam)
		# Play eye beam SFX
		_play_sfx(sfx_eye_beam)
	
	#print("Beholder: Eye Beam (laser) fired!")

func transform_to_eye_aberration() -> void:
	"""Transform into massive Eye of Aberration (Phase 3)"""
	if not eye_aberration_scene:
		print("Beholder: No eye_aberration scene assigned!")
		return
	
	print("Beholder: TRANSFORMING into Eye of Aberration!")
	
	# Create the transformation effect
	var aberration = eye_aberration_scene.instantiate()
	if aberration:
		aberration.global_position = global_position
		
		# Set properties for damage calculation
		if aberration.has_method("set_base_value"):
			aberration.set_base_value(eye_aberration_base_value)
		if aberration.has_method("set_owner_atk"):
			aberration.set_owner_atk(float(atk))
		
		# Set movement speed
		if aberration.has_method("set_speed"):
			aberration.set_speed(eye_aberration_speed)
		elif "move_speed" in aberration:
			aberration.move_speed = eye_aberration_speed
		
		get_tree().current_scene.add_child(aberration)
	
	is_transformed = true

	# Play transform SFX
	_play_sfx(sfx_transform)

func enter_phase_two() -> void:
	"""Transition to Phase 2 at 50% HP"""
	phase_two = true
	phase_one = false
	
	# Reset anchor position for new attacks from different location
	anchor_position = global_position
	
	# Increase attack frequency
	attack_cooldown *= 0.8
	
	#print("Beholder: PHASE TWO! More dangerous attacks incoming!")

func enter_phase_three() -> void:
	"""Transition to Phase 3 at 25% HP"""
	phase_three = true
	phase_two = false
	
	# Keep anchor position at current location
	anchor_position = global_position
	
	#print("Beholder: PHASE THREE! Preparing Eye of Aberration transformation!")

func _physics_process(delta: float) -> void:
	# Update timers for ongoing attacks
	if current_attack_type == "lightning_orb":
		update_lightning_orb_spawn(delta)
	elif current_attack_type == "lightning_strike":
		update_lightning_strike_spawn(delta)
	
	# Call base physics (which handles phase transitions)
	super._physics_process(delta)

func update_lightning_orb_spawn(delta: float) -> void:
	"""Handle spawning of lightning orbs at intervals"""
	orb_spawn_timer += delta
	
	if orb_spawn_timer >= lightning_orb_interval and orb_count < lightning_orb_count:
		# Spawn one orb
		if lightning_orb_scene:
			var orb = lightning_orb_scene.instantiate()
			if orb:
				orb.global_position = global_position
				var dir = (player.global_position - global_position).normalized()
				
				if orb.has_method("set_velocity"):
					orb.set_velocity(dir * lightning_orb_speed)
				elif "velocity" in orb:
					orb.velocity = dir * lightning_orb_speed
				
				# Set damage properties
				if orb.has_method("set_base_value"):
					orb.set_base_value(lightning_orb_base_value)
				if orb.has_method("set_owner_atk"):
					orb.set_owner_atk(float(atk))
				
					get_tree().current_scene.add_child(orb)
					# Play orb SFX for each spawned orb
					_play_sfx(sfx_lightning_orb)
		
		orb_count += 1
		orb_spawn_timer = 0.0
		
		if orb_count >= lightning_orb_count:
			current_attack_type = ""

func update_lightning_strike_spawn(delta: float) -> void:
	"""Handle the telegraph and strike sequence for lightning strikes"""
	if not is_telegraphing_strike:
		return
	
	strike_timer += delta
	
	# If telegraph time is up, spawn the strike and start cooldown
	if strike_timer >= lightning_strike_telegraph_duration:
		spawn_lightning_strike()
		strikes_completed += 1
		
		# Remove telegraph circle
		if strike_telegraph_instance and is_instance_valid(strike_telegraph_instance):
			strike_telegraph_instance.queue_free()
			strike_telegraph_instance = null
		
		# Check if we've completed all strikes
		if strikes_completed >= lightning_strike_count:
			current_attack_type = ""
			is_telegraphing_strike = false
		else:
			# Start next telegraph
			is_telegraphing_strike = true
			strike_timer = 0.0
			strike_target_position = player.global_position
			start_lightning_strike_telegraph()

func start_lightning_strike_telegraph() -> void:
	"""Show telegraph circle at player location"""
	if not lightning_strike_telegraph_scene:
		return
	
	var telegraph = lightning_strike_telegraph_scene.instantiate()
	if telegraph:
		telegraph.global_position = player.global_position
		# Make it red for danger telegraph
		if telegraph.has_node("Sprite2D"):
			telegraph.get_node("Sprite2D").modulate = Color.RED
		if "lifetime" in telegraph:
			telegraph.lifetime = lightning_strike_telegraph_duration
		get_tree().current_scene.add_child(telegraph)
		strike_telegraph_instance = telegraph
		#print("Beholder: Telegraph strike #", strikes_completed + 1, " at ", player.global_position)

func spawn_lightning_strike() -> void:
	"""Spawn the actual lightning strike damage area"""
	if not lightning_strike_scene:
		return
	
	var strike = lightning_strike_scene.instantiate()
	if strike:
		strike.global_position = strike_target_position
		
		# Set damage properties
		if strike.has_method("set_base_value"):
			strike.set_base_value(lightning_strike_base_value)
		if strike.has_method("set_owner_atk"):
			strike.set_owner_atk(float(atk))
		if strike.has_method("set_owner_enemy"):
			strike.set_owner_enemy(self)
		
		get_tree().current_scene.add_child(strike)
		# Play strike SFX when spawned
		_play_sfx(sfx_lightning_strike)
		#print("Beholder: Lightning strike #", strikes_completed + 1, " spawned at ", strike_target_position)

func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0) -> void:
	# Beholder cannot be damaged from the front
	if is_player_in_front():
		print("Beholder: Protected by front-facing defense!")
		return
	
	# Visual feedback
	modulate = Color.CYAN
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	# Delegate to base Enemy (damage already computed by attacker using DamageCalc)
	super.take_damage(amount, from_direction, knockback_force)
	
	#print("Beholder took ", amount, " damage. HP: ", health)

func die() -> void:
	print("Beholder defeated!")
	super.die()

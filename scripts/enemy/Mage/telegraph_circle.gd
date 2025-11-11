extends Node2D

# Simple visual indicator for mage attack telegraph
# Does NOT deal damage - only shows where the attack will land

@export var lifetime: float = 1.0  # How long before auto-despawn
@export var pulse_speed: float = 2.0  # Speed of pulsing animation

var time_alive: float = 0.0

func _ready():
	modulate = Color(1, 0, 0, 0.6)  # Red, semi-transparent
	z_index = -1  # Draw behind everything

func _process(delta):
	time_alive += delta
	
	# Optional: pulse animation
	var pulse = 0.5 + 0.5 * sin(time_alive * pulse_speed * TAU)
	modulate.a = 0.4 + 0.3 * pulse
	
	# Auto-despawn if lifetime set
	if lifetime > 0 and time_alive >= lifetime:
		queue_free()

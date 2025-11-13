class_name SpeedUpArea
extends Area2D

## How much to multiply the time speed by when player enters
@export var time_speed_multiplier: int = 7

## How fast the timer should tick (in seconds)
@export var timer_interval: float = 0.01

## Reference to the level's timer node (auto-detected if not set)
@export var timer_node: Timer

## Reference to the level script that has time_speed variable (auto-detected if not set)
@export var level_node: Node

var original_time_speed: int = 1
var is_player_inside: bool = false

func _ready() -> void:
	# Auto-detect timer and level if not manually set
	if not timer_node:
		timer_node = get_tree().get_current_scene().get_node_or_null("Timer")
	
	if not level_node:
		level_node = get_tree().get_current_scene()
	
	# Connect body entered/exited signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_player_inside:
		is_player_inside = true
		activate_speed_up()

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" and is_player_inside:
		is_player_inside = false
		deactivate_speed_up()

func activate_speed_up() -> void:
	if level_node and "time_speed" in level_node:
		level_node.time_speed = time_speed_multiplier
	
	if timer_node:
		timer_node.start(timer_interval)

func deactivate_speed_up() -> void:
	if level_node and "time_speed" in level_node:
		level_node.time_speed = original_time_speed
	
	if timer_node:
		timer_node.start(1.0)

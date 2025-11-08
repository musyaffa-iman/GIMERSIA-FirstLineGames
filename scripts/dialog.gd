@tool
extends Control

# Node Variable
@onready var Anim = $AnimationPlayer
@onready var NodeText = $Text

# Editor Variable
@export_multiline var Text : String
@export var Play : bool
@export_category("Animation")
@export_group("Typewriter Animation")
@export var TypewriterAnimation : bool
@export var Duration_Second : float


func _draw() -> void:
	if TypewriterAnimation :
		var animation = Anim.get_animation("Typewriter")
		if animation.get_track_count() == 1 : animation.remove_track(0)
		var track = animation.add_track(Animation.TYPE_VALUE)
		var text_length = NodeText.get_total_character_count()
		animation.length = Duration_Second
		animation.set_loop_mode(false)
		animation.track_set_path(track, "Text:visible_characters")
		animation.track_insert_key(track, 0.0, 0)
		animation.track_insert_key(track, Duration_Second, text_length)
		Anim.play("Typewriter")
	else :
		NodeText.text = Text
		NodeText.visible_characters = -1

func _process(delta: float) -> void:
	if Play && TypewriterAnimation:
		Duration_Second = Duration_Second
		Anim.play("Typewriter")
	else :
		NodeText.text = Text
		NodeText.visible_characters = -1

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	Play = false

extends Control

@onready var menu_music: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

var clicked

func _ready() -> void:
	# Ensure the menu music is playing. If the underlying AudioStream resource supports looping,
	# enable it on the resource itself (AudioStreamPlayer2D does not expose `loop`).
	if menu_music:
		var st = menu_music.stream
		if st and "loop" in st:
			st.loop = true
		if not menu_music.playing:
			menu_music.play()

	# Assign UI hover/click sounds to buttons and connect Play
	var hover_stream: AudioStream = load("res://assets/audio/sfx/ui_hover1.wav") if ResourceLoader.exists("res://assets/audio/sfx/ui_hover1.wav") else null
	var click_stream: AudioStream = load("res://assets/audio/sfx/ui_click1.wav") if ResourceLoader.exists("res://assets/audio/sfx/ui_click1.wav") else null
	var play_stream: AudioStream = load("res://assets/audio/sfx/ui_play1.wav") if ResourceLoader.exists("res://assets/audio/sfx/ui_play1.wav") else null

	var btn_parent = $Control_Button if has_node("Control_Button") else null
	if btn_parent:
		for child in btn_parent.get_children():
			if child is Button:
				# Assign hover/click SFX (BaseButton exports HoverSound/ClickSound)
				if hover_stream:
					child.HoverSound = hover_stream
				# Give Play a special start sound, others get generic click
				if child.name == "Play":
					if play_stream:
						child.ClickSound = play_stream
					# connect Play pressed to start handler
					child.connect("pressed", Callable(self, "_on_play_pressed"))
				else:
					if click_stream:
						child.ClickSound = click_stream


func _on_play_pressed() -> void:
	# Let the button's click SFX play, then change to the level scene
	# Small delay to hear the click
	await get_tree().create_timer(0.08).timeout
	# Stop menu music (instant stop). For a fade, implement a coroutine.
	if menu_music and menu_music.playing:
		menu_music.stop()
	# Change to Tutorial scene
	$AnimationPlayer.play("Fade_out")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	var level_path := "res://scenes/Level/Tutorial.tscn"
	if ResourceLoader.exists(level_path):
		get_tree().change_scene_to_file(level_path)
	else:
		printerr("MainMenu: Level scene not found:", level_path)

extends AudioStreamPlayer2D

@export var audio_library: AudioLibrary
@export var custom_max_polyphony: int = 32

func _ready():
	# Use a polyphonic stream so we can play overlapping short SFX
	stream = AudioStreamPolyphonic.new()
	# Set the polyphony (max simultaneous voices)
	if stream and stream is AudioStreamPolyphonic:
		stream.polyphony = custom_max_polyphony

func play_sound_effect_from_library(_tag: String) -> void:
	if _tag:
		if not audio_library:
			printerr("polyphonic_audio_player: no audio_library assigned")
			return
		var audio_stream = audio_library.get_audio_stream(_tag)
		if not audio_stream:
			printerr("polyphonic_audio_player: audio stream not found for tag: ", _tag)
			return

		# Ensure player is active
		if not playing:
			play()

		var polyphonic_stream_playback := self.get_stream_playback()
		if polyphonic_stream_playback and polyphonic_stream_playback.has_method("play_stream"):
			polyphonic_stream_playback.play_stream(audio_stream)
		else:
			printerr("polyphonic_audio_player: stream playback does not support play_stream()")
	else:
		printerr("no tag provided, cannot play sound effect!")

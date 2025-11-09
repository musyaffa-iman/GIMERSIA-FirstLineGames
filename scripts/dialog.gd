extends Control

# Variabel Lokal
@onready var Anim: AnimationPlayer = $AnimationPlayer
@onready var NodeText: RichTextLabel = $Text
var temp : String

# Editor variables
@export_multiline var Text: String = ""
@export_category("Animation")
@export_group("Typewriter Animation")
@export var TypewriterAnimation: bool = false
@export var Type_Duration: float = 2.0
@export var Play_Type: bool = false
@export_group("Fade Animation")
@export var Fadein: bool = false
@export var Fadein_Duration: float = 1.0
@export var Fadeout: bool = false
@export var Fadeout_Duration: float = 1.0
@export var Play_Fade: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		NodeText.text = Text
		NodeText.visible_characters = -1
	else:
		NodeText.text = ""
	_create_animations()

func _create_animations():
	if not Anim.has_animation("Typewriter"):
		Anim.add_animation("Typewriter")
	if not Anim.has_animation("FadeIn"):
		Anim.add_animation("FadeIn")
	if not Anim.has_animation("FadeOut"):
		Anim.add_animation("FadeOut")
	_setup_typewriter_anim()
	_setup_fadein_anim()
	_setup_fadeout_anim()

func setText(text:String) :
	NodeText.text = text
	NodeText.visible_characters = 0

func _setup_typewriter_anim():
	var anim = Anim.get_animation("Typewriter")
	anim.clear()
	var text_length = NodeText.get_total_character_count()
	anim.length = Type_Duration
	anim.loop_mode = Animation.LOOP_NONE
	var track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "Text:visible_characters")
	anim.track_insert_key(track, 0.0, 0)
	anim.track_insert_key(track, Type_Duration, text_length)

func _setup_fadein_anim():
	var anim = Anim.get_animation("FadeIn")
	temp = NodeText.text
	NodeText.text = ""
	anim.clear()
	anim.length = Fadein_Duration
	anim.loop_mode = Animation.LOOP_NONE
	var track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "Text:self_modulate")
	anim.track_insert_key(track, 0.0, Color(1, 1, 1, 0))
	anim.track_insert_key(track, Fadein_Duration, Color(1, 1, 1, 1))

func _setup_fadeout_anim():
	var anim = Anim.get_animation("FadeOut")
	anim.clear()
	anim.length = Fadeout_Duration
	anim.loop_mode = Animation.LOOP_NONE
	var track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "Text:self_modulate")
	anim.track_insert_key(track, 0.0, Color(1, 1, 1, 1))
	anim.track_insert_key(track, Fadeout_Duration, Color(1, 1, 1, 0))

func _process(delta: float) -> void:
	if Play_Type and TypewriterAnimation:
		Play_Type = false
		NodeText.text = Text
		_setup_typewriter_anim()
		Anim.play("Typewriter")

	elif Play_Fade:
		Play_Fade = false
		if Fadein:
			_setup_fadein_anim()
			Anim.play("FadeIn")
		elif Fadeout:
			_setup_fadeout_anim()
			Anim.play("FadeOut")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"FadeIn":
			if TypewriterAnimation:
				NodeText.text = temp
				temp = ""
				Anim.play("Typewriter")
			elif Fadeout :
				Anim.play("FadeOut")
		"Typewriter":
			if Fadeout:
				Anim.play("FadeOut")

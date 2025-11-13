extends CanvasLayer

@onready var hpbar = $HPBar

@export var player : Player
@onready var key_a: AnimatedSprite2D = $KEYA
@onready var key_b: AnimatedSprite2D = $KEYB
@onready var key_c: AnimatedSprite2D = $KEYC

func _ready() -> void:
	if player != null : hpbar.max_value = player.max_health

func _process(delta: float) -> void:
	if player != null :
		hpbar.value = player.current_health

func update(key: int):
	if key == 0 : 
		key_a.visible = !key_a.visible
	elif key == 1 : 
		key_b.visible = !key_b.visible
	elif  key == 2 : 
		key_a.visible = !key_a.visible

extends CanvasLayer

@onready var hpbar = $HPBar

@export var player : Player

func _ready() -> void:
	if player != null : hpbar.max_value = player.max_health

func _process(delta: float) -> void:
	if player != null :
		hpbar.value = player.current_health

func update(key: int):
	if key == 0 : 
		if !$KEYA.get_visible():
			$KEYA.set_visible(true)
		else : $KEYA.set_visible(false)
	elif key == 1 : 
		if !$KEYB.get_visible():
			$KEYB.set_visible(true)
		else : $KEYB.set_visible(false)
	elif  key == 2 : 
		if !$KEYC.get_visible():
			$KEYC.set_visible(true)
		else : $KEYC.set_visible(false)

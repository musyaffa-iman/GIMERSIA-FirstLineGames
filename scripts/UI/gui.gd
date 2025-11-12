extends CanvasLayer

@onready var hpbar = $HPBar

@export var player : Player

func _ready() -> void:
	hpbar.max_value = player.max_health

func _process(delta: float) -> void:
	if player != null :
		hpbar.value = player.current_health

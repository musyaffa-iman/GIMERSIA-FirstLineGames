extends Button

# Variabel Lokal
@onready var sfx = $Sfx
var active := false
# Optional
@export var ClickSound : AudioStream = null
@export var HoverSound : AudioStream = null

func _on_pressed() -> void:
	var parent = get_parent_control()
	for i in range(parent.get_child_count()) :
		if active == true :
				parent.get_child(i).set_self_modulate(Color("ffffff"))
		elif (parent.get_child(i) != self && parent.get_child(i).is_in_group("Button")) :
			parent.get_child(i).fade();
	self.set_self_modulate(Color("ffffff"))
	if active : active = false
	else : active = true
	if ClickSound != null : 
		sfx.set_stream(ClickSound)
		sfx.play()

func fade():
	self.set_self_modulate(Color("ffffffa0"))


func _on_mouse_entered() -> void:
	if HoverSound != null :
		sfx.set_stream(HoverSound)
		sfx.play()

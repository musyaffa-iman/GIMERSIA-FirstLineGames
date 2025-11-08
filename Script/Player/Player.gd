extends CharacterBody2D

@export var move_speed: float = 220.0
@export var max_health: float = 100.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 0.25
@export var projectile_scene: PackedScene = preload("res://Scenes/player_projectile.tscn")

var current_health: float
var _attack_timer := 0.0

func _ready():
    current_health = max_health
    add_to_group("player")

func _physics_process(delta: float) -> void:
    # Movement using default ui_* actions
    var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = input_vec * move_speed
    move_and_slide()

    # Face mouse
    look_at(get_global_mouse_position())

    # Attack cooldown
    if _attack_timer > 0.0:
        _attack_timer -= delta

    # Attack input: use action if present, otherwise fallback to left mouse button
    var do_attack := Input.is_action_just_pressed("attack")

    if do_attack and _attack_timer <= 0.0:
        _attack_timer = attack_cooldown
        _shoot_projectile()

func _shoot_projectile() -> void:
    if not projectile_scene:
        return
    var proj := projectile_scene.instantiate()
    if not proj:
        return
    get_parent().add_child(proj)
    proj.global_position = global_position
    var dir := (get_global_mouse_position() - global_position).normalized()
    proj.rotation = dir.angle()
    if proj.has_method("configure"):
        proj.configure(dir, attack_damage)
    else:
        proj.set("velocity", dir * 600.0)
        proj.set("damage", attack_damage)

func take_damage(amount: float) -> void:
    current_health -= max(amount, 0.0)
    modulate = Color(1, 0.6, 0.6)
    await get_tree().create_timer(0.1).timeout
    modulate = Color(1, 1, 1)
    if current_health <= 0.0:
        _die()

func _die() -> void:
    queue_free()

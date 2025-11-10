extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var max_count: int = 6
@export var spawn_on_ready: bool = true

var _spawn_timer: Timer

func _ready() -> void:
    if spawn_on_ready:
        _spawn_timer = Timer.new()
        _spawn_timer.wait_time = spawn_interval
        _spawn_timer.one_shot = false
        _spawn_timer.autostart = true
        add_child(_spawn_timer)
        _spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))

func _on_spawn_timer_timeout() -> void:
    # count existing children that look like enemies (in enemies group)
    var existing = 0
    for node in get_tree().get_nodes_in_group("enemies"):
        if node and node.is_inside_tree():
            existing += 1
    if existing >= max_count:
        return
    spawn_enemy()

func spawn_enemy() -> Node:
    if not enemy_scene:
        push_error("EnemyFactory: no enemy_scene set")
        return null
    var e = enemy_scene.instantiate()
    if not e:
        return null
    # place at the factory's global position by default
    e.global_position = global_position
    get_tree().get_current_scene().add_child(e)
    return e

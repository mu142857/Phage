extends BasicState

@export var ground_y: float = 80.0
@export var attack_fps: float = 10.0
@export var trigger_frame_index: int = 3
@export var bullet_flight_time: float = 0.45
@export var bullet_gravity: float = 900.0

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var bullet_release_point: Node2D = $"../../BulletReleasePoint"

const BULLET_SCENE: PackedScene = preload("res://entities/actinos/actinos_bullet.tscn")

var attack_elapsed: float = 0.0
var bullet_spawned: bool = false

func enter() -> void:
	attack_elapsed = 0.0
	bullet_spawned = false
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Attack")
		if not ani_2D.animation_finished.is_connected(_on_animation_finished):
			ani_2D.animation_finished.connect(_on_animation_finished)

func process(delta: float) -> void:
	attack_elapsed += delta
	if not bullet_spawned and attack_elapsed >= _trigger_time():
		_spawn_bullet()
		bullet_spawned = true

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.animation_finished.is_connected(_on_animation_finished):
		ani_2D.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished() -> void:
	if is_instance_valid(ani_2D) and ani_2D.animation == &"Attack":
		change_state(1)

func _trigger_time() -> float:
	if attack_fps <= 0.0:
		return 0.0
	return float(trigger_frame_index) / attack_fps

func _spawn_bullet() -> void:
	if BULLET_SCENE == null:
		return
	var bullet := BULLET_SCENE.instantiate() as Node2D
	if bullet == null:
		return
	if get_tree().current_scene == null:
		return
	get_tree().current_scene.add_child(bullet)
	var start_pos := monster.global_position
	if is_instance_valid(bullet_release_point):
		start_pos = bullet_release_point.global_position
	var target_pos := Vector2(_get_player_x(), ground_y)
	if bullet.has_method("setup"):
		bullet.call("setup", start_pos, target_pos, bullet_flight_time, bullet_gravity)
	else:
		bullet.global_position = start_pos

func _get_player_x() -> float:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return monster.global_position.x
	var player := players[0]
	if player is Node2D:
		return (player as Node2D).global_position.x
	return monster.global_position.x

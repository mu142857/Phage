extends BasicState

@export var spin_distance: float = 10.0
@export var spin_damage: int = 5
@export var damage_frame_a: int = 5
@export var damage_frame_b: int = 6

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var spin_hitbox: Area2D = $"../../SpinHitBox"

var _last_damage_frame: int = -1

func enter() -> void:
	_last_damage_frame = -1
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Spin")
		if not ani_2D.animation_finished.is_connected(_on_animation_finished):
			ani_2D.animation_finished.connect(_on_animation_finished)

func process(_delta: float) -> void:
	_apply_spin_damage_if_needed()
	if monster != null and monster.has_method("is_player_close"):
		if not monster.call("is_player_close", spin_distance):
			change_state(1)

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.animation_finished.is_connected(_on_animation_finished):
		ani_2D.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished() -> void:
	if ani_2D.animation == "Spin":
		get_parent().change_state(1)

func _apply_spin_damage_if_needed() -> void:
	if not is_instance_valid(ani_2D):
		return
	if ani_2D.animation != "Spin":
		_last_damage_frame = -1
		return
	var frame := ani_2D.frame
	if frame != damage_frame_a and frame != damage_frame_b:
		_last_damage_frame = -1
		return
	if frame == _last_damage_frame:
		return
	_last_damage_frame = frame
	if not is_instance_valid(spin_hitbox):
		return
	for body in spin_hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", spin_damage)
		break

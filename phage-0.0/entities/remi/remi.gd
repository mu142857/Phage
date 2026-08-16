# res://entities/remi/remi.gd
# 雷米:真主角。只能左右走,不能跳。
class_name Remi
extends CharacterBody2D

const GRAVITY: float = 1000.0
const WALK_SPEED: float = 70.0

var facing_direction: int = 1  # 1 = 右, -1 = 左
var input_locked: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# 像素对齐:与 player 相同,只把渲染 sprite 的 Y 吸附到整数像素,消除脚底亚像素缝隙。
func _process(_delta: float) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.position.y = roundf(global_position.y) - global_position.y

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var move_input := 0.0
	if not input_locked:
		move_input = Input.get_axis(&"move_left", &"move_right")
	velocity.x = move_input * WALK_SPEED

	if move_input != 0.0:
		set_facing_direction(int(signf(move_input)))
		_play_anim(&"HumanWalk")
	else:
		_play_anim(&"HumanIdle")

	move_and_slide()

func set_lock(locked: bool) -> void:
	input_locked = locked
	if locked:
		velocity.x = 0.0

func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return
	facing_direction = sign(direction)
	var scale_x := absf(sprite.scale.x)
	if scale_x == 0.0:
		scale_x = 1.0
	sprite.scale.x = scale_x * float(facing_direction)

func _play_anim(anim_name: StringName) -> void:
	if sprite.animation != anim_name:
		sprite.play(anim_name)

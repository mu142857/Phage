extends Node2D

@export var camera_limit_top: int = -90
@export var camera_limit_bottom: int = 90
@export var camera_limit_left: int = -800
@export var camera_limit_right: int = 1600
@export var gold_egg_light_cycle_speed: float = 0.2  # 金蛋灯每秒推进的色相比例(1.0 = 一秒转完一圈)

@onready var _gold_egg_light: PointLight2D = $NPCs/GoldEggLight

var _gold_egg_hue: float = 0.0


func _ready() -> void:
	add_to_group("camera_follow")


func _process(delta: float) -> void:
	# 金蛋的灯持续平滑地循环变色(五颜六色)。
	if is_instance_valid(_gold_egg_light):
		_gold_egg_hue = fmod(_gold_egg_hue + gold_egg_light_cycle_speed * delta, 1.0)
		_gold_egg_light.color = Color.from_hsv(_gold_egg_hue, 1.0, 1.0)

func get_camera_limits() -> Dictionary:
	return {
		"left": camera_limit_left,
		"right": camera_limit_right,
		"top": camera_limit_top,
		"bottom": camera_limit_bottom,
	}

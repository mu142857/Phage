# res://levels/remi's_room/window_view.gd
# 窗外夜景:七夜月相 + 星星闪烁 + 窗沿小鸟。
# 画在 Background 之上、Window 之下,只透过窗户玻璃的透明区露出来。
class_name WindowView
extends Node2D

# 第几夜(1-7):月亮从细弯月逐夜圆到满月。以后接入梦流程的天数变量。
@export_range(1, 7) var night: int = 1:
	set(value):
		night = clampi(value, 1, 7)
		_apply_night()

@onready var moon: Sprite2D = $Moon
@onready var bird: Sprite2D = $Bird
@onready var bird_timer: Timer = $Bird/FlickTimer

func _ready() -> void:
	_apply_night()
	_start_twinkles()
	bird_timer.timeout.connect(_on_bird_flick)
	bird_timer.start(randf_range(0.9, 2.6))

func _apply_night() -> void:
	if is_instance_valid(moon):
		moon.frame = night - 1

# 每颗闪烁星各自随机呼吸,永远循环(tween 随节点释放,无悬置)。
func _start_twinkles() -> void:
	for star: CanvasItem in $Twinkles.get_children():
		var tween := create_tween().set_loops()
		tween.tween_interval(randf_range(0.0, 2.0))
		tween.tween_property(star, "modulate:a", randf_range(0.15, 0.4), randf_range(0.5, 1.4)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(star, "modulate:a", 1.0, randf_range(0.5, 1.4)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# 小鸟不定期抖一下尾巴(两帧来回)。
func _on_bird_flick() -> void:
	bird.frame = 1 - bird.frame
	bird_timer.start(randf_range(0.9, 2.6))

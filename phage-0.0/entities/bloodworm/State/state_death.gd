# 红丝虫 死亡状态(2 号)：它不会真死——血打空只是播 Disappear 钻回血肉里溜了
# (非常弱的家伙，打不过就跑)。不出死亡爆炸；钻完 queue_free，
# 正式关卡用 DreamEnd.watch_path 盯它收梦，BossIntro 会顺带把传送门重新打开。
extends BasicState

@export var escape_shake: float = 2.5
@export var escape_rumble: float = 1.2     # 钻走过程持续的小幅震屏
@export var disappear_timeout: float = 1.0

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false


func enter() -> void:
	is_active = true
	if not is_instance_valid(monster):
		return
	monster.velocity = Vector2.ZERO
	monster.set_physics_process(false)
	_disable_all_interactions()
	if monster.has_method("hide_health_ui"):
		monster.hide_health_ui()
	_play_sequence()


func process(_delta: float) -> void:
	pass


func exit() -> void:
	is_active = false


func _play_sequence() -> void:
	Game.shake_camera(escape_shake)
	if is_instance_valid(ani_2d) and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Disappear"):
		ani_2d.play(&"Disappear")
		var t := 0.0
		while t < disappear_timeout:
			if not is_active or not is_instance_valid(ani_2d):
				return
			if ani_2d.animation != &"Disappear" or not ani_2d.is_playing():
				break
			if escape_rumble > 0.0:
				Game.shake_camera(escape_rumble)
			await get_tree().process_frame
			t += get_process_delta_time()
	Game.stop_shake()
	if is_active and is_instance_valid(monster):
		monster.queue_free()


func _disable_all_interactions() -> void:
	monster.set_deferred("collision_layer", 0)
	monster.set_deferred("collision_mask", 0)
	var shape := get_node_or_null("../../CollisionShape2D") as CollisionShape2D
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)
	var area := get_node_or_null("../../PlayerCheck") as Area2D
	if is_instance_valid(area):
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)

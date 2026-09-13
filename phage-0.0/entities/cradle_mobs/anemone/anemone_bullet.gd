# 弹幕葵的大弹:弱追踪。出膛面朝上、很慢、渐显出来;track_delay 后开始转向主角,
# 转向很钝(turn_rate 度/秒),速度线性增加到上限。所以站在长虫和葵之间、等它快到了再闪开,
# 它转不过弯就撞进墙里——碰长虫(worm_wall 组)碎墙。
# 碰主角:立刻掉盾 + 震屏 + 爆炸粒子,再播 Explode 动画(纯表演,没有第二次判定)。碰别的怪穿过,碰世界墙爆。
# 子弹铁律:不许凭空消失——出屏 ScreenNotifier 删,寿命到了渐隐。
# 动画名:Flying(循环)、Explode(单次)。setup(start_pos)
extends Area2D

const EXPLOSION_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/anemone/anemone_bullet_explosion.tscn")

@export var damage_amount: int = 10       # 数值对主角无意义,碰一下=一次破盾
@export var lifetime: float = 7.0
@export var explode_shake: float = 2.5
@export var wall_arm_time: float = 0.3    # 出膛保护:刚出来别撞自己的葵
@export var appear_time: float = 0.35     # 渐显时长

@export_group("Homing")
@export var speed_start: float = 10.0     # 出膛速度(面朝上慢慢飘)
@export var speed_accel: float = 18.0     # 每秒加多少
@export var speed_max: float = 60.0       # 上限
@export var track_delay: float = 0.4      # 飘多久才开始追
@export var turn_rate_deg: float = 75.0   # 起步时的转向速度(度/秒)
@export var turn_rate_at_max: float = 0.3  # 飞到最高速时转向只剩起步的几成(越快越转不动弯,越好骗进墙)

var _dir := Vector2.UP
var _speed := 10.0
var _active := false
var _done := false
var _fading := false
var _elapsed := 0.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var flight_shape: CollisionShape2D = get_node_or_null("FlightShape") as CollisionShape2D
@onready var explosion_shape: CollisionShape2D = get_node_or_null("ExplosionShape") as CollisionShape2D


func _ready() -> void:
	if _has_anim(&"Flying"):
		ani_2d.play(&"Flying")
	# 爆炸范围形状不再用于判定(命中即刻结算),关掉省事
	if explosion_shape != null:
		explosion_shape.disabled = true
	var notifier := get_node_or_null("ScreenNotifier") as VisibleOnScreenNotifier2D
	if notifier != null:
		notifier.screen_exited.connect(queue_free)
	# 渐显
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, appear_time)


func setup(start_pos: Vector2, _dir_hint: Vector2 = Vector2.UP) -> void:
	global_position = start_pos
	_dir = Vector2.UP
	_speed = speed_start
	_elapsed = 0.0
	_active = true


func _physics_process(delta: float) -> void:
	if not _active or _done:
		return
	_elapsed += delta
	# 追踪:过了起飞段就慢慢把方向掰向主角;速度线性涨到上限
	if _elapsed >= track_delay:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			var want := (player.global_position + Vector2(0, -4) - global_position).normalized()
			if want != Vector2.ZERO:
				# 转向随速度线性变钝:speed_start 时 100%,speed_max 时只剩 turn_rate_at_max
				var k := clampf((_speed - speed_start) / maxf(speed_max - speed_start, 0.01), 0.0, 1.0)
				var rate := turn_rate_deg * lerpf(1.0, turn_rate_at_max, k)
				var max_turn := deg_to_rad(rate) * delta
				var diff := _dir.angle_to(want)
				_dir = _dir.rotated(clampf(diff, -max_turn, max_turn)).normalized()
		_speed = minf(_speed + speed_accel * delta, speed_max)
	global_position += _dir * _speed * delta
	if _fading:
		return
	_check_touch()
	if _elapsed >= lifetime:
		_start_fade_out()


func _start_fade_out() -> void:
	if _fading or _done:
		return
	_fading = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _check_touch() -> void:
	for body in get_overlapping_bodies():
		if body == null:
			continue
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.call("take_damage", damage_amount)
			_explode()
			return
		if body.is_in_group("worm_wall"):
			if body.has_method("hit_by_anemone"):
				body.call("hit_by_anemone")
			_explode()
			return
		if body.is_in_group("monster"):
			continue
		if _elapsed >= wall_arm_time:
			_explode()
			return


# 命中即刻结算:震屏 + 粒子,然后播 Explode 当表演(没有第二次伤害)
func _explode() -> void:
	if _done:
		return
	_done = true
	set_deferred("monitoring", false)
	Game.shake_camera(explode_shake)
	_spawn_explosion_effect()
	if _has_anim(&"Explode"):
		ani_2d.play(&"Explode")
		await ani_2d.animation_finished
	queue_free()


func _has_anim(anim: StringName) -> bool:
	return ani_2d != null and ani_2d.sprite_frames != null \
		and ani_2d.sprite_frames.has_animation(anim) \
		and ani_2d.sprite_frames.get_frame_count(anim) > 0


func _spawn_explosion_effect() -> void:
	if EXPLOSION_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := EXPLOSION_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true

# 浓雾弹:喷射战士源源不断喷出的小方块雾,直线飞,每颗速度/大小/颜色都不同,出现时渐显。
# 碰主角 → 一次破盾,自己散掉;碰蚯蚓(earthworm 组)→ 被挡住散掉(这是躲雾的唯一办法);
# 碰别的怪 → 穿过;碰世界墙 → 散掉。散掉=快速缩小淡出,不凭空消失;出屏 ScreenNotifier 删,寿命到渐隐。
# 纯 Polygon2D 方块+本色残影,没有贴图;以后要换贴图把 Square 换成 AnimatedSprite2D 即可。
# setup(start_pos, dir: Vector2, speed, size_scale = 1, color = 默认紫, gravity = 0):吃一点重力会往下弯
extends Area2D

@export var lifetime: float = 3.0
@export var appear_time: float = 0.25     # 渐显时长
## 被蚯蚓挡住时往回弹的比例,按雾的大小插值:小的轻、弹得多;大的重、几乎不弹。再各自 ±jitter 随机一点
@export var bounce_small: float = 0.6     # 最小雾(size_small)的回弹比例
@export var bounce_big: float = 0.04      # 最大雾(size_big)的回弹比例
@export var size_small: float = 0.7       # 和喷射战士 fog_size 的区间对齐
@export var size_big: float = 1.7
@export var bounce_jitter: float = 0.1
@export var block_fade_time: float = 0.45 # 被挡住后散掉用时
@export var wall_arm_time: float = 0.15
@export var trail_interval: float = 0.05
@export var trail_lifetime: float = 0.28
@export var trail_alpha: float = 0.35

var _dir := Vector2.LEFT
var _speed := 50.0
var _vel := Vector2.ZERO
var _fall_gravity := 0.0   # 别叫 gravity,Area2D 自带这个属性
var _size := 1.0
var _active := false
var _done := false
var _elapsed := 0.0
var _trail_timer := 0.0

@onready var _square: Polygon2D = get_node_or_null("Square") as Polygon2D


func _ready() -> void:
	var notifier := get_node_or_null("ScreenNotifier") as VisibleOnScreenNotifier2D
	if notifier != null:
		notifier.screen_exited.connect(queue_free)
	# 渐显
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, appear_time)


func setup(start_pos: Vector2, dir: Vector2, speed: float, size_scale: float = 1.0, color: Color = Color(0.78, 0.66, 0.9, 0.85), gravity_amount: float = 0.0) -> void:
	global_position = start_pos
	_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	_speed = speed
	_vel = _dir * _speed
	_fall_gravity = gravity_amount
	_active = true
	_size = size_scale
	if _square != null:
		_square.scale = Vector2(size_scale, size_scale)
		_square.color = color


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_vel.y += _fall_gravity * delta
	global_position += _vel * delta   # 散掉时 _vel 已被压低,只是慢慢飘
	if _done:
		return
	_elapsed += delta
	_spawn_trail(delta)
	_check_touch()
	if _elapsed >= lifetime:
		_dissipate()


func _check_touch() -> void:
	for body in get_overlapping_bodies():
		if body == null:
			continue
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.call("take_damage", 1)
			_dissipate()
			return
		if body.is_in_group("earthworm"):
			# 被蚯蚓挡住:往回弹一小段再散掉,看得出是"撞上了"(它的碰撞箱随动画变化很大,别硬邦邦地瞬间消失)
			# 小雾弹得多、大雾几乎不弹,再随机一点,别每颗都一个样
			var k := clampf(inverse_lerp(size_small, size_big, _size), 0.0, 1.0)
			var bounce := lerpf(bounce_small, bounce_big, k) + randf_range(-bounce_jitter, bounce_jitter)
			_dissipate(block_fade_time, -maxf(bounce, 0.0))
			return
		if body.is_in_group("monster"):
			continue
		if _elapsed >= wall_arm_time:
			_dissipate()
			return


# 散掉:缩小+淡出,不凭空消失。duration=淡多久;drift=淡的时候速度乘多少(负数=往回弹)
func _dissipate(duration: float = 0.18, drift: float = 0.0) -> void:
	if _done:
		return
	_done = true
	set_deferred("monitoring", false)
	_vel *= drift
	_fall_gravity = 0.0
	var tw := create_tween().set_parallel(true)
	modulate.a = minf(modulate.a, 1.0)
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), duration)
	tw.chain().tween_callback(queue_free)


func _spawn_trail(delta: float) -> void:
	_trail_timer += delta
	if _trail_timer < trail_interval or _square == null:
		return
	_trail_timer = 0.0
	var scene := get_tree().current_scene
	if scene == null:
		return
	var g := Polygon2D.new()
	g.polygon = _square.polygon
	g.color = _square.color
	g.scale = _square.scale * 0.8
	g.z_index = z_index - 1
	g.modulate.a = trail_alpha
	scene.add_child(g)
	g.global_position = global_position
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "modulate:a", 0.0, trail_lifetime)
	tw.tween_property(g, "scale", g.scale * 0.4, trail_lifetime)
	tw.chain().tween_callback(g.queue_free)

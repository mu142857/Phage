# 红丝虫的吐弹。从喷吐触手的子弹复制出来单独调参(那个出膛位置低、滑翔段贴地就炸；
# 红丝虫嘴高得多，同参数会悬在半空平飞不下来)。
# 弹道差异：出膛上扬压低 + 下坠段保留更久；拉平比下坠快一点，
# 让爆点往外多挪几格，但仍会沉到地面撞地爆，不做长距离水平滑翔。
# 碰到玩家或墙壁/地面「立刻」起爆(Explode)，但前几帧只是预警——
# 震屏+爆炸粒子+伤害全在伤害帧(第 damage_frame_start 帧,0 起数)那一刻才触发，
# 与喷吐触手同一套反馈时机。寿命耗尽渐隐兜底、真划出屏幕才删(子弹不许凭空消失)。
# 飞行带半透明重影拖尾。动画名：Flying(循环)、Explode(单次)。
# setup 约定: setup(start_pos: Vector2, direction_x: float)  # 1=往右, -1=往左
extends Area2D

const EXPLOSION_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/spitter_tentacle/spitter_tentacle_bullet_explosion.tscn")

@export var damage_amount: int = 5
@export var lifetime: float = 6.0         # 超时不爆也不凭空消失，而是渐隐(兜底)
@export var damage_frame_start: int = 4   # Explode 伤害窗口起始帧(0 起数)
@export var damage_frame_end: int = 5     # Explode 伤害窗口结束帧(含)
@export var explode_shake: float = 2.0    # 爆炸震屏强度
@export var wall_arm_time: float = 0.25   # 出膛保护:这段时间内碰墙不炸(防出生贴着东西直接炸)

@export_group("Trajectory")
@export var horizontal_speed: float = 38.0  # 水平速度(全程不变)
@export var launch_up_speed: float = 40.0   # 出膛上扬初速(比喷吐触手低,压低整条弧线)
@export var fall_gravity: float = 200.0     # 上升减速/刚过顶下坠用的重力
@export var peak_fall_speed: float = 55.0   # 下坠到这个速度才开始收(下坠段保留更久)
@export var glide_damp: float = 1.5         # 拉平速率(略快=爆点水平往外多挪几格,但仍会落地)

@export_group("Trail")
@export var trail_interval: float = 0.05    # 每隔多久留一个残影
@export var trail_lifetime: float = 0.3     # 残影淡出时长
@export var trail_alpha: float = 0.4        # 残影初始不透明度

var _dir: float = -1.0
var _vertical_speed: float = 0.0
var _gliding: bool = false
var _active: bool = false
var _exploded: bool = false
var _fading: bool = false
var _boom_done: bool = false
var _damage_done: bool = false
var _elapsed: float = 0.0
var _explode_elapsed: float = 0.0
var _trail_timer: float = 0.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
## 两个形状分工：CollisionShape2D2=子弹真实大小(飞行碰撞用)，
## CollisionShape2D=爆炸范围(比子弹大一圈，伤害窗口用)。按阶段二选一启用。
@onready var flight_shape: CollisionShape2D = get_node_or_null("CollisionShape2D2") as CollisionShape2D
@onready var explosion_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	if ani_2d != null and ani_2d.sprite_frames != null:
		if ani_2d.sprite_frames.has_animation(&"Flying"):
			ani_2d.play(&"Flying")
	# 飞行阶段只用真实大小的形状(两个都在的前提下)
	if flight_shape != null and explosion_shape != null:
		explosion_shape.disabled = true
		flight_shape.disabled = false
	# 真正划出摄像机画面才删(不用世界坐标矩形，房间偏移也不会误删)
	var notifier := get_node_or_null("ScreenNotifier") as VisibleOnScreenNotifier2D
	if notifier != null and not notifier.screen_exited.is_connected(_on_screen_exited):
		notifier.screen_exited.connect(_on_screen_exited)


func _on_screen_exited() -> void:
	queue_free()


func setup(start_pos: Vector2, direction_x: float) -> void:
	global_position = start_pos
	_dir = signf(direction_x)
	if _dir == 0.0:
		_dir = -1.0
	_vertical_speed = -launch_up_speed
	_gliding = false
	_elapsed = 0.0
	_active = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _exploded:
		_process_explosion(delta)
		return
	if _fading:
		# 渐隐中继续飞，不再有任何判定
		_process_trajectory(delta)
		return

	_elapsed += delta
	_process_trajectory(delta)
	_spawn_trail(delta)
	_check_touch()
	if _elapsed >= lifetime:
		_start_fade_out()


# 兜底寿命到了：不凭空消失，边飞边 tween 渐隐
func _start_fade_out() -> void:
	if _fading or _exploded:
		return
	_fading = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


# 上升段/下坠段吃重力；坠速到 peak_fall_speed 后进入收束段，
# 垂直速度衰减但衰减前一直在沉——沉到地面就撞地爆
func _process_trajectory(delta: float) -> void:
	if not _gliding:
		_vertical_speed += fall_gravity * delta
		if _vertical_speed >= peak_fall_speed:
			_gliding = true
	else:
		_vertical_speed = lerpf(_vertical_speed, 0.0, minf(glide_damp * delta, 1.0))
	global_position += Vector2(_dir * horizontal_speed, _vertical_speed) * delta


# 飞行中碰到玩家或墙壁/地面(mask=1|2，非玩家的 body 就是世界碰撞)：不直接掉血，立刻起爆
func _check_touch() -> void:
	for body in get_overlapping_bodies():
		if body == null:
			continue
		if body.is_in_group("player"):
			_explode()
			return
		if _elapsed >= wall_arm_time:
			_explode()
			return


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_damage_done = false
	_boom_done = false
	_explode_elapsed = 0.0
	# 换形状：关掉飞行小箱，开爆炸大圆(伤害帧在 0.4s 后，deferred 一帧来得及)
	if flight_shape != null and explosion_shape != null:
		flight_shape.set_deferred("disabled", true)
		explosion_shape.set_deferred("disabled", false)
	# 注意：震屏和爆炸粒子不在这——起爆动画前几帧只是预警，真正的"炸"
	# (震屏+粒子+伤害)都在伤害帧那一刻，见 _process_explosion
	# monitoring 保持开着——伤害帧还要查重叠
	if ani_2d != null and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Explode"):
		ani_2d.play(&"Explode")
	else:
		# 没有 Explode 动画的兜底：按普通子弹处理，炸+伤害+消失
		Game.shake_camera(explode_shake)
		_spawn_explosion_effect()
		_try_window_damage()
		queue_free()


func _process_explosion(delta: float) -> void:
	_explode_elapsed += delta
	# 到伤害帧那一刻才"真炸"：震屏+粒子(只来一次)
	if not _boom_done and ani_2d != null and ani_2d.animation == &"Explode" \
			and ani_2d.frame >= damage_frame_start:
		_boom_done = true
		Game.shake_camera(explode_shake)
		_spawn_explosion_effect()
	# 伤害窗口内每帧都判，命中一次就停(玩家窗口中途踩进来也会挨)
	if not _damage_done and ani_2d != null and ani_2d.animation == &"Explode" \
			and ani_2d.frame >= damage_frame_start and ani_2d.frame <= damage_frame_end:
		_try_window_damage()
	# 爆炸动画播完就消失(1.5s 兜底防悬置)
	if ani_2d == null or not ani_2d.is_playing() or _explode_elapsed > 1.5:
		queue_free()


func _try_window_damage() -> void:
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", damage_amount)
		_damage_done = true
		return


func _spawn_explosion_effect() -> void:
	if EXPLOSION_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := EXPLOSION_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true


# ---- 半透明重影拖尾(player_jump_trail 同款：当前帧复制成淡出的 Sprite2D) ----

func _spawn_trail(delta: float) -> void:
	_trail_timer += delta
	if _trail_timer < trail_interval:
		return
	_trail_timer = 0.0
	if ani_2d == null or ani_2d.sprite_frames == null:
		return
	if not ani_2d.sprite_frames.has_animation(ani_2d.animation):
		return
	var tex: Texture2D = ani_2d.sprite_frames.get_frame_texture(ani_2d.animation, ani_2d.frame)
	if tex == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# 防图集相邻帧渗色:复制成 filter_clip 的 AtlasTexture
	var draw_tex: Texture2D = tex
	if tex is AtlasTexture:
		var clipped := AtlasTexture.new()
		clipped.atlas = (tex as AtlasTexture).atlas
		clipped.region = (tex as AtlasTexture).region
		clipped.filter_clip = true
		draw_tex = clipped
	var g := Sprite2D.new()
	g.texture = draw_tex
	g.offset = ani_2d.offset
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.z_index = z_index + ani_2d.z_index - 1
	# 相似色随机抖动：明暗在本色附近浮动，别一串一模一样的
	var v: float = randf_range(0.8, 1.2)
	g.modulate = Color(v, v, v, trail_alpha)
	scene.add_child(g)
	g.global_transform = ani_2d.global_transform
	# 残影一边淡出一边缩小：拖尾越远越细，别一串等大方块显得死板
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "modulate:a", 0.0, trail_lifetime)
	tw.tween_property(g, "scale", g.scale * 0.3, trail_lifetime)
	tw.chain().tween_callback(g.queue_free)

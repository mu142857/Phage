# 血法师的红色攻击弹：2×2 方块(Polygon2D 画的，不用贴图)。
# 出膛是黄色，很快渐变成红色；双层拖尾——上层是本色方块残影，
# 底层是 TrailParticles 发的浅橙黄方块粒子(越远越宽，alpha 头尾渐变)。
# 出手瞬间锁定目标点(玩家当时的位置)，之后直线匀速飞——不追踪、不预判，
# 玩家保持移动就能躲。穿透一切障碍物，真正划出摄像机画面(ScreenNotifier)才
# 消失——不用世界坐标矩形，关卡房间怎么偏移都不会误删。
# setup 约定: setup(start_pos: Vector2, target_pos: Vector2)
extends Area2D

const RED: Color = Color(1, 0.25, 0.25)
const SPAWN_YELLOW: Color = Color(1, 0.92, 0.35)

@export var damage_amount: int = 8
@export var fly_speed: float = 45.0
@export var lifetime: float = 6.0         # 兜底寿命(正常是划出屏幕消失)，到点渐隐
@export var spawn_tint_time: float = 0.25 # 出膛黄→红的渐变时长

@export_group("Trail")
@export var trail_interval: float = 0.02
@export var trail_lifetime: float = 0.5   # 长拖尾
@export var trail_alpha: float = 0.5

var _fly_dir: Vector2 = Vector2.LEFT
var _active: bool = false
var _fading: bool = false
var _damage_done: bool = false
var _elapsed: float = 0.0
var _trail_timer: float = 0.0

@onready var square: Polygon2D = get_node_or_null("Square") as Polygon2D
@onready var trail_particles: GPUParticles2D = get_node_or_null("TrailParticles") as GPUParticles2D


func _ready() -> void:
	var notifier := get_node_or_null("ScreenNotifier") as VisibleOnScreenNotifier2D
	if notifier != null and not notifier.screen_exited.is_connected(_on_screen_exited):
		notifier.screen_exited.connect(_on_screen_exited)


func _on_screen_exited() -> void:
	_release_trail_particles()
	queue_free()


func setup(start_pos: Vector2, target_pos: Vector2) -> void:
	global_position = start_pos
	_fly_dir = (target_pos - start_pos).normalized()
	if _fly_dir == Vector2.ZERO:
		_fly_dir = Vector2.LEFT
	_elapsed = 0.0
	_active = true
	# 出膛黄色，渐变回红色(残影跟着当前颜色走)
	if square != null:
		square.color = SPAWN_YELLOW
		var tw := square.create_tween()
		tw.tween_property(square, "color", RED, spawn_tint_time)


func _physics_process(delta: float) -> void:
	if not _active or _damage_done:
		return
	_elapsed += delta
	global_position += _fly_dir * fly_speed * delta
	if _fading:
		return
	_spawn_trail(delta)
	_try_damage_player()
	if _elapsed >= lifetime:
		_start_fade_out()


# 兜底寿命到了：不凭空消失，边飞边渐隐
func _start_fade_out() -> void:
	if _fading:
		return
	_fading = true
	set_deferred("monitoring", false)
	_release_trail_particles()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


# 上层拖尾(本色方块残影，颜色跟着黄→红渐变走)
func _spawn_trail(delta: float) -> void:
	_trail_timer += delta
	if _trail_timer < trail_interval:
		return
	_trail_timer = 0.0
	var scene := get_tree().current_scene
	if scene == null:
		return
	var g := Polygon2D.new()
	g.polygon = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	# 相似色随机抖动：每个残影在本色附近随机明暗，别一串一模一样的
	var base_color: Color = square.color if square != null else RED
	var shift: float = randf_range(-0.22, 0.22)
	g.color = base_color.lightened(shift) if shift >= 0.0 else base_color.darkened(-shift)
	g.modulate = Color(1, 1, 1, trail_alpha)
	g.z_index = z_index - 1
	scene.add_child(g)
	g.global_position = global_position
	# 残影一边淡出一边缩小：拖尾越远越细，别一串等大方块显得死板
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "modulate:a", 0.0, trail_lifetime)
	tw.tween_property(g, "scale", g.scale * 0.3, trail_lifetime)
	tw.chain().tween_callback(g.queue_free)


# 子弹消失前把粒子层交给场景飘完再删，避免拖尾被啪一下截断(basket_ball 的做法)
func _release_trail_particles() -> void:
	if trail_particles == null or not is_instance_valid(trail_particles):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	trail_particles.emitting = false
	# 换算成相对场景根的层级再脱手，不然重挂后相对 z 变负、掉到背景后面
	trail_particles.z_index = z_index + trail_particles.z_index
	trail_particles.reparent(scene)
	var particles := trail_particles
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free())


func _try_damage_player() -> void:
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", damage_amount)
		_damage_done = true
		_release_trail_particles()
		queue_free()
		return

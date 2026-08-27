# 血法师的绿色回血弹：2×2 方块(Polygon2D 画的)。
# 出膛是黄色，很快渐变成绿色；双层拖尾——上层是本色方块残影，
# 底层是 TrailParticles 发的浅蓝方块粒子(越远越宽，alpha 头尾渐变)。
# 追踪指定的怪物(怕它乱跑打不到)，追上就 +90 血、目标绿闪一下，然后消失。
# 不用碰撞——每帧朝目标飞，距离够近即命中。目标半路死了就自行消散。
# setup 约定: setup(start_pos: Vector2, target: Node2D)
extends Node2D

@export var heal_amount: int = 90
@export var fly_speed: float = 55.0
@export var lifetime: float = 5.0          # 兜底寿命
@export var hit_distance: float = 4.0      # 离目标多近算命中
## 瞄准目标原点的偏移(怪物原点在脚底，往上抬到身体中心)
@export var aim_offset: Vector2 = Vector2(0, -4)

@export_group("Trail")
@export var trail_interval: float = 0.02
@export var trail_lifetime: float = 0.5   # 长拖尾
@export var trail_alpha: float = 0.5

const GREEN: Color = Color(0.35, 0.9, 0.45)
const SPAWN_YELLOW: Color = Color(1, 0.92, 0.35)

@export var spawn_tint_time: float = 0.25  # 出膛黄→绿的渐变时长

var _target: Node2D = null
var _active: bool = false
var _fading: bool = false
var _last_dir: Vector2 = Vector2.LEFT
var _elapsed: float = 0.0
var _trail_timer: float = 0.0

@onready var square: Polygon2D = get_node_or_null("Square") as Polygon2D
@onready var trail_particles: GPUParticles2D = get_node_or_null("TrailParticles") as GPUParticles2D


func setup(start_pos: Vector2, target: Node2D) -> void:
	global_position = start_pos
	_target = target
	_elapsed = 0.0
	_active = true
	# 出膛黄色，渐变回绿色(残影跟着当前颜色走)
	if square != null:
		square.color = SPAWN_YELLOW
		var tw := square.create_tween()
		tw.tween_property(square, "color", GREEN, spawn_tint_time)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _fading:
		# 渐隐中沿最后的方向继续飘
		global_position += _last_dir * fly_speed * delta
		return
	if not is_instance_valid(_target) or _elapsed >= lifetime:
		# 目标半路死了(或超时)：不凭空消失，边飘边渐隐
		_start_fade_out()
		return

	var aim: Vector2 = _target.global_position + aim_offset
	var to_target: Vector2 = aim - global_position
	if to_target.length() <= hit_distance:
		_heal_target()
		_release_trail_particles()
		queue_free()
		return
	_last_dir = to_target.normalized()
	global_position += _last_dir * fly_speed * delta
	_spawn_trail(delta)


func _start_fade_out() -> void:
	if _fading:
		return
	_fading = true
	_release_trail_particles()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


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


func _heal_target() -> void:
	if not is_instance_valid(_target):
		return
	if "health" in _target and "max_health" in _target:
		_target.health = clampi(int(_target.health) + heal_amount, 0, int(_target.max_health))
	_flash_green(_target)


# 目标绿闪：临时把受击闪白的 Tint 换成绿色播一次 HitFlash，0.3s 后换回原色
func _flash_green(target: Node2D) -> void:
	var sprite := target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.material is ShaderMaterial:
		var mat := sprite.material as ShaderMaterial
		var original_tint: Variant = mat.get_shader_parameter("Tint")
		mat.set_shader_parameter("Tint", GREEN)
		var restore := func() -> void:
			if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
				(sprite.material as ShaderMaterial).set_shader_parameter("Tint", original_tint)
		target.get_tree().create_timer(0.3).timeout.connect(restore)
	var hep := target.get_node_or_null("HitEffectPlayer") as AnimationPlayer
	if hep != null:
		if not hep.active:
			hep.active = true
		hep.play(&"HitFlash")


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
	var base_color: Color = square.color if square != null else GREEN
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

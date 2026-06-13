# =============================================================================
# bullet_parabola.gd  —  抛物线子弹（瞄准落点砸地类）
# =============================================================================
# 行为：从起点抛物线飞向指定落点（数学保证 flight_time 秒后准点到达）→ 途中碰到
#       玩家造成一次伤害 → 到点后播落地表现（粒子/震屏/留置物）→ 消失。
# setup 约定: setup(start_pos, target_pos, flight_time_override, gravity_override)
#   （和 Actinos 原版完全一致，state_shoot.gd 的 "parabola" 分支直接兼容）
#
# 初速度反解公式（核心，别动）：
#   vx = (target.x - start.x) / t
#   vy = (target.y - start.y - 0.5 * g * t²) / t
#
# 场景结构：
#   Bullet (Area2D, 挂本脚本)
#   ├── Sprite2D 或 AnimatedSprite2D
#   └── CollisionShape2D
# =============================================================================

extends Area2D

@export var projectile_gravity: float = 400.0  # 弹道重力（Actinos 调用时传 400）
@export var flight_time: float = 1.1           # 飞行时长（Actinos: 1.1）
@export var damage_amount: int = 5             # 途中命中伤害（Actinos: 5）
@export var land_shake: float = 2.0            # 落地震屏（Actinos: 2）

# 落地生成物（可空）：粒子特效 + 留在原地的尖刺/危险物
const LAND_EFFECT_SCENE: PackedScene = null  # 例: preload(".../xxx_jump_effect.tscn")
const SPAWN_ON_LAND_SCENE: PackedScene = null  # 例: preload(".../xxx_spike.tscn")

var velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var active: bool = false
var damage_applied: bool = false


func _ready() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(sprite):
		sprite.play(&"default")


func setup(start_pos: Vector2, target_pos: Vector2,
		time_override: float = -1.0, gravity_override: float = -1.0) -> void:
	global_position = start_pos
	target_position = target_pos
	if time_override > 0.0:
		flight_time = time_override
	if gravity_override > 0.0:
		projectile_gravity = gravity_override

	# 反解初速度：保证恰好 flight_time 秒后命中 target_position
	var t := maxf(flight_time, 0.01)
	velocity.x = (target_position.x - start_pos.x) / t
	velocity.y = (target_position.y - start_pos.y - 0.5 * projectile_gravity * t * t) / t

	elapsed = 0.0
	active = true
	damage_applied = false


func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	velocity.y += projectile_gravity * delta
	global_position += velocity * delta

	_try_damage_player()

	# 飞满时长 = 到达落点
	if elapsed >= flight_time:
		_land()


func _land() -> void:
	active = false
	if LAND_EFFECT_SCENE != null and get_tree().current_scene != null:
		var eff := LAND_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(eff)
		eff.global_position = target_position
		if eff is GPUParticles2D:
			(eff as GPUParticles2D).emitting = true
	if SPAWN_ON_LAND_SCENE != null and get_tree().current_scene != null:
		var spawn := SPAWN_ON_LAND_SCENE.instantiate()
		get_tree().current_scene.add_child(spawn)
		spawn.global_position = target_position
	Game.shake_camera(land_shake)
	queue_free()


func _try_damage_player() -> void:
	if damage_applied:
		return
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
		damage_applied = true
		break

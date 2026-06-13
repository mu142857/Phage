# =============================================================================
# bullet_bounce.gd  —  弹射反弹子弹（碰墙反弹类，源自旧游戏栗子劫念，已现代化）
# =============================================================================
# 行为：直线飞 → 碰到墙/地反弹（最多 max_bounce 次）→ 次数用完原地停住淡出消失；
#       途中碰到玩家造成一次伤害并消失。
# setup 约定: setup(start_pos: Vector2, velocity_vector: Vector2)
#   （和 bullet_straight 同签名，state_shoot.gd 的 "bounce" 分支直接用）
#
# ※ 为什么用 CharacterBody2D 而不是 Area2D：
#   反弹需要 move_and_collide 返回的碰撞法线（collision.get_normal()），
#   Area2D 拿不到法线。本体负责撞墙，玩家判定交给子节点 HitArea (Area2D)。
#
# 场景结构：
#   Bullet (CharacterBody2D, 挂本脚本)
#   │   collision_mask 勾 world 层（撞墙用），collision_layer 可留空
#   ├── Sprite2D
#   ├── CollisionShape2D            ← 撞墙的形状
#   └── HitArea (Area2D)            ← 打玩家的判定
#       │   collision_mask 勾 player 层
#       └── CollisionShape2D
#
# 旧版差异说明（对照栗子劫念的弹射水晶）：
#   - 旧版 speed=1200 是旧游戏分辨率，新 160×90 屏参考 100~200
#   - 旧版玩家接口 take_hit → 已统一为 take_damage
#   - 旧版淡出用每帧 -0.01 → 改为按时长淡出，帧率无关
# =============================================================================

extends CharacterBody2D

@export var max_bounce: int = 3            # 最大反弹次数（栗子: 3）
@export var damage_amount: int = 17        # 命中伤害（栗子: 17）
@export var fade_time: float = 1.0         # 停住后的淡出时长
@export var rotate_to_velocity: bool = true  # 贴图朝向飞行方向（栗子原版行为）
@export var bounce_shake: float = 0.0      # 每次反弹震屏（0=不震）

# 反弹时的撞击粒子（可空）
const BOUNCE_EFFECT_SCENE: PackedScene = null  # 例: preload(".../xxx_explosion.tscn")

var bounce_count: int = 0
var stopped: bool = false
var damage_applied: bool = false


func setup(start_pos: Vector2, velocity_vector: Vector2) -> void:
	global_position = start_pos
	velocity = velocity_vector
	bounce_count = 0
	stopped = false
	damage_applied = false
	modulate.a = 1.0
	if rotate_to_velocity and velocity.length() > 0.0:
		rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if stopped:
		return

	var collision := move_and_collide(velocity * delta)
	if collision:
		_spawn_bounce_effect()
		if bounce_shake > 0.0:
			Game.shake_camera(bounce_shake)
		velocity = velocity.bounce(collision.get_normal())
		bounce_count += 1
		if bounce_count >= max_bounce:
			_stop_and_fade()
			return

	if rotate_to_velocity and velocity.length() > 0.0:
		rotation = velocity.angle()

	_try_damage_player()


# 次数用完：停住 → 按时长淡出 → 消失（替代旧版的每帧 -0.01）
func _stop_and_fade() -> void:
	stopped = true
	velocity = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)


func _try_damage_player() -> void:
	if damage_applied:
		return
	var hit_area := get_node_or_null("HitArea") as Area2D
	if not is_instance_valid(hit_area):
		return
	for body in hit_area.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
		damage_applied = true
		queue_free()
		break


func _spawn_bounce_effect() -> void:
	if BOUNCE_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var eff := BOUNCE_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(eff)
	eff.global_position = global_position
	if eff is GPUParticles2D:
		(eff as GPUParticles2D).emitting = true

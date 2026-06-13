# =============================================================================
# state_death.gd  —  死亡状态（固定 2 号）
# =============================================================================
# 职责：关掉一切碰撞/交互 → 隐藏血条 → 播死亡演出（动画+震屏+粒子）→ queue_free。
# 由 boss_base.gd 的 take_damage 在 health<=0 时自动切入（STATE_DEATH = 2）。
#
# 节点要求：
#   - 主体下有 AnimatedSprite2D（需要 "Death" 动画；没有 "Battlecry" 就只播 Death）
#   - 各攻击 HitBox 的路径按你实际节点名改下面的 _disable_all_interactions()
#   - 死亡粒子场景路径自己换
# =============================================================================

extends BasicState

@export var pre_death_duration: float = 0.9   # 死前挣扎段时长（Actinos 用 Battlecry 动画演 0.9s）
@export var death_duration: float = 1.1       # Death 动画时长（Actinos: 1.1s）
@export var death_shake_light: float = 2.0    # 死亡动画期间的轻震（Actinos: 2）
@export var death_shake_heavy: float = 6.0    # 爆体瞬间的重震（Actinos: 6）

# 死亡粒子（换成你 boss 自己的；可为空）
const DEATH_EFFECT_SCENE: PackedScene = null  # 例: preload("res://entities/xxx/xxx_death_effect.tscn")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false


func enter() -> void:
	is_active = true
	if not is_instance_valid(monster):
		return
	monster.velocity = Vector2.ZERO
	monster.set_physics_process(false)   # 停掉主体的边界 clamp 等物理逻辑
	_disable_all_interactions()
	_play_sequence()


func process(_delta: float) -> void:
	pass


func exit() -> void:
	is_active = false


func _play_sequence() -> void:
	# 先藏血条
	if is_instance_valid(monster) and monster.has_method("hide_health_ui"):
		monster.hide_health_ui()

	if not is_instance_valid(ani_2d):
		_free_boss()
		return

	# --- 死前挣扎段（有 Battlecry 动画就用它演挣扎，没有就跳过）---
	if ani_2d.sprite_frames != null and ani_2d.sprite_frames.has_animation(&"Battlecry"):
		ani_2d.play(&"Battlecry")
		await get_tree().create_timer(pre_death_duration).timeout
		if not is_active or not is_instance_valid(ani_2d):
			return

	# --- Death 动画段 ---
	ani_2d.play(&"Death")
	Game.shake_camera(death_shake_light)
	await get_tree().create_timer(death_duration).timeout
	if not is_active:
		return

	# --- 爆体：粒子 + 重震 + 删除 ---
	if DEATH_EFFECT_SCENE != null and is_instance_valid(monster):
		var eff := DEATH_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(eff)
		eff.global_position = monster.global_position
		if eff is GPUParticles2D:
			(eff as GPUParticles2D).emitting = true
	Game.shake_camera(death_shake_heavy)
	_free_boss()


# 关掉全部碰撞和检测，防止尸体还能打人/被打
# === 按你 boss 实际的 HitBox 节点名增删下面几行 ===
func _disable_all_interactions() -> void:
	if is_instance_valid(monster):
		monster.collision_layer = 0
		monster.collision_mask = 0
	_disable_shape("../../CollisionShape2D")
	_disable_area("../../PlayerCheck")
	# 示例：每个攻击 hitbox 都加一行
	# _disable_area("../../AttackHitBox")
	# _disable_area("../../SprintHitBox")


func _disable_shape(path: String) -> void:
	var shape := get_node_or_null(path) as CollisionShape2D
	if is_instance_valid(shape):
		shape.disabled = true


func _disable_area(path: String) -> void:
	var area := get_node_or_null(path) as Area2D
	if is_instance_valid(area):
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0


func _free_boss() -> void:
	if is_instance_valid(monster):
		monster.queue_free()

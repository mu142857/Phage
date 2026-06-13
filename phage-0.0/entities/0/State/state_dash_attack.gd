# =============================================================================
# state_dash_attack.gd  —  位移攻击样板（冲刺 / 跳扑 / 后撤类）
# =============================================================================
# 积木结构：前摇动画 → 位移段（水平冲 or 抛物线跳，二选一）→ 到位后开 hitbox 判定
#          → 后摇动画 → 回 Idle。
# 这是 Actinos JumpAttack 的通用化版本。靠参数能拼出：
#   - 跳扑（jump_mode=true, 目标=玩家位置）          ← Actinos 原版
#   - 地面冲刺（jump_mode=false, 目标=玩家位置）
#   - 后撤步（jump_mode=false, retreat=true 反向位移）← 锈神「后撤步」的位移段
#     ※ 后撤步投篮 = 本状态(retreat) 去掉 hitbox 判定 + 接 state_shoot 的发射段拼合；
#       无敌帧部分见 state_dodge.gd，三块积木拼一起就是完整的后撤步投篮。
#
# 节点要求：
#   - AnimatedSprite2D 需要动画：pre_animation（前摇）、move_animation（位移中）、
#     after_animation（后摇）
#   - 本招专用 HitBox (Area2D)，路径填 hitbox_path（不需要判定就留空）
# =============================================================================

extends BasicState

# --- 动画名 ---
@export var pre_animation: StringName = &"Prejump"     # 前摇（Actinos: Prejump）
@export var move_animation: StringName = &"Jump"       # 位移中（Actinos: Jump）
@export var after_animation: StringName = &"Afterjump" # 后摇/落地（Actinos: Afterjump）

# --- 位移模式 ---
@export var jump_mode: bool = true          # true=抛物线跳跃, false=贴地水平冲刺
@export var retreat: bool = false           # true=远离玩家方向位移（后撤步）
@export var jump_velocity_y: float = -180.0 # 跳跃初速（Actinos: -180）
@export var gravity: float = 350.0          # 跳跃重力（Actinos: 350）
@export var max_horizontal_speed: float = 70.0  # 水平速度上限（Actinos: 70）
@export var dash_distance: float = 50.0     # 冲刺模式的位移距离（retreat 时也用它）
@export var dash_time: float = 0.35         # 冲刺模式的位移耗时
@export var ground_y: float = 80.0          # 地面高度（Actinos: 80，按你关卡改）
@export var screen_min_x: float = 0.0       # 位移横向边界（Actinos: 0~160）
@export var screen_max_x: float = 160.0

# --- 判定（落点攻击；不需要判定就把 hitbox_path 留空）---
@export var hitbox_path: NodePath = ^"../../AttackHitBox"
@export var damage: int = 20                              # Actinos: 20
@export var hit_filter_amount: float = 0.45               # Actinos: 0.45
@export var hit_filter_color: Color = Color(0.9, 0.1, 0.1, 0.6)

# --- 落地表现 ---
@export var land_shake: float = 2.0          # 落地震屏（Actinos: 2）
@export var effect_offset: Vector2 = Vector2(0.0, 6.0)  # 落地粒子偏移（Actinos: 0,6）
const LAND_EFFECT_SCENE: PackedScene = null  # 落地粒子，例: preload("res://entities/xxx/xxx_jump_effect.tscn")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)

var target_x: float = 0.0
var moving: bool = false          # 位移段进行中
var landing: bool = false         # 已到位，后摇判定中
var hit_registered: bool = false
var dash_elapsed: float = 0.0


func enter() -> void:
	moving = false
	landing = false
	hit_registered = false
	dash_elapsed = 0.0
	monster.velocity = Vector2.ZERO

	_set_target_x()
	_apply_facing()
	_set_hitbox_active(false)

	if is_instance_valid(ani_2d):
		ani_2d.play(pre_animation)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)


func process(delta: float) -> void:
	if not moving:
		return
	if landing:
		_check_hit()
		return

	if jump_mode:
		_process_jump(delta)
	else:
		_process_dash(delta)


func exit() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation_finished.is_connected(_on_animation_finished):
		ani_2d.animation_finished.disconnect(_on_animation_finished)
	_set_hitbox_active(false)
	_reset_facing_scale()


# --- 抛物线跳跃位移（Actinos 原版逻辑）---
func _process_jump(delta: float) -> void:
	monster.velocity.y += gravity * delta
	monster.move_and_slide()
	_clamp_x()

	var landed := monster.is_on_floor()
	if monster.global_position.y >= ground_y:
		monster.global_position.y = ground_y
		if monster.velocity.y > 0.0:
			monster.velocity.y = 0.0
		landed = true

	if landed and monster.velocity.y >= 0.0:
		_arrive()


# --- 贴地水平冲刺位移 ---
func _process_dash(delta: float) -> void:
	dash_elapsed += delta
	monster.move_and_slide()
	_clamp_x()
	# 到时间 或 到达目标附近 就算到位
	if dash_elapsed >= dash_time or absf(monster.global_position.x - target_x) < 2.0:
		_arrive()


# 到位：停下 → 落地表现 → 开判定 → 播后摇
func _arrive() -> void:
	monster.velocity = Vector2.ZERO
	landing = true
	if LAND_EFFECT_SCENE != null:
		var eff := LAND_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(eff)
		eff.global_position = monster.global_position + effect_offset
		if eff is GPUParticles2D:
			(eff as GPUParticles2D).emitting = true
	Game.shake_camera(land_shake)
	_set_hitbox_active(true)
	if is_instance_valid(ani_2d):
		ani_2d.play(after_animation)
	_check_hit()


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d):
		return
	# 前摇放完 → 起动位移
	if ani_2d.animation == pre_animation:
		ani_2d.play(move_animation)
		moving = true
		if jump_mode:
			monster.velocity.y = jump_velocity_y
			# 0.6s 内水平赶到目标（Actinos 的算法）
			monster.velocity.x = clampf((target_x - monster.global_position.x) / 0.6,
				-max_horizontal_speed, max_horizontal_speed)
		else:
			var dir := signf(target_x - monster.global_position.x)
			monster.velocity.x = dir * (dash_distance / maxf(dash_time, 0.01))
		return
	# 后摇放完 → 回 Idle
	if ani_2d.animation == after_animation:
		change_state(1)


# --- 目标点：玩家位置；retreat=true 则取反方向 ---
func _set_target_x() -> void:
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	if player == null:
		target_x = monster.global_position.x
		return
	if retreat:
		# 远离玩家：往玩家反方向撤 dash_distance
		var away := signf(monster.global_position.x - player.global_position.x)
		if away == 0.0:
			away = 1.0
		target_x = clampf(monster.global_position.x + away * dash_distance, screen_min_x, screen_max_x)
	else:
		target_x = player.global_position.x


func _clamp_x() -> void:
	if monster.global_position.x < screen_min_x or monster.global_position.x > screen_max_x:
		monster.global_position.x = clampf(monster.global_position.x, screen_min_x, screen_max_x)
		monster.velocity.x = 0.0


func _check_hit() -> void:
	if hit_registered or not is_instance_valid(hitbox):
		return
	for body in hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage)
			Game.filter(hit_filter_amount, hit_filter_color)
		hit_registered = true
		break


func _set_hitbox_active(active: bool) -> void:
	if is_instance_valid(hitbox):
		hitbox.monitoring = active
		hitbox.monitorable = active


# 朝向：朝着 target_x（参考 Actinos 的 _set_jump_facing；翻转方向按你素材改）
func _apply_facing() -> void:
	if not is_instance_valid(ani_2d):
		return
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	var face_right := target_x > monster.global_position.x
	ani_2d.scale.x = -s if face_right else s
	if is_instance_valid(hitbox):
		var hs := maxf(absf(hitbox.scale.x), 1.0)
		hitbox.scale.x = -hs if face_right else hs


func _reset_facing_scale() -> void:
	if is_instance_valid(ani_2d):
		ani_2d.scale.x = maxf(absf(ani_2d.scale.x), 1.0)
	if is_instance_valid(hitbox):
		hitbox.scale.x = maxf(absf(hitbox.scale.x), 1.0)

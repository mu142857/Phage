# =============================================================================
# state_elbow_strike.gd  —  肘击冲锋（rust_goat 的 6 号状态）
# =============================================================================
# 行为：
#   1. 进入时面向「离场地边缘更远的那一侧」（保证冲刺距离长）
#   2. 播 ElbowStrike(Before) 前摇 → 播完起冲
#   3. 冲锋段：循环播 ElbowStrike，恒定速度冲向固定坐标（左 25 / 右 135），
#      ★ 时间由距离决定（速度恒定），不是固定时长 ★
#      期间持续小幅震屏 + hitbox 判定
#   4. 到达目标 x → 停震、播 ElbowStrike(After) 后摇 → 播完问大脑
#
# 持续震屏的做法（和 Battlecry 一样）：每帧调 Game.shake_camera(小值)，
# 停止时调 Game.stop_shake()。Game.shake_camera 单次只震一下，每帧调就是持续震。
#
# 注意：ElbowStrike 是循环动画 → 不会发 animation_finished，
#       所以冲锋段的结束只靠「到达坐标」判定，不靠动画信号。
# =============================================================================

extends BasicState

# --- 动画名（按你 SpriteFrames 里的实际名字）---
@export var before_animation: StringName = &"ElbowStrike(Before)"
@export var strike_animation: StringName = &"ElbowStrike"        # 循环，有伤害
@export var after_animation: StringName = &"ElbowStrike(After)"

# --- 冲锋目标（场地固定坐标）---
@export var left_target_x: float = 50.0    # 朝左冲的终点
@export var right_target_x: float = 110.0  # 朝右冲的终点

# --- 冲锋参数 ---
@export var dash_speed: float = 350.0       # 恒定速度（像素/秒）；160 宽屏参考 80~120
@export var dash_shake: float = 1.1        # 持续小震幅度（参考：Battlecry 大震是 3.0）

# --- 判定 ---
@export var hitbox_path: NodePath = ^"../../ElbowStrikeHitbox"
@export var damage: int = 20
@export var hit_filter_amount: float = 0.45
@export var hit_filter_color: Color = Color(0.9, 0.1, 0.1, 0.6)

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)

var target_x: float = 0.0
var dashing: bool = false
var hit_registered: bool = false
const EFFECT_SCENE: PackedScene = preload("res://entities/rust_goat/basketball_land.tscn")

func enter() -> void:
	dashing = false
	hit_registered = false
	monster.velocity = Vector2.ZERO

	_choose_direction()
	_apply_facing()
	_set_hitbox_active(false)

	if is_instance_valid(ani_2d):
		ani_2d.play(before_animation)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)


func process(delta: float) -> void:
	if not dashing:
		return

	# 恒速冲向目标 x（时间自然随距离变化）
	var dir := signf(target_x - monster.global_position.x)
	monster.global_position.x += dir * dash_speed * delta

	# 持续小震（每帧调一下 = 一直震）
	Game.shake_camera(dash_shake)

	_check_hit()

	# 到达（冲过头也算到）
	if (dir > 0.0 and monster.global_position.x >= target_x) \
			or (dir < 0.0 and monster.global_position.x <= target_x) \
			or dir == 0.0:
		monster.global_position.x = target_x
		_finish_dash()


func exit() -> void:
	# 兜底：无论怎么离开（包括死亡打断）都停震、关判定
	Game.stop_shake()
	_set_hitbox_active(false)
	dashing = false
	if is_instance_valid(ani_2d):
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)
		ani_2d.scale.x = maxf(absf(ani_2d.scale.x), 1.0)
	if is_instance_valid(hitbox):
		hitbox.scale.x = maxf(absf(hitbox.scale.x), 1.0)


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d):
		return
	# 前摇完 → 起冲（strike_animation 是循环动画，靠到达坐标结束，不走这里）
	if ani_2d.animation == before_animation:
		ani_2d.play(strike_animation)
		dashing = true
		_set_hitbox_active(true)
		return
	# 后摇完 → 问大脑
	if ani_2d.animation == after_animation:
		if monster.has_method("get_next_attack_state"):
			change_state(int(monster.get_next_attack_state()))
		else:
			change_state(1)


func _finish_dash() -> void:
	dashing = false
	Game.stop_shake()
	_set_hitbox_active(false)
	if is_instance_valid(ani_2d):
		ani_2d.play(after_animation)
		Game.shake_camera(12)
		Game.flash(1, Color(0.892, 0.782, 0.607, 0.207))
		if EFFECT_SCENE != null and get_tree().current_scene != null:
			var eff := EFFECT_SCENE.instantiate()
			get_tree().current_scene.add_child(eff)
			eff.global_position = monster.global_position
			if eff is GPUParticles2D:
				(eff as GPUParticles2D).emitting = true


# 面向「离边缘更远的那一侧」：哪边能冲更长就冲哪边
func _choose_direction() -> void:
	var dist_left := monster.global_position.x - left_target_x
	var dist_right := right_target_x - monster.global_position.x
	if dist_right >= dist_left:
		monster.face_right()
		target_x = right_target_x
	else:
		monster.face_left()
		target_x = left_target_x


func _check_hit() -> void:
	# 一次冲锋只打一下（想要碰一下掉一次血+无敌帧节奏，需配合玩家侧的受击无敌）
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


func _apply_facing() -> void:
	var d: int = monster.direct if "direct" in monster else 1
	if is_instance_valid(ani_2d):
		var s := maxf(absf(ani_2d.scale.x), 1.0)
		ani_2d.scale.x = -s if d > 0 else s  # 翻转方向按你素材改
	if is_instance_valid(hitbox):
		var hs := maxf(absf(hitbox.scale.x), 1.0)
		hitbox.scale.x = -hs if d > 0 else hs

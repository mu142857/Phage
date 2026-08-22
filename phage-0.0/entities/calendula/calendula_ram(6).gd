# =============================================================================
# calendula_ram(6).gd  —  冲撞（6 号）：对高横扫（参考空洞骑士·复仇蝇之王）
# =============================================================================
# 流程（process 驱动的四段）：
#   0 对高：缓慢漂浮到玩家当前高度（持续追踪，最多 max_align_time 秒）
#   1 预备：停 telegraph_time 秒（微震屏 = 前摇提示，给玩家反应窗口）
#   2 冲扫：锁定方向，横着全速扫到对面场地边界，RamHitbox 里的玩家吃一次伤害
#   3 收招：停 recover_time 秒 → 问大脑
#
# Ram 动画建议【循环】（整个冲撞期间一直播，不靠 animation_finished）。
# =============================================================================

extends BasicState

@export var ram_animation: StringName = &"Ram"
@export var align_speed: float = 32.0      # 对高的缓慢垂直速度
@export var align_y_min: float = 24.0      # 对高上限（别飞出屏）
@export var align_y_max: float = 72.0      # 对高下限（贴地扫，别插进地板）
@export var max_align_time: float = 2.5    # 玩家一直乱跳就强制开冲
@export var telegraph_time: float = 0.35   # 前摇停顿
@export var telegraph_shake: float = 1.0   # 前摇微震（0=不震）
@export var dash_speed: float = 230.0      # 横扫速度
@export var recover_time: float = 0.25     # 收招停顿
@export var damage_amount: int = 12        # 命中伤害
@export var hit_shake: float = 2.0         # 命中震屏（0=不震）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var stage: int = 0
var stage_time: float = 0.0
var dash_dir: float = 1.0
var dash_target_x: float = 0.0
var damage_applied: bool = false


func enter() -> void:
	monster.velocity = Vector2.ZERO
	stage = 0
	stage_time = 0.0
	damage_applied = false

	if monster.has_method("face_player"):
		monster.face_player()
	_apply_facing()

	if is_instance_valid(ani_2d):
		ani_2d.play(ram_animation)


func process(delta: float) -> void:
	stage_time += delta
	match stage:
		0:  # 对高：缓慢贴向玩家高度（持续追踪）
			var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
			var target_y: float = monster.global_position.y
			if player != null:
				target_y = clampf(player.global_position.y, align_y_min, align_y_max)
			var dy := target_y - monster.global_position.y
			var step := align_speed * delta
			if absf(dy) <= step:
				monster.global_position.y = target_y
			else:
				monster.global_position.y += signf(dy) * step
			if monster.has_method("face_player"):
				monster.face_player()
			_apply_facing()
			if absf(dy) <= 1.5 or stage_time >= max_align_time:
				_next_stage(1)
		1:  # 预备：前摇停顿
			if telegraph_shake > 0.0:
				Game.shake_camera(telegraph_shake)
			if stage_time >= telegraph_time:
				Game.stop_shake()
				_lock_dash()
				_next_stage(2)
		2:  # 冲扫：横着全速扫过去
			monster.global_position.x += dash_dir * dash_speed * delta
			if not damage_applied:
				_try_damage_player()
			if (dash_dir > 0.0 and monster.global_position.x >= dash_target_x) \
					or (dash_dir < 0.0 and monster.global_position.x <= dash_target_x):
				monster.global_position.x = dash_target_x
				_next_stage(3)
		3:  # 收招
			if stage_time >= recover_time:
				stage = -1  # 防止重复问大脑
				if monster.has_method("get_next_attack_state"):
					change_state(int(monster.get_next_attack_state()))
				else:
					change_state(1)


func exit() -> void:
	Game.stop_shake()


func _next_stage(next: int) -> void:
	stage = next
	stage_time = 0.0


# 锁定冲刺方向和终点：朝玩家所在的那一侧，扫到对面边界
func _lock_dash() -> void:
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	if player != null:
		dash_dir = signf(player.global_position.x - monster.global_position.x)
	else:
		dash_dir = float(monster.direct)
	if dash_dir == 0.0:
		dash_dir = float(monster.direct)
	var min_x: float = monster.bound_min_x if "bound_min_x" in monster else 10.0
	var max_x: float = monster.bound_max_x if "bound_max_x" in monster else 150.0
	dash_target_x = max_x if dash_dir > 0.0 else min_x
	if dash_dir > 0.0:
		monster.face_right()
	else:
		monster.face_left()
	_apply_facing()


func _try_damage_player() -> void:
	var hitbox := monster.get_node_or_null("RamHitbox") as Area2D
	if hitbox == null:
		return
	for body in hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
		damage_applied = true
		if hit_shake > 0.0:
			Game.shake_camera(hit_shake)
		break


func _apply_facing() -> void:
	if not is_instance_valid(ani_2d):
		return
	var d: int = monster.direct if "direct" in monster else 1
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	ani_2d.scale.x = -s if d > 0 else s  # 翻转方向按你素材改

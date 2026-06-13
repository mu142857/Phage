# =============================================================================
# state_shoot.gd  —  rust_goat 投篮（4 号）：连播 Shoot 1~3 次 → 篮球天降
# =============================================================================
# 行为：随机决定播放次数 N（1~3）→ 连续播 N 遍 Shoot 动画 →
#       最后一遍播完 0.1 秒后 → N 个篮球从天而降：
#         · x 随机分布在 [15, 145]，多球时两两间距 > 30（防重叠）
#         · y 从 20 开始下落
#       → 问大脑要下一个状态（球是独立场景，自己落自己的）。
#
# 注意：Shoot 动画必须【不循环】，靠 animation_finished 数次数。
# =============================================================================

extends BasicState

@export var shoot_animation: StringName = &"Shoot"
@export var min_plays: int = 1            # 最少连播次数
@export var max_plays: int = 2            # 最多连播次数
@export var spawn_delay: float = 0.02      # 最后一遍播完到落球的延迟
@export var stagger_delay: float = 0.085  # 多个球落下的间隔时间（单位：秒）
@export var ball_spawn_y: float = -20.0    # 球的起始高度
@export var spawn_min_x: float = 15.0     # 落点范围
@export var spawn_max_x: float = 145.0
@export var min_gap: float = 30.0         # 多球间最小间距

const BALL_SCENE: PackedScene = preload("res://entities/rust_goat/basket_ball.tscn")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var plays_target: int = 1   # 本轮要播几次（= 落几个球）
var plays_done: int = 0
var ticket: int = 0         # 防过期 await


func enter() -> void:
	monster.velocity = Vector2.ZERO
	plays_target = monster.rng.randi_range(min_plays, max_plays) \
			if "rng" in monster else randi_range(min_plays, max_plays)
	plays_done = 0
	ticket += 1

	if monster.has_method("face_player"):
		monster.face_player()
	_apply_facing()

	if is_instance_valid(ani_2d):
		ani_2d.play(shoot_animation)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	ticket += 1  # 作废未完成的 await（被闪避/死亡打断时不再落球）
	if is_instance_valid(ani_2d):
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)
		ani_2d.scale.x = maxf(absf(ani_2d.scale.x), 1.0)


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d) or ani_2d.animation != shoot_animation:
		return
	plays_done += 1
	if plays_done < plays_target:
		ani_2d.play(shoot_animation)  # 还没播够，再来一遍
		return
	_finish_and_spawn(ticket)


func _finish_and_spawn(t: int) -> void:
	await get_tree().create_timer(spawn_delay).timeout
	if t != ticket:
		return  # 状态已退出，作废
	
	# 等待所有球间隔着生成完毕 [1]
	await _spawn_balls(plays_target, t)
	
	if t != ticket:
		return  # 在生成球的过程中状态可能已被打断（如受击）
		
	# 演完问大脑
	if monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))
	else:
		change_state(1)


# =============================================================================
# 落球：N 个随机 x，两两间距 > min_gap，并带有时间间隔
# =============================================================================
func _spawn_balls(count: int, t: int) -> void:
	if BALL_SCENE == null or get_tree().current_scene == null:
		return
	
	var xs := _pick_spaced_positions(count)
	for i in range(count):
		# 每次生成前检查 ticket，防止生成间隔期间状态已经被打断/切换
		if t != ticket:
			return
			
		var x := xs[i]
		var ball := BALL_SCENE.instantiate()
		get_tree().current_scene.add_child(ball)
		if ball.has_method("setup"):
			ball.setup(Vector2(x, ball_spawn_y))
		else:
			ball.global_position = Vector2(x, ball_spawn_y)
			
		# 如果不是最后一个球，且未被打断，就等待一段时间再生成下一个 [1]
		if i < count - 1:
			await get_tree().create_timer(stagger_delay).timeout


# 随机取 count 个 x ∈ [spawn_min_x, spawn_max_x]，两两间距 > min_gap。
# 随机重试 50 次，仍失败则退化为「均匀分布 + 小抖动」（数学上必然合法）。
func _pick_spaced_positions(count: int) -> Array[float]:
	var result: Array[float] = []
	var r: RandomNumberGenerator = monster.rng if "rng" in monster else null

	for _try in range(50):
		result.clear()
		var ok := true
		for i in range(count):
			var x: float = r.randf_range(spawn_min_x, spawn_max_x) if r != null \
					else randf_range(spawn_min_x, spawn_max_x)
			for placed in result:
				if absf(x - placed) <= min_gap:
					ok = false
					break
			if not ok:
				break
			result.append(x)
		if ok:
			return result

	# 兜底：均匀切段，每段内随机一点（段距足够大时天然满足间距）
	result.clear()
	var span := (spawn_max_x - spawn_min_x) / float(count)
	for i in range(count):
		var lo := spawn_min_x + span * float(i)
		var hi := lo + maxf(span - min_gap, 0.0)
		var x: float = r.randf_range(lo, hi) if r != null else randf_range(lo, hi)
		result.append(x)
	return result


func _apply_facing() -> void:
	if not is_instance_valid(ani_2d):
		return
	var d: int = monster.direct if "direct" in monster else 1
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	ani_2d.scale.x = -s if d > 0 else s  # 翻转方向按你素材改

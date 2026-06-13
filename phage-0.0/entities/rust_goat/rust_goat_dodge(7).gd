# =============================================================================
# state_dodge.gd  —  rust_goat 闪避（7 号）：原地无敌闪避 + 篮球天降
# =============================================================================
# 触发来源：主体 take_damage 里的反应闪避判定（Idle/Move 中被打、概率累积制）。
# 行为：原地不动 → 播 Dodge 动画（13 帧）→ 前 4 帧（编号 0~3）无敌，
#       从第 4 帧起恢复可被打 → 播完 0.1 秒后 → N 个篮球从天而降：
#         · x 随机分布在 [15, 145]，多球时两两间距 > 30（防重叠）
#         · y 从 20 开始下落
#       → 播完问大脑（自动续上剧本）。
#
# 无敌实现：enter 时 hittable=false（触发本状态的那一下攻击在 take_damage
# 里已被吞掉），到第 4 帧 hittable=true。exit 兜底强制恢复 true，
# 防止任何打断路径留下永久无敌。
#
# 注意：Dodge 动画必须【不循环】。
# =============================================================================

extends BasicState

@export var dodge_animation: StringName = &"Dodge"
@export var vulnerable_frame: int = 4   # 从这一帧起恢复可被打（前面 0~3 帧无敌）
@export var ghost_alpha: float = 0.5    # 无敌期间半透明（1.0 = 不变）

@export_group("Ball Spawn")
@export var min_balls: int = 1            # 最少落球数量
@export var max_balls: int = 1            # 最多落球数量
@export var spawn_delay: float = 0.1      # 播完到落球的延迟
@export var stagger_delay: float = 0.085  # 多个球落下的间隔时间
@export var ball_spawn_y: float = -20.0    # 球的起始高度
@export var spawn_min_x: float = 15.0     # 落点范围
@export var spawn_max_x: float = 145.0
@export var min_gap: float = 30.0         # 多球间最小间距

const BALL_SCENE: PackedScene = preload("res://entities/rust_goat/basket_ball.tscn")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var vulnerable: bool = false
var ball_count: int = 1
var ticket: int = 0         # 防过期 await（被打断时不再落球）


func enter() -> void:
	vulnerable = false
	monster.velocity = Vector2.ZERO
	ticket += 1
	
	ball_count = monster.rng.randi_range(min_balls, max_balls) \
			if "rng" in monster else randi_range(min_balls, max_balls)

	# ===== 开无敌 =====
	if "hittable" in monster:
		monster.hittable = false

	if is_instance_valid(ani_2d):
		ani_2d.modulate.a = ghost_alpha
		ani_2d.play(dodge_animation)
		if not ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.connect(_on_frame_changed)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	ticket += 1  # 作废未完成的 await（如果在落球中途被打断，不再继续生成）
	
	# ===== 兜底：无论怎么离开都恢复可被打 + 不透明 =====
	if "hittable" in monster:
		monster.hittable = true
	if is_instance_valid(ani_2d):
		ani_2d.modulate.a = 1.0
		if ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.disconnect(_on_frame_changed)
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)


func _on_frame_changed() -> void:
	if vulnerable or not is_instance_valid(ani_2d):
		return
	if ani_2d.animation != dodge_animation:
		return
	if ani_2d.frame >= vulnerable_frame:
		vulnerable = true
		if "hittable" in monster:
			monster.hittable = true
		ani_2d.modulate.a = 1.0


func _on_animation_finished() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation == dodge_animation:
		_finish_and_spawn(ticket)


func _finish_and_spawn(t: int) -> void:
	await get_tree().create_timer(spawn_delay).timeout
	if t != ticket:
		return  # 状态已退出，作废
	
	await _spawn_balls(ball_count, t)
	
	if t != ticket:
		return  # 在落球间隔期间状态可能已被打断/切换
		
	# 演完问大脑（自动续上被打断的剧本）
	if monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))
	else:
		change_state(1)


# =============================================================================
# 落球：N 个随机 x，两两间距 > min_gap，并带有时间间隔 [1]
# =============================================================================
func _spawn_balls(count: int, t: int) -> void:
	if BALL_SCENE == null or get_tree().current_scene == null:
		return
	var xs := _pick_spaced_positions(count)
	for i in range(count):
		if t != ticket:
			return
		var x := xs[i]
		var ball := BALL_SCENE.instantiate()
		get_tree().current_scene.add_child(ball)
		if ball.has_method("setup"):
			ball.setup(Vector2(x, ball_spawn_y))
		else:
			ball.global_position = Vector2(x, ball_spawn_y)
		
		# 如果还没到最后一个球，就等待一段时间再生成下一个 [1]
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

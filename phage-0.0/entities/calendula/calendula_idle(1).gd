# =============================================================================
# calendula_idle(1).gd  —  悬浮待机（固定 1 号，「会飘的 Idle」）
# =============================================================================
# 职责：像 cox 一样悬浮 + 正弦忽高忽低（低点要沉到玩家够得着的高度，
#       主角没有上劈也能打到）+ 缓慢横向游走保持与玩家的距离 →
#       等一段时间（血越少等越短）→ 问主体下一招 → 切过去。
# 注意：这里【不做任何决策】，决策全在 calendula.gd 的 get_next_attack_state()。
#
# 位置用指数平滑贴向正弦轨道，进入状态时不会瞬移跳变。
# =============================================================================

extends BasicState

# 待机时长区间（血越少 Idle 越短，攻击越密）
@export var idle_time_full_health: float = 2.2
@export var idle_time_low_health: float = 1.1

# --- 悬浮参数（参考 cox: amplitude 15 / speed 2.2）---------------------------
@export var hover_center_y: float = 46.0   # 忽高忽低的中心高度
@export var hover_amplitude: float = 20.0  # 振幅：低点 66 左右，站地上能砍到
@export var hover_speed: float = 1.6       # 正弦角速度（弧度/秒）
@export var follow_smooth: float = 4.0     # 贴向轨道的指数平滑系数（越大越跟手）

# --- 横向游走 ----------------------------------------------------------------
@export var keep_distance: float = 34.0    # 与玩家保持的横向距离
@export var drift_smooth: float = 1.6      # 横向平滑系数（小 = 慢悠悠）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var idle_ticket: int = 0   # 票据：防止「上一轮 Idle 的计时器」在退出后才触发
var _time: float = 0.0


func enter() -> void:
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Idle")

	# 调试开关：idle_only 时永远待机（悬浮照常）
	if "idle_only" in monster and monster.idle_only:
		return

	var health_ratio: float = 1.0
	if "health" in monster and "max_health" in monster and monster.max_health > 0:
		health_ratio = float(monster.health) / float(monster.max_health)
	var duration: float = lerpf(idle_time_low_health, idle_time_full_health, health_ratio)

	idle_ticket += 1
	_start_timer(duration, idle_ticket)


func process(delta: float) -> void:
	_time += delta

	# 纵向：指数平滑贴向正弦轨道（忽高忽低）
	var target_y := hover_center_y + sin(_time * hover_speed) * hover_amplitude
	var k := 1.0 - exp(-follow_smooth * delta)
	monster.global_position.y = lerpf(monster.global_position.y, target_y, k)

	# 横向：慢悠悠飘到玩家身侧 keep_distance 处（保持在自己这一侧）
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	if player != null:
		var side := signf(monster.global_position.x - player.global_position.x)
		if side == 0.0:
			side = -float(monster.direct)
		var target_x: float = player.global_position.x + side * keep_distance
		var min_x: float = monster.bound_min_x if "bound_min_x" in monster else 10.0
		var max_x: float = monster.bound_max_x if "bound_max_x" in monster else 150.0
		target_x = clampf(target_x, min_x, max_x)
		var kx := 1.0 - exp(-drift_smooth * delta)
		monster.global_position.x = lerpf(monster.global_position.x, target_x, kx)

	if monster.has_method("face_player"):
		monster.face_player()
	_apply_facing()


func exit() -> void:
	idle_ticket += 1  # 作废还没响的计时器


func _start_timer(duration: float, ticket: int) -> void:
	await get_tree().create_timer(duration).timeout
	if ticket != idle_ticket:
		return  # 计时器过期（中途退出过 Idle），不执行
	_decide_next()


func _decide_next() -> void:
	if "idle_only" in monster and monster.idle_only:
		return
	# 问主体要下一招（战吼插播/剧本轮换全在主体里算好了）
	if monster != null and monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))


func _apply_facing() -> void:
	if not is_instance_valid(ani_2d):
		return
	var d: int = monster.direct if "direct" in monster else 1
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	ani_2d.scale.x = -s if d > 0 else s  # 翻转方向按你素材改

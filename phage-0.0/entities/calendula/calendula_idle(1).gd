# =============================================================================
# calendula_idle(1).gd  —  悬浮待机（固定 1 号，「会飘的 Idle」）
# =============================================================================
# 职责：悬浮在玩家的【侧上方】（monster.side：1=右上，-1=左上，由冲刺在屏幕外
#       切换，场上永不翻转）+ 正弦忽高忽低（低点要沉到玩家够得着的高度）→
#       等一段时间（血越少等越短）→ 问主体下一招 → 切过去。
# 注意：这里【不做任何决策】，决策全在 calendula.gd 的 get_next_attack_state()。
#
# 位置用指数平滑贴向目标，进入状态时不会瞬移跳变（冲刺收尾在屏幕外时，
# 也是靠这里平滑滑回场内，形成「绕回头顶归位」的动线）。
# =============================================================================

extends BasicState

# 待机时长区间（血越少 Idle 越短，攻击越密）
@export var idle_time_full_health: float = 4.0
@export var idle_time_low_health: float = 1.5

# --- 悬浮参数 ----------------------------------------------------------------
# ★ 高度铁律：贴图从原点往下延伸 ~35px，任何时刻 root y ≤ 45，
#   否则贴图下缘插进地面(80)，而且低位吐弹必中，没法躲。
@export var hover_center_y: float = 33.0   # 忽高忽低的中心高度
@export var hover_amplitude: float = 12.0  # 振幅：低点正好压在 45 的上限
@export var hover_y_max: float = 45.0      # root y 硬上限（80 - 贴图下探 35）
@export var hover_speed: float = 1.6       # 正弦角速度（弧度/秒）
@export var follow_smooth: float = 4.0     # 贴向轨道的指数平滑系数（越大越跟手）

# --- 横向定位 ----------------------------------------------------------------
# 不跟着玩家跑（贴身漂移违和）：认领半场——side=1 固定飘在 x=+hover_home_x，
# side=-1 固定飘在 x=-hover_home_x，以 x=0 为界各占一边；
# 驻点上再叠一层慢速左右游移，别像钉在空中
@export var hover_home_x: float = 40.0
@export var wander_amplitude: float = 14.0 # 左右游移幅度
@export var wander_speed: float = 0.9      # 左右游移角速度（和上下不同频，走∞字轨迹）
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

	# 纵向：指数平滑贴向正弦轨道（忽高忽低），硬顶在 hover_y_max
	var target_y := hover_center_y + sin(_time * hover_speed) * hover_amplitude
	target_y = minf(target_y, hover_y_max)
	var k := 1.0 - exp(-follow_smooth * delta)
	monster.global_position.y = minf(lerpf(monster.global_position.y, target_y, k), hover_y_max)

	# 横向：慢悠悠飘回自己半场的驻点，驻点上叠慢速左右游移
	var side: int = monster.side if "side" in monster else 1
	var center: float = monster.center_x if "center_x" in monster else 0.0
	var target_x: float = center + float(side) * hover_home_x + sin(_time * wander_speed) * wander_amplitude
	var min_x: float = monster.bound_min_x if "bound_min_x" in monster else 10.0
	var max_x: float = monster.bound_max_x if "bound_max_x" in monster else 150.0
	target_x = clampf(target_x, min_x, max_x)
	var kx := 1.0 - exp(-drift_smooth * delta)
	monster.global_position.x = lerpf(monster.global_position.x, target_x, kx)


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

# =============================================================================
# state_idle.gd  —  待机状态（固定 1 号）
# =============================================================================
# 职责：播 Idle 动画 → 等一段时间（血越少等越短，越来越凶）→ 问主体下一招 → 切过去。
# 注意：这里【不做任何决策】，决策全在 boss_base.gd 的 get_next_attack_state()。
# 改打法去改主体，不要改这里。
#
# 节点要求：本状态节点下不需要任何子节点（计时用 create_timer + 票据防过期）。
# =============================================================================

extends BasicState

# 待机时长区间（参考 Actinos: 满血 2.0s ~ 空血 1.0s；血越少 Idle 越短）
@export var idle_time_full_health: float = 2.0   # 满血时的待机时长
@export var idle_time_low_health: float = 1.0    # 血量见底时的待机时长

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

# 票据：防止「上一轮 Idle 的计时器」在退出后才触发、错切状态
var idle_ticket: int = 0


func enter() -> void:
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Idle")

	# 调试开关：idle_only 时永远待机（boss_base.gd 里的 @export）
	if "idle_only" in monster and monster.idle_only:
		return

	# 血量比例 → 待机时长（血少 = 等得短 = 攻击更密）
	var health_ratio: float = 1.0
	if "health" in monster and "max_health" in monster and monster.max_health > 0:
		health_ratio = float(monster.health) / float(monster.max_health)
	var duration: float = lerpf(idle_time_low_health, idle_time_full_health, health_ratio)

	idle_ticket += 1
	_start_timer(duration, idle_ticket)


func process(_delta: float) -> void:
	pass


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
	# 问主体要下一招（战吼插播/连放/轮换全在主体里算好了）
	if monster != null and monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))

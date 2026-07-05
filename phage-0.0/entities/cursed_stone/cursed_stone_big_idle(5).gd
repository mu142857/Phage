# =============================================================================
# BigIdle(5)  —  大形态待机（备用）
# =============================================================================
# 正常大形态循环是 BigAttack ↔ BigeMove，用不到本状态。
# 保留作安全兜底：万一被切进来，播一下 BigIdle 就转去攻击，不会卡死。
# =============================================================================
extends BasicState

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

func enter() -> void:
	monster.velocity = Vector2.ZERO
	if is_instance_valid(ani_2d):
		ani_2d.play(&"BigIdle")
	change_state(monster.STATE_BIG_ATTACK)

func process(_delta: float) -> void:
	pass

func exit() -> void:
	pass

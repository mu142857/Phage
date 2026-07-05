# =============================================================================
# SmallIdle(1)  —  沉睡待机（初始状态）
# =============================================================================
# 播 SmallIdle，原地不动，盯着玩家距离。玩家靠近 < wake_distance(50px) →
# 唤醒（标记 awake，之后永不再睡）→ 立刻进 SmallAttack 开打。
# =============================================================================
extends BasicState

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."


func enter() -> void:
	monster.velocity = Vector2.ZERO
	if is_instance_valid(ani_2d):
		ani_2d.play(&"SmallIdle")


func process(_delta: float) -> void:
	if monster.distance_to_player() <= monster.wake_distance:
		monster.awake = true
		monster.face_player()
		change_state(monster.STATE_SMALL_MOVE)  # 小形态循环：先移动两次再攻击一次


func exit() -> void:
	pass

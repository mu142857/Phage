# =============================================================================
# Idle(1)  —  短待机：落地站定、面向玩家，等一小段时间 → Disappear(传送)
# =============================================================================
# 旧邪帽 Idle 逻辑：等待时长随血量变化（血越多等越久）；若已排队地火，则立刻传送。
# =============================================================================
extends BasicState

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var _ticket: int = 0


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.show()
	monster.global_position.y = monster.floor_y
	monster.face_player()
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Idle")

	_ticket += 1
	if monster.ready_to_underground_fire:
		_wait(_ticket, 0.0)
	else:
		# 血越多待越久：0.33 ~ 1.33s
		var t := float(monster.health) / float(monster.max_health) + 0.333
		_wait(_ticket, t)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	_ticket += 1  # 作废还没触发的等待


func _wait(t: int, seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
		if t != _ticket:
			return
	change_state(monster.STATE_DISAPPEAR)

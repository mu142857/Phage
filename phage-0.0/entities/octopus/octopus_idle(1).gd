# 大章鱼 Idle(1):一边往前压、一边让天上掉子弹,等够了出一招(砸地或激光);排着阶段战吼就先吼。
# BossIntro 字卡播完切到这里 = 开打。
extends BasicState

const SELF_ID := 1

@onready var monster = $"../.."

var _wait := 0.0


func enter() -> void:
	monster.start_fight()
	monster.set_advancing(true, monster.move_ramp_time)
	monster.set_drops(true)
	monster.set_bobbing(true)
	monster.play_anim(&"Idle")
	_wait = monster.attack_wait_time()


func process(delta: float) -> void:
	if monster.idle_only:
		return
	if monster.pending_battlecry > 0:
		change_state(monster.get_next_attack_state(SELF_ID))
		return
	_wait -= delta
	if _wait <= 0.0:
		change_state(monster.get_next_attack_state(SELF_ID))

# 章鱼 Flee(2):打赢了——它不死(之后会变成 NPC)。吃痛一闪、愣一下,
# 然后往上飞出屏幕 / 沉到地下(主体的 flee_mode),出了屏幕就删掉;BossIntro 看它没了会把传送门重新打开。
extends BasicState

## 挨了最后一下后愣多久再跑
@export var stun_time: float = 0.35

@onready var monster = $"../.."


func enter() -> void:
	monster.end_fight()
	monster.flash_hit()
	Game.shake_camera(2.0)
	monster.play_anim(&"Idle")
	var target: float = monster.flee_target_y()
	var tw: Tween = monster.create_tween()
	tw.tween_interval(stun_time)
	tw.tween_property(monster, "global_position:y", target, monster.flee_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(monster.queue_free)

# 收钱小弟:拖着铁管走过来,看见人先拿管子指着喊"交钱!",贴脸了就抡一管子
# (举起→拉到脑后憋两帧→横扫→砸地,第 7~8 帧有判定)。
extends GangMob

const SHOUTS := ["交钱！", "交钱！", "过路费！", "站住！"]

var _shouted := false


func _start() -> void:
	state = S.ENGAGE


func _after_land() -> void:
	_shout()


func _engage(delta: float) -> void:
	if not _shouted:
		var p := player()
		if p != null and absf(p.global_position.x - global_position.x) < 110.0:
			_shout()
			return
	super._engage(delta)


func _shout() -> void:
	_shouted = true
	state = S.CUSTOM
	velocity.x = 0.0
	bark(SHOUTS[randi() % SHOUTS.size()])
	play_once(&"Alert", func() -> void:
		cooldown = 0.3
		state = S.ENGAGE)

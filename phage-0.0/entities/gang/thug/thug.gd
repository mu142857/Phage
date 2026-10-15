# 收钱小弟:拖着铁管走过来,看见人先拿管子指着喊"交钱!",贴脸了就抡一管子
# (举起→拉到脑后憋两帧→横扫→砸地,第 7~8 帧有判定)。
extends GangMob

var _shouted := false


func _start() -> void:
	state = S.ENGAGE


func _after_land() -> void:
	_shout(has_meta("entry_line"))


func _engage(delta: float) -> void:
	if not _shouted:
		var p := player()
		if p != null and absf(p.global_position.x - global_position.x) < 110.0:
			_shout(false)
			return
	super._engage(delta)


## 看见人:拿管子一指,喊一声(伏击战落地时已经喊过开场白就只指不喊)
func _shout(quiet: bool) -> void:
	_shouted = true
	_spotted = true
	state = S.CUSTOM
	velocity.x = 0.0
	var p := player()
	if p != null:
		face(signf(p.global_position.x - global_position.x))
	if not quiet:
		shout("spot", 1.0, true)
	play_once(&"Alert", func() -> void:
		cooldown = 0.3
		state = S.ENGAGE)


func _lines() -> Dictionary:
	return {
		"spot": ["交钱！", "打劫！", "站住！", "钱拿来！", "奥斯卡帮收钱！"],
		"attack": ["吃我一管！", "嘿——！"],
	}

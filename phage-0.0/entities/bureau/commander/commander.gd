# 队长:最高、倒三角,栅栏面甲 + 头顶一片后掠的钢刀冠,藏青披风,大剑。
# 自己也砍(Attack 第 5~6 帧),主要是隔一阵举剑喊"放!"(Command 第 5 帧),全队弩手一起射。
# 他一死整队就乱了(各打各的、出手变慢)——先打队长。
extends BureauMob

@export var command_frame: int = 5

var _ordered := false


## 队伍喊他下令齐射(BureauSquad 调)
func order_volley() -> void:
	if health <= 0 or state != S.ENGAGE:
		return
	state = S.CUSTOM
	velocity.x = 0.0
	_ordered = false
	shout("command", 1.0, true)
	play_once(&"Command", func() -> void:
		if state == S.CUSTOM:
			state = S.ENGAGE)


func _custom_tick(_delta: float) -> void:
	velocity.x = 0.0
	if sprite.animation == &"Command" and sprite.frame >= command_frame and not _ordered:
		_ordered = true
		if squad != null and is_instance_valid(squad):
			squad.volley()


func _lines() -> Dictionary:
	return {
		"command": ["弩手——放！", "放！", "齐射！"],
		"attack": ["斩！", "退下。"],
		"spot": ["什么人？", "站住。"],
		"die": ["……全体……", "撤……", "……记……工伤……"],
	}

# 章鱼 Slam(4):砸地,一轮可能连砸两下(主体开轮时决定)。
# 每一下:前 slam_frame 帧不管当时飘在哪,把身体挪到 Hit 正好压在地面上的高度(主体 slam_windup);
# 第 slam_frame 帧砸下去:震屏 + 天上斜着落下一把子弹(主体 slam_impact),剩下的帧里飘回去。
# 砸的时候照样往前压,平时的掉落先停;一轮砸完原地停 slam_rest_time 秒(不走、不掉子弹),再回 Idle。
extends BasicState

const SELF_ID := 4

## Slam 动画第几帧砸到地(从 0 数,第 5 号帧 = 触手甩到左下碰地、正对 Hit 点)
@export var slam_frame: int = 5
## 没导 Slam 帧时:抬身多久算砸到地、砸完再过多久算这一下结束
@export var fallback_windup: float = 0.5
@export var fallback_recover: float = 0.5

@onready var monster = $"../.."
@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"

var _t := 0.0
var _windup := 0.0
var _length := 0.0
var _fired := false
var _use_anim := false
var _resting := false
var _rest_left := 0.0
var _done := false


func enter() -> void:
	_done = false
	_resting = false
	monster.set_drops(false)
	_start_one_slam()


func _start_one_slam() -> void:
	_t = 0.0
	_fired = false
	monster.set_advancing(true)
	_use_anim = monster.has_anim(&"Slam")
	if _use_anim:
		monster.restart_anim(&"Slam")
		_windup = monster.anim_time_until(&"Slam", slam_frame)
		_length = monster.anim_length(&"Slam")
	else:
		_windup = fallback_windup
		_length = fallback_windup + fallback_recover
	monster.slam_windup(_windup)


func process(delta: float) -> void:
	if _done:
		return
	if _resting:
		_rest_left -= delta
		if _rest_left <= 0.0:
			_done = true
			change_state(monster.get_next_attack_state(SELF_ID))
		return
	_t += delta
	if not _fired:
		var landed := _t >= _windup
		if _use_anim:
			# 帧数比 slam_frame 还少也得砸:播完那一刻补上
			landed = (ani_2d.animation == &"Slam" and ani_2d.frame >= slam_frame) or _t >= _length
		if landed:
			_fired = true
			monster.slam_impact()
			monster.slam_recover(maxf(_length - _t, 0.25))
	# 按时长收尾,不靠 animation_finished(动画要是被勾了循环也不会卡死)
	if _t >= _length:
		if monster.take_extra_slam():
			_start_one_slam()
			return
		# 一轮砸完:原地停一会儿,不走不掉子弹
		_resting = true
		_rest_left = monster.slam_rest_time
		monster.set_advancing(false)
		monster.play_anim(&"Idle")

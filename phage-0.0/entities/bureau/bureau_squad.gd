# 管道局的一队兵:子节点里的 BureauMob 按出生时的前后间距排成队形(朝 facing 最靠前的 = 队头)。
# 平时原地站岗,或者在 patrol_left~patrol_right 之间齐步来回走(到头了队长喊"向后——转!");
# 有要打的(主角没交钱 / 奥斯卡帮):整队往前推,队头顶到目标跟前 engage_gap 就停,不后退;
# 目标跑到队伍背后 → 向后转(队形镜像,原来的后排变前排——绕到背后的人先打到弩手)。
# 队长隔 volley_interval 喊一次"放!",弩手一起射。队长死了 → 全队 break_rank() 各打各的。
class_name BureauSquad
extends Node2D

@export var facing: float = 1.0
@export var march_speed: float = 12.0
## 巡逻范围(队头的 x);两个都是 0 = 不巡逻,原地站岗
@export var patrol_left: float = 0.0
@export var patrol_right: float = 0.0
## 队头顶到目标跟前多远停下
@export var engage_gap: float = 24.0
@export var volley_interval: float = 5.0

var anchor_x := 0.0
var marching := false
var move_dir := 1.0
var broken := false
var commander: BureauMob = null

var _slots := {}          # BureauMob -> 离队头多远
var _members: Array = []
var _depth := 0.0
var _turn_cd := 0.0
var _volley_cd := 2.5
var _in_fight := false
var _home_anchor := 0.0
var _home_facing := 1.0
var _calm := 0.0


func _ready() -> void:
	move_dir = facing
	for c in get_children():
		if c is BureauMob:
			_members.append(c)
			if c.has_method("order_volley") and commander == null:
				commander = c
	_measure(true)
	_home_anchor = anchor_x
	_home_facing = facing


## 量队形:队头位置 + 每个人离队头多远
func _measure(first: bool) -> void:
	if _members.is_empty():
		return
	var front := -INF
	for m in _members:
		front = maxf(front, (m as Node2D).global_position.x * facing)
	if first:
		anchor_x = front * facing
		for m in _members:
			_slots[m] = (anchor_x - (m as Node2D).global_position.x) * facing
	_depth = 0.0
	for m in _members:
		_depth = maxf(_depth, float(_slots.get(m, 0.0)))


func slot_x(m: BureauMob) -> float:
	return anchor_x - facing * float(_slots.get(m, 0.0))


## 全队走路帧对齐用
func step_frame() -> int:
	return int(Time.get_ticks_msec() / 100)


func _physics_process(delta: float) -> void:
	if broken or _members.is_empty():
		return
	_turn_cd = maxf(0.0, _turn_cd - delta)
	var foe := _squad_foe()
	if foe != null:
		if not _in_fight:
			_in_fight = true
			if commander != null:
				commander.shout("form_up", 1.0, true)
		var rel := (foe.global_position.x - anchor_x) * facing
		if rel < -_depth - 6.0:
			marching = false
			about_face("turn")
			return
		var want := foe.global_position.x - facing * engage_gap
		var d := (want - anchor_x) * facing
		if d > 2.0:
			marching = true
			move_dir = facing
			anchor_x += facing * march_speed * delta
		else:
			marching = false
		if commander != null and is_instance_valid(commander):
			_volley_cd -= delta
			if _volley_cd <= 0.0 and _has_shooters():
				_volley_cd = volley_interval
				commander.call("order_volley")
		return
	if _in_fight:
		_in_fight = false
		_calm = 0.0
	_calm += delta
	if patrol_right > patrol_left:
		marching = true
		move_dir = facing
		anchor_x += facing * march_speed * delta
		var tail := anchor_x - facing * _depth
		if (facing > 0.0 and anchor_x >= patrol_right) or (facing < 0.0 and anchor_x <= patrol_left) \
				or (facing > 0.0 and tail < patrol_left - 40.0) or (facing < 0.0 and tail > patrol_right + 40.0):
			about_face("patrol_turn")
	elif _calm > 3.0:
		# 打完了:齐步走回原来站岗的地方,站好后朝回原来的方向
		var target := _home_anchor if facing == _home_facing else _home_anchor - _home_facing * _depth
		var d := (target - anchor_x) * facing
		if d < -2.0:
			marching = false
			about_face("patrol_turn")
		elif d > 2.0:
			marching = true
			move_dir = facing
			anchor_x += facing * minf(march_speed * delta, d)
		else:
			marching = false
			if facing != _home_facing:
				about_face("patrol_turn")
	else:
		marching = false


## 向后转:队形镜像(谁也不用挪,原来的队尾变队头)
func about_face(line: String) -> void:
	if _turn_cd > 0.0:
		return
	_turn_cd = 1.2
	var back := anchor_x - facing * _depth
	facing = -facing
	move_dir = facing
	anchor_x = back
	for m in _members:
		_slots[m] = _depth - float(_slots.get(m, 0.0))
	if commander != null and is_instance_valid(commander):
		commander.shout(line, 1.0, true)


func _squad_foe() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for m in _members:
		if not is_instance_valid(m) or (m as BureauMob).health <= 0:
			continue
		var f := (m as BureauMob).foe()
		if f == null:
			continue
		var d := absf(f.global_position.x - anchor_x)
		if d < best_d:
			best = f
			best_d = d
	return best


func _has_shooters() -> bool:
	for m in _members:
		if is_instance_valid(m) and m.has_method("is_shooter") and m.call("is_shooter"):
			return true
	return false


## 队长喊"放!"的那一帧:弩手一起射
func volley() -> void:
	for m in _members:
		if is_instance_valid(m):
			(m as BureauMob).on_volley()


func member_died(m: BureauMob) -> void:
	_members.erase(m)
	_slots.erase(m)
	if m == commander:
		commander = null
		broken = true
		for o in _members:
			if is_instance_valid(o):
				(o as BureauMob).break_rank()
		return
	# 补位:前面的倒了,后面的整体往前顶
	var front := INF
	for o in _members:
		front = minf(front, float(_slots.get(o, 0.0)))
	if front > 0.0 and front < INF:
		for o in _members:
			_slots[o] = float(_slots[o]) - front
	_measure(false)

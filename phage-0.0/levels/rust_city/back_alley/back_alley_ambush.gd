# 后巷伏击战(晾衣巷尽头那扇小门进来,走错路了)。
# 放哨的(装成垃圾袋)吹哨,或者主角走过巷子中段 trigger_x → 身后铁栅门砸下来,
# 下水道帮一波一波从楼顶跳下来。放哨的没来得及吹哨就被砍死 = 第一波少来一个;
# 打的时候放哨的还活着,每吹一次哨就多下来一个小弟。
# 全打完:铁栅门升起,天上掉下来一袋"保护费"。这一夜打过一次就不再伏击(Story 标记)。
# 用计时器状态机,不用 await(主角死了场景重载,协程会醒在已经释放的节点上)。
extends Node2D

const SCENES := {
	"thug": preload("res://entities/gang/thug/thug.tscn"),
	"knife": preload("res://entities/gang/knife/knife.tscn"),
	"shield": preload("res://entities/gang/shield/shield.tscn"),
	"thrower": preload("res://entities/gang/thrower/thrower.tscn"),
	"brute": preload("res://entities/gang/brute/brute.tscn"),
	"chain": preload("res://entities/gang/chain/chain.tscn"),
	"crossbow": preload("res://entities/gang/crossbow/crossbow.tscn"),
	"roller": preload("res://entities/gang/roller/roller.tscn"),
}
const MONEY_BAG: PackedScene = preload("res://entities/gang/money_bag/money_bag.tscn")
const FLAG := "back_alley_ambush_done"

@export var trigger_x: float = 200.0
@export var arena_left: float = 100.0
@export var arena_right: float = 468.0
@export var gate_path: NodePath
@export var door_path: NodePath
@export var lookout_path: NodePath
@export var reward_coins: int = 12
## 空降时避开的 x 区间(消防梯平台底下,掉下来会挂在平台上)
@export var no_drop: Array[Vector2] = []
## 扔瓶子的专门落到消防梯平台上:平台中间的 x
@export var perch_xs: PackedFloat32Array = PackedFloat32Array()
@export var drop_y: float = -26.0
@export var gate_closed_y: float = 43.0
@export var gate_open_y: float = -40.0

# 每一项:[种类, 相对主角的 x(正=前方)] 或 [种类, "perch"]
var waves: Array = [
	[["thug", 46], ["thug", -42]],
	[["knife", 62], ["crossbow", "perch"], ["chain", -46]],
	[["shield", 56], ["roller", -70], ["thrower", "perch"]],
	[["brute", 66], ["knife", -48]],
]

enum P { WAIT, DELAY, SPAWN, FIGHT, DONE }

var phase: P = P.WAIT
var _t := 0.0
var _wave := -1
var _queue: Array = []
var _alive: Array = []
var _lookout_blew := false
var _gate: Node2D = null
var _gate_shape: CollisionShape2D = null
var _gate_sprite: Node2D = null


func _ready() -> void:
	_gate = get_node_or_null(gate_path) as Node2D
	if _gate != null:
		_gate_shape = _gate.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_gate_sprite = _gate.get_node_or_null("Sprite2D") as Node2D
	if get_tree().get_first_node_in_group("coin_hud") == null:
		var hud := CoinHud.new()
		hud.add_to_group("coin_hud")
		add_child(hud)
	var lookout := get_node_or_null(lookout_path)
	if Story.flag(FLAG, false):
		phase = P.DONE
		if lookout != null:
			lookout.queue_free()
		_set_gate(false, true)
		return
	_set_gate(false, true)
	if lookout != null and lookout.has_signal("whistled"):
		lookout.connect("whistled", _on_whistle)
		lookout.connect("died", func(_m: Node) -> void: _alive.erase(_m))


func _physics_process(delta: float) -> void:
	match phase:
		P.WAIT:
			var p := _player()
			if p != null and p.global_position.x >= trigger_x:
				_begin()
		P.DELAY:
			_t -= delta
			if _t <= 0.0:
				_next_wave()
		P.SPAWN:
			_t -= delta
			if _t <= 0.0:
				if _queue.is_empty():
					phase = P.FIGHT
				else:
					_spawn(_queue.pop_front())
					_t = 0.35
		P.FIGHT:
			_alive = _alive.filter(func(m: Variant) -> bool: return is_instance_valid(m))
			if not _queue.is_empty():
				phase = P.SPAWN
				_t = 0.2
			elif _alive.is_empty():
				if _wave + 1 >= waves.size():
					_finish()
				else:
					phase = P.DELAY
					_t = 1.1


func _begin() -> void:
	if phase != P.WAIT:
		return
	_set_gate(true)
	var door := get_node_or_null(door_path)
	if door != null and door.has_method("deactivate"):
		door.call("deactivate")
	# 放哨的没吹成哨(先被砍死了):第一波少下来一个
	var lookout := get_node_or_null(lookout_path)
	if not _lookout_blew and (lookout == null or not is_instance_valid(lookout)) and waves[0].size() > 1:
		waves[0] = waves[0].slice(0, waves[0].size() - 1)
	elif lookout != null and is_instance_valid(lookout):
		_alive.append(lookout)
	phase = P.DELAY
	_t = 0.9


func _next_wave() -> void:
	_wave += 1
	_queue = waves[_wave].duplicate()
	phase = P.SPAWN
	_t = 0.0


func _on_whistle(_l: Node) -> void:
	if phase == P.DONE:
		return
	if phase == P.WAIT:
		_lookout_blew = true
		_begin()
	else:
		# 打到一半又吹一次:叫来一个小弟
		_queue.append(["thug", [-40, 40, 70][randi() % 3]])


func _spawn(entry: Array) -> void:
	var kind: String = entry[0]
	var p := _player()
	var px := p.global_position.x if p != null else (arena_left + arena_right) * 0.5
	var x: float
	if typeof(entry[1]) == TYPE_STRING and entry[1] == "perch" and not perch_xs.is_empty():
		# 挑离主角远一点的那个平台
		x = perch_xs[0]
		for c in perch_xs:
			if absf(c - px) > absf(x - px):
				x = c
	else:
		x = px + float(entry[1])
		if x < arena_left + 10.0 or x > arena_right - 10.0:
			x = px - float(entry[1])
		x = clampf(x, arena_left + 10.0, arena_right - 10.0)
		for r in no_drop:
			if x > r.x and x < r.y:
				x = r.x - 4.0 if absf(x - r.x) < absf(x - r.y) else r.y + 4.0
		x = clampf(x, arena_left + 10.0, arena_right - 10.0)
	var mob := (SCENES[kind] as PackedScene).instantiate() as Node2D
	mob.set("drop_in", true)
	mob.set("land_on_platforms", typeof(entry[1]) == TYPE_STRING and entry[1] == "perch")
	mob.position = Vector2(x, drop_y)
	get_parent().add_child(mob)
	_alive.append(mob)


func _finish() -> void:
	phase = P.DONE
	Story.set_flag(FLAG, true)
	_set_gate(false)
	var door := get_node_or_null(door_path)
	if door != null and door.has_method("activate"):
		door.call("activate")
	var p := _player()
	var bag := MONEY_BAG.instantiate() as Node2D
	bag.set("coins", reward_coins)
	# 一袋保护费从楼顶直接砸到主角头上(站哪儿都够得着)
	var bx := clampf(p.global_position.x if p != null else 300.0, arena_left + 10.0, arena_right - 10.0)
	bag.position = Vector2(bx, drop_y)
	get_parent().add_child(bag)


func _set_gate(closed: bool, instant := false) -> void:
	if _gate == null:
		return
	if _gate_shape != null:
		_gate_shape.set_deferred("disabled", not closed)
	if _gate_sprite == null:
		return
	var y := gate_closed_y if closed else gate_open_y
	if instant:
		_gate_sprite.position.y = y
		return
	var tw := create_tween()
	if closed:
		tw.tween_property(_gate_sprite, "position:y", y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: Game.shake_camera(4.0))
	else:
		tw.tween_property(_gate_sprite, "position:y", y, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

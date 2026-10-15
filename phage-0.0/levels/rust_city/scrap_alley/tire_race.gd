# 轮胎赛跑(剧本 #12):从 2 号路灯跑到 3 号路灯,中间是废车场——红车、轮胎堆、废铁山、四层摞的车。
# 轮胎自己沿着地形滚,前面高了就蹦过去;主角用自己的跑/跳/冲刺。
#   第 1 场:正常跑。  第 2 场:它快多了。  第 3 场:对面废车场的野轮胎滚过来,要跳过去(撞上会被撞开、定一下)。
# 流程:黑一下把两个人摆到起跑线 → 锁住主角 3、2、1、跑! → 谁先过终点旗 → 大字 + 给钱 → 黑一下轮胎回原位。
# 赛道上的提示:顶上"第几场 · 押几个"+ 一根小赛道(两个点),起跑线是地上一道粉笔,终点是一面格子旗。
# 主角往回跑出起跑线 40 格、或者 30 秒还没跑完 = 跑丢了,押的钱退回。
class_name TireRace
extends Node2D

signal finished(result: int)   # 1 主角赢 / 0 轮胎赢 / -1 跑丢了
signal reset_done                 # 比完黑屏那一下,轮胎该回原位了

const TIRE_TEX: Texture2D = preload("res://entities/rust_npcs/tire.png")
const FLAG_TEX: Texture2D = preload("res://entities/rust_npcs/race/finish_flag.png")
const WILD_SCENE: PackedScene = preload("res://levels/rust_city/scrap_alley/wild_tire.tscn")
const G := 620.0
const PLAYER_DOT := Color(0.62, 0.95, 0.86)
const TIRE_DOT := Color(0.95, 0.62, 0.3)

@export var start_x := 300.0
@export var finish_x := 596.0
## 每场轮胎的基础速度(像素/秒);主角平地跑 70,冲刺一下 220
@export var speeds := PackedFloat32Array([54.0, 82.0, 78.0])

var round_no := 1
var bet := 0
var player: CharacterBody2D

var _x0 := 0
var _h := PackedFloat32Array()
var _racer: Sprite2D
var _rx := 0.0
var _ry := 0.0
var _rvy := 0.0
var _grounded := true
var _hud: MiniHud
var _state := 0          # 0 准备 1 倒计时 2 跑 3 完
var _t := 0.0
var _wild_times: Array = []
var _decor: Array = []


func setup(p: CharacterBody2D, round_number: int, bet_amount: int) -> void:
	player = p
	round_no = clampi(round_number, 1, 3)
	bet = bet_amount
	if round_no == 3:
		_wild_times = [1.2, 2.6, 4.2]


func _ready() -> void:
	z_index = 10
	_build_heightmap()
	_racer = Sprite2D.new()
	_racer.texture = TIRE_TEX
	_racer.light_mask = 1
	_racer.self_modulate = Color(0.75, 0.75, 0.75)
	add_child(_racer)
	_place_markers()
	GangMob.truce = true
	_run.call_deferred()


# ------------------------------------------------------------------ 地形
# 从天上往下打射线,记下每一列最上面的实心表面(单向平台不算)
func _build_heightmap() -> void:
	_x0 = int(start_x) - 40
	var x1 := int(finish_x) + 80
	var skip: Array[RID] = []
	for n in get_tree().current_scene.find_children("*", "StaticBody2D", true, false):
		if n.has_method("_drop"):
			skip.append((n as StaticBody2D).get_rid())
	var space := get_world_2d().direct_space_state
	_h.resize(x1 - _x0 + 1)
	for i in _h.size():
		var x := float(_x0 + i) + 0.5
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, -30), Vector2(x, 86), 1)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		_h[i] = hit.position.y if not hit.is_empty() else 80.0


func ground_y(x: float) -> float:
	var i := clampi(int(floor(x)) - _x0, 0, _h.size() - 1)
	return _h[i]


## 往 dir 方向 look 格以内最高的地面(y 最小)
func highest_ahead(x: float, dir: float, look: float) -> float:
	var best := 999.0
	var k := 1.0
	while k <= look:
		best = minf(best, ground_y(x + dir * k))
		k += 1.0
	return best


func _place_markers() -> void:
	# 起跑线:地上一道粉笔(两格宽的虚线)
	var line := Node2D.new()
	line.z_index = 11
	add_child(line)
	for k in 3:
		var r := ColorRect.new()
		r.color = Color(0.92, 0.9, 0.84)
		r.size = Vector2(2, 1)
		r.position = Vector2(start_x - 1, ground_y(start_x) - 1 - k * 3)
		line.add_child(r)
	_decor.append(line)
	var flag := Sprite2D.new()
	flag.texture = FLAG_TEX
	flag.centered = false
	flag.position = Vector2(finish_x, ground_y(finish_x) - FLAG_TEX.get_height())
	flag.z_index = 9
	flag.light_mask = 0
	flag.modulate = Color(0.85, 0.85, 0.85)
	add_child(flag)
	_decor.append(flag)


# ------------------------------------------------------------------ 流程
func _run() -> void:
	_hud = MiniHud.open(self)
	await Game.fade_cover(1.0, 0.2)
	if not is_inside_tree():
		return
	player.global_position = Vector2(start_x - 3, ground_y(start_x - 3) - 1)
	player.velocity = Vector2.ZERO
	if player.has_method("set_facing_direction"):
		player.call("set_facing_direction", 1)
	player.set_lock(true)
	_rx = start_x - 12   # 轮胎站在主角身后一点,起跑公平
	_ry = ground_y(_rx)
	_grounded = true
	_update_racer(0.0)
	_hud.banner(_banner_text())
	_update_track()
	await Game.fade_cover(0.0, 0.2)
	if not is_inside_tree():
		return
	_state = 1
	await _hud.countdown("跑！")
	if not is_inside_tree():
		return
	player.set_lock(false)
	_state = 2
	_t = 0.0


func _banner_text() -> String:
	var s := "第 %d 场" % round_no
	if bet > 0:
		s += " · 押 %d" % bet
	return s


func _physics_process(delta: float) -> void:
	if _state != 2:
		return
	_t += delta
	_move_racer(delta)
	_update_track()
	while not _wild_times.is_empty() and _t >= float(_wild_times[0]):
		_wild_times.pop_front()
		_spawn_wild()
	var px := player.global_position.x
	if px >= finish_x:
		_finish(1)
	elif _rx >= finish_x:
		_finish(0)
	elif px < start_x - 40.0 or _t > 30.0:
		_finish(-1)


func _move_racer(delta: float) -> void:
	var v := speeds[round_no - 1] * _rubber_band()
	var nx := _rx + v * delta
	if _grounded:
		var top := highest_ahead(_rx, 1.0, 14.0)
		if top < _ry - 3.0:
			# 前面高了:蹦上去(多蹦 5 格保证过得去)
			_rvy = -sqrt(2.0 * G * (_ry - top + 5.0))
			_grounded = false
		else:
			var g := ground_y(nx)
			if g <= _ry + 1.5:
				_ry = g
			else:
				_grounded = false
				_rvy = 0.0
	if not _grounded:
		_rvy += G * delta
		_ry += _rvy * delta
		if ground_y(nx) < _ry - 2.0 and _rvy < 0.0:
			nx = _rx   # 还没蹦够高,贴着墙往上
		var g2 := ground_y(nx)
		if _ry >= g2 and _rvy >= 0.0:
			_ry = g2
			_rvy = 0.0
			_grounded = true
	_rx = nx
	_update_racer(v * delta)


# 拉开太多就慢一点,落后太多就快一点:一直咬得很紧
func _rubber_band() -> float:
	var gap := _rx - player.global_position.x
	if gap > 36.0:
		return 0.82
	if gap < -28.0:
		return 1.14
	return 1.0


func _update_racer(dist: float) -> void:
	var r := TIRE_TEX.get_height() / 2.0
	_racer.position = Vector2(roundf(_rx), roundf(_ry - r))
	_racer.rotation += dist / r


func _update_track() -> void:
	var span := finish_x - start_x
	_hud.track([(player.global_position.x - start_x) / span, (_rx - start_x) / span], [PLAYER_DOT, TIRE_DOT])


func _spawn_wild() -> void:
	var w := WILD_SCENE.instantiate() as Node2D
	w.position = Vector2(finish_x + 30.0, ground_y(finish_x + 30.0))
	add_child(w)
	w.call("setup", self, player)


func _finish(result: int) -> void:
	_state = 3
	player.set_lock(false)
	match result:
		1:
			_hud.big("赢了！", MiniHud.GOOD, 1.0)
			Game.flash(0.1, Color(1, 0.95, 0.8))
			if bet > 0:
				Story.add_coins(bet * 2)
				MiniHud.float_text(get_parent(), player.global_position + Vector2(0, -10), "+%d" % (bet * 2))
		0:
			_hud.big("输了……", MiniHud.BAD, 1.0)
		-1:
			_hud.big("跑丢了", MiniHud.TEXT, 1.0)
			if bet > 0:
				Story.add_coins(bet)   # 退回
	finished.emit(result)
	_cleanup.call_deferred()


func _cleanup() -> void:
	await get_tree().create_timer(1.4).timeout
	if not is_inside_tree():
		return
	await Game.fade_cover(1.0, 0.2)
	if not is_inside_tree():
		return
	GangMob.truce = false
	_hud.close()
	_racer.visible = false
	for d in _decor:
		d.queue_free()
	for c in get_children():
		if c.has_method("setup"):
			c.queue_free()   # 还在滚的野轮胎
	reset_done.emit()   # 黑着的时候让轮胎回原位
	await Game.fade_cover(0.0, 0.2)
	queue_free()


func _exit_tree() -> void:
	GangMob.truce = false

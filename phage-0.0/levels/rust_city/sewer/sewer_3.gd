# 下水道第三段【清场费】:奥斯卡帮砸穿了拱顶打进来,两帮当场开打(管道局见黑衣服就清,黑衣服见铁罐头就砸),
# 过一会儿管道局从里头飞来一个刀翼兵增援。你可以帮一边、两边都打、或者躲远点等他们两败俱伤。
# 打完了稽查员还要收"清场费"——黑衣服是我们清的。
extends SewerRoom

const RAIDERS := {
	"thug": preload("res://entities/gang/thug/thug.tscn"),
	"knife": preload("res://entities/gang/knife/knife.tscn"),
	"chain": preload("res://entities/gang/chain/chain.tscn"),
	"brute": preload("res://entities/gang/brute/brute.tscn"),
	"thrower": preload("res://entities/gang/thrower/thrower.tscn"),
	"crossbow": preload("res://entities/gang/crossbow/crossbow.tscn"),
	"shield": preload("res://entities/gang/shield/shield.tscn"),
}
const WING: PackedScene = preload("res://entities/bureau/wingblade/wingblade.tscn")

## 主角走到这里,奥斯卡帮砸下来
@export var raid_x: float = 120.0
@export var drop_x: float = 320.0
## 两波:[种类, 相对 drop_x 的偏移, 落在哪(0 地面)]
var waves := [
	[["thug", -18], ["knife", 6], ["chain", 22], ["thug", 40]],
	[["brute", 0], ["thrower", -30], ["crossbow", 30], ["shield", 52]],
]
const WAVE_LINES := ["奥斯卡帮到！", "砸罐头！", "管道局的狗！"]
@export var wing_delay: float = 7.0
@export var wing_from: Vector2 = Vector2(566, 22)

var _raid := 0          # 0 没来 1 打着 2 打完
var _wave := 0
var _t := 0.0
var _wing_sent := false
var _raiders: Array = []


func _setup() -> void:
	if Story.flag("sewer3_raid_done"):
		_raid = 2


func can_talk() -> bool:
	return _raid == 2


func _tick() -> void:
	var dt := get_process_delta_time()
	if _raid == 0:
		if player.global_position.x >= raid_x:
			_raid = 1
			_t = 0.0
			_drop_wave()
		return
	if _raid != 1:
		return
	_t += dt
	_raiders = _raiders.filter(func(m: Variant) -> bool: return is_instance_valid(m) and (m as GangMob).health > 0)
	if _wave < waves.size() and (_t > 6.0 or _raiders.size() <= 1):
		_drop_wave()
	if not _wing_sent and _t > wing_delay:
		_wing_sent = true
		_send_wing()
	if _wave >= waves.size() and _raiders.is_empty():
		_raid = 2
		Story.set_flag("sewer3_raid_done")


func _drop_wave() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	Game.shake_camera(3.0)
	var w: Array = waves[_wave]
	_wave += 1
	_t = 0.0
	for i in w.size():
		var kind: String = w[i][0]
		var m := (RAIDERS[kind] as PackedScene).instantiate() as GangMob
		m.drop_in = true
		m.coins = 3 if kind == "brute" else 2
		m.aggro_range = 400.0
		m.position = Vector2(drop_x + float(w[i][1]), -10.0 - i * 14.0)
		if i == 0:
			m.set_meta("entry_line", WAVE_LINES[(_wave - 1) % WAVE_LINES.size()])
		scene.add_child(m)
		_raiders.append(m)


func _send_wing() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var w := WING.instantiate() as BureauMob
	w.position = wing_from
	w.coins = 5
	scene.add_child(w)
	w.died.connect(func(_x: GangMob) -> void: _check_clear.call_deferred())
	w.say_later("增援！", 0.3)


func _fee_lines() -> Array:
	return [["稽查员", "刚才那帮黑衣服的，"], ["稽查员", "是我们清的。"]]


func _refuse_options(can_pay: bool) -> Array:
	return ["我也打了", "没钱了"] if can_pay else ["没钱了", "我也打了"]


func _refused_reply(idx: int, can_pay: bool) -> Array:
	var opts := _refuse_options(can_pay)
	return ["那就打。"] if opts[idx] == "没钱了" else ["那叫妨碍公务。", "加罚。"]


func _paid_lines() -> Array:
	return ["清场费收到。", "前面出口，自己爬。"]

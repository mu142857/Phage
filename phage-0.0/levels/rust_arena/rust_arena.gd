# 铁锈城竞技场:先打几轮小怪热场,最后老大史莱姆登场(BossIntro 手动开演)。
# 两种进法:
#   ① 从竞技场街大门走进来(铁锈城里逛过来的)—— 打完老大,大门打开能回街上,梦不结束;
#   ② 这里就是这一夜的入梦场景(Story.DREAM_SCENES 周三还指着这里)—— 打完老大 = 梦醒(DreamEnd)。
# 用计时器状态机,不用 await(主角死了场景重载,协程会醒在已经释放的节点上)。
extends Node2D

const SCENES := {
	"mini": preload("res://entities/slime/mini_slime.tscn"),
	"mid": preload("res://entities/slime/mid_slime.tscn"),
	"big": preload("res://entities/slime/big_slime.tscn"),
	"thug": preload("res://entities/gang/thug/thug.tscn"),
	"knife": preload("res://entities/gang/knife/knife.tscn"),
	"thrower": preload("res://entities/gang/thrower/thrower.tscn"),
	"chain": preload("res://entities/gang/chain/chain.tscn"),
	"shield": preload("res://entities/gang/shield/shield.tscn"),
}
# 史莱姆小弟的颜色(贴图是灰的,靠 tint 上色)
const SLIME_TINTS := [Color("ff9484"), Color("b25d53"), Color("e79669")]
const ROUND_NAMES := ["第一轮", "第二轮", "第三轮", "第四轮", "第五轮"]
const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")

## 每一轮:[种类, 落点 x]。落点 x 填 -1 = 落在离主角远的那一边。
## 改出场阵容只改这里。
@export var waves: Array = [
	[["mini", -1], ["mini", -1], ["mini", -1], ["mid", -1]],
	[["thug", -1], ["mid", -1], ["knife", -1]],
	[["big", -1], ["thrower", -1], ["chain", -1]],
]
@export var arena_left: float = 14.0
@export var arena_right: float = 146.0
@export var drop_y: float = -26.0
@export var crowd_path: NodePath = ^"Crowd"
@export var boss_intro_path: NodePath = ^"BossIntro"
@export var boss_path: NodePath = ^"RustGOAT"
@export var exit_door_path: NodePath = ^"FromArenaStreet"
@export var dream_end_path: NodePath = ^"DreamEnd"

enum P { WAIT_INTRO, PRE, BANNER, SPAWN, FIGHT, BREAK, BOSS, WON }

var phase: P = P.WAIT_INTRO
var _t := 0.0
var _wave := -1
var _queue: Array = []
var _alive: Array = []
var _crowd: ArenaCrowd = null
var _boss: Node = null
var _banner: Label = null


func _ready() -> void:
	_crowd = get_node_or_null(crowd_path) as ArenaCrowd
	_boss = get_node_or_null(boss_path)
	# 不是这一夜的入梦场景(从街上走进来的 / F6 单跑):打赢不算梦醒,开门回街上
	if not _is_dream_entry():
		var end := get_node_or_null(dream_end_path)
		if end != null:
			end.queue_free()
	var door := get_node_or_null(exit_door_path)
	if door != null and door.has_method("deactivate"):
		door.call("deactivate")
	_make_banner()


func _is_dream_entry() -> bool:
	if not Story.in_dream or Story.current_dream_night <= 0:
		return false
	var night := Story.current_dream_night
	return night <= Story.DREAM_SCENES.size() and Story.DREAM_SCENES[night - 1] == scene_file_path


func _physics_process(delta: float) -> void:
	match phase:
		P.WAIT_INTRO:
			# 入梦字卡在播就等它演完(它结束会 queue_free 自己)
			if get_node_or_null("DreamIntro") == null:
				phase = P.PRE
				_t = 1.0
		P.PRE:
			_t -= delta
			if _t <= 0.0:
				_next_wave()
		P.BANNER:
			_t -= delta
			if _t <= 0.0:
				phase = P.SPAWN
				_t = 0.0
		P.SPAWN:
			_t -= delta
			if _t <= 0.0:
				if _queue.is_empty():
					phase = P.FIGHT
				else:
					_spawn(_queue.pop_front())
					_t = 0.45
		P.FIGHT:
			var before := _alive.size()
			_alive = _alive.filter(func(m: Variant) -> bool: return is_instance_valid(m))
			if _alive.size() < before and _alive.size() > 0 and _crowd != null:
				_crowd.cheer(0.4, 0.7)
			if _alive.is_empty():
				if _crowd != null:
					_crowd.cheer(1.0, 1.6)
				phase = P.BREAK
				_t = 1.8
		P.BREAK:
			_t -= delta
			if _t <= 0.0:
				if _wave + 1 >= waves.size():
					_start_boss()
				else:
					_next_wave()
		P.BOSS:
			if not is_instance_valid(_boss):
				_won()
		P.WON:
			pass


func _next_wave() -> void:
	_wave += 1
	_queue = (waves[_wave] as Array).duplicate()
	_show_banner(ROUND_NAMES[mini(_wave, ROUND_NAMES.size() - 1)])
	if _crowd != null:
		_crowd.cheer(0.7, 1.2)
	phase = P.BANNER
	_t = 1.0


func _spawn(entry: Array) -> void:
	var kind: String = entry[0]
	var x := float(entry[1])
	if x < 0.0:
		x = _far_x()
	x = clampf(x + randf_range(-6.0, 6.0), arena_left, arena_right)
	var mob := (SCENES[kind] as PackedScene).instantiate() as Node2D
	if mob is Slime:
		(mob as Slime).tint = SLIME_TINTS[randi() % SLIME_TINTS.size()]
	else:
		mob.set("drop_in", true)
	mob.position = Vector2(x, drop_y)
	add_child(mob)
	_alive.append(mob)


# 离主角远的那半边场子里挑一个点,别砸在主角头上
func _far_x() -> float:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var mid := (arena_left + arena_right) * 0.5
	if p == null:
		return randf_range(arena_left, arena_right)
	if p.global_position.x < mid:
		return randf_range(mid + 20.0, arena_right)
	return randf_range(arena_left, mid - 20.0)


func _start_boss() -> void:
	phase = P.BOSS
	_show_banner("决赛")
	if _crowd != null:
		_crowd.cheer(1.0, 3.0)
	var intro := get_node_or_null(boss_intro_path)
	if intro != null and intro.has_method("start"):
		intro.call("start")


func _won() -> void:
	phase = P.WON
	if _crowd != null:
		_crowd.cheer(1.0, 5.0)
	# BossIntro 盯着 boss,死了会把场里的门都 activate();这里再保一次
	var door := get_node_or_null(exit_door_path)
	if door != null and door.has_method("activate"):
		door.call("activate")


# ---- 每轮开头的大字:"第一轮" ----
func _make_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_banner = Label.new()
	_banner.add_theme_font_override("font", FONT)
	_banner.add_theme_font_size_override("font_size", 14)
	_banner.add_theme_color_override("font_color", Color(0.86, 0.66, 0.47))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.position = Vector2(0, 14)
	_banner.size = Vector2(160, 16)
	_banner.modulate.a = 0.0
	layer.add_child(_banner)


func _show_banner(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.9)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)

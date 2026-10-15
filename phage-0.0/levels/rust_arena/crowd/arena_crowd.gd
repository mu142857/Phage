# 竞技场看台上的观众:平时站着,偶尔有人挥一下拳;cheer() 时一起举手、蹦。
# 贴图 spectators.png 由 PixelLab/claude_drafts/arena_crowd/build_crowd.py 生成:
# 每种一行,三帧 = 手藏袍里 / 举一只拳 / 两只都举(格 9×15,脚底在最后一行)。
class_name ArenaCrowd
extends Node2D

const SHEET: Texture2D = preload("res://levels/rust_arena/crowd/spectators.png")
const KINDS := 8
const CELL_W := 9
const CELL_H := 15

## 左半边看台上每个人的脚底(站在方块顶上那一行);右半边按 mirror_x 镜像再摆一份
@export var spots: PackedVector2Array = PackedVector2Array([
	Vector2(12, 30), Vector2(17, 30), Vector2(22, 30), Vector2(27, 30),
	Vector2(33, 40), Vector2(38, 40), Vector2(43, 40), Vector2(48, 40),
	Vector2(55, 62),
])
@export var mirror_x: float = 160.0
## 远景压暗一点,别和场上的怪抢眼
@export var brightness: float = 0.78
@export var crowd_seed: int = 3

var _fans: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = crowd_seed
	var feet: Array[Vector2] = []
	for p in spots:
		feet.append(p)
	for p in spots:
		feet.append(Vector2(mirror_x - p.x, p.y))
	for i in feet.size():
		var s := Sprite2D.new()
		s.texture = SHEET
		s.centered = false
		s.hframes = 3
		s.vframes = KINDS
		s.light_mask = 0
		s.modulate = Color(brightness, brightness, brightness)
		var kind := (i * 5 + 3) % KINDS
		s.flip_h = feet[i].x > mirror_x * 0.5  # 两边都朝场子中间
		var base := Vector2(roundf(feet[i].x) - floorf(CELL_W / 2.0), feet[i].y - CELL_H)
		s.position = base
		add_child(s)
		_fans.append({
			"sprite": s, "kind": kind, "base": base,
			"cheer": 0.0,                           # 剩余欢呼时间
			"delay": 0.0,                           # 欢呼开始前的反应延迟
			"beat": 0.0,                            # 下一拍倒计时
			"up": false,                            # 这一拍是不是蹦在半空
			"idle": _rng.randf_range(1.5, 6.0),     # 平时多久挥一次拳
			"wave": 0.0,                            # 平时挥拳剩余时间
		})
		_set_pose(_fans[i], 0, false)


## 欢呼:strength = 有多少比例的人跟着喊(0~1),duration = 喊多久。
func cheer(strength: float = 1.0, duration: float = 1.2) -> void:
	for f in _fans:
		if _rng.randf() > strength:
			continue
		f["delay"] = _rng.randf_range(0.0, 0.25)
		f["cheer"] = maxf(float(f["cheer"]), duration * _rng.randf_range(0.8, 1.2))
		f["beat"] = 0.0


func _process(delta: float) -> void:
	for f in _fans:
		if float(f["cheer"]) > 0.0:
			if float(f["delay"]) > 0.0:
				f["delay"] = float(f["delay"]) - delta
				continue
			f["cheer"] = float(f["cheer"]) - delta
			f["beat"] = float(f["beat"]) - delta
			if float(f["cheer"]) <= 0.0:
				_set_pose(f, 0, false)
			elif float(f["beat"]) <= 0.0:
				f["beat"] = _rng.randf_range(0.14, 0.24)
				f["up"] = not bool(f["up"])
				_set_pose(f, 2 if bool(f["up"]) else _rng.randi_range(1, 2), bool(f["up"]))
			continue
		# 平时:偶尔有人举一只拳晃一下
		if float(f["wave"]) > 0.0:
			f["wave"] = float(f["wave"]) - delta
			if float(f["wave"]) <= 0.0:
				_set_pose(f, 0, false)
			continue
		f["idle"] = float(f["idle"]) - delta
		if float(f["idle"]) <= 0.0:
			f["idle"] = _rng.randf_range(2.5, 7.0)
			f["wave"] = _rng.randf_range(0.3, 0.6)
			_set_pose(f, 1, false)


func _set_pose(f: Dictionary, pose: int, hop: bool) -> void:
	var s: Sprite2D = f["sprite"]
	s.frame = int(f["kind"]) * 3 + pose
	s.position = (f["base"] as Vector2) + (Vector2(0, -1) if hop else Vector2.ZERO)

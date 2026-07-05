#SlimeSpawner —— CrimsonSanctum 的史莱姆刷怪器（Terraria 风格）。
#在玩家附近维持一个活跃数上限，低于上限时按间隔+概率在屏幕外(玩家左右90~110px)生成，
#按玩家当前所处「区域等级」的组成权重挑选史莱姆类型。x<400 不刷任何怪。
extends Node

const MINI_SCENE: PackedScene = preload("res://entities/slime/mini_slime.tscn")
const MID_SCENE: PackedScene = preload("res://entities/slime/mid_slime.tscn")
const BIG_SCENE: PackedScene = preload("res://entities/slime/big_slime.tscn")

## 玩家附近同时存在的史莱姆上限
@export var max_active: int = 6
## 每隔多少秒尝试一次刷新
@export var spawn_interval: float = 0.5
## 每次尝试的成功概率（Terraria 也是概率刷新，避免瞬间刷满）
@export var spawn_chance: float = 0.7
## 刷怪距玩家的最近/最远像素距离（屏幕外一带）
@export var min_spawn_dist: float = 90.0
@export var max_spawn_dist: float = 110.0
## 场景可行走范围；x<start 不刷怪，[start,end] 平均分 7 级
@export var level_start_x: float = 400.0
@export var level_end_x: float = 3200.0
## 地面 y（史莱姆落脚），生成时略高一点让其落下
@export var ground_y: float = 80.0
@export var spawn_drop_height: float = 10.0

# 少量=2，中等=5；每级 {mini, mid, big} 权重，0=该级无此类型
const FEW: int = 2
const MED: int = 5
var _levels: Array = [
	{"mini": 0,   "mid": FEW, "big": 0},    # 一级：少量中
	{"mini": FEW, "mid": FEW, "big": 0},    # 二级：少量中 + 少量小
	{"mini": FEW, "mid": FEW, "big": FEW},  # 三级：少量中 + 少量小 + 少量大
	{"mini": MED, "mid": 0,   "big": 0},    # 四级：中等小
	{"mini": FEW, "mid": MED, "big": 0},    # 五级：少量小 + 中等中
	{"mini": FEW, "mid": MED, "big": FEW},  # 六级：少量小 + 中等中 + 少量大
	{"mini": FEW, "mid": FEW, "big": MED},  # 七级：少量小 + 少量中 + 中等大
]

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	if _time < spawn_interval:
		return
	_time = 0.0
	_try_spawn()

func _try_spawn() -> void:
	if randf() > spawn_chance:
		return
	if get_tree().get_nodes_in_group("slime").size() >= max_active:
		return
	var player := _get_player()
	if player == null:
		return
	var px := player.global_position.x
	if px < level_start_x:
		return

	var level := _level_index(px)
	var scene := _pick_scene(level)
	if scene == null:
		return

	var side := 1.0 if randf() < 0.5 else -1.0
	var dist := randf_range(min_spawn_dist, max_spawn_dist)
	var spawn_x := clampf(px + side * dist, 0.0, level_end_x)

	var slime := scene.instantiate() as Slime
	if slime == null:
		return
	slime.tint = _pick_tint()
	get_parent().add_child(slime)
	slime.global_position = Vector2(spawn_x, ground_y - spawn_drop_height)

## 玩家 x 落在第几级（0~6）
func _level_index(px: float) -> int:
	var span := (level_end_x - level_start_x) / 7.0
	var idx := int((px - level_start_x) / span)
	return clampi(idx, 0, 6)

## 按当前级的权重随机挑一种史莱姆场景
func _pick_scene(level: int) -> PackedScene:
	var w: Dictionary = _levels[level]
	var total: int = int(w["mini"]) + int(w["mid"]) + int(w["big"])
	if total <= 0:
		return null
	var r := randi() % total
	if r < int(w["mini"]):
		return MINI_SCENE
	r -= int(w["mini"])
	if r < int(w["mid"]):
		return MID_SCENE
	return BIG_SCENE

## 颜色分布：1/2 ff9484，1/4 b25d53，1/8 e79669，1/8 同 S/V 随机色相
func _pick_tint() -> Color:
	var r := randf()
	if r < 0.5:
		return Color("ff9484")
	elif r < 0.75:
		return Color("b25d53")
	elif r < 0.875:
		return Color("e79669")
	else:
		var base := Color("ff9484")
		return Color.from_hsv(randf(), base.s, base.v, 1.0)

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D

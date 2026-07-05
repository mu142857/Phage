# =============================================================================
# UndergroundFire(9)  —  地火横扫【状态】：boss 隐身、无敌，沿地板扫出一排地火 → Disappear
# =============================================================================
# 注意：这是「状态机脚本」，负责让 boss 钻地并生成一排地火。
# 地火本身(危险物)是另一个脚本 penitent_ground_fire.gd（挂在 penitent_ground_fire.tscn 上）。
# =============================================================================
extends BasicState

const GROUND_FIRE_SCENE: PackedScene = preload("res://entities/penitent/penitent_ground_fire.tscn")

@export var fire_count: int = 6          # 一排几处地火
@export var spawn_interval: float = 0.12 # 相邻两处的间隔（形成横扫感）
@export var tail_wait: float = 0.8       # 最后一处烧完再等多久收尾

@onready var monster: CharacterBody2D = $"../.."

var _ticket: int = 0


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.hide()
	monster.set_deferred("collision_layer", 0)  # 地火期间打不到 boss（本体层=4）
	_ticket += 1
	_sweep(_ticket)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	_ticket += 1
	monster.set_deferred("collision_layer", 4)
	monster.ready_to_underground_fire = false


func _sweep(t: int) -> void:
	var n := maxi(fire_count, 1)
	for i in n:
		if t != _ticket:
			return
		var f := float(i) / float(maxi(n - 1, 1))
		var x := lerpf(monster.bound_min_x, monster.bound_max_x, f)
		_spawn_fire(x)
		await get_tree().create_timer(spawn_interval).timeout
		if t != _ticket:
			return
	await get_tree().create_timer(tail_wait).timeout
	if t != _ticket:
		return
	change_state(monster.STATE_DISAPPEAR)


func _spawn_fire(x: float) -> void:
	if GROUND_FIRE_SCENE == null:
		return
	var fire := GROUND_FIRE_SCENE.instantiate()
	if fire is Node2D:
		(fire as Node2D).global_position = Vector2(x, monster.floor_y)
	monster.spawn_in_world(fire)

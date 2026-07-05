# =============================================================================
# SprintAttack(8)  —  横向冲刺穿场，甩一把长镰(Scythe)，到对面边缘结束 → Idle
# =============================================================================
# 每次冲刺只甩一把长镰（进场时甩）。中段更快（acc 加速）。
# 每当血量跨过一个阶段线，本次冲刺结束时排队一波地火。
# =============================================================================
extends BasicState

const SCYTHE_SCENE: PackedScene = preload("res://entities/penitent/scythe.tscn")

@export var base_speed: float = 24.0        # 起步速度 px/s
@export var accel_bonus: float = 34.0       # 中段最高额外速度
@export var scythe_scale: float = 1.0       # 长镰缩放（=1 不缩小）
@export var scythe_offset: Vector2 = Vector2(0, 0)   # 相对 boss 原点；(0,0)=和 boss 同坐标

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var last_health_stage: int = 1


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.show()
	monster.global_position.y = monster.floor_y
	monster.apply_facing()
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Idle")
	_spawn_scythe()  # 每次冲刺只甩一把


func process(delta: float) -> void:
	# 横向移动（中段加速）
	monster.global_position.x += float(monster.direct) * _current_speed() * delta

	# 冲到对面边缘 → 结束
	var reached := false
	if monster.direct > 0 and monster.global_position.x >= monster.bound_max_x - monster.edge_margin:
		reached = true
	elif monster.direct < 0 and monster.global_position.x <= monster.bound_min_x + monster.edge_margin:
		reached = true
	if reached:
		_finish_sprint()


func exit() -> void:
	last_health_stage = monster.health_tier()


func _current_speed() -> float:
	# 越靠场地中心越快
	var center: float = (monster.bound_min_x + monster.bound_max_x) * 0.5
	var half := maxf((monster.bound_max_x - monster.bound_min_x) * 0.5, 1.0)
	var t := 1.0 - clampf(absf(monster.global_position.x - center) / half, 0.0, 1.0)
	# 血越少基础速度越快
	var hp_bonus := (1.0 - float(monster.health) / float(monster.max_health)) * 20.0
	return base_speed + hp_bonus + accel_bonus * t


func _spawn_scythe() -> void:
	if SCYTHE_SCENE == null or not is_instance_valid(ani_2d):
		return
	var sce := SCYTHE_SCENE.instantiate()
	ani_2d.add_child(sce)  # 挂在 boss 精灵上，随冲刺一起扫
	if sce is Node2D:
		(sce as Node2D).position = scythe_offset
		(sce as Node2D).scale = Vector2(scythe_scale, scythe_scale)


func _finish_sprint() -> void:
	# 跨阶段则排队一波地火（下次待机前触发）
	if monster.health_tier() != last_health_stage:
		monster.ready_to_underground_fire = true
	change_state(monster.STATE_IDLE)

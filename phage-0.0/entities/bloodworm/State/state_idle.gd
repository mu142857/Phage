# 红丝虫 待机状态(1 号)：播 Idle → 等一段(血越少越短) → 问主体下一招。
# 决策全在 bloodworm.gd 的 get_next_attack_state()，别在这写打法。
extends BasicState

@export var idle_time_full_health: float = 1.8
@export var idle_time_low_health: float = 0.9

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

# 票据：防止上一轮 Idle 的计时器在退出后才触发、错切状态
var idle_ticket: int = 0


func enter() -> void:
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Idle")

	if "idle_only" in monster and monster.idle_only:
		return

	var health_ratio: float = 1.0
	if "health" in monster and "max_health" in monster and monster.max_health > 0:
		health_ratio = float(monster.health) / float(monster.max_health)
	var duration: float = lerpf(idle_time_low_health, idle_time_full_health, health_ratio)

	idle_ticket += 1
	_start_timer(duration, idle_ticket)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	idle_ticket += 1  # 作废还没响的计时器


func _start_timer(duration: float, ticket: int) -> void:
	await get_tree().create_timer(duration).timeout
	if ticket != idle_ticket:
		return
	_decide_next()


func _decide_next() -> void:
	if "idle_only" in monster and monster.idle_only:
		return
	if monster != null and monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))

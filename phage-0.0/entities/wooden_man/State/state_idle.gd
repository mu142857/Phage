# 木头人 待机状态(1 号)：吊在手上原地晃(正弦上下 + 慢慢贴回自己的槽位 x)，
# 等一段(时长问木偶师，血越少越短) → 问木偶师下一招。
# 木偶师可能回 Idle(别的人偶正在攻击，同一时刻只许一只动手) → 过 retry_time 再问。
extends BasicState

@export var bob_amplitude: float = 3.0   # 上下晃幅度
@export var bob_speed: float = 2.0       # 晃的角速度(弧度/秒)
@export var drift_smooth: float = 3.0    # 贴回槽位 x 的指数平滑系数
@export var retry_time: float = 0.5      # 被拒绝后多久再问

@onready var monster: CharacterBody2D = $"../.."

var idle_ticket: int = 0
var _time: float = 0.0


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.hittable = true
	monster.play_anim(&"Idle")
	monster.face_player()
	idle_ticket += 1
	_start_timer(monster.idle_time(), idle_ticket)


func process(delta: float) -> void:
	_time += delta
	var target_y: float = monster.hover_y + sin(_time * bob_speed) * bob_amplitude
	var k := 1.0 - exp(-drift_smooth * delta)
	monster.global_position.y = lerpf(monster.global_position.y, target_y, k)
	monster.global_position.x = lerpf(monster.global_position.x, monster.slot_x, k)


func exit() -> void:
	idle_ticket += 1


func _start_timer(duration: float, ticket: int) -> void:
	await get_tree().create_timer(duration).timeout
	if ticket != idle_ticket or not is_instance_valid(monster):
		return
	var next: int = monster.get_next_attack_state()
	if next == monster.STATE_IDLE:
		idle_ticket += 1
		_start_timer(retry_time, idle_ticket)
		return
	change_state(next)

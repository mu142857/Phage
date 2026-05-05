extends CharacterBody2D

@export var max_health: int = 6500
@export var health: int = 6500
@export var idle_only: bool = true # 调试用：生成后保持Idle

var direct: int = 1 # 1 = facing right, -1 = facing left

func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	if health <= 0:
		health = max_health
	if has_node("StateMachine"):
		$StateMachine.set_process(true)
		$StateMachine.set_physics_process(true)

func change_state(state_id: int) -> void:
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)

func take_hit(value: int) -> void:
	health -= value
	if health <= 0:
		health = 0
		if has_node("StateMachine"):
			$StateMachine.change_state(5)

func face_left() -> void:
	direct = -1

func face_right() -> void:
	direct = 1

# =============================================================================
# BigeMove(7)  —  大形态移动（循环动画 = 持续加速追击，玩家逃不掉）
# =============================================================================
# BigMove 是【循环】动画，不发 animation_finished，所以本状态靠「距离」结束：
#   每帧朝玩家移动，速度带加速度越追越快（上限 max_speed）→ 追到 <= 20px 就
#   停下进 BigAttack。若一进来就已经 <=20px，立刻攻击。
# =============================================================================
extends BasicState

@export var move_animation: StringName = &"BigMove"
@export var start_speed: float = 40.0    # 起步速度（px/s）
@export var acceleration: float = 90.0   # 加速度（px/s²）
@export var max_speed: float = 260.0     # 追击最高速

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var speed: float = 0.0


func enter() -> void:
	speed = start_speed
	monster.velocity = Vector2.ZERO
	monster.face_player()
	if is_instance_valid(ani_2d):
		ani_2d.play(move_animation)


func process(delta: float) -> void:
	var player: Node2D = monster.get_player()
	if player == null:
		return

	var dist := absf(player.global_position.x - monster.global_position.x)
	# 追到攻击距离 → 停下开打
	if dist <= monster.retreat_distance:
		change_state(monster.STATE_BIG_ATTACK)
		return

	# 加速追击
	speed = minf(speed + acceleration * delta, max_speed)
	monster.face_player()
	var dir := signf(player.global_position.x - monster.global_position.x)
	if dir == 0.0:
		dir = float(monster.direct)
	var step := dir * speed * delta
	# 不要一步越过玩家：夹到刚好 retreat_distance 处
	var new_x := monster.global_position.x + step
	monster.global_position.x = clampf(new_x, monster.bound_min_x, monster.bound_max_x)


func exit() -> void:
	monster.velocity = Vector2.ZERO

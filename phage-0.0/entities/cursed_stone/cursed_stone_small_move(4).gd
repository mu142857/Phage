# =============================================================================
# SmallMove(4)  —  小形态移动一下（非循环 = 位移距离有限）
# =============================================================================
# 太近(<retreat_distance 20px)就远离玩家一步；否则朝玩家靠近一步。
# 用 Tween 在动画时长内平移 x。SmallMove 非循环，播完 → 回 SmallAttack。
# （变大计时由主体 _physics_process 独立跑，可能在移动途中打断本状态变身。）
# =============================================================================
extends BasicState

@export var move_animation: StringName = &"SmallMove"
@export var move_distance: float = 24.0   # 每次位移距离（有限）
@export var move_count: int = 2           # 连续移动几次再去攻击（小形态：移动两次）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var move_tween: Tween = null
var moves_done: int = 0


func enter() -> void:
	moves_done = 0
	monster.velocity = Vector2.ZERO
	monster.face_player()

	if is_instance_valid(ani_2d):
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)
		ani_2d.play(move_animation)

	_start_move()


func process(_delta: float) -> void:
	pass


func exit() -> void:
	# 必须杀掉 Tween：变身/死亡可能在位移途中打断本状态
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	move_tween = null
	if is_instance_valid(ani_2d):
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)


func _start_move() -> void:
	var player: Node2D = monster.get_player()
	var dir := float(monster.direct)
	if player != null:
		var dist := absf(player.global_position.x - monster.global_position.x)
		if dist < monster.retreat_distance:
			# 太近 → 远离玩家
			dir = signf(monster.global_position.x - player.global_position.x)
		else:
			# 太远 → 靠近玩家
			dir = signf(player.global_position.x - monster.global_position.x)
		if dir == 0.0:
			dir = 1.0

	# 位移时长 = 整段动画时长
	var duration := _anim_duration()
	var target_x := clampf(monster.global_position.x + dir * move_distance,
			monster.bound_min_x, monster.bound_max_x)

	move_tween = get_tree().create_tween()
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_property(monster, "global_position:x", target_x, duration)


func _anim_duration() -> float:
	if not is_instance_valid(ani_2d) or ani_2d.sprite_frames == null:
		return 0.5
	var fps := ani_2d.sprite_frames.get_animation_speed(move_animation)
	var frames := ani_2d.sprite_frames.get_frame_count(move_animation)
	return float(frames) / maxf(fps, 0.01)


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d) or ani_2d.animation != move_animation:
		return
	moves_done += 1
	if moves_done < move_count:
		# 还没移动够 → 再走一步（重新算方向：太近远离 / 太远靠近）
		monster.face_player()
		ani_2d.play(move_animation)
		_start_move()
		return
	change_state(monster.STATE_SMALL_ATTACK)  # 移动两次 → 攻击一次

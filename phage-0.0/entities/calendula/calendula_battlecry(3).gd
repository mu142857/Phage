# =============================================================================
# calendula_battlecry(3).gd  —  金盏战吼（3 号）：没有专属动画就播 Idle 充当
# =============================================================================
# 出场演出由 BossIntro 负责（它预先把 initial_battlecry_shown 设 true），
# 所以这里实际只会以「阶段插播战吼」运行：震屏 + 锁玩家，不做名字层。
# 结束后「问大脑」接着播当前阶段剧本。
# =============================================================================

extends BasicState

@export var battlecry_animation: StringName = &"Idle"  # 没有专属动画就用 Idle
@export var duration: float = 2.0
@export var shake_amount: float = 3.0

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false


func enter() -> void:
	is_active = true
	if is_instance_valid(ani_2d):
		ani_2d.play(battlecry_animation)

	# BossIntro 已把 initial_battlecry_shown 预设为 true；万一没挂组件裸测，
	# 这里也只把标记补上，不做运镜/名字（出场演出统一归 BossIntro）
	if monster != null and "initial_battlecry_shown" in monster:
		monster.initial_battlecry_shown = true

	_set_player_lock(true)
	_start_timer()


func process(_delta: float) -> void:
	if is_active:
		Game.shake_camera(shake_amount)


func exit() -> void:
	is_active = false
	_set_player_lock(false)
	Game.stop_shake()


func _start_timer() -> void:
	await get_tree().create_timer(duration).timeout
	if not is_active:
		return
	Game.stop_shake()
	# 演完问大脑
	if monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))
	else:
		change_state(1)


func _set_player_lock(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	if players[0].has_method("set_lock"):
		players[0].set_lock(locked)

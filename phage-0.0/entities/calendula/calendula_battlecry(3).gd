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
var _frozen_minions: Array = []


func enter() -> void:
	is_active = true
	if is_instance_valid(ani_2d):
		ani_2d.play(battlecry_animation)

	# BossIntro 已把 initial_battlecry_shown 预设为 true；万一没挂组件裸测，
	# 这里也只把标记补上，不做运镜/名字（出场演出统一归 BossIntro）
	if monster != null and "initial_battlecry_shown" in monster:
		monster.initial_battlecry_shown = true

	_set_player_lock(true)
	_freeze_minions(true)
	_start_timer()


func process(_delta: float) -> void:
	if is_active:
		Game.shake_camera(shake_amount)


func exit() -> void:
	is_active = false
	_set_player_lock(false)
	_freeze_minions(false)
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
	# 战吼式锁定:落地+全程无敌——已飞出的蛛网/毒弹不会因战吼消失,靠无敌兜底
	if players[0].has_method("set_battlecry_lock"):
		players[0].set_battlecry_lock(locked)
	elif players[0].has_method("set_lock"):
		players[0].set_lock(locked)


# 战吼锁玩家的同时也冻住场上小怪（含落地网）：
# 只锁玩家不锁小蜘蛛 = 白挨咬，不公平。只解冻自己冻的，不碰垂降中本来就冻着的。
func _freeze_minions(freeze: bool) -> void:
	if freeze:
		_frozen_minions.clear()
		for m in get_tree().get_nodes_in_group("monster"):
			var node := m as Node
			if node == null or node == monster:
				continue
			if node.process_mode != Node.PROCESS_MODE_DISABLED:
				node.process_mode = Node.PROCESS_MODE_DISABLED
				_frozen_minions.append(node)
	else:
		for node in _frozen_minions:
			if is_instance_valid(node):
				(node as Node).process_mode = Node.PROCESS_MODE_INHERIT
		_frozen_minions.clear()

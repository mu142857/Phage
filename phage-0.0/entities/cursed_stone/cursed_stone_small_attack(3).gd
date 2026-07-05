# =============================================================================
# SmallAttack(3)  —  小形态攻击：连播 SmallAttack ×2，每次召唤小地火
# =============================================================================
# 攻击前先停顿 windup_idle 秒（播 SmallIdle）—— 削弱攻击欲望，别一上来猛打。
# 停顿结束后：SmallAttack 非循环动画播 2 遍（每遍开头召唤一次小地火）→ SmallMove。
# 小地火只落在玩家当前脚下（y = fire_y = 77），无预判。
# =============================================================================
extends BasicState

const FIRE_SCENE: PackedScene = preload("res://entities/cursed_stone/cursed_stone_small_fire.tscn")

@export var attack_animation: StringName = &"SmallAttack"
@export var plays_target: int = 1      # 连打几下（小形态：攻击一次）
@export var windup_idle: float = 0.8   # 攻击前停顿秒数（越大攻击欲望越低）
@export var fire_y: float = 77.0       # 小地火释放高度

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var plays_done: int = 0
var _ticket: int = 0   # 防过期：停顿途中被打断（变身/死亡）就作废


func enter() -> void:
	monster.velocity = Vector2.ZERO
	plays_done = 0
	_ticket += 1
	monster.face_player()
	# 先摆出待机，酝酿一下
	if is_instance_valid(ani_2d):
		ani_2d.play(&"SmallIdle")
	_windup(_ticket)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	_ticket += 1  # 作废还没触发的停顿计时
	if is_instance_valid(ani_2d):
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)


func _windup(t: int) -> void:
	if windup_idle > 0.0:
		await get_tree().create_timer(windup_idle).timeout
		if t != _ticket:
			return  # 停顿期间状态已切走
	_begin_attack()


func _begin_attack() -> void:
	monster.face_player()
	if is_instance_valid(ani_2d):
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)
		ani_2d.play(attack_animation)
	_spawn_fire()  # 进入攻击即召唤


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d) or ani_2d.animation != attack_animation:
		return
	plays_done += 1
	if plays_done < plays_target:
		monster.face_player()
		ani_2d.play(attack_animation)  # 还没打够，再来一遍
		_spawn_fire()
		return
	change_state(monster.STATE_SMALL_MOVE)  # 攻击两下 → 移动一下


func _spawn_fire() -> void:
	var player: Node2D = monster.get_player()
	if player == null or FIRE_SCENE == null or get_tree().current_scene == null:
		return
	var fire := FIRE_SCENE.instantiate()
	get_tree().current_scene.add_child(fire)
	# 小地火：正落玩家脚下
	if fire is Node2D:
		(fire as Node2D).global_position = Vector2(player.global_position.x, fire_y)

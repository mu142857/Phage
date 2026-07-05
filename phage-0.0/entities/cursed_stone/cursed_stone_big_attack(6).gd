# =============================================================================
# BigAttack(6)  —  大形态攻击：连播 BigAttack ×2，每次召唤大地火（带预判）
# =============================================================================
# 一进入立刻召唤大地火（CursedStoneBigFire）。BigAttack 非循环，数 2 次 → BigeMove。
#
# ★ 大地火预判：防止玩家往前跑躲攻击。落点 =
#     玩家当前 x  +  玩家朝向 × random(0, 20)
#   即在「玩家当前位置」到「玩家逃跑方向 20px 处」之间随机取一点，
#   覆盖玩家可能走到的路径。玩家朝向取自 player.facing_direction，
#   没有该属性时退化为用玩家水平速度方向。
# =============================================================================
extends BasicState

const FIRE_SCENE: PackedScene = preload("res://entities/cursed_stone/cursed_stone_big_fire.tscn")

@export var attack_animation: StringName = &"BigAttack"
@export var plays_target: int = 1          # 大形态：攻击一次动画
@export var forward_distance: float = 35.0  # 前方那团地火：玩家面朝方向的前探距离
@export var back_distance: float = 5.0       # 后方那团地火：玩家背面方向的距离
@export var fire_y: float = 77.0             # 大地火释放高度

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var plays_done: int = 0


func enter() -> void:
	monster.velocity = Vector2.ZERO
	plays_done = 0
	monster.face_player()

	if is_instance_valid(ani_2d):
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)
		ani_2d.play(attack_animation)

	_spawn_fire()


func process(_delta: float) -> void:
	pass


func exit() -> void:
	if is_instance_valid(ani_2d):
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d) or ani_2d.animation != attack_animation:
		return
	plays_done += 1
	if plays_done < plays_target:
		monster.face_player()
		ani_2d.play(attack_animation)
		_spawn_fire()
		return
	change_state(monster.STATE_BIG_MOVE)


func _spawn_fire() -> void:
	var player: Node2D = monster.get_player()
	if player == null or FIRE_SCENE == null or get_tree().current_scene == null:
		return

	var px: float = player.global_position.x
	var face := _player_facing(player)
	# 一团在玩家背面（面朝反方向）back_distance 处
	_spawn_fire_at(px - face * back_distance)
	# 一团在玩家面朝方向前方 forward_distance 处
	_spawn_fire_at(px + face * forward_distance)


func _spawn_fire_at(x: float) -> void:
	var fire := FIRE_SCENE.instantiate()
	get_tree().current_scene.add_child(fire)
	if fire is Node2D:
		(fire as Node2D).global_position = Vector2(x, fire_y)


func _player_facing(player: Node2D) -> float:
	if "facing_direction" in player and player.facing_direction != 0:
		return signf(float(player.facing_direction))
	if "velocity" in player and absf(player.velocity.x) > 1.0:
		return signf(player.velocity.x)
	# 兜底：朝远离石头的方向（玩家多半往外逃）
	var away := signf(player.global_position.x - monster.global_position.x)
	return away if away != 0.0 else 1.0

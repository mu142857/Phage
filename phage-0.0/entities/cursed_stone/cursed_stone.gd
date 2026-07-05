# =============================================================================
# cursed_stone.gd  —  诅咒石（CursedStone）主体
# =============================================================================
# 行为总览：
#   · 平时沉睡：播 SmallIdle，不动。玩家靠近 <50px → 唤醒（唤醒后永不再睡）。
#   · 小形态循环：SmallAttack ×2 → SmallMove ×1 → 循环。
#       - SmallMove 是【非循环】动画，每次位移距离有限。
#       - 太近(<20)就远离一步，太远就靠近一步。
#   · 变大条件：唤醒后，若与玩家水平距离持续 > 20px 达 10 秒 → Transformation。
#       - 变大回满血：400 → 2000，并切换到大碰撞箱。
#   · 大形态循环：BigAttack ×2 → BigeMove ×1 → 循环。
#       - BigeMove 用【循环】动画，带加速度越追越快，追到 <20px 才停下攻击，
#         玩家逃不掉。
#   · 攻击一进入就立刻召唤地火（小地火落玩家脚下；大地火带预判随机）。
#
# 状态槽位（= StateMachine 子节点顺序 = change_state 的 id）：
#   0 Null / 1 SmallIdle(沉睡待机) / 2 Death
#   3 SmallAttack / 4 SmallMove / 5 BigIdle / 6 BigAttack / 7 BigeMove
# =============================================================================

extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/cursed_stone/cursed_stone_death.tscn")

const STATE_NULL: int = 0
const STATE_SMALL_IDLE: int = 1
const STATE_DEATH: int = 2
const STATE_SMALL_ATTACK: int = 3
const STATE_SMALL_MOVE: int = 4
const STATE_BIG_IDLE: int = 5
const STATE_BIG_ATTACK: int = 6
const STATE_BIG_MOVE: int = 7

# --- 数值 --------------------------------------------------------------------
@export var small_max_health: int = 500
@export var big_max_health: int = 3000

@export var wake_distance: float = 50.0     # 玩家靠近多少像素唤醒
@export var retreat_distance: float = 20.0  # 小于此距离就远离玩家
@export var transform_delay: float = 20.0   # 唤醒后固定多少秒【无条件】变大（不受距离影响）
@export var ground_y: float = 80.0          # 地板高度（地火落点用）

# --- 横向活动边界（防止走出场地，按关卡调）---------------------------------
@export var bound_min_x: float = -100000.0
@export var bound_max_x: float = 100000.0

# --- 运行时 ------------------------------------------------------------------
var max_health: int = 400
var health: int = 400
var awake: bool = false
var is_big: bool = false
var direct: int = 1               # 朝向：1=右 / -1=左（翻转 sprite.scale.x）
var _awake_time: float = 0.0      # 唤醒后累计存活时间（到 transform_delay 就变大）
var _transforming: bool = false
var rng := RandomNumberGenerator.new()

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var shape_small: CollisionShape2D = get_node_or_null("CollisionShape2DSmall") as CollisionShape2D
@onready var shape_big: CollisionShape2D = get_node_or_null("CollisionShape2DBig") as CollisionShape2D


func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	rng.randomize()

	max_health = small_max_health
	health = small_max_health

	# 小形态：只开小碰撞箱
	_use_big_body(false)

	# 复制材质，关掉受击闪白（每个实例独立一份）
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	# 变大计时：唤醒后固定累计存活时间，与距离无关。
	# 只要「已唤醒 + 还是小形态 + 不在变身中」，满 transform_delay 秒就必定变大。
	if awake and not is_big and not _transforming:
		_awake_time += delta
		if _awake_time >= transform_delay:
			begin_transform()


# =============================================================================
# 受伤 / 死亡
# =============================================================================
func take_damage(value: int) -> void:
	if health <= 0:
		return
	health = clampi(health - value, 0, max_health)

	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")

	if health <= 0:
		change_state(STATE_DEATH)


# =============================================================================
# 变身：Transformation 动画 → 换大碰撞箱 + 回满血 → 进大形态攻击
# =============================================================================
func begin_transform() -> void:
	if _transforming or is_big:
		return
	_transforming = true
	change_state(STATE_NULL)  # 停到 Null（不碰动画），让 Transformation 播完不被覆盖

	if ani_2d != null:
		face_player()
		ani_2d.play(&"Transformation")
		if not ani_2d.animation_finished.is_connected(_on_transform_finished):
			ani_2d.animation_finished.connect(_on_transform_finished, CONNECT_ONE_SHOT)
	else:
		_on_transform_finished()


func _on_transform_finished() -> void:
	is_big = true
	_transforming = false
	max_health = big_max_health
	health = big_max_health          # 变大回满血
	_use_big_body(true)              # 换大碰撞箱
	change_state(STATE_BIG_ATTACK)   # 变大后立刻进攻


func _use_big_body(big: bool) -> void:
	# physics 回调里改碰撞用 set_deferred 更安全
	if shape_small != null:
		shape_small.set_deferred("disabled", big)
	if shape_big != null:
		shape_big.set_deferred("disabled", not big)


# =============================================================================
# 状态切换转发
# =============================================================================
func change_state(state_id: int) -> void:
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)


# =============================================================================
# 朝向
# =============================================================================
func face_player() -> void:
	var player := get_player()
	if player == null:
		return
	direct = 1 if player.global_position.x > global_position.x else -1
	_apply_facing()

func _apply_facing() -> void:
	if ani_2d == null:
		return
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	ani_2d.scale.x = -s if direct > 0 else s  # 素材默认朝向若相反，把这里正负对调


# =============================================================================
# 工具
# =============================================================================
func get_player() -> Node2D:
	var check := get_node_or_null("PlayerCheck") as Area2D
	if check != null:
		for body in check.get_overlapping_bodies():
			if body != null and body.is_in_group("player"):
				return body as Node2D
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null

func distance_to_player() -> float:
	var p := get_player()
	if p == null:
		return INF
	return absf(p.global_position.x - global_position.x)


# 死亡时释放 CursedStoneDeath（与 Wowen 同款做法）
func spawn_death_effect() -> void:
	if DEATH_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := DEATH_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true

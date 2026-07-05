# =============================================================================
# penitent.gd  —  忏悔者 The Penitent（旧「邪帽」重置版）主体
# =============================================================================
# 移植自旧游戏 邪帽.gd + 各状态脚本，逻辑保持一致，数值全部重定到 160×90 竞技场
# （地板 y=80，可活动区约 x∈[12,148]）。
#
# 行为总览（一个大循环）：
#   Battlecry(出场·显示名字/运镜) → Disappear(传送) → Appear(现身) →
#   Skill(镰刀弹幕：SkillStart→SkillLoop→SkillEnd) → 传送到场地边缘 →
#   Prominence(从地里升起) → SprintAttack(横向冲刺+长镰) → Idle(短待机) →
#   Disappear → …循环。
#   每当血量跨过一个阶段线，下一次待机前会插一波 UndergroundFire(地火横扫)。
#   ★ 并行：只要战斗已开始，天上会周期性砸下一排「火矢」跟随玩家（血越少越密）。
#
# 状态槽位（= StateMachine 子节点顺序 = change_state 的 id）：
#   0 Null / 1 Idle / 2 Death / 3 Battlecry / 4 Appear /
#   5 Disappear / 6 Prominence / 7 Skill / 8 SprintAttack / 9 UndergroundFire
# =============================================================================

extends CharacterBody2D

const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_DEATH: int = 2
const STATE_BATTLECRY: int = 3
const STATE_APPEAR: int = 4
const STATE_DISAPPEAR: int = 5
const STATE_PROMINENCE: int = 6
const STATE_SKILL: int = 7
const STATE_SPRINT_ATTACK: int = 8
const STATE_UNDERGROUND_FIRE: int = 9

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/penitent/the_penitent_effect.tscn")
const FIRE_ARROW_SCENE: PackedScene = preload("res://entities/penitent/penitent_fire_arrow.tscn")

# --- 数值 --------------------------------------------------------------------
@export var max_health: int = 300
@export var health: int = 300

# --- 竞技场坐标（160×90 固定场地，按需在编辑器里改）------------------------
@export var bound_min_x: float = 12.0     # 可活动最左 x
@export var bound_max_x: float = 148.0    # 可活动最右 x
@export var floor_y: float = 80.0         # 地板表面（boss 立足 y / 地火落点）
@export var ceiling_y: float = 4.0        # 天降火矢的生成高度
@export var hover_y: float = 34.0         # 施法时悬浮高度
@export var edge_margin: float = 8.0      # 冲刺起手离边缘的距离

# --- 运行时 ------------------------------------------------------------------
var direct: int = 1                       # 朝向：1=右 / -1=左
var current_state_id: int = 1
var fighting: bool = false                # 出场战吼后置 true，火矢雨才开始
var initial_battlecry_shown: bool = false
var ready_to_underground_fire: bool = false
var rng := RandomNumberGenerator.new()

# --- 火矢雨（并行系统，与状态机无关）----------------------------------------
var _arrow_timer: float = 0.0
var _hit_flash_tween: Tween

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	rng.randomize()
	if health <= 0:
		health = max_health
	health = clampi(health, 0, max_health)
	global_position.y = floor_y

	if has_node("StateMachine"):
		current_state_id = $StateMachine.initial_state_index


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	# 出场前：停在 Null 里等玩家进场，玩家一出现就触发出场战吼（只一次）
	if not fighting:
		if get_player() != null:
			fighting = true
			change_state(STATE_BATTLECRY)
		return
	global_position.x = clampf(global_position.x, bound_min_x, bound_max_x)
	_update_arrow_rain(delta)


# =============================================================================
# 受伤 / 死亡
# =============================================================================
func take_damage(value: int) -> void:
	if health <= 0:
		return
	# 还没开打就被打到 → 也直接开战
	if not fighting:
		fighting = true
		change_state(STATE_BATTLECRY)
	health = clampi(health - value, 0, max_health)
	_play_hit_flash()
	if health <= 0:
		change_state(STATE_DEATH)


# 无 shader 也能看到的轻量受击闪白（往亮里推一下再缓回）
func _play_hit_flash() -> void:
	if not is_instance_valid(ani_2d):
		return
	if is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
	ani_2d.modulate = Color(2.2, 2.2, 2.2, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(ani_2d, "modulate", Color(1, 1, 1, 1), 0.12)


# =============================================================================
# 状态切换转发（顺便记录当前状态号）
# =============================================================================
func change_state(state_id: int) -> void:
	current_state_id = state_id
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)


# =============================================================================
# 天降火矢雨：血越少发数越多、间隔越长（沿用旧 ArrowTimer 手感）
# =============================================================================
func _update_arrow_rain(delta: float) -> void:
	if not fighting:
		return
	if current_state_id == STATE_BATTLECRY or current_state_id == STATE_DEATH or current_state_id == STATE_NULL:
		return
	var player := get_player()
	if player == null:
		return
	_arrow_timer -= delta
	if _arrow_timer > 0.0:
		return
	_arrow_timer = _arrow_interval()
	_fire_arrow_volley(player)


func _fire_arrow_volley(player: Node2D) -> void:
	if FIRE_ARROW_SCENE == null or get_tree().current_scene == null:
		return
	var px := player.global_position.x
	for off in _arrow_offsets():
		var arrow := FIRE_ARROW_SCENE.instantiate()
		get_tree().current_scene.add_child(arrow)
		if arrow is Node2D:
			(arrow as Node2D).global_position = Vector2(clampf(px + off, bound_min_x, bound_max_x), ceiling_y)


# 每波火矢的落点相对玩家的 x 偏移（对称左右），随血量阶段变多变宽
func _arrow_offsets() -> Array:
	match health_tier():
		1: return [-7.0, 7.0]
		2: return [-9.0, 9.0, -14.0, 14.0]
		3: return [-10.0, 10.0, -22.0, 22.0, -28.0, 28.0]
		_: return [-16.0, 16.0, -20.0, 20.0, -24.0, 24.0, -28.0, 28.0]


func _arrow_interval() -> float:
	match health_tier():
		1: return 3.0
		2: return 3.8
		3: return 4.8
		_: return 5.5


# =============================================================================
# 阶段：1(满~75%) / 2(~50%) / 3(~25%) / 4(残血)——控制火矢与镰刀的规模
# =============================================================================
func health_tier() -> int:
	if max_health <= 0:
		return 1
	var ratio := float(health) / float(max_health)
	if ratio > 0.75:
		return 1
	if ratio > 0.5:
		return 2
	if ratio > 0.25:
		return 3
	return 4


# =============================================================================
# 朝向
# =============================================================================
func face_player() -> void:
	var player := get_player()
	if player == null:
		return
	direct = 1 if player.global_position.x > global_position.x else -1
	apply_facing()

func apply_facing() -> void:
	if not is_instance_valid(ani_2d):
		return
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	# 素材默认朝右；若发现方向反了，把下面的正负对调即可
	ani_2d.scale.x = s if direct > 0 else -s


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


func spawn_in_world(node: Node) -> void:
	if get_tree().current_scene != null:
		get_tree().current_scene.add_child(node)


func spawn_death_effect() -> void:
	if DEATH_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := DEATH_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).one_shot = true
		(effect as GPUParticles2D).emitting = true
	# boss 随即 queue_free，用 tree 计时器托管把一次性特效清掉
	# （effect 若提前被释放，Godot 会自动断开这个连接，安全）
	get_tree().create_timer(3.0).timeout.connect(effect.queue_free)


# =============================================================================
# 血条 / 名字 钩子（这版先不做，留空接口，以后接 BossHealthUI + 关卡 Front 层）
# =============================================================================
func show_health_ui() -> void:
	var ui := get_node_or_null("BossHealthUI")
	if ui != null and ui.has_method("show_ui"):
		ui.show_ui(true)

func hide_health_ui() -> void:
	var ui := get_node_or_null("BossHealthUI")
	if ui != null and ui.has_method("hide_ui"):
		ui.hide_ui(false)

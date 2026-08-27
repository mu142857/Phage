# =============================================================================
# bloodworm.gd  —  红丝虫「伤口里的新住客」Boss 主体
# =============================================================================
# 周一《伤口》的虫子 boss。幼体形态：平时是小虫在地上爬，招式全和"钻进血肉里"有关。
# 由 entities/0/boss_base.gd 样板改造，决策全在这里，State 只负责演。
#
# 技能槽位：
#   Burrow(4)  钻地：沉入血肉 → 鼓包追着玩家钻 → 脚下顶出尖刺(无敌但有预警)
#   Lunge(5)   突进：贴地加速冲过去咬一口
#   Dive(6)    巨虫穿场：全屏大招，巨大的成体虫身斜穿整个画面(二阶段解锁)
#
# 动画名约定(AnimatedSprite2D)：Idle / Battlecry / Death / Burrow / Mound /
#   Emerge / Windup / Lunge；DiveSprite 上另有全屏的 Dive 动画。
# =============================================================================

extends CharacterBody2D

# --- 固定状态槽位 ------------------------------------------------------------
const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_DEATH: int = 2
const STATE_BATTLECRY: int = 3
const STATE_BURROW: int = 4
const STATE_LUNGE: int = 5
const STATE_DIVE: int = 6

# --- 基础数值 ----------------------------------------------------------------
@export var max_health: int = 4000
@export var health: int = 4000
@export var idle_only: bool = false  # 调试用：生成后只待机不攻击

# --- 横向活动边界 ------------------------------------------------------------
@export var bound_min_x: float = 10.0
@export var bound_max_x: float = 150.0

# --- 阶段阈值 ----------------------------------------------------------------
@export var phase_half_ratio: float = 0.5
@export var phase_quarter_ratio: float = 0.25

const PHASE_NORMAL: int = 0
const PHASE_HALF: int = 1
const PHASE_QUARTER: int = 2

# --- 运行时状态 --------------------------------------------------------------
var direct: int = 1
var phase: int = PHASE_NORMAL
var hittable: bool = true
var initial_battlecry_shown: bool = false  # BossIntro 组件会预先设 true
var battle_started: bool = false

var battlecry_done_half: bool = false
var battlecry_done_quarter: bool = false
var pending_battlecry: int = 0

# --- 连放/轮换 决策变量 ------------------------------------------------------
var attack_pool: Array[int] = []
var combo_remaining: int = 0
var current_attack: int = -1
var last_attack: int = -1
var rng := RandomNumberGenerator.new()

@onready var boss_health_ui = get_node_or_null("BossHealthUI")


func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	if health <= 0:
		health = max_health
	health = clampi(health, 0, max_health)
	rng.randomize()
	phase = _calc_phase()
	_update_phase()

	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health)
		boss_health_ui.hide_ui(false)

	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("Enabled", false)

	if has_node("StateMachine"):
		$StateMachine.set_process(true)
		$StateMachine.set_physics_process(true)


func _physics_process(_delta: float) -> void:
	global_position.x = clampf(global_position.x, bound_min_x, bound_max_x)
	# 停在 Null 等玩家进场；踩进 PlayerCheck(或挨打)就开战
	if not battle_started and not idle_only:
		if _get_player() != null:
			start_battle()


# 场景/BossIntro 也可以直接调这个开战
func start_battle() -> void:
	if battle_started:
		return
	battle_started = true
	change_state(STATE_BATTLECRY)


# =============================================================================
# 受伤
# =============================================================================
func take_damage(value: int) -> void:
	if not hittable:
		return  # 钻在血肉里打不到

	if not battle_started:
		start_battle()

	health -= value
	health = clampi(health, 0, max_health)

	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health, true)

	_update_phase()

	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")

	if health <= 0:
		change_state(STATE_DEATH)


# =============================================================================
# 钻地/出土 统一开关（Burrow、Dive 状态用）
# 钻着时无敌 + 本体碰撞关掉。恢复碰撞值必须是 4(层号3)，别用 set_collision_layer_value(4,..)
# =============================================================================
func set_burrowed(burrowed: bool) -> void:
	hittable = not burrowed
	set_deferred("collision_layer", 0 if burrowed else 4)


# =============================================================================
# 状态切换转发
# =============================================================================
func change_state(state_id: int) -> void:
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)


# =============================================================================
# 朝向
# =============================================================================
func face_left() -> void:
	direct = -1

func face_right() -> void:
	direct = 1

func face_player() -> void:
	var player := _get_player()
	if player == null:
		return
	if player.global_position.x < global_position.x:
		face_left()
	else:
		face_right()


# =============================================================================
# 决策核心 —— Idle 结束时调这个
# =============================================================================
func get_next_attack_state() -> int:
	_update_phase()

	if pending_battlecry > 0:
		pending_battlecry -= 1
		return STATE_BATTLECRY

	if combo_remaining > 0:
		combo_remaining -= 1
		return current_attack

	current_attack = _pick_next_attack()
	combo_remaining = _roll_combo_count(current_attack) - 1
	last_attack = current_attack
	return current_attack


func _pick_next_attack() -> int:
	_refresh_attack_pool()
	if attack_pool.is_empty():
		return STATE_IDLE
	var pool := attack_pool.duplicate()
	if pool.size() > 1:
		pool.erase(last_attack)
	return pool[rng.randi() % pool.size()]


# 一阶段只会钻地和咬；血掉半解锁巨虫穿场(体现"它其实能长很大"的压迫感)
func _refresh_attack_pool() -> void:
	match phase:
		PHASE_NORMAL:
			attack_pool = [STATE_BURROW, STATE_LUNGE]
		PHASE_HALF:
			attack_pool = [STATE_BURROW, STATE_LUNGE, STATE_DIVE]
		PHASE_QUARTER:
			attack_pool = [STATE_BURROW, STATE_LUNGE, STATE_DIVE]
		_:
			attack_pool = [STATE_BURROW]


func _roll_combo_count(_attack_id: int) -> int:
	# 巨虫穿场是大招，不连放
	if _attack_id == STATE_DIVE:
		return 1
	match phase:
		PHASE_NORMAL:
			return rng.randi_range(1, 2)
		PHASE_HALF:
			return rng.randi_range(2, 3)
		_:
			return rng.randi_range(3, 4)


# =============================================================================
# 阶段计算
# =============================================================================
func _calc_phase() -> int:
	if max_health <= 0:
		return PHASE_NORMAL
	var ratio := float(health) / float(max_health)
	if ratio <= phase_quarter_ratio:
		return PHASE_QUARTER
	if ratio <= phase_half_ratio:
		return PHASE_HALF
	return PHASE_NORMAL


func _update_phase() -> void:
	var new_phase := _calc_phase()
	if new_phase == phase:
		return
	phase = new_phase
	if phase >= PHASE_HALF and not battlecry_done_half:
		battlecry_done_half = true
		pending_battlecry += 1
	if phase >= PHASE_QUARTER and not battlecry_done_quarter:
		battlecry_done_quarter = true
		pending_battlecry += 1


# =============================================================================
# 血条 UI 接口
# =============================================================================
func show_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.show_ui(true)

func hide_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.hide_ui(false)


# =============================================================================
# 工具：拿玩家节点
# =============================================================================
func _get_player() -> Node2D:
	var player_check := get_node_or_null("PlayerCheck") as Area2D
	if player_check != null:
		for body in player_check.get_overlapping_bodies():
			if body != null and body.is_in_group("player"):
				return body as Node2D
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null

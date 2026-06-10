# =============================================================================
# boss_base.gd  —  Boss 主体骨架样板
# =============================================================================
# 用法：新 boss 复制这个文件，改数值、改 _build_attack_plan() 里的技能编排即可。
# 这是「主体」，负责所有「决策」：血量、阶段、连放计数、轮换顺序、无敌开关。
# 状态(State)只负责「演」，不做决策——需要决定下一招时调用 get_next_attack_state()。
#
# 节点结构假设（和 Actinos 一致，除碰撞箱外）：
#   Boss (CharacterBody2D, 挂本脚本)
#   ├── AnimatedSprite2D
#   ├── StateMachine (挂 state_manager.gd)
#   │     ├── Null(0)
#   │     ├── Idle(1)
#   │     ├── Death(2)
#   │     ├── Battlecry(3)
#   │     └── 各种攻击状态(4,5,6...)   ← 必须按括号里的序号排列！
#   ├── PlayerCheck (Area2D, 检测玩家位置)
#   ├── CollisionShape2D
#   ├── 各种 AttackHitBox (Area2D)
#   ├── HitEffectPlayer (AnimationPlayer, 受击闪白)
#   └── BulletReleasePoint (Node2D, 可选, 子弹发射点)
# =============================================================================

extends CharacterBody2D

# --- 固定状态槽位（每个 boss 都一样，按名字引用，不用记数字）-----------------
const STATE_NULL: int = 0       # 占位/生成前
const STATE_IDLE: int = 1       # 待机+决策中转
const STATE_DEATH: int = 2      # 死亡
const STATE_BATTLECRY: int = 3  # 战吼（出场 + 阶段切换插播）
# 技能状态从 4 往后排，在编辑器里按顺序摆好子节点

# --- 基础数值（参考值来自 Actinos）------------------------------------------
@export var max_health: int = 6500   # Actinos: 6500
@export var health: int = 6500       # 当前血量；<=0 时 _ready 自动补满
@export var idle_only: bool = false  # 调试用：生成后只待机不攻击

# --- 横向活动边界（防止 boss 跑出屏幕；参考 Actinos: 10~150）------------------
@export var bound_min_x: float = 10.0
@export var bound_max_x: float = 150.0

# --- 阶段阈值（血量比例低于此值进入下一阶段）---------------------------------
@export var phase_half_ratio: float = 0.5     # 50% 血进二阶段
@export var phase_quarter_ratio: float = 0.25 # 25% 血进三阶段

# --- 阶段常量 ----------------------------------------------------------------
const PHASE_NORMAL: int = 0
const PHASE_HALF: int = 1
const PHASE_QUARTER: int = 2

# --- 运行时状态 --------------------------------------------------------------
var direct: int = 1                  # 朝向：1=右, -1=左
var phase: int = PHASE_NORMAL
var hittable: bool = true            # ← 无敌开关！闪避状态 enter 时设 false, exit 时设 true
var initial_battlecry_shown: bool = false  # 出场战吼是否已播过（区分出场 vs 阶段插播）

# 阶段战吼「只插一次」的标记
var battlecry_done_half: bool = false
var battlecry_done_quarter: bool = false
var pending_battlecry: int = 0       # 待插播的战吼次数

# --- 连放/轮换 决策变量 ------------------------------------------------------
# 这套是 Actinos 的「同一招连放 N 次再换下一招」逻辑的通用化。
# attack_pool: 当前阶段可用的技能状态序号列表（决策从这里挑）
# combo_remaining: 当前这一招还要再连放几次
# current_attack: 当前正在连放的招（状态序号）
var attack_pool: Array[int] = []
var combo_remaining: int = 0
var current_attack: int = -1
var last_attack: int = -1            # 上一招（用于「不连续重复」的随机）
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

	# 初始化血条
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health)
		boss_health_ui.hide_ui(false)

	# 关掉受击闪白 shader（开场不闪）
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("Enabled", false)

	if has_node("StateMachine"):
		$StateMachine.set_process(true)
		$StateMachine.set_physics_process(true)


func _physics_process(_delta: float) -> void:
	# 把 boss 锁在横向边界内（参考 Actinos）
	global_position.x = clampf(global_position.x, bound_min_x, bound_max_x)


# =============================================================================
# 受伤 —— 注意第一行的 hittable 检查，这是无敌帧的核心
# =============================================================================
func take_damage(value: int) -> void:
	if not hittable:
		return  # ← 无敌中：血不掉、不闪白、不进任何后续逻辑

	health -= value
	health = clampi(health, 0, max_health)

	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health, true)  # true = 播放受伤表现

	_update_phase()

	# 受击闪白
	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")

	if health <= 0:
		change_state(STATE_DEATH)


# 回血（给「冰红茶回血」这类技能用；你说这个你自己写，这里留个范例）
# heal() 里建议血条用绿色闪一下区别于红色受伤闪——boss_health_ui.refresh 第三参数
# 你可以扩成 refresh(health, max_health, "heal") 之类，按你血条的实现来。
func heal(value: int) -> void:
	health = clampi(health + value, 0, max_health)
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health)  # 这里按需触发绿闪


# =============================================================================
# 状态切换转发（State 通过 host.change_state() 最终走到这）
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

# 朝向玩家（攻击状态 enter 时调一下，省得每个状态自己算）
func face_player() -> void:
	var player := _get_player()
	if player == null:
		return
	if player.global_position.x < global_position.x:
		face_left()
	else:
		face_right()


# =============================================================================
# 决策核心 —— Idle 结束时调这个，返回下一个状态序号
# =============================================================================
# 这是整个 boss「打法」的大脑。所有编排逻辑都集中在这，改打法只改这里。
# 流程：1) 先处理阶段战吼插播  2) 没插播就走「连放/轮换」逻辑
func get_next_attack_state() -> int:
	_update_phase()

	# --- 1. 阶段战吼插播优先 ---
	if pending_battlecry > 0:
		pending_battlecry -= 1
		return STATE_BATTLECRY

	# --- 2. 连放逻辑：当前这招还没放够次数，继续放 ---
	if combo_remaining > 0:
		combo_remaining -= 1
		return current_attack

	# --- 3. 这招放够了，挑下一招 ---
	current_attack = _pick_next_attack()
	combo_remaining = _roll_combo_count(current_attack) - 1  # 减1因为这次就要放一下
	last_attack = current_attack
	return current_attack


# 从当前阶段的技能池里挑一招（不连续重复上一招）
# 改这里 = 改「这个 boss 会放哪些招、各阶段招式不同」
func _pick_next_attack() -> int:
	_refresh_attack_pool()
	if attack_pool.is_empty():
		return STATE_IDLE  # 兜底：没招可放就回 Idle
	var pool := attack_pool.duplicate()
	if pool.size() > 1:
		pool.erase(last_attack)  # 不连续放同一招（栗子劫念的做法）
	return pool[rng.randi() % pool.size()]


# 按阶段刷新可用技能池。
# === 这里是你每个 boss 要重点改的地方 ===
# 示例：一阶段全技能，越往后阶段技能越少/越凶（仿栗子劫念）
func _refresh_attack_pool() -> void:
	match phase:
		PHASE_NORMAL:
			attack_pool = [4, 5, 6]      # 一阶段：所有技能（按你实际状态序号填）
		PHASE_HALF:
			attack_pool = [4, 5, 6]      # 二阶段：可改成换一套
		PHASE_QUARTER:
			attack_pool = [5, 6]         # 三阶段：示例，去掉某招
		_:
			attack_pool = [4]


# 某一招要连放几次（参考 Actinos: jump 一阶段 1~2 次, spike 2~3 次, 越后期越多）
# 改这里 = 改「每招连放几次、各阶段强度」
func _roll_combo_count(attack_id: int) -> int:
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
	# 跨过阶段线时排队一次战吼插播（每条线只插一次）
	if phase >= PHASE_HALF and not battlecry_done_half:
		battlecry_done_half = true
		pending_battlecry += 1
	if phase >= PHASE_QUARTER and not battlecry_done_quarter:
		battlecry_done_quarter = true
		pending_battlecry += 1


# =============================================================================
# 血条 UI 接口（出场战吼结束才显示，参考 Actinos）
# =============================================================================
func show_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.show_ui(true)

func hide_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.hide_ui(false)


# =============================================================================
# 工具：拿玩家节点（攻击状态里追踪玩家位置用）
# =============================================================================
func _get_player() -> Node2D:
	var player_check := get_node_or_null("PlayerCheck") as Area2D
	if player_check != null:
		for body in player_check.get_overlapping_bodies():
			if body != null and body.is_in_group("player"):
				return body as Node2D
	# PlayerCheck 没覆盖到时，从组里兜底找
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null

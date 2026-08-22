# =============================================================================
# calendula.gd  —  金盏主体（顶级捕猎者 · 蛛网森林 Boss，剧本制决策）
# =============================================================================
# 悬浮型 Boss：平时像 cox 一样漂浮，忽高忽低（没有上劈也能打到）。
# 状态槽位：
#   0 Null / 1 Idle(悬浮游走) / 2 Death / 3 Battlecry
#   4 WebShot(吐网弹,单发) / 5 Summon(召唤小蜘蛛,三选轮换) / 6 Ram(对高冲扫)
#
# 决策 = 「剧本制」（同 rust_goat）：每阶段一个剧本，两种模式——
#   sequence    按列表顺序循环播（Idle 也是列表里的普通条目）
#   random_link 从列表随机挑（不连续重复），每招之间插一个 link 状态衔接
#
# ★ 全项目统一规则：状态演完不写死 change_state(1)，
#   而是 change_state(monster.get_next_attack_state())——「演完问大脑」。
#
# 出场演出由 BossIntro 组件负责（头衔「顶级捕猎者」+ 名字「金盏」字卡），
# 本体不做 Front 名字层。
# =============================================================================

extends CharacterBody2D

const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_DEATH: int = 2
const STATE_BATTLECRY: int = 3
const STATE_WEB_SHOT: int = 4
const STATE_SUMMON: int = 5
const STATE_RAM: int = 6

# --- 基础数值 ----------------------------------------------------------------
@export var max_health: int = 5000
@export var health: int = 5000
@export var idle_only: bool = false

# --- 横向活动边界 --------------------------------------------------------------
@export var bound_min_x: float = 10.0
@export var bound_max_x: float = 150.0

# --- 阶段阈值（血量比例低于此值进入下一阶段）---------------------------------
@export var phase_two_ratio: float = 0.667    # 低于 66.7% 进二阶段
@export var phase_three_ratio: float = 0.333  # 低于 33.3% 进三阶段

const PHASE_ONE: int = 0
const PHASE_TWO: int = 1
const PHASE_THREE: int = 2

# =============================================================================
# ★ 剧本表 —— 改打法只改这里 ★
# =============================================================================
# 一阶段：三招各来一遍，节奏舒缓，教玩家认招
# 二阶段：冲撞变频，压走位
# 三阶段：全招式随机连轴转，Idle（悬浮）当衔接
var phase_scripts: Dictionary = {
	PHASE_ONE: {
		"mode": "sequence",
		"list": [STATE_WEB_SHOT, STATE_IDLE, STATE_SUMMON, STATE_IDLE,
				STATE_RAM, STATE_IDLE, STATE_WEB_SHOT, STATE_IDLE],
	},
	PHASE_TWO: {
		"mode": "sequence",
		"list": [STATE_RAM, STATE_IDLE, STATE_WEB_SHOT, STATE_IDLE,
				STATE_SUMMON, STATE_IDLE, STATE_RAM, STATE_IDLE,
				STATE_WEB_SHOT, STATE_IDLE],
	},
	PHASE_THREE: {
		"mode": "random_link",
		"list": [STATE_WEB_SHOT, STATE_SUMMON, STATE_RAM],
		"link": STATE_IDLE,
	},
}

# --- 运行时状态 --------------------------------------------------------------
var direct: int = 1
var phase: int = PHASE_ONE
var hittable: bool = true
var initial_battlecry_shown: bool = false
var current_state_id: int = 0

var battlecry_done_p2: bool = false  # 二阶段战吼只插一次
var battlecry_done_p3: bool = false  # 三阶段战吼只插一次
var pending_battlecry: int = 0

# --- 剧本播放指针 --------------------------------------------------------------
var seq_index: int = 0       # sequence 模式：播到列表第几个
var link_turn: bool = false  # random_link 模式：下一个是不是该出 link
var last_pick: int = -1      # random_link 模式：上一招（避免连续重复）
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
		current_state_id = $StateMachine.initial_state_index
		$StateMachine.set_process(true)
		$StateMachine.set_physics_process(true)


func _physics_process(_delta: float) -> void:
	global_position.x = clampf(global_position.x, bound_min_x, bound_max_x)


# =============================================================================
# 受伤（含 hittable 无敌开关）
# =============================================================================
func take_damage(value: int) -> void:
	if not hittable:
		return

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


func heal(value: int) -> void:
	health = clampi(health + value, 0, max_health)
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health, true)


# =============================================================================
# 状态切换转发（顺便记录当前状态号）
# =============================================================================
func change_state(state_id: int) -> void:
	current_state_id = state_id
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
# 决策核心：剧本播放器
# =============================================================================
func get_next_attack_state() -> int:
	_update_phase()

	# 1. 阶段战吼插播优先（不动剧本指针，战吼完回来接着播）
	if pending_battlecry > 0:
		pending_battlecry -= 1
		return STATE_BATTLECRY

	var script: Dictionary = phase_scripts.get(phase, phase_scripts[PHASE_ONE])
	var list: Array = script["list"]
	if list.is_empty():
		return STATE_IDLE

	match script["mode"]:
		"sequence":
			var next: int = list[seq_index % list.size()]
			seq_index += 1
			return next
		"random_link":
			if link_turn:
				link_turn = false
				return script["link"]
			var pool := list.duplicate()
			if pool.size() > 1:
				pool.erase(last_pick)
			var pick: int = pool[rng.randi() % pool.size()]
			last_pick = pick
			link_turn = true
			return pick
	return STATE_IDLE


# =============================================================================
# 阶段计算（换阶段时剧本指针归零，从新剧本头开始播）
# =============================================================================
func _calc_phase() -> int:
	if max_health <= 0:
		return PHASE_ONE
	var ratio := float(health) / float(max_health)
	if ratio <= phase_three_ratio:
		return PHASE_THREE
	if ratio <= phase_two_ratio:
		return PHASE_TWO
	return PHASE_ONE


func _update_phase() -> void:
	var new_phase := _calc_phase()
	if new_phase == phase:
		return
	phase = new_phase
	# 换剧本：指针复位
	seq_index = 0
	link_turn = false
	last_pick = -1
	# 阶段战吼排队（每条线一次）
	if phase >= PHASE_TWO and not battlecry_done_p2:
		battlecry_done_p2 = true
		pending_battlecry += 1
	if phase >= PHASE_THREE and not battlecry_done_p3:
		battlecry_done_p3 = true
		pending_battlecry += 1


# =============================================================================
# 血条 UI
# =============================================================================
func show_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.show_ui(true)

func hide_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.hide_ui(false)


# =============================================================================
# 工具：拿玩家
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

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

# 死亡特效 = 同时放大/中/小镰刀三种粒子
const BIG_SICKLE_EFFECT: PackedScene = preload("res://entities/penitent/big_sickle_effect.tscn")
const MID_SICKLE_EFFECT: PackedScene = preload("res://entities/penitent/mid_sickle_effect.tscn")
const SMALL_SICKLE_EFFECT: PackedScene = preload("res://entities/penitent/small_sickle_effect.tscn")
const FIRE_ARROW_SCENE: PackedScene = preload("res://entities/penitent/penitent_fire_arrow.tscn")

# --- 数值 --------------------------------------------------------------------
@export var max_health: int = 4200
@export var health: int = 4200

# --- 竞技场坐标（160×90 固定场地，按需在编辑器里改）------------------------
@export var bound_min_x: float = 12.0     # 可活动最左 x
@export var bound_max_x: float = 148.0    # 可活动最右 x
@export var floor_y: float = 80.0         # 地板表面（boss 立足 y / 地火落点）
@export var ceiling_y: float = 4.0        # 天降火矢的生成高度
@export var hover_y: float = 34.0         # 施法时悬浮高度
@export var edge_margin: float = 8.0      # 冲刺起手离边缘的距离
@export var spear_min_x: float = 5.0     # 天降长矛随机落点范围（屏幕内 5~155）
@export var spear_max_x: float = 155.0
# 掉矛限速：两波矛的最短间隔。上限对齐玩家召唤卵的攻速（spider_egg fire_interval = 0.4s），
# 玩家攻速再快，掉矛也不能比卵射得还快。
@export var spear_drop_interval: float = 0.4

# --- 运行时 ------------------------------------------------------------------
var direct: int = 1                       # 朝向：1=右 / -1=左
var current_state_id: int = 1
var fighting: bool = false                # 出场战吼后置 true，火矢雨才开始
var initial_battlecry_shown: bool = false
var ready_to_underground_fire: bool = false
var _spear_drop_cooldown: float = 0.0     # 掉矛限速计时（>0 期间挨打不掉矛）
var rng := RandomNumberGenerator.new()

var _hit_flash_tween: Tween

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var boss_health_ui = get_node_or_null("BossHealthUI")


func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	rng.randomize()
	if health <= 0:
		health = max_health
	health = clampi(health, 0, max_health)
	global_position.y = floor_y

	# 复制材质并关掉受击闪白 shader（每实例独立一份，默认不闪；受击时才由 HitFlash 打开）
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)

	if has_node("StateMachine"):
		current_state_id = $StateMachine.initial_state_index


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	_spear_drop_cooldown = maxf(_spear_drop_cooldown - delta, 0.0)
	# 出场前：停在 Null 里等玩家进场，玩家一出现就触发出场战吼（只一次）
	if not fighting:
		if get_player() != null:
			fighting = true
			change_state(STATE_BATTLECRY)
		return
	global_position.x = clampf(global_position.x, bound_min_x, bound_max_x)


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
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health, true)   # 刷新血条 + 受击红闪
	_play_hit_flash()
	if fighting:
		_drop_spears()   # 每次被成功击中 → 天降长矛
	if health <= 0:
		change_state(STATE_DEATH)


# 受击闪白：走 HitEffectPlayer 的 HitFlash（开一下 hurt shader 再关）
func _play_hit_flash() -> void:
	if not has_node("HitEffectPlayer"):
		return
	if not $HitEffectPlayer.active:
		$HitEffectPlayer.active = true
	$HitEffectPlayer.play("HitFlash")


# =============================================================================
# 状态切换转发（顺便记录当前状态号）
# =============================================================================
func change_state(state_id: int) -> void:
	current_state_id = state_id
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)


# =============================================================================
# 天降长矛：玩家击中 boss 时在屏幕内随机落 1~3 根（血越少越多）。
# 带限速：两波之间至少隔 spear_drop_interval，连击太快时中间的击中不掉矛。
# =============================================================================
func _drop_spears() -> void:
	if _spear_drop_cooldown > 0.0:
		return   # 限速中：这一下不掉矛
	if FIRE_ARROW_SCENE == null or get_tree().current_scene == null:
		return
	_spear_drop_cooldown = spear_drop_interval
	var count := clampi(health_tier(), 1, 3)   # 1~3 根，血越少越多
	for i in count:
		var x := rng.randf_range(spear_min_x, spear_max_x)
		var spear := FIRE_ARROW_SCENE.instantiate()
		get_tree().current_scene.add_child(spear)
		if spear is Node2D:
			(spear as Node2D).global_position = Vector2(x, ceiling_y)


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
	if get_tree().current_scene == null:
		return
	# 死亡时在 boss 处同时放三种镰刀粒子（各自的 Timer 会自己清理）
	for scene: PackedScene in [BIG_SICKLE_EFFECT, MID_SICKLE_EFFECT, SMALL_SICKLE_EFFECT]:
		if scene == null:
			continue
		var fx := scene.instantiate()
		get_tree().current_scene.add_child(fx)
		if fx is Node2D:
			(fx as Node2D).global_position = global_position
		if fx is GPUParticles2D:
			(fx as GPUParticles2D).emitting = true


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

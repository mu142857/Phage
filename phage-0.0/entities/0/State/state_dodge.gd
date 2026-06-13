# =============================================================================
# state_dodge.gd  —  闪避/无敌帧样板
# =============================================================================
# 最小积木：进入时 hittable=false（主体 take_damage 第一行直接吞伤害）→ 播闪避动画
#          + 可选半透明表现 → 时长结束恢复 hittable → 回 Idle 或接指定状态。
#
# 配套要求（缺一不可）：
#   1. boss_base.gd 已内置 hittable 检查（已有 ✓）
#   2. 玩家攻击命中处加一行：命中目标若有 hittable 且为 false → 不放命中特效
#      伪代码: if "hittable" in target and not target.hittable: return  # 不放特效
#
# 拼接用法（后撤步投篮 = 三块积木）：
#   方案A（推荐，省事）：直接在 state_dash_attack.gd 的副本里加上本文件的
#     enter 设 false / exit 设 true 两行，retreat=true，到位后接发射逻辑。
#   方案B：本状态 next_state 填后续攻击的序号，闪避完自动接招。
# =============================================================================

extends BasicState

@export var dodge_animation: StringName = &"Dodge"  # 闪避动画名（没有就播 Idle）
@export var duration: float = 0.5                   # 无敌时长（短闪避 0.3~0.6 合适）
@export var next_state: int = 1                     # 结束后去哪（1=回Idle；填技能序号=接招）
@export var ghost_alpha: float = 0.5                # 无敌期间半透明度（1.0=不变）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var ticket: int = 0


func enter() -> void:
	# ===== 核心：开无敌 =====
	if "hittable" in monster:
		monster.hittable = false

	# 半透明表现（让玩家直观知道「现在打不中」）
	if is_instance_valid(ani_2d):
		ani_2d.modulate.a = ghost_alpha
		if ani_2d.sprite_frames != null and ani_2d.sprite_frames.has_animation(dodge_animation):
			ani_2d.play(dodge_animation)
		else:
			ani_2d.play(&"Idle")

	ticket += 1
	_start_timer(duration, ticket)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	ticket += 1
	# ===== 核心：关无敌（无论怎么离开本状态都恢复，防卡永久无敌）=====
	if "hittable" in monster:
		monster.hittable = true
	if is_instance_valid(ani_2d):
		ani_2d.modulate.a = 1.0


func _start_timer(time: float, t: int) -> void:
	await get_tree().create_timer(time).timeout
	if t != ticket:
		return
	change_state(next_state)
